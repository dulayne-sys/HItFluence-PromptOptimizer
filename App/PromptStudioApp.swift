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
            CommandGroup(replacing: .newItem) {
                Button("New Prompt") {
                    model.freshPrompt()
                    model.destination = .studio
                }
                .keyboardShortcut("n", modifiers: [.command])
                Button("Optimize Prompt") { model.optimize() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.canOptimize)
                Button("Copy Optimized Markdown") { model.copyOutput() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(model.output.isEmpty)
            }
        }

        WindowGroup("Optimized Preview", id: "preview") {
            ExpandedOutputView(model: model, popout: true)
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 1020, height: 740)

        WindowGroup("Web Browser", id: "browser") {
            BrowserWorkspace(model: model, popout: true)
                .frame(minWidth: 850, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 800)

        MenuBarExtra("Prompt Studio", systemImage: "number") {
            QuickPromptView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
