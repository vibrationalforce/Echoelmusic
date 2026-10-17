import EchoelCore

/// What the session asks of one track's slot. Main thread → render thread.
public enum LaunchAction: Sendable, Equatable {
    /// Play this clip of the track as a loop, from the next launch boundary. The track's
    /// arrangement stays silent until `backToArrangement`.
    case launch(ClipID)
    /// Stop the track's clip at the next launch boundary.
    case stop
    /// Let the arrangement play the track again, at once.
    case backToArrangement
}

struct LaunchRequest: Sendable {
    var slot: Int
    var action: LaunchAction
}

/// What happened to a slot's clip, for the session view. Render thread → main thread.
public struct LaunchReport: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        /// Waiting for its boundary.
        case queued
        case playing
        case stopped
        /// The arrangement plays the track again.
        case arrangement
    }

    public let slot: Int
    /// The clip the state is about; nil for a stop or the arrangement.
    public let clip: ClipID?
    public let state: State
}

/// Render-thread state of one slot's session clip.
struct SessionSlot {
    /// `arrangement` is an audio slot's return, taken at its sample so it crossfades.
    enum Pending { case none, launch(ClipID), stop, arrangement }

    /// The arrangement is muted for the slot.
    var overrides = false
    var clip: ClipID?
    /// Index of `clip` in the lane's clips of the current snapshot, or −1.
    var index = -1
    /// Where the clip started, and where its current pass started.
    var launchTick: Tick = 0
    var base: Tick = 0
    var cursor = 0
    var pending = Pending.none
    var pendingTick: Tick = 0

    var isIdle: Bool {
        if case .none = pending { return true }
        return false
    }
}
