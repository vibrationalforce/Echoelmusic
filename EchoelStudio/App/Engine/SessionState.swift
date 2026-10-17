import EchoelCore
import EchoelEngine
import Observation

/// What the session plays, as the render thread reports it: per track the clip that plays,
/// the one waiting for its bar, and whether the track left the arrangement. Changes only at
/// launch boundaries, so a view may read it in its body.
@MainActor
@Observable
final class SessionState {
    private(set) var playing: [TrackID: ClipID] = [:]
    private(set) var queued: [TrackID: ClipID] = [:]
    /// Tracks the session took over; their arrangement is silent until Back to Arrangement.
    private(set) var detached: Set<TrackID> = []
    /// How long a launch waits: nil one bar, 0 none, otherwise ticks.
    var quantum: Tick?

    func apply(_ report: LaunchReport, to track: TrackID) {
        switch report.state {
        case .queued:
            if let clip = report.clip { queued[track] = clip }
        case .playing:
            queued[track] = nil
            playing[track] = report.clip
            detached.insert(track)
        case .stopped:
            if playing[track] == report.clip || report.clip == nil { playing[track] = nil }
            if queued[track] == report.clip { queued[track] = nil }
        case .arrangement:
            playing[track] = nil
            queued[track] = nil
            detached.remove(track)
        }
    }

    /// A new engine core starts with nothing launched.
    func reset() {
        playing = [:]
        queued = [:]
        detached = []
    }
}
