# Xcode 27.3 beta — verification before release

This is a release gate, not a claim that a build has passed.

1. Confirm `xcodebuild -version` reports the requested Xcode 27.3 beta (27C5020n).
2. In HitTree, use `search_docs` and `check_symbol` for `LanguageModelSession`, `SystemLanguageModel.availability`, `TextEditor`, `MenuBarExtra`, and `NSSavePanel`; verify macOS 27 SDK availability.
3. Compile the PromptStudio scheme in Xcode. Resolve any beta SDK / Swift concurrency errors without changing the prompt-fidelity contract.
4. Select development signing and verify the built binary contains App Sandbox, network client and user-selected file access entitlements.
5. With Apple Intelligence enabled, submit a small prompt. Confirm response, output editing, copy and export.
6. Select the bundled Qwen3 1.7B, then choose your models folder and select Qwen2.5 14B. Confirm it completes with no Internet access. Verify Glimmer only if its local tag is installed.
7. Select a model marked too large or not installed (Glimmer). Confirm an explicit reason and no fallback.
8. Cancel a long generation and confirm state recovers.
9. Test prompts with paths, dates, URLs, inline code and potentially conflicting requirements. Confirm warning display.
10. Disable history, relaunch and verify no history file is persisted. Enable history, generate, relaunch, and confirm records restore. Clear history, then verify deletion.
11. Verify the menu-bar utility and main window share data without unwanted duplicate actions.
12. Test dark appearance, larger text, keyboard navigation, VoiceOver and reduced motion.
13. Run `swift test` for the Foundation-only optimization core.
14. Record exact Xcode build logs, device OS version, model tags, task latency and memory before declaring completion.
