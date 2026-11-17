import AppKit
import UniformTypeIdentifiers

@MainActor
enum MacActions {
    static func pasteboardString() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func exportMarkdown(_ markdown: String) throws -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Markdown"
        panel.message = "Choose a location for your optimized prompt."
        panel.nameFieldStringValue = "optimized-prompt.md"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let destination = panel.url else { return false }
        try markdown.write(to: destination, atomically: true, encoding: .utf8)
        return true
    }
}
