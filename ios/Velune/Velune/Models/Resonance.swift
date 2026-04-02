import Foundation
import Supabase

struct Resonance: Identifiable, Equatable {
    var id: UUID
    var soulerId: UUID
    var soulerName: String
    var lastSessionId: UUID?
    var lastSessionTitle: String
    var count: Int
    var createdAt: Date
    var updatedAt: Date
}

extension Resonance {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var lastSessionId: UUID?
        var lastSessionTitle: String?
        var count: Int?
        var createdAt: Date
        var updatedAt: Date
        var souler: SoulerName?

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case lastSessionId = "last_session_id"
            case lastSessionTitle = "last_session_title"
            case count
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case souler = "soulers"
        }
    }

    private struct SoulerName: Codable {
        var name: String
    }

    private static func mapResponse(_ response: [Response]) -> [Resonance] {
        let fallbackName = String(localized: "resonance.unknownSouler")
        return response.map { res in
            let trimmedTitle = res.lastSessionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedTitle = res.lastSessionId == nil ? "" : trimmedTitle
            return Resonance(
                id: res.id,
                soulerId: res.soulerId,
                soulerName: res.souler?.name ?? fallbackName,
                lastSessionId: res.lastSessionId,
                lastSessionTitle: resolvedTitle,
                count: max(res.count ?? 1, 1),
                createdAt: res.createdAt,
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
        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("resonances")
            .select("id, souler_id, last_session_id, last_session_title, count, created_at, updated_at, soulers(name)")
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return mapResponse(response)
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

        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("resonances")
            .select("id, souler_id, last_session_id, last_session_title, count, created_at, updated_at, soulers(name)")
            .gte("updated_at", value: encodeTimestamp(overlappedDate))
            .order("updated_at", ascending: false)
            .range(from: pageOffset, to: upperBound)
            .execute()
            .value

        return mapResponse(response)
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
}
