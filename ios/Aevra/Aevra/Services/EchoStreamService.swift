import Foundation

enum EchoStreamService {
    private static let domain = "EchoStream"

    struct DonePayload {
        let plan: String?
        let monthlyLimit: Int?
        let creditsRemaining: Int?
    }

    struct EchoPayload {
        let id: UUID
        let glimmerId: UUID
        let soulerId: UUID
        let soulerName: String?
        let content: String
    }

    enum Event {
        case echo(EchoPayload)
        case done(DonePayload)
    }

    private struct RequestBody: Encodable {
        let glimmerId: UUID
    }

    private struct StreamEvent: Decodable {
        struct EchoData: Decodable {
            let id: UUID
            let glimmerId: UUID
            let soulerId: UUID
            let soulerName: String?
            let content: String
        }

        let type: String
        let echo: EchoData?
        let plan: String?
        let monthlyLimit: Int?
        let creditsRemaining: Int?
        let code: String?
        let message: String?
    }

    static func stream(glimmerId: UUID, path: String) -> AsyncThrowingStream<Event, Error> {
        let payloadDataStream = APISSEClient.stream(
            path: path,
            body: RequestBody(glimmerId: glimmerId)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await payloadData in payloadDataStream {
                        let payload = try APISSEClient.decode(
                            StreamEvent.self,
                            from: payloadData,
                            domain: domain
                        )
                        guard let event = try mapEvent(payload) else { continue }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func mapEvent(_ payload: StreamEvent) throws -> Event? {
        switch payload.type {
        case "echo":
            guard let echoData = payload.echo else { return nil }
            return .echo(
                EchoPayload(
                    id: echoData.id,
                    glimmerId: echoData.glimmerId,
                    soulerId: echoData.soulerId,
                    soulerName: echoData.soulerName,
                    content: echoData.content
                )
            )
        case "done":
            return .done(
                DonePayload(
                    plan: payload.plan,
                    monthlyLimit: payload.monthlyLimit,
                    creditsRemaining: payload.creditsRemaining
                )
            )
        case "error":
            throw NSError(
                domain: domain,
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessage(for: payload)]
            )
        default:
            return nil
        }
    }

    private static func errorMessage(for payload: StreamEvent) -> String {
        if payload.code == "INSUFFICIENT_CREDITS" {
            return String(localized: "billing.error.insufficientCredits")
        }
        return payload.message ?? "Unknown error from echo stream"
    }
}
