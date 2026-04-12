import Foundation

extension ChatView {
    var inlineChapterOptions: [String] {
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            return []
        }

        if !chapterOptions.isEmpty {
            return chapterOptions
        }

        return chapterMessagePayload(from: lastMessage.content)?.options ?? []
    }

    func visibleContent(for message: Message) -> String {
        guard message.role == .assistant else {
            return message.content
        }

        guard let payload = chapterMessagePayload(from: message.content) else {
            return message.content
        }

        return payload.body
    }

    private func chapterMessagePayload(from content: String) -> (body: String, options: [String])? {
        let openMarker = "---JSON---"
        let closeMarker = "---END_JSON---"

        guard let openRange = content.range(of: openMarker) else {
            return nil
        }
        guard let closeRange = content.range(
            of: closeMarker,
            range: openRange.upperBound ..< content.endIndex
        ) else {
            return nil
        }

        let body = String(content[..<openRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonBlock = String(content[openRange.upperBound ..< closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonBlock.isEmpty else {
            return nil
        }

        let options = parseOptions(from: jsonBlock)
        if options.isEmpty {
            return (body.isEmpty ? content : body, [])
        }
        return (body.isEmpty ? content : body, options)
    }

    private func parseOptions(from jsonBlock: String) -> [String] {
        let normalized = jsonBlock.replacingOccurrences(
            of: #",\s*([\]}])"#,
            with: "$1",
            options: .regularExpression
        )

        guard let data = normalized.data(using: .utf8) else {
            return []
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawOptions = object["options"] as? [Any]
        else {
            return []
        }

        let options = rawOptions.compactMap { item -> String? in
            guard let option = item as? String else { return nil }
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return normalizeChapterOptions(options)
    }
}
