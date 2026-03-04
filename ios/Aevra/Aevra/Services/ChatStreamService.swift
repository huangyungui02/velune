import Foundation
import Supabase

enum ChatStreamService {
    enum Event {
        case delta(String)
        case done
    }

    private struct SendRequest: Encodable {
        var sessionId: String
        var content: String
    }

    private struct StreamPayload: Decodable {
        var type: String
        var delta: String?
        var message: String?
    }

    static func streamReply(
        sessionId: UUID,
        content: String
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            sessionId: sessionId.uuidString,
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
                            continuation.yield(.done)
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
