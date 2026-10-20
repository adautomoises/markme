import AppKit
import SwiftUI
import MarkmeCore

struct SourceTextView: NSViewRepresentable {
    let text: String
    let findQuery: String
    let scrollToLine: Int?
    var onVisibleLine: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVisibleLine: onVisibleLine)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = true
        scroll.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = SourceTextConfiguration.isEditable
        textView.isSelectable = SourceTextConfiguration.isSelectable
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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

        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onVisibleLine = onVisibleLine
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.ruler?.needsDisplay = true
        }
        if context.coordinator.lastFind != findQuery {
            context.coordinator.lastFind = findQuery
            guard let range = TextFind.ranges(of: findQuery, in: text).first else { return }
            let nsRange = NSRange(range, in: text)
            textView.setSelectedRange(nsRange)
            textView.scrollRangeToVisible(nsRange)
        }
        if let scrollToLine, context.coordinator.lastScroll != scrollToLine {
            context.coordinator.lastScroll = scrollToLine
            context.coordinator.scroll(to: scrollToLine)
        }
    }

    final class Coordinator: NSObject {
        var onVisibleLine: (Int) -> Void
        weak var textView: NSTextView?
        weak var ruler: LineNumberRuler?
        var lastFind = ""
        var lastScroll: Int?

        init(onVisibleLine: @escaping (Int) -> Void) {
            self.onVisibleLine = onVisibleLine
        }

        @MainActor
        @objc func boundsChanged(_ notification: Notification) {
            ruler?.needsDisplay = true
            guard let textView else { return }
            onVisibleLine(Self.visibleLine(in: textView))
        }

        @MainActor
        func scroll(to line: Int) {
            guard let textView else { return }
            let ns = textView.string as NSString
            var current = 1
            var index = 0
            while current < line, index < ns.length {
                if ns.character(at: index) == 10 { current += 1 }
                index += 1
            }
            textView.scrollRangeToVisible(NSRange(location: min(index, ns.length), length: 0))
        }

        @MainActor
        static func visibleLine(in textView: NSTextView) -> Int {
            guard let layout = textView.layoutManager, let container = textView.textContainer else { return 1 }
            let origin = textView.enclosingScrollView?.contentView.bounds.origin ?? .zero
            let point = NSPoint(x: origin.x + textView.textContainerInset.width, y: origin.y + textView.textContainerInset.height)
            let glyph = layout.glyphIndex(for: point, in: container, fractionOfDistanceThroughGlyph: nil)
            let char = layout.characterIndexForGlyph(at: glyph)
            let ns = textView.string as NSString
            let end = min(char, ns.length)
            return ns.substring(to: end).components(separatedBy: "\n").count
        }
    }
}

final class LineNumberRuler: NSRulerView {
    weak var textView: NSTextView?

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
            let lineNumber = ns.substring(to: min(charIndex, ns.length)).components(separatedBy: "\n").count
            let y = fragment.minY - visible.minY + textView.textContainerInset.height
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y), withAttributes: attributes)
            if NSMaxRange(lineRange) <= glyph { break }
            glyph = NSMaxRange(lineRange)
        }
    }
}
