import Foundation

public enum PromptPostProcessor {
    public static func render(_ modelText: String, source: String, includeOriginal: Bool) -> String {
        var body = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```markdown\n") && body.hasSuffix("```") {
            body = String(body.dropFirst("```markdown\n".count).dropLast(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !body.isEmpty else { return "" }
        if !body.hasPrefix("#") { body = "# Optimized Prompt\n\n" + body }
        if includeOriginal {
            let fenceCount = max(4, longestBacktickRun(in: source) + 1)
            let fence = String(repeating: "`", count: fenceCount)
            body += "\n\n---\n\n## Original Request (Verbatim)\n\n\(fence)text\n\(source)\n\(fence)"
        }
        return body + "\n"
    }

    private static func longestBacktickRun(in value: String) -> Int {
        var current = 0
        var longest = 0
        for character in value {
            if character == "`" { current += 1; longest = max(longest, current) }
            else { current = 0 }
        }
        return longest
    }
}
