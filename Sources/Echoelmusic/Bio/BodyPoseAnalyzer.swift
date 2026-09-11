//
//  BodyPoseAnalyzer.swift
//  Echoelmusic — Bio capture
//
//  K6a (#1264) — hands and shoulders from the SAME front-camera frames the face session
//  already delivers (`ARFrame.capturedImage`), through Vision, on its own serial queue,
//  with a DROP policy: a frame that arrives while one is being analysed is dropped, not
//  queued (prompt rule 1c — "eigene Queue, Drop-Strategie"). Never a second camera session.
//  The ARFrame itself is not retained; the pixel buffer is, ONE at a time, for the length of
//  the pass. Output is a bag of control values under `BodyPoseMath`'s keys — MOVEMENT as a
//  control signal, never an inferred state (the face file's EU-AI-Act framing, unchanged).
//
//  RATE + THERMAL: every `frameStride`-th delivered frame (~15 passes/s at any capture rate —
//  K7b derives the stride from the rate, `FaceTrackingRate.stride(forCaptureHz:)`), and nothing
//  at all once `ProcessInfo.thermalState` reaches `.serious` (the prompt asks for automatic
//  degradation from exactly there). Both are cheap reads on the delegate's queue.
//
//  ORIENTATION (K6c, #1266): the handler is told the Vision orientation that matches the
//  INTERFACE orientation (`BodyPoseMath.visionOrientationRaw`, a pure table), pushed by the
//  publisher's drain on change — so a landscape performance reads heights along the right
//  axis instead of the portrait default `.right`.
//  NEEDS-FOUNDER-VERIFY (#1264): Face source on, Bio panel — raise the LEFT hand: does
//  "Hand L" rise (chirality, not screen side)? Spread the arms: does "Apart" reach ~1 without
//  saturating early? Tilt the shoulders: does "Tilt" leave 0.5 in the expected direction?
//  Leave the frame: do the body numbers ease to rest within ~1 s?
//
//  ⚠️ AUDIO THREAD: none of this touches it. The sink stores a small dictionary under a lock;
//  the 10 Hz main-actor drain reads it (`FaceExpressionBioPublisher.tick`).
//

#if canImport(Vision) && canImport(CoreVideo)
import Foundation
import Vision
import CoreVideo
import ImageIO   // `CGImagePropertyOrientation` is ImageIO's; Vision re-exports it, this does not rely on that (#1268)

/// `CVPixelBuffer` is not `Sendable`; one buffer crosses to the analysis queue at a time and
/// nothing else holds it — the wrapper states that contract where the compiler asks for it.
private struct AnalysisFrame: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

final class BodyPoseAnalyzer: @unchecked Sendable {

    /// Analyse every N-th delivered frame (~`FaceTrackingRate.analysisHz` passes/s); set from
    /// the running capture rate by `setCaptureHz(_:)`, 60 Hz assumed until told.
    private var frameStride = FaceTrackingRate.stride(forCaptureHz: 60)
    /// Vision's per-joint confidence below which a joint is "not seen".
    static let minimumJointConfidence: Float = 0.3

    private let queue = DispatchQueue(label: "com.echoelmusic.bodypose", qos: .userInitiated)
    private let lock = NSLock()
    private var busy = false
    private var frameCounter = 0
    /// `CGImagePropertyOrientation` raw value for the next pass; portrait by default.
    private var orientationRaw: UInt32 = BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 1)
    private let sink: @Sendable ([String: Float]) -> Void

    init(sink: @escaping @Sendable ([String: Float]) -> Void) {
        self.sink = sink
    }

    /// K7b — the capture rate changed (main actor, on change only): keep ~15 passes/s.
    func setCaptureHz(_ hz: Int) {
        let stride = FaceTrackingRate.stride(forCaptureHz: hz)
        lock.lock(); frameStride = stride; lock.unlock()
    }

    /// K6c — the interface orientation changed (main actor, on change only): the next pass
    /// reads the buffer accordingly. A `UIInterfaceOrientation` raw value goes in.
    func setInterfaceOrientation(raw: Int) {
        let vision = BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: raw)
        lock.lock(); orientationRaw = vision; lock.unlock()
    }

    /// Called on the ARKit delegate queue for every frame. Returns at once; the pass runs on
    /// `queue`. Drop policy, stride and thermal gate happen HERE, before anything is retained.
    func analyze(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        frameCounter &+= 1
        let take = !busy && frameCounter % frameStride == 0
        if take { busy = true }
        let orientation = orientationRaw
        lock.unlock()
        guard take else { return }
        // Thermal: `.serious` and `.critical` skip the pass entirely — the body channels ease
        // to rest through the bank (their keys stop arriving; the drain ages the bag out).
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            lock.lock(); busy = false; lock.unlock()
            return
        }
        let frame = AnalysisFrame(buffer: pixelBuffer)
        queue.async { [self] in
            let bag = BodyPoseMath.bag(from: Self.sample(from: frame.buffer, orientationRaw: orientation))
            lock.lock(); busy = false; lock.unlock()
            sink(bag)
        }
    }

    /// One Vision pass: up to two hands (wrists, with chirality) and the body's shoulders.
    private static func sample(from pixelBuffer: CVPixelBuffer, orientationRaw: UInt32) -> BodyPoseSample {
        let hands = VNDetectHumanHandPoseRequest()
        hands.maximumHandCount = 2
        let body = VNDetectHumanBodyPoseRequest()
        let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        var sample = BodyPoseSample()
        do {
            try handler.perform([hands, body])
        } catch {
            return sample
        }
        for hand in hands.results ?? [] {
            guard let wrist = try? hand.recognizedPoint(.wrist),
                  wrist.confidence >= minimumJointConfidence else { continue }
            let p = SIMD2<Float>(Float(wrist.location.x), Float(wrist.location.y))
            switch hand.chirality {
            case .left:
                sample.leftWrist = p
            case .right:
                sample.rightWrist = p
            default:
                // Unknown chirality: fill the empty slot, so one visible hand still counts.
                if sample.leftWrist == nil { sample.leftWrist = p } else if sample.rightWrist == nil { sample.rightWrist = p }
            }
        }
        if let pose = body.results?.first {
            let left = try? pose.recognizedPoint(.leftShoulder)
            let right = try? pose.recognizedPoint(.rightShoulder)
            let neck = try? pose.recognizedPoint(.neck)
            if let l = left, l.confidence >= minimumJointConfidence {
                sample.leftShoulder = SIMD2<Float>(Float(l.location.x), Float(l.location.y))
            }
            if let r = right, r.confidence >= minimumJointConfidence {
                sample.rightShoulder = SIMD2<Float>(Float(r.location.x), Float(r.location.y))
            }
            // Presence = the best of neck and the two shoulders: the torso, not a stray hand.
            sample.bodyConfidence = Swift.max(neck?.confidence ?? 0,
                                              Swift.max(left?.confidence ?? 0, right?.confidence ?? 0))
        }
        return sample
    }
}
#endif
