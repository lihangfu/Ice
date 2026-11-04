//
//  MenuBarWallpaperBlur.swift
//  Ice
//

import Cocoa
import CoreImage
import QuartzCore
import ObjectiveC

/// Captures only the wallpaper and the system-owned menu window, never Ice's overlay.
struct MenuBarWallpaperBlurSource {
    let wallpaper: CGImage
    let menuBar: CGImage
    let crop: CGRect
    let scale: CGFloat
    let id = UUID()
}

/// Image processing is independent of the live foreground compositor.
enum MenuBarWallpaperBlurRenderer {
    struct Output {
        let wallpaper: CGImage
        let normalization: CGImage
        let lightText: Bool
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func render(_ source: MenuBarWallpaperBlurSource, radius: Double) -> Output? {
        let width = source.menuBar.width
        let height = source.menuBar.height
        guard
            width > 0, height >= 4, source.scale.isFinite, source.scale > 0,
            radius.isFinite, (0...30).contains(radius),
            source.crop.origin.x.isFinite, source.crop.origin.y.isFinite,
            source.crop.width.isFinite, source.crop.height.isFinite,
            !source.crop.isEmpty,
            CGRect(x: 0, y: 0, width: source.wallpaper.width, height: source.wallpaper.height).contains(source.crop)
        else {
            return nil
        }
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let bitmap = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let data = bitmap.data
        else {
            return nil
        }
        bitmap.draw(source.menuBar, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let inset = max(1, min(Int(source.scale), height / 4))
        let topRow = inset
        let bottomRow = height - inset - 1
        var darkInk = 0.0
        var lightInk = 0.0
        // The Apple-menu region provides the foreground polarity even when system
        // appearance and wallpaper-dependent menu text use different colors.
        for y in (inset * 2)..<(height - inset * 2) {
            for x in 0..<min(width, Int(60 * source.scale)) {
                for channel in 0..<3 {
                    let background = Double(pixels[(topRow * width + x) * 4 + channel])
                    let pixel = Double(pixels[(y * width + x) * 4 + channel])
                    darkInk += max(background - pixel, 0)
                    lightInk += max(pixel - background, 0)
                }
            }
        }
        let lightText = lightInk > darkInk
        var normalization = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let fraction = min(max(Double(y - topRow) / Double(bottomRow - topRow), 0), 1)
            for x in 0..<width {
                for channel in 0..<3 {
                    let top = Double(pixels[(topRow * width + x) * 4 + channel])
                    let bottom = Double(pixels[(bottomRow * width + x) * 4 + channel])
                    let background = top + (bottom - top) * fraction
                    // Dodge recovers black-text coverage with C / B. Burn recovers
                    // white-text coverage with 1 - (1 - C) / (1 - B).
                    normalization[(y * width + x) * 4 + channel] = UInt8(min(max(255 - background, 1), 254))
                }
            }
        }
        guard
            let provider = CGDataProvider(data: Data(normalization) as CFData),
            let normalized = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return nil
        }
        let wallpaper = CIImage(cgImage: source.wallpaper).clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius * source.scale])
        guard let image = context.createCGImage(wallpaper, from: source.crop) else {
            return nil
        }
        return Output(wallpaper: image, normalization: normalized, lightText: lightText)
    }
}

/// Keeps the system foreground live while replacing its background with blurred wallpaper.
/// Private compositing support is isolated here and fails closed when unavailable.
final class MenuBarWallpaperBlurView: NSVisualEffectView {
    private typealias SetSublevel = @convention(c) (Int32, UInt32, Int32) -> Int32
    private static let setSublevel: SetSublevel? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetWindowSubLevel") else {
            return nil
        }
        return unsafeBitCast(symbol, to: SetSublevel.self)
    }()

    static let isSupported: Bool = {
        guard
            let type = NSClassFromString("CABackdropLayer") as? CALayer.Type,
            setSublevel != nil,
            NSVisualEffectView.accessInstanceVariablesDirectly,
            class_getInstanceVariable(NSVisualEffectView.self, "_clear") != nil
        else {
            return false
        }
        let layer = type.init()
        return ["setWindowServerAware:", "setScale:", "setAllowsInPlaceFiltering:"].allSatisfy {
            layer.responds(to: NSSelectorFromString($0))
        } && ["colorBrightness", "colorBurnBlendMode", "screenBlendMode", "colorDodgeBlendMode", "multiplyBlendMode"].allSatisfy {
            makeFilter($0) != nil
        }
    }()

    private static func makeFilter(_ type: String) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") else {
            return nil
        }
        let object: AnyObject = filterClass
        let selector = NSSelectorFromString("filterWithType:")
        guard object.responds(to: selector) else {
            return nil
        }
        return object.perform(selector, with: type)?.takeUnretainedValue() as? NSObject
    }

    private let container = CALayer()
    private let normalization = CALayer()
    private let wallpaper = CALayer()
    private let clipping = CAShapeLayer()
    private var backdrop: CALayer?
    private var identityFilter: NSObject?
    private var dodgeFilter: NSObject?
    private var burnFilter: NSObject?
    private var multiplyFilter: NSObject?
    private var screenFilter: NSObject?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var sourceID: UUID?
    private var renderedRadius: Double?
    private var changedSublevel = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        guard Self.isSupported, let type = NSClassFromString("CABackdropLayer") as? CALayer.Type else {
            return
        }
        state = .active
        blendingMode = .behindWindow
        material = .menu
        setValue(true, forKey: "clear")
        wantsLayer = true
        let backdrop = type.init()
        backdrop.setValue(true, forKey: "windowServerAware")
        backdrop.setValue(1.0, forKey: "scale")
        backdrop.setValue(false, forKey: "allowsInPlaceFiltering")
        identityFilter = Self.makeFilter("colorBrightness")
        identityFilter?.setValue(0.0, forKey: "inputAmount")
        dodgeFilter = Self.makeFilter("colorDodgeBlendMode")
        burnFilter = Self.makeFilter("colorBurnBlendMode")
        multiplyFilter = Self.makeFilter("multiplyBlendMode")
        screenFilter = Self.makeFilter("screenBlendMode")
        container.sublayers = [backdrop, normalization, wallpaper]
        container.mask = clipping
        layer?.addSublayer(container)
        self.backdrop = backdrop
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(source: MenuBarWallpaperBlurSource?, radius: Double, shape: CGPath) {
        clipping.path = shape
        guard
            let source, radius > 0, radius.isFinite, radius <= 30, backdrop != nil,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        else {
            suspend()
            return
        }
        guard sourceID != source.id || renderedRadius != radius else {
            return
        }
        sourceID = source.id
        renderedRadius = radius
        generation += 1
        let expectedGeneration = generation
        task?.cancel()
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let output = MenuBarWallpaperBlurRenderer.render(source, radius: radius)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.generation == expectedGeneration else { return }
                guard
                    let output, let window = self.window,
                    Self.setSublevel?(CGSMainConnectionID(), UInt32(window.windowNumber), -1) == 0
                else {
                    self.suspend()
                    return
                }
                self.changedSublevel = true
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.backdrop?.filters = [self.identityFilter].compactMap { $0 }
                self.normalization.compositingFilter = output.lightText ? self.burnFilter : self.dodgeFilter
                self.wallpaper.compositingFilter = output.lightText ? self.screenFilter : self.multiplyFilter
                self.normalization.contents = output.normalization
                self.wallpaper.contents = output.wallpaper
                self.isHidden = false
                self.needsLayout = true
                CATransaction.commit()
            }
        }
    }

    func suspend() {
        generation += 1
        task?.cancel()
        task = nil
        sourceID = nil
        renderedRadius = nil
        isHidden = true
        normalization.contents = nil
        wallpaper.contents = nil
        if changedSublevel, let window {
            _ = Self.setSublevel?(CGSMainConnectionID(), UInt32(window.windowNumber), 0)
        }
        changedSublevel = false
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [container, backdrop, normalization, wallpaper, clipping].compactMap({ $0 }) {
            layer.frame = bounds
        }
        CATransaction.commit()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            suspend()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit {
        task?.cancel()
    }
}
