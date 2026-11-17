import Foundation

public struct PromptValidation: Sendable, Equatable {
    public var missingExactStrings: [String]
    public var warnings: [String]
    public var hasWarnings: Bool { !warnings.isEmpty }
    public init(missingExactStrings: [String], warnings: [String]) {
        self.missingExactStrings = missingExactStrings
        self.warnings = warnings
    }
}

public enum PromptValidator {
    /// A mechanical preservation check, not a semantic correctness score.
    public static func inspect(source: String, generated: String) -> PromptValidation {
        guard !generated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return PromptValidation(missingExactStrings: [], warnings: ["The model returned no prompt."])
        }
        let values = collectProtectedStrings(source)
        let missing = values.filter { !generated.contains($0) }
        var warnings = [String]()
        if !missing.isEmpty {
            warnings.append("Some exact URLs, paths, dates or quoted values are absent. Review them before sending.")
        }
        if generated.contains("{{TO_CONFIRM}}") {
            warnings.append("The optimized prompt contains information that needs confirmation.")
        }
        return PromptValidation(missingExactStrings: missing, warnings: warnings)
    }

    public static func collectProtectedStrings(_ input: String) -> [String] {
        let patterns = [
            #"https?://[^\s<>\)\]]+"#,
            // Absolute paths: folders may contain spaces ("/Volumes/Test Drive/…"), the last component may not,
            // so trailing prose is not swallowed; never start inside a URL or after another path character.
            #"(?<![\w:/.])(?:/[A-Za-z0-9._+-]+(?: [A-Za-z0-9._+-]+)*(?=/))+/[A-Za-z0-9._+-]+/?"#,
            #"\b\d{4}-\d{2}-\d{2}\b"#,
            #"\b[A-Za-z0-9_.-]+\.(?:swift|xcodeproj|xcworkspace|md|json|plist|xcassets)\b"#,
            #"`[^`\n]+`"#
        ]
        var result = [String]()
        var seen = Set<String>()
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: input, range: range) {
                guard let foundRange = Range(match.range, in: input) else { continue }
                let value = String(input[foundRange]).trimmingCharacters(in: CharacterSet(charactersIn: ",.;"))
                if !value.isEmpty && seen.insert(value).inserted { result.append(value) }
            }
        }
        return result
    }
}
