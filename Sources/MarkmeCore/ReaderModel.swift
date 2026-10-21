import Foundation

public enum ReaderMode: String, Equatable, Sendable {
    case source
    case split
    case page
    case presentation
}

/// What to do with the window chrome when presentation mode changes.
///
/// The toolbar must stay visible until the window is actually fullscreen.
/// AppKit remembers the toolbar visibility from the moment fullscreen starts
/// and puts that visibility back on the way out. Hiding the buttons earlier
/// makes them stay gone after Escape.
public struct PresentationChrome: Equatable, Sendable {
    public var hideToolbar: Bool
    public var toggleFullscreen: Bool
    public var enteredByUs: Bool

    public init(hideToolbar: Bool, toggleFullscreen: Bool, enteredByUs: Bool) {
        self.hideToolbar = hideToolbar
        self.toggleFullscreen = toggleFullscreen
        self.enteredByUs = enteredByUs
    }
}

public enum PresentationChromePlanner {
    public static func plan(presenting: Bool, fullscreen: Bool, enteredByUs: Bool) -> PresentationChrome {
        if presenting {
            if fullscreen {
                return PresentationChrome(hideToolbar: true, toggleFullscreen: false, enteredByUs: enteredByUs)
            }
            return PresentationChrome(hideToolbar: false, toggleFullscreen: true, enteredByUs: true)
        }
        return PresentationChrome(
            hideToolbar: false,
            toggleFullscreen: enteredByUs && fullscreen,
            enteredByUs: false
        )
    }
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
    public static let baseFontSize: CGFloat = 13

    public static func fontSize(zoom: Double) -> CGFloat {
        baseFontSize * CGFloat(zoom)
    }
}

public enum ReaderZoomAction: String, Equatable, Sendable {
    case zoomIn
    case zoomOut
    case actualSize
}

public struct ReaderZoom: Equatable, Sendable {
    public static let minimumTenths = 5
    public static let maximumTenths = 30
    public static let identityTenths = 10
    public private(set) var tenths: Int

    public init() {
        tenths = Self.identityTenths
    }

    public var factor: Double { Double(tenths) / 10 }

    public mutating func apply(_ action: ReaderZoomAction) {
        switch action {
        case .zoomIn:
            tenths = min(tenths + 1, Self.maximumTenths)
        case .zoomOut:
            tenths = max(tenths - 1, Self.minimumTenths)
        case .actualSize:
            tenths = Self.identityTenths
        }
    }
}

public struct WheelZoom: Equatable, Sendable {
    public static let precisePointsPerStep = 48.0
    public private(set) var remainder: Double = 0

    public init() {}

    /// An upward scroll (`deltaY` > 0) zooms in. A mouse notch is one step.
    /// A trackpad accumulates points until `precisePointsPerStep`.
    public mutating func actions(deltaY: Double, precise: Bool) -> [ReaderZoomAction] {
        guard deltaY.isFinite, deltaY != 0 else { return [] }
        if !precise {
            remainder = 0
            return [deltaY > 0 ? .zoomIn : .zoomOut]
        }
        remainder += deltaY
        let count = Int((remainder / Self.precisePointsPerStep).rounded(.towardZero))
        guard count != 0 else { return [] }
        remainder -= Double(count) * Self.precisePointsPerStep
        let steps = min(abs(count), 3)
        return Array(repeating: count > 0 ? ReaderZoomAction.zoomIn : .zoomOut, count: steps)
    }

    public mutating func endGesture() {
        remainder = 0
    }
}
