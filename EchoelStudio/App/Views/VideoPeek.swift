import AVFoundation
import SwiftUI
import UIKit

/// A video's picture in the media browser before it is placed (2026-11-19, founder: „preview bei
/// Videos ist wichtig“): muted and over and over, in a leaf of its own. The player exists only while
/// the picture shows and stops with it; nothing is decoded into the song and nothing is heard — the
/// player is muted, as the video window's is (`VideoMonitor`).
struct VideoPeek: UIViewRepresentable {
    let url: URL

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view.playerLayer?.videoGravity = .resizeAspect
        view.playerLayer?.player = player
        player.play()
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    static func dismantleUIView(_ view: PlayerView, coordinator: Coordinator) {
        view.playerLayer?.player?.pause()
        view.playerLayer?.player = nil
        coordinator.looper?.disableLooping()
        coordinator.looper = nil
    }
}
