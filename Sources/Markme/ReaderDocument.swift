import SwiftUI
import UniformTypeIdentifiers

struct ReaderDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        var types = ["md", "markdown", "mdown", "mkd", "mdwn"].compactMap { UTType(filenameExtension: $0) }
        if let markdown = UTType("net.daringfireball.markdown") {
            types.append(markdown)
        }
        return types.isEmpty ? [.plainText] : types
    }

    static var writableContentTypes: [UTType] { [] }

    var data: Data
    var missing: Bool

    init(data: Data = Data(), missing: Bool = false) {
        self.data = data
        self.missing = missing
    }

    init(configuration: ReadConfiguration) throws {
        if let contents = configuration.file.regularFileContents {
            data = contents
            missing = false
        } else {
            data = Data()
            missing = true
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
