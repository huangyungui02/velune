import CryptoKit
import Foundation
import OSLog
import UIKit

@MainActor
final class ImageDiskCache {
    static let shared = ImageDiskCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = baseURL.appendingPathComponent("AvatarCache", isDirectory: true)
        memoryCache.countLimit = 240
        memoryCache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        let cacheKey = url as NSURL
        if let image = memoryCache.object(forKey: cacheKey) {
            return image
        }

        if let image = await diskImage(for: url) {
            memoryCache.setObject(image, forKey: cacheKey, cost: imageCost(image))
            return image
        }

        guard let image = await downloadImage(from: url) else {
            return nil
        }

        memoryCache.setObject(image, forKey: cacheKey, cost: imageCost(image))
        Task { await store(image, for: url) }
        return image
    }

    private func diskImage(for url: URL) async -> UIImage? {
        let fileURL = fileURL(for: url)

        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)
        }.value
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200 ..< 300).contains(httpResponse.statusCode),
                let image = UIImage(data: data)
            else { return nil }
            return image
        } catch {
            return nil
        }
    }

    private func store(_ image: UIImage, for url: URL) async {
        let fileURL = fileURL(for: url)
        let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData()

        await Task.detached(priority: .utility) {
            guard let data else { return }
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                AppLogger.storage.debug("Failed to store cached image: \(error.localizedDescription, privacy: .public)")
            }
        }.value
    }

    private func fileURL(for url: URL) -> URL {
        directoryURL.appendingPathComponent(Self.cacheKey(for: url), isDirectory: false)
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }

    private static func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
