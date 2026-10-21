# markme 1.0 — Markdown viewer

Date: 2026-10-20

The README describes the app as it is now. This document is the original 1.0 design.

## Intent

markme is a small Markdown viewer for the Mac. The Finder opens it when someone double-clicks a file. The formatted page is there immediately.

Today that click lands in a large editor and the file arrives raw, with the markup in view. The comparison with Windows Notepad is only about three things: weight, speed, and being the system default. The window itself is an easy viewer. The page is where the person stays.

Version 1.0 only reads. Nothing is written back to the file.

## Who it is for

A person on a MacBook, in the middle of something else, who found a `.md` in the Finder, on the Desktop, in Downloads, or in a saved attachment. They want to read. They do not want to wait for a project editor to start, or to see a folder tree, git, or a plugin panel.

## Goals

- A double-click on a Markdown file in the Finder opens markme already on the formatted page.
- The person can make markme the default reader, with the confirmation macOS requires. The app does not change the default silently.
- Three modes, in the order of the IntelliJ Markdown plugin: Text, Side by side, Page.
- The page covers everyday Markdown, in full.
- The window comes up quickly and stays light in memory.
- Text can be selected and copied, in the source and on the page.
- One file, one window.

## Non-goals for 1.0

- Editing or saving the file. Cut and paste in the document stay off. Copy stays on.
- Diagrams (Mermaid and the like) and math (TeX, KaTeX, MathJax).
- Git, a folder tree, a project panel, workspace tabs, plugins, downloadable themes.
- MDX and other formats that mix executable code into Markdown.
- Exporting PDF, printing, publishing, or syncing an account.
- The App Store and notarization. 1.0 runs on the machine of the person building it.

## Decisions already made

These came from the conversation, or were stated out loud and followed from there.

- 1.0 is a viewer only.
- A native Mac app, one window per file.
- On open, the mode is always Page. Changing mode lasts while that window is open. The next open returns to Page.
- Button order, left to right: Text, Side by side, Page. Page is the selected button on open.
- Diagrams and math stay out, so the app does not load a heavy engine.

## How it is built

A SwiftUI app, using the system document model (`DocumentGroup`, read-only). That gives open, open recent, one window per file, and window restoration.

- The Text view is a native text field, read-only, monospace, with line wrap and line numbers. No syntax color. Color stays on the page.
- The Page view is HTML generated on the spot, shown in the WebKit that already ships with macOS. Do not embed another browser.
- Markdown is parsed with cmark-gfm, in-process, off the main thread.
- Code blocks on the page are colored for the common languages: bash, css, go, html, javascript, json, markdown, python, rust, sql, swift, typescript, yaml. An unknown or missing language is monospace text, without color.
- In Side by side, the text is on the left and the page is on the right. The divider starts in the middle, can be dragged, and each side keeps at least 240 points.
- The two sides scroll together in both directions, by the source line number marked on each block of the page. Matching by block is enough. Pixel matching is not required.

### Files it opens

Extensions: `md`, `markdown`, `mdown`, `mkd`, `mdwn`. It does not open `mdx` or `txt`.

Encoding: UTF-8. If the file is not UTF-8 text, the window stays open with the file name and the sentence "This file is not UTF-8 text." On a Portuguese Mac that sentence is "Este arquivo não está em texto UTF-8."

An empty file is a blank page, with the file name in the title bar and no empty-state illustration.

A large file is not cut off. The interface stays responsive while the page is built.

If the file changes on disk while the window is open, the window rereads it. If the read fails, the window shows "Could not read this file." and the short system message, without a stack trace. On a Portuguese Mac that sentence is "Não foi possível ler este arquivo."

### Page

HTML from the file does not run. Remove `script`, `iframe`, `object`, `embed`, and event attributes. Raw HTML in the Markdown is kept only as formatting.

An image with a relative path resolves from the file's folder. A remote image loads when there is a network. A path that does not open stays in the flow, with the path visible.

An `http` or `https` link opens in the default browser. A relative link to another Markdown file opens another markme window. An anchor link scrolls the page.

The page text can be selected. Copy takes the rendered text, not the markup.

The page shows, when the file has them:

- headings and subheadings at every level
- emphasis, strong, strikethrough
- lists, ordered lists, task lists
- quotes
- inline code and fenced code
- links and autolinks
- images
- tables
- a horizontal rule
- a GFM footnote, when cmark-gfm already provides it

### Window

A macOS document window. The file name is the title. No sidebar. No status bar.

One thin toolbar. At the trailing end, a segmented control with three icons, in the order above:

- Text: a text-lines icon. Shortcut Command-1.
- Side by side: a two-column icon. Shortcut Command-2.
- Page: an image icon. Shortcut Command-3.

The button for the current mode has a quiet background. All three have a tooltip.

The page uses a reading column of about 68 characters, with space at the edges. Light and dark appearance follow the Mac. There is no custom theme.

Interface and page type: the system sans. Code: the system monospace. Color only where it has a job: links, keyboard focus, and the background of the selected mode. The accent is the system accent.

Search: Command-F searches the active view. In side-by-side mode it searches both. No permanent panel.

Changing the type size was left for later. System zoom covers 1.0.

### Becoming the default reader

The app declares the document types in `Info.plist`.

On the first open, a thin bar inside the window, not a modal: "Open Markdown files in this viewer?" with "Use as default" and "Not now". "Not now" dismisses the bar and it does not come back. "Use as default" calls the system API, which may ask for confirmation. On a Portuguese Mac the bar says "Quer abrir os markdown neste visualizador?", "Usar como padrão", and "Agora não".

The same command is in the View menu, "Use as the Default Markdown Reader", for someone who dismissed the bar. On a Portuguese Mac the menu is Visualizar and the item is "Usar como leitor padrão de Markdown".

### Language

Portuguese when the Mac language is Portuguese. English otherwise. The fixed sentences are few: the modes, the default-reader bar, search, and the two read errors.

The file's own content appears as it was written.

## Calls closed after the design

The window shown on 2026-10-20 was accepted: page on open, side by side, text, system colors, and the bar only on the first open.

- macOS 14 or later. Identifier `app.markme.viewer`.
- Parser: `https://github.com/swiftlang/swift-cmark.git`, version `0.9.0`, products `cmark-gfm` and `cmark-gfm-extensions`.
- Code color: highlight.js 11 embedded in the app, light and dark theme following the Mac. No download when a file opens.
- Literal search, case-insensitive.
- A task-list checkbox does not change on click.
- No App Sandbox in 1.0, so the Finder can hand over any folder the person can already read, including iCloud.
- The `.app` comes from `scripts/package-app.sh`, with an ad-hoc signature. No developer account and no notarization.

## Left to the person building it

- Internal layout of the Swift files, as long as the public names in the plan stay.
- Fine measurements of the toolbar, within what Apple recommends for a document window.
- The exact tone of the code color, as long as the contrast works in light and dark.

## Done when

- A double-click on a real `.md` opens Page with a heading, a list, a task, a quote, colored code, a link, a local image, a table, and struck-through text.
- The three buttons and the shortcuts Command-1, Command-2, and Command-3 switch the mode. Side by side scrolls together.
- No path in the interface changes the file.
- The first-open bar and the menu item start the system confirmation to become the default reader.
- An empty file, a file that is not UTF-8, and a file that disappears from disk do not close the window.
- Raw HTML in the Markdown does not run a script.
