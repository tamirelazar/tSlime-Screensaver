#import "../routing-probe/ProbeView.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>
#include <unistd.h>

// Control for Aerial 4.0's NSView + AVPlayerLayer rendering path.
// Both host-declared instances play the same card; this tests geometry,
// not which instance supplies the selected-saver image.
@interface RoutingProbeView ()
@property AVQueuePlayer *player;
@property AVPlayerLooper *looper;
@property AVPlayerLayer *videoLayer;
@end

@implementation RoutingProbeView
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    self = [super initWithFrame:frame isPreview:preview];
    if (self) {
        self.wantsLayer = YES;
        NSURL *url = [[NSBundle bundleForClass:self.class] URLForResource:@"calibration" withExtension:@"mov"];
        self.player = [AVQueuePlayer queuePlayerWithItems:@[]];
        self.looper = [AVPlayerLooper playerLooperWithPlayer:self.player templateItem:[AVPlayerItem playerItemWithURL:url]];
        self.videoLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        self.videoLayer.backgroundColor = NSColor.blackColor.CGColor;
        self.videoLayer.frame = self.bounds;
        [self.layer addSublayer:self.videoLayer];
    }
    return self;
}
- (CALayer *)makeBackingLayer {
    CALayer *layer = [CALayer layer];
    layer.backgroundColor = NSColor.blackColor.CGColor;
    layer.opaque = YES;
    return layer;
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) [self.player play]; else [self.player pause];
    os_log(OS_LOG_DEFAULT, "AV-GEOMETRY pid=%d preview=%d bounds=%{public}@ backing=%g gravity=%{public}@", getpid(), self.isPreview, NSStringFromRect(self.bounds), self.window.backingScaleFactor, self.videoLayer.videoGravity);
}
- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.videoLayer.frame = self.bounds;
    [CATransaction commit];
    os_log(OS_LOG_DEFAULT, "AV-GEOMETRY layout pid=%d preview=%d bounds=%{public}@ videoFrame=%{public}@", getpid(), self.isPreview, NSStringFromRect(self.bounds), NSStringFromRect(self.videoLayer.frame));
}
@end
