import Foundation

public enum MarkdownTableAlignment: String, Sendable, Equatable {
    case leading, center, trailing
}

public struct MarkdownListItem: Equatable, Sendable {
    /// Inline Markdown (bold, code, links) for the renderer to style.
    public var text: String
    public var level: Int
    /// Present for ordered items ("3." → 3); nil for bullets.
    public var ordinal: Int?
    /// Present for task items: false for "[ ]", true for "[x]".
    public var checked: Bool?

    public init(text: String, level: Int, ordinal: Int?, checked: Bool?) {
        self.text = text
        self.level = level
        self.ordinal = ordinal
        self.checked = checked
    }
}

public indirect enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([MarkdownListItem])
    case quote([MarkdownBlock])
    case code(language: String?, content: String)
    case table(header: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
    case thematicBreak
}

/// Block-level Markdown structure (CommonMark/GFM subset used by prompts). Inline syntax stays in the text
/// and is styled by the app with Foundation's `AttributedString(markdown:)`, so this never drops characters.
public enum MarkdownDocument {
    public static func parse(_ source: String) -> [MarkdownBlock] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return MarkdownLineParser(lines: normalized.components(separatedBy: "\n")).parse()
    }

    /// Display-only: GFM table cells can't hold real line breaks, so models write `<br>`. Shown as newlines;
    /// the stored Markdown is never changed.
    public static func tableCellDisplayText(_ cell: String) -> String {
        cell.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
    }

    /// All human-readable text in the blocks, used to prove nothing was lost.
    public static func allText(in blocks: [MarkdownBlock]) -> String {
        blocks.map { block in
            switch block {
            case .heading(_, let text), .paragraph(let text): text
            case .list(let items): items.map(\.text).joined(separator: "\n")
            case .quote(let inner): allText(in: inner)
            case .code(_, let content): content
            case .table(let header, _, let rows): ([header] + rows).map { $0.joined(separator: " ") }.joined(separator: "\n")
            case .thematicBreak: ""
            }
        }.joined(separator: "\n")
    }
}

private final class MarkdownLineParser {
    private let lines: [String]
    private var index = 0
    private var blocks: [MarkdownBlock] = []
    private var paragraph: [String] = []

    init(lines: [String]) { self.lines = lines }

    func parse() -> [MarkdownBlock] {
        while index < lines.count {
            let line = lines[index]
            if Self.isBlank(line) {
                flushParagraph(); index += 1
            } else if let fence = Self.fenceOpening(line) {
                flushParagraph(); parseFence(fence)
            } else if let heading = Self.atxHeading(line) {
                flushParagraph(); blocks.append(heading); index += 1
            } else if !paragraph.isEmpty, let level = Self.setextLevel(line) {
                blocks.append(.heading(level: level, text: paragraph.map(Self.trimmed).joined(separator: " ")))
                paragraph = []; index += 1
            } else if Self.isThematicBreak(line) {
                flushParagraph(); blocks.append(.thematicBreak); index += 1
            } else if Self.quoteContent(line) != nil {
                flushParagraph(); parseQuote()
            } else if isTableStart(at: index) {
                flushParagraph(); parseTable()
            } else if Self.listMarker(line) != nil {
                flushParagraph(); parseList()
            } else {
                paragraph.append(Self.trimmed(line)); index += 1
            }
        }
        flushParagraph()
        return blocks
    }

    private func flushParagraph() {
        guard !paragraph.isEmpty else { return }
        blocks.append(.paragraph(paragraph.joined(separator: "\n")))
        paragraph = []
    }

    // MARK: Fenced code

    private struct Fence { let indent: Int; let marker: Character; let length: Int; let info: String }

    private static func fenceOpening(_ line: String) -> Fence? {
        let indent = line.prefix { $0 == " " }.count
        let rest = line.dropFirst(indent)
        guard let marker = rest.first, marker == "`" || marker == "~" else { return nil }
        let length = rest.prefix { $0 == marker }.count
        guard length >= 3 else { return nil }
        let info = rest.dropFirst(length).trimmingCharacters(in: .whitespaces)
        if marker == "`" && info.contains("`") { return nil }
        return Fence(indent: indent, marker: marker, length: length, info: info)
    }

    private func parseFence(_ fence: Fence) {
        index += 1
        var content: [String] = []
        while index < lines.count {
            let line = lines[index]
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.count >= fence.length, stripped.allSatisfy({ $0 == fence.marker }) {
                index += 1
                break
            }
            content.append(Self.removeIndent(line, upTo: fence.indent))
            index += 1
        }
        let language = fence.info.split(separator: " ").first.map(String.init)
        blocks.append(.code(language: language, content: content.joined(separator: "\n")))
    }

    // MARK: Headings and breaks

    private static func atxHeading(_ line: String) -> MarkdownBlock? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let rest = line.dropFirst(indent)
        let level = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let afterHashes = rest.dropFirst(level)
        guard afterHashes.isEmpty || afterHashes.first == " " || afterHashes.first == "\t" else { return nil }
        var text = afterHashes.trimmingCharacters(in: .whitespaces)
        if let range = text.range(of: #"(^|\s)#+$"#, options: .regularExpression) {
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return .heading(level: level, text: text)
    }

    private static func setextLevel(_ line: String) -> Int? {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        guard line.prefix(while: { $0 == " " }).count <= 3, !stripped.isEmpty else { return nil }
        if stripped.allSatisfy({ $0 == "=" }) { return 1 }
        if stripped.allSatisfy({ $0 == "-" }) && stripped.count >= 2 { return 2 }
        return nil
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        guard line.prefix(while: { $0 == " " }).count <= 3 else { return false }
        let compact = line.filter { $0 != " " && $0 != "\t" }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    // MARK: Block quotes

    private static func quoteContent(_ line: String) -> String? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        let rest = line.dropFirst(indent)
        guard rest.first == ">" else { return nil }
        let body = rest.dropFirst()
        return String(body.first == " " ? body.dropFirst() : body)
    }

    private func parseQuote() {
        var inner: [String] = []
        while index < lines.count, let content = Self.quoteContent(lines[index]) {
            inner.append(content)
            index += 1
        }
        blocks.append(.quote(MarkdownLineParser(lines: inner).parse()))
    }

    // MARK: Tables (GFM)

    private func isTableStart(at position: Int) -> Bool {
        guard position + 1 < lines.count, lines[position].contains("|") else { return false }
        return Self.delimiterAlignments(lines[position + 1]) != nil
    }

    private static func delimiterAlignments(_ line: String) -> [MarkdownTableAlignment]? {
        let cells = splitRow(line)
        guard !cells.isEmpty, line.contains("-") else { return nil }
        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let spec = cell.trimmingCharacters(in: .whitespaces)
            let core = spec.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard !core.isEmpty, core.allSatisfy({ $0 == "-" }) else { return nil }
            switch (spec.hasPrefix(":"), spec.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        return alignments
    }

    private static func splitRow(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespaces)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|") && !row.hasSuffix("\\|") { row.removeLast() }
        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in row {
            if escaped {
                current.append(character == "|" ? "|" : "\\\(character)")
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private func parseTable() {
        let header = Self.splitRow(lines[index])
        let alignments = Self.delimiterAlignments(lines[index + 1]) ?? []
        let width = header.count
        index += 2
        var rows: [[String]] = []
        while index < lines.count, !Self.isBlank(lines[index]), lines[index].contains("|") {
            var cells = Self.splitRow(lines[index])
            if cells.count < width { cells += Array(repeating: "", count: width - cells.count) }
            rows.append(Array(cells.prefix(width)))
            index += 1
        }
        let paddedAlignments = Array((alignments + Array(repeating: .leading, count: max(0, width - alignments.count))).prefix(width))
        blocks.append(.table(header: header, alignments: paddedAlignments, rows: rows))
    }

    // MARK: Lists and task lists

    private struct Marker { let indent: Int; let ordinal: Int?; let content: String }

    private static func listMarker(_ line: String) -> Marker? {
        let expanded = line.replacingOccurrences(of: "\t", with: "    ")
        let indent = expanded.prefix { $0 == " " }.count
        let rest = expanded.dropFirst(indent)
        guard let first = rest.first else { return nil }
        if "-*+".contains(first) {
            let after = rest.dropFirst()
            guard after.isEmpty || after.first == " " else { return nil }
            if isThematicBreak(line) { return nil }
            return Marker(indent: indent, ordinal: nil, content: after.trimmingCharacters(in: .whitespaces))
        }
        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard (1...9).contains(digits.count), let ordinal = Int(digits) else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")" else { return nil }
        let after = afterDigits.dropFirst()
        guard after.isEmpty || after.first == " " else { return nil }
        return Marker(indent: indent, ordinal: ordinal, content: after.trimmingCharacters(in: .whitespaces))
    }

    private func parseList() {
        var items: [MarkdownListItem] = []
        var indentStack: [Int] = []
        while index < lines.count {
            let line = lines[index]
            if let marker = Self.listMarker(line) {
                while let top = indentStack.last, marker.indent < top { indentStack.removeLast() }
                if indentStack.isEmpty || marker.indent > indentStack.last! { indentStack.append(marker.indent) }
                var text = marker.content
                var checked: Bool?
                for (box, value) in [("[ ]", false), ("[x]", true), ("[X]", true)] where text == box || text.hasPrefix(box + " ") {
                    checked = value
                    text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                items.append(MarkdownListItem(text: text, level: indentStack.count - 1, ordinal: marker.ordinal, checked: checked))
                index += 1
            } else if Self.isBlank(line) {
                // A blank line continues the list only if another item or indented continuation follows.
                var next = index + 1
                while next < lines.count, Self.isBlank(lines[next]) { next += 1 }
                guard next < lines.count, Self.listMarker(lines[next]) != nil
                        || (lines[next].hasPrefix("  ") && Self.fenceOpening(lines[next]) == nil) else { break }
                index = next
            } else if Self.fenceOpening(line) != nil || Self.atxHeading(line) != nil || Self.isThematicBreak(line)
                        || Self.quoteContent(line) != nil || isTableStart(at: index) {
                break
            } else if !items.isEmpty {
                items[items.count - 1].text += "\n" + Self.trimmed(line)
                index += 1
            } else {
                break
            }
        }
        if !items.isEmpty { blocks.append(.list(items)) }
    }

    // MARK: Helpers

    private static func isBlank(_ line: String) -> Bool { line.allSatisfy { $0 == " " || $0 == "\t" } }
    private static func trimmed(_ line: String) -> String { line.trimmingCharacters(in: .whitespaces) }

    private static func removeIndent(_ line: String, upTo count: Int) -> String {
        let leading = min(count, line.prefix { $0 == " " }.count)
        return String(line.dropFirst(leading))
    }
}
