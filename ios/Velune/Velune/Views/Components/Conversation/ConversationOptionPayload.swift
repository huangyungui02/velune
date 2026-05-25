import Foundation

struct ConversationOptionPayload: Equatable {
    var body: String
    var options: [String]
}

enum ConversationOptionParser {
    static let openMarker = "---JSON---"
    static let closeMarker = "---END_JSON---"

    static func parse(_ content: String) -> ConversationOptionPayload {
        guard let openRange = content.range(of: openMarker) else {
            return ConversationOptionPayload(body: content, options: [])
        }

        let body = String(content[..<openRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let closeRange = content.range(
            of: closeMarker,
            range: openRange.upperBound ..< content.endIndex
        ) else {
            return ConversationOptionPayload(body: body, options: [])
        }

        let jsonBlock = String(content[openRange.upperBound ..< closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonBlock.isEmpty else {
            return ConversationOptionPayload(body: body, options: [])
        }

        return ConversationOptionPayload(
            body: body,
            options: parseOptions(from: jsonBlock)
        )
    }

    static func storageContent(body: String, options: [String]) -> String {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBody = normalizedBody.isEmpty ? body : normalizedBody
        let normalizedOptions = normalize(options)
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

        return "\(resolvedBody)\n\n\(openMarker)\n\(jsonBlock)\n\(closeMarker)"
    }

    static func normalize(_ options: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for option in options {
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            normalized.append(trimmed)

            if normalized.count == 4 {
                break
            }
        }

        return normalized
    }

    private static func parseOptions(from jsonBlock: String) -> [String] {
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

        return normalize(rawOptions.compactMap { $0 as? String })
    }
}
