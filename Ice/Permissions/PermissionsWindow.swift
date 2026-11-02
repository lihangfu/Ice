//
//  PermissionsWindow.swift
//  Ice
//

import SwiftUI

struct PermissionsWindow: Scene {
    @ObservedObject var appState: AppState

    var body: some Scene {
        Window(LocalizedStringKey(Constants.permissionsWindowTitle), id: Constants.permissionsWindowID) {
            PermissionsView()
                .modifier(AppLanguageModifier(manager: appState.settingsManager.generalSettingsManager))
                .readWindow { window in
                    guard let window else {
                        return
                    }
                    appState.assignPermissionsWindow(window)
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .environmentObject(appState.permissionsManager)
    }
}
