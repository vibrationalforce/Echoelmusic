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

    /// Forgets every track not in `tracks`, the ones that hold a slot. A deleted track, another
    /// song's, or an audio track whose slot went to an instrument never gets a report again, so
    /// what it played would stay lit, and Stop All and Back to Arrangement enabled, for good
    /// (audit 2026-10-23). Writes only what changes: this runs with every snapshot.
    func retain(_ tracks: Set<TrackID>) {
        let keptPlaying = playing.filter { tracks.contains($0.key) }
        if keptPlaying.count != playing.count { playing = keptPlaying }
        let keptQueued = queued.filter { tracks.contains($0.key) }
        if keptQueued.count != queued.count { queued = keptQueued }
        if !detached.isSubset(of: tracks) { detached.formIntersection(tracks) }
    }

    /// A new engine core starts with nothing launched.
    func reset() {
        playing = [:]
        queued = [:]
        detached = []
    }
}
