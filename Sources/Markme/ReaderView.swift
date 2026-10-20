import AppKit
import SwiftUI
import MarkmeCore

struct ReaderView: View {
    let fileURL: URL?
    @State private var model: ReaderModel
    @State private var pageHTML = ""
    @State private var split = SplitFraction()
    @State private var dragOrigin: CGFloat = 0.5
    @State private var findQuery = ""
    @State private var findPresented = false
    @State private var pageScrollLine: Int?
    @State private var sourceScrollLine: Int?
    @State private var anchorName: String?
    @State private var anchorToken = 0
    @State private var hostWindow: NSWindow?
    @State private var sync = ScrollSync()
    @StateObject private var watcher = FileWatcher()

    init(document: ReaderDocument, fileURL: URL?) {
        self.fileURL = fileURL
        let name = fileURL?.lastPathComponent ?? "markdown"
        let dismissed = UserDefaults.standard.bool(forKey: Self.bannerKey)
        let data: Data? = document.missing ? nil : document.data
        _model = State(initialValue: ReaderModel(fileName: name, data: data, bannerDismissed: dismissed))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.showsBanner {
                banner
                Divider()
            }
            if findPresented {
                findBar
                Divider()
            }
            documentBody
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar { modeToolbar }
        .background(WindowPlacement { hostWindow = $0 })
        .onAppear { startWatching() }
        .onReceive(NotificationCenter.default.publisher(for: .markmeFind)) { _ in
            guard ownsMenuAction else { return }
            findPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .markmeMode)) { note in
            guard ownsMenuAction, let raw = note.object as? String, let mode = ReaderMode(rawValue: raw) else { return }
            model.mode = mode
        }
        .onDisappear { watcher.stop() }
        .task(id: model.text) { await renderPage() }
    }

    @ViewBuilder
    private var documentBody: some View {
        if let failure = model.failure {
            Text(ReaderCopy.string(failure == .notUTF8 ? .notUTF8 : .unreadable, languageCode: languageCode))
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            switch model.mode {
            case .page:
                page
            case .source:
                source
            case .split:
                splitBody
            }
        }
    }

    private var page: some View {
        PageWebView(
            html: pageHTML,
            baseURL: fileURL?.deletingLastPathComponent(),
            findQuery: findPresented ? findQuery : "",
            scrollToLine: pageScrollLine,
            scrollToAnchor: anchorName,
            anchorToken: anchorToken,
            onLink: open,
            onVisibleLine: pageScrolled
        )
    }

    private var source: some View {
        SourceTextView(
            text: model.text,
            findQuery: findPresented ? findQuery : "",
            scrollToLine: sourceScrollLine,
            onVisibleLine: sourceScrolled
        )
    }

    private var splitBody: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            HStack(spacing: 0) {
                source.frame(width: max(width * split.fraction, 0))
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 8)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let delta = value.translation.width
                                var next = SplitFraction()
                                next.fraction = dragOrigin
                                next.drag(translation: delta, width: width)
                                split = next
                            }
                            .onEnded { _ in
                                dragOrigin = split.fraction
                            }
                    )
                page
            }
        }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Text(copy(.bannerQuestion))
                .font(.callout)
            Spacer()
            Button(copy(.bannerNotNow)) { dismissBanner() }
            Button(copy(.bannerAccept)) { DefaultReader.request() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var findBar: some View {
        HStack {
            TextField(copy(.findPrompt), text: $findQuery)
                .textFieldStyle(.roundedBorder)
            Button(copy(.bannerNotNow)) {
                findQuery = ""
                findPresented = false
            }
        }
        .padding(8)
    }

    @ToolbarContentBuilder
    private var modeToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            modeButton(.source, symbol: "line.3.horizontal")
            modeButton(.split, symbol: "rectangle.split.2x1")
            modeButton(.page, symbol: "photo")
        }
    }

    private func modeButton(_ mode: ReaderMode, symbol: String) -> some View {
        let key: CopyKey = switch mode {
        case .source: .modeSource
        case .split: .modeSplit
        case .page: .modePage
        }
        return Button {
            model.mode = mode
        } label: {
            Image(systemName: symbol)
                .frame(width: 32, height: 28)
                .background(
                    model.mode == mode ? Color.primary.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(copy(key))
        .accessibilityLabel(copy(key))
    }

    private var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func copy(_ key: CopyKey) -> String {
        ReaderCopy.string(key, languageCode: languageCode)
    }

    private func dismissBanner() {
        model.dismissBannerForever()
        UserDefaults.standard.set(true, forKey: Self.bannerKey)
    }

    private func renderPage() async {
        let text = model.text
        let highlighter = HighlighterLibrary.script
        let html = await Task.detached(priority: .userInitiated) {
            PageShell.html(body: MarkdownRenderer.render(text).htmlBody, highlighter: highlighter)
        }.value
        pageHTML = html
    }

    private var ownsMenuAction: Bool {
        guard let hostWindow else { return NSApp.windows.count < 2 }
        return hostWindow.isKeyWindow || hostWindow.isMainWindow
    }

    private func open(_ url: URL) {
        if let fragment = url.fragment, !fragment.isEmpty, isCurrentDocument(url) {
            scrollToAnchor(fragment)
            return
        }
        let href = url.isFileURL ? url.lastPathComponent : url.absoluteString
        let base = fileURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/")
        switch LinkResolver.resolve(href: href, baseDirectory: base) {
        case .browser(let destination):
            NSWorkspace.shared.open(destination)
        case .markdownFile:
            NSWorkspace.shared.open(url)
        case .anchor(let name):
            scrollToAnchor(name)
        case .ignore:
            if url.isFileURL {
                let ext = url.pathExtension.lowercased()
                if ["md", "markdown", "mdown", "mkd", "mdwn"].contains(ext) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func scrollToAnchor(_ name: String) {
        let decoded = name.removingPercentEncoding ?? name
        guard !decoded.isEmpty else { return }
        anchorName = decoded
        anchorToken += 1
    }

    private func isCurrentDocument(_ url: URL) -> Bool {
        if url.scheme == "about" { return true }
        if sameFile(url) { return true }
        guard url.isFileURL, let fileURL else { return false }
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let directory = fileURL.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().path
        return path == directory
    }

    private func sameFile(_ url: URL) -> Bool {
        guard let fileURL else { return false }
        return url.path == fileURL.path
    }

    private func pageScrolled(_ line: Int) {
        let now = Date()
        guard !sync.isEcho(now: now), model.mode == .split else { return }
        sync.markEcho(now: now)
        sourceScrollLine = line
    }

    private func sourceScrolled(_ line: Int) {
        let now = Date()
        guard !sync.isEcho(now: now), model.mode == .split else { return }
        sync.markEcho(now: now)
        pageScrollLine = line
    }

    private func startWatching() {
        guard let fileURL else { return }
        _ = fileURL.startAccessingSecurityScopedResource()
        watcher.onChange = {
            let data = try? Data(contentsOf: fileURL)
            model.reload(data: data)
        }
        watcher.start(url: fileURL)
    }

    static let bannerKey = "markme.bannerDismissed"
}

private enum HighlighterLibrary {
    static let script: String = {
        if let url = Bundle.main.url(forResource: "highlight.min", withExtension: "js"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Resources/highlight.min.js")
        return (try? String(contentsOf: dev, encoding: .utf8)) ?? ""
    }()
}

extension Notification.Name {
    static let markmeFind = Notification.Name("markme.find")
    static let markmeMode = Notification.Name("markme.mode")
}

private struct WindowPlacement: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PlacementView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PlacementView else { return }
        view.onWindow = onWindow
    }

    final class PlacementView: NSView {
        var onWindow: (NSWindow?) -> Void = { _ in }
        private var placed = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow(window)
            schedule()
        }

        private func schedule() {
            DispatchQueue.main.async { [weak self] in self?.centerIfOffscreen(lock: false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.centerIfOffscreen(lock: true)
            }
        }

        private func centerIfOffscreen(lock: Bool) {
            guard let window, !placed else { return }
            let frame = window.frame
            guard frame.width > 40, frame.height > 40 else { return }
            let visible = NSScreen.screens.contains { screen in
                let overlap = frame.intersection(screen.visibleFrame)
                return !overlap.isNull && overlap.width > 80 && overlap.height > 80
            }
            if !visible {
                window.center()
            }
            if visible || lock {
                placed = true
            }
        }
    }
}

final class FileWatcher: ObservableObject {
    var onChange: () -> Void = {}
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var descriptor: CInt = -1

    func start(url: URL) {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .link],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            self?.schedule()
        }
        let descriptor = descriptor
        source.setCancelHandler {
            if descriptor >= 0 { close(descriptor) }
        }
        source.resume()
        self.source = source
    }

    func stop() {
        pending?.cancel()
        source?.cancel()
        source = nil
        descriptor = -1
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
