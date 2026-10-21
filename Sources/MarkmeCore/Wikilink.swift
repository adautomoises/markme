import Foundation

enum Wikilink {
    private static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdwn"]

    /// Replaces a wikilink with a relative Markdown link when that file is in the folder or one level down.
    static func expand(_ markdown: String, baseDirectory: URL?, fileManager: FileManager = .default) -> String {
        guard let baseDirectory else { return markdown }
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var openFence: Character?
        var fenceLength = 0
        let expanded = lines.map { raw -> String in
            let line = String(raw)
            if let marker = openFence {
                if closesFence(line, marker: marker, length: fenceLength) { openFence = nil }
                return line
            }
            if let opened = openingFence(line) {
                openFence = opened.marker
                fenceLength = opened.length
                return line
            }
            return expandLine(line, baseDirectory: baseDirectory, fileManager: fileManager)
        }
        return expanded.joined(separator: "\n")
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

    private static func expandLine(_ line: String, baseDirectory: URL, fileManager: FileManager) -> String {
        var output = ""
        var cursor = line.startIndex
        while cursor < line.endIndex {
            if line[cursor] == "`" {
                let runEnd = backtickRunEnd(line, from: cursor)
                let marker = line[cursor..<runEnd]
                if let close = line.range(of: marker, range: runEnd..<line.endIndex) {
                    output.append(contentsOf: line[cursor..<close.upperBound])
                    cursor = close.upperBound
                    continue
                }
            }
            if line[cursor...].hasPrefix("[["), let link = parseLink(line, from: cursor) {
                if let href = relativeTarget(name: link.name, baseDirectory: baseDirectory, fileManager: fileManager) {
                    output.append("[\(link.label)](<\(href)>)")
                } else {
                    output.append(contentsOf: line[link.range])
                }
                cursor = link.range.upperBound
                continue
            }
            output.append(line[cursor])
            cursor = line.index(after: cursor)
        }
        return output
    }

    private struct ParsedLink {
        var name: String
        var label: String
        var range: Range<String.Index>
    }

    private static func parseLink(_ line: String, from start: String.Index) -> ParsedLink? {
        guard line[start...].hasPrefix("[[") else { return nil }
        let body = line.index(start, offsetBy: 2)
        guard let close = line.range(of: "]]", range: body..<line.endIndex) else { return nil }
        let inside = String(line[body..<close.lowerBound])
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

    private static func backtickRunEnd(_ line: String, from start: String.Index) -> String.Index {
        var index = start
        while index < line.endIndex, line[index] == "`" {
            index = line.index(after: index)
        }
        return index
    }

    private static func openingFence(_ line: String) -> (marker: Character, length: Int)? {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < 4 {
            spaces += 1
            index = line.index(after: index)
        }
        guard spaces <= 3, index < line.endIndex else { return nil }
        let marker = line[index]
        guard marker == "`" || marker == "~" else { return nil }
        var length = 0
        var rest = line[index...]
        while rest.first == marker {
            length += 1
            rest = rest.dropFirst()
        }
        guard length >= 3, !rest.contains(marker) else { return nil }
        return (marker, length)
    }

    private static func closesFence(_ line: String, marker: Character, length: Int) -> Bool {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < 4 {
            spaces += 1
            index = line.index(after: index)
        }
        guard spaces <= 3 else { return false }
        var count = 0
        var rest = line[index...]
        while rest.first == marker {
            count += 1
            rest = rest.dropFirst()
        }
        return count >= length && rest.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
