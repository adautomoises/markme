# Agents

markme is a read-only Markdown viewer for macOS. A double-click opens one window on the formatted page. The source can be selected and copied. The file is not edited.

Before adding a capability, read [docs/BACKLOG.md](docs/BACKLOG.md). The backlog is the priority order borrowed from Nimbalyst without taking its workspace: no agent runner, no git UI, no folder tree, no write path.

## While you change the code

- macOS 14 or later. Swift 6. Library `MarkmeCore`, app target `Markme`.
- Run `swift test` before handing work back. CI runs that plus `swift build -c release`.
- Code, comments, fixtures, and docs are English.
- Interface strings are Portuguese when the language code starts with `pt`, and English otherwise. The sentences live in `Sources/MarkmeCore/ReaderCopy.swift`. Keep both, and keep the tests that pin them.
- Gherkin step words include the Portuguese forms (`Dado`, `Quando`, `Então`, and `E`). Leave them in the highlighter.
- WebKit and AppKit stay out of `MarkmeCore`.
- Do not add telemetry, an account, or a network call on behalf of the person reading a file.
- The sample notes in `Fixtures/` are fictional. Do not put employer names, customer data, or private paths in the tree.

## Check

```sh
swift test
```
