import EchoelCore
import EchoelKernels
import Foundation
import Synchronization

/// One stereo delay line of plugin delay compensation (WS-PDC): a ring of exactly `delay` frames
/// per side, so what leaves it went in `delay` frames before — at any block size, sample by sample.
///
/// Threading: made, sized and freed on the main thread, with the snapshot it belongs to
/// (`CompensationLines`); `delay` is read there too. Everything else runs on the render thread
/// only, and allocates nothing.
final class DelayLine: @unchecked Sendable {
    /// Frames between input and output, at least 1.
    let delay: Int
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    /// Where the oldest frame sits, the one that leaves next.
    private var cursor = 0
    /// Silent frames that went in since the last one that sounded, up to `delay`: at `delay`
    /// the line holds silence and nothing it holds is still to be heard.
    private var quiet: Int

    init(delay: Int) {
        let frames = Swift.max(1, delay)
        self.delay = frames
        left = .allocate(capacity: frames)
        left.initialize(repeating: 0, count: frames)
        right = .allocate(capacity: frames)
        right.initialize(repeating: 0, count: frames)
        quiet = frames
    }

    deinit {
        left.deallocate()
        right.deallocate()
    }

    /// Holds nothing that is still to be heard.
    var isDrained: Bool { quiet >= delay }

    /// Render thread: replaces `frames` of the pair with what went in `delay` frames before.
    func process(left sourceLeft: UnsafeMutablePointer<Float>, right sourceRight: UnsafeMutablePointer<Float>,
                 frames: Int) {
        guard frames > 0 else { return }
        var at = cursor
        var silent = quiet
        for i in 0..<frames {
            let inLeft = sourceLeft[i], inRight = sourceRight[i]
            sourceLeft[i] = left[at]
            sourceRight[i] = right[at]
            left[at] = inLeft
            right[at] = inRight
            silent = inLeft == 0 && inRight == 0 ? Swift.min(silent + 1, delay) : 0
            at += 1
            if at == delay { at = 0 }
        }
        cursor = at
        quiet = silent
    }

    /// Render thread, while a snapshot is taken up: the newest frames `other` holds — as many as
    /// both lines take, and at most `budget` — become this line's newest, and anything older is
    /// silence, so a lane whose delay changes plays on from what it held instead of falling silent
    /// for the whole new delay. Returns the frames it copied. Two copies at most, no per-frame
    /// work: a line only ever takes over while it is new, and a new line is already silence.
    @discardableResult
    func takeOver(_ other: DelayLine, upTo budget: Int = .max) -> Int {
        guard other !== self else { return 0 }
        let kept = Swift.max(0, Swift.min(delay, other.delay, budget))
        let older = delay - kept
        // A drained line holds only silence already (it holds exactly its last `delay` inputs).
        if !isDrained {
            left.update(repeating: 0, count: older)
            right.update(repeating: 0, count: older)
        }
        if kept > 0 {
            var start = other.cursor - kept
            if start < 0 { start += other.delay }
            let first = Swift.min(kept, other.delay - start)
            (left + older).update(from: other.left + start, count: first)
            (right + older).update(from: other.right + start, count: first)
            if first < kept {
                (left + older + first).update(from: other.left, count: kept - first)
                (right + older + first).update(from: other.right, count: kept - first)
            }
        }
        cursor = 0
        // Silent through every kept frame: the silence before them is silent too.
        quiet = other.quiet >= kept ? delay : other.quiet
        return kept
    }
}

/// The engine-wide clock of a change of waits while a live core plays (SIM76-D1): every place
/// whose wait changes (`PathSwitch`) holds its old path while the new one fills, then all of them
/// glide together over `rampFrames` on a raised cosine, so every lane crosses on the same sample.
/// Render thread only.
struct Crossover: Sendable, Equatable {
    /// 5.3 ms at 48 kHz.
    static let rampFrames = 256

    enum Phase: Sendable, Equatable {
        case idle
        /// Frames left before the glide begins.
        case holding(Int)
        /// Frames of the glide already played.
        case ramping(Int)
    }

    /// Within the next chunk: the old path alone until `holdEnd`, the glide until `rampEnd`
    /// (beginning at step `start` of the ramp), the new path alone after it.
    struct Window: Sendable, Equatable {
        let holdEnd: Int
        let rampEnd: Int
        let start: Int
    }

    private(set) var phase: Phase = .idle

    var isIdle: Bool { phase == .idle }

    var isRamping: Bool {
        if case .ramping = phase { return true }
        return false
    }

    /// The ramp's gain at `step` (0 ..< `rampFrames`): a raised cosine, flat at both ends, so
    /// neither end of the glide has a kink. 0 before the first step, 1 after the last.
    static func gain(_ step: Int) -> Float {
        guard step >= 0 else { return 0 }
        guard step < rampFrames else { return 1 }
        return Float(0.5 - 0.5 * Foundation.cos(Double.pi * (Double(step) + 0.5) / Double(rampFrames)))
    }

    /// Hold the old paths at least `frames` more before the glide; a hold already running keeps
    /// the longer of the two. Never called while ramping: no snapshot is taken up then.
    mutating func hold(atLeast frames: Int) {
        switch phase {
        case .idle: phase = .holding(Swift.max(0, frames))
        case .holding(let left): phase = .holding(Swift.max(left, Swift.max(0, frames)))
        case .ramping: break
        }
    }

    /// Every change that was holding was undone before anyone heard it.
    mutating func end() { phase = .idle }

    func window(frames: Int) -> Window {
        switch phase {
        case .idle: return Window(holdEnd: 0, rampEnd: 0, start: 0)
        case .holding(let left):
            return Window(holdEnd: Swift.min(left, frames), rampEnd: Swift.min(left + Self.rampFrames, frames), start: 0)
        case .ramping(let done):
            return Window(holdEnd: 0, rampEnd: Swift.min(Self.rampFrames - done, frames), start: done)
        }
    }

    /// After a chunk of `frames`: true when the glide ended in it.
    mutating func advance(_ frames: Int) -> Bool {
        switch phase {
        case .idle:
            return false
        case .holding(let left):
            if frames < left {
                phase = .holding(left - frames)
                return false
            }
            let into = frames - left
            if into >= Self.rampFrames {
                phase = .idle
                return true
            }
            phase = .ramping(into)
            return false
        case .ramping(let done):
            if done + frames >= Self.rampFrames {
                phase = .idle
                return true
            }
            phase = .ramping(done + frames)
            return false
        }
    }
}

/// What a `PathSwitch` crosses between: a delay line of the compensation, or a latent insert of
/// a chain (an effect that plays its output behind its input). Nil is the input as it is.
enum PathStep: Sendable {
    case line(DelayLine)
    case unit(any HostedProcessor)

    var line: DelayLine? {
        if case .line(let line) = self { return line }
        return nil
    }

    /// Render thread: the pair through this step, in place.
    func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        switch self {
        case .line(let line): line.process(left: left, right: right, frames: frames)
        case .unit(let unit): unit.process(frames: frames, left: left, right: right)
        }
    }

    /// The same object, or both none.
    static func same(_ a: PathStep?, _ b: PathStep?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (.line(let x)?, .line(let y)?): return x === y
        case (.unit(let x)?, .unit(let y)?): return x === y
        default: return false
        }
    }
}

/// One step of an insert chain while a latent insert arrives, leaves or is replaced as a live core
/// plays (SIM76-D1): an insert as it always plays, or the switch at the place one comes or goes.
enum ChainStep: Sendable {
    case unit(any HostedProcessor)
    case slot(PathSwitch)
}

/// One place whose wait changes while a live core plays (SIM76-D1): the line it played (or none,
/// the input as it is) and the line it plays now (or none). While the `Crossover` holds, the place
/// plays its old path exactly and the new line fills with what comes in; then the two cross on the
/// ramp; after it, the new path exactly. Without it, a new line started as silence and a line that
/// went away skipped what it held: a step in the middle of the song.
///
/// Two switches in series on one lane in one crossover (its `pre` and `direct` waits, a track's
/// `pre` and the `back` of a return its send feeds, or a latent insert arriving on a chain whose
/// lane's wait changes too) are click-free but not exact: the downstream
/// new line fills during the hold with the upstream OLD path, so after the shared glide the lane
/// plays a mixed alignment for the downstream new delay, then glides once more as the upstream
/// glide comes out of the downstream line.
///
/// Threading: made on the main thread with its snapshot's lines; `new`, `settledOld` and
/// `predecessor` are read there too. Armed and played on the render thread, which alone touches
/// `old`, `isArmed` and `isSame`; `settled` tells the next snapshot's build that the glide is over.
final class PathSwitch: @unchecked Sendable {
    /// What the place plays once the glide is over: the snapshot's own line or insert there, or
    /// nil.
    let new: PathStep?
    /// What the snapshot before this one plays at the place, when the crossover was idle.
    let settledOld: PathStep?
    /// The switch at the same place in the snapshot before, while that one had not settled: an
    /// index into its `switches`, or -1.
    let predecessor: Int
    /// Frames a new insert plays before its output is real sound (`warmUp(for:)`); 0 for a line,
    /// which counts what it holds instead.
    let warmUp: Int
    /// Main thread only: for an insert that leaves, the insert it sat before in the old chain (nil
    /// at the chain's end), so a later edit carries it on at its place.
    let anchor: ObjectIdentifier?
    /// Main thread only: every insert the old path may play when this switch is armed — its own
    /// `settledOld`, or what a predecessor it cancels played — so a program never runs one twice.
    let possibleOld: [ObjectIdentifier]
    /// Render → main: the crossover this switch played in is over.
    let settled = Atomic<Bool>(false)

    // Render thread only.
    private var old: PathStep?
    private var isArmed = false
    private var isSame = false

    init(step new: PathStep?, settledOld: PathStep?, predecessor: Int, warmUp: Int = 0,
         anchor: ObjectIdentifier? = nil, inherits before: PathSwitch? = nil) {
        self.new = new
        self.settledOld = settledOld
        self.predecessor = predecessor
        self.warmUp = Swift.max(0, warmUp)
        self.anchor = anchor
        var possible: [ObjectIdentifier] = before?.possibleOld ?? []
        if case .unit(let unit)? = settledOld { possible.append(ObjectIdentifier(unit)) }
        possibleOld = possible
    }

    /// A place of the compensation: one line for another.
    convenience init(new: DelayLine?, settledOld: DelayLine?, predecessor: Int) {
        self.init(step: new.map { PathStep.line($0) }, settledOld: settledOld.map { PathStep.line($0) },
                  predecessor: predecessor)
    }

    /// How long a latent insert that arrives while playing is held behind the old path: its
    /// latency (bounded as the compensation bounds it), and as much again up to a tenth of a
    /// second, so filters and a tape's sway have settled before anyone hears it. Main thread.
    static func warmUp(for unit: any HostedProcessor) -> Int {
        let latency = Swift.min(Swift.max(0, unit.latencyFrames), DelayCompensation.maximumUnitLatency)
        return latency + Swift.min(latency, PluginLatency.frames(seconds: 0.1, sampleRate: unit.sampleRate))
    }

    /// Render thread: still crossing.
    var isLive: Bool { isArmed && !isSame && !settled.load(ordering: .relaxed) }

    /// Render thread, while its snapshot is taken up: the path it leaves is what was heard at the
    /// place — the predecessor's old path when the crossover still holds (its new line was never
    /// heard, so that edit is dropped unheard), else what the snapshot before played. The new line
    /// takes over what the old one holds, within `budget`. Returns the frames the new path needs
    /// before it holds real sound, or -1 when nothing changes what plays here.
    func arm(after before: PathSwitch?, holding: Bool, budget: inout Int) -> Int {
        guard !isArmed else { return -1 }
        isArmed = true
        if holding, let before, !before.settled.load(ordering: .relaxed) {
            old = before.old
        } else {
            old = settledOld
        }
        isSame = PathStep.same(old, new)
        guard !isSame else { return -1 }
        switch new {
        case nil:
            return 0
        case .unit?:
            return warmUp
        case .line(let line)?:
            var held = 0
            if case .line(let source)? = old, budget > 0 {
                held = line.takeOver(source, upTo: budget)
                budget -= held
            }
            return Swift.max(0, line.delay - held)
        }
    }

    /// Render thread: the end of the crossover this switch played in.
    func settle() { settled.store(true, ordering: .releasing) }

    /// Render thread: an insert this switch still plays as its old path (one that leaves or is
    /// replaced) keeps time with the song while it crosses, as the chain's inserts do.
    func followOld(_ transport: HostTransport, key: SongKey) {
        guard isLive, case .unit(let unit)? = old else { return }
        unit.follow(transport)
        unit.follow(key: key)
    }

    /// Render thread, while the crossover runs: the place's pair through both paths — the old one
    /// on a copy in `scratch` — then the old path until `window.holdEnd`, the glide to the new one
    /// until `window.rampEnd`, and the new path after. Allocates nothing.
    func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int,
                window: Crossover.Window, curve: UnsafePointer<Float>,
                scratchLeft: UnsafeMutablePointer<Float>, scratchRight: UnsafeMutablePointer<Float>) {
        guard frames > 0 else { return }
        guard isArmed, !isSame, !settled.load(ordering: .relaxed) else {
            new?.process(left: left, right: right, frames: frames)
            return
        }
        scratchLeft.update(from: left, count: frames)
        scratchRight.update(from: right, count: frames)
        old?.process(left: scratchLeft, right: scratchRight, frames: frames)
        new?.process(left: left, right: right, frames: frames)
        let hold = Swift.min(Swift.max(0, window.holdEnd), frames)
        let rampEnd = Swift.min(Swift.max(window.rampEnd, hold), frames)
        var i = 0
        while i < hold {
            left[i] = scratchLeft[i]
            right[i] = scratchRight[i]
            i += 1
        }
        var step = Swift.max(0, window.start)
        while i < rampEnd, step < Crossover.rampFrames {
            let g = curve[step]
            left[i] = scratchLeft[i] + (left[i] - scratchLeft[i]) * g
            right[i] = scratchRight[i] + (right[i] - scratchRight[i]) * g
            step += 1
            i += 1
        }
    }
}

/// The delay lines one snapshot's compensation plan asks for, by the place of each lane in the
/// snapshot (`EngineSnapshot.lanes`, `.audioLanes`, `.returns`): nil where the lane waits for
/// nothing, so a song without latency renders exactly as without compensation. Made on the main
/// thread in `EngineCore.publish`, and freed there with the snapshot it came with.
///
/// Per track: `pre` after its chain, before its fader and send taps (`TrackDelay.delay`), and
/// `direct` on its own output after the send taps (`TrackDelay.directDelay`). Per return: after
/// its chain, before its fader (`ReturnDelay.delay`).
struct CompensationLines: Sendable {
    enum Place: Hashable, Sendable {
        case pre(TrackID)
        case direct(TrackID)
        case back(TrackID)
    }

    struct Entry: Sendable {
        let place: Place
        let line: DelayLine
    }

    /// Identity only: which lines another snapshot's were resolved against.
    final class Origin: Sendable {}

    /// Frames all lines together copy when one snapshot is taken up (`takeOver(from:)`): two
    /// copies of a pair per line, about 256 KB at most, a few tens of microseconds — so the swap
    /// costs the same whatever the latencies. A lane's wait reaches
    /// `DelayCompensation.maximumUnitLatency` (96,000) per unit and 64 times that per lane, and a
    /// change to the longest wait makes every lane's line anew at once; a line beyond the budget
    /// starts from what fits of its newest frames, and silence before them.
    static let takeOverFrames = 32_768

    let instrumentPre: [DelayLine?]
    let instrumentDirect: [DelayLine?]
    let audioPre: [DelayLine?]
    let audioDirect: [DelayLine?]
    let returns: [DelayLine?]
    /// Every line with its place, for the next snapshot to find.
    let entries: [Entry]
    /// Per entry, where its line takes over from in the lines it was made against (an index into
    /// their `entries`), or -1: resolved here on the main thread, so the render thread never
    /// searches.
    let sources: [Int]
    let origin: Origin
    /// The `origin` of the lines `sources` points into.
    let resolvedFrom: Origin?

    /// The places whose wait changes from the snapshot before while a live core plays, parallel to
    /// the line arrays: nil where the place plays its line (or nothing) as it is (`PathSwitch`).
    let instrumentPreSwitches: [PathSwitch?]
    let instrumentDirectSwitches: [PathSwitch?]
    let audioPreSwitches: [PathSwitch?]
    let audioDirectSwitches: [PathSwitch?]
    let returnSwitches: [PathSwitch?]
    /// Every switch this snapshot plays: the ones it brings and the ones still crossing that it
    /// carries on from the snapshot before.
    let switches: [PathSwitch]
    /// The ones it brings, armed when the render thread takes it up.
    let armed: [PathSwitch]
    /// Main thread only: where each place's switch sits in `switches`, for the next snapshot.
    let switchPlaces: [Place: Int]
    /// The insert chains whose latent inserts arrive, leave or are replaced while a live core
    /// plays, parallel to the lanes, the returns and the master: nil where the chain plays as it
    /// is (`ChainStep`). Their slots are in `switches` too.
    let instrumentChains: [[ChainStep]?]
    let audioChains: [[ChainStep]?]
    let returnChains: [[ChainStep]?]
    let masterChain: [ChainStep]?

    /// No line and no switch: a song without latency, as without compensation. Computed, so each
    /// empty value has its own `origin` like any other.
    static var none: CompensationLines {
        CompensationLines(instrumentPre: [], instrumentDirect: [], audioPre: [], audioDirect: [],
                          returns: [], entries: [], sources: [], resolvedFrom: nil)
    }

    private init(instrumentPre: [DelayLine?], instrumentDirect: [DelayLine?], audioPre: [DelayLine?],
                 audioDirect: [DelayLine?], returns: [DelayLine?], entries: [Entry], sources: [Int],
                 resolvedFrom: Origin?) {
        self.instrumentPre = instrumentPre
        self.instrumentDirect = instrumentDirect
        self.audioPre = audioPre
        self.audioDirect = audioDirect
        self.returns = returns
        self.entries = entries
        self.sources = sources
        origin = Origin()
        self.resolvedFrom = resolvedFrom
        instrumentPreSwitches = []
        instrumentDirectSwitches = []
        audioPreSwitches = []
        audioDirectSwitches = []
        returnSwitches = []
        switches = []
        armed = []
        switchPlaces = [:]
        instrumentChains = []
        audioChains = []
        returnChains = []
        masterChain = nil
    }

    /// The lines of `snapshot`'s plan. A line the previous snapshot already has at the same place
    /// and the same delay is the same line, so a fader, a note or a send changed while playing
    /// never touches what a lane holds. Main thread.
    ///
    /// With `earlier`, the snapshot those previous lines belong to, a lane that played there too
    /// and whose wait changes gets a `PathSwitch` at that place, so a latency that arrives, leaves
    /// or changes while the song plays crosses over instead of stepping. Without it (an export, the
    /// first snapshot) every line is made as before: a new one starts as silence.
    init(_ snapshot: EngineSnapshot, reusing previous: CompensationLines?, after earlier: EngineSnapshot? = nil) {
        let plan = snapshot.compensation
        // Only a lane that played in the snapshot before can be heard to change.
        var playedBefore: Set<TrackID> = []
        if let earlier, previous != nil {
            for lane in earlier.lanes { playedBefore.insert(lane.track) }
            for lane in earlier.audioLanes { playedBefore.insert(lane.track) }
            for lane in earlier.returns { playedBefore.insert(lane.track) }
        }
        let carried = previous?.switches ?? []
        let carriedPlaces = previous?.switchPlaces ?? [:]
        guard !plan.isEmpty || !playedBefore.isEmpty || !carried.isEmpty else {
            self = .none
            return
        }
        let earlierEntries = previous?.entries ?? []
        var known: [Place: Int] = [:]
        for (index, entry) in earlierEntries.enumerated() { known[entry.place] = index }
        var made: [Entry] = []
        var from: [Int] = []
        var all: [PathSwitch] = []
        var fresh: [PathSwitch] = []
        var places: [Place: Int] = [:]
        let resolve = { (place: Place, track: TrackID, frames: Int) -> (line: DelayLine?, change: PathSwitch?) in
            let found = known[place] ?? -1
            let was: DelayLine? = found >= 0 && found < earlierEntries.count ? earlierEntries[found].line : nil
            guard playedBefore.contains(track) else {
                guard frames > 0 else { return (nil, nil) }
                if let was, was.delay == frames {
                    made.append(Entry(place: place, line: was))
                    from.append(-1)
                    return (was, nil)
                }
                let result = DelayLine(delay: frames)
                made.append(Entry(place: place, line: result))
                from.append(was == nil ? -1 : found)
                return (result, nil)
            }
            // A switch at this place that is still crossing.
            var running: PathSwitch?
            var runningAt = -1
            if let at = carriedPlaces[place], at >= 0, at < carried.count,
               !carried[at].settled.load(ordering: .acquiring) {
                running = carried[at]
                runningAt = at
            }
            let waits = Swift.max(0, frames)
            if (was?.delay ?? 0) == waits {
                // The wait stays: the line goes on, and so does a crossing at this place.
                if let was {
                    made.append(Entry(place: place, line: was))
                    from.append(-1)
                }
                if let running {
                    places[place] = all.count
                    all.append(running)
                }
                return (was, running)
            }
            // The wait changes while the lane plays: the new line fills from what the old one
            // holds when the switch is armed, so it is not paired through `sources`. Back to the
            // wait a running switch left: its old line again, so an edit undone in its hold
            // changes nothing and the crossover ends.
            var line: DelayLine?
            if waits > 0 {
                let result: DelayLine
                if let back = running?.settledOld?.line, back.delay == waits {
                    result = back
                } else {
                    result = DelayLine(delay: waits)
                }
                made.append(Entry(place: place, line: result))
                from.append(-1)
                line = result
            }
            let change = PathSwitch(new: line, settledOld: was, predecessor: runningAt)
            places[place] = all.count
            all.append(change)
            fresh.append(change)
            return (line, change)
        }
        let trackDelays = Dictionary(plan.tracks.map { ($0.track, $0) }, uniquingKeysWith: { first, _ in first })
        let returnDelays = Dictionary(plan.returns.map { ($0.track, $0) }, uniquingKeysWith: { first, _ in first })
        var instrumentPre: [DelayLine?] = [], instrumentPreSwitches: [PathSwitch?] = []
        var instrumentDirect: [DelayLine?] = [], instrumentDirectSwitches: [PathSwitch?] = []
        for lane in snapshot.lanes {
            let pre = resolve(.pre(lane.track), lane.track, trackDelays[lane.track]?.delay ?? 0)
            instrumentPre.append(pre.line)
            instrumentPreSwitches.append(pre.change)
            let direct = resolve(.direct(lane.track), lane.track, trackDelays[lane.track]?.directDelay ?? 0)
            instrumentDirect.append(direct.line)
            instrumentDirectSwitches.append(direct.change)
        }
        var audioPre: [DelayLine?] = [], audioPreSwitches: [PathSwitch?] = []
        var audioDirect: [DelayLine?] = [], audioDirectSwitches: [PathSwitch?] = []
        for lane in snapshot.audioLanes {
            let pre = resolve(.pre(lane.track), lane.track, trackDelays[lane.track]?.delay ?? 0)
            audioPre.append(pre.line)
            audioPreSwitches.append(pre.change)
            let direct = resolve(.direct(lane.track), lane.track, trackDelays[lane.track]?.directDelay ?? 0)
            audioDirect.append(direct.line)
            audioDirectSwitches.append(direct.change)
        }
        var returns: [DelayLine?] = [], returnSwitches: [PathSwitch?] = []
        for lane in snapshot.returns {
            let back = resolve(.back(lane.track), lane.track, returnDelays[lane.track]?.delay ?? 0)
            returns.append(back.line)
            returnSwitches.append(back.change)
        }
        // The insert chains: a latent insert that arrives, leaves or is replaced while the lane
        // plays crosses over on the same clock (only when there is a snapshot before).
        var instrumentChains: [[ChainStep]?] = []
        var audioChains: [[ChainStep]?] = []
        var returnChains: [[ChainStep]?] = []
        var masterChain: [ChainStep]?
        if let earlier, let previous {
            var oldChains: [TrackID: [any HostedProcessor]] = [:]
            var oldPrograms: [TrackID: [ChainStep]] = [:]
            for (index, lane) in earlier.lanes.enumerated() {
                oldChains[lane.track] = lane.inserts
                if let program = CompensationLines.at(previous.instrumentChains, index) { oldPrograms[lane.track] = program }
            }
            for (index, lane) in earlier.audioLanes.enumerated() {
                oldChains[lane.track] = lane.inserts
                if let program = CompensationLines.at(previous.audioChains, index) { oldPrograms[lane.track] = program }
            }
            for (index, lane) in earlier.returns.enumerated() {
                oldChains[lane.track] = lane.inserts
                if let program = CompensationLines.at(previous.returnChains, index) { oldPrograms[lane.track] = program }
            }
            let chain = { (track: TrackID, inserts: [any HostedProcessor]) -> [ChainStep]? in
                guard let before = oldChains[track] else { return nil }
                return CompensationLines.program(from: before, to: inserts, carrying: oldPrograms[track],
                                    previousSwitches: previous.switches, all: &all, fresh: &fresh)
            }
            for lane in snapshot.lanes { instrumentChains.append(chain(lane.track, lane.inserts)) }
            for lane in snapshot.audioLanes { audioChains.append(chain(lane.track, lane.inserts)) }
            for lane in snapshot.returns { returnChains.append(chain(lane.track, lane.inserts)) }
            masterChain = CompensationLines.program(from: earlier.masterEffects, to: snapshot.masterEffects,
                                       carrying: previous.masterChain, previousSwitches: previous.switches,
                                       all: &all, fresh: &fresh)
        }
        guard !made.isEmpty || !all.isEmpty else {
            self = .none
            return
        }
        self.instrumentPre = instrumentPre
        self.instrumentDirect = instrumentDirect
        self.audioPre = audioPre
        self.audioDirect = audioDirect
        self.returns = returns
        self.instrumentPreSwitches = instrumentPreSwitches
        self.instrumentDirectSwitches = instrumentDirectSwitches
        self.audioPreSwitches = audioPreSwitches
        self.audioDirectSwitches = audioDirectSwitches
        self.returnSwitches = returnSwitches
        entries = made
        sources = from
        switches = all
        armed = fresh
        switchPlaces = places
        self.instrumentChains = instrumentChains
        self.audioChains = audioChains
        self.returnChains = returnChains
        self.masterChain = masterChain
        origin = Origin()
        resolvedFrom = previous?.origin
    }

    /// The program of one chain going from `old` to `new` while a live core plays, or nil when it
    /// plays as it is. A latent insert (not bypassed, `latencyFrames` > 0) that arrives, leaves or
    /// takes another's place gets a slot (`PathSwitch`); everything else plays as it always did. A
    /// slot still crossing from the program before is carried on with its unit; one whose edit is
    /// undone gets a successor that cancels it. A chain whose common inserts changed their order
    /// plays as it is: the reorder switches at once, as before. Main thread.
    static func program(from old: [any HostedProcessor], to new: [any HostedProcessor], carrying carried: [ChainStep]?,
                        previousSwitches: [PathSwitch], all: inout [PathSwitch], fresh: inout [PathSwitch]) -> [ChainStep]? {
        let latent = { (unit: any HostedProcessor) -> Bool in !unit.isBypassed && unit.latencyFrames > 0 }
        let isOld = { (unit: any HostedProcessor) -> Bool in old.contains { $0 === unit } }
        let isNew = { (unit: any HostedProcessor) -> Bool in new.contains { $0 === unit } }
        // The slots of the program before that still cross.
        var running: [PathSwitch] = []
        for step in carried ?? [] {
            if case .slot(let slot) = step, !slot.settled.load(ordering: .acquiring) { running.append(slot) }
        }
        let slotIndex = { (slot: PathSwitch) -> Int in previousSwitches.firstIndex { $0 === slot } ?? -1 }
        let runningFor = { (unit: any HostedProcessor) -> PathSwitch? in
            running.first { (slot: PathSwitch) -> Bool in
                if case .unit(let playing)? = slot.new { return playing === unit }
                return false
            }
        }
        let leavingFrom = { (unit: any HostedProcessor) -> PathSwitch? in
            running.first { (slot: PathSwitch) -> Bool in
                guard slot.new == nil, case .unit(let leaving)? = slot.settledOld else { return false }
                return leaving === unit
            }
        }
        let same = old.count == new.count && zip(old, new).allSatisfy { $0 === $1 }
        if same {
            guard !running.isEmpty, let carried else { return nil }
            var program: [ChainStep] = []
            for step in carried {
                switch step {
                case .unit(let unit):
                    program.append(.unit(unit))
                case .slot(let slot):
                    if !slot.settled.load(ordering: .acquiring) {
                        all.append(slot)
                        program.append(.slot(slot))
                    } else if case .unit(let unit)? = slot.new {
                        program.append(.unit(unit))
                    }
                }
            }
            return program
        }
        // The inserts both chains play must keep their order.
        let common = new.filter { isOld($0) }
        let commonBefore = old.filter { isNew($0) }
        guard common.count == commonBefore.count, zip(common, commonBefore).allSatisfy({ $0 === $1 }) else { return nil }
        // Each latent insert that leaves, with the gap it leaves from (the number of common inserts
        // before it) and the common insert it sat before.
        var leaving: [(unit: any HostedProcessor, gap: Int)] = []
        var gap = 0
        for unit in old {
            if isNew(unit) {
                gap += 1
            } else if latent(unit) {
                leaving.append((unit, gap))
            }
        }
        let anchorOf = { (gap: Int) -> ObjectIdentifier? in gap < common.count ? ObjectIdentifier(common[gap]) : nil }
        let arriving = new.contains { !isOld($0) && latent($0) }
        guard !leaving.isEmpty || arriving || !running.isEmpty else { return nil }
        // Slots still taking out an insert neither chain has any more: carried on before the
        // insert they sat before, or at the end when that one went too.
        let stillLeaving = running.filter { (slot: PathSwitch) -> Bool in
            guard slot.new == nil, case .unit(let unit)? = slot.settledOld else { return false }
            return !isOld(unit) && !isNew(unit)
        }
        var placed = [Bool](repeating: false, count: stillLeaving.count)
        var program: [ChainStep] = []
        var paired = [Bool](repeating: false, count: leaving.count)
        var made = false
        // Collected here and handed out at the end: a closure may not capture the inout lists.
        var played: [PathSwitch] = []
        var brought: [PathSwitch] = []
        let leave = { (at: Int) in
            for (offset, entry) in leaving.enumerated() where entry.gap == at && !paired[offset] {
                paired[offset] = true
                let before = runningFor(entry.unit)
                let slot = PathSwitch(step: nil, settledOld: .unit(entry.unit), predecessor: before.map(slotIndex) ?? -1,
                                      anchor: anchorOf(at), inherits: before)
                played.append(slot)
                brought.append(slot)
                program.append(.slot(slot))
                made = true
            }
        }
        let carryLeaving = { (anchor: ObjectIdentifier?) in
            for (offset, slot) in stillLeaving.enumerated() where !placed[offset] && (anchor == nil || slot.anchor == anchor) {
                placed[offset] = true
                played.append(slot)
                program.append(.slot(slot))
                made = true
            }
        }
        gap = 0
        for unit in new {
            if isOld(unit) {
                leave(gap)
                carryLeaving(ObjectIdentifier(unit))
                gap += 1
                if let slot = runningFor(unit) {
                    played.append(slot)
                    program.append(.slot(slot))
                    made = true
                } else {
                    program.append(.unit(unit))
                }
            } else if latent(unit) {
                // Takes the place of the first latent insert that leaves from the same gap.
                var replaced: (any HostedProcessor)?
                if let offset = leaving.indices.first(where: { leaving[$0].gap == gap && !paired[$0] }) {
                    paired[offset] = true
                    replaced = leaving[offset].unit
                }
                let before = replaced.flatMap(runningFor) ?? leavingFrom(unit)
                let slot = PathSwitch(step: .unit(unit), settledOld: replaced.map { PathStep.unit($0) },
                                      predecessor: before.map(slotIndex) ?? -1, warmUp: PathSwitch.warmUp(for: unit),
                                      inherits: before)
                played.append(slot)
                brought.append(slot)
                program.append(.slot(slot))
                made = true
            } else {
                program.append(.unit(unit))
            }
        }
        leave(gap)
        carryLeaving(nil)
        guard made else { return nil }
        // Each insert runs once per chunk: in the chain, as a slot's new path, or as the old path a
        // slot may play. Where a quick run of edits would run one twice, the chain switches at
        // once instead, as it always did.
        var seen = Set<ObjectIdentifier>()
        for step in program {
            switch step {
            case .unit(let unit):
                guard seen.insert(ObjectIdentifier(unit)).inserted else { return nil }
            case .slot(let slot):
                var mine = Set(slot.possibleOld)
                if case .unit(let unit)? = slot.new { mine.insert(ObjectIdentifier(unit)) }
                for identity in mine {
                    guard seen.insert(identity).inserted else { return nil }
                }
            }
        }
        all.append(contentsOf: played)
        fresh.append(contentsOf: brought)
        return program
    }

    /// Render thread: a slot of `program` still crosses.
    static func isCrossing(_ program: [ChainStep]?) -> Bool {
        for step in program ?? [] {
            if case .slot(let slot) = step, slot.isLive { return true }
        }
        return false
    }

    /// Render thread, while a snapshot is taken up: each line this snapshot brings new takes over
    /// what the previous snapshot's line at its place holds — by the pairing made on the main
    /// thread, and within `takeOverFrames` in all. Only lines made without `after:` are paired
    /// here; a wait that changes while a live core plays is primed by its switch in
    /// `arm(after:holding:)`, under a budget of its own. `EngineCore.publish` withdraws a box the render
    /// thread never took before it makes the next one's lines, so lines are made against the ones
    /// the render thread holds; the identity check only keeps a mismatched pairing silent, should
    /// that ever change.
    func takeOver(from previous: CompensationLines) {
        guard let resolvedFrom, resolvedFrom === previous.origin else { return }
        var budget = Self.takeOverFrames
        let count = Swift.min(entries.count, sources.count)
        var index = 0
        while index < count, budget > 0 {
            let source = sources[index]
            if source >= 0, source < previous.entries.count {
                budget -= entries[index].line.takeOver(previous.entries[source].line, upTo: budget)
            }
            index += 1
        }
    }

    /// Render thread, while this snapshot is taken up, after `takeOver(from:)`: arms the switches
    /// it brings against the ones `previous` played (`PathSwitch.arm`), within one copy budget.
    /// `holding` while the crossover still holds. Returns the frames the crossover must hold for
    /// them, or -1 when none of them changes what plays.
    func arm(after previous: CompensationLines, holding: Bool) -> Int {
        // Made against other lines than the render thread played: no predecessor and no copy,
        // the new lines start as silence (with `EngineCore.publish` withdrawing first, never).
        let paired = resolvedFrom != nil && resolvedFrom === previous.origin
        var budget = paired ? Self.takeOverFrames : 0
        var need = -1
        for change in armed {
            let at = change.predecessor
            let before: PathSwitch? = paired && at >= 0 && at < previous.switches.count ? previous.switches[at] : nil
            need = Swift.max(need, change.arm(after: before, holding: holding, budget: &budget))
        }
        return need
    }

    /// Render thread: a switch of this snapshot still crosses.
    var hasLiveSwitch: Bool {
        for change in switches where change.isLive { return true }
        return false
    }

    /// Render thread: the crossover is over; every switch this snapshot plays has settled.
    func markSettled() {
        for change in switches { change.settle() }
    }

    static func at<Element>(_ items: [Element?], _ index: Int) -> Element? {
        index >= 0 && index < items.count ? items[index] : nil
    }
}
