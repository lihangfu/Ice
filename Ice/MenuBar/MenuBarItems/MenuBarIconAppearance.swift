//
//  MenuBarIconAppearance.swift
//  Ice
//

import Cocoa

/// A capture has no template metadata. Ambiguous images must retain their colors.
enum MenuBarIconAppearance {
    static func monochromeMask(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        // Bound work for unusually wide status items and reject unsupported captures.
        guard
            width > 2, height > 2, width <= 2048, height <= 256,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            let data = context.data
        else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var solidLuminance: Double = 0
        var solidCount = 0
        var minimum: Double = 1
        var maximum: Double = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                // A transparent perimeter prevents opaque tiles from becoming solid rectangles.
                if x == 0 || y == 0 || x == width - 1 || y == height - 1, alpha > 0.03 {
                    return nil
                }
                guard alpha >= 0.08 else { continue }
                let red = Double(pixels[offset]) / 255 / alpha
                let green = Double(pixels[offset + 1]) / 255 / alpha
                let blue = Double(pixels[offset + 2]) / 255 / alpha
                // Even a small colored status badge must prevent recoloring the whole item.
                guard max(red, green, blue) - min(red, green, blue) <= 0.06 else { return nil }
                if alpha >= 0.75 {
                    let luminance = (red + green + blue) / 3
                    solidLuminance += luminance
                    solidCount += 1
                    minimum = min(minimum, luminance)
                    maximum = max(maximum, luminance)
                }
            }
        }
        guard solidCount >= 4, maximum - minimum <= 0.15 else { return nil }
        let foreground = solidLuminance / Double(solidCount)
        let isLight = foreground >= 0.5
        let strength = isLight ? foreground : 1 - foreground
        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0 else { continue }
            let luminance = Double(Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / (3 * 255 * alpha)
            // Use coverage and polarity to suppress the opposite-color shadow in white captures.
            // Normalize by the solid foreground so gray glyphs do not become faint templates.
            let coverage = min(max((isLight ? luminance : 1 - luminance) / strength, 0), 1) * alpha
            let value = UInt8((coverage * 255).rounded())
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = value
        }
        return context.makeImage()
    }
}
