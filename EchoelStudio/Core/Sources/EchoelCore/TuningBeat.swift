import Foundation

/// How the song's tone system tunes its third, as the beat the ear hears: the third above the
/// key's tonic, as the system plays it, against the pure ratio nearest it. Two notes a pure 5 : 4
/// apart share a partial (the fifth of the lower is the fourth of the upper) and do not beat; a
/// tempered third puts those partials a few hertz apart, and they beat at the difference. The
/// Moiré look (`FieldPattern.moire`) shows it: pure stands still, tempered drifts. Pure.
///
/// - The interval is the major third (4 semitones) where the song's scale has one, else the minor
///   third (3); every scale has one of the two.
/// - Its size is what the system really plays there (`TuningSystem.centsDeviation`), so a system
///   that plays semitone 4 as 6/5 is judged as a 6/5.
/// - The pure ratio p/q is the nearest of 9/8, 6/5, 5/4 and 4/3; the beat is |q·f₂ − p·f₁| Hz,
///   f₁ the tonic in the octave of middle C at the song's concert pitch.
/// - The picture drifts at `maximumDriftHz` · tanh(beat / `maximumDriftHz`): a slow beat at its
///   own rate, a fast one ever closer to the ceiling, faster beats never slower — and never as
///   fast as `FieldPulse.maximumRateHz`, the house flash ceiling.
public struct TuningBeat: Equatable, Sendable {
    /// Semitones above the tonic: 4 or 3.
    public var semitones: Int
    /// The pure ratio p/q the interval is judged against.
    public var p: Int
    public var q: Int
    /// The tonic and the third as they sound, Hz.
    public var lowerHz: Double
    public var upperHz: Double
    /// The beat of the coinciding partials, Hz.
    public var beatHz: Double
    /// How fast the picture drifts, Hz (below `maximumDriftHz`).
    public var driftHz: Double

    /// The picture's drift ceiling, under the house flash ceiling with half a hertz to spare.
    public static let maximumDriftHz = 2.0
    /// The pure ratios an interval may be judged against.
    public static let ratios: [(p: Int, q: Int)] = [(9, 8), (6, 5), (5, 4), (4, 3)]

    /// Two equal notes: no beat, no drift.
    public static let unison = TuningBeat(semitones: 0, p: 1, q: 1, lowerHz: FieldFrame.middleC,
                                          upperHz: FieldFrame.middleC, beatHz: 0, driftHz: 0)

    public init(semitones: Int, p: Int, q: Int, lowerHz: Double, upperHz: Double, beatHz: Double, driftHz: Double) {
        self.semitones = semitones
        self.p = p
        self.q = q
        self.lowerHz = lowerHz
        self.upperHz = upperHz
        self.beatHz = beatHz
        self.driftHz = driftHz
    }

    /// The third of the song's key in its tone system.
    public static func of(_ context: MusicalContext) -> TuningBeat {
        let semitones = context.scale.intervals.contains(4) ? 4 : 3
        let system = TuningSystem.named(context.tuning)
        let cents = 100 * Double(semitones) + system.centsDeviation(forSemitone: semitones)
            - system.centsDeviation(forSemitone: 0)
        let lower = FieldFrame.tonicHz(of: context)
        let upper = lower * Foundation.pow(2, cents / 1200)
        var best = ratios[0]
        var bestDistance = Double.greatestFiniteMagnitude
        for ratio in ratios {
            let distance = Swift.abs(cents - 1200 * Foundation.log2(Double(ratio.p) / Double(ratio.q)))
            if distance < bestDistance {
                bestDistance = distance
                best = ratio
            }
        }
        let beat = Swift.abs(Double(best.q) * upper - Double(best.p) * lower)
        guard beat.isFinite, lower.isFinite, upper.isFinite else { return .unison }
        return TuningBeat(semitones: semitones, p: best.p, q: best.q, lowerHz: lower, upperHz: upper,
                          beatHz: beat, driftHz: drift(beatHz: beat))
    }

    /// The picture's drift for a beat: monotone, 0 at 0, below the ceiling.
    public static func drift(beatHz: Double) -> Double {
        guard beatHz.isFinite, beatHz > 0 else { return 0 }
        return maximumDriftHz * Foundation.tanh(beatHz / maximumDriftHz)
    }

    /// What VoiceOver says while the Moiré look shows.
    public var spoken: String {
        let name = semitones == 4 ? "major third" : semitones == 3 ? "minor third" : "unison"
        if beatHz < 0.05 { return "\(name) \(p) to \(q), pure, stands still" }
        return "\(name) \(p) to \(q), beats \(String(format: "%.1f", beatHz)) times a second"
    }
}
