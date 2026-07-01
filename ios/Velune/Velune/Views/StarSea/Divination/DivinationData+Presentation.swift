import Foundation

extension DivinationData {
    var yaoStates: [YaoState] {
        castedLines.map(YaoState.init(code:))
    }

    var primaryHexagram: Hexagram {
        lookupHexagram(lines: yaoStates.map(\.primaryType))
    }

    var changedHexagram: Hexagram {
        lookupHexagram(lines: yaoStates.map(\.changedType))
    }

    var localizedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    var iso8601DateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    func streamContent(question: String) -> StarSeaStreamService.Content {
        .divination(
            StarSeaStreamService.Content.DivinationContent(
                castedLines: castedLines,
                date: iso8601DateString,
                question: question
            )
        )
    }
}
