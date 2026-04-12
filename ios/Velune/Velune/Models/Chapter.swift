import Foundation
import Supabase

enum SoulerChaptersStatus: String, Codable {
    case pending
    case processing
    case complete
    case failed
}

struct SoulerChapter: Identifiable, Equatable, Codable {
    var id: UUID
    var seq: Int
    var title: String
    var subtitle: String
}

struct SoulerChapterState: Equatable {
    var status: SoulerChaptersStatus
    var chapters: [SoulerChapter]
}

extension SoulerChapterState {
    private struct SoulerResponse: Decodable {
        var chaptersStatus: String?
        var chapters: [SoulerChapter]?

        enum CodingKeys: String, CodingKey {
            case chaptersStatus = "chapters_status"
            case chapters
        }
    }

    static func fetch(for soulerId: UUID) async throws -> SoulerChapterState {
        let supabase = try Backend.requireSupabase()
        let response: SoulerResponse = try await supabase
            .from("soulers")
            .select("chapters_status, chapters(id, seq, title, subtitle)")
            .eq("id", value: soulerId.uuidString)
            .single()
            .execute()
            .value

        let status = SoulerChaptersStatus(rawValue: response.chaptersStatus ?? "") ?? .pending
        let chapters = (response.chapters ?? []).sorted { $0.seq < $1.seq }
        return SoulerChapterState(
            status: status,
            chapters: chapters
        )
    }
}
