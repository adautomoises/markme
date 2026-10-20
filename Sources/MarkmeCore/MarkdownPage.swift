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
        MarkdownPage(htmlBody: fillEmptyImageAlt(renderHTML(markdown)))
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
