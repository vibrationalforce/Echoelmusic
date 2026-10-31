import AVFoundation
import EchoelCore
import SwiftUI
import UIKit

/// Shows the song's video tracks on the song clock (wave W7, C3): one muted `AVPlayer` follows the
/// position the engine is heard at, picked by `VideoPlan` — the top video track, the later part.
/// It keeps no time of its own. Ten times a second it compares where the player is with where
/// the clock says the file should be and holds, slews (±3 %) or seeks (`VideoPlan.correction`).
/// A video's own sound is never played. Not observable: nothing in a view body reads it (Law 6).
@MainActor
final class VideoMonitor {
    let player = AVPlayer()
    nonisolated static let tickMilliseconds = 100
    /// A seek while playing aims this far ahead, so it lands about where the clock is when it ends.
    nonisolated static let seekLeadSeconds = 0.1

    private var loop: Task<Void, Never>?
    private var loaded: (media: MediaID, url: URL)?
    private var seeking = false

    init() {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func start(store: ProjectStore, engine: AudioEngine, documents: DocumentController) {
        guard loop == nil else { return }
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.step(project: store.project, engine: engine, package: documents.currentURL)
                try? await Task.sleep(for: .milliseconds(VideoMonitor.tickMilliseconds))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        loaded = nil
        seeking = false
    }

    private func step(project: Project, engine: AudioEngine, package: URL?) {
        let playing = engine.isPlaying
        let position: Double
        if playing, let heard = engine.heardPosition(atHostTime: mach_absolute_time()) {
            position = heard.tick
        } else {
            position = Double(engine.playheadTick(in: project))
        }
        guard let shot = VideoPlan.shot(in: project, at: position), let file = project.mediaFile(shot.media),
              let package, let url = file.url(in: package) else {
            blank()
            return
        }
        if loaded?.media != shot.media || loaded?.url != url {
            loaded = (shot.media, url)
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            seek(to: shot.fileSeconds, playing: playing)
            return
        }
        guard !seeking else { return }
        let observed = player.currentTime().seconds
        guard playing else {
            if player.rate != 0 { player.pause() }
            if !(abs(observed - shot.fileSeconds) <= VideoPlan.deadbandSeconds) { seek(to: shot.fileSeconds, playing: false) }
            return
        }
        switch VideoPlan.correction(expected: shot.fileSeconds, observed: observed) {
        case .hold:
            if player.rate != 1 { player.rate = 1 }
        case .nudge(let rate):
            player.rate = Float(rate)
        case .seek(let seconds):
            seek(to: seconds, playing: true)
        }
    }

    private func seek(to seconds: Double, playing: Bool) {
        guard seconds.isFinite else { return }
        let target = Swift.max(0, seconds + (playing ? Self.seekLeadSeconds : 0))
        seeking = true
        player.pause()
        player.seek(to: CMTime(seconds: target, preferredTimescale: 48_000), toleranceBefore: .zero,
                    toleranceAfter: .zero) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.seeking = false }
        }
        if playing { player.rate = 1 }
    }

    private func blank() {
        guard loaded != nil else { return }
        loaded = nil
        seeking = false
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}

/// A view whose layer is the player's picture.
private final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
}

/// The picture of an `AVPlayer`, fitted whole into its frame on black.
struct PlayerPicture: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer?.videoGravity = .resizeAspect
        view.playerLayer?.player = player
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        (view as? PlayerLayerView)?.playerLayer?.player = player
    }
}

/// The song's video as a small window over the views, while the song has a video track. Its own
/// leaf: the monitor's loop runs only while it is on screen, and nothing above reads the clock.
struct VideoWindow: View {
    /// Whether the window shows; kept on this device, never in the song.
    nonisolated static let shownKey = "video.window.shown"

    let close: () -> Void
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var monitor = VideoMonitor()

    var body: some View {
        VStack(spacing: 0) {
            PlayerPicture(player: monitor.player)
                .frame(width: width, height: width * 9 / 16)
                .allowsHitTesting(false)
                .accessibilityLabel("Video")
            Divider().overlay(Theme.Color.border)
            HStack(spacing: 0) {
                Image(systemName: "film")
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .accessibilityLabel("Hide Video Window")
                    .accessibilityHint("The film button on a video track shows it again.")
            }
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.text)
            .background(Theme.Color.surface)
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Color.border, lineWidth: 1))
        .onAppear { monitor.start(store: store, engine: engine, documents: documents) }
        .onDisappear { monitor.stop() }
    }

    private var width: CGFloat { horizontalSizeClass == .regular ? 240 : 160 }
}
