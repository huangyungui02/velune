import Foundation
import Supabase
import SwiftData

struct ChatSession: Identifiable, Equatable, Hashable {
    var id: UUID
    var soulerId: UUID
    var chapterId: UUID?
    var soulerName: String
    var title: String
    var updatedAt: Date = .now

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
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case chapterId = "chapter_id"
            case title
            case souler = "soulers"
            case updatedAt = "updated_at"
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
                title: item.title,
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
                .select("id, souler_id, chapter_id, title, updated_at, soulers(name)")
                .eq("souler_id", value: soulerId.uuidString)
                .order("updated_at", ascending: false)
                .range(from: offset, to: upperBound)
                .execute()
                .value
        } else {
            response = try await supabase
                .from("sessions")
                .select("id, souler_id, chapter_id, title, updated_at, soulers(name)")
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

    static func getAll(soulerId: UUID, pageSize: Int = 20) async throws -> [ChatSession] {
        let resolvedPageSize = max(pageSize, 1)
        var allSessions: [ChatSession] = []
        var offset = 0

        while true {
            let page = try await getPage(
                soulerId: soulerId,
                limit: resolvedPageSize,
                offset: offset
            )
            allSessions.append(contentsOf: page)
            guard page.count == resolvedPageSize else { break }
            offset += page.count
        }

        return allSessions
    }

    static func get(id: UUID) async throws -> ChatSession? {
        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("sessions")
            .select("id, souler_id, chapter_id, title, updated_at, soulers(name)")
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
            var updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case soulerId = "souler_id"
                case chapterId = "chapter_id"
                case title
                case updatedAt = "updated_at"
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
            .select("id, souler_id, chapter_id, title, updated_at")
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
            title: inserted.title,
            updatedAt: inserted.updatedAt
        )
    }

    @MainActor
    static func fetchCached(userId: String, context: ModelContext) throws -> [ChatSession] {
        try context.fetch(fetchDescriptor(userId: userId, soulerId: nil))
            .map(\.asChatSession)
    }

    @MainActor
    static func fetchCached(userId: String, soulerId: UUID, context: ModelContext) throws -> [ChatSession] {
        try context.fetch(fetchDescriptor(userId: userId, soulerId: soulerId))
            .map(\.asChatSession)
    }

    @MainActor
    static func mergeCached(_ remoteSessions: [ChatSession], userId: String, context: ModelContext) throws -> Bool {
        guard !remoteSessions.isEmpty else { return false }

        let targetUserId = userId
        let existing = try context.fetch(
            FetchDescriptor<CachedChatSession>(
                predicate: #Predicate<CachedChatSession> {
                    $0.userId == targetUserId
                }
            )
        )
        var localById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var hasChanges = false

        for remoteSession in remoteSessions {
            if let local = localById[remoteSession.id] {
                if local.mergeIfNeeded(with: remoteSession, userId: userId) {
                    hasChanges = true
                }
            } else {
                let cached = CachedChatSession(session: remoteSession, userId: userId)
                context.insert(cached)
                localById[remoteSession.id] = cached
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }

        return hasChanges
    }

    @MainActor
    static func clearCached(userId: String, context: ModelContext) throws {
        let records = try context.fetch(fetchDescriptor(userId: userId, soulerId: nil))
        guard !records.isEmpty else { return }

        for record in records {
            context.delete(record)
        }
        try context.save()
    }

    private static func fetchDescriptor(
        userId: String,
        soulerId: UUID?
    ) -> FetchDescriptor<CachedChatSession> {
        let targetUserId = userId

        if let soulerId {
            let targetSoulerId = soulerId
            return FetchDescriptor<CachedChatSession>(
                predicate: #Predicate<CachedChatSession> {
                    $0.userId == targetUserId && $0.soulerId == targetSoulerId
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }

        return FetchDescriptor<CachedChatSession>(
            predicate: #Predicate<CachedChatSession> {
                $0.userId == targetUserId
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }
}

@Model
class CachedChatSession {
    @Attribute(.unique) var id: UUID
    var userId: String
    var soulerId: UUID
    var chapterId: UUID?
    var soulerName: String
    var title: String
    var updatedAt: Date

    init(session: ChatSession, userId: String) {
        id = session.id
        self.userId = userId
        soulerId = session.soulerId
        chapterId = session.chapterId
        soulerName = session.soulerName
        title = session.title
        updatedAt = session.updatedAt
    }

    var asChatSession: ChatSession {
        ChatSession(
            id: id,
            soulerId: soulerId,
            chapterId: chapterId,
            soulerName: soulerName,
            title: title,
            updatedAt: updatedAt
        )
    }

    func mergeIfNeeded(with session: ChatSession, userId: String) -> Bool {
        guard session.updatedAt >= updatedAt else { return false }

        let hasChanged = self.userId != userId
            || soulerId != session.soulerId
            || chapterId != session.chapterId
            || soulerName != session.soulerName
            || title != session.title
            || updatedAt != session.updatedAt

        guard hasChanged else { return false }

        self.userId = userId
        soulerId = session.soulerId
        chapterId = session.chapterId
        soulerName = session.soulerName
        title = session.title
        updatedAt = session.updatedAt
        return true
    }
}
