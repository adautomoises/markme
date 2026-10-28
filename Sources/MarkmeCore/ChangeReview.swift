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

    /// Marks the tightest block for each new line and inserts a marker where lines were removed.
    /// An empty span list returns `html` unchanged. A fence gets one anchor per changed line.
    public static func annotate(
        html: String,
        spans: [ChangeSpan],
        selected: Int?,
        removedLabel: (Int) -> String
    ) -> String {
        guard !spans.isEmpty else { return html }
        let hits = tagHits(in: html)
        var edits: [Edit] = []

        for (spanIndex, span) in spans.enumerated() {
            guard case .removed = span.kind else { continue }
            let place = removalPlacement(of: span, hits: hits, html: html)
            edits.append(Edit(
                start: place.index,
                end: place.index,
                text: marker(
                    spanIndex,
                    spans: spans,
                    selected: selected,
                    removedLabel: removedLabel,
                    element: place.element
                ),
                order: spanIndex
            ))
        }

        var wrappedFences = Set<Int>()
        for hitIndex in hits.indices where hits[hitIndex].name == "pre" {
            let added = tightAddedIndexes(hitIndex: hitIndex, hits: hits, spans: spans)
            guard !added.isEmpty, let body = fenceBody(in: html, pre: hits[hitIndex]) else { continue }
            let wrapped = wrapFenceLines(
                body.text,
                contentStart: body.contentStart,
                spans: spans,
                selected: selected
            )
            guard wrapped.didMark else { continue }
            edits.append(Edit(
                start: body.range.lowerBound,
                end: body.range.upperBound,
                text: wrapped.text,
                order: 0
            ))
            wrappedFences.insert(hitIndex)
        }

        for hitIndex in hits.indices where !wrappedFences.contains(hitIndex) {
            let added = tightAddedIndexes(hitIndex: hitIndex, hits: hits, spans: spans)
            guard !added.isEmpty else { continue }
            var classes = ["change-added"]
            if let selected, added.contains(selected), firstTightHit(for: selected, hits: hits, spans: spans) == hitIndex {
                classes.append("change-current")
            }
            edits.append(Edit(
                start: hits[hitIndex].range.lowerBound,
                end: hits[hitIndex].range.upperBound,
                text: tagByAdding(classes: classes, changes: added, to: String(html[hits[hitIndex].range])),
                order: 10_000 + hitIndex
            ))
        }

        return apply(edits, to: html)
    }

    private struct TagHit {
        var range: Range<String.Index>
        var startLine: Int
        var endLine: Int
        var name: String
    }

    private struct Edit {
        var start: String.Index
        var end: String.Index
        var text: String
        var order: Int
    }

    private struct RemovalPlace {
        var index: String.Index
        var element: String
    }

    private struct FenceBody {
        var range: Range<String.Index>
        var text: String
        var contentStart: Int
    }

    /// Table and fence markup cannot hold the removal pill. It goes after that whole block.
    private static let blockedNames: Set<String> = [
        "table", "thead", "tbody", "tfoot", "tr", "td", "th", "pre", "code"
    ]
    private static let voidNames: Set<String> = ["br", "hr", "img", "input"]

    static func lines(_ text: String) -> [String] {
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

    private static func tagHits(in html: String) -> [TagHit] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<([A-Za-z][A-Za-z0-9]*)[^>]*data-sourcepos="(\d+):\d+-(\d+):\d+"[^>]*>"#
        ) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard let range = Range(match.range, in: html),
                  let nameRange = Range(match.range(at: 1), in: html),
                  let startRange = Range(match.range(at: 2), in: html),
                  let endRange = Range(match.range(at: 3), in: html),
                  let start = Int(html[startRange]),
                  let end = Int(html[endRange]) else { return nil }
            return TagHit(
                range: range,
                startLine: start,
                endLine: end,
                name: String(html[nameRange]).lowercased()
            )
        }
    }

    private static func removalPlacement(of span: ChangeSpan, hits: [TagHit], html: String) -> RemovalPlace {
        let after: Int
        if case .removed(let afterLine, _) = span.kind {
            after = afterLine
        } else {
            after = 0
        }
        if after <= 0 {
            return RemovalPlace(index: html.startIndex, element: "p")
        }
        if let tight = tightestIndex(containing: after, hits: hits) {
            let target = blockedRoot(of: tight, hits: hits) ?? tight
            let element = target == tight && hits[tight].name == "li" ? "li" : "p"
            return RemovalPlace(
                index: endOfElement(named: hits[target].name, opening: hits[target].range, in: html),
                element: element
            )
        }
        if let next = hits.indices.first(where: { isTopLevel($0, hits: hits) && hits[$0].startLine > after }) {
            return RemovalPlace(index: hits[next].range.lowerBound, element: "p")
        }
        return RemovalPlace(index: html.endIndex, element: "p")
    }

    /// The table or fence that contains `hitIndex`, when the pill cannot sit inside it.
    private static func blockedRoot(of hitIndex: Int, hits: [TagHit]) -> Int? {
        let involved = hits.enumerated().filter { index, hit in
            blockedNames.contains(hit.name) && (index == hitIndex || contains(hit, hits[hitIndex]))
        }
        return involved.max { lhs, rhs in
            let left = lhs.element.endLine - lhs.element.startLine
            let right = rhs.element.endLine - rhs.element.startLine
            if left != right { return left < right }
            return lhs.offset > rhs.offset
        }?.offset
    }

    private static func contains(_ outer: TagHit, _ inner: TagHit) -> Bool {
        let covers = outer.startLine <= inner.startLine && outer.endLine >= inner.endLine
        let larger = outer.startLine < inner.startLine || outer.endLine > inner.endLine
        let earlier = outer.range.lowerBound < inner.range.lowerBound
        return covers && (larger || (earlier && outer.startLine == inner.startLine && outer.endLine == inner.endLine))
    }

    private static func isTighter(_ inner: TagHit, than outer: TagHit) -> Bool {
        let inside = inner.startLine >= outer.startLine && inner.endLine <= outer.endLine
        guard inside else { return false }
        if inner.startLine > outer.startLine || inner.endLine < outer.endLine { return true }
        return inner.range.lowerBound > outer.range.lowerBound
    }

    private static func tightestIndex(containing line: Int, hits: [TagHit]) -> Int? {
        var best: Int?
        for index in hits.indices {
            let hit = hits[index]
            guard line >= hit.startLine, line <= hit.endLine else { continue }
            if let best, !isTighter(hit, than: hits[best]) { continue }
            best = index
        }
        return best
    }

    private static func isTopLevel(_ index: Int, hits: [TagHit]) -> Bool {
        !hits.enumerated().contains { other, hit in
            other != index && contains(hit, hits[index])
        }
    }

    private static func isTightest(_ hitIndex: Int, for lines: ClosedRange<Int>, hits: [TagHit]) -> Bool {
        let hit = hits[hitIndex]
        guard overlaps(hit, lines: lines) else { return false }
        for otherIndex in hits.indices where otherIndex != hitIndex {
            guard overlaps(hits[otherIndex], lines: lines) else { continue }
            if isTighter(hits[otherIndex], than: hit) { return false }
        }
        return true
    }

    private static func tightAddedIndexes(hitIndex: Int, hits: [TagHit], spans: [ChangeSpan]) -> [Int] {
        spans.enumerated().compactMap { index, span in
            guard case .added(let lines) = span.kind, isTightest(hitIndex, for: lines, hits: hits) else { return nil }
            return index
        }
    }

    private static func firstTightHit(for spanIndex: Int, hits: [TagHit], spans: [ChangeSpan]) -> Int? {
        guard case .added(let lines) = spans[spanIndex].kind else { return nil }
        return hits.indices.first { isTightest($0, for: lines, hits: hits) }
    }

    private static func endOfElement(named name: String, opening: Range<String.Index>, in html: String) -> String.Index {
        let wanted = name.lowercased()
        if voidNames.contains(wanted) { return opening.upperBound }
        var depth = 1
        var index = opening.upperBound
        while index < html.endIndex {
            guard let bracket = html[index...].firstIndex(of: "<") else { break }
            let next = html.index(after: bracket)
            guard next < html.endIndex else { break }
            let isClose = html[next] == "/"
            let nameStart = isClose ? html.index(after: next) : next
            guard nameStart < html.endIndex else { break }
            var nameEnd = nameStart
            while nameEnd < html.endIndex {
                let character = html[nameEnd]
                if character.isLetter || character.isNumber {
                    nameEnd = html.index(after: nameEnd)
                } else {
                    break
                }
            }
            guard let close = html[nameEnd...].firstIndex(of: ">") else { break }
            if html[nameStart..<nameEnd].lowercased() == wanted {
                if isClose {
                    depth -= 1
                    if depth == 0 { return html.index(after: close) }
                } else if html[html.index(before: close)] != "/" {
                    depth += 1
                }
            }
            index = html.index(after: close)
        }
        return html.endIndex
    }

    private static func fenceBody(in html: String, pre: TagHit) -> FenceBody? {
        guard let codeStart = html[pre.range.upperBound...].range(of: "<code")?.lowerBound,
              let openEnd = html[codeStart...].firstIndex(of: ">"),
              let close = html[html.index(after: openEnd)...].range(of: "</code>") else { return nil }
        let bodyStart = html.index(after: openEnd)
        let text = String(html[bodyStart..<close.lowerBound])
        var parts = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if text.hasSuffix("\n"), parts.last?.isEmpty == true {
            parts.removeLast()
        }
        let span = pre.endLine - pre.startLine + 1
        let lead = parts.count < span ? (span - parts.count) / 2 : 0
        return FenceBody(range: bodyStart..<close.lowerBound, text: text, contentStart: pre.startLine + lead)
    }

    private static func wrapFenceLines(
        _ text: String,
        contentStart: Int,
        spans: [ChangeSpan],
        selected: Int?
    ) -> (text: String, didMark: Bool) {
        let trailingNewline = text.hasSuffix("\n")
        var parts = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if trailingNewline, parts.last?.isEmpty == true {
            parts.removeLast()
        }
        var didMark = false
        let wrapped = parts.enumerated().map { offset, line in
            let sourceLine = contentStart + offset
            guard let change = spans.firstIndex(where: { span in
                if case .added(let lines) = span.kind { return lines.contains(sourceLine) }
                return false
            }) else { return line }
            didMark = true
            var classes = "change-added"
            if selected == change { classes += " change-current" }
            return "<span class=\"\(classes)\" data-change=\"\(change)\" data-sourcepos=\"\(sourceLine):1-\(sourceLine):1\">\(line)</span>"
        }
        var joined = wrapped.joined(separator: "\n")
        if trailingNewline { joined += "\n" }
        return (joined, didMark)
    }

    private static func apply(_ edits: [Edit], to html: String) -> String {
        let ordered = edits.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.order < rhs.order
        }
        var result = ""
        var cursor = html.startIndex
        for edit in ordered {
            guard edit.start >= cursor else { continue }
            result += html[cursor..<edit.start]
            result += edit.text
            cursor = edit.end
        }
        result += html[cursor...]
        return result
    }

    private static func tagByAdding(classes: [String], changes: [Int], to tag: String) -> String {
        guard tag.hasSuffix(">"), let first = changes.first else { return tag }
        var result = String(tag.dropLast())
        let addition = classes.joined(separator: " ")
        if let classStart = result.range(of: "class=\"") {
            result.insert(contentsOf: addition + " ", at: classStart.upperBound)
        } else {
            result += " class=\"\(addition)\""
        }
        result += " data-change=\"\(first)\""
        if changes.count > 1 {
            result += " data-changes=\"\(changes.map(String.init).joined(separator: " "))\""
        }
        result += ">"
        return result
    }

    private static func marker(
        _ spanIndex: Int,
        spans: [ChangeSpan],
        selected: Int?,
        removedLabel: (Int) -> String,
        element: String
    ) -> String {
        guard case .removed(_, let count) = spans[spanIndex].kind else { return "" }
        let name = element == "li" ? "li" : "p"
        var classes = "change-removed"
        if selected == spanIndex {
            classes += " change-current"
        }
        let label = escape(removedLabel(count))
        return "<\(name) class=\"\(classes)\" data-change=\"\(spanIndex)\">\(label)</\(name)>"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
