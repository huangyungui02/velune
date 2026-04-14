import Foundation

enum EchoStreamService {
    private static let domain = "EchoStream"

    struct DonePayload {}

    struct EchoPayload {
        let id: UUID
        let stirringId: UUID
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
        let stirringId: UUID
        let content: String?

        enum CodingKeys: String, CodingKey {
            case stirringId = "glimmerId"
            case content
        }
    }

    private struct StreamEvent: Decodable {
        struct EchoData: Decodable {
            let id: UUID
            let stirringId: UUID
            let soulerId: UUID
            let soulerName: String?
            let content: String

            enum CodingKeys: String, CodingKey {
                case id
                case stirringId = "glimmerId"
                case soulerId
                case soulerName
                case content
            }
        }

        let type: String
        let echo: EchoData?
        let code: String?
        let message: String?
    }

    static func stream(
        stirringId: UUID,
        content: String? = nil,
        path: String
    ) -> AsyncThrowingStream<Event, Error> {
        let payloadDataStream = APISSEClient.stream(
            path: path,
            body: RequestBody(stirringId: stirringId, content: content)
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
                    stirringId: echoData.stirringId,
                    soulerId: echoData.soulerId,
                    soulerName: echoData.soulerName,
                    content: echoData.content
                )
            )
        case "done":
            return .done(DonePayload())
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

        return NSError(domain: domain, code: -1, userInfo: userInfo)
    }

    private static func errorMessage(for payload: StreamEvent) -> String {
        if payload.code == "INSUFFICIENT_CREDITS" {
            return NSLocalizedString("billing.error.insufficientStardust.free", comment: "")
        }
        return payload.message ?? "Unknown error from echo stream"
    }
}
