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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The test status is on the [CI workflow](https://github.com/vlrod/markme/actions/workflows/ci.yml).

## License

[MIT](LICENSE). Highlight.js, the Dart grammar, and Mermaid keep their own licenses. See [NOTICE](NOTICE).
People working on markme follow the [code of conduct](CODE_OF_CONDUCT.md).
Security reports go to the address in [SECURITY.md](SECURITY.md).
