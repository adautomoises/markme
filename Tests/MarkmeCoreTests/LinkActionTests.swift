import XCTest
@testable import MarkmeCore

final class LinkActionTests: XCTestCase {
    func testResolve() {
        let base = URL(fileURLWithPath: "/tmp/notas")
        XCTAssertEqual(LinkResolver.resolve(href: "https://example.com/a", baseDirectory: base), .browser(URL(string: "https://example.com/a")!))
        XCTAssertEqual(LinkResolver.resolve(href: "http://example.com", baseDirectory: base), .browser(URL(string: "http://example.com")!))
        XCTAssertEqual(LinkResolver.resolve(href: "#compras", baseDirectory: base), .anchor("compras"))
        XCTAssertEqual(LinkResolver.resolve(href: "guia.md", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/guia.md")))
        XCTAssertEqual(LinkResolver.resolve(href: "Guia.MD", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/Guia.MD")))
        XCTAssertEqual(LinkResolver.resolve(href: "sub/guia.mdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/sub/guia.mdown")))
        XCTAssertEqual(LinkResolver.resolve(href: "nota.markdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/nota.markdown")))
        XCTAssertEqual(LinkResolver.resolve(href: "a.mkd", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/a.mkd")))
        XCTAssertEqual(LinkResolver.resolve(href: "a.mdwn", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notas/a.mdwn")))
        XCTAssertEqual(LinkResolver.resolve(href: "mailto:a@b.c", baseDirectory: base), .ignore)
        XCTAssertEqual(LinkResolver.resolve(href: "javascript:alert(1)", baseDirectory: base), .ignore)
    }

    func testOnlyTheInitialDocumentLoadIsAllowed() {
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: false, requestIsInitialDocument: true), .allow)
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: true, requestIsInitialDocument: true), .cancel)
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: false, requestIsInitialDocument: false), .cancel)
    }
}
