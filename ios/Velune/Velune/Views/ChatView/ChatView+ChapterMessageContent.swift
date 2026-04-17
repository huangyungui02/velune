import Foundation

private let chapterJSONOpenMarker = "---JSON---"
private let chapterJSONCloseMarker = "---END_JSON---"

extension ChatView {
    var inlineChapterOptions: [String] {
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            return []
        }

        return chapterMessagePayload(from: lastMessage.content)?.options ?? []
    }

    func visibleContent(for message: Message) -> String {
        guard message.role == .assistant else {
            return message.content
        }

        return chapterMessageBody(from: message.content)
    }

    func chapterMessageBody(from content: String) -> String {
        guard let payload = chapterMessagePayload(from: content) else {
            return content
        }
        return payload.body
    }

    func chapterMessageStorageContent(body: String, options: [String]) -> String {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBody = normalizedBody.isEmpty ? body : normalizedBody
        let normalizedOptions = normalizeChapterOptions(options)
        guard !normalizedOptions.isEmpty else {
            return resolvedBody
        }

        let payload: [String: Any] = ["options": normalizedOptions]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
            let jsonBlock = String(data: data, encoding: .utf8)
        else {
            return resolvedBody
        }

        return "\(resolvedBody)\n\n\(chapterJSONOpenMarker)\n\(jsonBlock)\n\(chapterJSONCloseMarker)"
    }

    private func chapterMessagePayload(from content: String) -> (body: String, options: [String])? {
        guard let openRange = content.range(of: chapterJSONOpenMarker) else {
            return nil
        }
        guard let closeRange = content.range(
            of: chapterJSONCloseMarker,
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
