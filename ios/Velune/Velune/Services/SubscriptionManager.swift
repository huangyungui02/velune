import Foundation
import OSLog
import RevenueCat
import Supabase

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    private let logger = AppLogger.billing

    var isPremium = false
    var credits = BillingConfig.freeMonthlyCredits
    var monthlyPriceText = BillingConfig.premiumMonthlyPriceUSD
    var entitlementExpiresAt: Date?

    var isRevenueCatAvailable = false
    var isSyncing = false
    var isLoadingOfferings = false
    var isPurchasing = false
    var isRestoring = false

    private(set) var lastErrorMessage: String?

    private var hasConfiguredRevenueCat = false
    private var activeAppUserID: String?
    private var monthlyPackage: Package?
    private var currentBillingUserID: UUID?
    private var pendingForcedRefresh = false
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func bootstrap(userId: UUID?) async {
        currentBillingUserID = userId

        configureRevenueCatIfNeeded()

        guard userId != nil else {
            await signOutRevenueCatIfNeeded()
            resetToFreeDefaults()
            return
        }

        await refreshOfferings()
        await refreshBillingState()
    }

    func refreshBillingState(force: Bool = false) async {
        if isSyncing {
            if force {
                pendingForcedRefresh = true
            }
            return
        }

        while true {
            isSyncing = true
            _ = await syncBillingState(maxAttempts: 1, expectPremium: false)
            isSyncing = false

            if pendingForcedRefresh {
                pendingForcedRefresh = false
                continue
            }

            return
        }
    }

    func purchasePremium() async throws {
        guard !AuthManager.shared.isAnonymous else {
            throw NSError(
                domain: "Billing",
                code: -4,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "billing.error.signInRequiredForPurchase")
                ]
            )
        }

        let currentUserId = try requireAuthenticatedRevenueCatUserId()
        try await ensureRevenueCatIdentityMatches(userId: currentUserId)

        if monthlyPackage == nil {
            await refreshOfferings()
        }

        guard let package = monthlyPackage else {
            let message = lastErrorMessage ?? String(localized: "billing.error.offeringUnavailable")
            throw NSError(
                domain: "RevenueCat",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await Purchases.shared.purchase(package: package)
        logger.notice("purchase completed for appUserID=\(Purchases.shared.appUserID, privacy: .public)")
        applyCustomerInfo(result.customerInfo)
        Task { await syncBillingStateQuietly() }
    }

    func restorePurchases() async throws {
        let currentUserId = try requireAuthenticatedRevenueCatUserId()
        try await ensureRevenueCatIdentityMatches(userId: currentUserId)
        let infoBeforeRestore = try await Purchases.shared.customerInfo()
        try ensureRestoreAccountMatches(infoBeforeRestore, expectedUserId: currentUserId)

        isRestoring = true
        defer { isRestoring = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        try ensureRestoreAccountMatches(customerInfo, expectedUserId: currentUserId)
        applyCustomerInfo(customerInfo)
        await syncBillingStateQuietly()
    }

    private func configureRevenueCatIfNeeded() {
        guard !hasConfiguredRevenueCat else { return }

        let apiKey = BillingConfig.revenueCatPublicSDKKey
        guard !apiKey.isEmpty else {
            isRevenueCatAvailable = false
            logger.notice("RevenueCat disabled: missing public SDK key")
            return
        }

        #if DEBUG
            Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: apiKey)
        hasConfiguredRevenueCat = true
        isRevenueCatAvailable = true
    }

    private func syncRevenueCatIdentity(userId: String) async throws {
        guard isRevenueCatAvailable else { return }
        if activeAppUserID == userId { return }

        _ = try await Purchases.shared.logIn(userId)
        activeAppUserID = userId
    }

    private func ensureRevenueCatIdentityMatches(userId: String) async throws {
        try await syncRevenueCatIdentity(userId: userId)
        let currentRCUserId = Purchases.shared.appUserID
        if currentRCUserId != userId {
            let message = "RevenueCat appUserID mismatch. expected=\(userId), current=\(currentRCUserId)"
            logger.error("\(message, privacy: .public)")
            throw NSError(
                domain: "RevenueCat",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func signOutRevenueCatIfNeeded() async {
        guard isRevenueCatAvailable else { return }
        activeAppUserID = nil

        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            logger.notice("RevenueCat logout ignored: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshOfferings() async {
        guard isRevenueCatAvailable else {
            monthlyPackage = nil
            applyDefaultMonthlyPrice()
            return
        }
        if isLoadingOfferings { return }

        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let package = selectPackage(from: offerings)
            monthlyPackage = package
            if let package {
                monthlyPriceText = package.storeProduct.localizedPriceString + " " + String(localized: "billing.price.perMonthSuffix")
                lastErrorMessage = nil
                logger.notice("offering resolved: \(package.storeProduct.productIdentifier, privacy: .public)")
            } else {
                applyDefaultMonthlyPrice()
                lastErrorMessage =
                    "RevenueCat offerings are empty. current=\(offerings.current?.identifier ?? "nil"), all=\(Array(offerings.all.keys))"
                logger.error("offering unavailable: \(self.lastErrorMessage ?? "", privacy: .public)")
            }
        } catch {
            monthlyPackage = nil
            applyDefaultMonthlyPrice()
            lastErrorMessage = "RevenueCat offerings fetch failed: \(error.localizedDescription)"
            logger.error("offerings fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resetToFreeDefaults() {
        isPremium = false
        credits = BillingConfig.freeMonthlyCredits
        applyDefaultMonthlyPrice()
        entitlementExpiresAt = nil
        pendingForcedRefresh = false
        currentBillingUserID = nil
    }

    private func apply(_ payload: BillingSyncResponse) {
        isPremium = payload.isEntitlementActive
        credits = payload.credits
        entitlementExpiresAt = parseISODate(payload.entitlementExpiresAt)
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        if !info.entitlements.active.isEmpty {
            isPremium = true
        }
    }

    private func syncBillingStateQuietly() async {
        let synced = await syncBillingState(maxAttempts: 5, expectPremium: isPremium)
        if !synced {
            logger.notice("billing state not yet reconciled after retries")
        }
    }

    private func syncBillingState(maxAttempts: Int, expectPremium: Bool) async -> Bool {
        for attempt in 1 ... maxAttempts {
            do {
                let response = try await callBillingSync()
                apply(response)
                lastErrorMessage = nil
                if !expectPremium || response.isEntitlementActive {
                    return true
                }
            } catch {
                lastErrorMessage = error.localizedDescription
                logger.error("billing sync attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        return false
    }

    private func callBillingSync() async throws -> BillingSyncResponse {
        let supabase = try Backend.requireSupabase()
        let rows: [BillingSyncResponse] = try await supabase
            .rpc("get_user_credit_state")
            .execute()
            .value

        guard let state = rows.first else {
            throw NSError(
                domain: "BillingRPC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Billing state is empty"]
            )
        }

        return state
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        let timezoneNormalized = normalized.hasSuffix("+00")
            ? String(normalized.dropLast(3)) + "Z"
            : normalized
        let trimmedFraction = trimFractionalSeconds(timezoneNormalized)
        let candidates = [value, normalized, timezoneNormalized, trimmedFraction]

        for candidate in candidates {
            if let parsed = Self.iso8601FractionalFormatter.date(from: candidate) {
                return parsed
            }
            if let parsed = Self.iso8601Formatter.date(from: candidate) {
                return parsed
            }
        }

        return nil
    }

    private func trimFractionalSeconds(_ value: String) -> String {
        guard let dotIndex = value.firstIndex(of: ".") else { return value }
        guard let zoneIndex = value[dotIndex...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return value
        }

        let fractionStart = value.index(after: dotIndex)
        let fraction = value[fractionStart ..< zoneIndex]
        if fraction.count <= 3 { return value }

        let prefix = value[..<fractionStart]
        let shortenedFraction = fraction.prefix(3)
        let suffix = value[zoneIndex...]
        return String(prefix) + shortenedFraction + suffix
    }

    private func ensureRestoreAccountMatches(_ customerInfo: CustomerInfo, expectedUserId: String) throws {
        guard let originalUserId = normalizeUUID(customerInfo.originalAppUserId) else {
            return
        }

        guard originalUserId == expectedUserId else {
            logger.error("restore blocked: expectedAppUserID=\(expectedUserId, privacy: .public) originalAppUserID=\(originalUserId, privacy: .public)")
            throw NSError(
                domain: "Billing",
                code: -5,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "billing.error.restoreAccountMismatch")
                ]
            )
        }
    }

    private func normalizeUUID(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: normalized) != nil else {
            return nil
        }
        return normalized.lowercased()
    }

    private func applyDefaultMonthlyPrice() {
        monthlyPriceText = BillingConfig.premiumMonthlyPriceUSD
    }

    private func requireAuthenticatedRevenueCatUserId() throws -> String {
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

    private func selectPackage(from offerings: Offerings) -> Package? {
        if let monthly = offerings.current?.monthly {
            return monthly
        }
        if let firstCurrent = offerings.current?.availablePackages.first {
            return firstCurrent
        }

        let allPackages = offerings.all.values.flatMap { $0.availablePackages }
        if let monthly = allPackages.first(where: { $0.packageType == .monthly }) {
            return monthly
        }
        return allPackages.first
    }
}

private struct BillingSyncResponse: Decodable {
    var credits: Int
    var isEntitlementActive: Bool
    var entitlementExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case credits
        case isEntitlementActive = "is_entitlement_active"
        case entitlementExpiresAt = "entitlement_expires_at"
    }
}
