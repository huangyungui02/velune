import Foundation

enum AppLanguage {
    case english
    case simplifiedChinese

    static var current: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
            ? .simplifiedChinese
            : .english
    }

    var apiLanguageCode: String {
        switch self {
        case .english:
            "en"
        case .simplifiedChinese:
            "zh"
        }
    }
}

enum AppLinks {
    static let terms = URL(string: "https://velune.echoversa.com/terms")!

    static let privacy = URL(string: "https://velune.echoversa.com/privacy")!

    static var contactEmail: URL {
        URL(string: "mailto:velune@echoversa.com")!
    }
}
