import Foundation

enum BillingPlan: String, Equatable {
    case free
    case awaken
    case depth

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
    static var revenueCatPublicSDKKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvePlan(productId: String?) -> BillingPlan {
        if let productId, let matched = resolvePlan(productIdentifiers: [productId]) {
            return matched
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
