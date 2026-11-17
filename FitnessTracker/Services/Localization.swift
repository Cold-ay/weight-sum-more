import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: L10n.text("Follow system")
        case .english: "English"
        case .traditionalChinese: "繁體中文"
        }
    }

    var identifier: String {
        if self != .system { return rawValue }
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hant" : "en"
    }
}

enum L10n {
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system
    }

    static var locale: Locale { Locale(identifier: language.identifier) }

    static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func date(_ date: Date, includeTime: Bool = false) -> String {
        let style = Date.FormatStyle(date: .abbreviated, time: includeTime ? .shortened : .omitted)
        return date.formatted(style.locale(locale))
    }
}

extension String {
    var localized: String { L10n.text(self) }
}
