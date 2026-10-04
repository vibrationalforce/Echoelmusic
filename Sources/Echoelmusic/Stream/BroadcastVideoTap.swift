//
//  BroadcastVideoTap.swift
//  Echoelmusic — Stream
//
//  THE PICTURE'S WAY OUT. `MetalBioRenderer` (the one Metal view) asks this tap once per drawn
//  frame whether the stream wants a picture; when it does, the renderer draws the SAME shader
//  a second time into a pixel buffer at the stream's size, and the command buffer's completion
//  handler drops that buffer here. The broadcast pump drains it on its own queue.
//
//  ⭐ THREE BOUNDS, each one a failure mode it closes:
//  · RATE — a picture is due at most every `frameInterval` (30 fps by default), whatever the
//    display runs at; the second draw is skipped on the other display frames.
//  · GPU WORK IN FLIGHT — at most `maxInFlight` stream pictures may be encoded and not yet
//    finished. A slow GPU sheds stream pictures, never the on-screen picture.
//  · HANDOFF — the queue holds at most `capacity` finished pictures; the oldest goes first.
//    A stalled encoder can never grow memory.
//  Every shed picture is counted (`droppedFrames`), never silent.
//
//  ⚠️ NO CAMERA. The stream's picture is the Echoelmusic visual. The rear camera stays with
//  the rPPG pulse path (`Video/CameraCapture`), and streaming takes nothing from it.
//
//  ⚠️ NO `framebufferOnly` FLIP. The on-screen drawable stays write-only — the law in
//  `MetalBioRenderer` (`lastFramebufferOnly` tombstone) is untouched, because the stream
//  renders its OWN target instead of reading the drawable back.
//

#if canImport(Metal) && canImport(CoreVideo)
import CoreVideo
import Foundation
import Metal

/// A picture rendered for the stream, and the host time it was rendered at.
/// `@unchecked Sendable`: the pixel buffer is written by the GPU before the completion handler
/// hands the frame over and is only READ afterwards.
struct BroadcastVideoFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let hostTicks: UInt64
    /// Keeps the Metal view of the buffer alive until the GPU has finished with it.
    let metalTexture: CVMetalTexture?
}

/// Lock-protected channel between the renderer (main thread + Metal completion threads) and
/// the broadcast pump (its own queue). No actor hop per frame — the 10.76.48 law: a
/// high-frequency producer pushes into a locked queue, a low-rate consumer drains it.
final class BroadcastVideoTap: @unchecked Sendable {

    static let shared = BroadcastVideoTap()

    static let capacity = 3
    static let maxInFlight = 2

    private let lock = NSLock()
    private var spec: BroadcastVideoSpec?
    private var intervalTicks: UInt64 = 0
    private var lastDueTicks: UInt64 = 0
    private var inFlight = 0
    private var frames: [BroadcastVideoFrame] = []
    private var dropped = 0
    private var lastDeliveredTicks: UInt64 = 0

    init() { frames.reserveCapacity(Self.capacity + 1) }

    /// Start wanting pictures. Clears anything left from a previous stream.
    func enable(_ spec: BroadcastVideoSpec, timebase: BroadcastTimebase) {
        guard spec.isValid else { return }
        lock.lock(); defer { lock.unlock() }
        self.spec = spec
        intervalTicks = timebase.ticks(seconds: 1.0 / spec.framesPerSecond)
        lastDueTicks = 0
        frames.removeAll(keepingCapacity: true)
        dropped = 0
        lastDeliveredTicks = 0
    }

    /// Stop wanting pictures. Pictures already in flight are discarded when they land.
    func disable() {
        lock.lock(); defer { lock.unlock() }
        spec = nil
        frames.removeAll(keepingCapacity: true)
    }

    /// The renderer asks once per drawn frame. Non-nil = draw one stream picture at this size
    /// now, then call `deliver` (or `abandon` when the draw could not be encoded). Reserves an
    /// in-flight slot, so every non-nil answer MUST be answered by exactly one of the two.
    func dueFrame(nowTicks: UInt64) -> BroadcastVideoSpec? {
        lock.lock(); defer { lock.unlock() }
        guard let spec else { return nil }
        // A 10 % early allowance so a 60 Hz display does not alias 30 fps down to 20.
        let early = intervalTicks / 10
        if lastDueTicks != 0, nowTicks &+ early < lastDueTicks &+ intervalTicks { return nil }
        guard inFlight < Self.maxInFlight else { dropped += 1; return nil }
        inFlight += 1
        lastDueTicks = nowTicks
        return spec
    }

    /// A stream picture finished on the GPU.
    func deliver(_ frame: BroadcastVideoFrame) {
        lock.lock(); defer { lock.unlock() }
        inFlight = Swift.max(0, inFlight - 1)
        guard spec != nil else { return }
        if frames.count >= Self.capacity {
            frames.removeFirst()
            dropped += 1
        }
        frames.append(frame)
        lastDeliveredTicks = frame.hostTicks
    }

    /// A due picture could not be encoded (no pipeline, no pixel buffer). Frees its slot.
    func abandon() {
        lock.lock(); defer { lock.unlock() }
        inFlight = Swift.max(0, inFlight - 1)
    }

    /// Everything finished since the last drain, oldest first.
    func drain() -> [BroadcastVideoFrame] {
        lock.lock(); defer { lock.unlock() }
        let out = frames
        frames.removeAll(keepingCapacity: true)
        return out
    }

    var droppedFrames: Int { lock.lock(); defer { lock.unlock() }; return dropped }

    /// Host time of the newest delivered picture (0 = none since `enable`).
    var lastDelivered: UInt64 { lock.lock(); defer { lock.unlock() }; return lastDeliveredTicks }
}

/// Pixel buffers the GPU can render into — owned by the renderer, created on first use.
/// BGRA, IOSurface-backed, Metal-compatible: the format VideoToolbox takes without conversion.
final class BroadcastFrameTarget {

    private let device: MTLDevice
    private var pool: CVPixelBufferPool?
    private var cache: CVMetalTextureCache?
    private var poolWidth = 0
    private var poolHeight = 0

    init?(device: MTLDevice) {
        self.device = device
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess,
              let cache else { return nil }
        self.cache = cache
    }

    /// A fresh pixel buffer and its Metal view, or nil (pool exhausted, allocation failed).
    func make(width: Int, height: Int, pixelFormat: MTLPixelFormat)
        -> (pixelBuffer: CVPixelBuffer, texture: MTLTexture, cvTexture: CVMetalTexture)? {
        guard let cache else { return nil }
        if pool == nil || width != poolWidth || height != poolHeight {
            let attributes: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary
            ]
            // A small minimum keeps the pool from allocating per frame; the tap's in-flight and
            // queue bounds keep the number of buffers alive at once well under it.
            let poolAttributes: [CFString: Any] = [kCVPixelBufferPoolMinimumBufferCountKey: 4]
            var newPool: CVPixelBufferPool?
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as CFDictionary,
                                          attributes as CFDictionary, &newPool) == kCVReturnSuccess,
                  let newPool else { return nil }
            pool = newPool
            poolWidth = width
            poolHeight = height
            CVMetalTextureCacheFlush(cache, 0)
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }
        var cvTexture: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, nil,
                                                        pixelFormat, width, height, 0,
                                                        &cvTexture) == kCVReturnSuccess,
              let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) else { return nil }
        return (buffer, texture, cvTexture)
    }

    /// A black picture for when no visual is on screen — the stream keeps a picture track
    /// instead of starving the encoder. Built once per size, without Metal.
    static func blackFrame(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary
        ]
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                  attributes as CFDictionary, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        // BGRA: 0,0,0 colour, 255 alpha.
        for row in 0..<height {
            let line = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                line[x * 4] = 0; line[x * 4 + 1] = 0; line[x * 4 + 2] = 0; line[x * 4 + 3] = 255
            }
        }
        return buffer
    }
}
#endif
