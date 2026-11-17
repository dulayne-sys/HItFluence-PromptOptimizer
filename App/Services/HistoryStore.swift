import Foundation

/// Local-only, opt-in storage. No CloudKit and no analytics.
actor HistoryStore {
    static let shared = HistoryStore()
    private init() {}

    func load() -> [PromptRecord] {
        guard let path = try? historyURL(),
              let data = try? Data(contentsOf: path),
              let items = try? JSONDecoder().decode([PromptRecord].self, from: data) else { return [] }
        return items
    }

    func save(_ records: [PromptRecord]) throws {
        let path = try historyURL()
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Array(records.prefix(100)))
        try data.write(to: path, options: .atomic)
    }

    func delete() throws {
        let path = try historyURL()
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }

    private func historyURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appending(path: "HitFluence/PromptStudio/history.json")
    }
}
