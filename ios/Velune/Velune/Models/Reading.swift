import Foundation
import Supabase

struct ReadingSoulerItem: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var name: String
    var imageURL: URL?
}

struct ReadingSection: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String
    var soulers: [ReadingSoulerItem]
}

extension ReadingSoulerItem {
    private struct SoulerRow: Decodable {
        var id: UUID
        var wikiId: String?
        var profiles: [ProfileRow]?

        enum CodingKeys: String, CodingKey {
            case id
            case wikiId = "wiki_id"
            case profiles = "souler_profile"
        }
    }

    private struct ProfileRow: Decodable {
        var name: String?
        var lang: String?
    }

    private struct AvatarRow: Decodable {
        var wikiId: String
        var avatar: String?
        var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case wikiId = "wiki_id"
            case avatar
            case updatedAt = "updated_at"
        }
    }

    private static let fallbackName = String(localized: "resonance.unknownSouler")

    static func search(query: String, limit: Int = 24) async throws -> [ReadingSoulerItem] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .prefix(80)

        guard !normalizedQuery.isEmpty else { return [] }

        let safeQuery = escapeSearchPattern(String(normalizedQuery))
        let boundedLimit = min(max(limit, 1), 50)
        let supabase = try Backend.requireSupabase()
        let prefixRows: [SoulerRow] = try await supabase
            .from("soulers")
            .select("id, wiki_id, souler_profile!inner(name, lang)")
            .eq("checked", value: true)
            .eq("souler_profile.lang", value: AppLanguage.current.apiLanguageCode)
            .ilike("souler_profile.name", pattern: "\(safeQuery)%")
            .order("updated_at", ascending: false)
            .limit(boundedLimit)
            .execute()
            .value

        var rowsById = Dictionary(uniqueKeysWithValues: prefixRows.map { ($0.id, $0) })
        if rowsById.count < boundedLimit {
            let fuzzyRows: [SoulerRow] = try await supabase
                .from("soulers")
                .select("id, wiki_id, souler_profile!inner(name, lang)")
                .eq("checked", value: true)
                .eq("souler_profile.lang", value: AppLanguage.current.apiLanguageCode)
                .ilike("souler_profile.name", pattern: "%\(safeQuery)%")
                .order("updated_at", ascending: false)
                .limit(boundedLimit)
                .execute()
                .value

            for row in fuzzyRows where rowsById.count < boundedLimit {
                rowsById[row.id] = row
            }
        }

        return try await mapRows(Array(rowsById.values))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func resolveImageURLs(wikiIds: [String?]) async throws -> [String: URL] {
        let normalizedWikiIds = Array(Set(wikiIds.compactMap(normalizeWikiId)))
        guard !normalizedWikiIds.isEmpty else { return [:] }

        let supabase = try Backend.requireSupabase()
        let avatarRows: [AvatarRow] = try await supabase
            .from("soulers")
            .select("wiki_id, avatar, updated_at")
            .in("wiki_id", values: normalizedWikiIds)
            .execute()
            .value

        var result: [String: URL] = [:]
        for row in avatarRows {
            guard let wikiId = normalizeWikiId(row.wikiId),
                  let imagePath = row.avatar?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !imagePath.isEmpty,
                  let url = try Backend.publicStorageURL(
                    bucket: "avatars",
                    path: imagePath,
                    version: row.updatedAt
                  )
            else { continue }
            result[wikiId] = url
        }
        return result
    }

    private static func mapRows(_ rows: [SoulerRow]) async throws -> [ReadingSoulerItem] {
        let avatarByWikiId = try await resolveImageURLs(wikiIds: rows.map(\.wikiId))
        let nameBySoulerId = try await fetchProfileNames(soulerIds: rows.map(\.id))
        return rows.map { row in
            let nestedName = row.profiles?.first?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileName = nameBySoulerId[row.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = nestedName?.isEmpty == false ? nestedName : profileName
            let wikiId = normalizeWikiId(row.wikiId)
            return ReadingSoulerItem(
                id: row.id,
                name: name?.isEmpty == false ? name! : fallbackName,
                imageURL: wikiId.flatMap { avatarByWikiId[$0] }
            )
        }
    }

    private struct ProfileNameRow: Decodable {
        var soulerId: UUID
        var name: String

        enum CodingKeys: String, CodingKey {
            case soulerId = "souler_id"
            case name
        }
    }

    private static func fetchProfileNames(soulerIds: [UUID]) async throws -> [UUID: String] {
        let ids = Array(Set(soulerIds))
        guard !ids.isEmpty else { return [:] }

        let rows: [ProfileNameRow] = try await Backend.requireSupabase()
            .from("souler_profile")
            .select("souler_id, name")
            .in("souler_id", values: ids.map(\.uuidString))
            .eq("lang", value: AppLanguage.current.apiLanguageCode)
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.soulerId, $0.name) })
    }

    private static func normalizeWikiId(_ value: String?) -> String? {
        let wikiId = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return wikiId.isEmpty ? nil : wikiId
    }

    private static func escapeSearchPattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}

extension ReadingSection {
    private struct SectionRow: Decodable {
        var id: UUID
        var profiles: [SectionProfileRow]?

        enum CodingKeys: String, CodingKey {
            case id
            case profiles = "discover_section_profile"
        }
    }

    private struct SectionProfileRow: Decodable {
        var lang: String
        var title: String
        var subtitle: String?
    }

    private struct ItemRow: Decodable {
        var sectionId: UUID
        var soulerId: UUID

        enum CodingKeys: String, CodingKey {
            case sectionId = "section_id"
            case soulerId = "souler_id"
        }
    }

    private struct SoulerRow: Decodable {
        var id: UUID
        var wikiId: String?
        var profiles: [SoulerProfileRow]?

        enum CodingKeys: String, CodingKey {
            case id
            case wikiId = "wiki_id"
            case profiles = "souler_profile"
        }
    }

    private struct SoulerProfileRow: Decodable {
        var name: String?
        var lang: String?
    }

    static func featured(preferredLang: String = AppLanguage.current.apiLanguageCode) async throws -> [ReadingSection] {
        let supabase = try Backend.requireSupabase()
        var sectionRows = try await fetchSections(lang: preferredLang, supabase: supabase)
        if sectionRows.isEmpty, preferredLang != "zh" {
            sectionRows = try await fetchSections(lang: "zh", supabase: supabase)
        }
        if sectionRows.isEmpty {
            let allRows: [SectionRow] = try await supabase
                .from("discover_sections")
                .select("id, discover_section_profile!inner(lang, title, subtitle)")
                .eq("is_active", value: true)
                .eq("discover_section_profile.lang", value: "zh")
                .order("sort_order", ascending: true)
                .order("updated_at", ascending: false)
                .execute()
                .value

            if let fallbackLang = allRows.first?.profiles?.first?.lang.trimmingCharacters(in: .whitespacesAndNewlines),
               !fallbackLang.isEmpty
            {
                sectionRows = allRows.filter {
                    $0.profiles?.first?.lang.trimmingCharacters(in: .whitespacesAndNewlines) == fallbackLang
                }
            }
        }

        let sectionIds = sectionRows.map(\.id)
        guard !sectionIds.isEmpty else { return [] }

        let itemRows: [ItemRow] = try await supabase
            .from("discover_section_items")
            .select("section_id, souler_id")
            .in("section_id", values: sectionIds.map(\.uuidString))
            .order("sort_order", ascending: true)
            .execute()
            .value

        let soulerIds = Array(Set(itemRows.map(\.soulerId)))
        guard !soulerIds.isEmpty else { return [] }

        let soulerRows: [SoulerRow] = try await supabase
            .from("soulers")
            .select("id, wiki_id, souler_profile!inner(name, lang)")
            .in("id", values: soulerIds.map(\.uuidString))
            .eq("checked", value: true)
            .eq("souler_profile.lang", value: preferredLang)
            .execute()
            .value

        let avatarByWikiId = try await ReadingSoulerItem.resolveImageURLs(wikiIds: soulerRows.map(\.wikiId))
        let soulerById = Dictionary(uniqueKeysWithValues: soulerRows.map { row in
            let name = row.profiles?.first?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let wikiId = row.wikiId?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                row.id,
                ReadingSoulerItem(
                    id: row.id,
                    name: name?.isEmpty == false ? name! : String(localized: "resonance.unknownSouler"),
                    imageURL: wikiId.flatMap { avatarByWikiId[$0] }
                )
            )
        })

        var soulerIdsBySectionId: [UUID: [UUID]] = [:]
        for item in itemRows where soulerById[item.soulerId] != nil {
            soulerIdsBySectionId[item.sectionId, default: []].append(item.soulerId)
        }

        return sectionRows.compactMap { section in
            let soulers = (soulerIdsBySectionId[section.id] ?? []).compactMap { soulerById[$0] }
            guard !soulers.isEmpty else { return nil }
            return ReadingSection(
                id: section.id,
                title: section.profiles?.first?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                subtitle: section.profiles?.first?.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                soulers: soulers
            )
        }
    }

    private static func fetchSections(lang: String, supabase: SupabaseClient) async throws -> [SectionRow] {
        try await supabase
            .from("discover_sections")
            .select("id, discover_section_profile!inner(lang, title, subtitle)")
            .eq("is_active", value: true)
            .eq("discover_section_profile.lang", value: lang)
            .order("sort_order", ascending: true)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }
}
