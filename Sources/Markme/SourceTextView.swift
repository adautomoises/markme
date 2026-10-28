import AppKit
import SwiftUI
import MarkmeCore

struct SourceTextView: NSViewRepresentable {
    let text: String
    let editable: Bool
    let focusToken: Int
    let findQuery: String
    let scrollToLine: Int?
    let zoom: Double
    let changes: [ChangeSpan]
    let changeCursor: Int?
    let changeScrollToken: Int
    let editMarks: [EditMark]
    let jumpLine: Int?
    let jumpToken: Int
    let replacement: TextReplacement?
    let replacementToken: Int
    var peek: (Int, @escaping () -> Void) -> AnyView
    var onVisibleLine: (Int) -> Void
    var onViewport: (ClosedRange<Int>) -> Void
    var onSelection: (Int, Bool) -> Void
    var onEdit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVisibleLine: onVisibleLine, onViewport: onViewport, onSelection: onSelection, onEdit: onEdit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = true
        scroll.borderType = .noBorder

        let textView = MarkdownTextView()
        textView.isEditable = editable
        textView.isSelectable = SourceTextConfiguration.isSelectable
        textView.isRichText = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(
            ofSize: SourceTextConfiguration.fontSize(zoom: zoom),
            weight: .regular
        )
        textView.textContainerInset = NSSize(width: 12, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        scroll.documentView = textView

        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        let ruler = LineNumberRuler(textView: textView)
        scroll.verticalRulerView = ruler
        ruler.clientView = textView

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.reportSelection()
        context.coordinator.lastZoom = zoom
        context.coordinator.lastJumpToken = jumpToken
        context.coordinator.lastReplacementToken = replacementToken
        context.coordinator.peek = peek
        context.coordinator.ruler = ruler
        ruler.onMark = { [weak coordinator = context.coordinator] index, rect in
            coordinator?.presentPeek(index, at: rect)
        }
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )
        // A taller window, a moved divider, or a new zoom shows a different span of lines.
        scroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: scroll.contentView
        )
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            coordinator?.reportViewport()
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onVisibleLine = onVisibleLine
        context.coordinator.onViewport = onViewport
        context.coordinator.peek = peek
        context.coordinator.onSelection = onSelection
        context.coordinator.onEdit = onEdit
        guard let textView = scroll.documentView as? NSTextView else { return }
        textView.isEditable = editable
        if context.coordinator.lastFocus != focusToken {
            context.coordinator.lastFocus = focusToken
            if editable, focusToken > 0 {
                textView.window?.makeFirstResponder(textView)
            }
        }
        if context.coordinator.lastZoom != zoom {
            context.coordinator.lastZoom = zoom
            textView.font = NSFont.monospacedSystemFont(
                ofSize: SourceTextConfiguration.fontSize(zoom: zoom),
                weight: .regular
            )
            context.coordinator.ruler?.needsDisplay = true
            DispatchQueue.main.async { [weak coordinator = context.coordinator] in
                coordinator?.reportViewport()
            }
        }
        if textView.string != text {
            context.coordinator.applyingExternal = true
            textView.string = text
            context.coordinator.applyingExternal = false
            context.coordinator.ruler?.needsDisplay = true
            context.coordinator.reportSelection()
        }
        if context.coordinator.lastFind != findQuery {
            context.coordinator.lastFind = findQuery
            if let range = TextFind.ranges(of: findQuery, in: text).first {
                let nsRange = NSRange(range, in: text)
                textView.setSelectedRange(nsRange)
                textView.scrollRangeToVisible(nsRange)
            } else {
                let caret = textView.selectedRange().location
                textView.setSelectedRange(NSRange(location: min(caret, (text as NSString).length), length: 0))
            }
        }
        if let scrollToLine, context.coordinator.lastScroll != scrollToLine {
            context.coordinator.lastScroll = scrollToLine
            context.coordinator.scroll(to: scrollToLine)
        }
        context.coordinator.applyChanges(changes, cursor: changeCursor, token: changeScrollToken)
        if context.coordinator.lastEditMarks != editMarks {
            context.coordinator.lastEditMarks = editMarks
            context.coordinator.ruler?.gutter = EditGutter(editMarks)
            context.coordinator.ruler?.needsDisplay = true
        }
        if context.coordinator.lastJumpToken != jumpToken {
            context.coordinator.lastJumpToken = jumpToken
            if let jumpLine {
                context.coordinator.scrollToTop(line: jumpLine)
            }
        }
        if context.coordinator.lastReplacementToken != replacementToken {
            context.coordinator.lastReplacementToken = replacementToken
            if let replacement {
                // The edit reports back through the text delegate, which changes SwiftUI state.
                // Doing that inside this update would be dropped, and the next update would put the old text back.
                DispatchQueue.main.async { [weak coordinator = context.coordinator] in
                    coordinator?.apply(replacement)
                }
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onVisibleLine: (Int) -> Void
        var onViewport: (ClosedRange<Int>) -> Void
        var onSelection: (Int, Bool) -> Void
        var onEdit: (String) -> Void
        weak var textView: NSTextView?
        weak var ruler: LineNumberRuler?
        var applyingExternal = false
        var lastFind = ""
        var lastScroll: Int?
        var lastZoom = 1.0
        var lastFocus = 0
        var lastChanges: [ChangeSpan] = []
        var lastChangeCursor: Int?
        var lastChangeToken = 0
        var lastHighlighted = ""
        var lastEditMarks: [EditMark] = []
        var lastJumpToken = 0
        var lastReplacementToken = 0
        var peek: ((Int, @escaping () -> Void) -> AnyView)?
        private var popover: NSPopover?

        init(
            onVisibleLine: @escaping (Int) -> Void,
            onViewport: @escaping (ClosedRange<Int>) -> Void,
            onSelection: @escaping (Int, Bool) -> Void,
            onEdit: @escaping (String) -> Void
        ) {
            self.onVisibleLine = onVisibleLine
            self.onViewport = onViewport
            self.onSelection = onSelection
            self.onEdit = onEdit
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard !applyingExternal, let textView else { return }
            ruler?.needsDisplay = true
            onEdit(textView.string)
            reportViewport()
            settleMarkdownWindow(textView.window)
            DispatchQueue.main.async { [weak textView] in
                settleMarkdownWindow(textView?.window)
            }
        }

        @MainActor
        func textViewDidChangeSelection(_ notification: Notification) {
            reportSelection()
        }

        @MainActor
        func reportSelection() {
            guard let textView else { return }
            let range = textView.selectedRange()
            onSelection(Self.lineNumber(location: range.location, in: textView.string), range.length == 0)
        }

        static func lineNumber(location: Int, in text: String) -> Int {
            LineBreaks.line(at: location, in: text as NSString)
        }

        @MainActor
        @objc func boundsChanged(_ notification: Notification) {
            ruler?.needsDisplay = true
            guard let textView else { return }
            onVisibleLine(Self.visibleLine(in: textView))
            reportViewport()
        }

        @MainActor
        @objc func frameChanged(_ notification: Notification) {
            reportViewport()
        }

        @MainActor
        func reportViewport() {
            guard let textView else { return }
            let top = Self.visibleLine(in: textView)
            let bottom = Self.visibleLine(in: textView, atBottom: true)
            onViewport(top...max(top, bottom))
        }

        /// One undoable edit, as if typed. The delegate then saves it like any other keystroke.
        @MainActor
        func apply(_ replacement: TextReplacement) {
            guard let textView else { return }
            let length = (textView.string as NSString).length
            guard replacement.location >= 0, replacement.length >= 0,
                  replacement.location + replacement.length <= length else { return }
            let range = NSRange(location: replacement.location, length: replacement.length)
            guard textView.shouldChangeText(in: range, replacementString: replacement.text) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: replacement.text)
            textView.didChangeText()
            let inserted = NSRange(location: replacement.location, length: (replacement.text as NSString).length)
            textView.setSelectedRange(NSRange(location: replacement.location, length: 0))
            textView.scrollRangeToVisible(inserted)
        }

        @MainActor
        func presentPeek(_ index: Int, at rect: NSRect) {
            guard let ruler, let peek else { return }
            popover?.close()
            let popover = NSPopover()
            popover.behavior = .transient
            let close: () -> Void = { [weak popover] in popover?.performClose(nil) }
            let host = NSHostingController(rootView: peek(index, close))
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
            popover.show(relativeTo: rect, of: ruler, preferredEdge: .maxX)
            self.popover = popover
        }

        /// Puts the start of `line` at the top of the pane, or as near as the end of the text allows.
        @MainActor
        func scrollToTop(line: Int) {
            guard let textView,
                  let layout = textView.layoutManager,
                  let scroll = textView.enclosingScrollView else { return }
            let ns = textView.string as NSString
            let index = Self.characterIndex(ofLine: line, in: ns)
            layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: min(index + 1, ns.length)))
            let y: CGFloat
            if index >= ns.length, ns.length > 0 {
                y = .greatestFiniteMagnitude
            } else {
                let glyph = layout.glyphIndexForCharacter(at: index)
                y = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            }
            let clip = scroll.contentView
            let limit = max(textView.frame.height - clip.bounds.height, 0)
            let target = min(max(y + textView.textContainerOrigin.y - textView.textContainerInset.height, 0), limit)
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: target))
            scroll.reflectScrolledClipView(clip)
        }

        @MainActor
        func applyChanges(_ changes: [ChangeSpan], cursor: Int?, token: Int) {
            guard let textView, let layout = textView.layoutManager else { return }
            if textView.string != lastHighlighted || changes != lastChanges || cursor != lastChangeCursor {
                lastHighlighted = textView.string
                lastChanges = changes
                lastChangeCursor = cursor
                let full = NSRange(location: 0, length: (textView.string as NSString).length)
                layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
                for (index, span) in changes.enumerated() {
                    guard case .added(let lines) = span.kind,
                          let range = ChangeReview.utf16Range(of: lines, in: textView.string) else { continue }
                    layout.addTemporaryAttribute(
                        .backgroundColor,
                        value: index == cursor ? Self.selectedColor : Self.addedColor,
                        forCharacterRange: range
                    )
                }
            }
            guard token != lastChangeToken else { return }
            lastChangeToken = token
            guard token > 0, let cursor, changes.indices.contains(cursor) else { return }
            scroll(to: changes[cursor].focusLine)
        }

        @MainActor
        func scroll(to line: Int) {
            guard let textView else { return }
            let ns = textView.string as NSString
            textView.scrollRangeToVisible(NSRange(location: Self.characterIndex(ofLine: line, in: ns), length: 0))
        }

        /// UTF-16 offset where the 1-based `line` starts, or the end of the text.
        static func characterIndex(ofLine line: Int, in ns: NSString) -> Int {
            LineBreaks.offset(ofLine: line, in: ns)
        }

        @MainActor
        static func visibleLine(in textView: NSTextView, atBottom: Bool = false) -> Int {
            guard let layout = textView.layoutManager, let container = textView.textContainer else { return 1 }
            let bounds = textView.enclosingScrollView?.contentView.bounds ?? .zero
            let inset = textView.textContainerInset
            let y = atBottom ? bounds.maxY - inset.height - 1 : bounds.origin.y + inset.height
            let point = NSPoint(x: bounds.origin.x + inset.width, y: max(y, 0))
            let glyph = layout.glyphIndex(for: point, in: container, fractionOfDistanceThroughGlyph: nil)
            let char = layout.characterIndexForGlyph(at: glyph)
            return LineBreaks.line(at: char, in: textView.string as NSString)
        }

        static let addedColor = NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 0.25, green: 0.62, blue: 0.36, alpha: 0.28)
                : NSColor(srgbRed: 0.18, green: 0.65, blue: 0.32, alpha: 0.18)
        }

        static let selectedColor = NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 0.25, green: 0.62, blue: 0.36, alpha: 0.45)
                : NSColor(srgbRed: 0.18, green: 0.65, blue: 0.32, alpha: 0.32)
        }
    }
}

/// Plain Markdown editor. Undo stays on this view so the window document
/// does not treat keystrokes as its own unsaved changes.
final class MarkdownTextView: NSTextView {
    private let editingUndo = UndoManager()

    override var undoManager: UndoManager? { editingUndo }
}

/// DocumentGroup watches the text view and paints "Edited" on the title.
/// ReaderDocument refuses that save; this window writes the file itself.
@MainActor
func settleMarkdownWindow(_ window: NSWindow?) {
    guard let window else { return }
    if let document = window.windowController?.document as? NSDocument, document.isDocumentEdited {
        document.updateChangeCount(.changeCleared)
    }
    var root: NSView? = window.contentView
    while let parent = root?.superview { root = parent }
    guard let root else { return }
    func walk(_ view: NSView) {
        let name = String(describing: type(of: view))
        if name.contains("NSToolbarTitleStackView") {
            for child in view.subviews where child is NSTextField {
                child.isHidden = true
            }
        }
        if name.contains("NSDocumentAutosaveButton") {
            view.isHidden = true
        }
        for child in view.subviews {
            walk(child)
        }
    }
    walk(root)
}

final class LineNumberRuler: NSRulerView {
    weak var textView: NSTextView?
    /// Lines that differ from the text the window opened with.
    var gutter = EditGutter()
    /// A click on a mark: the mark index and the clicked line's rect in this ruler.
    var onMark: (Int, NSRect) -> Void = { _, _ in }
    private static let markWidth: CGFloat = 3

    override func mouseDown(with event: NSEvent) {
        guard let textView, let layout = textView.layoutManager, let container = textView.textContainer else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let visible = scrollView?.contentView.bounds ?? bounds
        let inset = textView.textContainerInset.height
        let textY = point.y + visible.minY - inset
        guard textY >= 0 else { return }
        let glyph = layout.glyphIndex(for: NSPoint(x: 0, y: textY), in: container)
        let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let ns = textView.string as NSString
        let char = min(layout.characterIndexForGlyph(at: glyph), ns.length)
        var line = LineBreaks.line(at: char, in: ns)
        var hit = fragment
        if textY > fragment.maxY {
            // Below the last line. Only the empty line after a final newline counts, not the blank space under it.
            let extra = layout.extraLineFragmentRect
            guard !extra.isEmpty, textY <= extra.maxY, LineBreaks.isBreak(at: ns.length - 1, in: ns) else { return }
            line += 1
            hit = extra
        }
        guard let index = gutter.mark(nearLine: line) else { return }
        let rect = NSRect(x: 0, y: hit.minY - visible.minY + inset, width: ruleThickness, height: max(hit.height, 4))
        onMark(index, rect)
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        ruleThickness = 44
        clientView = textView
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let visible = scrollView?.contentView.bounds ?? rect
        let glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        let ns = textView.string as NSString
        var glyph = glyphRange.location
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        while glyph < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
            let charIndex = layout.characterIndexForGlyph(at: glyph)
            let lineNumber = LineBreaks.line(at: charIndex, in: ns)
            let y = fragment.minY - visible.minY + textView.textContainerInset.height
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y), withAttributes: attributes)
            drawMarks(line: lineNumber, top: y, height: fragment.height, glyphs: lineRange, layout: layout, text: ns)
            if NSMaxRange(lineRange) <= glyph { break }
            glyph = NSMaxRange(lineRange)
        }
    }

    private func drawMarks(
        line: Int,
        top: CGFloat,
        height: CGFloat,
        glyphs: NSRange,
        layout: NSLayoutManager,
        text: NSString
    ) {
        let x = ruleThickness - Self.markWidth
        switch gutter.lines[line] {
        case .added:
            EditColors.added.setFill()
            NSRect(x: x, y: top, width: Self.markWidth, height: height).fill()
        case .modified:
            EditColors.modified.setFill()
            NSRect(x: x, y: top, width: Self.markWidth, height: height).fill()
        case nil:
            break
        }
        // A removal sits on the boundary below the last line of a wrapped paragraph, or above line 1.
        let firstFragmentOfLineOne = line == 1 && layout.characterIndexForGlyph(at: glyphs.location) == 0
        if firstFragmentOfLineOne, gutter.removedAfter.contains(0) {
            drawWedge(at: top, x: x)
        }
        let lastChar = layout.characterIndexForGlyph(at: max(NSMaxRange(glyphs) - 1, glyphs.location))
        let endsLine = lastChar >= text.length - 1 || LineBreaks.isBreak(at: lastChar, in: text)
        if endsLine, gutter.removedAfter.contains(line) {
            drawWedge(at: top + height, x: x)
        }
    }

    private func drawWedge(at y: CGFloat, x: CGFloat) {
        let wedge = NSBezierPath()
        wedge.move(to: NSPoint(x: x - 3, y: y - 4))
        wedge.line(to: NSPoint(x: ruleThickness, y: y))
        wedge.line(to: NSPoint(x: x - 3, y: y + 4))
        wedge.close()
        EditColors.removed.setFill()
        wedge.fill()
    }
}
