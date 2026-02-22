import Foundation
import Supabase

struct Message: Identifiable, Equatable {
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

extension Message {
    enum StreamEvent {
        case delta(String)
        case done
    }

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

    static func getHistory(soulerId: UUID) async throws -> [Message] {
        let response: [Response] = try await supabase
            .from("messages")
            .select("id, souler_id, role, content, created_at")
            .eq("souler_id", value: soulerId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response.map { item in
            Message(
                id: item.id,
                soulerId: item.soulerId,
                role: item.role,
                content: item.content,
                createdAt: item.createdAt
            )
        }
    }

    static func streamReply(soulerId: UUID, content: String) -> AsyncThrowingStream<StreamEvent, Error> {
        let request = SendRequest(soulerId: soulerId.uuidString, content: content)
        let rawStream = supabase.functions._invokeWithStreamedResponse(
            "chat",
            options: FunctionInvokeOptions(body: request)
        )

        return AsyncThrowingStream { continuation in
            Task {
                struct Event: Decodable {
                    var type: String
                    var delta: String?
                    var message: String?
                }

                let decoder = JSONDecoder()
                var buffer = Data()

                do {
                    func drainBuffer() throws {
                        let delimiter = Data([0x0A, 0x0A]) // "\n\n"
                        while let range = buffer.range(of: delimiter) {
                            let eventData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

                            if eventData.isEmpty { continue }

                            let eventText = String(decoding: eventData, as: UTF8.self)
                            let dataLines = eventText
                                .split(separator: "\n")
                                .compactMap { line -> Substring? in
                                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                                    if trimmed.hasPrefix("data:") {
                                        return trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)[...]
                                    }
                                    return nil
                                }

                            let payloadString = dataLines.joined(separator: "\n")
                            if payloadString.isEmpty { continue }

                            let event = try decoder.decode(Event.self, from: Data(payloadString.utf8))
                            switch event.type {
                            case "delta":
                                if let delta = event.delta, !delta.isEmpty {
                                    continuation.yield(.delta(delta))
                                }
                            case "done":
                                continuation.yield(.done)
                            case "error":
                                let message = event.message ?? String(localized: "matching.error.unknown")
                                throw NSError(
                                    domain: "ResonanceChat",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: message]
                                )
                            default:
                                continue
                            }
                        }
                    }

                    for try await chunk in rawStream {
                        buffer.append(chunk)
                        try drainBuffer()
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
