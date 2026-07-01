import Foundation
import Supabase

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = try .object(container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self {
            return value
        }
        return nil
    }

    var stringValue: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case .object, .array, .null:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case let .number(value):
            return Int(value)
        case let .string(value):
            return Int(value)
        case .bool, .object, .array, .null:
            return nil
        }
    }
}

struct GlimmerMessage: Identifiable, Decodable, Hashable {
    let id: UUID
    let glimmerId: UUID
    let sequence: Int
    let type: String
    let role: String?
    let content: JSONValue
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case glimmerId = "glimmer_id"
        case sequence
        case type
        case role
        case content
        case createdAt = "created_at"
    }
}

extension GlimmerMessage {
    static func getAll(glimmerId: UUID) async throws -> [GlimmerMessage] {
        let userId = try AuthManager.shared.getUserId()
        let supabase = try Backend.requireSupabase()
        return try await supabase
            .from("glimmer_messages")
            .select("id, glimmer_id, sequence, type, role, content, created_at")
            .eq("glimmer_id", value: glimmerId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .order("sequence", ascending: true)
            .execute()
            .value
    }
}
