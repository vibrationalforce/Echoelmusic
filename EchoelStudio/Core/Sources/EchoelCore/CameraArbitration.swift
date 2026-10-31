import Foundation

/// Who holds the one rear camera (camera-arbitration, wave W7): a production take, the pulse
/// (rPPG, W1) or the sky view's camera layer (Sky S2). Exactly one producer owns it, in this
/// order: a take always wins — it suspends the pulse or closes the sky layer and gives the camera
/// back when it ends; the pulse wins over the sky layer, because it feeds the sound and the
/// musician chose it, while the sky view is complete without its camera (the sky is drawn). A
/// lower claimant waits for the camera and gets it when the higher one lets go.
/// Every change of holder is a new generation, so a callback that arrives late from an earlier
/// holder is recognised and dropped. A value type: the app carries out the steps it answers.
public struct CameraArbitration: Equatable, Sendable {
    public enum Holder: Equatable, Sendable {
        case none
        case pulse
        case take
        case sky
    }

    /// What the app does after a request.
    public enum Step: Equatable, Sendable {
        case openPulse
        case suspendPulse
        case resumePulse
        case closePulse
        case openTake
        case closeTake
        case openSky
        case closeSky
    }

    public private(set) var holder: Holder = .none
    /// The musician has the pulse on — it holds the camera, or waits for a take to end.
    public private(set) var pulseChosen = false
    /// The sky view is open and would show its camera layer — it holds the camera, or waits.
    public private(set) var skyWanted = false
    /// Raised at every change of holder; a callback carrying an older one is stale.
    public private(set) var generation: UInt64 = 0

    public init() {}

    /// The musician turned the camera pulse on.
    public mutating func choosePulse() -> [Step] {
        guard !pulseChosen else { return [] }
        pulseChosen = true
        switch holder {
        case .none:
            hand(to: .pulse)
            return [.openPulse]
        case .sky:
            hand(to: .pulse)
            return [.closeSky, .openPulse]
        case .pulse, .take:
            return []
        }
    }

    /// The musician turned the camera pulse off.
    public mutating func dropPulse() -> [Step] {
        guard pulseChosen else { return [] }
        pulseChosen = false
        guard holder == .pulse else { return [] }
        if skyWanted {
            hand(to: .sky)
            return [.closePulse, .openSky]
        }
        hand(to: .none)
        return [.closePulse]
    }

    /// The sky view wants its camera layer: it gets the camera when nobody else holds it.
    public mutating func wantSky() -> [Step] {
        guard !skyWanted else { return [] }
        skyWanted = true
        guard holder == .none else { return [] }
        hand(to: .sky)
        return [.openSky]
    }

    /// The sky view closed.
    public mutating func dropSky() -> [Step] {
        guard skyWanted else { return [] }
        skyWanted = false
        guard holder == .sky else { return [] }
        hand(to: .none)
        return [.closeSky]
    }

    /// A take wants the camera: it gets it, the pulse pausing first. Nil while a take holds it.
    public mutating func beginTake() -> [Step]? {
        guard holder != .take else { return nil }
        let before = holder
        hand(to: .take)
        switch before {
        case .pulse: return [.suspendPulse, .openTake]
        case .sky: return [.closeSky, .openTake]
        case .none, .take: return [.openTake]
        }
    }

    /// The take ended (stopped, failed or interrupted): the camera goes back to a chosen pulse.
    public mutating func endTake() -> [Step] {
        guard holder == .take else { return [] }
        if pulseChosen {
            hand(to: .pulse)
            return [.closeTake, .resumePulse]
        }
        if skyWanted {
            hand(to: .sky)
            return [.closeTake, .openSky]
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
