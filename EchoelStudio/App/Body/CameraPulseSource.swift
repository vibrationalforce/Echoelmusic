import EchoelCore
import EchoelDSP
import EchoelEngine
import Foundation
import Observation
import os

/// The rear camera as a body source (wave W1): a fingertip on the lens, lit by the flash, read as a
/// pulse (rPPG). Off until the musician chooses "Camera"; only then does iOS ask for the camera.
/// This class is the ONE owner of the camera's life (`CameraCapture`), of the analyzer
/// (`PulseAnalyzer`) and of the exposure policy (`RPPGExposureLock`), on the main actor.
///
/// It publishes what the strap publishes: the pulse through a `BodyChannel` (a value only while it
/// is real — trusted, from this run, fresh), HRV and coherence from the beat-to-beat intervals once
/// enough clean beats exist, and the three as modulation sources that glide into `output`.
///
/// What the frames become: three averaged numbers per frame, on the capture queue, pushed into a
/// queue the 10 Hz loop here drains in one batch — never a task per frame (10.76.48). No frame,
/// no image and no sample is kept or written anywhere; the camera feed never leaves the device.
/// The flash is steady at one level, never pulsed (the 3 Hz law applies to light the eye sees).
///
/// Observed properties change at most about once a second (`beatsPerMinute`, `cue`, `status`,
/// `measuring`), so a readout may read them without churning (Law 6). The analyzer's own 15 Hz
/// state is not observable at all.
@MainActor
@Observable
final class CameraPulseSource {
    enum Status: Equatable {
        case off
        /// The camera cannot be used in this build or on this device; the text says why.
        case unavailable(String)
        /// Camera access is off in Settings.
        case denied
        /// Asking for access, opening the camera.
        case starting
        /// The camera runs; `cue` says what the finger should do.
        case measuring
        /// iOS holds the camera (a call, Control Centre, the background); it resumes by itself.
        case interrupted
    }

    private(set) var status: Status = .off
    /// The last trusted rate, only while `pulse` holds a value.
    private(set) var beatsPerMinute: Int?
    /// What the finger should do right now; `.locked` while a pulse is trusted.
    private(set) var cue: PulseCue = .coverLens
    /// The sources that carry a value right now — what a route would actually follow. Changes
    /// only when a source starts or stops being measured, so a menu may read it (Law 6).
    private(set) var measuring: Set<ModulationSource> = []

    /// The pulse channel: normalized 0 … 1 over 40 … 200 bpm, nil while not measured. Not observed:
    /// it steps on every tick, and nothing on screen needs the channel itself.
    @ObservationIgnored private(set) var pulse = BodyChannel(maximumAgeMilliseconds: CameraPulseSource.freshMilliseconds,
                                                           minimumQuality: PulseTrust.displayThreshold)

    // The same numbers as the strap's (`HeartRateStrap`), written out: a `static let` on a
    // `@MainActor` class is isolated on Xcode's toolchain, and a static initializer is not a place
    // to read another class's.
    nonisolated static let plausibleBeats = 40...200
    /// A trusted reading is published about once a second; three missed and the pulse is no
    /// longer live — the hold that keeps a brief dropout from snapping anything to zero.
    nonisolated static let freshMilliseconds: Int64 = 3_000
    /// The loop's period: drains the frames, steps the exposure policy, refreshes the cue.
    nonisolated static let tickMilliseconds = 100
    /// Every tenth tick publishes to the channel — about once a second, like the strap's packets.
    nonisolated static let publishEveryTicks = 10
    /// The newest accepted beat intervals kept for HRV and coherence.
    nonisolated static let intervalCapacity = 64
    /// The sources the camera feeds.
    nonisolated static let feeds: [ModulationSource] = [.heartRate, .hrv, .coherence]
    nonisolated static let glideSeconds = 0.6
    nonisolated static let glideStepSeconds = 1.0 / 30
    /// Frames per second below which the pulse band cannot be measured (the camera throttled to a trickle).
    nonisolated static let minMeasurableInboundHz = 6.0
    /// The analyzer's window counts as full from here (150 samples at 15 fps).
    nonisolated static let fullWindowSamples = 140

    /// Where the pulse goes as the modulation sources (W2), gliding like the strap's.
    @ObservationIgnored var output: ModulationInputs?
    @ObservationIgnored private var capture: CameraCapture?
    @ObservationIgnored private var analyzer = PulseAnalyzer()
    @ObservationIgnored private var exposure = RPPGExposureLock()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var glide: Task<Void, Never>?
    /// The current run; a start that resumes from its awaits with another number is not the owner.
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var sequence: Int64 = 0
    @ObservationIgnored private var tick = 0
    @ObservationIgnored private let started = ContinuousClock.now
    /// The accepted beat intervals of this take, oldest first, fed exactly once per beat.
    @ObservationIgnored private var rrIntervalsMilliseconds: [Double] = []
    /// The capture time of the newest beat taken from the analyzer's overlapping windows.
    @ObservationIgnored private var lastBeatTime: Double = 0
    @ObservationIgnored private var derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
    @ObservationIgnored private var gliding: [ModulationSource: Double] = [:]
    /// Frames per second the loop actually drains, smoothed; seeded at the nominal rate so a
    /// fresh start never reads as a stall.
    @ObservationIgnored private var inboundRate: Double = 15
    @ObservationIgnored private var loopTicks = 0
    /// When the cue became `.finding` and stayed there, in host milliseconds; 0 while it is not.
    @ObservationIgnored private var findingSince: Int64 = 0
    @ObservationIgnored private var stallWasRhythmless: Bool?
    @ObservationIgnored private var suspended = false
    /// THE arbitration of the rear camera for the whole app (`CameraArbitration`): take > pulse >
    /// sky. This class owns it because it is the camera's long-lived owner; a take
    /// (`VideoTakeRecorder`) and the sky view (`SkyCamera`) ask here and open the camera only when
    /// it answers so — never two capture sessions on the one lens.
    @ObservationIgnored private var arbitration = CameraArbitration()
    /// The sky view's camera layer may hold the camera now. Observed: it changes only at a hand-over.
    private(set) var skyHoldsCamera = false
    /// A video take holds the camera: a pulse chosen now waits suspended, and `resume()` opens it
    /// when the take gives the camera back.
    var takeHoldsCamera: Bool { arbitration.holder == .take }
    /// The current holder's generation; a callback stamped with an older one is stale.
    var cameraGeneration: UInt64 { arbitration.generation }
    func isCameraCurrent(_ generation: UInt64) -> Bool { arbitration.isCurrent(generation) }
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "body")

    var isOn: Bool { status != .off }

    // MARK: - On and off

    /// The musician chose the camera. Asks for access the first time, then opens the camera and
    /// lights the flash. A build without the camera permission text refuses here, visibly, instead
    /// of letting iOS end the app at the first access.
    func start() {
        guard !isOn else { return }
        guard CameraCapture.hasUsageDescription else {
            status = .unavailable("This build carries no camera permission text; the camera stays closed.")
            cue = .coverLens
            log.error("camera pulse refused: NSCameraUsageDescription is missing from the bundle")
            return
        }
        generation &+= 1
        let run = generation
        carry(arbitration.choosePulse())
        if takeHoldsCamera {
            // Production wins: the pulse is on, and waits for the camera.
            suspended = true
            status = .interrupted
            apply(.start(.camera, CameraCapture.permission()))
            apply(.suspend)
            return
        }
        status = .starting
        apply(.start(.camera, CameraCapture.permission()))
        Task { @MainActor [weak self] in
            await self?.open(run: run, resuming: false)
        }
    }

    /// The musician turned it off: the camera is released, the flash is off, every value is gone.
    func stop() {
        guard isOn else { return }
        generation &+= 1
        closeCamera()
        // After the camera is closed: a waiting sky layer may take it now.
        carry(arbitration.dropPulse())
        apply(.stop)
        status = .off
        cue = .coverLens
        beatsPerMinute = nil
        forgetTake()
    }

    // MARK: - The other claimants (take, sky)

    /// A take wants the camera: it gets it — the pulse pausing, the sky layer closing — and the
    /// answer is the take's generation. Nil while a take already holds it.
    func beginTake() -> UInt64? {
        guard let steps = arbitration.beginTake() else { return nil }
        carry(steps)
        return arbitration.generation
    }

    /// The take ended: the camera goes back to a chosen pulse, else to a waiting sky view.
    func endTake() {
        carry(arbitration.endTake())
    }

    /// The sky view opened and would show its camera layer; `skyHoldsCamera` says when it may.
    func wantSky() {
        carry(arbitration.wantSky())
    }

    /// The sky view closed.
    func dropSky() {
        carry(arbitration.dropSky())
    }

    /// Carries out what the arbitration answered. Opening and closing the pulse's own camera is
    /// `start()`/`stop()`'s work; the steps here are what the OTHER claimants' moves mean for it.
    private func carry(_ steps: [CameraArbitration.Step]) {
        for step in steps {
            switch step {
            case .suspendPulse: suspend()
            case .resumePulse: resume()
            case .openSky: if !skyHoldsCamera { skyHoldsCamera = true }
            case .closeSky: if skyHoldsCamera { skyHoldsCamera = false }
            case .openPulse, .closePulse, .openTake, .closeTake: break
            }
        }
    }

    /// A production camera takes the lens (camera-arbitration: production wins): the pulse pauses
    /// without turning off, and `resume()` reopens it. Called through `beginTake()`/`endTake()`.
    func suspend() {
        guard isOn, !suspended else { return }
        suspended = true
        generation &+= 1
        closeCamera()
        apply(.suspend)
        status = .interrupted
        forgetTake()
    }

    func resume() {
        guard isOn, suspended else { return }
        suspended = false
        generation &+= 1
        let run = generation
        status = .starting
        apply(.resume)
        Task { @MainActor [weak self] in
            await self?.open(run: run, resuming: true)
        }
    }

    /// Ask, open, light, run the loops — unless a stop or another start came first.
    private func open(run: UInt64, resuming: Bool) async {
        let granted = await CameraCapture.requestAccess()
        guard run == generation, isOn else { return }
        if !resuming {
            apply(.permission(granted ? .granted : .denied, source: .camera, epoch: pulse.epoch))
        }
        guard granted else {
            status = .denied
            cue = .cameraDenied
            return
        }
        let capture = self.capture ?? makeCapture()
        self.capture = capture
        do {
            try await capture.start(epoch: run)
        } catch {
            // A stop or a newer start owns the state now; the camera this call opened is torn down
            // only when it is a stop that won (a newer start has its own session to keep).
            guard run == generation else {
                if !isOn { capture.stop() }
                return
            }
            log.warning("camera pulse could not start: \(String(describing: error), privacy: .public)")
            status = .unavailable(Self.words(for: error))
            return
        }
        guard run == generation else {
            if !isOn { capture.stop() }
            return
        }
        capture.setTorch(true)
        analyzer.start()
        exposure.reset()
        inboundRate = 15
        loopTicks = 0
        tick = 0
        status = .measuring
        cue = .coverLens
        startLoops()
        log.notice("camera pulse started")
    }

    private func makeCapture() -> CameraCapture {
        CameraCapture { [weak self] event in
            Task { @MainActor [weak self] in
                self?.cameraEvent(event)
            }
        }
    }

    private func closeCamera() {
        loop?.cancel()
        loop = nil
        glide?.cancel()
        glide = nil
        capture?.setTorch(false)
        capture?.unlockExposure()
        capture?.stop()
        analyzer.reset()
        exposure.reset()
        for source in Self.feeds { output?.set(source, nil) }
        gliding = [:]
        if !measuring.isEmpty { measuring = [] }
    }

    private func forgetTake() {
        rrIntervalsMilliseconds = []
        lastBeatTime = 0
        derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
        findingSince = 0
        stallWasRhythmless = nil
        inboundRate = 15
        loopTicks = 0
    }

    static func words(for error: Error) -> String {
        guard let start = error as? CameraCapture.StartError else { return "The camera could not be opened." }
        switch start {
        case .noCamera: return "This device has no rear camera to read a pulse from."
        case .configurationFailed: return "The camera could not be opened — another app may be using it."
        }
    }

    // MARK: - Camera events (main actor, from the session queue)

    private func cameraEvent(_ event: CameraCapture.Event) {
        guard isOn, !suspended else { return }
        switch event {
        case .interrupted:
            apply(.suspend)
            if status != .interrupted { status = .interrupted }
            clearMeasured()
        case .resumed:
            apply(.resume)
            // A resumed session keeps a locked exposure from before: hand it back to auto and
            // let the policy re-lock on the finger as it is now; the window re-acquires from clean.
            capture?.unlockExposure()
            exposure.sessionReset()
            analyzer.rearmFrameRateAdaptation()
            analyzer.resetForRecovery(keepEstimate: false)
            inboundRate = 15
            if status != .measuring { status = .measuring }
        case .restarted:
            capture?.unlockExposure()
            exposure.sessionReset()
            analyzer.rearmFrameRateAdaptation()
            analyzer.resetForRecovery(keepEstimate: false)
            inboundRate = 15
        case .failed(let reason):
            generation &+= 1
            closeCamera()
            apply(.stop)
            forgetTake()
            beatsPerMinute = nil
            status = .unavailable(reason)
            cue = .coverLens
        }
    }

    // MARK: - The loop

    private func startLoops() {
        loop?.cancel()
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(CameraPulseSource.tickMilliseconds))
                guard let self, !Task.isCancelled else { break }
                self.poll()
            }
        }
        glide?.cancel()
        glide = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(CameraPulseSource.glideStepSeconds))
                guard let self, !Task.isCancelled else { break }
                self.glideTowardsPulse()
            }
        }
    }

    /// One tick: the frames since the last one into the analyzer, in order and with their capture
    /// times; then the exposure policy, the cue, and every tenth tick the channel.
    private func poll() {
        guard status == .measuring || status == .interrupted, let capture else { return }
        let drained = capture.samples.drain()
        for sample in drained {
            analyzer.process(red: sample.red, green: sample.green, blue: sample.blue, at: sample.time)
        }
        loopTicks += 1
        let seconds = Double(Self.tickMilliseconds) / 1_000
        inboundRate = inboundRate * 0.9 + Double(drained.count) / seconds * 0.1
        apply(.tick)
        guard status == .measuring else { return }

        let trusted = PulseTrust.isTrustworthy(confidence: analyzer.confidence, autoStrength: analyzer.autoStrength)
        steerExposure(capture, trusted: trusted)
        updateCue(trusted: trusted)

        tick += 1
        guard tick % Self.publishEveryTicks == 0 else { return }
        // A camera throttled to a trickle cannot carry the pulse band: publish nothing, and the
        // channel runs stale by itself.
        guard loopTicks < 50 || inboundRate >= Self.minMeasurableInboundHz else { return }
        // Evidence read fresh here: the exposure step above may just have flushed the window.
        let bpm = analyzer.estimatedBPM
        let quality = PulseTrust.quality(confidence: analyzer.confidence, autoStrength: analyzer.autoStrength)
        guard PulseTrust.shouldPublish(bpm: bpm, confidence: analyzer.confidence, autoStrength: analyzer.autoStrength) else {
            return
        }
        sequence += 1
        let rounded = Int(bpm.rounded())
        let normalized: Double? = Self.plausibleBeats.contains(rounded)
            ? Double(rounded - Self.plausibleBeats.lowerBound)
                / Double(Self.plausibleBeats.upperBound - Self.plausibleBeats.lowerBound)
            : nil
        apply(.sample(.init(source: .camera, epoch: pulse.epoch, sequence: sequence, capturedMilliseconds: nowMilliseconds,
                            value: normalized, quality: quality)))
        if pulse.value != nil {
            if beatsPerMinute != rounded { beatsPerMinute = rounded }
            takeNewBeats()
        }
    }

    /// Each beat exactly once: the analyzer's windows overlap by ~90 %, so only intervals whose
    /// closing beat is newer than the last one taken are new. One cursor feeds HRV and coherence.
    private func takeNewBeats() {
        let intervals = analyzer.rrIntervalsMs
        let times = analyzer.beatTimes
        guard intervals.count == times.count else { return }
        var added = false
        for (index, time) in times.enumerated() where time > lastBeatTime {
            lastBeatTime = time
            let interval = intervals[index]
            guard interval > 250, interval < 2_000 else { continue }
            rrIntervalsMilliseconds.append(interval)
            added = true
        }
        guard added else { return }
        if rrIntervalsMilliseconds.count > Self.intervalCapacity {
            rrIntervalsMilliseconds.removeFirst(rrIntervalsMilliseconds.count - Self.intervalCapacity)
        }
        derived = BeatDerivedSources.readings(rrMs: rrIntervalsMilliseconds)
    }

    private func steerExposure(_ capture: CameraCapture, trusted: Bool) {
        let input = RPPGExposureLock.Input(fingerDetected: analyzer.isFingerDetected,
                                           brightness: analyzer.brightness,
                                           red: analyzer.redChannel,
                                           autoStrength: Float(analyzer.autoStrength),
                                           confidence: Float(analyzer.confidence),
                                           windowFull: analyzer.windowSize >= Self.fullWindowSamples,
                                           settled: trusted)
        switch exposure.tick(input) {
        case .none:
            break
        case .lock:
            capture.lockExposure()
            capture.setTorch(true)   // an exposure change can drop the torch
        case .unlock(let flush):
            capture.unlockExposure()
            switch flush {
            case .none: break
            case .keepEstimate: analyzer.resetForRecovery(keepEstimate: true)
            case .dropEstimate: analyzer.resetForRecovery(keepEstimate: false)
            }
        case .flushWindow:
            analyzer.resetForRecovery(keepEstimate: false)
        }
    }

    /// The placement classification, from the live signal, then the one thing an instant cannot
    /// know: how long a clean contact has produced nothing. Assigned only on change.
    private func updateCue(trusted: Bool) {
        var next: PulseCue
        if trusted, analyzer.estimatedBPM > 0 {
            next = .locked
        } else if capture?.isTorchUnavailable == true {
            next = .noLight
        } else if !analyzer.isFingerDetected {
            next = .coverLens
        } else if RPPGExposureLock.isWashedOut(brightness: analyzer.brightness, red: analyzer.redChannel) {
            next = .tooBright
        } else if PulseAnalyzer.isMotionAmplitude(analyzer.filteredAmplitude) {
            next = .holdStill
        } else if analyzer.filteredAmplitude < 0.0008 {
            next = .pressGently
        } else {
            next = .finding
        }
        let now = nowMilliseconds
        if next == .finding {
            if findingSince == 0 { findingSince = now }
            if let rhythmless = stallWasRhythmless {
                next = .stalled(hasRhythmlessSignal: rhythmless)
            } else if now - findingSince >= Int64(PulseCue.stalledAfterSeconds * 1_000) {
                // Latched once: a signal of the wrong shape (re-place the finger) or none at all.
                let rhythmless = analyzer.confidence >= PulseTrust.displayThreshold
                    || analyzer.autoStrength >= PulseTrust.trustAutoFloor
                stallWasRhythmless = rhythmless
                next = .stalled(hasRhythmlessSignal: rhythmless)
            }
        } else {
            findingSince = 0
            stallWasRhythmless = nil
        }
        if next != cue { cue = next }
    }

    /// One step of the glide: each source towards its measurement, or absent at once without one.
    /// HRV and coherence exist only while the pulse does — they come from its beats.
    private func glideTowardsPulse() {
        let factor = 1 - Foundation.exp(-Self.glideStepSeconds / Self.glideSeconds)
        let pulseValue = pulse.value
        for source in Self.feeds {
            let target: Double? = switch source {
            case .heartRate: pulseValue
            case .hrv: pulseValue == nil ? nil : derived.hrv
            case .coherence: pulseValue == nil ? nil : derived.coherence
            default: nil
            }
            guard let target else {
                if gliding.removeValue(forKey: source) != nil { output?.set(source, nil) }
                continue
            }
            let next = gliding[source].map { $0 + (target - $0) * factor } ?? target
            gliding[source] = next
            output?.set(source, next)
        }
        let now = Set(gliding.keys)
        if now != measuring { measuring = now }
    }

    private func clearMeasured() {
        for source in Self.feeds { output?.set(source, nil) }
        gliding = [:]
        if !measuring.isEmpty { measuring = [] }
        if beatsPerMinute != nil { beatsPerMinute = nil }
    }

    // MARK: - Steps

    private var nowMilliseconds: Int64 {
        let elapsed = ContinuousClock.now - started
        return elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
    }

    private func apply(_ event: BodyChannel.Event) {
        do {
            _ = try pulse.step(event, at: nowMilliseconds)
        } catch {
            log.error("body clock went back — \(String(describing: error), privacy: .public)")
        }
        if pulse.value == nil, beatsPerMinute != nil { beatsPerMinute = nil }
    }
}
