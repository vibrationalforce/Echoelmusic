//
//  FaceExpressionBioPublisher.swift
//  Echoelmusic — Bio capture (A5 BodyVibe camera modulator)
//
//  Publishes front-camera facial-EXPRESSION as bio control channels: ARKit
//  ARFaceTrackingConfiguration → blendShapes → smile/brow/jaw ∈ [0..1] on the
//  EngineBus, at ~10 Hz, source `.faceCam`.
//
//  IMPORTANT — framing (EU AI Act): these are EXPRESSION / MOVEMENT used as a
//  CONTROL signal for the instrument, NEVER an inferred "emotion" or affective
//  state. A smile MOVES a parameter; it is not read as a feeling. The image never
//  leaves the device — only the abstracted [0..1] channels (see BioEgressPolicy).
//
//  Camera exclusivity: ARFaceTrackingConfiguration owns the front TrueDepth camera
//  and cannot run alongside the rPPG AVCaptureSession — so this is ONE more
//  mutually-exclusive `BioSource`, selected deliberately (the single-active-source
//  model already enforces the exclusion). It carries NO pulse; whether the pulse
//  source should COEXIST (e.g. a BLE strap for HR + face for expression) is a
//  product decision deferred to the selection-wiring slice — this file just
//  honestly publishes face channels + neutral bio under `.faceCam`.
//
//  WIRING STATE (#1257, 2026-09-11): constructed ONCE in `EchoelmusicApp`, started and
//  stopped ONLY by the studio's source picker ("Play with your face", `BioSourceOption
//  .face`, offered where `isSupported`). From 2026-07-18 to #1257 nothing instantiated it
//  (`FeatureFlags.cameraExpression` was meant as the lever and never became one — the
//  device capability is the gate). Concurrency follows the rPPG discipline: the ARKit
//  delegate (which may fire off the main actor) never hops to @MainActor per frame —
//  it stores the latest blendShapes under a lock; the 10 Hz @MainActor loop drains.
//  NEEDS-FOUNDER-VERIFY: Bio source → "Play with your face" on a TrueDepth iPhone — the
//  camera dialog names both lenses, Smile/Brow/Jaw appear as FX bio-mod carriers, a
//  smile moves the routed parameter; switch Pulse ↔ Face ten times without a crash.
//  NEEDS-FOUNDER-VERIFY (#1258): Bio panel → "Calibrate", hold still 3 s — afterwards a
//  still face shows Smile/Brow/Jaw at 0.00 (no flicker; the 0.06 deadzone is a guess),
//  a deliberate smile rises smoothly, and the numbers survive a relaunch.
//

import Foundation
import Observation
#if canImport(ARKit)
import ARKit
#endif

/// Thread-safe holder for the latest blendShape bag. Mirrors the rPPG
/// `RGBSampleQueue` rule: the high-rate producer writes here with ZERO actor hop;
/// the low-rate main-actor loop reads it.
private final class LatestFaceSample: @unchecked Sendable {
    private let lock = NSLock()
    private var coefficients: [String: Float] = [:]
    private var hasFace = false
    private var failure: String?

    func store(_ c: [String: Float]) {
        lock.lock(); coefficients = c; hasFace = true; lock.unlock()
    }
    /// The latest bag, or `nil` while no face has been seen yet.
    func read() -> [String: Float]? {
        lock.lock(); defer { lock.unlock() }
        return hasFace ? coefficients : nil
    }
    func clear() {
        lock.lock(); coefficients = [:]; hasFace = false; lock.unlock()
    }
    /// #1257 — a session failure (camera denied or revoked, hardware lost) recorded by the
    /// nonisolated delegate; the main-actor drain takes it ONCE and stops the publisher.
    func fail(_ message: String) {
        lock.lock(); failure = message; coefficients = [:]; hasFace = false; lock.unlock()
    }
    func takeFailure() -> String? {
        lock.lock(); defer { lock.unlock() }
        let f = failure; failure = nil; return f
    }
}

@MainActor
@Observable
public final class FaceExpressionBioPublisher {

    /// True while the ARKit session is running and the publish loop is live.
    public private(set) var isPublishing = false

    /// #1257 — why the last session ended on its own: the camera permission denied or
    /// revoked in Settings, or the tracking hardware failing. `nil` while running or after
    /// a clean `stop()`. Read by the bio panel's source row; never a crash.
    public private(set) var lastError: String?

    /// #1258 — the three channels as the instrument sees them (calibrated, gated, smoothed),
    /// written at the 10 Hz drain for the bio panel's numbers row (`FaceChannelsRow`, a
    /// leaf — the freeze law: a 10 Hz `@Observable` read belongs in its own `View`).
    public private(set) var smile: Float = 0
    public private(set) var browRaise: Float = 0
    public private(set) var jawOpen: Float = 0
    /// True while a neutral hold is being collected (`calibrate(seconds:)`).
    public private(set) var isCalibrating = false
    /// True when a non-identity calibration is applied (persisted across launches).
    public private(set) var hasCalibration = false

    /// Whether this device can track the face at all (front TrueDepth / ARKit).
    /// `false` on any platform without ARKit or without face-tracking hardware —
    /// callers gate the "Face" bio source on this. `nonisolated`: it is a device fact
    /// read by `BioSourceOption.offered` off the actor (#1255b lesson — Xcode isolates a
    /// `static` member of a `@MainActor` class, SwiftPM does not).
    nonisolated public static var isSupported: Bool {
        #if canImport(ARKit)
        return ARFaceTrackingConfiguration.isSupported
        #else
        return false
        #endif
    }

    @ObservationIgnored private var mapping = FaceExpressionBioPublisher.freshMapping()
    @ObservationIgnored private let latest = LatestFaceSample()
    @ObservationIgnored private var lastPublish: CFAbsoluteTime = 0
    @ObservationIgnored private var calibration = FaceExpressionBioPublisher.loadCalibration()
    @ObservationIgnored private var neutralSamples: (smile: [Float], brow: [Float], jaw: [Float]) = ([], [], [])
    @ObservationIgnored private var calibrationEndsAt: CFAbsoluteTime = 0

    /// The production mapping: deadzone ON. `stop()` resets to this, never to a bare `init`.
    private static func freshMapping() -> FaceExpressionMapping {
        FaceExpressionMapping(deadzone: FaceExpressionMapping.defaultDeadzone)
    }

    private static func loadCalibration() -> FaceCalibration {
        guard let data = UserDefaults.standard.data(forKey: FaceCalibration.defaultsKey),
              let c = try? JSONDecoder().decode(FaceCalibration.self, from: data) else { return .identity }
        return c
    }

    #if canImport(ARKit)
    @ObservationIgnored private let arSession = ARSession()
    @ObservationIgnored private var delegateProxy: FaceDelegateProxy?
    @ObservationIgnored private var publishTask: Task<Void, Never>?
    #endif

    public init() {
        hasCalibration = !calibration.isIdentity
    }

    /// #1258 — collect a NEUTRAL hold for `seconds` (default 3) and derive per-channel
    /// baselines from it. Only while publishing (there is nothing to sample otherwise). The
    /// result is persisted under `FaceCalibration.defaultsKey` and applied from the next
    /// tick on; the numbers row shows the hold while it runs.
    public func calibrate(seconds: Double = 3) {
        guard isPublishing, !isCalibrating else { return }
        neutralSamples = ([], [], [])
        calibrationEndsAt = CFAbsoluteTimeGetCurrent() + Swift.max(0.5, seconds)
        isCalibrating = true
    }

    /// Back to identity (raw = calibrated), and the persisted one is removed.
    public func clearCalibration() {
        calibration = .identity
        hasCalibration = false
        isCalibrating = false
        UserDefaults.standard.removeObject(forKey: FaceCalibration.defaultsKey)
    }

    /// Start front-camera expression tracking and publish `.faceCam` frames to `bus`.
    /// No-op when unsupported or already running. `arSession.run` raises the camera
    /// dialog using the app-wide `NSCameraUsageDescription` — which since #1257 names
    /// BOTH uses (rear-lens pulse, front-camera facial movement as a control signal),
    /// because iOS has one string per app and the old one described only the pulse.
    /// A denial does not crash: ARKit reports it through the delegate, the drain records
    /// `lastError` and stops.
    public func start(publishing bus: EngineBus) {
        guard !isPublishing, Self.isSupported else { return }
        lastError = nil
        #if canImport(ARKit)
        let proxy = FaceDelegateProxy(latest: latest)
        delegateProxy = proxy
        arSession.delegate = proxy
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        isPublishing = true
        startPublishLoop(bus: bus)
        #endif
    }

    /// Stop tracking and publishing. Idempotent. Resets the smoothed state so a
    /// restart begins from neutral (a lost face reads as "no expression").
    public func stop() {
        #if canImport(ARKit)
        publishTask?.cancel()
        publishTask = nil
        arSession.pause()
        arSession.delegate = nil
        delegateProxy = nil
        #endif
        latest.clear()
        mapping = Self.freshMapping()
        isCalibrating = false
        smile = 0; browRaise = 0; jawOpen = 0
        isPublishing = false
    }

    #if canImport(ARKit)
    private func startPublishLoop(bus: EngineBus) {
        lastPublish = CFAbsoluteTimeGetCurrent()
        publishTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)   // 10 Hz
                guard let self else { return }
                self.tick(bus: bus)
            }
        }
    }

    /// One 10 Hz drain: latest bag → channels → rate-based EMA → `.faceCam` frame.
    /// Skips while no face is present (never publishes a stale/spiked value).
    private func tick(bus: EngineBus) {
        if let failure = latest.takeFailure() {
            stop()
            lastError = failure
            return
        }
        guard let bag = latest.read() else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let dt = Swift.max(0, now - lastPublish)
        lastPublish = now
        let raw = FaceExpressionMapping.rawChannels(from: bag)
        if isCalibrating {
            neutralSamples.smile.append(raw.smile)
            neutralSamples.brow.append(raw.browRaise)
            neutralSamples.jaw.append(raw.jawOpen)
            if now >= calibrationEndsAt {
                calibration = FaceCalibration.fromNeutral(smile: neutralSamples.smile,
                                                          browRaise: neutralSamples.brow,
                                                          jawOpen: neutralSamples.jaw)
                if let data = try? JSONEncoder().encode(calibration) {
                    UserDefaults.standard.set(data, forKey: FaceCalibration.defaultsKey)
                }
                hasCalibration = !calibration.isIdentity
                isCalibrating = false
                neutralSamples = ([], [], [])
            }
        }
        let scaled = calibration.apply(smile: raw.smile, browRaise: raw.browRaise, jawOpen: raw.jawOpen)
        mapping = mapping.updated(rawSmile: scaled.smile,
                                  rawBrowRaise: scaled.browRaise,
                                  rawJawOpen: scaled.jawOpen,
                                  dt: dt)
        smile = mapping.smile
        browRaise = mapping.browRaise
        jawOpen = mapping.jawOpen
        bus.publish(bio: BioSampleFrame(
            timestamp: now,
            heartRateBPM: 0,          // faceCam carries NO pulse (coexistence deferred)
            hrvNormalized: 0,
            breathRate: 0,
            breathPhase: 0,
            coherence: 0,
            motionEnergy: 0,
            source: .faceCam,
            faceSmile: mapping.smile,
            faceBrowRaise: mapping.browRaise,
            faceJawOpen: mapping.jawOpen
        ))
    }
    #endif
}

#if canImport(ARKit)
/// Nonisolated ARKit delegate: extracts blendShape coefficients into the lock-
/// protected holder. Never touches the @MainActor publisher directly, so ARKit's
/// delegate queue is irrelevant — no per-frame actor hop (the rPPG lesson).
private final class FaceDelegateProxy: NSObject, ARSessionDelegate {
    private let latest: LatestFaceSample
    init(latest: LatestFaceSample) { self.latest = latest }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let face = anchor as? ARFaceAnchor else { continue }
            var bag: [String: Float] = [:]
            bag.reserveCapacity(face.blendShapes.count)
            for (key, value) in face.blendShapes {
                bag[key.rawValue] = value.floatValue
            }
            latest.store(bag)
        }
    }

    /// #1257 — the face left the frame's certainty (ARKit stops updating an anchor it
    /// cannot see): drop the bag so the drain publishes nothing stale. The consumers hold
    /// their last value by their own law; the ~300 ms fade to neutral is K3's slice.
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        if anchors.contains(where: { $0 is ARFaceAnchor }) { latest.clear() }
    }

    /// Camera denied/revoked, hardware unavailable, or the session otherwise unable to
    /// run: recorded for the main-actor drain, which stops the publisher and exposes
    /// `lastError`. Never a crash, never a silent "face never arrives".
    func session(_ session: ARSession, didFailWithError error: Error) {
        latest.fail(error.localizedDescription)
    }

    /// A phone call or a backgrounding: the frames stop, and so must the stale bag.
    func sessionWasInterrupted(_ session: ARSession) { latest.clear() }
}
#endif
