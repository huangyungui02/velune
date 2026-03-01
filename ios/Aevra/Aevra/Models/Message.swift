import Foundation
import Supabase

struct Message: Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID
    var soulerId: UUID
    var role: Role
    var content: String
    var createdAt: Date
}

extension Message {
    struct SeedMessage: Encodable {
        var role: Role
        var content: String
    }

    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var role: Role
        var content: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case role
            case content
            case createdAt = "created_at"
        }
    }

    static func getHistory(soulerId: UUID) async throws -> [Message] {
        let response: [Response] = try await supabase
            .from("messages")
            .select("id, souler_id, role, content, created_at")
            .eq("souler_id", value: soulerId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response.map { item in
            Message(
                id: item.id,
                soulerId: item.soulerId,
                role: item.role,
                content: item.content,
                createdAt: item.createdAt
            )
        }
    }
}
