import Foundation

/// What the note editor does to the chosen notes at once (2026-11-27, the professional editing
/// set): move them by a semitone or an octave, copy them right after themselves, and play them
/// legato. Pure: each returns notes for the one door (`updateNotes`, `addNotes`), or nil where the
/// edit cannot be made whole — a note would leave the keyboard or the clip — so the editor says
/// so instead of doing half of it.
public enum NoteSelection {
    /// The notes `semitones` higher (lower when negative), each keeping its time and velocity; nil
    /// when any would leave the keyboard, or when there is nothing to move.
    public static func transposed(_ notes: [Note], by semitones: Int) -> [Note]? {
        guard !notes.isEmpty, semitones != 0 else { return nil }
        var moved: [Note] = []
        moved.reserveCapacity(notes.count)
        for note in notes {
            let pitch = note.pitch + semitones
            guard Note.pitchRange.contains(pitch) else { return nil }
            var shifted = note
            shifted.pitch = pitch
            moved.append(shifted)
        }
        return moved
    }

    /// Copies of the notes placed right after them: shifted by the span from the earliest start to
    /// the latest end, so a phrase repeats in time. New ids from `newID`; nil when the copy would
    /// not fit inside the clip, or when there is nothing to copy.
    public static func duplicated(_ notes: [Note], in clip: Clip, newID: () -> NoteID = { NoteID() }) -> [Note]? {
        guard let first = notes.map(\.start).min(), let last = notes.map({ $0.start + $0.length }).max(), last > first else {
            return nil
        }
        let span = last - first
        var copies: [Note] = []
        copies.reserveCapacity(notes.count)
        for note in notes.sorted(by: { ($0.start, $0.pitch) < ($1.start, $1.pitch) }) {
            let start = note.start + span
            guard start < clip.length else { return nil }
            copies.append(Note(id: newID(), pitch: note.pitch, velocity: note.velocity, start: start,
                               length: Swift.min(note.length, clip.length - start)))
        }
        return copies
    }

    /// Each note lengthened or shortened to end where the next later start among the chosen notes
    /// begins; notes that start together end together. The last ones keep their length. Only the
    /// notes whose length changes are returned; nil when none would.
    public static func legato(_ notes: [Note]) -> [Note]? {
        let starts = Set(notes.map(\.start)).sorted()
        var changed: [Note] = []
        for note in notes {
            guard let next = starts.first(where: { $0 > note.start }) else { continue }
            let length = next - note.start
            guard length > 0, length != note.length else { continue }
            var joined = note
            joined.length = length
            changed.append(joined)
        }
        return changed.isEmpty ? nil : changed
    }
}
