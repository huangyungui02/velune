import Foundation
import Supabase

enum ChatStreamService {
    struct DonePayload {
        var sessionId: UUID?
        var title: String?
    }

    enum Event {
        case delta(String)
        case done(DonePayload)
    }

    private struct SendRequest: Encodable {
        var sessionId: String?
        var soulerId: String
        var soulerName: String
        var content: String
    }

    private struct StreamPayload: Decodable {
        var type: String
        var delta: String?
        var message: String?
        var sessionId: String?
        var title: String?

        enum CodingKeys: String, CodingKey {
            case type
            case delta
            case message
            case sessionId = "sessionId"
            case title
        }
    }

    static func streamReply(
        sessionId: UUID?,
        soulerId: UUID,
        soulerName: String,
        content: String
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            sessionId: sessionId?.uuidString,
            soulerId: soulerId.uuidString,
            soulerName: soulerName,
            content: content
        )
        let rawStream = supabase.functions._invokeWithStreamedResponse(
            "chat",
            options: FunctionInvokeOptions(body: request)
        )
        let payloadDataStream = SSEEventDecoder.decode(from: rawStream)

        return AsyncThrowingStream { continuation in
            Task {
                let decoder = JSONDecoder()
                do {
                    for try await payloadData in payloadDataStream {
                        let payload = try decoder.decode(StreamPayload.self, from: payloadData)
                        switch payload.type {
                        case "delta":
                            if let delta = payload.delta, !delta.isEmpty {
                                continuation.yield(.delta(delta))
                            }
                        case "done":
                            let resolvedSessionId = payload.sessionId.flatMap(UUID.init(uuidString:))
                            let donePayload = DonePayload(
                                sessionId: resolvedSessionId,
                                title: payload.title
                            )
                            continuation.yield(.done(donePayload))
                        case "error":
                            let message = payload.message ?? String(localized: "matching.error.unknown")
                            throw NSError(
                                domain: "ResonanceChat",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: message]
                            )
                        default:
                            continue
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
