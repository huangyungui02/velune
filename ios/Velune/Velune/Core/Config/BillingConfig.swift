import Foundation

enum BillingConfig {
    static let freeDailyCredits = 10
    static let premiumDailyCredits = 100
    static let premiumMonthlyPriceUSD = "$9.99 / month"

    static var revenueCatPublicSDKKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
