# Feature Specification: Minimap and edit marks

Date: 2026-10-28
Status: Draft, written after a first implementation, used to review it
Backlog: Priority 1, "Show what the agent just changed"

The README describes the app as it is now. This document is the rule set the minimap is held to. It follows the spec-kit layout: stories with priorities, acceptance scenarios, requirements, and success criteria.

## Intent

An agent rewrites a note, or the person types in it, and the window should answer two questions without a git panel: where am I in this file, and what is different from the file I opened. A narrow column beside the window shows the whole file, the part on screen, and every line that differs from the opened text. A click on a difference shows the old lines and can put them back.

The comparison is with the text the window opened. markme does not run git, does not read history, and keeps nothing after the window closes.

## Non-goals

- A git diff, a blame, a history, or a comparison with any file other than the open one.
- Marks that survive closing the window.
- Rendering the page itself in miniature. The minimap draws the source lines, not the formatted page.
- Accept, stage, or commit. Revert is the only action, and it writes only the open file.
- A minimap during a presentation.

## User scenarios and testing

### Story 1. Find my place in a long file (P1)

The person reads a long plan in Page, Text, or Side by side. The column on the right shows every line of the file. A band shows the part on screen. A click or a drag moves the view there.

**Why this priority:** it is useful on every file, edited or not, and it is the frame the marks live in.

**Independent test:** open a 1,000-line fixture, click near the bottom of the column, and check that the pane shows the end of the file and the band moved there.

**Acceptance scenarios:**

1. **Given** a file of any length, **when** the window opens, **then** every source line has a row in the column and the column does not scroll.
2. **Given** the view in Text, **when** the person scrolls, **then** the band covers the first through the last line on screen.
3. **Given** Page, **when** the person scrolls, **then** the band follows the source lines of the blocks on screen.
4. **Given** Side by side, **when** the person scrolls one pane, **then** the band follows the pane scrolled last.
5. **Given** any mode, **when** the person clicks a row, **then** that line is brought near the middle of the pane, and in Side by side both panes move without scroll sync fighting the jump.
6. **Given** a press, **when** the person drags, **then** the view follows the pointer continuously.
7. **Given** a short file, **when** the window opens, **then** rows keep a readable maximum height and do not stretch to fill the column.

### Story 2. See what differs from the opened file (P1)

An agent writes the file while it is open, or the person types. The column marks new lines green, changed lines blue, and the place of removed lines with a red wedge. The line-number gutter of Text shows the same marks. A chip under the column counts them and steps to the next one.

**Why this priority:** it is Backlog priority 1. The reason a reader keeps the window open while an agent works.

**Independent test:** open a fixture, change one line, add one, delete one, and check the three kinds in the column, in the gutter, and in the chip.

**Acceptance scenarios:**

1. **Given** an unchanged file, **then** no mark and no chip are shown.
2. **Given** lines inserted between two untouched lines, **then** they are added.
3. **Given** lines removed and lines inserted at the same place, **then** they are one modification, not a removal plus an addition.
4. **Given** lines removed with nothing in their place, **then** one removal sits on the boundary below the last surviving line, or above line 1.
5. **Given** an outside write that the window reloads, **then** it is marked the same way as typing.
6. **Given** marks, **when** the person clicks the chip, **then** the view moves to the first mark below the screen, and wraps to the first mark after the last.
7. **Given** marks, **when** the pointer rests on the column or the chip, **then** a tooltip reads "+A ~M −R since opened", and "No changes since opened" when there are none.

### Story 3. Look at a change and put it back (P2)

A click on a mark at the left edge of the column, or on a mark in the gutter of Text, opens a small panel. Before lists the opened lines, Now lists the lines there today, and Revert puts that one change back.

**Why this priority:** it turns the marks into the keep-or-revert step Nimbalyst has, inside the one write markme allows.

**Independent test:** delete two lines, open the panel on the wedge, press Revert, and check the file on disk is byte for byte the opened file.

**Acceptance scenarios:**

1. **Given** a modification, **then** the panel shows Before and Now, a title like "2 changed lines", and the line number.
2. **Given** an addition, **then** the panel shows only Now. **Given** a removal, **then** it shows only Before.
3. **Given** the panel, **when** the person presses Revert, **then** only that change goes back. Other marks stay.
4. **Given** a revert in Text or Side by side, **when** the person presses ⌘Z, **then** the revert is undone as one step.
5. **Given** any revert, **then** the file is saved the way a keystroke is saved, and the save is not marked as an outside change.
6. **Given** a panel opened before other edits moved the change, **when** Revert is pressed, **then** the same change is found where it is now and reverted, or nothing happens with a beep when it is gone. A stale panel never reverts a different change.
7. **Given** the panel in the minimap, **then** Go to scrolls the change into view.

### Story 4. Turn it off (P3)

Minimap in the View menu, ⇧⌘M, shows or hides the column. The choice is kept for the next window.

**Independent test:** hide it, close the window, open another file, and check it stays hidden.

## Edge cases

- Empty file: the column is empty, no chip, and a revert of an emptied file restores it.
- A file without a final newline keeps that shape after a revert. An emptied file gets one.
- `\r\n`, `\r`, and mixed endings: every untouched line keeps its own ending after a revert. A restored line takes the ending of the line next to it.
- Accents and emoji: a revert never splits a character.
- The same line text in many places (blank lines, `- [ ]`): a stale mark matches by kind, opened lines, and inserted lines, nearest to where it was.
- A fence opened with four backticks is not closed by three. A `#` line inside a fence is not a heading. `#tag` is not a heading.
- A file that is not UTF-8 shows the error and no minimap. If it becomes readable, the first text read is the opened text.
- A plan composed with its spec: the spec part has no source lines, so the band rests on the last plan line above it.
- Presentation hides the column. Leaving presentation brings it back.
- A very long file: the column still fits every line. Typing stays responsive.

## Requirements

### Functional

- **FR-001** The column draws one row per source line, counted the way the change review counts lines: `\r\n`, `\r`, and `\n` each end a line, and a final newline does not add a row. The Text gutter, a jump, and Copy Location count lines the same way.
- **FR-002** A row shows where the ink starts (indent, a tab counts as four) and how long the line is, capped. ATX headings, fenced code, and quotes each have a distinct look. A fence reads as one block.
- **FR-003** Every line fits in the column height. A row never grows past a fixed maximum height.
- **FR-004** The band shows the lines on screen in the pane the column follows: Text in Text, Page in Page, the pane scrolled last in Side by side.
- **FR-005** A click or drag scrolls the followed panes so the line under the pointer sits near the middle. A jump that arrives while the page loads is replayed after the load.
- **FR-006** Marks compare the text now with the text the window opened, line by line. Added, modified, and removed are the only kinds. A replaced run is one modification.
- **FR-007** The same marks are drawn in the minimap and in the line-number gutter of Text, in the same three colors, in light and dark appearance.
- **FR-008** Typing and a reloaded outside write both update the marks after the next render.
- **FR-009** The chip counts lines per kind and is hidden when there are no marks.
- **FR-010** Revert writes the open file only, through the same save path as typing. In Text and Side by side it is one undoable edit applied by the editor.
- **FR-011** Revert is refused when the change is no longer in the text. It never reverts a different change.
- **FR-012** Revert keeps line endings, the final-newline shape, and whole characters.
- **FR-013** The minimap is hidden during a presentation and on the error page.
- **FR-014** Minimap (Minimapa), ⇧⌘M, toggles the column and is remembered.
- **FR-015** Every sentence on screen comes from `ReaderCopy`, in English and Portuguese, with tests that pin both: Minimap, Revert, Go to, Before, Now, the line counts, the line number, and the summary.
- **FR-016** No network, telemetry, git, or extra file. Nothing about the marks is written to disk.
- **FR-017** Diffing, line classification, scale math, and revert live in `MarkmeCore` without AppKit or WebKit, and have unit tests.

### Quality

- **QR-001** Diffing and line classification run off the main thread with the render. Lines shared at the start and end skip the diff. When the rest is so different that the diff would stall, the changed middle is one modification, and reverting it still restores the opened text.
- **QR-002** Scrolling and hovering redraw only the band and the guide, not the ink.
- **QR-003** A scroll in a pane does not re-evaluate the reader view. Only the minimap observes the viewport.
- **QR-004** The column carries an accessibility label with the summary, an action that goes to the next change, and one revert action per change.
- **QR-006** The mode buttons in the toolbar keep their highlight inside the toolbar's capsule.
- **QR-005** Code, comments, and docs are English and match the surrounding style.

### Key entities

- **MinimapLine:** indent, length, and kind of one source line.
- **EditMark:** a kind with its line range or gap, the opened lines it replaced, and the lines an addition put in.
- **EditGutter:** per-line lookup of marks for the gutter.
- **MinimapScale:** maps lines to the column height and back.
- **TextReplacement:** the smallest UTF-16 edit between two texts.

## Success criteria

- **SC-001** Reverting every mark, in any order, gives back the opened text byte for byte.
- **SC-002** A click anywhere in the column lands within one screen of the line under the pointer.
- **SC-003** On a 5,000-line file, typing a character updates the page and the marks without a visible stall.
- **SC-004** `swift test` and `swift build -c release` pass.
- **SC-005** README and BACKLOG describe the minimap as shipped and say nothing that contradicts it.

## Assumptions

- "Opened" means the first text the window read successfully. Use the disk and reloads do not reset it. Closing the window does.
- Setext headings (`Title` over `===`) draw as text. That is acceptable for a glance.
- Hiding the minimap hides the column only. The gutter keeps its marks.
