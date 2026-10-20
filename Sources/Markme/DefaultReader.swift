import AppKit
import UniformTypeIdentifiers

enum DefaultReader {
    static func request() {
        let bundle = Bundle.main.bundleURL
        var identifiers = Set<String>()
        var types: [UTType] = []
        if let markdown = UTType("net.daringfireball.markdown") {
            types.append(markdown)
        }
        types += ["md", "markdown", "mdown", "mkd", "mdwn"].compactMap { UTType(filenameExtension: $0) }
        for type in types where identifiers.insert(type.identifier).inserted {
            NSWorkspace.shared.setDefaultApplication(at: bundle, toOpen: type) { _ in }
        }
    }
}
