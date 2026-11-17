import Foundation

/// Rules for downloading and keeping feed thumbnails. Pure logic; the app's ThumbnailCache does the I/O.
public struct ThumbnailCachePolicy: Sendable {
    public var maxAge: TimeInterval
    public var maxItemBytes: Int
    public var maxTotalBytes: Int

    /// Raster formats only. SVG is excluded because it can carry scripts and external references.
    public static let allowedMIMETypes: Set<String> = [
        "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp", "image/heic", "image/heif", "image/avif"
    ]

    public init(maxAge: TimeInterval = 7 * 24 * 3600, maxItemBytes: Int = 1_500_000, maxTotalBytes: Int = 40_000_000) {
        self.maxAge = maxAge
        self.maxItemBytes = maxItemBytes
        self.maxTotalBytes = maxTotalBytes
    }

    public enum Rejection: Error, Equatable, Sendable {
        case insecureURL
        case httpStatus(Int)
        case notImage(String)
        case tooLarge(Int)
    }

    public func validate(url: URL) -> Rejection? {
        url.scheme?.lowercased() == "https" && url.host != nil ? nil : .insecureURL
    }

    /// `expectedLength` is -1 when the server doesn't say; the downloader then enforces the cap while streaming.
    public func validate(statusCode: Int, mimeType: String?, expectedLength: Int64) -> Rejection? {
        guard (200...299).contains(statusCode) else { return .httpStatus(statusCode) }
        let type = (mimeType ?? "").lowercased()
        guard Self.allowedMIMETypes.contains(type) else { return .notImage(type) }
        if expectedLength > Int64(maxItemBytes) { return .tooLarge(Int(expectedLength)) }
        return nil
    }

    public func isExpired(storedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(storedAt) > maxAge
    }
}

public struct ThumbnailCacheEntry: Codable, Equatable, Sendable {
    public let key: String
    public let url: URL
    public let bytes: Int
    public let storedAt: Date
    public var lastAccess: Date
}

/// On-disk index: expiry by age, then least-recently-used eviction down to the byte budget.
public struct ThumbnailCacheIndex: Codable, Equatable, Sendable {
    public private(set) var entries: [String: ThumbnailCacheEntry] = [:]

    public init() {}

    public var totalBytes: Int { entries.values.reduce(0) { $0 + $1.bytes } }

    /// Stable 64-bit FNV-1a hash of the absolute URL, as 16 hex characters (also the file name).
    public static func key(for url: URL) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in url.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }

    public mutating func insert(url: URL, bytes: Int, now: Date) {
        let key = Self.key(for: url)
        entries[key] = ThumbnailCacheEntry(key: key, url: url, bytes: bytes, storedAt: now, lastAccess: now)
    }

    public func lookup(_ url: URL, now: Date, policy: ThumbnailCachePolicy) -> ThumbnailCacheEntry? {
        guard let entry = entries[Self.key(for: url)], !policy.isExpired(storedAt: entry.storedAt, now: now) else { return nil }
        return entry
    }

    public mutating func touch(_ url: URL, now: Date) {
        entries[Self.key(for: url)]?.lastAccess = now
    }

    /// Removes expired entries, then the least recently used, until within budget. Returns removed keys.
    public mutating func evict(now: Date, policy: ThumbnailCachePolicy) -> [String] {
        var removed: [String] = []
        for (key, entry) in entries where policy.isExpired(storedAt: entry.storedAt, now: now) {
            entries[key] = nil
            removed.append(key)
        }
        var total = totalBytes
        for entry in entries.values.sorted(by: { $0.lastAccess < $1.lastAccess }) where total > policy.maxTotalBytes {
            entries[entry.key] = nil
            total -= entry.bytes
            removed.append(entry.key)
        }
        return removed
    }

    public mutating func removeAll() { entries = [:] }
}
