import SwiftUI

/// Distraction-free Markdown preview, also used by the independent pop-out window.
struct ExpandedOutputView: View {
    @Bindable var model: StudioModel
    @Environment(\.dismiss) private var dismiss
    var popout = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Optimized Prompt", systemImage: "text.alignleft")
                    .font(.title3.weight(.bold))
                Spacer()
                Picker("View", selection: $model.isPreview) {
                    Text("Rendered").tag(true)
                    Text("Markdown").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                Button("Copy", systemImage: "doc.on.doc") { model.copyOutput() }
                    .disabled(model.output.isEmpty)
                Button("Export", systemImage: "square.and.arrow.up") { model.exportOutput() }
                    .disabled(model.output.isEmpty)
                if !popout {
                    Button("Return to Studio", systemImage: "arrow.down.right.and.arrow.up.left") {
                        model.outputExpanded = false
                    }
                }
            }
            .buttonStyle(.bordered)
            .padding(18)
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            if model.output.isEmpty {
                ContentUnavailableView("No optimized prompt yet", systemImage: "doc.text",
                                       description: Text("Return to the Studio and optimize a prompt."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.isPreview {
                ScrollView {
                    Text(.init(model.output))
                        .textSelection(.enabled)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: 960, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(28)
                }
            } else {
                TextEditor(text: $model.output)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(20)
            }
            HStack {
                Text("\(model.output.count) characters")
                Spacer()
                Text("Local-first · Editable Markdown")
            }
            .font(.caption)
            .foregroundStyle(HFBrand.muted)
            .padding(15)
        }
        .background(HFBrand.editor)
        .foregroundStyle(.white)
    }
}
