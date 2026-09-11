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
//  NEEDS-FOUNDER-VERIFY (#1259): with a Smile → FX route sounding, turn the face away — the
//  parameter eases back over ~0.3 s (no click, no 6-s freeze); with Health authorised on
//  the same phone, hold a smile for 20 s — no periodic dip every 4–5 s.
//  K5 (#1262): the SAME session's `capturedImage` feeds `CameraFrameSlot` for the visual's
//  camera layer — one owner of the front camera, no second capture session; nothing is
//  stored unless a renderer wants a frame, and a recorded take never contains one.
//
//  K6a (#1264) — the BODY rides the same session: `BodyPoseAnalyzer` (Vision, own serial
//  queue, drop policy, thermal gate) reads `capturedImage` in the frame delegate and stores
//  a bag of hand/shoulder values in a second slot; the 10 Hz drain MERGES it with the face
//  bag, so the five body channels get the bank's three stages (deadzone, EMA, release) from
//  the same code. Still ONE owner of the front camera. The body is never calibrated
//  (absolute frame — `FaceGestureChannel.isBody`), and a body bag older than
//  `bodyStaleSeconds` reads as "no body" so a thermal stop eases the channels to rest.
//  NEEDS-FOUNDER-VERIFY (#1264): the four device asks are at `BodyPoseAnalyzer`'s header.
//

import Foundation
import Observation
#if canImport(ARKit)
import ARKit
import UIKit   // `UIInterfaceOrientation` for `ARFrame.displayTransform` (K5)
#endif

/// Thread-safe holder for the latest blendShape bag. Mirrors the rPPG
/// `RGBSampleQueue` rule: the high-rate producer writes here with ZERO actor hop;
/// the low-rate main-actor loop reads it.
private final class LatestFaceSample: @unchecked Sendable {
    private let lock = NSLock()
    private var coefficients: [String: Float] = [:]
    private var hasFace = false
    private var failure: String?
    private var storedAt: CFAbsoluteTime = 0

    func store(_ c: [String: Float]) {
        lock.lock(); coefficients = c; hasFace = true; storedAt = CFAbsoluteTimeGetCurrent(); lock.unlock()
    }
    /// The latest bag, or `nil` while no face has been seen yet.
    func read() -> [String: Float]? {
        lock.lock(); defer { lock.unlock() }
        return hasFace ? coefficients : nil
    }
    /// K6a — the latest bag only if it was stored within `maxAge` seconds. The BODY slot is
    /// filled by Vision passes that STOP under the thermal gate or when nothing is analysed;
    /// a bag older than the window reads as "no body", so the body channels ease to rest
    /// instead of freezing on the last pose (prompt: loss is a state, never a freeze).
    func read(maxAge: Double) -> [String: Float]? {
        lock.lock(); defer { lock.unlock() }
        guard hasFace, CFAbsoluteTimeGetCurrent() - storedAt <= maxAge else { return nil }
        return coefficients
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
    /// #1259 — true while ARKit is delivering a face; false once it is gone (the channels
    /// then fade to 0 over ~0.3 s and the publisher falls silent). For the numbers row.
    public private(set) var isFaceTracked = false
    /// K6a (#1264) — the five body channels for the numbers row (same leaf, same 10 Hz
    /// drain): wrists' heights, wrist separation, shoulder tilt (0.5 = level), presence.
    public private(set) var handHeightL: Float = 0
    public private(set) var handHeightR: Float = 0
    public private(set) var handDistance: Float = 0
    public private(set) var shoulderTilt: Float = 0.5
    public private(set) var bodyPresence: Float = 0
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

    /// K7 (#1265) — whether this device can segment the person out of the front-camera frame
    /// (A12 and later). The cut-out toggle is DISABLED, never simulated, where this is false
    /// (prompt: "Option ausgrauen, nicht simulieren").
    nonisolated public static var supportsSegmentation: Bool {
        #if canImport(ARKit)
        return ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation)
        #else
        return false
        #endif
    }

    /// K7 — the thermal ladder, VISIBLE: non-nil while `ProcessInfo.thermalState` is
    /// `.serious` or worse and the session has shed body tracking and the person matte
    /// (prompt: "der Nutzer sieht, dass es passiert"). Written at the drain on CHANGE only.
    public private(set) var thermalRelief: String?

    @ObservationIgnored private var mapping = FaceExpressionBioPublisher.freshMapping()
    /// #1260 — the nine further channels (brow down, blink, squint, pucker, cheeks, head
    /// turn/nod/tilt/distance), same three stages, one bank.
    @ObservationIgnored private var gestures = FaceGestureBank(deadzone: FaceExpressionMapping.defaultDeadzone)
    @ObservationIgnored private var gestureNeutral: [[Float]] = []
    @ObservationIgnored private let latest = LatestFaceSample()
    /// K6a — the body bag from `BodyPoseAnalyzer` (Vision on the SAME frames), one slot,
    /// read with an age window so a stalled analysis does not freeze a pose.
    @ObservationIgnored private let latestBody = LatestFaceSample()
    #if canImport(ARKit)
    @ObservationIgnored private var bodyAnalyzer: BodyPoseAnalyzer?
    /// K7 — the running configuration, kept so the person-segmentation semantics can be
    /// toggled with a plain `run(config)` (no reset options → tracking continues).
    @ObservationIgnored private var arConfig: ARFaceTrackingConfiguration?
    @ObservationIgnored private var segmentationOn = false
    /// K6c — the interface orientation last pushed to the body analyzer (-1 = never).
    @ObservationIgnored private var pushedOrientationRaw = -1
    #endif
    /// True once a face OR a body has been seen since the last loss — the loss fade starts
    /// at the first drain that finds neither (before K6a the face alone decided).
    @ObservationIgnored private var hadInput = false
    @ObservationIgnored private var lastPublish: CFAbsoluteTime = 0
    @ObservationIgnored private var calibration = FaceExpressionBioPublisher.loadCalibration()
    @ObservationIgnored private var neutralSamples: (smile: [Float], brow: [Float], jaw: [Float]) = ([], [], [])
    @ObservationIgnored private var calibrationEndsAt: CFAbsoluteTime = 0
    /// #1259 — set at the first drain without a face; the fade runs from it until settled
    /// or `lossFadeCapSeconds`, whichever first. `nil` = no loss in progress.
    @ObservationIgnored private var faceLostAt: CFAbsoluteTime?
    /// Hard cap on the loss fade so a never-settling channel cannot keep a dead source
    /// publishing: 3 × the loss time constant is >95 % gone by the 0.1 s constant.
    nonisolated static let lossFadeCapSeconds: Double = 0.6   // read by a guard off-actor (#1255b)
    /// K6a — a body bag older than this is "no body" (see `LatestFaceSample.read(maxAge:)`).
    /// Vision runs at ~15 passes/s; one second is ~15 missed passes, i.e. the analysis has
    /// stopped (thermal gate, backgrounding), not a dropped frame.
    nonisolated static let bodyStaleSeconds: Double = 1.0

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
        gestureNeutral = []
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
        let bodySlot = latestBody
        let body = BodyPoseAnalyzer(sink: { bag in bodySlot.store(bag) })
        bodyAnalyzer = body
        let proxy = FaceDelegateProxy(latest: latest, body: body)
        delegateProxy = proxy
        arSession.delegate = proxy
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        // K7 — segmentation only if a picture wants the matte right now; `syncSegmentation`
        // follows the wish (and the thermal ladder) from the drain on.
        segmentationOn = Self.supportsSegmentation && CameraFrameSlot.shared.wantsMatte() && !Self.thermalIsSerious
        config.frameSemantics = segmentationOn ? [.personSegmentation] : []
        arConfig = config
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
        bodyAnalyzer = nil
        pushedOrientationRaw = -1
        arConfig = nil
        segmentationOn = false
        #endif
        thermalRelief = nil
        latest.clear()
        latestBody.clear()
        CameraFrameSlot.shared.clear()   // K5 — no stale camera frame survives a stop
        mapping = Self.freshMapping()
        gestures = FaceGestureBank(deadzone: FaceExpressionMapping.defaultDeadzone)
        isCalibrating = false
        isFaceTracked = false
        faceLostAt = nil
        hadInput = false
        smile = 0; browRaise = 0; jawOpen = 0
        syncBodyNumbers()
        isPublishing = false
    }

    /// The five body observables from the bank — one place, called wherever the bank moves.
    private func syncBodyNumbers() {
        handHeightL = gestures[.handHeightL]
        handHeightR = gestures[.handHeightR]
        handDistance = gestures[.handDistance]
        shoulderTilt = gestures[.shoulderTilt]
        bodyPresence = gestures[.bodyPresence]
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
        syncSegmentation()
        syncBodyOrientation()
        let now = CFAbsoluteTimeGetCurrent()
        let dt = Swift.max(0, now - lastPublish)
        // K6a — two slots feed one drain: the face bag (ARKit anchors) and the body bag
        // (Vision on the same frames, aged out after `bodyStaleSeconds`). Either alone keeps
        // the take alive; the channels of the absent half ease to rest through the ordinary
        // update, because their keys are simply missing from the merged bag.
        let faceBag = latest.read()
        let bodyBag = latestBody.read(maxAge: Self.bodyStaleSeconds)
        guard faceBag != nil || bodyBag != nil else {
            // #1259 — face gone: fade, do not snap, do not freeze. Publish the fading
            // channels for up to `lossFadeCapSeconds`, then stop publishing (a source that
            // measures nothing says nothing — the consumers hold or read neutral by their
            // own law, and `usableBio()` ages the last frame out after the freshness window).
            isFaceTracked = false
            if hadInput { hadInput = false; faceLostAt = now }
            guard let lostAt = faceLostAt else { return }
            if (mapping.isSettled && gestures.isSettled) || now - lostAt > Self.lossFadeCapSeconds {
                faceLostAt = nil
                mapping = mapping.released(dt: 10)   // exact 0, hysteresis released
                gestures = gestures.released(dt: 10)
                smile = 0; browRaise = 0; jawOpen = 0
                syncBodyNumbers()
                return
            }
            mapping = mapping.released(dt: dt)
            gestures = gestures.released(dt: dt)
            lastPublish = now
            smile = mapping.smile; browRaise = mapping.browRaise; jawOpen = mapping.jawOpen
            syncBodyNumbers()
            publishFrame(bus: bus, at: now)
            return
        }
        faceLostAt = nil
        hadInput = true
        isFaceTracked = faceBag != nil
        lastPublish = now
        var bag = faceBag ?? [:]
        if let body = bodyBag { bag.merge(body) { _, new in new } }
        let raw = FaceExpressionMapping.rawChannels(from: bag)
        let rawGestures = FaceGestureChannel.rawValues(from: bag)
        // The neutral hold collects FACE samples only: without a face there is nothing to
        // centre, and the body channels are never calibrated (`FaceGestureChannel.isBody`).
        if isCalibrating, faceBag != nil {
            neutralSamples.smile.append(raw.smile)
            neutralSamples.brow.append(raw.browRaise)
            neutralSamples.jaw.append(raw.jawOpen)
            gestureNeutral.append(rawGestures)
            if now >= calibrationEndsAt {
                calibration = FaceCalibration.fromNeutral(smile: neutralSamples.smile,
                                                          browRaise: neutralSamples.brow,
                                                          jawOpen: neutralSamples.jaw)
                // #1260 — the bank's baselines from the same hold (mean per channel).
                var baselines: [String: Float] = [:]
                for (i, ch) in FaceGestureChannel.allCases.enumerated() where !ch.isBody {
                    let xs = gestureNeutral.compactMap { i < $0.count && $0[i].isFinite ? $0[i] : nil }
                    if !xs.isEmpty { baselines[ch.rawValue] = xs.reduce(0, +) / Float(xs.count) }
                }
                calibration.gestureBaselines = baselines
                gestureNeutral = []
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
        gestures = gestures.updated(raw: calibration.applyGestures(rawGestures), dt: dt)
        smile = mapping.smile
        browRaise = mapping.browRaise
        jawOpen = mapping.jawOpen
        syncBodyNumbers()
        publishFrame(bus: bus, at: now)
    }

    /// K7 — the person matte follows the renderer's wish AND the thermal ladder: at
    /// `.serious` the matte is the rung after body tracking (`BodyPoseAnalyzer` gates itself);
    /// the camera image itself keeps flowing. Re-running the SAME configuration with changed
    /// `frameSemantics` and no reset options keeps the face tracking — no flicker on the field.
    /// The relief text is written on change only (cold for the leaves that read it).
    private func syncSegmentation() {
        let serious = Self.thermalIsSerious
        let relief: String? = serious ? "Heat: body tracking and cut-out paused until the device cools." : nil
        if relief != thermalRelief { thermalRelief = relief }
        guard let config = arConfig, Self.supportsSegmentation else { return }
        let want = CameraFrameSlot.shared.wantsMatte() && !serious
        guard want != segmentationOn else { return }
        segmentationOn = want
        config.frameSemantics = want ? [.personSegmentation] : []
        arSession.run(config)
    }

    /// K6c — the body pass reads the sensor buffer in the INTERFACE's orientation. Read here on
    /// the main actor (the draw loop's `MainActor.assumeIsolated` read in the renderer is the
    /// same fact), pushed to the analyzer on change only.
    private func syncBodyOrientation() {
        #if canImport(ARKit) && canImport(UIKit)
        let raw = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation.rawValue ?? 1
        guard raw != pushedOrientationRaw else { return }
        pushedOrientationRaw = raw
        bodyAnalyzer?.setInterfaceOrientation(raw: raw)
        #endif
    }

    /// `ProcessInfo.thermalState` at `.serious` or worse — the prompt's degradation threshold.
    nonisolated static var thermalIsSerious: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    /// The ONE `.faceCam` frame shape — tracked and fading takes share it.
    private func publishFrame(bus: EngineBus, at now: CFAbsoluteTime) {
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
            faceJawOpen: mapping.jawOpen,
            faceBrowDown: gestures[.browDown],
            faceEyeBlink: gestures[.eyeBlink],
            faceEyeSquint: gestures[.eyeSquint],
            faceMouthPucker: gestures[.mouthPucker],
            faceCheekPuff: gestures[.cheekPuff],
            headYaw: gestures[.headYaw],
            headPitch: gestures[.headPitch],
            headRoll: gestures[.headRoll],
            headDistance: gestures[.headDistance],
            handHeightL: gestures[.handHeightL],
            handHeightR: gestures[.handHeightR],
            handDistance: gestures[.handDistance],
            shoulderTilt: gestures[.shoulderTilt],
            bodyPresence: gestures[.bodyPresence]
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
    /// K6a — hands and shoulders from the SAME frames (Vision on `capturedImage`, own queue,
    /// drop policy inside). `nil` only in a build without Vision.
    private let body: BodyPoseAnalyzer?
    init(latest: LatestFaceSample, body: BodyPoseAnalyzer?) {
        self.latest = latest
        self.body = body
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let face = anchor as? ARFaceAnchor else { continue }
            var bag: [String: Float] = [:]
            bag.reserveCapacity(face.blendShapes.count + 4)
            for (key, value) in face.blendShapes {
                bag[key.rawValue] = value.floatValue
            }
            // #1260 — head pose RELATIVE TO THE CAMERA (world-space anchor × inverse camera),
            // so holding the phone off-axis is not a head turn. Radians / metres go into the
            // same bag; `FaceGestureChannel` normalises them. Sign convention is a device
            // ask (see `FaceGestureChannel.yawFullScaleRadians`).
            if let camera = session.currentFrame?.camera.transform {
                let rel = simd_inverse(camera) * face.transform
                let fwd = simd_normalize(SIMD3(rel.columns.2.x, rel.columns.2.y, rel.columns.2.z))
                let right = simd_normalize(SIMD3(rel.columns.0.x, rel.columns.0.y, rel.columns.0.z))
                let t = SIMD3(rel.columns.3.x, rel.columns.3.y, rel.columns.3.z)
                bag[FaceGestureChannel.headYawKey] = atan2f(fwd.x, fwd.z)
                bag[FaceGestureChannel.headPitchKey] = asinf(Swift.max(-1, Swift.min(1, fwd.y)))
                bag[FaceGestureChannel.headRollKey] = atan2f(right.y, right.x)
                bag[FaceGestureChannel.headDistanceKey] = simd_length(t)
            }
            latest.store(bag)
        }
    }

    /// K5 (#1262) — the camera image itself, for the visual's texture layer. Stored only while
    /// a renderer has said it wants one (`wantedViewports()` non-empty), so a Face source with
    /// the layer at 0 retains no buffer. ONE owner of the front camera: this is the session
    /// that tracks the face — no second capture session (prompt rule 1). The transform is
    /// ARKit's own `displayTransform`, inverted (viewport → image), computed per registered
    /// viewport at frame rate because it is a 3×2 affine and the delegate already holds the
    /// frame. The `ARFrame` itself is NOT retained (ARKit stalls its pool on that); only the
    /// pixel buffer is, one slot deep, latest wins — that IS the drop strategy.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // K6a — the body pass FIRST, unconditionally: it is the instrument input, the texture
        // layer below is the picture. `analyze` returns at once (stride, drop, thermal gate).
        body?.analyze(frame.capturedImage)
        let wanted = CameraFrameSlot.shared.wantedViewports()
        guard !wanted.isEmpty else { return }
        var transforms: [UUID: CGAffineTransform] = [:]
        transforms.reserveCapacity(wanted.count)
        for (key, viewport) in wanted {
            guard viewport.size.width > 0, viewport.size.height > 0 else { continue }
            let orientation = UIInterfaceOrientation(rawValue: viewport.orientationRaw) ?? .portrait
            transforms[key] = frame.displayTransform(for: orientation, viewportSize: viewport.size).inverted()
        }
        // K7 — the matte rides along when ARKit produced one (segmentation on); nil otherwise.
        CameraFrameSlot.shared.store(frame.capturedImage, matte: frame.segmentationBuffer, transforms: transforms)
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
    func sessionWasInterrupted(_ session: ARSession) {
        latest.clear()
        // The body slot ages out by itself (`bodyStaleSeconds`) — no clear needed here, and
        // the analyzer holds no frame between passes.
        CameraFrameSlot.shared.clear()   // K5 — the last image must not stay on the field
    }
}
#endif
