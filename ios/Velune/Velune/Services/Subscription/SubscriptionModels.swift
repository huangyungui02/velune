import Foundation

struct BillingSyncResponse: Decodable {
    var productId: String?
    var expirationAt: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case expirationAt = "expiration_at"
    }
}

struct RestorePurchaseResponse: Decodable {
    var ok: Bool
}
