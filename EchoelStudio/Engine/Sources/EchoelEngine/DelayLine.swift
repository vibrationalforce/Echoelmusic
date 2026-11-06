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

    /// Render thread: forgets what it holds. A drained line is left as it is.
    func clear() {
        guard !isDrained else { return }
        left.update(repeating: 0, count: delay)
        right.update(repeating: 0, count: delay)
        cursor = 0
        quiet = delay
    }

    /// Render thread, while a snapshot is taken up: the newest frames `other` holds — as many as
    /// both lines take — become this line's newest, and anything older is silence, so a lane whose
    /// delay changes plays on from what it held instead of falling silent for the whole new delay.
    func takeOver(_ other: DelayLine) {
        guard other !== self else { return }
        let kept = Swift.min(delay, other.delay)
        let older = delay - kept
        left.update(repeating: 0, count: older)
        right.update(repeating: 0, count: older)
        for k in 0..<kept {
            var from = other.cursor - kept + k
            if from < 0 { from += other.delay }
            left[older + k] = other.left[from]
            right[older + k] = other.right[from]
        }
        cursor = 0
        // Silent through every kept frame: the silence before them is silent too.
        quiet = other.quiet >= kept ? delay : other.quiet
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

    let instrumentPre: [DelayLine?]
    let instrumentDirect: [DelayLine?]
    let audioPre: [DelayLine?]
    let audioDirect: [DelayLine?]
    let returns: [DelayLine?]
    /// Every line with its place, for the next snapshot to find.
    let entries: [Entry]

    static let none = CompensationLines(instrumentPre: [], instrumentDirect: [], audioPre: [], audioDirect: [],
                                        returns: [], entries: [])

    private init(instrumentPre: [DelayLine?], instrumentDirect: [DelayLine?], audioPre: [DelayLine?],
                 audioDirect: [DelayLine?], returns: [DelayLine?], entries: [Entry]) {
        self.instrumentPre = instrumentPre
        self.instrumentDirect = instrumentDirect
        self.audioPre = audioPre
        self.audioDirect = audioDirect
        self.returns = returns
        self.entries = entries
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
        var known: [Place: DelayLine] = [:]
        for entry in previous?.entries ?? [] { known[entry.place] = entry.line }
        var made: [Entry] = []
        let line = { (place: Place, frames: Int) -> DelayLine? in
            guard frames > 0 else { return nil }
            let kept = known[place].flatMap { $0.delay == frames ? $0 : nil }
            let result = kept ?? DelayLine(delay: frames)
            made.append(Entry(place: place, line: result))
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
    }

    /// Render thread, while a snapshot is taken up: each line this snapshot brings new takes over
    /// what the previous snapshot's line at its place holds.
    func takeOver(from previous: CompensationLines) {
        for entry in entries {
            for old in previous.entries where old.place == entry.place {
                entry.line.takeOver(old.line)
                break
            }
        }
    }

    static func at(_ lines: [DelayLine?], _ index: Int) -> DelayLine? {
        index >= 0 && index < lines.count ? lines[index] : nil
    }
}
