import Foundation
import Supabase

struct ResonanceMessage: Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID
    var soulerId: UUID
    var role: Role
    var content: String
    var createdAt: Date
}

extension ResonanceMessage {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var role: Role
        var content: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case role
            case content
            case createdAt = "created_at"
        }
    }

    private struct SendRequest: Encodable {
        var soulerId: String
        var content: String
    }

    static func getHistory(soulerId: UUID) async throws -> [ResonanceMessage] {
        let response: [Response] = try await supabase
            .from("resonance_messages")
            .select("id, souler_id, role, content, created_at")
            .eq("souler_id", value: soulerId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response.map { item in
            ResonanceMessage(
                id: item.id,
                soulerId: item.soulerId,
                role: item.role,
                content: item.content,
                createdAt: item.createdAt
            )
        }
    }

    static func send(soulerId: UUID, content: String) async throws {
        let request = SendRequest(
            soulerId: soulerId.uuidString,
            content: content
        )

        struct SendResponse: Decodable {
            var ok: Bool
        }

        let response: SendResponse = try await supabase.functions.invoke(
            "resonance-chat",
            options: FunctionInvokeOptions(body: request)
        )

        if !response.ok {
            throw NSError(
                domain: "ResonanceChat",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "resonance chat failed"]
            )
        }
    }
}
