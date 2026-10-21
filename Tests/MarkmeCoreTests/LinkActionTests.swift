import XCTest
@testable import MarkmeCore

final class LinkActionTests: XCTestCase {
    func testResolve() {
        let base = URL(fileURLWithPath: "/tmp/notes")
        XCTAssertEqual(LinkResolver.resolve(href: "https://example.com/a", baseDirectory: base), .browser(URL(string: "https://example.com/a")!))
        XCTAssertEqual(LinkResolver.resolve(href: "http://example.com", baseDirectory: base), .browser(URL(string: "http://example.com")!))
        XCTAssertEqual(LinkResolver.resolve(href: "#shopping", baseDirectory: base), .anchor("shopping"))
        XCTAssertEqual(LinkResolver.resolve(href: "guide.md", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/guide.md")))
        XCTAssertEqual(LinkResolver.resolve(href: "Guide.MD", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/Guide.MD")))
        XCTAssertEqual(LinkResolver.resolve(href: "sub/guide.mdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/sub/guide.mdown")))
        XCTAssertEqual(LinkResolver.resolve(href: "note.markdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/note.markdown")))
        XCTAssertEqual(LinkResolver.resolve(href: "a.mkd", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/a.mkd")))
        XCTAssertEqual(LinkResolver.resolve(href: "a.mdwn", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/a.mdwn")))
        XCTAssertEqual(LinkResolver.resolve(href: "mailto:a@b.c", baseDirectory: base), .ignore)
        XCTAssertEqual(LinkResolver.resolve(href: "javascript:alert(1)", baseDirectory: base), .ignore)
        XCTAssertEqual(
            LinkResolver.resolve(href: "my%20plan.md", baseDirectory: base),
            .markdownFile(URL(fileURLWithPath: "/tmp/notes/my plan.md"))
        )
    }

    func testOnlyTheInitialDocumentLoadIsAllowed() {
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: false, requestIsInitialDocument: true), .allow)
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: true, requestIsInitialDocument: true), .cancel)
        XCTAssertEqual(DocumentLoadPolicy.decide(isLinkActivation: false, requestIsInitialDocument: false), .cancel)
    }
}
