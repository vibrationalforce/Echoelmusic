import Foundation

/// A mood (W12, the Instrument page's Mood): a few of the synth's own values mixed under one name
/// — the colour a sound is played in. It sets the filter and the engine's character, never the
/// envelope, the waveform or the engine itself, so a pluck stays a pluck and a pad a pad; and its
/// values are the synth's, so it adds no processing. On the Body voice the body moves two of them
/// further (`BodyVoice.routes`): the mood is where they rest.
public struct InstrumentMood: Sendable, Equatable, Identifiable {
    public let name: String
    public let values: [SynthParameter: Double]

    public var id: String { name }

    init(_ name: String, _ values: [SynthParameter: Double]) {
        self.name = name
        self.values = values
    }

    public static let all: [InstrumentMood] = [
        InstrumentMood("Warm", [.cutoff: 700, .resonance: 0.2, .character: 0.35, .filter: 1]),
        InstrumentMood("Clear", [.cutoff: 2_400, .resonance: 0.15, .character: 0.6, .filter: 0]),
        InstrumentMood("Dark", [.cutoff: 320, .resonance: 0.3, .character: 0.15, .filter: 1]),
        InstrumentMood("Bright", [.cutoff: 6_000, .resonance: 0.3, .character: 0.85, .filter: 0]),
    ]

    /// The mood a track's sound is in: the one whose every value the track holds. Nil while the
    /// values are the preset's own, or moved by hand since.
    public static func current(of settings: InstrumentSettings) -> InstrumentMood? {
        all.first { mood in mood.values.allSatisfy { entry in settings.value(entry.key) == entry.value } }
    }

    /// The commands that put `track` in this mood: one value each, always in the same order.
    public func commands(for track: TrackID) -> [Command] {
        var steps: [Command] = []
        for parameter in SynthParameter.all {
            guard let value = values[parameter] else { continue }
            steps.append(.setInstrumentParameter(track, key: parameter.key.rawValue, value: value))
        }
        return steps
    }
}

/// The sound a track plays (W12, the Instrument page's Sound): one of the synth's presets on one of
/// its engines. Choosing a preset keeps the engine and the mood the track is in, so the two picks
/// stay apart; choosing an engine keeps everything else. A preset made for one engine — the
/// choir's, which name their vowel in `character` (VOX) — brings that engine and its own colour
/// instead: kept, the mood would rewrite the vowel the preset is named for.
public enum InstrumentSound {
    /// Loads `preset` on `track` and keeps its engine and its mood, unless the preset names its own
    /// engine.
    public static func choosing(preset: String, on track: Track) -> [Command] {
        var steps: [Command] = [.loadInstrumentPreset(track.id, name: preset)]
        if InstrumentPreset.named(preset)?.values[SynthParameter.engine.key.rawValue] != nil { return steps }
        let engine = track.instrument.value(.engine)
        steps.append(.setInstrumentParameter(track.id, key: SynthParameter.engine.key.rawValue, value: engine))
        if let mood = InstrumentMood.current(of: track.instrument) {
            steps += mood.commands(for: track.id)
        }
        return steps
    }

    /// Sets the engine of `track`, by its index among `SynthParameter.engine.choices`.
    public static func choosing(engine index: Int, on track: TrackID) -> [Command] {
        [.setInstrumentParameter(track, key: SynthParameter.engine.key.rawValue, value: Double(index))]
    }
}
