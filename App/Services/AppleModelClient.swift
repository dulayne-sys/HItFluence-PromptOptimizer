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
    static func generate(input: String, instructions: String) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppleModelError.unavailable(modelStatus())
        }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: PromptRules.userEnvelope(input))
        try Task.checkCancellation()
        return response.content
    }
}

enum AppleModelError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let message): message }
    }
}
