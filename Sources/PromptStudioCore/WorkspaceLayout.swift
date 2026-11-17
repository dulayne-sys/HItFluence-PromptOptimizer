import Foundation

public enum WorkspacePane: String, Codable, Sendable, CaseIterable {
    case browser, chat, artifact
}

/// Per-window panel preferences plus the rules that adapt them to the window width.
/// Order on screen: [sidebar] [browser] [chat] [artifact]. Chat is the flexible column.
public struct WorkspaceLayout: Codable, Equatable, Sendable {
    public static let sidebarWidth = 250.0
    public static let minChat = 380.0
    public static let minBrowser = 360.0
    public static let minArtifact = 340.0
    public static let maxPaneWidth = 900.0
    public static let railWidth = 44.0
    public static let dividerWidth = 9.0

    /// What the user wants when there is room.
    public var sidebarPreferred = true
    /// The user re-opened the sidebar while space was tight; don't auto-collapse it again.
    public var sidebarPinned = false
    public var browserOpen = false
    public var artifactOpen = true
    public var focus: WorkspacePane?
    public var browserWidth = 480.0
    public var artifactWidth = 520.0
    /// When both side panes can't fit, this one stays full and the other becomes a rail.
    public var compactPrimary: WorkspacePane = .artifact

    public init() {}

    public enum PaneState: Equatable, Sendable {
        case hidden, rail, visible(Double)
    }

    public struct Resolved: Equatable, Sendable {
        public var sidebar: Bool
        public var browser: PaneState
        public var chat: Bool
        public var artifact: PaneState

        public init(sidebar: Bool, browser: PaneState, chat: Bool, artifact: PaneState) {
            self.sidebar = sidebar
            self.browser = browser
            self.chat = chat
            self.artifact = artifact
        }
    }

    public func resolve(windowWidth: Double) -> Resolved {
        if let focus {
            return Resolved(sidebar: false,
                            browser: focus == .browser ? .visible(windowWidth) : .hidden,
                            chat: focus == .chat,
                            artifact: focus == .artifact ? .visible(windowWidth) : .hidden)
        }
        var sidebar = sidebarPreferred
        var browser: PaneState = browserOpen ? .visible(browserWidth) : .hidden
        var artifact: PaneState = artifactOpen ? .visible(artifactWidth) : .hidden

        func cost(_ state: PaneState) -> Double {
            switch state {
            case .hidden: 0
            case .rail: Self.railWidth + Self.dividerWidth
            case .visible(let width): width + Self.dividerWidth
            }
        }
        func total() -> Double { (sidebar ? Self.sidebarWidth : 0) + Self.minChat + cost(browser) + cost(artifact) }
        func overflows() -> Bool { total() > windowWidth + 0.5 }

        // 1. Collapse the sidebar first, unless the user explicitly asked for it.
        if overflows() && sidebar && !sidebarPinned { sidebar = false }

        // 2. Shrink side panes toward their minimum widths, proportionally.
        if overflows() {
            let over = total() - windowWidth
            let browserSlack = browser.width.map { $0 - Self.minBrowser } ?? 0
            let artifactSlack = artifact.width.map { $0 - Self.minArtifact } ?? 0
            let slack = browserSlack + artifactSlack
            if slack > 0 {
                let ratio = min(1, over / slack)
                if let width = browser.width { browser = .visible(width - browserSlack * ratio) }
                if let width = artifact.width { artifact = .visible(width - artifactSlack * ratio) }
            }
        }

        // 3. Still too wide: keep the primary side pane and turn the other into a rail.
        if overflows() {
            if browser.width != nil && artifact.width != nil {
                if compactPrimary == .browser { artifact = .rail } else { browser = .rail }
            } else if browser.width != nil {
                browser = .rail
            } else if artifact.width != nil {
                artifact = .rail
            }
            // Give the surviving pane back as much of its preferred width as now fits.
            let reserved = (sidebar ? Self.sidebarWidth : 0) + Self.minChat + Self.dividerWidth
            if case .visible = browser, artifact == .rail {
                let room = windowWidth - reserved - cost(.rail)
                browser = .visible(max(Self.minBrowser, min(browserWidth, room)))
            } else if case .visible = artifact, browser == .rail {
                let room = windowWidth - reserved - cost(.rail)
                artifact = .visible(max(Self.minArtifact, min(artifactWidth, room)))
            }
        }

        // 4. Last resort: even a pinned sidebar yields to the conversation.
        if overflows() && sidebar { sidebar = false }

        return Resolved(sidebar: sidebar, browser: browser, chat: true, artifact: artifact)
    }

    // MARK: Mutations

    public mutating func toggleBrowser() {
        browserOpen.toggle()
        focus = nil
        if browserOpen {
            sidebarPinned = false
            compactPrimary = .browser
        } else {
            compactPrimary = .artifact
        }
    }

    public mutating func openBrowser() {
        if !browserOpen { toggleBrowser() } else { focus = focus == .browser ? .browser : nil; compactPrimary = .browser }
    }

    public mutating func toggleArtifact() {
        artifactOpen.toggle()
        focus = nil
        if artifactOpen { compactPrimary = .artifact }
    }

    public mutating func showArtifact() {
        artifactOpen = true
        if focus != .artifact { focus = nil }
        compactPrimary = .artifact
    }

    public mutating func toggleFocus(_ pane: WorkspacePane) {
        focus = focus == pane ? nil : pane
    }

    /// Called when a railed pane is clicked: it becomes the one that keeps its width.
    public mutating func reveal(_ pane: WorkspacePane) {
        compactPrimary = pane
        if pane == .browser { browserOpen = true }
        if pane == .artifact { artifactOpen = true }
    }

    /// Reflects the user's own sidebar toggle.
    public mutating func setSidebarVisible(_ visible: Bool) {
        sidebarPreferred = visible
        sidebarPinned = visible
    }

    public mutating func resize(_ pane: WorkspacePane, to width: Double) {
        switch pane {
        case .browser: browserWidth = min(Self.maxPaneWidth, max(Self.minBrowser, width))
        case .artifact: artifactWidth = min(Self.maxPaneWidth, max(Self.minArtifact, width))
        case .chat: break
        }
    }

    // MARK: Persistence (SceneStorage-friendly)

    public var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    public init(encoded: String) {
        if let data = encoded.data(using: .utf8), let layout = try? JSONDecoder().decode(Self.self, from: data) {
            self = layout
        } else {
            self.init()
        }
    }
}

extension WorkspaceLayout.PaneState {
    public var width: Double? {
        if case .visible(let width) = self { width } else { nil }
    }
}
