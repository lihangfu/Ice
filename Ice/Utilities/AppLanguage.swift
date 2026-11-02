//
//  AppLanguage.swift
//  Ice
//

import Foundation

/// The language preference used by the app's interface.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    static var current: AppLanguage {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return .system
        }
        return load(bundleIdentifier: bundleIdentifier)
    }

    var locale: Locale {
        let regionalLocale = Locale.current
        var components = Locale.Components(locale: regionalLocale)
        components.languageComponents = Locale.Language.Components(identifier: resolvedIdentifier())
        components.languageComponents.region = regionalLocale.region
        components.hourCycle = regionalLocale.hourCycle
        return Locale(components: components)
    }

    var title: String {
        switch self {
        case .system: "System Default"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    func resolvedIdentifier(
        systemLanguages: [String] = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[Defaults.Key.appleLanguages.rawValue] as? [String] ?? []
    ) -> String {
        if self != .system {
            return rawValue
        }
        // Ignore the app override when returning to the system language.
        let supported = [Self.english.rawValue, Self.simplifiedChinese.rawValue]
        return Bundle.preferredLocalizations(from: supported, forPreferences: systemLanguages).first ?? Self.english.rawValue
    }

    func localizedString(_ value: String.LocalizationValue, bundle: Bundle = .main) -> String {
        let identifier = resolvedIdentifier()
        let localizedBundle = bundle.url(forResource: identifier, withExtension: "lproj")
            .flatMap(Bundle.init(url:)) ?? bundle
        return String(localized: value, bundle: localizedBundle, locale: locale)
    }

    static func load(from defaults: UserDefaults = .standard, bundleIdentifier: String) -> AppLanguage {
        // Read only the app's domain. The global AppleLanguages value means
        // following the system, rather than an explicit app preference.
        guard
            let languages = defaults.persistentDomain(forName: bundleIdentifier)?[Defaults.Key.appleLanguages.rawValue] as? [String],
            !languages.isEmpty
        else {
            return .system
        }
        let supported = [english.rawValue, simplifiedChinese.rawValue]
        let language = Bundle.preferredLocalizations(from: supported, forPreferences: languages).first
        return language.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    func save(to defaults: UserDefaults = .standard) {
        if self == .system {
            defaults.removeObject(forKey: Defaults.Key.appleLanguages.rawValue)
        } else {
            defaults.set([rawValue], forKey: Defaults.Key.appleLanguages.rawValue)
        }
    }
}
