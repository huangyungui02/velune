import Foundation

struct ConversationOptionPayload: Equatable {
    var body: String
    var options: [String]
}

enum ConversationOptionParser {
    static let openMarker = "<options>"
    static let closeMarker = "</options>"

    static func parse(_ content: String) -> ConversationOptionPayload {
        guard let openRange = content.range(of: openMarker) else {
            return ConversationOptionPayload(body: trimmedBody(content), options: [])
        }

        let body = trimmedBody(String(content[..<openRange.lowerBound]))

        guard let closeRange = content.range(
            of: closeMarker,
            range: openRange.upperBound ..< content.endIndex
        ) else {
            return ConversationOptionPayload(body: body, options: [])
        }

        let optionsBlock = String(content[openRange.lowerBound ..< closeRange.upperBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !optionsBlock.isEmpty else {
            return ConversationOptionPayload(body: body, options: [])
        }

        return ConversationOptionPayload(
            body: body,
            options: parseOptions(from: optionsBlock)
        )
    }

    static func storageContent(body: String, options: [String]) -> String {
        let normalizedBody = trimmedBody(body)
        let resolvedBody = normalizedBody.isEmpty ? body : normalizedBody
        let normalizedOptions = normalize(options)
        guard !normalizedOptions.isEmpty else {
            return resolvedBody
        }

        let optionsBlock = normalizedOptions
            .map { "  <opt>\(escapeOptionText($0))</opt>" }
            .joined(separator: "\n")

        return "\(resolvedBody)\n\n\(openMarker)\n\(optionsBlock)\n\(closeMarker)"
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

    private static func trimmedBody(_ body: String) -> String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseOptions(from optionsBlock: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"<opt>([\s\S]*?)</opt>"#,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(optionsBlock.startIndex ..< optionsBlock.endIndex, in: optionsBlock)
        let rawOptions = expression.matches(in: optionsBlock, range: range).compactMap { match -> String? in
            guard
                match.numberOfRanges > 1,
                let matchRange = Range(match.range(at: 1), in: optionsBlock)
            else {
                return nil
            }
            return unescapeOptionText(String(optionsBlock[matchRange]))
        }

        return normalize(rawOptions)
    }

    private static func escapeOptionText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func unescapeOptionText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
