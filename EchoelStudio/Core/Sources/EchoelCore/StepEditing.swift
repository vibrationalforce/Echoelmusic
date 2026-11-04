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

    // MARK: Euclidean rhythms (ECHOELTOOLS A12)

    /// The longest Euclidean cycle, in steps: four bars of sixteenths.
    public static let euclideanSteps = 1...64

    /// `hits` onsets spread as evenly as `steps` allow — Toussaint's Euclidean rhythms (3 over 8
    /// is the tresillo `x..x..x.`, 5 over 8 the cinquillo's necklace) — starting on a hit, then
    /// turned `rotation` steps later (a negative rotation turns it earlier). Step `i` is a hit
    /// when `i · hits mod steps < hits`, the Bresenham form of Bjorklund's algorithm: the same
    /// necklace, no recursion, no allocation beyond the result. Nil when `steps` is outside
    /// `euclideanSteps` or `hits` outside 0…`steps`. It is a pattern tool, not a voice: it only
    /// says which steps play.
    public static func euclidean(hits: Int, steps: Int, rotation: Int = 0) -> [Bool]? {
        guard euclideanSteps.contains(steps), (0...steps).contains(hits) else { return nil }
        // Reduced first, so no model- or menu-given number can overflow the subtraction below.
        let turn = ((rotation % steps) + steps) % steps
        return (0..<steps).map { index in
            let source = (index - turn + steps) % steps
            return (source * hits) % steps < hits
        }
    }

    /// Fills `pitch`'s lane with a Euclidean rhythm of `step`-long steps, repeated over the whole
    /// clip, and clears what the lane held — one command list, so it is one undo step. The other
    /// lanes stay. Nil when the rhythm or the pitch is out of range, or nothing would change.
    public static func euclid(in clip: Clip, pitch: Int, hits: Int, steps: Int, rotation: Int = 0,
                              step: Tick, velocity: Int = normalVelocity) -> [Command]? {
        guard Note.pitchRange.contains(pitch), step > 0,
              let pattern = euclidean(hits: hits, steps: steps, rotation: rotation) else { return nil }
        let v = Swift.min(Swift.max(velocity, Note.velocityRange.lowerBound), Note.velocityRange.upperBound)
        var notes: [Note] = []
        var start: Tick = 0, index = 0
        while start < clip.length {
            if pattern[index % pattern.count] {
                notes.append(Note(pitch: pitch, velocity: v, start: start, length: Swift.min(step, clip.length - start)))
            }
            start += step
            index += 1
        }
        let old = clip.notes.filter { $0.pitch == pitch }
        let same = old.map { [$0.start, Tick($0.velocity)] }.sorted { $0.lexicographicallyPrecedes($1) }
            == notes.map { [$0.start, Tick($0.velocity)] }
        if same { return nil }
        var commands: [Command] = []
        if !old.isEmpty { commands.append(.removeNotes(clip.id, old.map(\.id))) }
        if !notes.isEmpty { commands.append(.addNotes(clip.id, notes)) }
        return commands.isEmpty ? nil : commands
    }

    /// Turns one lane by `steps` steps of `step` ticks — later for a positive number — wrapping
    /// round the clip, so a Euclidean rhythm (or any lane) can start elsewhere in its cycle.
    /// Nil when the lane is empty or the turn is a whole cycle.
    public static func rotateLane(in clip: Clip, pitch: Int, by steps: Int, step: Tick) -> Command? {
        guard step > 0, clip.length > 0 else { return nil }
        let lane = clip.notes.filter { $0.pitch == pitch }
        guard !lane.isEmpty else { return nil }
        let span = clip.length
        // Reduced to one cycle first: a turn far past the clip cannot overflow the multiply.
        let count = Tick(stepCount(of: clip, step: step))
        let turn = ((Tick(steps) % count) + count) % count
        let shift = (turn * step) % span
        guard shift != 0 else { return nil }
        let moved = lane.map { note -> Note in
            var copy = note
            copy.start = (note.start + shift) % span
            copy.length = Swift.max(1, Swift.min(note.length, span - copy.start))
            return copy
        }
        return .updateNotes(clip.id, moved)
    }
}
