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
        var fractional = try decode("{\"wallpaperBlurRadius\":12.345}")
        try require(fractional.wallpaperBlurRadius == 12.345, "Fractional blur radius was rounded.")
        let roundTrip = try decoder.decode(MenuBarAppearanceConfigurationV2.self, from: encoder.encode(fractional))
        try require(roundTrip == fractional, "Blur persistence changed the radius.")
        for (value, expected) in [(Double.nan, 0.0), (.infinity, 0), (-1, 0), (31, 30)] {
            fractional.wallpaperBlurRadius = value
            try require(fractional.wallpaperBlurRadius == expected, "Invalid blur radius escaped normalization.")
        }
        let clamped = try decode("{\"wallpaperBlurRadius\":90}")
        try require(clamped.wallpaperBlurRadius == 30, "Decoded blur radius escaped normalization.")
        do {
            _ = try decode("{\"wallpaperBlurRadius\":\"invalid\"}")
            throw Failure(description: "Malformed blur radius was accepted.")
        } catch is DecodingError { }
        print("PASS: appearance migration, fractional blur persistence, bounds and invalid input")
    }

    @MainActor
    static func renderAppearance(to directory: URL) -> Int32 {
        do {
            try validateAppearanceConfiguration()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let state = AppState()
            state.appearanceManager.configuration.wallpaperBlurRadius = 12.345
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
            print("PASS: real unified SwiftUI appearance editor in light/dark")
            print("PASS: real settings navigation and general pane at all sidebar sizes in light/dark")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Appearance validation failed: \(error)\n".utf8))
            return 1
        }
    }
    @MainActor
    static func validateWallpaperBlur(to directory: URL) -> Int32 {
        do {
            try validateAppearanceConfiguration()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try require(MenuBarWallpaperBlurView.isSupported, "Private background compositor unavailable.")
            try require(!NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency, "Reduce Transparency is enabled.")
            guard let screen = NSScreen.main, let height = screen.getMenuBarHeight() else {
                throw Failure(description: "No menu bar screen.")
            }
            func settle(_ duration: TimeInterval = 0.6) {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
            }
            func save(_ image: CGImage, _ name: String) throws {
                guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw Failure(description: "Cannot encode blur snapshot.")
                }
                try data.write(to: directory.appendingPathComponent(name + ".png"))
            }
            @discardableResult
            func capture(_ name: String, rect: CGRect) throws -> CGImage {
                let ids = WindowInfo.getOnScreenWindows().map(\.windowID)
                guard let image = ScreenCapture.captureWindows(ids, screenBounds: rect, option: [.bestResolution, .boundsIgnoreFraming]) else {
                    throw Failure(description: "Cannot capture live compositor.")
                }
                try save(image, name)
                return image
            }
            let menuRect = CGRect(x: CGDisplayBounds(screen.displayID).minX,
                                  y: CGDisplayBounds(screen.displayID).minY,
                                  width: screen.frame.width, height: height)
            try capture("system-before", rect: menuRect)
            let state = AppState()
            let panel = MenuBarOverlayPanel(appState: state, owningScreen: screen)
            panel.isReleasedWhenClosed = false
            defer { panel.close() }
            panel.setFrame(CGRect(x: screen.frame.minX, y: screen.frame.maxY - height - 5,
                                  width: screen.frame.width, height: height + 5), display: true)
            panel.orderFrontRegardless()
            state.appearanceManager.configuration.wallpaperBlurRadius = 12.345
            panel.requestWallpaperUpdate()
            settle(0.1)
            if !AXIsProcessTrusted() {
                print("LIMIT: accessibility authorization unavailable; testing the production capture/drawing path directly, excluding menu discovery and interaction.")
                panel.updateDesktopWallpaper(for: screen.displayID, with: WindowInfo.getOnScreenWindows())
            }
            settle()
            try require(panel.wallpaperBlurSource != nil, "Wallpaper/menu source capture failed.")
            try require(!panel.wallpaperBlurView.isHidden, "Production compositor did not become visible.")
            try capture("blur-12", rect: menuRect)
            state.appearanceManager.configuration.wallpaperBlurRadius = 30
            settle()
            try capture("blur-30", rect: menuRect)
            state.appearanceManager.configuration.shapeKind = .split
            settle()
            try capture("blur-split", rect: menuRect)
            panel.isDraggingMenuBarItem = true
            settle()
            try require(panel.wallpaperBlurView.isHidden, "Dragging did not suspend blur.")
            panel.isDraggingMenuBarItem = false
            settle()
            try require(!panel.wallpaperBlurView.isHidden, "Blur did not resume after dragging.")
            state.appearanceManager.configuration = .defaultConfiguration
            settle()
            try require(panel.wallpaperBlurView.isHidden, "Zero did not restore system background.")
            try capture("system-restored", rect: menuRect)
            state.appearanceManager.configuration.wallpaperBlurRadius = 30
            panel.requestWallpaperUpdate()
            panel.orderOut(nil)
            settle()
            try require(panel.wallpaperBlurView.isHidden, "Late render revived hidden panel.")

            // Exercise both foreground polarities with real WindowServer composition,
            // without changing the user's wallpaper, appearance, or preferences.
            let size = CGSize(width: 420, height: 32)
            let fixtureFrame = CGRect(x: screen.frame.minX + 100, y: screen.frame.maxY - 180,
                                      width: size.width, height: size.height)
            let fixtureRect = CGRect(x: menuRect.minX + 100, y: menuRect.minY + 148,
                                     width: size.width, height: size.height)
            func fixture(lightText: Bool, stripes: Bool) throws -> CGImage {
                let image = NSImage(size: size, flipped: false) { rect in
                    if stripes {
                        for x in stride(from: 0, to: Int(size.width), by: 4) {
                            (x % 8 == 0 ? NSColor.systemBlue : NSColor.systemOrange).setFill()
                            CGRect(x: x, y: 0, width: 4, height: Int(size.height)).fill()
                        }
                    } else {
                        NSColor(white: lightText ? 0.2 : 0.8, alpha: 1).setFill()
                        rect.fill()
                        ("Aa Menu 123" as NSString).draw(at: CGPoint(x: 8, y: 8), withAttributes: [
                            .font: NSFont.systemFont(ofSize: 15),
                            .foregroundColor: lightText ? NSColor.white : NSColor.black,
                        ])
                    }
                    return true
                }
                guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw Failure(description: "Fixture rendering failed.")
                }
                return cgImage
            }
            let wallpaper = try fixture(lightText: false, stripes: true)
            var fixtureBackground: NSColor?
            for lightText in [false, true] {
                let native = try fixture(lightText: lightText, stripes: false)
                let source = MenuBarWallpaperBlurSource(wallpaper: wallpaper, menuBar: native,
                                                       crop: CGRect(origin: .zero, size: size), scale: 1)
                guard let output = MenuBarWallpaperBlurRenderer.render(source, radius: 12.345) else {
                    throw Failure(description: "Renderer rejected valid fixture.")
                }
                try require(output.lightText == lightText, "Foreground polarity was misidentified.")
                try require(output.wallpaper.width == Int(size.width), "Blur changed crop dimensions.")
                let originalPixels = NSBitmapImageRep(cgImage: wallpaper)
                let blurredPixels = NSBitmapImageRep(cgImage: output.wallpaper)
                func variation(_ image: NSBitmapImageRep) -> CGFloat {
                    var sum: CGFloat = 0
                    for x in 20..<image.pixelsWide - 20 {
                        let left = image.colorAt(x: x - 1, y: 2)?.usingColorSpace(.sRGB)?.redComponent ?? 0
                        let right = image.colorAt(x: x, y: 2)?.usingColorSpace(.sRGB)?.redComponent ?? 0
                        sum += abs(left - right)
                    }
                    return sum
                }
                try require(variation(blurredPixels) < variation(originalPixels) * 0.1, "Wallpaper texture was not blurred.")
                for invalid in [Double.nan, .infinity, -1, 31] {
                    try require(MenuBarWallpaperBlurRenderer.render(source, radius: invalid) == nil, "Renderer accepted invalid radius.")
                }
                let underlay = NSPanel(contentRect: fixtureFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                underlay.isReleasedWhenClosed = false
                underlay.level = .mainMenu
                let imageView = NSImageView(frame: CGRect(origin: .zero, size: size))
                imageView.image = NSImage(cgImage: native, size: size)
                underlay.contentView = imageView
                underlay.orderFrontRegardless()
                let overlay = NSPanel(contentRect: fixtureFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                overlay.isReleasedWhenClosed = false
                overlay.isOpaque = false
                overlay.backgroundColor = .clear
                overlay.level = .statusBar
                let view = MenuBarWallpaperBlurView(frame: CGRect(origin: .zero, size: size))
                overlay.contentView = view
                overlay.orderFrontRegardless()
                view.update(source: source, radius: 12.345, shape: CGPath(rect: view.bounds, transform: nil))
                settle()
                try require(!view.isHidden, "Fixture compositor failed.")
                let screenshot = try capture(lightText ? "white-text" : "black-text", rect: fixtureRect)
                let pixels = NSBitmapImageRep(cgImage: screenshot)
                guard let background = pixels.colorAt(x: pixels.pixelsWide - 40, y: pixels.pixelsHigh / 2)?.usingColorSpace(.sRGB) else {
                    throw Failure(description: "Cannot read composed background.")
                }
                if let reference = fixtureBackground {
                    let difference = abs(reference.redComponent - background.redComponent)
                        + abs(reference.greenComponent - background.greenComponent)
                        + abs(reference.blueComponent - background.blueComponent)
                    try require(difference < 0.03, "White/black foreground changed replacement wallpaper color.")
                } else {
                    fixtureBackground = background
                }
                var inkPixels = 0
                for y in 4..<pixels.pixelsHigh - 4 {
                    for x in 8..<min(180, pixels.pixelsWide) {
                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                        let luminance = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                        if lightText ? luminance > 0.95 : luminance < 0.05 {
                            inkPixels += 1
                        }
                    }
                }
                try require(inkPixels > 100, "Compositing erased the foreground glyphs.")
                view.update(source: source, radius: 18.75, shape: CGPath(rect: view.bounds, transform: nil))
                view.suspend()
                settle(0.1)
                try require(view.isHidden, "Cancelled rendering made a suspended compositor visible.")
                overlay.close()
                underlay.close()
            }
            print("PASS: production capture/drawing, radius changes, shape clipping, dragging, zero restore, cancellation, texture reduction, black/white foreground pixels and invalid inputs")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Wallpaper blur validation failed: \(error)\n".utf8))
            return 1
        }
    }

}
#endif
