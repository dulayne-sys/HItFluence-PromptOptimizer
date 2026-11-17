import CoreAILanguageModels
import Foundation
import FoundationModels
import MLXLLM
import MLXLMCommon
import MLXVLM

enum LocalModelError: LocalizedError {
    case notUsable(String)
    case emptyResponse
    case loadFailed(String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .notUsable(let reason): reason
        case .emptyResponse: "The local model generated an empty response."
        case .loadFailed(let name, let underlying): "Couldn't load \(name): \(underlying)"
        }
    }
}

/// Runs local models inside the app process: Core AI bundles through FoundationModels'
/// `LanguageModelSession`, MLX weights through mlx-swift-lm's `ChatSession`. One model is resident at a time;
/// switching models unloads the previous one so a 16 GB Mac isn't asked to hold two.
actor LocalModelRuntime {
    static let shared = LocalModelRuntime()

    private enum Loaded {
        case coreAI(CoreAILanguageModel)
        case mlx(ModelContainer)
    }

    private var loaded: (id: String, model: Loaded)?

    var loadedModelID: String? { loaded?.id }

    /// Generates with `model`, loading it first if needed. `onPhase` reports real progress ("Loading…").
    func generate(_ model: LocalModel, prompt: String, instructions: String,
                  onPhase: @escaping @Sendable (String) -> Void) async throws -> String {
        guard model.isUsable else { throw LocalModelError.notUsable(model.status.explanation) }
        let resident = try await load(model, onPhase: onPhase)
        try Task.checkCancellation()
        onPhase("Generating with \(model.name)…")
        let output: String
        switch resident {
        case .coreAI(let languageModel):
            let session = LanguageModelSession(model: languageModel, instructions: instructions)
            do {
                output = try await session.respond(
                    to: prompt, options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 2_048)).content
            } catch let error as LanguageModelError {
                if case .contextSizeExceeded(let detail) = error {
                    throw AppleModelError.tooLong(tokens: detail.tokenCount, limit: detail.contextSize)
                }
                throw error
            }
        case .mlx(let container):
            let session = ChatSession(container, instructions: instructions,
                                      generateParameters: GenerateParameters(maxTokens: 2_048, temperature: 0.2))
            output = try await session.respond(to: prompt)
        }
        try Task.checkCancellation()
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocalModelError.emptyResponse }
        return output
    }

    func unload() {
        if case .coreAI(let model) = loaded?.model { model.unload() }
        loaded = nil
    }

    private func load(_ model: LocalModel, onPhase: @Sendable (String) -> Void) async throws -> Loaded {
        if let loaded, loaded.id == model.id { return loaded.model }
        unload()
        onPhase(model.backend == .coreAI ? "Loading \(model.name) (slower the first time while macOS compiles it)…"
                                         : "Loading \(model.name) into memory…")
        do {
            let resident: Loaded
            switch model.backend {
            case .coreAI:
                let languageModel = try await CoreAILanguageModel(resourcesAt: model.directory)
                try await languageModel.load()
                resident = .coreAI(languageModel)
            case .mlxText:
                resident = .mlx(try await LLMModelFactory.shared.loadContainer(from: model.directory,
                                                                                 using: LocalTokenizerLoader()))
            case .mlxVision:
                resident = .mlx(try await VLMModelFactory.shared.loadContainer(from: model.directory,
                                                                                 using: LocalTokenizerLoader()))
            }
            loaded = (model.id, resident)
            return resident
        } catch let error where GenerationCancellation.isCancellation(error) {
            throw error
        } catch {
            throw LocalModelError.loadFailed(model.name, underlying: error.localizedDescription)
        }
    }
}
