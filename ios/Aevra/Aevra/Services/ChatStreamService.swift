import Foundation

enum ChatStreamService {
    private static let domain = "ResonanceChat"

    struct DonePayload {
        var sessionId: UUID?
        var title: String?
        var plan: String?
        var monthlyLimit: Int?
        var creditsRemaining: Int?
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

    private struct StreamEvent: Decodable {
        let type: String
        let delta: String?
        let sessionId: UUID?
        let title: String?
        let plan: String?
        let monthlyLimit: Int?
        let creditsRemaining: Int?
        let code: String?
        let message: String?
    }

    static func streamReply(
        sessionId: UUID?,
        soulerId: UUID,
        soulerName: String,
        path: String,
        content: String
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            sessionId: sessionId?.uuidString,
            soulerId: soulerId.uuidString,
            soulerName: soulerName,
            content: content
        )
        let payloadDataStream = APISSEClient.stream(path: path, body: request)

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
        case "delta":
            guard let delta = payload.delta, !delta.isEmpty else { return nil }
            return .delta(delta)
        case "done":
            return .done(
                DonePayload(
                    sessionId: payload.sessionId,
                    title: payload.title,
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
        return payload.message ?? String(localized: "matching.error.unknown")
    }
}
