// Tokenizer loading for MLX models from the model folder only. Adapted from HitSwap's DACModelsMLX
// (same pins: mlx-swift-lm 3.32.3, swift-transformers 1.3.5). `AutoTokenizer.from(modelFolder:)` reads
// tokenizer.json and tokenizer_config.json from disk; no Hugging Face request is made.

import Foundation
import MLXLMCommon
import Tokenizers

struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TransformersTokenizer(try await AutoTokenizer.from(modelFolder: directory))
    }
}

/// Adapts a swift-transformers tokenizer to mlx-swift-lm's protocol.
private struct TransformersTokenizer: MLXLMCommon.Tokenizer, @unchecked Sendable {
    let base: any Tokenizers.Tokenizer

    init(_ base: any Tokenizers.Tokenizer) { self.base = base }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] { base.encode(text: text, addSpecialTokens: addSpecialTokens) }
    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String { base.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens) }
    func convertTokenToId(_ token: String) -> Int? { base.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { base.convertIdToToken(id) }
    var bosToken: String? { base.bosToken }
    var eosToken: String? { base.eosToken }
    var unknownToken: String? { base.unknownToken }

    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        try base.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
    }
}
