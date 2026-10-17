import Foundation

/// An Audio Unit effect on a track's insert chain. The chain runs in order on the track's
/// signal before its fader and pan; a bypassed insert passes the signal through and keeps its
/// place and settings.
public struct Insert: Codable, Equatable, Sendable, Identifiable {
    public var id: InsertID
    public var plugin: PluginComponent
    /// The effect's own settings as it reported them, at most `PluginComponent.maximumStateBytes`.
    public var state: Data?
    public var isBypassed: Bool

    /// Effects on one track. Each one costs a render call per block.
    public static let maximumPerTrack = 8

    public init(id: InsertID = InsertID(), plugin: PluginComponent, state: Data? = nil, isBypassed: Bool = false) {
        self.id = id
        self.plugin = plugin
        self.state = state
        self.isBypassed = isBypassed
    }
}

extension Track {
    public func insertIndex(_ id: InsertID) -> Int? {
        inserts.firstIndex { $0.id == id }
    }
}
