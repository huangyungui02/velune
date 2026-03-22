import Foundation
import Supabase
import SwiftData

@Model
class Echo {
    @Attribute(.unique) var id: UUID
    var userId: String
    var content: String
    var createdAt: Date

    var glimmer: Glimmer?
    var soulerId: UUID
    var soulerName: String

    init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        createdAt: Date = .now,
        soulerId: UUID,
        soulerName: String
    ) {
        self.id = id
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.soulerId = soulerId
        self.soulerName = soulerName
    }

    convenience init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        createdAt: Date = .now,
        souler: Souler
    ) {
        self.init(
            id: id,
            userId: userId,
            content: content,
            createdAt: createdAt,
            soulerId: souler.id,
            soulerName: souler.name
        )
    }
}

extension Echo {
    static func getAll(_ glimmerId: UUID) async throws -> [Echo] {
        struct Response: Codable, Identifiable {
            var id: UUID
            var content: String
            var createdAt: Date
            var soulerId: UUID
            var soulerName: String

            enum CodingKeys: String, CodingKey {
                case id
                case content
                case createdAt = "created_at"
                case soulerId = "souler_id"
                case soulerName = "souler_name"
            }
        }

        let userId = try await AuthManager.shared.getUserId()
        let response: [Response] = try await supabase
            .from("echoes_with_souler")
            .select()
            .eq("glimmer_id", value: glimmerId)
            .execute()
            .value

        return response.map { res in
            Echo(
                id: res.id,
                userId: userId.uuidString,
                content: res.content,
                createdAt: res.createdAt,
                soulerId: res.soulerId,
                soulerName: res.soulerName
            )
        }
    }
}
