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

/// The extension point's only entry point (confirmed by runtime dump: it is the
/// *sole* method on ScreenSaverExtension). WallpaperAgent delivers its
/// start/stop commands here as NSExtensionItems on the context's
/// -inputItems, which is why -startAnimation is not seen on the view.
/// Overridden by the lifecycle probe for issue #9.
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context;

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
/// Animation: WallpaperAgent sends commands as NSExtensionItems to the
/// ScreenSaverExtension principal class -- measured in issue #9, the item's
/// userInfo carries a "command" key whose values include "startAnimation" and
/// "handshake" (the latter also carrying "isPreview"). -startAnimation IS
/// delivered to this view controller, but its default implementation does not
/// forward to the ScreenSaverView: zero view-level startAnimation calls were
/// seen across five instrumented runs, with SSENeedsAnimationTimer both true
/// and false. Do not gate work on the view's overrides; start from
/// viewDidMoveToWindow.
///
/// There is no teardown signal at all. On dismissal the host cancels the XPC
/// connection and PlugInKit idle-exits the process; -stopAnimation,
/// -invalidate, -viewDidDisappear and -_didDisassociateFromHostWindow were
/// never observed, and Swift deinit does not run.
///
/// Note: -loadViewForFrame:isPreview: and the representedView / animating
/// properties existed on older macOS but are gone from the current framework
/// (verified via runtime dump); only the standard -loadView is called. The
/// preview flag survives that removal only on the `handshake` item's userInfo
/// -- this controller declares nothing about previews, and every isPreview
/// accessor left in the framework (ScreenSaverExtensionManager,
/// ScreenSaverModules, ScreenSaverExtensionModule) is host-side. See
/// HostHandshake.swift, issue #22.
@interface ScreenSaverViewController : NSViewController

- (void)startAnimation;
- (void)stopAnimation;

#pragma mark Lifecycle probe surface (issue #9)

// Declared from the live runtime dump on macOS 26.5; the type encodings are
// transcribed exactly, because a wrong return type or argument here is a
// silent ABI mismatch rather than a compile error.
//
// The first two are ScreenSaverViewController's own (v16@0:8, Q16@0:8,
// B40@0:8{CGSize=dd}16@32). The rest are inherited from the private
// NSServiceViewController superclass and are the ViewBridge-level
// hidden/shown and input signals -- the ones most likely to fire when the
// view-level callbacks do not. They are declared here only so the probe can
// observe them; nothing in the shipping saver should depend on a private
// method without a fallback.

- (void)invalidate;                                              // v16@0:8
- (unsigned long long)awakeFromRemoteView;                       // Q16@0:8
- (BOOL)remoteViewSizeChanged:(NSSize)size transaction:(nullable id)transaction; // B40@0:8{CGSize=dd}16@32

- (void)_didAssociateWithHostWindow;                             // v16@0:8
- (void)_didDisassociateFromHostWindow;                          // v16@0:8
- (void)hostWindowReceivedEventType:(unsigned long long)type;    // v24@0:8Q16
- (void)beginAppearanceTransition:(BOOL)isAppearing;             // v20@0:8B16
- (void)endAppearanceTransition;                                 // v16@0:8

// Read-only state the probe samples once, to explain the callbacks it does or
// does not see (e.g. appearance transitions are only bridged across the remote
// boundary when -_shouldBridgeAppearanceTransitions is YES).
- (BOOL)_shouldBridgeAppearanceTransitions;                      // B16@0:8
- (BOOL)isValid;                                                 // B16@0:8
- (BOOL)allowsSnapshot;                                          // B16@0:8
- (BOOL)canBecomeKey;                                            // B16@0:8
- (NSSize)remoteViewSize;                                        // {CGSize=dd}16@0:8
- (unsigned int)hostSDKVersion;                                  // I16@0:8

@end

#pragma mark - ScreenSaverConfigurationViewController

/// View controller for the screensaver configuration sheet.
/// Subclass this if SSEHasConfigureSheet is true in Info.plist.
@interface ScreenSaverConfigurationViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
