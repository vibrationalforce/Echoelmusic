import Foundation

/// Voicings of the musician's own chords (2026-11-19): the same notes, some of them moved by an
/// octave, the way a player re-voices a chord — nothing is added or removed, and every note keeps
/// its id, start, length and velocity. One `updateNotes` command, one undo step, like Revoice.
///
/// What each does to a chord (its notes lowest first, as `Revoice.chords` finds them):
/// - Invert Up: the lowest note an octave up. Invert Down: the highest note an octave down.
/// - Open: the second-lowest note an octave up, so a close chord spreads.
/// - Drop 2: the second-highest note an octave down. Drop 3: the third-highest (four notes or more).
/// A note is not moved where its new pitch would leave 0 … 127 or land on a pitch the chord already
/// holds; that chord stays as written.
public enum ChordVoicing {
    public enum Kind: Sendable, Equatable, CaseIterable {
        case invertUp, invertDown, open, dropTwo, dropThree

        public var title: String {
            switch self {
            case .invertUp: "Invert Up"
            case .invertDown: "Invert Down"
            case .open: "Open"
            case .dropTwo: "Drop 2"
            case .dropThree: "Drop 3"
            }
        }
    }

    public struct Result: Equatable, Sendable {
        public var command: Command?
        /// The chords looked at, and how many of them changed.
        public var chordCount: Int
        public var changedCount: Int
    }

    /// The chords of `clip` re-voiced by `kind`: those holding a chosen note, or all of them.
    public static func voiced(_ clip: Clip, chosen: Set<NoteID> = [], kind: Kind) -> Result {
        var chords = Revoice.chords(in: clip)
        if !chosen.isEmpty { chords = chords.filter { chord in chord.contains { chosen.contains($0.id) } } }
        var changed: [Note] = []
        var changedChords = 0
        for chord in chords {
            guard let target = move(in: chord, kind: kind) else { continue }
            let index = target.index
            let pitch = chord[index].pitch + target.shift
            guard Note.pitchRange.contains(pitch), !chord.contains(where: { $0.pitch == pitch }) else { continue }
            var moved = chord[index]
            moved.pitch = pitch
            changed.append(moved)
            changedChords += 1
        }
        return Result(command: changed.isEmpty ? nil : .updateNotes(clip.id, changed),
                      chordCount: chords.count, changedCount: changedChords)
    }

    /// Which note of a chord (lowest first) moves, and by how many semitones; nil where the chord
    /// has too few notes for it.
    static func move(in chord: [Note], kind: Kind) -> (index: Int, shift: Int)? {
        let count = chord.count
        switch kind {
        case .invertUp: return count >= 1 ? (0, 12) : nil
        case .invertDown: return count >= 1 ? (count - 1, -12) : nil
        case .open: return count >= 3 ? (1, 12) : nil
        case .dropTwo: return count >= 3 ? (count - 2, -12) : nil
        case .dropThree: return count >= 4 ? (count - 3, -12) : nil
        }
    }

    /// What the app says after a voicing, sighted and spoken alike.
    public static func message(_ result: Result, kind: Kind) -> String {
        if result.chordCount == 0 { return "\(kind.title) needs a chord of \(Revoice.minimumChordNotes) or more notes together." }
        let chords = "\(result.changedCount) chord\(result.changedCount == 1 ? "" : "s")"
        guard result.command != nil else { return "\(kind.title): no chord could move without leaving the range or doubling a note." }
        return "\(kind.title): \(chords) re-voiced."
    }
}
