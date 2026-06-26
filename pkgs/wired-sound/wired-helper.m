// wired-helper: the long-lived half of the "OS talks back" layer. a plain launchd
// agent cannot subscribe to the com.apple.screenIsLocked / screenIsUnlocked
// DISTRIBUTED notifications (they ride NSDistributedNotificationCenter, not a
// launchd path/notification key), so this process holds an observer for the whole
// session. on each UNLOCK it afplays the (low, slightly-wrong) unlock tone, and on each
// USB device insertion it plays a soft "noticed" blip (the machine watches: it sees you
// plug something in). on SIGTERM (logout/shutdown tears the agent down) it logs the
// end-card once. NO TTS: the macOS `say` voice was removed (it read uncanny). it
// deliberately does NOT react to lock: the machine answers your return, not your leaving.
//
// modeled on pkgs/record/recorder.m: an objc source compiled by a nix
// stdenv.mkDerivation, signals routed through a dispatch source because a plain
// signal handler cannot safely touch objc / spawn.
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

// afplay volume for the unlock tone. LOW on purpose: this is a-little-wrong
// presence, not a notification chime. the connection tone (login) is driven from
// the launchd agent, not here.
static NSString *const kAfplayVolume = @"0.30";

// the end-card. the capital E in "nExt" is canon, do not normalize it.
static NSString *const kEndCard = @"Close the World, Open the nExt";

// paths to the sox-baked assets and the system tools, substituted at build time so
// the agent never depends on launchd's minimal PATH.
static NSString *const kUnlockTone = @AFPLAY_UNLOCK_TONE;
static NSString *const kNoticedTone = @AFPLAY_NOTICED_TONE;
static NSString *const kAfplayBin = @AFPLAY_BIN;

// run a tool detached and wait for it, so an unlock that arrives mid-play does not
// pile up a backlog of overlapping afplays. NSTask keeps us off system().
static void runTool(NSString *bin, NSArray<NSString *> *args) {
  @try {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:bin];
    task.arguments = args;
    NSError *err = nil;
    if (![task launchAndReturnError:&err]) {
      fprintf(stderr, "wired-helper: launch %s: %s\n", bin.UTF8String,
              err.localizedDescription.UTF8String);
      return;
    }
    [task waitUntilExit];
  } @catch (NSException *ex) {
    fprintf(stderr, "wired-helper: %s\n", ex.reason.UTF8String);
  }
}

static void playUnlock(void) {
  runTool(kAfplayBin, @[ @"-v", kAfplayVolume, kUnlockTone ]);
}

static void playNoticed(void) {
  runTool(kAfplayBin, @[ @"-v", @"0.28", kNoticedTone ]);
}

// IOKit fires this with an iterator of newly-matched USB devices. it MUST be drained
// (IOIteratorNext to exhaustion) to re-arm the notification. the first call, at
// registration, hands us every ALREADY-connected device; gUsbArmed gates that initial
// drain silent so only genuine insertions afterward make a sound.
static BOOL gUsbArmed = NO;
static void usbAdded(void *refcon, io_iterator_t iter) {
  (void)refcon;
  io_service_t svc;
  BOOL any = NO;
  while ((svc = IOIteratorNext(iter)) != 0) {
    IOObjectRelease(svc);
    any = YES;
  }
  if (gUsbArmed && any) {
    playNoticed();
  }
}

// the end-card: log it, silently. no TTS (the `say` voice was uncanny and removed);
// the line lives in the wallpaper, here it just stamps the session's close to the log.
// guarded so a second SIGTERM (or a teardown race) can't double it.
static void logEndCard(void) {
  static BOOL logged = NO;
  if (logged) {
    return;
  }
  logged = YES;
  fprintf(stdout, "%s\n", kEndCard.UTF8String);
  fflush(stdout);
}

int main(void) {
  @autoreleasepool {
    NSDistributedNotificationCenter *center =
        [NSDistributedNotificationCenter defaultCenter];

    // the unlock signal. screensaver-stop is intentionally NOT observed: only a
    // real unlock (auth cleared) should answer.
    [center addObserverForName:@"com.apple.screenIsUnlocked"
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
                      (void)note;
                      playUnlock();
                    }];

    // USB insertions: the machine notices when you plug something in. add the IOKit
    // notification source to this run loop, then drain the initial (already-connected)
    // set silently so only later insertions sound.
    IONotificationPortRef usbPort = IONotificationPortCreate(kIOMainPortDefault);
    if (usbPort != NULL) {
      CFRunLoopAddSource(CFRunLoopGetCurrent(),
                         IONotificationPortGetRunLoopSource(usbPort), kCFRunLoopDefaultMode);
      io_iterator_t usbIter = 0;
      kern_return_t kr =
          IOServiceAddMatchingNotification(usbPort, kIOFirstMatchNotification,
                                           IOServiceMatching("IOUSBHostDevice"), usbAdded,
                                           NULL, &usbIter);
      if (kr == KERN_SUCCESS) {
        usbAdded(NULL, usbIter); // drain the already-connected devices, silent (gUsbArmed=NO)
        gUsbArmed = YES;
      } else {
        fprintf(stderr, "wired-helper: USB watch unavailable (0x%x)\n", kr);
      }
    }

    // logout/shutdown delivers SIGTERM to the agent. a plain handler can't run
    // NSTask safely, so route through a dispatch source on the main queue (same
    // pattern as record/recorder.m).
    signal(SIGTERM, SIG_IGN);
    dispatch_source_t term = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL, (uintptr_t)SIGTERM, 0,
        dispatch_get_main_queue());
    dispatch_source_set_event_handler(term, ^{
      logEndCard();
      exit(0);
    });
    dispatch_resume(term);
    // intentionally leaked: lives for the whole process, like record/recorder.m
    (void)(__bridge_retained void *)term;

    // CFRunLoop (not dispatch_main): NSDistributedNotificationCenter delivery needs
    // a live run loop on this thread to fire the observer block.
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
