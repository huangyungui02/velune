import Foundation

enum BillingDateParser {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }

        let normalized = value.replacingOccurrences(of: " ", with: "T")
        let timezoneNormalized = normalized.hasSuffix("+00")
            ? String(normalized.dropLast(3)) + "Z"
            : normalized
        let trimmedFraction = trimFractionalSeconds(in: timezoneNormalized)
        let candidates = [value, normalized, timezoneNormalized, trimmedFraction]

        for candidate in candidates {
            if let parsed = iso8601FractionalFormatter.date(from: candidate) {
                return parsed
            }
            if let parsed = iso8601Formatter.date(from: candidate) {
                return parsed
            }
        }

        return nil
    }

    private static func trimFractionalSeconds(in value: String) -> String {
        guard let dotIndex = value.firstIndex(of: ".") else { return value }
        guard let zoneIndex = value[dotIndex...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return value
        }

        let fractionStart = value.index(after: dotIndex)
        let fraction = value[fractionStart ..< zoneIndex]
        if fraction.count <= 3 { return value }

        let prefix = value[..<fractionStart]
        let shortenedFraction = fraction.prefix(3)
        let suffix = value[zoneIndex...]
        return String(prefix) + shortenedFraction + suffix
    }
}
