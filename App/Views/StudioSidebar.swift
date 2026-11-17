import SwiftUI

private enum SidebarItem: Hashable {
    case destination(StudioDestination)
    case session(UUID)
}

/// Native sidebar: workspace destinations plus reusable prompt sessions.
struct StudioSidebar: View {
    @Bindable var model: StudioModel

    var body: some View {
        List(selection: selection) {
            Section("Workspace") {
                ForEach(StudioDestination.allCases) { destination in
                    Label(destination.rawValue, systemImage: destination.symbol)
                        .tag(SidebarItem.destination(destination))
                }
            }
            Section {
                ForEach(model.recentSessions.prefix(40)) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title.isEmpty ? "Untitled prompt" : session.title)
                            .lineLimit(1)
                        Text("\(session.versions.count) version\(session.versions.count == 1 ? "" : "s") · \(session.updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(HFBrand.muted)
                    }
                    .tag(SidebarItem.session(session.id))
                    .contextMenu {
                        Button("Delete Session", role: .destructive) { model.deleteSession(session.id) }
                            .disabled(model.isGenerating)
                    }
                    .accessibilityLabel("\(session.title), \(session.versions.count) versions")
                }
                if model.recentSessions.isEmpty {
                    Text("Your prompt sessions appear here.")
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                }
            } header: {
                HStack {
                    Text("Prompt Sessions")
                    Spacer()
                    Button("New Prompt", systemImage: "plus") { model.newSession() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(model.isGenerating)
                        .help("New prompt session (⌘N)")
                }
            }
        }
        .listStyle(.sidebar)
        // Aurora brand surface instead of the translucent system material (HitFluence visual system).
        .scrollContentBackground(.hidden)
        .background(LinearGradient(colors: [HFBrand.windowTop, HFBrand.navy.opacity(0.96)],
                                   startPoint: .top, endPoint: .bottom))
        .safeAreaInset(edge: .top, spacing: 0) { brand }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: {
                if model.destination == .workspace, !model.session.isBlank {
                    return .session(model.currentSessionID)
                }
                return .destination(model.destination)
            },
            set: { item in
                switch item {
                case .destination(let destination): model.destination = destination
                case .session(let id): model.select(id)
                case nil: break
                }
            }
        )
    }

    private var brand: some View {
        HStack(spacing: 10) {
            HFHashtag(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("HitFluence")
                    .font(.headline.weight(.bold))
                Text("PROMPT OPTIMIZER")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(HFBrand.periwinkle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HitFluence Prompt Optimizer")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Save sessions on this Mac", isOn: Binding(
                get: { model.historyEnabled }, set: { model.setHistoryEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            Button("Clear saved sessions") { model.deleteHistory() }
                .buttonStyle(.plain)
                .foregroundStyle(HFBrand.muted)
                .disabled(model.isGenerating)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#if DEBUG
#Preview("Sidebar") {
    NavigationSplitView {
        StudioSidebar(model: .previewSample())
    } detail: {
        HFAuroraBackground()
    }
    .frame(width: 760, height: 560)
    .preferredColorScheme(.dark)
}
#endif
