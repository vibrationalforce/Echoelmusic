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
// ⚠️ ONE PICTURE, ONE LANE (v1). The visual has ONE footage layer, so the lane shown is the FIRST
// picture lane in the document's order (`TimelineDocument.videoLaneIDs`); a second picture lane is
// never shown. Mute, solo and level are not read yet — `VideoLanePlan` records that as a founder
// question, and this file keeps the answer open rather than guessing it.
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
    /// Apply a drift correction the plan computed.
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

    /// The file a clip resolves to — the one answer the Play button's question asks too (#1439).
    public func resolvedURL(forClipID id: UUID) -> URL? { resolveURL(id) }

    /// The one lane shown: the first picture lane in the document's order.
    nonisolated static func shownLane(in document: TimelineDocument) -> UUID? {
        document.videoLaneIDs.first
    }

    /// Start, locate, cycle wrap or a structure edit: show what the shown lane plays at `tick`,
    /// or go dark.
    public func prime(in document: TimelineDocument, atTick tick: Int, bpm: Double) {
        guard let lane = Self.shownLane(in: document),
              let shot = VideoLanePlan.shot(in: document, laneID: lane, at: tick, bpm: bpm,
                                            clip: clip, resolveURL: resolveURL) else {
            clear()
            return
        }
        show(shot)
    }

    /// One contiguous transport step `fromTick` → `toTick`: a new part shows, a gap clears, and the
    /// same part is corrected toward the song clock when the sink can say where it is.
    public func apply(in document: TimelineDocument, fromTick: Int, toTick: Int, bpm: Double) {
        guard let lane = Self.shownLane(in: document) else {
            clear()
            return
        }
        let commands = VideoLanePlan.commands(in: document, fromTick: fromTick, toTick: toTick, bpm: bpm,
                                              clip: clip, resolveURL: resolveURL)
        for command in commands {
            switch command {
            case .show(let shot) where shot.laneID == lane:
                show(shot)
            case .clear(let laneID) where laneID == lane:
                clear()
            case .keep(let laneID) where laneID == lane:
                correct(in: document, lane: lane, atTick: toTick, bpm: bpm)
            default:
                continue
            }
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
        guard current != nil, let sink, let observed = sink.observedSeconds,
              let expected = VideoLanePlan.shot(in: document, laneID: lane, at: tick, bpm: bpm,
                                                clip: clip, resolveURL: resolveURL) else { return }
        let resync = VideoLanePlan.resync(expected, observedSeconds: observed, itemSeconds: sink.itemSeconds)
        if resync != .hold { sink.correct(resync) }
    }
}
