//
//  IceApp.swift
//  Ice
//

import SwiftUI

@main
struct IceApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @ObservedObject var appState: AppState

    init() {
        #if SWIFT_PACKAGE
        if let index = CommandLine.arguments.firstIndex(of: "--validate-wallpaper-blur"),
           CommandLine.arguments.indices.contains(index + 1) {
            exit(LocalBuildValidation.validateWallpaperBlur(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])))
        }
        if let index = CommandLine.arguments.firstIndex(of: "--validate-appearance"),
           CommandLine.arguments.indices.contains(index + 1) {
            exit(LocalBuildValidation.renderAppearance(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])))
        }
        if CommandLine.arguments.contains("--validate-build") {
            exit(LocalBuildValidation.run())
        }
        #endif
        appState = AppState()
        NSSplitViewItem.swizzle()
        MigrationManager.migrateAll(appState: appState)
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        SettingsWindow(appState: appState)
        PermissionsWindow(appState: appState)
    }
}
