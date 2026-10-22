import Foundation

/// Decides what a write to the open file means, and what an outside write means.
///
/// The page follows the buffer at once. The file is written after `saveDelay` of quiet.
/// A write of our own must not come back as a reload. An outside write during an
/// unfinished sentence waits until the person chooses.
public struct DraftSync: Equatable, Sendable {
    public static let saveDelay: TimeInterval = 0.5

    public private(set) var saved: String
    public private(set) var pendingWrite: String?
    public private(set) var echoedWrite: String?
    public private(set) var heldDisk: String?

    public init(saved: String) {
        self.saved = saved
    }

    /// An outside version is waiting. Saving now would replace it.
    public var saveIsBlocked: Bool { heldDisk != nil }

    public mutating func willWrite(_ text: String) {
        pendingWrite = text
    }

    public mutating func didWrite(_ text: String) {
        if pendingWrite == text { pendingWrite = nil }
        echoedWrite = text
        if heldDisk == nil { saved = text }
    }

    public mutating func failWrite(_ text: String) {
        if pendingWrite == text { pendingWrite = nil }
    }

    public enum Arrival: Equatable, Sendable {
        /// Disk matches the buffer.
        case same
        /// Disk matches a write of ours, and the buffer has moved on.
        case continued
        /// The buffer matched disk, and disk has a new version.
        case reload
        /// The buffer and disk both moved. `heldDisk` is the outside version.
        case conflict
    }

    public mutating func receive(disk: String, buffer: String) -> Arrival {
        if disk == buffer {
            saved = disk
            pendingWrite = nil
            echoedWrite = nil
            heldDisk = nil
            return .same
        }
        if disk == pendingWrite || disk == echoedWrite {
            saved = disk
            pendingWrite = nil
            echoedWrite = nil
            return .continued
        }
        if buffer == saved && heldDisk == nil {
            saved = disk
            return .reload
        }
        heldDisk = disk
        return .conflict
    }

    public mutating func keepMine() {
        heldDisk = nil
    }

    /// The outside text to show. Empty when nothing is held.
    public mutating func takeDisk() -> String? {
        guard let heldDisk else { return nil }
        saved = heldDisk
        pendingWrite = nil
        echoedWrite = nil
        self.heldDisk = nil
        return saved
    }
}
