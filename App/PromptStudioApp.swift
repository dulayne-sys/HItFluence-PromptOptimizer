import SwiftUI

@main
struct PromptStudioApp: App {
    @State private var model = StudioModel()

    var body: some Scene {
        WindowGroup("HitFluence Prompt Studio", id: "main") {
            StudioRootView(model: model)
        }
        .defaultSize(width: 1450, height: 880)
        .commands {
            SidebarCommands()
            StudioCommands(model: model)
        }

        WindowGroup("Prompt Artifact", id: "artifact") {
            ExpandedOutputView(model: model)
                .frame(minWidth: 560, minHeight: 480)
        }
        .defaultSize(width: 900, height: 760)

        WindowGroup("Web Browser", id: "browser") {
            BrowserWorkspace(model: model)
                .frame(minWidth: 640, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 800)

        Settings {
            SettingsView(model: model)
        }

        MenuBarExtra("Prompt Studio", systemImage: "number") {
            QuickPromptView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Every primary workspace command is reachable from the menu bar with a keyboard shortcut.
struct StudioCommands: Commands {
    let model: StudioModel
    @FocusedValue(\.workspaceActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Prompt") { model.newSession() }
                .keyboardShortcut("n")
                .disabled(model.isGenerating)
        }
        CommandGroup(replacing: .importExport) {
            Button("Export Markdown…") { model.exportOutput() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.output.isEmpty)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Artifact Markdown") { model.copyOutput() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.output.isEmpty)
        }
        CommandMenu("Prompt") {
            Button(model.session.currentVersion == nil ? "Optimize" : "Send Follow-Up") { model.send() }
                .keyboardShortcut(.return)
                .disabled(!model.canOptimize)
            Button("Stop Generating") { model.cancel() }
                .keyboardShortcut(".")
                .disabled(!model.isGenerating)
            Divider()
            if let proposal = model.session.proposal {
                Button("Apply Version \(proposal.number)") { model.accept(proposal) }
                Button("Discard Version \(proposal.number)") { model.discard(proposal) }
            } else {
                Button("Apply Proposed Version") {}.disabled(true)
            }
            Divider()
            Picker("Model", selection: Binding(get: { model.engine }, set: { model.engine = $0 })) {
                ForEach(PromptEngineKind.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }
            .disabled(model.isGenerating)
        }
        CommandGroup(after: .sidebar) {
            Button(actions?.isBrowserOpen == true ? "Hide Browser" : "Show Browser") { actions?.toggleBrowser() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button(actions?.isArtifactOpen == true ? "Hide Markdown Preview" : "Show Markdown Preview") { actions?.toggleArtifact() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Divider()
            Button("Focus Browser") { actions?.toggleFocus(.browser) }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Focus Chat") { actions?.toggleFocus(.chat) }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Focus Artifact") { actions?.toggleFocus(.artifact) }
                .keyboardShortcut("3", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Show All Panels") { actions?.exitFocus() }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(actions?.focus == nil)
            Divider()
            Button("Pop Out Artifact") { actions?.popOutArtifact() }
                .disabled(actions == nil)
            Button("Pop Out Browser") { actions?.popOutBrowser() }
                .disabled(actions == nil)
            Divider()
        }
    }
}
