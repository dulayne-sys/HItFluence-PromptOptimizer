import SwiftUI

struct StudioRootView: View {
    @Bindable var model: StudioModel

    var body: some View {
        HStack(spacing: 0) {
            if !model.outputExpanded && !(model.destination == .browser && model.browserExpanded) {
                StudioSidebar(model: model)
                    .frame(width: 234)
                HFBrand.separator.frame(width: 1)
            }
            VStack(spacing: 0) {
                StudioToolbar(model: model)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 14)
                HFBrand.separator.frame(height: 1)
                if model.outputExpanded {
                    ExpandedOutputView(model: model)
                } else {
                    switch model.destination {
                    case .home:
                        HomeDashboard(model: model, news: model.news)
                    case .studio:
                        HStack(spacing: 18) {
                            PromptChatPanel(model: model)
                                .frame(minWidth: 310, maxWidth: .infinity, maxHeight: .infinity)
                            PromptOutputPanel(model: model)
                                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(20)
                    case .browser:
                        BrowserWorkspace(model: model)
                    case .sources:
                        NewsSourcesView(model: model, news: model.news)
                    }
                }
                StudioStatusBar(model: model)
            }
        }
        .background(HFAuroraBackground())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1020, minHeight: 690)
        .task { await model.bootstrap() }
        .alert("HitFluence Prompt Studio", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

private struct StudioToolbar: View {
    @Bindable var model: StudioModel
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                HFHashtag(size: 31)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prompt Studio")
                        .font(.headline.weight(.bold))
                    Text(model.outputExpanded ? "Expanded preview" : model.destination.rawValue)
                        .font(.caption)
                        .foregroundStyle(HFBrand.muted)
                }
            }
            Spacer(minLength: 8)
            if model.destination == .studio && !model.outputExpanded {
                Picker("Profile", selection: $model.profile) {
                    ForEach(PromptProfile.allCases) { profile in
                        Label(profile.title, systemImage: profile.icon).tag(profile)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 162)
                .accessibilityLabel("Target AI agent profile")
                Picker("Detail", selection: $model.detail) {
                    ForEach(PromptDetail.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
            } else {
                Label("PRIVATE · LOCAL INTELLIGENCE", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HFBrand.periwinkle)
            }
        }
    }
}

private struct StudioStatusBar: View {
    let model: StudioModel
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isGenerating ? HFBrand.gold : HFBrand.mint)
                .frame(width: 7, height: 7)
            Text(model.status)
                .lineLimit(1)
            Spacer()
            Text(model.news.isEnabled ? "News feeds: opt-in enabled" : "News feeds: off")
            Text("·")
            Label("AI: Local-first", systemImage: "lock.shield")
        }
        .font(.caption)
        .foregroundStyle(HFBrand.muted)
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
