import SwiftUI

struct PromptOutputPanel: View {
    @Bindable var model: StudioModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "curlybraces.square.fill")
                        .foregroundStyle(HFBrand.mint)
                    Text("OPTIMIZED MARKDOWN")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(HFBrand.muted)
                    Spacer(minLength: 8)
                    Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
                        model.outputExpanded = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Expand Markdown preview into the full workspace")
                    Button("Pop Out", systemImage: "macwindow.on.rectangle") { openWindow(id: "preview") }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Open an independent Markdown preview window")
                    if !model.output.isEmpty {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(HFBrand.mint)
                            .accessibilityLabel("Output ready")
                    }
                }
                .padding(22)
                Rectangle().fill(HFBrand.separator).frame(height: 1)

                if model.isGenerating && model.output.isEmpty {
                    VStack(spacing: 18) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Building a better prompt")
                            .font(.headline)
                        Text("Preserving details and structuring instructions")
                            .font(.subheadline)
                            .foregroundStyle(HFBrand.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.output.isEmpty {
                    VStack(spacing: 13) {
                        Image(systemName: "text.page.badge.magnifyingglass")
                            .font(.system(size: 43, weight: .thin))
                            .foregroundStyle(HFBrand.periwinkle)
                            .padding(.bottom, 4)
                        Text("Ready when you are")
                            .font(.title3.weight(.semibold))
                        Text("Your optimized, agent-ready Markdown will appear here. You can review, edit, copy or export it.")
                            .font(.subheadline)
                            .foregroundStyle(HFBrand.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 270)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Picker("Output display", selection: $model.isPreview) {
                                Text("Preview").tag(true)
                                Text("Markdown source").tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 235)
                            Spacer()
                            Toggle("Include original", isOn: $model.includeOriginal)
                                .help("When selected for the next generation, append the original request verbatim")
                                .font(.caption)
                                .toggleStyle(.checkbox)
                        }
                        .padding(17)
                        Rectangle().fill(HFBrand.separator).frame(height: 1)
                        if model.isPreview {
                            ScrollView {
                                Text(.init(model.output))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .lineSpacing(5)
                                    .padding(22)
                            }
                            .accessibilityLabel("Optimized Markdown preview")
                        } else {
                            TextEditor(text: $model.output)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(17)
                                .accessibilityLabel("Editable optimized Markdown")
                        }
                        if model.validation.hasWarnings {
                            ValidationNotice(validation: model.validation)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Rectangle().fill(HFBrand.separator).frame(height: 1)
                HStack(spacing: 10) {
                    Label(model.output.isEmpty ? "Markdown" : "\(model.output.count) characters", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                    Spacer()
                    Button { model.exportOutput() } label: {
                        Label("Export .md", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.output.isEmpty)
                    Button { model.copyOutput() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.mint)
                    .foregroundStyle(HFBrand.ink)
                    .disabled(model.output.isEmpty)
                }
                .padding(17)
            }
        }
    }
}

struct ValidationNotice: View {
    let validation: PromptValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Review exact-detail preservation", systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
            ForEach(validation.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption2)
            }
            if !validation.missingExactStrings.isEmpty {
                Text(validation.missingExactStrings.prefix(3).joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .lineLimit(2)
            }
        }
        .foregroundStyle(HFBrand.gold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(HFBrand.gold.opacity(0.07))
    }
}
