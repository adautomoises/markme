import Foundation

public enum PageShell {
    public static func html(body: String, highlighter: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file: https: http: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <style>
        html, body { margin: 0; background: #fff; color: #1d1d1f; }
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 17px; line-height: 1.55; }
        article { max-width: 68ch; margin: 0 auto; padding: 40px 28px 64px; user-select: text; }
        code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
        pre { background: #f4f4f5; border-radius: 10px; padding: 14px 16px; overflow: auto; }
        .hljs-keyword, .hljs-selector-tag, .hljs-type { color: #ad3da4; }
        .hljs-string, .hljs-attr { color: #d12f1b; }
        .hljs-comment { color: #707f8c; }
        .hljs-number, .hljs-literal { color: #272ad8; }
        .hljs-title, .hljs-section, .hljs-name { color: #0e7c3a; }
        .hljs-built_in, .hljs-meta { color: #804fb8; }
        a { color: -webkit-link; }
        blockquote { margin-left: 0; padding-left: 14px; border-left: 3px solid #d2d2d7; color: #424245; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px 10px 8px 0; border-bottom: 1px solid #ececf0; }
        input[type="checkbox"] { pointer-events: none; }
        img { max-width: 100%; border-radius: 10px; }
        @media (prefers-color-scheme: dark) {
          html, body { background: #1c1c1e; color: #f5f5f7; }
          pre { background: #2c2c2e; }
          .hljs-keyword, .hljs-selector-tag, .hljs-type { color: #fc6a5d; }
          .hljs-string, .hljs-attr { color: #fc6a5d; }
          .hljs-comment { color: #8b9bab; }
          .hljs-number, .hljs-literal { color: #d0bf69; }
          .hljs-title, .hljs-section, .hljs-name { color: #67b7a4; }
          .hljs-built_in, .hljs-meta { color: #d0a8ff; }
          a { color: -webkit-link; }
          blockquote { border-left-color: #48484a; color: #d1d1d6; }
          th, td { border-bottom-color: #3a3a3c; }
        }
        </style>
        <script>\(highlighter)</script>
        <script>hljs.highlightAll();</script>
        </head>
        <body><article>\(body)</article></body>
        </html>
        """
    }
}
