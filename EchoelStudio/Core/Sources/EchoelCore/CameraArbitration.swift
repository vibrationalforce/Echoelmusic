import Foundation

/// Who holds the one rear camera (camera-arbitration, wave W7): the pulse (rPPG, W1) or a
/// production take. Exactly one producer owns it; a take always wins — it suspends the pulse and
/// gives the camera back when it ends. A pulse chosen while a take holds the camera waits for it.
/// Every change of holder is a new generation, so a callback that arrives late from an earlier
/// holder is recognised and dropped. A value type: the app carries out the steps it answers.
public struct CameraArbitration: Equatable, Sendable {
    public enum Holder: Equatable, Sendable {
        case none
        case pulse
        case take
    }

    /// What the app does after a request.
    public enum Step: Equatable, Sendable {
        case openPulse
        case suspendPulse
        case resumePulse
        case closePulse
        case openTake
        case closeTake
    }

    public private(set) var holder: Holder = .none
    /// The musician has the pulse on — it holds the camera, or waits for a take to end.
    public private(set) var pulseChosen = false
    /// Raised at every change of holder; a callback carrying an older one is stale.
    public private(set) var generation: UInt64 = 0

    public init() {}

    /// The musician turned the camera pulse on.
    public mutating func choosePulse() -> [Step] {
        guard !pulseChosen else { return [] }
        pulseChosen = true
        guard holder == .none else { return [] }
        hand(to: .pulse)
        return [.openPulse]
    }

    /// The musician turned the camera pulse off.
    public mutating func dropPulse() -> [Step] {
        guard pulseChosen else { return [] }
        pulseChosen = false
        guard holder == .pulse else { return [] }
        hand(to: .none)
        return [.closePulse]
    }

    /// A take wants the camera: it gets it, the pulse pausing first. Nil while a take holds it.
    public mutating func beginTake() -> [Step]? {
        guard holder != .take else { return nil }
        let pausing = holder == .pulse
        hand(to: .take)
        return pausing ? [.suspendPulse, .openTake] : [.openTake]
    }

    /// The take ended (stopped, failed or interrupted): the camera goes back to a chosen pulse.
    public mutating func endTake() -> [Step] {
        guard holder == .take else { return [] }
        if pulseChosen {
            hand(to: .pulse)
            return [.closeTake, .resumePulse]
        }
        hand(to: .none)
        return [.closeTake]
    }

    /// Whether a callback stamped with `generation` belongs to the holder now.
    public func isCurrent(_ stamped: UInt64) -> Bool { stamped == generation }

    private mutating func hand(to next: Holder) {
        holder = next
        generation &+= 1
    }
}
