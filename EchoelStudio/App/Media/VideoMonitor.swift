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

    /// Hands the loaded file's frames to a picture the app draws itself — the Field layer's preview
    /// (W15) — while true. Off, nothing is decoded beyond what the player's own layer shows.
    var deliversFrames = false {
        didSet {
            guard deliversFrames != oldValue else { return }
            detachOutput()
            if let item = player.currentItem { attachOutput(to: item) }
        }
    }
    /// The frames of the loaded file while `deliversFrames` is on.
    private(set) var output: AVPlayerItemVideoOutput?
    /// How the loaded file stands — its own orientation, which a frame of it does not carry — so a
    /// picture drawn from its frames turns them upright as the player's layer does.
    private(set) var orientation: CGAffineTransform = .identity

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
        detachOutput()
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
            detachOutput()
            let item = AVPlayerItem(url: url)
            attachOutput(to: item)
            player.replaceCurrentItem(with: item)
            loadOrientation(of: url)
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
        detachOutput()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - Frames for the Field layer's preview (W15)

    private static var frameAttributes: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
         kCVPixelBufferMetalCompatibilityKey as String: true]
    }

    private func attachOutput(to item: AVPlayerItem) {
        guard deliversFrames else { return }
        let made = AVPlayerItemVideoOutput(pixelBufferAttributes: Self.frameAttributes)
        item.add(made)
        output = made
    }

    private func detachOutput() {
        if let output, let item = player.currentItem, item.outputs.contains(output) { item.remove(output) }
        output = nil
    }

    /// Reads the file's orientation off the main thread; a file loaded meanwhile keeps its own.
    private func loadOrientation(of url: URL) {
        orientation = .identity
        Task { @MainActor [weak self] in
            let transform = await VideoMonitor.preferredTransform(of: url)
            guard let self, self.loaded?.url == url else { return }
            self.orientation = transform
        }
    }

    nonisolated private static func preferredTransform(of url: URL) async -> CGAffineTransform {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let transform = try? await track.load(.preferredTransform) else { return .identity }
        return transform
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
/// With the export's Field Layer on (W15), the window draws the Field over the picture the way the
/// export will (`FieldLayerPicture`); the setting is read cold, the moving parts in the draw loop.
struct VideoWindow: View {
    /// Whether the window shows; kept on this device, never in the song.
    nonisolated static let shownKey = "video.window.shown"

    let close: () -> Void
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monitor = VideoMonitor()
    @AppStorage(VideoExportView.fieldBlendKey) private var fieldBlend = FieldLayer.Blend.off
    @AppStorage(VideoExportView.fieldOpacityKey) private var fieldOpacity = FieldLayer().opacityPercent

    var body: some View {
        VStack(spacing: 0) {
            picture
                .frame(width: width, height: width * 9 / 16)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(layer.isVisible ? "Video with the Field" : "Video")
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
        .onAppear {
            monitor.deliversFrames = layer.isVisible
            monitor.start(store: store, engine: engine, documents: documents)
        }
        .onDisappear { monitor.stop() }
        .onChange(of: layer.isVisible) { _, visible in monitor.deliversFrames = visible }
    }

    /// The player's own picture, and over it — while the layer shows — the picture with the Field,
    /// drawn by the export's pass. Should that pass not build, it stands aside and the plain
    /// picture shows.
    private var picture: some View {
        ZStack {
            PlayerPicture(player: monitor.player)
            if layer.isVisible {
                FieldLayerPicture(monitor: monitor, layer: layer, reduceMotion: reduceMotion)
            }
        }
    }

    /// The export's layer, as the export takes it.
    private var layer: FieldLayer { FieldLayer.stored(blend: fieldBlend, percent: fieldOpacity) }

    private var width: CGFloat { horizontalSizeClass == .regular ? 240 : 160 }
}
