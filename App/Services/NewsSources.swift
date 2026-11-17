import Foundation

/// An editorial topic used to filter the Home news feed.
enum NewsTopic: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "For You"
    case apple = "Apple & Swift"
    case ai = "AI Models"
    case coding = "Coding"
    case security = "Security"
    var id: String { rawValue }
}

struct FeedSource: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let publisher: String
    let feedURL: URL
    let homepage: URL
    let topics: [NewsTopic]

    static let builtIn: [FeedSource] = [
        FeedSource(id: "apple-developer", publisher: "Apple Developer", feedURL: URL(string: "https://developer.apple.com/news/rss/news.rss")!, homepage: URL(string: "https://developer.apple.com/news/")!, topics: [.apple]),
        FeedSource(id: "swift-org", publisher: "Swift.org", feedURL: URL(string: "https://www.swift.org/atom.xml")!, homepage: URL(string: "https://www.swift.org/blog/")!, topics: [.apple, .coding]),
        FeedSource(id: "webkit", publisher: "WebKit", feedURL: URL(string: "https://webkit.org/feed/")!, homepage: URL(string: "https://webkit.org/blog/")!, topics: [.apple, .coding]),
        FeedSource(id: "apple-ml", publisher: "Apple Machine Learning Research", feedURL: URL(string: "https://machinelearning.apple.com/rss.xml")!, homepage: URL(string: "https://machinelearning.apple.com/")!, topics: [.ai, .apple]),
        FeedSource(id: "deepmind", publisher: "Google DeepMind", feedURL: URL(string: "https://deepmind.google/blog/rss.xml")!, homepage: URL(string: "https://deepmind.google/discover/blog/")!, topics: [.ai]),
        FeedSource(id: "hugging-face", publisher: "Hugging Face", feedURL: URL(string: "https://huggingface.co/blog/feed.xml")!, homepage: URL(string: "https://huggingface.co/blog")!, topics: [.ai]),
        FeedSource(id: "github-blog", publisher: "GitHub Blog", feedURL: URL(string: "https://github.blog/feed/")!, homepage: URL(string: "https://github.blog/")!, topics: [.coding]),
        FeedSource(id: "github-security", publisher: "GitHub Security", feedURL: URL(string: "https://github.blog/security/feed/")!, homepage: URL(string: "https://github.blog/security/")!, topics: [.security]),
        FeedSource(id: "openai", publisher: "OpenAI", feedURL: URL(string: "https://openai.com/news/rss.xml")!, homepage: URL(string: "https://openai.com/news/")!, topics: [.ai]),
        FeedSource(id: "github-changelog", publisher: "GitHub Changelog", feedURL: URL(string: "https://github.blog/changelog/feed/")!, homepage: URL(string: "https://github.blog/changelog/")!, topics: [.coding])
    ]

    /// Links requested in the user's HitCode briefing. Neither is silently scraped as a feed.
    static let readingList: [(name: String, url: URL)] = [
        ("Superhuman AI", URL(string: "https://www.superhuman.ai/")!),
        ("The Code", URL(string: "https://codenewsletter.ai/")!)
    ]
}

struct NewsItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let sourceID: String
    let publisher: String
    let title: String
    let url: URL
    let summary: String
    let date: Date?
    let topics: [NewsTopic]
}
