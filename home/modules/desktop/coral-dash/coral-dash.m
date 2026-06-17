// CoralDash screensaver: a ScreenSaverView that hosts a WKWebView pointed at a
// loopback server (http://127.0.0.1:PORT). loopback (not file://) keeps the
// legacyScreenSaver sandbox happy and lets the page fetch data.json same-origin.
// the WebGL shader animates itself via requestAnimationFrame inside the page, so
// animateOneFrame is a no-op.
#import <ScreenSaver/ScreenSaver.h>
#import <WebKit/WebKit.h>

@interface CoralDashView : ScreenSaverView
@property (strong) WKWebView *web;
@end

@implementation CoralDashView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  self = [super initWithFrame:frame isPreview:isPreview];
  if (self) {
    self.animationTimeInterval = 1.0 / 30.0;
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    self.web = [[WKWebView alloc] initWithFrame:self.bounds configuration:cfg];
    self.web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.web.wantsLayer = YES;
    self.web.layer.backgroundColor =
        [[NSColor colorWithSRGBRed:0.094 green:0.094 blue:0.137 alpha:1.0] CGColor];
    [self addSubview:self.web];
    [self load];
  }
  return self;
}

- (void)load {
  NSURL *u = [NSURL URLWithString:@"http://127.0.0.1:8765/"];
  [self.web loadRequest:[NSURLRequest requestWithURL:u]];
}

// reload when the saver (re)starts so a fresh lock always shows current data.
- (void)startAnimation { [super startAnimation]; [self load]; }
- (void)stopAnimation  { [super stopAnimation]; }
- (void)animateOneFrame { /* the page drives its own animation */ }
- (BOOL)hasConfigureSheet { return NO; }
- (NSWindow *)configureSheet { return nil; }

@end
