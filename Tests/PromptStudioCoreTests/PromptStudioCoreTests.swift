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

    func testPathsStopAtTrailingWordsAndIgnoreURLInternals() {
        // Reproduces a false "missing" warning seen with live Apple Intelligence output on macOS 27.3.
        let input = "fix /Users/me/Code/App/Editor.swift before 2026-12-01, see https://developer.apple.com/documentation/foundationmodels and /Volumes/Test Drive/Code/Main.swift now"
        let values = PromptValidator.collectProtectedStrings(input)
        XCTAssertTrue(values.contains("/Users/me/Code/App/Editor.swift"))
        XCTAssertTrue(values.contains("/Volumes/Test Drive/Code/Main.swift"))
        XCTAssertFalse(values.contains { $0.hasSuffix(" before") || $0.contains(" before 2026") || $0.hasSuffix(" now") })
        XCTAssertFalse(values.contains { $0.hasPrefix("/developer.apple.com") || $0.hasPrefix("//") })

        let faithful = """
        1. Fix the build in `/Users/me/Code/App/Editor.swift` before 2026-12-01.
        2. Refer to: https://developer.apple.com/documentation/foundationmodels.
        3. Then update /Volumes/Test Drive/Code/Main.swift.
        """
        XCTAssertEqual(PromptValidator.inspect(source: input, generated: faithful).missingExactStrings, [])
    }

    func testCancellationIsRecognizedFromTaskAndURLSession() {
        XCTAssertTrue(GenerationCancellation.isCancellation(CancellationError()))
        XCTAssertTrue(GenerationCancellation.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(GenerationCancellation.isCancellation(URLError(.cannotConnectToHost)))
        XCTAssertFalse(GenerationCancellation.isCancellation(CocoaError(.fileNoSuchFile)))
    }

    func testInputEnvelopedAsData() {
        let prompt = PromptRules.userEnvelope("Build something")
        XCTAssertTrue(prompt.contains("<original_request>"))
        XCTAssertTrue(prompt.contains("Build something"))
    }
}
