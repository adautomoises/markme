import XCTest
@testable import MarkmeCore

final class MinimapTests: XCTestCase {
    func testUnchangedTextHasNoEditMarks() {
        XCTAssertEqual(EditMarks.marks(from: "alpha\nbeta\n", to: "alpha\nbeta\n"), [])
    }

    func testNewLinesAreAdded() {
        let marks = EditMarks.marks(from: "alpha\ngamma\n", to: "alpha\nbeta\ngamma\n")
        XCTAssertEqual(marks, [EditMark(kind: .added(2...2), current: ["beta"])])
    }

    func testReplacedLinesAreOneModification() {
        let marks = EditMarks.marks(from: "alpha\nbeta\ngamma\n", to: "alpha\nBETA\ngamma\n")
        XCTAssertEqual(marks, [EditMark(kind: .modified(2...2), original: ["beta"], current: ["BETA"])])
    }

    func testDeletedLinesAreARemovalAfterTheSurvivingLine() {
        let marks = EditMarks.marks(from: "alpha\nbeta\ngamma\n", to: "alpha\ngamma\n")
        XCTAssertEqual(marks, [EditMark(kind: .removed(afterLine: 1, count: 1), original: ["beta"])])
    }

    func testDeletingTheFirstLinesKeepsTheirText() {
        let marks = EditMarks.marks(from: "one\ntwo\nthree\n", to: "three\n")
        XCTAssertEqual(marks, [EditMark(kind: .removed(afterLine: 0, count: 2), original: ["one", "two"])])
    }

    func testEveryMarkRevertsToTheOpenedText() {
        let original = "# Title\n\nalpha\nbeta\ngamma\ndelta\n"
        let edited = "# Title\nnew\n\nalpha\nBETA\ndelta\n"
        var text = edited
        // Revert from the bottom so earlier line numbers stay valid.
        for mark in EditMarks.marks(from: original, to: edited).reversed() {
            text = EditMarks.reverted(mark, in: text)
        }
        XCTAssertEqual(text, original)
    }

    func testRevertingOneMarkLeavesTheOthers() {
        let original = "a\nb\nc\nd\n"
        let edited = "a\nB\nc\n"
        let marks = EditMarks.marks(from: original, to: edited)
        XCTAssertEqual(marks.count, 2)
        let back = EditMarks.reverted(marks[1], in: edited)
        XCTAssertEqual(back, "a\nB\nc\nd\n")
        XCTAssertEqual(EditMarks.marks(from: original, to: back), [marks[0]])
    }

    func testRevertKeepsWindowsLineEndings() {
        let original = "a\r\nb\r\nc\r\n"
        let edited = "a\r\nc\r\n"
        let mark = EditMarks.marks(from: original, to: edited)[0]
        XCTAssertEqual(EditMarks.reverted(mark, in: edited), original)
    }

    func testReplacementIsTheSmallestEdit() {
        let edit = EditMarks.replacement(from: "a\nb\nc\n", to: "a\nBB\nc\n")
        XCTAssertEqual(edit, TextReplacement(location: 2, length: 1, text: "BB"))
        let insert = EditMarks.replacement(from: "a\nc\n", to: "a\nb\nc\n")
        let applied = ("a\nc\n" as NSString).replacingCharacters(
            in: NSRange(location: insert.location, length: insert.length),
            with: insert.text
        )
        XCTAssertEqual(applied, "a\nb\nc\n")
    }

    func testReplacementNeverSplitsAnEmoji() {
        let edit = EditMarks.replacement(from: "x😀\n", to: "x😁\n")
        let applied = ("x😀\n" as NSString).replacingCharacters(
            in: NSRange(location: edit.location, length: edit.length),
            with: edit.text
        )
        XCTAssertEqual(applied, "x😁\n")
    }

    func testCurrentLinesOfAMark() {
        XCTAssertEqual(EditMarks.lines(2...3, in: "a\nb\nc\nd\n"), ["b", "c"])
        XCTAssertEqual(EditMarks.lines(3...9, in: "a\nb\nc\n"), ["c"])
    }

    func testCountsAddUpEveryLine() {
        let marks = EditMarks.marks(
            from: "one\ntwo\nthree\nfour\n",
            to: "one\nTWO\nthree\nnew\nnewer\n"
        )
        let counts = EditMarks.counts(marks)
        XCTAssertEqual(counts.added + counts.modified, 3)
        XCTAssertGreaterThan(counts.modified, 0)
    }

    func testGutterLooksUpLinesAndRemovals() {
        let gutter = EditGutter([
            EditMark(kind: .added(3...4)),
            EditMark(kind: .modified(7...7)),
            EditMark(kind: .removed(afterLine: 0, count: 2)),
        ])
        XCTAssertEqual(gutter.lines[3], .added)
        XCTAssertEqual(gutter.lines[4], .added)
        XCTAssertEqual(gutter.lines[7], .modified)
        XCTAssertNil(gutter.lines[5])
        XCTAssertEqual(gutter.removedAfter, [0])
        XCTAssertEqual(gutter.mark(nearLine: 4), 0)
        XCTAssertEqual(gutter.mark(nearLine: 7), 1)
        XCTAssertEqual(gutter.mark(nearLine: 1), 2)
        XCTAssertNil(gutter.mark(nearLine: 10))
    }

    func testLinesKnowHeadingsFencesQuotesAndIndent() {
        let text = """
        # Title

        Some text
            indented
        > quote
        ```swift
        # not a heading
        ```
        #hashtag
        """
        let kinds = Minimap.lines(in: text).map(\.kind)
        XCTAssertEqual(kinds, [.heading, .blank, .text, .text, .quote, .fence, .fence, .fence, .text])
        XCTAssertEqual(Minimap.lines(in: text)[3].indent, 4)
        XCTAssertEqual(Minimap.lines(in: text)[2].length, 9)
    }

    func testLengthIsCappedAndATabIndentsFour() {
        let lines = Minimap.lines(in: "\tx\n" + String(repeating: "a", count: 500) + "\n")
        XCTAssertEqual(lines[0].indent, Minimap.tabWidth)
        XCTAssertEqual(lines[1].length, Minimap.maximumLength)
    }

    func testASetextHeadingDrawsAsText() {
        // A glance does not need the underline to lift the line above it.
        XCTAssertEqual(Minimap.lines(in: "Title\n=====\n").map(\.kind), [.text, .text])
    }

    func testARewriteBeyondTheBudgetIsOneModification() {
        let opened = (1...3000).map { "line \($0)" }.joined(separator: "\n") + "\n"
        let rewritten = "keep\n" + (1...3000).map { "new \($0)" }.joined(separator: "\n") + "\n"
        let marks = EditMarks.marks(from: "keep\n" + opened, to: rewritten)
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(marks[0].kind, .modified(2...3001))
        XCTAssertEqual(marks[0].original.count, 3000)
        XCTAssertEqual(EditMarks.revert(marks[0], original: "keep\n" + opened, current: rewritten), "keep\n" + opened)
    }

    func testASmallEditInALongFileSkipsTheBudget() {
        let opened = (1...5000).map { "line \($0)" }.joined(separator: "\n") + "\n"
        let edited = opened.replacingOccurrences(of: "line 2500\n", with: "LINE 2500\n")
        XCTAssertEqual(EditMarks.marks(from: opened, to: edited), [
            EditMark(kind: .modified(2500...2500), original: ["line 2500"], current: ["LINE 2500"]),
        ])
    }

    func testLineBreaksCountEveryEnding() {
        let text = "a\r\nb\rc\nd" as NSString
        XCTAssertEqual(LineBreaks.line(at: 0, in: text), 1)
        XCTAssertEqual(LineBreaks.line(at: 3, in: text), 2)
        XCTAssertEqual(LineBreaks.line(at: 5, in: text), 3)
        XCTAssertEqual(LineBreaks.line(at: 7, in: text), 4)
        XCTAssertEqual(LineBreaks.line(at: 99, in: text), 4)
        XCTAssertEqual(LineBreaks.offset(ofLine: 1, in: text), 0)
        XCTAssertEqual(LineBreaks.offset(ofLine: 2, in: text), 3)
        XCTAssertEqual(LineBreaks.offset(ofLine: 3, in: text), 5)
        XCTAssertEqual(LineBreaks.offset(ofLine: 4, in: text), 7)
        XCTAssertEqual(LineBreaks.offset(ofLine: 9, in: text), text.length)
        XCTAssertTrue(LineBreaks.isBreak(at: 4, in: text))
        XCTAssertFalse(LineBreaks.isBreak(at: 0, in: text))
        XCTAssertFalse(LineBreaks.isBreak(at: 99, in: text))
    }

    func testLineBreaksAgreeWithTheMarks() {
        // The gutter numbers lines with LineBreaks and draws marks from EditMarks. They must agree.
        let original = "one\rtwo\rthree\r"
        let edited = "one\rTWO\rthree\r" as NSString
        let mark = EditMarks.marks(from: original, to: edited as String)[0]
        XCTAssertEqual(LineBreaks.line(at: edited.range(of: "TWO").location, in: edited), mark.focusLine)
    }

    func testAFenceClosesOnlyWithItsOwnMarker() {
        let text = "````\n```\ninside\n````\nafter\n"
        XCTAssertEqual(Minimap.lines(in: text).map(\.kind), [.fence, .fence, .fence, .fence, .text])
    }

    func testScaleFitsEveryLineAndCapsTheRow() {
        let short = MinimapScale(lineCount: 10, height: 600)
        XCTAssertEqual(short.rowHeight, MinimapScale.maximumRowHeight)
        let long = MinimapScale(lineCount: 1000, height: 500)
        XCTAssertEqual(long.rowHeight, 0.5)
        XCTAssertEqual(long.y(ofLine: 1), 0)
        XCTAssertEqual(long.line(atY: 499.9), 1000)
        XCTAssertEqual(long.line(atY: -5), 1)
        XCTAssertEqual(long.line(atY: 10_000), 1000)
    }

    func testJumpCentersTheLineUnderThePointer() {
        let scale = MinimapScale(lineCount: 100, height: 300)
        XCTAssertEqual(scale.jumpLine(atY: 150, visibleLines: 20), 41)
        XCTAssertEqual(scale.jumpLine(atY: 3, visibleLines: 20), 1)
    }

    func testCopyForTheMinimap() {
        XCTAssertEqual(ReaderCopy.string(.minimap, languageCode: "pt-BR"), "Minimapa")
        XCTAssertEqual(ReaderCopy.string(.minimap, languageCode: "en"), "Minimap")
        XCTAssertEqual(
            ReaderCopy.editSummary(added: 3, modified: 2, removed: 1, languageCode: "pt-BR"),
            "+3 ~2 −1 desde a abertura"
        )
        XCTAssertEqual(
            ReaderCopy.editSummary(added: 0, modified: 0, removed: 0, languageCode: "en"),
            "No changes since opened"
        )
        XCTAssertEqual(
            ReaderCopy.editSummary(added: 0, modified: 0, removed: 0, languageCode: "pt"),
            "Sem mudanças desde a abertura"
        )
        XCTAssertEqual(ReaderCopy.string(.revertChange, languageCode: "pt-BR"), "Reverter")
        XCTAssertEqual(ReaderCopy.string(.revertChange, languageCode: "en"), "Revert")
        XCTAssertEqual(ReaderCopy.string(.goToChange, languageCode: "pt-BR"), "Ir para")
        XCTAssertEqual(ReaderCopy.string(.peekBefore, languageCode: "pt-BR"), "Antes")
        XCTAssertEqual(ReaderCopy.string(.peekNow, languageCode: "en"), "Now")
        XCTAssertEqual(ReaderCopy.linesAdded(1, languageCode: "pt-BR"), "1 linha nova")
        XCTAssertEqual(ReaderCopy.linesAdded(3, languageCode: "en"), "3 new lines")
        XCTAssertEqual(ReaderCopy.linesChanged(2, languageCode: "pt"), "2 linhas alteradas")
        XCTAssertEqual(ReaderCopy.linesChanged(1, languageCode: "en"), "1 changed line")
        XCTAssertEqual(ReaderCopy.lineNumber(12, languageCode: "pt-BR"), "linha 12")
        let changed = EditMark(kind: .modified(12...13), original: ["a"], current: ["b", "c"])
        XCTAssertEqual(ReaderCopy.revertAction(changed, languageCode: "en"), "Revert: 2 changed lines, line 12")
        XCTAssertEqual(ReaderCopy.revertAction(changed, languageCode: "pt-BR"), "Reverter: 2 linhas alteradas, linha 12")
        let gone = EditMark(kind: .removed(afterLine: 0, count: 1), original: ["a"])
        XCTAssertEqual(ReaderCopy.revertAction(gone, languageCode: "en"), "Revert: 1 line removed, line 1")
    }
}
