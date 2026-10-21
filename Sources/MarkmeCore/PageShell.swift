import Foundation

public enum PageShell {
    public static func html(body: String, highlighter: String, mermaid: String = "") -> String {
        let diagrams = mermaid.isEmpty ? "" : mermaidMarkup(mermaid)
        return """
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
        .hljs-keyword, .hljs-selector-tag { color: #ad3da4; font-weight: 600; }
        .hljs-type, .hljs-title.class_, .hljs-class .hljs-title { color: #2457b5; }
        .hljs-built_in { color: #6f42c1; }
        .hljs-title, .hljs-section, .hljs-name, .hljs-function, .hljs-title.function_ { color: #0e7c3a; font-weight: 600; }
        .hljs-string, .hljs-subst { color: #c41a16; }
        .hljs-attr { color: #953800; }
        .hljs-comment { color: #6e7781; font-style: italic; }
        .hljs-number, .hljs-literal { color: #1a1aa6; }
        .hljs-meta { color: #9a6700; }
        .language-gherkin .hljs-keyword, .language-cucumber .hljs-keyword, .language-feature .hljs-keyword { color: #d1242f; font-weight: 700; }
        .language-gherkin .hljs-symbol, .language-cucumber .hljs-symbol, .language-feature .hljs-symbol { color: #1f75cb; font-weight: 500; }
        body.presenting article { max-width: 52rem; min-height: 100vh; display: flex; flex-direction: column; justify-content: center; padding: 8vh 7vw 12vh; }
        body.presenting .slide { display: none; }
        body.presenting .slide.active { display: block; }
        body.presenting h1 { font-size: 3rem; line-height: 1.12; letter-spacing: -0.03em; }
        body.presenting h2 { font-size: 2.15rem; line-height: 1.2; }
        body.presenting p, body.presenting li { font-size: 1.45rem; }
        body.presenting pre { font-size: 1.02rem; max-height: 62vh; }
        body.presenting .slide-count { position: fixed; right: 28px; bottom: 22px; color: #86868b; font-size: 13px; font-variant-numeric: tabular-nums; }
        .mermaid { margin: 1.25rem 0; overflow-x: auto; }
        .mermaid svg { max-width: 100%; height: auto; }
        .change-added { background: rgba(46, 160, 67, 0.16); border-radius: 8px; }
        .change-removed { margin: 0.8rem 0; padding: 4px 10px; border-radius: 8px; background: rgba(207, 34, 46, 0.1); color: #a40e26; font-size: 13px; }
        .change-current { box-shadow: inset 0 0 0 2px #0969da; }
        a { color: -webkit-link; }
        blockquote { margin-left: 0; padding-left: 14px; border-left: 3px solid #d2d2d7; color: #424245; }
        blockquote.alert { color: inherit; border-radius: 10px; padding: 8px 14px 2px; }
        blockquote.alert .alert-title { font-size: 13px; font-weight: 650; margin: 2px 0 6px; }
        blockquote.alert-note { border-left-color: #0969da; background: rgba(9, 105, 218, 0.08); }
        blockquote.alert-note .alert-title { color: #0969da; }
        blockquote.alert-tip { border-left-color: #1a7f37; background: rgba(26, 127, 55, 0.08); }
        blockquote.alert-tip .alert-title { color: #1a7f37; }
        blockquote.alert-important { border-left-color: #8250df; background: rgba(130, 80, 223, 0.08); }
        blockquote.alert-important .alert-title { color: #8250df; }
        blockquote.alert-warning { border-left-color: #9a6700; background: rgba(154, 103, 0, 0.1); }
        blockquote.alert-warning .alert-title { color: #9a6700; }
        blockquote.alert-caution { border-left-color: #cf222e; background: rgba(207, 34, 46, 0.08); }
        blockquote.alert-caution .alert-title { color: #cf222e; }
        .front-matter { margin: 0 0 1.6rem; }
        .front-title { font-size: 1.7rem; font-weight: 650; letter-spacing: -0.02em; margin: 0; }
        .front-status { margin: 0.3rem 0 0; color: #6e6e73; font-size: 13px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px 10px 8px 0; border-bottom: 1px solid #ececf0; }
        input[type="checkbox"] { pointer-events: none; }
        img { max-width: 100%; border-radius: 10px; }
        @media (prefers-color-scheme: dark) {
          html, body { background: #1c1c1e; color: #f5f5f7; }
          pre { background: #2c2c2e; }
          .hljs-keyword, .hljs-selector-tag { color: #ff7b72; }
          .hljs-type, .hljs-title.class_, .hljs-class .hljs-title { color: #79c0ff; }
          .hljs-built_in { color: #d2a8ff; }
          .hljs-title, .hljs-section, .hljs-name, .hljs-function, .hljs-title.function_ { color: #7ee787; }
          .hljs-string, .hljs-subst { color: #e6b089; }
          .hljs-attr { color: #ffa657; }
          .hljs-comment { color: #8b9bab; }
          .hljs-number, .hljs-literal { color: #d0bf69; }
          .hljs-meta { color: #e3b341; }
          body.presenting .slide-count { color: #98989d; }
          .change-added { background: rgba(63, 185, 80, 0.18); }
          .change-removed { background: rgba(248, 81, 73, 0.15); color: #ff7b72; }
          .change-current { box-shadow: inset 0 0 0 2px #58a6ff; }
          .language-gherkin .hljs-keyword, .language-cucumber .hljs-keyword, .language-feature .hljs-keyword { color: #ff7b72; }
          .language-gherkin .hljs-symbol, .language-cucumber .hljs-symbol, .language-feature .hljs-symbol { color: #79c0ff; }
          a { color: -webkit-link; }
          blockquote { border-left-color: #48484a; color: #d1d1d6; }
          blockquote.alert-note { border-left-color: #58a6ff; background: rgba(88, 166, 255, 0.12); }
          blockquote.alert-note .alert-title { color: #58a6ff; }
          blockquote.alert-tip { border-left-color: #3fb950; background: rgba(63, 185, 80, 0.12); }
          blockquote.alert-tip .alert-title { color: #3fb950; }
          blockquote.alert-important { border-left-color: #d2a8ff; background: rgba(210, 168, 255, 0.12); }
          blockquote.alert-important .alert-title { color: #d2a8ff; }
          blockquote.alert-warning { border-left-color: #d29922; background: rgba(210, 153, 34, 0.14); }
          blockquote.alert-warning .alert-title { color: #d29922; }
          blockquote.alert-caution { border-left-color: #f85149; background: rgba(248, 81, 73, 0.12); }
          blockquote.alert-caution .alert-title { color: #f85149; }
          .front-status { color: #98989d; }
          th, td { border-bottom-color: #3a3a3c; }
        }
        </style>
        </head>
        <body>
        <article>\(body)</article>
        <script>\(highlighter)</script>
        <script>
        if (window.hljs) {
          hljs.registerLanguage("gherkin", function (hljs) {
            return {
              name: "Gherkin",
              aliases: ["cucumber", "feature"],
              contains: [
                hljs.HASH_COMMENT_MODE,
                { className: "symbol", begin: "@[^\\\\s@]+" },
                { className: "keyword", begin: "(^|\\\\n)([ \\\\t]*)(Dado|Dada|Dados|Dadas|Quando|Então|Entao|Mas|Given|When|Then|And|But|E)(?=\\\\s|$)" },
                { className: "string", begin: '"'.repeat(3), end: '"'.repeat(3) },
                hljs.QUOTE_STRING_MODE
              ]
            };
          });
          document.querySelectorAll("pre code").forEach(function (node) {
            var cls = node.className || "";
            if (cls.indexOf("language-") !== -1 && !/language-(text|plaintext|plain)/.test(cls)) return;
            var text = node.textContent || "";
            if (/^[ \\t]*@\\S+/m.test(text) && /\\b(Dado|Given|Quando|When|Então|Entao|Then)\\b/.test(text)) {
              node.classList.add("language-gherkin");
            }
          });
          hljs.highlightAll();
        }
        </script>
        <script>
        window.markmePresent = function (on) {
          var article = document.querySelector("article");
          if (!article) return;
          var existing = article.querySelectorAll(":scope > section.slide");
          if (on) {
            document.body.classList.add("presenting");
            if (existing.length) return;
            var groups = [[]];
            Array.prototype.forEach.call(article.childNodes, function (node) {
              if (node.nodeType === 1 && node.tagName === "HR") {
                groups.push([]);
                return;
              }
              groups[groups.length - 1].push(node);
            });
            groups = groups.filter(function (group) {
              return group.some(function (node) {
                return node.nodeType !== 3 || (node.textContent || "").trim() !== "";
              });
            });
            if (!groups.length) groups = [[]];
            groups.forEach(function (group) {
              var slide = document.createElement("section");
              slide.className = "slide";
              group.forEach(function (node) { slide.appendChild(node); });
              article.appendChild(slide);
            });
            var counter = document.createElement("div");
            counter.className = "slide-count";
            document.body.appendChild(counter);
            window.markmeSlide(0);
            return;
          }
          document.body.classList.remove("presenting");
          Array.prototype.forEach.call(existing, function (slide) {
            while (slide.firstChild) article.insertBefore(slide.firstChild, slide);
            slide.remove();
          });
          var counter = document.querySelector(".slide-count");
          if (counter) counter.remove();
        };
        window.markmeShowChange = function (index) {
          var marked = document.querySelectorAll(".change-current");
          for (var i = 0; i < marked.length; i++) marked[i].classList.remove("change-current");
          var key = String(index | 0);
          var nodes = document.querySelectorAll("[data-change], [data-changes]");
          var match = null;
          var best = Infinity;
          for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            var single = node.getAttribute("data-change");
            var many = (node.getAttribute("data-changes") || "").split(" ");
            var hit = single === key;
            if (!hit) {
              for (var j = 0; j < many.length; j++) if (many[j] === key) hit = true;
            }
            if (!hit) continue;
            var box = node.getBoundingClientRect();
            var area = Math.abs(box.width * box.height);
            if (area <= best) { best = area; match = node; }
          }
          if (!match) return;
          match.classList.add("change-current");
          match.scrollIntoView({ block: "center" });
        };
        window.markmeSlide = function (index) {
          var slides = document.querySelectorAll("article > section.slide");
          if (!slides.length) return 0;
          index = Math.max(0, Math.min(slides.length - 1, index | 0));
          Array.prototype.forEach.call(slides, function (slide, position) {
            slide.classList.toggle("active", position === index);
          });
          var counter = document.querySelector(".slide-count");
          if (counter) counter.textContent = (index + 1) + " / " + slides.length;
          return index;
        };
        </script>
        \(diagrams)
        </body>
        </html>
        """
    }

    public static func containsMermaidFence(_ text: String) -> Bool {
        for line in text.split(whereSeparator: \.isNewline) {
            var rest = Substring(line)
            var spaces = 0
            while rest.first == " " {
                spaces += 1
                if spaces > 3 { break }
                rest = rest.dropFirst()
            }
            if spaces > 3 || rest.first == "\t" { continue }
            let marker = rest.first
            guard marker == "`" || marker == "~" else { continue }
            var count = 0
            while rest.first == marker {
                count += 1
                rest = rest.dropFirst()
            }
            guard count >= 3 else { continue }
            while rest.first == " " || rest.first == "\t" {
                rest = rest.dropFirst()
            }
            guard rest.lowercased().hasPrefix("mermaid") else { continue }
            let after = rest.dropFirst("mermaid".count)
            if after.isEmpty || after.first?.isWhitespace == true {
                return true
            }
        }
        return false
    }

    private static func mermaidMarkup(_ library: String) -> String {
        let source = library.replacingOccurrences(
            of: "</script",
            with: "<\\/script",
            options: .caseInsensitive
        )
        return """
        <script>\(source)</script>
        <script>
        if (window.mermaid) {
          document.querySelectorAll("pre code").forEach(function (node) {
            if (!/(^|\\s)language-mermaid(\\s|$)/i.test(node.className || "")) return;
            var pre = node.parentElement;
            if (!pre) return;
            var div = document.createElement("div");
            div.className = "mermaid";
            var marks = pre.querySelectorAll("[data-change]");
            var ids = [];
            var own = pre.getAttribute("data-change") || node.getAttribute("data-change");
            if (own) ids.push(own);
            for (var i = 0; i < marks.length; i++) {
              var id = marks[i].getAttribute("data-change");
              if (id && ids.indexOf(id) < 0) ids.push(id);
            }
            if (pre.classList.contains("change-added") || node.classList.contains("change-added") || ids.length) {
              div.classList.add("change-added");
            }
            if (pre.classList.contains("change-current") || node.classList.contains("change-current") || pre.querySelector(".change-current")) {
              div.classList.add("change-current");
            }
            var listed = pre.getAttribute("data-changes") || node.getAttribute("data-changes");
            if (listed) ids = listed.split(" ");
            if (ids.length) {
              div.setAttribute("data-change", ids[0]);
              if (ids.length > 1) div.setAttribute("data-changes", ids.join(" "));
            }
            div.textContent = node.textContent || "";
            pre.replaceWith(div);
          });
          var dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
          mermaid.initialize({
            startOnLoad: false,
            securityLevel: "strict",
            theme: dark ? "dark" : "default",
            fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
          });
          mermaid.run({ querySelector: ".mermaid", suppressErrors: true }).catch(function () {});
        }
        </script>
        """
    }
}
