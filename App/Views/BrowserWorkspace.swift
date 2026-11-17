import AppKit
import Observation
import SwiftUI
import WebKit

/// An independent, ephemeral reader. No webpage text is sent to an AI provider.
@MainActor @Observable final class BrowserSession {
    var address = ""
    var pageTitle = "Web Preview"
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var message: String?
    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var navigationObserver: BrowserNavigationObserver?

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        let observer = BrowserNavigationObserver()
        navigationObserver = observer
        observer.stateChanged = { [weak self] webView in
            self?.sync(from: webView)
        }
        webView.navigationDelegate = observer
    }

    func visit(_ url: URL) {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            message = "The in-app browser accepts HTTPS links only."
            return
        }
        message = nil
        address = url.absoluteString
        webView.load(URLRequest(url: url))
        sync(from: webView)
    }

    func visitAddress() {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let normalized = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: normalized) else {
            message = "Enter a valid HTTPS URL."
            return
        }
        visit(url)
    }

    func back() { webView.goBack() }
    func forward() { webView.goForward() }
    func reload() { webView.reload() }
    func external() {
        if let url = webView.url, url.scheme?.lowercased() == "https" {
            NSWorkspace.shared.open(url)
        }
    }

    func sync(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        if let url = webView.url { address = url.absoluteString }
        pageTitle = webView.title?.isEmpty == false ? (webView.title ?? "Web Preview") : "Web Preview"
    }
}

@MainActor private final class BrowserNavigationObserver: NSObject, WKNavigationDelegate {
    var stateChanged: ((WKWebView) -> Void)?

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        stateChanged?(webView)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        stateChanged?(webView)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        stateChanged?(webView)
    }
    // Must match the SDK exactly (async form of decidePolicyForNavigationAction); a near-miss
    // signature is silently never called, which would leave the HTTPS-only policy unenforced.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased() else { return .cancel }
        return scheme == "https" || scheme == "about" ? .allow : .cancel
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let session: BrowserSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) { }
}

struct BrowserWorkspace: View {
    @Bindable var model: StudioModel
    @Environment(\.openWindow) private var openWindow
    @State private var browser = BrowserSession()
    var popout = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(HFBrand.periwinkle)
                Text("BROWSER")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                Spacer()
                if !popout {
                    Button(model.browserExpanded ? "Restore" : "Expand",
                           systemImage: model.browserExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                        model.browserExpanded.toggle()
                    }
                    .buttonStyle(.borderless)
                    Button("Pop Out", systemImage: "macwindow.on.rectangle") { openWindow(id: "browser") }
                        .buttonStyle(.borderless)
                }
                Button("Open Externally", systemImage: "arrow.up.right.square") { browser.external() }
                    .buttonStyle(.borderless)
            }
            .padding(16)
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            HStack(spacing: 10) {
                Button("Back", systemImage: "chevron.left") { browser.back() }
                    .disabled(!browser.canGoBack)
                Button("Forward", systemImage: "chevron.right") { browser.forward() }
                    .disabled(!browser.canGoForward)
                Button("Reload", systemImage: "arrow.clockwise") { browser.reload() }
                TextField("HTTPS address", text: $browser.address)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { browser.visitAddress() }
                    .accessibilityLabel("Browser address")
                Button("Go") { browser.visitAddress() }
                    .buttonStyle(.borderedProminent)
                    .tint(HFBrand.blue)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(12)
            if let message = browser.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(HFBrand.coral)
                    .padding(.horizontal, 16)
            }
            if browser.isLoading { ProgressView().controlSize(.mini).padding(.vertical, 4) }
            BrowserWebView(session: browser)
                .background(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(browser.pageTitle).lineLimit(1)
                Spacer()
                Label("Ephemeral browser · No AI transmission", systemImage: "lock.shield")
            }
            .font(.caption)
            .foregroundStyle(HFBrand.muted)
            .padding(12)
        }
        .background(HFBrand.editor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(HFBrand.separator))
        .padding(popout ? 12 : 20)
        .onAppear { if let url = model.browserURL { browser.visit(url) } }
        .onChange(of: model.browserURL) { _, new in
            if let new { browser.visit(new) }
        }
    }
}
