import Foundation

public enum LocationReference {
    /// A path an agent can open, plus a 1-based line. Inside a git checkout the path is relative to that root.
    public static func format(fileURL: URL, line: Int, fileManager: FileManager = .default) -> String {
        "\(projectPath(of: fileURL, fileManager: fileManager)):\(max(line, 1))"
    }

    /// A selection uses its first line. A caret uses the heading at or above it, or the caret line when there is none.
    public static func line(caret: Int, selectionExtends: Bool, headings: [Int]) -> Int {
        let place = max(caret, 1)
        if selectionExtends { return place }
        return headings.last(where: { $0 <= place }) ?? place
    }

    /// ATX heading lines. Fenced code and a leading YAML block are not headings.
    public static func headingLines(in markdown: String) -> [Int] {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let frontMatterEnd = closedFrontMatterEnd(rawLines)
        var lines: [Int] = []
        var openFence: Character?
        var fenceLength = 0
        var number = 0
        for raw in rawLines {
            number += 1
            if number <= frontMatterEnd { continue }
            let line = String(raw)
            if let marker = openFence {
                if closesFence(line, marker: marker, length: fenceLength) {
                    openFence = nil
                }
                continue
            }
            if let opened = openingFence(line) {
                openFence = opened.marker
                fenceLength = opened.length
                continue
            }
            if atxLevel(line) != nil {
                lines.append(number)
            }
        }
        return lines
    }

    /// A leading `---` is front matter only when a later `---` or `...` closes it.
    private static func closedFrontMatterEnd(_ lines: [Substring]) -> Int {
        guard let first = lines.first, String(first) == "---" else { return 0 }
        for (offset, raw) in lines.dropFirst().enumerated() {
            let line = String(raw)
            if line == "---" || line == "..." { return offset + 2 }
        }
        return 0
    }

    private static func projectPath(of fileURL: URL, fileManager: FileManager) -> String {
        let file = fileURL.standardizedFileURL
        var directory = file.deletingLastPathComponent()
        var steps = 0
        while steps < 64 {
            if fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                let root = directory.path
                let full = file.path
                let prefix = root.hasSuffix("/") ? root : root + "/"
                if full.hasPrefix(prefix) {
                    return String(full.dropFirst(prefix.count))
                }
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
            steps += 1
        }
        return file.path
    }

    private static func atxLevel(_ line: String) -> Int? {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < 4 {
            spaces += 1
            index = line.index(after: index)
        }
        guard spaces <= 3, index < line.endIndex, line[index] == "#" else { return nil }
        var level = 0
        while index < line.endIndex, line[index] == "#", level < 7 {
            level += 1
            index = line.index(after: index)
        }
        guard (1...6).contains(level) else { return nil }
        if index == line.endIndex { return level }
        return line[index] == " " || line[index] == "\t" ? level : nil
    }

    private static func openingFence(_ line: String) -> (marker: Character, length: Int)? {
        let body = indent(line, max: 3)
        guard body.indent <= 3, let marker = body.text.first, marker == "`" || marker == "~" else { return nil }
        var length = 0
        var rest = body.text
        while rest.first == marker {
            length += 1
            rest = rest.dropFirst()
        }
        guard length >= 3, !rest.contains(marker) else { return nil }
        return (marker, length)
    }

    private static func closesFence(_ line: String, marker: Character, length: Int) -> Bool {
        let body = indent(line, max: 3)
        guard body.indent <= 3 else { return false }
        var count = 0
        var rest = body.text
        while rest.first == marker {
            count += 1
            rest = rest.dropFirst()
        }
        return count >= length && rest.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func indent(_ line: String, max: Int) -> (indent: Int, text: Substring) {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < max + 1 {
            spaces += 1
            index = line.index(after: index)
        }
        return (spaces, line[index...])
    }
}
