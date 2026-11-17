import AppKit
import Observation
import SwiftUI
import WebKit

/// One private (non-persistent) WebKit session per window. It lives as long as the window, so hiding and
/// re-showing the browser pane keeps the page, scroll position and back/forward history.
/// Page content is never read by the app or sent to any model.
@MainActor @Observable final class BrowserSession {
    var address = ""
    var pageTitle = ""
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var hasPage = false
    var notice: String?
    var errorMessage: String?
    private(set) var currentURL: URL?
    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var navigationObserver: BrowserNavigationObserver?

    init(initialURL: URL? = nil) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        let observer = BrowserNavigationObserver()
        navigationObserver = observer
        observer.stateChanged = { [weak self] webView in self?.sync(from: webView) }
        observer.failed = { [weak self] error in self?.handle(error) }
        observer.blocked = { [weak self] url in
            self?.notice = "Blocked a \(url?.scheme ?? "non-web") link. This browser opens HTTPS pages only."
        }
        webView.navigationDelegate = observer
        if let initialURL { visit(initialURL) }
    }

    func visit(_ url: URL) {
        guard url.scheme?.lowercased() == "https", url.host != nil else {
            notice = "The in-app browser accepts HTTPS links only."
            return
        }
        notice = nil
        errorMessage = nil
        hasPage = true
        address = url.absoluteString
        webView.load(URLRequest(url: url))
        sync(from: webView)
    }

    func visitAddress() {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let normalized = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: normalized) else {
            notice = "Enter a valid HTTPS address."
            return
        }
        visit(url)
    }

    func back() { webView.goBack() }
    func forward() { webView.goForward() }
    func reloadOrStop() {
        if isLoading { webView.stopLoading() } else { webView.reload() }
    }

    func openExternally() {
        if let url = webView.url, url.scheme?.lowercased() == "https" { NSWorkspace.shared.open(url) }
    }

    fileprivate func sync(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        if let url = webView.url {
            currentURL = url
            address = url.absoluteString
            errorMessage = nil
        }
        pageTitle = webView.title ?? ""
    }

    fileprivate func handle(_ error: Error) {
        sync(from: webView)
        let nsError = error as NSError
        // A cancelled load (new navigation, Stop) or a navigation we blocked by policy is not a page error.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        errorMessage = nsError.localizedDescription
    }
}

@MainActor private final class BrowserNavigationObserver: NSObject, WKNavigationDelegate {
    var stateChanged: ((WKWebView) -> Void)?
    var failed: ((Error) -> Void)?
    var blocked: ((URL?) -> Void)?

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        stateChanged?(webView)
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        stateChanged?(webView)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        stateChanged?(webView)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failed?(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed?(error)
    }
    // Must match the SDK exactly (async form of decidePolicyForNavigationAction); a near-miss
    // signature is silently never called, which would leave the HTTPS-only policy unenforced.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        if scheme == "https" || scheme == "about" { return .allow }
        blocked?(navigationAction.request.url)
        return .cancel
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let session: BrowserSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

/// The browser panel used on the left of the workspace and in the pop-out window.
struct BrowserPane: View {
    @Bindable var session: BrowserSession
    var isFocused = false
    var popout = false
    var onToggleFocus: () -> Void = {}
    var onClose: (() -> Void)?
    var onPopOut: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(HFBrand.separator).frame(height: 1)
            navigationBar
            if let message = session.errorMessage ?? session.notice {
                HStack(spacing: 8) {
                    Image(systemName: session.errorMessage == nil ? "hand.raised" : "exclamationmark.triangle")
                    Text(message).lineLimit(2)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark") {
                        session.notice = nil
                        session.errorMessage = nil
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
                .font(.caption)
                .foregroundStyle(HFBrand.coral)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(HFBrand.coral.opacity(0.08))
            }
            if session.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }
            if session.hasPage {
                BrowserWebView(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(session.pageTitle.isEmpty ? "Web page" : session.pageTitle)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 38, weight: .thin))
                        .foregroundStyle(HFBrand.periwinkle)
                    Text("Read beside your prompt")
                        .font(.title3.weight(.semibold))
                    Text("Open a story from Home, or type an HTTPS address. Pages stay private and are never sent to a model.")
                        .font(.subheadline)
                        .foregroundStyle(HFBrand.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 6) {
                Label("Private session · not shared with AI", systemImage: "lock.shield")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(HFBrand.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(HFBrand.editor.opacity(0.94))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(HFBrand.periwinkle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.pageTitle.isEmpty ? "Browser" : session.pageTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(session.currentURL?.host() ?? "No page open")
                    .font(.caption)
                    .foregroundStyle(HFBrand.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if !popout {
                Button(isFocused ? "Restore Layout" : "Expand",
                       systemImage: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                       action: onToggleFocus)
                    .help(isFocused ? "Restore the workspace panels" : "Expand the browser to fill the window")
                if let onPopOut {
                    Button("Pop Out", systemImage: "macwindow.on.rectangle", action: onPopOut)
                        .help("Open this page in its own browser window")
                }
            }
            Button("Open in Default Browser", systemImage: "arrow.up.right.square") { session.openExternally() }
                .disabled(session.currentURL == nil)
                .help("Open this page in your default browser")
            if let onClose {
                Button("Close Browser", systemImage: "xmark", action: onClose)
                    .help("Hide the browser (⇧⌘B). The page stays loaded.")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            Button("Back", systemImage: "chevron.left") { session.back() }
                .disabled(!session.canGoBack)
            Button("Forward", systemImage: "chevron.right") { session.forward() }
                .disabled(!session.canGoForward)
            Button(session.isLoading ? "Stop" : "Reload", systemImage: session.isLoading ? "xmark" : "arrow.clockwise") {
                session.reloadOrStop()
            }
            .disabled(!session.hasPage)
            TextField("HTTPS address", text: $session.address)
                .textFieldStyle(.roundedBorder)
                .onSubmit { session.visitAddress() }
                .accessibilityLabel("Browser address")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// The independent browser window ("Pop Out"): its own private session, opened at the current page.
struct BrowserWorkspace: View {
    @Bindable var model: StudioModel
    var popout = true
    @State private var session: BrowserSession?

    var body: some View {
        Group {
            if let session {
                BrowserPane(session: session, popout: popout)
            } else {
                Color.clear
            }
        }
        .background(HFAuroraBackground())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .navigationTitle(session?.pageTitle.isEmpty == false ? session!.pageTitle : "Web Browser")
        .onAppear {
            if session == nil { session = BrowserSession(initialURL: model.lastBrowserURL) }
        }
    }
}
