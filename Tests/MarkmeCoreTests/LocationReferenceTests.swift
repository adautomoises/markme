import XCTest
@testable import MarkmeCore

final class LocationReferenceTests: XCTestCase {
    func testCaretUsesTheHeadingAboveAndASelectionUsesItsOwnLine() {
        let text = "# Title\n\nParagraph.\n"
        let headings = LocationReference.headingLines(in: text)
        XCTAssertEqual(headings, [1])
        XCTAssertEqual(LocationReference.line(caret: 3, selectionExtends: false, headings: headings), 1)
        XCTAssertEqual(LocationReference.line(caret: 3, selectionExtends: true, headings: headings), 3)
        XCTAssertEqual(LocationReference.line(caret: 0, selectionExtends: false, headings: []), 1)
    }

    func testHeadingsInsideFencesAndFrontMatterAreIgnored() {
        let text = """
        ---
        # comment
        title: Plan
        ---
        # Title

        ```
        # not a heading
        ```

        ## After
        """
        XCTAssertEqual(LocationReference.headingLines(in: text), [5, 11])
    }

    func testUnclosedLeadingRuleDoesNotHideHeadings() {
        XCTAssertEqual(LocationReference.headingLines(in: "---\n# Only slide\n"), [2])
    }

    func testFrontMatterCanEndWithDots() {
        let text = "---\ntitle: Plan\n...\n# Title\n"
        XCTAssertEqual(LocationReference.headingLines(in: text), [4])
    }

    func testReferenceIsRelativeToTheGitRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("markme-loc-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = docs.appendingPathComponent("plan.md")
        try Data("x".utf8).write(to: file)
        XCTAssertEqual(LocationReference.format(fileURL: file, line: 42), "docs/plan.md:42")
    }

    func testReferenceOutsideAGitRootIsAbsolute() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("markme-abs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("note.md")
        try Data("x".utf8).write(to: file)
        let reference = LocationReference.format(fileURL: file, line: 3)
        XCTAssertEqual(reference, file.standardizedFileURL.path + ":3")
    }
}
