import Foundation
import OSLog
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    let logger = AppLogger.billing

    var isPremium = false
    var currentPlan: BillingPlan = .free
    
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
    private init() {}

    func updateLastErrorMessage(_ message: String?) {
        lastErrorMessage = message
    }

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
        availablePackages = []
        entitlementExpiresAt = nil
        pendingForcedRefresh = false
        currentBillingUserID = nil
    }

}
