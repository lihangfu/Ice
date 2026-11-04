//
//  IceAssets.swift
//  Ice
//

import SwiftUI

/// SwiftPM copies the catalog without actool; read the same source assets in both builds.
enum IceAssets {
    static func image(named name: String) -> NSImage? {
        #if SWIFT_PACKAGE
        if let cached = NSImage(named: name) {
            return cached
        }
        guard
            let directory = imageDirectories[name],
            let data = try? Data(contentsOf: directory.appendingPathComponent("Contents.json")),
            let manifest = try? JSONDecoder().decode(ImageManifest.self, from: data)
        else {
            return nil
        }
        let image = NSImage()
        for entry in manifest.images {
            guard
                let filename = entry.filename,
                let scale = Double(entry.scale.replacingOccurrences(of: "x", with: "")), scale > 0,
                let imageData = try? Data(contentsOf: directory.appendingPathComponent(filename)),
                let representation = NSBitmapImageRep(data: imageData)
            else {
                continue
            }
            representation.size = NSSize(
                width: Double(representation.pixelsWide) / scale,
                height: Double(representation.pixelsHigh) / scale
            )
            image.addRepresentation(representation)
        }
        guard !image.representations.isEmpty else {
            return nil
        }
        image.isTemplate = manifest.properties?["template-rendering-intent"] == "template"
        image.setName(name)
        return image
        #else
        return NSImage(named: name)
        #endif
    }

    static func requiredImage(named name: String) -> NSImage {
        guard let image = image(named: name) else {
            preconditionFailure("Missing bundled image: \(name). Rebuild Ice using scripts/build-app.sh.")
        }
        return image
    }

    static var defaultLayoutBarColor: Color {
        #if SWIFT_PACKAGE
        return Color(nsColor: layoutBarColor)
        #else
        return .defaultLayoutBar
        #endif
    }

    #if SWIFT_PACKAGE
    // SwiftPM's generated accessor otherwise falls back to an absolute build directory.
    static let resourceBundle = Bundle.main.url(forResource: "Ice_Ice", withExtension: "bundle")
        .flatMap(Bundle.init(url:)) ?? Bundle.module

    private struct ImageManifest: Decodable {
        struct Entry: Decodable {
            let filename: String?
            let scale: String
        }
        let images: [Entry]
        let properties: [String: String]?
    }

    private struct ColorManifest: Decodable {
        struct Entry: Decodable {
            struct Appearance: Decodable {
                let appearance: String
                let value: String
            }
            struct Value: Decodable {
                let components: [String: String]
            }
            let appearances: [Appearance]?
            let color: Value
        }
        let colors: [Entry]
    }

    private static let imageDirectories: [String: URL] = {
        guard
            let catalog = resourceBundle.url(forResource: "Assets", withExtension: "xcassets"),
            let enumerator = FileManager.default.enumerator(at: catalog, includingPropertiesForKeys: nil)
        else {
            return [:]
        }
        var directories = [String: URL]()
        for case let url as URL in enumerator where url.pathExtension == "imageset" {
            directories[url.deletingPathExtension().lastPathComponent] = url
        }
        return directories
    }()

    private static let layoutBarColor: NSColor = {
        guard
            let catalog = resourceBundle.url(forResource: "Assets", withExtension: "xcassets"),
            let data = try? Data(contentsOf: catalog.appendingPathComponent("DefaultLayoutBarColor.colorset/Contents.json")),
            let manifest = try? JSONDecoder().decode(ColorManifest.self, from: data),
            let light = manifest.colors.first(where: { $0.appearances == nil }),
            let dark = manifest.colors.first(where: {
                $0.appearances?.contains(where: { $0.appearance == "luminosity" && $0.value == "dark" }) == true
            })
        else {
            preconditionFailure("Missing layout bar colors. Rebuild Ice using scripts/build-app.sh.")
        }
        func color(_ entry: ColorManifest.Entry) -> NSColor {
            let values = entry.color.components
            guard
                let red = Double(values["red"] ?? ""),
                let green = Double(values["green"] ?? ""),
                let blue = Double(values["blue"] ?? ""),
                let alpha = Double(values["alpha"] ?? "")
            else {
                preconditionFailure("Invalid layout bar color components.")
            }
            return NSColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
        }
        let lightColor = color(light)
        let darkColor = color(dark)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }()
    #endif
}
