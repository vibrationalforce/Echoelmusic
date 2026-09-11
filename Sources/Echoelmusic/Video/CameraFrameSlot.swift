//
//  CameraFrameSlot.swift
//  Echoelmusic
//
//  K5 (#1262) — the front camera's image, one slot deep, from the Face source's ARSession to
//  the Metal field. The camera has ONE owner (prompt rule 1): `FaceExpressionBioPublisher`'s
//  `ARSession` tracks the face AND is the only thing that ever sees `capturedImage`; there is
//  no second `AVCaptureSession` on the front lens, and never an `AVCaptureMultiCamSession`.
//
//  THE SHAPE, and why it is not a queue. ARKit's delegate delivers ~60 frames/s on its own
//  queue; the renderer draws on the main thread at its own 60 Hz. A queue between them would
//  either grow (a retained `CVPixelBuffer` is a pooled sensor buffer — hold several and ARKit
//  starves) or need a drain policy. One slot with "latest wins" IS the drop strategy the prompt
//  asks for: a frame the renderer never picked up is simply overwritten, and nothing is copied.
//  Same law as `RGBSampleQueue` (rPPG) and `LatestFaceSample`: the producer writes under a lock
//  with ZERO actor hop, the consumer reads under the same lock.
//
//  WHO WANTS IT. Nothing is stored unless a renderer has registered a viewport and said
//  `wanted` — so a Face session with the camera layer at 0 (the default) retains no buffer at
//  all, and a session that is running while the visual window is hidden retains none either.
//  Each renderer registers under its own key because there can be TWO (the phone's floating
//  window and the external stage), with different sizes and orientations, and the mapping
//  from a viewport pixel to an image pixel depends on both. The producer computes ARKit's
//  own `displayTransform` once per registered viewport per frame (a 3×2 affine, cheap) and
//  stores the INVERSE — viewport → image — so a renderer never has to guess rotation or
//  aspect-fill for itself. That arithmetic is the one thing here only a device can confirm
//  (NEEDS-FOUNDER-VERIFY sits at the renderer's camera block, not here).
//
//  PRIVACY. Frames never leave this process: no file, no socket, no `Data` copy. The slot is
//  cleared on interruption, on `stop()`, and whenever nobody wants a frame. The recorder is
//  refused the layer by the renderer (see `MetalBioRenderer`'s camera block) — a take never
//  contains the camera, which is what the app's camera-usage sentence promises.
//

import Foundation
import CoreGraphics
#if canImport(CoreVideo)
import CoreVideo
#endif

/// One registered consumer's geometry: the size the transform is computed for and the
/// interface orientation (`UIInterfaceOrientation.rawValue`; 1 = portrait) — kept as an
/// `Int` so this file needs no UIKit and compiles on the macOS test host.
public struct CameraViewport: Equatable, Sendable {
    public var size: CGSize
    public var orientationRaw: Int
    public init(size: CGSize, orientationRaw: Int) {
        self.size = size
        self.orientationRaw = orientationRaw
    }
}

#if canImport(CoreVideo)
/// What a renderer takes out: the buffer, the monotonically increasing sequence it was stored
/// under (the renderer's "is this new" test and the #1244 skip's extra term), and the
/// viewport → image transform computed for THAT renderer's registered geometry.
public struct CameraFrame {
    public let buffer: CVPixelBuffer
    public let sequence: UInt64
    public let viewportToImage: CGAffineTransform
}
#endif

public final class CameraFrameSlot: @unchecked Sendable {

    public static let shared = CameraFrameSlot()

    private let lock = NSLock()
    #if canImport(CoreVideo)
    private var buffer: CVPixelBuffer?
    #endif
    private var sequence: UInt64 = 0
    /// Registered consumers that currently want frames, by their own key.
    private var viewports: [UUID: CameraViewport] = [:]
    /// The transforms the producer computed for the frame in `buffer`, by consumer key.
    private var transforms: [UUID: CGAffineTransform] = [:]

    public init() {}

    // MARK: - consumer side (the renderer, main thread)

    /// Register / update this consumer's wish. `wanted == false` removes its geometry, and
    /// when the last consumer leaves the buffer is dropped — no wish, no retained frame.
    public func setWanted(_ wanted: Bool, for key: UUID, viewport: CameraViewport) {
        lock.lock(); defer { lock.unlock() }
        if wanted {
            viewports[key] = viewport
        } else {
            viewports[key] = nil
            transforms[key] = nil
            if viewports.isEmpty { dropLocked() }
        }
    }

    /// A consumer going away entirely (renderer deinit). Same as an unwanted wish.
    public func unregister(_ key: UUID) {
        setWanted(false, for: key, viewport: CameraViewport(size: .zero, orientationRaw: 1))
    }

    #if canImport(CoreVideo)
    /// The latest frame for this consumer, or nil while there is none — or while the producer
    /// has not yet computed a transform for this key (the first frame after registering).
    public func latest(for key: UUID) -> CameraFrame? {
        lock.lock(); defer { lock.unlock() }
        guard let buffer, let transform = transforms[key] else { return nil }
        return CameraFrame(buffer: buffer, sequence: sequence, viewportToImage: transform)
    }
    #endif

    // MARK: - producer side (the ARKit delegate, its own queue)

    /// Every geometry somebody wants a frame for. Empty = store nothing.
    public func wantedViewports() -> [UUID: CameraViewport] {
        lock.lock(); defer { lock.unlock() }
        return viewports
    }

    #if canImport(CoreVideo)
    /// Store the newest frame with the transforms computed for the geometries returned by
    /// `wantedViewports()` a moment ago. Latest wins; a consumer that registered in between
    /// simply waits one frame for its transform. Stores nothing if nobody wants a frame any
    /// more — the wish can have been withdrawn between the two calls.
    public func store(_ newBuffer: CVPixelBuffer, transforms newTransforms: [UUID: CGAffineTransform]) {
        lock.lock(); defer { lock.unlock() }
        guard !viewports.isEmpty else { return }
        buffer = newBuffer
        transforms = newTransforms
        sequence &+= 1
    }
    #endif

    /// The session stopped or was interrupted: nothing stale may be drawn. The sequence
    /// still advances so a renderer holding the old sequence sees "something changed".
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        dropLocked()
    }

    /// The current sequence — test and diagnostics access; 0 until the first store.
    public var currentSequence: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return sequence
    }

    private func dropLocked() {
        #if canImport(CoreVideo)
        buffer = nil
        #endif
        transforms = [:]
        sequence &+= 1
    }
}
