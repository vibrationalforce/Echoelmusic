import EchoelCore
import EchoelDSP
import Foundation

/// What a finished master is for: the loudness it is brought to and the spectral balance it is
/// compared with. The raw values are kept by the device between launches: never rename them.
public enum MasterTarget: String, CaseIterable, Sendable, Identifiable {
    case streaming, podcast, broadcast

    public var id: String { rawValue }

    /// The export choice with the same loudness, so the file can be brought exactly there.
    public var loudness: ExportLoudness {
        switch self {
        case .streaming: .minus14
        case .podcast: .minus16
        case .broadcast: .minus23
        }
    }

    /// The integrated loudness in LUFS.
    public var lufs: Double { loudness.target ?? -14 }

    /// The tilt this target is compared with, in dB per octave from 125 Hz to 8 kHz. A reference,
    /// not a rule: about the slope released music mixes show there, a little steeper for speech.
    public var referenceTilt: Double {
        switch self {
        case .streaming: -4.5
        case .podcast: -5
        case .broadcast: -4.5
        }
    }

    public var title: String {
        switch self {
        case .streaming: "Streaming −14 LUFS"
        case .podcast: "Podcast −16 LUFS"
        case .broadcast: "Broadcast −23 LUFS"
        }
    }
}

/// The tone characters of the earlier app's master chain (`AutoMixChain.Preset`), as offsets on
/// the suggested EQ: low shelf at 140 Hz, presence at 2.8 kHz, air shelf at 9 kHz. Their gains
/// are the earlier app's, unchanged. A new tone goes at the end; the raw values are kept by the
/// device between launches.
public enum MasterTone: String, CaseIterable, Sendable, Identifiable {
    case balanced, warm, bright, transparent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: "Balanced"
        case .warm: "Warm"
        case .bright: "Bright"
        case .transparent: "Transparent"
        }
    }

    /// The gains in dB: low shelf, presence, air.
    public var gains: (low: Double, presence: Double, air: Double) {
        switch self {
        case .balanced: (-1.5, 1.5, 2.5)
        case .warm: (1.5, 0.5, 1.5)
        case .bright: (-2.5, 3.0, 5.0)
        case .transparent: (0, 0, 0)
        }
    }
}

/// A master chain proposed from a measurement, every number with the reason it has. Nothing is
/// applied until `commands(for:)` goes through the door, as one undo step.
public struct MasterSuggestion: Equatable, Sendable {
    public struct Value: Equatable, Sendable {
        public let identifier: String
        public let title: String
        public let value: Float
        public let unit: EffectParameter.Unit
        public let reason: String
    }

    public struct Stage: Equatable, Sendable {
        public let effect: StandardEffect
        public let values: [Value]

        /// The insert's stored state: these values by identifier, the rest at their defaults.
        public var state: Data? {
            StandardEffectSettings.state(Dictionary(values.map { ($0.identifier, $0.value) }, uniquingKeysWith: { $1 }),
                                         for: effect)
        }
    }

    public let target: MasterTarget
    public let tone: MasterTone
    /// In chain order.
    public let stages: [Stage]
    /// The master fader in dB, when the mix is louder than the target and has to come down
    /// before the chain; nil to leave the fader where it is.
    public let masterVolume: Double?
    public let masterVolumeReason: String?
    /// What the analysis found and left alone, and what it cannot know.
    public let notes: [String]

    /// The commands that put this chain on the master in place of its current effects (and the
    /// fader, when it moves). `makeID` names each new insert.
    public func commands(for project: Project, makeID: () -> InsertID = { InsertID() }) -> [Command] {
        var commands: [Command] = project.masterInserts.map { .removeMasterInsert($0.id) }
        for stage in stages {
            let id = makeID()
            commands.append(.addMasterInsert(id: id, plugin: stage.effect.component, index: nil))
            commands.append(.setMasterInsertState(id, stage.state))
        }
        if let masterVolume { commands.append(.setVolume(.master, db: masterVolume)) }
        return commands
    }

    /// The undo step's name.
    public static let actionTitle = "Apply Master Suggestion"
}

/// Proposes a master chain — EQ, multiband compressor, mid/side where the image needs it, and a
/// limiter — from a measured mixdown. Pure arithmetic on the measurement: no model, nothing
/// learned, the same mix gives the same chain. Measure the mix WITHOUT the master's effects,
/// since the suggestion replaces them.
public enum MasterAssistant {
    /// The two shelves sit at the earlier app's corners; the tilt is turned between them.
    static let lowShelfHz: Float = 140
    static let presenceHz: Float = 2_800
    /// The earlier app's 1.5-octave presence band, as a Q.
    static let presenceQ: Float = 0.92
    static let airShelfHz: Float = 9_000
    /// Octaves between the two shelves.
    static var shelfSpan: Double { Foundation.log2(Double(airShelfHz / lowShelfHz)) }
    /// A tilt this close to the reference is left alone, in dB per octave.
    public static let tiltTolerance = 0.75
    /// The most a tilt correction moves one shelf, in dB.
    public static let maximumTiltShelf = 4.0
    /// A band compresses only what rises this far above its measured average level.
    public static let thresholdAboveAverage = 6.0
    /// Below this correlation under 150 Hz the low end is made mono.
    public static let lowCorrelationLimit = 0.5
    /// A mono sum quieter than this, in dB, narrows the image.
    public static let monoLossLimit = -3.0

    /// Nil when the mix is silent: there is nothing to measure a master from.
    public static func suggest(from mix: MixAnalysis, target: MasterTarget, tone: MasterTone = .balanced,
                               masterVolume current: Double = 0) -> MasterSuggestion? {
        guard !mix.isSilent else { return nil }
        var notes: [String] = []
        var stages = [equalizer(mix, target: target, tone: tone, notes: &notes), multiband(mix)]
        if let image = midSide(mix, notes: &notes) { stages.append(image) }
        let level = limiter(mix, target: target, current: current)
        stages.append(level.stage)
        notes.append("The limiter's gain is measured on the mix before the EQ and the compressor; export at "
                     + "\(target.loudness.title) to measure the result and bring it exactly there.")
        return MasterSuggestion(target: target, tone: tone, stages: stages, masterVolume: level.volume,
                                masterVolumeReason: level.volumeReason, notes: notes)
    }

    private static func value(_ effect: StandardEffect, _ identifier: String, _ number: Double, _ reason: String)
        -> MasterSuggestion.Value? {
        guard let parameter = EffectKernel.parameters(for: effect).first(where: { $0.identifier == identifier }) else {
            return nil
        }
        let clamped = Swift.min(Swift.max(Float(number), parameter.range.lowerBound), parameter.range.upperBound)
        return MasterSuggestion.Value(identifier: identifier, title: parameter.title, value: clamped,
                                      unit: parameter.unit, reason: reason)
    }

    static func halfDecibel(_ value: Double) -> Double { (value * 2).rounded() / 2 }

    private static func decibels(_ value: Double) -> String { String(format: "%.1f dB", value) }

    private static func equalizer(_ mix: MixAnalysis, target: MasterTarget, tone: MasterTone,
                                  notes: inout [String]) -> MasterSuggestion.Stage {
        var tiltShelf = 0.0
        var tiltReason: String
        if let tilt = mix.tilt {
            let error = target.referenceTilt - tilt
            let measured = String(format: "%.1f", tilt), reference = String(format: "%.1f", target.referenceTilt)
            if Swift.abs(error) <= tiltTolerance {
                tiltReason = "the tilt measured \(measured) dB/oct, on the \(reference) dB/oct reference"
            } else {
                tiltShelf = halfDecibel(Swift.min(Swift.max(error * shelfSpan / 2, -maximumTiltShelf), maximumTiltShelf))
                tiltReason = "the tilt measured \(measured) dB/oct against the \(reference) dB/oct reference"
            }
        } else {
            tiltReason = "too few bands sound to measure a tilt"
            notes.append("No tilt correction: fewer than three octaves between 125 Hz and 8 kHz sound.")
        }
        let gains = tone.gains
        let sub = mix.bandLevels.count > 1 ? mix.bandLevels[0] - mix.bandLevels[1] : 0
        let rumble = sub.isFinite && sub > 3
        let values: [MasterSuggestion.Value?] = [
            value(.equalizer, "highpass", rumble ? 40 : 30,
                  rumble ? "the 31.5 Hz octave is \(decibels(sub)) above the 63 Hz octave: rumble, not bass"
                         : "below hearing on most speakers; it frees headroom"),
            value(.equalizer, "lowFrequency", Double(lowShelfHz), "the earlier app's low-shelf corner"),
            value(.equalizer, "lowGain", -tiltShelf + gains.low,
                  "\(tiltReason); \(tone.title) adds \(decibels(gains.low))"),
            value(.equalizer, "highMidFrequency", Double(presenceHz), "presence, the earlier app's band"),
            value(.equalizer, "highMidGain", gains.presence, "\(tone.title)'s presence"),
            value(.equalizer, "highMidQ", Double(presenceQ), "1.5 octaves wide"),
            value(.equalizer, "highFrequency", Double(airShelfHz), "the earlier app's air-shelf corner"),
            value(.equalizer, "highGain", tiltShelf + gains.air,
                  "\(tiltReason); \(tone.title) adds \(decibels(gains.air))"),
        ]
        return MasterSuggestion.Stage(effect: .equalizer, values: values.compactMap { $0 })
    }

    private static func multiband(_ mix: MixAnalysis) -> MasterSuggestion.Stage {
        // The default crossovers, 200 Hz and 2.5 kHz, between the octaves they part.
        let bands: [(name: String, range: ClosedRange<Int>, ratio: Double)] = [
            ("low", 0...2, 2), ("mid", 3...6, 1.5), ("high", 7...9, 1.5),
        ]
        var values: [MasterSuggestion.Value?] = []
        for band in bands {
            let level = mix.level(ofBands: band.range)
            if level.isFinite {
                let threshold = halfDecibel(level + thresholdAboveAverage)
                values.append(value(.multibandCompressor, "\(band.name)Threshold", threshold,
                                    "the \(band.name) band averages \(decibels(level)); "
                                    + "\(decibels(thresholdAboveAverage)) above catches its peaks only"))
                values.append(value(.multibandCompressor, "\(band.name)Ratio", band.ratio,
                                    "gentle, to hold the band together"))
            } else {
                values.append(value(.multibandCompressor, "\(band.name)Threshold", 0,
                                    "nothing sounds in the \(band.name) band"))
                values.append(value(.multibandCompressor, "\(band.name)Ratio", 1, "nothing to compress"))
            }
        }
        return MasterSuggestion.Stage(effect: .multibandCompressor, values: values.compactMap { $0 })
    }

    private static func midSide(_ mix: MixAnalysis, notes: inout [String]) -> MasterSuggestion.Stage? {
        var values: [MasterSuggestion.Value?] = []
        if let low = mix.lowCorrelation, low < lowCorrelationLimit {
            values.append(value(.midSide, "monoBelow", 120,
                                String(format: "below 150 Hz the channels correlate at %.2f; a phone or one speaker loses that bass", low)))
        }
        if let loss = mix.monoLoss, loss < monoLossLimit {
            values.append(value(.midSide, "width", 0.8, "summed to mono the mix plays \(decibels(-loss)) quieter"))
        }
        guard !values.isEmpty else {
            let correlation = mix.correlation.map { String(format: "%.2f", $0) } ?? "—"
            notes.append("Stereo image left alone: correlation \(correlation), and it holds up in mono.")
            return nil
        }
        return MasterSuggestion.Stage(effect: .midSide, values: values.compactMap { $0 })
    }

    private static func limiter(_ mix: MixAnalysis, target: MasterTarget, current: Double)
        -> (stage: MasterSuggestion.Stage, volume: Double?, volumeReason: String?) {
        let delta = target.lufs - mix.integratedLoudness
        let measured = String(format: "%.1f LUFS", mix.integratedLoudness)
        var gain = 0.0
        var volume: Double?
        var volumeReason: String?
        let gainReason: String
        if delta >= 0 {
            gain = halfDecibel(Swift.min(delta, 24))
            gainReason = "the mix measured \(measured); the target is \(target.loudness.title)"
        } else {
            let fader = halfDecibel(Swift.max(current + delta, MixerStrip.volumeRange.lowerBound))
            volume = fader
            volumeReason = "the mix measured \(measured), \(decibels(-delta)) above \(target.loudness.title): "
                + "the fader lowers it before the chain"
            gainReason = "the mix is louder than the target; the master fader comes down instead"
        }
        let ceiling = ExportLoudness.truePeakCeiling
        let values: [MasterSuggestion.Value?] = [
            value(.limiter, "gain", gain, gainReason),
            value(.limiter, "ceiling", ceiling,
                  String(format: "every target keeps the true peak at or under %.0f dBTP; the mix peaked at %.1f dBTP",
                         ceiling, mix.truePeak)),
        ]
        return (MasterSuggestion.Stage(effect: .limiter, values: values.compactMap { $0 }), volume, volumeReason)
    }
}
