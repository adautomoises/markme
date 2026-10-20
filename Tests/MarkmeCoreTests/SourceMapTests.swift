import XCTest
@testable import MarkmeCore

final class SourceMapTests: XCTestCase {
    func testMap() {
        let html = "<h1 data-sourcepos=\"1:1-1:5\">A</h1><p data-sourcepos=\"4:1-5:3\">B</p>"
        let blocks = SourceMap.blocks(in: html)
        XCTAssertEqual(blocks.map(\.startLine), [1, 4])
        XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 1, blocks: blocks), 0)
        XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 3, blocks: blocks), 0)
        XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 5, blocks: blocks), 1)
        XCTAssertEqual(SourceMap.sourceLine(forBlockIndex: 1, blocks: blocks), 4)
        XCTAssertNil(SourceMap.blockIndex(forSourceLine: 0, blocks: blocks))
    }
}
