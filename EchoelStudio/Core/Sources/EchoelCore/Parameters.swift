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
}

public enum ParameterUnit: String, Codable, Sendable {
    case bpm, decibel, pan
}

/// How a 0…1 control (a CC, a fader, a modulation amount) maps onto the parameter's range.
public enum ParameterTaper: Sendable, Equatable {
    case linear
    /// Cubic amplitude law, the standard console fader feel: most travel sits where levels
    /// are actually set, and the bottom of the throw is silence.
    case fader
}

public struct ParameterDescriptor: Sendable, Equatable {
    public let address: ParameterAddress
    public let title: String
    public let unit: ParameterUnit
    public let range: ClosedRange<Double>
    public let defaultValue: Double
    public let taper: ParameterTaper

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
        }
        return list
    }

    /// The descriptor for `address`, or nil when it names nothing in this project.
    public func descriptor(for address: ParameterAddress) -> ParameterDescriptor? {
        guard value(of: address) != nil else { return nil }
        let title: String
        switch address.owner {
        case .project: title = "Tempo"
        case .master: title = address.key == .pan ? "Master Pan" : "Master Volume"
        case .track(let id):
            guard let track = track(id) else { return nil }
            title = "\(track.name) \(address.key == .pan ? "Pan" : "Volume")"
        }
        return Self.descriptor(address, title: title)
    }

    /// The current value at `address`, or nil when it names nothing in this project.
    public func value(of address: ParameterAddress) -> Double? {
        switch (address.owner, address.key) {
        case (.project, .tempo): return tempo
        case (.master, .volume): return master.volumeDB
        case (.master, .pan): return master.pan
        case (.track(let id), .volume): return track(id)?.mixer.volumeDB
        case (.track(let id), .pan): return track(id)?.mixer.pan
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
            return ParameterDescriptor(address: address, title: title, unit: .decibel, range: MixerStrip.volumeRange,
                                       defaultValue: 0, taper: .fader)
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
        default: return nil
        }
    }
}
