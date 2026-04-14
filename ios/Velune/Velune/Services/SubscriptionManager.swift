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
    var currentPlan: BillingPlan = .free
    var credits = BillingConfig.freeDailyCredits
    var dailyCreditsAllowance: Int { currentPlan.dailyCredits }
    
    private(set) var availablePackages: [Package] = []
    var entitlementExpiresAt: Date?

    var isRevenueCatAvailable = false
    var isSyncing = false
    var isLoadingOfferings = false
    var isPurchasing = false
    var isRestoring = false

    private(set) var lastErrorMessage: String?

    private var hasConfiguredRevenueCat = false
    private var activeAppUserID: String?
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

    func purchasePremium(package: Package) async throws {
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

        if availablePackages.isEmpty {
            await refreshOfferings()
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

        isRestoring = true
        defer { isRestoring = false }

        try await ensureRevenueCatIdentityMatches(userId: currentUserId)

        var customerInfo = try await Purchases.shared.customerInfo()
        var activeProductId = resolveRevenueCatActiveProductId(customerInfo)

        if activeProductId == nil {
            logger.notice("restore probing store receipt because current RevenueCat user has no active subscription")
            customerInfo = try await Purchases.shared.restorePurchases()
            activeProductId = resolveRevenueCatActiveProductId(customerInfo)
        }

        guard let activeProductId else {
            logger.notice("restore skipped: no active RevenueCat subscription after receipt restore")
            return
        }

        if isRestoreStateConsistent(revenueCatProductId: activeProductId) {
            logger.notice("restore skipped: RevenueCat subscription already consistent with local state")
            return
        }

        let boundUserId = resolveRevenueCatBoundUserId(customerInfo)
        if boundUserId != currentUserId {
            logger.notice(
                "restore rebinding RevenueCat user from \(boundUserId ?? "unknown", privacy: .public) to \(currentUserId, privacy: .public)"
            )
            _ = try await Purchases.shared.logIn(currentUserId)
            activeAppUserID = currentUserId
            customerInfo = try await Purchases.shared.restorePurchases()
        }

        applyCustomerInfo(customerInfo)
        try await syncRestorePurchaseOnServer()
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
            availablePackages = []
            return
        }
        if isLoadingOfferings { return }

        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            if let packages = offerings.current?.availablePackages, !packages.isEmpty {
                availablePackages = packages
                lastErrorMessage = nil
                logger.notice("offerings resolved: \(packages.count, privacy: .public) packages")
            } else {
                availablePackages = []
                lastErrorMessage =
                    "RevenueCat offerings are empty. current=\(offerings.current?.identifier ?? "nil"), all=\(Array(offerings.all.keys))"
                logger.error("offering unavailable: \(self.lastErrorMessage ?? "", privacy: .public)")
            }
        } catch {
            availablePackages = []
            lastErrorMessage = "RevenueCat offerings fetch failed: \(error.localizedDescription)"
            logger.error("offerings fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resetToFreeDefaults() {
        isPremium = false
        currentPlan = .free
        credits = BillingConfig.freeDailyCredits
        availablePackages = []
        entitlementExpiresAt = nil
        pendingForcedRefresh = false
        currentBillingUserID = nil
    }

    private func apply(_ payload: BillingSyncResponse) {
        let expiration = parseISODate(payload.expirationAt)
        let hasProduct = payload.productId != nil
        let notExpired = expiration.map { $0 > Date() } ?? true
        let resolvedPlan = BillingConfig.resolvePlan(
            productId: payload.productId,
            dailyCredits: payload.dailyCredits
        )
        currentPlan = resolvedPlan
        isPremium = (resolvedPlan != .free || hasProduct) && notExpired
        credits = payload.credits
        entitlementExpiresAt = expiration
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
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
                if !expectPremium || isPremium {
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

    private func syncRestorePurchaseOnServer() async throws {
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

    private func resolveRevenueCatActiveProductId(_ customerInfo: CustomerInfo) -> String? {
        let products = Array(customerInfo.activeSubscriptions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !products.isEmpty else { return nil }
        if let depth = products.first(where: { $0.localizedCaseInsensitiveContains("depth") }) {
            return depth
        }
        if let awaken = products.first(where: { $0.localizedCaseInsensitiveContains("awaken") }) {
            return awaken
        }
        return products.sorted().first
    }

    private func isRestoreStateConsistent(revenueCatProductId: String) -> Bool {
        guard isPremium else { return false }
        guard let revenueCatPlan = BillingConfig.resolvePlan(productIdentifiers: [revenueCatProductId]) else {
            return false
        }
        return currentPlan == revenueCatPlan
    }

    private func resolveRevenueCatBoundUserId(_ customerInfo: CustomerInfo) -> String? {
        if let appUserId = normalizeUUID(Purchases.shared.appUserID) {
            return appUserId
        }
        return normalizeUUID(customerInfo.originalAppUserId)
    }

    private func normalizeUUID(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: normalized) != nil else {
            return nil
        }
        return normalized.lowercased()
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
}

private struct BillingSyncResponse: Decodable {
    var credits: Int
    var productId: String?
    var dailyCredits: Int?
    var expirationAt: String?

    enum CodingKeys: String, CodingKey {
        case credits
        case productId = "product_id"
        case dailyCredits = "daily_credits"
        case expirationAt = "expiration_at"
    }
}

private struct RestorePurchaseResponse: Decodable {
    var ok: Bool
}
