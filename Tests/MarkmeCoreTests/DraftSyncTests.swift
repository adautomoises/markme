import XCTest
@testable import MarkmeCore

final class DraftSyncTests: XCTestCase {
    func testAMatchingDiskIsIgnored() {
        var sync = DraftSync(saved: "a")
        XCTAssertEqual(sync.receive(disk: "a", buffer: "a"), .same)
        XCTAssertFalse(sync.saveIsBlocked)
        XCTAssertEqual(sync.saved, "a")
    }

    func testACleanBufferReloadsAnOutsideEdit() {
        var sync = DraftSync(saved: "a")
        XCTAssertEqual(sync.receive(disk: "b", buffer: "a"), .reload)
        XCTAssertEqual(sync.saved, "b")
        XCTAssertFalse(sync.saveIsBlocked)
    }

    func testAnUnfinishedSentenceHoldsTheOutsideEdit() {
        var sync = DraftSync(saved: "a")
        XCTAssertEqual(sync.receive(disk: "from agent", buffer: "a!"), .conflict)
        XCTAssertTrue(sync.saveIsBlocked)
        XCTAssertEqual(sync.saved, "a")
        XCTAssertEqual(sync.heldDisk, "from agent")
        XCTAssertEqual(sync.receive(disk: "from agent 2", buffer: "a!!"), .conflict)
        XCTAssertEqual(sync.heldDisk, "from agent 2")
    }

    func testOurWriteDoesNotReloadAndALaterKeyIsNotAConflict() {
        var sync = DraftSync(saved: "a")
        sync.willWrite("ab")
        sync.didWrite("ab")
        XCTAssertEqual(sync.saved, "ab")
        XCTAssertEqual(sync.receive(disk: "ab", buffer: "abc"), .continued)
        XCTAssertEqual(sync.saved, "ab")
        XCTAssertFalse(sync.saveIsBlocked)
        XCTAssertNil(sync.echoedWrite)
    }

    func testAFailedWriteCanBeRetried() {
        var sync = DraftSync(saved: "a")
        sync.willWrite("ab")
        sync.failWrite("ab")
        XCTAssertNil(sync.pendingWrite)
        XCTAssertEqual(sync.receive(disk: "a", buffer: "ab"), .conflict)
        sync.keepMine()
        XCTAssertFalse(sync.saveIsBlocked)
        XCTAssertEqual(sync.saved, "a")
    }

    func testKeepMineAndTakeDisk() {
        var sync = DraftSync(saved: "a")
        XCTAssertEqual(sync.receive(disk: "disk", buffer: "mine"), .conflict)
        sync.keepMine()
        XCTAssertFalse(sync.saveIsBlocked)
        XCTAssertNil(sync.takeDisk())

        XCTAssertEqual(sync.receive(disk: "disk", buffer: "mine"), .conflict)
        XCTAssertEqual(sync.takeDisk(), "disk")
        XCTAssertEqual(sync.saved, "disk")
        XCTAssertFalse(sync.saveIsBlocked)
        XCTAssertNil(sync.takeDisk())
    }

    func testSaveDelayIsAShortPause() {
        XCTAssertEqual(DraftSync.saveDelay, 0.5, accuracy: 0.001)
    }
}
