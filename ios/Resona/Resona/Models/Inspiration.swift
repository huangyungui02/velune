import Foundation
import Supabase
import SwiftData

@Model
class Inspiration {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var status: String

    @Relationship(deleteRule: .cascade, inverse: \Echo.inspiration)
    var echoes: [Echo] = []

    init(id: UUID = UUID(), content: String, createdAt: Date = .now, status: String = "pending") {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.status = status
    }

    func update(from: Inspiration) {
        self.status = from.status
        for echo in from.echoes {
            if !self.echoes.contains(where: { $0.id == echo.id }) {
                self.echoes.append(echo)
            }
        }
    }
}

extension Inspiration {
    nonisolated struct Response: Identifiable, Codable, Sendable {
        var id: UUID
        var content: String
        var createdAt: Date
        var status: String

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case createdAt = "created_at"
            case status
        }
    }

    static func get(_ inspirationId: UUID) async throws -> Inspiration {
        let response: Response = try await supabase
            .from("inspirations")
            .select("id, content, created_at, status")
            .eq("id", value: inspirationId)
            .single()
            .execute()
            .value

        return Inspiration(id: response.id, content: response.content, createdAt: response.createdAt, status: response.status)
    }

    static func getAll() async throws -> [Inspiration] {
        let userId = try await AuthManager.shared.getUserId()

        let response: [Response] = try await supabase
            .from("inspirations")
            .select("id, content, created_at, status")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { response in
            Inspiration(id: response.id, content: response.content, createdAt: response.createdAt)
        }
    }

    static func create(_ inspiration: Inspiration) async throws {
        struct Data: Codable {
            var id: UUID
            var userId: UUID
            var content: String
            var createdAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case content
                case createdAt = "created_at"
            }
        }

        let userId = try await AuthManager.shared.getUserId()
        let data = Data(
            id: inspiration.id,
            userId: userId,
            content: inspiration.content,
            createdAt: inspiration.createdAt
        )

        try await supabase
            .from("inspirations")
            .insert(data)
            .execute()
    }

    static func delete(_ inspirationId: UUID) async throws {
        try await supabase
            .from("inspirations")
            .delete()
            .eq("id", value: inspirationId)
            .execute()
    }
}

extension Inspiration {
    static let sampleData: [Inspiration] =
        [
            Inspiration(
                content: "Today I suddenly had a great idea! I want to write these concepts down—maybe they’ll come in handy one day.",
                createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                status: "completed"
            ),
            Inspiration(
                content: "What if I build an app that helps people capture inspiration anytime, anywhere—before those fleeting thoughts disappear?",
                createdAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                status: "completed"
            ),
            Inspiration(
                content: "Inspired by a book: the best ideas often come from collisions across disciplines. Stay curious and expose yourself to new things.",
                createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                status: "completed"
            ),
            Inspiration(
                content: "Walking in the park today, I saw sunlight filtering through the leaves and thought: this could be a great visual motif for design. Nature really is the best teacher.",
                createdAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
                status: "completed"
            ),
            Inspiration(
                content: "A sudden spark: what if I combine this concept with that technology? Worth exploring.",
                createdAt: Date(),
                status: "completed"
            )
        ]
}
