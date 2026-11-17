import Foundation

public enum LocalModelDiscovery {
    /// Ollama model tags are not inferred from the user's hardware or from a guessed filename.
    public static func suitableTags(for engine: PromptEngineKind, among tags: [String]) -> [String] {
        switch engine {
        case .apple: return []
        case .qwen:
            return tags.filter { $0.localizedCaseInsensitiveContains("qwen") }
                .sorted { score($0, engine: engine) > score($1, engine: engine) }
        case .glimmer:
            return tags.filter { $0.localizedCaseInsensitiveContains("glimmer") }
                .sorted { score($0, engine: engine) > score($1, engine: engine) }
        }
    }

    private static func score(_ tag: String, engine: PromptEngineKind) -> Int {
        let lowered = tag.lowercased()
        return switch engine {
        case .apple: 0
        case .qwen: (lowered.contains("instruct") ? 10 : 0) + (lowered.contains("coder") ? 3 : 0)
        case .glimmer: (lowered.contains("mlx") ? 10 : 0) + (lowered.contains("30b") ? 2 : 0)
        }
    }
}
