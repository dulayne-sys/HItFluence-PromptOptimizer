import SwiftUI

struct StudioSidebar: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                HFHashtag(size: 49)
                VStack(alignment: .leading, spacing: 4) {
                    Text("HitFluence")
                        .font(.headline.weight(.bold))
                    Text("PROMPT OPTIMIZER")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(HFBrand.periwinkle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 25)
            .padding(.bottom, 23)

            Button {
                model.freshPrompt()
                model.destination = .studio
            } label: {
                Label("New Prompt", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(HFBrand.blue)
            .padding(.horizontal, 15)
            .disabled(model.isGenerating)

            HFEyebrow(title: "WORKSPACE")
                .padding(.horizontal, 18)
                .padding(.top, 27)
                .padding(.bottom, 9)
            VStack(spacing: 4) {
                navigation("Home", symbol: "house", destination: .home)
                navigation("Optimize", symbol: "bubble.left.and.text.bubble.right", destination: .studio)
                navigation("Browser", symbol: "globe", destination: .browser)
                navigation("News Sources", symbol: "newspaper", destination: .sources)
            }
            .padding(.horizontal, 10)

            HFEyebrow(title: "INTELLIGENCE")
                .padding(.horizontal, 18)
                .padding(.top, 25)
                .padding(.bottom, 9)
            VStack(spacing: 3) {
                ForEach(PromptEngineKind.allCases) { choice in
                    EngineSelectionRow(title: choice.title, selected: model.engine == choice,
                                       symbol: choice == .apple ? "apple.logo" : choice == .qwen ? "cpu" : "brain.head.profile") {
                        model.engine = choice
                        model.destination = .studio
                    }
                }
            }
            .padding(.horizontal, 10)

            if model.engine.isLocalOllama {
                VStack(alignment: .leading, spacing: 8) {
                    if model.matchingTags.isEmpty {
                        Text("No installed model detected")
                            .font(.caption)
                            .foregroundStyle(HFBrand.coral)
                    } else {
                        Picker("Installed model", selection: localSelection) {
                            ForEach(model.matchingTags, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    Button("Refresh models", systemImage: "arrow.clockwise") {
                        Task { await model.refreshLocalModels() }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(HFBrand.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            HFEyebrow(title: "RECENT PROMPTS")
                .padding(.horizontal, 18)
                .padding(.top, 23)
                .padding(.bottom, 9)
            ScrollView {
                LazyVStack(spacing: 3) {
                    if model.history.isEmpty {
                        Text("Your prompts appear here after optimization.")
                            .font(.caption)
                            .foregroundStyle(HFBrand.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(model.history) { record in
                            Button {
                                model.loadRecord(record)
                                model.destination = .studio
                            } label: {
                                Label(record.input.replacingOccurrences(of: "\n", with: " "), systemImage: "text.bubble")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(9)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isGenerating)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Save local history", isOn: Binding(
                    get: { model.historyEnabled }, set: { model.setHistoryEnabled($0) }
                ))
                .font(.caption)
                .toggleStyle(.switch)
                Button("Clear saved history") { model.deleteHistory() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HFBrand.muted)
                Text("HITFLUENCE MEDIA & TECHNOLOGY")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(HFBrand.muted)
            }
            .padding(17)
        }
        .background(HFBrand.windowTop.opacity(0.88))
    }

    private func navigation(_ label: String, symbol: String, destination: StudioDestination) -> some View {
        Button { model.destination = destination } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .frame(width: 20)
                Text(label)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(model.destination == destination ? .semibold : .regular))
            .foregroundStyle(model.destination == destination ? .white : HFBrand.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(model.destination == destination ? HFBrand.blue.opacity(0.22) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.destination == destination ? .isSelected : [])
    }

    private var localSelection: Binding<String> {
        Binding(
            get: { model.selectedLocalTag ?? "" },
            set: { value in
                if model.engine == .qwen { model.chosenQwenTag = value }
                if model.engine == .glimmer { model.chosenGlimmerTag = value }
            }
        )
    }
}

struct EngineSelectionRow: View {
    let title: String
    let selected: Bool
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(selected ? HFBrand.lavender : HFBrand.muted)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(HFBrand.mint) }
            }
            .font(.subheadline)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(selected ? HFBrand.violet.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
