import Foundation
import Supabase

struct SoulerChapter: Identifiable, Equatable, Codable {
    var id: UUID
    var seq: Int
    var title: String
    var subtitle: String
}

extension SoulerChapter {
    static func fetchList(for soulerId: UUID) async throws -> [SoulerChapter] {
        let supabase = try Backend.requireSupabase()
        let response: [SoulerChapter] = try await supabase
            .from("chapters")
            .select("id, seq, title, subtitle")
            .eq("souler_id", value: soulerId.uuidString)
            .eq("lang", value: AppLanguage.current.apiLanguageCode)
            .eq("active", value: true)
            .order("seq", ascending: true)
            .execute()
            .value
        return response
    }
}
