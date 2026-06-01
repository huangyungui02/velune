import Foundation
import Supabase

struct Souler: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var introduction: String
    var imageURL: URL?
    var keywords: [String]
    var checked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        introduction: String,
        imageURL: URL? = nil,
        keywords: [String] = [],
        checked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.introduction = introduction
        self.imageURL = imageURL
        self.keywords = keywords
        self.checked = checked
    }
}

extension Souler {
    private struct Response: Codable {
        var id: UUID
        var name: String
        var introduction: String?
        var wikiId: String?
        var checked: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case introduction
            case wikiId = "wiki_id"
            case checked
        }
    }

    private struct KeywordRow: Decodable {
        var weight: Double?
        var keywords: KeywordValue?
    }

    private struct KeywordWord: Decodable {
        var word: String
    }

    private enum KeywordValue: Decodable {
        case single(KeywordWord)
        case list([KeywordWord])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(KeywordWord.self) {
                self = .single(value)
                return
            }
            self = .list((try? container.decode([KeywordWord].self)) ?? [])
        }

        var word: String? {
            switch self {
            case let .single(value):
                return value.word
            case let .list(values):
                return values.first?.word
            }
        }
    }

    static func get(_ soulerId: UUID) async throws -> Souler {
        let supabase = try Backend.requireSupabase()
        let response: Response = try await supabase
            .from("soulers")
            .select("id, name, introduction, wiki_id, checked")
            .eq("id", value: soulerId)
            .single()
            .execute()
            .value
        let keywords = (try? await fetchKeywords(soulerId, supabase: supabase)) ?? []
        let wikiId = response.wikiId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let imageURL = try await ReadingSoulerItem.resolveImageURLs(wikiIds: [wikiId])[wikiId]

        return Souler(
            id: response.id,
            name: response.name.trimmingCharacters(in: .whitespacesAndNewlines),
            introduction: response.introduction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageURL: imageURL,
            keywords: keywords,
            checked: response.checked
        )
    }

    private static func fetchKeywords(_ soulerId: UUID, supabase: SupabaseClient) async throws -> [String] {
        let rows: [KeywordRow] = try await supabase
            .from("souler_keyword")
            .select("weight, keywords!inner(word)")
            .eq("souler_id", value: soulerId.uuidString)
            .order("weight", ascending: false)
            .limit(10)
            .execute()
            .value

        return rows
            .compactMap { $0.keywords?.word?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
