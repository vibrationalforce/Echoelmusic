import CoreMedia
import CoreVideo
import EchoelCore
import Foundation
import Metal

/// The live stream's picture (wave W14): the Field, drawn offscreen at 30 frames a second by its
/// own `MetalFieldRenderer` — the same snapshot, clocks, flash guards and shader as the window on
/// screen — once per shape the stream carries (9:16, 16:9, 1:1, 4:5), each at its encoded size.
/// A frame leaves as a `CMSampleBuffer` stamped with the host clock, the clock the master mix's
/// timestamps use too, so the encoder keeps picture and sound together.
///
/// Runs on the main actor (the snapshot lives there) only while a stream runs; the GPU writes the
/// frame and Metal's completion thread hands it on through `frames` — no main-actor hop per frame.
/// The pools hold a few buffers each; when the encoder falls behind, a frame is skipped instead of
/// a pool growing.
@MainActor
final class FieldStreamSource {
    struct Frame: @unchecked Sendable {
        let sampleBuffer: CMSampleBuffer
        let format: StreamFormat
    }

    /// The drawn frames, oldest first; the newest few wait while the publisher is busy.
    let frames: AsyncStream<Frame>
    private let continuation: AsyncStream<Frame>.Continuation
    private(set) var skippedFrames = 0

    private struct Lane {
        let renderer: MetalFieldRenderer
        let pool: CVPixelBufferPool
    }

    private let device: MTLDevice
    private let textureCache: CVMetalTextureCache
    private weak var store: ProjectStore?
    private weak var engine: AudioEngine?
    private var lanes: [StreamFormat: Lane] = [:]
    private var ticker: Task<Void, Never>?

    /// Nil on a device without Metal: there the stream has no picture to send.
    init?(store: ProjectStore, engine: AudioEngine) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess, let cache else { return nil }
        self.device = device
        textureCache = cache
        self.store = store
        self.engine = engine
        let stream = AsyncStream.makeStream(of: Frame.self, bufferingPolicy: .bufferingNewest(4))
        frames = stream.stream
        continuation = stream.continuation
    }

    /// Starts drawing `formats`, or changes which ones are drawn.
    func start(formats: [StreamFormat]) {
        for format in Array(lanes.keys) where !formats.contains(format) { lanes[format] = nil }
        for format in formats where lanes[format] == nil {
            guard let pool = Self.makePool(format) else {
                DiagnosticLog.app.note("stream: no pixel pool", [("w", Double(format.pixelWidth))])
                continue
            }
            let renderer = MetalFieldRenderer()
            renderer.configure(device: device)
            renderer.store = store
            renderer.engine = engine
            lanes[format] = Lane(renderer: renderer, pool: pool)
        }
        guard ticker == nil, !lanes.isEmpty else { return }
        ticker = Task { [weak self] in
            let clock = ContinuousClock()
            let interval = Duration.nanoseconds(1_000_000_000 / Int64(StreamQuality.framesPerSecond))
            var next = clock.now
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                next += interval
                // Behind by more than a frame (a stall): start the cadence again from now.
                if next < clock.now { next = clock.now }
                try? await clock.sleep(until: next)
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        lanes = [:]
        CVMetalTextureCacheFlush(textureCache, 0)
    }

    private func tick() {
        for (format, lane) in lanes {
            var made: CVPixelBuffer?
            let limit = [kCVPixelBufferPoolAllocationThresholdKey: Self.poolLimit] as CFDictionary
            guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, lane.pool, limit, &made) == kCVReturnSuccess,
                  let pixel = made else {
                skippedFrames += 1
                continue
            }
            Self.tagColour(pixel)
            var wrapped: CVMetalTexture?
            guard CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixel, nil, .bgra8Unorm_srgb,
                                                            format.pixelWidth, format.pixelHeight, 0,
                                                            &wrapped) == kCVReturnSuccess,
                  let wrapped, let texture = CVMetalTextureGetTexture(wrapped) else {
                skippedFrames += 1
                continue
            }
            let time = CMClockGetTime(CMClockGetHostTimeClock())
            // The pixel buffer and its texture stay alive until the GPU has written them.
            let handoff = Handoff(pixel: pixel, texture: wrapped)
            let continuation = continuation
            let encoded = lane.renderer.render(into: texture) {
                guard let sample = Self.sample(handoff.pixel, at: time) else { return }
                _ = handoff.texture
                continuation.yield(Frame(sampleBuffer: sample, format: format))
            }
            if !encoded { skippedFrames += 1 }
        }
    }

    /// A few buffers per shape: one being drawn, one being encoded, one waiting.
    private static let poolLimit = 6

    private static func makePool(_ format: StreamFormat) -> CVPixelBufferPool? {
        let pixels: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: format.pixelWidth,
            kCVPixelBufferHeightKey: format.pixelHeight,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any](),
        ]
        let poolAttributes: [CFString: Any] = [kCVPixelBufferPoolMinimumBufferCountKey: 3]
        var pool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(nil, poolAttributes as CFDictionary, pixels as CFDictionary, &pool) == kCVReturnSuccess
        else { return nil }
        return pool
    }

    /// The shader writes sRGB; the encoder is told the buffer is Rec. 709, which every player expects.
    private static func tagColour(_ pixel: CVPixelBuffer) {
        CVBufferSetAttachment(pixel, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixel, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixel, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
    }

    private nonisolated static func sample(_ pixel: CVPixelBuffer, at time: CMTime) -> CMSampleBuffer? {
        var description: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixel,
                                                           formatDescriptionOut: &description) == noErr,
              let description else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(StreamQuality.framesPerSecond)),
                                        presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixel, formatDescription: description,
                                                       sampleTiming: &timing, sampleBufferOut: &sample) == noErr
        else { return nil }
        return sample
    }
}

/// Carries a pixel buffer and its Metal texture to the GPU's completion thread. Nothing else
/// touches either until the frame is handed on, so the unchecked crossing is safe.
private struct Handoff: @unchecked Sendable {
    let pixel: CVPixelBuffer
    let texture: CVMetalTexture
}
