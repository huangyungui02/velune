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
    private struct BookselfRow: Decodable {
        var userId: UUID
        var soulerId: UUID
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case soulerId = "souler_id"
            case createdAt = "created_at"
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

    private struct ProfileRow: Decodable {
        var soulerId: UUID
        var name: String

        enum CodingKeys: String, CodingKey {
            case soulerId = "souler_id"
            case name
        }
    }

    static func fetch(limit: Int = 80) async throws -> [BookshelfItem] {
        let supabase = try Backend.requireSupabase()
        let userId = try AuthManager.shared.getUserId()
        let bookselfRows: [BookselfRow] = try await supabase
            .from("bookself")
            .select("user_id, souler_id, created_at")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let soulerIds = Array(Set(bookselfRows.map(\.soulerId)))
        let nameBySoulerId = try await fetchNames(soulerIds: soulerIds, supabase: supabase)
        let imageBySoulerId = try await fetchImages(soulerIds: soulerIds, supabase: supabase)

        return bookselfRows.map { row in
            let name = nameBySoulerId[row.soulerId]?.trimmingCharacters(in: .whitespacesAndNewlines)
            return BookshelfItem(
                id: row.soulerId,
                soulerId: row.soulerId,
                soulerName: name?.isEmpty == false ? name! : String(localized: "resonance.unknownSouler"),
                lastSessionId: nil,
                lastChapterId: nil,
                lastSessionTitle: "",
                updatedAt: row.createdAt,
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

    private static func fetchNames(soulerIds: [UUID], supabase: SupabaseClient) async throws -> [UUID: String] {
        guard !soulerIds.isEmpty else { return [:] }
        let rows: [ProfileRow] = try await supabase
            .from("souler_profile")
            .select("souler_id, name")
            .in("souler_id", values: soulerIds.map(\.uuidString))
            .eq("lang", value: AppLanguage.current.apiLanguageCode)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.soulerId, $0.name) })
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
