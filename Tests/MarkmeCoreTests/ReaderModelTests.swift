import XCTest
@testable import MarkmeCore

final class ReaderModelTests: XCTestCase {
    func testNewModelOpensOnPage() {
        let model = ReaderModel(fileName: "a.md", data: Data("hello".utf8), bannerDismissed: false)
        XCTAssertEqual(model.mode, .page)
        XCTAssertEqual(model.text, "hello")
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
        var model = ReaderModel(fileName: "a.md", data: Data("before".utf8), bannerDismissed: true)
        model.mode = .source
        model.reload(data: Data("after".utf8))
        XCTAssertEqual(model.mode, .source)
        XCTAssertEqual(model.text, "after")
        XCTAssertNil(model.failure)
        model.reload(data: nil, failureDetail: "Permission denied")
        XCTAssertEqual(model.mode, .source)
        XCTAssertEqual(model.text, "after")
        XCTAssertEqual(model.failure, .unreadable)
        XCTAssertEqual(model.failureDetail, "Permission denied")
    }

    func testReloadArmsAReviewWithoutMarkingUntilTheDiffIsReady() {
        var model = ReaderModel(fileName: "a.md", data: Data("before".utf8), bannerDismissed: true)
        XCTAssertNil(model.changeBaseline)
        XCTAssertEqual(model.changeRevision, 0)
        model.reload(data: Data("after".utf8))
        XCTAssertEqual(model.changeBaseline, "before")
        XCTAssertEqual(model.changeRevision, 1)
        XCTAssertTrue(model.changes.isEmpty)
        model.reload(data: Data("after".utf8))
        XCTAssertEqual(model.changeRevision, 1)
        model.reload(data: Data("later".utf8))
        XCTAssertEqual(model.changeBaseline, "before")
        XCTAssertEqual(model.text, "later")
        XCTAssertEqual(model.changeRevision, 2)
        let spans = [
            ChangeSpan(kind: .removed(afterLine: 0, count: 1)),
            ChangeSpan(kind: .added(1...1))
        ]
        model.adoptChanges(spans, revision: 2)
        XCTAssertEqual(model.changes, spans)
        XCTAssertEqual(model.changeCursor, 0)
        XCTAssertNil(model.changeBaseline)
        model.stepChange(by: 1)
        XCTAssertEqual(model.changeCursor, 1)
        model.stepChange(by: 1)
        XCTAssertEqual(model.changeCursor, 0)
        model.stepChange(by: -1)
        XCTAssertEqual(model.changeCursor, 1)
        model.dismissChanges()
        XCTAssertTrue(model.changes.isEmpty)
        XCTAssertNil(model.changeCursor)
        XCTAssertEqual(model.changeRevision, 3)
        model.adoptChanges(spans, revision: 2)
        XCTAssertTrue(model.changes.isEmpty)
    }

    func testReloadClearsMarksFromThePreviousDiff() {
        var model = ReaderModel(fileName: "a.md", data: Data("before".utf8), bannerDismissed: true)
        model.reload(data: Data("after".utf8))
        let spans = [ChangeSpan(kind: .added(1...1))]
        model.adoptChanges(spans, revision: 1)
        XCTAssertEqual(model.changes, spans)
        model.reload(data: Data("later".utf8))
        XCTAssertTrue(model.changes.isEmpty)
        XCTAssertNil(model.changeCursor)
        XCTAssertEqual(model.changeBaseline, "after")
        XCTAssertEqual(model.text, "later")
        XCTAssertEqual(model.changeRevision, 2)
    }

    func testFailedReloadDoesNotArmAReview() {
        var model = ReaderModel(fileName: "a.md", data: Data("before".utf8), bannerDismissed: true)
        model.reload(data: nil, failureDetail: "Permission denied")
        XCTAssertNil(model.changeBaseline)
        XCTAssertEqual(model.changeRevision, 0)
        XCTAssertEqual(model.text, "before")
    }

    func testReloadOfInvalidUTF8KeepsTheText() {
        var model = ReaderModel(fileName: "a.md", data: Data("still here".utf8), bannerDismissed: true)
        model.reload(data: Data([0xFF, 0xFE]))
        XCTAssertEqual(model.failure, .notUTF8)
        XCTAssertEqual(model.text, "still here")
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

    func testZoomStepsStayBetweenHalfAndTriple() {
        var zoom = ReaderZoom()
        XCTAssertEqual(zoom.factor, 1, accuracy: 0.001)
        zoom.apply(.zoomIn)
        XCTAssertEqual(zoom.factor, 1.1, accuracy: 0.001)
        zoom.apply(.zoomOut)
        zoom.apply(.zoomOut)
        XCTAssertEqual(zoom.factor, 0.9, accuracy: 0.001)
        zoom.apply(.actualSize)
        XCTAssertEqual(zoom.factor, 1, accuracy: 0.001)
        XCTAssertEqual(SourceTextConfiguration.fontSize(zoom: zoom.factor), 13, accuracy: 0.001)
        for _ in 0..<40 { zoom.apply(.zoomIn) }
        XCTAssertEqual(zoom.factor, 3, accuracy: 0.001)
        XCTAssertEqual(SourceTextConfiguration.fontSize(zoom: zoom.factor), 39, accuracy: 0.001)
        for _ in 0..<40 { zoom.apply(.zoomOut) }
        XCTAssertEqual(zoom.factor, 0.5, accuracy: 0.001)
        XCTAssertEqual(SourceTextConfiguration.fontSize(zoom: zoom.factor), 6.5, accuracy: 0.001)
    }

    func testCommandWheelNotchZoomsOneStepAndTrackpadAccumulates() {
        var wheel = WheelZoom()
        XCTAssertEqual(wheel.actions(deltaY: 1, precise: false), [.zoomIn])
        XCTAssertEqual(wheel.actions(deltaY: -1, precise: false), [.zoomOut])
        XCTAssertEqual(wheel.actions(deltaY: 0, precise: false), [])
        XCTAssertEqual(wheel.actions(deltaY: 47, precise: true), [])
        XCTAssertEqual(wheel.actions(deltaY: 1, precise: true), [.zoomIn])
        XCTAssertEqual(wheel.remainder, 0, accuracy: 0.001)
        XCTAssertEqual(wheel.actions(deltaY: -30, precise: true), [])
        XCTAssertEqual(wheel.actions(deltaY: -20, precise: true), [.zoomOut])
        XCTAssertEqual(wheel.actions(deltaY: 100, precise: true), [.zoomIn, .zoomIn])
        XCTAssertEqual(wheel.remainder, 2, accuracy: 0.001)
        wheel.endGesture()
        XCTAssertEqual(wheel.remainder, 0, accuracy: 0.001)
        XCTAssertEqual(wheel.actions(deltaY: 10, precise: true), [])
    }

    func testEchoLock() {
        var sync = ScrollSync()
        let now = Date(timeIntervalSince1970: 1_000)
        sync.markEcho(now: now)
        XCTAssertTrue(sync.isEcho(now: now.addingTimeInterval(0.05)))
        XCTAssertFalse(sync.isEcho(now: now.addingTimeInterval(ScrollSync.echoInterval)))
    }

    func testSourceIsPlainMarkdown() {
        XCTAssertTrue(SourceTextConfiguration.isEditable)
        XCTAssertTrue(SourceTextConfiguration.isSelectable)
    }

    func testPresentationKeepsTheToolbarVisibleUntilFullscreenStarts() {
        let entering = PresentationChromePlanner.plan(presenting: true, fullscreen: false, enteredByUs: false)
        XCTAssertFalse(entering.hideToolbar)
        XCTAssertTrue(entering.toggleFullscreen)
        XCTAssertTrue(entering.enteredByUs)

        let inside = PresentationChromePlanner.plan(presenting: true, fullscreen: true, enteredByUs: true)
        XCTAssertTrue(inside.hideToolbar)
        XCTAssertFalse(inside.toggleFullscreen)
        XCTAssertTrue(inside.enteredByUs)

        let alreadyFullscreen = PresentationChromePlanner.plan(presenting: true, fullscreen: true, enteredByUs: false)
        XCTAssertTrue(alreadyFullscreen.hideToolbar)
        XCTAssertFalse(alreadyFullscreen.toggleFullscreen)
        XCTAssertFalse(alreadyFullscreen.enteredByUs)
    }

    func testLeavingPresentationShowsTheToolbarAndLeavesOnlyOurFullscreen() {
        let leaving = PresentationChromePlanner.plan(presenting: false, fullscreen: true, enteredByUs: true)
        XCTAssertFalse(leaving.hideToolbar)
        XCTAssertTrue(leaving.toggleFullscreen)
        XCTAssertFalse(leaving.enteredByUs)

        let beforeFullscreen = PresentationChromePlanner.plan(presenting: false, fullscreen: false, enteredByUs: true)
        XCTAssertFalse(beforeFullscreen.hideToolbar)
        XCTAssertFalse(beforeFullscreen.toggleFullscreen)

        let usersOwnFullscreen = PresentationChromePlanner.plan(presenting: false, fullscreen: true, enteredByUs: false)
        XCTAssertFalse(usersOwnFullscreen.hideToolbar)
        XCTAssertFalse(usersOwnFullscreen.toggleFullscreen)
        XCTAssertFalse(usersOwnFullscreen.enteredByUs)
    }
}
