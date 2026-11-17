import XCTest
@testable import PromptStudioCore

// MARK: - Conversation state

final class ConversationStateTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstMessageCreatesInitialRequestAndAcceptedVersion() throws {
        var session = PromptSession(now: t0)
        session.draft = "Fix the build in /Users/me/App/Editor.swift"
        let request = try XCTUnwrap(session.submit(session.draft, now: t0))
        XCTAssertEqual(request.kind, .initial)
        XCTAssertEqual(session.draft, "", "composer clears on send")
        XCTAssertEqual(session.messages.map(\.role), [.user])
        XCTAssertEqual(session.title, "Fix the build in /Users/me/App/Editor.swift")
        XCTAssertNil(session.submit("second while busy", now: t0), "one generation at a time")

        let version = try XCTUnwrap(session.complete(request, markdown: "# Fix\n\nEdit `/Users/me/App/Editor.swift`.", engineLabel: "Apple Intelligence", now: t0))
        XCTAssertEqual(version.number, 1)
        XCTAssertEqual(version.state, .accepted)
        XCTAssertEqual(session.currentVersionID, version.id)
        XCTAssertEqual(session.messages.last?.role, .assistant)
        XCTAssertEqual(session.messages.last?.versionID, version.id)
        XCTAssertNil(session.pendingRequestID)
    }

    func testFollowUpProposesVersionWithoutReplacingCurrent() throws {
        var session = PromptSession(now: t0)
        let first = try XCTUnwrap(session.submit("Write a release checklist", now: t0))
        let v1 = try XCTUnwrap(session.complete(first, markdown: "# Checklist\n\n- Build", engineLabel: "Qwen", now: t0))

        let followUp = try XCTUnwrap(session.submit("Add a step to run swift test", now: t0))
        XCTAssertEqual(followUp.kind, .refinement(baseVersionID: v1.id))
        XCTAssertEqual(followUp.baseMarkdown, "# Checklist\n\n- Build")
        XCTAssertEqual(followUp.originalRequest, "Write a release checklist", "original request is never overwritten")

        let v2 = try XCTUnwrap(session.complete(followUp, markdown: "# Checklist\n\n- Build\n- Run swift test", engineLabel: "Qwen", now: t0))
        XCTAssertEqual(v2.state, .proposed)
        XCTAssertEqual(v2.basedOn, v1.id)
        XCTAssertEqual(session.currentVersionID, v1.id, "a proposal does not replace the applied version")
        XCTAssertEqual(session.proposal?.id, v2.id)

        XCTAssertTrue(session.accept(v2.id, now: t0))
        XCTAssertEqual(session.currentVersionID, v2.id)
        XCTAssertEqual(session.versions.count, 2, "prior versions are preserved")

        XCTAssertTrue(session.restore(v1.id, now: t0))
        XCTAssertEqual(session.currentVersionID, v1.id)
        XCTAssertEqual(session.version(v2.id)?.markdown, "# Checklist\n\n- Build\n- Run swift test")
    }

    func testDiscardAndSupersededProposals() throws {
        var session = PromptSession(now: t0)
        let r1 = try XCTUnwrap(session.submit("Plan a launch", now: t0))
        _ = session.complete(r1, markdown: "# Plan", engineLabel: "Apple", now: t0)
        let r2 = try XCTUnwrap(session.submit("Shorter", now: t0))
        let v2 = try XCTUnwrap(session.complete(r2, markdown: "# Plan (short)", engineLabel: "Apple", now: t0))
        let r3 = try XCTUnwrap(session.submit("Even shorter", now: t0))
        let v3 = try XCTUnwrap(session.complete(r3, markdown: "# P", engineLabel: "Apple", now: t0))
        XCTAssertEqual(session.version(v2.id)?.state, .discarded, "a newer proposal supersedes the older one")
        XCTAssertEqual(session.proposal?.id, v3.id)
        XCTAssertTrue(session.discard(v3.id, now: t0))
        XCTAssertNil(session.proposal)
        XCTAssertEqual(session.version(v3.id)?.state, .discarded)
    }

    func testFailureAndCancellationKeepTheDraftAndCreateNoVersion() throws {
        var session = PromptSession(now: t0)
        let request = try XCTUnwrap(session.submit("Summarize https://example.com/spec", now: t0))
        session.fail(request, message: "Could not use local Ollama: Could not connect to the server.", now: t0)
        XCTAssertEqual(session.draft, "Summarize https://example.com/spec", "the user's words return to the composer")
        XCTAssertTrue(session.versions.isEmpty)
        XCTAssertEqual(session.messages.last?.isError, true)
        XCTAssertEqual(session.messages.last?.text, "Could not use local Ollama: Could not connect to the server.")

        let retry = try XCTUnwrap(session.submit(session.draft, now: t0))
        session.cancel(retry, now: t0)
        XCTAssertEqual(session.draft, "Summarize https://example.com/spec")
        XCTAssertEqual(session.messages.last?.role, .notice)
        XCTAssertNil(session.pendingRequestID)
    }

    func testStaleCompletionIsIgnored() throws {
        var session = PromptSession(now: t0)
        let request = try XCTUnwrap(session.submit("Hello", now: t0))
        session.cancel(request, now: t0)
        XCTAssertNil(session.complete(request, markdown: "# Late", engineLabel: "Apple", now: t0))
        XCTAssertTrue(session.versions.isEmpty)
    }

    func testEditingCurrentVersionAndCodableRoundTrip() throws {
        var session = PromptSession(now: t0)
        let request = try XCTUnwrap(session.submit("Draft an email", now: t0))
        _ = session.complete(request, markdown: "# Email", engineLabel: "Apple", now: t0)
        session.editCurrent(markdown: "# Email\n\nHi team,", now: t0)
        XCTAssertEqual(session.currentVersion?.markdown, "# Email\n\nHi team,")
        XCTAssertEqual(session.currentVersion?.isEdited, true)
        let decoded = try JSONDecoder().decode(PromptSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded, session)
    }

    func testLegacyHistoryRecordBecomesSession() {
        let record = PromptRecord(createdAt: t0, input: "Old request", output: "# Old", profile: .research, detail: .concise, engineLabel: "qwen3:8b")
        let session = PromptSession(legacy: record)
        XCTAssertEqual(session.originalRequest, "Old request")
        XCTAssertEqual(session.currentVersion?.markdown, "# Old")
        XCTAssertEqual(session.profile, .research)
        XCTAssertEqual(session.messages.first?.text, "Old request")
    }
}

// MARK: - Refinement prompting and exact-value preservation

final class RefinementPreservationTests: XCTestCase {
    func testRefinementPromptCarriesOriginalCurrentAndRevision() {
        let envelope = PromptRules.refinementEnvelope(original: "Build X by 2026-12-01",
                                                      current: "# Build X\n\nDeadline: 2026-12-01",
                                                      revision: "Make it more concise")
        XCTAssertTrue(envelope.contains("<original_request>\nBuild X by 2026-12-01\n</original_request>"))
        XCTAssertTrue(envelope.contains("<current_prompt>\n# Build X\n\nDeadline: 2026-12-01\n</current_prompt>"))
        XCTAssertTrue(envelope.contains("<revision_request>\nMake it more concise\n</revision_request>"))
        let rules = PromptRules.refinementInstructions(profile: .developer, detail: .complete)
        XCTAssertTrue(rules.contains("COMPLETE revised Markdown"))
        XCTAssertTrue(rules.contains("exactly as written"))
        XCTAssertTrue(rules.contains("code agents"), "profile specialization still applies")
    }

    func testOriginalInstructionsUnchangedForInitialPrompts() {
        let instructions = PromptRules.instructions(profile: .general, detail: .concise)
        XCTAssertTrue(instructions.contains("REWRITE the request, NOT perform it"))
        XCTAssertTrue(instructions.contains("Be concise."))
    }

    func testRefinementFlagsDroppedValuesFromOriginalOrCurrentVersion() throws {
        var session = PromptSession()
        let r1 = try XCTUnwrap(session.submit("Deploy https://example.com/app on 2026-12-01 using `deploy.sh`"))
        _ = session.complete(r1, markdown: "# Deploy\n\n- URL: https://example.com/app\n- Date: 2026-12-01\n- Run `deploy.sh`", engineLabel: "Apple")
        let r2 = try XCTUnwrap(session.submit("Make it one sentence"))
        let lossy = try XCTUnwrap(session.complete(r2, markdown: "# Deploy\n\nDeploy the app soon.", engineLabel: "Apple"))
        XCTAssertTrue(lossy.validation.hasWarnings)
        XCTAssertTrue(lossy.validation.missingExactStrings.contains("https://example.com/app"))
        XCTAssertTrue(lossy.validation.missingExactStrings.contains("2026-12-01"))

        let r3 = try XCTUnwrap(session.submit("Make it one sentence, keep details"))
        let faithful = try XCTUnwrap(session.complete(r3, markdown: "# Deploy\n\nDeploy https://example.com/app on 2026-12-01 with `deploy.sh`.", engineLabel: "Apple"))
        XCTAssertEqual(faithful.validation.missingExactStrings, [])
    }
}

// MARK: - Markdown fidelity

final class MarkdownFidelityTests: XCTestCase {
    private let sample = """
    # Release Plan

    Ship **v2** to [staging](https://example.com/staging) before 2026-12-01.

    ## Steps
    1. Build the app
    2. Run `swift test`
       - include *core* tests
    - [ ] Update notes
    - [x] Tag release

    > Keep the original request intact.
    > - quoted bullet

    | Step | Owner | Done |
    |:-----|:-----:|-----:|
    | Build | Ana | yes |
    | Test \\| verify | Lee |

    ````swift
    let fence = "```"
    print(fence)
    ````

    ---
    Setext Title
    ============
    Closing paragraph
    with a soft break.
    """

    func testAllBlockKindsParse() {
        let blocks = MarkdownDocument.parse(sample)
        guard blocks.count == 10 else { return XCTFail("unexpected block count \(blocks.count): \(blocks)") }
        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Release Plan"))
        XCTAssertEqual(blocks[1], .paragraph("Ship **v2** to [staging](https://example.com/staging) before 2026-12-01."))
        XCTAssertEqual(blocks[2], .heading(level: 2, text: "Steps"))
        XCTAssertEqual(blocks[3], .list([
            MarkdownListItem(text: "Build the app", level: 0, ordinal: 1, checked: nil),
            MarkdownListItem(text: "Run `swift test`", level: 0, ordinal: 2, checked: nil),
            MarkdownListItem(text: "include *core* tests", level: 1, ordinal: nil, checked: nil),
            MarkdownListItem(text: "Update notes", level: 0, ordinal: nil, checked: false),
            MarkdownListItem(text: "Tag release", level: 0, ordinal: nil, checked: true)
        ]))
        XCTAssertEqual(blocks[4], .quote([
            .paragraph("Keep the original request intact."),
            .list([MarkdownListItem(text: "quoted bullet", level: 0, ordinal: nil, checked: nil)])
        ]))
        XCTAssertEqual(blocks[5], .table(header: ["Step", "Owner", "Done"],
                                         alignments: [.leading, .center, .trailing],
                                         rows: [["Build", "Ana", "yes"], ["Test | verify", "Lee", ""]]))
        XCTAssertEqual(blocks[6], .code(language: "swift", content: "let fence = \"```\"\nprint(fence)"))
        XCTAssertEqual(blocks[7], .thematicBreak)
        XCTAssertEqual(blocks[8], .heading(level: 1, text: "Setext Title"))
        XCTAssertEqual(blocks[9], .paragraph("Closing paragraph\nwith a soft break."))
    }

    func testCodeBlockContentIsVerbatimIncludingIndentationAndBlankLines() {
        let source = "```json\n{\n  \"a\": 1,\n\n  \"b\": [\"# not a heading\", \"- not a list\"]\n}\n```"
        XCTAssertEqual(MarkdownDocument.parse(source),
                       [.code(language: "json", content: "{\n  \"a\": 1,\n\n  \"b\": [\"# not a heading\", \"- not a list\"]\n}")])
    }

    func testFenceInsideListItemIsKeptAsCode() {
        let source = "1. Run this:\n   ```sh\n   swift test\n   ```\n2. Done"
        let blocks = MarkdownDocument.parse(source)
        XCTAssertEqual(blocks, [
            .list([MarkdownListItem(text: "Run this:", level: 0, ordinal: 1, checked: nil)]),
            .code(language: "sh", content: "swift test"),
            .list([MarkdownListItem(text: "Done", level: 0, ordinal: 2, checked: nil)])
        ])
    }

    func testUnclosedFenceRunsToEndAndHashtagsAreNotHeadings() {
        XCTAssertEqual(MarkdownDocument.parse("#hashtag text"), [.paragraph("#hashtag text")])
        XCTAssertEqual(MarkdownDocument.parse("```\nopen"), [.code(language: nil, content: "open")])
    }

    func testTableCellLineBreaksDisplayAsNewlinesWithoutChangingSource() {
        // Seen live: Apple Intelligence put "<br>" inside GFM table cells.
        XCTAssertEqual(MarkdownDocument.tableCellDisplayText("- Build<br>- Test<BR/>- Ship<br />done"),
                       "- Build\n- Test\n- Ship\ndone")
        let blocks = MarkdownDocument.parse("| A |\n|---|\n| x<br>y |")
        XCTAssertEqual(blocks, [.table(header: ["A"], alignments: [.leading], rows: [["x<br>y"]])], "parsing keeps the source verbatim")
    }

    func testNoSourceTextIsLost() {
        let blocks = MarkdownDocument.parse(sample)
        let rendered = MarkdownDocument.allText(in: blocks)
        for word in ["Release", "staging", "swift test", "core", "Update notes", "Tag release", "intact", "quoted bullet",
                     "Owner", "Lee", "Test | verify", "print(fence)", "Setext Title", "soft break", "2026-12-01"] {
            XCTAssertTrue(rendered.contains(word), "lost \"\(word)\"")
        }
    }
}

// MARK: - Version comparison

final class ArtifactDiffTests: XCTestCase {
    func testLineDiffMarksAddedAndRemovedLines() {
        let diff = ArtifactDiff.lines(from: "# Plan\n- Build\n- Ship", to: "# Plan\n- Build\n- Test\n- Ship now")
        XCTAssertEqual(diff, [
            DiffLine(kind: .unchanged, text: "# Plan"),
            DiffLine(kind: .unchanged, text: "- Build"),
            DiffLine(kind: .removed, text: "- Ship"),
            DiffLine(kind: .added, text: "- Test"),
            DiffLine(kind: .added, text: "- Ship now")
        ])
        XCTAssertEqual(ArtifactDiff.counts(diff).added, 2)
        XCTAssertEqual(ArtifactDiff.counts(diff).removed, 1)
    }

    func testIdenticalTextHasNoChanges() {
        XCTAssertEqual(ArtifactDiff.counts(ArtifactDiff.lines(from: "a\nb", to: "a\nb")).added, 0)
    }
}

// MARK: - Feed image parsing

final class FeedImageParsingTests: XCTestCase {
    private let source = FeedSource(id: "test", publisher: "Test", feedURL: URL(string: "https://example.com/feed")!,
                                    homepage: URL(string: "https://example.com")!, topics: [.coding])

    func testMediaRSSAndEnclosuresProvideHTTPSImagesOnly() {
        let rss = """
        <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <image><url>https://example.com/channel-logo.png</url></image>
        <item><title>Thumb</title><link>https://example.com/a</link>
          <media:content url="https://cdn.example.com/a-large.jpg" medium="image"/>
          <media:thumbnail url="https://cdn.example.com/a-thumb.jpg"/></item>
        <item><title>Content</title><link>https://example.com/b</link>
          <media:content url="https://cdn.example.com/b.png" type="image/png"/></item>
        <item><title>Enclosure</title><link>https://example.com/c</link>
          <enclosure url="https://cdn.example.com/c.webp" type="image/webp" length="100"/></item>
        <item><title>Audio</title><link>https://example.com/d</link>
          <enclosure url="https://cdn.example.com/d.mp3" type="audio/mpeg"/></item>
        <item><title>Insecure</title><link>https://example.com/e</link>
          <media:thumbnail url="http://cdn.example.com/e.jpg"/></item>
        <item><title>None</title><link>https://example.com/f</link><description>&lt;img src="https://x.com/f.jpg"&gt;</description></item>
        </channel></rss>
        """
        let items = NewsFeedParser.parse(Data(rss.utf8), source: source)
        XCTAssertEqual(items.map(\.title), ["Thumb", "Content", "Enclosure", "Audio", "Insecure", "None"])
        XCTAssertEqual(items.map { $0.imageURL?.absoluteString }, [
            "https://cdn.example.com/a-thumb.jpg", "https://cdn.example.com/b.png", "https://cdn.example.com/c.webp",
            nil, nil, nil
        ])
        XCTAssertEqual(items[0].url.absoluteString, "https://example.com/a", "article URL is the canonical link, never the image")
    }

    func testAtomEntryWithMediaThumbnail() {
        let atom = """
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
        <entry><title>Atom story</title><link rel="alternate" href="https://example.com/atom"/>
        <updated>2026-11-16T10:00:00Z</updated><content type="html">Body</content>
        <media:thumbnail url="https://cdn.example.com/atom.jpg" width="640"/></entry></feed>
        """
        let item = NewsFeedParser.parse(Data(atom.utf8), source: source).first
        XCTAssertEqual(item?.url.absoluteString, "https://example.com/atom")
        XCTAssertEqual(item?.imageURL?.absoluteString, "https://cdn.example.com/atom.jpg")
        XCTAssertNotNil(item?.date)
    }

    func testCachedItemsWithoutImageFieldStillDecode() throws {
        let legacy = #"{"id":"x","sourceID":"s","publisher":"P","title":"T","url":"https://example.com","summary":"","topics":["Coding"]}"#
        let item = try JSONDecoder().decode(NewsItem.self, from: Data(legacy.utf8))
        XCTAssertNil(item.imageURL)
    }

    func testNumericEntitiesInSummariesAreDecoded() {
        // Seen live in the WebKit feed: "&#60;model&#62; element" was shown raw on Home.
        let rss = "<rss><channel><item><title>T</title><link>https://example.com/t</link><description>the &amp;#60;model&amp;#62; element &amp;#x2014; &amp;#39;3D&amp;#39;</description></item></channel></rss>"
        XCTAssertEqual(NewsFeedParser.parse(Data(rss.utf8), source: source).first?.summary, "the <model> element — '3D'")
    }

    func testRFC822ZoneAbbreviationDates() {
        let rss = "<rss><channel><item><title>T</title><link>https://example.com/t</link><pubDate>Wed, 28 Oct 2026 10:00:55 PDT</pubDate></item></channel></rss>"
        XCTAssertNotNil(NewsFeedParser.parse(Data(rss.utf8), source: source).first?.date)
    }
}

// MARK: - Thumbnail cache policy

final class ThumbnailCachePolicyTests: XCTestCase {
    private let policy = ThumbnailCachePolicy(maxAge: 3600, maxItemBytes: 1000, maxTotalBytes: 2500)
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testValidation() {
        XCTAssertEqual(policy.validate(url: URL(string: "http://example.com/a.jpg")!), .insecureURL)
        XCTAssertNil(policy.validate(url: URL(string: "https://example.com/a.jpg")!))
        XCTAssertEqual(policy.validate(statusCode: 404, mimeType: "image/jpeg", expectedLength: 10), .httpStatus(404))
        XCTAssertEqual(policy.validate(statusCode: 200, mimeType: "text/html", expectedLength: 10), .notImage("text/html"))
        XCTAssertEqual(policy.validate(statusCode: 200, mimeType: "image/svg+xml", expectedLength: 10), .notImage("image/svg+xml"))
        XCTAssertEqual(policy.validate(statusCode: 200, mimeType: "image/png", expectedLength: 5000), .tooLarge(5000))
        XCTAssertNil(policy.validate(statusCode: 200, mimeType: "IMAGE/JPEG", expectedLength: -1), "unknown length is checked while downloading")
    }

    func testExpirationAndLeastRecentlyUsedEviction() {
        var index = ThumbnailCacheIndex()
        let url = { (n: Int) in URL(string: "https://example.com/\(n).jpg")! }
        index.insert(url: url(1), bytes: 1000, now: t0)
        index.insert(url: url(2), bytes: 1000, now: t0.addingTimeInterval(10))
        index.insert(url: url(3), bytes: 1000, now: t0.addingTimeInterval(20))
        XCTAssertNotNil(index.lookup(url(1), now: t0.addingTimeInterval(100), policy: policy))
        XCTAssertNil(index.lookup(url(1), now: t0.addingTimeInterval(3601), policy: policy), "expired after maxAge")

        index.touch(url(1), now: t0.addingTimeInterval(30))
        let removed = index.evict(now: t0.addingTimeInterval(40), policy: policy)
        XCTAssertEqual(removed, [ThumbnailCacheIndex.key(for: url(2))], "least recently used goes first until under budget")
        XCTAssertEqual(index.totalBytes, 2000)

        let expired = index.evict(now: t0.addingTimeInterval(4000), policy: policy)
        XCTAssertEqual(Set(expired).count, 2)
        XCTAssertTrue(index.entries.isEmpty)
    }

    func testKeysAreStableAndDistinct() {
        let a = ThumbnailCacheIndex.key(for: URL(string: "https://example.com/a.jpg")!)
        XCTAssertEqual(a, ThumbnailCacheIndex.key(for: URL(string: "https://example.com/a.jpg")!))
        XCTAssertNotEqual(a, ThumbnailCacheIndex.key(for: URL(string: "https://example.com/b.jpg")!))
        XCTAssertEqual(a.count, 16)
    }
}

// MARK: - Workspace navigation / layout state

final class WorkspaceLayoutTests: XCTestCase {
    func testDefaultShowsSidebarChatAndArtifact() {
        let resolved = WorkspaceLayout().resolve(windowWidth: 1450)
        XCTAssertTrue(resolved.sidebar)
        XCTAssertEqual(resolved.browser, .hidden)
        XCTAssertEqual(resolved.artifact, .visible(520))
        XCTAssertTrue(resolved.chat)
    }

    func testOpeningBrowserCollapsesSidebarOnlyWhenNeededAndRestoresIt() {
        var layout = WorkspaceLayout()
        layout.toggleBrowser()
        let normal = layout.resolve(windowWidth: 1450)
        XCTAssertFalse(normal.sidebar, "sidebar auto-collapses to keep chat usable")
        XCTAssertEqual(normal.browser, .visible(480))
        XCTAssertEqual(normal.artifact, .visible(520))
        let wide = layout.resolve(windowWidth: 2000)
        XCTAssertTrue(wide.sidebar, "wide windows keep all four columns")
        layout.toggleBrowser()
        XCTAssertTrue(layout.resolve(windowWidth: 1450).sidebar, "closing the browser restores the sidebar")
    }

    func testNarrowWindowRailsSecondaryPaneInsteadOfSqueezing() {
        var layout = WorkspaceLayout()
        layout.toggleBrowser()
        let narrow = layout.resolve(windowWidth: 1020)
        XCTAssertFalse(narrow.sidebar)
        XCTAssertEqual(narrow.artifact, .rail)
        guard case .visible(let browserWidth) = narrow.browser else { return XCTFail("browser should stay visible") }
        XCTAssertGreaterThanOrEqual(browserWidth, WorkspaceLayout.minBrowser)
        XCTAssertLessThanOrEqual(browserWidth + WorkspaceLayout.minChat + WorkspaceLayout.railWidth + 2 * WorkspaceLayout.dividerWidth, 1020)

        layout.reveal(.artifact)
        let swapped = layout.resolve(windowWidth: 1020)
        XCTAssertEqual(swapped.browser, .rail)
        if case .visible = swapped.artifact {} else { XCTFail("artifact should now be visible") }
    }

    func testFocusModeAndExplicitSidebar() {
        var layout = WorkspaceLayout()
        layout.toggleFocus(.artifact)
        let focused = layout.resolve(windowWidth: 1020)
        XCTAssertEqual(focused, .init(sidebar: false, browser: .hidden, chat: false, artifact: .visible(1020)))
        layout.toggleFocus(.artifact)
        XCTAssertNil(layout.focus)

        layout.toggleBrowser()
        layout.setSidebarVisible(true)
        XCTAssertTrue(layout.resolve(windowWidth: 1450).sidebar, "a sidebar the user re-opens stays open")
        layout.setSidebarVisible(false)
        layout.toggleBrowser()
        XCTAssertFalse(layout.resolve(windowWidth: 1450).sidebar, "a sidebar the user hid stays hidden")
    }

    func testResizeClampsAndLayoutPersists() throws {
        var layout = WorkspaceLayout()
        layout.resize(.browser, to: 120)
        XCTAssertEqual(layout.browserWidth, WorkspaceLayout.minBrowser)
        layout.resize(.artifact, to: 5000)
        XCTAssertEqual(layout.artifactWidth, WorkspaceLayout.maxPaneWidth)
        let restored = WorkspaceLayout(encoded: layout.encoded)
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(WorkspaceLayout(encoded: "not json"), WorkspaceLayout())
    }
}
