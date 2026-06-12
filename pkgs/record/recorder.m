// record-helper: full-display screen + system-audio recorder over ScreenCaptureKit.
// capturesAudio taps the system mix only; the mic is never opened (captureMicrophone
// stays NO). SIGINT/SIGTERM trigger a clean stop so the .mov is always finalized.
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

static const int64_t kFinalizeTimeoutSec = 10;
static const int kFramesPerSecond = 60;
static const NSInteger kAudioSampleRate = 48000;
static const NSInteger kAudioChannels = 2;

// kept in globals so ARC holds them for the lifetime of dispatch_main()
static SCStream *gStream;
static SCRecordingOutput *gOutput;
static id gRecorder;

// after a stop is underway, the only valid exits are didFinishRecording or this timeout
static void scheduleFinalizeTimeout(void) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kFinalizeTimeoutSec * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
                   fprintf(stderr, "record-helper: finalize timed out, file may be unusable\n");
                   exit(1);
                 });
}

static void requestStop(void) {
  static BOOL stopping = NO;
  if (stopping) {
    return;
  }
  stopping = YES;
  if (gStream == nil) {
    exit(130);
  }
  [gStream stopCaptureWithCompletionHandler:^(NSError *error) {
    if (error != nil) {
      fprintf(stderr, "record-helper: stop: %s\n", error.localizedDescription.UTF8String);
    }
  }];
  scheduleFinalizeTimeout();
}

@interface Recorder : NSObject <SCStreamDelegate, SCRecordingOutputDelegate>
@end

@implementation Recorder
- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
  // external stop (control-center button, display teardown): wait for the file
  (void)stream;
  fprintf(stderr, "record-helper: stream stopped: %s\n",
          error.localizedDescription.UTF8String);
  scheduleFinalizeTimeout();
}

- (void)recordingOutput:(SCRecordingOutput *)output didFailWithError:(NSError *)error {
  (void)output;
  fprintf(stderr, "record-helper: recording failed: %s\n",
          error.localizedDescription.UTF8String);
  exit(1);
}

- (void)recordingOutputDidFinishRecording:(SCRecordingOutput *)output {
  (void)output;
  exit(0);
}
@end

static void beginCapture(NSURL *url) {
  [SCShareableContent getShareableContentWithCompletionHandler:^(
                          SCShareableContent *content, NSError *error) {
    if (error != nil) {
      fprintf(stderr,
              "record-helper: shareable content: %s (missing screen recording permission?)\n",
              error.localizedDescription.UTF8String);
      exit(1);
    }

    // primary display (origin 0,0); good default for a single-keybind recorder
    SCDisplay *display = content.displays.firstObject;
    CGDirectDisplayID mainID = CGMainDisplayID();
    for (SCDisplay *candidate in content.displays) {
      if (candidate.displayID == mainID) {
        display = candidate;
        break;
      }
    }
    if (display == nil) {
      fprintf(stderr, "record-helper: no display found\n");
      exit(1);
    }

    SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display
                                                      excludingWindows:@[]];
    SCStreamConfiguration *cfg = [[SCStreamConfiguration alloc] init];
    CGFloat scale = filter.pointPixelScale;
    cfg.width = (size_t)(filter.contentRect.size.width * scale);
    cfg.height = (size_t)(filter.contentRect.size.height * scale);
    cfg.minimumFrameInterval = CMTimeMake(1, kFramesPerSecond);
    cfg.showsCursor = YES;
    cfg.capturesAudio = YES;
    cfg.sampleRate = kAudioSampleRate;
    cfg.channelCount = kAudioChannels;

    SCRecordingOutputConfiguration *recCfg = [[SCRecordingOutputConfiguration alloc] init];
    recCfg.outputURL = url;
    recCfg.outputFileType = AVFileTypeQuickTimeMovie;
    // h264 over hevc: plays everywhere the recording gets shared
    recCfg.videoCodecType = AVVideoCodecTypeH264;

    Recorder *recorder = [[Recorder alloc] init];
    gRecorder = recorder;
    gOutput = [[SCRecordingOutput alloc] initWithConfiguration:recCfg delegate:recorder];
    gStream = [[SCStream alloc] initWithFilter:filter configuration:cfg delegate:recorder];

    NSError *addError = nil;
    if (![gStream addRecordingOutput:gOutput error:&addError]) {
      fprintf(stderr, "record-helper: add output: %s\n",
              addError.localizedDescription.UTF8String);
      exit(1);
    }
    [gStream startCaptureWithCompletionHandler:^(NSError *startError) {
      if (startError != nil) {
        fprintf(stderr, "record-helper: start: %s\n",
                startError.localizedDescription.UTF8String);
        exit(1);
      }
      fprintf(stderr, "record-helper: recording\n");
    }];
  }];
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: record-helper <output.mov>\n");
    return 2;
  }
  NSURL *url = [NSURL fileURLWithPath:@(argv[1])];

  // plain signal handlers can't safely touch objc; route through dispatch sources
  signal(SIGINT, SIG_IGN);
  signal(SIGTERM, SIG_IGN);
  int signals[] = {SIGINT, SIGTERM};
  for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,
                                                   (uintptr_t)signals[i], 0,
                                                   dispatch_get_main_queue());
    dispatch_source_set_event_handler(src, ^{ requestStop(); });
    dispatch_resume(src);
    // intentionally leaked: lives for the whole process
    (void)(__bridge_retained void *)src;
  }

  beginCapture(url);
  dispatch_main();
}
