import AppKit
import SwiftUI

struct HomeDashboard: View {
    @Bindable var model: StudioModel
    @Bindable var news: NewsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HFMascotHero()
                HomeWelcome(model: model)
                HomeNewsHeader(model: model, news: news)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(NewsTopic.allCases) { topic in
                            Button(topic.rawValue) { news.selectedTopic = topic }
                                .font(.caption.weight(news.selectedTopic == topic ? .bold : .medium))
                                .buttonStyle(.plain)
                                .foregroundStyle(news.selectedTopic == topic ? Color.white : HFBrand.muted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(news.selectedTopic == topic ? HFBrand.blue.opacity(0.45) : HFBrand.panel.opacity(0.5),
                                            in: Capsule())
                                .accessibilityAddTraits(news.selectedTopic == topic ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
                HomeNewsGrid(model: model, news: news)
                HomeReadingList(model: model)
            }
            .padding(28)
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task { news.bootstrap(); news.refreshIfStale() }
    }
}

private struct HomeWelcome: View {
    let model: StudioModel
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HFBrand.periwinkle)
                Text("Your command center")
                    .font(.title.weight(.bold))
                Text("Build a sharper agent instruction, then get back to what matters.")
                    .font(.subheadline)
                    .foregroundStyle(HFBrand.muted)
            }
            Spacer()
            Button {
                model.newSession()
            } label: {
                Label("New Prompt", systemImage: "sparkles")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(HFBrand.blue)
        }
    }
}

private struct HomeNewsHeader: View {
    let model: StudioModel
    @Bindable var news: NewsStore
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                HFEyebrow(title: "THE BRIEFING")
                Text("Ideas worth exploring")
                    .font(.title2.weight(.bold))
                Text(news.freshness)
                    .font(.caption)
                    .foregroundStyle(HFBrand.muted)
            }
            Spacer()
            if news.isRefreshing { ProgressView().controlSize(.small) }
            Button { news.refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(!news.isEnabled || news.isRefreshing)
            .buttonStyle(.bordered)
            Button {
                model.destination = .sources
            } label: {
                Label("Sources", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct HomeNewsGrid: View {
    let model: StudioModel
    @Bindable var news: NewsStore

    var body: some View {
        if !news.isEnabled && news.articles.isEmpty {
            HFGlassPanel {
                VStack(spacing: 13) {
                    Image(systemName: "newspaper")
                        .font(.largeTitle)
                        .foregroundStyle(HFBrand.periwinkle)
                    Text("Your news. On your terms.")
                        .font(.title3.weight(.semibold))
                    Text("Enable news to fetch headlines, source attribution, publisher images and short excerpts from official Apple, Swift, AI and developer feeds. Nothing is fetched until you opt in.")
                        .font(.subheadline)
                        .foregroundStyle(HFBrand.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                    Button("Enable Home News") { news.toggleNetwork(true) }
                        .buttonStyle(.borderedProminent)
                        .tint(HFBrand.blue)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
                .padding(30)
            }
        } else if news.filtered.isEmpty {
            HFGlassPanel {
                VStack(spacing: 12) {
                    Image(systemName: news.selectedTopic == .saved ? "bookmark" : "rectangle.stack")
                        .font(.title)
                        .foregroundStyle(HFBrand.periwinkle)
                    Text(news.isRefreshing ? "Fetching your briefing…"
                         : news.selectedTopic == .saved ? "No saved stories yet" : "No stories in this topic yet")
                        .font(.headline)
                    Text(news.selectedTopic == .saved
                         ? "Bookmark a story to keep its headline and link available offline."
                         : "Your enabled sources and any cached articles will appear here. If a publisher is unavailable, check Sources for errors.")
                        .font(.subheadline)
                        .foregroundStyle(HFBrand.muted)
                        .multilineTextAlignment(.center)
                    if !news.failures.isEmpty {
                        Text("\(news.failures.count) sources could not be reached")
                            .font(.caption)
                            .foregroundStyle(HFBrand.coral)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .padding(28)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Wide: hero beside two compact cards. Narrow: hero above them. Same three stories either way.
                let lead = Array(news.filtered.dropFirst().prefix(2))
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        HomeHeroArticle(model: model, news: news, item: news.filtered[0])
                            // ViewThatFits compares ideal sizes; without an ideal width the headline's
                            // single-line length would force the stacked layout on every window.
                            .frame(minWidth: 460, idealWidth: 560, maxWidth: .infinity, alignment: .topLeading)
                        if !lead.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(lead) { item in
                                    HomeArticleCard(model: model, news: news, item: item, compact: true)
                                }
                            }
                            .frame(width: 330)
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HomeHeroArticle(model: model, news: news, item: news.filtered[0])
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(lead) { item in
                                HomeArticleCard(model: model, news: news, item: item, compact: true)
                            }
                        }
                    }
                }
                if news.filtered.count > 3 {
                    HFEyebrow(title: "MORE STORIES")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                        ForEach(Array(news.filtered.dropFirst(3).prefix(18))) { item in
                            HomeArticleCard(model: model, news: news, item: item, compact: false)
                        }
                    }
                }
            }
        }
    }
}

/// Publisher-provided image when the feed supplies one; otherwise a clean publisher mark. Never generated.
struct NewsThumbnail: View {
    let item: NewsItem
    let allowNetwork: Bool
    var height: CGFloat
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            PublisherMark(publisher: item.publisher)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .task(id: item.imageURL) {
            image = nil
            guard let url = item.imageURL else { return }
            let data = await ThumbnailCache.shared.imageData(for: url, allowNetwork: allowNetwork)
            guard !Task.isCancelled, let data else { return }
            image = NSImage(data: data)
        }
        .accessibilityHidden(true)
    }
}

private struct PublisherMark: View {
    let publisher: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [HFBrand.navy, HFBrand.violet.opacity(0.35), HFBrand.panel],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 4) {
                Text(initials)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(HFBrand.lavender.opacity(0.6))
                Text(publisher.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(HFBrand.muted.opacity(0.7))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var initials: String {
        publisher.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

private struct HomeHeroArticle: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem

    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                Button { model.openInBrowser(item.url) } label: {
                    NewsThumbnail(item: item, allowNetwork: news.allowsImageDownloads, height: 210)
                }
                .buttonStyle(.plain)
                .help("Open \(item.url.host() ?? "the article") in the browser")
                .accessibilityLabel("Open article image: \(item.title)")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("FEATURED", systemImage: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HFBrand.periwinkle)
                        Spacer()
                        ArticleMeta(item: item)
                    }
                    Button { model.openInBrowser(item.url) } label: {
                        Text(item.title)
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the publisher's page in the built-in browser")
                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .font(.body)
                            .foregroundStyle(HFBrand.muted)
                            .lineLimit(3)
                    }
                    HomeArticleActions(model: model, news: news, item: item)
                }
                .padding(22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HomeArticleCard: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem
    let compact: Bool

    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                if !compact {
                    Button { model.openInBrowser(item.url) } label: {
                        NewsThumbnail(item: item, allowNetwork: news.allowsImageDownloads, height: 130)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open article image: \(item.title)")
                }
                VStack(alignment: .leading, spacing: 9) {
                    ArticleMeta(item: item)
                    Button { model.openInBrowser(item.url) } label: {
                        Text(item.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the publisher's page in the built-in browser")
                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .font(.caption)
                            .foregroundStyle(HFBrand.muted)
                            .lineLimit(compact ? 2 : 3)
                    }
                    Spacer(minLength: 0)
                    HomeArticleActions(model: model, news: news, item: item)
                }
                .padding(15)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 150 : 300, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ArticleMeta: View {
    let item: NewsItem

    var body: some View {
        HStack(spacing: 6) {
            Text(item.publisher)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HFBrand.periwinkle)
            if let date = item.date {
                Text("·")
                Text(date, format: .dateTime.month(.abbreviated).day())
            }
            if let host = item.url.host() {
                Text("·")
                Text(host).lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(HFBrand.muted)
        .lineLimit(1)
    }
}

private struct HomeArticleActions: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem

    var body: some View {
        HStack(spacing: 12) {
            Button("Read", systemImage: "book") { model.openInBrowser(item.url) }
                .help("Open the publisher's page in the built-in browser")
            Button(news.savedIDs.contains(item.id) ? "Saved" : "Save",
                   systemImage: news.savedIDs.contains(item.id) ? "bookmark.fill" : "bookmark") {
                news.toggleSaved(item)
            }
            .help(news.savedIDs.contains(item.id) ? "Remove from saved stories" : "Save for offline reading list")
            Button("Use as prompt context", systemImage: "text.bubble") { model.useAsContext(item) }
                .help("Insert this story's title and link, with attribution, into the composer")
        }
        .font(.caption)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(HFBrand.periwinkle)
    }
}

private struct HomeReadingList: View {
    let model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HFEyebrow(title: "YOUR NEWSLETTER SHORTCUTS")
            HStack(spacing: 14) {
                ForEach(FeedSource.readingList.indices, id: \.self) { index in
                    let publisher = FeedSource.readingList[index]
                    Button { model.openInBrowser(publisher.url) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "envelope.open")
                                .foregroundStyle(HFBrand.gold)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(publisher.name).font(.headline)
                                Text("Open publisher website")
                                    .font(.caption)
                                    .foregroundStyle(HFBrand.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(HFBrand.periwinkle)
                        }
                        .padding(17)
                        .frame(maxWidth: .infinity)
                        .background(HFBrand.panel.opacity(0.72),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("The Code and Superhuman AI are publisher shortcuts, not assumed RSS feeds. No article scraping is performed.")
                .font(.caption2)
                .foregroundStyle(HFBrand.muted)
        }
    }
}
