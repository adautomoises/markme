import XCTest
@testable import MarkmeCore

/// Revert as the window does it: marks come from the opened text and the text now,
/// a click reverts one of them, and the marks are computed again afterwards.
final class RevertScenarioTests: XCTestCase {
    private let opened = """
    # Weekend

    ## Saturday

    - Buy bread
    - Call the plumber
    - Water the plants

    ## Sunday

    Lunch at noon.
    Walk in the park.

    ```swift
    let total = 3
    ```

    """

    /// Reverts the first mark, recomputes, and repeats until nothing is left.
    private func revertAll(from current: String, pick: ([EditMark]) -> EditMark) -> String {
        var text = current
        for _ in 0..<50 {
            let marks = EditMarks.marks(from: opened, to: text)
            guard !marks.isEmpty else { break }
            guard let next = EditMarks.revert(pick(marks), original: opened, current: text) else {
                XCTFail("Could not revert \(pick(marks))")
                break
            }
            text = next
        }
        return text
    }

    private func replacing(_ old: String, with new: String) -> String {
        opened.replacingOccurrences(of: old, with: new)
    }

    func testScenarioDeletingLinesWhileTypingCanBeReverted() {
        let edited = replacing("- Call the plumber\n- Water the plants\n", with: "")
        let marks = EditMarks.marks(from: opened, to: edited)
        XCTAssertEqual(marks, [EditMark(
            kind: .removed(afterLine: 5, count: 2),
            original: ["- Call the plumber", "- Water the plants"]
        )])
        XCTAssertEqual(EditMarks.revert(marks[0], original: opened, current: edited), opened)
    }

    func testScenarioAChangedLineShowsTheOldTextAndReverts() {
        let edited = replacing("Lunch at noon.", with: "Lunch at one.")
        let marks = EditMarks.marks(from: opened, to: edited)
        XCTAssertEqual(marks, [EditMark(kind: .modified(11...11), original: ["Lunch at noon."], current: ["Lunch at one."])])
        XCTAssertEqual(EditMarks.lines(11...11, in: edited), ["Lunch at one."])
        XCTAssertEqual(EditMarks.revert(marks[0], original: opened, current: edited), opened)
    }

    func testScenarioANewLineIsTakenOutOnRevert() {
        let edited = replacing("- Buy bread\n", with: "- Buy bread\n- Buy milk\n")
        let marks = EditMarks.marks(from: opened, to: edited)
        XCTAssertEqual(marks, [EditMark(kind: .added(6...6), current: ["- Buy milk"])])
        XCTAssertEqual(EditMarks.revert(marks[0], original: opened, current: edited), opened)
    }

    func testScenarioRevertingTopToBottomRestoresTheFile() {
        let edited = opened
            .replacingOccurrences(of: "# Weekend", with: "# Long weekend")
            .replacingOccurrences(of: "- Call the plumber\n", with: "")
            .replacingOccurrences(of: "Walk in the park.", with: "Walk in the park.\nRead a book.")
            .replacingOccurrences(of: "let total = 3", with: "let total = 4")
        XCTAssertEqual(EditMarks.marks(from: opened, to: edited).count, 4)
        XCTAssertEqual(revertAll(from: edited) { $0.first! }, opened)
    }

    func testScenarioRevertingBottomToTopRestoresTheFile() {
        let edited = opened
            .replacingOccurrences(of: "# Weekend", with: "# Long weekend")
            .replacingOccurrences(of: "- Call the plumber\n", with: "")
            .replacingOccurrences(of: "Walk in the park.", with: "Walk in the park.\nRead a book.")
        XCTAssertEqual(revertAll(from: edited) { $0.last! }, opened)
    }

    func testScenarioAStaleMarkStillRevertsAfterAnEarlierRevertMovedIt() {
        // Two changes. The panel for the second was opened before the first was reverted.
        let edited = opened
            .replacingOccurrences(of: "## Saturday\n\n", with: "")
            .replacingOccurrences(of: "Walk in the park.\n", with: "")
        let marks = EditMarks.marks(from: opened, to: edited)
        XCTAssertEqual(marks.count, 2)
        let staleSecond = marks[1]
        let afterFirst = EditMarks.revert(marks[0], original: opened, current: edited)!
        XCTAssertNotEqual(EditMarks.marks(from: opened, to: afterFirst), [staleSecond], "the mark moved down two lines")
        XCTAssertEqual(EditMarks.revert(staleSecond, original: opened, current: afterFirst), opened)
    }

    func testScenarioAMarkAlreadyRevertedIsRefused() {
        let edited = replacing("Lunch at noon.", with: "Lunch at one.")
        let mark = EditMarks.marks(from: opened, to: edited)[0]
        let back = EditMarks.revert(mark, original: opened, current: edited)!
        XCTAssertNil(EditMarks.revert(mark, original: opened, current: back))
    }

    func testScenarioTypingAfterOpeningThePanelStillReverts() {
        // The panel shows a removal. Then the person types elsewhere before pressing Revert.
        let edited = replacing("- Water the plants\n", with: "")
        let mark = EditMarks.marks(from: opened, to: edited)[0]
        let typedMore = edited.replacingOccurrences(of: "# Weekend", with: "# Weekend!")
        let next = EditMarks.revert(mark, original: opened, current: typedMore)
        XCTAssertEqual(next, opened.replacingOccurrences(of: "# Weekend", with: "# Weekend!"))
    }

    func testScenarioAnOutsideWriteIsMarkedAndRevertedLikeTyping() {
        // An agent rewrote a section on disk. The window reloaded the new text.
        let agent = replacing("Lunch at noon.\nWalk in the park.\n", with: "Brunch at eleven.\n")
        let marks = EditMarks.marks(from: opened, to: agent)
        XCTAssertEqual(marks, [EditMark(
            kind: .modified(11...11),
            original: ["Lunch at noon.", "Walk in the park."],
            current: ["Brunch at eleven."]
        )])
        XCTAssertEqual(EditMarks.revert(marks[0], original: opened, current: agent), opened)
    }

    func testScenarioEmptyingTheWholeFileCanBeReverted() {
        let marks = EditMarks.marks(from: opened, to: "")
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(EditMarks.revert(marks[0], original: opened, current: ""), opened)
    }

    func testScenarioAFileWithoutAFinalNewline() {
        let original = "alpha\nbeta"
        let edited = "alpha"
        let mark = EditMarks.marks(from: original, to: edited)[0]
        XCTAssertEqual(EditMarks.revert(mark, original: original, current: edited), original)
    }

    func testScenarioWindowsLineEndingsSurviveARevert() {
        let original = "# Title\r\n\r\none\r\ntwo\r\n"
        let edited = "# Title\r\n\r\ntwo\r\n"
        let mark = EditMarks.marks(from: original, to: edited)[0]
        XCTAssertEqual(EditMarks.revert(mark, original: original, current: edited), original)
    }

    func testScenarioAStaleAdditionNeverTakesOutAnotherAddition() {
        // Two one-line additions. The panel for the first is open, then that line is deleted by hand.
        let edited = opened
            .replacingOccurrences(of: "- Buy bread\n", with: "- Buy bread\n- Buy milk\n")
            .replacingOccurrences(of: "Walk in the park.\n", with: "Walk in the park.\nRead a book.\n")
        let stale = EditMarks.marks(from: opened, to: edited)[0]
        XCTAssertEqual(stale.current, ["- Buy milk"])
        let typed = edited.replacingOccurrences(of: "- Buy milk\n", with: "")
        XCTAssertNil(EditMarks.revert(stale, original: opened, current: typed))
    }

    func testScenarioAStaleAdditionStillRevertsAfterTypingAboveIt() {
        let edited = replacing("- Buy bread\n", with: "- Buy bread\n- Buy milk\n")
        let stale = EditMarks.marks(from: opened, to: edited)[0]
        let typed = edited.replacingOccurrences(of: "# Weekend\n", with: "# Weekend\nA new line.\n")
        XCTAssertEqual(
            EditMarks.revert(stale, original: opened, current: typed),
            opened.replacingOccurrences(of: "# Weekend\n", with: "# Weekend\nA new line.\n")
        )
    }

    func testScenarioAChangedLineTypedOverAgainStillReverts() {
        let edited = replacing("Lunch at noon.", with: "Lunch at one.")
        let stale = EditMarks.marks(from: opened, to: edited)[0]
        let typed = replacing("Lunch at noon.", with: "Lunch at two.")
        XCTAssertEqual(EditMarks.revert(stale, original: opened, current: typed), opened)
    }

    func testScenarioAStaleChangeNeverRevertsATwinChange() {
        // Two identical opened lines, both changed. The panel was for the first, which was then typed over.
        let twins = "- [ ] todo\nmiddle\n- [ ] todo\n"
        let edited = "- [x] todo\nmiddle\n- [x] done\n"
        let stale = EditMarks.marks(from: twins, to: edited)[0]
        let typed = "- [x] todo!\nmiddle\n- [x] done\n"
        XCTAssertNil(EditMarks.revert(stale, original: twins, current: typed))
    }

    func testScenarioClassicMacLineEndingsRevertLineByLine() {
        let original = "one\rtwo\rthree\r"
        let edited = "one\rTWO\rthree\r"
        let mark = EditMarks.marks(from: original, to: edited)[0]
        XCTAssertEqual(mark, EditMark(kind: .modified(2...2), original: ["two"], current: ["TWO"]))
        XCTAssertEqual(EditMarks.revert(mark, original: original, current: edited), original)
    }

    func testScenarioMixedLineEndingsAreLeftAsTheyWere() {
        let original = "one\r\ntwo\nthree\nfour\r\n"
        let edited = "one\r\ntwo\nfour\r\n"
        let mark = EditMarks.marks(from: original, to: edited)[0]
        // The restored line takes the ending of the line above it. Every other line keeps its own.
        XCTAssertEqual(EditMarks.revert(mark, original: original, current: edited), original)
    }

    func testScenarioTheEditorAppliesTheRevertAsOneSmallReplacement() {
        // In Text the revert goes through the editor, so ⌘Z can undo it.
        let edited = replacing("- Call the plumber\n", with: "")
        let mark = EditMarks.marks(from: opened, to: edited)[0]
        let next = EditMarks.revert(mark, original: opened, current: edited)!
        let edit = EditMarks.replacement(from: edited, to: next)
        // Pure insertion of one line's worth of text. Where it starts can shift along a shared prefix.
        XCTAssertEqual(edit.length, 0)
        XCTAssertEqual(edit.text.count, "- Call the plumber\n".count)
        let applied = (edited as NSString).replacingCharacters(
            in: NSRange(location: edit.location, length: edit.length),
            with: edit.text
        )
        XCTAssertEqual(applied, opened)
    }

    func testScenarioAccentsAndEmojiRevertIntact() {
        let original = "Café com pão 🍞\nAção\n"
        let edited = "Café com pão 🥐\n"
        var text = edited
        while let mark = EditMarks.marks(from: original, to: text).first,
              let next = EditMarks.revert(mark, original: original, current: text) {
            let edit = EditMarks.replacement(from: text, to: next)
            text = (text as NSString).replacingCharacters(
                in: NSRange(location: edit.location, length: edit.length),
                with: edit.text
            )
        }
        XCTAssertEqual(text, original)
    }
}
