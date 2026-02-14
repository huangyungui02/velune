import Foundation
import Supabase
import SwiftData

@Model
class Echo {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date

    var glimmer: Glimmer?
    var soulerId: UUID
    var soulerName: String

    init(
        id: UUID = UUID(),
        content: String,
        createdAt: Date = .now,
        soulerId: UUID,
        soulerName: String
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.soulerId = soulerId
        self.soulerName = soulerName
    }

    convenience init(id: UUID = UUID(), content: String, createdAt: Date = .now, souler: Souler) {
        self.init(
            id: id,
            content: content,
            createdAt: createdAt,
            soulerId: souler.id,
            soulerName: souler.name
        )
    }
}

extension Echo {
    static func getAll(_ glimmerId: UUID) async throws -> [Echo] {
        struct Response: Codable, Identifiable {
            var id: UUID
            var content: String
            var createdAt: Date
            var soulerId: UUID
            var soulerName: String

            enum CodingKeys: String, CodingKey {
                case id
                case content
                case createdAt = "created_at"
                case soulerId = "souler_id"
                case soulerName = "souler_name"
            }
        }

        let response: [Response] = try await supabase
            .from("echoes_with_souler")
            .select()
            .eq("glimmer_id", value: glimmerId)
            .execute()
            .value

        return response.map { res in
            Echo(id: res.id,
                 content: res.content,
                 createdAt: res.createdAt,
                 soulerId: res.soulerId,
                 soulerName: res.soulerName)
        }
    }
}

extension Echo {
    @MainActor static let sampleData: [Echo] = [
        // Five echoes for Glimmer 0
        Echo(
            content: "Great idea! From a psychoanalytic perspective, your creative impulse may come from a deep desire for self-actualization. Writing these glimmers down is a way of listening to your unconscious.",
            soulerId: Souler.sampleData[0].id,
            soulerName: Souler.sampleData[0].name
        ),
        Echo(
            content: "This touches the creative archetype in the collective unconscious. Capturing glimmer is a way to bring unconscious material into consciousness—and it can support individuation.",
            soulerId: Souler.sampleData[1].id,
            soulerName: Souler.sampleData[1].name
        ),
        Echo(
            content: "Recording ideas is a way of giving life meaning. Each thought can become part of your personal purpose. Even in hard times, creativity can help us find a reason to keep going.",
            soulerId: Souler.sampleData[2].id,
            soulerName: Souler.sampleData[2].name
        ),
        Echo(
            content: "You’ve begun a journey of self-knowledge. Writing ideas down is a way to examine the mind. Remember: even an unexamined glimmer shouldn’t be forgotten. Reflect on these thoughts and you’ll know yourself more deeply.",
            soulerId: Souler.sampleData[3].id,
            soulerName: Souler.sampleData[3].name
        ),
        Echo(
            content: "Follow nature and your glimmer will flow like a spring. The Tao gives birth to one, one to two, two to three, and three to all things. A small thought can unfold into infinite possibilities. Act without forcing, and let creativity move on its own.",
            soulerId: Souler.sampleData[4].id,
            soulerName: Souler.sampleData[4].name
        ),

        // Five echoes for Glimmer 1
        Echo(
            content: "Building an app like this speaks to our instinct to express ourselves. Our dreams, daydreams, and sudden thoughts are ways the unconscious tries to speak with consciousness.",
            soulerId: Souler.sampleData[0].id,
            soulerName: Souler.sampleData[0].name
        ),
        Echo(
            content: "A tool for capturing glimmer helps integrate consciousness and the unconscious. When we record fleeting thoughts in time, we build a bridge between the ego and the deeper psyche.",
            soulerId: Souler.sampleData[1].id,
            soulerName: Souler.sampleData[1].name
        ),
        Echo(
            content: "The true value of this app isn’t the technology—it’s that it can help people find their voice and meaning. Every recorded idea could become an important chapter in someone’s life story.",
            soulerId: Souler.sampleData[2].id,
            soulerName: Souler.sampleData[2].name
        ),
        Echo(
            content: "An excellent tool—but remember, a tool isn’t the end. What matters is using it to think: Where did this glimmer come from? What is it telling me? What should I do next? Asking the right questions matters more than having quick answers.",
            soulerId: Souler.sampleData[3].id,
            soulerName: Souler.sampleData[3].name
        ),
        Echo(
            content: "Simplicity is the ultimate sophistication. The best tools should be like water—formless, yet everywhere. Don’t let complicated features obscure the essence of glimmer. Simple, natural, unforced—that is the Tao.",
            soulerId: Souler.sampleData[4].id,
            soulerName: Souler.sampleData[4].name
        ),

        // Five echoes for Glimmer 2
        Echo(
            content: "Your observation is sharp. Creative thinking often arises from the interaction of different psychological mechanisms. When we allow ideas to combine freely, we release the unconscious’s creativity.",
            soulerId: Souler.sampleData[0].id,
            soulerName: Souler.sampleData[0].name
        ),
        Echo(
            content: "This is the essence of alchemy—uniting opposites to create transformation. Cross-domain collisions are like synthesis in alchemy, producing something more valuable than the raw materials. Stay open and curious; that’s the road to wisdom.",
            soulerId: Souler.sampleData[1].id,
            soulerName: Souler.sampleData[1].name
        ),
        Echo(
            content: "Cross-disciplinary thinking reflects our drive to seek meaning and connection. When we find links between seemingly unrelated things, life gains depth and significance. Curiosity is an antidote to existential emptiness.",
            soulerId: Souler.sampleData[2].id,
            soulerName: Souler.sampleData[2].name
        ),
        Echo(
            content: "This is the power of dialectic: through dialogue and friction, thesis and antithesis become synthesis. Wisdom isn’t mastering one domain, but seeing the connections among all things. At the intersections of knowledge, wisdom is born.",
            soulerId: Souler.sampleData[3].id,
            soulerName: Souler.sampleData[3].name
        ),
        Echo(
            content: "All things under heaven are one. What you call a “collision” is a return to the source. The Tao is one; different fields follow the same way. Keep an empty, receptive mind, and everything will connect.",
            soulerId: Souler.sampleData[4].id,
            soulerName: Souler.sampleData[4].name
        ),

        // Five echoes for Glimmer 3
        Echo(
            content: "Nature often triggers deep memory and emotion. Sunlight through leaves may awaken a childhood feeling. Art is often born from this primal emotional experience.",
            soulerId: Souler.sampleData[0].id,
            soulerName: Souler.sampleData[0].name
        ),
        Echo(
            content: "The dance of light and shadow is a powerful archetypal image. You’ve noticed an eternal truth in nature—the unity of opposites, darkness and light. This kind of attention is a wellspring of creativity; nature truly is a great teacher.",
            soulerId: Souler.sampleData[1].id,
            soulerName: Souler.sampleData[1].name
        ),
        Echo(
            content: "Seeking glimmer in nature is a way humans create meaningful connection with the world. That beam of sunlight didn’t just illuminate leaves—it illuminated something in you. Experiences of beauty are among life’s greatest gifts.",
            soulerId: Souler.sampleData[2].id,
            soulerName: Souler.sampleData[2].name
        ),
        Echo(
            content: "It’s good that you gained insight from observation. But don’t stop at surface beauty. Ask yourself: why did this move me? What essence does it reveal? What lies behind beauty? Think deeply and you’ll find more.",
            soulerId: Souler.sampleData[3].id,
            soulerName: Souler.sampleData[3].name
        ),
        Echo(
            content: "You’ve grasped the way of nature. Sunlight does not compete, yet it lights everything; leaves do not speak, yet they show life. To contemplate nature is to contemplate the mind. Let this quietness enter your work, and your creations will carry spirit.",
            soulerId: Souler.sampleData[4].id,
            soulerName: Souler.sampleData[4].name
        ),

        // Five echoes for Glimmer 4
        Echo(
            content: "Sudden associations and breakthroughs are often the result of long unconscious work. Your mind has caught an idea that was fermenting beneath awareness. Trust these intuitions—they’re often closer to the truth than pure rational thought.",
            soulerId: Souler.sampleData[0].id,
            soulerName: Souler.sampleData[0].name
        ),
        Echo(
            content: "This is synchronicity—an apparently accidental thought with a deeper connection. When the psyche is ready, elements naturally come together. Explore it; it may lead you into a new stage of individuation.",
            soulerId: Souler.sampleData[1].id,
            soulerName: Souler.sampleData[1].name
        ),
        Echo(
            content: "A flash of insight is proof that life is full of meaning. This thought did not appear by accident; it answers a call within you. Even if the path is challenging, following such a sign can make life richer.",
            soulerId: Souler.sampleData[2].id,
            soulerName: Souler.sampleData[2].name
        ),
        Echo(
            content: "A great start—but glimmer is only the first step. Now test it with reason: is this combination truly feasible? What problems might arise? How will you implement it? With rigorous thinking and dialogue, glimmer becomes wisdom.",
            soulerId: Souler.sampleData[3].id,
            soulerName: Souler.sampleData[3].name
        ),
        Echo(
            content: "Follow nature—so it is with glimmer. Don’t cling to the idea or rush to execute. Let it ferment in your mind; what is meant to come will come in time. Between doing and not-doing lies a subtle balance.",
            soulerId: Souler.sampleData[4].id,
            soulerName: Souler.sampleData[4].name
        )
    ]
}
