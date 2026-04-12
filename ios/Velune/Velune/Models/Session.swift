import Foundation
import Supabase

struct ChatSession: Identifiable, Equatable, Hashable {
    var id: UUID
    var soulerId: UUID
    var chapterId: UUID?
    var soulerName: String
    var title: String

    var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension ChatSession {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var chapterId: UUID?
        var title: String
        var souler: SoulerName?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case chapterId = "chapter_id"
            case title
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
                chapterId: item.chapterId,
                soulerName: item.souler?.name ?? fallbackName,
                title: item.title
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
                .select("id, souler_id, chapter_id, title, soulers(name)")
                .eq("souler_id", value: soulerId.uuidString)
                .order("updated_at", ascending: false)
                .range(from: offset, to: upperBound)
                .execute()
                .value
        } else {
            response = try await supabase
                .from("sessions")
                .select("id, souler_id, chapter_id, title, soulers(name)")
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
            .select("id, souler_id, chapter_id, title, soulers(name)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return mapResponse(response).first
    }

    static func create(
        soulerId: UUID,
        soulerName: String,
        title: String,
        chapterId: UUID?
    ) async throws -> ChatSession {
        struct InsertPayload: Encodable {
            var userId: UUID
            var soulerId: UUID
            var chapterId: UUID?
            var title: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case soulerId = "souler_id"
                case chapterId = "chapter_id"
                case title
            }
        }

        struct InsertResponse: Decodable {
            var id: UUID
            var soulerId: UUID
            var chapterId: UUID?
            var title: String

            enum CodingKeys: String, CodingKey {
                case id
                case soulerId = "souler_id"
                case chapterId = "chapter_id"
                case title
            }
        }

        let userId = try await MainActor.run {
            try AuthManager.shared.getUserId()
        }
        let supabase = try Backend.requireSupabase()
        let response: [InsertResponse] = try await supabase
            .from("sessions")
            .insert(
                InsertPayload(
                    userId: userId,
                    soulerId: soulerId,
                    chapterId: chapterId,
                    title: title
                )
            )
            .select("id, souler_id, chapter_id, title")
            .limit(1)
            .execute()
            .value

        guard let inserted = response.first else {
            throw NSError(
                domain: "ChatSession",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create session"]
            )
        }

        return ChatSession(
            id: inserted.id,
            soulerId: inserted.soulerId,
            chapterId: inserted.chapterId,
            soulerName: soulerName,
            title: inserted.title
        )
    }
}
