//
//  SettingsWindow.swift
//  Ice
//

import SwiftUI

struct SettingsWindow: Scene {
    @ObservedObject var appState: AppState
    @State private var titlebarHeight: CGFloat = 0

    var body: some Scene {
        Window(Constants.settingsWindowTitle, id: Constants.settingsWindowID) {
            SettingsView()
                .environment(\.settingsTitlebarHeight, titlebarHeight)
                .background(SettingsWindowChrome(height: $titlebarHeight).allowsHitTesting(false))
                .modifier(AppLanguageModifier(manager: appState.settingsManager.generalSettingsManager))
                .readWindow { window in
                    guard let window else {
                        return
                    }
                    appState.assignSettingsWindow(window)
                }
                .frame(minWidth: 825, minHeight: 560)
        }
        .commandsRemoved()
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)
        .environmentObject(appState)
        .environmentObject(appState.navigationState)
    }
}
