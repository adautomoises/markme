# markme

[![CI](https://github.com/vlrod/markme/actions/workflows/ci.yml/badge.svg)](https://github.com/vlrod/markme/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/github/license/vlrod/markme)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://github.com/vlrod/markme)

markme opens a Markdown file so you can read it. Double-click the file in the Finder. The page is already formatted. You can select and copy the text. The file is not edited.

Requires macOS 14 or later.

## Start here

1. Build markme with the steps under [Build](#build), or use the app already in `/Applications`.
2. Double-click a `.md` file.
3. Read the page. Switch the view only when you need the source or a presentation.

A new window opens on the page. That choice lasts until you close the window. The next file opens on the page again.

One file uses one window. The file has to be UTF-8. These extensions open: `md`, `markdown`, `mdown`, `mkd`, and `mdwn`.

From Terminal:

```sh
open -a /Applications/Markme.app path/to/note.md
```

## Read

The commands are in the View menu. On a Mac set to Portuguese, the app uses the names in the Portuguese column. Every other language uses the English names.

| You want | English | Portuguese | Shortcut |
| --- | --- | --- | --- |
| The formatted page | Page | Página | ⌘3 |
| The source | Text | Texto | ⌘1 |
| Source and page together | Side by side | Lado a lado | ⌘2 |
| Slides | Presentation | Apresentação | ⌘4 |

Side by side keeps the two panes on the same source line. Scroll one, and the other follows.

### Presentation

A `---` between sections starts the next slide. The `---` of a YAML block at the top of the file does not.

Right arrow, space, and Return go forward. Left arrow goes back. Escape returns to the page.

### Zoom and find

These are in the same View menu.

| | English | Portuguese | Shortcut |
| --- | --- | --- | --- |
| Larger | Zoom In | Aumentar | ⌘+ |
| Smaller | Zoom Out | Diminuir | ⌘− |
| Back to 100% | Actual Size | Tamanho real | ⌘0 |
| Search this file | Find | Buscar | ⌘F |

Command and the mouse wheel zoom the same way. Escape closes Find. Find stays hidden during a presentation.

### Copy a place in the file

In the Edit menu, Copy Location (Copiar localização, ⇧⌘C) puts a reference on the clipboard, such as `docs/plan.md:42`.

- A selection uses the first line of that selection.
- A click with no selection uses the heading above the caret.
- Inside a git checkout, the path is relative to that checkout. Otherwise it is the full path.

Paste the reference where you need it. markme does not launch anything else.

## When the file changes

If the file changes on disk while the window is open, the new lines are marked. A bar at the top shows “1 of 3” (“1 de 3” in Portuguese) and steps through the marks. A removal says how many lines went away. Seen (Visto) clears the marks. The file on disk is left as it is.

The bar stays hidden during a presentation, and when there is nothing new to show.

## What the page shows

Headings, lists, tables, task lists, footnotes, quotes, links, images, and fenced code.

Code is colored. That includes Dart, Flutter, and Kotlin. A `gherkin` fence colors the tags and the step words. A `mermaid` fence becomes a diagram.

A GitHub alert is a quote that starts with a tag:

```markdown
> [!NOTE]
> Check the filter first.
```

`TIP`, `IMPORTANT`, `WARNING`, and `CAUTION` work the same way. The page shows a label: Note, Tip, Important, Warning, or Caution. On a Portuguese Mac those labels are Nota, Dica, Importante, Aviso, and Cuidado. The source stays a quote.

A YAML block at the top can show a title and a status on the page. The block itself stays visible when you switch to Text. Any other field stays in the source.

```markdown
---
title: Filter notes
status: draft
---
```

A wikilink opens another Markdown file in a new window. markme looks for that name in the same folder, then one folder down.

```markdown
The rest of the list is in [[weekend]].
```

If nothing matches, the brackets stay as text. A normal link whose path ends in `.md` opens the same way. A web link opens in the browser. Raw HTML is left out of the page.

Someone writing a note for this window can follow [What to tell an agent](docs/BACKLOG.md#what-to-tell-an-agent).

## Open files in markme from the Finder

The first window can ask “Open Markdown files in this viewer?” In Portuguese: “Quer abrir os markdown neste visualizador?”

- Use as default (Usar como padrão) makes markme the reader for these files. The question stays until you choose Not now.
- Not now (Agora não) hides the question.

The View menu item Use as Default Markdown Reader (Usar como leitor padrão de Markdown) sets the same reader later.

## Build

```sh
swift test
scripts/package-app.sh
open -a /Applications/Markme.app Fixtures/weekend.md
```

`scripts/package-app.sh` builds the app, signs it for this Mac, and replaces `/Applications/Markme.app`. That is the app the Finder opens. The app bundle is not committed.

The files in `Fixtures/` are made-up notes for trying the window.

## Backlog

markme stays a viewer. [docs/BACKLOG.md](docs/BACKLOG.md) is the list of ideas still worth adding, taken from [Nimbalyst](https://github.com/nimbalyst/nimbalyst) and narrowed to reading notes. Sessions, git, and editing stay out.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Test status is on the [CI workflow](https://github.com/vlrod/markme/actions/workflows/ci.yml). People changing this repository should read [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE). Highlight.js, the Dart grammar, and Mermaid keep their own licenses. See [NOTICE](NOTICE).
People working on markme follow the [code of conduct](CODE_OF_CONDUCT.md).
Security reports go to the address in [SECURITY.md](SECURITY.md).
