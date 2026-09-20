//
//  ContentView.swift
//  AppexSaverMinimal
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  The host app's main window: registers the extension, activates it as the
//  screensaver, and opens the tuning surface.
//
//  The look is the one #32 settled by eye: a grouped form in three sections —
//  Extension, Screensaver, Look — each with a status row and its buttons, and
//  nothing else. No icon, no large title, no version, no path, and no status
//  caption at the foot: the dots say what it said, and the red line in a
//  section carries a failure. Exactly one button per section is prominent,
//  and it is the next thing to do.
//

import SwiftUI

private let logger = AppexLog.logger("HostApp")

struct ContentView: View {
    @StateObject private var pluginManager = PluginManager()
    @State private var hijackedSettingsDomain: URL?

    /// The window's width (#32: 520 pt). A grouped form is a list and has no
    /// height of its own, so the height is computed from what is showing.
    static let width: CGFloat = 520

    var body: some View {
        Form {
            extensionSection
            screensaverSection
            lookSection
            settingsDomainWarning
        }
        .formStyle(.grouped)
        .frame(width: Self.width, height: height)
        .onAppear(perform: checkSettingsDomain)
        // How the Options sheet in System Settings reaches the tuning
        // surface: the sheet is sandboxed and can only ask the system to open
        // a URL, so the app registers a scheme and turns it into a show().
        // Opening the app's main window instead would be a dead end with a
        // step in it; always launching into the surface would be worse, since
        // this window is also how the extension is installed and activated.
        .onOpenURL { url in
            guard url.scheme == SaverTuningSurface.urlScheme else { return }
            SaverTuningSurface.shared.show()
        }
    }

    // MARK: - Sections

    private var extensionSection: some View {
        Section("Extension") {
            LabeledContent("Status") {
                status(on: pluginManager.isInstalled,
                       pluginManager.isInstalled ? "Registered" : "Not registered")
            }
            if let error = pluginManager.lastError {
                failure(error)
            }
            HStack {
                Spacer()
                refresh(busy: pluginManager.isLoading) { pluginManager.checkInstallationStatus() }
                if pluginManager.isInstalled {
                    Button("Uninstall", action: uninstallExtension)
                        .buttonStyle(.bordered)
                } else {
                    Button("Install", action: installExtension)
                        .buttonStyle(.borderedProminent)
                }
            }
            .disabled(pluginManager.isLoading)
        }
    }

    private var screensaverSection: some View {
        Section("Screensaver") {
            LabeledContent("Status") {
                status(on: pluginManager.isActiveScreensaver,
                       pluginManager.isActiveScreensaver ? "Active on every display" : "Not active")
            }
            if let error = pluginManager.screensaverError {
                failure(error)
            }
            HStack {
                Spacer()
                refresh(busy: pluginManager.isCheckingScreensaver) { pluginManager.checkScreensaverStatus() }
                // Plain until the extension is registered: a prominent button
                // under a step not yet taken read as the thing to press.
                setAsScreensaver
                    .disabled(!pluginManager.isInstalled || pluginManager.isActiveScreensaver)
            }
            .disabled(pluginManager.isCheckingScreensaver)
            LabeledContent("System Settings") {
                Button("Open Screen Saver Settings", action: openScreenSaverSettings)
            }
        }
    }

    @ViewBuilder
    private var setAsScreensaver: some View {
        let button = Button("Set as Screensaver") {
            Task { await pluginManager.enableAsScreensaver() }
        }
        if pluginManager.isInstalled {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var lookSection: some View {
        Section("Look") {
            LabeledContent {
                Button("Tune…") { SaverTuningSurface.shared.show() }
                    .buttonStyle(.borderedProminent)
                    .help("Tune the saver over a live full-screen render")
            } label: {
                Text("Braille, dot size, frame rate")
                Text("Over a live full-screen render")
            }
        }
    }

    // MARK: - Rows

    private func status(on: Bool, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(on ? Color.green : Color.gray)
                .frame(width: 9, height: 9)
            Text(text)
        }
    }

    private func failure(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.red)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func refresh(busy: Bool, action: @escaping () -> Void) -> some View {
        if busy {
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 8)
        } else {
            Button("Refresh", action: action)
        }
    }

    /// The alarm for the one failure that is invisible everywhere else.
    ///
    /// cfprefsd routes a defaults domain into a container the moment that
    /// container holds a plist for it — for every writer, sandboxed or not.
    /// A plist left behind by an earlier sandboxed build of this app sends
    /// this app's writes into the container while the extension's reads go
    /// to ~/Library/Preferences, and the two never meet. Nothing errors;
    /// the settings simply never apply. It doubles as the alarm if anyone
    /// ever puts this target back in a sandbox, which ADR 0002 forbids.
    @ViewBuilder
    private var settingsDomainWarning: some View {
        if let plist = hijackedSettingsDomain {
            Section {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saver settings will not apply")
                            .fontWeight(.medium)
                        Text("A container holds a preferences file for this app's settings domain, so this app writes there while the screensaver reads ~/Library/Preferences. Delete it and relaunch.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(plist.path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.35)))
                .listRowInsets(EdgeInsets())
            }
        }
    }

    // MARK: - Height

    /// What the form needs, row by row. Measured on the built window; the
    /// rows a grouped form draws are fixed-height, so this is exact for the
    /// steady state and generous for the lines that can wrap.
    private var height: CGFloat {
        var h: CGFloat = 418
        if pluginManager.lastError != nil { h += 44 }
        if pluginManager.screensaverError != nil { h += 44 }
        if hijackedSettingsDomain != nil { h += 150 }
        return h
    }

    // MARK: - Actions

    private func checkSettingsDomain() {
        #if canImport(SwiftTerm)
        hijackedSettingsDomain = SaverSettingsStore.hijackingContainerPlistURL
        if let plist = hijackedSettingsDomain {
            logger.error("settings domain routed into a container: \(plist.path, privacy: .public)")
        }
        #endif
    }

    private func installExtension() {
        do {
            try pluginManager.install()
        } catch {
            logger.error("Install failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func uninstallExtension() {
        do {
            try pluginManager.uninstall()
        } catch {
            logger.error("Uninstall failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func openScreenSaverSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
