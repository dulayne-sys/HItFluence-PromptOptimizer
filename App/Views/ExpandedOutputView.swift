import SwiftUI

/// The independent artifact window ("Pop Out"). Shares the current session with the main window.
struct ExpandedOutputView: View {
    @Bindable var model: StudioModel
    var popout = true

    var body: some View {
        PromptOutputPanel(model: model, popout: popout, onOpenLink: { url in model.openInBrowser(url) })
            .background(HFAuroraBackground())
            .foregroundStyle(.white)
            .preferredColorScheme(.dark)
            .navigationTitle(model.session.title.isEmpty ? "Prompt Artifact" : model.session.title)
    }
}
