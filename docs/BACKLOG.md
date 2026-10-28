# Backlog

markme is the window that opens when a Markdown file is double-clicked. It stays a light Markdown window: the formatted page first, and the source when you want to change the file. This list is what is worth taking from [Nimbalyst](https://github.com/nimbalyst/nimbalyst) so that window is a good place to read and edit the notes, plans, and reviews written with Claude Code, GitHub Copilot, Grok, and other coding agents.

Nimbalyst is a visual workspace: many agent sessions, git worktrees, a task board, a terminal, WYSIWYG editors, and a phone app. Its own markdown policy is the part that matches markme: the file on disk is the truth, the syntax is ordinary Markdown, and anything that needs a private format stays out. markme borrows that idea and leaves the workspace behind.

The README describes the app as it is today. A shipped item says so. The rest are not built yet.

## Already in the app

These overlap Nimbalyst and stay as they are.

- The formatted page is the default. Text and side by side are one menu away.
- Text and side by side edit the Markdown. The page follows. The file is written after a short pause, and ⌘S writes it at once. That write is not marked as an outside change.
- The file reloads when it changes on disk and the sentence on screen already matches the last save. The reading position is kept. New lines are marked, a short marker shows where text was removed, and a bar steps through those marks. Seen clears them. An outside write during an unfinished sentence waits for Keep mine or Use the disk.
- A minimap beside the window shows every line, marks the part on screen, and scrolls there on a click or drag. It also marks lines added, changed, or removed since the window opened, and the text gutter shows the same marks. A click on a mark shows the opened lines and can revert that change, which writes the file like any edit. The comparison is with the opened text, not with git.
- Copy Location puts `path:line` on the clipboard. A selection uses that line. A caret uses the heading above it. Inside a git checkout the path is relative to the checkout root. Nothing is launched.
- A GitHub alert shows its label. YAML at the top of the file shows title and status on the page. A wikilink opens a Markdown file in the same folder or one folder down.
- GitHub-flavored Markdown: tables, task lists, strikethrough, footnotes, autolinks.
- A `mermaid` fence becomes a diagram. Other fences are colored, including Gherkin, Dart, Flutter, and Kotlin.
- A relative link to another Markdown file opens in markme. A web link opens in the browser.
- Headings have stable ids. The page can scroll to a line in the source.
- A plan that cites a spec with `**Spec:**` in its opening is one reading: a map of the intent, goals, out of scope, and tasks, then the spec, then the plan. A task link scrolls on that page. The text view stays the opened file. No extra file is written, and a file without that line is unchanged.
- `---` starts a slide in presentation.
- The page follows the system appearance. Zoom and find are per window.

## Left in Nimbalyst

These stay there. Importing them would turn markme into a project tool.

- Running agents, sessions, kanban, workstreams, and worktrees.
- Git: staging, commits, branches, pull requests, and a terminal.
- Keeping or reverting an edit by agent session, and writing any file other than the open one. markme reverts one change against the text the window opened, and that writes only the open file.
- WYSIWYG editing, Monaco, Excalidraw, CSV grids, mockups, and an extension marketplace.
- Accounts, sync, multiplayer cursors, telemetry, and a mobile companion.
- A folder tree or a project panel. One file, one window.

## Priority

### 1. Show what the agent just changed

Shipped. The behavior is described under [Already in the app](#already-in-the-app).

### 2. Copy a location an agent can use

Shipped. The behavior is described under [Already in the app](#already-in-the-app).

### 3. Render the Markdown agents already write

Shipped. The behavior is described under [Already in the app](#already-in-the-app). Raw HTML stays stripped.

### 4. A short contract agents can be pointed at

Shipped. [What to tell an agent](#what-to-tell-an-agent) is the contract. A person working in another repo can point an agent at this file. markme does not install itself into Claude, Copilot, or Grok, and it does not read their session logs. Opening a file is `open -a Markme path/to/note.md`. A custom URL scheme stays out.

### 5. Math, only on pages that contain it

Agents emit `$inline$` and `$$blocks$$`. The original viewer left math out, and a math engine is large. Ship one only if it is loaded for a page that contains math and left out of every other page. The same rule already applies to Mermaid. Until that budget is believable, math stays out and the dollar text shows as text.

## What to tell an agent

Paste this, or point the agent at this heading, when it writes Markdown a person will read in markme.

```markdown
The human reads and edits Markdown in markme, a Mac window. Write ordinary
GitHub-flavored Markdown to the file. The window reloads when the file changes
and the person is not in the middle of a sentence.

- Use headings, lists, tables, task lists, footnotes, and fenced code.
- Put diagrams in a mermaid fence. Put slides in one file, split with ---.
- For a callout, use a GitHub alert: > [!NOTE], > [!TIP], > [!WARNING], > [!IMPORTANT], > [!CAUTION].
- Link other notes with a relative path ending in .md. Wikilinks [[name]] are fine for a file in the same folder.
- Do not write raw HTML, scripts, or a private widget syntax.
- After an edit, name the file and the line in the summary. The human copies those locations back.
```

## Working on this repository

Agents that change markme itself should read [AGENTS.md](../AGENTS.md). Product behavior stays inside the priorities above. A new capability that runs an agent or adds a project panel is outside the backlog. The open Markdown file is the only write.
