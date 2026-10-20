import XCTest
@testable import MarkmeCore

final class MarkdownPageTests: XCTestCase {
    func testEverydayMarkdown() {
        let source = """
        # Casa

        Texto *itálico* e **forte** e ~~velho~~.

        - um
        - dois

        1. primeiro

        > citação

        `linha`

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
        | Item | Qtd |
        | --- | --- |
        | Leite | 2 |

        - [x] botija
        - [ ] caixa

        Texto [^1].

        [^1]: Origem

        ## Depois
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("<table"))
        XCTAssertTrue(html.contains("Leite"))
        XCTAssertTrue(html.contains("checkbox"))
        XCTAssertTrue(html.contains("Origem"))
        XCTAssertTrue(html.contains("Depois"))
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
        let html = MarkdownRenderer.render("# Casa\n\nParágrafo.\n").htmlBody
        XCTAssertTrue(html.contains("data-sourcepos=\"1:"))
    }

    func testImageKeepsItsPathAsText() {
        let html = MarkdownRenderer.render("![](fotos/planta.png)").htmlBody
        XCTAssertTrue(html.contains("fotos/planta.png"))
        XCTAssertTrue(html.contains("alt=\"fotos/planta.png\""))
    }

    func testThousandsOfLinesStillRenderTheEnd() {
        var lines = Array(repeating: "linha", count: 5000)
        lines.append("## Fim")
        let html = MarkdownRenderer.render(lines.joined(separator: "\n")).htmlBody
        XCTAssertTrue(html.contains("Fim"))
    }
}
