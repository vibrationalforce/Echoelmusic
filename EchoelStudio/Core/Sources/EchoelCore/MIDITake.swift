/// Notes played live while recording, collected into what becomes one clip. Note-on and
/// note-off arrive with the song position they were played at; a key still held when the take
/// stops ends there, a key struck again while it sounds ends the earlier note first. The wheel
/// and the controllers played along are kept with them.
public struct MIDITake: Sendable {
    private var open: [Int: (start: Tick, velocity: Int)] = [:]
    private(set) var notes: [Note] = []
    private(set) var controls: [ControlChange] = []

    public init() {}

    public var isEmpty: Bool { notes.isEmpty && open.isEmpty && controls.isEmpty }

    /// A pitch bend (0…16383) or a controller (0…119); anything else is not kept.
    public mutating func control(_ kind: ControlChange.Kind, value: Int, at tick: Tick) {
        let change = ControlChange(kind: kind, start: Swift.max(0, tick), value: value)
        guard change.isValid else { return }
        controls.append(change)
    }

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
    /// as long as whole bars reaching past its last; the notes and controls in clip time. Nil
    /// when no note was played. Keys still held end at `end`. A wheel or pedal moved before the
    /// clip begins is set at its start, to the value it had then; a move after its end is dropped.
    public func clip(endingAt end: Tick, bar: Tick) -> (start: Tick, length: Tick, notes: [Note], controls: [ControlChange])? {
        var take = self
        for pitch in take.open.keys.sorted() { take.noteOff(pitch: pitch, at: end) }
        guard bar > 0, let first = take.notes.map(\.start).min() else { return nil }
        let start = first / bar * bar
        let last = take.notes.map { $0.start + $0.length }.max() ?? first
        let length = Swift.min(Swift.max(bar, (last - start + bar - 1) / bar * bar), MusicalTime.maximumTick)
        let notes = take.notes
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
            .map { Note(pitch: $0.pitch, velocity: $0.velocity, start: $0.start - start, length: $0.length) }
        return (start, length, notes, Self.controls(take.controls, from: start, length: length))
    }

    static func controls(_ played: [ControlChange], from start: Tick, length: Tick) -> [ControlChange] {
        let ordered = played.enumerated()
            .sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
            .map(\.element)
        var before: [ControlChange.Kind: Int] = [:]
        var kinds: [ControlChange.Kind] = []
        var inside: [ControlChange] = []
        for change in ordered {
            if change.start < start {
                if before[change.kind] == nil { kinds.append(change.kind) }
                before[change.kind] = change.value
            } else if change.start - start < length {
                inside.append(ControlChange(kind: change.kind, start: change.start - start, value: change.value))
            }
        }
        let carried = kinds.compactMap { kind in before[kind].map { ControlChange(kind: kind, start: 0, value: $0) } }
        return carried + inside
    }
}
