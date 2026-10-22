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
        let length = Swift.max(1, Swift.min(grid, clip.length - start))
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
}
