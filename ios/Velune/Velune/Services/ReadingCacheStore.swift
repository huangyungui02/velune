import Foundation

struct CachedReadingPayload: Codable, Equatable, Sendable {
    var savedAt: Date
    var featuredSections: [ReadingSection]
    var latestItems: [ReadingSoulerItem]
    var latestPage: Int
    var latestHasMore: Bool
}

@MainActor
final class ReadingCacheStore {
    static let shared = ReadingCacheStore()

    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        fileURL = baseURL
            .appendingPathComponent("ReadingCache", isDirectory: true)
            .appendingPathComponent("reading.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> CachedReadingPayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CachedReadingPayload.self, from: data)
    }

    func save(_ payload: CachedReadingPayload) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }
}
