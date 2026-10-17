import Foundation

/// The drum kit's lanes in General MIDI numbering, so a pattern plays the same kit on our own
/// drum device, on an AUv3 drum plugin and on hardware.
public struct DrumLane: Equatable, Sendable, Identifiable {
    public let pitch: Int
    public let name: String
    public var id: Int { pitch }

    public init(pitch: Int, name: String) {
        self.pitch = pitch
        self.name = name
    }

    /// Top to bottom as a step sequencer shows them: the kick at the bottom.
    public static let standardKit: [DrumLane] = [
        DrumLane(pitch: 49, name: "Crash"),
        DrumLane(pitch: 46, name: "Open Hat"),
        DrumLane(pitch: 42, name: "Closed Hat"),
        DrumLane(pitch: 50, name: "High Tom"),
        DrumLane(pitch: 45, name: "Low Tom"),
        DrumLane(pitch: 39, name: "Clap"),
        DrumLane(pitch: 38, name: "Snare"),
        DrumLane(pitch: 36, name: "Kick"),
    ]
}

/// The step sequencer as a VIEW over a clip's notes: a step that is on is a note at the lane's
/// pitch, starting on that step. There is no second store of steps, so the piano roll and the
/// step grid always show the same pattern, and every edit is an ordinary note command.
public enum StepEditing {
    /// Accented and normal hit velocities, as on a classic drum machine.
    public static let normalVelocity = 100
    public static let accentVelocity = 127

    /// How many steps of `step` ticks fit in the clip; never fewer than one.
    public static func stepCount(of clip: Clip, step: Tick) -> Int {
        guard step > 0 else { return 1 }
        return Swift.max(1, Int((clip.length + step - 1) / step))
    }

    /// The note that turns `index` on in `pitch`'s lane: any note of that pitch starting inside
    /// the step counts, so a slightly early or late hit from a recording still shows.
    public static func hit(in clip: Clip, pitch: Int, step index: Int, step: Tick) -> Note? {
        guard step > 0, index >= 0 else { return nil }
        let start = Tick(index) * step
        return clip.notes.first { $0.pitch == pitch && $0.start >= start && $0.start < start + step }
    }

    /// Tapping a step: on clears every hit in it, off adds one hit one step long.
    /// Nil when the step lies outside the clip or the pitch is not a MIDI note.
    public static func toggle(in clip: Clip, pitch: Int, step index: Int, step: Tick,
                              velocity: Int = normalVelocity) -> Command? {
        guard Note.pitchRange.contains(pitch), step > 0, index >= 0 else { return nil }
        let start = Tick(index) * step
        guard start < clip.length else { return nil }
        let hits = clip.notes.filter { $0.pitch == pitch && $0.start >= start && $0.start < start + step }
        if !hits.isEmpty {
            return .removeNotes(clip.id, hits.map(\.id))
        }
        let v = Swift.min(Swift.max(velocity, Note.velocityRange.lowerBound), Note.velocityRange.upperBound)
        let length = Swift.max(1, Swift.min(step, clip.length - start))
        return .addNotes(clip.id, [Note(pitch: pitch, velocity: v, start: start, length: length)])
    }

    /// Flips an existing hit between normal and accented. Nil when the step is off.
    public static func toggleAccent(in clip: Clip, pitch: Int, step index: Int, step: Tick) -> Command? {
        guard var note = hit(in: clip, pitch: pitch, step: index, step: step) else { return nil }
        note.velocity = note.velocity >= accentVelocity ? normalVelocity : accentVelocity
        return .updateNotes(clip.id, [note])
    }

    /// Clears one lane of the pattern. Nil when it is already empty.
    public static func clearLane(in clip: Clip, pitch: Int) -> Command? {
        let ids = clip.notes.filter { $0.pitch == pitch }.map(\.id)
        return ids.isEmpty ? nil : .removeNotes(clip.id, ids)
    }
}
