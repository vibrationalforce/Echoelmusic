// VideoLaneAVSink.swift
// Echoel — One World V3a (founder 2026-10-15: "Video Spur fehlt"). The device half of the picture
// lane: one silent `AVPlayer` whose frames reach the visual through `VideoLayerSlot`, driven ONLY by
// `VideoLanePlayer` on the transport's step. It has no clock of its own — no periodic or boundary
// observer, no timer, no end-of-item loop. Where the file runs out, `actionAtItemEnd = .pause` holds
// the last frame and the plan's next correction decides what follows.
//
// ⭐ THE SAME SLOT RULE AS THE VIDEO CARD (One World V1): the last attach wins, and this sink lets go
// only of the output IT attached. Every show (Play, a locate, a new part, a loop wrap, a structure
// edit while playing) puts the lane's output
// back if the card took the slot meanwhile; stopping the card's footage cannot blank the lane, and
// the other way round. ⚠️ A card shown or hidden WHILE the song plays takes or empties the slot
// until the lane's next show — known, not covered.
//
// ⭐ ONE CLOSURE IS HANDED TO AVFOUNDATION, and it is spelled `@Sendable`: the seek's completion,
// which hops to main once per SEEK, never per frame (2613/2618: a closure a framework calls off main
// must not inherit main-actor isolation). The file is measured by the async geometry read inside a
// main-actor `Task`, once per new file. Seeks are COALESCED: while one is in
// flight the newest target waits, and older targets are dropped, so a Flow tempo glide never queues
// a seek per step. While loading or seeking `observedSeconds` is nil, so the executor does not
// correct a position in flux.
//
// ⚠️ NOT DEVICE-VERIFIED: whether the picture holds the beat, whether a nudge reads as invisible,
// and whether a seek on a long file lands quickly enough are device probes.
// NEEDS-FOUNDER-VERIFY: put a video part on a picture track, press Play — the picture runs with the
// song, stops with it, and starts where the playhead is after a locate.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

@MainActor
final class VideoLaneAVSink: VideoLaneSink {

    private var player: AVPlayer?
    /// The output this sink attached — the only one its `clear` may take down (One World V1).
    private var output: AVPlayerItemVideoOutput?
    /// The file loaded (or loading) now.
    private var url: URL?
    /// The video track's own transform, kept for a re-attach.
    private var transform: CGAffineTransform = .identity
    /// Bumped by every load and every clear, so a load a later shot overtook attaches nothing.
    private var generation = 0
    private var loading = false
    private var seeking = false
    /// The newest seek asked while another was in flight.
    private var pendingSeek: (seconds: Double, play: Bool)?
    /// Whether the transport wants the picture moving (show without a held frame), so a seek
    /// lands playing or still.
    private var running = false

    var observedSeconds: Double? {
        guard !loading, !seeking, let player else { return nil }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : nil
    }

    var itemSeconds: Double? {
        guard let seconds = player?.currentItem?.duration.seconds, seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    func show(_ shot: VideoLanePlan.Shot) {
        running = !shot.holdsLastFrame
        if shot.url == url, loading {
            // The newest target waits for the load (a locate or a wrap during a slow load).
            pendingSeek = (shot.mediaSeconds, running)
            return
        }
        if shot.url == url, player != nil {
            attachIfTaken()   // the video card may have taken the slot since the last show
            seek(to: shot.mediaSeconds, play: running)
            return
        }
        load(shot)
    }

    func correct(_ resync: VideoLanePlan.Resync) {
        guard let player, !loading, !seeking else { return }
        switch resync {
        case .hold:
            if running, player.rate != 0, player.rate != 1 { player.rate = 1 }
        case .nudge(let rate):
            if running, rate.isFinite, rate > 0 { player.rate = rate }
        case .seek(let seconds):
            seek(to: seconds, play: running)
        }
    }

    func pause() {
        running = false
        pendingSeek = nil
        player?.pause()
    }

    func clear() {
        generation += 1
        running = false
        loading = false
        seeking = false
        pendingSeek = nil
        player?.pause()
        player = nil
        url = nil
        if let output { VideoLayerSlot.shared.detachVideoOutput(ifAttached: output) }
        output = nil
    }

    private func load(_ shot: VideoLanePlan.Shot) {
        clear()
        running = !shot.holdsLastFrame   // `clear` stops the run; this shot starts it again
        let token = generation
        url = shot.url
        loading = true
        Task { @MainActor [weak self] in
            let geometry = await VideoFootageGeometry.load(url: shot.url)
            guard let self, token == self.generation else { return }
            self.loading = false
            guard let geometry else {
                // No readable picture: the lane stays dark rather than holding an empty layer.
                self.url = nil
                return
            }
            let item = AVPlayerItem(url: shot.url)
            let output = VideoLayerSlot.makeVideoOutput(naturalWidth: geometry.width, naturalHeight: geometry.height)
            item.add(output)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .pause
            self.player = player
            self.output = output
            self.transform = geometry.transform
            self.attachIfTaken()
            let target = self.pendingSeek?.seconds ?? shot.mediaSeconds
            self.pendingSeek = nil
            self.seek(to: target, play: self.running)
        }
    }

    /// Put this sink's output on the slot unless it is already there — the one attach. Re-asked on
    /// every show, so a lane whose slot the video card took is put back on Play.
    private func attachIfTaken() {
        guard let output, !VideoLayerSlot.shared.holds(output) else { return }
        VideoLayerSlot.shared.attachVideoOutput(output, preferredTransform: transform, dial: 1)
    }

    /// One seek at a time; the newest target waits and older ones are dropped.
    private func seek(to seconds: Double, play: Bool) {
        guard seconds.isFinite, let player else { return }
        if seeking {
            pendingSeek = (seconds, play)
            return
        }
        seeking = true
        player.pause()
        let token = generation
        let target = CMTime(seconds: Swift.max(0, seconds), preferredTimescale: 600)
        // AVFoundation may call this off main: `@Sendable`, and one hop per SEEK, never per frame.
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { @Sendable [weak self] _ in
            Task { @MainActor in self?.seekLanded(token: token, play: play) }
        }
    }

    private func seekLanded(token: Int, play: Bool) {
        guard token == generation else { return }
        seeking = false
        if let next = pendingSeek {
            pendingSeek = nil
            seek(to: next.seconds, play: next.play)
            return
        }
        if play, running { player?.playImmediately(atRate: 1) }
    }
}
#endif
