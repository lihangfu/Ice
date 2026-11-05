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
            try require(
                retired.current.hasBorder && retired.shapeKind == .full && !retired.isInset,
                "Retired blur setting changed other appearance settings."
            )
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
        if CommandLine.arguments.contains("--original-settings-titlebar-control") {
            FileHandle.standardError.write(Data("Use --validate-settings-scene OUTPUT_DIRECTORY --opaque-settings-window-control for the titlebar negative control.\n".utf8))
            return 2
        }
        do {
            try validateAppearanceConfiguration()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try validateIceBarIcons(to: directory)
            let state = AppState()
            let content = MenuBarAppearanceEditor(location: .settings)
                .environmentObject(state)
                .environmentObject(state.appearanceManager)
                .environment(\.iceFormStyle, .settings)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
            let host = NSHostingView(rootView: content.background(SettingsPalette.background(for: .light)))
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
                host.rootView = content.background(SettingsPalette.background(for: appearance == .aqua ? .light : .dark))
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
            print("PASS: settings content at all sidebar sizes in light/dark; window chrome requires --validate-settings-scene")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Appearance validation failed: \(error)\n".utf8))
            return 1
        }
    }

    @MainActor
    private static func validateIceBarIcons(to directory: URL) throws {
        func fixture(_ kind: String) throws -> CGImage {
            guard
                let space = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: nil,
                    width: 32,
                    height: 32,
                    bitsPerComponent: 8,
                    bytesPerRow: 128,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else {
                throw Failure(description: "Cannot allocate icon fixture.")
            }
            if kind == "opaque" {
                context.setFillColor(CGColor(gray: 0.7, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }
            let gray: CGFloat = kind == "black" ? 0 : (kind == "gray" ? 0.5 : 1)
            context.setFillColor(CGColor(gray: gray, alpha: 1))
            context.fillEllipse(in: CGRect(x: 6, y: 6, width: 20, height: 20))
            if kind != "opaque" {
                context.clear(CGRect(x: 12, y: 12, width: 8, height: 8))
            }
            if kind == "badge" {
                context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
                context.fill(CGRect(x: 20, y: 8, width: 6, height: 6))
            }
            if kind == "two-tone" {
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(CGRect(x: 7, y: 8, width: 4, height: 8))
            }
            guard let result = context.makeImage() else { throw Failure(description: "Cannot render fixture.") }
            return result
        }
        let kinds = ["white", "black", "gray", "badge", "opaque", "two-tone"]
        let images = try kinds.map(fixture)
        let masks = images.map { MenuBarIconAppearance.monochromeMask(from: $0) }
        for index in kinds.indices {
            try require((masks[index] != nil) == (index < 3), "Incorrect monochrome classification: \(kinds[index])")
            if let mask = masks[index] {
                let bitmap = NSBitmapImageRep(cgImage: mask)
                try require(bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0, "Template turned transparent padding opaque.")
                try require(bitmap.colorAt(x: 16, y: 16)?.alphaComponent == 0, "Template filled an icon cutout.")
                try require((bitmap.colorAt(x: 10, y: 16)?.alphaComponent ?? 0) > 0.95, "Template lost solid glyph coverage.")
            }
        }
        try validateLayoutIcons(images: images, masks: masks, to: directory)
        let originalControl = CommandLine.arguments.contains("--original-ice-bar-icons-control")
        let window = NSPanel(
            contentRect: CGRect(x: 100, y: 180, width: 296, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        let host = NSHostingView(rootView: HStack(spacing: 16) {
            ForEach(kinds.indices, id: \.self) { index in
                IceBarIcon(image: images[index], monochromeMask: originalControl ? nil : masks[index], scale: 1)
            }
        }
        .padding(12)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow)))
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.close() }
        var badgeReference: NSColor?
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua), ("light-restored", .aqua)] {
            window.appearance = NSAppearance(named: appearance)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
            guard
                let screenshot = ScreenCapture.captureWindow(CGWindowID(window.windowNumber), option: [.bestResolution, .boundsIgnoreFraming]),
                let png = NSBitmapImageRep(cgImage: screenshot).representation(using: .png, properties: [:])
            else { throw Failure(description: "Cannot capture icon composition; screen recording access is required.") }
            try png.write(to: directory.appendingPathComponent("icons-\(name).png"))
            let pixels = NSBitmapImageRep(cgImage: screenshot)
            let scale = CGFloat(screenshot.width) / 296
            func color(x: Int, y: Int) throws -> NSColor {
                guard let value = pixels.colorAt(x: Int(CGFloat(x) * scale), y: Int(CGFloat(y) * scale))?.usingColorSpace(.sRGB) else {
                    throw Failure(description: "Cannot read composed icon pixel.")
                }
                return value
            }
            for index in 0..<3 {
                let ink = try color(x: 12 + index * 48 + 10, y: 28)
                let lightness = (ink.redComponent + ink.greenComponent + ink.blueComponent) / 3
                try require(
                    appearance == .darkAqua ? lightness > 0.8 : lightness < 0.3,
                    "Monochrome icon did not follow \(name) appearance: \(kinds[index])"
                )
            }
            let badge = try color(x: 12 + 3 * 48 + 23, y: 33)
            try require(
                badge.redComponent - badge.greenComponent > 0.4 && badge.redComponent - badge.blueComponent > 0.4,
                "Colored status badge lost its red hue."
            )
            if let reference = badgeReference {
                let difference = abs(reference.redComponent - badge.redComponent)
                    + abs(reference.greenComponent - badge.greenComponent)
                    + abs(reference.blueComponent - badge.blueComponent)
                try require(difference < 0.02, "Colored status badge changed with system appearance.")
            }
            badgeReference = badge
        }
        // Real captured status items exercise capture formats that synthetic RGBA fixtures cannot cover.
        let captured = MenuBarItem.getMenuBarItems(onScreenOnly: true, activeSpaceOnly: true).prefix(24).compactMap {
            ScreenCapture.captureWindow($0.windowID, option: [.bestResolution, .boundsIgnoreFraming])
        }
        let realMasks = captured.map { MenuBarIconAppearance.monochromeMask(from: $0) }
        if captured.isEmpty {
            print("LIMIT: no live status item captures; only production rendering with synthetic icons was verified")
        } else {
            let realHost = NSHostingView(rootView: HStack(spacing: 12) {
                ForEach(captured.indices, id: \.self) { index in
                    IceBarIcon(image: captured[index], monochromeMask: realMasks[index], scale: NSScreen.main?.backingScaleFactor ?? 1)
                }
            }
            .padding(12)
            .background(VisualEffectView(material: .popover, blendingMode: .behindWindow)))
            window.contentView = realHost
            window.setContentSize(realHost.fittingSize)
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                window.appearance = NSAppearance(named: appearance)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
                guard
                    let screenshot = ScreenCapture.captureWindow(CGWindowID(window.windowNumber), option: [.bestResolution, .boundsIgnoreFraming]),
                    let png = NSBitmapImageRep(cgImage: screenshot).representation(using: .png, properties: [:])
                else { throw Failure(description: "Cannot capture live icon preview.") }
                try png.write(to: directory.appendingPathComponent("live-icons-\(name).png"))
            }
            print("CAPTURED: \(captured.count) live status items, \(realMasks.compactMap { $0 }.count) eligible for monochrome adaptation")
        }
        print("PASS: white/black/gray icons follow light-dark-light, colored badge/opaque/two-tone fallbacks and transparent cutouts")
    }
    @MainActor
    private static func validateLayoutIcons(images: [CGImage], masks: [CGImage?], to directory: URL) throws {
        let items = MenuBarItem.getMenuBarItems(onScreenOnly: true, activeSpaceOnly: true)
        guard let item = items.first else { throw Failure(description: "No status item for layout view validation.") }
        let state = AppState()
        let window = NSWindow(
            contentRect: CGRect(x: 100, y: 160, width: 320, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
        window.contentView = root
        let originalControl = CommandLine.arguments.contains("--original-layout-icons-control")
        let views = images.indices.map { index in
            let view = LayoutBarItemView(appState: state, item: item)
            view.updateImage(images[index], monochromeMask: originalControl ? nil : masks[index], scale: 1)
            view.isEnabled = true
            view.setFrameOrigin(CGPoint(x: 12 + index * 48, y: 24))
            root.addSubview(view)
            return view
        }
        window.orderFrontRegardless()
        defer { window.close() }
        func bitmap(_ view: NSView) throws -> NSBitmapImageRep {
            guard let result = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw Failure(description: "Cannot allocate layout icon snapshot.")
            }
            view.cacheDisplay(in: view.bounds, to: result)
            return result
        }
        func sample(_ view: NSView, x: CGFloat, y: CGFloat) throws -> NSColor {
            let pixels = try bitmap(view)
            let scale = CGFloat(pixels.pixelsWide) / view.bounds.width
            guard let color = pixels.colorAt(x: Int(x * scale), y: Int(y * scale))?.usingColorSpace(.sRGB) else {
                throw Failure(description: "Cannot read layout icon pixels.")
            }
            return color
        }
        func save(_ name: String) throws {
            guard
                let image = ScreenCapture.captureWindow(CGWindowID(window.windowNumber), option: [.bestResolution, .boundsIgnoreFraming]),
                let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { throw Failure(description: "Cannot capture layout preview.") }
            try data.write(to: directory.appendingPathComponent(name + ".png"))
        }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua), ("light-restored", .aqua)] {
            window.appearance = NSAppearance(named: appearance)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            try save("layout-icons-\(name)")
            for view in views.prefix(3) {
                let color = try sample(view, x: 10, y: 16)
                let lightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                try require(
                    appearance == .darkAqua ? lightness > 0.8 : lightness < 0.3,
                    "Layout monochrome icon did not follow \(name) appearance."
                )
                let cutout = try sample(view, x: 16, y: 16)
                try require(cutout.alphaComponent == 0, "Layout icon cutout became opaque.")
                guard
                    let draggingImage = view.displayedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
                    let dragColor = NSBitmapImageRep(cgImage: draggingImage).colorAt(x: draggingImage.width * 10 / 32, y: draggingImage.height / 2)?.usingColorSpace(.sRGB)
                else { throw Failure(description: "Missing themed dragging image.") }
                try require(abs(dragColor.redComponent - color.redComponent) < 0.05, "Dragging image differs from layout icon.")
                try require(root.hitTest(CGPoint(x: view.frame.midX, y: view.frame.midY)) === view, "Icon adaptation intercepted layout hit testing.")
            }
            let badge = try sample(views[3], x: 23, y: 21)
            try require(badge.redComponent - badge.greenComponent > 0.4, "Layout recolored the colored badge.")
        }
        let testView = views[0]
        let enabled = try sample(testView, x: 10, y: 16)
        testView.isEnabled = false
        let disabled = try sample(testView, x: 10, y: 16)
        try require(
            enabled.alphaComponent > 0.5 && abs(disabled.alphaComponent / enabled.alphaComponent - 0.67) < 0.03,
            "Disabled layout icon lost its dimming relative to the system label color."
        )
        let frame = testView.frame
        testView.isDraggingPlaceholder = true
        let placeholder = try sample(testView, x: 10, y: 16)
        try require(placeholder.alphaComponent == 0 && testView.frame == frame, "Dragging placeholder changed geometry or drew the icon.")
        testView.isDraggingPlaceholder = false
        testView.updateImage(images[3], monochromeMask: masks[3], scale: 1)
        let changedBadge = try sample(testView, x: 23, y: 21)
        try require(changedBadge.redComponent - changedBadge.greenComponent > 0.4, "A new colored badge retained the old template.")
        for view in views { view.removeFromSuperview() }
        var x: CGFloat = 12
        for item in items.prefix(24) {
            guard let capture = ScreenCapture.captureWindow(item.windowID, option: [.bestResolution, .boundsIgnoreFraming]) else { continue }
            let view = LayoutBarItemView(appState: state, item: item)
            view.updateImage(capture, monochromeMask: MenuBarIconAppearance.monochromeMask(from: capture), scale: NSScreen.main?.backingScaleFactor ?? 1)
            view.setFrameOrigin(CGPoint(x: x, y: 24))
            root.addSubview(view)
            x += view.frame.width + 12
        }
        window.setContentSize(CGSize(width: x, height: 80))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            try save("layout-live-icons-\(name)")
        }
        print("PASS: real AppKit layout icons, theme restoration, color updates, drag image, hit testing, disabled opacity and placeholder geometry")
    }
}
#endif
