import XCTest
@testable import MarkmeCore

final class ChangeReviewTests: XCTestCase {
    func testIdenticalTextIncludingATrailingNewlineHasNoMarks() {
        XCTAssertEqual(ChangeReview.spans(from: "alpha\n", to: "alpha"), [])
        XCTAssertEqual(ChangeReview.spans(from: "alpha\r\nbeta\r\n", to: "alpha\nbeta\n"), [])
    }

    func testInsertionIsOneAddedSpan() {
        let spans = ChangeReview.spans(from: "alpha\ngamma\n", to: "alpha\nbeta\ngamma\n")
        XCTAssertEqual(spans, [ChangeSpan(kind: .added(2...2))])
    }

    func testDeletionLeavesAMarkerAfterTheSurvivingLine() {
        let spans = ChangeReview.spans(from: "alpha\nbeta\ngamma\n", to: "alpha\ngamma\n")
        XCTAssertEqual(spans, [ChangeSpan(kind: .removed(afterLine: 1, count: 1))])
        XCTAssertEqual(spans[0].focusLine, 1)
    }

    func testDeletingTheFirstLineAnchorsAtTheStart() {
        let spans = ChangeReview.spans(from: "alpha\nbeta\n", to: "beta\n")
        XCTAssertEqual(spans, [ChangeSpan(kind: .removed(afterLine: 0, count: 1))])
        XCTAssertEqual(spans[0].focusLine, 1)
    }

    func testReplacementShowsTheRemovalBeforeTheNewLines() {
        let spans = ChangeReview.spans(
            from: "alpha\nbeta\ngamma\n",
            to: "alpha\nBETA\ngamma\n"
        )
        XCTAssertEqual(spans, [
            ChangeSpan(kind: .removed(afterLine: 1, count: 1)),
            ChangeSpan(kind: .added(2...2))
        ])
    }

    func testSeparateEditsStaySeparate() {
        let spans = ChangeReview.spans(
            from: "a\nb\nc\nd\n",
            to: "a\nB\nc\nD\n"
        )
        XCTAssertEqual(spans.count, 4)
        XCTAssertEqual(spans[0], ChangeSpan(kind: .removed(afterLine: 1, count: 1)))
        XCTAssertEqual(spans[1], ChangeSpan(kind: .added(2...2)))
        XCTAssertEqual(spans[2], ChangeSpan(kind: .removed(afterLine: 3, count: 1)))
        XCTAssertEqual(spans[3], ChangeSpan(kind: .added(4...4)))
    }

    func testLineRangeIncludesTheTrailingNewline() {
        let text = "alpha\nbeta\ngamma\n"
        let range = ChangeReview.utf16Range(of: 2...2, in: text)
        XCTAssertEqual(range, NSRange(location: 6, length: 5))
        XCTAssertEqual((text as NSString).substring(with: range!), "beta\n")
    }

    func testAnnotateMarksTheAddedBlockAndTheGap() {
        let html = "<h1 data-sourcepos=\"1:1-1:6\">Alpha</h1><p data-sourcepos=\"2:1-2:5\">Beta</p>"
        let spans = [
            ChangeSpan(kind: .removed(afterLine: 1, count: 2)),
            ChangeSpan(kind: .added(2...2))
        ]
        let marked = ChangeReview.annotate(html: html, spans: spans, selected: 0) { count in
            "\(count) lines removed"
        }
        XCTAssertTrue(marked.contains("<p class=\"change-removed change-current\" data-change=\"0\">2 lines removed</p>"))
        XCTAssertTrue(marked.contains("class=\"change-added\""))
        XCTAssertTrue(marked.contains("data-change=\"1\""))
        XCTAssertTrue(marked.contains("<h1"))
        XCTAssertFalse(marked.contains("change-current\" data-change=\"1\""))
    }

    func testAnnotateLeavesUnchangedHTMLAlone() {
        let html = "<p data-sourcepos=\"1:1-1:2\">Hi</p>"
        XCTAssertEqual(ChangeReview.annotate(html: html, spans: [], selected: nil) { _ in "" }, html)
    }

    func testAnnotateSkipsAParentWhenAChildCoversTheSameLine() {
        let html = "<ul data-sourcepos=\"1:1-2:4\"><li data-sourcepos=\"1:1-1:4\">one</li><li data-sourcepos=\"2:1-2:4\">two</li></ul>"
        let marked = ChangeReview.annotate(
            html: html,
            spans: [ChangeSpan(kind: .added(2...2))],
            selected: 0
        ) { _ in "" }
        XCTAssertFalse(marked.contains("<ul data-sourcepos=\"1:1-2:4\" class=\"change-added\""), marked)
        XCTAssertTrue(
            marked.contains("<li data-sourcepos=\"2:1-2:4\" class=\"change-added change-current\" data-change=\"0\">"),
            marked
        )
        XCTAssertEqual(marked.components(separatedBy: "change-added").count - 1, 1, marked)
    }

    func testTwoAddedLinesInsideAFenceEachGetAnAnchor() {
        let html = "<pre data-sourcepos=\"1:1-5:3\"><code>alpha\nbeta\ngamma\n</code></pre>"
        let spans = [
            ChangeSpan(kind: .added(3...3)),
            ChangeSpan(kind: .added(4...4))
        ]
        let marked = ChangeReview.annotate(html: html, spans: spans, selected: 1) { _ in "" }
        XCTAssertFalse(marked.contains("<pre data-sourcepos=\"1:1-5:3\" class=\"change-added\""), marked)
        XCTAssertTrue(marked.contains("data-change=\"0\""), marked)
        XCTAssertTrue(marked.contains("data-change=\"1\""), marked)
        XCTAssertTrue(marked.contains(">beta</span>"), marked)
        XCTAssertTrue(marked.contains("change-current"), marked)
        XCTAssertFalse(marked.contains(">alpha</span>"), marked)
    }

    func testListDeletionUsesAListItemInsideTheList() {
        let before = "- one\n- two\n- three\n"
        let after = "- one\n- three\n"
        let marked = markedDiff(from: before, to: after)
        XCTAssertTrue(marked.contains("<li class=\"change-removed"), marked)
        let list = inside(marked, from: "<ul", to: "</ul>")
        XCTAssertFalse(list.contains("<p class=\"change-removed"), marked)
        XCTAssertTrue(list.contains("change-removed"), marked)
    }

    func testTableDeletionStaysOutsideTheTable() {
        let before = "| a | b |\n| --- | --- |\n| c | d |\n| e | f |\n"
        let after = "| a | b |\n| --- | --- |\n| e | f |\n"
        let marked = markedDiff(from: before, to: after)
        let table = inside(marked, from: "<table", to: "</table>")
        XCTAssertFalse(table.contains("change-removed"), marked)
        XCTAssertTrue(marked.contains("change-removed"), marked)
    }

    func testBlockquoteDeletionStaysInsideTheQuote() {
        let before = "> one\n> two\n> three\n"
        let after = "> one\n> three\n"
        let marked = markedDiff(from: before, to: after)
        let quote = inside(marked, from: "<blockquote", to: "</blockquote>")
        XCTAssertTrue(quote.contains("change-removed"), marked)
        XCTAssertFalse(quote.contains("<table"), marked)
    }

    func testFenceDeletionStaysOutsideTheFence() throws {
        let before = "```\nalpha\nbeta\ngamma\n```\n"
        let after = "```\nalpha\ngamma\n```\n"
        let marked = markedDiff(from: before, to: after)
        let fence = inside(marked, from: "<pre", to: "</pre>")
        XCTAssertFalse(fence.contains("change-removed"), marked)
        let close = try XCTUnwrap(marked.range(of: "</pre>"))
        let pill = try XCTUnwrap(marked.range(of: "change-removed"))
        XCTAssertGreaterThan(pill.lowerBound, close.lowerBound, marked)
    }

    func testAChangedListItemDoesNotMarkTheWholeList() {
        var lines = (1...12).map { "- item \($0)" }
        let before = lines.joined(separator: "\n") + "\n"
        lines[8] = "- item 9 edited"
        let after = lines.joined(separator: "\n") + "\n"
        let marked = markedDiff(from: before, to: after)
        XCTAssertFalse(openingTag(marked, "ul").contains("change-added"), marked)
        XCTAssertEqual(marked.components(separatedBy: "change-added").count - 1, 1, marked)
    }

    func testAChangedTableCellDoesNotMarkTheWholeTable() {
        let before = "| a | b |\n| --- | --- |\n| c | d |\n"
        let after = "| a | b |\n| --- | --- |\n| c | EDITED |\n"
        let marked = markedDiff(from: before, to: after)
        XCTAssertFalse(openingTag(marked, "table").contains("change-added"), marked)
        XCTAssertTrue(marked.contains("change-added"), marked)
        XCTAssertFalse(openingTag(marked, "tr").contains("change-added"), marked)
    }

    private func markedDiff(from before: String, to after: String) -> String {
        let spans = ChangeReview.spans(from: before, to: after)
        let html = MarkdownRenderer.render(after).htmlBody
        return ChangeReview.annotate(html: html, spans: spans, selected: spans.isEmpty ? nil : 0) { count in
            "\(count) removed"
        }
    }

    private func openingTag(_ html: String, _ name: String) -> String {
        guard let start = html.range(of: "<\(name)") else { return "" }
        guard let end = html[start.lowerBound...].firstIndex(of: ">") else { return "" }
        return String(html[start.lowerBound...end])
    }

    private func inside(_ html: String, from startToken: String, to endToken: String) -> String {
        guard let start = html.range(of: startToken), let end = html.range(of: endToken) else { return "" }
        return String(html[start.lowerBound..<end.upperBound])
    }

    func testRemovedLabelIsEscaped() {
        let html = "<p data-sourcepos=\"1:1-1:2\">Hi</p>"
        let marked = ChangeReview.annotate(
            html: html,
            spans: [ChangeSpan(kind: .removed(afterLine: 0, count: 1))],
            selected: nil
        ) { _ in "<b>" }
        XCTAssertTrue(marked.contains("&lt;b&gt;"))
        XCTAssertFalse(marked.contains("<b>"))
    }
}
