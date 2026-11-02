import Foundation

private enum TestFailure: Error {
    case failed(String)
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure.failed(message)
    }
}

@main
struct LocalizationTests {
    static func main() throws {
        let domain = "Ice.LocalizationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else {
            throw TestFailure.failed("Could not create isolated preferences")
        }
        defer { defaults.removePersistentDomain(forName: domain) }

        // An inherited language must not look like an explicit app override.
        let globalLanguages = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        try expect(AppLanguage.load(from: defaults, bundleIdentifier: domain) == .system, "New preferences must follow the system")
        defaults.set(true, forKey: "UnrelatedSetting")

        for language in [AppLanguage.english, .simplifiedChinese] {
            language.save(to: defaults)
            try expect(defaults.stringArray(forKey: "AppleLanguages") == [language.rawValue], "Language override was not saved")
            defaults.synchronize()
            guard let reloaded = UserDefaults(suiteName: domain) else {
                throw TestFailure.failed("Could not reload preferences")
            }
            try expect(AppLanguage.load(from: reloaded, bundleIdentifier: domain) == language, "Language override did not survive reloading")
        }

        // macOS can store regional variants for per-app language preferences.
        defaults.set(["en-GB"], forKey: "AppleLanguages")
        try expect(AppLanguage.load(from: defaults, bundleIdentifier: domain) == .english, "Regional English was not recognized")
        defaults.set(["zh-Hans-CN"], forKey: "AppleLanguages")
        try expect(AppLanguage.load(from: defaults, bundleIdentifier: domain) == .simplifiedChinese, "Regional Simplified Chinese was not recognized")

        AppLanguage.system.save(to: defaults)
        try expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil, "System Default must remove the app override")
        try expect(AppLanguage.load(from: defaults, bundleIdentifier: domain) == .system, "System Default did not persist")
        try expect(defaults.bool(forKey: "UnrelatedSetting"), "Language selection changed another preference")
        let currentGlobalLanguages = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        try expect(globalLanguages == currentGlobalLanguages, "Language selection changed the system language")

        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let resources = root.appendingPathComponent("Ice/Resources", isDirectory: true)
        let english = try readStrings(resources.appendingPathComponent("en.lproj/Localizable.strings"))
        let chinese = try readStrings(resources.appendingPathComponent("zh-Hans.lproj/Localizable.strings"))
        try expect(Set(english.keys) == Set(chinese.keys), "English and Chinese keys differ")
        for (key, translation) in chinese {
            try expect(!translation.isEmpty, "Empty Chinese translation: \(key)")
            try expect(placeholders(in: key) == placeholders(in: translation), "Format placeholders differ: \(key)")
        }

        guard let chineseBundle = Bundle(url: resources.appendingPathComponent("zh-Hans.lproj")) else {
            throw TestFailure.failed("Could not load the Chinese bundle")
        }
        try expect(chineseBundle.localizedString(forKey: "Language", value: nil, table: nil) == "语言", "Language label is not translated")
        try expect(chineseBundle.localizedString(forKey: "General", value: nil, table: nil) == "通用", "Settings navigation is not translated")
        let seconds = chineseBundle.localizedString(forKey: "%@ seconds", value: nil, table: nil)
        try expect(String(format: seconds, "0.5") == "0.5 秒", "Fractional seconds are not translated")
        let showSection = chineseBundle.localizedString(forKey: "Show the %@ Section", value: nil, table: nil)
        try expect(String(format: showSection, "隐藏") == "显示隐藏分区", "Context menu interpolation is not translated")

        try expect(AppLanguage.system.resolvedIdentifier(systemLanguages: ["zh-Hans-CN"]) == "zh-Hans", "System Default ignored Chinese system preferences")
        try expect(AppLanguage.system.resolvedIdentifier(systemLanguages: ["en-GB"]) == "en", "System Default ignored English system preferences")
        try expect(AppLanguage.system.resolvedIdentifier(systemLanguages: ["fr"]) == "en", "Unsupported system languages must fall back to English")
        try expect(AppLanguage.english.resolvedIdentifier(systemLanguages: ["zh-Hans"]) == "en", "Explicit English must override the system language")

        try expect(Locale.current.region?.identifier == "GB", "Regional test fixture must use the British locale")
        for language in AppLanguage.allCases {
            try expect(language.locale.region == Locale.current.region, "Changing language must preserve the user's region")
            try expect(language.locale.hourCycle == Locale.current.hourCycle, "Changing language must preserve the user's hour cycle")
        }
        let date = Date(timeIntervalSince1970: 1763861400)
        let format = Date.FormatStyle(date: .abbreviated, time: .standard)
        try expect(
            date.formatted(format.locale(AppLanguage.english.locale)) == date.formatted(format.locale(Locale.current)),
            "English language selection must preserve British date and time formatting"
        )

        let fixtureURL = FileManager.default.temporaryDirectory.appendingPathComponent("IceLocalizationTests.\(UUID().uuidString).bundle")
        defer { try? FileManager.default.removeItem(at: fixtureURL) }
        let fixtureResources = fixtureURL.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: fixtureResources, withIntermediateDirectories: true)
        for identifier in ["en", "zh-Hans"] {
            try FileManager.default.copyItem(
                at: resources.appendingPathComponent("\(identifier).lproj"),
                to: fixtureResources.appendingPathComponent("\(identifier).lproj")
            )
        }
        let info = ["CFBundleIdentifier": domain, "CFBundleDevelopmentRegion": "en"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: fixtureURL.appendingPathComponent("Contents/Info.plist"))
        guard let fixture = Bundle(url: fixtureURL) else {
            throw TestFailure.failed("Could not load the runtime localization fixture")
        }
        // Reuse one bundle and process to catch launch-time localization caching.
        for (language, label) in [(AppLanguage.english, "Language"), (.simplifiedChinese, "语言"), (.english, "Language")] {
            language.save(to: defaults)
            let selected = AppLanguage.load(from: defaults, bundleIdentifier: domain)
            try expect(selected.localizedString("Language", bundle: fixture) == label, "Language did not change immediately in the current process")
        }
        let interval = "0.5"
        try expect(AppLanguage.simplifiedChinese.localizedString("\(interval) seconds", bundle: fixture) == "0.5 秒", "Runtime interpolation did not use Chinese")
        try expect(AppLanguage.english.localizedString("Ice Settings…", bundle: fixture) == "Ice Settings…", "English context menu did not refresh")
        try expect(AppLanguage.simplifiedChinese.localizedString("Ice Settings…", bundle: fixture) == "Ice 设置…", "Chinese context menu did not refresh")
        print("PASS: immediate English → Chinese → English switching, context menus, persistence, system fallback, British region/date/time preferences, \(chinese.count) translation keys, and format placeholders")
    }

    private static func readStrings(_ url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        guard let strings = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            throw TestFailure.failed("Invalid strings table: \(url.path)")
        }
        return strings
    }

    private static func placeholders(in value: String) -> [String] {
        value.components(separatedBy: "%@").dropFirst().map { _ in "%@" }
    }
}
