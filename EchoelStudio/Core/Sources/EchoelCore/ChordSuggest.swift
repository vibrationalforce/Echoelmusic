import Foundation

/// Which chord could come next, without a model (ECHOELTOOLS D5): the deterministic core of the
/// earlier app's `Sequencer/ChordSuggest.swift` (H2), ported without its subsystem — no seeded
/// journey, no coherence selector, no `VoiceLeader`. What it keeps is the ranking: a chord on every
/// degree of the song's scale plus a short list of borrowed chords, ordered by classical harmonic
/// function (tonic → subdominant → dominant → tonic, the cadence D → T free), with how far the
/// voices move as the tie-break inside a function.
///
/// The chords of a scale come from its pitch classes (TH-5, 2026-11-27): a vocabulary of named
/// chords — six triads and the sevenths on them (`Quality`) — of which a scale holds those whose
/// tones all lie in it (`vocabulary`). In a seven-note scale every other step is a third, so a
/// degree's chord is its third-stack, the scale's own third and fifth above it, wherever the
/// vocabulary names it: on every degree of the church modes and of harmonic and melodic minor, as
/// before. In a scale of another size every other step is no third (C major pentatonic stacks
/// C-E-A), so a degree takes the first triad of the vocabulary that the scale holds there; so does
/// a seven-note degree whose third-stack has no name. A degree on which none fits has no chord: C
/// major pentatonic has C, Dsus2, Gsus2 and Am, and nothing on E.
///
/// It writes nothing by itself. The note editor and the assistant offer the list; a chord lands
/// in a clip only when the musician picks one (`insert`), through the one door like every note.
/// A borrowed chord holds notes outside the scale and says so (`borrowed`, `outside`), it is
/// never quietly moved into it. A song without a key (chromatic) has no chords to suggest.
public enum ChordSuggest {
    /// The harmonic function family of a chord root.
    public enum Function: String, Sendable, Equatable {
        case tonic, subdominant, dominant
    }

    /// What kind of chord a chord is: its tones in semitones above the root, the root first. The six
    /// triads name the scale's own chords (`candidates`, the chord row); the sevenths add a seventh to
    /// five of them, for a caller that asks for them (`vocabulary`). Never stored.
    public enum Quality: CaseIterable, Sendable {
        case major, minor, diminished, augmented, suspendedSecond, suspendedFourth
        case majorSeventh, dominantSeventh, minorSeventh, minorMajorSeventh, halfDiminishedSeventh
        case diminishedSeventh, augmentedMajorSeventh, augmentedSeventh, dominantSeventhSuspendedFourth

        /// The six triads, in the order a degree tries them.
        public static let triads: [Quality] = [.major, .minor, .diminished, .augmented, .suspendedSecond, .suspendedFourth]
        /// The sevenths on the major, minor, diminished, augmented and suspended-fourth triads.
        public static let sevenths: [Quality] = [.majorSeventh, .dominantSeventh, .minorSeventh, .minorMajorSeventh,
                                                 .halfDiminishedSeventh, .diminishedSeventh, .augmentedMajorSeventh,
                                                 .augmentedSeventh, .dominantSeventhSuspendedFourth]

        /// The tones in semitones above the root, rising from 0.
        public var intervals: [Int] {
            switch self {
            case .major: [0, 4, 7]
            case .minor: [0, 3, 7]
            case .diminished: [0, 3, 6]
            case .augmented: [0, 4, 8]
            case .suspendedSecond: [0, 2, 7]
            case .suspendedFourth: [0, 5, 7]
            case .majorSeventh: [0, 4, 7, 11]
            case .dominantSeventh: [0, 4, 7, 10]
            case .minorSeventh: [0, 3, 7, 10]
            case .minorMajorSeventh: [0, 3, 7, 11]
            case .halfDiminishedSeventh: [0, 3, 6, 10]
            case .diminishedSeventh: [0, 3, 6, 9]
            case .augmentedMajorSeventh: [0, 4, 8, 11]
            case .augmentedSeventh: [0, 4, 8, 10]
            case .dominantSeventhSuspendedFourth: [0, 5, 7, 10]
            }
        }

        /// What a chord's name writes after its root: "" (C), "m" (Dm), "°", "+", "sus2", "sus4",
        /// "maj7", "7", "m7", "m(maj7)", "ø7", "°7", "+maj7", "+7", "7sus4".
        public var symbol: String {
            switch self {
            case .major: ""
            case .minor: "m"
            case .diminished: "°"
            case .augmented: "+"
            case .suspendedSecond: "sus2"
            case .suspendedFourth: "sus4"
            case .majorSeventh: "maj7"
            case .dominantSeventh: "7"
            case .minorSeventh: "m7"
            case .minorMajorSeventh: "m(maj7)"
            case .halfDiminishedSeventh: "ø7"
            case .diminishedSeventh: "°7"
            case .augmentedMajorSeventh: "+maj7"
            case .augmentedSeventh: "+7"
            case .dominantSeventhSuspendedFourth: "7sus4"
            }
        }

        /// What VoiceOver says after the root, in words: "minor", "dominant seventh".
        public var spokenName: String {
            switch self {
            case .major: "major"
            case .minor: "minor"
            case .diminished: "diminished"
            case .augmented: "augmented"
            case .suspendedSecond: "suspended second"
            case .suspendedFourth: "suspended fourth"
            case .majorSeventh: "major seventh"
            case .dominantSeventh: "dominant seventh"
            case .minorSeventh: "minor seventh"
            case .minorMajorSeventh: "minor major seventh"
            case .halfDiminishedSeventh: "half-diminished seventh"
            case .diminishedSeventh: "diminished seventh"
            case .augmentedMajorSeventh: "augmented major seventh"
            case .augmentedSeventh: "augmented seventh"
            case .dominantSeventhSuspendedFourth: "dominant seventh suspended fourth"
            }
        }
    }

    /// One chord on degree `rootDegree` of the scale. A chord of the scale moves none of its tones
    /// (`alterations` all zero); a borrowed one is the scale's third-stack on that degree with each
    /// tone moved by `alterations` semitones.
    public struct Chord: Equatable, Sendable {
        public let rootDegree: Int
        public let alterations: [Int]
        public let function: Function
        public let borrowed: Bool
        /// The tones as pitch classes, 0 = C … 11 = B: the root first, then the others in the order
        /// of the chord's quality — third and fifth, and the seventh where it has one.
        public let pitchClasses: [Int]
        /// Root, third and fifth as written in the key they were suggested in (TH-3), by the rules
        /// of `KeySpelling.chordSpelling`: the root as the key writes it and the other tones on the
        /// letters their intervals have above it — G♯ B D♯ for F♯ major's ii, D♭ F A♭ for C minor's
        /// Neapolitan, C♭ E♭ G♭ for E♭ major's ♭VI.
        public let spelling: [SpelledNote]

        /// `key` is the key the chord is written in. It has no default, so no chord is ever spelled
        /// without one by accident; a chord of no key is written in `KeySpelling(MusicalContext())`.
        init(rootDegree: Int, alterations: [Int], function: Function, borrowed: Bool, pitchClasses: [Int],
             spelledIn key: KeySpelling) {
            self.rootDegree = rootDegree
            self.alterations = alterations
            self.function = function
            self.borrowed = borrowed
            self.pitchClasses = pitchClasses
            spelling = key.chordSpelling(of: pitchClasses)
        }

        /// What the chord is above its root; nil for a stack of tones the vocabulary has no name for.
        public var quality: Quality? {
            guard let root = pitchClasses.first else { return nil }
            let above = pitchClasses.map { ChordSuggest.pitchClass($0 - root) }
            return Quality.allCases.first { $0.intervals == above }
        }

        /// "C", "Dm", "B°", "C+", "Gsus4", "G♯m" in F♯ major; a stack without a name lists its tones,
        /// "C-E-A".
        public var name: String { name(.english) }
    }

    // MARK: Weights — the laws of the ranking (ChordSuggestTests)

    /// The smallest function step (0.35) times this stays above the distance term's ceiling, so
    /// function always outranks smoothness and smoothness only breaks ties.
    static let functionWeight = 4.0
    /// Above the in-class ceiling, so a borrowed chord never ranks first.
    static let borrowedSurcharge = 3.0
    /// Suggesting the chord just played again.
    static let repeatPenalty = 2.0
    /// The voice-movement tie-break, capped at `distanceWeight · distanceCap` = 1.2 < 1.4.
    static let distanceWeight = 0.15
    static let distanceCap = 8.0

    // MARK: Candidates

    /// The scale's degrees above the root, ascending; empty for a song without a key.
    static func degrees(_ context: MusicalContext) -> [Int] {
        context.scale == .chromatic ? [] : context.scale.intervals.sorted()
    }

    /// Every chord the ranking considers: the scale's own chord on each degree that holds one, in the
    /// scale's order — in a seven-note scale the third-stack where the vocabulary names it, otherwise
    /// the first triad of the vocabulary there (see the type's notes) — then the borrowed chords of
    /// the key's tonality. Empty without a key.
    public static func candidates(in context: MusicalContext) -> [Chord] {
        let steps = degrees(context)
        guard steps.count >= 3 else { return [] }
        let triads = vocabulary(in: context, qualities: Quality.triads)
        var out: [Chord] = []
        for degree in steps.indices {
            let stack = chord(degree: degree, alterations: [0, 0, 0], function: function(interval: steps[degree]),
                              borrowed: false, in: context, steps: steps)
            if steps.count == 7, stack.quality != nil {
                out.append(stack)
            } else if let first = triads.first(where: { $0.rootDegree == degree }) {
                out.append(first)
            }
        }
        return out + borrowedCandidates(in: context, steps: steps)
    }

    /// Every chord of `qualities` that the song's scale holds: its root a degree of the scale and each
    /// of its tones in the scale, worked out from the scale's pitch classes. Root by root in the
    /// scale's order and, on one root, in the order of `qualities` (a quality named twice counts
    /// once); none is borrowed. Empty for a song without a key.
    public static func vocabulary(in context: MusicalContext, qualities: [Quality] = Quality.allCases) -> [Chord] {
        let steps = degrees(context)
        guard steps.count >= 3 else { return [] }
        let held = Set(steps)
        var asked: [Quality] = []
        for quality in qualities where !asked.contains(quality) { asked.append(quality) }
        var out: [Chord] = []
        for (degree, interval) in steps.enumerated() {
            for quality in asked where quality.intervals.allSatisfy({ held.contains(pitchClass(interval + $0)) }) {
                out.append(Chord(rootDegree: degree, alterations: quality.intervals.map { _ in 0 },
                                 function: function(interval: interval), borrowed: false,
                                 pitchClasses: quality.intervals.map { pitchClass(context.root + interval + $0) },
                                 spelledIn: KeySpelling(context)))
            }
        }
        return out
    }

    /// The T/S/D family of a root by its distance from the tonic in semitones.
    static func function(interval: Int) -> Function {
        switch pitchClass(interval) {
        case 0, 3, 4, 8, 9: .tonic         // I, iii, vi colours
        case 1, 2, 5, 6: .subdominant      // ii, IV colours
        default: .dominant                 // V, vii colours
        }
    }

    /// A scale is of minor tonality when it has a minor third above the root and no major one.
    static func isMinor(_ steps: [Int]) -> Bool { steps.contains(3) && !steps.contains(4) }

    /// Major tonality borrows iv, ♭VI and ♭VII from the parallel minor; minor tonality borrows V
    /// (the raised leading tone), the major tonic (Picardy) and the Neapolitan ♭II.
    static func borrowedCandidates(in context: MusicalContext, steps: [Int]) -> [Chord] {
        let curated: [([Int], Function)] = isMinor(steps)
            ? [([7, 11, 2], .dominant), ([0, 4, 7], .tonic), ([1, 5, 8], .subdominant)]
            : [([5, 8, 0], .subdominant), ([8, 0, 3], .subdominant), ([10, 2, 5], .dominant)]
        return curated.compactMap { borrowed(target: $0.0, function: $0.1, in: context, steps: steps) }
    }

    /// The target chord as the nearest third-stack of the scale with each tone moved at most a
    /// semitone; the smallest total move wins, the lower degree on a tie. Nil when none fits, and
    /// when every tone of the target lies in the scale: a chord the scale holds is not borrowed,
    /// though in a scale of other than seven notes it need not be a third-stack (TH-5).
    static func borrowed(target: [Int], function: Function, in context: MusicalContext, steps: [Int]) -> Chord? {
        let wanted = target.map { pitchClass(context.root + $0) }
        let held = Set(steps.map { pitchClass(context.root + $0) })
        guard wanted.contains(where: { !held.contains($0) }) else { return nil }
        var best: (degree: Int, alterations: [Int], total: Int)?
        for degree in steps.indices {
            var alterations: [Int] = []
            var total = 0
            var fits = true
            for (index, offset) in [0, 2, 4].enumerated() {
                var difference = pitchClass(wanted[index] - tone(degree + offset, in: context, steps: steps))
                if difference > 6 { difference -= 12 }
                guard abs(difference) <= 1 else { fits = false; break }
                alterations.append(difference)
                total += abs(difference)
            }
            guard fits else { continue }
            if best == nil || total < (best?.total ?? .max) { best = (degree, alterations, total) }
        }
        guard let found = best, found.total > 0 else { return nil }
        return chord(degree: found.degree, alterations: found.alterations, function: function, borrowed: true,
                     in: context, steps: steps)
    }

    private static func chord(degree: Int, alterations: [Int], function: Function, borrowed: Bool,
                              in context: MusicalContext, steps: [Int]) -> Chord {
        let classes = [0, 2, 4].enumerated().map { index, offset in
            pitchClass(tone(degree + offset, in: context, steps: steps) + alterations[index])
        }
        return Chord(rootDegree: degree, alterations: alterations, function: function, borrowed: borrowed,
                     pitchClasses: classes, spelledIn: KeySpelling(context))
    }

    /// The pitch class of a scale degree counted from the root, any number of octaves up.
    private static func tone(_ degree: Int, in context: MusicalContext, steps: [Int]) -> Int {
        pitchClass(context.root + steps[degree % steps.count])
    }

    // MARK: Ranking

    /// What moving from one function to the next costs: continuing T → S → D is free, the
    /// cadence D → T is free, standing still and going back cost more. No previous chord: the
    /// tonic opens.
    static func functionCost(from previous: Function?, to next: Function) -> Double {
        guard let previous else {
            switch next {
            case .tonic: return 0
            case .subdominant: return 0.35
            case .dominant: return 0.5
            }
        }
        switch (previous, next) {
        case (.tonic, .subdominant), (.subdominant, .dominant), (.dominant, .tonic): return 0
        case (.tonic, .dominant): return 0.35
        case (.subdominant, .tonic): return 0.5
        case (.dominant, .dominant): return 0.6
        case (.tonic, .tonic): return 0.7
        case (.subdominant, .subdominant): return 0.8
        case (.dominant, .subdominant): return 1
        }
    }

    /// How far the voices move: for each tone of the chord, the fewest semitones to a pitch class
    /// of what sounds now. Zero when nothing sounds.
    static func distance(from sounding: [Int], to chord: Chord) -> Double {
        let previous = Set(sounding.map(pitchClass))
        guard !previous.isEmpty else { return 0 }
        return Double(chord.pitchClasses.reduce(0) { sum, target in
            sum + (previous.map { abs(pitchClass(target - $0 + 6) - 6) }.min() ?? 0)
        })
    }

    /// The candidates for the chord after `previous`, best first. `sounding` is what plays now
    /// (MIDI pitches), for the voice-movement tie-break. Ties: a chord of the scale before a
    /// borrowed one, then the lower degree.
    public static func ranked(after previous: Chord?, sounding: [Int], in context: MusicalContext) -> [Chord] {
        let scored = candidates(in: context).map { candidate -> (Chord, Double) in
            var score = functionWeight * functionCost(from: previous?.function, to: candidate.function)
            if candidate.borrowed { score += borrowedSurcharge }
            if let previous, previous.pitchClasses == candidate.pitchClasses { score += repeatPenalty }
            score += distanceWeight * Swift.min(distance(from: sounding, to: candidate), distanceCap)
            return (candidate, score)
        }
        return scored.sorted { a, b in
            if a.1 != b.1 { return a.1 < b.1 }
            if a.0.borrowed != b.0.borrowed { return !a.0.borrowed }
            if a.0.rootDegree != b.0.rootDegree { return a.0.rootDegree < b.0.rootDegree }
            return a.0.alterations.lexicographicallyPrecedes(b.0.alterations)
        }.map(\.0)
    }

    /// The candidate that `pitches` spell: the one sharing the most pitch classes, at least two,
    /// a chord of the scale before a borrowed one and one whose root is the lowest note first.
    public static func recognize(_ pitches: [Int], in context: MusicalContext) -> Chord? {
        let classes = Set(pitches.map(pitchClass))
        guard let lowest = pitches.min() else { return nil }
        let bass = pitchClass(lowest)
        return candidates(in: context)
            .map { ($0, Set($0.pitchClasses).intersection(classes).count) }
            .filter { $0.1 >= 2 }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                if (a.0.pitchClasses.first == bass) != (b.0.pitchClasses.first == bass) { return a.0.pitchClasses.first == bass }
                if a.0.borrowed != b.0.borrowed { return !a.0.borrowed }
                return a.0.rootDegree < b.0.rootDegree
            }
            .first?.0
    }

    /// The tones of a chord outside the song's scale, as pitch classes.
    public static func outside(_ chord: Chord, in context: MusicalContext) -> [Int] {
        chord.pitchClasses.filter { !context.contains($0) }
    }

    // MARK: In a clip

    /// Where a clip's next chord goes and what it follows: the notes that start last in the clip
    /// are the chord before; the next one starts where the last note ends.
    public struct Position: Equatable, Sendable {
        public let previous: Chord?
        /// The MIDI pitches of the notes that start last; empty in an empty clip.
        public let sounding: [Int]
        public let start: Tick
    }

    public static func position(in clip: Clip, context: MusicalContext) -> Position {
        guard let last = clip.notes.map(\.start).max() else { return Position(previous: nil, sounding: [], start: 0) }
        let sounding = clip.notes.filter { $0.start == last }.map(\.pitch).sorted()
        let end = clip.notes.map { $0.start + $0.length }.max() ?? 0
        return Position(previous: recognize(sounding, in: context), sounding: sounding, start: end)
    }

    /// The chord's three notes close to what sounds now — each tone at the pitch nearest any note
    /// of the chord before (the lower on a tie), or around E4 when nothing sounds — so common
    /// tones stay and the others move by the smallest step.
    public static func voicing(of chord: Chord, after sounding: [Int]) -> [Int] {
        let anchors = sounding.isEmpty ? [64] : sounding
        return chord.pitchClasses.map { pitchClass in
            var best: (pitch: Int, distance: Int)?
            for anchor in anchors {
                let below = anchor - self.pitchClass(anchor - pitchClass)
                for pitch in [below, below + 12] where Note.pitchRange.contains(pitch) {
                    let distance = abs(pitch - anchor)
                    if let current = best, (current.distance, current.pitch) <= (distance, pitch) { continue }
                    best = (pitch, distance)
                }
            }
            return best?.pitch ?? Swift.min(Swift.max(60 + pitchClass, Note.pitchRange.lowerBound), Note.pitchRange.upperBound)
        }.sorted()
    }

    /// Places `chord` as the clip's next chord, `length` ticks long or to the clip's end — the
    /// command a pick in the note editor sends. Nil when the clip has no room after its last note.
    public static func insert(_ chord: Chord, in clip: Clip, context: MusicalContext, length: Tick,
                              velocity: Int = 100) -> Command? {
        let place = position(in: clip, context: context)
        guard length > 0, place.start < clip.length else { return nil }
        let duration = Swift.min(length, clip.length - place.start)
        let notes = voicing(of: chord, after: place.sounding).map {
            Note(pitch: $0, velocity: velocity, start: place.start, length: duration)
        }
        return .addNotes(clip.id, notes)
    }

    static func pitchClass(_ pitch: Int) -> Int { ((pitch % 12) + 12) % 12 }
}
