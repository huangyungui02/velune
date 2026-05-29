import Foundation
import RevenueCat

extension SubscriptionManager {
    func resolveRevenueCatActiveProductId(_ customerInfo: CustomerInfo) -> String? {
        let products = Array(customerInfo.activeSubscriptions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !products.isEmpty else { return nil }
        if let depth = products.first(where: BillingConfig.isDepthProduct) {
            return depth
        }
        return products.sorted().first
    }

    func isRestoreStateConsistent(revenueCatProductId: String) -> Bool {
        guard isPremium else { return false }
        guard let revenueCatPlan = BillingConfig.resolvePlan(productIdentifiers: [revenueCatProductId]) else {
            return false
        }
        return currentPlan == revenueCatPlan
    }

    func resolveRevenueCatBoundUserId(_ customerInfo: CustomerInfo) -> String? {
        if let appUserId = normalizeUUID(Purchases.shared.appUserID) {
            return appUserId
        }
        return normalizeUUID(customerInfo.originalAppUserId)
    }

    func requireAuthenticatedRevenueCatUserId() throws -> String {
        guard isRevenueCatAvailable else {
            throw NSError(
                domain: "RevenueCat",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "billing.error.missingRevenueCatKey")
                ]
            )
        }

        guard let currentUserId = AuthManager.shared.currentUserId?.uuidString else {
            throw AppError.unauthenticated
        }

        return currentUserId.lowercased()
    }

    private func normalizeUUID(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: normalized) != nil else {
            return nil
        }
        return normalized.lowercased()
    }
}
