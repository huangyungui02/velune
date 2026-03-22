import Foundation
import Supabase
import SwiftData

@Model
class Glimmer {
    @Attribute(.unique) var id: UUID
    var userId: String
    var content: String
    var createdAt: Date
    var status: String

    @Relationship(deleteRule: .cascade, inverse: \Echo.glimmer)
    var echoes: [Echo] = []

    init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        createdAt: Date = .now,
        status: String = "pending"
    ) {
        self.id = id
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.status = status
    }

}

extension Glimmer {
    nonisolated struct Response: Identifiable, Codable, Sendable {
        var id: UUID
        var content: String
        var createdAt: Date
        var status: String

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case createdAt = "created_at"
            case status
        }
    }

    static func get(_ glimmerId: UUID) async throws -> Glimmer {
        let response: Response = try await supabase
            .from("glimmers")
            .select("id, content, created_at, status")
            .eq("id", value: glimmerId)
            .single()
            .execute()
            .value

        let userId = try await AuthManager.shared.getUserId()
        return Glimmer(
            id: response.id,
            userId: userId.uuidString,
            content: response.content,
            createdAt: response.createdAt,
            status: response.status
        )
    }

    static func getAll() async throws -> [Glimmer] {
        let userId = try await AuthManager.shared.getUserId()

        let response: [Response] = try await supabase
            .from("glimmers")
            .select("id, content, created_at, status")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { response in
            Glimmer(
                id: response.id,
                userId: userId.uuidString,
                content: response.content,
                createdAt: response.createdAt,
                status: response.status
            )
        }
    }

    static func create(_ glimmer: Glimmer, status: String = "pending") async throws {
        struct Data: Codable {
            var id: UUID
            var userId: UUID
            var content: String
            var createdAt: Date
            var status: String

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case content
                case createdAt = "created_at"
                case status
            }
        }

        let userId = try await AuthManager.shared.getUserId()
        let data = Data(
            id: glimmer.id,
            userId: userId,
            content: glimmer.content,
            createdAt: glimmer.createdAt,
            status: status
        )

        try await supabase
            .from("glimmers")
            .insert(data)
            .execute()
    }

    static func delete(_ glimmerId: UUID) async throws {
        try await supabase
            .from("glimmers")
            .delete()
            .eq("id", value: glimmerId)
            .execute()
    }
}
