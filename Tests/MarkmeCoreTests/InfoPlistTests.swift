import XCTest

final class InfoPlistTests: XCTestCase {
    func testInfoPlistDeclaresAReadOnlyMarkdownViewer() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "app.markme.viewer")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "AppIcon")
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "14.0")
        let types = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        let type = try XCTUnwrap(types.first)
        XCTAssertEqual(type["CFBundleTypeRole"] as? String, "Viewer")
        XCTAssertEqual(type["LSHandlerRank"] as? String, "Owner")
        let extensions = try XCTUnwrap(type["CFBundleTypeExtensions"] as? [String])
        XCTAssertEqual(Set(extensions), Set(["md", "markdown", "mdown", "mkd", "mdwn"]))
        let ats = try XCTUnwrap(plist["NSAppTransportSecurity"] as? [String: Any])
        XCTAssertEqual(ats["NSAllowsArbitraryLoadsInWebContent"] as? Bool, true)
    }
}
