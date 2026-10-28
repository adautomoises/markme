import AppKit
import Observation
import SwiftUI
import MarkmeCore

/// Where each pane is scrolled. Only the minimap reads it, so a scroll frame redraws the minimap and nothing else.
@Observable
@MainActor
final class MinimapViewport {
    enum Pane {
        case source
        case page
    }

    var source: ClosedRange<Int>?
    var page: ClosedRange<Int>?
    /// In Side by Side, the pane the person scrolled last. The other one only follows it.
    var leading = Pane.source

    func range(following pane: Pane?) -> ClosedRange<Int>? {
        switch pane ?? leading {
        case .source: return source
        case .page: return page
        }
    }
}

/// The whole file at a glance beside the window. A click or a drag brings that part into view.
/// A click on a colored mark at the left edge shows what the opened file had there.
struct MinimapView: View {
    let lines: [MinimapLine]
    let marks: [EditMark]
    let counts: (added: Int, modified: Int, removed: Int)
    let viewports: MinimapViewport
    /// The pane to follow. Nil follows whichever pane was scrolled last.
    let follows: MinimapViewport.Pane?
    let summary: String
    let languageCode: String
    var onJump: (Int) -> Void
    var onRevert: (EditMark) -> Void
    var peek: (Int, @escaping () -> Void) -> AnyView

    @State private var hoverY: CGFloat?
    /// The mark under a press, kept by value: a render while the mouse is down can renumber the list.
    @State private var pressedMark: EditMark?
    @State private var peekIndex: Int?
    @State private var peekRect = CGRect.zero

    static let width: CGFloat = 112
    static let gutterWidth: CGFloat = 4
    /// A press this close to the left edge can open a mark instead of scrolling.
    private static let markHitWidth: CGFloat = 18
    static let columns: CGFloat = 80
    static let inset = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 6)

    /// First and last source line on screen in the pane the minimap follows.
    private var viewport: ClosedRange<Int>? {
        viewports.range(following: follows)
    }

    var body: some View {
        // Read here, not only inside the Canvas: Observation tracks what body reads,
        // and a scroll in either pane must redraw the band.
        let viewport = viewport
        let hover = hoverY
        VStack(spacing: 0) {
            GeometryReader { geo in
                let scale = MinimapScale(lineCount: lines.count, height: geo.size.height)
                // The ink only changes with the text. Hover and scrolling redraw the light layer on top.
                MinimapInk(lines: lines, marks: marks, lifted: liftedMarks)
                    .equatable()
                    .overlay {
                        Canvas { context, size in
                            drawViewport(in: &context, size: size, scale: scale, viewport: viewport, hoverY: hover)
                        }
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point): hoverY = point.y
                        case .ended: hoverY = nil
                        }
                    }
                    .gesture(press(scale: scale))
                    .popover(
                        isPresented: Binding(
                            get: { peekIndex != nil },
                            set: { if !$0 { peekIndex = nil } }
                        ),
                        attachmentAnchor: .rect(.rect(peekRect)),
                        arrowEdge: .leading
                    ) {
                        if let peekIndex {
                            peek(peekIndex) { self.peekIndex = nil }
                        }
                    }
            }
            .padding(.top, Self.inset.top)
            .padding(.bottom, Self.inset.bottom)
            if !marks.isEmpty {
                countChip
                    .padding(.bottom, 8)
            }
        }
        .frame(width: Self.width)
        .background(
            ZStack {
                Color(nsColor: .textBackgroundColor)
                Color.primary.opacity(0.025)
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1)
        }
        // An open peek is found by index. New marks can mean a different change at that index.
        .onChange(of: marks) {
            peekIndex = nil
            pressedMark = nil
        }
        .help(summary)
        .accessibilityElement()
        .accessibilityLabel(summary)
        // VoiceOver cannot aim at a 4-point mark, so each change is an action.
        .accessibilityActions {
            if !marks.isEmpty {
                Button(ReaderCopy.string(.goToChange, languageCode: languageCode)) { jumpToNextMark() }
            }
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                Button(ReaderCopy.revertAction(mark, languageCode: languageCode)) { onRevert(mark) }
            }
        }
    }

    private var liftedMarks: Set<Int> {
        var lifted = Set<Int>()
        if let peekIndex { lifted.insert(peekIndex) }
        if let pressedMark, let index = marks.firstIndex(of: pressedMark) { lifted.insert(index) }
        return lifted
    }

    private var countChip: some View {
        Button {
            jumpToNextMark()
        } label: {
            HStack(spacing: 6) {
                if counts.added > 0 {
                    Text("+\(counts.added)").foregroundStyle(Self.addedColor)
                }
                if counts.modified > 0 {
                    Text("~\(counts.modified)").foregroundStyle(Self.modifiedColor)
                }
                if counts.removed > 0 {
                    Text("−\(counts.removed)").foregroundStyle(Self.removedColor)
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .help(summary)
    }

    /// Steps to the first mark below the screen, then wraps to the top.
    private func jumpToNextMark() {
        guard !marks.isEmpty else { return }
        let below = viewport?.upperBound ?? 0
        let target = marks.first { $0.focusLine > below } ?? marks[0]
        let visible = viewport.map { $0.count } ?? 1
        onJump(max(target.focusLine - visible / 3, 1))
    }

    private func press(scale: MinimapScale) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let moved = abs(value.translation.width) + abs(value.translation.height)
                if value.translation == .zero, value.startLocation.x <= Self.markHitWidth,
                   let hit = markIndex(atY: value.startLocation.y, scale: scale) {
                    pressedMark = marks[hit]
                    return
                }
                if pressedMark != nil, moved < 4 { return }
                pressedMark = nil
                let visible = viewport.map { $0.count } ?? 1
                onJump(scale.jumpLine(atY: value.location.y, visibleLines: visible))
            }
            .onEnded { _ in
                guard let pressed = pressedMark else { return }
                pressedMark = nil
                guard let hit = marks.firstIndex(of: pressed) else { return }
                let span = Self.markSpan(marks[hit], scale: scale)
                peekRect = CGRect(x: 0, y: span.lowerBound, width: Self.gutterWidth + 4, height: max(span.upperBound - span.lowerBound, 2))
                peekIndex = hit
            }
    }

    private func markIndex(atY y: CGFloat, scale: MinimapScale) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, mark) in marks.enumerated() {
            let span = Self.markSpan(mark, scale: scale)
            let distance: CGFloat = span.contains(y) ? 0 : min(abs(y - span.lowerBound), abs(y - span.upperBound))
            guard distance <= 5 else { continue }
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best?.index
    }

    private static func markSpan(_ mark: EditMark, scale: MinimapScale) -> ClosedRange<CGFloat> {
        switch mark.kind {
        case .added(let range), .modified(let range):
            let top = scale.y(ofLine: range.lowerBound)
            return top...max(scale.y(ofLine: range.upperBound + 1), top + 2)
        case .removed(let after, _):
            let y = scale.y(ofLine: after + 1)
            return y...y
        }
    }

    private func drawViewport(
        in context: inout GraphicsContext,
        size: CGSize,
        scale: MinimapScale,
        viewport: ClosedRange<Int>?,
        hoverY: CGFloat?
    ) {
        let accent = Color.accentColor
        if let viewport {
            let top = scale.y(ofLine: viewport.lowerBound)
            let bottom = max(scale.y(ofLine: viewport.upperBound + 1), top + 6)
            let band = Path(roundedRect: CGRect(x: 1.5, y: top, width: size.width - 3, height: bottom - top), cornerRadius: 3)
            let hovering = hoverY.map { $0 >= top && $0 <= bottom } ?? false
            context.fill(band, with: .color(accent.opacity(hovering ? 0.16 : 0.1)))
            context.stroke(band, with: .color(accent.opacity(hovering ? 0.5 : 0.32)), lineWidth: 1)
        }

        if let hoverY, hoverY <= scale.y(ofLine: lines.count + 1) {
            let guide = Path(CGRect(x: 0, y: hoverY - 0.5, width: size.width, height: 1))
            context.fill(guide, with: .color(Color.primary.opacity(0.18)))
        }
    }

    static let addedColor = Color(nsColor: EditColors.added)
    static let modifiedColor = Color(nsColor: EditColors.modified)
    static let removedColor = Color(nsColor: EditColors.removed)
}

/// Lines, fences, and change marks. Equatable, so hovering and scrolling leave it alone.
private struct MinimapInk: View, Equatable {
    let lines: [MinimapLine]
    let marks: [EditMark]
    /// Marks drawn wider: the one pressed and the one open in a peek.
    let lifted: Set<Int>

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size, scale: MinimapScale(lineCount: lines.count, height: size.height))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, scale: MinimapScale) {
        let row = scale.rowHeight
        let left = MinimapView.gutterWidth + 6
        let right = size.width - MinimapView.inset.trailing
        let column = (right - left) / MinimapView.columns
        let accent = Color.accentColor

        // Change tints go under everything, across the whole row.
        for mark in marks {
            switch mark.kind {
            case .added(let range):
                context.fill(rowBand(range, scale: scale, width: size.width), with: .color(MinimapView.addedColor.opacity(0.14)))
            case .modified(let range):
                context.fill(rowBand(range, scale: scale, width: size.width), with: .color(MinimapView.modifiedColor.opacity(0.14)))
            case .removed:
                break
            }
        }

        // Code fences read as one block.
        var fenceStart: Int?
        var fenceBlocks = Path()
        for (offset, line) in lines.enumerated() {
            if line.kind == .fence {
                if fenceStart == nil { fenceStart = offset }
            } else if line.kind != .blank, let start = fenceStart {
                fenceBlocks.addRoundedRect(in: block(start, offset - 1, scale: scale, left: left, right: right), cornerSize: CGSize(width: 2, height: 2))
                fenceStart = nil
            }
        }
        if let start = fenceStart {
            fenceBlocks.addRoundedRect(in: block(start, lines.count - 1, scale: scale, left: left, right: right), cornerSize: CGSize(width: 2, height: 2))
        }
        context.fill(fenceBlocks, with: .color(Color.orange.opacity(0.08)))

        var headings = Path()
        var fences = Path()
        var quotes = Path()
        var texts = Path()
        let ink = max(row * 0.66, 0.5)
        let radius = min(ink / 2, 1)
        for (offset, line) in lines.enumerated() where line.kind != .blank {
            let indent = min(CGFloat(line.indent), MinimapView.columns - 1)
            let length = min(CGFloat(max(line.length, 1)), MinimapView.columns - indent)
            let height = line.kind == .heading ? max(row * 0.9, 0.5) : ink
            let rect = CGRect(
                x: left + indent * column,
                y: scale.y(ofLine: offset + 1) + (row - height) / 2,
                width: max(length * column, 1),
                height: height
            )
            let corner = CGSize(width: radius, height: radius)
            switch line.kind {
            case .heading: headings.addRoundedRect(in: rect, cornerSize: corner)
            case .fence: fences.addRoundedRect(in: rect, cornerSize: corner)
            case .quote: quotes.addRoundedRect(in: rect, cornerSize: corner)
            case .text, .blank: texts.addRoundedRect(in: rect, cornerSize: corner)
            }
        }
        context.fill(texts, with: .color(Color.primary.opacity(0.26)))
        context.fill(quotes, with: .color(Color.secondary.opacity(0.38)))
        context.fill(fences, with: .color(Color.orange.opacity(0.55)))
        context.fill(headings, with: .color(accent.opacity(0.9)))

        for (index, mark) in marks.enumerated() {
            let lifted = lifted.contains(index)
            switch mark.kind {
            case .added(let range):
                context.fill(gutterBar(range, scale: scale, lifted: lifted), with: .color(MinimapView.addedColor))
            case .modified(let range):
                context.fill(gutterBar(range, scale: scale, lifted: lifted), with: .color(MinimapView.modifiedColor))
            case .removed(let after, _):
                let y = scale.y(ofLine: after + 1)
                let line = Path(CGRect(x: 0, y: y - 0.75, width: size.width, height: 1.5))
                context.fill(line, with: .color(MinimapView.removedColor.opacity(0.55)))
                let reach: CGFloat = lifted ? 9 : 7
                var wedge = Path()
                wedge.move(to: CGPoint(x: 0, y: y - 4))
                wedge.addLine(to: CGPoint(x: reach, y: y))
                wedge.addLine(to: CGPoint(x: 0, y: y + 4))
                wedge.closeSubpath()
                context.fill(wedge, with: .color(MinimapView.removedColor))
            }
        }
    }

    private func block(_ first: Int, _ last: Int, scale: MinimapScale, left: CGFloat, right: CGFloat) -> CGRect {
        let top = scale.y(ofLine: first + 1)
        let bottom = scale.y(ofLine: last + 2)
        return CGRect(x: left - 3, y: top, width: right - left + 3, height: max(bottom - top, 1))
    }

    private func rowBand(_ range: ClosedRange<Int>, scale: MinimapScale, width: CGFloat) -> Path {
        let top = scale.y(ofLine: range.lowerBound)
        let bottom = scale.y(ofLine: range.upperBound + 1)
        return Path(CGRect(x: 0, y: top, width: width, height: max(bottom - top, 1.5)))
    }

    private func gutterBar(_ range: ClosedRange<Int>, scale: MinimapScale, lifted: Bool) -> Path {
        let top = scale.y(ofLine: range.lowerBound)
        let bottom = scale.y(ofLine: range.upperBound + 1)
        let width = lifted ? MinimapView.gutterWidth + 2 : MinimapView.gutterWidth
        return Path(roundedRect: CGRect(x: 0, y: top, width: width, height: max(bottom - top, 2.5)), cornerRadius: 1)
    }
}

/// What the opened file had where a mark sits, and a way to put it back.
struct EditPeekView: View {
    let mark: EditMark
    /// The lines on screen now for an addition or a modification.
    let current: [String]
    let languageCode: String
    var onRevert: () -> Void
    var onGo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                Text(ReaderCopy.lineNumber(mark.focusLine, languageCode: languageCode))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !mark.original.isEmpty {
                        section(.peekBefore, lines: mark.original, sign: "−", tint: MinimapView.removedColor)
                    }
                    if !current.isEmpty {
                        section(.peekNow, lines: current, sign: "+", tint: MinimapView.addedColor)
                    }
                }
            }
            .frame(maxHeight: 300)
            HStack {
                Spacer()
                if let onGo {
                    Button(ReaderCopy.string(.goToChange, languageCode: languageCode), action: onGo)
                }
                Button(ReaderCopy.string(.revertChange, languageCode: languageCode), action: onRevert)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 460)
    }

    private var title: String {
        switch mark.kind {
        case .added(let lines): return ReaderCopy.linesAdded(lines.count, languageCode: languageCode)
        case .modified(let lines): return ReaderCopy.linesChanged(lines.count, languageCode: languageCode)
        case .removed(_, let count): return ReaderCopy.linesRemoved(count, languageCode: languageCode)
        }
    }

    private var color: Color {
        switch mark.kind {
        case .added: return MinimapView.addedColor
        case .modified: return MinimapView.modifiedColor
        case .removed: return MinimapView.removedColor
        }
    }

    private func section(_ key: CopyKey, lines: [String], sign: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ReaderCopy.string(key, languageCode: languageCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(sign)
                            .foregroundStyle(tint)
                        Text(line.isEmpty ? " " : line)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Shared by the minimap and the line-number gutter.
enum EditColors {
    static let added = NSColor.systemGreen
    static let modified = NSColor.systemBlue
    static let removed = NSColor.systemRed
}
