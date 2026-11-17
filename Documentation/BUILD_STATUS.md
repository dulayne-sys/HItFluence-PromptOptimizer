# Build and validation status — 2026-11-17 (owner's Mac, Xcode 27.3 beta)

## In-app local models (branch `feature/in-app-local-models`)

Qwen runs **inside Prompt Studio**, with no Ollama or other server. Core AI bundles go through FoundationModels' `LanguageModelSession`; MLX weights go through mlx-swift-lm's `ChatSession`. The package pins match HitSwap exactly: `apple/coreai-models` 1.0.0, `ml-explore/mlx-swift-lm` 3.32.3 (mlx-swift 0.32.3), `huggingface/swift-transformers` 1.3.5.

| Check | Result |
|---|---|
| Xcode 27.3 build, Debug and Release | **Passed.** 0 errors and 0 warnings in app code (MLX's own Metal headers emit C++17 notices), MacOSX27.3.sdk |
| Unit tests | **48 passed, 0 failed.** Adds the local-model catalog (Core AI/MLX detection, TTS skipped, too-large, unsupported, missing files, Glimmer, bundled de-duplication) and `<think>` stripping |
| Bundled model | The "Bundle Core AI model" build step copies `~/Models/CoreAI/qwen3-1.7b` (943 MB) into `Contents/Resources/Models`. The app is 1.0 GB |
| **Sandboxed app, bundled Qwen3-1.7B (Core AI)** | **Passed** (`-PromptStudioSelfTest`, Debug only): 22.9 s on first use (compile cached in the app container), **11.5 s warm** |
| Qwen3-1.7B from the models folder (Core AI) | **Passed:** 22.4 s, all literals preserved |
| **Qwen2.5-14B-Instruct-4bit (MLX)** | **Passed:** 38.2 s including loading 8.3 GB of weights on the 16 GB M4; all literals preserved |
| Qwen3.6-27B / 35B (backup folder) | **Refused before loading:** "Needs about 11.77 GB of memory; this Mac has 16 GB" |
| Cancel during a local generation | **Passed:** `CancellationError` |
| UI with real local generations | Captured: model menu, real "Loading … into memory · Ns" phase, a 14B follow-up proposal, Settings › Local models |
| Muse Glimmer | **Not on disk.** The runtime supports `muse_glimmer` (MLX vision); the app shows "not installed" |
| Folder access in the sandbox | The picker is implemented with an app-scoped bookmark, read-only. **Not yet clicked through by hand**; the harness supplied the folder directly |

Models are listed only if they're found on disk. Each is checked against 60% of physical memory, using weights plus about 15% overhead, and only one model is kept in memory at a time.

## Aurora chat workspace (branch `feature/aurora-chat-workspace`)

| Area | Status | Evidence |
|---|---|---|
| Xcode 27.3 build, Debug and Release | **Passed** | `xcodebuild` with `DEVELOPER_DIR` set to Xcode 27.3, MacOSX27.3.sdk: **0 errors, 0 warnings** in both configurations |
| Xcode MCP bridge | **Passed** | `BuildProject` succeeded. `RunAllTests` (PromptStudioCore): **40 passed, 0 failed**. This session's bridge ran Xcode 27.2; the 27.3 bridge is pinned for new sessions |
| Unit tests (Swift 6.4.4) | **Passed** | `swift test`: 40 tests, 0 failures: conversation state, follow-up exact-value preservation, Markdown fidelity, version diff, feed images, entity decoding, thumbnail-cache expiry and eviction, workspace layout and navigation |
| App launch, ad-hoc signed 27.3 build | **Passed** | Running, with no crash reports, logged errors or faults, or sandbox denials |
| Visual QA, 23 states | **Passed with limits** | Real views driven by real activity; see `QA/2026-11-17/README.md`. In-process captures, **not screen captures**: the sidebar list pixels and the full WKWebView content can't be captured this way |
| Real screenshots of `PromptStudio.app` | **Not run** | Needs Screen Recording permission for the agent |
| Xcode preview (`RenderPreview`) | **Failed (tooling)** | The 27.2 preview runtime crashed in `List.init` on macOS 27.3. The same view runs in the 27.3 app and in the harness. Retry with the 27.3 bridge |
| VoiceOver, keyboard focus, Reduce Motion (hands-on) | **Not run** | Labels, adjustable dividers, menu shortcuts and Reduce Motion paths are implemented but not exercised with assistive technology |
| Light appearance | **N/A** | The Aurora brand system is dark-only (`preferredColorScheme(.dark)`) |
| Live Qwen / Glimmer output | **Not run** | Ollama is not installed; the unavailable and failed states were verified |

### Fixes found by live QA

- Feed summaries showed numeric entities (`&#60;model&#62;`). They are now decoded, with a test.
- Models write `<br>` in GFM table cells. It is shown as a line break without changing the stored Markdown, with a test.
- The Qwen error said "No matching local model" when Ollama wasn't running. It now re-checks at send time and reports "nothing is listening at 127.0.0.1:11434".
- The Home lead layout always fell back to stacked because `ViewThatFits` measured the headline's ideal width. Fixed.
- Apply buttons were low-contrast when the window was inactive.
- The composer status pill truncated in the narrow chat column; it is now a status dot with a tooltip.
- Previews broke the Release build. The generated project now defines `DEBUG` for Debug, and previews are wrapped in `#if DEBUG`.

### Commands

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.3.app/Contents/Developer
swift test
xcodebuild -project PromptStudio.xcodeproj -scheme PromptStudio -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
python3 Documentation/create_project.py           # regenerate the project (icons untouched)
python3 Documentation/create_project.py --icons   # also re-render icons (needs Pillow)
```

## Build-out (commit 26e4b95)

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
