#import "../routing-probe/ProbeView.h"
#import "Calibration.h"
#import <os/log.h>
#include <unistd.h>
@implementation RoutingProbeView
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    self=[super initWithFrame:frame isPreview:preview];
    if(self) self.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    return self;
}
- (BOOL)isOpaque { return YES; }
- (void)setFrameSize:(NSSize)size { [super setFrameSize:size]; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirty {
    os_log(OS_LOG_DEFAULT,"GEOMETRY-PROBE pid=%d preview=%d bounds=%{public}@ backing=%g",getpid(),self.isPreview,NSStringFromRect(self.bounds),self.window.backingScaleFactor);
    DrawCalibration(self.bounds,self.isPreview);
}
@end
