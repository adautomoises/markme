import Foundation

enum AlertBlock {
    private static let kinds = ["note", "tip", "important", "warning", "caution"]

    /// Turns a blockquote that starts with `[!NOTE]` (and the other four) into a labeled block.
    static func apply(html: String, languageCode: String) -> String {
        var output = ""
        var cursor = html.startIndex
        while cursor < html.endIndex {
            guard let start = html.range(of: "<blockquote", range: cursor..<html.endIndex)?.lowerBound else {
                output.append(contentsOf: html[cursor...])
                break
            }
            output.append(contentsOf: html[cursor..<start])
            guard let end = matchingClose(html, from: start) else {
                output.append(contentsOf: html[start...])
                break
            }
            output.append(transform(String(html[start..<end]), languageCode: languageCode))
            cursor = end
        }
        return output
    }

    private static func transform(_ block: String, languageCode: String) -> String {
        guard let openEnd = block.firstIndex(of: ">"),
              block.hasSuffix("</blockquote>") else { return block }
        let open = String(block[...openEnd])
        let innerStart = block.index(after: openEnd)
        let innerEnd = block.index(block.endIndex, offsetBy: -("</blockquote>".count))
        let inner = apply(html: String(block[innerStart..<innerEnd]), languageCode: languageCode)
        guard let kind = kindAtStart(of: inner) else { return open + inner + "</blockquote>" }
        let cleaned = dropEmptyParagraphs(removingMarker(kind, from: inner))
        let title = "<p class=\"alert-title\">\(escape(label(kind, languageCode: languageCode)))</p>"
        return addClass(open, kind: kind) + title + cleaned + "</blockquote>"
    }

    private static func kindAtStart(of html: String) -> String? {
        let text = plainText(html).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        for kind in kinds {
            if lower.hasPrefix("[!\(kind)]") { return kind }
        }
        return nil
    }

    private static func removingMarker(_ kind: String, from html: String) -> String {
        let token = "[!\(kind)]"
        var output = ""
        var cursor = html.startIndex
        var removed = false
        var inTag = false
        while cursor < html.endIndex {
            let character = html[cursor]
            if character == "<" { inTag = true }
            if !removed, !inTag, html[cursor...].lowercased().hasPrefix(token) {
                cursor = html.index(cursor, offsetBy: token.count)
                // The marker line stays in the paragraph. Page selection counts
                // newlines from data-sourcepos, which still starts on that line.
                // A marker sharing its line (`[!NOTE] text`) drops one leading space.
                if cursor < html.endIndex, html[cursor] == " " {
                    cursor = html.index(after: cursor)
                }
                removed = true
                continue
            }
            output.append(character)
            if character == ">" { inTag = false }
            cursor = html.index(after: cursor)
        }
        return output
    }

    private static func dropEmptyParagraphs(_ html: String) -> String {
        var output = ""
        var cursor = html.startIndex
        while cursor < html.endIndex {
            guard let start = html.range(of: "<p", range: cursor..<html.endIndex)?.lowerBound else {
                output.append(contentsOf: html[cursor...])
                break
            }
            output.append(contentsOf: html[cursor..<start])
            guard let end = matchingParagraph(html, from: start) else {
                output.append(contentsOf: html[start...])
                break
            }
            let paragraph = String(html[start..<end])
            if plainText(paragraph).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !hasInnerElement(paragraph) {
                cursor = end
                continue
            }
            output.append(paragraph)
            cursor = end
        }
        return output
    }

    private static func label(_ kind: String, languageCode: String) -> String {
        switch kind {
        case "note": return ReaderCopy.string(.alertNote, languageCode: languageCode)
        case "tip": return ReaderCopy.string(.alertTip, languageCode: languageCode)
        case "important": return ReaderCopy.string(.alertImportant, languageCode: languageCode)
        case "warning": return ReaderCopy.string(.alertWarning, languageCode: languageCode)
        case "caution": return ReaderCopy.string(.alertCaution, languageCode: languageCode)
        default: return kind
        }
    }

    private static func addClass(_ open: String, kind: String) -> String {
        let extra = "alert alert-\(kind)"
        if let classStart = open.range(of: "class=\"") {
            let insertAt = classStart.upperBound
            return open[..<insertAt] + extra + " " + open[insertAt...]
        }
        guard open.hasSuffix(">") else { return open }
        return String(open.dropLast()) + " class=\"\(extra)\">"
    }

    /// An image, break, or other tag is still content. `plainText` skips every tag.
    private static func hasInnerElement(_ paragraph: String) -> Bool {
        guard let openEnd = paragraph.firstIndex(of: ">") else { return false }
        let innerStart = paragraph.index(after: openEnd)
        let suffix = "</p>"
        let innerEnd = paragraph.hasSuffix(suffix)
            ? paragraph.index(paragraph.endIndex, offsetBy: -suffix.count)
            : paragraph.endIndex
        guard innerStart < innerEnd else { return false }
        return paragraph[innerStart..<innerEnd].contains("<")
    }

    private static func plainText(_ html: String) -> String {
        var text = ""
        var inTag = false
        for character in html {
            if character == "<" { inTag = true }
            if !inTag { text.append(character) }
            if character == ">" { inTag = false }
        }
        return text
    }

    private static func matchingClose(_ html: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var cursor = start
        while cursor < html.endIndex {
            if html[cursor...].hasPrefix("<blockquote") {
                depth += 1
                cursor = html.index(cursor, offsetBy: "<blockquote".count)
                continue
            }
            if html[cursor...].hasPrefix("</blockquote>") {
                depth -= 1
                cursor = html.index(cursor, offsetBy: "</blockquote>".count)
                if depth == 0 { return cursor }
                continue
            }
            cursor = html.index(after: cursor)
        }
        return nil
    }

    private static func matchingParagraph(_ html: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var cursor = start
        while cursor < html.endIndex {
            if html[cursor...].hasPrefix("<p"), isTagBoundary(html, at: html.index(cursor, offsetBy: 2)) {
                depth += 1
                cursor = html.index(cursor, offsetBy: 2)
                continue
            }
            if html[cursor...].hasPrefix("</p>") {
                depth -= 1
                cursor = html.index(cursor, offsetBy: "</p>".count)
                if depth == 0 { return cursor }
                continue
            }
            cursor = html.index(after: cursor)
        }
        return nil
    }

    private static func isTagBoundary(_ html: String, at index: String.Index) -> Bool {
        guard index < html.endIndex else { return true }
        let character = html[index]
        return character == ">" || character == " " || character == "/"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
