import Foundation

/// The life of the video-take camera (wave W7), from opening to a take that landed — and what a
/// call, Siri, Control Centre or a failing camera does to it. Pure, so the interruption cases are
/// tested here, where no camera can be interrupted on purpose.
///
/// A take that iOS cuts short is not thrown away: the file is closed and lands with what was
/// filmed, said plainly (`cutShort`). An interruption while the camera only shows its picture
/// waits and gives the picture back when it ends. Every event carries the generation it was
/// stamped with; an event of an older generation (a camera that was closed, a lens that was put
/// away) changes nothing. Opening, closing and a change of lens raise the generation.
public struct VideoTakeLifecycle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case closed
        /// The camera is being opened.
        case opening
        /// The camera shows its picture; Record starts a take.
        case ready
        case recording
        /// The take's file is being closed.
        case finishing
        /// The last take is on the song; Record starts the next one.
        case landed
        /// iOS holds the camera; nothing is filmed until it gives it back.
        case interrupted
        /// The camera stopped with an error; closing and opening it again is the way back.
        case failed
    }

    /// What the camera reports. Each comes stamped with a generation.
    public enum Event: Equatable, Sendable {
        /// The camera is open and running.
        case opened
        /// The take's first frame is in.
        case started
        /// iOS took the camera (a call, Siri, Control Centre, another app).
        case interruptionBegan
        /// iOS gave the camera back.
        case interruptionEnded
        /// The camera session stopped with an error.
        case runtimeError
        /// The take's file is closed; `usable` says whether it holds the take.
        case fileClosed(usable: Bool)
    }

    public private(set) var phase: Phase = .closed
    public private(set) var generation: UInt64 = 0
    /// The take running or last landed was ended by an interruption or an error, not by Stop.
    public private(set) var cutShort = false
    /// iOS holds the camera now, whatever the phase shows (a take may still be closing its file).
    public private(set) var isInterrupted = false
    /// The last take's file could not be kept.
    public private(set) var lostLastTake = false
    /// The session reported a runtime error since it opened.
    private var brokeDown = false

    public init() {}

    /// Record may start a take now.
    public var canRecord: Bool { (phase == .ready || phase == .landed) && !isInterrupted }

    /// The camera is about to open: a new generation. Answers it; nil while the camera is open.
    @discardableResult
    public mutating func open() -> UInt64? {
        guard phase == .closed else { return nil }
        generation &+= 1
        phase = .opening
        cutShort = false
        isInterrupted = false
        lostLastTake = false
        brokeDown = false
        return generation
    }

    /// The camera is released. Every event still on its way is from an older generation now.
    public mutating func close() {
        generation &+= 1
        phase = .closed
        cutShort = false
        isInterrupted = false
        lostLastTake = false
        brokeDown = false
    }

    /// Record: a take begins. False when the camera cannot film now.
    @discardableResult
    public mutating func record() -> Bool {
        guard canRecord else { return false }
        phase = .recording
        cutShort = false
        lostLastTake = false
        return true
    }

    /// Stop: the take's file is closed and the take lands. False when nothing is filmed.
    @discardableResult
    public mutating func stop() -> Bool {
        guard phase == .recording else { return false }
        phase = .finishing
        return true
    }

    /// The lens changes (front or back) while the picture shows: a new generation, so a late event
    /// of the lens put away is dropped, and the camera opens again (`opened` follows). Refused —
    /// false, nothing changed — while a take is filmed or its file is closed, and while iOS holds
    /// the camera.
    @discardableResult
    public mutating func changeLens() -> Bool {
        guard canRecord else { return false }
        generation &+= 1
        phase = .opening
        return true
    }

    /// Whether an event stamped with `stamped` belongs to the camera now.
    public func isCurrent(_ stamped: UInt64) -> Bool { stamped == generation }

    /// The camera reports `event`, stamped with `stamped`. False (and nothing changed) when the
    /// stamp is stale or the event means nothing in this phase.
    @discardableResult
    public mutating func handle(_ event: Event, stamped: UInt64) -> Bool {
        guard isCurrent(stamped), phase != .closed else { return false }
        switch event {
        case .opened:
            guard phase == .opening else { return false }
            phase = isInterrupted ? .interrupted : .ready
        case .started:
            return phase == .recording
        case .interruptionBegan:
            guard !isInterrupted else { return false }
            isInterrupted = true
            switch phase {
            case .recording:
                // iOS closes the file itself; the take lands with what was filmed.
                phase = .finishing
                cutShort = true
            case .ready, .landed:
                phase = .interrupted
            case .opening, .finishing, .interrupted, .failed, .closed:
                // Opening waits for `opened`; a take already stopped closes its file as it was.
                break
            }
        case .interruptionEnded:
            guard isInterrupted else { return false }
            isInterrupted = false
            if phase == .interrupted { phase = .ready }
        case .runtimeError:
            guard !brokeDown else { return false }
            brokeDown = true
            switch phase {
            case .recording:
                // The file is closed with what was filmed; the camera is not trusted after it.
                phase = .finishing
                cutShort = true
            case .finishing:
                break
            case .opening, .ready, .landed, .interrupted, .failed, .closed:
                phase = .failed
            }
        case .fileClosed(let usable):
            // A take can also end by itself (the disk filled up): then its file closes while it records.
            guard phase == .recording || phase == .finishing else { return false }
            if !usable { lostLastTake = true }
            if brokeDown {
                phase = .failed
            } else if usable {
                phase = .landed
            } else {
                phase = isInterrupted ? .interrupted : .ready
            }
        }
        return true
    }
}
