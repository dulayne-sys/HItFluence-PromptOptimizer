# Xcode 27.3 beta on-device handoff

You are working in the standalone `dulayne-sys/HItFluence-PromptOptimizer` repository. The user approved implementing the source and Aurora UI. **Do not modify HitCode or HitTree.**

1. Open `PromptStudio.xcodeproj` in Xcode 27.3 beta, select `PromptStudio / My Mac`. Confirm the active Xcode's SDK and toolchain.
2. If HitTree's MCP plugin is connected, call `search_docs`, `read_doc` and `check_symbol` to verify the live FoundationModels, SwiftUI, WebKit, AppKit, SwiftData and window-scene APIs used here. Use the actual Xcode MCP bridge to inspect, build, run and capture compiler diagnostics; do not assume bridge access exists in an unrelated chat session.
3. Run `BuildProject`, then focused app tests and the Swift package tests. Make bounded compiler fixes in this repository. Preserve native UI and offline model restrictions.
4. Test all four destinations: Home, Optimize, Browser, Sources. Verify news is off until opted in, RSS/Atom sources show factual metadata, feed failure states, and cache survives relaunch.
5. Test two output expansion mechanisms: expand in current window and separate WindowGroup pop-out; test independent WebKit pop-out and HTTPS-only navigation.
6. Launch an eligible Apple Intelligence on-device model, and test the in-app Qwen models (bundled Core AI and folder MLX); Glimmer only once its weights exist. Missing models must show truthful errors; no fallback to cloud.
7. Capture **actual app screenshots** at 1450×880 and 1020×690, check keyboard and VoiceOver behavior, Reduce Motion, sign app with owner's team, and record built binary identity. Do not call conceptual layouts production screenshots.
8. Compare the included newly generated metallic `[#]` icon and vector SwiftUI mark with the owner's final approved mascot asset, then replace if provided. This project does **not** claim to include an original unrecovered high-resolution mascot file.
9. Commit any verified compiler and UI fixes on a new branch, and report build/test results and exact changes. Do not silently merge unverified patches.

Status from build environment: 7/7 portable Swift tests passed, parser RSS+Atom fixtures passed, Swift parser passed. macOS compile and runtime QA **remain pending**.
