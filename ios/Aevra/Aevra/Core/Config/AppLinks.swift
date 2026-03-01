import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh"

    static let storageKey = "app.language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    var websitePathPrefix: String {
        switch self {
        case .english:
            ""
        case .simplifiedChinese:
            "/zh"
        }
    }

    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
            ? .simplifiedChinese
            : .english
    }

    static var current: AppLanguage {
        guard
            let rawValue = UserDefaults.standard.string(forKey: storageKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return systemDefault
        }
        return language
    }

    var appleLanguageIdentifier: String {
        switch self {
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    func applyAsPreferredLanguage() {
        UserDefaults.standard.set([appleLanguageIdentifier], forKey: "AppleLanguages")
    }
}

enum AppLinks {
    static var terms: URL {
        URL(string: "https://aevra.echoversa.com\(AppLanguage.current.websitePathPrefix)/terms")!
    }

    static var privacy: URL {
        URL(string: "https://aevra.echoversa.com\(AppLanguage.current.websitePathPrefix)/privacy")!
    }

    static var contactEmail: URL {
        URL(string: "mailto:aevra@echoversa.com")!
    }
}
