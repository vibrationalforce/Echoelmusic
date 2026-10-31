import AVFoundation
import CoreVideo
import EchoelCore
import EchoelEngine
import MetalKit
import QuartzCore
import SwiftUI
import UIKit

/// The video window's picture with the Field over it (wave W15): the video's frames, placed upright
/// and whole, and the Field laid over them by the same GPU pass and the same formula as the export
/// (`FieldLayerPass`), in real time. It shows the film the export will write: the song as it plays
/// — its beat, its key and the master's level — without the body, which the export leaves out.
///
/// Light on the device: at most `FieldLayerPreview.framesPerSecond` frames a second, a drawable no
/// longer than `FieldLayerPreview.longestSide` pixels, no frame drawn while nothing has changed,
/// and the Field held still under Reduce Motion, Low Power Mode or a warm device. Everything that
/// moves is read in the view's own draw loop, never in a SwiftUI body (Law 6).
struct FieldLayerPicture: UIViewRepresentable {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let monitor: VideoMonitor
    let layer: FieldLayer
    /// The system's Reduce Motion, read by the SwiftUI parent and handed down cold.
    let reduceMotion: Bool

    func makeCoordinator() -> FieldLayerPreview { FieldLayerPreview() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        let preview = context.coordinator
        if let pass = FieldLayerPass.make() {
            view.device = pass.device
            preview.pass = pass
        } else {
            // No pass (a shader that did not build, the log says why): this view stands aside and
            // the player's own picture under it shows, so the video is never hidden by the layer.
            view.isHidden = true
        }
        view.delegate = preview
        view.clearColor = MetalFieldRenderer.ground
        // The pass computes linear light; the sRGB drawable encodes it on write.
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.framebufferOnly = true
        view.preferredFramesPerSecond = FieldLayerPreview.framesPerSecond
        view.isPaused = preview.pass == nil
        view.enableSetNeedsDisplay = false
        view.isOpaque = true
        // The preview sizes its drawable itself, capped (see `FieldLayerPreview.settleDrawable`).
        view.autoResizeDrawable = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        // References and cold settings only; the playhead, the meter and the frames are read in
        // the draw loop.
        let preview = context.coordinator
        preview.store = store
        preview.engine = engine
        preview.monitor = monitor
        preview.layer = layer
        preview.reduceMotion = reduceMotion
    }
}

/// Draws the video window's picture with the Field over it. `MTKView` calls it on the main thread
/// (its display link), so the song, the meter and the video frame are read under
/// `MainActor.assumeIsolated`.
final class FieldLayerPreview: NSObject, MTKViewDelegate {
    /// Half the Field window's rate: a card beside the work, not the stage.
    nonisolated static let framesPerSecond = 30
    /// The drawable's longest side, in pixels: enough for a card, a fraction of the GPU time of a
    /// full-resolution layer.
    nonisolated static let longestSide: CGFloat = 640

    var pass: FieldLayerPass?
    weak var store: ProjectStore?
    weak var engine: AudioEngine?
    weak var monitor: VideoMonitor?
    var layer = FieldLayer()
    var reduceMotion = false

    private var motion = FieldMotion()
    private var lastFrameTime = CFAbsoluteTimeGetCurrent()
    /// The newest frame the player handed over, kept until a newer one comes.
    private var picture: CVPixelBuffer?
    /// What the last drawn frame showed: the same again is not drawn again.
    private var lastDrawn: Drawn?

    private struct Drawn: Equatable {
        let shown: FieldMotion.Shown
        let layer: FieldLayer
        let picture: ObjectIdentifier?
        let width: Int
        let height: Int
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        // Real elapsed time, clamped after a stall, so the motion is frame-rate independent.
        let seconds = Swift.min(Swift.max(now - lastFrameTime, 0), 0.1)
        lastFrameTime = now
        MainActor.assumeIsolated {
            drawFrame(in: view, after: seconds)
        }
    }

    @MainActor
    private func drawFrame(in view: MTKView, after seconds: Double) {
        guard let pass, let store, let engine else { return }
        settleDrawable(of: view)
        if let output = monitor?.output {
            let time = output.itemTime(forHostTime: CACurrentMediaTime())
            if output.hasNewPixelBuffer(forItemTime: time),
               let pixel = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
                picture = pixel
            }
        } else {
            picture = nil
        }
        // The film the export will write: the song as it plays, without the body (`FieldExport`).
        let frame = FieldFrame.current(store: store, engine: engine).withoutBody
        let shown = motion.step(frame, after: seconds, still: reduceMotion || Self.deviceAsksForStillness(),
                                patternScale: 1)
        let size = view.drawableSize
        let drawn = Drawn(shown: shown, layer: layer, picture: picture.map { ObjectIdentifier($0) },
                          width: Int(size.width), height: Int(size.height))
        // Nothing changed: the last frame stays on the layer, and the GPU rests.
        if drawn == lastDrawn { return }
        guard let drawable = view.currentDrawable, let buffer = pass.queue.makeCommandBuffer() else { return }
        let wrapped = picture.flatMap { pass.texture($0) }
        let placement = picture.flatMap { pixel -> FieldLayerPlacement? in
            let natural = CGSize(width: CVPixelBufferGetWidth(pixel), height: CVPixelBufferGetHeight(pixel))
            let placing = VideoExport.placement(natural: natural, transform: monitor?.orientation ?? .identity,
                                                in: size, fit: .fit)
            return FieldLayerPlacement(placing: placing, sourceWidth: Double(natural.width),
                                       sourceHeight: Double(natural.height))
        }
        guard pass.encode(field: shown, over: wrapped.flatMap { CVMetalTextureGetTexture($0) }, placement: placement,
                          layer: layer, into: drawable.texture, on: buffer) else { return }
        // The frame's texture stays alive until the GPU has read it.
        let held = HeldTexture(texture: wrapped)
        buffer.addCompletedHandler { @Sendable _ in _ = held }
        buffer.present(drawable)
        buffer.commit()
        lastDrawn = drawn
    }

    /// A warm device or Low Power Mode holds the layer still, as the Field window sheds its motion.
    @MainActor
    private static func deviceAsksForStillness() -> Bool {
        let info = ProcessInfo.processInfo
        return info.isLowPowerModeEnabled || info.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    /// The drawable at the card's size on screen, its longest side capped at `longestSide`.
    @MainActor
    private func settleDrawable(of view: MTKView) {
        let traitScale = view.traitCollection.displayScale
        let scale = traitScale > 0 ? traitScale : view.contentScaleFactor
        var width = view.bounds.width * scale
        var height = view.bounds.height * scale
        let longest = Swift.max(width, height)
        if longest > Self.longestSide {
            width *= Self.longestSide / longest
            height *= Self.longestSide / longest
        }
        let want = CGSize(width: Swift.max(1, width.rounded()), height: Swift.max(1, height.rounded()))
        let have = view.drawableSize
        if Swift.abs(want.width - have.width) > 0.5 || Swift.abs(want.height - have.height) > 0.5 {
            view.drawableSize = want
        }
    }
}

/// Carries a frame's Metal texture to the GPU's completion thread, where nothing touches it but
/// its release, so the unchecked crossing is safe.
private struct HeldTexture: @unchecked Sendable {
    let texture: CVMetalTexture?
}

extension FieldLayer {
    /// The layer as kept on this device — the export's Field Layer and Field Opacity, in percent —
    /// held at Off where it cannot be drawn: what the export takes, and what the video window shows.
    static func stored(blend: FieldLayer.Blend, percent: Int) -> FieldLayer {
        MetalField.isAvailable ? FieldLayer(blend: blend, opacity: Double(percent) / 100) : FieldLayer()
    }
}
