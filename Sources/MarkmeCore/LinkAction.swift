import Foundation

public enum LinkAction: Equatable, Sendable {
    case browser(URL)
    case markdownFile(URL)
    case anchor(String)
    case ignore
}

public enum LinkResolver {
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdwn"]

    public static func resolve(href: String, baseDirectory: URL) -> LinkAction {
        if href.hasPrefix("#") {
            let name = String(href.dropFirst())
            return name.isEmpty ? .ignore : .anchor(name)
        }

        if let url = URL(string: href), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" {
                return .browser(url)
            }
            return .ignore
        }

        let withoutQuery = href.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        let path = withoutQuery.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? withoutQuery
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        guard markdownExtensions.contains(ext) else { return .ignore }

        let root = baseDirectory.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return .markdownFile(URL(fileURLWithPath: prefix + path).standardizedFileURL)
    }
}

public enum DocumentLoadDecision: Equatable, Sendable {
    case allow
    case cancel
}

public enum DocumentLoadPolicy {
    public static func decide(isLinkActivation: Bool, requestIsInitialDocument: Bool) -> DocumentLoadDecision {
        if isLinkActivation || !requestIsInitialDocument { return .cancel }
        return .allow
    }
}
