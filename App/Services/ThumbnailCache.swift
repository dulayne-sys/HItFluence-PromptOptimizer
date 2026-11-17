import Foundation
import ImageIO

/// Bounded memory + disk cache for publisher-provided feed thumbnails.
/// Network use is opt-in (news enabled), HTTPS only, raster images only, size-capped while streaming,
/// and cancellable: a disappearing card cancels its download.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let policy = ThumbnailCachePolicy()
    private let memory = NSCache<NSString, NSData>()
    private let session: URLSession
    private var index: ThumbnailCacheIndex
    private let directory: URL?

    private init() {
        memory.totalCostLimit = 24_000_000
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "HitFluence/Thumbnails", directoryHint: .isDirectory)
        if let indexURL = directory?.appending(path: "index.json"), let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode(ThumbnailCacheIndex.self, from: data) {
            index = saved
        } else {
            index = ThumbnailCacheIndex()
        }
    }

    /// Cached bytes for `url`, downloading only when `allowNetwork` is true.
    func imageData(for url: URL, allowNetwork: Bool) async -> Data? {
        let key = ThumbnailCacheIndex.key(for: url)
        if let data = memory.object(forKey: key as NSString) { return data as Data }
        if index.lookup(url, now: .now, policy: policy) != nil, let file = fileURL(key), let data = try? Data(contentsOf: file) {
            memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            index.touch(url, now: .now)
            return data
        }
        guard allowNetwork, policy.validate(url: url) == nil else { return nil }
        do {
            let data = try await download(url)
            try Task.checkCancellation()
            store(data, for: url, key: key)
            return data
        } catch {
            return nil
        }
    }

    func usage() -> (count: Int, bytes: Int) { (index.entries.count, index.totalBytes) }

    func clear() {
        memory.removeAllObjects()
        index.removeAll()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    // MARK: Private

    private func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/gif", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ThumbnailCachePolicy.Rejection.httpStatus(-1) }
        if let rejection = policy.validate(statusCode: http.statusCode, mimeType: http.mimeType,
                                           expectedLength: http.expectedContentLength) {
            throw rejection
        }
        var data = Data()
        data.reserveCapacity(min(policy.maxItemBytes, max(0, Int(http.expectedContentLength))))
        for try await byte in bytes {
            data.append(byte)
            if data.count > policy.maxItemBytes { throw ThumbnailCachePolicy.Rejection.tooLarge(data.count) }
        }
        // Must actually decode as a raster image, whatever the server claimed.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw ThumbnailCachePolicy.Rejection.notImage("undecodable")
        }
        return data
    }

    private func store(_ data: Data, for url: URL, key: String) {
        memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let directory, let file = fileURL(key) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            index.insert(url: url, bytes: data.count, now: .now)
            for removed in index.evict(now: .now, policy: policy) {
                if let stale = fileURL(removed) { try? FileManager.default.removeItem(at: stale) }
                memory.removeObject(forKey: removed as NSString)
            }
            try JSONEncoder().encode(index).write(to: directory.appending(path: "index.json"), options: .atomic)
        } catch {
            // Disk caching is best-effort; the image is still served from memory this session.
        }
    }

    private func fileURL(_ key: String) -> URL? { directory?.appending(path: "\(key).img") }
}
