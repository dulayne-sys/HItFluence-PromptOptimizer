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
                HStack(spacing: 10) {
                    ForEach(NewsTopic.allCases) { topic in
                        Button(topic.rawValue) { news.selectedTopic = topic }
                            .font(.caption.weight(news.selectedTopic == topic ? .bold : .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(news.selectedTopic == topic ? .white : HFBrand.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(news.selectedTopic == topic ? HFBrand.blue.opacity(0.45) : HFBrand.panel.opacity(0.5),
                                        in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .contain)
                HomeNewsGrid(model: model, news: news)
                HomeReadingList(model: model)
            }
            .padding(28)
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(HFAuroraBackground(hero: true))
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
                model.freshPrompt()
                model.destination = .studio
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
                    Text("Enable news to fetch headlines, source attribution and short excerpts from official Apple, Swift, AI and developer feeds. Nothing is fetched until you opt in.")
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
                    Image(systemName: "rectangle.stack")
                        .font(.title)
                        .foregroundStyle(HFBrand.periwinkle)
                    Text(news.isRefreshing ? "Fetching your briefing…" : "No stories in this topic yet")
                        .font(.headline)
                    Text("Your enabled sources and any cached articles will appear here. If a publisher is unavailable, check Sources for errors.")
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
                HStack(alignment: .top, spacing: 14) {
                    HomeHeroArticle(model: model, news: news, item: news.filtered[0])
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    if news.filtered.count > 1 {
                        VStack(spacing: 12) {
                            ForEach(Array(news.filtered.dropFirst().prefix(2))) { item in
                                HomeArticleCard(model: model, news: news, item: item)
                            }
                        }
                        .frame(maxWidth: 330)
                    }
                }
                if news.filtered.count > 3 {
                    HFEyebrow(title: "MORE STORIES")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                        ForEach(Array(news.filtered.dropFirst(3).prefix(18))) { item in
                            HomeArticleCard(model: model, news: news, item: item)
                        }
                    }
                }
            }
        }
    }
}

private struct HomeHeroArticle: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem
    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("FEATURED", systemImage: "sparkle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HFBrand.periwinkle)
                    Spacer()
                    Text(item.publisher)
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                }
                Text(item.title)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.body)
                        .foregroundStyle(HFBrand.muted)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                HomeArticleActions(model: model, news: news, item: item)
            }
            .padding(24)
            .frame(minHeight: 290)
        }
    }
}

private struct HomeArticleCard: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem
    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.publisher)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HFBrand.periwinkle)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(3)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                HomeArticleActions(model: model, news: news, item: item)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 183, alignment: .topLeading)
        }
    }
}

private struct HomeArticleActions: View {
    let model: StudioModel
    let news: NewsStore
    let item: NewsItem
    var body: some View {
        HStack(spacing: 10) {
            Button("Read", systemImage: "book") { model.openBrowser(item.url) }
            Button(news.savedIDs.contains(item.id) ? "Saved" : "Save",
                   systemImage: news.savedIDs.contains(item.id) ? "bookmark.fill" : "bookmark") {
                news.toggleSaved(item)
            }
            Button("Use as prompt context", systemImage: "bubble.left") {
                model.input = "Explore this \(item.publisher) story:\n\(item.title)\n\(item.url.absoluteString)\n\nMy request: "
                model.destination = .studio
            }
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
                    Button { model.openBrowser(publisher.url) } label: {
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
