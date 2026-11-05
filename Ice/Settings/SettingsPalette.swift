//
//  SettingsPalette.swift
//  Ice
//

import SwiftUI

enum SettingsPalette {
    static let lightSidebar = Color(.sRGB, red: 227 / 255, green: 229 / 255, blue: 231 / 255)

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(.sRGB, red: 239 / 255, green: 241 / 255, blue: 243 / 255)
            : Color(nsColor: .windowBackgroundColor)
    }

    static func groupBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(.sRGB, red: 235 / 255, green: 237 / 255, blue: 239 / 255)
            : Color(nsColor: .windowBackgroundColor)
    }
}
