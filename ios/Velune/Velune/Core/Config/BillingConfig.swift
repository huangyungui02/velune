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

    // RevenueCat product IDs plus semantic fallbacks from subscription.md.
    private static let awakenProductTokens: Set<String> = [
        "prod2a5ae70e22",
        "awaken",
    ]
    private static let depthProductTokens: Set<String> = [
        "prod2454840db9",
        "depth",
    ]

    static var revenueCatPublicSDKKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvePlan(
        isEntitlementActive: Bool,
        productId: String?,
        dailyCredits: Int?
    ) -> BillingPlan {
        guard isEntitlementActive else { return .free }

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

        return .depth
    }

    static func resolvePlan(productIdentifiers: [String]) -> BillingPlan? {
        let normalized = productIdentifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if normalized.contains(where: matchesDepthProduct) {
            return .depth
        }
        if normalized.contains(where: matchesAwakenProduct) {
            return .awaken
        }

        return nil
    }

    private static func matchesAwakenProduct(_ productId: String) -> Bool {
        awakenProductTokens.contains(where: { token in
            productId == token || productId.contains(token)
        })
    }

    private static func matchesDepthProduct(_ productId: String) -> Bool {
        depthProductTokens.contains(where: { token in
            productId == token || productId.contains(token)
        })
    }
}
