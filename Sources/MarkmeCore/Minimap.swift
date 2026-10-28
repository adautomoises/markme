import Foundation

/// One row of the minimap: where the ink starts, how far it runs, and what kind of line it is.
public struct MinimapLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case blank
        case heading
        case fence
        case quote
        case text
    }

    public var indent: Int
    public var length: Int
    public var kind: Kind

    public init(indent: Int, length: Int, kind: Kind) {
        self.indent = indent
        self.length = length
        self.kind = kind
    }
}

/// A difference between the text on screen and the text the window opened with.
public struct EditMark: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Inclusive 1-based lines that did not exist when the window opened.
        case added(ClosedRange<Int>)
        /// Inclusive 1-based lines that replaced lines of the opened text.
        case modified(ClosedRange<Int>)
        /// Lines that are gone. `afterLine` is the last surviving line before the gap. 0 means the top.
        case removed(afterLine: Int, count: Int)
    }

    public var kind: Kind
    /// The lines of the opened text that this mark replaced or removed. Empty for an addition.
    public var original: [String]
    /// The lines an addition or a modification put in. Empty for a removal.
    /// A stale mark is matched by its text, so it can never take out a different change of the same size.
    public var current: [String]

    public init(kind: Kind, original: [String] = [], current: [String] = []) {
        self.kind = kind
        self.original = original
        self.current = current
    }

    /// The line to bring into view. A gap at the start focuses the first line.
    public var focusLine: Int {
        switch kind {
        case .added(let lines), .modified(let lines):
            return lines.lowerBound
        case .removed(let after, _):
            return max(after, 1)
        }
    }
}

/// Per-line lookup of edit marks, for a gutter that draws one line at a time.
public struct EditGutter: Equatable, Sendable {
    public enum Line: Equatable, Sendable {
        case added
        case modified
    }

    public private(set) var lines: [Int: Line] = [:]
    /// Index in the mark list for each added or modified line.
    public private(set) var markOfLine: [Int: Int] = [:]
    /// Index in the mark list for each gap, keyed by the line above it. 0 is the top.
    public private(set) var markOfGap: [Int: Int] = [:]

    public var removedAfter: Set<Int> { Set(markOfGap.keys) }

    public init() {}

    public init(_ marks: [EditMark]) {
        for (index, mark) in marks.enumerated() {
            switch mark.kind {
            case .added(let range):
                for line in range {
                    lines[line] = .added
                    markOfLine[line] = index
                }
            case .modified(let range):
                for line in range {
                    lines[line] = .modified
                    markOfLine[line] = index
                }
            case .removed(let after, _):
                markOfGap[after] = index
            }
        }
    }

    /// The mark a click on `line` means: the line itself, then a gap right below it, then a gap right above it.
    public func mark(nearLine line: Int) -> Int? {
        markOfLine[line] ?? markOfGap[line] ?? markOfGap[line - 1]
    }
}

public enum EditMarks {
    /// Marks from `original` to `current`. Lines removed and added at the same place are one modification.
    public static func marks(from original: String, to current: String) -> [EditMark] {
        let old = ChangeReview.lines(original)
        let new = ChangeReview.lines(current)
        if old == new { return [] }

        // Lines shared at the start and the end never need the diff.
        var head = 0
        while head < old.count, head < new.count, old[head] == new[head] {
            head += 1
        }
        var tail = 0
        while tail < old.count - head, tail < new.count - head, old[old.count - 1 - tail] == new[new.count - 1 - tail] {
            tail += 1
        }
        let oldEnd = old.count - tail
        let newEnd = new.count - tail

        if isTooCostly(old[head..<oldEnd], new[head..<newEnd]) {
            return [block(gone: Array(old[head..<oldEnd]), put: Array(new[head..<newEnd]), at: head)]
        }

        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in new[head..<newEnd].difference(from: old[head..<oldEnd]) {
            switch change {
            case .remove(let offset, _, _): removed.insert(head + offset)
            case .insert(let offset, _, _): inserted.insert(head + offset)
            }
        }

        var marks: [EditMark] = []
        var oldIndex = head
        var newIndex = head
        while oldIndex < oldEnd || newIndex < newEnd {
            let removing = oldIndex < oldEnd && removed.contains(oldIndex)
            let inserting = newIndex < newEnd && inserted.contains(newIndex)
            guard removing || inserting else {
                oldIndex += 1
                newIndex += 1
                continue
            }
            let start = newIndex
            var gone: [String] = []
            var moved = true
            while moved {
                moved = false
                while oldIndex < oldEnd, removed.contains(oldIndex) {
                    gone.append(old[oldIndex])
                    oldIndex += 1
                    moved = true
                }
                while newIndex < newEnd, inserted.contains(newIndex) {
                    newIndex += 1
                    moved = true
                }
            }
            marks.append(block(gone: gone, put: Array(new[start..<newIndex]), at: start))
        }
        return marks
    }

    /// Above this much work the diff would stall typing. The changed middle becomes one mark instead.
    /// About 100 ms in a release build. A 5,000-line file with 1,000 lines changed still gets every mark.
    static let diffBudget = 20_000_000

    /// The diff costs about (old + new) × (lines that differ). Lines that differ are at least
    /// old + new − 2 × (lines the two sides share), so a rewrite is caught before the diff runs.
    static func isTooCostly(_ old: ArraySlice<String>, _ new: ArraySlice<String>) -> Bool {
        let size = old.count + new.count
        guard size > 0 else { return false }
        var pool: [String: Int] = [:]
        for line in old { pool[line, default: 0] += 1 }
        var shared = 0
        for line in new {
            if let left = pool[line], left > 0 {
                pool[line] = left - 1
                shared += 1
            }
        }
        return size * (size - 2 * shared) > diffBudget
    }

    /// One mark for `gone` opened lines replaced by `put` lines, starting after line `at` of the text now.
    private static func block(gone: [String], put: [String], at start: Int) -> EditMark {
        if put.isEmpty {
            return EditMark(kind: .removed(afterLine: start, count: gone.count), original: gone)
        }
        let lines = (start + 1)...(start + put.count)
        if gone.isEmpty {
            return EditMark(kind: .added(lines), current: put)
        }
        return EditMark(kind: .modified(lines), original: gone, current: put)
    }

    /// Inclusive 1-based lines of `text`, clamped to the text.
    public static func lines(_ range: ClosedRange<Int>, in text: String) -> [String] {
        let all = ChangeReview.lines(text)
        return Array(all[clamped(range, count: all.count)])
    }

    /// The text after reverting `mark`, or nil when the text no longer has that change.
    ///
    /// The mark may come from a render that trails the typing, or from before another revert moved its lines.
    /// It is matched against the marks of the text as it is now: the same mark, else the same kind of change
    /// with the same opened lines, nearest to where it was.
    public static func revert(_ mark: EditMark, original: String, current: String) -> String? {
        guard let fresh = locate(mark, in: marks(from: original, to: current)) else { return nil }
        let next = reverted(fresh, in: current)
        return next == current ? nil : next
    }

    public static func locate(_ mark: EditMark, in fresh: [EditMark]) -> EditMark? {
        if fresh.contains(mark) { return mark }
        let sameChange = fresh.filter { sameKind($0, mark) && $0.original == mark.original }
        let exact = sameChange.filter { $0.current == mark.current }
        if !exact.isEmpty {
            return exact.min { abs($0.focusLine - mark.focusLine) < abs($1.focusLine - mark.focusLine) }
        }
        // A modification typed over again is still the change of those opened lines, but only when no other
        // change replaced the same lines. An addition has no opened lines, so it must match by its text.
        if case .modified = mark.kind, sameChange.count == 1 {
            return sameChange[0]
        }
        return nil
    }

    private static func sameKind(_ lhs: EditMark, _ rhs: EditMark) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case (.added(let a), .added(let b)): return a.count == b.count
        case (.modified(let a), .modified(let b)): return a.count == b.count
        case (.removed(_, let a), .removed(_, let b)): return a == b
        default: return false
        }
    }

    /// `text` with one mark put back the way the window opened it. Other marks stay.
    public static func reverted(_ mark: EditMark, in text: String) -> String {
        // Lines are counted the way the marks count them: "\r\n", "\r", and "\n" each end a line.
        // Every untouched line keeps its own ending, so a file with mixed endings is not rewritten.
        var parts = terminatedLines(text)
        let ending = parts.first { !$0.end.isEmpty }?.end ?? "\n"
        // An emptied file has no line ending left to copy. Markdown files end with one.
        let trailing = parts.last.map { !$0.end.isEmpty } ?? true
        // Restored lines take the ending of the line next to them.
        func restored(near index: Int) -> [(line: String, end: String)] {
            let nearby = parts.indices.contains(index) ? parts[index].end : ""
            return mark.original.map { (line: $0, end: nearby.isEmpty ? ending : nearby) }
        }
        switch mark.kind {
        case .added(let lines):
            parts.removeSubrange(clamped(lines, count: parts.count))
        case .modified(let lines):
            let range = clamped(lines, count: parts.count)
            parts.replaceSubrange(range, with: restored(near: range.isEmpty ? range.lowerBound - 1 : range.upperBound - 1))
        case .removed(let after, _):
            let at = min(max(after, 0), parts.count)
            parts.insert(contentsOf: restored(near: at > 0 ? at - 1 : 0), at: at)
        }
        guard let last = parts.indices.last else { return "" }
        for index in parts.indices.dropLast() where parts[index].end.isEmpty {
            parts[index].end = ending
        }
        parts[last].end = trailing ? (parts[last].end.isEmpty ? ending : parts[last].end) : ""
        return parts.map { $0.line + $0.end }.joined()
    }

    /// Each line of `text` with the ending that closed it. The last line's ending is empty when the file has none.
    private static func terminatedLines(_ text: String) -> [(line: String, end: String)] {
        // Swift reads "\r\n" as one Character, so walk the scalars.
        let scalars = Array(text.unicodeScalars)
        var parts: [(line: String, end: String)] = []
        var start = 0
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            guard scalar == "\n" || scalar == "\r" else {
                index += 1
                continue
            }
            let crlf = scalar == "\r" && index + 1 < scalars.count && scalars[index + 1] == "\n"
            var line = String.UnicodeScalarView()
            line.append(contentsOf: scalars[start..<index])
            parts.append((line: String(line), end: crlf ? "\r\n" : String(scalar)))
            index += crlf ? 2 : 1
            start = index
        }
        if start < scalars.count {
            var line = String.UnicodeScalarView()
            line.append(contentsOf: scalars[start...])
            parts.append((line: String(line), end: ""))
        }
        return parts
    }

    /// The smallest UTF-16 replacement that turns `old` into `new`, so an editor can apply it as one undoable step.
    public static func replacement(from old: String, to new: String) -> TextReplacement {
        let a = Array(old.utf16)
        let b = Array(new.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] {
            prefix += 1
        }
        if prefix > 0, UTF16.isLeadSurrogate(a[prefix - 1]) {
            prefix -= 1
        }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] {
            suffix += 1
        }
        if suffix > 0, UTF16.isTrailSurrogate(a[a.count - suffix]) {
            suffix -= 1
        }
        let inserted = String(decoding: b[prefix..<(b.count - suffix)], as: UTF16.self)
        return TextReplacement(location: prefix, length: a.count - suffix - prefix, text: inserted)
    }

    private static func clamped(_ lines: ClosedRange<Int>, count: Int) -> Range<Int> {
        let lower = min(max(lines.lowerBound - 1, 0), count)
        let upper = min(max(lines.upperBound, lower), count)
        return lower..<upper
    }

    public static func counts(_ marks: [EditMark]) -> (added: Int, modified: Int, removed: Int) {
        var added = 0
        var modified = 0
        var removed = 0
        for mark in marks {
            switch mark.kind {
            case .added(let lines): added += lines.count
            case .modified(let lines): modified += lines.count
            case .removed(_, let count): removed += count
            }
        }
        return (added, modified, removed)
    }
}

/// Line numbers in UTF-16 text, counted the way the marks count them: "\r\n", "\r", and "\n" each end a line.
public enum LineBreaks {
    /// The 1-based line that holds `offset`.
    public static func line(at offset: Int, in text: NSString) -> Int {
        let end = min(max(offset, 0), text.length)
        var line = 1
        var index = 0
        while index < end {
            let unit = text.character(at: index)
            if unit == 10 || (unit == 13 && !(index + 1 < text.length && text.character(at: index + 1) == 10)) {
                line += 1
            }
            index += 1
        }
        return line
    }

    /// The UTF-16 offset where the 1-based `line` starts, or the end of the text.
    public static func offset(ofLine line: Int, in text: NSString) -> Int {
        var current = 1
        var index = 0
        while current < line, index < text.length {
            let unit = text.character(at: index)
            index += 1
            if unit == 13, index < text.length, text.character(at: index) == 10 {
                index += 1
            }
            if unit == 10 || unit == 13 { current += 1 }
        }
        return index
    }

    /// Whether the unit at `index` ends a line.
    public static func isBreak(at index: Int, in text: NSString) -> Bool {
        guard index >= 0, index < text.length else { return false }
        let unit = text.character(at: index)
        return unit == 10 || unit == 13
    }
}

/// One edit to a text, in UTF-16 units.
public struct TextReplacement: Equatable, Sendable {
    public var location: Int
    public var length: Int
    public var text: String

    public init(location: Int, length: Int, text: String) {
        self.location = location
        self.length = length
        self.text = text
    }
}

public enum Minimap {
    public static let tabWidth = 4
    public static let maximumLength = 200

    public static func lines(in text: String) -> [MinimapLine] {
        var inFence = false
        var fenceMarker = ""
        return ChangeReview.lines(text).map { line in
            var indent = 0
            var start = line.startIndex
            while start < line.endIndex, line[start] == " " || line[start] == "\t" {
                indent += line[start] == "\t" ? tabWidth : 1
                start = line.index(after: start)
            }
            let body = line[start...].trimmingCharacters(in: .whitespaces)
            let length = min(body.count, maximumLength)
            if let marker = fenceOpening(body) {
                if !inFence {
                    inFence = true
                    fenceMarker = marker
                } else if body.hasPrefix(fenceMarker), body.trimmingCharacters(in: CharacterSet(charactersIn: "`~")).isEmpty {
                    inFence = false
                }
                return MinimapLine(indent: indent, length: length, kind: .fence)
            }
            if inFence {
                return MinimapLine(indent: indent, length: length, kind: body.isEmpty ? .blank : .fence)
            }
            if body.isEmpty {
                return MinimapLine(indent: 0, length: 0, kind: .blank)
            }
            if body.hasPrefix("#"), indent < 4 {
                let level = body.prefix { $0 == "#" }.count
                let rest = body.dropFirst(level)
                if level <= 6, rest.isEmpty || rest.first == " " {
                    return MinimapLine(indent: indent, length: length, kind: .heading)
                }
            }
            if body.hasPrefix(">") {
                return MinimapLine(indent: indent, length: length, kind: .quote)
            }
            return MinimapLine(indent: indent, length: length, kind: .text)
        }
    }

    private static func fenceOpening(_ body: String) -> String? {
        for character in ["`", "~"] {
            let run = body.prefix { String($0) == character }.count
            if run >= 3 { return String(repeating: character, count: run) }
        }
        return nil
    }
}

/// Maps source lines onto a minimap of a given height. Every line fits; a row is never taller than `maximumRowHeight`.
public struct MinimapScale: Equatable, Sendable {
    public static let maximumRowHeight: CGFloat = 3

    public var lineCount: Int
    public var height: CGFloat

    public init(lineCount: Int, height: CGFloat) {
        self.lineCount = max(lineCount, 1)
        self.height = max(height, 0)
    }

    public var rowHeight: CGFloat {
        min(Self.maximumRowHeight, height / CGFloat(lineCount))
    }

    /// Top edge of a 1-based line.
    public func y(ofLine line: Int) -> CGFloat {
        CGFloat(max(line, 1) - 1) * rowHeight
    }

    /// The 1-based line under `y`, clamped to the document.
    public func line(atY y: CGFloat) -> Int {
        guard rowHeight > 0 else { return 1 }
        let line = Int((y / rowHeight).rounded(.down)) + 1
        return min(max(line, 1), lineCount)
    }

    /// The top line to show so the line under `y` sits in the middle of a viewport `visibleLines` tall.
    public func jumpLine(atY y: CGFloat, visibleLines: Int) -> Int {
        max(line(atY: y) - max(visibleLines, 1) / 2, 1)
    }
}
