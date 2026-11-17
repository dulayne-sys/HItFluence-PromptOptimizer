import Foundation

/// Opt-in, local-only storage for prompt sessions (chat + artifact versions). No CloudKit, no analytics.
/// Reads the pre-conversation `history.json` once and converts it, so earlier saved prompts are preserved.
actor SessionStore {
    static let shared = SessionStore()
    private init() {}

    func load() -> [PromptSession] {
        if let url = try? sessionsURL(), let data = try? Data(contentsOf: url),
           let sessions = try? JSONDecoder().decode([PromptSession].self, from: data) {
            return sessions
        }
        return HistoryStore.shared.legacyRecords().map(PromptSession.init(legacy:))
    }

    func save(_ sessions: [PromptSession]) throws {
        let url = try sessionsURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let kept = sessions.filter { !$0.isBlank }.sorted { $0.updatedAt > $1.updatedAt }.prefix(100)
        let cleaned = kept.map { session -> PromptSession in
            var copy = session
            copy.pendingRequestID = nil
            return copy
        }
        try JSONEncoder().encode(cleaned).write(to: url, options: .atomic)
    }

    func delete() throws {
        let url = try sessionsURL()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try HistoryStore.shared.deleteLegacy()
    }

    private func sessionsURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appending(path: "HitFluence/PromptStudio/sessions.json")
    }
}
