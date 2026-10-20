import XCTest
@testable import MarkmeCore

final class ReaderModelTests: XCTestCase {
    func testNewModelOpensOnPage() {
        let model = ReaderModel(fileName: "a.md", data: Data("olá".utf8), bannerDismissed: false)
        XCTAssertEqual(model.mode, .page)
        XCTAssertEqual(model.text, "olá")
        XCTAssertNil(model.failure)
        XCTAssertTrue(model.showsBanner)
    }

    func testEmptyFileIsABlankDocument() {
        let model = ReaderModel(fileName: "a.md", data: Data(), bannerDismissed: true)
        XCTAssertEqual(model.text, "")
        XCTAssertNil(model.failure)
        XCTAssertFalse(model.showsBanner)
    }

    func testNotUTF8() {
        let model = ReaderModel(fileName: "a.md", data: Data([0xFF, 0xFE]), bannerDismissed: true)
        XCTAssertEqual(model.failure, .notUTF8)
    }

    func testMissingFile() {
        let model = ReaderModel(fileName: "a.md", data: nil, bannerDismissed: true)
        XCTAssertEqual(model.failure, .unreadable)
    }

    func testReloadKeepsMode() {
        var model = ReaderModel(fileName: "a.md", data: Data("antes".utf8), bannerDismissed: true)
        model.mode = .source
        model.reload(data: Data("depois".utf8))
        XCTAssertEqual(model.mode, .source)
        XCTAssertEqual(model.text, "depois")
        XCTAssertNil(model.failure)
        model.reload(data: nil, failureDetail: "Permissão negada")
        XCTAssertEqual(model.mode, .source)
        XCTAssertEqual(model.text, "depois")
        XCTAssertEqual(model.failure, .unreadable)
        XCTAssertEqual(model.failureDetail, "Permissão negada")
    }

    func testReloadOfInvalidUTF8KeepsTheText() {
        var model = ReaderModel(fileName: "a.md", data: Data("ainda aqui".utf8), bannerDismissed: true)
        model.reload(data: Data([0xFF, 0xFE]))
        XCTAssertEqual(model.failure, .notUTF8)
        XCTAssertEqual(model.text, "ainda aqui")
    }

    func testDismissBannerStaysDismissed() {
        var model = ReaderModel(fileName: "a.md", data: Data(), bannerDismissed: false)
        model.dismissBannerForever()
        XCTAssertFalse(model.showsBanner)
    }

    func testSplitClampsTo240() {
        var split = SplitFraction()
        XCTAssertEqual(split.fraction, 0.5)
        split.drag(translation: -400, width: 1000)
        XCTAssertEqual(split.fraction, 0.24, accuracy: 0.001)
        split.drag(translation: 800, width: 1000)
        XCTAssertEqual(split.fraction, 0.76, accuracy: 0.001)
    }

    func testFindIsLiteralAndCaseInsensitive() {
        let text = "casa CASA a.b"
        XCTAssertEqual(TextFind.ranges(of: "", in: text).count, 0)
        XCTAssertEqual(TextFind.ranges(of: "casa", in: text).count, 2)
        XCTAssertEqual(TextFind.ranges(of: "a.b", in: text).count, 1)
        XCTAssertEqual(TextFind.ranges(of: "a.", in: "abc").count, 0)
    }

    func testEchoLock() {
        var sync = ScrollSync()
        let now = Date(timeIntervalSince1970: 1_000)
        sync.markEcho(now: now)
        XCTAssertTrue(sync.isEcho(now: now.addingTimeInterval(0.05)))
        XCTAssertFalse(sync.isEcho(now: now.addingTimeInterval(ScrollSync.echoInterval)))
    }

    func testSourceCannotBeEdited() {
        XCTAssertFalse(SourceTextConfiguration.isEditable)
        XCTAssertTrue(SourceTextConfiguration.isSelectable)
    }
}
