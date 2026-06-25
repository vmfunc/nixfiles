// lumen: a music-reactive desktop wallpaper.
//
// one borderless window per screen, pinned at the desktop window level (above the
// static desktop picture, below the icons), click-through and on every space, each
// rendering shader.metal in an MTKView. system audio is tapped through
// ScreenCaptureKit, the SAME path and TCC grant as pkgs/record (capturesAudio only,
// the mic is never opened), run through a vDSP FFT into bass/mid/treble/level bands
// that drive the shader uniforms.
//
// degradation is deliberate: if the screen-recording grant is missing the audio tap
// keeps retrying while the field still drifts on time alone, so the process never
// exits and launchd never hot-loops. rendering pauses per-window when that window is
// occluded (a fullscreen app covering the desktop), to keep the GPU idle on battery.
//
// TCC: first run needs the one-time Screen Recording grant, same as `record`. nix
// cannot grant it; accept the prompt once per machine.
#import <AppKit/AppKit.h>
#import <Accelerate/Accelerate.h>
#import <CoreMedia/CoreMedia.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <os/lock.h>

static const int kTargetFps = 30;             // calm field; 30 is plenty and saves power
static const NSInteger kAudioSampleRate = 48000;
// enum, not const int: these size stack arrays, so they must be constant expressions
enum { kFftLog2 = 10, kFftN = 1 << kFftLog2 };  // 1024-point FFT
static const int kHopSize = 512;              // run the FFT every 512 samples (~94 Hz),
                                              // NOT per-sample: that pegs a core and the
                                              // SCK audio handler drops the stream
// bin width is kAudioSampleRate/kFftN ~= 46.9 Hz; the band bin ranges below derive from it

// band edges in bins (skip DC at bin 0). feel-tuned, not psychoacoustically exact.
static const int kBassLo = 1, kBassHi = 4;     // ~47..187 Hz
static const int kMidLo = 5, kMidHi = 42;      // ~234..1968 Hz
static const int kTrebLo = 43, kTrebHi = 255;  // ~2..12 kHz

// per-band noise gate (measured against silence) and AGC: each gated band is
// normalized against a slow-decaying peak so the reaction tracks the music's dynamics
// and adapts to volume, instead of a fixed gain that saturates loud and dies quiet.
// minPeak is the gated level a band reads as "full" when nothing louder is the
// reference. values measured against silence and 0.5-amp 80Hz/1k/8k tones.
static const float kFloorBass = 0.010f, kFloorMid = 0.0035f, kFloorTreb = 0.0005f;
static const float kMinPeakBass = 0.035f, kMinPeakMid = 0.0035f, kMinPeakTreb = 0.0009f;
static const float kPeakDecay = 0.995f;  // ~1.5s half-life AGC envelope at the hop rate
static const float kBandDecay = 0.93f;   // per-hop release: light fades, not snaps
static const float kAttack = 0.35f;      // eased attack: light swells in, never strobes

// uniform layout mirrors shader.metal Uniforms exactly (float2 then 5 floats)
typedef struct {
  float resolution[2];
  float time;
  float bass;
  float mid;
  float treble;
  float level;
} Uniforms;

typedef struct {
  float bass, mid, treble, level;
} Bands;

// audio thread publishes, render thread reads; tiny critical section under a spinlock
static Bands gBands;
static os_unfair_lock gBandsLock = OS_UNFAIR_LOCK_INIT;

// eased attack, slow release: light swells in and fades out, it never snaps or strobes
static inline float smoothBand(float cur, float target) {
  if (target > cur) {
    return cur + (target - cur) * kAttack;
  }
  float decayed = cur * kBandDecay;
  return decayed > target ? decayed : target;
}

// kept alive for the process lifetime (ARC would otherwise drop them)
static id<MTLDevice> gDevice;
static id<MTLCommandQueue> gQueue;
static id<MTLRenderPipelineState> gPipeline;
static CFTimeInterval gStartTime;
static NSMutableArray *gWindows;
static id gRenderer;
static id gAudioTap;

// defined below; the screen-reconfiguration observer calls it before its definition
void rebuildWindows(void);

#pragma mark - audio

@interface AudioTap : NSObject <SCStreamDelegate, SCStreamOutput>
@end

@implementation AudioTap {
  dispatch_queue_t _queue;
  SCStream *_stream;
  FFTSetup _fft;
  float _window[kFftN];   // Hann window
  float _ring[kFftN];     // circular buffer of recent mono samples
  int _writePos;          // next write index into _ring (wraps); also the oldest once full
  int _filled;            // valid samples so far, caps at kFftN
  int _sinceHop;          // samples accumulated since the last FFT
  float _realp[kFftN / 2];
  float _imagp[kFftN / 2];
  float _peakBass, _peakMid, _peakTreb;  // per-band AGC envelopes
  BOOL _starting;         // a start() is mid-flight: single-flight guard
  BOOL _active;           // a stream is live; never start a second one
  int _debug;             // LUMEN_DEBUG in env: log band levels periodically
  int _logTick;
}

- (instancetype)init {
  if ((self = [super init])) {
    _queue = dispatch_queue_create("re.vmfunc.lumen.audio", DISPATCH_QUEUE_SERIAL);
    _fft = vDSP_create_fftsetup(kFftLog2, kFFTRadix2);
    if (_fft == NULL) {
      fprintf(stderr, "lumen: vDSP_create_fftsetup failed\n");
      return nil;
    }
    vDSP_hann_window(_window, kFftN, vDSP_HANN_NORM);
    _debug = getenv("LUMEN_DEBUG") != NULL;
  }
  return self;
}

- (void)start {
  if (_starting || _active) {
    return;  // single-flight: two SCStreams would interrupt each other and flap
  }
  _starting = YES;
  [SCShareableContent
      getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
        if (error != nil || content.displays.firstObject == nil) {
          // almost always the missing screen-recording grant; the field keeps drifting
          self->_starting = NO;
          fprintf(stderr, "lumen: audio tap unavailable (%s); retrying in 5s\n",
                  error.localizedDescription.UTF8String ?: "no display");
          [self retryStart];
          return;
        }
        [self beginWithDisplay:content.displays.firstObject];
      }];
}

- (void)retryStart {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(),
                 ^{ [self start]; });
}

- (void)beginWithDisplay:(SCDisplay *)display {
  SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
  SCStreamConfiguration *cfg = [[SCStreamConfiguration alloc] init];
  // we only want audio; keep the (mandatory) video path as cheap as possible
  cfg.width = 2;
  cfg.height = 2;
  cfg.minimumFrameInterval = CMTimeMake(1, 1);
  cfg.capturesAudio = YES;
  cfg.excludesCurrentProcessAudio = YES;
  cfg.sampleRate = kAudioSampleRate;
  cfg.channelCount = 2;

  _stream = [[SCStream alloc] initWithFilter:filter configuration:cfg delegate:self];
  NSError *addErr = nil;
  if (![_stream addStreamOutput:self
                           type:SCStreamOutputTypeAudio
             sampleHandlerQueue:_queue
                          error:&addErr]) {
    _starting = NO;
    fprintf(stderr, "lumen: addStreamOutput: %s; retrying in 5s\n",
            addErr.localizedDescription.UTF8String);
    [self retryStart];
    return;
  }
  [_stream startCaptureWithCompletionHandler:^(NSError *startErr) {
    if (startErr != nil) {
      self->_starting = NO;
      fprintf(stderr, "lumen: startCapture: %s; retrying in 5s\n",
              startErr.localizedDescription.UTF8String);
      [self retryStart];
      return;
    }
    self->_starting = NO;
    self->_active = YES;
    fprintf(stderr, "lumen: audio tap live\n");
  }];
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
  (void)stream;
  _active = NO;
  _starting = NO;
  fprintf(stderr, "lumen: audio stream stopped: %s; retrying in 5s\n",
          error.localizedDescription.UTF8String);
  [self retryStart];
}

- (void)stream:(SCStream *)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  (void)stream;
  if (type != SCStreamOutputTypeAudio || !CMSampleBufferIsValid(sampleBuffer)) {
    return;
  }

  CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *asbd =
      fmt ? CMAudioFormatDescriptionGetStreamBasicDescription(fmt) : NULL;
  if (asbd == NULL || asbd->mChannelsPerFrame == 0) {
    return;
  }
  BOOL interleaved = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0;
  UInt32 channels = asbd->mChannelsPerFrame;
  CMItemCount frames = CMSampleBufferGetNumSamples(sampleBuffer);
  if (frames <= 0) {
    return;
  }

  // a buffer list sized for this sample buffer (1 buffer if interleaved, N if planar)
  size_t ablSize = 0;
  if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &ablSize, NULL, 0, NULL,
                                                              NULL, 0, NULL) != noErr ||
      ablSize == 0) {
    return;
  }
  AudioBufferList *abl = (AudioBufferList *)malloc(ablSize);
  if (abl == NULL) {
    return;
  }
  CMBlockBufferRef block = NULL;
  OSStatus st = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, NULL, abl, ablSize, NULL, NULL, 0, &block);
  if (st != noErr || block == NULL) {
    free(abl);
    return;
  }

  [self ingestBufferList:abl channels:channels frames:(int)frames interleaved:interleaved];

  CFRelease(block);
  free(abl);
}

// downmix to mono into the ring, then run an FFT over the most recent kFftN samples
- (void)ingestBufferList:(const AudioBufferList *)abl
                channels:(UInt32)channels
                  frames:(int)frames
             interleaved:(BOOL)interleaved {
  for (int f = 0; f < frames; f++) {
    float sum = 0.0f;
    if (interleaved) {
      const float *s = (const float *)abl->mBuffers[0].mData;
      if (s == NULL) {
        return;
      }
      for (UInt32 ch = 0; ch < channels; ch++) {
        sum += s[(size_t)f * channels + ch];
      }
    } else {
      UInt32 n = abl->mNumberBuffers < channels ? abl->mNumberBuffers : channels;
      for (UInt32 ch = 0; ch < n; ch++) {
        const float *s = (const float *)abl->mBuffers[ch].mData;
        if (s != NULL) {
          sum += s[f];
        }
      }
    }
    float mono = sum / (float)channels;
    _ring[_writePos] = mono;
    _writePos = (_writePos + 1) % kFftN;
    if (_filled < kFftN) {
      _filled++;
    }
    if (++_sinceHop >= kHopSize) {
      _sinceHop = 0;
      if (_filled >= kFftN) {
        [self analyze];
      }
    }
  }
}

- (void)analyze {
  // copy the circular buffer out oldest-to-newest into a linear frame for the FFT
  float frame[kFftN];
  int oldest = _writePos;  // once full, the write cursor sits on the oldest sample
  for (int i = 0; i < kFftN; i++) {
    frame[i] = _ring[(oldest + i) % kFftN];
  }
  // strip DC first: a DC offset windowed by the Hann leaks into the lowest bins and
  // pins the bass band high even in silence. subtract the frame mean to zero it out.
  float mean = 0.0f;
  vDSP_meanv(frame, 1, &mean, kFftN);
  float negMean = -mean;
  vDSP_vsadd(frame, 1, &negMean, frame, 1, kFftN);

  float windowed[kFftN];
  vDSP_vmul(frame, 1, _window, 1, windowed, 1, kFftN);

  DSPSplitComplex split = {.realp = _realp, .imagp = _imagp};
  vDSP_ctoz((const DSPComplex *)windowed, 2, &split, 1, kFftN / 2);
  vDSP_fft_zrip(_fft, &split, 1, kFftLog2, kFFTDirection_Forward);

  // squared magnitudes; bin 0 holds DC (realp) and Nyquist (imagp), we skip both
  float mag[kFftN / 2];
  vDSP_zvmags(&split, 1, mag, 1, kFftN / 2);

  float rb = [self rawBand:mag lo:kBassLo hi:kBassHi];
  float rm = [self rawBand:mag lo:kMidLo hi:kMidHi];
  float rt = [self rawBand:mag lo:kTrebLo hi:kTrebHi];
  float bass = [self normBand:rb floor:kFloorBass minPeak:kMinPeakBass peak:&_peakBass];
  float mid = [self normBand:rm floor:kFloorMid minPeak:kMinPeakMid peak:&_peakMid];
  float treble = [self normBand:rt floor:kFloorTreb minPeak:kMinPeakTreb peak:&_peakTreb];
  float level = (bass + mid + treble) / 3.0f;

  os_unfair_lock_lock(&gBandsLock);
  gBands.bass = smoothBand(gBands.bass, bass);
  gBands.mid = smoothBand(gBands.mid, mid);
  gBands.treble = smoothBand(gBands.treble, treble);
  gBands.level = smoothBand(gBands.level, level);
  os_unfair_lock_unlock(&gBandsLock);

  if (_debug && (++_logTick % 23) == 0) {  // ~ every 0.25s at the hop rate
    fprintf(stderr, "lumen: raw b=%.4f m=%.4f t=%.4f -> bass=%.2f mid=%.2f treble=%.2f\n", rb, rm,
            rt, bass, mid, treble);
  }
}

// mean magnitude over a bin range, normalized by the FFT size (vDSP_fft_zrip is
// unnormalized). normBand below turns this into the 0..1 reaction value.
- (float)rawBand:(const float *)mag lo:(int)lo hi:(int)hi {
  float acc = 0.0f;
  for (int i = lo; i <= hi; i++) {
    acc += sqrtf(mag[i]);
  }
  return (acc / (float)(hi - lo + 1)) / (float)kFftN;
}

// gate out the noise floor, then AGC-normalize against a slow per-band peak so the
// reaction tracks the music's dynamics and adapts to volume rather than saturating.
- (float)normBand:(float)raw floor:(float)floor minPeak:(float)minPeak peak:(float *)peak {
  float g = raw - floor;
  if (g < 0.0f) {
    g = 0.0f;
  }
  float p = *peak * kPeakDecay;
  if (g > p) {
    p = g;
  }
  *peak = p;
  return g / (p > minPeak ? p : minPeak);
}

@end

#pragma mark - rendering

@interface Renderer : NSObject <MTKViewDelegate>
@end

@implementation Renderer

- (void)drawInMTKView:(MTKView *)view {
  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
  if (drawable == nil || pass == nil) {
    return;
  }

  Uniforms u;
  u.resolution[0] = (float)view.drawableSize.width;
  u.resolution[1] = (float)view.drawableSize.height;
  u.time = (float)(CACurrentMediaTime() - gStartTime);
  os_unfair_lock_lock(&gBandsLock);
  u.bass = gBands.bass;
  u.mid = gBands.mid;
  u.treble = gBands.treble;
  u.level = gBands.level;
  os_unfair_lock_unlock(&gBandsLock);

  id<MTLCommandBuffer> cb = [gQueue commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
  [enc setRenderPipelineState:gPipeline];
  [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];
  [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  (void)view;
  (void)size;
}

@end

#pragma mark - windows

// pause a window's render loop when it is occluded (a fullscreen app over the
// desktop), so the GPU goes idle instead of drawing a wallpaper nobody can see
static void updatePauseForWindow(NSWindow *window) {
  MTKView *view = (MTKView *)window.contentView;
  BOOL visible = (window.occlusionState & NSWindowOcclusionStateVisible) != 0;
  view.paused = !visible;
}

@interface WindowObserver : NSObject
@end

@implementation WindowObserver
- (void)occlusionChanged:(NSNotification *)note {
  updatePauseForWindow((NSWindow *)note.object);
}
- (void)screensChanged:(NSNotification *)note {
  (void)note;
  rebuildWindows();
}
@end

static WindowObserver *gObserver;

static NSWindow *makeWallpaperWindow(NSScreen *screen) {
  // build in GLOBAL coordinates: passing screen: makes the contentRect be interpreted
  // relative to that screen's origin, double-counting it on a secondary display (the
  // window lands at 2x the origin, mostly off-panel, only a corner showing). create
  // without screen: against the already-global screen.frame, then pin the frame exactly.
  NSWindow *w = [[NSWindow alloc] initWithContentRect:screen.frame
                                            styleMask:NSWindowStyleMaskBorderless
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
  [w setFrame:screen.frame display:NO];
  w.level = (NSWindowLevel)CGWindowLevelForKey(kCGDesktopWindowLevelKey);
  w.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                         NSWindowCollectionBehaviorStationary |
                         NSWindowCollectionBehaviorIgnoresCycle |
                         NSWindowCollectionBehaviorFullScreenNone;
  w.ignoresMouseEvents = YES;  // clicks fall through to the real desktop
  w.opaque = YES;
  w.backgroundColor = NSColor.blackColor;
  w.releasedWhenClosed = NO;

  // the content view's frame is in the WINDOW's coordinate space (origin 0,0), not the
  // global screen.frame: on a secondary display screen.frame carries a large origin and
  // would shove the view off-window, leaving only a corner visible.
  NSRect bounds = NSMakeRect(0.0, 0.0, screen.frame.size.width, screen.frame.size.height);
  MTKView *v = [[MTKView alloc] initWithFrame:bounds device:gDevice];
  v.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  v.delegate = gRenderer;
  v.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  v.framebufferOnly = YES;
  v.enableSetNeedsDisplay = NO;
  v.paused = NO;
  v.preferredFramesPerSecond = kTargetFps;
  w.contentView = v;

  [[NSNotificationCenter defaultCenter] addObserver:gObserver
                                           selector:@selector(occlusionChanged:)
                                               name:NSWindowDidChangeOcclusionStateNotification
                                             object:w];
  [w orderFrontRegardless];  // never makeKey: a wallpaper must not steal focus
  if (getenv("LUMEN_DEBUG")) {
    NSRect sf = screen.frame;
    NSRect wf = w.frame;
    NSRect vb = v.bounds;
    fprintf(stderr,
            "lumen: screen=(%.0f,%.0f %.0fx%.0f) scale=%.1f -> win=(%.0f,%.0f %.0fx%.0f) "
            "view=%.0fx%.0f drawable=%.0fx%.0f\n",
            sf.origin.x, sf.origin.y, sf.size.width, sf.size.height, screen.backingScaleFactor,
            wf.origin.x, wf.origin.y, wf.size.width, wf.size.height, vb.size.width, vb.size.height,
            v.drawableSize.width, v.drawableSize.height);
  }
  return w;
}

void rebuildWindows(void) {
  for (NSWindow *w in gWindows) {
    [[NSNotificationCenter defaultCenter] removeObserver:gObserver
                                                    name:NSWindowDidChangeOcclusionStateNotification
                                                  object:w];
    [w orderOut:nil];
  }
  [gWindows removeAllObjects];
  for (NSScreen *screen in NSScreen.screens) {
    [gWindows addObject:makeWallpaperWindow(screen)];
  }
}

#pragma mark - setup

// load shader.metal from the store path baked in at build time and build the pipeline
static BOOL buildPipeline(void) {
  // prefer the bundled resource (the .app), fall back to the baked store path
  NSString *path = [[NSBundle mainBundle] pathForResource:@"shader" ofType:@"metal"];
  if (path == nil) {
    path = @LUMEN_SHADER_PATH;
  }
  NSError *err = nil;
  NSString *src = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
  if (src == nil) {
    fprintf(stderr, "lumen: read shader %s: %s\n", path.UTF8String,
            err.localizedDescription.UTF8String);
    return NO;
  }
  id<MTLLibrary> lib = [gDevice newLibraryWithSource:src options:nil error:&err];
  if (lib == nil) {
    fprintf(stderr, "lumen: compile shader: %s\n", err.localizedDescription.UTF8String);
    return NO;
  }

  MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
  desc.vertexFunction = [lib newFunctionWithName:@"vs_main"];
  desc.fragmentFunction = [lib newFunctionWithName:@"fs_main"];
  desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  if (desc.vertexFunction == nil || desc.fragmentFunction == nil) {
    fprintf(stderr, "lumen: shader missing vs_main/fs_main\n");
    return NO;
  }
  gPipeline = [gDevice newRenderPipelineStateWithDescriptor:desc error:&err];
  if (gPipeline == nil) {
    fprintf(stderr, "lumen: pipeline: %s\n", err.localizedDescription.UTF8String);
    return NO;
  }
  return YES;
}

int main(void) {
  @autoreleasepool {
    gDevice = MTLCreateSystemDefaultDevice();
    if (gDevice == nil) {
      fprintf(stderr, "lumen: no Metal device\n");
      return 1;
    }
    gQueue = [gDevice newCommandQueue];
    if (gQueue == nil || !buildPipeline()) {
      return 1;
    }
    gStartTime = CACurrentMediaTime();

    // accessory: a GUI app with windows but no Dock icon or menu bar, launchd-friendly
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

    gRenderer = [[Renderer alloc] init];
    gObserver = [[WindowObserver alloc] init];
    gWindows = [NSMutableArray array];
    [[NSNotificationCenter defaultCenter] addObserver:gObserver
                                             selector:@selector(screensChanged:)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];
    rebuildWindows();

    gAudioTap = [[AudioTap alloc] init];
    if (gAudioTap == nil) {
      return 1;
    }
    [gAudioTap start];

    [app run];
  }
  return 0;
}
