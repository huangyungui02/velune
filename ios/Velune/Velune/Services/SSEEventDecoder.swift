import Foundation
import OSLog

nonisolated enum APISSEClient {
    private static let logger = AppLogger.network
    private static let connectionTimeout: TimeInterval = 8
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func stream<Body: Encodable>(
        path: String,
        body: Body
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let encodedBody: Data
            do {
                encodedBody = try JSONEncoder().encode(body)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let task = Task(priority: .userInitiated) {
                do {
                    let request = try await makeRequest(path: path, body: encodedBody)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw serverUnavailableError()
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        let data = try await readData(from: bytes)
                        throw httpError(statusCode: httpResponse.statusCode, data: data)
                    }

                    var buffer = Data()
                    var didReceivePayload = false
                    for try await byte in bytes {
                        if Task.isCancelled { break }

                        buffer.append(byte)
                        while let eventData = nextEventData(from: &buffer) {
                            if let payload = eventPayload(from: eventData) {
                                didReceivePayload = true
                                continuation.yield(Data(payload.utf8))
                            }
                        }
                    }

                    if let payload = eventPayload(from: buffer) {
                        didReceivePayload = true
                        continuation.yield(Data(payload.utf8))
                    }
                    finish(continuation, didReceivePayload: didReceivePayload)
                } catch {
                    continuation.finish(throwing: resolveNetworkError(error))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    nonisolated private static func makeRequest(path: String, body: Data) async throws -> URLRequest {
        let accessToken = await MainActor.run { AuthManager.shared.currentAccessToken }
        guard let accessToken else {
            logger.error("stream request blocked: missing Supabase access token")
            throw NSError(
                domain: "APISSEClient",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing Supabase access token"]
            )
        }

        let endpoint = try Backend.requireAPIBaseURL().appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = connectionTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    nonisolated private static func resolveNetworkError(_ error: Error) -> Error {
        if let networkError = networkErrorMessage(for: error) {
            logger.error("stream request failed: \(networkError, privacy: .public)")
            return NSError(
                domain: "APISSEClient",
                code: (error as? URLError)?.errorCode ?? -1,
                userInfo: [
                    NSLocalizedDescriptionKey: networkError,
                    NSUnderlyingErrorKey: error,
                ]
            )
        }

        return error
    }

    nonisolated private static func httpError(statusCode: Int, data: Data) -> NSError {
        let message = parseAPIErrorMessage(from: data)
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
        logger.error("stream request failed: status=\(statusCode, privacy: .public) message=\(message, privacy: .public)")
        return NSError(
            domain: "APISSEClient",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    nonisolated private static func nextEventData(from buffer: inout Data) -> Data? {
        let separators = [
            Data("\r\n\r\n".utf8),
            Data("\n\n".utf8),
        ]

        for separator in separators {
            if let range = buffer.range(of: separator) {
                let eventData = buffer[..<range.lowerBound]
                buffer.removeSubrange(..<range.upperBound)
                return Data(eventData)
            }
        }

        return nil
    }

    nonisolated private static func eventPayload(from eventData: Data) -> String? {
        guard let event = String(data: eventData, encoding: .utf8) else { return nil }
        let dataLines = event
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let line = line.trimmingCharacters(in: .newlines)
                guard line.hasPrefix("data:") else { return nil }
                return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        let raw = dataLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "[DONE]" else { return nil }
        return raw
    }

    nonisolated private static func readData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    nonisolated private static func finish(
        _ continuation: AsyncThrowingStream<Data, Error>.Continuation,
        didReceivePayload: Bool
    ) {
        if didReceivePayload {
            continuation.finish()
        } else {
            continuation.finish(throwing: serverUnavailableError())
        }
    }

    nonisolated private static func serverUnavailableError() -> NSError {
        NSError(
            domain: "APISSEClient",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: String(localized: "network.error.serverUnavailable")]
        )
    }

    nonisolated private static func networkErrorMessage(for error: Error) -> String? {
        guard let urlError = error as? URLError else { return nil }

        switch urlError.code {
        case .notConnectedToInternet,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .networkConnectionLost:
            return String(localized: "network.error.unavailable")
        case .timedOut:
            return String(localized: "network.error.timeout")
        default:
            return nil
        }
    }

    static func decode<Payload: Decodable>(
        _ payloadType: Payload.Type,
        from data: Data,
        domain: String
    ) throws -> Payload {
        do {
            return try decoder.decode(payloadType, from: data)
        } catch {
            let rawPayload = String(data: data, encoding: .utf8) ?? "<non-utf8 payload>"
            logger.error("invalid stream payload: \(rawPayload, privacy: .private)")
            throw NSError(
                domain: domain,
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid stream payload format",
                    NSUnderlyingErrorKey: error,
                    "payload": rawPayload,
                ]
            )
        }
    }

    nonisolated private static func parseAPIErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty
        {
            if
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = object["message"] as? String ?? object["error"] as? String,
                !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return message
            }
            return text
        }
        return nil
    }
}
