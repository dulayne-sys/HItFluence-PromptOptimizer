import Foundation

/// Legacy single-turn history (`history.json`) from before prompt sessions. Read once for migration by
/// `SessionStore`, and removed when the user clears history. New data is written by `SessionStore` only.
struct HistoryStore: Sendable {
    static let shared = HistoryStore()

    func legacyRecords() -> [PromptRecord] {
        guard let url = try? historyURL(), let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([PromptRecord].self, from: data) else { return [] }
        return items
    }

    func deleteLegacy() throws {
        let url = try historyURL()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func historyURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appending(path: "HitFluence/PromptStudio/history.json")
    }
}
