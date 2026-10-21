# markme 1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native Mac app that opens a markdown file from the Finder on the formatted page, with three read-only view modes, and can become the default markdown reader.

**Architecture:** A Swift package, `MarkmeCore`, parses GitHub-flavored markdown with cmark-gfm, sanitizes the HTML, and owns the reader state. A SwiftUI executable, `Markme`, shows that state in a document window: a read-only text view, a WebKit page, or both. `scripts/package-app.sh` wraps the binary into an ad-hoc signed `.app` so the Finder can open it.

**Tech Stack:** Swift 6.1, SwiftUI, WebKit, AppKit, swift-cmark 0.9.0, highlight.js 11 vendored in the app, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-10-20-markme-viewer-design.md`

## Global Constraints

- Version 1.0 only reads. No path in the interface writes the file. Cut and paste stay unavailable. Copy stays available.
- Every new window opens on Page. Switching mode lasts until that window closes.
- Button order, left to right: Text (Command-1), Side by side (Command-2), Page (Command-3). On a Portuguese Mac the labels are Texto, Lado a lado, and Página.
- Extensions: `md`, `markdown`, `mdown`, `mkd`, `mdwn`. Not `mdx`. Not `txt`.
- Encoding is UTF-8. Any other byte sequence shows "Este arquivo não está em texto UTF-8." when the Mac language is Portuguese.
- Empty file: blank page, file name in the title, no empty-state illustration.
- No Mermaid engine and no math engine. A mermaid fence stays a code block.
- Raw HTML from the file must not execute. Strip `script`, `iframe`, `object`, `embed`, and event attributes.
- Page column is `68ch`. Type is the system sans. Code is the system monospace. Light and dark follow the Mac.
- No App Sandbox. Bundle id `app.markme.viewer`. Minimum system macOS 14.0.
- Parser package `https://github.com/swiftlang/swift-cmark.git` at `0.9.0`.
- Portuguese copy when the language code starts with `pt`. English otherwise.
- Search is literal and case-insensitive. An empty query matches nothing.
- Task-list checkboxes do not toggle.
- Remote images may load. Nothing else in the app uses the network.

## Review Focus

- Mixed-case `<SCRIPT>` and an `onerror` attribute must not survive in the page HTML. Pinned in Task 2.
- A `javascript:` link must not survive as a URL. Pinned in Task 2.
- A new file opens on Page even when the value `.source` exists in the type. Pinned in Task 4.
- Rereading the file after an outside edit keeps the current mode. Pinned in Task 4.
- A relative link such as `sub/guide.md` is a markdown file to open, not a browser URL and not a navigation inside the page. Pinned in Task 3.

---

## File structure

- `Package.swift` — products `MarkmeCore` (library) and `Markme` (executable).
- `Sources/MarkmeCore/MarkdownPage.swift` — parse, render, sanitize.
- `Sources/MarkmeCore/SourceMap.swift` — `data-sourcepos` blocks and scroll mapping.
- `Sources/MarkmeCore/LinkAction.swift` — what a clicked URL does.
- `Sources/MarkmeCore/PageShell.swift` — the HTML document around the body.
- `Sources/MarkmeCore/ReaderModel.swift` — open, reload, mode, banner, split, find.
- `Sources/MarkmeCore/ReaderCopy.swift` — the fixed strings.
- `Tests/MarkmeCoreTests/` — one test file per type above, plus `InfoPlistTests.swift`.
- `Sources/Markme/MarkmeApp.swift` — `App`, commands, shortcuts.
- `Sources/Markme/ReaderDocument.swift` — read-only `FileDocument`.
- `Sources/Markme/ReaderView.swift` — toolbar, banner, mode switch.
- `Sources/Markme/PageWebView.swift` — `WKWebView`, base URL, cancelled navigation.
- `Sources/Markme/SourceTextView.swift` — read-only `NSTextView`.
- `Sources/Markme/DefaultReader.swift` — system default-app request.
- `App/Info.plist` — document types.
- `App/Resources/highlight.min.js` — vendored highlighter.
- `scripts/package-app.sh` — build the `.app` and ad-hoc sign it.

`Markme` imports `MarkmeCore` and does not reimplement parsing. WebKit and AppKit stay out of `MarkmeCore`.

### Task 1: Parse everyday markdown

**Files:**
- Create: `Package.swift`
- Create: `Sources/MarkmeCore/MarkdownPage.swift`
- Test: `Tests/MarkmeCoreTests/MarkdownPageTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `public struct MarkdownPage: Equatable, Sendable { public var htmlBody: String }`
  - `public enum MarkdownRenderer { public static func render(_ markdown: String) -> MarkdownPage }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MarkmeCore

final class MarkdownPageTests: XCTestCase {
    func testEverydayMarkdown() {
        let source = """
        # House

        Text *italic* and **strong** and ~~old~~.

        - um
        - dois

        1. primeiro

        > quote

        `line`

        ---

        https://example.com
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("<h1"))
        XCTAssertTrue(html.contains("<em>"))
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<del>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("<code>"))
        XCTAssertTrue(html.contains("<hr"))
        XCTAssertTrue(html.contains("https://example.com"))
    }

    func testTableTaskAndFootnoteBodySurvive() {
        let source = """
        | Item | Qtd |
        | --- | --- |
        | Milk | 2 |

        - [x] cylinder
        - [ ] caixa

        Texto [^1].

        [^1]: Origem

        ## Depois
        """
        let html = MarkdownRenderer.render(source).htmlBody
        XCTAssertTrue(html.contains("<table"))
        XCTAssertTrue(html.contains("Milk"))
        XCTAssertTrue(html.contains("checkbox"))
        XCTAssertTrue(html.contains("Origem"))
        XCTAssertTrue(html.contains("Depois"))
    }

    func testFencedCodeCarriesLanguageAndPlainFenceDoesNot() {
        let swift = MarkdownRenderer.render("```swift\nlet a = 1\n```").htmlBody
        XCTAssertTrue(swift.contains("language-swift"))
        let plain = MarkdownRenderer.render("```\nlet a = 1\n```").htmlBody
        XCTAssertFalse(plain.contains("language-"))
    }

    func testMermaidStaysACodeBlock() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```").htmlBody
        XCTAssertTrue(html.contains("language-mermaid"))
        XCTAssertFalse(html.contains("<svg"))
    }

    func testSourcePositionIsMarked() {
        let html = MarkdownRenderer.render("# House\n\nParagraph.\n").htmlBody
        XCTAssertTrue(html.contains("data-sourcepos=\"1:"))
    }

    func testImageKeepsItsPathAsText() {
        let html = MarkdownRenderer.render("![](fotos/planta.png)").htmlBody
        XCTAssertTrue(html.contains("fotos/planta.png"))
        XCTAssertTrue(html.contains("alt=\"fotos/planta.png\""))
    }

    func testThousandsOfLinesStillRenderTheEnd() {
        var lines = Array(repeating: "line", count: 5000)
        lines.append("## End")
        let html = MarkdownRenderer.render(lines.joined(separator: "\n")).htmlBody
        XCTAssertTrue(html.contains("End"))
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `swift test --filter MarkdownPageTests`
Expected: FAIL because `MarkdownRenderer` does not exist.

- [ ] **Step 3: Implement the package and `MarkdownRenderer.render(_:)`**

`Package.swift` tools version `6.0`, platform `.macOS(.v14)`. Dependency `https://github.com/swiftlang/swift-cmark.git` exact `0.9.0`. Library target `MarkmeCore` links products `cmark-gfm` and `cmark-gfm-extensions`.

`render` creates a cmark parser, registers the core GFM extensions (`table`, `strikethrough`, `autolink`, `tagfilter`, `tasklist`, and `footnote` only when `cmark_find_syntax_extension` returns it), renders HTML with source positions and raw HTML enabled, then runs the sanitizer from Task 2. Until Task 2 lands, return the cmark HTML unchanged so Task 1's tests pass.

Attach `data-sourcepos` via cmark's source-position option. When an image has an empty alt, set the alt to its path so a missing file still shows that path. Do not add a Mermaid or math pass.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `swift test --filter MarkdownPageTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/MarkmeCore/MarkdownPage.swift Tests/MarkmeCoreTests/MarkdownPageTests.swift
git commit -m "feat: render everyday markdown to HTML"
```

### Task 2: Strip active HTML

**Files:**
- Modify: `Sources/MarkmeCore/MarkdownPage.swift`
- Modify: `Tests/MarkmeCoreTests/MarkdownPageTests.swift`

**Interfaces:**
- Consumes: `MarkdownRenderer.render(_:)`
- Produces: the same function, now sanitized. No new public type.

- [ ] **Step 1: Write the failing test**

```swift
func testDangerousHTMLIsStripped() {
    let html = MarkdownRenderer.render(
        "<script>alert(1)</script><ScRiPt>alert(2)</ScRiPt><p onclick=\"alert(3)\">oi</p><img src=\"a.png\" onerror=\"alert(4)\"><iframe src=\"https://evil.test\"></iframe><object data=\"x\"></object><embed src=\"y\"></embed><a href=\"javascript:alert(5)\">x</a><strong>negrito</strong>texto"
    ).htmlBody
    XCTAssertTrue(html.contains("oi"))
    XCTAssertTrue(html.contains("negrito"))
    XCTAssertTrue(html.contains("texto"))
    XCTAssertTrue(html.contains("a.png"))
    XCTAssertFalse(html.lowercased().contains("<script"))
    XCTAssertFalse(html.contains("alert(1)"))
    XCTAssertFalse(html.contains("alert(2)"))
    XCTAssertFalse(html.contains("onclick"))
    XCTAssertFalse(html.contains("onerror"))
    XCTAssertFalse(html.lowercased().contains("<iframe"))
    XCTAssertFalse(html.lowercased().contains("<object"))
    XCTAssertFalse(html.lowercased().contains("<embed"))
    XCTAssertFalse(html.lowercased().contains("javascript:"))
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `swift test --filter MarkdownPageTests/testDangerousHTMLIsStripped`
Expected: FAIL because `javascript:` or `<script` is still present.

- [ ] **Step 3: Sanitize inside `render` before returning**

Remove `script`, `iframe`, `object`, and `embed` elements together with their contents, case-insensitive. Remove any attribute whose name starts with `on`, case-insensitive. Replace a `href` or `src` whose scheme is `javascript` with an empty value. Keep ordinary formatting tags, including `strong`, `img`, and links that are not `javascript:`.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `swift test --filter MarkdownPageTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MarkmeCore/MarkdownPage.swift Tests/MarkmeCoreTests/MarkdownPageTests.swift
git commit -m "fix: strip active HTML from rendered markdown"
```

### Task 3: Links and the source map

**Files:**
- Create: `Sources/MarkmeCore/LinkAction.swift`
- Create: `Sources/MarkmeCore/SourceMap.swift`
- Test: `Tests/MarkmeCoreTests/LinkActionTests.swift`
- Test: `Tests/MarkmeCoreTests/SourceMapTests.swift`

**Interfaces:**
- Consumes: `MarkdownPage.htmlBody`
- Produces:
  - `public enum LinkAction: Equatable, Sendable { case browser(URL); case markdownFile(URL); case anchor(String); case ignore }`
  - `public enum LinkResolver { public static func resolve(href: String, baseDirectory: URL) -> LinkAction }`
  - `public struct SourceBlock: Equatable, Sendable { public var startLine: Int; public var endLine: Int }`
  - `public enum SourceMap { public static func blocks(in html: String) -> [SourceBlock]; public static func blockIndex(forSourceLine line: Int, blocks: [SourceBlock]) -> Int?; public static func sourceLine(forBlockIndex index: Int, blocks: [SourceBlock]) -> Int? }`

- [ ] **Step 1: Write the failing tests**

```swift
func testResolve() {
    let base = URL(fileURLWithPath: "/tmp/notes")
    XCTAssertEqual(LinkResolver.resolve(href: "https://example.com/a", baseDirectory: base), .browser(URL(string: "https://example.com/a")!))
    XCTAssertEqual(LinkResolver.resolve(href: "http://example.com", baseDirectory: base), .browser(URL(string: "http://example.com")!))
    XCTAssertEqual(LinkResolver.resolve(href: "#compras", baseDirectory: base), .anchor("compras"))
    XCTAssertEqual(LinkResolver.resolve(href: "guide.md", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/guide.md")))
    XCTAssertEqual(LinkResolver.resolve(href: "Guide.MD", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/Guide.MD")))
    XCTAssertEqual(LinkResolver.resolve(href: "sub/guide.mdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/sub/guide.mdown")))
    XCTAssertEqual(LinkResolver.resolve(href: "note.markdown", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/note.markdown")))
    XCTAssertEqual(LinkResolver.resolve(href: "a.mkd", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/a.mkd")))
    XCTAssertEqual(LinkResolver.resolve(href: "a.mdwn", baseDirectory: base), .markdownFile(URL(fileURLWithPath: "/tmp/notes/a.mdwn")))
    XCTAssertEqual(LinkResolver.resolve(href: "mailto:a@b.c", baseDirectory: base), .ignore)
    XCTAssertEqual(LinkResolver.resolve(href: "javascript:alert(1)", baseDirectory: base), .ignore)
}

func testMap() {
    let html = "<h1 data-sourcepos=\"1:1-1:5\">A</h1><p data-sourcepos=\"4:1-5:3\">B</p>"
    let blocks = SourceMap.blocks(in: html)
    XCTAssertEqual(blocks.map(\.startLine), [1, 4])
    XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 1, blocks: blocks), 0)
    XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 3, blocks: blocks), 0)
    XCTAssertEqual(SourceMap.blockIndex(forSourceLine: 5, blocks: blocks), 1)
    XCTAssertEqual(SourceMap.sourceLine(forBlockIndex: 1, blocks: blocks), 4)
    XCTAssertNil(SourceMap.blockIndex(forSourceLine: 0, blocks: blocks))
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `swift test --filter 'LinkActionTests|SourceMapTests'`
Expected: FAIL because the types do not exist.

- [ ] **Step 3: Implement `LinkResolver` and `SourceMap`**

Markdown extensions are `md`, `markdown`, `mdown`, `mkd`, `mdwn`, compared case-insensitive on the path extension, ignoring a query or fragment. `#compras` is an anchor. `http` and `https` are browser URLs. Anything else, including `mailto` and `javascript`, is `.ignore`.

`blocks` reads every `data-sourcepos="START:COL-END:COL"` in order. `blockIndex` returns the last block whose `startLine` is less than or equal to the line. `sourceLine` returns that block's `startLine`, or nil when the index is out of range.

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `swift test --filter 'LinkActionTests|SourceMapTests'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MarkmeCore/LinkAction.swift Sources/MarkmeCore/SourceMap.swift Tests/MarkmeCoreTests/LinkActionTests.swift Tests/MarkmeCoreTests/SourceMapTests.swift
git commit -m "feat: classify links and map source lines"
```

### Task 4: Reader state, copy, and find

**Files:**
- Create: `Sources/MarkmeCore/ReaderModel.swift`
- Create: `Sources/MarkmeCore/ReaderCopy.swift`
- Create: `Sources/MarkmeCore/PageShell.swift`
- Test: `Tests/MarkmeCoreTests/ReaderModelTests.swift`
- Test: `Tests/MarkmeCoreTests/ReaderCopyTests.swift`
- Test: `Tests/MarkmeCoreTests/PageShellTests.swift`

**Interfaces:**
- Consumes: nothing from the renderer. The app combines them later.
- Produces:
  - `public enum ReaderMode: String, Equatable, Sendable { case source, split, page }`
  - `public enum OpenFailure: Equatable, Sendable { case notUTF8; case unreadable }`
  - `public struct ReaderModel: Equatable, Sendable { public var fileName: String; public var text: String; public var failure: OpenFailure?; public var mode: ReaderMode; public var bannerDismissed: Bool; public init(fileName: String, data: Data?, bannerDismissed: Bool); public mutating func reload(data: Data?); public mutating func dismissBannerForever(); public var showsBanner: Bool { get } }`
  - `public struct SplitFraction: Equatable, Sendable { public static let minimumSide: CGFloat; public var fraction: CGFloat; public init(); public mutating func drag(translation: CGFloat, width: CGFloat) }`
  - `public enum TextFind { public static func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] }`
  - `public struct ScrollSync: Equatable, Sendable { public static let echoInterval: TimeInterval; public mutating func markEcho(now: Date); public func isEcho(now: Date) -> Bool }`
  - `public enum CopyKey: String, Sendable { case modeSource, modeSplit, modePage, bannerQuestion, bannerAccept, bannerNotNow, menuMakeDefault, notUTF8, unreadable, findPrompt }`
  - `public enum ReaderCopy { public static func string(_ key: CopyKey, languageCode: String) -> String }`
  - `public enum PageShell { public static func html(body: String, highlighter: String) -> String }`
  - `public enum SourceTextConfiguration { public static let isEditable: Bool; public static let isSelectable: Bool }`

- [ ] **Step 1: Write the failing tests**

```swift
func testNewModelOpensOnPage() {
    let model = ReaderModel(fileName: "a.md", data: Data("hello".utf8), bannerDismissed: false)
    XCTAssertEqual(model.mode, .page)
    XCTAssertEqual(model.text, "hello")
    XCTAssertNil(model.failure)
    XCTAssertTrue(model.showsBanner)
}

func testEmptyFileIsABlankDocument() {
    let model = ReaderModel(fileName: "a.md", data: Data(), bannerDismissed: true)
    XCTAssertEqual(model.text, "")
    XCTAssertNil(model.failure)
    XCTAssertFalse(model.showsBanner)
}

func testNotUTF8() {
    let model = ReaderModel(fileName: "a.md", data: Data([0xFF, 0xFE]), bannerDismissed: true)
    XCTAssertEqual(model.failure, .notUTF8)
}

func testMissingFile() {
    let model = ReaderModel(fileName: "a.md", data: nil, bannerDismissed: true)
    XCTAssertEqual(model.failure, .unreadable)
}

func testReloadKeepsMode() {
    var model = ReaderModel(fileName: "a.md", data: Data("antes".utf8), bannerDismissed: true)
    model.mode = .source
    model.reload(data: Data("depois".utf8))
    XCTAssertEqual(model.mode, .source)
    XCTAssertEqual(model.text, "depois")
    XCTAssertNil(model.failure)
    model.reload(data: nil)
    XCTAssertEqual(model.mode, .source)
    XCTAssertEqual(model.text, "depois")
    XCTAssertEqual(model.failure, .unreadable)
}

func testDismissBannerStaysDismissed() {
    var model = ReaderModel(fileName: "a.md", data: Data(), bannerDismissed: false)
    model.dismissBannerForever()
    XCTAssertFalse(model.showsBanner)
}

func testSplitClampsTo240() {
    var split = SplitFraction()
    XCTAssertEqual(split.fraction, 0.5)
    split.drag(translation: -400, width: 1000)
    XCTAssertEqual(split.fraction, 0.24, accuracy: 0.001)
    split.drag(translation: 800, width: 1000)
    XCTAssertEqual(split.fraction, 0.76, accuracy: 0.001)
}

func testFindIsLiteralAndCaseInsensitive() {
    let text = "casa CASA a.b"
    XCTAssertEqual(TextFind.ranges(of: "", in: text).count, 0)
    XCTAssertEqual(TextFind.ranges(of: "casa", in: text).count, 2)
    XCTAssertEqual(TextFind.ranges(of: "a.b", in: text).count, 1)
    XCTAssertEqual(TextFind.ranges(of: "a.", in: "abc").count, 0)
}

func testEchoLock() {
    var sync = ScrollSync()
    let now = Date(timeIntervalSince1970: 1_000)
    sync.markEcho(now: now)
    XCTAssertTrue(sync.isEcho(now: now.addingTimeInterval(0.05)))
    XCTAssertFalse(sync.isEcho(now: now.addingTimeInterval(ScrollSync.echoInterval)))
}

func testPortugueseAndEnglishCopy() {
    XCTAssertEqual(ReaderCopy.string(.modeSource, languageCode: "pt-BR"), "Texto")
    XCTAssertEqual(ReaderCopy.string(.modeSplit, languageCode: "pt"), "Lado a lado")
    XCTAssertEqual(ReaderCopy.string(.modePage, languageCode: "pt-BR"), "Página")
    XCTAssertEqual(ReaderCopy.string(.bannerQuestion, languageCode: "pt-BR"), "Quer abrir os markdown neste visualizador?")
    XCTAssertEqual(ReaderCopy.string(.bannerAccept, languageCode: "pt-BR"), "Usar como padrão")
    XCTAssertEqual(ReaderCopy.string(.bannerNotNow, languageCode: "pt-BR"), "Agora não")
    XCTAssertEqual(ReaderCopy.string(.menuMakeDefault, languageCode: "pt-BR"), "Usar como leitor padrão de Markdown")
    XCTAssertEqual(ReaderCopy.string(.notUTF8, languageCode: "pt-BR"), "Este arquivo não está em texto UTF-8.")
    XCTAssertEqual(ReaderCopy.string(.unreadable, languageCode: "pt-BR"), "Não foi possível ler este arquivo.")
    XCTAssertEqual(ReaderCopy.string(.findPrompt, languageCode: "pt-BR"), "Buscar")
    XCTAssertEqual(ReaderCopy.string(.modeSource, languageCode: "en"), "Text")
    XCTAssertEqual(ReaderCopy.string(.modeSplit, languageCode: "fr"), "Side by side")
    XCTAssertEqual(ReaderCopy.string(.modePage, languageCode: "en"), "Page")
    XCTAssertEqual(ReaderCopy.string(.bannerQuestion, languageCode: "en"), "Open Markdown files in this viewer?")
    XCTAssertEqual(ReaderCopy.string(.notUTF8, languageCode: "en"), "This file is not UTF-8 text.")
    XCTAssertEqual(ReaderCopy.string(.unreadable, languageCode: "en"), "Could not read this file.")
}

func testShellContract() {
    let html = PageShell.html(body: "<p>oi</p>", highlighter: "HIGHLIGHTJS")
    XCTAssertTrue(html.contains("<p>oi</p>"))
    XCTAssertTrue(html.contains("HIGHLIGHTJS"))
    XCTAssertTrue(html.contains("hljs.highlightAll"))
    XCTAssertTrue(html.contains("max-width: 68ch"))
    XCTAssertTrue(html.contains("-apple-system"))
    XCTAssertTrue(html.contains("ui-monospace"))
    XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
    XCTAssertTrue(html.contains("user-select: text"))
    XCTAssertTrue(html.contains("pointer-events: none"))
    XCTAssertTrue(html.contains("default-src 'none'"))
    XCTAssertTrue(html.contains("script-src 'unsafe-inline'"))
    XCTAssertTrue(html.contains("img-src file: https: http: data:"))
    XCTAssertFalse(html.contains("script-src 'self'"))
}

func testSourceCannotBeEdited() {
    XCTAssertFalse(SourceTextConfiguration.isEditable)
    XCTAssertTrue(SourceTextConfiguration.isSelectable)
}
```

`SplitFraction.minimumSide` is `240`. `ScrollSync.echoInterval` is `0.1`. `isEcho` is true while `now` is strictly before `markEcho`'s date plus that interval.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `swift test --filter 'ReaderModelTests|ReaderCopyTests|PageShellTests'`
Expected: FAIL because the types do not exist.

- [ ] **Step 3: Implement the types**

`ReaderModel.init` always sets `mode` to `.page`. `data == nil` sets `.unreadable`. Data that is not valid UTF-8 sets `.notUTF8` and leaves `text` empty. Empty data is a successful empty document. `reload` with valid UTF-8 replaces `text`, clears `failure`, and does not change `mode`. `reload(nil)` sets `.unreadable`, keeps `text`, and keeps `mode`. `showsBanner` is the inverse of `bannerDismissed`.

`drag` moves the fraction by `translation / width` and clamps so each side stays at least `minimumSide` when `width` is large enough. If `width` is under `480`, keep the fraction inside `0.5`.

`TextFind` uses a case-insensitive literal search, not a regular expression.

`PageShell.html` returns a full HTML document. The content security policy is exactly `default-src 'none'; img-src file: https: http: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'`. Inline the `highlighter` argument and call `hljs.highlightAll`. Style the reading column, both color schemes, selection, and disabled checkboxes as the tests require. Do not load a script from the file's directory.

English strings not listed in the test: "Use as default", "Not now", "Use as Default Markdown Reader", "Find".

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `swift test --filter 'ReaderModelTests|ReaderCopyTests|PageShellTests'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MarkmeCore/ReaderModel.swift Sources/MarkmeCore/ReaderCopy.swift Sources/MarkmeCore/PageShell.swift Tests/MarkmeCoreTests/ReaderModelTests.swift Tests/MarkmeCoreTests/ReaderCopyTests.swift Tests/MarkmeCoreTests/PageShellTests.swift
git commit -m "feat: add reader state, copy, and page shell"
```

### Task 5: Page window

**Files:**
- Create: `Sources/Markme/MarkmeApp.swift`
- Create: `Sources/Markme/ReaderDocument.swift`
- Create: `Sources/Markme/ReaderView.swift`
- Create: `Sources/Markme/PageWebView.swift`
- Create: `App/Info.plist`
- Create: `App/Resources/highlight.min.js`
- Create: `scripts/package-app.sh`
- Modify: `Package.swift`
- Test: `Tests/MarkmeCoreTests/InfoPlistTests.swift`

**Interfaces:**
- Consumes: `ReaderModel`, `ReaderCopy`, `PageShell`, `MarkdownRenderer`, `LinkResolver`, `OpenFailure`
- Produces: `Markme.app`. `ReaderDocument` is a read-only `FileDocument`. `writableContentTypes` is empty. `fileWrapper(configuration:)` throws `CocoaError(.fileWriteNoPermission)`.

- [ ] **Step 1: Write the failing plist test**

```swift
func testInfoPlistDeclaresAReadOnlyMarkdownViewer() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("App/Info.plist")
    let data = try Data(contentsOf: url)
    let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "app.markme.viewer")
    XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "14.0")
    let types = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])
    let type = try XCTUnwrap(types.first)
    XCTAssertEqual(type["CFBundleTypeRole"] as? String, "Viewer")
    XCTAssertEqual(type["LSHandlerRank"] as? String, "Owner")
    let extensions = try XCTUnwrap(type["CFBundleTypeExtensions"] as? [String])
    XCTAssertEqual(Set(extensions), Set(["md", "markdown", "mdown", "mkd", "mdwn"]))
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `swift test --filter InfoPlistTests`
Expected: FAIL because `App/Info.plist` does not exist.

- [ ] **Step 3: Open a file on the page**

Add executable target `Markme` depending on `MarkmeCore`. No `main.swift`. Entry is `@main struct MarkmeApp: App` with `DocumentGroup(viewing: ReaderDocument.self)`. With no file, the system open panel appears. There is no sample document.

`ReaderDocument` keeps the bytes and the file URL. Invalid UTF-8 still opens a window. `ReaderView` builds a `ReaderModel` and, when `failure` is nil, renders on a detached task and publishes `PageShell.html` on the main actor. The `WKWebView` uses the file's directory as `baseURL`. Its navigation delegate cancels every navigation, then runs `LinkResolver.resolve`: `.browser` opens with `NSWorkspace`, `.markdownFile` opens that file URL with `NSWorkspace`, `.anchor` sets the page hash, `.ignore` does nothing. The web view is not editable. Copy stays the system's copy of the composed text.

`.notUTF8` and `.unreadable` show the matching `ReaderCopy` sentence in the window. The window stays up. The title is the file name. No sidebar and no status bar.

Vendor highlight.js 11, core plus bash, css, go, html, javascript, json, markdown, python, rust, sql, swift, typescript, and yaml, into `App/Resources/highlight.min.js`. Pass its text as `highlighter`. Do not download it when a file opens.

`App/Info.plist` matches the test. `CFBundleExecutable` is `Markme`, `CFBundlePackageType` is `APPL`, `CFBundleName` is `markme`. Declare `net.daringfireball.markdown` and imported UTIs for the five extensions, conforming to `public.plain-text`. No sandbox entitlement.

`scripts/package-app.sh` builds release, lays out `Markme.app`, copies the binary, the plist, and the highlighter, then runs `codesign --force --deep --sign - Markme.app`.

- [ ] **Step 4: Verify**

Run: `swift test`
Expected: PASS

Run: `bash scripts/package-app.sh`
Expected: exit 0, and `codesign -dv Markme.app 2>&1` contains `Signature=adhoc`.

`open -a "$PWD/Markme.app" caminho/de/um.md` opens that file on the formatted page.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Markme App scripts/package-app.sh Tests/MarkmeCoreTests/InfoPlistTests.swift
git commit -m "feat: open markdown on the formatted page"
```

### Task 6: Text, split, scroll, and find

**Files:**
- Create: `Sources/Markme/SourceTextView.swift`
- Modify: `Sources/Markme/ReaderView.swift`
- Modify: `Sources/Markme/MarkmeApp.swift`

**Interfaces:**
- Consumes: `ReaderMode`, `SourceTextConfiguration`, `SplitFraction`, `TextFind`, `ScrollSync`, `SourceMap`, `ReaderCopy`
- Produces: the three modes in one window. No new core type.

- [ ] **Step 1: Confirm the core pins still pass**

Run: `swift test --filter 'testSourceCannotBeEdited|testSplitClampsTo240|testFindIsLiteralAndCaseInsensitive|testEchoLock|testMap'`
Expected: PASS. These pins are what this task wires up. There is no separate UI test target.

- [ ] **Step 2: Add the three modes**

The toolbar's trailing control is three buttons, order `.source`, `.split`, `.page`, labels and help from `ReaderCopy`. The selected button has a quiet rounded fill. Command-1, Command-2, and Command-3 switch mode.

Source mode is an `NSTextView` with `isEditable` and `isSelectable` from `SourceTextConfiguration`, line wrapping on, a monospace font, a line-number gutter, and no syntax colors. Split puts the source on the left and the page on the right, starting at `SplitFraction().fraction`. Dragging calls `drag(translation:width:)`.

Scroll sync uses `SourceMap` and `ScrollSync`. A scroll on one side, when `isEcho` is false, scrolls the other side and calls `markEcho`.

Command-F shows a find field, placeholder `CopyKey.findPrompt`. The source scrolls to `TextFind` ranges. The page uses `WKWebView.find`. Split runs both. An empty query clears the highlights.

- [ ] **Step 3: Verify the app still builds**

Run: `bash scripts/package-app.sh`
Expected: exit 0.

Open one markdown file and switch all three modes with the buttons and with Command-1, Command-2, and Command-3. In split, scrolling either side moves the other. Command-F finds a word that differs only by case.

- [ ] **Step 4: Commit**

```bash
git add Sources/Markme/SourceTextView.swift Sources/Markme/ReaderView.swift Sources/Markme/MarkmeApp.swift
git commit -m "feat: add source, split, and find"
```

### Task 7: Default reader and live reload

**Files:**
- Create: `Sources/Markme/DefaultReader.swift`
- Modify: `Sources/Markme/ReaderView.swift`
- Modify: `Sources/Markme/MarkmeApp.swift`

**Interfaces:**
- Consumes: `ReaderModel.dismissBannerForever()`, `ReaderModel.reload(data:)`, `ReaderModel.showsBanner`, `ReaderCopy`
- Produces: `DefaultReader.request()`, which asks macOS to make this bundle the default app for the markdown UTIs in `App/Info.plist`.

- [ ] **Step 1: Confirm the banner pin still passes**

Run: `swift test --filter 'testDismissBannerStaysDismissed|testReloadKeepsMode'`
Expected: PASS.

- [ ] **Step 2: Add the banner, the menu, and the file watch**

The banner is a bar under the toolbar, not a modal. Copy comes from `bannerQuestion`, `bannerNotNow`, and `bannerAccept`. `showsBanner` decides visibility. The model is created with `bannerDismissed` read from `UserDefaults` key `markme.bannerDismissed`. "Not now" calls `dismissBannerForever()` and sets that key to true. It does not return. "Use as default" calls `DefaultReader.request()`. The View menu item uses `menuMakeDefault` and the same call. On a Portuguese Mac those labels are "Agora não", "Usar como padrão", and the menu title is Visualizar.

`DefaultReader.request()` calls `NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenContentType:)` for `net.daringfireball.markdown` and each imported extension UTI. The system may ask the person to confirm. The app does not change the default by itself at launch.

Watch the open file with `DispatchSource` for write, rename, delete, and link. Debounce 150 milliseconds, reread the bytes off the main actor, and call `reload(data:)` on the main actor. `nil` data when the file is gone. A failed reread does not close the window.

- [ ] **Step 3: Verify**

Run: `bash scripts/package-app.sh`
Expected: exit 0.

Open a markdown file. The banner is visible the first time and stays gone after "Not now". Edit the same file in another program and save: the page updates and the current mode stays. Move the file to the Trash: the window shows the unreadable sentence and stays open.

- [ ] **Step 4: Commit**

```bash
git add Sources/Markme/DefaultReader.swift Sources/Markme/ReaderView.swift Sources/Markme/MarkmeApp.swift
git commit -m "feat: offer the default reader and reload on disk changes"
```
