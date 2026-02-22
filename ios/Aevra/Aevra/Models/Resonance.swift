import Foundation
import Supabase

struct Resonance: Identifiable, Equatable {
    var id: UUID
    var soulerId: UUID
    var soulerName: String
    var count: Int
    var createdAt: Date
    var updatedAt: Date
}

extension Resonance {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var count: Int
        var createdAt: Date
        var updatedAt: Date
        var souler: SoulerName?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case count
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case souler = "soulers"
        }
    }

    private struct SoulerName: Codable {
        var name: String
    }

    static func getAll() async throws -> [Resonance] {
        let response: [Response] = try await supabase
            .from("resonances")
            .select("id, souler_id, count, created_at, updated_at, soulers(name)")
            .order("updated_at", ascending: false)
            .execute()
            .value

        let fallbackName = String(localized: "resonance.unknownSouler")
        return response.map { res in
            Resonance(
                id: res.id,
                soulerId: res.soulerId,
                soulerName: res.souler?.name ?? fallbackName,
                count: res.count,
                createdAt: res.createdAt,
                updatedAt: res.updatedAt
            )
        }
    }
}
