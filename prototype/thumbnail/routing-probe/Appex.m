#import "ProbeView.h"
#import <os/log.h>
// The same private superclass declarations used by the product.
@interface ScreenSaverExtension : NSObject
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context;
@end
@interface ScreenSaverViewController : NSViewController
@end
static BOOL declaredPreview = NO;
@interface RoutingProbeExtension : ScreenSaverExtension
@end
@implementation RoutingProbeExtension
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    for (NSExtensionItem *item in context.inputItems) {
        NSNumber *flag = item.userInfo[@"isPreview"];
        if (flag) declaredPreview = flag.boolValue;
        os_log(OS_LOG_DEFAULT, "ROUTING-PROBE request command=%{public}@ preview=%{public}@", item.userInfo[@"command"], flag);
    }
    [super beginRequestWithExtensionContext:context];
}
@end
@interface RoutingProbeController : ScreenSaverViewController
@end
@implementation RoutingProbeController
- (void)loadView {
#ifdef ZERO_FRAME
    NSRect frame = NSZeroRect;
#else
    NSRect frame = NSScreen.mainScreen.frame;
#endif
    self.view = [[RoutingProbeView alloc] initWithFrame:frame isPreview:declaredPreview];
}
@end
