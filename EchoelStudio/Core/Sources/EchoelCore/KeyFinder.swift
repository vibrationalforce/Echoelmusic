import Foundation

/// Which key a clip's notes sound in, offered to the musician and never set by itself (TH-9). How
/// long each pitch class sounds in the clip is correlated (Pearson) with Krumhansl and Kessler's
/// major and minor profiles turned to all twelve roots, and the key that fits best wins: the
/// Krumhansl–Schmuckler method, the key half of the earlier app's `TuningDetector` (the
/// concert-pitch half there reads audio and has no place in a clip of notes).
///
/// A finding names the runner-up and the lead between the two, because the method's ordinary
/// failure is a near tie: relative keys (C major, A minor) share every note, and parallel keys (C
/// major, C minor) share the tonic, which both profiles weigh most. A lead below `marginFloor`
/// makes a finding ambiguous, a fit below `correlationFloor` weak, and either one unsure. A finding
/// that is neither is still no proof of a key (`Finding.isUnsure` has the measurement).
///
/// It sets nothing. `Finding.commands` are the commands that would set the song's key root and
/// scale, for the musician to accept through the one door as one undo step; the frame stays theirs
/// (`MusicalContext`). Only major and minor keys are found, the two the profiles were measured for,
/// and a minor key is proposed as the song's Minor scale (natural minor); a Dorian clip is found as
/// the major or minor key its durations fit best.
///
/// Deterministic: durations are whole ticks summed exactly, the correlation needs only arithmetic
/// and square roots, which IEEE 754 rounds exactly, so no maths library decides anything; and keys
/// that fit exactly alike keep a fixed order, by root from C and major before minor.
public enum KeyFinder {
    /// A major or minor key.
    public struct Key: Hashable, Sendable {
        /// The tonic as a pitch class, 0 = C … 11 = B.
        public let root: Int
        /// `.major` or `.minor`.
        public let scale: Scale

        public init(root: Int, scale: Scale) {
            self.root = root
            self.scale = scale
        }

        /// "A Minor", as the song's frame reads it (`MusicalContext.title`).
        public var title: String { MusicalContext(root: root, scale: scale).title }
    }

    /// A key and how well the clip fits it: the Pearson correlation of the clip's durations with
    /// the key's profile, from −1 to 1.
    public struct Fit: Equatable, Sendable {
        public let key: Key
        public let correlation: Double
    }

    /// The key that fits best and the one after it, with the best one as a proposal.
    public struct Finding: Equatable, Sendable {
        public let best: Fit
        public let runnerUp: Fit

        /// How far the best key leads the runner-up; zero when two keys fit exactly alike.
        public var margin: Double { best.correlation - runnerUp.correlation }
        /// The runner-up fits almost as well, so naming either key would be a guess.
        public var isAmbiguous: Bool { margin < KeyFinder.marginFloor }
        /// Even the best key fits poorly: the notes have little tonal centre.
        public var isWeak: Bool { best.correlation < KeyFinder.correlationFloor }
        /// Ambiguous or weak: a key to offer as a guess, if at all. The reverse is no evidence of a
        /// key. What the two floors achieve was measured in the earlier app (`AudioKeyAnalysis.swift`,
        /// under `keyMarginFloor`) and holds here: of N notes drawn uniformly from the twelve pitch
        /// classes, which have no key, about half still come out neither ambiguous nor weak — 54 % at
        /// 8 notes and 48 % at 64, in 40 000 draws each on 2026-11-27, and `KeyFinderTests` draws them
        /// again. The floors catch flat and degenerate material; they are no test of whether notes
        /// have a key.
        public var isUnsure: Bool { isAmbiguous || isWeak }

        /// The commands that would set the song to the best key, root first. Nothing here performs
        /// them; the musician's accept does, through `ProjectStore.perform` as one undo step. A song
        /// already in that key takes no step, because `perform` drops a batch that changes nothing.
        public var commands: [Command] { [.setKeyRoot(best.key.root), .setScale(best.key.scale)] }
    }

    /// The lead below which a finding is ambiguous. A judgement, not a measurement: the earlier
    /// app's `AudioKeyAnalysis.keyMarginFloor`, set for keys heard in audio and kept for notes. What
    /// the two floors achieve is measured under `Finding.isUnsure`; whether they suit a clip's notes
    /// is the founder's verdict, still open here as in the earlier app.
    public static let marginFloor = 0.05
    /// The fit below which a finding is weak. A judgement too, open like `marginFloor`: the earlier
    /// app's `AudioKeyAnalysis.keyConfidenceFloor`.
    public static let correlationFloor = 0.5

    /// The key the clip's sounding notes fit best, with the runner-up. Nil when nothing sounds, and
    /// when every pitch class sounds equally long, which every key fits alike.
    public static func find(in clip: Clip) -> Finding? {
        find(weights: weights(of: clip))
    }

    /// The key that twelve durations, C first, fit best. Nil unless there are twelve, none is
    /// negative and they are not all equal. Several clips' `weights(of:)` may be summed first.
    public static func find(weights durations: [Tick]) -> Finding? {
        guard durations.count == 12, durations.allSatisfy({ $0 >= 0 }) else { return nil }
        let total = durations.reduce(Tick(0)) { (sum: Tick, duration: Tick) -> Tick in saturating(sum, duration) }
        guard total > 0 else { return nil }
        // The ticks sum exactly, so the mean does not depend on which pitch class holds which
        // duration, and the squares are summed smallest first for the same reason: a transposed
        // clip fits its transposed key to the last bit, and keys that tie stay tied.
        let mean = Double(total) / 12
        let centred = durations.map { (duration: Tick) -> Double in Double(duration) - mean }
        let norm = centred.map { (value: Double) -> Double in value * value }.sorted().reduce(0, +).squareRoot()
        guard norm > 0 else { return nil }

        var best: Fit?
        var runnerUp: Fit?
        for key in keys {
            let profile = key.scale == .minor ? minorProfile : majorProfile
            var sum = 0.0
            for degree in 0..<12 {
                sum += centred[(key.root + degree) % 12] * profile.centred[degree]
            }
            let fit = Fit(key: key, correlation: sum / (norm * profile.norm))
            // Only a strictly better fit moves ahead, so of keys that fit alike the one earlier in
            // `keys` stays in front.
            if best.map({ fit.correlation > $0.correlation }) ?? true {
                runnerUp = best
                best = fit
            } else if runnerUp.map({ fit.correlation > $0.correlation }) ?? true {
                runnerUp = fit
            }
        }
        guard let best, let runnerUp else { return nil }
        return Finding(best: best, runnerUp: runnerUp)
    }

    /// How long each pitch class sounds when the clip plays, in ticks, C first. As `PlaybackPlan`
    /// plays a clip: a note from its start to the clip's end at the latest and not at all from the
    /// end on, two notes of one pitch never at once. A note the door would refuse (a pitch outside
    /// 0…127, a start before the clip, no length) sounds nothing.
    public static func weights(of clip: Clip) -> [Tick] {
        let heard = clip.notes.compactMap { (note: Note) -> PlaybackPlan.Interval? in
            guard Note.pitchRange.contains(note.pitch), note.start >= 0, note.start < clip.length, note.length > 0 else {
                return nil
            }
            let end = note.start + Swift.min(note.length, clip.length - note.start)
            return PlaybackPlan.Interval(start: note.start, end: end, pitch: note.pitch, velocity: note.velocity)
        }
        var sounding = [Tick](repeating: 0, count: 12)
        for interval in PlaybackPlan.resolvingOverlaps(heard) {
            let pitchClass = ChordSuggest.pitchClass(interval.pitch)
            sounding[pitchClass] = saturating(sounding[pitchClass], interval.end - interval.start)
        }
        return sounding
    }

    // MARK: The profiles

    /// Krumhansl and Kessler's probe-tone ratings, the tonic first: how well each of the twelve
    /// tones was heard to fit after a major or a minor key had been set up (C. L. Krumhansl and
    /// E. J. Kessler, "Tracing the dynamic changes in perceived tonal organization in a spatial
    /// representation of musical keys", Psychological Review 89 (4), 1982, pp. 334–368; their use
    /// for finding a key: C. L. Krumhansl, Cognitive Foundations of Musical Pitch, Oxford University
    /// Press, 1990). The earlier app's `TuningDetector` holds the same numbers.
    static let majorRatings: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorRatings: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// A profile with its mean taken out, and the length of what is left: the half of every
    /// correlation that never changes, worked out once.
    struct Profile: Sendable {
        let centred: [Double]
        let norm: Double

        init(_ ratings: [Double]) {
            let mean = ratings.reduce(0, +) / Double(ratings.count)
            centred = ratings.map { (rating: Double) -> Double in rating - mean }
            norm = centred.reduce(0) { (sum: Double, value: Double) -> Double in sum + value * value }.squareRoot()
        }
    }

    static let majorProfile = Profile(majorRatings)
    static let minorProfile = Profile(minorRatings)

    /// Every key, in the order that decides a tie: by root from C, major before minor.
    static let keys: [Key] = (0..<12).flatMap { (root: Int) -> [Key] in
        [Key(root: root, scale: .major), Key(root: root, scale: .minor)]
    }

    /// `a + b`, or `Tick.max` where that does not fit: a clip no song can hold must not trap here.
    private static func saturating(_ a: Tick, _ b: Tick) -> Tick {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? .max : sum
    }
}

// MARK: - A whole song

extension KeyFinder {
    /// The tracks the finder reads in `project`: those played on keys that hold at least one clip
    /// with a note. A drum kit's and a sliced sampler's notes pick a sound, not a pitch
    /// (`PlaySurface`), so their tracks are left out.
    public static func tracks(in project: Project) -> [Track] {
        project.tracks.filter { (track: Track) -> Bool in
            PlaySurface.surface(for: track.instrument) == .keys && track.clips.contains { !$0.notes.isEmpty }
        }
    }

    /// How long each pitch class sounds in the clips of the tracks the finder reads, C first: every
    /// such track of `project`, or `track` alone. Each clip counts once, however often the
    /// arrangement or the session plays it, so a loop placed sixteen times weighs no more than a
    /// melody placed once.
    public static func weights(of project: Project, track: TrackID? = nil) -> [Tick] {
        var sounding = [Tick](repeating: 0, count: 12)
        for candidate in tracks(in: project) where track == nil || candidate.id == track {
            for clip in candidate.clips {
                for (pitchClass, duration) in weights(of: clip).enumerated() {
                    sounding[pitchClass] = saturating(sounding[pitchClass], duration)
                }
            }
        }
        return sounding
    }

    /// The key the song's notes fit best, with the runner-up: of every track played on keys, or of
    /// `track` alone. Nil when nothing sounds there. A proposal, as `find(in:)` is.
    public static func find(in project: Project, track: TrackID? = nil) -> Finding? {
        find(weights: weights(of: project, track: track))
    }
}
