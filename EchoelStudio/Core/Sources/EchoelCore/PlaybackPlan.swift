/// What the engine plays: the arrangement flattened into sorted note events per track.
///
/// Compiled on the main thread whenever the project changes, then handed to the render
/// thread whole. The render thread only reads it — it never sees a `Project`, never sorts,
/// never allocates. Mixer state (mute, solo, volume) is NOT baked in, so toggling a mute
/// while playing changes the mix without recompiling the notes.
public struct PlaybackPlan: Equatable, Sendable {
    public var tempoMap: TempoMap
    public var tracks: [TrackEvents]
    /// The end of the last note on any track, or 0 for an empty song.
    public var songEnd: Tick

    public struct TrackEvents: Equatable, Sendable {
        public var track: TrackID
        /// Sorted by tick; at equal ticks every note-off comes first, then bends and controllers,
        /// then note-ons — a note that ends where the next one of the same pitch starts
        /// re-triggers cleanly, and a pedal or bend at a note's tick is in place when it sounds.
        public var events: [NoteEvent]
        /// Every clip of the track on its own, in clip time, for launching from the session.
        public var clips: [ClipEvents] = []
    }

    /// One clip as a loop: events in clip time, sorted like a track's, all before `length`.
    public struct ClipEvents: Equatable, Sendable {
        public var clip: ClipID
        public var length: Tick
        public var events: [NoteEvent]
    }

    public struct NoteEvent: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case noteOn(velocity: UInt8)
            case noteOff
            /// A controller 0…119; `pitch` is unused.
            case control(number: UInt8, value: UInt8)
            /// 14-bit, centre 8192; `pitch` is unused.
            case pitchBend(UInt16)
        }

        public var tick: Tick
        public var pitch: UInt8
        public var kind: Kind
    }

    /// Everything `init(compiling:)` reads, and nothing else: the tempo map and each instrument
    /// track's clips and placements, in track order. A fader, a pan, a mute, a send, a rename or
    /// a synth parameter leaves it equal, and an equal source compiles to an equal plan — so the
    /// engine keeps the plan it has instead of compiling the whole song again for every step of
    /// a fader drag (ultra-audit E6). Comparing two is cheap while nothing changed: the arrays
    /// share their storage with the song, and equal storage compares in one step.
    public struct Source: Equatable, Sendable {
        let tempoMap: TempoMap
        let tracks: [TrackSource]

        struct TrackSource: Equatable, Sendable {
            let id: TrackID
            let clips: [Clip]
            let placements: [Placement]
        }

        public init(_ project: Project) {
            tempoMap = project.tempoMap
            tracks = project.tracks.compactMap { track in
                track.kind == .instrument ? TrackSource(id: track.id, clips: track.clips, placements: track.placements) : nil
            }
        }
    }

    public init(compiling project: Project) {
        tempoMap = project.tempoMap
        var end: Tick = 0
        tracks = project.tracks.compactMap { track in
            guard track.kind == .instrument else { return nil }
            let intervals = Self.noteIntervals(of: track)
            end = intervals.reduce(end) { Swift.max($0, $1.end) }
            return TrackEvents(track: track.id, events: Self.events(from: intervals, controls: Self.controls(of: track)),
                               clips: track.clips.map(Self.loop))
        }
        songEnd = end
    }

    /// Index of the first event at or after `tick`, by binary search. Allocation-free, so the
    /// render thread may call it when the playhead jumps.
    public static func firstIndex(in events: [NoteEvent], atOrAfter tick: Tick) -> Int {
        var low = 0
        var high = events.count
        while low < high {
            let mid = (low + high) / 2
            if events[mid].tick < tick { low = mid + 1 } else { high = mid }
        }
        return low
    }

    // MARK: - Compilation

    struct Interval {
        var start: Tick
        var end: Tick
        var pitch: Int
        var velocity: Int
    }

    /// Every note of every placement in song time. A note is cut at its clip's end, as in
    /// any DAW: a placement plays one clip length and no further.
    static func noteIntervals(of track: Track) -> [Interval] {
        var intervals: [Interval] = []
        for placement in track.placements {
            guard let clip = track.clips.first(where: { $0.id == placement.clip }) else { continue }
            for note in clip.notes where note.start < clip.length {
                let end = Swift.min(note.start + note.length, clip.length)
                intervals.append(Interval(start: placement.start + note.start,
                                          end: placement.start + end,
                                          pitch: note.pitch, velocity: note.velocity))
            }
        }
        return resolvingOverlaps(intervals)
    }

    struct Control {
        var tick: Tick
        var kind: NoteEvent.Kind
    }

    /// Every bend and controller of every placement in song time, plus a return to rest — wheel
    /// centred, pedal up — where a placement that moved them ends. The returns come first in the
    /// list, so where a placement ends on the tick the next one starts, the next one's own value
    /// at that tick wins.
    static func controls(of track: Track) -> [Control] {
        var returns: [Control] = []
        var changes: [Control] = []
        for placement in track.placements {
            guard let clip = track.clips.first(where: { $0.id == placement.clip }), !clip.controls.isEmpty else { continue }
            for control in clip.controls where control.start < clip.length {
                changes.append(Control(tick: placement.start + control.start, kind: event(control.kind, control.value)))
            }
            for rest in rests(of: clip) {
                returns.append(Control(tick: placement.start + clip.length, kind: rest))
            }
        }
        return returns + changes
    }

    /// The returns to rest a clip needs, once per kind it moves, in a fixed order.
    static func rests(of clip: Clip) -> [NoteEvent.Kind] {
        var kinds: [ControlChange.Kind] = []
        for control in clip.controls where control.start < clip.length && !kinds.contains(control.kind) {
            kinds.append(control.kind)
        }
        return kinds.compactMap { kind in
            ControlChange(kind: kind, start: 0, value: 0).rest.map { event(kind, $0) }
        }
    }

    static func event(_ kind: ControlChange.Kind, _ value: Int) -> NoteEvent.Kind {
        switch kind {
        case .pitchBend: .pitchBend(UInt16(clamping: Swift.min(Swift.max(value, 0), ControlChange.bendRange.upperBound)))
        case .controller(let number): .control(number: UInt8(clamping: number), value: UInt8(clamping: Swift.min(Swift.max(value, 0), 127)))
        }
    }

    /// A clip's notes in clip time, each cut at the clip's end so the loop never carries a note
    /// into its next pass. A clip that bends or holds the pedal starts every pass from rest.
    static func loop(_ clip: Clip) -> ClipEvents {
        let intervals = clip.notes.compactMap { note -> Interval? in
            guard note.start < clip.length else { return nil }
            return Interval(start: note.start, end: Swift.min(note.start + note.length, clip.length),
                            pitch: note.pitch, velocity: note.velocity)
        }
        let changes = rests(of: clip).map { Control(tick: 0, kind: $0) }
            + clip.controls.filter { $0.start < clip.length }.map { Control(tick: $0.start, kind: event($0.kind, $0.value)) }
        return ClipEvents(clip: clip.id, length: clip.length,
                          events: events(from: resolvingOverlaps(intervals), controls: changes))
    }

    /// One pitch can sound only once on a monophonic MIDI key. Where two notes of the same
    /// pitch overlap (stacked placements, a duplicated note), the earlier one ends where the
    /// later one starts; of two that start together the longer plays and the shorter, swallowed
    /// by it, is dropped. (Until 2026-10-22 the longer was dropped: a take's one-tick remnant
    /// beside a held note played as a click and the held note vanished.)
    static func resolvingOverlaps(_ intervals: [Interval]) -> [Interval] {
        let byPitch = Dictionary(grouping: intervals, by: \.pitch)
        var result: [Interval] = []
        for pitch in byPitch.keys.sorted() {
            let sorted = (byPitch[pitch] ?? []).sorted {
                $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end
            }
            for (i, var interval) in sorted.enumerated() {
                if i + 1 < sorted.count {
                    interval.end = Swift.min(interval.end, sorted[i + 1].start)
                }
                if interval.end > interval.start {
                    result.append(interval)
                }
            }
        }
        return result
    }

    static func events(from intervals: [Interval], controls: [Control] = []) -> [NoteEvent] {
        var events: [NoteEvent] = []
        events.reserveCapacity(intervals.count * 2 + controls.count)
        for interval in intervals {
            events.append(NoteEvent(tick: interval.start, pitch: UInt8(interval.pitch),
                                    kind: .noteOn(velocity: UInt8(interval.velocity))))
            events.append(NoteEvent(tick: interval.end, pitch: UInt8(interval.pitch), kind: .noteOff))
        }
        for control in controls {
            events.append(NoteEvent(tick: control.tick, pitch: 0, kind: control.kind))
        }
        // Controllers keep their list order at one tick (a return to rest before a new value).
        return events.enumerated().sorted { a, b in
            if a.element.tick != b.element.tick { return a.element.tick < b.element.tick }
            if a.element.kind.rank != b.element.kind.rank { return a.element.kind.rank < b.element.kind.rank }
            if a.element.kind.rank == 1 { return a.offset < b.offset }
            return a.element.pitch < b.element.pitch
        }.map(\.element)
    }
}

extension PlaybackPlan.NoteEvent.Kind {
    var isOff: Bool {
        if case .noteOff = self { return true }
        return false
    }

    /// The order at one tick: offs, then bends and controllers, then ons.
    var rank: Int {
        switch self {
        case .noteOff: 0
        case .control, .pitchBend: 1
        case .noteOn: 2
        }
    }
}

/// Converting between musical time and samples, through the project's tempo map.
public struct TimeConversion: Equatable, Sendable {
    public let tempoMap: TempoMap
    public let sampleRate: Double

    public init(tempoMap: TempoMap, sampleRate: Double) {
        self.tempoMap = tempoMap
        self.sampleRate = sampleRate
    }

    /// A constant tempo.
    public init(bpm: Double, sampleRate: Double) {
        self.init(tempoMap: TempoMap(bpm: bpm), sampleRate: sampleRate)
    }

    /// Samples per tick at the tempo sounding at `tick`.
    public func samplesPerTick(at tick: Tick) -> Double {
        sampleRate * 60 / (tempoMap.bpm(at: tick) * Double(MusicalTime.ticksPerQuarter))
    }

    public func seconds(at tick: Tick) -> Double {
        tempoMap.seconds(at: tick)
    }

    /// The sample on which `tick` falls, rounded down, counted from tick 0.
    public func sample(at tick: Tick) -> Int64 {
        Int64((tempoMap.seconds(at: tick) * sampleRate).rounded(.down))
    }

    /// Where `sample` falls in musical time, in fractional ticks.
    public func position(atSample sample: Int64) -> Double {
        tempoMap.position(atSeconds: Double(sample) / sampleRate)
    }

    /// The sample nearest a fractional tick.
    public func sample(atPosition position: Double) -> Int64 {
        let seconds = tempoMap.seconds(atPosition: position)
        guard seconds.isFinite else { return 0 }
        return Int64((seconds * sampleRate).rounded())
    }

    /// The tick that is sounding at `sample`, rounded down.
    public func tick(atSample sample: Int64) -> Tick {
        tempoMap.tick(atSeconds: Double(sample) / sampleRate)
    }
}
