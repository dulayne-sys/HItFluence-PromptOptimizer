import SwiftUI

struct NewsSourcesView: View {
    @Bindable var model: StudioModel
    @Bindable var news: NewsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HFEyebrow(title: "HOME / NEWS SOURCES")
                Text("Curate your briefing")
                    .font(.largeTitle.weight(.bold))
                Text("Publisher feeds are opt-in, fetched directly over HTTPS, and stored as attributed headlines and short summaries only. Your model traffic remains separate and local.")
                    .font(.subheadline)
                    .foregroundStyle(HFBrand.muted)
                Toggle("Enable network requests for Home news", isOn: Binding(
                    get: { news.isEnabled }, set: { news.toggleNetwork($0) }
                ))
                .tint(HFBrand.blue)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(HFBrand.panel, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Load publisher images (Media RSS and image enclosures only)", isOn: Binding(
                        get: { news.showImages }, set: { news.setShowImages($0) }
                    ))
                    .tint(HFBrand.blue)
                    ThumbnailCacheControls()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(HFBrand.panel, in: RoundedRectangle(cornerRadius: 12))
                HFEyebrow(title: "VERIFIED SOURCE LIST FROM YOUR HITCODE PROJECT")
                ForEach(FeedSource.builtIn) { source in
                    HStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .foregroundStyle(HFBrand.periwinkle)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.publisher).font(.headline)
                            Text(source.feedURL.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundStyle(HFBrand.muted)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button("Open site", systemImage: "arrow.up.right.square") {
                            model.openBrowser(source.homepage)
                        }
                        .buttonStyle(.borderless)
                        Toggle(source.publisher, isOn: Binding(
                            get: { news.enabledSourceIDs.contains(source.id) },
                            set: { _ in news.toggleSource(source.id) }
                        ))
                        .labelsHidden()
                        .tint(HFBrand.blue)
                    }
                    .padding(16)
                    .background(HFBrand.panel, in: RoundedRectangle(cornerRadius: 12))
                }
                HFEyebrow(title: "NETWORK STATUS")
                Text(news.freshness).font(.subheadline)
                if !news.failures.isEmpty {
                    ForEach(news.failures, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(HFBrand.coral)
                    }
                }
                Button("Refresh selected sources") { news.refresh() }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.blue)
                    .disabled(!news.isEnabled || news.isRefreshing)
            }
            .padding(28)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(HFAuroraBackground())
    }
}
