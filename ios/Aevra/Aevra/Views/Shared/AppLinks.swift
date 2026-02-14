import Foundation

enum AppLocale {
    static var isChineseLanguage: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }
}

enum AppLinks {
    static var terms: URL {
        URL(string: AppLocale.isChineseLanguage
            ? "https://aevra.echoversa.com/zh/terms"
            : "https://aevra.echoversa.com/terms")!
    }

    static var privacy: URL {
        URL(string: AppLocale.isChineseLanguage
            ? "https://aevra.echoversa.com/zh/privacy"
            : "https://aevra.echoversa.com/privacy")!
    }

    static var supportEmail: URL {
        URL(string: "mailto:support@resona.app")!
    }

    static var privacyEmail: URL {
        URL(string: "mailto:privacy@resona.app?subject=Account%20Deletion%20Request")!
    }
}
