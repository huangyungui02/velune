import Foundation
import Supabase
import SwiftData

@Model
class Glimmer {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var status: String

    @Relationship(deleteRule: .cascade, inverse: \Echo.glimmer)
    var echoes: [Echo] = []

    init(id: UUID = UUID(), content: String, createdAt: Date = .now, status: String = "pending") {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.status = status
    }

    func update(from: Glimmer) {
        self.status = from.status
        for echo in from.echoes {
            if !self.echoes.contains(where: { $0.id == echo.id }) {
                self.echoes.append(echo)
            }
        }
    }
}

extension Glimmer {
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

    static func get(_ glimmerId: UUID) async throws -> Glimmer {
        let response: Response = try await supabase
            .from("glimmers")
            .select("id, content, created_at, status")
            .eq("id", value: glimmerId)
            .single()
            .execute()
            .value

        return Glimmer(id: response.id, content: response.content, createdAt: response.createdAt, status: response.status)
    }

    static func getAll() async throws -> [Glimmer] {
        let userId = try await AuthManager.shared.getUserId()

        let response: [Response] = try await supabase
            .from("glimmers")
            .select("id, content, created_at, status")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { response in
            Glimmer(id: response.id, content: response.content, createdAt: response.createdAt)
        }
    }

    static func create(_ glimmer: Glimmer) async throws {
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
            id: glimmer.id,
            userId: userId,
            content: glimmer.content,
            createdAt: glimmer.createdAt
        )

        try await supabase
            .from("glimmers")
            .insert(data)
            .execute()
    }

    static func delete(_ glimmerId: UUID) async throws {
        try await supabase
            .from("glimmers")
            .delete()
            .eq("id", value: glimmerId)
            .execute()
    }
}

extension Glimmer {
    @MainActor static let sampleData: [Glimmer] =
        [
            Glimmer(
                content: "Today I suddenly had a great idea! I want to write these concepts down—maybe they’ll come in handy one day.",
                createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                status: "completed"
            ),
            Glimmer(
                content: "What if I build an app that helps people capture glimmer anytime, anywhere—before those fleeting thoughts disappear?",
                createdAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                status: "completed"
            ),
            Glimmer(
                content: "Inspired by a book: the best ideas often come from collisions across disciplines. Stay curious and expose yourself to new things.",
                createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                status: "completed"
            ),
            Glimmer(
                content: "Walking in the park today, I saw sunlight filtering through the leaves and thought: this could be a great visual motif for design. Nature really is the best teacher.",
                createdAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
                status: "completed"
            ),
            Glimmer(
                content: "A sudden spark: what if I combine this concept with that technology? Worth exploring.",
                createdAt: Date(),
                status: "completed"
            )
        ]
}
