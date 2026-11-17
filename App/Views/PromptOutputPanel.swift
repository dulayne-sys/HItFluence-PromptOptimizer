import AppKit
import SwiftUI

/// The right-hand Markdown artifact workspace: rendered/source/compare modes, version history,
/// proposals from follow-up turns, and copy/export/expand/pop-out.
struct PromptOutputPanel: View {
    @Bindable var model: StudioModel
    var isFocused = false
    var popout = false
    var onToggleFocus: () -> Void = {}
    var onClose: (() -> Void)?
    var onOpenLink: (URL) -> Void = { NSWorkspace.shared.open($0) }
    @Environment(\.openWindow) private var openWindow

    private var session: PromptSession { model.session }
    private var displayed: ArtifactVersion? { model.displayedVersion }

    /// The version a comparison is made against: what it was based on, else the one before it.
    private var comparisonBase: ArtifactVersion? {
        guard let displayed else { return nil }
        if let base = displayed.basedOn.flatMap(session.version) { return base }
        return session.versions.last { $0.number < displayed.number }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            if let proposal = session.proposal {
                ProposalBanner(model: model, proposal: proposal)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(HFBrand.editor.opacity(0.94))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundStyle(HFBrand.mint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Prompt Artifact")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                versionMenu
                if !popout {
                    Button(isFocused ? "Restore Layout" : "Expand",
                           systemImage: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                           action: onToggleFocus)
                        .help(isFocused ? "Restore the workspace panels" : "Expand the artifact to fill the window")
                    Button("Pop Out", systemImage: "macwindow.on.rectangle") { openWindow(id: "artifact") }
                        .help("Open the artifact in its own window")
                }
                if let onClose {
                    Button("Close Preview", systemImage: "xmark", action: onClose)
                        .help("Hide the artifact panel (⇧⌘M)")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)

            HStack(spacing: 8) {
                Picker("Display", selection: $model.artifactMode) {
                    ForEach(ArtifactDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                .disabled(displayed == nil)
                Spacer(minLength: 4)
                Button("Copy", systemImage: "doc.on.doc") { model.copyOutput() }
                    .help("Copy this version's Markdown (⇧⌘C)")
                Button("Export", systemImage: "square.and.arrow.up") { model.exportOutput() }
                    .help("Export this version as a .md file (⇧⌘E)")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(displayed == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        guard let displayed else { return "No versions yet" }
        return "Version \(displayed.number) · \(stateLabel(displayed)) · \(displayed.engineLabel)"
    }

    private func stateLabel(_ version: ArtifactVersion) -> String {
        if version.id == session.currentVersionID { return version.isEdited ? "Current, edited" : "Current" }
        switch version.state {
        case .proposed: return "Proposed"
        case .discarded: return "Discarded"
        case .accepted: return "Earlier"
        }
    }

    private var versionMenu: some View {
        Menu {
            ForEach(session.versions.reversed()) { version in
                Button {
                    model.show(versionID: version.id)
                } label: {
                    if version.id == displayed?.id {
                        Label("Version \(version.number) · \(stateLabel(version))", systemImage: "checkmark")
                    } else {
                        Text("Version \(version.number) · \(stateLabel(version))")
                    }
                }
            }
            if let displayed, displayed.id != session.currentVersionID, displayed.state != .proposed {
                Divider()
                Button("Restore Version \(displayed.number)", systemImage: "clock.arrow.circlepath") { model.restore(displayed) }
            }
        } label: {
            Label("Versions", systemImage: "clock.arrow.circlepath")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(session.versions.isEmpty)
        .help("Version history")
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if let displayed {
            switch model.artifactMode {
            case .preview:
                ScrollView {
                    MarkdownRenderedView(markdown: displayed.markdown, onOpenLink: onOpenLink)
                        .frame(maxWidth: 860, alignment: .leading)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Rendered Markdown, version \(displayed.number)")
            case .source:
                if displayed.id == session.currentVersionID {
                    TextEditor(text: Binding(get: { displayed.markdown }, set: { model.updateCurrentMarkdown($0) }))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .accessibilityLabel("Editable Markdown source")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Label(displayed.state == .proposed
                              ? "Proposals are read-only. Apply it to edit."
                              : "Earlier versions are read-only. Restore it to edit.", systemImage: "lock")
                            .font(.caption)
                            .foregroundStyle(HFBrand.muted)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        ScrollView {
                            Text(displayed.markdown)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
            case .compare:
                if let base = comparisonBase {
                    ArtifactDiffView(old: base, new: displayed)
                } else {
                    ContentUnavailableView("Nothing to compare yet", systemImage: "arrow.left.arrow.right",
                                           description: Text("Version \(displayed.number) is the first version. Ask for a change in the chat to create another."))
                }
            }
        } else if let request = model.activeRequest, request.sessionID == session.id {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Building version 1")
                    .font(.headline)
                Text("\(model.activeEngineTitle) is working on your prompt.")
                    .font(.subheadline)
                    .foregroundStyle(HFBrand.muted)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 12) {
                HFHashtag(size: 52)
                Text("Your prompt artifact appears here")
                    .font(.title3.weight(.semibold))
                Text("Describe the task in the chat. The optimized Markdown opens here as Version 1, and every follow-up becomes a new version you can compare, apply or revert.")
                    .font(.subheadline)
                    .foregroundStyle(HFBrand.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(24)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if let displayed, displayed.validation.hasWarnings {
                ValidationNotice(validation: displayed.validation)
            }
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            HStack(spacing: 10) {
                if let displayed {
                    Text("\(displayed.markdown.count) characters")
                    Text(displayed.createdAt, format: .dateTime.hour().minute())
                    Spacer()
                    if displayed.id != session.currentVersionID, displayed.state != .proposed {
                        Button("Restore Version \(displayed.number)") { model.restore(displayed) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(HFBrand.periwinkle)
                    }
                } else {
                    Text("Local-first · Markdown")
                    Spacer()
                }
            }
            .font(.caption)
            .foregroundStyle(HFBrand.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }
}

private struct ProposalBanner: View {
    let model: StudioModel
    let proposal: ArtifactVersion

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(HFBrand.lavender)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(proposal.number) proposed")
                    .font(.subheadline.weight(.semibold))
                Text("“\(proposal.instruction)”")
                    .font(.caption)
                    .foregroundStyle(HFBrand.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Button("Compare") {
                model.show(versionID: proposal.id)
                model.artifactMode = .compare
            }
            Button("Discard") { model.discard(proposal) }
            Button("Apply") { model.accept(proposal) }
                .buttonStyle(.borderedProminent)
                .tint(HFBrand.blue)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(HFBrand.violet.opacity(0.16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Version \(proposal.number) proposed")
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
        .padding(12)
        .background(HFBrand.gold.opacity(0.08))
    }
}
