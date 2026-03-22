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
        case ready
        case echo(EchoPayload)
        case done(DonePayload)
    }

    private struct RequestBody: Encodable {
        let glimmerId: UUID
        let content: String?
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

    static func stream(
        glimmerId: UUID,
        content: String? = nil,
        path: String
    ) -> AsyncThrowingStream<Event, Error> {
        let payloadDataStream = APISSEClient.stream(
            path: path,
            body: RequestBody(glimmerId: glimmerId, content: content)
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
        case "ready":
            return .ready
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
            throw streamError(for: payload)
        default:
            return nil
        }
    }

    private static func streamError(for payload: StreamEvent) -> NSError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: errorMessage(for: payload)
        ]
        if let code = payload.code, !code.isEmpty {
            userInfo[AppErrorUserInfoKey.billingCode] = code
        }
        if let plan = payload.plan, !plan.isEmpty {
            userInfo[AppErrorUserInfoKey.billingPlan] = plan
        }

        return NSError(domain: domain, code: -1, userInfo: userInfo)
    }

    private static func errorMessage(for payload: StreamEvent) -> String {
        if payload.code == "INSUFFICIENT_CREDITS" {
            return payload.plan == "premium"
                ? NSLocalizedString("billing.error.insufficientStardust.premium", comment: "")
                : NSLocalizedString("billing.error.insufficientStardust.free", comment: "")
        }
        return payload.message ?? "Unknown error from echo stream"
    }
}
