import SwiftUI

/// [browser] | [chat] | [artifact], driven by `WorkspaceLayout.Resolved`. Side panes have stored widths
/// adjustable by dragging; chat is the flexible column. Panes that don't fit collapse to a one-click rail.
struct WorkspaceSplitView<Browser: View, Chat: View, Artifact: View>: View {
    @Binding var layout: WorkspaceLayout
    let resolved: WorkspaceLayout.Resolved
    @ViewBuilder var browser: () -> Browser
    @ViewBuilder var chat: () -> Chat
    @ViewBuilder var artifact: () -> Artifact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFocusMode: Bool { layout.focus != nil }

    var body: some View {
        HStack(spacing: 0) {
            switch resolved.browser {
            case .visible(let width):
                browser()
                    .frame(width: isFocusMode ? nil : width)
                    .frame(maxWidth: isFocusMode ? .infinity : nil)
                if !isFocusMode {
                    PaneResizeHandle(label: "Resize browser", width: width, direction: 1) { layout.resize(.browser, to: $0) }
                }
            case .rail:
                PaneRail(title: "Browser", symbol: "globe") { animate { layout.reveal(.browser) } }
                PaneSeparator()
            case .hidden:
                EmptyView()
            }

            if resolved.chat {
                chat()
                    .frame(minWidth: 320, maxWidth: .infinity)
            }

            switch resolved.artifact {
            case .visible(let width):
                if !isFocusMode {
                    PaneResizeHandle(label: "Resize artifact preview", width: width, direction: -1) { layout.resize(.artifact, to: $0) }
                }
                artifact()
                    .frame(width: isFocusMode ? nil : width)
                    .frame(maxWidth: isFocusMode ? .infinity : nil)
            case .rail:
                PaneSeparator()
                PaneRail(title: "Preview", symbol: "doc.richtext") { animate { layout.reveal(.artifact) } }
            case .hidden:
                EmptyView()
            }
        }
    }

    private func animate(_ change: () -> Void) {
        if reduceMotion { change() } else { withAnimation(.snappy(duration: 0.25)) { change() } }
    }
}

/// Draggable divider. `direction` is +1 when dragging right widens the pane (browser on the left), -1 otherwise.
private struct PaneResizeHandle: View {
    let label: String
    let width: Double
    let direction: Double
    let onResize: (Double) -> Void
    @State private var dragStartWidth: Double?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: WorkspaceLayout.dividerWidth)
            .overlay { Rectangle().fill(HFBrand.separator).frame(width: 1) }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = width }
                        onResize(start + direction * value.translation.width)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(width)) points wide")
            .accessibilityAdjustableAction { adjustment in
                switch adjustment {
                case .increment: onResize(width + 40)
                case .decrement: onResize(width - 40)
                @unknown default: break
                }
            }
    }
}

private struct PaneSeparator: View {
    var body: some View {
        Rectangle().fill(HFBrand.separator).frame(width: 1)
    }
}

/// A collapsed pane: one click brings it back and makes it the pane that keeps its width.
private struct PaneRail: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 70)
                Spacer()
            }
            .padding(.top, 16)
            .frame(width: WorkspaceLayout.railWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(HFBrand.periwinkle)
        .background(HFBrand.panel.opacity(0.55))
        .help("Show \(title)")
        .accessibilityLabel("Show \(title)")
    }
}
