import Foundation

/// Strum: the notes of each chord the musician wrote spread in time, one after another, the way a
/// hand moves across strings — lowest first (down) or highest first (up). Nothing is added or
/// removed and no pitch or velocity changes: a note starts later and ENDS where it ended, so the
/// chord still lets go together. One `updateNotes` command, one undo step, like Revoice.
///
/// What it does, exactly (and the only thing the app may say about it):
/// - A chord is what Revoice calls a chord (`Revoice.chords`): three or more notes starting within
///   `Revoice.chordWindow` ticks of the first of them, each sounding with another of them.
/// - The chord's earliest start stays where it is (its anchor). The first note in strum order
///   starts there, the last at anchor + `span`, the others evenly between, rounded down to ticks.
/// - `span` is at most `maximumSpan`, so a strummed chord is still one chord: strumming it again,
///   the other way or wider, starts from the same anchor, and a span of 0 puts every note back
///   on the anchor.
/// - A start never leaves the clip; a length is at least one tick.
public enum Strum {
    /// Down plays the lowest note first, up the highest first.
    public enum Direction: Sendable, Equatable {
        case down, up
    }

    /// The widest spread: the chord window, so a strummed chord stays one chord.
    public static let maximumSpan: Tick = Revoice.chordWindow

    public struct Result: Equatable, Sendable {
        /// The command to perform; nil when nothing would move.
        public var command: Command?
        /// How many chords were found (in the chosen notes' chords, when a note is chosen).
        public var chordCount: Int
    }

    /// The chords of `clip` spread over `span` ticks in `direction`. With notes `chosen`, only the
    /// chords that hold one of them; with none, every chord of the clip.
    public static func strummed(_ clip: Clip, chosen: Set<NoteID> = [], direction: Direction, span: Tick) -> Result {
        let span = Swift.min(Swift.max(span, 0), maximumSpan)
        var chords = Revoice.chords(in: clip)
        if !chosen.isEmpty { chords = chords.filter { chord in chord.contains { chosen.contains($0.id) } } }
        guard clip.length > 0, !chords.isEmpty else { return Result(command: nil, chordCount: chords.count) }
        var changed: [Note] = []
        for chord in chords {
            // `Revoice.chords` lists a chord lowest first; ties keep the id order it gives.
            let order = direction == .down ? chord : Array(chord.reversed())
            guard let anchor = chord.map(\.start).min() else { continue }
            let gaps = Tick(order.count - 1)
            for (index, note) in order.enumerated() {
                let offset = gaps > 0 ? Tick(index) * span / gaps : 0
                let end = note.start + note.length
                var edited = note
                edited.start = Swift.min(anchor + offset, clip.length - 1)
                edited.length = Swift.max(end - edited.start, 1)
                if edited != note { changed.append(edited) }
            }
        }
        return Result(command: changed.isEmpty ? nil : .updateNotes(clip.id, changed), chordCount: chords.count)
    }

    /// What the app says after Strum, sighted and spoken alike.
    public static func message(_ result: Result, direction: Direction, span: Tick) -> String {
        let count = result.chordCount
        if count == 0 { return "Strum needs a chord of \(Revoice.minimumChordNotes) or more notes together." }
        let chords = "\(count) chord\(count == 1 ? "" : "s")"
        guard result.command != nil else { return span <= 0 ? "\(chords) already together." : "\(chords) already strummed so." }
        if span <= 0 { return "\(chords) back together." }
        return "\(chords) strummed \(direction == .down ? "down, lowest note first" : "up, highest note first")."
    }
}
