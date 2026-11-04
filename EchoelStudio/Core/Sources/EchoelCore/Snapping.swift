import Foundation

/// The one magnet the arrangement and the note editor share (founder 2026-11-04: "Snap-to-Beat
/// ABER AUCH stufenlos"): Off places to the tick, Bar and Beat follow the meter where the edit
/// lands, the note values run from 1/8 down to 1/128, and four triplets. Kept on this device,
/// never in the song: the raw values are written to the device's settings only, so a new choice
/// may go anywhere in the list, but an existing raw value is never renamed (a musician's choice
/// would fall back to the default).
public enum SnapGrid: String, CaseIterable, Sendable {
    case off, bar, beat
    case eighth, sixteenth, thirtySecond, sixtyFourth, hundredTwentyEighth
    case quarterTriplet, eighthTriplet, sixteenthTriplet, thirtySecondTriplet

    /// Where the choice is kept on this device.
    public static let storageKey = "edit.snap"
    /// The choice on a fresh install: the note editor's grid before this setting existed.
    public static let standard: SnapGrid = .sixteenth

    /// What the picker shows.
    public var title: String {
        switch self {
        case .off: "Off"
        case .bar: "Bar"
        case .beat: "Beat"
        case .eighth: "1/8"
        case .sixteenth: "1/16"
        case .thirtySecond: "1/32"
        case .sixtyFourth: "1/64"
        case .hundredTwentyEighth: "1/128"
        case .quarterTriplet: "1/4T"
        case .eighthTriplet: "1/8T"
        case .sixteenthTriplet: "1/16T"
        case .thirtySecondTriplet: "1/32T"
        }
    }

    /// What VoiceOver says for the choice — "1/16T" is read as a date otherwise.
    public var spokenTitle: String {
        switch self {
        case .off: "off, free placement"
        case .bar: "bar"
        case .beat: "beat"
        case .eighth: "eighth"
        case .sixteenth: "sixteenth"
        case .thirtySecond: "thirty-second"
        case .sixtyFourth: "sixty-fourth"
        case .hundredTwentyEighth: "hundred-twenty-eighth"
        case .quarterTriplet: "quarter triplet"
        case .eighthTriplet: "eighth triplet"
        case .sixteenthTriplet: "sixteenth triplet"
        case .thirtySecondTriplet: "thirty-second triplet"
        }
    }

    /// The step of a note-value choice in ticks; nil for Off, Bar and Beat, whose step depends
    /// on the meter (`step(at:meter:)`).
    public var noteValue: Tick? {
        let quarter = MusicalTime.ticksPerQuarter
        switch self {
        case .off, .bar, .beat: return nil
        case .eighth: return quarter / 2
        case .sixteenth: return quarter / 4
        case .thirtySecond: return quarter / 8
        case .sixtyFourth: return quarter / 16
        case .hundredTwentyEighth: return quarter / 32
        case .quarterTriplet: return quarter * 2 / 3
        case .eighthTriplet: return quarter / 3
        case .sixteenthTriplet: return quarter / 6
        case .thirtySecondTriplet: return quarter / 12
        }
    }

    /// The grid step where `tick` lies: a bar or a beat of the meter there, or the note value;
    /// nil with the magnet off.
    public func step(at tick: Tick, meter: MeterMap) -> Tick? {
        switch self {
        case .off: nil
        case .bar: meter.ticksPerBar(at: tick)
        case .beat: meter.ticksPerBeat(at: tick)
        default: noteValue
        }
    }

    /// The grid step an editor counts in from the start of `meter` (a clip's own meter): the
    /// step at tick 0, or 0 with the magnet off.
    public func editorStep(meter: MeterMap) -> Tick {
        step(at: 0, meter: meter) ?? 0
    }

    /// `tick` on the nearest grid line, half way rounding up; never before tick 0, never past
    /// the last tick a song holds. The grid counts from the bar line before `tick`, so a triplet
    /// in 7/8 or a beat after a meter change lands where the musician sees it, and a bar's last
    /// step is never longer than what is left of the bar. Off returns the tick itself.
    public func nearest(_ tick: Tick, meter: MeterMap) -> Tick {
        let clamped = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        guard let step = step(at: clamped, meter: meter), step > 0 else { return clamped }
        let barStart = meter.barStart(at: clamped)
        let barEnd = barStart + meter.ticksPerBar(at: clamped)
        let lower = barStart + (clamped - barStart) / step * step
        let upper = Swift.min(lower + step, barEnd)
        let rounded = clamped - lower >= (upper - lower + 1) / 2 ? upper : lower
        return rounded > MusicalTime.maximumTick ? lower : rounded
    }
}

/// Quantize and Humanize for a clip's notes: each builds ONE `updateNotes` command, so it is one
/// undo step through the one door, and redo puts back exactly the notes it made.
public enum NoteTiming {
    /// The notes an edit acts on: the chosen ones, or every note of the clip when none is chosen.
    static func targets(in clip: Clip, chosen: Set<NoteID>) -> [Note] {
        chosen.isEmpty ? clip.notes : clip.notes.filter { chosen.contains($0.id) }
    }

    /// The notes' starts moved toward the grid by `strength` (0 leaves them, 1 puts them on it),
    /// with `swing` (0 straight … 1 a triplet feel) delaying every second grid line by up to a
    /// third of a step. The grid counts in the clip's own meter. Lengths stay; a start never
    /// leaves the clip. Nil when nothing would move, the magnet is off, or a number is not finite.
    public static func quantized(_ clip: Clip, chosen: Set<NoteID> = [], snap: SnapGrid, meter: MeterMap,
                                 strength: Double, swing: Double = 0) -> Command? {
        guard snap != .off, strength.isFinite, swing.isFinite, clip.length > 0 else { return nil }
        let strength = Swift.min(Swift.max(strength, 0), 1)
        let swing = Swift.min(Swift.max(swing, 0), 1)
        var changed: [Note] = []
        for note in targets(in: clip, chosen: chosen) {
            var target = snap.nearest(note.start, meter: meter)
            if swing > 0, let step = snap.step(at: target, meter: meter), step > 0 {
                let index = (target - meter.barStart(at: target)) / step
                if index % 2 == 1 { target += Tick((Double(step) / 3 * swing).rounded()) }
            }
            let start = note.start + Tick((Double(target - note.start) * strength).rounded())
            var edited = note
            edited.start = Swift.min(Swift.max(0, start), clip.length - 1)
            if edited != note { changed.append(edited) }
        }
        return changed.isEmpty ? nil : .updateNotes(clip.id, changed)
    }

    /// The largest offsets Humanize may give: timing in ticks either way, velocity either way.
    public static let maximumTiming: Tick = MusicalTime.ticksPerQuarter / 8
    public static let maximumVelocity = 40

    /// The notes moved by a random offset of at most `timing` ticks either way and struck up to
    /// `velocity` harder or softer, from `seed` — the same seed gives the same notes, so a test
    /// and a redo see exactly one result. Bounded by `maximumTiming` and `maximumVelocity`; a
    /// start stays inside the clip and a velocity inside 1…127. Nil when nothing changes.
    public static func humanized(_ clip: Clip, chosen: Set<NoteID> = [], timing: Tick, velocity: Int,
                                 seed: UInt64) -> Command? {
        let timing = Swift.min(Swift.max(timing, 0), maximumTiming)
        let velocity = Swift.min(Swift.max(velocity, 0), maximumVelocity)
        guard timing > 0 || velocity > 0, clip.length > 0 else { return nil }
        var random = SplitMix64(seed: seed)
        var changed: [Note] = []
        for note in targets(in: clip, chosen: chosen) {
            let shift = random.offset(within: timing)
            let accent = random.offset(within: Tick(velocity))
            var edited = note
            edited.start = Swift.min(Swift.max(0, note.start + shift), clip.length - 1)
            edited.velocity = Swift.min(Swift.max(note.velocity + Int(accent), Note.velocityRange.lowerBound),
                                        Note.velocityRange.upperBound)
            if edited != note { changed.append(edited) }
        }
        return changed.isEmpty ? nil : .updateNotes(clip.id, changed)
    }
}

/// A small seeded generator (SplitMix64): the same seed, the same numbers, on every platform.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A whole number in -bound…bound; 0 for a bound of 0.
    mutating func offset(within bound: Tick) -> Tick {
        let value = next()
        guard bound > 0 else { return 0 }
        return Tick(value % UInt64(2 * bound + 1)) - bound
    }
}
