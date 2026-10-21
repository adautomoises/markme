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
