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
        /// Sorted by tick; at equal ticks every note-off comes before any note-on, so a note
        /// that ends where the next one of the same pitch starts re-triggers cleanly.
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
        }

        public var tick: Tick
        public var pitch: UInt8
        public var kind: Kind
    }

    public init(compiling project: Project) {
        tempoMap = project.tempoMap
        var end: Tick = 0
        tracks = project.tracks.compactMap { track in
            guard track.kind == .instrument else { return nil }
            let intervals = Self.noteIntervals(of: track)
            end = intervals.reduce(end) { Swift.max($0, $1.end) }
            return TrackEvents(track: track.id, events: Self.events(from: intervals),
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

    /// A clip's notes in clip time, each cut at the clip's end so the loop never carries a note
    /// into its next pass.
    static func loop(_ clip: Clip) -> ClipEvents {
        let intervals = clip.notes.compactMap { note -> Interval? in
            guard note.start < clip.length else { return nil }
            return Interval(start: note.start, end: Swift.min(note.start + note.length, clip.length),
                            pitch: note.pitch, velocity: note.velocity)
        }
        return ClipEvents(clip: clip.id, length: clip.length, events: events(from: resolvingOverlaps(intervals)))
    }

    /// One pitch can sound only once on a monophonic MIDI key. Where two notes of the same
    /// pitch overlap (stacked placements, a duplicated note), the earlier one ends where the
    /// later one starts; a note swallowed entirely by a same-start twin is dropped.
    static func resolvingOverlaps(_ intervals: [Interval]) -> [Interval] {
        let byPitch = Dictionary(grouping: intervals, by: \.pitch)
        var result: [Interval] = []
        for pitch in byPitch.keys.sorted() {
            let sorted = (byPitch[pitch] ?? []).sorted {
                $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end
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

    static func events(from intervals: [Interval]) -> [NoteEvent] {
        var events: [NoteEvent] = []
        events.reserveCapacity(intervals.count * 2)
        for interval in intervals {
            events.append(NoteEvent(tick: interval.start, pitch: UInt8(interval.pitch),
                                    kind: .noteOn(velocity: UInt8(interval.velocity))))
            events.append(NoteEvent(tick: interval.end, pitch: UInt8(interval.pitch), kind: .noteOff))
        }
        events.sort { a, b in
            if a.tick != b.tick { return a.tick < b.tick }
            if a.kind.isOff != b.kind.isOff { return a.kind.isOff }
            return a.pitch < b.pitch
        }
        return events
    }
}

extension PlaybackPlan.NoteEvent.Kind {
    var isOff: Bool {
        if case .noteOff = self { return true }
        return false
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
