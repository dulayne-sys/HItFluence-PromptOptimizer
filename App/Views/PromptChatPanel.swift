import SwiftUI

struct PromptChatPanel: View {
    @Bindable var model: StudioModel

    var body: some View {
        HFGlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("YOUR PROMPT", systemImage: "bubble.left.and.text.bubble.right")
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                    Spacer()
                    Text("INPUT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HFBrand.periwinkle)
                }
                .foregroundStyle(HFBrand.muted)
                .padding(22)

                Rectangle().fill(HFBrand.separator).frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 10) {
                            HFHashtag(size: 31)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Your prompt, upgraded.")
                                    .font(.headline.weight(.semibold))
                                Text("Describe the task naturally. I'll structure it for the agent you choose while keeping your original requirements intact.")
                                    .font(.subheadline)
                                    .foregroundStyle(HFBrand.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(15)
                            .background(HFBrand.panelRaised, in: RoundedRectangle(cornerRadius: 15))
                        }
                        if !model.output.isEmpty {
                            HStack(alignment: .top, spacing: 9) {
                                Spacer(minLength: 24)
                                Text(model.input)
                                    .font(.subheadline)
                                    .lineLimit(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(HFBrand.blue.opacity(0.21), in: RoundedRectangle(cornerRadius: 15))
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(HFBrand.periwinkle)
                            }
                        }
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        HFEyebrow(title: "COMPOSE")
                        Spacer()
                        Button { model.importClipboard() } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(HFBrand.periwinkle)
                        .disabled(model.isGenerating)
                    }
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(HFBrand.ink.opacity(0.60))
                        if model.input.isEmpty {
                            Text("Paste your agent instructions or type a new prompt…")
                                .font(.body)
                                .foregroundStyle(HFBrand.muted.opacity(0.70))
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $model.input)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 130)
                            .disabled(model.isGenerating)
                            .accessibilityLabel("Original prompt input")
                    }
                    .frame(minHeight: 138)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(HFBrand.separator, lineWidth: 1)
                    }
                    HStack {
                        Text("⌘ Return to optimize")
                            .font(.caption)
                            .foregroundStyle(HFBrand.muted)
                        Spacer()
                        if model.isGenerating {
                            Button("Cancel", role: .cancel) { model.cancel() }
                                .buttonStyle(.bordered)
                        } else {
                            Button { model.optimize() } label: {
                                Label("Optimize Prompt", systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(HFBrand.blue)
                            .disabled(!model.canOptimize)
                            .keyboardShortcut(.return, modifiers: [.command])
                        }
                    }
                }
                .padding(20)
                .background(HFBrand.panelRaised.opacity(0.60))
            }
        }
    }
}
