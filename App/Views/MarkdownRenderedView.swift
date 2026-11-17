import AppKit
import SwiftUI

/// Renders an artifact with block structure from `MarkdownDocument` (headings, lists, checklists, quotes,
/// fenced code, tables, separators) and inline styling from Foundation's `AttributedString(markdown:)`.
struct MarkdownRenderedView: View {
    let markdown: String
    var onOpenLink: (URL) -> Void = { NSWorkspace.shared.open($0) }

    var body: some View {
        let blocks = MarkdownDocument.parse(markdown)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            onOpenLink(url)
            return .handled
        })
    }
}

enum MarkdownInline {
    static func attributed(_ text: String, base: Font = .body) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                              failurePolicy: .returnPartiallyParsedIfPossible)
        var result = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        for run in result.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                result[run.range].font = .system(.body, design: .monospaced)
                result[run.range].foregroundColor = HFBrand.mint
                result[run.range].backgroundColor = HFBrand.ink.opacity(0.55)
            }
            if run.link != nil {
                result[run.range].foregroundColor = HFBrand.periwinkle
                result[run.range].underlineStyle = .single
            }
        }
        return result
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownInline.attributed(text))
                .font(Self.headingFont(level))
                .foregroundStyle(level <= 2 ? Color.white : HFBrand.lavender)
                .padding(.top, level <= 2 ? 8 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(MarkdownInline.attributed(text))
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items):
            MarkdownListView(items: items)
        case .quote(let inner):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(HFBrand.periwinkle.opacity(0.7))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(inner.enumerated()), id: \.offset) { _, nested in
                        AnyView(MarkdownBlockView(block: nested))
                    }
                }
                .foregroundStyle(HFBrand.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quote")
        case .code(let language, let content):
            MarkdownCodeBlock(language: language, content: content)
        case .table(let header, let alignments, let rows):
            MarkdownTableView(header: header, alignments: alignments, rows: rows)
        case .thematicBreak:
            Rectangle()
                .fill(HFBrand.separator)
                .frame(height: 1)
                .padding(.vertical, 6)
                .accessibilityHidden(true)
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(.title, design: .rounded, weight: .bold)
        case 2: .title2.weight(.semibold)
        case 3: .title3.weight(.semibold)
        default: .headline
        }
    }
}

private struct MarkdownListView: View {
    let items: [MarkdownListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    marker(for: item)
                        .frame(minWidth: 20, alignment: .trailing)
                    Text(MarkdownInline.attributed(item.text))
                        .foregroundStyle(item.checked == true ? HFBrand.muted : Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, CGFloat(item.level) * 22)
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private func marker(for item: MarkdownListItem) -> some View {
        if let checked = item.checked {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundStyle(checked ? HFBrand.mint : HFBrand.muted)
                .accessibilityLabel(checked ? "Completed" : "Not completed")
        } else if let ordinal = item.ordinal {
            Text("\(ordinal).")
                .monospacedDigit()
                .foregroundStyle(HFBrand.periwinkle)
        } else {
            Text(item.level == 0 ? "•" : "◦")
                .foregroundStyle(HFBrand.periwinkle)
                .accessibilityHidden(true)
        }
    }
}

private struct MarkdownCodeBlock: View {
    let language: String?
    let content: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text((language ?? "code").uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(HFBrand.muted)
                Spacer()
                Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    MacActions.copy(content)
                    copied = true
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .help("Copy this code block")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            ScrollView(.horizontal) {
                Text(content)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(HFBrand.lavender)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
        }
        .background(HFBrand.ink.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HFBrand.separator))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code block\(language.map { ", \($0)" } ?? "")")
    }
}

private struct MarkdownTableView: View {
    let header: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(header.indices, id: \.self) { column in
                        cell(header[column], column: column, isHeader: true, stripe: false)
                    }
                }
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row].indices, id: \.self) { column in
                            cell(rows[row][column], column: column, isHeader: false, stripe: row.isMultiple(of: 2))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HFBrand.separator))
        }
        .accessibilityLabel("Table with \(header.count) columns and \(rows.count) rows")
    }

    private func cell(_ text: String, column: Int, isHeader: Bool, stripe: Bool) -> some View {
        let alignment = column < alignments.count ? alignments[column] : .leading
        return Text(MarkdownInline.attributed(MarkdownDocument.tableCellDisplayText(text)))
            .font(isHeader ? .callout.weight(.semibold) : .callout)
            .multilineTextAlignment(alignment == .center ? .center : alignment == .trailing ? .trailing : .leading)
            .frame(minWidth: 70, maxWidth: 320,
                   alignment: alignment == .center ? .center : alignment == .trailing ? .trailing : .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHeader ? HFBrand.panelRaised : stripe ? HFBrand.panel.opacity(0.45) : Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(HFBrand.separator).frame(height: 1) }
    }
}

/// Line-by-line comparison of two artifact versions.
struct ArtifactDiffView: View {
    let old: ArtifactVersion
    let new: ArtifactVersion

    var body: some View {
        let lines = ArtifactDiff.lines(from: old.markdown, to: new.markdown)
        let counts = ArtifactDiff.counts(lines)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Label("Version \(old.number) → Version \(new.number)", systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("+\(counts.added)").foregroundStyle(HFBrand.mint)
                Text("−\(counts.removed)").foregroundStyle(HFBrand.coral)
            }
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Comparing version \(old.number) to \(new.number): \(counts.added) lines added, \(counts.removed) removed")
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(symbol(line.kind))
                                .frame(width: 12)
                                .foregroundStyle(color(line.kind))
                            Text(line.text.isEmpty ? " " : line.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(line.kind == .unchanged ? Color.clear : color(line.kind).opacity(0.13))
                        .accessibilityLabel("\(word(line.kind)) \(line.text)")
                    }
                }
                .padding(.vertical, 8)
                .textSelection(.enabled)
            }
        }
    }

    private func symbol(_ kind: DiffLine.Kind) -> String {
        switch kind { case .added: "+"; case .removed: "−"; case .unchanged: " " }
    }
    private func color(_ kind: DiffLine.Kind) -> Color {
        switch kind { case .added: HFBrand.mint; case .removed: HFBrand.coral; case .unchanged: HFBrand.muted }
    }
    private func word(_ kind: DiffLine.Kind) -> String {
        switch kind { case .added: "Added:"; case .removed: "Removed:"; case .unchanged: "" }
    }
}
