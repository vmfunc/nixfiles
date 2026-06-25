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
static const int kFftLog2 = 10;               // 1024-point FFT
static const int kFftN = 1 << kFftLog2;
static const float kBinHz = (float)kAudioSampleRate / (float)kFftN;  // ~46.9 Hz/bin

// band edges in bins (skip DC at bin 0). feel-tuned, not psychoacoustically exact.
static const int kBassLo = 1, kBassHi = 4;     // ~47..187 Hz
static const int kMidLo = 5, kMidHi = 42;      // ~234..1968 Hz
static const int kTrebLo = 43, kTrebHi = 255;  // ~2..12 kHz

// per-band gains for the soft-clip knee, and the beat attack/decay. magnitudes out
// of vDSP are unnormalized, so these are empirical: enough to map typical music into
// [0,1) without pinning. decay < 1 gives fast attack, slow release => a beat "punch".
static const float kBassGain = 90.0f, kMidGain = 140.0f, kTrebGain = 220.0f;
static const float kBandDecay = 0.90f;

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
  float _ring[kFftN];     // last kFftN mono samples
  int _ringFill;          // how many valid samples (caps at kFftN)
  float _realp[kFftN / 2];
  float _imagp[kFftN / 2];
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
  }
  return self;
}

- (void)start {
  [SCShareableContent
      getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
        if (error != nil || content.displays.firstObject == nil) {
          // almost always the missing screen-recording grant; the field keeps drifting
          fprintf(stderr, "lumen: audio tap unavailable (%s); retrying in 5s\n",
                  error.localizedDescription.UTF8String ?: "no display");
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                         dispatch_get_main_queue(), ^{ [self start]; });
          return;
        }
        [self beginWithDisplay:content.displays.firstObject];
      }];
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
    fprintf(stderr, "lumen: addStreamOutput: %s\n", addErr.localizedDescription.UTF8String);
    return;
  }
  [_stream startCaptureWithCompletionHandler:^(NSError *startErr) {
    if (startErr != nil) {
      fprintf(stderr, "lumen: startCapture: %s; retrying in 5s\n",
              startErr.localizedDescription.UTF8String);
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                     dispatch_get_main_queue(), ^{ [self start]; });
      return;
    }
    fprintf(stderr, "lumen: audio tap live\n");
  }];
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
  (void)stream;
  fprintf(stderr, "lumen: audio stream stopped: %s; retrying in 5s\n",
          error.localizedDescription.UTF8String);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(),
                 ^{ [self start]; });
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
    // shift-in: cheap because callbacks deliver far fewer than kFftN frames each
    memmove(_ring, _ring + 1, (kFftN - 1) * sizeof(float));
    _ring[kFftN - 1] = mono;
    if (_ringFill < kFftN) {
      _ringFill++;
    }
  }
  if (_ringFill >= kFftN) {
    [self analyze];
  }
}

- (void)analyze {
  float windowed[kFftN];
  vDSP_vmul(_ring, 1, _window, 1, windowed, 1, kFftN);

  DSPSplitComplex split = {.realp = _realp, .imagp = _imagp};
  vDSP_ctoz((const DSPComplex *)windowed, 2, &split, 1, kFftN / 2);
  vDSP_fft_zrip(_fft, &split, 1, kFftLog2, kFFTDirection_Forward);

  // squared magnitudes; bin 0 holds DC (realp) and Nyquist (imagp), we skip both
  float mag[kFftN / 2];
  vDSP_zvmags(&split, 1, mag, 1, kFftN / 2);

  float bass = [self bandAmp:mag lo:kBassLo hi:kBassHi gain:kBassGain];
  float mid = [self bandAmp:mag lo:kMidLo hi:kMidHi gain:kMidGain];
  float treble = [self bandAmp:mag lo:kTrebLo hi:kTrebHi gain:kTrebGain];
  float level = (bass + mid + treble) / 3.0f;

  os_unfair_lock_lock(&gBandsLock);
  // fast attack (take the louder), slow release (decay the old) for a beat punch
  gBands.bass = fmaxf(bass, gBands.bass * kBandDecay);
  gBands.mid = fmaxf(mid, gBands.mid * kBandDecay);
  gBands.treble = fmaxf(treble, gBands.treble * kBandDecay);
  gBands.level = fmaxf(level, gBands.level * kBandDecay);
  os_unfair_lock_unlock(&gBandsLock);
}

// mean amplitude over a bin range, soft-clipped through a 1-exp knee into [0,1)
- (float)bandAmp:(const float *)mag lo:(int)lo hi:(int)hi gain:(float)gain {
  float acc = 0.0f;
  for (int i = lo; i <= hi; i++) {
    acc += sqrtf(mag[i]);
  }
  float amp = acc / (float)(hi - lo + 1);
  return 1.0f - expf(-amp * gain);
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
  NSWindow *w = [[NSWindow alloc] initWithContentRect:screen.frame
                                            styleMask:NSWindowStyleMaskBorderless
                                              backing:NSBackingStoreBuffered
                                                defer:NO
                                               screen:screen];
  w.level = (NSWindowLevel)CGWindowLevelForKey(kCGDesktopWindowLevelKey);
  w.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                         NSWindowCollectionBehaviorStationary |
                         NSWindowCollectionBehaviorIgnoresCycle |
                         NSWindowCollectionBehaviorFullScreenNone;
  w.ignoresMouseEvents = YES;  // clicks fall through to the real desktop
  w.opaque = YES;
  w.backgroundColor = NSColor.blackColor;
  w.releasedWhenClosed = NO;

  MTKView *v = [[MTKView alloc] initWithFrame:screen.frame device:gDevice];
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
  NSString *path = @LUMEN_SHADER_PATH;
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
