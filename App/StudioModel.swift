import Foundation
import Observation

enum StudioDestination: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case workspace = "Chat"
    case sources = "News Sources"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house"
        case .workspace: "bubble.left.and.text.bubble.right"
        case .sources: "newspaper"
        }
    }
}

enum ArtifactDisplayMode: String, CaseIterable, Identifiable {
    case preview = "Preview"
    case source = "Source"
    case compare = "Compare"
    var id: String { rawValue }
}

/// A request for the window's browser pane to open a URL (from Home, links in the artifact, etc.).
struct BrowserRequest: Equatable {
    let id = UUID()
    let url: URL
}

/// Real availability of the selected engine, for the composer's status pill.
struct EngineAvailability: Equatable {
    let isReady: Bool
    let summary: String
}

@MainActor
@Observable
final class StudioModel {
    var destination: StudioDestination = .home
    var news = NewsStore()

    // Conversation sessions
    var sessions: [PromptSession]
    var currentSessionID: UUID
    var activeRequest: GenerationRequest?
    var generationStartedAt: Date?
    var activeEngineTitle = ""

    // Artifact display (shared by the main pane and the pop-out window)
    var viewedVersionID: UUID?
    var artifactMode: ArtifactDisplayMode = .preview

    // Engines
    var engine: PromptEngineKind = .apple
    var availableLocalTags: [String] = []
    var chosenQwenTag = ""
    var chosenGlimmerTag = ""
    var localServerReachable = false
    var includeOriginal = false

    // Persistence and status
    var historyEnabled = UserDefaults.standard.bool(forKey: "PromptStudio.HistoryEnabled")
    var status = "Ready for your next prompt"
    var alertMessage: String?

    // Browser routing
    var browserRequest: BrowserRequest?
    var lastBrowserURL: URL?

    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var hasBootstrapped = false
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    init() {
        let first = PromptSession()
        sessions = [first]
        currentSessionID = first.id
    }

    // MARK: Current session

    var session: PromptSession {
        sessions.first { $0.id == currentSessionID } ?? sessions[0]
    }

    var recentSessions: [PromptSession] {
        sessions.filter { !$0.isBlank }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mutate(_ id: UUID, _ body: (inout PromptSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        body(&sessions[index])
    }

    /// The composer draft of the current session (also used by the menu-bar quick window).
    var input: String {
        get { session.draft }
        set { mutate(currentSessionID) { $0.draft = newValue } }
    }

    var profile: PromptProfile {
        get { session.profile }
        set { mutate(currentSessionID) { $0.profile = newValue } }
    }

    var detail: PromptDetail {
        get { session.detail }
        set { mutate(currentSessionID) { $0.detail = newValue } }
    }

    var isGenerating: Bool { activeRequest != nil }
    var canOptimize: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating }

    /// The version shown in the artifact pane: an explicit selection, else a pending proposal, else current.
    var displayedVersion: ArtifactVersion? {
        if let viewedVersionID, let version = session.version(viewedVersionID) { return version }
        return session.proposal ?? session.currentVersion
    }

    /// Markdown of the applied version (Copy/Export/quick window use what is displayed).
    var output: String { displayedVersion?.markdown ?? "" }

    // MARK: Engines

    var matchingTags: [String] { LocalModelDiscovery.suitableTags(for: engine, among: availableLocalTags) }

    var selectedLocalTag: String? {
        let selected = engine == .qwen ? chosenQwenTag : chosenGlimmerTag
        let matches = matchingTags
        return matches.contains(selected) ? selected : matches.first
    }

    var engineAvailability: EngineAvailability {
        switch engine {
        case .apple:
            let status = AppleModelClient.modelStatus()
            return EngineAvailability(isReady: status == "Ready on device", summary: status)
        case .qwen, .glimmer:
            guard localServerReachable else { return EngineAvailability(isReady: false, summary: "Ollama is not running") }
            guard let tag = selectedLocalTag else {
                return EngineAvailability(isReady: false, summary: "No \(engine == .qwen ? "Qwen" : "Glimmer") model installed")
            }
            return EngineAvailability(isReady: true, summary: "\(tag) · local")
        }
    }

    var modelDescription: String { engineAvailability.summary }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        news.bootstrap()
        news.refreshIfStale()
        if historyEnabled {
            let saved = await SessionStore.shared.load()
            if !saved.isEmpty { sessions = [session] + saved.filter { $0.id != currentSessionID } }
        }
        await refreshLocalModels()
    }

    func refreshLocalModels() async {
        do {
            availableLocalTags = try await LocalOllamaClient.shared.installedModelNames()
            localServerReachable = true
        } catch {
            availableLocalTags = []
            localServerReachable = false
        }
    }

    // MARK: Conversation turns

    /// Sends the composer text: the first message optimizes, later messages propose a revised version.
    func optimize() {
        guard canOptimize else { return }
        var request: GenerationRequest?
        let text = input
        mutate(currentSessionID) { request = $0.submit(text) }
        guard let request else { return }
        run(request)
    }

    func send() { optimize() }

    private func run(_ request: GenerationRequest) {
        let chosenEngine = engine
        let selectedTag = selectedLocalTag
        let label = chosenEngine == .apple ? chosenEngine.title : (selectedTag ?? chosenEngine.title)
        let appendOriginal = includeOriginal && !request.isRefinement
        activeRequest = request
        generationStartedAt = .now
        activeEngineTitle = label
        status = request.isRefinement ? "Revising with \(label)…" : "Optimizing with \(label)…"

        generationTask = Task {
            defer {
                activeRequest = nil
                generationStartedAt = nil
                generationTask = nil
            }
            do {
                let raw: String
                switch chosenEngine {
                case .apple:
                    raw = try await AppleModelClient.generate(prompt: request.modelPrompt, instructions: request.instructions)
                case .qwen, .glimmer:
                    var tag = selectedTag
                    if tag == nil {
                        await refreshLocalModels() // Ollama may have started since launch: check for real.
                        tag = selectedLocalTag
                    }
                    guard let tag else {
                        throw localServerReachable
                            ? LocalModelError.modelNotInstalled
                            : LocalModelError.connection("nothing is listening at 127.0.0.1:11434. Start Ollama and try again.")
                    }
                    raw = try await LocalOllamaClient.shared.generate(model: tag, prompt: request.modelPrompt,
                                                                      instructions: request.instructions)
                }
                try Task.checkCancellation()
                let markdown = PromptPostProcessor.render(raw, source: request.originalRequest, includeOriginal: appendOriginal)
                guard !markdown.isEmpty else { throw LocalModelError.emptyResponse }
                var version: ArtifactVersion?
                mutate(request.sessionID) { version = $0.complete(request, markdown: markdown, engineLabel: label) }
                if let version, request.sessionID == currentSessionID {
                    viewedVersionID = version.id
                    artifactMode = .preview
                }
                if let version {
                    status = version.validation.hasWarnings
                        ? "Version \(version.number) ready · review preservation warnings"
                        : request.isRefinement ? "Version \(version.number) proposed" : "Version \(version.number) ready"
                }
                persist()
            } catch let error where GenerationCancellation.isCancellation(error) {
                mutate(request.sessionID) { $0.cancel(request) }
                status = "Generation canceled"
            } catch {
                mutate(request.sessionID) { $0.fail(request, message: "\(label) couldn't generate. \(error.localizedDescription)") }
                status = "Could not generate"
            }
        }
    }

    func cancel() { generationTask?.cancel() }

    // MARK: Versions

    func accept(_ version: ArtifactVersion) {
        mutate(currentSessionID) { _ = $0.accept(version.id) }
        viewedVersionID = version.id
        artifactMode = .preview
        status = "Applied version \(version.number)"
        persist()
    }

    func discard(_ version: ArtifactVersion) {
        mutate(currentSessionID) { _ = $0.discard(version.id) }
        viewedVersionID = nil
        artifactMode = .preview
        status = "Discarded version \(version.number)"
        persist()
    }

    func restore(_ version: ArtifactVersion) {
        mutate(currentSessionID) { _ = $0.restore(version.id) }
        viewedVersionID = version.id
        status = "Restored version \(version.number)"
        persist()
    }

    func show(versionID: UUID) {
        viewedVersionID = versionID
        if artifactMode == .compare, session.version(versionID)?.basedOn == nil { artifactMode = .preview }
    }

    /// Edits from the source editor apply to the current version only.
    func updateCurrentMarkdown(_ markdown: String) {
        mutate(currentSessionID) { $0.editCurrent(markdown: markdown) }
        // Typing in the source editor saves once, a second after the last keystroke.
        persistTask?.cancel()
        persistTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    // MARK: Sessions

    func newSession() {
        guard !isGenerating else { return }
        if session.isBlank {
            destination = .workspace
            return
        }
        let fresh = PromptSession(profile: profile, detail: detail)
        sessions.insert(fresh, at: 0)
        select(fresh.id)
    }

    /// Kept for menu and quick-window callers.
    func freshPrompt() { newSession() }

    func select(_ id: UUID) {
        guard !isGenerating, sessions.contains(where: { $0.id == id }) else { return }
        currentSessionID = id
        viewedVersionID = nil
        artifactMode = .preview
        destination = .workspace
        status = session.isBlank ? "Ready for your next prompt" : "Opened \(session.title)"
    }

    func deleteSession(_ id: UUID) {
        guard !isGenerating else { return }
        sessions.removeAll { $0.id == id }
        if sessions.isEmpty { sessions = [PromptSession(profile: profile, detail: detail)] }
        if !sessions.contains(where: { $0.id == currentSessionID }) { currentSessionID = sessions[0].id }
        persist()
    }

    func setHistoryEnabled(_ value: Bool) {
        historyEnabled = value
        UserDefaults.standard.set(value, forKey: "PromptStudio.HistoryEnabled")
        if value {
            persist()
        } else {
            Task { try? await SessionStore.shared.delete() }
        }
    }

    func deleteHistory() {
        let keep = session.isBlank ? session : PromptSession(profile: profile, detail: detail)
        sessions = [keep]
        currentSessionID = keep.id
        viewedVersionID = nil
        Task {
            do { try await SessionStore.shared.delete() }
            catch { alertMessage = "Could not delete history: \(error.localizedDescription)" }
        }
    }

    private func persist() {
        guard historyEnabled else { return }
        let snapshot = sessions
        Task {
            do { try await SessionStore.shared.save(snapshot) }
            catch { status = "Could not save history: \(error.localizedDescription)" }
        }
    }

    // MARK: Browser and news

    /// Opens a canonical HTTPS article URL in the window's browser pane, next to the conversation.
    func openInBrowser(_ url: URL) {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            alertMessage = "Only HTTPS pages can be opened in the built-in browser."
            return
        }
        lastBrowserURL = url
        browserRequest = BrowserRequest(url: url)
        destination = .workspace
    }

    /// Kept for existing callers (Home, Sources).
    func openBrowser(_ url: URL) { openInBrowser(url) }

    /// Explicit, attributed insertion of story metadata into the composer. Page content is never sent.
    func useAsContext(_ item: NewsItem) {
        let attribution = "Context from \(item.publisher): \(item.title)\n\(item.url.absoluteString)\n\n"
        input = attribution + input
        destination = .workspace
    }

    // MARK: Clipboard and export

    func importClipboard() {
        let pasted = MacActions.pasteboardString()
        guard !pasted.isEmpty else { return }
        input = input.isEmpty ? pasted : input + "\n" + pasted
    }

    func copyOutput() {
        guard !output.isEmpty else { return }
        MacActions.copy(output)
        status = "Markdown copied to clipboard"
    }

    func exportOutput() {
        guard !output.isEmpty else { return }
        do {
            if try MacActions.exportMarkdown(output) { status = "Markdown exported" }
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
extension StudioModel {
    /// Sample state for SwiftUI previews only (never shipped): one session built through the real
    /// submit/complete path, with an applied version and a pending follow-up proposal.
    static func previewSample() -> StudioModel {
        let model = StudioModel()
        model.destination = .workspace
        var session = PromptSession()
        if let first = session.submit("Write a Codex task to fix the failing build in /Users/me/Studio/Editor.swift before 2026-12-01.") {
            session.complete(first, markdown: """
            # Fix the Failing Build

            **Location:** `/Users/me/Studio/Editor.swift` · **Deadline:** 2026-12-01

            ## Steps
            1. Reproduce the failure with `xcodebuild build`.
            2. Fix the compiler errors in `Editor.swift`.

            ## Acceptance Criteria
            - [ ] Build succeeds with 0 errors
            - [x] No changes to `Package.swift`
            """, engineLabel: "Apple Intelligence (preview sample)")
        }
        if let followUp = session.submit("Add a table of owners.") {
            session.complete(followUp, markdown: """
            # Fix the Failing Build

            | Step | Owner |
            |:-----|:-----:|
            | Reproduce | Ana |
            | Fix | Lee |
            """, engineLabel: "Apple Intelligence (preview sample)")
        }
        model.sessions = [session]
        model.currentSessionID = session.id
        return model
    }
}
#endif
