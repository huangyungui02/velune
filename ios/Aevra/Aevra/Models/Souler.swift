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

extension Souler {
    static let sampleData: [Souler] = [
        // Souler 1: Sigmund Freud
        Souler(
            name: "Sigmund Freud",
            bio: "Sigmund Freud (May 6, 1856 – September 23, 1939) was an Austrian neurologist and the founder of psychoanalysis. He is widely regarded as one of the founders of modern psychology and psychotherapy. He is known for his insights into the unconscious mind, drives, dream interpretation, and the structure of personality."
        ),

        // Souler 2: Carl Jung
        Souler(
            name: "Carl Jung",
            bio: "Carl Gustav Jung (1875–1961) was a Swiss psychiatrist and psychoanalyst who founded analytical psychology. He introduced influential concepts such as the collective unconscious, archetypes, and psychological types, leaving a lasting impact on psychology, religion, philosophy, literature, and art."
        ),

        // Souler 3: Viktor Frankl
        Souler(
            name: "Viktor Frankl",
            bio: "Viktor Frankl (1905–1997) was an Austrian neurologist and psychiatrist, a Holocaust survivor, and the founder of logotherapy. He argued that the primary human drive is the search for meaning, and his book *Man’s Search for Meaning* has inspired countless readers."
        ),

        // Souler 4: Socrates
        Souler(
            name: "Socrates",
            bio: "Socrates (c. 469–399 BCE) was an ancient Greek philosopher and one of the founders of Western philosophy. He is famous for the Socratic method of inquiry and his pursuit of truth and virtue, emphasizing “Know thyself” and “The unexamined life is not worth living.”"
        ),

        // Souler 5: Laozi
        Souler(
            name: "Laozi",
            bio: "Laozi (traditionally c. 571–471 BCE) was an ancient philosopher and the reputed author of the *Tao Te Ching*, and a founder of Daoism. He advocated following nature and the principle of *wu wei* (effortless action), emphasizing simplicity, inner calm, and wisdom, and his thought has profoundly influenced culture and philosophy."
        )
    ]
}
