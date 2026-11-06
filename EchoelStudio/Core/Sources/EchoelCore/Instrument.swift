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
    /// The file the synth's wavetable engine is cut from, and into how many cycles; nil plays the
    /// factory shapes. Optional, added inside format 4 (2026-11-04).
    public var wavetable: WavetableSource?
    /// The pads the sampler's file is cut into (the break slicer); nil plays it across the keys.
    /// Optional, added inside format 4 (2026-11-04); never stored empty.
    public var slices: [SampleSlice]?
    public var preset: String
    public var values: [String: Double]
    /// The Audio Unit the plugin device plays, kept when the track switches to a built-in
    /// instrument so switching back restores it.
    public var plugin: PluginComponent?
    /// The plugin's own saved settings, as it reported them; applied when it loads.
    public var pluginState: Data?

    public init(device: InstrumentDevice = .synth, sample: MediaID? = nil, preset: String = InstrumentPreset.initial.name,
                values: [String: Double] = [:], plugin: PluginComponent? = nil, pluginState: Data? = nil,
                wavetable: WavetableSource? = nil) {
        self.device = device
        self.sample = sample
        self.wavetable = wavetable
        self.preset = preset
        self.values = values
        self.plugin = plugin
        self.pluginState = pluginState
    }

    private enum CodingKeys: String, CodingKey { case device, sample, wavetable, preset, values, plugin, pluginState, slices }

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
        wavetable = try c.decodeIfPresent(WavetableSource.self, forKey: .wavetable)
        preset = try c.decode(String.self, forKey: .preset)
        values = try c.decode([String: Double].self, forKey: .values)
        plugin = try c.decodeIfPresent(PluginComponent.self, forKey: .plugin)
        pluginState = try c.decodeIfPresent(Data.self, forKey: .pluginState)
        slices = try c.decodeIfPresent([SampleSlice].self, forKey: .slices)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(unrecognizedDevice ?? device.rawValue, forKey: .device)
        try c.encodeIfPresent(sample, forKey: .sample)
        try c.encodeIfPresent(wavetable, forKey: .wavetable)
        try c.encode(preset, forKey: .preset)
        try c.encode(values, forKey: .values)
        try c.encodeIfPresent(plugin, forKey: .plugin)
        try c.encodeIfPresent(pluginState, forKey: .pluginState)
        if let slices, !slices.isEmpty { try c.encode(slices, forKey: .slices) }
    }

    /// The wavetable's file while the synth plays its wavetable engine: what is heard. Nil otherwise.
    public var heardWavetable: MediaID? {
        guard device == .synth, let wavetable,
              Int(value(.engine).rounded()) == WavetableSource.engineIndex else { return nil }
        return wavetable.media
    }

    /// The value the track plays: the stored one, or the row's song default.
    public func value(_ parameter: SynthParameter) -> Double {
        values[parameter.key.rawValue] ?? parameter.songDefault
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

/// Where the synth's wavetable engine takes its cycles from: an audio file of the song, cut into
/// `frames` single cycles spread across it. The frame count is stored, so a song's Position finds
/// the same cycle in every build. The cutting itself (pitch, zero crossings, band limits) is the
/// engine's, deterministic, and never stored.
public struct WavetableSource: Codable, Equatable, Hashable, Sendable {
    public var media: MediaID
    public var frames: Int

    /// The most cycles a table holds (`WavetableBank.maximumFrames` in EchoelDSP).
    public static let frameRange: ClosedRange<Int> = 2...64

    public init(media: MediaID, frames: Int) {
        self.media = media
        self.frames = frames
    }

    /// The cycles a file is cut into when it is chosen: one per 2048 frames of the file, at least 2
    /// and at most 64 — a short sound gives a short table, a long one sweeps through its whole length.
    public static func frames(for file: MediaFile) -> Int {
        Swift.min(Swift.max(file.frameCount / 2_048, frameRange.lowerBound), frameRange.upperBound)
    }

    /// The `synth.engine` index of the wavetable engine: the media is heard only while it plays.
    public static let engineIndex = 9
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
    /// Where the instrument's plugin starts (the Audio Unit publishes it).
    public let defaultValue: Double
    /// What a song's track plays while it stores no value, and what a double tap returns to. The
    /// plugin's default everywhere but the drums' level: the app always played the kit at unity
    /// while the plugin starts at 0.8, and a song that stores no level must sound as it did.
    public let songDefault: Double
    public let taper: ParameterTaper
    public let choices: [String]

    /// The synth's parameters as a closed list, in display order. Every row of `all` is one case,
    /// so a new synth parameter is a new case — and the engine's mapping to sound (`PatchField`
    /// in EchoelKernels, an exhaustive `switch` over these cases) does not compile until it is
    /// mapped. The case names are part of the code, not of the file: songs store the keys.
    public enum Name: Sendable, CaseIterable {
        // A new row goes at the end: a song stores the key, and the plugin its place.
        case waveform, cutoff, resonance, filterAmount, filterDecay, attack, decay, sustain, release, level, engine, character, filter
        case vibrato
        // Appended 2026-11-04 (EchoelTools A2): the bass-line glide and accent.
        case slide, accent
        // Appended 2026-11-04 (EchoelTools A10): the texture engine's automaton.
        case textureRule, textureDensity, textureRate, textureSeed
        // Appended 2026-11-06: the DDSP engine's spectral profile.
        case ddspProfile

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
            // The engine stores the index of its choice: a new engine goes at the end.
            case .engine: SynthParameter("synth.engine", "Engine", .choice, 0...10, 0, .stepped,
                                         choices: ["Classic", "Supersaw", "FM", "Sub", "Morph", "Mallet", "DDSP", "Choir",
                                                   "Pluck", "Wavetable", "Texture"])
            case .character: SynthParameter("synth.character", "Character", .amount, 0...1, 0.5, .linear)
            case .filter: SynthParameter("synth.filter", "Filter", .choice, 0...1, 0, .stepped, choices: ["Clean", "Ladder"])
            // The vibrato with the modulation wheel at rest (W12): what a route moves with the pulse.
            case .vibrato: SynthParameter("synth.vibrato", "Vibrato", .amount, 0...1, 0, .linear)
            // A key struck while another is held glides there on the same voice (0: off).
            case .slide: SynthParameter("synth.slide", "Slide", .seconds, 0...2, 0, .linear)
            // A note at velocity 100 or more opens the filter further and plays louder (0: off).
            case .accent: SynthParameter("synth.accent", "Accent", .amount, 0...1, 0, .linear)
            // The texture engine (A10). The rule stores the index of its choice, Wolfram's number
            // as its name: a new rule goes at the end.
            case .textureRule: SynthParameter("synth.textureRule", "Rule", .choice, 0...7, 0, .stepped,
                                              choices: ["90", "30", "110", "150", "184", "45", "73", "105"])
            // How many of the sixteen partials may sound: 0 the fundamental alone, 1 all.
            case .textureDensity: SynthParameter("synth.textureDensity", "Density", .amount, 0...1, 0.6, .linear)
            // Generations a second; 0 holds the row.
            case .textureRate: SynthParameter("synth.textureRate", "Evolve Rate", .hertz, 0...40, 8, .linear)
            // The row each note starts from: 0 a single middle cell, any other a row drawn from it.
            case .textureSeed: SynthParameter("synth.textureSeed", "Seed", .amount, 0...9_999, 0, .stepped)
            // The DDSP engine's spectrum. Index 0 is the one it always had, set by Character; the
            // others are fixed shapes, Character still setting the tone/breath blend. Stored by
            // index: a new profile goes at the end (the names are the display's, not the file's).
            case .ddspProfile: SynthParameter("synth.ddspProfile", "Profile", .choice, 0...9, 0, .stepped,
                                              choices: ["Character", "Metallic", "Hollow", "Bell", "Flat",
                                                        "Bowed", "Brass", "Low Bowed", "Reed", "Double Reed"])
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
    public static let engine = Name.engine.parameter
    public static let character = Name.character.parameter
    public static let filter = Name.filter.parameter
    public static let vibrato = Name.vibrato.parameter
    public static let slide = Name.slide.parameter
    public static let accent = Name.accent.parameter
    public static let textureRule = Name.textureRule.parameter
    public static let textureDensity = Name.textureDensity.parameter
    public static let textureRate = Name.textureRate.parameter
    public static let textureSeed = Name.textureSeed.parameter
    public static let ddspProfile = Name.ddspProfile.parameter
    /// The rows only the texture engine plays: the Sound page shows them while it is chosen.
    public static let textureRows: [SynthParameter] = [textureRule, textureDensity, textureRate, textureSeed]
    /// The `synth.engine` index of the texture engine.
    public static let textureEngineIndex = 10
    /// The `synth.engine` index of the DDSP engine, the only one that hears `ddspProfile`.
    public static let ddspEngineIndex = 6

    /// In display order: one row per `Name`.
    public static let all: [SynthParameter] = Name.allCases.map(\.parameter)

    /// The synth's row for `key`; nil for a drums or sampler key. A lane plays, and
    /// `Project.parameters` lists, the rows of the device a track plays
    /// (`InstrumentDevice.parameters`); what a command may write and a song stores is `builtIn`.
    public static func named(_ key: ParameterKey) -> SynthParameter? {
        all.first { $0.key == key }
    }

    /// A built-in instrument's row for `key` — the synth's, the drums' or the sampler's: the
    /// values an instrument's `values` stores and `instrument.parameter` writes.
    public static func builtIn(_ key: ParameterKey) -> InstrumentParameter? {
        named(key) ?? InstrumentDevice.builtIn.flatMap(\.parameters).first { $0.key == key }
    }

    // The drums' and the sampler's rows, in the order their plugins publish them. Read through
    // `InstrumentDevice.parameters`. A song stores their values and lanes under these keys, so
    // the names, the order and the sampler mode's choices are frozen (Law 3, `StoredNamesTests`).
    public static let drumsLevel = SynthParameter("drums.level", "Level", .amount, 0...1, 0.8, .linear, songDefault: 1)
    // The kit's sound beyond its level (EchoelTools A11, 2026-11-04), appended after it: how far
    // the kick's pitch falls, the hats' and the toms' models, then each piece's tune, decay and
    // level. Every default plays the kit exactly as it sounded before these rows existed.
    public static let drumsKickGlide = SynthParameter("drums.kickGlide", "Kick Glide", .amount, 0...4, 1, .linear)
    public static let drumsHatModel = SynthParameter("drums.hatModel", "Hats", .choice, 0...1, 0, .stepped,
                                                     choices: ["Noise", "Metal"])
    public static let drumsTomModel = SynthParameter("drums.tomModel", "Toms", .choice, 0...1, 0, .stepped,
                                                     choices: ["Sine", "Modal"])
    /// The kit's pieces as their rows name them, in the kit's order (kick … crash).
    public static let drumPieces: [(key: String, title: String)] = [
        ("kick", "Kick"), ("snare", "Snare"), ("clap", "Clap"), ("lowTom", "Low Tom"), ("highTom", "High Tom"),
        ("closedHat", "Closed Hat"), ("openHat", "Open Hat"), ("crash", "Crash"),
    ]
    /// Per piece: tune in semitones, decay as a factor on the piece's own length, level as a factor.
    public static let drumsPieceRows: [SynthParameter] = drumPieces.flatMap { piece in
        [SynthParameter("drums.\(piece.key).tune", "\(piece.title) Tune", .amount, -24...24, 0, .linear),
         SynthParameter("drums.\(piece.key).decay", "\(piece.title) Decay", .amount, 0.1...4, 1, .exponential),
         SynthParameter("drums.\(piece.key).level", "\(piece.title) Level", .amount, 0...1, 1, .linear)]
    }
    public static let samplerRoot = SynthParameter("sampler.root", "Root key", .amount, 0...127, 60, .stepped)
    public static let samplerAttack = SynthParameter("sampler.attack", "Attack", .seconds, 0.001...2, 0.001, .exponential)
    public static let samplerRelease = SynthParameter("sampler.release", "Release", .seconds, 0.01...5, 0.15, .exponential)
    public static let samplerLevel = SynthParameter("sampler.level", "Level", .amount, 0...1, 0.8, .linear)
    public static let samplerMode = SynthParameter("sampler.mode", "Mode", .choice, 0...1, 0, .stepped,
                                                   choices: ["Gate", "One-shot"])

    init(_ key: String, _ title: String, _ unit: ParameterUnit, _ range: ClosedRange<Double>, _ defaultValue: Double,
         _ taper: ParameterTaper, choices: [String] = [], songDefault: Double? = nil) {
        self.key = ParameterKey(rawValue: key)
        self.title = title
        self.unit = unit
        self.range = range
        self.defaultValue = defaultValue
        self.songDefault = songDefault ?? defaultValue
        self.taper = taper
        self.choices = choices
    }

    /// A row of a device the track does not play names that device and says so: its lane waits
    /// in the song, silent, and must not read like the playing device's row of the same title.
    func descriptor(track: Track) -> ParameterDescriptor {
        var name = "\(track.name) \(title)"
        if !track.instrument.device.parameters.contains(where: { $0.key == key }),
           let owner = InstrumentDevice.builtIn.first(where: { $0.parameters.contains { $0.key == key } }) {
            name = "\(track.name) \(owner.title) \(title) (not playing)"
        }
        return ParameterDescriptor(address: ParameterAddress(.track(track.id), key), title: name,
                                   unit: unit, range: range, defaultValue: songDefault, taper: taper, choices: choices)
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
        case .drums: [.drumsLevel, .drumsKickGlide, .drumsHatModel, .drumsTomModel] + SynthParameter.drumsPieceRows
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
        // The choir's (VOX): each names its engine and its vowel (character: 0 oo, 0.25 oh, 0.5 ah),
        // so it sounds as its name says on any page. Slow to swell and to fade, as a choir breathes;
        // the filter stays open above the formants, which shape the sound.
        InstrumentPreset("Choir Ah", [.engine: 7, .character: 0.5, .cutoff: 6_000, .resonance: 0.1, .filterAmount: 0,
                                      .filterDecay: 0.3, .attack: 0.25, .decay: 0.6, .sustain: 0.9, .release: 0.8,
                                      .level: 0.35]),
        InstrumentPreset("Choir Oo", [.engine: 7, .character: 0, .cutoff: 4_000, .resonance: 0.1, .filterAmount: 0,
                                      .filterDecay: 0.3, .attack: 0.35, .decay: 0.6, .sustain: 0.9, .release: 1,
                                      .level: 0.38]),
        InstrumentPreset("Low Chant", [.engine: 7, .character: 0.25, .cutoff: 2_200, .resonance: 0.1, .filterAmount: 0,
                                       .filterDecay: 0.3, .attack: 0.5, .decay: 0.8, .sustain: 0.95, .release: 1.4,
                                       .level: 0.4]),
        // The bass pair of EchoelTools A3. Reese: two saws beating against each other — the
        // supersaw held close — under the ladder, slowly opening. 808 Glide: a sine that falls away,
        // each overlapping note gliding into the next, accented notes punching through.
        InstrumentPreset("Reese Bass", [.engine: 1, .character: 0.18, .filter: 1, .cutoff: 420, .resonance: 0.25,
                                        .filterAmount: 1.2, .filterDecay: 0.6, .attack: 0.005, .decay: 0.4, .sustain: 0.9,
                                        .release: 0.2, .level: 0.3]),
        InstrumentPreset("808 Glide", [.engine: 3, .character: 0.15, .waveform: 0, .cutoff: 1_200, .resonance: 0.1,
                                       .filterAmount: 0.8, .filterDecay: 0.25, .attack: 0.002, .decay: 1.6, .sustain: 0.25,
                                       .release: 0.35, .level: 0.38, .slide: 0.12, .accent: 0.4]),
        // The texture engine's (A10): rule 90 growing from the middle cell, the harmonics opening
        // and closing a few times a second under a slow swell, the filter open above them.
        InstrumentPreset("Cell Texture", [.engine: 10, .character: 0.55, .textureRule: 0, .textureDensity: 0.8,
                                          .textureRate: 6, .textureSeed: 0, .cutoff: 9_000, .resonance: 0.1,
                                          .filterAmount: 0, .filterDecay: 0.3, .attack: 0.3, .decay: 0.6, .sustain: 0.9,
                                          .release: 1.2, .level: 0.35]),
    ]

    public static func named(_ name: String) -> InstrumentPreset? {
        all.first { $0.name == name }
    }
}

extension SynthParameter: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
}
