import Foundation

/// One name for every continuous control in a project. Automation lanes, MIDI-learn mappings,
/// the agent and — later — modulation sources (LFOs, envelopes, the body) all address a control
/// by this value and nothing else, so a new source never needs its own path into the document.
public struct ParameterAddress: Hashable, Codable, Sendable, CustomStringConvertible {
    public enum Owner: Hashable, Codable, Sendable {
        case project
        case master
        case track(TrackID)
    }

    public let owner: Owner
    public let key: ParameterKey

    public init(_ owner: Owner, _ key: ParameterKey) {
        self.owner = owner
        self.key = key
    }

    public static let tempo = ParameterAddress(.project, .tempo)
    public static let masterVolume = ParameterAddress(.master, .volume)
    public static let masterPan = ParameterAddress(.master, .pan)
    public static func volume(_ track: TrackID) -> ParameterAddress { ParameterAddress(.track(track), .volume) }
    public static func pan(_ track: TrackID) -> ParameterAddress { ParameterAddress(.track(track), .pan) }

    /// Stable text form, e.g. `track/<uuid>/mixer.volume` — what the agent reads and writes.
    public var description: String {
        switch owner {
        case .project: "project/\(key.rawValue)"
        case .master: "master/\(key.rawValue)"
        case .track(let id): "track/\(id.description)/\(key.rawValue)"
        }
    }
}

/// An open set of keys: devices and plugins add their own later without touching this file.
/// Like command names, a key is stored in mappings and lanes and is never renamed.
public struct ParameterKey: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let tempo = ParameterKey(rawValue: "tempo")
    public static let volume = ParameterKey(rawValue: "mixer.volume")
    public static let pan = ParameterKey(rawValue: "mixer.pan")

    private static let sendPrefix = "mixer.send/"

    /// A track's send level into one return track.
    public static func send(to target: TrackID) -> ParameterKey {
        ParameterKey(rawValue: sendPrefix + target.description)
    }

    /// The return track this key sends to, if it is a send key.
    public var sendTarget: TrackID? {
        guard rawValue.hasPrefix(Self.sendPrefix),
              let uuid = UUID(uuidString: String(rawValue.dropFirst(Self.sendPrefix.count))) else { return nil }
        return TrackID(uuid)
    }
}

extension ParameterAddress {
    public static func send(_ track: TrackID, to target: TrackID) -> ParameterAddress {
        ParameterAddress(.track(track), .send(to: target))
    }

    /// One parameter of an Audio Unit on `track`: its instrument plugin or one of its inserts.
    public static func plugin(_ track: TrackID, _ parameter: PluginParameter) -> ParameterAddress {
        ParameterAddress(.track(track), .plugin(parameter))
    }
}

/// A parameter of a hosted Audio Unit, by the unit's own parameter address. The song stores its
/// value as 0…1 of the parameter's travel: the unit's ranges belong to the unit and can change
/// with its version, a position along them does not.
public struct PluginParameter: Hashable, Sendable {
    public enum Unit: Hashable, Sendable {
        /// The track's instrument plugin.
        case instrument
        case insert(InsertID)
    }

    public let unit: Unit
    /// The `AUParameterAddress` the unit gave the parameter.
    public let address: UInt64

    public init(_ unit: Unit, address: UInt64) {
        self.unit = unit
        self.address = address
    }
}

extension ParameterKey {
    private static let instrumentPluginPrefix = "plugin.instrument/"
    private static let insertPluginPrefix = "plugin.insert/"

    public static func plugin(_ parameter: PluginParameter) -> ParameterKey {
        switch parameter.unit {
        case .instrument: ParameterKey(rawValue: instrumentPluginPrefix + String(parameter.address))
        case .insert(let id): ParameterKey(rawValue: insertPluginPrefix + id.description + "/" + String(parameter.address))
        }
    }

    /// The plugin parameter this key names, if it is a plugin key.
    public var pluginParameter: PluginParameter? {
        if rawValue.hasPrefix(Self.instrumentPluginPrefix) {
            guard let address = UInt64(rawValue.dropFirst(Self.instrumentPluginPrefix.count)) else { return nil }
            return PluginParameter(.instrument, address: address)
        }
        guard rawValue.hasPrefix(Self.insertPluginPrefix) else { return nil }
        let rest = rawValue.dropFirst(Self.insertPluginPrefix.count)
        guard let slash = rest.firstIndex(of: "/"), let uuid = UUID(uuidString: String(rest[..<slash])),
              let address = UInt64(rest[rest.index(after: slash)...]) else { return nil }
        return PluginParameter(.insert(InsertID(uuid)), address: address)
    }
}

public enum ParameterUnit: String, Codable, Sendable {
    case bpm, decibel, pan
    case hertz, seconds, octaves
    /// A plain 0…1 amount.
    case amount
    /// One of the descriptor's named `choices`, stored as its index.
    case choice
}

/// How a 0…1 control (a CC, a fader, a modulation amount) maps onto the parameter's range.
public enum ParameterTaper: Sendable, Equatable {
    case linear
    /// Cubic amplitude law, the standard console fader feel: most travel sits where levels
    /// are actually set, and the bottom of the throw is silence.
    case fader
    /// Equal ratios per equal travel — frequencies and times, where an octave or a doubling
    /// should feel the same everywhere. Needs a positive lower bound.
    case exponential
    /// Whole steps from the lower bound: named choices.
    case stepped
}

public struct ParameterDescriptor: Sendable, Equatable {
    public let address: ParameterAddress
    public let title: String
    public let unit: ParameterUnit
    public let range: ClosedRange<Double>
    public let defaultValue: Double
    public let taper: ParameterTaper
    /// The names of a `.choice` parameter's values, in index order; empty otherwise.
    public let choices: [String]

    public init(address: ParameterAddress, title: String, unit: ParameterUnit, range: ClosedRange<Double>,
                defaultValue: Double, taper: ParameterTaper, choices: [String] = []) {
        self.address = address
        self.title = title
        self.unit = unit
        self.range = range
        self.defaultValue = defaultValue
        self.taper = taper
        self.choices = choices
    }

    /// The parameter value for a normalised control position. Non-finite input reads as 0.
    public func value(forNormalized position: Double) -> Double {
        let n = position.isFinite ? Swift.min(Swift.max(position, 0), 1) : 0
        switch taper {
        case .linear:
            return range.lowerBound + n * (range.upperBound - range.lowerBound)
        case .fader:
            guard n > 0 else { return range.lowerBound }
            let maxGain = Foundation.pow(10, range.upperBound / 20)
            let db = 20 * Foundation.log10(n * n * n * maxGain)
            return Swift.min(Swift.max(db, range.lowerBound), range.upperBound)
        case .exponential:
            guard range.lowerBound > 0 else { return range.lowerBound + n * (range.upperBound - range.lowerBound) }
            return range.lowerBound * Foundation.pow(range.upperBound / range.lowerBound, n)
        case .stepped:
            return (range.lowerBound + n * (range.upperBound - range.lowerBound)).rounded()
        }
    }

    /// The control position for a parameter value; the inverse of `value(forNormalized:)`.
    public func normalized(_ value: Double) -> Double {
        let v = value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : defaultValue
        switch taper {
        case .linear:
            let span = range.upperBound - range.lowerBound
            return span > 0 ? (v - range.lowerBound) / span : 0
        case .fader:
            guard v > range.lowerBound else { return 0 }
            let maxGain = Foundation.pow(10, range.upperBound / 20)
            let cube = Foundation.pow(10, v / 20) / maxGain
            return Swift.min(Swift.max(Foundation.cbrt(cube), 0), 1)
        case .exponential:
            guard range.lowerBound > 0, range.upperBound > range.lowerBound else { return 0 }
            return Foundation.log(v / range.lowerBound) / Foundation.log(range.upperBound / range.lowerBound)
        case .stepped:
            let span = range.upperBound - range.lowerBound
            return span > 0 ? (v.rounded() - range.lowerBound) / span : 0
        }
    }
}

extension Project {
    /// Every addressable parameter in the project, in display order.
    public var parameters: [ParameterDescriptor] {
        var list = [
            Self.descriptor(.tempo, title: "Tempo"),
            Self.descriptor(.masterVolume, title: "Master Volume"),
            Self.descriptor(.masterPan, title: "Master Pan"),
        ]
        for track in tracks {
            list.append(Self.descriptor(.volume(track.id), title: "\(track.name) Volume"))
            list.append(Self.descriptor(.pan(track.id), title: "\(track.name) Pan"))
            if track.kind != .returnTrack {
                for target in tracks where target.kind == .returnTrack {
                    list.append(Self.descriptor(.send(track.id, to: target.id), title: "\(track.name) → \(target.name)"))
                }
            }
            if track.kind == .instrument {
                list += SynthParameter.all.map { $0.descriptor(track: track) }
            }
        }
        return list
    }

    /// The descriptor for `address`, or nil when it names nothing in this project.
    public func descriptor(for address: ParameterAddress) -> ParameterDescriptor? {
        if case .track(let id) = address.owner, let parameter = address.key.pluginParameter {
            guard let track = track(id), let plugin = track.plugin(for: parameter.unit) else { return nil }
            // The unit names its parameters; the song only knows where it is.
            return ParameterDescriptor(address: address, title: "\(track.name) \(plugin.name) #\(parameter.address)",
                                       unit: .amount, range: 0...1, defaultValue: 0, taper: .linear)
        }
        guard value(of: address) != nil else { return nil }
        if case .track(let id) = address.owner, let synth = SynthParameter.named(address.key), let track = track(id) {
            return synth.descriptor(track: track)
        }
        let title: String
        switch address.owner {
        case .project: title = "Tempo"
        case .master: title = address.key == .pan ? "Master Pan" : "Master Volume"
        case .track(let id):
            guard let track = track(id) else { return nil }
            if let target = address.key.sendTarget.flatMap({ self.track($0) }) {
                title = "\(track.name) → \(target.name)"
            } else {
                title = "\(track.name) \(address.key == .pan ? "Pan" : "Volume")"
            }
        }
        return Self.descriptor(address, title: title)
    }

    /// The current value at `address`, or nil when it names nothing in this project. A plugin
    /// parameter's value lives in the unit, not the song: nil, though it has a descriptor.
    public func value(of address: ParameterAddress) -> Double? {
        switch (address.owner, address.key) {
        case (.project, .tempo): return tempo
        case (.master, .volume): return master.volumeDB
        case (.master, .pan): return master.pan
        case (.track(let id), .volume): return track(id)?.mixer.volumeDB
        case (.track(let id), .pan): return track(id)?.mixer.pan
        case (.track(let id), let key) where key.sendTarget != nil:
            guard let source = track(id), source.kind != .returnTrack, let target = key.sendTarget,
                  track(target)?.kind == .returnTrack else { return nil }
            return source.send(to: target)?.levelDB ?? MixerStrip.volumeRange.lowerBound
        case (.track(let id), let key):
            guard let synth = SynthParameter.named(key), let track = track(id), track.kind == .instrument else { return nil }
            return track.instrument.value(synth)
        default: return nil
        }
    }

    private static func descriptor(_ address: ParameterAddress, title: String) -> ParameterDescriptor {
        switch address.key {
        case .tempo:
            return ParameterDescriptor(address: address, title: title, unit: .bpm, range: Tempo.range,
                                       defaultValue: Tempo.defaultBPM, taper: .linear)
        case .pan:
            return ParameterDescriptor(address: address, title: title, unit: .pan, range: MixerStrip.panRange,
                                       defaultValue: 0, taper: .linear)
        default:
            // A send starts silent; double-tap returns it there.
            return ParameterDescriptor(address: address, title: title, unit: .decibel, range: MixerStrip.volumeRange,
                                       defaultValue: address.key.sendTarget == nil ? 0 : MixerStrip.volumeRange.lowerBound,
                                       taper: .fader)
        }
    }
}

extension Command {
    /// The command that sets `address` to `value`. A parameter has no writer of its own: this
    /// returns the same command the dedicated control would send, so validation, undo titles
    /// and the catalog stay in one place. Nil when the address names no parameter.
    public static func setParameter(_ address: ParameterAddress, to value: Double) -> Command? {
        switch (address.owner, address.key) {
        case (.project, .tempo): return .setTempo(bpm: value)
        case (.master, .volume): return .setVolume(.master, db: value)
        case (.master, .pan): return .setPan(.master, pan: value)
        case (.track(let id), .volume): return .setVolume(.track(id), db: value)
        case (.track(let id), .pan): return .setPan(.track(id), pan: value)
        case (.track(let id), let key) where key.sendTarget != nil:
            guard let target = key.sendTarget else { return nil }
            return .setSend(track: id, to: target, db: value)
        case (.track(let id), let key) where SynthParameter.named(key) != nil:
            return .setInstrumentParameter(id, key: key.rawValue, value: value)
        default: return nil
        }
    }
}

extension Track {
    /// The plugin a plugin parameter belongs to: the instrument plugin of an instrument track
    /// (chosen, whether or not it is the device playing), or the named insert.
    public func plugin(for unit: PluginParameter.Unit) -> PluginComponent? {
        switch unit {
        case .instrument: kind == .instrument ? instrument.plugin : nil
        case .insert(let id): inserts.first { $0.id == id }?.plugin
        }
    }
}

extension Project {
    /// Drops the lanes and mappings of one unit's parameters on `track` — its addresses mean
    /// nothing to the unit that replaces it.
    mutating func forgetParameters(of unit: PluginParameter.Unit, on track: TrackID) {
        let gone = { (address: ParameterAddress) in
            address.owner == .track(track) && address.key.pluginParameter?.unit == unit
        }
        automation.removeAll { gone($0.target) }
        midiMappings.removeAll { gone($0.target) }
    }
}
