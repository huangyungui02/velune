import Foundation
import Supabase
import SwiftData

@Model
class Glimmer {
    @Attribute(.unique) var id: UUID
    var userId: String
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: String = "",
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
    }

}

extension Glimmer {
    nonisolated struct Page {
        var items: [Glimmer]
        var hasMore: Bool
    }

    nonisolated struct Response: Identifiable, Codable, Sendable {
        var id: UUID
        var content: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case createdAt = "created_at"
        }
    }

    static func get(_ glimmerId: UUID) async throws -> Glimmer {
        let supabase = try Backend.requireSupabase()
        let response: Response = try await supabase
            .from("glimmers")
            .select("id, content, created_at")
            .eq("id", value: glimmerId)
            .single()
            .execute()
            .value

        let userId = try await AuthManager.shared.getUserId()
        return Glimmer(
            id: response.id,
            userId: userId.uuidString,
            content: response.content,
            createdAt: response.createdAt
        )
    }

    static func getPage(limit: Int, offset: Int) async throws -> Page {
        let pageSize = max(limit, 1)
        let pageOffset = max(offset, 0)
        let userId = try await AuthManager.shared.getUserId()
        let upperBound = max(pageOffset + pageSize - 1, pageOffset)

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("glimmers")
            .select("id, content, created_at")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        let items = response.map { response in
            Glimmer(
                id: response.id,
                userId: userId.uuidString,
                content: response.content,
                createdAt: response.createdAt
            )
        }

        return Page(items: items, hasMore: response.count == pageSize)
    }

    static func getAll() async throws -> [Glimmer] {
        let userId = try await AuthManager.shared.getUserId()

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("glimmers")
            .select("id, content, created_at")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { response in
            Glimmer(
                id: response.id,
                userId: userId.uuidString,
                content: response.content,
                createdAt: response.createdAt
            )
        }
    }

    static func create(_ glimmer: Glimmer) async throws {
        struct Data: Codable {
            var id: UUID
            var userId: UUID
            var content: String
            var createdAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case content
                case createdAt = "created_at"
            }
        }

        let userId = try await AuthManager.shared.getUserId()
        let data = Data(
            id: glimmer.id,
            userId: userId,
            content: glimmer.content,
            createdAt: glimmer.createdAt
        )

        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("glimmers")
            .insert(data)
            .execute()
    }

    static func updateContent(id: UUID, content: String) async throws {
        struct Data: Encodable {
            var content: String
        }

        let userId = try await AuthManager.shared.getUserId()
        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("glimmers")
            .update(Data(content: content))
            .eq("id", value: id)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func delete(_ glimmerId: UUID) async throws {
        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("glimmers")
            .delete()
            .eq("id", value: glimmerId)
            .execute()
    }
}
