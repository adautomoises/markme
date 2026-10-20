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

    var body: some Scene {
        DocumentGroup(viewing: ReaderDocument.self) { configuration in
            ReaderView(document: configuration.document, fileURL: configuration.fileURL)
        }
        .defaultSize(width: 960, height: 680)
        .commands {
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
