// VideoLanePlayer.swift
// Echoel — Sequencer
//
// One World V2 (founder 2026-10-15: "Video Spur fehlt") — the VV-8 executor, the piece
// `VideoLanePlan` waited for. It turns the pure plan into calls on ONE picture sink while the
// transport runs, on the transport's own step: `TimelineRegionPlayer` primes it where it primes the
// audio lanes (play, locate, cycle wrap, a structure edit), steps it where it steps them, and
// releases it on both stop paths. No clock, no timer, no observer of its own — the song clock is the
// one every lane rides, and the drift correction runs on the step that already fires.
//
// ⭐ FOUNDATION-ONLY, like the plan. The device half — an `AVPlayer` feeding `VideoLayerSlot` — is the
// injected `VideoLaneSink` (`Studio/VideoLaneAVSink.swift`), so this file can be driven end to end
// by a spy sink in the blocking bundle.
//
// ⭐ ONE PICTURE, STACKED LANES (One World M2, the multi-camera cut). The visual has ONE footage
// layer, so ONE lane shows at a time: the TOP picture lane (document order) that has a part to show
// there (`VideoLanePlan.programShot`). A lower lane shows through wherever every lane above it is
// dark — trim or split the top angle and the next one takes over, exactly as in a video editor.
// A two-lens take (M1) lands rear on the top track and front below it. Mute, solo and level are
// not read yet — `VideoLanePlan` records that as a founder question, and this file keeps the answer
// open rather than guessing it.
//
// ⚠️ NOT DEVICE-VERIFIED. Whether the picture stays on the beat — the resync constants, the seek
// cadence under a Flow tempo glide — is a device probe. Nothing here may be claimed in store text,
// on the website or in `ContentPipeline/CLAIMS.md` until a device run has watched it.

import Foundation

/// The device half of a picture lane: what shows the file. Main-actor, and never observable — the
/// player is driven from the transport step, and nothing in a SwiftUI body may read it.
@MainActor
public protocol VideoLaneSink: AnyObject {
    /// Load `shot.url` (or keep it when it is the file already loaded) and run it from
    /// `shot.mediaSeconds` — held still when `shot.holdsLastFrame`.
    func show(_ shot: VideoLanePlan.Shot)
    /// Apply the correction the plan computed — `.hold` included, so a nudged rate goes back to 1
    /// once the picture is inside the deadband again.
    func correct(_ resync: VideoLanePlan.Resync)
    /// The transport stopped: hold the frame on screen, stop advancing.
    func pause()
    /// The lane went dark: let the picture go.
    func clear()
    /// The file position the player shows now, or nil while it loads or seeks — then no correction
    /// is asked, because a position in flux is not a measurement.
    var observedSeconds: Double? { get }
    /// The length the player measured for its file, or nil while it does not know.
    var itemSeconds: Double? { get }
}

/// The picture lane's executor: the plan's answers, applied to one sink on the transport's step.
@MainActor
public final class VideoLanePlayer {

    private let makeSink: () -> VideoLaneSink
    private let resolveURL: (UUID) -> URL?
    private let clip: (UUID) -> Clip?
    private var sink: VideoLaneSink?
    /// What the sink shows now, or nil while the lane is dark.
    private(set) var current: VideoLanePlan.Shot?

    /// `resolveURL` is the SAME resolver the audio lanes and the Play button ask (#1439) — the app
    /// hands both players one closure.
    public init(makeSink: @escaping () -> VideoLaneSink, resolveURL: @escaping (UUID) -> URL?,
                clip: @escaping (UUID) -> Clip?) {
        self.makeSink = makeSink
        self.resolveURL = resolveURL
        self.clip = clip
    }

    /// The file a clip resolves to, through the injected resolver — the same closure the app hands
    /// the audio lanes, whose `resolvedURL` the Play button asks (#1439). No caller yet.
    public func resolvedURL(forClipID id: UUID) -> URL? { resolveURL(id) }

    /// The top picture track — the one a picked file or a rear-lens take lands on, and the one that
    /// covers every track below it.
    nonisolated static func topLane(in document: TimelineDocument) -> UUID? {
        document.videoLaneIDs.first
    }

    /// Start, locate, cycle wrap or a structure edit: show the picture the song shows at `tick`
    /// (`VideoLanePlan.programShot`), or go dark.
    public func prime(in document: TimelineDocument, atTick tick: Int, bpm: Double) {
        guard let shot = VideoLanePlan.programShot(in: document, at: tick, bpm: bpm,
                                                   clip: clip, resolveURL: resolveURL) else {
            clear()
            return
        }
        show(shot)
    }

    /// One contiguous transport step `fromTick` → `toTick`. While no picture lane changes, the part
    /// showing is corrected toward the song clock. When any lane changes — a part starts or ends on
    /// ANY track — the stack is asked again: the same part keeps playing (and is corrected), another
    /// part takes over from its own song position, or the picture goes.
    public func apply(in document: TimelineDocument, fromTick: Int, toTick: Int, bpm: Double) {
        guard !document.videoLaneIDs.isEmpty else {
            clear()
            return
        }
        let commands = VideoLanePlan.commands(in: document, fromTick: fromTick, toTick: toTick, bpm: bpm,
                                              clip: clip, resolveURL: resolveURL)
        let changed = commands.contains { command in
            if case .keep = command { return false }
            return true
        }
        guard changed else {
            if let showing = current { correct(in: document, lane: showing.laneID, atTick: toTick, bpm: bpm) }
            return
        }
        guard let next = VideoLanePlan.programShot(in: document, at: toTick, bpm: bpm,
                                                   clip: clip, resolveURL: resolveURL) else {
            clear()
            return
        }
        if let showing = current, showing.laneID == next.laneID, showing.regionID == next.regionID {
            correct(in: document, lane: next.laneID, atTick: toTick, bpm: bpm)   // a change below: keep running
        } else {
            show(next)
        }
    }

    /// Both stop paths: the picture holds its frame and stops advancing.
    public func stopAll() {
        sink?.pause()
    }

    private func show(_ shot: VideoLanePlan.Shot) {
        let target = sink ?? makeSink()
        sink = target
        current = shot
        target.show(shot)
    }

    private func clear() {
        guard current != nil else { return }
        current = nil
        sink?.clear()
    }

    /// The drift correction for the part still showing — only while the sink reports a settled
    /// position, so a load or a seek in flight is never corrected again.
    private func correct(in document: TimelineDocument, lane: UUID, atTick tick: Int, bpm: Double) {
        // The file is the one already showing: no resolver (no file probes) on the step path.
        guard let showing = current, let sink, let observed = sink.observedSeconds,
              let expected = VideoLanePlan.shot(in: document, laneID: lane, at: tick, bpm: bpm,
                                                clip: clip, resolveURL: { _ in showing.url }) else { return }
        // `.hold` goes through too: inside the deadband the sink returns a nudged rate to 1.
        sink.correct(VideoLanePlan.resync(expected, observedSeconds: observed, itemSeconds: sink.itemSeconds))
    }
}
