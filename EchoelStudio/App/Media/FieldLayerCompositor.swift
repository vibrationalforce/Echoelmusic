import AVFoundation
import CoreVideo
import EchoelCore
import EchoelEngine
import Foundation
import Metal

/// The Field of one video export, ready to draw (wave W15): the GPU pass, the layer the musician
/// chose and the motion of every frame of the film, computed before the export starts
/// (`FieldExport`). A frame is looked up by its time, never stepped from the frame before, so the
/// film does not depend on the order or the number of times AVFoundation asks for a frame — and
/// two exports of one song are the same film.
final class FieldLayerFilm: @unchecked Sendable {
    private let pass: FieldLayerPass
    private let layer: FieldLayer
    private let motion: [FieldMotion.Shown]
    /// One frame on the GPU at a time: the pass keeps one Field texture.
    private let lock = NSLock()

    init(pass: FieldLayerPass, layer: FieldLayer, motion: [FieldMotion.Shown]) {
        self.pass = pass
        self.layer = layer
        self.motion = motion
    }

    /// Draws the film's frame at `seconds` into `output`: `source` placed by `placement` (black
    /// without one), the Field of that frame over it. Returns once the GPU has written the frame —
    /// so the export never runs ahead of it; false when the frame could not be drawn.
    func draw(_ source: CVPixelBuffer?, placement: FieldLayerPlacement?, at seconds: Double,
              into output: CVPixelBuffer) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        // The shader writes sRGB; the encoder is told Rec. 709, as for the live stream.
        CVBufferSetAttachment(output, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        guard let target = pass.texture(output), let targetTexture = CVMetalTextureGetTexture(target),
              let buffer = pass.queue.makeCommandBuffer() else { return false }
        let picture = source.flatMap { pass.texture($0) }
        let pictureTexture = picture.flatMap { CVMetalTextureGetTexture($0) }
        let shown = motion.isEmpty ? FieldMotion.Shown() : motion[FieldExport.index(at: seconds, count: motion.count)]
        guard pass.encode(field: shown, over: pictureTexture, placement: placement, layer: layer, into: targetTexture,
                          on: buffer) else { return false }
        buffer.commit()
        // The textures stay alive until the GPU has used them.
        withExtendedLifetime((target, picture)) {
            buffer.waitUntilCompleted()
        }
        pass.flush()
        return buffer.status == .completed
    }
}

/// One stretch of an export with the Field Layer on (wave W15): a part of a video file placed in the
/// frame — or black — with the film's Field over it. What `AVMutableVideoCompositionInstruction` and
/// its layer instruction carry when the built-in compositor draws, handed to `FieldLayerCompositor`.
final class FieldLayerInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    /// A time range, carried across the export's threads; it is never changed after `init`.
    private struct Span: @unchecked Sendable {
        let value: CMTimeRange
    }

    private let span: Span
    let enablePostProcessing = false
    /// The Field moves on every frame, even over a still picture or black: a frame is never reused
    /// for another time.
    let containsTweening = true
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    /// The picture track this stretch shows; nil for black.
    let track: CMPersistentTrackID?
    let placement: FieldLayerPlacement?
    let film: FieldLayerFilm

    init(timeRange: CMTimeRange, track: CMPersistentTrackID?, placement: FieldLayerPlacement?, film: FieldLayerFilm) {
        span = Span(value: timeRange)
        self.track = track
        self.placement = placement
        self.film = film
        super.init()
    }

    var timeRange: CMTimeRange { span.value }

    var requiredSourceTrackIDs: [NSValue]? {
        guard let track else { return [] }
        return [NSNumber(value: track)]
    }
}

/// The export's compositor while the Field Layer is on (wave W15): places each source frame as the
/// built-in compositor does — the same transform, black where the picture does not reach — and lays
/// the film's Field over it with `FieldLayer`'s formula. Each request is finished before it returns,
/// one frame at a time; there is nothing pending to cancel.
final class FieldLayerCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
         kCVPixelBufferMetalCompatibilityKey as String: true]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
         kCVPixelBufferMetalCompatibilityKey as String: true,
         kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int]()]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? FieldLayerInstruction,
              let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: Self.failure)
            return
        }
        let source = instruction.track.flatMap { request.sourceFrame(byTrackID: $0) }
        guard instruction.film.draw(source, placement: instruction.placement, at: request.compositionTime.seconds,
                                    into: output) else {
            request.finish(with: Self.failure)
            return
        }
        request.finish(withComposedVideoFrame: output)
    }

    func cancelAllPendingVideoCompositionRequests() {}

    /// What a frame that could not be drawn ends the export with; `VideoExport` words it.
    static var failure: NSError {
        NSError(domain: "com.echoelmusic.studio.field-layer", code: 1)
    }
}
