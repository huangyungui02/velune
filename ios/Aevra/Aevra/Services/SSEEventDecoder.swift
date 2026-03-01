import Foundation

enum SSEEventDecoder {
    static func decode(from rawStream: AsyncThrowingStream<Data, Error>) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
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

                            continuation.yield(Data(payloadString.utf8))
                        }
                    }

                    for try await chunk in rawStream {
                        if Task.isCancelled { break }
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
