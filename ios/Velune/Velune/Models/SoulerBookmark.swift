import Foundation
import Supabase

extension Notification.Name {
    static let bookselfDidChange = Notification.Name("bookselfDidChange")
}

enum SoulerBookmark {
    private struct Payload: Encodable {
        var userId: UUID
        var soulerId: UUID

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case soulerId = "souler_id"
        }
    }

    private struct Row: Decodable {
        var soulerId: UUID

        enum CodingKeys: String, CodingKey {
            case soulerId = "souler_id"
        }
    }

    static func contains(soulerId: UUID) async throws -> Bool {
        let userId = try AuthManager.shared.getUserId()
        let supabase = try Backend.requireSupabase()
        let rows: [Row] = try await supabase
            .from("bookself")
            .select("souler_id")
            .eq("user_id", value: userId.uuidString)
            .eq("souler_id", value: soulerId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    static func setBookmarked(_ isBookmarked: Bool, soulerId: UUID) async throws {
        if isBookmarked {
            try await add(soulerId: soulerId)
        } else {
            try await remove(soulerId: soulerId)
        }
    }

    private static func add(soulerId: UUID) async throws {
        let userId = try AuthManager.shared.getUserId()
        let payload = Payload(userId: userId, soulerId: soulerId)
        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("bookself")
            .insert(payload)
            .execute()
    }

    private static func remove(soulerId: UUID) async throws {
        let userId = try AuthManager.shared.getUserId()
        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("bookself")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("souler_id", value: soulerId.uuidString)
            .execute()
    }
}
