import SwiftUI
import MarkmeCore

@main
struct MarkmeApp: App {
    private var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func postMode(_ mode: ReaderMode) {
        NotificationCenter.default.post(name: .markmeMode, object: mode.rawValue)
    }

    private func postZoom(_ action: ReaderZoomAction) {
        NotificationCenter.default.post(name: .markmeZoom, object: action.rawValue)
    }

    var body: some Scene {
        DocumentGroup(viewing: ReaderDocument.self) { configuration in
            ReaderView(document: configuration.document, fileURL: configuration.fileURL)
        }
        .defaultSize(width: 960, height: 680)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button(ReaderCopy.string(.copyLocation, languageCode: languageCode)) {
                    NotificationCenter.default.post(name: .markmeCopyLocation, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button(ReaderCopy.string(.modeSource, languageCode: languageCode)) {
                    postMode(.source)
                }
                .keyboardShortcut("1", modifiers: .command)
                Button(ReaderCopy.string(.modeSplit, languageCode: languageCode)) {
                    postMode(.split)
                }
                .keyboardShortcut("2", modifiers: .command)
                Button(ReaderCopy.string(.modePage, languageCode: languageCode)) {
                    postMode(.page)
                }
                .keyboardShortcut("3", modifiers: .command)
                Button(ReaderCopy.string(.modePresentation, languageCode: languageCode)) {
                    postMode(.presentation)
                }
                .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button(ReaderCopy.string(.zoomIn, languageCode: languageCode)) {
                    postZoom(.zoomIn)
                }
                .keyboardShortcut("+", modifiers: .command)
                Button(ReaderCopy.string(.zoomOut, languageCode: languageCode)) {
                    postZoom(.zoomOut)
                }
                .keyboardShortcut("-", modifiers: .command)
                Button(ReaderCopy.string(.actualSize, languageCode: languageCode)) {
                    postZoom(.actualSize)
                }
                .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(ReaderCopy.string(.findPrompt, languageCode: languageCode)) {
                    NotificationCenter.default.post(name: .markmeFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button(ReaderCopy.string(.menuMakeDefault, languageCode: languageCode)) {
                    DefaultReader.request()
                }
            }
        }
    }
}
