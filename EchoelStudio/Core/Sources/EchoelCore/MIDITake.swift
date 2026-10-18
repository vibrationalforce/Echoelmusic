/// Notes played live while recording, collected into what becomes one clip. Note-on and
/// note-off arrive with the song position they were played at; a key still held when the take
/// stops ends there, a key struck again while it sounds ends the earlier note first.
public struct MIDITake: Sendable {
    private var open: [Int: (start: Tick, velocity: Int)] = [:]
    private(set) var notes: [Note] = []

    public init() {}

    public var isEmpty: Bool { notes.isEmpty && open.isEmpty }

    public mutating func noteOn(pitch: Int, velocity: Int, at tick: Tick) {
        guard Note.pitchRange.contains(pitch) else { return }
        guard velocity > 0 else { return noteOff(pitch: pitch, at: tick) }
        if open[pitch] != nil { noteOff(pitch: pitch, at: tick) }
        open[pitch] = (Swift.max(0, tick), Swift.min(Swift.max(velocity, Note.velocityRange.lowerBound),
                                                    Note.velocityRange.upperBound))
    }

    public mutating func noteOff(pitch: Int, at tick: Tick) {
        guard let held = open.removeValue(forKey: pitch) else { return }
        notes.append(Note(pitch: pitch, velocity: held.velocity, start: held.start,
                          length: Swift.max(1, tick - held.start)))
    }

    /// What the take becomes: a clip placed on the bar line at or before the take's first note,
    /// as long as whole bars reaching past its last; the notes in clip time. Nil when no note
    /// was played. Keys still held end at `end`.
    public func clip(endingAt end: Tick, bar: Tick) -> (start: Tick, length: Tick, notes: [Note])? {
        var take = self
        for pitch in take.open.keys.sorted() { take.noteOff(pitch: pitch, at: end) }
        guard bar > 0, let first = take.notes.map(\.start).min() else { return nil }
        let start = first / bar * bar
        let last = take.notes.map { $0.start + $0.length }.max() ?? first
        let length = Swift.min(Swift.max(bar, (last - start + bar - 1) / bar * bar), MusicalTime.maximumTick)
        let notes = take.notes
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
            .map { Note(pitch: $0.pitch, velocity: $0.velocity, start: $0.start - start, length: $0.length) }
        return (start, length, notes)
    }
}
