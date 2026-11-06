import EchoelCore
import Foundation

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

    static let none = CompensationLines(instrumentPre: [], instrumentDirect: [], audioPre: [], audioDirect: [],
                                        returns: [], entries: [], sources: [], resolvedFrom: nil)

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
    }

    /// The lines of `snapshot`'s plan. A line the previous snapshot already has at the same place
    /// and the same delay is the same line, so a fader, a note or a send changed while playing
    /// never touches what a lane holds. Main thread.
    init(_ snapshot: EngineSnapshot, reusing previous: CompensationLines?) {
        let plan = snapshot.compensation
        guard !plan.isEmpty else {
            self = .none
            return
        }
        let earlier = previous?.entries ?? []
        var known: [Place: Int] = [:]
        for (index, entry) in earlier.enumerated() { known[entry.place] = index }
        var made: [Entry] = []
        var from: [Int] = []
        let line = { (place: Place, frames: Int) -> DelayLine? in
            guard frames > 0 else { return nil }
            let found = known[place] ?? -1
            let old = found >= 0 && found < earlier.count ? earlier[found].line : nil
            if let old, old.delay == frames {
                made.append(Entry(place: place, line: old))
                from.append(-1)
                return old
            }
            let result = DelayLine(delay: frames)
            made.append(Entry(place: place, line: result))
            from.append(old == nil ? -1 : found)
            return result
        }
        let trackDelays = Dictionary(plan.tracks.map { ($0.track, $0) }, uniquingKeysWith: { first, _ in first })
        let returnDelays = Dictionary(plan.returns.map { ($0.track, $0) }, uniquingKeysWith: { first, _ in first })
        instrumentPre = snapshot.lanes.map { line(.pre($0.track), trackDelays[$0.track]?.delay ?? 0) }
        instrumentDirect = snapshot.lanes.map { line(.direct($0.track), trackDelays[$0.track]?.directDelay ?? 0) }
        audioPre = snapshot.audioLanes.map { line(.pre($0.track), trackDelays[$0.track]?.delay ?? 0) }
        audioDirect = snapshot.audioLanes.map { line(.direct($0.track), trackDelays[$0.track]?.directDelay ?? 0) }
        returns = snapshot.returns.map { line(.back($0.track), returnDelays[$0.track]?.delay ?? 0) }
        entries = made
        sources = from
        origin = Origin()
        resolvedFrom = previous?.origin
    }

    /// Render thread, while a snapshot is taken up: each line this snapshot brings new takes over
    /// what the previous snapshot's line at its place holds — by the pairing made on the main
    /// thread, and within `takeOverFrames` in all. Lines made against other lines than the ones
    /// the render thread held (a snapshot in between was published and never taken up) start
    /// silent instead.
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

    static func at(_ lines: [DelayLine?], _ index: Int) -> DelayLine? {
        index >= 0 && index < lines.count ? lines[index] : nil
    }
}
