// sets the desktop picture on every screen via NSWorkspace. unlike the
// `osascript -> System Events` route, this needs no Automation TCC (a process
// setting its OWN desktop is unprivileged), so it works headless when run in the
// user's GUI session via `launchctl asuser`.
#import <Cocoa/Cocoa.h>
int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: set-wallpaper <image>\n"); return 2; }
  @autoreleasepool {
    NSURL *u = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    int rc = 0, n = 0;
    for (NSScreen *s in [NSScreen screens]) {
      NSError *err = nil;
      if (![ws setDesktopImageURL:u forScreen:s options:@{} error:&err]) {
        rc = 1; fprintf(stderr, "screen %d: %s\n", n, err.localizedDescription.UTF8String);
      }
      n++;
    }
    fprintf(stderr, "set on %d screen(s), rc=%d\n", n, rc);
    return rc;
  }
}
