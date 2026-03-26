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

    var apiLanguageCode: String {
        switch self {
        case .english:
            "en"
        case .simplifiedChinese:
            "chs"
        }
    }

    func applyAsPreferredLanguage() {
        UserDefaults.standard.set([appleLanguageIdentifier], forKey: "AppleLanguages")
    }
}

enum AppLinks {
    static let terms = URL(string: "https://velune.echoversa.com/terms")!

    static let privacy = URL(string: "https://velune.echoversa.com/privacy")!

    static var contactEmail: URL {
        URL(string: "mailto:velune@echoversa.com")!
    }
}
