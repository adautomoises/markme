# Backlog

markme is the window that opens when a Markdown file is double-clicked. It stays a light, read-only viewer. This list is what is worth taking from [Nimbalyst](https://github.com/nimbalyst/nimbalyst) so that window is a good place to read the notes, plans, and reviews written with Claude Code, GitHub Copilot, Grok, and other coding agents.

Nimbalyst is a visual workspace: many agent sessions, git worktrees, a task board, a terminal, WYSIWYG editors, and a phone app. Its own markdown policy is the part that matches markme: the file on disk is the truth, the syntax is ordinary Markdown, and anything that needs a private format stays out. markme borrows that idea and leaves the workspace behind.

The README describes the app as it is today. Items below are not built yet.

## Already in the app

These overlap Nimbalyst and stay as they are.

- The formatted page is the default. Text and side by side are one menu away.
- The file reloads when it changes on disk. The reading position is kept.
- GitHub-flavored Markdown: tables, task lists, strikethrough, footnotes, autolinks.
- A `mermaid` fence becomes a diagram. Other fences are colored, including Gherkin, Dart, Flutter, and Kotlin.
- A relative link to another Markdown file opens in markme. A web link opens in the browser.
- Headings have stable ids. The page can scroll to a line in the source.
- `---` starts a slide in presentation.
- The page follows the system appearance. Zoom and find are per window.

## Left in Nimbalyst

These stay there. Importing them would turn markme into a project tool.

- Running agents, sessions, kanban, workstreams, and worktrees.
- Git: staging, commits, branches, pull requests, and a terminal.
- Writing the file. Nimbalyst can keep or revert an agent edit. Revert writes the file. markme only reads. Cut and paste inside the document stay off. Copy stays on.
- WYSIWYG editing, Monaco, Excalidraw, CSV grids, mockups, and an extension marketplace.
- Accounts, sync, multiplayer cursors, telemetry, and a mobile companion.
- A folder tree or a project panel. One file, one window.

## Priority

### 1. Show what the agent just changed

When the file on disk changes, the page updates and the new regions are marked. Removed text leaves a short marker at that spot. Next and previous step through the marks. Dismissing them means the change has been seen. The file is not rewritten.

This is Nimbalyst's red and green review, cut down to a viewer. There the agent writes the file immediately, Keep only clears the highlight, and Revert writes the old text back. markme does the highlight. Putting the old text back stays with the agent, or with git outside this app.

The source map already ties a block on the page to lines in the file. The diff runs off the main thread. A page with no reload looks as it does today.

### 2. Copy a location an agent can use

From a selection or a heading, copy a reference such as `docs/plan.md:42`. The person pastes it into Claude Code, Copilot, Grok, or another agent. Nimbalyst starts a session with `@file` from the open document. markme only copies the reference. It does not start an agent and it does not embed a chat.

The same copy works in Text, side by side, and Page. The line number comes from the source map.

### 3. Render the Markdown agents already write

Three syntaxes show up constantly in agent output. Each one is still a Markdown file another viewer can open.

- GitHub alerts: a blockquote that starts with `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, or `[!CAUTION]`. The page shows the label and a distinct block. The source stays a blockquote.
- YAML front matter. Page mode shows the title and a status line when those fields exist, and hides the raw block. Text mode still shows the YAML. Unknown fields stay in the source only. There is no database of documents.
- Wikilinks written as `[[name]]` or `[[name|label]]`. A match opens that Markdown file in a new window, the same way a relative link does. The search is the file's folder and one level of children, by file name, case-insensitive. No match stays ordinary text. There is no vault index and no backlink panel.

Raw HTML stays stripped, as it is now. Agents are asked to use Markdown instead.

### 4. A short contract agents can be pointed at

The section [What to tell an agent](#what-to-tell-an-agent) is the contract. A person working in another repo can point the agent at this file. markme does not install itself into Claude, Copilot, or Grok, and it does not read their session logs.

Opening a file from an agent is the command that already works:

```sh
open -a Markme path/to/note.md
```

A custom URL scheme can wait until that command is not enough.

### 5. Math, only on pages that contain it

Agents emit `$inline$` and `$$blocks$$`. The original viewer left math out, and a math engine is large. Ship one only if it is loaded for a page that contains math and left out of every other page. The same rule already applies to Mermaid. Until that budget is believable, math stays out and the dollar text shows as text.

## What to tell an agent

Paste this, or point the agent at this heading, when it writes Markdown a person will read in markme.

```markdown
The human reads Markdown in markme, a read-only Mac viewer. Write ordinary
GitHub-flavored Markdown to the file. The viewer reloads when the file changes.

- Use headings, lists, tables, task lists, footnotes, and fenced code.
- Put diagrams in a mermaid fence. Put slides in one file, split with ---.
- For a callout, use a GitHub alert: > [!NOTE], > [!TIP], > [!WARNING], > [!IMPORTANT], > [!CAUTION].
- Link other notes with a relative path ending in .md. Wikilinks [[name]] are fine for a file in the same folder.
- Do not write raw HTML, scripts, or a private widget syntax.
- After an edit, name the file and the line in the summary. The human copies those locations back.
```

## Working on this repository

Agents that change markme itself should read [AGENTS.md](../AGENTS.md). Product behavior stays inside the priorities above. A new capability that writes the file, runs an agent, or adds a project panel is outside the backlog.
