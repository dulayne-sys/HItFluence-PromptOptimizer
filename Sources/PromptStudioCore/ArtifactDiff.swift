import Foundation

public struct DiffLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case unchanged, added, removed }
    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Line-level comparison between two artifact versions (longest common subsequence).
public enum ArtifactDiff {
    public static func lines(from old: String, to new: String) -> [DiffLine] {
        let a = old.components(separatedBy: "\n")
        let b = new.components(separatedBy: "\n")
        // Very large inputs fall back to a plain replace view rather than an O(n·m) table.
        guard a.count * b.count <= 4_000_000 else {
            return a.map { DiffLine(kind: .removed, text: $0) } + b.map { DiffLine(kind: .added, text: $0) }
        }
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var result: [DiffLine] = []
        var i = 0, j = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] {
                result.append(DiffLine(kind: .unchanged, text: a[i])); i += 1; j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                result.append(DiffLine(kind: .removed, text: a[i])); i += 1
            } else {
                result.append(DiffLine(kind: .added, text: b[j])); j += 1
            }
        }
        result += a[i...].map { DiffLine(kind: .removed, text: $0) }
        result += b[j...].map { DiffLine(kind: .added, text: $0) }
        return result
    }

    public static func counts(_ lines: [DiffLine]) -> (added: Int, removed: Int) {
        (lines.filter { $0.kind == .added }.count, lines.filter { $0.kind == .removed }.count)
    }
}
