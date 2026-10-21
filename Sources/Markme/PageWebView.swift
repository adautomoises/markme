import SwiftUI
import WebKit
import MarkmeCore

struct PageWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let findQuery: String
    let scrollToLine: Int?
    let scrollToAnchor: String?
    let anchorToken: Int
    let zoom: Double
    let presenting: Bool
    let slideIndex: Int
    let changeCursor: Int?
    let changeScrollToken: Int
    var onSlide: (Int) -> Void
    var onLink: (URL) -> Void
    var onVisibleLine: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLink: onLink, onVisibleLine: onVisibleLine, onSlide: onSlide)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "markme")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        view.pageZoom = zoom
        context.coordinator.pageZoom = zoom
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onLink = onLink
        context.coordinator.onVisibleLine = onVisibleLine
        context.coordinator.onSlide = onSlide
        context.coordinator.pageZoom = zoom
        if abs(view.pageZoom - zoom) > 0.001 {
            view.pageZoom = zoom
        }
        let presentationChanged = context.coordinator.presenting != presenting
            || context.coordinator.slideIndex != slideIndex
        context.coordinator.presenting = presenting
        context.coordinator.slideIndex = slideIndex
        if presentationChanged {
            context.coordinator.applyPresentation(in: view)
        }
        if context.coordinator.lastChangeToken != changeScrollToken {
            context.coordinator.lastChangeToken = changeScrollToken
            context.coordinator.pendingChangeToken = changeScrollToken
            context.coordinator.pendingChangeCursor = changeScrollToken > 0 ? changeCursor : nil
        }
        let htmlChanged = context.coordinator.lastHTML != html || context.coordinator.lastBase != baseURL
        if htmlChanged {
            context.coordinator.lastHTML = html
            context.coordinator.lastBase = baseURL
            context.coordinator.awaitingLoad = true
            view.loadHTMLString(html, baseURL: baseURL)
        } else if !context.coordinator.awaitingLoad,
                  context.coordinator.pendingChangeToken > 0,
                  let changeCursor = context.coordinator.pendingChangeCursor {
            context.coordinator.pendingChangeCursor = nil
            context.coordinator.pendingChangeToken = 0
            view.evaluateJavaScript(
                "window.markmeShowChange && window.markmeShowChange(\(changeCursor))",
                completionHandler: nil
            )
        }
        if context.coordinator.lastFind != findQuery {
            context.coordinator.lastFind = findQuery
            let configuration = WKFindConfiguration()
            configuration.caseSensitive = false
            view.find(findQuery, configuration: configuration) { _ in }
        }
        if let scrollToLine,
           context.coordinator.pendingChangeToken == 0,
           context.coordinator.lastScroll != scrollToLine {
            context.coordinator.lastScroll = scrollToLine
            view.evaluateJavaScript("window.markmeScrollToLine && window.markmeScrollToLine(\(scrollToLine))", completionHandler: nil)
        }
        if anchorToken != context.coordinator.lastAnchorToken {
            context.coordinator.lastAnchorToken = anchorToken
            context.coordinator.pendingAnchor = scrollToAnchor
            if let scrollToAnchor {
                Coordinator.scrollToAnchor(scrollToAnchor, in: view)
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLink: (URL) -> Void
        var onVisibleLine: (Int) -> Void
        var onSlide: (Int) -> Void
        var lastHTML: String?
        var lastBase: URL?
        var lastFind: String?
        var lastScroll: Int?
        var lastAnchorToken = 0
        var pendingAnchor: String?
        var lastReportedLine: Int?
        var pageZoom = 1.0
        var presenting = false
        var slideIndex = 0
        var lastChangeToken = 0
        var pendingChangeCursor: Int?
        var pendingChangeToken = 0
        var awaitingLoad = false

        func applyPresentation(in webView: WKWebView) {
            let flag = presenting ? "true" : "false"
            let requested = slideIndex
            webView.evaluateJavaScript(
                "(function () { if (window.markmePresent) window.markmePresent(\(flag)); return window.markmeSlide ? window.markmeSlide(\(requested)) : 0; })()"
            ) { value, _ in
                let shown: Int?
                if let number = value as? Int {
                    shown = number
                } else if let number = value as? NSNumber {
                    shown = number.intValue
                } else {
                    shown = nil
                }
                guard let shown, shown != requested else { return }
                self.onSlide(shown)
            }
        }

        init(onLink: @escaping (URL) -> Void, onVisibleLine: @escaping (Int) -> Void, onSlide: @escaping (Int) -> Void) {
            self.onLink = onLink
            self.onVisibleLine = onVisibleLine
            self.onSlide = onSlide
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let line: Int?
            if let value = message.body as? Int {
                line = value
            } else if let number = message.body as? NSNumber {
                line = number.intValue
            } else {
                line = nil
            }
            if let line {
                lastReportedLine = line
                onVisibleLine(line)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            awaitingLoad = false
            webView.pageZoom = pageZoom
            applyPresentation(in: webView)
            webView.evaluateJavaScript(Self.scrollScript) { _, _ in
                if let pending = self.pendingAnchor {
                    Self.scrollToAnchor(pending, in: webView)
                } else if self.pendingChangeToken > 0, let cursor = self.pendingChangeCursor {
                    self.pendingChangeCursor = nil
                    self.pendingChangeToken = 0
                    webView.evaluateJavaScript(
                        "window.markmeShowChange && window.markmeShowChange(\(cursor))",
                        completionHandler: nil
                    )
                } else if let line = self.lastReportedLine, line > 1 {
                    webView.evaluateJavaScript(
                        "window.markmeScrollToLine && window.markmeScrollToLine(\(line))",
                        completionHandler: nil
                    )
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            let isLink = navigationAction.navigationType == .linkActivated
            let initial = Self.isDocumentRequest(navigationAction.request.url, base: lastBase)
            let decision = DocumentLoadPolicy.decide(
                isLinkActivation: isLink,
                requestIsInitialDocument: initial
            )
            if decision == .allow {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            if isLink, let url = navigationAction.request.url {
                onLink(url)
            }
        }

        private static let scrollScript = """
        if (!window.__markme) {
          window.__markme = true;
          const lineOf = (node) => parseInt((node.getAttribute('data-sourcepos') || '').split(':')[0], 10);
          const report = () => {
            const nodes = document.querySelectorAll('[data-sourcepos]');
            let line = 1;
            let best = -1e9;
            nodes.forEach((node) => {
              const top = node.getBoundingClientRect().top;
              const start = lineOf(node);
              if (!Number.isNaN(start) && top <= 32 && top >= best) {
                best = top;
                line = start;
              }
            });
            window.webkit.messageHandlers.markme.postMessage(line);
          };
          document.addEventListener('scroll', report, true);
          window.markmeScrollToLine = (line) => {
            const nodes = document.querySelectorAll('[data-sourcepos]');
            let target = null;
            nodes.forEach((node) => {
              const start = lineOf(node);
              if (!Number.isNaN(start) && start <= line) target = node;
            });
            if (target) target.scrollIntoView({block: 'start'});
          };
        }
        """

        fileprivate static func isDocumentRequest(_ url: URL?, base: URL?) -> Bool {
            guard let url else { return true }
            if url.scheme == "about" { return true }
            guard url.isFileURL, let base else { return false }
            let requestPath = url.standardizedFileURL.resolvingSymlinksInPath().path
            let basePath = base.standardizedFileURL.resolvingSymlinksInPath().path
            return Self.sameDirectory(requestPath, basePath)
        }

        private static func sameDirectory(_ lhs: String, _ rhs: String) -> Bool {
            let left = lhs.hasSuffix("/") ? String(lhs.dropLast()) : lhs
            let right = rhs.hasSuffix("/") ? String(rhs.dropLast()) : rhs
            return left == right
        }

        fileprivate static func scrollToAnchor(_ id: String, in view: WKWebView) {
            view.evaluateJavaScript(
                "document.getElementById(\(jsLiteral(id)))?.scrollIntoView({block:'start'})",
                completionHandler: nil
            )
        }

        private static func jsLiteral(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: value),
                  let text = String(data: data, encoding: .utf8) else { return "\"\"" }
            return text
        }
    }
}
