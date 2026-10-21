import XCTest
@testable import MarkmeCore

final class AgentMarkdownTests: XCTestCase {
    func testGitHubAlertShowsTheLabelAndKeepsTheBody() {
        let source = """
        > [!NOTE]
        > The pump is on.

        > [!WARNING]
        > Close the valve.

        > A plain quote.
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("class=\"alert alert-note\""), html)
        XCTAssertTrue(html.contains("class=\"alert-title\">Note<"), html)
        XCTAssertTrue(html.contains("The pump is on."), html)
        XCTAssertFalse(html.contains("[!NOTE]"), html)
        XCTAssertTrue(html.contains("class=\"alert alert-warning\""), html)
        XCTAssertTrue(html.contains(">Warning<"), html)
        XCTAssertTrue(html.contains("A plain quote."), html)
        XCTAssertEqual(html.components(separatedBy: "alert alert-").count - 1, 2, html)
        let portuguese = MarkdownRenderer.render("> [!TIP]\n> Bring a lamp.\n", languageCode: "pt-BR").htmlBody
        XCTAssertTrue(portuguese.contains(">Dica<"), portuguese)
        XCTAssertTrue(portuguese.contains("alert-tip"), portuguese)
    }

    func testEveryAlertKindHasABlock() {
        let source = """
        > [!IMPORTANT]
        > Read this.

        > [!CAUTION]
        > Stop.
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("alert-important"), html)
        XCTAssertTrue(html.contains(">Important<"), html)
        XCTAssertTrue(html.contains("alert-caution"), html)
        XCTAssertTrue(html.contains(">Caution<"), html)
        XCTAssertTrue(html.contains("Read this."), html)
        XCTAssertTrue(html.contains("Stop."), html)
    }

    func testFrontMatterShowsTitleAndStatusAndHidesTheRest() {
        let source = """
        ---
        title: Filter notes
        status: "draft"
        owner: the house
        ---

        # Body
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("class=\"front-title\""), html)
        XCTAssertTrue(html.contains("Filter notes"), html)
        XCTAssertTrue(html.contains("data-sourcepos=\"2:1-2:1\""), html)
        XCTAssertTrue(html.contains("class=\"front-status\""), html)
        XCTAssertTrue(html.contains(">draft<"), html)
        XCTAssertFalse(html.contains("the house"), html)
        XCTAssertFalse(html.contains("owner:"), html)
        XCTAssertTrue(html.contains(">Body<"), html)
        XCTAssertTrue(html.contains("data-sourcepos=\"7:"), html)
    }

    func testUnclosedLeadingRuleStaysARule() {
        let html = MarkdownRenderer.render("---\n# Only slide\n").htmlBody
        XCTAssertFalse(html.contains("front-title"), html)
        XCTAssertTrue(html.contains(">Only slide<"), html)
    }

    func testFrontMatterValuesAreEscaped() {
        let source = "---\ntitle: <script>\nstatus: a & b\n---\n\nText\n"
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertFalse(html.contains("<script>"), html)
        XCTAssertTrue(html.contains("&lt;script&gt;"), html)
        XCTAssertTrue(html.contains("a &amp; b"), html)
    }

    func testWikilinkOpensAFileInTheFolderOrOneLevelDown() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("markme-wiki-\(UUID().uuidString)")
        let nested = root.appendingPathComponent("notes")
        let deeper = nested.appendingPathComponent("deep")
        try FileManager.default.createDirectory(at: deeper, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("# Here\n".utf8).write(to: root.appendingPathComponent("Plan.md"))
        try Data("# Child\n".utf8).write(to: nested.appendingPathComponent("lamp.md"))
        try Data("# Too deep\n".utf8).write(to: deeper.appendingPathComponent("hidden-note.md"))
        let source = "See [[plan]] and [[lamp|the lamp]]. Also [[missing]] and [[hidden-note]]. `[[plan]]`\n\n```\n[[plan]]\n```\n"
        let html = MarkdownRenderer.render(source, baseDirectory: root).htmlBody
        XCTAssertTrue(html.contains("href=\"Plan.md\""), html)
        XCTAssertTrue(html.contains(">plan<") || html.contains(">Plan.md<") || html.contains(">plan</a>"), html)
        XCTAssertTrue(html.contains("href=\"notes/lamp.md\""), html)
        XCTAssertTrue(html.contains(">the lamp<"), html)
        XCTAssertTrue(html.contains("[[missing]]") || html.contains("missing"), html)
        XCTAssertFalse(html.contains("hidden-note.md"), html)
        XCTAssertTrue(html.contains("<code>[[plan]]</code>") || html.contains("[[plan]]"), html)
    }

    func testWikilinkInTheSameFolderWinsOverAChild() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("markme-wiki-\(UUID().uuidString)")
        let nested = root.appendingPathComponent("notes")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("a".utf8).write(to: root.appendingPathComponent("plan.md"))
        try Data("b".utf8).write(to: nested.appendingPathComponent("plan.md"))
        let html = MarkdownRenderer.render("[[plan]]\n", baseDirectory: root).htmlBody
        XCTAssertTrue(html.contains("href=\"plan.md\""), html)
        XCTAssertFalse(html.contains("notes/plan.md"), html)
    }
}
