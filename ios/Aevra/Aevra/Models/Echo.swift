import Foundation
import Supabase
import SwiftData

@Model
class Echo {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date

    var glimmer: Glimmer?
    var soulerId: UUID
    var soulerName: String
    var sessionId: UUID?

    init(
        id: UUID = UUID(),
        content: String,
        createdAt: Date = .now,
        soulerId: UUID,
        soulerName: String,
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.sessionId = sessionId
    }

    convenience init(
        id: UUID = UUID(),
        content: String,
        createdAt: Date = .now,
        souler: Souler,
        sessionId: UUID? = nil
    ) {
        self.init(
            id: id,
            content: content,
            createdAt: createdAt,
            soulerId: souler.id,
            soulerName: souler.name,
            sessionId: sessionId
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
            var sessionId: UUID?

            enum CodingKeys: String, CodingKey {
                case id
                case content
                case createdAt = "created_at"
                case soulerId = "souler_id"
                case soulerName = "souler_name"
                case sessionId = "session_id"
            }
        }

        let response: [Response] = try await supabase
            .from("echoes_with_souler")
            .select()
            .eq("glimmer_id", value: glimmerId)
            .execute()
            .value

        return response.map { res in
            Echo(id: res.id,
                 content: res.content,
                 createdAt: res.createdAt,
                 soulerId: res.soulerId,
                 soulerName: res.soulerName,
                 sessionId: res.sessionId)
        }
    }
}
