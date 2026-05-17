import Foundation
import Supabase
import SwiftData

struct BookshelfItem: Identifiable, Equatable {
    var id: UUID
    var soulerId: UUID
    var soulerName: String
    var lastSessionId: UUID?
    var lastChapterId: UUID?
    var lastSessionTitle: String
    var updatedAt: Date
    var imageURL: URL?
}

extension BookshelfItem {
    private struct ResonanceRow: Decodable {
        var id: UUID
        var soulerId: UUID
        var soulerName: String?
        var lastSessionId: UUID?
        var lastSessionTitle: String?
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case soulerName = "souler_name"
            case lastSessionId = "last_session_id"
            case lastSessionTitle = "last_session_title"
            case updatedAt = "updated_at"
        }
    }

    private struct SoulerCoverRow: Decodable {
        var id: UUID
        var wikiId: String?

        enum CodingKeys: String, CodingKey {
            case id
            case wikiId = "wiki_id"
        }
    }

    private struct SessionChapterRow: Decodable {
        var id: UUID
        var chapterId: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case chapterId = "chapter_id"
        }
    }

    static func fetch(limit: Int = 80) async throws -> [BookshelfItem] {
        let supabase = try Backend.requireSupabase()
        let resonanceRows: [ResonanceRow] = try await supabase
            .from("resonances_with_souler")
            .select("id, souler_id, souler_name, last_session_id, last_session_title, updated_at")
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let soulerIds = Array(Set(resonanceRows.map(\.soulerId)))
        let sessionIds = Array(Set(resonanceRows.compactMap(\.lastSessionId)))
        let imageBySoulerId = try await fetchImages(soulerIds: soulerIds, supabase: supabase)
        let chapterBySessionId = try await fetchChapterIds(sessionIds: sessionIds, supabase: supabase)

        return resonanceRows.map { row in
            let name = row.soulerName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return BookshelfItem(
                id: row.id,
                soulerId: row.soulerId,
                soulerName: name?.isEmpty == false ? name! : String(localized: "resonance.unknownSouler"),
                lastSessionId: row.lastSessionId,
                lastChapterId: row.lastSessionId.flatMap { chapterBySessionId[$0] ?? nil },
                lastSessionTitle: row.lastSessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                updatedAt: row.updatedAt,
                imageURL: imageBySoulerId[row.soulerId]
            )
        }
    }

    @MainActor
    static func fetchCached(userId: String, context: ModelContext) throws -> [BookshelfItem] {
        try Resonance.fetchCached(userId: userId, context: context).map(Self.init(resonance:))
    }

    @MainActor
    static func mergeCached(_ remoteItems: [BookshelfItem], userId: String, context: ModelContext) throws -> Bool {
        try Resonance.mergeCached(remoteItems.map { $0.asResonance(userId: userId) }, userId: userId, context: context)
    }

    private static func fetchImages(soulerIds: [UUID], supabase: SupabaseClient) async throws -> [UUID: URL] {
        guard !soulerIds.isEmpty else { return [:] }
        let rows: [SoulerCoverRow] = try await supabase
            .from("soulers")
            .select("id, wiki_id")
            .in("id", values: soulerIds.map(\.uuidString))
            .execute()
            .value

        let avatarByWikiId = try await ReadingSoulerItem.resolveImageURLs(wikiIds: rows.map(\.wikiId))
        var result: [UUID: URL] = [:]
        for row in rows {
            let wikiId = row.wikiId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !wikiId.isEmpty, let url = avatarByWikiId[wikiId] else { continue }
            result[row.id] = url
        }
        return result
    }

    private static func fetchChapterIds(
        sessionIds: [UUID],
        supabase: SupabaseClient
    ) async throws -> [UUID: UUID?] {
        guard !sessionIds.isEmpty else { return [:] }
        let rows: [SessionChapterRow] = try await supabase
            .from("sessions")
            .select("id, chapter_id")
            .in("id", values: sessionIds.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.chapterId) })
    }

    private init(resonance: Resonance) {
        self.init(
            id: resonance.id,
            soulerId: resonance.soulerId,
            soulerName: resonance.soulerName,
            lastSessionId: resonance.lastSessionId,
            lastChapterId: nil,
            lastSessionTitle: resonance.lastSessionTitle,
            updatedAt: resonance.updatedAt,
            imageURL: resonance.soulerAvatarURL.flatMap(URL.init(string:))
        )
    }

    private func asResonance(userId: String) -> Resonance {
        Resonance(
            id: id,
            userId: userId,
            soulerId: soulerId,
            soulerName: soulerName,
            soulerAvatarURL: imageURL?.absoluteString,
            lastSessionId: lastSessionId,
            lastSessionTitle: lastSessionTitle,
            updatedAt: updatedAt
        )
    }
}
