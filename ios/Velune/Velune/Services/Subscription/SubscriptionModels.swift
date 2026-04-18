import Foundation

struct RedeemCodeSuccess {
    var rewardCredits: Int
    var credits: Int
}

struct BillingSyncResponse: Decodable {
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

struct RestorePurchaseResponse: Decodable {
    var ok: Bool
}

struct RedeemCodeResponse: Decodable {
    var ok: Bool
    var code: String?
    var message: String?
    var rewardCredits: Int?
    var credits: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case message
        case rewardCredits = "reward_credits"
        case credits
    }
}
