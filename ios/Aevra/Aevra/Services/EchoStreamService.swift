import Foundation
import Supabase

enum EchoStreamService {
    struct EchoPayload {
        let id: UUID
        let glimmerId: UUID
        let soulerId: UUID
        let sessionId: UUID?
        let content: String
    }

    enum Event {
        case echo(EchoPayload)
        case done
    }

    private struct RequestBody: Encodable {
        let glimmerId: UUID
        let lang: String
    }

    private struct StreamEcho: Decodable {
        let id: UUID
        let glimmerId: UUID
        let soulerId: UUID
        let sessionId: UUID?
        let content: String
    }

    private struct StreamPayload: Decodable {
        let type: String
        let echo: StreamEcho?
        let message: String?
    }

    static func stream(glimmerId: UUID, lang: String) -> AsyncThrowingStream<Event, Error> {
        let rawStream = supabase.functions._invokeWithStreamedResponse(
            "echo",
            options: FunctionInvokeOptions(
                body: RequestBody(glimmerId: glimmerId, lang: lang)
            )
        )
        let payloadDataStream = SSEEventDecoder.decode(from: rawStream)

        return AsyncThrowingStream { continuation in
            Task {
                let decoder = JSONDecoder()
                do {
                    for try await payloadData in payloadDataStream {
                        let payload = try decoder.decode(StreamPayload.self, from: payloadData)
                        switch payload.type {
                        case "echo":
                            if let echo = payload.echo {
                                continuation.yield(
                                    .echo(
                                        EchoPayload(
                                            id: echo.id,
                                            glimmerId: echo.glimmerId,
                                            soulerId: echo.soulerId,
                                            sessionId: echo.sessionId,
                                            content: echo.content
                                        )
                                    )
                                )
                            }
                        case "done":
                            continuation.yield(.done)
                        case "error":
                            let message = payload.message ?? "Unknown error from echo stream"
                            throw NSError(
                                domain: "EchoStream",
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
