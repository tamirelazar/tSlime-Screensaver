//
//  ScreenSaverPrivate.h
//  AppexSaverExtension
//
//  Private API declarations for macOS screensaver extensions.
//  These classes exist in ScreenSaver.framework but are not publicly declared.
//  Discovered via reverse engineering Apple's screensaver appex bundles.
//

#import <ScreenSaver/ScreenSaver.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ScreenSaverExtension

/// Principal class for modern screensaver app extensions.
/// Subclass this and specify it as NSExtensionPrincipalClass in Info.plist.
@interface ScreenSaverExtension : NSObject

- (instancetype)init;

@end

#pragma mark - ScreenSaverViewController

/// Main view controller for screensaver animation.
/// Specify your subclass name as ScreenSaverViewControllerClass in Info.plist.
///
/// Sizing: the superclass is NSServiceViewController (ViewBridge); after the
/// view is attached to the remote window, the host can resize it via
/// -remoteViewSizeChanged:transaction: (calls setFrame: on the view). Apple's
/// own savers (e.g. Arabesque) create their view with NSZeroRect in loadView
/// and rely on this. In practice (observed on macOS 26) WallpaperAgent hosts
/// the saver at the screen's point size and no later resize arrives.
///
/// Animation: WallpaperAgent sends startAnimation/stopAnimation as
/// NSExtensionItem commands to the ScreenSaverExtension principal class, but
/// delivery of -startAnimation to the ScreenSaverView was NOT observed in
/// live runs — do not gate work on it; start from viewDidMoveToWindow.
///
/// Note: -loadViewForFrame:isPreview: and the representedView / animating
/// properties existed on older macOS but are gone from the current framework
/// (verified via runtime dump); only the standard -loadView is called.
@interface ScreenSaverViewController : NSViewController

- (void)startAnimation;
- (void)stopAnimation;

@end

#pragma mark - ScreenSaverConfigurationViewController

/// View controller for the screensaver configuration sheet.
/// Subclass this if SSEHasConfigureSheet is true in Info.plist.
@interface ScreenSaverConfigurationViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
