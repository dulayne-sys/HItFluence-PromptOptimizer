import SwiftUI

/// App Settings (⌘,): privacy, news, thumbnail cache, browser data and local model status.
struct SettingsView: View {
    @Bindable var model: StudioModel

    var body: some View {
        Form {
            Section("Prompt sessions") {
                Toggle("Save prompt sessions on this Mac", isOn: Binding(
                    get: { model.historyEnabled }, set: { model.setHistoryEnabled($0) }
                ))
                Button("Clear Saved Sessions", role: .destructive) { model.deleteHistory() }
                    .disabled(model.isGenerating)
                Text("Sessions are stored only in this app's container. Nothing is synced or uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Home news") {
                Toggle("Fetch news from publisher feeds", isOn: Binding(
                    get: { model.news.isEnabled }, set: { model.news.toggleNetwork($0) }
                ))
                Toggle("Load publisher images", isOn: Binding(
                    get: { model.news.showImages }, set: { model.news.setShowImages($0) }
                ))
                ThumbnailCacheControls()
            }
            Section("Browser") {
                LabeledContent("Website data", value: "Private, in memory only")
                Text("Cookies and site data are discarded when the window closes. Page content is never sent to a model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Local models") {
                LabeledContent("Apple Intelligence", value: AppleModelClient.modelStatus())
                LabeledContent("Ollama (127.0.0.1)", value: model.localServerReachable
                               ? "Connected · \(model.availableLocalTags.count) models" : "Not running")
                Button("Refresh Local Models") { Task { await model.refreshLocalModels() } }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
    }
}

/// Usage and Clear control for the feed thumbnail cache (Settings and News Sources).
struct ThumbnailCacheControls: View {
    @State private var usage: (count: Int, bytes: Int)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Thumbnail cache")
                Text(usageText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Clear Thumbnail Cache") {
                Task {
                    await ThumbnailCache.shared.clear()
                    usage = await ThumbnailCache.shared.usage()
                }
            }
            .disabled((usage?.count ?? 0) == 0)
        }
        .task { usage = await ThumbnailCache.shared.usage() }
    }

    private var usageText: String {
        guard let usage else { return "Checking…" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(usage.bytes), countStyle: .file)
        return "\(usage.count) images · \(size) · kept up to 7 days, 40 MB max"
    }
}
