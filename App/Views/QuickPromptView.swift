import SwiftUI
import AppKit

struct QuickPromptView: View {
    @Bindable var model: StudioModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                HFHashtag(size: 33)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prompt Studio").font(.headline)
                    Text("HitFluence quick optimize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.borderless)
                    .help("Open main window")
            }
            Picker("Model", selection: $model.engine) {
                Text("Apple Intelligence").tag(EngineChoice.apple)
                ForEach(model.localModels.filter(\.isUsable)) { local in
                    Text(local.name).tag(EngineChoice.local(local.id))
                }
            }
            TextEditor(text: $model.input)
                .font(.body)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(HFBrand.panelRaised, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Paste Clipboard") { model.importClipboard() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(model.isGenerating ? "Optimizing…" : "Optimize") { model.optimize() }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.blue)
                    .disabled(!model.canOptimize)
            }
            if !model.output.isEmpty {
                ScrollView {
                    Text(model.output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 140)
                Button("Copy Markdown") { model.copyOutput() }
                    .buttonStyle(.borderedProminent)
            }
            Text(model.status)
                .font(.caption2)
                .foregroundStyle(HFBrand.muted)
                .lineLimit(2)
        }
        .padding(20)
        .frame(width: 420)
        .background(HFBrand.ink)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .task { await model.bootstrap() }
    }
}
