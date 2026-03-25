import Foundation

enum BillingConfig {
    static let freeMonthlyCredits = 0
    static let premiumCredits = 1000
    static let premiumMonthlyPriceUSD = "$9.99 / month"

    static var revenueCatPublicSDKKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_SDK_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
