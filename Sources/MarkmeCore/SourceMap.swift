import Foundation

public struct SourceBlock: Equatable, Sendable {
    public var startLine: Int
    public var endLine: Int

    public init(startLine: Int, endLine: Int) {
        self.startLine = startLine
        self.endLine = endLine
    }
}

public enum SourceMap {
    public static func blocks(in html: String) -> [SourceBlock] {
        guard let regex = try? NSRegularExpression(pattern: #"data-sourcepos="(\d+):\d+-(\d+):\d+""#) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let startRange = Range(match.range(at: 1), in: html),
                  let endRange = Range(match.range(at: 2), in: html),
                  let start = Int(html[startRange]),
                  let end = Int(html[endRange]) else { return nil }
            return SourceBlock(startLine: start, endLine: end)
        }
    }

    public static func blockIndex(forSourceLine line: Int, blocks: [SourceBlock]) -> Int? {
        var found: Int?
        for (index, block) in blocks.enumerated() where block.startLine <= line {
            found = index
        }
        return found
    }

    public static func sourceLine(forBlockIndex index: Int, blocks: [SourceBlock]) -> Int? {
        guard blocks.indices.contains(index) else { return nil }
        return blocks[index].startLine
    }
}
