import Foundation

/// The sound of an instrument track: the preset it started from and every synth parameter
/// the musician has set. Values are stored by parameter key, so a future build that adds a
/// parameter reads an older song with that parameter at its default.
public struct InstrumentSettings: Codable, Equatable, Sendable {
    /// Which built-in instrument plays the track. Synth parameters stay stored when the
    /// device changes, so switching back restores the sound.
    public var device: InstrumentDevice
    /// The sample the sampler device plays; nil until one is chosen.
    public var sample: MediaID?
    public var preset: String
    public var values: [String: Double]

    public init(device: InstrumentDevice = .synth, sample: MediaID? = nil, preset: String = InstrumentPreset.initial.name,
                values: [String: Double] = [:]) {
        self.device = device
        self.sample = sample
        self.preset = preset
        self.values = values
    }

    private enum CodingKeys: String, CodingKey { case device, sample, preset, values }

    /// Songs written before devices existed are synth tracks.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = try c.decodeIfPresent(InstrumentDevice.self, forKey: .device) ?? .synth
        sample = try c.decodeIfPresent(MediaID.self, forKey: .sample)
        preset = try c.decode(String.self, forKey: .preset)
        values = try c.decode([String: Double].self, forKey: .values)
    }

    public func value(_ parameter: SynthParameter) -> Double {
        values[parameter.key.rawValue] ?? parameter.defaultValue
    }
}

/// The built-in instruments. Stored by name in the song; never rename a case.
public enum InstrumentDevice: String, Codable, CaseIterable, Sendable {
    /// The polyphonic subtractive synth.
    case synth
    /// The drum kit on the General MIDI drum map, played by the step sequencer.
    case drums
    /// Plays one imported audio file across the keyboard.
    case sampler

    public var title: String {
        switch self {
        case .synth: "Synth"
        case .drums: "Drums"
        case .sampler: "Sampler"
        }
    }
}

/// The built-in synth's parameters: names, ranges, defaults and how a control maps onto
/// them. The engine turns these values into a DSP patch; nothing else interprets them.
public struct SynthParameter: Sendable, Equatable {
    public let key: ParameterKey
    public let title: String
    public let unit: ParameterUnit
    public let range: ClosedRange<Double>
    public let defaultValue: Double
    public let taper: ParameterTaper
    public let choices: [String]

    public static let waveform = SynthParameter("synth.waveform", "Waveform", .choice, 0...3, 1, .stepped,
                                                choices: ["Sine", "Saw", "Square", "Triangle"])
    public static let cutoff = SynthParameter("synth.cutoff", "Cutoff", .hertz, 20...18_000, 800, .exponential)
    public static let resonance = SynthParameter("synth.resonance", "Resonance", .amount, 0...0.95, 0.3, .linear)
    public static let filterAmount = SynthParameter("synth.filterAmount", "Filter Envelope", .octaves, 0...8, 3, .linear)
    public static let filterDecay = SynthParameter("synth.filterDecay", "Filter Decay", .seconds, 0.001...10, 0.3, .exponential)
    public static let attack = SynthParameter("synth.attack", "Attack", .seconds, 0.001...10, 0.003, .exponential)
    public static let decay = SynthParameter("synth.decay", "Decay", .seconds, 0.001...10, 0.2, .exponential)
    public static let sustain = SynthParameter("synth.sustain", "Sustain", .amount, 0...1, 0.7, .linear)
    public static let release = SynthParameter("synth.release", "Release", .seconds, 0.001...10, 0.25, .exponential)
    public static let level = SynthParameter("synth.level", "Level", .amount, 0...1, 0.25, .linear)

    /// In display order.
    public static let all: [SynthParameter] = [
        waveform, cutoff, resonance, filterAmount, filterDecay, attack, decay, sustain, release, level,
    ]

    public static func named(_ key: ParameterKey) -> SynthParameter? {
        all.first { $0.key == key }
    }

    init(_ key: String, _ title: String, _ unit: ParameterUnit, _ range: ClosedRange<Double>, _ defaultValue: Double,
         _ taper: ParameterTaper, choices: [String] = []) {
        self.key = ParameterKey(rawValue: key)
        self.title = title
        self.unit = unit
        self.range = range
        self.defaultValue = defaultValue
        self.taper = taper
        self.choices = choices
    }

    func descriptor(track: Track) -> ParameterDescriptor {
        ParameterDescriptor(address: ParameterAddress(.track(track.id), key), title: "\(track.name) \(title)",
                            unit: unit, range: range, defaultValue: defaultValue, taper: taper, choices: choices)
    }

    /// Whether `value` is one this parameter accepts.
    func accepts(_ value: Double) -> Bool {
        guard value.isFinite, range.contains(value) else { return false }
        return taper != .stepped || value == value.rounded()
    }
}

/// A starting sound. Loading one replaces every synth value of the track.
public struct InstrumentPreset: Sendable, Equatable {
    public let name: String
    public let values: [String: Double]

    init(_ name: String, _ values: [SynthParameter: Double] = [:]) {
        self.name = name
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.key.key.rawValue, $0.value) })
    }

    public static let initial = InstrumentPreset("Init")

    public static let all: [InstrumentPreset] = [
        initial,
        InstrumentPreset("Pluck", [.waveform: 1, .cutoff: 400, .resonance: 0.35, .filterAmount: 4.5, .filterDecay: 0.2,
                                   .attack: 0.002, .decay: 0.25, .sustain: 0, .release: 0.2, .level: 0.3]),
        InstrumentPreset("Warm Pad", [.waveform: 1, .cutoff: 600, .resonance: 0.2, .filterAmount: 1.5, .filterDecay: 1.5,
                                      .attack: 0.6, .decay: 1, .sustain: 0.8, .release: 1.2, .level: 0.2]),
        InstrumentPreset("Sub Bass", [.waveform: 0, .cutoff: 300, .resonance: 0.1, .filterAmount: 0.5, .filterDecay: 0.3,
                                      .attack: 0.003, .decay: 0.3, .sustain: 0.9, .release: 0.12, .level: 0.35]),
        InstrumentPreset("Square Lead", [.waveform: 2, .cutoff: 1_800, .resonance: 0.4, .filterAmount: 2, .filterDecay: 0.4,
                                         .attack: 0.005, .decay: 0.3, .sustain: 0.7, .release: 0.25, .level: 0.22]),
        InstrumentPreset("Soft Keys", [.waveform: 3, .cutoff: 2_500, .resonance: 0.2, .filterAmount: 1, .filterDecay: 0.6,
                                       .attack: 0.004, .decay: 0.8, .sustain: 0.3, .release: 0.5, .level: 0.3]),
    ]

    public static func named(_ name: String) -> InstrumentPreset? {
        all.first { $0.name == name }
    }
}

extension SynthParameter: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
}
