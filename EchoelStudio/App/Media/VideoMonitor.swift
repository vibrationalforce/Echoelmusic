import AVFoundation
import EchoelCore
import Observation
import QuartzCore
import SwiftUI
import UIKit

/// Shows the song's video tracks on the song clock (wave W7, C3): one muted `AVPlayer` follows the
/// position the engine is heard at, picked by `VideoPlan` — the top video track, the later part.
/// It keeps no time of its own. Ten times a second it compares where the player is with where
/// the clock says the file should be and holds, slews (±3 %) or seeks (`VideoPlan.correction`).
/// A video's own sound is never played. Not observable: nothing in a view body reads it (Law 6).
///
/// The picture is a person's own footage, and footage can strobe. While the window shows, every
/// new frame is measured small and counted (`VideoFlashWatch`, over `VideoFlashLimit`); the gain it
/// answers is handed to the picture's leaf through `flashGate`, so a strobing passage is shown
/// dimmed instead of flashing. The live stream and the export do not come through here.
@MainActor
final class VideoMonitor {
    let player = AVPlayer()
    nonisolated static let tickMilliseconds = 100
    /// How often the shown frame is looked at for the flash limit: faster than any frame rate a
    /// phone plays, so no frame of a strobe goes by uncounted.
    nonisolated static let measureMilliseconds = 8
    /// A seek while playing aims this far ahead, so it lands about where the clock is when it ends.
    nonisolated static let seekLeadSeconds = 0.1

    private var loop: Task<Void, Never>?
    private var loaded: (media: MediaID, url: URL)?
    private var seeking = false

    /// The gain the shown picture may have, for the one leaf that draws it.
    let flashGate = VideoFlashGate()
    /// The loaded file's frames at `VideoFlashCells.pixelsPerSide`, only for measuring.
    private var measuring: AVPlayerItemVideoOutput?
    private var measureLoop: Task<Void, Never>?
    private var flashWatch = VideoFlashWatch()

    /// Hands the loaded file's frames to a picture the app draws itself — the Field layer's preview
    /// (W15) — while true. Off, nothing is decoded beyond what the player's own layer shows.
    var deliversFrames = false {
        didSet {
            guard deliversFrames != oldValue else { return }
            // The Field is drawn with the footage now, or no longer: the flash limit counts the
            // footage's colors only while it is (`VideoFlashWatch.isBlended`).
            flashWatch.isBlended = deliversFrames
            detachOutput()
            if let item = player.currentItem { attachOutput(to: item) }
        }
    }
    /// The frames of the loaded file while `deliversFrames` is on.
    private(set) var output: AVPlayerItemVideoOutput?
    /// How the loaded file stands — its own orientation, which a frame of it does not carry — so a
    /// picture drawn from its frames turns them upright as the player's layer does. While the colour
    /// correction draws the frames they arrive upright already, and nothing more is turned.
    var orientation: CGAffineTransform { grading == .attached ? .identity : fileOrientation }
    private var fileOrientation: CGAffineTransform = .identity

    /// The colour correction of the part showing (COLOR), read by `ColorGradeCompositor` for every
    /// frame — the export's drawing, so the window shows what the export writes.
    private let grade = ColorGradeSource()
    /// Whether the loaded file's frames go through the colour correction: only while a part of it
    /// has one, so a song without one plays exactly as before.
    private enum Grading { case off, loading, attached }
    private var grading = Grading.off

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
        measureLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.measureShownFrame()
                try? await Task.sleep(for: .milliseconds(VideoMonitor.measureMilliseconds))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        measureLoop?.cancel()
        measureLoop = nil
        grading = .off
        player.pause()
        detachOutput()
        detachMeasuring()
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
            detachMeasuring()
            let item = AVPlayerItem(url: url)
            attachOutput(to: item)
            attachMeasuring(to: item)
            player.replaceCurrentItem(with: item)
            grading = .off
            loadOrientation(of: url)
            updateGrade(project: project, shot: shot, url: url)
            seek(to: shot.fileSeconds, playing: playing)
            return
        }
        updateGrade(project: project, shot: shot, url: url)
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
        grading = .off
        player.pause()
        detachOutput()
        detachMeasuring()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - The flash limit for the shown picture

    private static var measuringAttributes: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
         kCVPixelBufferWidthKey as String: VideoFlashCells.pixelsPerSide,
         kCVPixelBufferHeightKey as String: VideoFlashCells.pixelsPerSide]
    }

    private func attachMeasuring(to item: AVPlayerItem) {
        let made = AVPlayerItemVideoOutput(pixelBufferAttributes: Self.measuringAttributes)
        item.add(made)
        measuring = made
    }

    private func detachMeasuring() {
        if let measuring, let item = player.currentItem, item.outputs.contains(measuring) { item.remove(measuring) }
        measuring = nil
    }

    /// One look at what is shown now, on the display's clock: a new frame is measured and counted,
    /// a held one only lets a lowered gain climb back (`VideoFlashWatch`). A frame that cannot be
    /// read changes nothing.
    private func measureShownFrame() {
        guard let output = measuring else { return }
        let now = CACurrentMediaTime()
        let itemTime = output.itemTime(forHostTime: now)
        if output.hasNewPixelBuffer(forItemTime: itemTime),
           let pixel = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            flashGate.update(show(pixel, at: now))
        } else {
            flashGate.update(flashWatch.hold(at: now))
        }
    }

    /// Hands a frame's bytes to the watch and answers the gain.
    private func show(_ pixel: CVPixelBuffer, at time: Double) -> Double {
        guard CVPixelBufferLockBaseAddress(pixel, .readOnly) == kCVReturnSuccess else { return flashWatch.gain }
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixel) else { return flashWatch.gain }
        let height = CVPixelBufferGetHeight(pixel)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixel)
        let bytes = UnsafeRawBufferPointer(start: base, count: bytesPerRow * height)
        return flashWatch.show(bgra: bytes, width: CVPixelBufferGetWidth(pixel), height: height,
                               bytesPerRow: bytesPerRow, at: time)
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
        fileOrientation = .identity
        Task { @MainActor [weak self] in
            let transform = await VideoMonitor.preferredTransform(of: url)
            guard let self, self.loaded?.url == url else { return }
            self.fileOrientation = transform
        }
    }

    // MARK: - Colour correction (COLOR)

    /// The grade of the part showing, and the drawing through it switched on while any part of the
    /// loaded file has one — off again when none has.
    private func updateGrade(project: Project, shot: VideoPlan.Shot, url: URL) {
        let shown = project.track(shot.track).flatMap { track in track.regions.first { $0.id == shot.region } }?.grade
        grade.grade = shown?.held ?? .neutral
        let wanted = project.tracks.contains { track in
            track.kind == .video && track.regions.contains { $0.media == shot.media && !($0.grade?.held.isNeutral ?? true) }
        }
        switch (wanted, grading) {
        case (true, .off):
            grading = .loading
            let source = grade
            Task { @MainActor [weak self] in
                let composition = await VideoMonitor.gradingComposition(of: url, grade: source)
                guard let self, self.loaded?.url == url, self.grading == .loading else { return }
                guard let composition else {
                    self.grading = .off
                    return
                }
                self.player.currentItem?.videoComposition = composition
                self.grading = .attached
            }
        case (false, .attached), (false, .loading):
            player.currentItem?.videoComposition = nil
            grading = .off
        default:
            break
        }
    }

    /// What the window's drawing needs to know of a file's picture track, read off the main thread.
    private struct PictureTrack: Sendable {
        let id: CMPersistentTrackID
        let natural: CGSize
        let transform: CGAffineTransform
        let endSeconds: Double
        let framesPerSecond: Double
    }

    nonisolated private static func pictureTrack(of url: URL) async -> PictureTrack? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let loaded = try? await track.load(.naturalSize, .preferredTransform, .timeRange, .nominalFrameRate) else {
            return nil
        }
        let (natural, transform, range, rate) = loaded
        return PictureTrack(id: track.trackID, natural: natural, transform: transform, endSeconds: CMTimeGetSeconds(CMTimeRangeGetEnd(range)),
                            framesPerSecond: rate.isFinite && rate >= 1 ? Double(rate) : 30)
    }

    /// The file's picture, upright, through `ColorGradeCompositor` — the export's drawing.
    private static func gradingComposition(of url: URL, grade: ColorGradeSource) async -> AVVideoComposition? {
        guard let picture = await pictureTrack(of: url) else { return nil }
        let upright = CGRect(origin: .zero, size: picture.natural).applying(picture.transform)
        let size = CGSize(width: abs(upright.width).rounded(), height: abs(upright.height).rounded())
        guard size.width >= 1, size.height >= 1 else { return nil }
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = ColorGradeCompositor.self
        composition.renderSize = size
        composition.frameDuration = CMTime(seconds: 1 / picture.framesPerSecond, preferredTimescale: 60_000)
        let placing = VideoExport.placement(natural: picture.natural, transform: picture.transform, in: size, fit: .fit)
        let end = CMTime(seconds: picture.endSeconds.isFinite ? Swift.max(picture.endSeconds, 0) : 0, preferredTimescale: 60_000)
        composition.instructions = [ColorGradeInstruction(timeRange: CMTimeRange(start: .zero, end: end),
                                                          track: picture.id, placing: placing, grade: grade)]
        return composition
    }

    nonisolated private static func preferredTransform(of url: URL) async -> CGAffineTransform {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let transform = try? await track.load(.preferredTransform) else { return .identity }
        return transform
    }
}

/// The gain the shown footage may have (`VideoFlashLimit`), for the picture's leaf: 1 while
/// nothing flashes, near 0 while something does, climbing back afterwards. Observed, and written
/// only when it moves, so a quiet film draws nothing again.
@MainActor
@Observable
final class VideoFlashGate {
    private(set) var gain = 1.0
    /// The picture is held back now: said in the window's bar, so a dark picture has a reason.
    private(set) var isLimiting = false

    func update(_ next: Double) {
        guard next.isFinite else { return }
        if next != gain { gain = next }
        let limiting = next < 1
        if limiting != isLimiting { isLimiting = limiting }
    }
}

/// The footage's picture behind its flash limit: on black, as bright as the limit allows. The one
/// view that reads the moving gain (Law 6).
private struct FlashLimitedPicture<Content: View>: View {
    let gate: VideoFlashGate
    let content: Content

    init(gate: VideoFlashGate, @ViewBuilder content: () -> Content) {
        self.gate = gate
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black
            content.opacity(gate.gain)
        }
    }
}

/// Says in the window's bar why the picture is dark while the limit holds it back.
private struct FlashLimitNote: View {
    let gate: VideoFlashGate

    var body: some View {
        if gate.isLimiting {
            Text("Flash limit")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("The picture flashes and is dimmed")
        }
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
                FlashLimitNote(gate: monitor.flashGate)
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
        FlashLimitedPicture(gate: monitor.flashGate) {
            ZStack {
                PlayerPicture(player: monitor.player)
                if layer.isVisible {
                    FieldLayerPicture(monitor: monitor, layer: layer, reduceMotion: reduceMotion)
                }
            }
        }
    }

    /// The export's layer, as the export takes it.
    private var layer: FieldLayer { FieldLayer.stored(blend: fieldBlend, percent: fieldOpacity) }

    private var width: CGFloat { horizontalSizeClass == .regular ? 240 : 160 }
}
