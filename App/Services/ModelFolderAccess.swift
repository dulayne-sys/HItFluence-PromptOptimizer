import AppKit
import Foundation

/// The sandboxed app reads model weights from a folder the user picks once (for example ~/Desktop/LLM).
/// Access is remembered with an app-scoped security bookmark and kept open while the app runs,
/// because MLX and Core AI read weights lazily after loading starts.
@MainActor
enum ModelFolderAccess {
    private static let bookmarkKey = "PromptStudio.ModelsFolderBookmark"
    private static var activeURL: URL?

    /// Shows an open panel. Returns the chosen folder after saving its bookmark.
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Your Models Folder"
        panel.message = "Choose the folder that holds your local models (for example LLM on your Desktop). Prompt Studio only reads it."
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            return nil
        }
        return activate(url)
    }

    /// The remembered folder with sandbox access started, or nil if none was chosen or it moved.
    static func restore() -> URL? {
        if let activeURL { return activeURL }
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let refreshed = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                        includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return activate(url)
    }

    static func forget() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static func activate(_ url: URL) -> URL {
        if activeURL != url {
            activeURL?.stopAccessingSecurityScopedResource()
            _ = url.startAccessingSecurityScopedResource()
            activeURL = url
        }
        return url
    }

    /// Models shipped inside the app bundle (Contents/Resources/Models).
    static var bundledModelsURL: URL? {
        Bundle.main.resourceURL?.appending(path: "Models", directoryHint: .isDirectory)
    }
}
