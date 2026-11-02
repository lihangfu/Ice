//
//  AppLanguageModifier.swift
//  Ice
//

import SwiftUI

/// Keeps each SwiftUI hosting surface in sync with the language preference.
struct AppLanguageModifier: ViewModifier {
    @ObservedObject var manager: GeneralSettingsManager

    func body(content: Content) -> some View {
        content.environment(\.locale, manager.appLanguage.locale)
    }
}
