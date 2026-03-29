import Foundation
import Supabase

struct ChatSession: Identifiable, Equatable, Hashable {
    var id: UUID
    var soulerId: UUID
    var soulerName: String
    var title: String
    var createdAt: Date
    var updatedAt: Date

    var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension ChatSession {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var souler: SoulerName?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case title
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case souler = "soulers"
        }
    }

    private struct SoulerName: Codable {
        var name: String
    }

    private static func mapResponse(_ response: [Response]) -> [ChatSession] {
        let fallbackName = String(localized: "resonance.unknownSouler")
        return response.map { item in
            ChatSession(
                id: item.id,
                soulerId: item.soulerId,
                soulerName: item.souler?.name ?? fallbackName,
                title: item.title,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
        }
    }

    static func getPage(limit: Int, offset: Int) async throws -> [ChatSession] {
        try await getPage(soulerId: nil, limit: limit, offset: offset)
    }

    static func getPage(
        soulerId: UUID?,
        limit: Int,
        offset: Int
    ) async throws -> [ChatSession] {
        let upperBound = max(offset + limit - 1, offset)
        let supabase = try Backend.requireSupabase()
        let response: [Response]
        if let soulerId {
            response = try await supabase
                .from("sessions")
                .select("id, souler_id, title, created_at, updated_at, soulers(name)")
                .eq("souler_id", value: soulerId.uuidString)
                .order("updated_at", ascending: false)
                .range(from: offset, to: upperBound)
                .execute()
                .value
        } else {
            response = try await supabase
                .from("sessions")
                .select("id, souler_id, title, created_at, updated_at, soulers(name)")
                .order("updated_at", ascending: false)
                .range(from: offset, to: upperBound)
                .execute()
                .value
        }

        return mapResponse(response)
    }

    static func getLatest(soulerId: UUID) async throws -> ChatSession? {
        let list = try await getPage(soulerId: soulerId, limit: 1, offset: 0)
        return list.first
    }

    static func get(id: UUID) async throws -> ChatSession? {
        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("sessions")
            .select("id, souler_id, title, created_at, updated_at, soulers(name)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return mapResponse(response).first
    }
}
