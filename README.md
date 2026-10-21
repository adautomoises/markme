# markme

[![CI](https://github.com/vlrod/markme/actions/workflows/ci.yml/badge.svg)](https://github.com/vlrod/markme/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/github/license/vlrod/markme)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://github.com/vlrod/markme)

A Markdown viewer for macOS. A double-click in the Finder opens the file already formatted. The window only reads: the text can be selected and copied, and it is not edited.

Requires macOS 14 or later.

## In the window

A new window opens on the page. While that window stays open, the View menu switches the mode:

| Mode | Shortcut |
| --- | --- |
| Text | ⌘1 |
| Side by side | ⌘2 |
| Page | ⌘3 |
| Presentation | ⌘4 |

On a Mac set to Portuguese, those labels are Texto, Lado a lado, Página, and Apresentação. Every other language uses the English labels.

In presentation, each `---` in the Markdown starts a slide. Right arrow, space, and Return advance. Left arrow goes back. Escape returns to the page.

Zoom is in the same menu: Zoom In (⌘+), Zoom Out (⌘−), and Actual Size (⌘0). Command and the mouse wheel use the same zoom.

When the file changes while the window is open, the new lines are marked and a bar steps through them. Seen clears the marks. The file is not edited.

Copy Location (⇧⌘C) puts a reference such as `docs/plan.md:42` on the clipboard. A selection uses that line. A caret uses the heading above it. The reference is there to paste into a coding agent. markme does not start one.

A GitHub alert (`> [!NOTE]`, tip, important, warning, caution) shows as a labeled block. YAML at the top of the file shows its title and status on the page and stays visible in the text. A wikilink such as `[[plan]]` opens a Markdown file of that name in the same folder, or one folder down.

The page colors code, including Dart, Flutter, and Kotlin. A `mermaid` fence becomes a diagram. A Gherkin fence colors the tags and the step words.

Extensions: `md`, `markdown`, `mdown`, `mkd`, `mdwn`. UTF-8 only. One file, one window.

## Build

```sh
swift test
scripts/package-app.sh
open -a "$PWD/Markme.app" Fixtures/weekend.md
```

`scripts/package-app.sh` builds `Markme.app` and ad-hoc signs it on this machine. The app bundle is not committed.

The files in `Fixtures/` are made-up notes for opening the viewer.

## Backlog

markme stays a viewer. [docs/BACKLOG.md](docs/BACKLOG.md) is the prioritized list of ideas worth taking from [Nimbalyst](https://github.com/nimbalyst/nimbalyst): show an agent's edit on the page, copy a file location back to the agent, and render the Markdown those tools already write. Sessions, git, and editing stay out.

The contract for a note written for this viewer is [What to tell an agent](docs/BACKLOG.md#what-to-tell-an-agent).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The test status is on the [CI workflow](https://github.com/vlrod/markme/actions/workflows/ci.yml). Agents working in this repository should read [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE). Highlight.js, the Dart grammar, and Mermaid keep their own licenses. See [NOTICE](NOTICE).
People working on markme follow the [code of conduct](CODE_OF_CONDUCT.md).
Security reports go to the address in [SECURITY.md](SECURITY.md).
