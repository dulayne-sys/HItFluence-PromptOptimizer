import SwiftUI

extension PromptEngineKind {
    var symbol: String {
        switch self {
        case .apple: "apple.logo"
        case .qwen: "cpu"
        case .glimmer: "brain.head.profile"
        }
    }
    var shortTitle: String {
        switch self {
        case .apple: "Apple Intelligence"
        case .qwen: "Qwen · Local"
        case .glimmer: "Glimmer · Local"
        }
    }
}

/// The conversational workspace: a threaded timeline for discussing and refining the prompt, with the
/// composer anchored at the bottom. The optimized Markdown itself lives in the artifact panel.
struct PromptChatPanel: View {
    @Bindable var model: StudioModel
    var isFocused = false
    var onToggleFocus: () -> Void = {}
    var onShowArtifact: () -> Void = {}
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ConversationHeader(model: model, isFocused: isFocused, onToggleFocus: onToggleFocus)
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            timeline
            ComposerView(model: model, focused: $composerFocused)
        }
        .onAppear { composerFocused = true }
        .onChange(of: model.currentSessionID) { composerFocused = true }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if model.session.messages.isEmpty {
                        ConversationWelcome(model: model)
                    }
                    ForEach(model.session.messages) { message in
                        MessageRow(message: message, model: model, onShowArtifact: onShowArtifact)
                            .id(message.id)
                    }
                    if let request = model.activeRequest, request.sessionID == model.session.id,
                       let startedAt = model.generationStartedAt {
                        GeneratingRow(engine: model.activeEngineTitle, startedAt: startedAt,
                                      isRefinement: request.isRefinement, onCancel: model.cancel)
                    }
                    Color.clear.frame(height: 1).id("timeline-bottom")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: model.session.messages.count) { scrollToBottom(proxy) }
            .onChange(of: model.isGenerating) { scrollToBottom(proxy) }
            .onAppear { proxy.scrollTo("timeline-bottom", anchor: .bottom) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("timeline-bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("timeline-bottom", anchor: .bottom) }
        }
    }
}

private struct ConversationHeader: View {
    let model: StudioModel
    let isFocused: Bool
    let onToggleFocus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.session.title.isEmpty ? "New prompt" : model.session.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(HFBrand.muted)
            }
            Spacer(minLength: 8)
            Button("New Prompt", systemImage: "square.and.pencil") { model.newSession() }
                .disabled(model.isGenerating)
                .help("Start a new prompt session (⌘N)")
            Button(isFocused ? "Restore Layout" : "Focus Chat",
                   systemImage: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                   action: onToggleFocus)
                .help(isFocused ? "Restore the workspace panels" : "Focus on the conversation")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var summary: String {
        let versions = model.session.versions.count
        let messages = model.session.messages.filter { $0.role != .notice }.count
        if messages == 0 { return "Describe what your agent should do" }
        return "\(messages) message\(messages == 1 ? "" : "s") · \(versions) version\(versions == 1 ? "" : "s")"
    }
}

private struct ConversationWelcome: View {
    let model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                HFHashtag(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your prompt, upgraded.")
                        .font(.title3.weight(.semibold))
                    Text("Describe the task naturally. The optimized Markdown appears in the artifact panel; reply here to refine it without losing earlier versions.")
                        .font(.subheadline)
                        .foregroundStyle(HFBrand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Nothing leaves this Mac: prompts go only to the model you select.")
                .font(.caption)
                .foregroundStyle(HFBrand.periwinkle)
        }
        .padding(18)
        .background(HFBrand.panelRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HFBrand.separator))
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    let model: StudioModel
    let onShowArtifact: () -> Void

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(HFBrand.blue.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HFBrand.blue.opacity(0.35)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You: \(message.text)")
        case .assistant:
            HStack(alignment: .top, spacing: 12) {
                if message.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(HFBrand.coral)
                        .frame(width: 30)
                } else {
                    HFHashtag(size: 30)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(message.text)
                        .textSelection(.enabled)
                        .foregroundStyle(message.isError ? HFBrand.coral : Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let id = message.versionID, let version = model.session.version(id) {
                        VersionChip(version: version, model: model, onShowArtifact: onShowArtifact)
                    }
                }
                .padding(message.isError ? 12 : 0)
                .background(message.isError ? HFBrand.coral.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer(minLength: 32)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(message.isError ? "Error: \(message.text)" : "Prompt Studio: \(message.text)")
        case .notice:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(HFBrand.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct VersionChip: View {
    let version: ArtifactVersion
    let model: StudioModel
    let onShowArtifact: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(HFBrand.mint)
            Text("Version \(version.number)")
                .font(.subheadline.weight(.semibold))
            Text(state)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(stateColor.opacity(0.18), in: Capsule())
                .foregroundStyle(stateColor)
            Spacer(minLength: 8)
            Button("View") {
                model.show(versionID: version.id)
                onShowArtifact()
            }
            if version.state == .proposed {
                Button("Discard") { model.discard(version) }
                Button("Apply") { model.accept(version) }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.blue)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(10)
        .background(HFBrand.panel.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HFBrand.separator))
        .frame(maxWidth: 460, alignment: .leading)
    }

    private var state: String {
        if version.id == model.session.currentVersionID { return "Current" }
        switch version.state {
        case .proposed: return "Proposed"
        case .discarded: return "Discarded"
        case .accepted: return "Earlier"
        }
    }

    private var stateColor: Color {
        if version.id == model.session.currentVersionID { return HFBrand.mint }
        switch version.state {
        case .proposed: return HFBrand.lavender
        case .discarded: return HFBrand.muted
        case .accepted: return HFBrand.periwinkle
        }
    }
}

/// Shown only while an engine call is actually in flight; the timer is real elapsed time.
private struct GeneratingRow: View {
    let engine: String
    let startedAt: Date
    let isRefinement: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HFHashtag(size: 30)
            ProgressView()
                .controlSize(.small)
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text("\(isRefinement ? "Revising" : "Optimizing") with \(engine) · \(max(0, Int(context.date.timeIntervalSince(startedAt))))s")
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(HFBrand.muted)
            Spacer()
            Button("Stop", systemImage: "stop.circle", action: onCancel)
                .buttonStyle(.borderless)
                .help("Stop generating (⌘.)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isRefinement ? "Revising" : "Optimizing") with \(engine)")
    }
}

private struct ComposerView: View {
    @Bindable var model: StudioModel
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                controlsRow(compactStatus: false)
                controlsRow(compactStatus: true)
            }
            .controlSize(.small)

            ZStack(alignment: .topLeading) {
                if model.input.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(HFBrand.muted.opacity(0.75))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $model.input)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(height: editorHeight)
                    .focused(focused)
                    .accessibilityLabel(model.session.currentVersion == nil ? "Prompt to optimize" : "Follow-up instruction")
            }
            .background(HFBrand.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused.wrappedValue ? HFBrand.periwinkle.opacity(0.65) : HFBrand.separator, lineWidth: 1))

            HStack(spacing: 10) {
                Button("Paste", systemImage: "doc.on.clipboard") { model.importClipboard() }
                    .buttonStyle(.borderless)
                    .help("Paste the clipboard into the composer")
                if model.session.currentVersion == nil {
                    Toggle("Append original", isOn: $model.includeOriginal)
                        .toggleStyle(.checkbox)
                        .help("Append the original request verbatim to Version 1")
                }
                Spacer()
                Text(model.isGenerating ? "⌘. to stop" : "⌘↩ to send")
                    .foregroundStyle(HFBrand.muted)
                if model.isGenerating {
                    Button("Stop", systemImage: "stop.fill") { model.cancel() }
                        .buttonStyle(.bordered)
                } else {
                    Button(model.session.currentVersion == nil ? "Optimize" : "Refine", systemImage: "arrow.up.circle.fill") {
                        model.send()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.blue)
                    .disabled(!model.canOptimize)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(HFBrand.panelRaised.opacity(0.55))
    }

    private func controlsRow(compactStatus: Bool) -> some View {
        HStack(spacing: 6) {
            EngineMenu(model: model)
            Picker("Profile", selection: $model.profile) {
                ForEach(PromptProfile.allCases) { profile in
                    Label(profile.title, systemImage: profile.icon).tag(profile)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("Target agent profile")
            Picker("Detail", selection: $model.detail) {
                ForEach(PromptDetail.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("Focused or detailed output")
            Spacer(minLength: 4)
            AvailabilityPill(availability: model.engineAvailability, compact: compactStatus)
        }
    }

    private var placeholder: String {
        model.session.currentVersion == nil
            ? "Paste agent instructions or describe a task…"
            : "Ask for a change — e.g. “add acceptance criteria” or “make it shorter”…"
    }

    private var editorHeight: CGFloat {
        let lines = model.input.split(separator: "\n", omittingEmptySubsequences: false).count
        return min(190, max(62, CGFloat(lines) * 19 + 26))
    }
}

private struct EngineMenu: View {
    @Bindable var model: StudioModel

    var body: some View {
        Menu {
            Picker("Engine", selection: $model.engine) {
                ForEach(PromptEngineKind.allCases) { engine in
                    Label(engine.title, systemImage: engine.symbol).tag(engine)
                }
            }
            .pickerStyle(.inline)
            if model.engine.isLocalOllama {
                if model.matchingTags.isEmpty {
                    Text(model.localServerReachable ? "No matching model installed" : "Ollama is not running")
                } else {
                    Picker("Installed model", selection: localSelection) {
                        ForEach(model.matchingTags, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
            Divider()
            Button("Refresh Local Models", systemImage: "arrow.clockwise") {
                Task { await model.refreshLocalModels() }
            }
        } label: {
            Label(model.engine.shortTitle, systemImage: model.engine.symbol)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(model.isGenerating)
        .help("Choose the local model")
        .accessibilityLabel("Model: \(model.engine.title)")
    }

    private var localSelection: Binding<String> {
        Binding(
            get: { model.selectedLocalTag ?? "" },
            set: { value in
                if model.engine == .qwen { model.chosenQwenTag = value }
                if model.engine == .glimmer { model.chosenGlimmerTag = value }
            }
        )
    }
}

private struct AvailabilityPill: View {
    let availability: EngineAvailability
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(availability.isReady ? HFBrand.mint : HFBrand.coral)
                .frame(width: 7, height: 7)
            if !compact {
                Text(availability.summary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .help(availability.summary)
        .font(.caption)
        .foregroundStyle(availability.isReady ? HFBrand.muted : HFBrand.coral)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model status: \(availability.summary)")
    }
}
