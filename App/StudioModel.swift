import Foundation
import Observation

enum StudioDestination: String, CaseIterable, Identifiable {
    case home = "Home"
    case studio = "Optimize"
    case browser = "Browser"
    case sources = "Sources"
    var id: String { rawValue }
}

@MainActor
@Observable
final class StudioModel {
    var destination: StudioDestination = .home
    var outputExpanded = false
    var browserExpanded = false
    var browserURL: URL?
    var news = NewsStore()
    var input = ""
    var output = ""
    var profile: PromptProfile = .developer
    var detail: PromptDetail = .complete
    var engine: PromptEngineKind = .apple
    var isGenerating = false
    var isPreview = true
    var includeOriginal = false
    var historyEnabled = UserDefaults.standard.bool(forKey: "PromptStudio.HistoryEnabled")
    var history: [PromptRecord] = []
    var availableLocalTags: [String] = []
    var chosenQwenTag = ""
    var chosenGlimmerTag = ""
    var status = "Ready for your next prompt"
    var validation = PromptValidation(missingExactStrings: [], warnings: [])
    var alertMessage: String?
    var localServerReachable = false

    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var hasBootstrapped = false

    var canOptimize: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var matchingTags: [String] {
        LocalModelDiscovery.suitableTags(for: engine, among: availableLocalTags)
    }

    var selectedLocalTag: String? {
        let selected = engine == .qwen ? chosenQwenTag : chosenGlimmerTag
        let matches = matchingTags
        return matches.contains(selected) ? selected : matches.first
    }

    var modelDescription: String {
        if engine == .apple { return AppleModelClient.modelStatus() }
        guard localServerReachable else { return "Ollama is not connected" }
        return selectedLocalTag ?? "No matching installed model"
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        news.bootstrap()
        news.refreshIfStale()
        if historyEnabled { history = await HistoryStore.shared.load() }
        await refreshLocalModels()
    }

    func refreshLocalModels() async {
        do {
            availableLocalTags = try await LocalOllamaClient.shared.installedModelNames()
            localServerReachable = true
        } catch {
            availableLocalTags = []
            localServerReachable = false
        }
    }

    func setHistoryEnabled(_ value: Bool) {
        historyEnabled = value
        UserDefaults.standard.set(value, forKey: "PromptStudio.HistoryEnabled")
        if value {
            Task { history = await HistoryStore.shared.load() }
        } else {
            history = []
            Task { try? await HistoryStore.shared.delete() }
        }
    }

    func optimize() {
        guard canOptimize else { return }
        let original = input
        let chosenProfile = profile
        let chosenDetail = detail
        let chosenEngine = engine
        let selected = selectedLocalTag
        let instructions = PromptRules.instructions(profile: chosenProfile, detail: chosenDetail)
        isGenerating = true
        status = "Optimizing with \(chosenEngine.title)…"
        alertMessage = nil
        validation = PromptValidation(missingExactStrings: [], warnings: [])
        generationTask = Task {
            defer {
                isGenerating = false
                generationTask = nil
            }
            do {
                let response: String
                switch chosenEngine {
                case .apple:
                    response = try await AppleModelClient.generate(input: original, instructions: instructions)
                case .qwen, .glimmer:
                    guard let selected else { throw LocalModelError.modelNotInstalled }
                    response = try await LocalOllamaClient.shared.generate(
                        model: selected, input: original, instructions: instructions)
                }
                try Task.checkCancellation()
                let result = PromptPostProcessor.render(response, source: original, includeOriginal: includeOriginal)
                guard !result.isEmpty else { throw LocalModelError.emptyResponse }
                output = result
                validation = PromptValidator.inspect(source: original, generated: result)
                status = validation.hasWarnings ? "Optimized · review preservation warnings" : "Optimized · ready to send"
                let record = PromptRecord(input: original, output: result,
                                          profile: chosenProfile, detail: chosenDetail,
                                          engineLabel: selected ?? chosenEngine.title)
                history.insert(record, at: 0)
                if history.count > 100 { history = Array(history.prefix(100)) }
                if historyEnabled {
                    do { try await HistoryStore.shared.save(history) }
                    catch {
                        status = "Optimized · could not save history"
                        alertMessage = "The output is ready, but history could not be saved: \(error.localizedDescription)"
                    }
                }
            } catch let error where GenerationCancellation.isCancellation(error) {
                status = "Generation canceled"
            } catch {
                status = "Could not optimize"
                alertMessage = error.localizedDescription
            }
        }
    }

    func cancel() { generationTask?.cancel() }

    func loadRecord(_ record: PromptRecord) {
        guard !isGenerating else { return }
        input = record.input
        output = record.output
        profile = record.profile
        detail = record.detail
        status = "Loaded saved prompt"
        validation = PromptValidator.inspect(source: record.input, generated: record.output)
    }

    func openBrowser(_ url: URL) {
        guard url.scheme?.lowercased() == "https" else {
            alertMessage = "Only HTTPS pages can be opened in the built-in browser."
            return
        }
        browserURL = url
        destination = .browser
    }

    func freshPrompt() {
        guard !isGenerating else { return }
        input = ""
        output = ""
        validation = PromptValidation(missingExactStrings: [], warnings: [])
        status = "Ready for your next prompt"
    }

    func importClipboard() { input = MacActions.pasteboardString() }

    func copyOutput() {
        guard !output.isEmpty else { return }
        MacActions.copy(output)
        status = "Markdown copied to clipboard"
    }

    func exportOutput() {
        guard !output.isEmpty else { return }
        do {
            if try MacActions.exportMarkdown(output) { status = "Markdown exported" }
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func deleteHistory() {
        history.removeAll()
        Task {
            do { try await HistoryStore.shared.delete() }
            catch { alertMessage = "Could not delete history: \(error.localizedDescription)" }
        }
    }
}
