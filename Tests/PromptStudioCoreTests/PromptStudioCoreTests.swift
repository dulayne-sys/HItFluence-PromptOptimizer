import XCTest
@testable import PromptStudioCore

final class PromptStudioCoreTests: XCTestCase {
    func testOptimizerIncludesCriticalRules() {
        let instructions = PromptRules.instructions(profile: .developer, detail: .complete)
        XCTAssertTrue(instructions.contains("NOT perform"))
        XCTAssertTrue(instructions.contains("Never invent"))
        XCTAssertTrue(instructions.contains("Markdown"))
    }

    func testProfileVariations() {
        let developer = PromptRules.instructions(profile: .developer, detail: .complete)
        let creative = PromptRules.instructions(profile: .creative, detail: .complete)
        XCTAssertTrue(developer.contains("code agents"))
        XCTAssertTrue(creative.contains("creative agents"))
        XCTAssertNotEqual(developer, creative)
    }

    func testProtectedLiteralsFlagged() {
        let input = "Review /Volumes/Test Drive/Code/Editor.swift and https://developer.apple.com on 2026-11-13."
        let report = PromptValidator.inspect(source: input, generated: "Review Editor")
        XCTAssertTrue(report.hasWarnings)
        XCTAssertTrue(report.missingExactStrings.contains("https://developer.apple.com"))
        XCTAssertTrue(report.missingExactStrings.contains("2026-11-13"))
    }

    func testVerbatimAppendixPreservesEmbeddedCodeFence() {
        let original = "Please keep this ```example``` exactly."
        let output = PromptPostProcessor.render("# Improved\n\nFollow instructions", source: original, includeOriginal: true)
        XCTAssertTrue(output.contains(original))
        XCTAssertTrue(output.contains("````text"))
        XCTAssertTrue(output.contains("## Original Request (Verbatim)"))
    }

    func testEmptyResponseNotPresentedAsSuccess() {
        XCTAssertEqual(PromptPostProcessor.render("\n\t", source: "test", includeOriginal: true), "")
        XCTAssertTrue(PromptValidator.inspect(source: "test", generated: "").hasWarnings)
    }

    func testKnownLocalModelTagsAreDiscovered() {
        let tags = ["qwen2.5-coder:14b", "muse-glimmer:30b-mlx", "qwen3:8b-instruct", "other:latest"]
        let qwen = LocalModelDiscovery.suitableTags(for: .qwen, among: tags)
        let glimmer = LocalModelDiscovery.suitableTags(for: .glimmer, among: tags)
        XCTAssertEqual(qwen.first, "qwen3:8b-instruct")
        XCTAssertEqual(glimmer, ["muse-glimmer:30b-mlx"])
    }

    func testInputEnvelopedAsData() {
        let prompt = PromptRules.userEnvelope("Build something")
        XCTAssertTrue(prompt.contains("<original_request>"))
        XCTAssertTrue(prompt.contains("Build something"))
    }
}
