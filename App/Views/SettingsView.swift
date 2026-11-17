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
                LabeledContent("Models folder") {
                    Text(model.modelsFolder?.path(percentEncoded: false) ?? "Not chosen")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                HStack {
                    Button(model.modelsFolder == nil ? "Choose Folder…" : "Change Folder…") { model.chooseModelsFolder() }
                    Button("Rescan") { Task { await model.refreshLocalModels() } }
                    if model.modelsFolder != nil {
                        Button("Forget Folder") { model.forgetModelsFolder() }
                    }
                    Spacer()
                    Button("Unload From Memory") { model.unloadLocalModel() }
                        .help("Free the memory used by the last local model")
                }
                if model.localModels.isEmpty {
                    Text(model.isScanningModels ? "Looking for models…" : "No local models found yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.localModels) { local in
                    LabeledContent {
                        Text(local.isUsable ? "Ready" : local.status.explanation)
                            .foregroundStyle(local.isUsable ? Color.secondary : HFBrand.coral)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text(local.name)
                        Text(local.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !model.hasMuseGlimmer {
                    Text("Muse Glimmer isn't installed. Add its MLX weights to your models folder and choose Rescan; it runs in-app with the MLX vision runtime when this Mac has enough memory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Models run inside Prompt Studio with Core AI or MLX. Prompts never leave this Mac, and no Ollama or other server is used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
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
