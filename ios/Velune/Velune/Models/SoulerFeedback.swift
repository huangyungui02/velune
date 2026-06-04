import Foundation
import Supabase

enum SoulerFeedback {
    private struct Payload: Encodable {
        var userId: UUID
        var soulerId: UUID
        var lang: String
        var content: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case soulerId = "souler_id"
            case lang
            case content
        }
    }

    static func submit(soulerId: UUID, content: String) async throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let userId = try AuthManager.shared.getUserId()
        let payload = Payload(
            userId: userId,
            soulerId: soulerId,
            lang: AppLanguage.current.apiLanguageCode,
            content: trimmedContent
        )

        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("souler_feedback")
            .insert(payload)
            .execute()
    }
}
