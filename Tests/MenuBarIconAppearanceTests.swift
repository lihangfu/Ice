import Cocoa

@main
struct MenuBarIconAppearanceTests {
    static func main() throws {
        var failures = [String]()
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }

        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for name in ["wechat-shadow", "qq-shadow", "bob-shadow", "metrics-shadow"] {
            let url = root.appendingPathComponent("Tests/Fixtures/MenuBarIcons/\(name).png")
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "IconTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name)"])
            }
            let mask = MenuBarIconAppearance.monochromeMask(from: image)
            expect(mask != nil, "\(name): clipped native shadow must not prevent theme adaptation")
            if let mask {
                let pixels = NSBitmapImageRep(cgImage: mask)
                expect(mask.width == image.width && mask.height == image.height, "\(name): mask changed geometry")
                for x in 0..<mask.width {
                    expect(pixels.colorAt(x: x, y: 0)?.alphaComponent == 0, "\(name): retained top shadow")
                    expect(pixels.colorAt(x: x, y: mask.height - 1)?.alphaComponent == 0, "\(name): retained bottom shadow")
                }
            }
        }

        let kinds = ["white", "black", "gray", "shadow", "opaque", "translucent", "two-tone", "badge", "edge-color", "edge-white", "strong-shadow"]
        for kind in kinds {
            let image = try fixture(kind)
            let mask = MenuBarIconAppearance.monochromeMask(from: image)
            let shouldAdapt = ["white", "black", "gray", "shadow"].contains(kind)
            expect((mask != nil) == shouldAdapt, "\(kind): incorrect monochrome classification")
            if let mask {
                let pixels = NSBitmapImageRep(cgImage: mask)
                expect(pixels.colorAt(x: 0, y: 0)?.alphaComponent == 0, "\(kind): padding became opaque")
                expect(pixels.colorAt(x: 16, y: 16)?.alphaComponent == 0, "\(kind): cutout became opaque")
                expect((pixels.colorAt(x: 10, y: 16)?.alphaComponent ?? 0) > 0.95, "\(kind): glyph lost coverage")
            }
        }
        for failure in failures { print("FAIL: \(failure)") }
        guard failures.isEmpty else { exit(1) }
        print("PASS: \(checks) icon checks; 4 native shadow captures, monochrome coverage/cutouts, colored badges/edges and background fallbacks")
    }

    private static func fixture(_ kind: String) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "IconTests", code: 2)
        }
        if kind == "opaque" || kind == "translucent" {
            context.setFillColor(CGColor(gray: 0, alpha: kind == "opaque" ? 1 : 0.05))
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        context.setFillColor(CGColor(gray: kind == "black" ? 0 : (kind == "gray" ? 0.5 : 1), alpha: 1))
        context.fillEllipse(in: CGRect(x: 6, y: 6, width: 20, height: 20))
        context.clear(CGRect(x: 12, y: 12, width: 8, height: 8))
        if kind == "two-tone" {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 7, y: 8, width: 4, height: 8))
        }
        if kind == "badge" {
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 20, y: 8, width: 6, height: 6))
        }
        if ["shadow", "edge-color", "edge-white", "strong-shadow"].contains(kind) {
            let alpha: CGFloat = kind == "strong-shadow" ? 0.2 : 0.06
            context.setFillColor(kind == "edge-color"
                ? CGColor(red: 1, green: 0, blue: 0, alpha: alpha)
                : CGColor(gray: kind == "edge-white" ? 1 : 0, alpha: alpha))
            context.fill(CGRect(x: 12, y: 0, width: 8, height: 1))
        }
        guard let image = context.makeImage() else { throw NSError(domain: "IconTests", code: 3) }
        return image
    }
}
