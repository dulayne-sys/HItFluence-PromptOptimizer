import AppKit
import SwiftUI

/// Window-scoped workspace actions for the menu bar (View and Workspace menus).
struct WorkspaceActions {
    var toggleBrowser: () -> Void
    var toggleArtifact: () -> Void
    var toggleFocus: (WorkspacePane) -> Void
    var exitFocus: () -> Void
    var popOutArtifact: () -> Void
    var popOutBrowser: () -> Void
    var isBrowserOpen: Bool
    var isArtifactOpen: Bool
    var focus: WorkspacePane?
}

extension FocusedValues {
    @Entry var workspaceActions: WorkspaceActions?
}

struct StudioRootView: View {
    @Bindable var model: StudioModel
    /// Optional starting layout (previews and visual QA); otherwise the window's saved layout is restored.
    var initialLayout: WorkspaceLayout?
    /// Per-window panel visibility and widths, restored with the window.
    @SceneStorage("HitFluence.workspaceLayout") private var storedLayout = ""
    @State private var layout = WorkspaceLayout()
    @State private var restoredLayout = false
    @State private var browser: BrowserSession?
    @State private var windowWidth = 1450.0
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolved: WorkspaceLayout.Resolved {
        guard model.destination == .workspace else {
            return .init(sidebar: layout.sidebarPreferred, browser: .hidden, chat: false, artifact: .hidden)
        }
        return layout.resolve(windowWidth: windowWidth)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            StudioSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: WorkspaceLayout.sidebarWidth, max: 320)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HFAuroraBackground(hero: model.destination == .home))
                .safeAreaInset(edge: .bottom, spacing: 0) { StudioStatusBar(model: model) }
                .toolbar { toolbarContent }
                .navigationTitle(windowTitle)
                .navigationSubtitle("HitFluence Prompt Studio")
        }
        .onGeometryChange(for: Double.self) { proxy in proxy.size.width } action: { width in windowWidth = width }
        .frame(minWidth: 900, minHeight: 620)
        .foregroundStyle(.white)
        .tint(HFBrand.periwinkle)
        .preferredColorScheme(.dark)
        .task { await model.bootstrap() }
        .onAppear {
            if browser == nil { browser = BrowserSession() }
            if !restoredLayout {
                layout = initialLayout ?? WorkspaceLayout(encoded: storedLayout)
                restoredLayout = true
            }
        }
        .onChange(of: layout) { _, newValue in storedLayout = newValue.encoded }
        .onChange(of: model.browserRequest) { _, request in
            guard let request else { return }
            if browser == nil { browser = BrowserSession() }
            animate { layout.openBrowser() }
            browser?.visit(request.url)
        }
        .focusedSceneValue(\.workspaceActions, actions)
        .alert("HitFluence Prompt Studio", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        switch model.destination {
        case .home:
            HomeDashboard(model: model, news: model.news)
        case .sources:
            NewsSourcesView(model: model, news: model.news)
        case .workspace:
            WorkspaceSplitView(layout: $layout, resolved: resolved) {
                if let browser {
                    BrowserPane(session: browser,
                                isFocused: layout.focus == .browser,
                                onToggleFocus: { animate { layout.toggleFocus(.browser) } },
                                onClose: { animate { layout.toggleBrowser() } },
                                onPopOut: { popOutBrowser() })
                }
            } chat: {
                PromptChatPanel(model: model,
                                isFocused: layout.focus == .chat,
                                onToggleFocus: { animate { layout.toggleFocus(.chat) } },
                                onShowArtifact: { animate { layout.showArtifact() } })
            } artifact: {
                PromptOutputPanel(model: model,
                                  isFocused: layout.focus == .artifact,
                                  onToggleFocus: { animate { layout.toggleFocus(.artifact) } },
                                  onClose: { animate { layout.toggleArtifact() } },
                                  onOpenLink: { url in openLink(url) })
            }
        }
    }

    private var windowTitle: String {
        switch model.destination {
        case .workspace: model.session.title.isEmpty ? "New Prompt" : model.session.title
        default: model.destination.rawValue
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.destination == .workspace {
                Toggle(isOn: Binding(get: { layout.artifactOpen && layout.focus == nil },
                                     set: { _ in animate { layout.toggleArtifact() } })) {
                    Label("Markdown Preview", systemImage: "sidebar.right")
                }
                .help("Show or hide the Markdown artifact (⇧⌘M)")
            }
            Toggle(isOn: Binding(get: { model.destination == .workspace && layout.browserOpen },
                                 set: { _ in toggleBrowser() })) {
                Label("Browser", systemImage: "globe")
            }
            .help("Open the web browser beside the conversation (⇧⌘B)")
        }
    }

    // MARK: Actions

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { resolved.sidebar ? .all : .detailOnly },
            set: { newValue in
                let visible = newValue != .detailOnly
                guard visible != resolved.sidebar else { return }
                animate { layout.setSidebarVisible(visible) }
            }
        )
    }

    private func toggleBrowser() {
        if model.destination != .workspace {
            model.destination = .workspace
            if !layout.browserOpen { animate { layout.toggleBrowser() } }
        } else {
            animate { layout.toggleBrowser() }
        }
    }

    private func popOutBrowser() {
        model.lastBrowserURL = browser?.currentURL ?? model.lastBrowserURL
        openWindow(id: "browser")
    }

    private func openLink(_ url: URL) {
        if url.scheme?.lowercased() == "https" {
            model.openInBrowser(url)
        } else if let scheme = url.scheme?.lowercased(), scheme == "mailto" || scheme == "http" {
            NSWorkspace.shared.open(url)
        }
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            toggleBrowser: { toggleBrowser() },
            toggleArtifact: {
                model.destination = .workspace
                animate { layout.toggleArtifact() }
            },
            toggleFocus: { pane in
                model.destination = .workspace
                animate { layout.toggleFocus(pane) }
            },
            exitFocus: { animate { layout.focus = nil } },
            popOutArtifact: { openWindow(id: "artifact") },
            popOutBrowser: { popOutBrowser() },
            isBrowserOpen: layout.browserOpen,
            isArtifactOpen: layout.artifactOpen,
            focus: layout.focus
        )
    }

    private func animate(_ change: () -> Void) {
        if reduceMotion { change() } else { withAnimation(.snappy(duration: 0.25)) { change() } }
    }
}

private struct StudioStatusBar: View {
    let model: StudioModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isGenerating ? HFBrand.gold : HFBrand.mint)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(model.status)
                .lineLimit(1)
            Spacer()
            Text(model.news.isEnabled ? "News: on" : "News: off")
            Text("·")
            Label("Local-first AI", systemImage: "lock.shield")
        }
        .font(.caption)
        .foregroundStyle(HFBrand.muted)
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(HFBrand.windowTop.opacity(0.85))
        .overlay(alignment: .top) { Rectangle().fill(HFBrand.separator).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Workspace 1450×880", traits: .fixedLayout(width: 1450, height: 880)) {
    StudioRootView(model: .previewSample())
}
#endif
