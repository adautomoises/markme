import Foundation

enum Wikilink {
    private static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdwn"]

    /// Replaces wikilinks in HTML text that is outside `pre` and `code`.
    /// cmark has already classified indented code, nested fences, and multiline
    /// spans, so those stay literal. `![[name]]` stays text. The link is an
    /// anchor, not raw Markdown, and the path is percent-encoded once.
    static func apply(html: String, baseDirectory: URL?, fileManager: FileManager = .default) -> String {
        guard let baseDirectory else { return html }
        var output = ""
        var cursor = html.startIndex
        var preDepth = 0
        var codeDepth = 0
        while cursor < html.endIndex {
            if html[cursor] == "<", let tag = readTag(html, from: cursor) {
                switch tag.name.lowercased() {
                case "pre":
                    if tag.closing { preDepth = max(0, preDepth - 1) }
                    else if !tag.selfClosing { preDepth += 1 }
                case "code":
                    if tag.closing { codeDepth = max(0, codeDepth - 1) }
                    else if !tag.selfClosing { codeDepth += 1 }
                default:
                    break
                }
                output.append(contentsOf: html[cursor..<tag.end])
                cursor = tag.end
                continue
            }
            let next = html[cursor...].firstIndex(of: "<") ?? html.endIndex
            let text = String(html[cursor..<next])
            if preDepth == 0, codeDepth == 0 {
                output.append(expandText(text, baseDirectory: baseDirectory, fileManager: fileManager))
            } else {
                output.append(text)
            }
            cursor = next
        }
        return output
    }

    static func relativeTarget(name: String, baseDirectory: URL, fileManager: FileManager = .default) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let here = markdownFiles(in: baseDirectory, fileManager: fileManager).filter { matches($0, name: trimmed) }
        if let file = here.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
            return relativePath(file, base: baseDirectory)
        }
        let children = childDirectories(of: baseDirectory, fileManager: fileManager)
        var below: [URL] = []
        for child in children {
            below.append(contentsOf: markdownFiles(in: child, fileManager: fileManager).filter { matches($0, name: trimmed) })
        }
        guard let file = below.sorted(by: { relativePath($0, base: baseDirectory) < relativePath($1, base: baseDirectory) }).first else {
            return nil
        }
        return relativePath(file, base: baseDirectory)
    }

    private static func expandText(_ text: String, baseDirectory: URL, fileManager: FileManager) -> String {
        var output = ""
        var cursor = text.startIndex
        while cursor < text.endIndex {
            let precededByImage = cursor > text.startIndex && text[text.index(before: cursor)] == "!"
            if !precededByImage,
               text[cursor...].hasPrefix("[["),
               let link = parseLink(text, from: cursor),
               let href = relativeTarget(name: link.name, baseDirectory: baseDirectory, fileManager: fileManager) {
                output.append("<a href=\"\(percentEncode(href))\">\(escape(link.label))</a>")
                cursor = link.range.upperBound
                continue
            }
            output.append(text[cursor])
            cursor = text.index(after: cursor)
        }
        return output
    }

    private struct ParsedLink {
        var name: String
        var label: String
        var range: Range<String.Index>
    }

    private static func parseLink(_ text: String, from start: String.Index) -> ParsedLink? {
        guard text[start...].hasPrefix("[[") else { return nil }
        let body = text.index(start, offsetBy: 2)
        guard let close = text.range(of: "]]", range: body..<text.endIndex) else { return nil }
        let inside = String(text[body..<close.lowerBound])
        guard !inside.isEmpty, !inside.contains("\n"), !inside.contains("[") else { return nil }
        let name: String
        let label: String
        if let bar = inside.firstIndex(of: "|") {
            name = String(inside[..<bar])
            label = String(inside[inside.index(after: bar)...])
            guard !name.isEmpty, !label.isEmpty else { return nil }
        } else {
            name = inside
            label = inside
        }
        return ParsedLink(name: name, label: label, range: start..<close.upperBound)
    }

    private static func matches(_ file: URL, name: String) -> Bool {
        let stem = file.deletingPathExtension().lastPathComponent
        let full = file.lastPathComponent
        return stem.compare(name, options: [.caseInsensitive]) == .orderedSame
            || full.compare(name, options: [.caseInsensitive]) == .orderedSame
    }

    private static func markdownFiles(in directory: URL, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.compactMap { name in
            guard !name.hasPrefix(".") else { return nil }
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
            guard extensions.contains(url.pathExtension.lowercased()) else { return nil }
            return url
        }
    }

    private static func childDirectories(of directory: URL, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.compactMap { name in
            guard !name.hasPrefix(".") else { return nil }
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            return url
        }
    }

    private static func relativePath(_ file: URL, base: URL) -> String {
        let root = base.standardizedFileURL.path
        let full = file.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard full.hasPrefix(prefix) else { return file.lastPathComponent }
        return String(full.dropFirst(prefix.count))
    }

    private struct Tag {
        var name: String
        var closing: Bool
        var selfClosing: Bool
        var end: String.Index
    }

    private static func readTag(_ html: String, from start: String.Index) -> Tag? {
        guard html[start] == "<" else { return nil }
        if html[start...].hasPrefix("<!--") {
            guard let end = html.range(of: "-->", range: start..<html.endIndex) else { return nil }
            return Tag(name: "!", closing: false, selfClosing: true, end: end.upperBound)
        }
        var cursor = html.index(after: start)
        if cursor < html.endIndex, html[cursor] == "!" || html[cursor] == "?" {
            guard let close = html[start...].firstIndex(of: ">") else { return nil }
            return Tag(name: "!", closing: false, selfClosing: true, end: html.index(after: close))
        }
        var closing = false
        if cursor < html.endIndex, html[cursor] == "/" {
            closing = true
            cursor = html.index(after: cursor)
        }
        let nameStart = cursor
        while cursor < html.endIndex, html[cursor].isLetter || html[cursor].isNumber {
            cursor = html.index(after: cursor)
        }
        guard cursor > nameStart, let close = html[start...].firstIndex(of: ">") else { return nil }
        let end = html.index(after: close)
        let selfClosing = html[html.index(before: close)] == "/"
        return Tag(name: String(html[nameStart..<cursor]), closing: closing, selfClosing: selfClosing, end: end)
    }

    /// One encoding pass. Link resolution decodes once, so `%` must already be `%25`.
    private static func percentEncode(_ path: String) -> String {
        let hex = Array("0123456789ABCDEF")
        var output = ""
        for byte in path.utf8 {
            let unreserved = (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
                || (byte >= 48 && byte <= 57)
                || byte == 45 || byte == 46 || byte == 95 || byte == 126 || byte == 47
            if unreserved {
                output.append(Character(UnicodeScalar(byte)))
            } else {
                output.append("%")
                output.append(hex[Int(byte >> 4)])
                output.append(hex[Int(byte & 0x0F)])
            }
        }
        return output
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
