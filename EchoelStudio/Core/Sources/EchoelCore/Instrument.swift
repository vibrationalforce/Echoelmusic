import Foundation

/// The sound of an instrument track: the preset it started from and every synth parameter
/// the musician has set. Values are stored by parameter key, so a future build that adds a
/// parameter reads an older song with that parameter at its default.
public struct InstrumentSettings: Codable, Equatable, Sendable {
    /// Which built-in instrument plays the track. Synth parameters stay stored when the
    /// device changes, so switching back restores the sound.
    public var device: InstrumentDevice {
        didSet { if device != .unrecognized { unrecognizedDevice = nil } }
    }
    /// The stored name of an instrument this build does not know (`device == .unrecognized`),
    /// written back unchanged so a later build still finds its instrument.
    public private(set) var unrecognizedDevice: String?
    /// The sample the sampler device plays; nil until one is chosen.
    public var sample: MediaID?
    public var preset: String
    public var values: [String: Double]
    /// The Audio Unit the plugin device plays, kept when the track switches to a built-in
    /// instrument so switching back restores it.
    public var plugin: PluginComponent?
    /// The plugin's own saved settings, as it reported them; applied when it loads.
    public var pluginState: Data?

    public init(device: InstrumentDevice = .synth, sample: MediaID? = nil, preset: String = InstrumentPreset.initial.name,
                values: [String: Double] = [:], plugin: PluginComponent? = nil, pluginState: Data? = nil) {
        self.device = device
        self.sample = sample
        self.preset = preset
        self.values = values
        self.plugin = plugin
        self.pluginState = pluginState
    }

    private enum CodingKeys: String, CodingKey { case device, sample, preset, values, plugin, pluginState }

    /// Songs written before devices existed are synth tracks. A device from a later build opens
    /// as `.unrecognized`: the track plays nothing here and keeps its instrument for that build,
    /// instead of the whole song being refused.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decodeIfPresent(String.self, forKey: .device) ?? InstrumentDevice.synth.rawValue
        if let known = InstrumentDevice(rawValue: name), known != .unrecognized {
            device = known
        } else {
            device = .unrecognized
            unrecognizedDevice = name
        }
        sample = try c.decodeIfPresent(MediaID.self, forKey: .sample)
        preset = try c.decode(String.self, forKey: .preset)
        values = try c.decode([String: Double].self, forKey: .values)
        plugin = try c.decodeIfPresent(PluginComponent.self, forKey: .plugin)
        pluginState = try c.decodeIfPresent(Data.self, forKey: .pluginState)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(unrecognizedDevice ?? device.rawValue, forKey: .device)
        try c.encodeIfPresent(sample, forKey: .sample)
        try c.encode(preset, forKey: .preset)
        try c.encode(values, forKey: .values)
        try c.encodeIfPresent(plugin, forKey: .plugin)
        try c.encodeIfPresent(pluginState, forKey: .pluginState)
    }

    public func value(_ parameter: SynthParameter) -> Double {
        values[parameter.key.rawValue] ?? parameter.defaultValue
    }

    /// Whether the synth sounds other than its preset: a value moved since the preset loaded.
    /// Compared as the synth plays them, so a value turned back to the preset's own reads as the
    /// preset again, and a synth value only a later build knows changes nothing here. False for
    /// a preset this build does not know: there is nothing to compare with.
    public var isEditedFromPreset: Bool {
        guard let loaded = InstrumentPreset.named(preset) else { return false }
        let preset = InstrumentSettings(values: loaded.values)
        return SynthParameter.all.contains { value($0) != preset.value($0) }
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
    /// A third-party Audio Unit instrument (`InstrumentSettings.plugin`).
    case plugin
    /// An instrument from a later build, kept by name (`InstrumentSettings.unrecognizedDevice`)
    /// and silent here. Never chosen, only read from a file.
    case unrecognized

    public var title: String {
        switch self {
        case .synth: "Synth"
        case .drums: "Drums"
        case .sampler: "Sampler"
        case .plugin: "Plugin"
        case .unrecognized: "Unknown"
        }
    }

    /// The instruments the app plays itself; `plugin` is chosen through `instrument.plugin`.
    public static let builtIn: [InstrumentDevice] = [.synth, .drums, .sampler]
    /// What a track can be set to.
    public static let choosable: [InstrumentDevice] = builtIn + [.plugin]
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

    /// The synth's parameters as a closed list, in display order. Every row of `all` is one case,
    /// so a new synth parameter is a new case — and the engine's mapping to sound (`PatchField`
    /// in EchoelKernels, an exhaustive `switch` over these cases) does not compile until it is
    /// mapped. The case names are part of the code, not of the file: songs store the keys.
    public enum Name: Sendable, CaseIterable {
        case waveform, cutoff, resonance, filterAmount, filterDecay, attack, decay, sustain, release, level

        /// The row this case stands for. Builds a value: read it off the render thread.
        public var parameter: SynthParameter {
            switch self {
            case .waveform: SynthParameter("synth.waveform", "Waveform", .choice, 0...3, 1, .stepped,
                                           choices: ["Sine", "Saw", "Square", "Triangle"])
            case .cutoff: SynthParameter("synth.cutoff", "Cutoff", .hertz, 20...18_000, 800, .exponential)
            case .resonance: SynthParameter("synth.resonance", "Resonance", .amount, 0...0.95, 0.3, .linear)
            case .filterAmount: SynthParameter("synth.filterAmount", "Filter Envelope", .octaves, 0...8, 3, .linear)
            case .filterDecay: SynthParameter("synth.filterDecay", "Filter Decay", .seconds, 0.001...10, 0.3, .exponential)
            case .attack: SynthParameter("synth.attack", "Attack", .seconds, 0.001...10, 0.003, .exponential)
            case .decay: SynthParameter("synth.decay", "Decay", .seconds, 0.001...10, 0.2, .exponential)
            case .sustain: SynthParameter("synth.sustain", "Sustain", .amount, 0...1, 0.7, .linear)
            case .release: SynthParameter("synth.release", "Release", .seconds, 0.001...10, 0.25, .exponential)
            case .level: SynthParameter("synth.level", "Level", .amount, 0...1, 0.25, .linear)
            }
        }

        /// The case whose row is stored under `key`; nil for a key the synth does not have.
        public init?(_ key: ParameterKey) {
            guard let name = Self.allCases.first(where: { $0.parameter.key == key }) else { return nil }
            self = name
        }
    }

    public static let waveform = Name.waveform.parameter
    public static let cutoff = Name.cutoff.parameter
    public static let resonance = Name.resonance.parameter
    public static let filterAmount = Name.filterAmount.parameter
    public static let filterDecay = Name.filterDecay.parameter
    public static let attack = Name.attack.parameter
    public static let decay = Name.decay.parameter
    public static let sustain = Name.sustain.parameter
    public static let release = Name.release.parameter
    public static let level = Name.level.parameter

    /// In display order: one row per `Name`.
    public static let all: [SynthParameter] = Name.allCases.map(\.parameter)

    /// The synth's row for `key`. Only the synth's: the ones a lane plays and `Project.parameters`
    /// lists. What a command may write and a song stores is `builtIn`.
    public static func named(_ key: ParameterKey) -> SynthParameter? {
        all.first { $0.key == key }
    }

    /// A built-in instrument's row for `key` — the synth's, the drums' or the sampler's: the
    /// values an instrument's `values` stores and `instrument.parameter` writes.
    public static func builtIn(_ key: ParameterKey) -> InstrumentParameter? {
        named(key) ?? InstrumentDevice.builtIn.flatMap(\.parameters).first { $0.key == key }
    }

    // The drums' and the sampler's rows, in the order their plugins publish them. Read through
    // `InstrumentDevice.parameters`. A song stores their values under these keys, so the names,
    // the order and the sampler mode's choices are frozen (Law 3, `StoredNamesTests`); a lane
    // does not play them yet, so `Project.parameters` does not list them.
    public static let drumsLevel = SynthParameter("drums.level", "Level", .amount, 0...1, 0.8, .linear)
    public static let samplerRoot = SynthParameter("sampler.root", "Root key", .amount, 0...127, 60, .stepped)
    public static let samplerAttack = SynthParameter("sampler.attack", "Attack", .seconds, 0.001...2, 0.001, .exponential)
    public static let samplerRelease = SynthParameter("sampler.release", "Release", .seconds, 0.01...5, 0.15, .exponential)
    public static let samplerLevel = SynthParameter("sampler.level", "Level", .amount, 0...1, 0.8, .linear)
    public static let samplerMode = SynthParameter("sampler.mode", "Mode", .choice, 0...1, 0, .stepped,
                                                   choices: ["Gate", "One-shot"])

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

/// One row of a built-in instrument's parameter table. The type began as the synth's and keeps
/// its name in the code that predates the other tables; new code says what it means.
public typealias InstrumentParameter = SynthParameter

extension InstrumentDevice {
    /// The device's parameter table in the order its plugin publishes it (the Audio Unit address is
    /// the index). Empty for a third-party plugin and an instrument from a later build. Builds an
    /// array: never read it on the render thread.
    public var parameters: [InstrumentParameter] {
        switch self {
        case .synth: SynthParameter.all
        case .drums: [.drumsLevel]
        case .sampler: [.samplerRoot, .samplerAttack, .samplerRelease, .samplerLevel, .samplerMode]
        case .plugin, .unrecognized: []
        }
    }
}

/// A starting sound. Loading one replaces every synth value of the track and keeps its other values.
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
