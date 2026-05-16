import Foundation

struct CachedExplorePayload: Codable, Equatable, Sendable {
    var savedAt: Date
    var featuredSections: [ExploreSection]
    var latestItems: [ExploreSoulerItem]
    var latestPage: Int
    var latestHasMore: Bool
}

@MainActor
final class ExploreCacheStore {
    static let shared = ExploreCacheStore()

    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        fileURL = baseURL
            .appendingPathComponent("ExploreCache", isDirectory: true)
            .appendingPathComponent("explore.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> CachedExplorePayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CachedExplorePayload.self, from: data)
    }

    func save(_ payload: CachedExplorePayload) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }
}
