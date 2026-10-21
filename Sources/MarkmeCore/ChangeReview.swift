import Foundation

public struct ChangeSpan: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Inclusive 1-based lines in the text after the change.
        case added(ClosedRange<Int>)
        /// Lines that disappeared. `afterLine` is the last surviving line before the gap. 0 means the gap is at the start.
        case removed(afterLine: Int, count: Int)
    }

    public var kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    /// The line to bring into view. A gap at the start focuses the first line.
    public var focusLine: Int {
        switch kind {
        case .added(let lines):
            return lines.lowerBound
        case .removed(let after, _):
            return max(after, 1)
        }
    }
}

public enum ChangeReview {
    public static func spans(from previous: String, to current: String) -> [ChangeSpan] {
        let oldLines = lines(previous)
        let newLines = lines(current)
        if oldLines == newLines { return [] }

        var removed: [Int] = []
        var inserted: [Int] = []
        for change in newLines.difference(from: oldLines) {
            switch change {
            case .remove(let offset, _, _):
                removed.append(offset)
            case .insert(let offset, _, _):
                inserted.append(offset)
            }
        }
        removed.sort()
        inserted.sort()
        let newLineOfOld = alignedNewLines(oldCount: oldLines.count, removed: Set(removed), inserted: Set(inserted))

        var spans: [ChangeSpan] = []
        var index = 0
        while index < removed.count {
            let start = removed[index]
            var end = start
            while index + 1 < removed.count, removed[index + 1] == end + 1 {
                index += 1
                end = removed[index]
            }
            let after = anchorLine(beforeOldIndex: start, newLineOfOld: newLineOfOld)
            spans.append(ChangeSpan(kind: .removed(afterLine: after, count: end - start + 1)))
            index += 1
        }

        index = 0
        while index < inserted.count {
            let start = inserted[index]
            var end = start
            while index + 1 < inserted.count, inserted[index + 1] == end + 1 {
                index += 1
                end = inserted[index]
            }
            spans.append(ChangeSpan(kind: .added((start + 1)...(end + 1))))
            index += 1
        }

        spans.sort { sortKey($0) < sortKey($1) }
        return spans
    }

    /// UTF-16 range of inclusive 1-based lines, including the trailing newline when one is present.
    public static func utf16Range(of lines: ClosedRange<Int>, in text: String) -> NSRange? {
        guard lines.lowerBound >= 1, lines.upperBound >= lines.lowerBound else { return nil }
        let ns = text as NSString
        var line = 1
        var index = 0
        var start: Int?
        while index <= ns.length {
            if line == lines.lowerBound, start == nil {
                start = index
            }
            if line == lines.upperBound, let start {
                var end = index
                while end < ns.length {
                    let unit = ns.character(at: end)
                    end += 1
                    if unit == 10 { break }
                }
                return NSRange(location: start, length: end - start)
            }
            if index >= ns.length { break }
            if ns.character(at: index) == 10 { line += 1 }
            index += 1
        }
        return nil
    }

    /// Marks added blocks and inserts a paragraph where lines were removed.
    /// An empty span list returns `html` unchanged.
    public static func annotate(
        html: String,
        spans: [ChangeSpan],
        selected: Int?,
        removedLabel: (Int) -> String
    ) -> String {
        guard !spans.isEmpty else { return html }
        guard let regex = try? NSRegularExpression(
            pattern: #"<[A-Za-z][^>]*data-sourcepos="(\d+):\d+-(\d+):\d+"[^>]*>"#
        ) else { return html }

        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        let hits: [TagHit] = matches.compactMap { match in
            guard let range = Range(match.range, in: html),
                  let startRange = Range(match.range(at: 1), in: html),
                  let endRange = Range(match.range(at: 2), in: html),
                  let start = Int(html[startRange]),
                  let end = Int(html[endRange]) else { return nil }
            return TagHit(range: range, startLine: start, endLine: end)
        }

        var insertions: [Int: [Int]] = [:]
        var trailing: [Int] = []
        for (spanIndex, span) in spans.enumerated() {
            guard case .removed(let after, _) = span.kind else { continue }
            if let hitIndex = hits.firstIndex(where: { $0.startLine > after }) {
                insertions[hitIndex, default: []].append(spanIndex)
            } else {
                trailing.append(spanIndex)
            }
        }

        var result = ""
        var cursor = html.startIndex
        for (hitIndex, hit) in hits.enumerated() {
            result += html[cursor..<hit.range.lowerBound]
            for spanIndex in insertions[hitIndex] ?? [] {
                result += marker(spanIndex, spans: spans, selected: selected, removedLabel: removedLabel)
            }
            result += opening(String(html[hit.range]), hit: hit, hitIndex: hitIndex, hits: hits, spans: spans, selected: selected)
            cursor = hit.range.upperBound
        }
        result += html[cursor...]
        for spanIndex in trailing {
            result += marker(spanIndex, spans: spans, selected: selected, removedLabel: removedLabel)
        }
        return result
    }

    private struct TagHit {
        var range: Range<String.Index>
        var startLine: Int
        var endLine: Int
    }

    private static func lines(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.isEmpty { return [] }
        var parts = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if normalized.hasSuffix("\n"), parts.last?.isEmpty == true {
            parts.removeLast()
        }
        return parts
    }

    /// 0-based index in the new text for each surviving old line.
    private static func alignedNewLines(oldCount: Int, removed: Set<Int>, inserted: Set<Int>) -> [Int?] {
        var mapped = [Int?](repeating: nil, count: oldCount)
        var oldIndex = 0
        var newIndex = 0
        let newCount = oldCount - removed.count + inserted.count
        while oldIndex < oldCount || newIndex < newCount {
            if oldIndex < oldCount, removed.contains(oldIndex) {
                oldIndex += 1
                continue
            }
            if newIndex < newCount, inserted.contains(newIndex) {
                newIndex += 1
                continue
            }
            if oldIndex < oldCount, newIndex < newCount {
                mapped[oldIndex] = newIndex
                oldIndex += 1
                newIndex += 1
                continue
            }
            break
        }
        return mapped
    }

    private static func anchorLine(beforeOldIndex oldIndex: Int, newLineOfOld: [Int?]) -> Int {
        var index = oldIndex - 1
        while index >= 0 {
            if let newIndex = newLineOfOld[index] {
                return newIndex + 1
            }
            index -= 1
        }
        return 0
    }

    private static func sortKey(_ span: ChangeSpan) -> (Int, Int) {
        switch span.kind {
        case .removed(let after, _):
            return (after, 0)
        case .added(let lines):
            return (lines.lowerBound, 1)
        }
    }

    private static func overlaps(_ hit: TagHit, lines: ClosedRange<Int>) -> Bool {
        lines.lowerBound <= hit.endLine && hit.startLine <= lines.upperBound
    }

    private static func firstHit(overlapping spanIndex: Int, spans: [ChangeSpan], hits: [TagHit]) -> Int? {
        guard case .added(let lines) = spans[spanIndex].kind else { return nil }
        return hits.firstIndex { overlaps($0, lines: lines) }
    }

    private static func opening(
        _ tag: String,
        hit: TagHit,
        hitIndex: Int,
        hits: [TagHit],
        spans: [ChangeSpan],
        selected: Int?
    ) -> String {
        let overlapping = spans.enumerated().compactMap { index, span -> Int? in
            guard case .added(let lines) = span.kind, overlaps(hit, lines: lines) else { return nil }
            return index
        }
        guard let change = overlapping.first else { return tag }
        var classes = ["change-added"]
        if let selected, overlapping.contains(selected), firstHit(overlapping: selected, spans: spans, hits: hits) == hitIndex {
            classes.append("change-current")
        }
        return tagByAdding(classes: classes, change: change, to: tag)
    }

    private static func tagByAdding(classes: [String], change: Int, to tag: String) -> String {
        guard tag.hasSuffix(">") else { return tag }
        var result = String(tag.dropLast())
        let addition = classes.joined(separator: " ")
        if let classStart = result.range(of: "class=\"") {
            let value = result.index(classStart.upperBound, offsetBy: 0)
            result.insert(contentsOf: addition + " ", at: value)
        } else {
            result += " class=\"\(addition)\""
        }
        result += " data-change=\"\(change)\">"
        return result
    }

    private static func marker(
        _ spanIndex: Int,
        spans: [ChangeSpan],
        selected: Int?,
        removedLabel: (Int) -> String
    ) -> String {
        guard case .removed(_, let count) = spans[spanIndex].kind else { return "" }
        var classes = "change-removed"
        if selected == spanIndex {
            classes += " change-current"
        }
        let label = escape(removedLabel(count))
        return "<p class=\"\(classes)\" data-change=\"\(spanIndex)\">\(label)</p>"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
