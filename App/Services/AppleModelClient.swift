import Foundation
import FoundationModels

/// Apple Intelligence is never replaced by a remote provider automatically.
enum AppleModelClient {
    @MainActor
    static func modelStatus() -> String {
        switch SystemLanguageModel.default.availability {
        case .available: "Ready on device"
        case .unavailable(.appleIntelligenceNotEnabled): "Enable Apple Intelligence in System Settings"
        case .unavailable(.deviceNotEligible): "This Mac is not eligible for Apple Intelligence"
        case .unavailable(.modelNotReady): "Apple's model is still preparing"
        case .unavailable: "Apple Intelligence is unavailable"
        }
    }

    @MainActor
    /// `prompt` is already wrapped in a data envelope by `GenerationRequest.modelPrompt`.
    static func generate(prompt: String, instructions: String) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppleModelError.unavailable(modelStatus())
        }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: prompt)
            try Task.checkCancellation()
            return response.content
        } catch let error as LanguageModelError {
            // macOS 27 replaces the deprecated LanguageModelSession.GenerationError with LanguageModelError.
            if case .contextSizeExceeded(let detail) = error {
                throw AppleModelError.tooLong(tokens: detail.tokenCount, limit: detail.contextSize)
            }
            throw error
        }
    }
}

enum AppleModelError: LocalizedError {
    case unavailable(String)
    case tooLong(tokens: Int, limit: Int)
    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        case .tooLong(let tokens, let limit):
            "This prompt is too long for Apple's on-device model (\(tokens) of \(limit) tokens). Shorten it, or select a local Qwen or Glimmer model."
        }
    }
}
