//
//  AppexSaverMinimalConfigurationViewController.swift
//  AppexSaverMinimalExtension
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  Configuration sheet displayed when the user clicks "Options" next to the
//  screensaver in System Settings. Specified as
//  ScreenSaverConfigurationSheetViewControllerClass in Info.plist as
//  `$(PRODUCT_MODULE_NAME).AppexSaverMinimalConfigurationViewController`.
//
//  The settings themselves are not here. They are tuned over a live
//  full-screen render in the host app (#21), which is the only process
//  allowed to write the settings domain (ADR 0002) and the only one that can
//  put the saver on screen at full size to judge it. So this sheet has one
//  job: get the user there.
//
//  The sheet stays, rather than SSEHasConfigureSheet being turned off:
//  System Settings is where a user goes to configure a screensaver, and a
//  missing Options button is a dead end.
//

import AppKit

private let logger = AppexLog.logger("Configuration")

@objc(AppexSaverMinimalConfigurationViewController)
class AppexSaverMinimalConfigurationViewController: NSViewController {

    /// The host app's URL scheme. Duplicated from `SaverTuningSurface`
    /// deliberately: the two targets share no file this could live in, and
    /// the extension must not link the host app's code.
    private static let tuningSurfaceURL = URL(string: "appexsaverminimal://settings")!

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        logger.info("init(nibName:bundle:)")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        logger.info("init(coder:)")
        super.init(coder: coder)
    }

    override func loadView() {
        logger.info("loadView()")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 160))

        let label = NSTextField(labelWithString: "AppexSaverMinimal")
        label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let explanation = NSTextField(wrappingLabelWithString:
            "Settings are tuned over a live full-screen preview in the AppexSaverMinimal app.")
        explanation.font = NSFont.systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor
        explanation.alignment = .center
        explanation.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(explanation)

        let button = NSButton(title: "Open Saver Settings\u{2026}",
                              target: self,
                              action: #selector(openTuningSurface(_:)))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),

            explanation.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            explanation.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            explanation.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),

            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        self.view = container
        self.preferredContentSize = NSSize(width: 340, height: 160)
    }

    /// Asks the system to open the host app at its tuning surface, then gets
    /// out of the way — leaving the sheet up over a screensaver that is about
    /// to be covered by a full-screen render would strand it.
    ///
    /// `NSWorkspace.open` needs no entitlement from inside the appex sandbox.
    @objc private func openTuningSurface(_ sender: Any?) {
        let opened = NSWorkspace.shared.open(Self.tuningSurfaceURL)
        logger.notice("opening tuning surface: \(opened ? "ok" : "refused", privacy: .public)")
        dismissSheet(sender)
    }

    @objc private func dismissSheet(_ sender: Any?) {
        if let window = self.view.window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.dismiss(nil)
        }
    }
}
