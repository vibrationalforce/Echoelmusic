import EchoelCore
import Foundation

/// A vocal chain to start from: a few of Echoel's standard effects in a fixed order, each with
/// its settings. Built only from effects every user has — low cut, de-esser, compressor, a gentle
/// air shelf, a short room — so a chain always loads, with no Audio Unit to find.
///
/// The template itself is written nowhere: applying it puts ordinary inserts on the track, each
/// with its values by identifier (`StandardEffectSettings`), exactly as if they had been added
/// and set by hand. A song stores those inserts, never the template's name — so a template can
/// be renamed or retuned without touching any saved song.
public enum VocalChain: CaseIterable, Sendable, Identifiable {
    case clean, present, warm, spoken

    public var id: Self { self }

    public var title: String {
        switch self {
        case .clean: "Clean"
        case .present: "Present"
        case .warm: "Warm"
        case .spoken: "Spoken"
        }
    }

    /// One line on what the chain does, for the menu.
    public var summary: String {
        switch self {
        case .clean: "Low cut, gentle compression, a little air and a small room."
        case .present: "Firmer compression and more presence, to sit in front of a busy mix."
        case .warm: "Softer top, slower compression and a slightly longer room."
        case .spoken: "Speech: mud cut, steady level, no reverb."
        }
    }

    /// One effect of the chain and its settings by parameter identifier; every identifier not
    /// named stays at the effect's default.
    public struct Stage: Equatable, Sendable {
        public struct Setting: Equatable, Sendable {
            public let identifier: String
            public let value: Float
        }

        public let effect: StandardEffect
        public let settings: [Setting]

        init(_ effect: StandardEffect, _ settings: [(String, Float)]) {
            self.effect = effect
            self.settings = settings.map { Setting(identifier: $0.0, value: $0.1) }
        }

        /// The insert's stored state: these values by identifier, the rest at their defaults.
        public var state: Data? {
            StandardEffectSettings.state(Dictionary(settings.map { ($0.identifier, $0.value) }, uniquingKeysWith: { $1 }),
                                         for: effect)
        }
    }

    /// In chain order: low cut first, so the compressor never works on rumble; the de-esser before
    /// the compressor, so an "s" does not pull the whole voice down; the air shelf after both, and
    /// the room last.
    public var stages: [Stage] {
        switch self {
        case .clean:
            [Stage(.equalizer, [("highpass", 80)]),
             Stage(.deEsser, [("frequency", 6_500), ("threshold", -30), ("range", 6)]),
             Stage(.compressor, [("threshold", -18), ("ratio", 2.5), ("attack", 0.015), ("release", 0.15),
                                 ("knee", 6), ("makeup", 2)]),
             Stage(.equalizer, [("highFrequency", 10_000), ("highGain", 1.5)]),
             Stage(.reverb, [("size", 0.3), ("decay", 0.8), ("predelay", 0.015), ("damping", 7_000), ("mix", 0.08)])]
        case .present:
            [Stage(.equalizer, [("highpass", 100)]),
             Stage(.deEsser, [("frequency", 7_000), ("threshold", -32), ("range", 8)]),
             Stage(.compressor, [("threshold", -22), ("ratio", 4), ("attack", 0.005), ("release", 0.1),
                                 ("knee", 6), ("makeup", 4)]),
             Stage(.equalizer, [("highMidFrequency", 3_000), ("highMidGain", 2), ("highMidQ", 0.9),
                                ("highFrequency", 10_000), ("highGain", 3)]),
             Stage(.reverb, [("size", 0.35), ("decay", 1.0), ("predelay", 0.02), ("damping", 8_000), ("mix", 0.1)])]
        case .warm:
            [Stage(.equalizer, [("highpass", 70), ("lowFrequency", 200), ("lowGain", 1.5)]),
             Stage(.deEsser, [("frequency", 6_000), ("threshold", -28), ("range", 5)]),
             Stage(.compressor, [("threshold", -20), ("ratio", 3), ("attack", 0.02), ("release", 0.2),
                                 ("knee", 9), ("makeup", 3)]),
             Stage(.equalizer, [("highMidFrequency", 3_000), ("highMidGain", -1), ("highFrequency", 12_000),
                                ("highGain", 1)]),
             Stage(.reverb, [("size", 0.45), ("decay", 1.4), ("predelay", 0.025), ("damping", 5_000), ("mix", 0.14)])]
        case .spoken:
            [Stage(.equalizer, [("highpass", 90), ("lowMidFrequency", 300), ("lowMidGain", -2), ("lowMidQ", 1)]),
             Stage(.deEsser, [("frequency", 6_500), ("threshold", -30), ("range", 6)]),
             Stage(.compressor, [("threshold", -24), ("ratio", 3.5), ("attack", 0.01), ("release", 0.18),
                                 ("knee", 6), ("makeup", 5)]),
             Stage(.equalizer, [("highFrequency", 9_000), ("highGain", 1.5)])]
        }
    }

    /// The commands that put this chain on `track` IN PLACE of its current effects. Replace, not
    /// append: a template is a starting point for the whole chain, and appending onto an existing
    /// one would double the compressor and could run past `Insert.maximumPerTrack`. Perform them
    /// as one step (`ProjectStore.perform(_:title:)` with `actionTitle`), so one undo brings the
    /// old chain back. Inserts kept from a newer build are not touched and keep their places; if
    /// they leave too few, the door refuses the whole step and nothing changes. `makeID` names
    /// each new insert.
    public func commands(for track: Track, makeID: () -> InsertID = { InsertID() }) -> [Command] {
        var commands: [Command] = track.inserts.map { .removeInsert(track: track.id, $0.id) }
        for stage in stages {
            let id = makeID()
            commands.append(.addInsert(track: track.id, id: id, plugin: stage.effect.component, index: nil))
            commands.append(.setInsertState(track: track.id, id, stage.state))
        }
        return commands
    }

    /// The undo step's name.
    public static let actionTitle = "Apply Vocal Chain"
}
