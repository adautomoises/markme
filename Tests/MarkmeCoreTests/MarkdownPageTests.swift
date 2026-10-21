import XCTest
@testable import MarkmeCore

final class MarkdownPageTests: XCTestCase {
    func testEverydayMarkdown() {
        let source = """
        # House

        Text *italic* and **strong** and ~~old~~.

        - one
        - two

        1. first

        > quote

        `line`

        ---

        https://example.com
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("<h1"))
        XCTAssertTrue(html.contains("<em>"))
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<del>"))
        XCTAssertTrue(html.contains("<ul"))
        XCTAssertTrue(html.contains("<ol"))
        XCTAssertTrue(html.contains("<blockquote"))
        XCTAssertTrue(html.contains("<code>"))
        XCTAssertTrue(html.contains("<hr"))
        XCTAssertTrue(html.contains("https://example.com"))
    }

    func testTableTaskAndFootnoteBodySurvive() {
        let source = """
        | Item | Qty |
        | --- | --- |
        | Milk | 2 |

        - [x] cylinder
        - [ ] tank

        Text [^1].

        [^1]: Source

        ## After
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("<table"))
        XCTAssertTrue(html.contains("Milk"))
        XCTAssertTrue(html.contains("checkbox"))
        XCTAssertTrue(html.contains("Source"))
        XCTAssertTrue(html.contains("After"))
    }

    func testFencedCodeCarriesLanguageAndPlainFenceDoesNot() {
        let swift = MarkdownRenderer.render("```swift\nlet a = 1\n```").htmlBody
        XCTAssertTrue(swift.contains("language-swift"))
        let plain = MarkdownRenderer.render("```\nlet a = 1\n```").htmlBody
        XCTAssertFalse(plain.contains("language-"))
    }

    func testMermaidStaysACodeBlock() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```").htmlBody
        XCTAssertTrue(html.contains("language-mermaid"))
        XCTAssertFalse(html.contains("<svg"))
    }

    func testSourcePositionIsMarked() {
        let html = MarkdownRenderer.render("# House\n\nParagraph.\n").htmlBody
        XCTAssertTrue(html.contains("data-sourcepos=\"1:"))
    }

    func testHeadingGetsAnchorId() {
        let html = MarkdownRenderer.render("## Before leaving\n").htmlBody
        XCTAssertTrue(html.contains("id=\"before-leaving\""))
    }

    func testImageKeepsItsPathAsText() {
        let html = MarkdownRenderer.render("![](photos/plan.png)").htmlBody
        XCTAssertTrue(html.contains("photos/plan.png"))
        XCTAssertTrue(html.contains("alt=\"photos/plan.png\""))
    }

    func testDangerousHTMLIsStripped() {
        let html = MarkdownRenderer.render(
            "<script>alert(1)</script><ScRiPt>alert(2)</ScRiPt><p onclick=\"alert(3)\">hi</p><img src=\"a.png\" onerror=\"alert(4)\"><iframe src=\"https://evil.test\"></iframe><object data=\"x\"></object><embed src=\"y\"></embed><a href=\"javascript:alert(5)\">x</a><strong>bold</strong>text"
        ).htmlBody
        XCTAssertTrue(html.contains("hi"))
        XCTAssertTrue(html.contains("bold"))
        XCTAssertTrue(html.contains("text"))
        XCTAssertTrue(html.contains("a.png"))
        XCTAssertFalse(html.lowercased().contains("<script"))
        XCTAssertFalse(html.contains("alert(1)"))
        XCTAssertFalse(html.contains("alert(2)"))
        XCTAssertFalse(html.contains("onclick"))
        XCTAssertFalse(html.contains("onerror"))
        XCTAssertFalse(html.lowercased().contains("<iframe"))
        XCTAssertFalse(html.lowercased().contains("<object"))
        XCTAssertFalse(html.lowercased().contains("<embed"))
        XCTAssertFalse(html.lowercased().contains("javascript:"))
    }

    func testEventHandlersWithoutSpaceDoNotSurvive() {
        let glued = MarkdownRenderer.render("<div><img src=\"x\"onerror=\"alert(1)\"></div>").htmlBody
        XCTAssertFalse(glued.lowercased().contains("onerror"))
        XCTAssertFalse(glued.contains("alert(1)"))
        let slashed = MarkdownRenderer.render("<div><img/src=\"x\"/onerror=\"alert(1)\"></div>").htmlBody
        XCTAssertFalse(slashed.lowercased().contains("onerror"))
        XCTAssertFalse(slashed.contains("alert(1)"))
    }

    func testJavascriptLinksWithoutQuotesOrEntitiesDoNotSurvive() {
        let bare = MarkdownRenderer.render("<div><a href=javascript:alert(1)>x</a></div>").htmlBody
        XCTAssertTrue(bare.contains(">x<") || bare.contains(">x</a>"))
        XCTAssertFalse(bare.lowercased().contains("javascript:"))
        let entity = MarkdownRenderer.render("<a href=\"&#106;avascript:alert(1)\">y</a>").htmlBody
        XCTAssertTrue(entity.contains("y"))
        XCTAssertFalse(entity.lowercased().contains("javascript"))
        XCTAssertFalse(entity.contains("alert(1)"))
    }

    func testOrdinaryOnWordsStayInProseAndCode() {
        let prose = MarkdownRenderer.render("The value is one=1 and online=yes today.").htmlBody
        XCTAssertTrue(prose.contains("one=1"))
        XCTAssertTrue(prose.contains("online=yes"))
        let code = MarkdownRenderer.render("```\nonline=yes\none=1\nonly=true\n```").htmlBody
        XCTAssertTrue(code.contains("online=yes"))
        XCTAssertTrue(code.contains("one=1"))
        XCTAssertTrue(code.contains("only=true"))
    }

    func testMetaRefreshIsRemoved() {
        let html = MarkdownRenderer.render("<meta http-equiv=\"refresh\" content=\"0;url=https://example.com/\">").htmlBody
        XCTAssertFalse(html.lowercased().contains("<meta"))
        XCTAssertFalse(html.lowercased().contains("http-equiv"))
        XCTAssertFalse(html.contains("example.com"))
    }

    func testTaskCheckboxIsDisabled() {
        let html = MarkdownRenderer.render("- [ ] tank\n").htmlBody
        XCTAssertTrue(html.contains("disabled"))
    }

    func testThousandsOfLinesStillRenderTheEnd() {
        var lines = Array(repeating: "line", count: 5000)
        lines.append("## End")
        let html = MarkdownRenderer.render(lines.joined(separator: "\n")).htmlBody
        XCTAssertTrue(html.contains("End"))
    }
}
