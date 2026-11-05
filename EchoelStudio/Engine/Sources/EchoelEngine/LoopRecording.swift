import EchoelCore
import Foundation

/// Loop record (2026-11-04): while the song loops, a take keeps recording through every wrap, and
/// each pass of the loop becomes a take of its own in the track's take folder, the newest one
/// sounding (`Command.foldTake`). Pure, so the cutting is tested here, apart from the audio.
///
/// Time comes from two clocks of the render thread. The playhead (`EngineCore.positionSample`)
/// jumps back at each wrap; `EngineCore.playedFrames` never jumps, and the core reports it at each
/// wrap (`takeLoopWraps`). An audio take is one file written without a break: its passes are
/// regions of that one file at different offsets — no new file, no gap in the writing. A MIDI take
/// is cut into one clip per pass.
public enum LoopRecording {
    /// The shortest loop a take is cut into passes over. A song's loop is not set by the musician:
    /// it runs from bar 1 to the end of the song's last bar (`Arranging.songLoop`), and a new, empty
    /// song loops ONE bar. A take on that is a first recording, not a loop record — it runs freely
    /// (an audio take suspends the loop, a MIDI take overdubs into one clip, as before). From two
    /// bars on there is a part to record passes over.
    public static let minimumBars = 2

    /// Whether a take over `loop` is cut into passes: the loop spans `minimumBars` bars at least.
    public static func recordsPasses(over loop: Range<Tick>?, meter: MeterMap) -> Bool {
        guard let loop else { return false }
        var end = loop.lowerBound
        for _ in 0..<minimumBars { end += meter.ticksPerBar(at: Swift.max(0, end)) }
        return loop.upperBound >= end
    }

    /// Whether the song's loop runs: while it is on, except under an audio take over a loop too
    /// short to record passes over (that take runs freely), and except while the sender of a
    /// timecode chase runs. The sender is the master then: a wrap at the loop's end threw the song
    /// off it, the chase jumped back onto the sender, the loop threw it off again — at every quarter
    /// frame, and the chase never locked (2026-11-05).
    public static func loopRuns(isOn: Bool, audioTake: Bool, over loop: Range<Tick>?, meter: MeterMap,
                                timecodeRuns: Bool) -> Bool {
        isOn && !timecodeRuns && (!audioTake || recordsPasses(over: loop, meter: meter))
    }

    /// Whether a take started now is cut into passes of the loop: it runs and spans enough bars.
    public static func takeRecordsPasses(isOn: Bool, over loop: Range<Tick>?, meter: MeterMap,
                                         timecodeRuns: Bool) -> Bool {
        isOn && !timecodeRuns && recordsPasses(over: loop, meter: meter)
    }

    /// A pass shorter than a quarter of a bar — Stop pressed just after the loop came round, or
    /// Record just before it did — is no take, and is dropped.
    public static func isTooShort(_ span: Range<Tick>, meter: MeterMap) -> Bool {
        span.upperBound - span.lowerBound < meter.ticksPerBar(at: Swift.max(0, span.lowerBound)) / 4
    }

    /// A moment of a take on both clocks: the playhead and the played frames, read together.
    public struct Moment: Equatable, Sendable {
        public var sample: Int64
        public var played: Int64

        public init(sample: Int64, played: Int64) {
            self.sample = sample
            self.played = played
        }
    }

    /// The loop a take ran over, in samples of the take's time, and where it wrapped.
    public struct Passes: Equatable, Sendable {
        public let loopStart: Int64
        public let loopEnd: Int64
        /// `playedFrames` at each wrap, rising.
        public let wraps: [Int64]

        public init(loop: Range<Tick>, wraps: [Int64], time: TimeConversion) {
            loopStart = time.sample(at: loop.lowerBound)
            loopEnd = Swift.max(time.sample(at: loop.upperBound), loopStart + 1)
            self.wraps = wraps.sorted()
        }

        /// How many wraps came at or before `played`: the pass that moment is in.
        func pass(at played: Int64) -> Int {
            wraps.lazy.filter { $0 <= played }.count
        }

        /// Where the sound played at `moment` was heard — `latency` samples earlier — as its pass
        /// and its playhead sample. The first pass reads the playhead, as a take without a loop
        /// does; once a wrap lies between, the played frames say where, since the playhead has
        /// jumped. A later pass starts on the loop's start at its wrap and never leaves the loop.
        public func locate(_ moment: Moment, latency: Int64) -> (pass: Int, sample: Int64) {
            let lag = Swift.max(0, latency)
            let heard = moment.played - lag
            let index = pass(at: heard)
            if index == 0 {
                guard pass(at: moment.played) > 0, let first = wraps.first else {
                    return (0, Swift.max(0, moment.sample - lag))
                }
                return (0, Swift.max(0, loopEnd - (first - heard)))
            }
            let into = heard - wraps[index - 1]
            return (index, loopStart + Swift.min(Swift.max(0, into), loopEnd - loopStart - 1))
        }
    }

    // MARK: - Audio

    /// One pass of an audio take: a region of the take's file.
    public struct AudioPass: Equatable, Sendable {
        public var start: Tick
        public var offset: Int
        public var length: Int
    }

    /// The regions an audio take of `frameCount` frames becomes. Its first frame came in while the
    /// playhead stood at `startSample` and the played frames at `startPlayed`; `latency` is output
    /// plus input. Without a wrap it is one region, placed as every take is (`RecordingPlacement`).
    /// With wraps, file frame `wrap − startPlayed + latency` was heard on the loop's start, so each
    /// pass is the stretch of the file between two of them: the first from where the take began,
    /// each later one on the loop's start. A pass shorter than a quarter bar is dropped.
    public static func audioPasses(frameCount: Int, startSample: Int64, startPlayed: Int64, latency: Int64,
                                   wraps: [Int64], loop: Range<Tick>?, time: TimeConversion,
                                   meter: MeterMap) -> [AudioPass] {
        let placement = RecordingPlacement.place(startSample: startSample, latency: latency, time: time)
        let later = wraps.filter { $0 > startPlayed }.sorted()
        guard let loop, recordsPasses(over: loop, meter: meter), !later.isEmpty else {
            guard frameCount > placement.offset else { return [] }
            return [AudioPass(start: placement.start, offset: placement.offset, length: frameCount - placement.offset)]
        }
        let passes = Passes(loop: loop, wraps: later, time: time)
        let loopLength = passes.loopEnd - passes.loopStart
        let lag = Swift.max(0, latency)
        let cuts = later.map { (wrap: Int64) -> Int in
            Int(Swift.min(Swift.max(0, wrap - startPlayed + lag), Int64(frameCount)))
        }
        var result: [AudioPass] = []
        func keep(start: Tick, from first: Int, to last: Int, longest: Int64) {
            let length = Int(Swift.min(Int64(last - first), Swift.max(0, longest)))
            guard length > 0 else { return }
            let end = time.tick(atSample: time.sample(at: start) + Int64(length))
            guard !isTooShort(start..<Swift.max(start, end), meter: meter) else { return }
            result.append(AudioPass(start: start, offset: first, length: length))
        }
        if let cut = cuts.first, cut > placement.offset {
            keep(start: placement.start, from: placement.offset, to: cut,
                 longest: passes.loopEnd - time.sample(at: placement.start))
        }
        for (i, cut) in cuts.enumerated() {
            let next = i + 1 < cuts.count ? cuts[i + 1] : frameCount
            keep(start: loop.lowerBound, from: cut, to: next, longest: loopLength)
        }
        return result
    }

    /// The commands that put `passes` of the take file `media` on `track`, oldest first, each folded
    /// with the takes before it, so the newest sounds over its span. With `addMedia` first and in
    /// one `perform`, one undo step.
    public static func audioCommands(_ passes: [AudioPass], media: MediaFile, track: TrackID) -> [Command] {
        var commands: [Command] = []
        for pass in passes {
            let region = RegionID()
            commands.append(.placeAudio(track: track, id: region, media: media.id, start: pass.start))
            if pass.offset > 0 || pass.length != media.frameCount {
                commands.append(.trimRegion(track: track, region, offset: pass.offset, length: pass.length))
            }
            commands.append(.foldTake(track: track, take: region.rawValue, group: TakeGroupID()))
        }
        return commands
    }

    // MARK: - MIDI

    /// A message played while a MIDI take recorded, at the moment it was played.
    public struct Event: Equatable, Sendable {
        public var moment: Moment
        public var status: UInt8
        public var data1: UInt8
        public var data2: UInt8

        public init(moment: Moment, status: UInt8, data1: UInt8, data2: UInt8) {
            self.moment = moment
            self.status = status
            self.data1 = data1
            self.data2 = data2
        }
    }

    /// One pass of a MIDI take: a clip, in song time.
    public struct MIDIPass: Equatable, Sendable {
        public var start: Tick
        public var length: Tick
        public var notes: [Note]
        public var controls: [ControlChange]
    }

    /// The clips a MIDI take becomes, one per pass that holds a note, oldest first. Each note sits
    /// where it was heard (`latency`, the output latency, taken off) in the pass it was heard in; a
    /// key held across a wrap ends at the loop's end. Without a wrap it is the one clip a take has
    /// always been. A pass shorter than a quarter bar is dropped.
    public static func midiPasses(_ events: [Event], from start: Moment, to end: Moment, wraps: [Int64],
                                  loop: Range<Tick>?, latency: Int64, time: TimeConversion,
                                  meter: MeterMap) -> [MIDIPass] {
        let later = wraps.filter { $0 > start.played }.sorted()
        let span = loop ?? 0..<1
        let looped = recordsPasses(over: loop, meter: meter) && !later.isEmpty
        let passes = Passes(loop: span, wraps: looped ? later : [], time: time)
        func tick(_ sample: Int64) -> Tick { time.tick(atSample: Swift.max(0, sample)) }
        var takes: [Int: MIDITake] = [:]
        for event in events {
            let (pass, sample) = passes.locate(event.moment, latency: latency)
            let at = tick(sample)
            var take = takes[pass] ?? MIDITake()
            switch event.status & 0xF0 {
            case 0x90 where event.data2 > 0: take.noteOn(pitch: Int(event.data1), velocity: Int(event.data2), at: at)
            case 0x80, 0x90: take.noteOff(pitch: Int(event.data1), at: at)
            case 0xE0: take.control(.pitchBend, value: Int(event.data1 & 0x7F) | Int(event.data2 & 0x7F) << 7, at: at)
            case 0xB0: take.control(.controller(number: Int(event.data1)), value: Int(event.data2), at: at)
            default: break
            }
            takes[pass] = take
        }
        let last = passes.locate(end, latency: latency)
        let first = passes.locate(start, latency: latency)
        var result: [MIDIPass] = []
        for pass in takes.keys.sorted() {
            guard let take = takes[pass] else { continue }
            let stop: Tick
            if !looped {
                stop = tick(last.sample)
            } else {
                let from = pass == 0 ? tick(first.sample) : span.lowerBound
                stop = pass >= last.pass ? tick(last.sample) : span.upperBound
                guard !isTooShort(from..<Swift.max(from, stop), meter: meter) else { continue }
            }
            guard let clip = take.clip(endingAt: stop, meter: meter) else { continue }
            result.append(MIDIPass(start: clip.start, length: clip.length, notes: clip.notes, controls: clip.controls))
        }
        return result
    }

    /// The commands that put `passes` on `track` as clips named "Take n", n from `firstNumber`,
    /// oldest first, each folded with the takes before it. In one `perform`, one undo step.
    public static func midiCommands(_ passes: [MIDIPass], track: TrackID, firstNumber: Int) -> [Command] {
        var commands: [Command] = []
        for (i, pass) in passes.enumerated() {
            let clip = ClipID(), placement = PlacementID()
            commands += [.createClip(track: track, id: clip, name: "Take \(firstNumber + i)", length: pass.length),
                         .addNotes(clip, pass.notes),
                         .setControls(clip, pass.controls),
                         .placeClip(track: track, id: placement, clip: clip, start: pass.start),
                         .foldTake(track: track, take: placement.rawValue, group: TakeGroupID())]
        }
        return commands
    }

    // MARK: - Room in the folder

    /// How many new takes a folder over `span` on `track` can still take: a folder holds at most
    /// `TakeGroup.maximumTakes`, and every take already there over the span joins it. At least one,
    /// so the newest pass is always kept.
    public static func room(on track: Track, in project: Project, over span: Range<Tick>) -> Int {
        let ids: [UUID] = switch track.kind {
        case .audio: track.regions.map(\.id.rawValue)
        case .instrument: track.placements.map(\.id.rawValue)
        case .returnTrack, .video: []
        }
        let there = ids.filter { project.takeSpan($0, on: track)?.overlaps(span) == true }.count
        return Swift.max(1, TakeGroup.maximumTakes - there)
    }

    /// The newest `room` of `passes`: a loop that ran longer than a folder holds keeps its last.
    public static func newest<Pass>(_ passes: [Pass], room: Int) -> [Pass] {
        Array(passes.suffix(Swift.max(1, room)))
    }
}
