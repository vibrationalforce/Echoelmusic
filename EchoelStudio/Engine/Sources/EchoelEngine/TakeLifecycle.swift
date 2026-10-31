/// The life of one audio take as the app's engine sees it — apart from the file, the ring and the
/// input node, which hold the audio: what a pause from outside, a jump of a followed clock, a
/// rebuild of the audio graph (a route change, a new sample rate, a media services reset) and a
/// lost input do to it, and when the next take may begin. Pure, so the route-change cases are
/// tested here, where there is no audio session to simulate (review 2026-10-28, 2.1).
///
/// A take that is ended from outside stops capturing input AT ONCE, on the main thread, before the
/// song pauses, the playhead moves or the graph changes: input that arrives while the song stands
/// or jumps would be appended to the take at a playhead that stood still, bars from where it was
/// played. Writing the file out, and the undo step that places the take, follow asynchronously
/// (`stop`, then `finished`); until then no new take may begin, because its writer would drain
/// the same ring and its arming would reset the start the ending take still reads.
///
/// The take keeps the recorder it began on until it is stopped. A rebuilt graph records through a
/// NEW recorder, never the take's: one that outlived a rebuild would join later input straight
/// onto the earlier input, early by the gap, and at the latency of a route the take was not
/// stamped for.
public struct TakeLifecycle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// No take.
        case idle
        /// Input is captured into the ring.
        case recording
        /// Ended from outside — a pause, a jump, a rebuild: the input is no longer captured and
        /// the record controller was told, once; the stop that writes the file out has not run yet.
        case ended
        /// The file is being written out; the recorder, its ring and the drain task are in use.
        case finishing
    }

    public private(set) var phase: Phase = .idle

    public init() {}

    /// Record may start a take: none runs and none is still being written out.
    public var canBegin: Bool { phase == .idle }

    /// The take still owns the recorder it began on: it records, or it ended and is not stopped
    /// yet. A graph built now gets a recorder of its own.
    public var ownsRecorder: Bool { phase == .recording || phase == .ended }

    /// Record starts a take. False while one runs or is still being written out.
    @discardableResult
    public mutating func begin() -> Bool {
        guard phase == .idle else { return false }
        phase = .recording
        return true
    }

    /// Something outside ends the take: a pause (a call, lost headphones, a followed clock's
    /// Stop), a followed clock moving the playhead, a rebuild of the graph. The caller disarms the
    /// take's recorder in the same breath, whatever this returns. True when the take was recording
    /// until now — the one moment the song is paused for its sake and the record controller told;
    /// a take already ended has had both, and is announced no second time.
    @discardableResult
    public mutating func endedFromOutside() -> Bool {
        guard phase == .recording else { return false }
        phase = .ended
        return true
    }

    /// The stop: the take's file is written out. False when there is no take to stop.
    @discardableResult
    public mutating func stop() -> Bool {
        guard ownsRecorder else { return false }
        phase = .finishing
        return true
    }

    /// The file is closed; the recorder, its ring and the drain are free. The next take may begin.
    public mutating func finished() {
        phase = .idle
    }
}
