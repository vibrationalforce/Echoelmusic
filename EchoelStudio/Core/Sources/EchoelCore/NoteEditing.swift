import Foundation

/// The note editor's decisions as pure functions — snapping, hit-testing, and which command
/// a tap or a drag becomes — so the piano roll stays a thin view and this is tested directly.
public enum NoteEditing {
    /// Grid divisions a musician picks from, in ticks.
    public enum Grid: Tick, CaseIterable, Sendable {
        case quarter = 960, eighth = 480, sixteenth = 240, thirtySecond = 120
        case eighthTriplet = 320, sixteenthTriplet = 160

        public var title: String {
            switch self {
            case .quarter: "1/4"
            case .eighth: "1/8"
            case .sixteenth: "1/16"
            case .thirtySecond: "1/32"
            case .eighthTriplet: "1/8T"
            case .sixteenthTriplet: "1/16T"
            }
        }
    }

    /// How long a note written with the magnet off is, and the step its actions and speech count
    /// in: a sixteenth.
    public static let freeNoteLength: Tick = MusicalTime.ticksPerQuarter / 4

    /// The step the editor's actions and speech count in for a grid of `grid` ticks: the grid when
    /// it is a note value VoiceOver can name, else a sixteenth (the magnet off, a bar, a beat of
    /// an odd meter) — so nothing is ever said in ticks.
    public static func spokenStep(for grid: Tick) -> Tick {
        noteValues.contains { $0.ticks == grid } ? grid : freeNoteLength
    }

    /// `tick` rounded down to the grid; negative ticks snap to 0.
    public static func snap(_ tick: Tick, to grid: Tick) -> Tick {
        guard grid > 0 else { return Swift.max(0, tick) }
        return Swift.max(0, tick) / grid * grid
    }

    /// The note sounding at `pitch` and `tick`, the latest-starting one if several overlap.
    public static func note(in clip: Clip, pitch: Int, tick: Tick) -> Note? {
        clip.notes.last { $0.pitch == pitch && $0.start <= tick && tick < $0.start + $0.length }
    }

    /// A tap: on a note it removes that note; on empty space it adds one grid step at the
    /// snapped position. Nil when the tap lies outside the clip or the keyboard.
    public static func tap(in clip: Clip, pitch: Int, tick: Tick, grid: Tick, velocity: Int = 100) -> Command? {
        guard Note.pitchRange.contains(pitch), tick >= 0, tick < clip.length else { return nil }
        if let hit = note(in: clip, pitch: pitch, tick: tick) {
            return .removeNotes(clip.id, [hit.id])
        }
        let start = snap(tick, to: grid)
        let length = Swift.max(1, Swift.min(grid > 0 ? grid : freeNoteLength, clip.length - start))
        return .addNotes(clip.id, [Note(pitch: pitch, velocity: velocity, start: start, length: length)])
    }

    /// The note moved by a drag, snapped to the grid and kept inside the clip and the keyboard.
    public static func moved(_ note: Note, byTicks delta: Tick, semitones: Int, grid: Tick, in clip: Clip) -> Note {
        var moved = note
        let latestStart = Swift.max(0, clip.length - 1)
        let target = note.start + delta
        let snapped = grid > 0 ? (target + grid / 2) / grid * grid : target
        moved.start = Swift.min(Swift.max(0, snapped), latestStart)
        moved.pitch = Swift.min(Swift.max(note.pitch + semitones, Note.pitchRange.lowerBound), Note.pitchRange.upperBound)
        return moved
    }

    /// The note with its end dragged to `endTick`, snapped; never shorter than one grid step
    /// (one tick without a grid) and never past the clip end.
    public static func resized(_ note: Note, toEnd endTick: Tick, grid: Tick, in clip: Clip) -> Note {
        var resized = note
        let snappedEnd = grid > 0 ? (endTick + grid / 2) / grid * grid : endTick
        let minimum = Swift.max(1, grid)
        resized.length = Swift.min(Swift.max(snappedEnd - note.start, minimum), Swift.max(1, clip.length - note.start))
        return resized
    }

    /// "Add Note" without a finger on the grid, VoiceOver's way to write (accessibility audit
    /// 2026-11-01, B1): one grid step long, on the first grid line at or after the end of the note
    /// that ends last, at that note's pitch — so done again and again it writes a line of notes —
    /// and C4 at the clip's start in an empty clip. It is a tap there (`tap`), so it lands where a
    /// finger would put it. Nil when the clip has no room left after its last note.
    public static func addAfterLast(in clip: Clip, grid: Tick, velocity: Int = 100) -> Command? {
        var pitch = 60
        var tick: Tick = 0
        if let last = noteEndingLast(in: clip) {
            pitch = last.pitch
            let end = last.start + last.length
            tick = grid > 0 ? (end + grid - 1) / grid * grid : end
        }
        // Nothing sounds at or after the last end, so the tap can only add.
        guard let command = tap(in: clip, pitch: pitch, tick: tick, grid: grid, velocity: velocity),
              case .addNotes = command else { return nil }
        return command
    }

    /// The note that ends last; of several, the one that starts last, then the one written last.
    private static func noteEndingLast(in clip: Clip) -> Note? {
        var last: Note?
        for note in clip.notes {
            guard let found = last else { last = note; continue }
            let end = note.start + note.length, foundEnd = found.start + found.length
            if end > foundEnd || (end == foundEnd && note.start >= found.start) { last = note }
        }
        return last
    }

    /// A note moved by one of the editor's actions — a semitone, an octave, a grid step, a bar —
    /// exactly that far, or nil when that would leave the clip or the keyboard, so the action says
    /// so instead of putting the note somewhere it was not sent. A drag snaps and clamps
    /// (`moved`); a step of a named size must not: changing the pitch of a recorded note keeps
    /// its timing.
    public static func nudged(_ note: Note, byTicks delta: Tick = 0, semitones: Int = 0, in clip: Clip) -> Note? {
        let start = note.start + delta
        let pitch = note.pitch + semitones
        guard start >= 0, start < clip.length, Note.pitchRange.contains(pitch) else { return nil }
        var nudged = note
        nudged.start = start
        nudged.pitch = pitch
        return nudged
    }

    /// A note made longer (`steps` > 0) or shorter by whole grid steps at its end, snapped as a
    /// drag of its edge is (`resized`); nil when it cannot change that way — the clip ends there,
    /// or it is already one step short.
    public static func resized(_ note: Note, bySteps steps: Int, grid: Tick, in clip: Clip) -> Note? {
        let edited = resized(note, toEnd: note.start + note.length + Tick(steps) * grid, grid: grid, in: clip)
        if steps > 0, edited.length > note.length { return edited }
        if steps < 0, edited.length < note.length { return edited }
        return nil
    }

    /// Whether a drag that starts `startX` points into the clip takes the note's right edge
    /// (resize) rather than its body (move). Asked of the note as it was when the drag began,
    /// so a note that grows under the finger does not move its edge away and flip the drag into
    /// a move half way (audit 2026-10-23).
    public static func dragTakesTheEnd(of origin: Note, startX: Double, pointsPerTick: Double,
                                       edgeWidth: Double, minimumWidth: Double) -> Bool {
        let width = Swift.max(Double(origin.length) * pointsPerTick, minimumWidth)
        let left = Double(origin.start) * pointsPerTick
        return startX >= left + width - Swift.min(edgeWidth, width / 2)
    }

    /// Note names for the keyboard: MIDI 60 is C4 (scientific pitch notation, as in Logic;
    /// Ableton labels the same key C3). Only the label could ever change, never the number.
    public static func name(of pitch: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let index = ((pitch % 12) + 12) % 12
        return "\(names[index])\(pitch / 12 - 1)"
    }

    public static func isBlackKey(_ pitch: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(((pitch % 12) + 12) % 12)
    }

    // MARK: Said aloud (VoiceOver)

    /// A note as VoiceOver says it after its name: where it starts, how long it is and how hard
    /// it is struck — "bar 1, beat 3, one sixteenth long, velocity 100" — never in ticks
    /// (accessibility audit 2026-11-01, M4).
    public static func spokenDetails(of note: Note, signature: TimeSignature, grid: Tick) -> String {
        spokenDetails(of: note, meter: MeterMap(signature: signature), grid: grid)
    }

    /// The same in the bars of a clip's meter (`Project.clipMeter`).
    public static func spokenDetails(of note: Note, meter: MeterMap, grid: Tick) -> String {
        "\(spokenPosition(note.start, meter: meter, grid: grid)), "
            + "\(spokenLength(note.length, grid: grid)) long, velocity \(note.velocity)"
    }

    /// Where `tick` lies in a clip, counted as the piano roll draws it, in bars from the clip's
    /// start: "bar 2, beat 3", and past a beat by how much — "bar 2, beat 3, plus one sixteenth".
    /// A position off the grid (a recorded note) is said as the nearest grid line: "about bar 2,
    /// beat 3".
    public static func spokenPosition(_ tick: Tick, signature: TimeSignature, grid: Tick) -> String {
        spokenPosition(tick, meter: MeterMap(signature: signature), grid: grid)
    }

    /// The same in the bars of a clip's meter, whatever their lengths.
    public static func spokenPosition(_ tick: Tick, meter: MeterMap, grid: Tick) -> String {
        let position = Swift.max(0, tick)
        let onGrid = grid <= 0 || position % grid == 0
        let said = onGrid ? position : (position + grid / 2) / grid * grid
        let beat = meter.ticksPerBeat(at: said)
        let inBar = said - meter.barStart(at: said)
        var spoken = "bar \(meter.bar(at: said) + 1), beat \(inBar / beat + 1)"
        let past = inBar % beat
        if past > 0 { spoken += ", plus " + (amount(past, grid: grid) ?? "\(past) ticks") }
        return onGrid ? spoken : "about " + spoken
    }

    /// How long `ticks` is in the editor's grid steps: "one sixteenth", "3 sixteenths"; off the
    /// grid, the nearest number of steps — "about 2 sixteenths", "less than one sixteenth".
    public static func spokenLength(_ ticks: Tick, grid: Tick) -> String {
        guard grid > 0, let value = noteValues.first(where: { $0.ticks == grid }) else { return "\(ticks) ticks" }
        if ticks > 0, ticks % grid == 0 { return count(ticks / grid, value) }
        let steps = (ticks + grid / 2) / grid
        return steps < 1 ? "less than one \(value.one)" : "about " + count(steps, value)
    }

    /// A step of the drum grid as VoiceOver says it after its lane's name: its number and the beat
    /// it falls in — "step 5, beat 2" — and the bar when the clip has more than one (accessibility
    /// audit 2026-11-01, M1).
    public static func spokenStep(_ index: Int, step: Tick, signature: TimeSignature, clipLength: Tick) -> String {
        spokenStep(index, step: step, meter: MeterMap(signature: signature), clipLength: clipLength)
    }

    /// The same in the bars of a clip's meter.
    public static func spokenStep(_ index: Int, step: Tick, meter: MeterMap, clipLength: Tick) -> String {
        let start = Tick(Swift.max(0, index)) * Swift.max(0, step)
        let place = clipLength > meter.ticksPerBar(at: 0) ? "bar \(meter.bar(at: start) + 1), " : ""
        return "step \(index + 1), \(place)beat \((start - meter.barStart(at: start)) / meter.ticksPerBeat(at: start) + 1)"
    }

    private typealias NoteValue = (ticks: Tick, one: String, many: String)

    /// The note values a grid step or a distance is said in, longest first.
    private static let noteValues: [NoteValue] = {
        let quarter = MusicalTime.ticksPerQuarter
        return [
            (quarter, "quarter", "quarters"),
            (quarter * 2 / 3, "quarter triplet", "quarter triplets"),
            (quarter / 2, "eighth", "eighths"),
            (quarter / 3, "eighth triplet", "eighth triplets"),
            (quarter / 4, "sixteenth", "sixteenths"),
            (quarter / 6, "sixteenth triplet", "sixteenth triplets"),
            (quarter / 8, "thirty-second", "thirty-seconds"),
            (quarter / 12, "thirty-second triplet", "thirty-second triplets"),
            (quarter / 16, "sixty-fourth", "sixty-fourths"),
            (quarter / 32, "hundred-twenty-eighth", "hundred-twenty-eighths"),
        ]
    }()

    /// `ticks` as a whole number of one note value: grid steps when the grid divides it, else the
    /// longest value that does (a triplet grid in 6/8 puts a line a sixteenth triplet past a beat);
    /// nil when none does.
    private static func amount(_ ticks: Tick, grid: Tick) -> String? {
        if grid > 0, ticks % grid == 0, let value = noteValues.first(where: { $0.ticks == grid }) {
            return count(ticks / grid, value)
        }
        guard let value = noteValues.first(where: { ticks % $0.ticks == 0 }) else { return nil }
        return count(ticks / value.ticks, value)
    }

    private static func count(_ number: Tick, _ value: NoteValue) -> String {
        number == 1 ? "one \(value.one)" : "\(number) \(value.many)"
    }
}
