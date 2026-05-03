import Foundation
import Supabase
import SwiftData

@Model
class Resonance {
    @Attribute(.unique) var id: UUID
    var userId: String
    var soulerId: UUID
    var soulerName: String
    var soulerAvatarURL: String?
    var lastSessionId: UUID?
    var lastSessionTitle: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String = "",
        soulerId: UUID,
        soulerName: String,
        soulerAvatarURL: String? = nil,
        lastSessionId: UUID?,
        lastSessionTitle: String,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.soulerAvatarURL = soulerAvatarURL
        self.lastSessionId = lastSessionId
        self.lastSessionTitle = lastSessionTitle
        self.updatedAt = updatedAt
    }

    func mergeIfNeeded(with resonance: Resonance) -> Bool {
        guard resonance.updatedAt >= updatedAt else { return false }

        let hasChanged = userId != resonance.userId
            || soulerId != resonance.soulerId
            || soulerName != resonance.soulerName
            || soulerAvatarURL != resonance.soulerAvatarURL
            || lastSessionId != resonance.lastSessionId
            || lastSessionTitle != resonance.lastSessionTitle
            || updatedAt != resonance.updatedAt

        guard hasChanged else { return false }

        userId = resonance.userId
        soulerId = resonance.soulerId
        soulerName = resonance.soulerName
        soulerAvatarURL = resonance.soulerAvatarURL
        lastSessionId = resonance.lastSessionId
        lastSessionTitle = resonance.lastSessionTitle
        updatedAt = resonance.updatedAt
        return true
    }
}

extension Resonance {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var lastSessionId: UUID?
        var lastSessionTitle: String?
        var updatedAt: Date
        var soulerName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case lastSessionId = "last_session_id"
            case lastSessionTitle = "last_session_title"
            case updatedAt = "updated_at"
            case soulerName = "souler_name"
        }
    }

    private struct SoulerWikiResponse: Codable {
        var id: UUID
        var wikiId: String?

        enum CodingKeys: String, CodingKey {
            case id
            case wikiId = "wiki_id"
        }
    }

    private struct AvatarResponse: Codable {
        var wikiId: String
        var imagePath: String?
        var updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case wikiId = "wiki_id"
            case imagePath = "image_path"
            case updatedAt = "updated_at"
        }
    }

    private static func mapResponse(_ response: [Response], userId: String) -> [Resonance] {
        let fallbackName = String(localized: "resonance.unknownSouler")
        return response.map { res in
            let trimmedTitle = res.lastSessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedTitle = res.lastSessionId == nil ? "" : trimmedTitle
            return Resonance(
                id: res.id,
                userId: userId,
                soulerId: res.soulerId,
                soulerName: res.soulerName ?? fallbackName,
                soulerAvatarURL: nil,
                lastSessionId: res.lastSessionId,
                lastSessionTitle: resolvedTitle,
                updatedAt: res.updatedAt
            )
        }
    }

    private static func encodeTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func normalizeWikiId(_ value: String?) -> String? {
        let wikiId = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return wikiId.isEmpty ? nil : wikiId
    }

    private static func normalizeImagePath(_ value: String?) -> String? {
        let imagePath = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return imagePath.isEmpty ? nil : imagePath
    }

    private static func versionedURL(_ url: URL, version: String?) -> URL {
        let trimmedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedVersion.isEmpty else { return url }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "v", value: trimmedVersion))
        components.queryItems = queryItems
        return components.url ?? url
    }

    private static func resolveAvatarURL(
        supabase: SupabaseClient,
        imagePath rawImagePath: String?,
        version: String?
    ) throws -> String? {
        guard let imagePath = normalizeImagePath(rawImagePath) else { return nil }

        if imagePath.hasPrefix("http://") || imagePath.hasPrefix("https://") || imagePath.hasPrefix("/") {
            guard let url = URL(string: imagePath) else { return nil }
            return versionedURL(url, version: version).absoluteString
        }

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: imagePath)

        return versionedURL(publicURL, version: version).absoluteString
    }

    private static func fetchAvatarURLBySoulerId(_ soulerIds: [UUID]) async throws -> [UUID: String?] {
        let uniqueSoulerIds = Array(Set(soulerIds))
        guard !uniqueSoulerIds.isEmpty else { return [:] }

        let supabase = try Backend.requireSupabase()
        let soulerRows: [SoulerWikiResponse] = try await supabase
            .from("soulers")
            .select("id, wiki_id")
            .in("id", values: uniqueSoulerIds.map(\.uuidString))
            .execute()
            .value

        let wikiIdBySoulerId = Dictionary(
            uniqueKeysWithValues: soulerRows.compactMap { row -> (UUID, String)? in
                guard let wikiId = normalizeWikiId(row.wikiId) else { return nil }
                return (row.id, wikiId)
            }
        )
        let uniqueWikiIds = Array(Set(wikiIdBySoulerId.values))
        guard !uniqueWikiIds.isEmpty else { return [:] }

        let avatarRows: [AvatarResponse] = try await supabase
            .from("souler_avatars")
            .select("wiki_id, image_path, updated_at")
            .in("wiki_id", values: uniqueWikiIds)
            .execute()
            .value

        let avatarURLByWikiId = Dictionary(
            uniqueKeysWithValues: avatarRows.compactMap { row -> (String, String?)? in
                guard let wikiId = normalizeWikiId(row.wikiId) else { return nil }
                return (
                    wikiId,
                    try? resolveAvatarURL(
                        supabase: supabase,
                        imagePath: row.imagePath,
                        version: row.updatedAt
                    )
                )
            }
        )

        return Dictionary(
            uniqueKeysWithValues: wikiIdBySoulerId.map { soulerId, wikiId in
                (soulerId, avatarURLByWikiId[wikiId] ?? nil)
            }
        )
    }

    private static func attachAvatarURLs(to resonances: [Resonance]) async throws -> [Resonance] {
        let avatarURLBySoulerId = try await fetchAvatarURLBySoulerId(resonances.map(\.soulerId))
        guard !avatarURLBySoulerId.isEmpty else { return resonances }

        for resonance in resonances {
            if let avatarURL = avatarURLBySoulerId[resonance.soulerId] {
                resonance.soulerAvatarURL = avatarURL
            }
        }

        return resonances
    }

    static func getPage(limit: Int, offset: Int) async throws -> [Resonance] {
        let pageSize = max(limit, 1)
        let pageOffset = max(offset, 0)
        let upperBound = max(pageOffset + pageSize - 1, pageOffset)
        let userId = try await AuthManager.shared.getUserId()

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("resonances_with_souler")
            .select("id, souler_id, last_session_id, last_session_title, updated_at, souler_name")
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return try await attachAvatarURLs(to: mapResponse(response, userId: userId.uuidString))
    }

    static func getUpdatedSince(
        _ date: Date,
        limit: Int,
        offset: Int,
        overlapSeconds: TimeInterval = 1
    ) async throws -> [Resonance] {
        let pageSize = max(limit, 1)
        let pageOffset = max(offset, 0)
        let upperBound = max(pageOffset + pageSize - 1, pageOffset)
        let overlappedDate = date.addingTimeInterval(-max(overlapSeconds, 0))
        let userId = try await AuthManager.shared.getUserId()

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("resonances_with_souler")
            .select("id, souler_id, last_session_id, last_session_title, updated_at, souler_name")
            .gte("updated_at", value: encodeTimestamp(overlappedDate))
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return try await attachAvatarURLs(to: mapResponse(response, userId: userId.uuidString))
    }

    static func getUpdatedSince(
        _ date: Date,
        pageSize: Int,
        overlapSeconds: TimeInterval = 1
    ) async throws -> [Resonance] {
        let limitedPageSize = max(pageSize, 1)
        var offset = 0
        var all: [Resonance] = []

        while true {
            let page = try await getUpdatedSince(
                date,
                limit: limitedPageSize,
                offset: offset,
                overlapSeconds: overlapSeconds
            )
            all.append(contentsOf: page)

            guard page.count == limitedPageSize else { break }
            offset += page.count
        }

        return all
    }

    @MainActor
    static func fetchCached(userId: String, context: ModelContext) throws -> [Resonance] {
        try context.fetch(fetchDescriptor(userId: userId))
    }

    @MainActor
    static func mergeCached(_ remoteResonances: [Resonance], userId: String, context: ModelContext) throws -> Bool {
        guard !remoteResonances.isEmpty else { return false }

        let localRecords = try context.fetch(fetchDescriptor(userId: userId))
        var localById = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        var hasChanges = false

        for remote in remoteResonances {
            remote.userId = userId

            if let local = localById[remote.id] {
                if local.mergeIfNeeded(with: remote) {
                    hasChanges = true
                }
            } else {
                context.insert(remote)
                localById[remote.id] = remote
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }

        return hasChanges
    }

    @MainActor
    static func refreshCachedAvatarURLs(userId: String, context: ModelContext) async throws -> Bool {
        let localRecords = try context.fetch(fetchDescriptor(userId: userId))
        guard !localRecords.isEmpty else { return false }

        let avatarURLBySoulerId = try await fetchAvatarURLBySoulerId(localRecords.map(\.soulerId))
        var hasChanges = false

        for record in localRecords {
            guard let avatarURL = avatarURLBySoulerId[record.soulerId] else { continue }
            if record.soulerAvatarURL != avatarURL {
                record.soulerAvatarURL = avatarURL
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
        let records = try context.fetch(fetchDescriptor(userId: userId))
        guard !records.isEmpty else { return }

        for record in records {
            context.delete(record)
        }

        try context.save()
    }

    private static func fetchDescriptor(userId: String) -> FetchDescriptor<Resonance> {
        let targetUserId = userId
        return FetchDescriptor<Resonance>(
            predicate: #Predicate<Resonance> { $0.userId == targetUserId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }
}
