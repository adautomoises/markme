import Foundation

public enum ReaderMode: String, Equatable, Sendable {
    case source
    case split
    case page
}

public enum OpenFailure: Equatable, Sendable {
    case notUTF8
    case unreadable
}

public struct ReaderModel: Equatable, Sendable {
    public var fileName: String
    public var text: String
    public var failure: OpenFailure?
    public var failureDetail: String
    public var mode: ReaderMode
    public var bannerDismissed: Bool

    public init(fileName: String, data: Data?, bannerDismissed: Bool) {
        self.fileName = fileName
        self.bannerDismissed = bannerDismissed
        self.mode = .page
        self.text = ""
        self.failure = nil
        self.failureDetail = ""
        apply(data)
    }

    public mutating func reload(data: Data?, failureDetail: String = "") {
        self.failureDetail = failureDetail
        apply(data)
    }

    public mutating func dismissBannerForever() {
        bannerDismissed = true
    }

    public var showsBanner: Bool { !bannerDismissed }

    private mutating func apply(_ data: Data?) {
        guard let data else {
            failure = .unreadable
            return
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            failure = .notUTF8
            failureDetail = ""
            return
        }
        text = decoded
        failure = nil
        failureDetail = ""
    }
}

public struct SplitFraction: Equatable, Sendable {
    public static let minimumSide: CGFloat = 240
    public var fraction: CGFloat

    public init() {
        fraction = 0.5
    }

    public mutating func drag(translation: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        if width < Self.minimumSide * 2 {
            fraction = 0.5
            return
        }
        let proposed = fraction + translation / width
        let lower = Self.minimumSide / width
        let upper = (width - Self.minimumSide) / width
        fraction = min(max(proposed, lower), upper)
    }
}

public enum TextFind {
    public static func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }
        var found: [Range<String.Index>] = []
        var remainder = haystack.startIndex..<haystack.endIndex
        while let match = haystack.range(of: needle, options: [.caseInsensitive], range: remainder) {
            found.append(match)
            remainder = match.upperBound..<haystack.endIndex
            if remainder.isEmpty { break }
        }
        return found
    }
}

public struct ScrollSync: Equatable, Sendable {
    public static let echoInterval: TimeInterval = 0.1
    private var lockedUntil: Date?

    public init() {}

    public mutating func markEcho(now: Date) {
        lockedUntil = now.addingTimeInterval(Self.echoInterval)
    }

    public func isEcho(now: Date) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }
}

public enum SourceTextConfiguration {
    public static let isEditable = false
    public static let isSelectable = true
}
