//
//  MenuBarAppearanceConfigurationV2.swift
//  Ice
//

import CoreGraphics
import Foundation

struct MenuBarAppearanceConfigurationV2: Hashable {
    var staticConfiguration: MenuBarAppearancePartialConfiguration
    var shapeKind: MenuBarShapeKind
    var fullShapeInfo: MenuBarFullShapeInfo
    var splitShapeInfo: MenuBarSplitShapeInfo
    var isInset: Bool

    var hasRoundedShape: Bool {
        switch shapeKind {
        case .none: false
        case .full: fullShapeInfo.hasRoundedShape
        case .split: splitShapeInfo.hasRoundedShape
        }
    }

    var current: MenuBarAppearancePartialConfiguration {
        staticConfiguration
    }
}

// MARK: Default Configuration
extension MenuBarAppearanceConfigurationV2 {
    static let defaultConfiguration = MenuBarAppearanceConfigurationV2(
        staticConfiguration: .defaultConfiguration,
        shapeKind: .none,
        fullShapeInfo: .default,
        splitShapeInfo: .default,
        isInset: true
    )
}

extension MenuBarAppearanceConfigurationV2: Codable {
    private enum CodingKeys: CodingKey {
        case lightModeConfiguration
        case darkModeConfiguration
        case staticConfiguration
        case shapeKind
        case fullShapeInfo
        case splitShapeInfo
        case isInset
        case isDynamic
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Preserve the active legacy appearance once; future system theme changes
        // no longer select a different set of user customizations.
        let isDynamic = try container.decodeIfPresent(Bool.self, forKey: .isDynamic) ?? false
        let activeKey: CodingKeys = SystemAppearance.current == .dark ? .darkModeConfiguration : .lightModeConfiguration
        let configurationKey: CodingKeys = isDynamic ? activeKey : .staticConfiguration
        try self.init(
            staticConfiguration: container.decodeIfPresent(MenuBarAppearancePartialConfiguration.self, forKey: configurationKey) ?? .defaultConfiguration,
            shapeKind: container.decodeIfPresent(MenuBarShapeKind.self, forKey: .shapeKind) ?? Self.defaultConfiguration.shapeKind,
            fullShapeInfo: container.decodeIfPresent(MenuBarFullShapeInfo.self, forKey: .fullShapeInfo) ?? Self.defaultConfiguration.fullShapeInfo,
            splitShapeInfo: container.decodeIfPresent(MenuBarSplitShapeInfo.self, forKey: .splitShapeInfo) ?? Self.defaultConfiguration.splitShapeInfo,
            isInset: container.decodeIfPresent(Bool.self, forKey: .isInset) ?? Self.defaultConfiguration.isInset
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(staticConfiguration, forKey: .staticConfiguration)
        try container.encode(shapeKind, forKey: .shapeKind)
        try container.encode(fullShapeInfo, forKey: .fullShapeInfo)
        try container.encode(splitShapeInfo, forKey: .splitShapeInfo)
        try container.encode(isInset, forKey: .isInset)
        try container.encode(false, forKey: .isDynamic)
    }
}

// MARK: - MenuBarAppearancePartialConfiguration

struct MenuBarAppearancePartialConfiguration: Hashable {
    var hasShadow: Bool
    var hasBorder: Bool
    var borderColor: CGColor
    var borderWidth: Double
    var tintKind: MenuBarTintKind
    var tintColor: CGColor
    var tintGradient: CustomGradient
}

// MARK: Default Partial Configuration
extension MenuBarAppearancePartialConfiguration {
    static let defaultConfiguration = MenuBarAppearancePartialConfiguration(
        hasShadow: false,
        hasBorder: false,
        borderColor: .black,
        borderWidth: 1,
        tintKind: .none,
        tintColor: .black,
        tintGradient: .defaultMenuBarTint
    )
}

// MARK: MenuBarAppearancePartialConfiguration: Codable
extension MenuBarAppearancePartialConfiguration: Codable {
    private enum CodingKeys: CodingKey {
        case hasShadow
        case hasBorder
        case borderColor
        case borderWidth
        case shapeKind
        case fullShapeInfo
        case splitShapeInfo
        case tintKind
        case tintColor
        case tintGradient
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            hasShadow: container.decodeIfPresent(Bool.self, forKey: .hasShadow) ?? Self.defaultConfiguration.hasShadow,
            hasBorder: container.decodeIfPresent(Bool.self, forKey: .hasBorder) ?? Self.defaultConfiguration.hasBorder,
            borderColor: container.decodeIfPresent(CodableColor.self, forKey: .borderColor)?.cgColor ?? Self.defaultConfiguration.borderColor,
            borderWidth: container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? Self.defaultConfiguration.borderWidth,
            tintKind: container.decodeIfPresent(MenuBarTintKind.self, forKey: .tintKind) ?? Self.defaultConfiguration.tintKind,
            tintColor: container.decodeIfPresent(CodableColor.self, forKey: .tintColor)?.cgColor ?? Self.defaultConfiguration.tintColor,
            tintGradient: container.decodeIfPresent(CustomGradient.self, forKey: .tintGradient) ?? Self.defaultConfiguration.tintGradient
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasShadow, forKey: .hasShadow)
        try container.encode(hasBorder, forKey: .hasBorder)
        try container.encode(CodableColor(cgColor: borderColor), forKey: .borderColor)
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encode(tintKind, forKey: .tintKind)
        try container.encode(CodableColor(cgColor: tintColor), forKey: .tintColor)
        try container.encode(tintGradient, forKey: .tintGradient)
    }
}
