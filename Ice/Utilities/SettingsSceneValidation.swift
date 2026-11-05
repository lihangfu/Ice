//
//  SettingsSceneValidation.swift
//  Ice
//

#if SWIFT_PACKAGE
import SwiftUI

@MainActor
enum SettingsSceneValidation {
    static let argument = "--validate-settings-scene"
    static var isRequested: Bool { CommandLine.arguments.contains(argument) }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private static func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    static func run(appState: AppState) async -> Int32 {
        do {
            guard
                let index = CommandLine.arguments.firstIndex(of: argument),
                CommandLine.arguments.indices.contains(index + 1),
                !CommandLine.arguments[index + 1].hasPrefix("--")
            else { throw Failure(description: "Usage: Ice --validate-settings-scene OUTPUT_DIRECTORY") }
            let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            appState.dismissPermissionsWindow()
            appState.openSettingsWindow()
            appState.activate(withPolicy: .regular)
            let deadline = Date(timeIntervalSinceNow: 5)
            while appState.settingsWindow?.isVisible != true {
                guard Date() < deadline else { throw Failure(description: "The production settings scene did not open.") }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard let window = appState.settingsWindow else { throw Failure(description: "The settings window was released.") }
            let originalFrame = window.frame
            let originalAppearance = window.appearance
            let originalApplicationAppearance = NSApp.appearance
            let originalPane = appState.navigationState.settingsNavigationIdentifier
            defer {
                window.appearance = originalAppearance
                NSApp.appearance = originalApplicationAppearance
                window.setFrame(originalFrame, display: false)
                appState.navigationState.settingsNavigationIdentifier = originalPane
            }
            window.setContentSize(NSSize(width: 825, height: 612))
            appState.navigationState.settingsNavigationIdentifier = .general
            try await Task.sleep(for: .milliseconds(400))
            let compactControl = CommandLine.arguments.contains("--compact-settings-toolbar-control")
            if compactControl { window.toolbarStyle = .unifiedCompact }
            guard window.toolbarStyle == .unified else {
                throw Failure(description: "The production settings scene is not using the unified toolbar.")
            }
            func capture(_ name: String) throws -> NSBitmapImageRep {
                window.contentView?.superview?.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                guard
                    let image = ScreenCapture.captureWindow(CGWindowID(window.windowNumber), option: [.bestResolution, .boundsIgnoreFraming]),
                    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                else { throw Failure(description: "Cannot capture the production settings scene.") }
                try png.write(to: directory.appendingPathComponent(name + ".png"))
                return NSBitmapImageRep(cgImage: image)
            }
            func sidebarColor(in bitmap: NSBitmapImageRep) throws -> NSColor {
                let scale = CGFloat(bitmap.pixelsWide) / window.frame.width
                guard let color = bitmap.colorAt(x: Int(100 * scale), y: Int(20 * scale))?.usingColorSpace(.sRGB) else {
                    throw Failure(description: "Cannot sample the sidebar titlebar.")
                }
                return color
            }
            for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                window.appearance = nil
                NSApp.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(250))
                guard
                    let root = window.contentView,
                    let scroll = descendants(of: root).compactMap({ $0 as? NSScrollView }).filter({
                        ($0.documentView?.frame.height ?? 0) > $0.documentVisibleRect.height + 1
                    }).max(by: { $0.bounds.width < $1.bounds.width })
                else { throw Failure(description: "The production settings form is not scrollable.") }
                let top = scroll.contentView.bounds.origin
                let baseline = try sidebarColor(in: capture("scene-\(theme)-top"))
                for (name, offset) in [("scrolled", CGFloat(90)), ("restored", 0)] {
                    scroll.contentView.scroll(to: NSPoint(x: top.x, y: top.y + offset))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    try await Task.sleep(for: .milliseconds(300))
                    if offset > 0, CommandLine.arguments.contains("--opaque-settings-window-control") {
                        window.titlebarAppearsTransparent = false
                    }
                    let sample = try sidebarColor(in: capture("scene-\(theme)-\(name)"))
                    let difference = max(
                        abs(sample.redComponent - baseline.redComponent),
                        abs(sample.greenComponent - baseline.greenComponent),
                        abs(sample.blueComponent - baseline.blueComponent)
                    )
                    guard difference < 0.035 else { throw Failure(description: "Scrolling repainted the sidebar titlebar.") }
                    guard window.titlebarAppearsTransparent else {
                        throw Failure(description: "The window-wide titlebar background was enabled.")
                    }
                    if offset > 0 {
                        let materials = descendants(of: root).compactMap { $0 as? NSVisualEffectView }
                        guard materials.contains(where: {
                            $0.material == .titlebar && $0.blendingMode == .withinWindow && !$0.isHiddenOrHasHiddenAncestor
                        }) else { throw Failure(description: "The detail titlebar has no native within-window material.") }
                    }
                }
                scroll.contentView.scroll(to: NSPoint(x: top.x, y: top.y + 90))
                scroll.reflectScrolledClipView(scroll.contentView)
                try await Task.sleep(for: .milliseconds(200))
                for identifier in SettingsNavigationIdentifier.allCases {
                    appState.navigationState.settingsNavigationIdentifier = identifier
                    try await Task.sleep(for: .milliseconds(250))
                    _ = try capture("scene-pane-\(identifier)-\(theme)")
                }
                appState.navigationState.settingsNavigationIdentifier = .general
                try await Task.sleep(for: .milliseconds(200))
            }
            NSApp.appearance = NSAppearance(named: .aqua)
            for width in [1100, 1500, 825] {
                window.setContentSize(NSSize(width: width, height: 612))
                try await Task.sleep(for: .milliseconds(300))
                _ = try capture("scene-resized-\(width)")
            }
            var observedHeight: CGFloat = -1
            let chrome = SettingsWindowChrome.Coordinator(
                height: Binding(
                    get: { observedHeight },
                    set: { observedHeight = $0 }
                )
            )
            let otherWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
            otherWindow.isReleasedWhenClosed = false
            defer { otherWindow.close() }
            otherWindow.titlebarAppearsTransparent = false
            otherWindow.titlebarSeparatorStyle = .line
            chrome.attach(to: otherWindow)
            try await Task.sleep(for: .milliseconds(50))
            guard observedHeight >= 0, otherWindow.titlebarAppearsTransparent else {
                throw Failure(description: "Window chrome did not attach or report its native height.")
            }
            chrome.attach(to: nil)
            chrome.detach()
            let detachedHeight = observedHeight
            otherWindow.setContentSize(NSSize(width: 400, height: 450))
            try await Task.sleep(for: .milliseconds(50))
            guard
                observedHeight == detachedHeight,
                !otherWindow.titlebarAppearsTransparent,
                otherWindow.titlebarSeparatorStyle == .line
            else { throw Failure(description: "Window chrome retained observation or style after detachment.") }
            let metadata: [String: Any] = [
                "toolbarStyle": window.toolbarStyle.rawValue,
                "titlebarHeight": window.frame.height - window.contentLayoutRect.maxY,
                "applicationActive": NSApp.isActive,
                "windowKey": window.isKeyWindow,
                "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            ]
            try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
                .write(to: directory.appendingPathComponent("scene-properties.json"))
            print("PASS: production settings scene, native column material, all panes, light/dark scrolling, resizing and chrome cleanup")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Settings scene validation failed: \(error)\n".utf8))
            return 1
        }
    }
}
#endif
