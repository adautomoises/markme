import Foundation
import cmark_gfm
import cmark_gfm_extensions

public struct MarkdownPage: Equatable, Sendable {
    public var htmlBody: String

    public init(htmlBody: String) {
        self.htmlBody = htmlBody
    }
}

public enum MarkdownRenderer {
    public static func render(
        _ markdown: String,
        baseDirectory: URL? = nil,
        languageCode: String = "en"
    ) -> MarkdownPage {
        let source = Wikilink.expand(markdown, baseDirectory: baseDirectory)
        let html = fillEmptyImageAlt(sanitize(renderHTML(source)))
        let withFront = FrontMatter.apply(html: html, markdown: markdown)
        let withIDs = assignHeadingIDs(withFront)
        let withAlerts = AlertBlock.apply(html: withIDs, languageCode: languageCode)
        return MarkdownPage(htmlBody: withAlerts)
    }

    private static let allowedTags: Set<String> = [
        "a", "blockquote", "br", "code", "del", "em", "h1", "h2", "h3", "h4", "h5", "h6",
        "hr", "img", "input", "li", "ol", "p", "pre", "s", "section", "span", "strong",
        "sub", "sup", "table", "tbody", "td", "tfoot", "th", "thead", "tr", "ul",
    ]
    private static let dropWithContent: Set<String> = [
        "embed", "iframe", "math", "noscript", "object", "script", "style", "svg", "template", "textarea",
    ]
    private static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
    ]
    private static let allowedAttributes: Set<String> = [
        "align", "alt", "checked", "class", "colspan", "data-sourcepos", "disabled", "href", "id",
        "rowspan", "src", "start", "title", "type",
    ]
    private static let attributeOrder = [
        "data-sourcepos", "class", "id", "href", "src", "alt", "title", "type", "checked", "disabled",
        "start", "align", "colspan", "rowspan",
    ]

    private static func sanitize(_ html: String) -> String {
        let source = stripEscapedDangerousBlocks(html)
        var output = ""
        var index = source.startIndex
        var skipTag = ""
        var skipDepth = 0

        while index < source.endIndex {
            if source[index] != "<" {
                if skipDepth == 0 {
                    let next = source[index...].firstIndex(of: "<") ?? source.endIndex
                    output.append(contentsOf: source[index..<next])
                    index = next
                } else {
                    index = source.index(after: index)
                }
                continue
            }
            if source[index...].hasPrefix("<!--") {
                if let end = source.range(of: "-->", range: index..<source.endIndex) {
                    index = end.upperBound
                } else {
                    break
                }
                continue
            }
            if source[index...].hasPrefix("<!") || source[index...].hasPrefix("<?") {
                if let end = source[index...].firstIndex(of: ">") {
                    index = source.index(after: end)
                } else {
                    break
                }
                continue
            }
            guard let tag = parseTag(in: source, from: index), tag.end > index else {
                if skipDepth == 0 { output.append("<") }
                index = source.index(after: index)
                continue
            }
            index = tag.end
            if skipDepth > 0 {
                if tag.name == skipTag {
                    if tag.closing {
                        skipDepth -= 1
                    } else if !tag.selfClosing && !voidTags.contains(tag.name) {
                        skipDepth += 1
                    }
                }
                continue
            }
            if dropWithContent.contains(tag.name), !tag.closing {
                if !tag.selfClosing && !voidTags.contains(tag.name) {
                    skipTag = tag.name
                    skipDepth = 1
                }
                continue
            }
            guard allowedTags.contains(tag.name) else { continue }
            if tag.closing {
                output.append("</\(tag.name)>")
            } else {
                output.append(emitStart(tag))
            }
        }
        return output
    }

    private static func stripEscapedDangerousBlocks(_ html: String) -> String {
        var result = html
        for tag in ["script", "iframe", "object", "embed"] {
            let escaped = "(?is)&lt;\(tag)\\b.*?&lt;/\(tag)\\s*>"
            result = result.replacingOccurrences(of: escaped, with: "", options: .regularExpression)
        }
        return result
    }

    private struct HTMLTag {
        var name: String
        var closing: Bool
        var selfClosing: Bool
        var attributes: [(String, String)]
        var end: String.Index
    }

    private static func parseTag(in html: String, from start: String.Index) -> HTMLTag? {
        guard start < html.endIndex, html[start] == "<" else { return nil }
        var index = html.index(after: start)
        guard index < html.endIndex else { return nil }
        var closing = false
        if html[index] == "/" {
            closing = true
            index = html.index(after: index)
        }
        let nameStart = index
        while index < html.endIndex, html[index].isLetter || html[index].isNumber {
            index = html.index(after: index)
        }
        guard index > nameStart else { return nil }
        let name = html[nameStart..<index].lowercased()
        var attributes: [(String, String)] = []
        var selfClosing = false
        while index < html.endIndex, html[index] != ">" {
            let character = html[index]
            if character == "/" {
                selfClosing = true
                index = html.index(after: index)
                continue
            }
            if character.isWhitespace {
                index = html.index(after: index)
                continue
            }
            let attributeStart = index
            while index < html.endIndex {
                let marker = html[index]
                if marker == "=" || marker == ">" || marker == "/" || marker.isWhitespace { break }
                index = html.index(after: index)
            }
            let attributeName = html[attributeStart..<index].lowercased()
            while index < html.endIndex, html[index].isWhitespace {
                index = html.index(after: index)
            }
            var value = ""
            if index < html.endIndex, html[index] == "=" {
                index = html.index(after: index)
                while index < html.endIndex, html[index].isWhitespace {
                    index = html.index(after: index)
                }
                if index < html.endIndex, html[index] == "\"" || html[index] == "'" {
                    let quote = html[index]
                    index = html.index(after: index)
                    let valueStart = index
                    while index < html.endIndex, html[index] != quote {
                        index = html.index(after: index)
                    }
                    value = String(html[valueStart..<index])
                    if index < html.endIndex { index = html.index(after: index) }
                } else {
                    let valueStart = index
                    while index < html.endIndex, !html[index].isWhitespace, html[index] != ">" {
                        index = html.index(after: index)
                    }
                    value = String(html[valueStart..<index])
                }
            }
            if !attributeName.isEmpty {
                attributes.append((attributeName, decodeEntities(value)))
            }
        }
        if index < html.endIndex, html[index] == ">" {
            index = html.index(after: index)
        }
        return HTMLTag(name: name, closing: closing, selfClosing: selfClosing, attributes: attributes, end: index)
    }

    private static func emitStart(_ tag: HTMLTag) -> String {
        var kept: [String: String] = [:]
        for (key, value) in tag.attributes {
            guard allowedAttributes.contains(key), kept[key] == nil else { continue }
            if key == "href" || key == "src", !urlIsSafe(value, attribute: key) { continue }
            kept[key] = value
        }
        if tag.name == "img" {
            let source = kept["src"] ?? ""
            if (kept["alt"] ?? "").isEmpty, !source.isEmpty {
                kept["alt"] = source
            }
        }
        if tag.name == "input" {
            kept["disabled"] = ""
        }
        var markup = "<\(tag.name)"
        for key in attributeOrder {
            guard let value = kept[key] else { continue }
            markup += " \(key)=\"\(escape(value))\""
        }
        markup += ">"
        return markup
    }

    private static func urlIsSafe(_ value: String, attribute: String) -> Bool {
        let compact = String(String.UnicodeScalarView(value.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }))
        if compact.hasPrefix("//") { return false }
        guard let colon = compact.firstIndex(of: ":") else { return true }
        if let slash = compact.firstIndex(of: "/"), slash < colon { return true }
        switch compact[..<colon].lowercased() {
        case "http", "https", "mailto", "file":
            return true
        case "data":
            return attribute == "src" && compact.lowercased().hasPrefix("data:image/")
        default:
            return false
        }
    }

    private static func decodeEntities(_ value: String) -> String {
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "&",
               let semi = value[index...].firstIndex(of: ";"),
               value.distance(from: index, to: semi) <= 16,
               let scalar = entityScalar(value[value.index(after: index)..<semi]) {
                result.unicodeScalars.append(scalar)
                index = value.index(after: semi)
                continue
            }
            result.append(value[index])
            index = value.index(after: index)
        }
        return result
    }

    private static func entityScalar(_ body: Substring) -> Unicode.Scalar? {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"]
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
        guard !digits.isEmpty, let number = UInt32(digits, radix: radix) else { return nil }
        return Unicode.Scalar(number)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func renderHTML(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        let options = Int32(CMARK_OPT_UNSAFE | CMARK_OPT_SOURCEPOS)
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in ["table", "strikethrough", "autolink", "tagfilter", "tasklist", "footnote"] {
            name.withCString { cString in
                if let syntax = cmark_find_syntax_extension(cString) {
                    _ = cmark_parser_attach_syntax_extension(parser, syntax)
                }
            }
        }

        markdown.utf8CString.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let length = max(buffer.count - 1, 0)
            cmark_parser_feed(parser, base, length)
        }

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }
        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let rendered = cmark_render_html(document, options, extensions) else { return "" }
        defer { free(rendered) }
        return String(cString: rendered)
    }

    private static func assignHeadingIDs(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<h([1-6])([^>]*)>(.*?)</h\1>"#) else {
            return html
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var used = Set<String>()
        var slugs = [String?]()
        slugs.reserveCapacity(matches.count)
        for match in matches {
            guard match.numberOfRanges == 4,
                  let attrRange = Range(match.range(at: 2), in: html),
                  let innerRange = Range(match.range(at: 3), in: html) else {
                slugs.append(nil)
                continue
            }
            let attributes = html[attrRange]
            if attributes.range(of: #"(?i)(?:^|\s)id\s*="#, options: .regularExpression) != nil {
                slugs.append(nil)
                continue
            }
            let base = slug(plainHeading(String(html[innerRange])))
            slugs.append(base.isEmpty ? nil : uniqueSlug(base, used: &used))
        }

        var result = html
        for (match, slug) in zip(matches, slugs).reversed() {
            guard let slug,
                  let whole = Range(match.range, in: result),
                  let levelRange = Range(match.range(at: 1), in: result),
                  let attrRange = Range(match.range(at: 2), in: result),
                  let innerRange = Range(match.range(at: 3), in: result) else { continue }
            let level = result[levelRange]
            let attributes = result[attrRange]
            let inner = result[innerRange]
            result.replaceSubrange(whole, with: "<h\(level) id=\"\(slug)\"\(attributes)>\(inner)</h\(level)>")
        }
        return result
    }

    private static func plainHeading(_ html: String) -> String {
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

    private static func slug(_ text: String) -> String {
        let folded = text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var output = ""
        var hyphen = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if hyphen, !output.isEmpty { output.append("-") }
                hyphen = false
                output.unicodeScalars.append(scalar)
            } else if !output.isEmpty {
                hyphen = true
            }
        }
        return output
    }

    private static func uniqueSlug(_ base: String, used: inout Set<String>) -> String {
        if used.insert(base).inserted { return base }
        var index = 1
        while true {
            let candidate = "\(base)-\(index)"
            if used.insert(candidate).inserted { return candidate }
            index += 1
        }
    }

    private static func fillEmptyImageAlt(_ html: String) -> String {
        var result = html
        let patterns = [
            #"src="([^"]*)" alt="""#,
            #"alt="" src="([^"]*)""#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                guard match.numberOfRanges > 1,
                      let whole = Range(match.range, in: result),
                      let source = Range(match.range(at: 1), in: result) else { continue }
                let path = String(result[source])
                let original = String(result[whole])
                let replaced = original.replacingOccurrences(of: #"alt="""#, with: #"alt="\#(path)""#)
                result.replaceSubrange(whole, with: replaced)
            }
        }
        return result
    }
}
