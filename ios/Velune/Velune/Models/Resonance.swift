import Foundation
import Supabase
import SwiftData

@Model
class Resonance {
    @Attribute(.unique) var id: UUID
    var userId: String
    var soulerId: UUID
    var soulerName: String
    var lastSessionId: UUID?
    var lastSessionTitle: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String = "",
        soulerId: UUID,
        soulerName: String,
        lastSessionId: UUID?,
        lastSessionTitle: String,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.lastSessionId = lastSessionId
        self.lastSessionTitle = lastSessionTitle
        self.updatedAt = updatedAt
    }

    func mergeIfNeeded(with resonance: Resonance) -> Bool {
        guard resonance.updatedAt >= updatedAt else { return false }

        let hasChanged = userId != resonance.userId
            || soulerId != resonance.soulerId
            || soulerName != resonance.soulerName
            || lastSessionId != resonance.lastSessionId
            || lastSessionTitle != resonance.lastSessionTitle
            || updatedAt != resonance.updatedAt

        guard hasChanged else { return false }

        userId = resonance.userId
        soulerId = resonance.soulerId
        soulerName = resonance.soulerName
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
        var souler: SoulerName?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case lastSessionId = "last_session_id"
            case lastSessionTitle = "last_session_title"
            case updatedAt = "updated_at"
            case souler = "soulers"
        }
    }

    private struct SoulerName: Codable {
        var name: String
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
                soulerName: res.souler?.name ?? fallbackName,
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

    static func getPage(limit: Int, offset: Int) async throws -> [Resonance] {
        let pageSize = max(limit, 1)
        let pageOffset = max(offset, 0)
        let upperBound = max(pageOffset + pageSize - 1, pageOffset)
        let userId = try await AuthManager.shared.getUserId()

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("resonances")
            .select("id, souler_id, last_session_id, last_session_title, updated_at, soulers(name)")
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return mapResponse(response, userId: userId.uuidString)
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
            .from("resonances")
            .select("id, souler_id, last_session_id, last_session_title, updated_at, soulers(name)")
            .gte("updated_at", value: encodeTimestamp(overlappedDate))
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return mapResponse(response, userId: userId.uuidString)
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
