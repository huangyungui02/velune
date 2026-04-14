import Foundation
import Supabase
import SwiftData

@Model
class Echo {
    @Attribute(.unique) var id: UUID
    var userId: String
    var content: String
    var sessionId: UUID?
    var createdAt: Date

    var stirring: Stirring?
    var soulerId: UUID
    var soulerName: String

    init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        sessionId: UUID? = nil,
        createdAt: Date = .now,
        soulerId: UUID,
        soulerName: String
    ) {
        self.id = id
        self.userId = userId
        self.content = content
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.soulerId = soulerId
        self.soulerName = soulerName
    }

    convenience init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        sessionId: UUID? = nil,
        createdAt: Date = .now,
        souler: Souler
    ) {
        self.init(
            id: id,
            userId: userId,
            content: content,
            sessionId: sessionId,
            createdAt: createdAt,
            soulerId: souler.id,
            soulerName: souler.name
        )
    }
}

extension Echo {
    static func getAll(_ stirringId: UUID) async throws -> [Echo] {
        struct Response: Codable, Identifiable {
            var id: UUID
            var content: String
            var sessionId: UUID?
            var createdAt: Date
            var soulerId: UUID
            var soulerName: String

            enum CodingKeys: String, CodingKey {
                case id
                case content
                case sessionId = "session_id"
                case createdAt = "created_at"
                case soulerId = "souler_id"
                case soulerName = "souler_name"
            }
        }

        let userId = try await AuthManager.shared.getUserId()
        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("echoes_with_souler")
            .select()
            .eq("glimmer_id", value: stirringId)
            .execute()
            .value

        return response.map { res in
            Echo(
                id: res.id,
                userId: userId.uuidString,
                content: res.content,
                sessionId: res.sessionId,
                createdAt: res.createdAt,
                soulerId: res.soulerId,
                soulerName: res.soulerName
            )
        }
    }
}
