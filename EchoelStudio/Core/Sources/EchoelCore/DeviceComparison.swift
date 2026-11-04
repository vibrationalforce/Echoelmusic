import Foundation

/// A/B for one device (PRO-W1): two settings of an instrument or an effect held side by side
/// while the musician compares them. Kept in memory for the session, never in the song — the song
/// stores what plays. Switching stores what plays now on the side being left and brings back the
/// other side's settings through the one door, so each switch is one undo step.
public enum DeviceComparison {
    /// The device a comparison belongs to.
    public enum Device: Hashable, Sendable {
        /// The track's instrument: a built-in one's sound, or a plugin's own settings.
        case instrument(TrackID)
        /// An insert on a track or on the master.
        case insert(InsertID)
    }

    public enum Side: String, Sendable, CaseIterable {
        case a = "A", b = "B"
        public var other: Side { self == .a ? .b : .a }
    }

    /// One side's settings.
    public enum Settings: Equatable, Sendable {
        /// A built-in instrument: its preset name and its stored values.
        case sound(preset: String, values: [String: Double])
        /// A plugin instrument or an effect: the settings the unit reported.
        case state(Data)
    }

    /// The two sides of one device and which one plays.
    public struct Pair: Equatable, Sendable {
        public private(set) var active: Side = .a
        public private(set) var a: Settings?
        public private(set) var b: Settings?

        public init() {}

        public func settings(_ side: Side) -> Settings? { side == .a ? a : b }

        private mutating func set(_ side: Side, _ settings: Settings?) {
            if side == .a { a = settings } else { b = settings }
        }

        /// Plays the other side. What plays now (`current`) is kept on the side being left; the
        /// settings to bring back are returned — nil on the first switch, when the other side
        /// starts as a copy of what plays and nothing needs to change.
        public mutating func toggle(current: Settings) -> Settings? {
            set(active, current)
            active = active.other
            guard let next = settings(active) else {
                set(active, current)
                return nil
            }
            return next == current ? nil : next
        }

        /// Copies one side onto the other. When the side copied onto is the one that plays, its
        /// new settings are returned to bring back; otherwise nil.
        public mutating func copy(_ from: Side, to: Side, current: Settings) -> Settings? {
            guard from != to else { return nil }
            set(active, current)
            let source = settings(from) ?? current
            set(to, source)
            return to == active && source != current ? source : nil
        }
    }

    /// What plays now on `device`, as the song holds it. A plugin's settings must have been stored
    /// in the song first (`PluginHost.store`); nil while the song holds none, or the device is gone.
    public static func current(_ device: Device, in project: Project) -> Settings? {
        switch device {
        case .instrument(let id):
            guard let track = project.track(id), track.kind == .instrument else { return nil }
            if track.instrument.device == .plugin {
                return track.instrument.pluginState.map(Settings.state)
            }
            return .sound(preset: track.instrument.preset, values: track.instrument.values)
        case .insert(let id):
            if let insert = project.masterInserts.first(where: { $0.id == id }) { return insert.state.map(Settings.state) }
            for track in project.tracks {
                if let insert = track.inserts.first(where: { $0.id == id }) { return insert.state.map(Settings.state) }
            }
            return nil
        }
    }

    /// The command that brings `settings` back on `device`; nil when the device is gone or the
    /// settings are of the other kind.
    public static func command(restoring settings: Settings, on device: Device, in project: Project) -> Command? {
        switch (device, settings) {
        case let (.instrument(id), .sound(preset, values)):
            guard let track = project.track(id), track.instrument.device != .plugin else { return nil }
            return .setInstrumentSound(id, preset: preset, values: values)
        case let (.instrument(id), .state(data)):
            guard let track = project.track(id), track.instrument.device == .plugin else { return nil }
            return .setPluginState(id, data)
        case let (.insert(id), .state(data)):
            if project.masterInserts.contains(where: { $0.id == id }) { return .setMasterInsertState(id, data) }
            guard let track = project.tracks.first(where: { $0.inserts.contains { $0.id == id } }) else { return nil }
            return .setInsertState(track: track.id, id, data)
        case (.insert, .sound):
            return nil
        }
    }
}
