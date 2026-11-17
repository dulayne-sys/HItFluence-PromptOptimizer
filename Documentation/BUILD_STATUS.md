# Build and validation status — 2026-11-17 (owner's Mac, Xcode 27.3 beta)

**Environment:** Apple Silicon Mac, macOS 27.3 (26C5035r). Xcode 27.3 beta (27C5035i) at `/Applications/Xcode-27.3.app`, Swift 6.4.4, MacOSX27.3.sdk. Note: `xcode-select` on this Mac points at `Xcode-beta.app` (27.2), so builds pin `DEVELOPER_DIR=/Applications/Xcode-27.3.app/Contents/Developer`.

| Area | Status | Evidence |
|---|---|---|
| Xcode 27.3 app build (`PromptStudio`, Debug, My Mac) | **Passed** | First macOS compile of Aurora: **0 errors, 0 warnings** against MacOSX27.3.sdk, with Swift 6 strict concurrency (after the fixes below) |
| Core prompt rules, postprocessor and validation | **Passed** | `swift test` on Swift 6.4.4: 9 tests, 0 failures |
| App launch (ad-hoc signed) | **Passed** | Runs with the App Sandbox, network-client and user-selected-file entitlements. No crash reports, no logged errors or faults, and no sandbox denials |
| Apple Foundation Models (on-device) | **Passed** | Harness running the app's `AppleModelClient`: "Ready on device", 8192-token context, live rewrite in about 3.2 s that kept every literal; over-long prompts get a clear token-count message; cancel is recognized |
| Ollama (local) | **Partial** | The offline error message and cancel behavior were checked against a fake slow local server. Ollama is not installed, so live Qwen and Glimmer output is untested |
| WebKit HTTPS-only policy | **Passed** | The real `BrowserSession` loads HTTPS pages; `http:` and `file:` navigations started by page script are blocked; the `visit()` guard rejects `http:` |
| News feeds (all 10 built-in) | **Passed** | Live fetch with the app's request settings plus `NewsFeedParser`: all return HTTP 200 and parse 10–50 items; every item is dated after the date fix |
| Brand assets | **Created** | AppIcon set present; the owner's approved production mascot is not imported |
| Visual UI, accessibility, screenshots | **Not run** | This agent session had no Screen Recording or Accessibility permission. Needs the owner's hands-on review (see `UI_BLUEPRINT.md` acceptance checks) |
| Team signing, hardened runtime, history and news-cache persistence across relaunch | **Not run** | Ad-hoc builds disable hardened runtime |

## Fixes made during the Xcode 27.3 build-out

1. **`NewsFeedParser.swift` would not compile on macOS:** it imported the Linux-only `FoundationXML`. The import is now conditional; `XMLParser` comes from Foundation on Apple platforms.
2. **HTTPS-only browser policy was never enforced** (`BrowserWorkspace.swift`). The `decidePolicyFor` delegate signature "nearly matched" the SDK, which marks the handler `@MainActor`, so WebKit never called it. It is replaced with the SDK's async form, and the result was verified at runtime.
3. **Apple Developer News stories had no dates:** that feed uses RFC 822 zone abbreviations (`PDT`), which the date patterns did not accept. Added `zzz` patterns; 50 of 50 items are now dated.
4. **Ollama cancel was reported as a failure:** URLSession reports cancellation as `URLError(.cancelled)`, and `LocalOllamaClient` wrapped it as a connection error. Added `GenerationCancellation.isCancellation(_:)` to the core, with a test; `LocalOllamaClient` and `StudioModel` use it.
5. **False "missing literal" warnings on most prompts with paths:** the path pattern swallowed trailing words and matched inside URLs. It is fixed, with a regression test built from live on-device output.
6. **macOS 27 FoundationModels:** `LanguageModelSession.GenerationError` is deprecated. `AppleModelClient` maps the new `LanguageModelError.contextSizeExceeded` to "too long (X of Y tokens); shorten it or select a local Qwen or Glimmer model". There is still no silent fallback.

## 27.3 SDK notes

- FoundationModels 27.2 → 27.3 only adds APIs (`DynamicInstructions.Group`, `@SessionState`, `@SessionBinding`, keyed `@Guide`); nothing the app uses changed.
- Available but unused: `SystemLanguageModel.contextSize`, `tokenCount(for:)` and `supportsLocale(_:)`. The SDK also exposes `PrivateCloudComputeLanguageModel`; the app intentionally does not use it.

## Reproduce

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.3.app/Contents/Developer
swift test
./Scripts/check-macos-build.sh
```
