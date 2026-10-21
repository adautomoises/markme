# Contributing

Issues and pull requests are welcome.

## Setup

You need macOS 14 or later and Swift 6.

```sh
swift test
scripts/package-app.sh
open -a /Applications/Markme.app Fixtures/weekend.md
```

`swift test` is what CI runs, plus a release build.

## Pull requests

- Keep the change focused.
- Match the style of the file you edit.
- Add or update a test when the change is in `MarkmeCore`.
- The interface is English, and Portuguese when the Mac language is Portuguese. Fixed sentences live in `Sources/MarkmeCore/ReaderCopy.swift`.
- Do not add project files, account sync, or a write path. markme only reads.
- New product work follows [docs/BACKLOG.md](docs/BACKLOG.md). [AGENTS.md](AGENTS.md) is the short version for coding agents.

## Reports

Use a bug report for something broken and a feature request for an idea. Security issues go to the address in [SECURITY.md](SECURITY.md), not to a public issue.
