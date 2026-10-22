import XCTest
@testable import MarkmeCore

final class PageShellTests: XCTestCase {
    func testShellContract() throws {
        let html = PageShell.html(body: "<p>oi</p>", highlighter: "HIGHLIGHTJS")
        XCTAssertTrue(html.contains("<p>oi</p>"))
        XCTAssertTrue(html.contains("HIGHLIGHTJS"))
        XCTAssertTrue(html.contains("hljs.highlightAll"))
        XCTAssertTrue(html.contains("max-width: 68ch"))
        XCTAssertTrue(html.contains("-apple-system"))
        XCTAssertTrue(html.contains("ui-monospace"))
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
        XCTAssertTrue(html.contains("user-select: text"))
        XCTAssertTrue(html.contains("pointer-events: none"))
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("script-src 'unsafe-inline'"))
        XCTAssertTrue(html.contains("img-src file: https: http: data:"))
        XCTAssertFalse(html.contains("script-src 'self'"))
        XCTAssertTrue(html.contains(".hljs-keyword"))
        XCTAssertTrue(html.contains(".hljs-string"))
        XCTAssertTrue(html.contains(".hljs-comment"))
        XCTAssertTrue(html.contains("registerLanguage(\"gherkin\""))
        XCTAssertTrue(html.contains("Dado|Dada|Dados|Dadas|Quando|Então|Entao|Mas|Given|When|Then|And|But|E"))
        XCTAssertTrue(html.contains(".language-gherkin .hljs-keyword"))
        XCTAssertTrue(html.contains("#d1242f"))
        XCTAssertTrue(html.contains("#1f75cb"))
        XCTAssertTrue(html.contains(".hljs-meta"))
        XCTAssertTrue(html.contains(".hljs-title.class_"))
        XCTAssertTrue(html.contains("window.markmePresent"))
        XCTAssertTrue(html.contains("window.markmeSlide"))
        XCTAssertTrue(html.contains("window.markmeShowChange"))
        XCTAssertTrue(html.contains("data-changes"))
        XCTAssertTrue(html.contains(".feature-map"))
        XCTAssertTrue(html.contains(".feature-part"))
        XCTAssertTrue(html.contains(".change-added"))
        XCTAssertTrue(html.contains(".change-removed"))
        XCTAssertTrue(html.contains("body.presenting"))
        XCTAssertFalse(html.contains("mermaid.run"))
        XCTAssertFalse(html.contains("securityLevel"))
        let article = try XCTUnwrap(html.range(of: "<article>"))
        let script = try XCTUnwrap(html.range(of: "<script>"))
        XCTAssertLessThan(article.lowerBound, script.lowerBound)
    }

    func testMermaidRendersOnlyWhenTheLibraryIsPassed() {
        let html = PageShell.html(body: "<p>oi</p>", highlighter: "HIGHLIGHTJS", mermaid: "MERMAIDLIB")
        XCTAssertTrue(html.contains("MERMAIDLIB"))
        XCTAssertTrue(html.contains("securityLevel: \"strict\""))
        XCTAssertTrue(html.contains("startOnLoad: false"))
        XCTAssertTrue(html.contains("mermaid.run"))
        XCTAssertTrue(html.contains("language-mermaid"))
    }

    func testMermaidFenceDetectionIgnoresProseAndOtherLanguages() {
        XCTAssertTrue(PageShell.containsMermaidFence("```mermaid\ngraph TD\n```"))
        XCTAssertTrue(PageShell.containsMermaidFence("~~~\nno\n~~~\n\n~~~mermaid\nA-->B\n~~~"))
        XCTAssertTrue(PageShell.containsMermaidFence("   ```mermaid\ngraph TD\n   ```"))
        XCTAssertFalse(PageShell.containsMermaidFence("    ```mermaid\ngraph TD\n    ```"))
        XCTAssertFalse(PageShell.containsMermaidFence("```mermaidx\ngraph TD\n```"))
        XCTAssertFalse(PageShell.containsMermaidFence("The word mermaid stays in the prose.\n\n```swift\nlet mermaid = 1\n```"))
    }

    func testDartGrammarCoversFlutter() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("App/Resources/dart.js"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("registerLanguage(\"dart\""))
        XCTAssertTrue(source.contains("aliases: [\"flutter\"]"))
        XCTAssertTrue(source.contains("StatelessWidget"))
        XCTAssertTrue(source.contains("BuildContext"))
        XCTAssertTrue(source.contains("@[A-Za-z]+"))
    }
}
