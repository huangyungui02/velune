import Foundation
import Supabase

struct Souler: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var bio: String

    init(id: UUID = UUID(), name: String, bio: String) {
        self.id = id
        self.name = name
        self.bio = bio
    }
}

extension Souler {
    static func get(_ soulerId: UUID) async throws -> Souler {
        struct Response: Codable {
            var id: UUID
            var name: String
            var bio: String?
        }

        let supabase = try Backend.requireSupabase()
        let res: Response = try await supabase
            .from("soulers")
            .select("id, name, bio")
            .eq("id", value: soulerId)
            .single()
            .execute()
            .value

        return Souler(id: res.id, name: res.name, bio: res.bio ?? "")
    }
}
