import XCTest
@testable import MarkmeCore

final class PageShellTests: XCTestCase {
    func testShellContract() {
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
    }
}
