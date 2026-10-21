import Foundation

enum FrontMatter {
    struct Block {
        var endLine: Int
        var title: String?
        var titleLine: Int
        var status: String?
        var statusLine: Int
    }

    /// Hides a closed YAML block at the top of the page and shows title and status when those fields exist.
    static func apply(html: String, markdown: String) -> String {
        let block = parse(markdown)
        guard block.endLine > 0 else { return html }
        let body = strip(html, through: block.endLine)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let header = headerHTML(block)
        if header.isEmpty { return body }
        if body.isEmpty { return header }
        return header + "\n" + body
    }

    static func parse(_ markdown: String) -> Block {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let endLine = closedEnd(lines)
        var block = Block(endLine: endLine, title: nil, titleLine: 0, status: nil, statusLine: 0)
        guard endLine > 2 else { return block }
        for number in 2..<endLine {
            let line = String(lines[number - 1])
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = unquote(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
            guard !value.isEmpty else { continue }
            if key == "title", block.title == nil {
                block.title = value
                block.titleLine = number
            } else if key == "status", block.status == nil {
                block.status = value
                block.statusLine = number
            }
        }
        return block
    }

    private static func closedEnd(_ lines: [Substring]) -> Int {
        guard let first = lines.first, String(first) == "---" else { return 0 }
        for (offset, raw) in lines.dropFirst().enumerated() {
            let line = String(raw)
            if line == "---" || line == "..." { return offset + 2 }
        }
        return 0
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first
        if (first == "\"" || first == "'"), value.last == first {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func headerHTML(_ block: Block) -> String {
        var parts: [String] = []
        if let title = block.title, block.titleLine > 0 {
            parts.append(
                "<p class=\"front-title\" data-sourcepos=\"\(block.titleLine):1-\(block.titleLine):1\">\(escape(title))</p>"
            )
        }
        if let status = block.status, block.statusLine > 0 {
            parts.append(
                "<p class=\"front-status\" data-sourcepos=\"\(block.statusLine):1-\(block.statusLine):1\">\(escape(status))</p>"
            )
        }
        guard !parts.isEmpty else { return "" }
        return "<section class=\"front-matter\">\n" + parts.joined(separator: "\n") + "\n</section>"
    }

    private static func strip(_ html: String, through endLine: Int) -> String {
        var output = ""
        var cursor = html.startIndex
        while cursor < html.endIndex {
            guard let tagStart = html[cursor...].firstIndex(of: "<") else {
                output.append(contentsOf: html[cursor...])
                break
            }
            output.append(contentsOf: html[cursor..<tagStart])
            guard let tag = readTag(html, from: tagStart) else {
                output.append("<")
                cursor = html.index(after: tagStart)
                continue
            }
            // A closing --- can be a setext underline, so the block starts inside the
            // front matter and its source position runs one line past the closer.
            let inside = sourceStart(tag.raw).map { $0 >= 1 && $0 <= endLine } ?? false
            if tag.closing {
                output.append(contentsOf: html[tagStart..<tag.end])
                cursor = tag.end
                continue
            }
            if tag.void || tag.selfClosing {
                if inside {
                    cursor = tag.end
                } else {
                    output.append(contentsOf: html[tagStart..<tag.end])
                    cursor = tag.end
                }
                continue
            }
            if inside, let close = matchingClose(html, name: tag.name, from: tag.end) {
                cursor = close
                continue
            }
            output.append(contentsOf: html[tagStart..<tag.end])
            cursor = tag.end
        }
        return output
    }

    private struct Tag {
        var name: String
        var closing: Bool
        var void: Bool
        var selfClosing: Bool
        var raw: String
        var end: String.Index
    }

    private static let voidNames: Set<String> = ["hr", "br", "img", "input"]

    private static func readTag(_ html: String, from start: String.Index) -> Tag? {
        guard html[start] == "<", let end = html[start...].firstIndex(of: ">") else { return nil }
        let raw = String(html[start...end])
        var index = html.index(after: start)
        if index < html.endIndex, html[index] == "/" { index = html.index(after: index) }
        let nameStart = index
        while index < end, html[index].isLetter || html[index].isNumber {
            index = html.index(after: index)
        }
        let name = String(html[nameStart..<index]).lowercased()
        guard !name.isEmpty else { return nil }
        let closing = raw.hasPrefix("</")
        let selfClosing = raw.hasSuffix("/>")
        return Tag(
            name: name,
            closing: closing,
            void: voidNames.contains(name),
            selfClosing: selfClosing,
            raw: raw,
            end: html.index(after: end)
        )
    }

    private static func sourceStart(_ raw: String) -> Int? {
        guard let marker = raw.range(of: "data-sourcepos=\""),
              let colon = raw[marker.upperBound...].firstIndex(of: ":") else { return nil }
        return Int(raw[marker.upperBound..<colon])
    }

    private static func matchingClose(_ html: String, name: String, from start: String.Index) -> String.Index? {
        var depth = 1
        var cursor = start
        while cursor < html.endIndex {
            guard let tagStart = html[cursor...].firstIndex(of: "<") else { return nil }
            guard let tag = readTag(html, from: tagStart) else {
                cursor = html.index(after: tagStart)
                continue
            }
            if tag.name == name {
                if tag.closing {
                    depth -= 1
                    if depth == 0 { return tag.end }
                } else if !tag.void && !tag.selfClosing {
                    depth += 1
                }
            }
            cursor = tag.end
        }
        return nil
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
