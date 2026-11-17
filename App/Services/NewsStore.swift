import Foundation
import Observation

/// Explicitly opt-in feed metadata. Articles are cached locally for offline Home viewing.
@MainActor @Observable final class NewsStore {
    var articles: [NewsItem] = []
    var selectedTopic: NewsTopic = .all
    var isRefreshing = false
    var lastUpdated: Date?
    var failures: [String] = []
    var isEnabled = UserDefaults.standard.bool(forKey: "PromptStudio.NewsEnabled")
    var enabledSourceIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "PromptStudio.NewsSources") ??
                                          FeedSource.builtIn.prefix(8).map(\.id))
    var savedIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "PromptStudio.NewsSaved") ?? [])
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var loadedCache = false

    var filtered: [NewsItem] {
        selectedTopic == .all ? articles : articles.filter { $0.topics.contains(selectedTopic) }
    }
    var saved: [NewsItem] { articles.filter { savedIDs.contains($0.id) } }
    var freshness: String {
        guard let lastUpdated else { return isEnabled ? "Not updated yet" : "Offline · News off" }
        return (isEnabled ? "Updated " : "Offline · updated ") + lastUpdated.formatted(.relative(presentation: .named))
    }
    private var cacheURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HitFluencePromptStudio", isDirectory: true)
        return folder.appendingPathComponent("news-cache.json")
    }
    private struct Cache: Codable { let articles: [NewsItem]; let lastUpdated: Date }

    func bootstrap() {
        guard !loadedCache else { return }
        loadedCache = true
        if let data = try? Data(contentsOf: cacheURL), let cached = try? JSONDecoder().decode(Cache.self, from: data) {
            articles = cached.articles
            lastUpdated = cached.lastUpdated
        }
    }

    func toggleNetwork(_ isOn: Bool) {
        isEnabled = isOn
        UserDefaults.standard.set(isOn, forKey: "PromptStudio.NewsEnabled")
        if isOn { refresh() } else { cancel() }
    }

    func toggleSource(_ id: String) {
        if enabledSourceIDs.contains(id) { enabledSourceIDs.remove(id) } else { enabledSourceIDs.insert(id) }
        UserDefaults.standard.set(enabledSourceIDs.sorted(), forKey: "PromptStudio.NewsSources")
    }

    func toggleSaved(_ item: NewsItem) {
        if savedIDs.contains(item.id) { savedIDs.remove(item.id) } else { savedIDs.insert(item.id) }
        UserDefaults.standard.set(savedIDs.sorted(), forKey: "PromptStudio.NewsSaved")
    }

    func refreshIfStale() {
        guard isEnabled, !isRefreshing else { return }
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 30 * 60 { return }
        refresh()
    }

    func cancel() { activeTask?.cancel(); activeTask = nil; isRefreshing = false }

    func refresh() {
        guard isEnabled, !isRefreshing else { return }
        let sources = FeedSource.builtIn.filter { enabledSourceIDs.contains($0.id) }
        isRefreshing = true
        failures = []
        activeTask = Task {
            var results: [NewsItem] = []
            var errors: [String] = []
            for source in sources {
                if Task.isCancelled { break }
                do {
                    var request = URLRequest(url: source.feedURL)
                    request.timeoutInterval = 12
                    request.setValue("application/rss+xml, application/atom+xml, application/xml", forHTTPHeaderField: "Accept")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode), data.count <= 2_000_000 else {
                        errors.append("\(source.publisher): unavailable or too large"); continue
                    }
                    results += NewsFeedParser.parse(data, source: source)
                } catch {
                    if !Task.isCancelled { errors.append("\(source.publisher): \(error.localizedDescription)") }
                }
            }
            guard !Task.isCancelled else { isRefreshing = false; return }
            failures = errors
            if !results.isEmpty {
                let combined = results + articles.filter { savedIDs.contains($0.id) }
                articles = Array(Dictionary(grouping: combined, by: \.url.absoluteString)
                    .compactMap { $0.value.first }
                    .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.prefix(160))
                lastUpdated = Date()
                let snapshot = Cache(articles: articles, lastUpdated: lastUpdated!)
                do {
                    let data = try JSONEncoder().encode(snapshot)
                    let folder = cacheURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try data.write(to: cacheURL, options: .atomic)
                } catch { failures.append("Offline cache: \(error.localizedDescription)") }
            }
            isRefreshing = false
            activeTask = nil
        }
    }
}
