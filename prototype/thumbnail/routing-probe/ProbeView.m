#import "ProbeView.h"
#import <os/log.h>
#include <unistd.h>
#ifndef PROBE_KIND
#define PROBE_KIND @"LEGACY"
#endif
static os_log_t ProbeLog(void) {
    static os_log_t log;
    if (!log) log = os_log_create("local.oozel.routing-probe", "routing");
    return log;
}
@implementation RoutingProbeView {
    NSTimer *_pulse;
    NSUInteger _ticks;
    BOOL _loggedDraw;
}
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    self = [super initWithFrame:frame isPreview:preview];
    if (self) {
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.animationTimeInterval = 1;
        os_log(ProbeLog(), "PROBE init kind=%{public}@ preview=%d pid=%d frame=%{public}@", PROBE_KIND, preview, getpid(), NSStringFromRect(frame));
        __weak RoutingProbeView *weakSelf = self;
        _pulse = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
            RoutingProbeView *view = weakSelf;
            if (!view) { [timer invalidate]; return; }
            view->_ticks++;
            view.needsDisplay = YES;
        }];
    }
    return self;
}
- (void)dealloc { [_pulse invalidate]; }
- (BOOL)isOpaque { return YES; }
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    os_log(ProbeLog(), "PROBE window kind=%{public}@ preview=%d pid=%d frame=%{public}@ window=%{public}@", PROBE_KIND, self.isPreview, getpid(), NSStringFromRect(self.frame), NSStringFromRect(self.window.frame));
}
- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    self.needsDisplay = YES;
    os_log(ProbeLog(), "PROBE resize kind=%{public}@ preview=%d pid=%d size=%{public}@", PROBE_KIND, self.isPreview, getpid(), NSStringFromSize(size));
}
- (void)animateOneFrame { self.needsDisplay = YES; }
- (void)drawRect:(NSRect)dirty {
    if (!_loggedDraw) {
        _loggedDraw = YES;
        os_log(ProbeLog(), "PROBE draw kind=%{public}@ preview=%d pid=%d bounds=%{public}@", PROBE_KIND, self.isPreview, getpid(), NSStringFromRect(self.bounds));
    }
    NSRect b = self.bounds;
    [(self.isPreview ? [NSColor colorWithSRGBRed:0.02 green:0.28 blue:0.9 alpha:1] : [NSColor colorWithSRGBRed:0.85 green:0.23 blue:0.02 alpha:1]) setFill];
    NSRectFill(b);
    if (b.size.width <= 0 || b.size.height <= 0) return;
    CGFloat unit = MIN(b.size.width / 16, b.size.height / 9);
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(b, unit * .3, unit * .3)];
    border.lineWidth = unit * .08;
    [[NSColor whiteColor] setStroke];
    [border stroke];
    NSMutableParagraphStyle *center = [NSMutableParagraphStyle new];
    center.alignment = NSTextAlignmentCenter;
    NSDictionary *small = @{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:unit * .55 weight:NSFontWeightBold], NSForegroundColorAttributeName:NSColor.whiteColor, NSParagraphStyleAttributeName:center};
    NSDictionary *large = @{NSFontAttributeName:[NSFont systemFontOfSize:unit * 4 weight:NSFontWeightBlack], NSForegroundColorAttributeName:NSColor.whiteColor, NSParagraphStyleAttributeName:center};
    NSString *kind = [NSString stringWithFormat:@"%@  %@", PROBE_KIND, self.isPreview ? @"PREVIEW" : @"FULL"];
    [kind drawInRect:NSMakeRect(0, b.size.height * .77, b.size.width, unit) withAttributes:small];
    [(self.isPreview ? @"P" : @"F") drawInRect:NSMakeRect(0, b.size.height * .24, b.size.width, unit * 5) withAttributes:large];
    NSString *details = [NSString stringWithFormat:@"%.0fx%.0f  PID %d  %lus", b.size.width, b.size.height, getpid(), (unsigned long)_ticks];
    [details drawInRect:NSMakeRect(0, b.size.height * .1, b.size.width, unit) withAttributes:small];
}
@end
