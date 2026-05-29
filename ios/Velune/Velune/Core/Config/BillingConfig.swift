import Foundation

enum BillingPlan: String, Equatable {
    case free
    case depth

    var localizedNameKey: String {
        switch self {
        case .free:
            "settings.billing.plan.free"
        case .depth:
            "settings.billing.plan.depth"
        }
    }
}

enum BillingConfig {
    static let depthAnnualProductId = "com.echoversa.velune.depth.annual"
    static let depthMonthlyProductId = "com.echoversa.velune.depth.monthly"

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

        if normalized.contains(where: isDepthProduct) {
            return .depth
        }

        return nil
    }

    static func isDepthProduct(_ productId: String) -> Bool {
        switch productId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case depthAnnualProductId, depthMonthlyProductId:
            true
        default:
            false
        }
    }
}
