//
//  AppexSaverMinimalApp.swift
//  AppexSaverMinimal
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  Host application for the screensaver extension. The host app exists so the
//  .appex can be bundled and registered with pluginkit; macOS does not load
//  appex bundles that aren't embedded inside an application.
//

import SwiftUI

@main
struct AppexSaverMinimalApp: App {
    init() {
        // `--render-panel PATH` renders the settings panel to a PNG and quits,
        // so its layout can be checked without the tuning surface taking
        // every screen. See SaverTuningSurface.renderPanelIfAsked.
        #if canImport(SwiftTerm)
        if SaverTuningSurface.renderPanelIfAsked() { exit(0) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
