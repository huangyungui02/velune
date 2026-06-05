import Foundation
import OSLog
import RevenueCat
import Supabase

extension SubscriptionManager {
    func apply(_ payload: BillingSyncResponse) {
        let expiration = BillingDateParser.parse(payload.expirationAt)
        let hasProduct = payload.productId != nil
        let notExpired = expiration.map { $0 > Date() } ?? true
        let resolvedPlan = BillingConfig.resolvePlan(productId: payload.productId)
        let hasActiveSubscription = hasProduct && notExpired

        currentPlan = hasActiveSubscription ? resolvedPlan : .free
        isPremium = hasActiveSubscription
        entitlementExpiresAt = expiration
    }

    func applyCustomerInfo(_ info: CustomerInfo) {
        guard !info.entitlements.active.isEmpty else {
            isPremium = false
            currentPlan = .free
            return
        }

        isPremium = true
        if let resolved = BillingConfig.resolvePlan(productIdentifiers: Array(info.activeSubscriptions)) {
            currentPlan = resolved
        } else if currentPlan == .free {
            currentPlan = .depth
        }
    }

    func syncBillingStateQuietly() async {
        let synced = await syncBillingState(maxAttempts: 5, expectPremium: isPremium)
        if !synced {
            logger.notice("billing state not yet reconciled after retries")
        }
    }

    func syncBillingState(maxAttempts: Int, expectPremium: Bool) async -> Bool {
        for attempt in 1 ... maxAttempts {
            do {
                let response = try await callBillingSync()
                apply(response)
                updateLastErrorMessage(nil)
                if !expectPremium || isPremium {
                    return true
                }
            } catch {
                updateLastErrorMessage(error.localizedDescription)
                logger.error("billing sync attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        return false
    }

    func syncRestorePurchaseOnServer() async throws {
        let supabase = try Backend.requireSupabase()
        let response: RestorePurchaseResponse = try await supabase.functions.invoke("restore-purchase")

        guard response.ok else {
            throw NSError(
                domain: "RestorePurchase",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "restore-purchase returned invalid response"]
            )
        }
    }

    private func callBillingSync() async throws -> BillingSyncResponse {
        let supabase = try Backend.requireSupabase()
        let rows: [BillingSyncResponse] = try await supabase
            .rpc("get_user_subscription_state")
            .execute()
            .value

        guard let state = rows.first else {
            throw NSError(
                domain: "BillingRPC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Subscription state is empty"]
            )
        }

        return state
    }
}
