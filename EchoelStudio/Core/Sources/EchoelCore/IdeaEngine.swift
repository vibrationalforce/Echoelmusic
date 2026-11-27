import Foundation

/// A sketch of chords for the song's key, proposed and never written by itself (TH-6, its first
/// part: chords and an optional bass line). The musician asks for an idea, reads its chord names,
/// asks for another, and only an accept sends it through the one door as one undo step; the song's
/// key, scale, tempo and sound stay theirs. No model runs here, which is why the app calls it an
/// Idea: a seed picks among the chords `ChordSuggest` ranks, so the same seed gives the same idea
/// on every device.
///
/// How an idea is made. One chord a bar, each a chord the scale holds (never a borrowed one, so
/// every note lies in the scale). The first bar is the tonic's chord where the scale has one. Each
/// next bar takes one of the three chords `ChordSuggest.ranked` puts first after the chord before,
/// the seed choosing which, voiced close to it (`ChordSuggest.voicing`). An idea of four bars or
/// more ends on a chord of dominant function where the scale holds one, so the loop turns back to
/// its start. The bass, when asked for, plays each chord's root two octaves down in one of three
/// figures the seed picks: one long note, a note on every beat, or root then fifth where the chord
/// has a perfect fifth.
///
/// Limits, said plainly: bars are counted in the meter the request names, one chord a bar; there is
/// no melody and no drum part yet; a song without a key (chromatic), or a scale that holds fewer
/// than two chords, gets no notes and a remark that says why.
public enum IdeaEngine {
    /// What the musician asks for.
    public struct Request: Equatable, Sendable {
        /// The song's key, scale and tone system; read, never changed.
        public var context: MusicalContext
        /// The meter the bars are counted in.
        public var meter: TimeSignature
        /// How many bars, 1 … `maximumBars`; out of range is brought into it.
        public var bars: Int
        /// Which idea: the same seed is the same idea, the next seed another one.
        public var seed: UInt64
        /// Whether a bass line plays under the chords.
        public var bass: Bool

        public init(context: MusicalContext, meter: TimeSignature, bars: Int = 4, seed: UInt64 = 0, bass: Bool = false) {
            self.context = context
            self.meter = meter
            self.bars = bars
            self.seed = seed
            self.bass = bass
        }
    }

    /// One note of an idea, before it has an id: where it starts in the idea, in ticks from its
    /// first bar, and how long it sounds.
    public struct Sketch: Equatable, Sendable {
        public let pitch: Int
        public let velocity: Int
        public let start: Tick
        public let length: Tick
    }

    /// Why an idea holds no notes.
    public enum Remark: Hashable, Sendable {
        /// The song names no key (the chromatic scale), so no chord belongs to it.
        case noKey
        /// The scale holds fewer than two chords the vocabulary names.
        case tooFewChords

        /// The sentence the page shows.
        public var sentence: String {
            switch self {
            case .noKey: "The song has no key yet (its scale is Chromatic). Choose a key and scale in the Song menu, and ideas follow it."
            case .tooFewChords: "This scale holds too few chords for a progression."
            }
        }
    }

    /// An idea: its chords, one a bar, and the notes that play them. A value; nothing is written
    /// until `commands(on:in:)` goes through the door.
    public struct Proposal: Equatable, Sendable {
        /// One chord a bar, in order.
        public let chords: [ChordSuggest.Chord]
        /// The chords' notes and, where asked for, the bass line's.
        public let notes: [Sketch]
        /// The idea's length in ticks: its bars in the request's meter.
        public let length: Tick
        public let remarks: [Remark]

        public var isEmpty: Bool { notes.isEmpty }

        /// The commands that put the idea on `track` as a new clip, placed on the first bar line
        /// after everything the track's arrangement holds, so it covers nothing: create the clip,
        /// add its notes, place it. One undo step when sent together. Empty for an idea without
        /// notes and for a track that is not an instrument track. Bar lines are counted in the
        /// song's first meter.
        public func commands(on track: TrackID, in project: Project) -> [Command] {
            guard !notes.isEmpty, length > 0, let target = project.track(track), target.kind == .instrument else { return [] }
            let clip = ClipID()
            let written = notes.map { (sketch: Sketch) -> Note in
                Note(pitch: sketch.pitch, velocity: sketch.velocity, start: sketch.start, length: sketch.length)
            }
            let first = IdeaEngine.firstFreeBar(on: target, barTicks: MusicalTime.ticksPerBar(project.timeSignature))
            return [.createClip(track: track, id: clip, name: Names.unique("Idea", taken: target.clips.map(\.name)), length: length),
                    .addNotes(clip, written),
                    .placeClip(track: track, id: PlacementID(), clip: clip, start: first)]
        }
    }

    /// The most bars an idea holds.
    public static let maximumBars = 16
    /// How hard the chords and the bass play: under the kit's accent, so an idea sits in a mix.
    static let chordVelocity = 80
    static let bassVelocity = 96
    /// The bass plays in the octave from C2.
    static let bassFloor = 36

    /// The idea `request` asks for. The same request always gives the same idea.
    public static func propose(_ request: Request) -> Proposal {
        let bars = Swift.min(Swift.max(request.bars, 1), maximumBars)
        let barTicks = MusicalTime.ticksPerBar(request.meter)
        guard request.context.scale != .chromatic else {
            return Proposal(chords: [], notes: [], length: 0, remarks: [.noKey])
        }
        let own = ChordSuggest.candidates(in: request.context).filter { !$0.borrowed }
        guard own.count >= 2, barTicks > 0 else {
            return Proposal(chords: [], notes: [], length: 0, remarks: [.tooFewChords])
        }
        var chords: [ChordSuggest.Chord] = []
        var notes: [Sketch] = []
        var sounding: [Int] = []
        for bar in 0..<bars {
            let ranked = ChordSuggest.ranked(after: chords.last, sounding: sounding, in: request.context).filter { !$0.borrowed }
            guard let chord = pick(bar: bar, of: bars, from: ranked, own: own, after: chords.last, seed: request.seed) else { break }
            let start = Tick(bar) * barTicks
            let voiced = ChordSuggest.voicing(of: chord, after: sounding)
            for pitch in voiced {
                notes.append(Sketch(pitch: pitch, velocity: chordVelocity, start: start, length: barTicks))
            }
            if request.bass {
                notes.append(contentsOf: bassLine(under: chord, from: start, barTicks: barTicks, meter: request.meter, seed: request.seed))
            }
            chords.append(chord)
            sounding = voiced
        }
        return Proposal(chords: chords, notes: notes, length: Tick(chords.count) * barTicks, remarks: [])
    }

    /// The chord of one bar: the tonic's first, a turn back on the last bar of four or more, else
    /// one of the three best ranked, as the seed picks.
    private static func pick(bar: Int, of bars: Int, from ranked: [ChordSuggest.Chord], own: [ChordSuggest.Chord],
                             after previous: ChordSuggest.Chord?, seed: UInt64) -> ChordSuggest.Chord? {
        if bar == 0, let tonic = own.first(where: { $0.rootDegree == 0 }) { return tonic }
        guard !ranked.isEmpty else { return nil }
        if bar == bars - 1, bars >= 4,
           let turn = ranked.first(where: { $0.function == .dominant && $0.pitchClasses != previous?.pitchClasses }) {
            return turn
        }
        let width = UInt64(Swift.min(3, ranked.count))
        let roll = ArpPattern.mix(seed &+ UInt64(bar) &* 0x9E37_79B9_7F4A_7C15) % width
        return ranked[Int(roll)]
    }

    /// The bass under one chord: its root from `bassFloor`, in the figure the seed picks for the
    /// whole idea.
    private static func bassLine(under chord: ChordSuggest.Chord, from start: Tick, barTicks: Tick, meter: TimeSignature,
                                 seed: UInt64) -> [Sketch] {
        guard let root = chord.pitchClasses.first else { return [] }
        let low = bassFloor + ChordSuggest.pitchClass(root)
        let hasFifth = chord.pitchClasses.contains(ChordSuggest.pitchClass(root + 7))
        switch ArpPattern.mix(seed ^ 0xB455_11E5) % 3 {
        case 0:
            return [Sketch(pitch: low, velocity: bassVelocity, start: start, length: barTicks)]
        case 1:
            let beats = Swift.max(meter.numerator, 1)
            let beat = barTicks / Tick(beats)
            guard beat > 0 else { return [Sketch(pitch: low, velocity: bassVelocity, start: start, length: barTicks)] }
            return (0..<beats).map { (index: Int) -> Sketch in
                Sketch(pitch: low, velocity: bassVelocity, start: start + Tick(index) * beat, length: beat)
            }
        default:
            let half = barTicks / 2
            guard half > 0 else { return [Sketch(pitch: low, velocity: bassVelocity, start: start, length: barTicks)] }
            return [Sketch(pitch: low, velocity: bassVelocity, start: start, length: half),
                    Sketch(pitch: hasFifth ? low + 7 : low, velocity: bassVelocity, start: start + half, length: barTicks - half)]
        }
    }

    /// The first bar line at or after the end of everything `track`'s arrangement holds: where an
    /// accepted idea is placed.
    public static func firstFreeBar(on track: Track, barTicks: Tick) -> Tick {
        let end = track.placements.compactMap { (placement: Placement) -> Tick? in
            guard let clip = track.clips.first(where: { $0.id == placement.clip }) else { return nil }
            return placement.start + clip.length
        }.max() ?? 0
        guard barTicks > 0, end > 0 else { return 0 }
        return (end + barTicks - 1) / barTicks * barTicks
    }
}
