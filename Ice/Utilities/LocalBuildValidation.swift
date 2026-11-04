//
//  LocalBuildValidation.swift
//  Ice
//

#if SWIFT_PACKAGE
import SwiftUI

/// Exercises the packaged executable before migrations, permissions, or event monitors start.
enum LocalBuildValidation {
    private struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw Failure(description: message)
        }
    }

    @MainActor
    static func run() -> Int32 {
        do {
            try validateAppearanceConfiguration()
            let bundle = Bundle.main
            try require(bundle.bundleURL.pathExtension == "app", "Run the packaged Ice.app, not the raw SwiftPM executable.")
            try require(Constants.isLocalBuild, "Local build metadata is missing.")
            for key in ["CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "NSHumanReadableCopyright"] {
                try require(!(bundle.object(forInfoDictionaryKey: key) as? String ?? "").isEmpty, "Missing metadata: \(key)")
            }
            let packagedResources = bundle.url(forResource: "Ice_Ice", withExtension: "bundle")
            try require(packagedResources != nil, "Packaged SwiftPM resources are missing.")
            try require(IceAssets.resourceBundle.bundleURL == packagedResources, "Resources escaped the app bundle.")
            for name in ["IceCubeStroke", "IceCubeFill", "DotStroke", "DotFill", "EllipsisStroke", "EllipsisFill", "Warning"] {
                guard let image = IceAssets.image(named: name) else {
                    throw Failure(description: "Missing image: \(name)")
                }
                try require(image.size.width > 0 && image.size.height > 0, "Empty image: \(name)")
                try require(image.isTemplate == (name != "Warning"), "Incorrect template rendering: \(name)")
            }
            try require(IceAssets.image(named: "IceCubeStroke")?.size == NSSize(width: 20, height: 20), "Retina image scale was lost.")
            for (appearanceName, expectedAlpha) in [(NSAppearance.Name.aqua, 0.17), (.darkAqua, 0.07)] {
                guard let appearance = NSAppearance(named: appearanceName) else {
                    throw Failure(description: "Cannot load system appearance.")
                }
                var alpha: CGFloat = 0
                appearance.performAsCurrentDrawingAppearance {
                    alpha = NSColor(IceAssets.defaultLayoutBarColor).usingColorSpace(.deviceRGB)?.alphaComponent ?? 0
                }
                try require(abs(alpha - expectedAlpha) < 0.001, "Layout bar color does not follow system appearance.")
            }
            try require(AppLanguage.simplifiedChinese.localizedString("General", bundle: bundle) == "通用", "Chinese localization is missing.")
            try require(AppLanguage.english.localizedString("General", bundle: bundle) == "General", "English localization is missing.")
            try require(bundle.url(forResource: "Acknowledgements", withExtension: "pdf") != nil, "Acknowledgements are missing.")
            try require(bundle.url(forResource: "AppIcon", withExtension: "icns") != nil, "App icon is missing.")
            print("PASS: packaged Ice, metadata, relocatable resources, 7 images, Retina scale, light/dark colors, English/Chinese, acknowledgements and app icon")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Build validation failed: \(error)\n".utf8))
            return 1
        }
    }

    @MainActor
    private static func validateAppearanceConfiguration() throws {
        _ = NSApplication.shared
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        func decode(_ json: String) throws -> MenuBarAppearanceConfigurationV2 {
            try decoder.decode(MenuBarAppearanceConfigurationV2.self, from: Data(json.utf8))
        }
        let originalAppearance = NSApp.appearance
        defer { NSApp.appearance = originalAppearance }
        let legacy = """
        {"isDynamic":true,"lightModeConfiguration":{"hasShadow":true},"darkModeConfiguration":{"hasBorder":true}}
        """
        let legacyData = Data(legacy.utf8)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            NSApp.appearance = NSAppearance(named: name)
            let migrated = try decoder.decode(MenuBarAppearanceConfigurationV2.self, from: legacyData)
            try require(migrated.current.hasShadow == (name == .aqua), "Active legacy shadow was not preserved.")
            try require(migrated.current.hasBorder == (name == .darkAqua), "Active legacy border was not preserved.")
            let saved = try encoder.encode(migrated)
            NSApp.appearance = NSAppearance(named: name == .aqua ? .darkAqua : .aqua)
            let reloaded = try decoder.decode(MenuBarAppearanceConfigurationV2.self, from: saved)
            try require(reloaded == migrated, "Unified appearance changed after switching system theme.")
        }
        let empty = try decode("{}")
        try require(empty == .defaultConfiguration, "Missing configuration must preserve defaults.")
        let oldStatic = try decode("{\"staticConfiguration\":{\"hasShadow\":true}}")
        try require(oldStatic.current.hasShadow, "Static legacy appearance changed.")
        do {
            _ = try decode("{\"isDynamic\":\"invalid\"}")
            throw Failure(description: "Malformed legacy appearance was accepted.")
        } catch is DecodingError {
            // A corrupt legacy flag must not silently select a different appearance.
        }
        for value in ["12.345", "90", "\"invalid\""] {
            let retired = try decode("{\"wallpaperBlurRadius\":\(value),\"staticConfiguration\":{\"hasBorder\":true},\"shapeKind\":1,\"isInset\":false}")
            try require(retired.current.hasBorder && retired.shapeKind == .full && !retired.isInset,
                        "Retired blur setting changed other appearance settings.")
            let saved = try encoder.encode(retired)
            let object = try JSONSerialization.jsonObject(with: saved) as? [String: Any]
            try require(object != nil && object?["wallpaperBlurRadius"] == nil, "Retired blur setting was written back.")
            let reloaded = try decoder.decode(MenuBarAppearanceConfigurationV2.self, from: saved)
            try require(reloaded == retired, "Appearance changed after dropping retired blur setting.")
        }
        let blurOnly = try decode("{\"wallpaperBlurRadius\":30}")
        try require(blurOnly == .defaultConfiguration, "A retired blur-only configuration must behave like the default.")
        print("PASS: appearance migration, retired blur compatibility and preserved customization")
    }

    @MainActor
    static func renderAppearance(to directory: URL) -> Int32 {
        do {
            try validateAppearanceConfiguration()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let state = AppState()
            let content = MenuBarAppearanceEditor(location: .settings)
                .environmentObject(state)
                .environmentObject(state.appearanceManager)
                .environment(\.iceFormStyle, .settings)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 760, height: 850), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = "Ice Appearance Validation"
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.close() }
            func snapshot(_ view: NSView, name: String) throws -> Data {
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    throw Failure(description: "Cannot allocate appearance snapshot.")
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw Failure(description: "Cannot encode appearance snapshot.")
                }
                try data.write(to: directory.appendingPathComponent(name + ".png"))
                return data
            }
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                window.appearance = NSAppearance(named: appearance)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
                _ = try snapshot(host, name: "settings-\(name)")
            }
            let settings = SettingsView()
                .environmentObject(state)
                .environmentObject(state.navigationState)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
            window.setContentSize(NSSize(width: 825, height: 612))
            for (sizeName, rowSize) in [("small", SidebarRowSize.small), ("medium", .medium), ("large", .large)] {
                let settingsHost = NSHostingView(rootView: settings.environment(\.sidebarRowSize, rowSize))
                window.contentView = settingsHost
                for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    window.appearance = NSAppearance(named: appearance)
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
                    _ = try snapshot(settingsHost, name: "general-\(sizeName)-\(name)")
                }
            }
            guard let screen = NSScreen.main else {
                throw Failure(description: "No screen for Ice Bar appearance validation.")
            }
            let panel = IceBarPanel(appState: state)
            panel.isReleasedWhenClosed = false
            let barHost = IceBarHostingView(appState: state, screen: screen, section: .hidden, closePanel: {})
            panel.contentView = barHost
            panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 50), display: false)
            panel.orderFrontRegardless()
            let originalAppearance = NSApp.appearance
            defer {
                panel.close()
                NSApp.appearance = originalAppearance
            }
            func material(in view: NSView) -> NSVisualEffectView? {
                if let effect = view as? NSVisualEffectView { return effect }
                return view.subviews.lazy.compactMap { material(in: $0) }.first
            }
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua), ("light-restored", .aqua)] {
                NSApp.appearance = NSAppearance(named: appearance)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
                let actual = material(in: barHost)?.effectiveAppearance ?? barHost.effectiveAppearance
                try require(actual.bestMatch(from: [.aqua, .darkAqua]) == appearance, "Ice Bar did not follow application appearance: \(name)")
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                    try require(material(in: barHost) != nil, "Ice Bar blur material is missing.")
                }
                _ = try snapshot(barHost, name: "ice-bar-\(name)")
            }
            print("PASS: real Ice Bar inherits light/dark appearance and updates on the same panel")
            print("PASS: real unified SwiftUI appearance editor in light/dark")
            print("PASS: real settings navigation and general pane at all sidebar sizes in light/dark")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Appearance validation failed: \(error)\n".utf8))
            return 1
        }
    }
}
#endif
