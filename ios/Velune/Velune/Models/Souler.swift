import Foundation
import Supabase

struct Souler: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var bio: String
    var imageURL: URL?
    var keywords: [String]

    init(
        id: UUID = UUID(),
        name: String,
        bio: String,
        imageURL: URL? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.bio = bio
        self.imageURL = imageURL
        self.keywords = keywords
    }
}

extension Souler {
    private struct Response: Codable {
        var id: UUID
        var name: String
        var bio: String?
        var wikiId: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case bio
            case wikiId = "wiki_id"
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
            .select("id, name, bio, wiki_id")
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
            bio: response.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageURL: imageURL,
            keywords: keywords
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
