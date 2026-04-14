import Foundation

enum BillingPlan: String, Equatable {
    case free
    case awaken
    case depth

    var dailyCredits: Int {
        switch self {
        case .free:
            BillingConfig.freeDailyCredits
        case .awaken:
            BillingConfig.awakenDailyCredits
        case .depth:
            BillingConfig.depthDailyCredits
        }
    }

    var localizedNameKey: String {
        switch self {
        case .free:
            "settings.billing.plan.free"
        case .awaken:
            "settings.billing.plan.awaken"
        case .depth:
            "settings.billing.plan.depth"
        }
    }
}

enum BillingConfig {
    static let freeDailyCredits = 10
    static let awakenDailyCredits = 50
    static let depthDailyCredits = 100

    static var revenueCatPublicSDKKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvePlan(
        productId: String?,
        dailyCredits: Int?
    ) -> BillingPlan {
        if let productId, let matched = resolvePlan(productIdentifiers: [productId]) {
            return matched
        }

        if let dailyCredits {
            switch dailyCredits {
            case awakenDailyCredits:
                return .awaken
            case depthDailyCredits...:
                return .depth
            case (freeDailyCredits + 1)..<depthDailyCredits:
                return .awaken
            default:
                break
            }
        }

        return .free
    }

    static func resolvePlan(productIdentifiers: [String]) -> BillingPlan? {
        let normalized = productIdentifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if normalized.contains(where: { $0.contains("depth") }) {
            return .depth
        }
        if normalized.contains(where: { $0.contains("awaken") }) {
            return .awaken
        }

        return nil
    }
}
