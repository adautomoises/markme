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
    public static func render(_ markdown: String) -> MarkdownPage {
        MarkdownPage(htmlBody: assignHeadingIDs(fillEmptyImageAlt(sanitize(renderHTML(markdown)))))
    }

    private static func sanitize(_ html: String) -> String {
        var result = html
        for tag in ["script", "iframe", "object", "embed"] {
            let paired = "(?is)<\(tag)\\b[^>]*>.*?</\(tag)\\s*>"
            result = result.replacingOccurrences(of: paired, with: "", options: .regularExpression)
            let orphan = "(?i)<\(tag)\\b[^>]*/?>"
            result = result.replacingOccurrences(of: orphan, with: "", options: .regularExpression)
            let escaped = "(?is)&lt;\(tag)\\b.*?&lt;/\(tag)\\s*>"
            result = result.replacingOccurrences(of: escaped, with: "", options: .regularExpression)
        }
        result = result.replacingOccurrences(
            of: "(?i)\\s+on[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?i)(href|src)\\s*=\\s*([\"'])\\s*javascript:[^\"']*\\2",
            with: "$1=$2$2",
            options: .regularExpression
        )
        return result
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
