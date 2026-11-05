//
//  SettingsContentLayout.swift
//  Ice
//

import SwiftUI

enum SettingsContentLayout {
    static let maximumWidth: CGFloat = 720
    static let horizontalPadding: CGFloat = 20
    static let coordinateSpace = "settingsDetail"
}

struct SettingsContentLeadingKey: PreferenceKey {
    static let defaultValue = SettingsContentLayout.horizontalPadding

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SettingsContentScrolledKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
