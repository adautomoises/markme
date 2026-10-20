import SwiftUI
import MarkmeCore

@main
struct MarkmeApp: App {
    private var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    var body: some Scene {
        DocumentGroup(viewing: ReaderDocument.self) { configuration in
            ReaderView(document: configuration.document, fileURL: configuration.fileURL)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button(ReaderCopy.string(.menuMakeDefault, languageCode: languageCode)) {
                    DefaultReader.request()
                }
                Divider()
                Button(ReaderCopy.string(.findPrompt, languageCode: languageCode)) {
                    NotificationCenter.default.post(name: .markmeFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
