# Visual QA — Aurora chat workspace (2026-11-17)

**How these were made:** a QA harness compiled the app's real `App/` and `Sources/` SwiftUI code with Xcode 27.3 (Swift 6.4.4, MacOSX27.3.sdk). It hosted `StudioRootView`, `ExpandedOutputView` and `BrowserWorkspace` in real `NSWindow`s and drove them with real activity:
- live publisher feeds;
- real thumbnails;
- the on-device Apple Intelligence model;
- real Ollama-unavailable errors and real cancellation.

Each window was rendered to an image from inside the process (`NSView.cacheDisplay`).

**These are not screen captures of `PromptStudio.app`.** Screen Recording permission was not granted to the agent session. Limits of in-process capture:
- **The sidebar list region renders black.** It is composited by the window server. The list itself was verified to have 6 visible rows by reading the view tree.
- **WKWebView content beyond the first paint may be missing.**
- **Prominent buttons look inactive**, because the harness window was not the active app.

Real screenshots of the running app are still an open item: grant Screen Recording, then capture.

| File | State | Real data shown |
|---|---|---|
| 02b-home-deepmind-thumbnails | Home with publisher thumbnails | Google DeepMind Media RSS images (the only built-in feed with per-item images); publisher marks elsewhere |
| 03-home-news-1020x690 | Home at the minimum design size | Live feed metadata |
| 06-version1-preview | Chat and artifact, Version 1 | On-device Apple Intelligence output, 0 preservation warnings |
| 08-followup-proposal | A follow-up proposes Version 2 | Apply / Discard / Compare; the validator flagged a URL the model altered |
| 09-compare-versions | Line diff, v1 → v2 | Shows the model dropping `.com` from the reference URL |
| 12-browser-open-1450x880 | The globe opens the browser left of chat | Canonical webkit.org article opened from a Home headline; sidebar auto-collapsed |
| 13-browser-open-1020x690 | Narrow window | Preview becomes a one-click rail instead of squeezing three panes |
| 14-wide-multipane-1900x1000 | Wide window | Sidebar, browser, chat and artifact side by side |
| 15-artifact-expanded | Focus mode on the artifact | Tables (`<br>` shown as line breaks), code spans, links, lists |
| 19-generation-failed | Qwen selected, Ollama not running | Real error text; draft restored; composer status dot |
| 20-canceled | Cancel during an Apple generation | "Generation canceled. Your message is back in the composer." |
| 22-saved-offline | Saved filter with news off | Cached, bookmarked story; decoded `<model>` entity |

The full-resolution set of 23 states, including pop-out windows, source mode, Sources and the empty and generating states, was produced in the agent's scratch folder and is not committed.
