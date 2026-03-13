import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var plan = "free"
    var isPremium = false
    var monthlyLimit = BillingConfig.freeMonthlyCredits
    var creditsRemaining = BillingConfig.freeMonthlyCredits
    var monthlyPriceText = BillingConfig.premiumMonthlyPriceUSD
    var lastSyncedAt: Date?
    var nextResetAt: Date?

    var isRevenueCatAvailable = false
    var isSyncing = false
    var isLoadingOfferings = false
    var isPurchasing = false
    var isRestoring = false

    private(set) var lastErrorMessage: String?

    private var hasConfiguredRevenueCat = false
    private var activeAppUserID: String?
    private var monthlyPackage: Package?
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
        configureRevenueCatIfNeeded()

        guard userId != nil else {
            await signOutRevenueCatIfNeeded()
            resetToFreeDefaults()
            return
        }

        await refreshOfferings()
        await refreshBillingState()
    }

    func refreshBillingState() async {
        if isSyncing { return }

        isSyncing = true
        defer { isSyncing = false }
        _ = await syncBillingState(maxAttempts: 1, expectPremium: false)
    }

    func purchasePremium() async throws {
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
                userInfo: [
                    NSLocalizedDescriptionKey: message
                ]
            )
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let purchaseResult = try await Purchases.shared.purchase(package: package)
        print(
            "rc purchase appUserID=\(Purchases.shared.appUserID) activeEntitlements=\(Array(purchaseResult.customerInfo.entitlements.active.keys)) activeSubscriptions=\(Array(purchaseResult.customerInfo.activeSubscriptions))"
        )
        await refreshBillingStateAfterTransaction(expectPremium: true)
    }

    func restorePurchases() async throws {
        let currentUserId = try requireAuthenticatedRevenueCatUserId()
        try await ensureRevenueCatIdentityMatches(userId: currentUserId)

        isRestoring = true
        defer { isRestoring = false }

        _ = try await Purchases.shared.restorePurchases()
        await refreshBillingStateAfterTransaction(expectPremium: false)
    }

    func applyServerCreditSnapshot(plan: String?, monthlyLimit: Int?, creditsRemaining: Int?) {
        if let plan {
            self.plan = plan
            isPremium = plan == "premium"
        }
        if let monthlyLimit {
            self.monthlyLimit = monthlyLimit
        }
        if let creditsRemaining {
            self.creditsRemaining = creditsRemaining
        }
    }

    private func configureRevenueCatIfNeeded() {
        guard !hasConfiguredRevenueCat else { return }

        let apiKey = BillingConfig.revenueCatPublicSDKKey
        guard !apiKey.isEmpty else {
            isRevenueCatAvailable = false
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
            print(message)
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
            // Ignore logout failures during session teardown.
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
                print(
                    "rc offering resolved: id=\(package.identifier) product=\(package.storeProduct.productIdentifier) offering=\(package.offeringIdentifier)"
                )
            } else {
                applyDefaultMonthlyPrice()
                lastErrorMessage =
                    "RevenueCat offerings are empty. current=\(offerings.current?.identifier ?? "nil"), all=\(Array(offerings.all.keys))"
                print(
                    "rc offering unavailable: current=\(offerings.current?.identifier ?? "nil") all=\(Array(offerings.all.keys))"
                )
            }
        } catch {
            monthlyPackage = nil
            applyDefaultMonthlyPrice()
            lastErrorMessage = "RevenueCat offerings fetch failed: \(error.localizedDescription)"
            print("rc offerings fetch failed: \(error.localizedDescription)")
        }
    }

    private func resetToFreeDefaults() {
        plan = "free"
        isPremium = false
        monthlyLimit = BillingConfig.freeMonthlyCredits
        creditsRemaining = BillingConfig.freeMonthlyCredits
        applyDefaultMonthlyPrice()
        lastSyncedAt = nil
        nextResetAt = nil
    }

    private func apply(_ payload: BillingSyncResponse) {
        plan = payload.plan
        isPremium = payload.plan == "premium"
        monthlyLimit = payload.monthlyLimit
        creditsRemaining = payload.creditsRemaining
        lastSyncedAt = parseISODate(payload.rcLastSyncedAt) ?? parseISODate(payload.entitlementExpiresAt)
        nextResetAt = parseISODate(payload.nextResetAt)
    }

    private func refreshBillingStateAfterTransaction(expectPremium: Bool) async {
        // RevenueCat webhook/state propagation can be slightly delayed after purchase/restore.
        let hasMetExpectation = await syncBillingState(maxAttempts: 5, expectPremium: expectPremium)
        if expectPremium && !hasMetExpectation {
            lastErrorMessage = String(localized: "billing.error.syncTimeout")
            print("billing-sync completed but plan still free after purchase retries")
        }
    }

    private func syncBillingState(maxAttempts: Int, expectPremium: Bool) async -> Bool {
        for attempt in 1 ... maxAttempts {
            do {
                let response = try await callBillingSync()
                apply(response)
                lastErrorMessage = nil
                if !expectPremium || response.plan == "premium" {
                    return true
                }
            } catch {
                lastErrorMessage = error.localizedDescription
                print("billing-sync attempt \(attempt) failed: \(error.localizedDescription)")
            }

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        return false
    }

    private func callBillingSync() async throws -> BillingSyncResponse {
        guard let accessToken = AuthManager.shared.currentAccessToken else {
            throw NSError(
                domain: "BillingSync",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing Supabase access token"]
            )
        }

        let endpoint = supabaseURL.appending(path: "functions/v1/billing-sync")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "BillingSync",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "matching.error.unknown")]
            )
        }

        if !(200 ... 299).contains(http.statusCode) {
            let backendError = try? JSONDecoder().decode(BillingSyncErrorResponse.self, from: data)
            let message = backendError?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                print("billing-sync failed (\(http.statusCode)): \(body)")
            } else {
                print("billing-sync failed (\(http.statusCode)): \(message)")
            }
            throw NSError(
                domain: "BillingSync",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        return try JSONDecoder().decode(BillingSyncResponse.self, from: data)
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
        let fraction = value[fractionStart..<zoneIndex]
        if fraction.count <= 3 { return value }

        let prefix = value[..<fractionStart]
        let shortenedFraction = fraction.prefix(3)
        let suffix = value[zoneIndex...]
        return String(prefix) + shortenedFraction + suffix
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
    var plan: String
    var monthlyLimit: Int
    var creditsRemaining: Int
    var entitlementExpiresAt: String?
    var rcLastSyncedAt: String?
    var nextResetAt: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case monthlyLimit
        case creditsRemaining
        case entitlementExpiresAt
        case rcLastSyncedAt
        case nextResetAt
    }
}

private struct BillingSyncErrorResponse: Decodable {
    var error: String
}
