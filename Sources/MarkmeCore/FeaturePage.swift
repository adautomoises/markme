import Foundation

/// One reading of a superpowers plan and the spec it cites.
///
/// The plan stays the file on disk and the text view. The page adds a map,
/// then the spec, then the plan. A plan with no `**Spec:**` line is left alone.
public struct CitedSpec: Equatable, Sendable {
    public var url: URL
    /// The path as written in the plan.
    public var label: String
    public var markdown: String

    public init(url: URL, label: String, markdown: String) {
        self.url = url
        self.label = label
        self.markdown = markdown
    }
}

public enum FeaturePage {
    /// The spec cited in the plan preamble, when that file can be read as UTF-8.
    /// A citation inside a fence, or after the first section heading, does not count.
    public static func load(
        plan: String,
        planDirectory: URL,
        excluding planFile: URL? = nil,
        fileManager: FileManager = .default
    ) -> CitedSpec? {
        guard let cited = citation(in: plan),
              let url = resolve(cited, planDirectory: planDirectory, excluding: planFile, fileManager: fileManager),
              let markdown = readUTF8(url, fileManager: fileManager) else { return nil }
        return CitedSpec(url: url, label: cited, markdown: markdown)
    }

    /// `planHTML` is the plan rendered on its own, so its source positions stay
    /// the plan's lines. Spec markup is rendered apart and carries none.
    public static func compose(
        plan: String,
        planHTML: String,
        spec: CitedSpec,
        planDirectory: URL,
        planLabel: String,
        languageCode: String
    ) -> String {
        let specHTML = namespacedSpec(
            MarkdownRenderer.render(
                spec.markdown,
                baseDirectory: spec.url.deletingLastPathComponent(),
                languageCode: languageCode
            ).htmlBody,
            specDirectory: spec.url.deletingLastPathComponent(),
            planDirectory: planDirectory
        )
        let tasks = taskLinks(in: plan, planHTML: planHTML)
        let outline = sections(in: spec.markdown)
        var parts: [String] = []
        parts.append(mapHTML(
            spec: spec,
            planLabel: planLabel,
            outline: outline,
            tasks: tasks,
            languageCode: languageCode
        ))
        if !specHTML.isEmpty {
            parts.append(partHeading(.featureSpec, id: "markme-feature-spec", languageCode: languageCode))
            parts.append(specHTML)
        }
        parts.append(partHeading(.featurePlan, id: "markme-feature-plan", languageCode: languageCode))
        parts.append(planHTML)
        return parts.joined()
    }

    private struct TaskLink {
        var number: Int
        var title: String
        var id: String?
    }

    private struct Section {
        var level: Int
        var title: String
        var body: [String]
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdwn"]

    private static func citation(in plan: String) -> String? {
        for line in preamble(of: plan) {
            guard let value = specValue(line), let path = path(in: value) else { continue }
            return path
        }
        return nil
    }

    private static func specValue(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marker = "**Spec:**"
        guard trimmed.hasPrefix(marker) else { return nil }
        return String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func path(in value: String) -> String? {
        if let quoted = firstBacktick(value), isMarkdownPath(quoted) { return quoted }
        if let linked = markdownDestination(value), isMarkdownPath(linked) { return linked }
        let token = value.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        return isMarkdownPath(cleaned) ? cleaned : nil
    }

    private static func firstBacktick(_ value: String) -> String? {
        guard let open = value.firstIndex(of: "`") else { return nil }
        let rest = value.index(after: open)
        guard let close = value[rest...].firstIndex(of: "`"), close > rest else { return nil }
        return String(value[rest..<close])
    }

    private static func markdownDestination(_ value: String) -> String? {
        guard let open = value.range(of: "](") else { return nil }
        let rest = open.upperBound
        guard let close = value[rest...].firstIndex(of: ")") else { return nil }
        let destination = String(value[rest..<close]).trimmingCharacters(in: .whitespaces)
        return destination.isEmpty ? nil : destination
    }

    private static func isMarkdownPath(_ path: String) -> Bool {
        let bare = path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? path
        let file = bare.split(separator: "?", maxSplits: 1).first.map(String.init) ?? bare
        let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
        return markdownExtensions.contains(ext)
    }

    private static func resolve(
        _ path: String,
        planDirectory: URL,
        excluding planFile: URL?,
        fileManager: FileManager
    ) -> URL? {
        let file = citedFilePath(path)
        guard !file.isEmpty else { return nil }
        let candidates: [URL]
        if file.hasPrefix("/") {
            candidates = [URL(fileURLWithPath: file)]
        } else {
            var found = [planDirectory.appendingPathComponent(file)]
            if let root = gitRoot(of: planDirectory, fileManager: fileManager) {
                found.append(root.appendingPathComponent(file))
            }
            candidates = found
        }
        let excluded = planFile?.standardizedFileURL.resolvingSymlinksInPath().path
        for candidate in candidates {
            let url = candidate.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            if url.resolvingSymlinksInPath().path == excluded { continue }
            return url
        }
        return nil
    }

    private static func gitRoot(of directory: URL, fileManager: FileManager) -> URL? {
        var current = directory.standardizedFileURL
        var steps = 0
        while steps < 64 {
            if fileManager.fileExists(atPath: current.appendingPathComponent(".git").path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
            steps += 1
        }
        return nil
    }

    private static func readUTF8(_ url: URL, fileManager: FileManager) -> String? {
        guard fileManager.isReadableFile(atPath: url.path),
              let data = fileManager.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    private static func mapHTML(
        spec: CitedSpec,
        planLabel: String,
        outline: [Section],
        tasks: [TaskLink],
        languageCode: String
    ) -> String {
        var html = "<section class=\"feature-map\">"
        let paths = [spec.label, planLabel].filter { !$0.isEmpty }
        if !paths.isEmpty {
            html += "<p class=\"feature-paths\">\(escape(paths.joined(separator: " · ")))</p>"
        }
        if let intent = outline.first(where: { normalized($0.title) == "intent" }),
           let paragraph = firstParagraph(intent.body) {
            html += "<p>\(escape(paragraph))</p>"
        }
        html += listBlock(
            title: .featureGoals,
            items: items(in: outline, matching: { normalized($0) == "goals" }),
            ordered: false,
            languageCode: languageCode
        )
        html += listBlock(
            title: .featureNonGoals,
            items: items(in: outline, matching: { title in
                let name = normalized(title)
                return name.hasPrefix("non-goal") || name.hasPrefix("non goal")
            }),
            ordered: false,
            languageCode: languageCode
        )
        if !tasks.isEmpty {
            html += "<h2>\(escape(ReaderCopy.string(.featureTasks, languageCode: languageCode)))</h2>"
            let numbers = tasks.map(\.number)
            let contiguous = numbers.enumerated().allSatisfy { $0.element == $0.offset + 1 }
            if contiguous {
                html += "<ol>"
                for task in tasks {
                    html += "<li>\(taskAnchor(task))</li>"
                }
                html += "</ol>"
            } else {
                html += "<ul>"
                for task in tasks {
                    let label = "Task \(task.number): \(task.title)"
                    html += "<li>\(taskAnchor(task, label: label))</li>"
                }
                html += "</ul>"
            }
        }
        html += "</section>"
        return html
    }

    private static func taskAnchor(_ task: TaskLink, label: String? = nil) -> String {
        let text = escape(label ?? task.title)
        guard let id = task.id else { return text }
        return "<a href=\"#\(escape(id))\">\(text)</a>"
    }

    private static func listBlock(
        title: CopyKey,
        items: [String],
        ordered: Bool,
        languageCode: String
    ) -> String {
        guard !items.isEmpty else { return "" }
        let tag = ordered ? "ol" : "ul"
        var html = "<h2>\(escape(ReaderCopy.string(title, languageCode: languageCode)))</h2><\(tag)>"
        for item in items {
            html += "<li>\(escape(item))</li>"
        }
        html += "</\(tag)>"
        return html
    }

    private static func items(in outline: [Section], matching: (String) -> Bool) -> [String] {
        guard let section = outline.first(where: { matching($0.title) }) else { return [] }
        let listed = section.body.compactMap(listItemText)
        if !listed.isEmpty { return listed }
        if let paragraph = firstParagraph(section.body) { return [paragraph] }
        return []
    }

    private static func partHeading(_ key: CopyKey, id: String, languageCode: String) -> String {
        "<h2 class=\"feature-part\" id=\"\(id)\">\(escape(ReaderCopy.string(key, languageCode: languageCode)))</h2>"
    }

    private static func taskLinks(in plan: String, planHTML: String) -> [TaskLink] {
        let headings = headingIDs(in: planHTML)
        var used: Set<Int> = []
        return taskTitles(in: plan).map { task in
            let match = headings.indices.first { index in
                !used.contains(index) && normalized(headings[index].text) == normalized(task.full)
            }
            if let match { used.insert(match) }
            return TaskLink(number: task.number, title: task.link, id: match.map { headings[$0].id })
        }
    }

    private struct ParsedTask {
        var number: Int
        var full: String
        var link: String
    }

    private static func taskTitles(in markdown: String) -> [ParsedTask] {
        sections(in: markdown).compactMap { section in
            guard let task = parseTask(section.title) else { return nil }
            return task
        }
    }

    private static func parseTask(_ title: String) -> ParsedTask? {
        var rest = title.drop(while: \.isWhitespace)
        guard rest.lowercased().hasPrefix("task") else { return nil }
        let afterWord = rest.dropFirst(4)
        guard afterWord.first?.isWhitespace == true else { return nil }
        rest = afterWord.drop(while: \.isWhitespace)
        var digits = ""
        while let character = rest.first, character.isNumber {
            digits.append(character)
            rest = rest.dropFirst()
        }
        guard let number = Int(digits) else { return nil }
        rest = rest.drop(while: \.isWhitespace)
        if rest.first == ":" {
            rest = rest.dropFirst().drop(while: \.isWhitespace)
        }
        let link = String(rest).trimmingCharacters(in: .whitespaces)
        let full = title.trimmingCharacters(in: .whitespaces)
        return ParsedTask(number: number, full: full, link: link.isEmpty ? full : link)
    }

    private struct HeadingID {
        var id: String
        var text: String
    }

    private static func headingIDs(in html: String) -> [HeadingID] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<h[1-6]\b([^>]*)>(.*?)</h[1-6]>"#
        ) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard match.numberOfRanges == 3,
                  let attrRange = Range(match.range(at: 1), in: html),
                  let innerRange = Range(match.range(at: 2), in: html),
                  let id = attribute("id", in: String(html[attrRange])) else { return nil }
            return HeadingID(id: id, text: plain(String(html[innerRange])))
        }
    }

    private static func attribute(_ name: String, in attributes: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "(?i)(?:^|\\s)\(NSRegularExpression.escapedPattern(for: name))=\"([^\"]*)\""
        ) else { return nil }
        let range = NSRange(attributes.startIndex..., in: attributes)
        guard let match = regex.firstMatch(in: attributes, range: range),
              match.numberOfRanges == 2,
              let value = Range(match.range(at: 1), in: attributes) else { return nil }
        return String(attributes[value])
    }

    private static func namespacedSpec(_ html: String, specDirectory: URL, planDirectory: URL) -> String {
        var result = html.replacingOccurrences(
            of: #"\sdata-sourcepos="[^"]*""#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<=\s)id="([^"]*)""#,
            with: #"id="spec-$1""#,
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: ##"href="#([^"]*)""##,
            with: ##"href="#spec-$1""##,
            options: .regularExpression
        )
        return rewriteResources(result, from: specDirectory, to: planDirectory)
    }

    private static func rewriteResources(_ html: String, from specDirectory: URL, to planDirectory: URL) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(href|src)="([^"]*)""#) else { return html }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var result = html
        for match in matches.reversed() {
            guard match.numberOfRanges == 3,
                  let valueRange = Range(match.range(at: 2), in: result) else { continue }
            let value = String(result[valueRange])
            let rewritten = relativeResource(value, from: specDirectory, to: planDirectory)
            if rewritten != value {
                result.replaceSubrange(valueRange, with: rewritten)
            }
        }
        return result
    }

    /// The file path of a citation. A `#fragment` or `?query` is not part of the name.
    private static func citedFilePath(_ path: String) -> String {
        let decoded = path.removingPercentEncoding ?? path
        let bare = decoded.split(separator: "#", maxSplits: 1).first.map(String.init) ?? decoded
        return bare.split(separator: "?", maxSplits: 1).first.map(String.init) ?? bare
    }

    private static func relativeResource(_ value: String, from specDirectory: URL, to planDirectory: URL) -> String {
        if value.isEmpty || value.hasPrefix("#") { return value }
        let decodedEntities = htmlDecoded(value)
        let text = decodedEntities.removingPercentEncoding ?? decodedEntities
        if text.hasPrefix("//") || hasScheme(text) { return value }
        let hash = text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let beforeFragment = String(hash[0])
        let fragment = hash.count > 1 ? String(hash[1]) : nil
        let queryParts = beforeFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(queryParts[0])
        let query = queryParts.count > 1 ? String(queryParts[1]) : nil
        guard !path.isEmpty else { return value }
        let target: URL
        if path.hasPrefix("/") {
            target = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            target = specDirectory.appendingPathComponent(path).standardizedFileURL
        }
        var relative = relativePath(from: planDirectory.standardizedFileURL, to: target)
        if let query { relative += "?\(query)" }
        if let fragment { relative += "#\(fragment)" }
        return percentEncodePath(relative)
    }

    private static func relativePath(from base: URL, to target: URL) -> String {
        let baseParts = base.path.split(separator: "/").map(String.init)
        let targetParts = target.path.split(separator: "/").map(String.init)
        var index = 0
        while index < baseParts.count, index < targetParts.count, baseParts[index] == targetParts[index] {
            index += 1
        }
        let ups = Array(repeating: "..", count: baseParts.count - index)
        return (ups + targetParts[index...]).joined(separator: "/")
    }

    private static func percentEncodePath(_ path: String) -> String {
        var output = ""
        for character in path {
            if character == "/" || character == "?" || character == "#" || character == "=" {
                output.append(character)
                continue
            }
            for byte in String(character).utf8 {
                let unreserved = (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
                    || (byte >= 48 && byte <= 57)
                    || byte == 45 || byte == 46 || byte == 95 || byte == 126
                if unreserved {
                    output.append(Character(UnicodeScalar(byte)))
                } else {
                    output.append(String(format: "%%%02X", byte))
                }
            }
        }
        return output
    }

    private static func hasScheme(_ value: String) -> Bool {
        guard let colon = value.firstIndex(of: ":"), colon > value.startIndex else { return false }
        let scheme = value[..<colon]
        guard let first = scheme.unicodeScalars.first, CharacterSet.letters.contains(first) else { return false }
        return scheme.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar)
                || CharacterSet.decimalDigits.contains(scalar)
                || scalar == "+" || scalar == "-" || scalar == "."
        }
    }

    /// Attribute text still has the entities the page sanitizer writes back (`&amp;`).
    private static func htmlDecoded(_ value: String) -> String {
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "&",
               let semi = value[index...].firstIndex(of: ";"),
               value.distance(from: index, to: semi) <= 16,
               let scalar = htmlScalar(value[value.index(after: index)..<semi]) {
                result.unicodeScalars.append(scalar)
                index = value.index(after: semi)
                continue
            }
            result.append(value[index])
            index = value.index(after: index)
        }
        return result
    }

    private static func htmlScalar(_ body: Substring) -> Unicode.Scalar? {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]
        if let value = named[String(body)] {
            return value.unicodeScalars.first
        }
        let digits: Substring
        let radix: Int
        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            digits = body.dropFirst(2)
            radix = 16
        } else if body.hasPrefix("#") {
            digits = body.dropFirst()
            radix = 10
        } else {
            return nil
        }
        guard !digits.isEmpty, let number = UInt32(digits, radix: radix), let scalar = Unicode.Scalar(number) else {
            return nil
        }
        return scalar
    }

    private static func preamble(of markdown: String) -> [String] {
        var lines = rawLines(markdown)
        if lines.first == "---" {
            if let end = lines.dropFirst().firstIndex(where: { $0 == "---" || $0 == "..." }) {
                lines = Array(lines[lines.index(after: end)...])
            }
        }
        var kept: [String] = []
        var fence: (Character, Int)?
        for line in lines {
            if let open = fence {
                if closesFence(line, marker: open.0, length: open.1) { fence = nil }
                continue
            }
            if let opened = openingFence(line) {
                fence = opened
                continue
            }
            if let level = atxLevel(line), level >= 2 { break }
            kept.append(line)
        }
        return kept
    }

    private static func sections(in markdown: String) -> [Section] {
        let lines = rawLines(markdown)
        var start = 0
        if lines.first == "---",
           let end = lines.dropFirst().firstIndex(where: { $0 == "---" || $0 == "..." }) {
            start = lines.index(after: end)
        }
        var sections: [Section] = []
        var fence: (Character, Int)?
        for line in lines[start...] {
            if let open = fence {
                if closesFence(line, marker: open.0, length: open.1) { fence = nil }
                continue
            }
            if let opened = openingFence(line) {
                fence = opened
                continue
            }
            if let level = atxLevel(line) {
                sections.append(Section(level: level, title: headingTitle(line), body: []))
                continue
            }
            if !sections.isEmpty {
                sections[sections.count - 1].body.append(line)
            }
        }
        return sections
    }

    private static func rawLines(_ markdown: String) -> [String] {
        markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private static func atxLevel(_ line: String) -> Int? {
        let indent = line.prefix(while: { $0 == " " }).count
        if indent > 3 || line.contains("\t") && line.first == "\t" { return nil }
        var rest = line.dropFirst(indent)
        var level = 0
        while rest.first == "#" {
            level += 1
            rest = rest.dropFirst()
        }
        guard (1...6).contains(level), rest.first == " " || rest.first == "\t" else { return nil }
        return level
    }

    private static func headingTitle(_ line: String) -> String {
        var rest = line.drop(while: { $0 == " " || $0 == "\t" })
        while rest.first == "#" { rest = rest.dropFirst() }
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        if let closing = rest.range(of: #"\s+#+\s*$"#, options: .regularExpression) {
            rest = rest[..<closing.lowerBound]
        }
        return String(rest).trimmingCharacters(in: .whitespaces)
    }

    private static func openingFence(_ line: String) -> (Character, Int)? {
        let indent = line.prefix(while: { $0 == " " }).count
        if indent > 3 { return nil }
        let rest = line.dropFirst(indent)
        guard let marker = rest.first, marker == "`" || marker == "~" else { return nil }
        var count = 0
        for character in rest {
            if character == marker { count += 1 } else { break }
        }
        let after = rest.dropFirst(count)
        guard count >= 3, after.allSatisfy({ $0 != marker }) else { return nil }
        return (marker, count)
    }

    private static func closesFence(_ line: String, marker: Character, length: Int) -> Bool {
        let indent = line.prefix(while: { $0 == " " }).count
        if indent > 3 { return false }
        let rest = line.dropFirst(indent).trimmingCharacters(in: .whitespaces)
        guard rest.allSatisfy({ $0 == marker }), rest.count >= length else { return false }
        return true
    }

    private static func firstParagraph(_ lines: [String]) -> String? {
        var collected: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !collected.isEmpty { break }
                continue
            }
            if listItemText(line) != nil { break }
            collected.append(line.trimmingCharacters(in: .whitespaces))
        }
        let paragraph = collected.joined(separator: " ")
        return paragraph.isEmpty ? nil : paragraph
    }

    private static func listItemText(_ line: String) -> String? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return checkboxStripped(String(trimmed.dropFirst(2)))
        }
        var digits = trimmed
        var seen = false
        while let character = digits.first, character.isNumber {
            seen = true
            digits = digits.dropFirst()
        }
        guard seen, digits.first == ".", digits.dropFirst().first == " " else { return nil }
        return checkboxStripped(String(digits.dropFirst(2)))
    }

    private static func checkboxStripped(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[ ] ") || trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
            return String(trimmed.dropFirst(4))
        }
        return trimmed
    }

    private static func plain(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "(?is)<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ",
        ]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        return text
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
