// Ported from the earlier app (Sources/Echoelmusic/Video/CameraAnalyzer.swift) for Echoel Studio
// 1.0, wave W1 "body" (scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md): the finger-on-lens
// pulse algorithm that locked on the device there, now a pure value type in EchoelDSP, Foundation
// only. What changed in the port, and nothing else: the Accelerate calls became plain loops (the
// windows are 150 samples); the `@MainActor @Observable` class became a struct the camera owner
// mutates on its own actor; a window too flat to measure now AGES the confidence like every other
// bail-out does (the earlier code left it frozen there); the DC estimate starts at the first
// sample instead of at 0, so the first 10 s window no longer carries a 0.4 step the motion gate
// reads as a moving finger; and the IQR bounds are inclusive, because a window of IDENTICAL
// intervals (the most regular one possible, exact at a period of whole frames) had an IQR of 0
// and the strict bounds rejected every one of its beats. `PulseAnalyzerTests` pins all three.

import Foundation

/// Camera photoplethysmography (rPPG): the red channel of a torch-lit fingertip, averaged per
/// frame, carries the pulse as a small periodic swing. This type takes one averaged RGB sample per
/// frame with its capture time and keeps a running estimate of the pulse rate, its confidence,
/// the beat-to-beat intervals and the signal's periodicity.
///
/// The pipeline, as it proved itself on the device:
/// 1. finger detection — red dominance with acquire-hard/hold-easy hysteresis over a 2 s window;
/// 2. DC removal (fast warm-up, then slow) and a 2nd-order Butterworth band-pass 0.7–4 Hz, re-tuned
///    once to the MEASURED frame rate;
/// 3. a 10 s rolling window: adaptive-threshold peak detection with a time-based refractory that
///    rejects the dicrotic notch, interval band 0.3–1.5 s, IQR rejection;
/// 4. autocorrelation (`PulsePeriodEstimator` over a `RPPGConditioning.linearDetrend`ed window) as
///    the independent witness: it seeds a fresh lock, folds octave errors, pulls an inflated peak
///    count toward the fundamental, and carries the estimate when fewer than three peaks are found;
/// 5. motion gates (a swing too large for a pulse, a ripple without periodicity), a median over
///    recent windows, a physiological slew limit of 8 bpm/s, and a confidence that cannot outlive
///    the measurement it describes.
///
/// Pure: time is the caller's monotonic clock in seconds (the frame capture time), and nothing
/// here reads a sensor, a clock or the main actor. Deterministic for a given sample sequence.
public struct PulseAnalyzer: Sendable {

    // MARK: - Outputs

    /// Average frame brightness (0 … 1) of the newest sample.
    public private(set) var brightness: Float = 0.5
    /// Average red channel (0 … 1) of the newest sample.
    public private(set) var redChannel: Float = 0.5
    /// The running pulse estimate in beats per minute; 0 while nothing is measured.
    public private(set) var estimatedBPM: Double = 0
    /// Trust in `estimatedBPM`, 0 … 1: window regularity and window-to-window agreement, aged by
    /// the time since the last real measurement.
    public private(set) var confidence: Double = 0
    /// Whether a finger covers the lit lens (the hysteresis window's decision).
    public private(set) var isFingerDetected = false
    /// Whether samples are being analyzed (`start()` … `stop()`).
    public private(set) var isDetecting = false
    /// A slow 0 … 1 summary: finger present, confidence, and a plausible pulsatile share of the red level.
    public private(set) var signalQuality: Double = 0
    /// The newest window's accepted beat-to-beat intervals in milliseconds — twice compacted
    /// (band, then IQR), so consecutive entries are not always consecutive beats; `rrSegments`
    /// says which are.
    public private(set) var rrIntervalsMs: [Double] = []
    /// The capture time of the beat that CLOSED each interval in `rrIntervalsMs`, 1:1 with it, so a
    /// consumer can take each beat exactly once across the overlapping windows.
    public private(set) var beatTimes: [Double] = []
    /// `rrIntervalsMs` split into runs of genuinely consecutive beats (`RRAdjacency`).
    public private(set) var rrSegments: [[Double]] = []
    /// Every peak-to-peak difference of the newest window in milliseconds, nothing removed, so a
    /// consumer can run its own hygiene and see how much it rejected.
    public private(set) var rawIntervalsMs: [Double] = []
    /// RMSSD over the accepted runs, in milliseconds; 0 while it cannot be stated.
    public private(set) var rmssd: Double = 0
    /// Autocorrelation strength of the newest window, 0 … 1 — the independent periodicity witness
    /// the trust gate reads beside `confidence`.
    public private(set) var autoStrength: Double = 0
    /// The autocorrelation's own rate estimate for the newest window; 0 without one.
    public private(set) var autoBPM: Double = 0
    /// Peak-to-peak amplitude of the band-passed window: the motion and placement cues read it.
    public private(set) var filteredAmplitude: Float = 0
    /// Peaks the newest scan found.
    public private(set) var peakCount = 0
    /// The frame rate measured from the newest window's timestamps.
    public private(set) var actualRate: Double = 0
    /// Samples in the newest window; a full window is about `windowSeconds` of frames.
    public private(set) var windowSize = 0

    // MARK: - Constants

    /// The rate the band-pass is designed for before the measured rate is known.
    public static let nominalSampleRate: Double = 15
    /// The analysis window.
    public static let windowSeconds: Double = 10
    /// The rolling buffers hold about 40 s at 15 Hz.
    public static let maxSignalLength = 600
    /// Frames in the finger-detection window (2 s at 15 Hz).
    public static let fingerDetectionWindow = 30
    /// A resting heart cannot swing tens of bpm in a second: the committed estimate moves at most
    /// this much per real second.
    public static let maxBPMChangePerSecond: Double = 8
    /// Age of the last real measurement up to which the confidence stands unreduced.
    public static let confidenceHoldSeconds: Double = 2
    /// Age at which the confidence has reached zero: the pair (bpm, confidence) then describes
    /// nothing that was measured.
    public static let confidenceZeroSeconds: Double = 8
    /// Samples the drawn trace spans (~6 s at 15 Hz).
    public static let waveformDisplaySamples = 90
    /// Samples the trace's gain is measured over (~20 s): longer than the display, so the height
    /// does not jump as the shown window slides past one strong beat.
    public static let waveformGainSamples = 300
    /// Band-pass filtered amplitude above which a window is the finger moving, not a pulse.
    public static let motionAmplitude: Float = 0.20

    // MARK: - State

    private var frameCount = 0
    private var peakTick = 0
    private var dcWarmupCount = 0
    private var recentBPMs: [Double] = []
    private static let recentBPMCapacity = 5
    private var lastEstimateTimestamp: Double = 0
    private var effectiveSampleRate: Double = PulseAnalyzer.nominalSampleRate
    private var filterRateAdapted = false
    private var rawRedSignal: [Float] = []
    private var filteredRedSignal: [Float] = []
    private var signalTimestamps: [Double] = []
    private var dcEstimate: Float = 0
    private var bandpassState = BandpassState()
    private var bandpass: BandpassCoefficients
    private var fingerDetectionBuffer: [Bool] = []
    private var fingerTrueCount = 0

    public init() {
        bandpass = BandpassCoefficients(sampleRate: Float(PulseAnalyzer.nominalSampleRate))
    }

    // MARK: - Filter

    /// 2nd-order Butterworth coefficients by bilinear transform: high-pass 0.7 Hz, low-pass 4 Hz
    /// clamped under the Nyquist limit (at a low frame rate a fixed 4 Hz cutoff would prewarp past
    /// π/2 into a broken filter).
    private struct BandpassCoefficients: Sendable {
        let hpA0: Float, hpA1: Float, hpA2: Float, hpB1: Float, hpB2: Float
        let lpA0: Float, lpA1: Float, lpA2: Float, lpB1: Float, lpB2: Float

        init(sampleRate: Float) {
            let wHP = tanf(Float.pi * 0.7 / sampleRate)
            let wHP2 = wHP * wHP
            let a0hp: Float = 1 / (1 + 1.414 * wHP + wHP2)
            hpA0 = a0hp
            hpA1 = -2 * a0hp
            hpA2 = a0hp
            hpB1 = 2 * (wHP2 - 1) * a0hp
            hpB2 = (1 - 1.414 * wHP + wHP2) * a0hp
            let lpHz: Float = Swift.min(4, sampleRate * 0.45)
            let wLP = tanf(Float.pi * lpHz / sampleRate)
            let wLP2 = wLP * wLP
            let denom: Float = 1 + 1.414 * wLP + wLP2
            lpA0 = wLP2 / denom
            lpA1 = 2 * wLP2 / denom
            lpA2 = wLP2 / denom
            lpB1 = 2 * (wLP2 - 1) / denom
            lpB2 = (1 - 1.414 * wLP + wLP2) / denom
        }
    }

    private struct BandpassState: Sendable {
        var hpX1: Float = 0, hpX2: Float = 0, hpY1: Float = 0, hpY2: Float = 0
        var lpX1: Float = 0, lpX2: Float = 0, lpY1: Float = 0, lpY2: Float = 0
    }

    // MARK: - Lifecycle

    /// Begin analyzing: a fresh window and a fresh frame-rate measurement.
    public mutating func start() {
        guard !isDetecting else { return }
        isDetecting = true
        rearmFrameRateAdaptation()
        resetPulseState(keepEstimate: false)
    }

    /// Stop analyzing; the finger-contact decision stands until `reset()`.
    public mutating func stop() {
        isDetecting = false
    }

    /// Flush the rolling window without stopping — after a camera stall, an exposure step or a
    /// finger re-placement, whose brightness step would otherwise sit in the window for 10 s.
    /// `keepEstimate` separates OPTICAL state (always flushed) from PHYSIOLOGICAL state: `true`
    /// keeps the rate estimate and halves its confidence, for a re-settle the finger stayed on
    /// the lens through; `false` forgets it, for a new placement or a new person.
    public mutating func resetForRecovery(keepEstimate: Bool) {
        guard isDetecting else { return }
        resetPulseState(keepEstimate: keepEstimate)
    }

    /// Re-arm the one-time frame-rate measurement — only for a FRESH capture session, which may
    /// deliver another format. A mid-take flush keeps the measured rate: re-measuring during an
    /// exposure ramp once tuned the high-pass corner onto the very pulse being hunted.
    public mutating func rearmFrameRateAdaptation() {
        filterRateAdapted = false
        effectiveSampleRate = Self.nominalSampleRate
        bandpass = BandpassCoefficients(sampleRate: Float(Self.nominalSampleRate))
    }

    /// Full teardown at a take boundary: also forgets the finger-contact decision and the optical
    /// levels, which a mid-take flush deliberately keeps (dropping the contact there is what the
    /// hysteresis exists to prevent). A take that opens holding the previous take's contact
    /// decision reports a finger over a lens nothing touches.
    public mutating func reset() {
        rearmFrameRateAdaptation()
        resetPulseState(keepEstimate: false)
        brightness = 0.5
        redChannel = 0.5
        isDetecting = false
        isFingerDetected = false
        fingerDetectionBuffer.removeAll()
        fingerTrueCount = 0
        dcEstimate = 0
    }

    private mutating func resetPulseState(keepEstimate: Bool) {
        rawRedSignal.removeAll()
        filteredRedSignal.removeAll()
        signalTimestamps.removeAll()
        rrIntervalsMs.removeAll()
        beatTimes.removeAll()
        rrSegments.removeAll()
        rawIntervalsMs.removeAll()
        bandpassState = BandpassState()
        dcEstimate = 0
        dcWarmupCount = 0
        peakTick = 0
        if keepEstimate {
            confidence *= 0.5
        } else {
            recentBPMs.removeAll()
            lastEstimateTimestamp = 0
            estimatedBPM = 0
            confidence = 0
        }
        signalQuality = 0
        rmssd = 0
        peakCount = 0
        autoStrength = 0
        autoBPM = 0
        filteredAmplitude = 0
        actualRate = 0
        windowSize = 0
    }

    // MARK: - Samples

    /// One frame's averaged channels (each 0 … 1) at its capture time in seconds. Call in capture
    /// order; a batch drained from a queue is fine as long as each sample carries its own time.
    public mutating func process(red: Float, green: Float, blue: Float, at timestamp: Double) {
        guard red.isFinite, green.isFinite, blue.isFinite, timestamp.isFinite else { return }
        frameCount += 1
        brightness = (red + green + blue) / 3
        redChannel = red

        // Saturation (every channel clipped near white): the finger IS on the lens, pressed too
        // hard or washed out. Red dominance would fail here and drop the lock, so it counts as
        // present with a bad signal: hold, decay quality, skip the clipped sample.
        let saturated = Swift.min(red, green, blue) > 0.92
        let fingerFrame = Self.isFingerFrame(red: red, green: green, blue: blue,
                                             wasDetected: isFingerDetected,
                                             pulseCorroborated: confidence >= 0.35)
        updateFingerDetection(fingerFrame)

        if isDetecting && isFingerDetected {
            if saturated {
                signalQuality = Swift.max(0, signalQuality - 0.02)
            } else {
                processPulseSignal(red: red, timestamp: timestamp)
            }
        } else if isDetecting && !isFingerDetected {
            confidence = Swift.max(0, confidence - 0.02)
            signalQuality = Swift.max(0, signalQuality - 0.02)
            // The lock is truly lost (not a flicker the hysteresis absorbs): clear the held values
            // so no phantom rate is shown.
            if confidence < 0.05 {
                estimatedBPM = 0
                rmssd = 0
                rrIntervalsMs.removeAll()
                beatTimes.removeAll()
                rrSegments.removeAll()
                rawIntervalsMs.removeAll()
                recentBPMs.removeAll()
            }
        }
    }

    /// Sliding window with a running count, so the decision is O(1) per frame. Hysteresis: harder
    /// to acquire (half the window) than to hold (a quarter), so a brief glare or pressure flicker
    /// does not drop the lock and reset the confidence.
    private mutating func updateFingerDetection(_ fingerFrame: Bool) {
        fingerDetectionBuffer.append(fingerFrame)
        if fingerFrame { fingerTrueCount += 1 }
        if fingerDetectionBuffer.count > Self.fingerDetectionWindow {
            if fingerDetectionBuffer.removeFirst() { fingerTrueCount -= 1 }
        }
        let needed = isFingerDetected ? (Self.fingerDetectionWindow / 4) : (Self.fingerDetectionWindow / 2)
        isFingerDetected = fingerTrueCount > needed
    }

    private mutating func processPulseSignal(red: Float, timestamp: Double) {
        // DC removal: seeded with the first sample (a start from 0 put a step the size of the red
        // level into the window, which the motion gate then refused for a whole window), fast
        // warm-up for the first second so the baseline settles in ~1 s instead of ~6 s, then slow
        // tracking that stays immune to respiration drift.
        if dcWarmupCount == 0 { dcEstimate = red }
        dcWarmupCount += 1
        let dcCoefficient: Float = dcWarmupCount < Int(effectiveSampleRate) ? 0.90 : 0.99
        dcEstimate = dcEstimate * dcCoefficient + red * (1 - dcCoefficient)
        let dcRemoved = red - dcEstimate
        let filtered = applyBandpass(dcRemoved)

        rawRedSignal.append(red)
        filteredRedSignal.append(filtered)
        signalTimestamps.append(timestamp)
        if rawRedSignal.count > Self.maxSignalLength {
            rawRedSignal.removeFirst()
            filteredRedSignal.removeFirst()
            signalTimestamps.removeFirst()
        }

        // One-time re-tune of the band-pass to the TRUE frame rate: the assumed 15 Hz is often
        // wrong (devices deliver 7.5–15 Hz), a mismatch detunes the filter and below ~8 Hz breaks
        // it. Once ~2 s of samples give a stable rate, redesign the filter and refill the window.
        if !filterRateAdapted, signalTimestamps.count >= 30,
           let firstTime = signalTimestamps.first, let lastTime = signalTimestamps.last, lastTime > firstTime {
            let measured = Double(signalTimestamps.count - 1) / (lastTime - firstTime)
            if measured.isFinite, measured >= 4, measured <= 60,
               abs(measured - effectiveSampleRate) / effectiveSampleRate > 0.15 {
                effectiveSampleRate = measured
                bandpass = BandpassCoefficients(sampleRate: Float(measured))
                bandpassState = BandpassState()
                rawRedSignal.removeAll(keepingCapacity: true)
                filteredRedSignal.removeAll(keepingCapacity: true)
                signalTimestamps.removeAll(keepingCapacity: true)
                dcEstimate = 0
                dcWarmupCount = 0
            }
            filterRateAdapted = true
        }

        // About 2 s of data before the first estimate.
        guard rawRedSignal.count >= Int(effectiveSampleRate * 2) else { return }

        // The scan is O(n) with allocations; every fourth frame (~4 Hz) is plenty for a pulse and
        // keeps the owner's actor free. The per-sample filtering above still runs on every frame.
        peakTick += 1
        guard peakTick % 4 == 0 else { return }

        detectPeaks(timestamp: timestamp)
        updateSignalQuality()
    }

    private mutating func applyBandpass(_ input: Float) -> Float {
        let hpOut = bandpass.hpA0 * input + bandpass.hpA1 * bandpassState.hpX1 + bandpass.hpA2 * bandpassState.hpX2
            - bandpass.hpB1 * bandpassState.hpY1 - bandpass.hpB2 * bandpassState.hpY2
        bandpassState.hpX2 = bandpassState.hpX1
        bandpassState.hpX1 = input
        bandpassState.hpY2 = bandpassState.hpY1
        bandpassState.hpY1 = hpOut

        let lpOut = bandpass.lpA0 * hpOut + bandpass.lpA1 * bandpassState.lpX1 + bandpass.lpA2 * bandpassState.lpX2
            - bandpass.lpB1 * bandpassState.lpY1 - bandpass.lpB2 * bandpassState.lpY2
        bandpassState.lpX2 = bandpassState.lpX1
        bandpassState.lpX1 = hpOut
        bandpassState.lpY2 = bandpassState.lpY1
        bandpassState.lpY1 = lpOut
        return lpOut
    }

    // MARK: - Peaks

    private mutating func detectPeaks(timestamp: Double) {
        let n = filteredRedSignal.count
        guard n >= 5, signalTimestamps.count == n else { return }
        let size = Swift.min(n, Int(effectiveSampleRate * Self.windowSeconds))
        guard size >= 5 else { return }
        let startIndex = n - size
        let window = Array(filteredRedSignal[startIndex..<n])

        // The TRUE rate from the timestamps, so every rate derived here is right whatever the
        // camera delivered.
        let span = signalTimestamps[n - 1] - signalTimestamps[startIndex]
        let rate = span > 0 ? Double(size - 1) / span : effectiveSampleRate
        actualRate = rate
        windowSize = size

        // Periodicity once per scan, on a DETRENDED copy: the estimator removes the mean but not
        // the slope, and a slow ramp that survives the band filter swamps the small cardiac swing
        // in the autocorrelation (the device "no-lock": finger yes, amplitude high, acf ≈ 0.1).
        // The amplitude gates below stay tuned on the filtered window itself.
        let auto = PulsePeriodEstimator.dominantBPM(RPPGConditioning.linearDetrend(window), sampleRate: rate)
        autoStrength = auto?.strength ?? 0
        autoBPM = auto?.bpm ?? 0

        var maxAmp: Float = -Float.greatestFiniteMagnitude
        var minAmp: Float = Float.greatestFiniteMagnitude
        for value in window {
            if value > maxAmp { maxAmp = value }
            if value < minAmp { minAmp = value }
        }
        let amplitude = maxAmp - minAmp
        filteredAmplitude = amplitude
        // Too flat to carry a pulse: no measurement, so the confidence ages like any other bail-out.
        guard amplitude > 0.0003 else {
            peakCount = 0
            ageConfidence(timestamp)
            return
        }
        // A swing this large is the finger moving, changing pressure or lifting; its steady peak
        // count would otherwise earn a false "agreement" lock. Bleed the confidence gently while
        // the independent autocorrelation still confirms a strong pulse (a brief pressure blip on
        // a good lock), hard otherwise — this runs per sample and a batch drains 15–30 at once.
        if Self.isMotionAmplitude(amplitude) {
            peakCount = 0
            confidence *= Self.motionBleed(autoStrength: autoStrength)
            return
        }
        // Elevated amplitude with NO corroborating periodicity: a wobble the peak counter would
        // self-agree into a drifting rate. Hold the estimate and bleed gently.
        if Self.isUncorroboratedRipple(amplitude: amplitude, autoStrength: autoStrength) {
            peakCount = 0
            confidence *= 0.9
            return
        }
        let threshold = minAmp + amplitude * 0.55

        var newPeaks: [Int] = []
        for i in 2..<(size - 2) {
            let value = window[i]
            guard value > threshold else { continue }
            if value > window[i - 1] && value > window[i - 2] && value > window[i + 1] && value > window[i + 2] {
                if let last = newPeaks.last,
                   Self.isWithinRefractory(previous: signalTimestamps[startIndex + last],
                                           candidate: signalTimestamps[startIndex + i],
                                           autoBPM: autoBPM) { continue }
                newPeaks.append(i)
            }
        }
        peakCount = newPeaks.count

        guard newPeaks.count >= 3 else {
            fallbackBPM(auto, timestamp: timestamp)
            ageConfidence(timestamp)
            return
        }

        var intervals: [Double] = []
        var endTimes: [Double] = []
        var raw: [Double] = []
        for j in 1..<newPeaks.count {
            let end = signalTimestamps[startIndex + newPeaks[j]]
            let dt = end - signalTimestamps[startIndex + newPeaks[j - 1]]
            raw.append(dt * 1_000)
            guard dt > 0.3 && dt < 1.5 else { continue }
            intervals.append(dt)
            endTimes.append(end)
        }
        // Before any bail-out below: the window's beat timings are real even when the lock refuses
        // its rate, and the consumer that runs hygiene on them should decide.
        rawIntervalsMs = raw

        guard intervals.count >= 2 else {
            fallbackBPM(auto, timestamp: timestamp)
            ageConfidence(timestamp)
            return
        }

        // IQR outlier rejection, indexed so the end times survive the same rejection. Inclusive
        // bounds: identical intervals have an IQR of 0, and they are beats, not outliers.
        let sorted = intervals.sorted()
        let count = sorted.count
        let q1 = sorted[count / 4]
        let q3 = sorted[(count * 3) / 4]
        let iqr = q3 - q1
        let lowBound = q1 - 1.5 * iqr
        let highBound = q3 + 1.5 * iqr
        var cleanIntervals: [Double] = []
        var cleanEndTimes: [Double] = []
        for (index, value) in intervals.enumerated() where value >= lowBound && value <= highBound {
            cleanIntervals.append(value)
            cleanEndTimes.append(endTimes[index])
        }
        guard !cleanIntervals.isEmpty else {
            ageConfidence(timestamp)
            return
        }

        let averageInterval = cleanIntervals.reduce(0, +) / Double(cleanIntervals.count)
        let bpm = 60 / averageInterval
        guard bpm > 40 && bpm < 200 else {
            ageConfidence(timestamp)
            return
        }

        // Fresh-lock corroboration: right after the finger is placed, settling motion can
        // peak-count a harmonic. With no prior estimate, a CONFIDENT autocorrelation that disagrees
        // by more than 20 % makes the discrete count the suspect — seed from the autocorrelation.
        if estimatedBPM == 0, let auto, auto.strength > 0.4, abs(bpm - auto.bpm) / auto.bpm > 0.2 {
            estimatedBPM = auto.bpm
            let seedConfidence = Swift.min(1, (auto.strength - 0.4) / 0.4)
            confidence = confidence * 0.82 + seedConfidence * 0.18
            lastEstimateTimestamp = timestamp
            rrIntervalsMs = cleanIntervals.map { $0 * 1_000 }
            beatTimes = cleanEndTimes
            calculateRMSSD()
            return
        }

        var variance = 0.0
        for value in cleanIntervals {
            let deviation = value - averageInterval
            variance += deviation * deviation
        }
        variance /= Double(cleanIntervals.count)
        let cv = sqrt(variance) / averageInterval

        // Confidence: within-window regularity OR window-to-window agreement — rPPG intervals are
        // noisy, a rock-steady rate that agrees with itself is the stronger trust signal.
        let cvConfidence = Swift.max(0, Swift.min(1, 1 - cv * 2))
        let agreement: Double = estimatedBPM > 0
            ? Swift.max(0, 1 - abs(bpm - estimatedBPM) / 12)
            : cvConfidence
        let windowConfidence = Swift.max(cvConfidence, agreement)

        let target = stabilisedBPM(bpm)
        let previous = estimatedBPM
        estimatedBPM = estimatedBPM == 0 ? target : estimatedBPM * 0.80 + target * 0.20
        estimatedBPM = Self.autoTrust(estimate: estimatedBPM, autoBPM: autoBPM, autoStrength: autoStrength)
        // Physiological slew limit over the REAL elapsed time; a first commit snaps in.
        var slewClamped = false
        if previous > 0, lastEstimateTimestamp > 0 {
            let dt = Swift.min(2, Swift.max(0, timestamp - lastEstimateTimestamp))
            let limited = Self.slewLimited(previous: previous, target: estimatedBPM,
                                           maxDelta: Self.maxBPMChangePerSecond * dt)
            slewClamped = abs(limited - estimatedBPM) > 0.5
            estimatedBPM = limited
        }
        lastEstimateTimestamp = timestamp
        confidence = confidence * 0.82 + windowConfidence * 0.18
        // A clamped window tried to jump faster than physiology allows: self-consistency must
        // not keep a drifting rate "locked".
        if slewClamped { confidence *= 0.85 }

        rrIntervalsMs = cleanIntervals.map { $0 * 1_000 }
        beatTimes = cleanEndTimes
        calculateRMSSD()
    }

    /// Octave-fold a raw window rate toward the running estimate, anchor it to the autocorrelation
    /// fundamental, then take the median of the recent windows — so one noisy window cannot yank
    /// the rate while a real change still carries once it persists.
    private mutating func stabilisedBPM(_ raw: Double) -> Double {
        var bpm = raw
        // Only in true harmonic territory (a ratio gate): a nearest-candidate fold would read a
        // genuine 1.5–2× ramp as a doubled old rate and trap the lock at the old octave.
        if estimatedBPM > 0 {
            let ratio = raw / estimatedBPM
            if ratio > 1.6, raw / 2 >= 40 {
                bpm = raw / 2
            } else if ratio < 0.625, raw * 2 <= 200 {
                bpm = raw * 2
            }
        }
        bpm = Self.octaveCorrected(raw: bpm, autoBPM: autoBPM, autoStrength: autoStrength)
        recentBPMs.append(bpm)
        if recentBPMs.count > Self.recentBPMCapacity { recentBPMs.removeFirst() }
        let sorted = recentBPMs.sorted()
        return sorted[sorted.count / 2]
    }

    /// When fewer than three clean peaks exist (a rounded or weak waveform), the window's
    /// periodicity carries the rate — gated on strength so it locks onto a pulse, not noise. A real
    /// measurement, so it stamps the clock the confidence ages against.
    private mutating func fallbackBPM(_ auto: (bpm: Double, strength: Double)?, timestamp: Double) {
        guard let auto, auto.strength > 0.3 else { return }
        estimatedBPM = estimatedBPM == 0 ? auto.bpm : estimatedBPM * 0.80 + auto.bpm * 0.20
        let fallbackConfidence = Swift.max(0, Swift.min(1, (auto.strength - 0.3) / 0.5))
        confidence = confidence * 0.82 + fallbackConfidence * 0.18
        lastEstimateTimestamp = timestamp
    }

    /// Clamp the confidence to what the AGE of the last real measurement allows. Only ever lowers
    /// it: a fresh measurement stamps the clock and the ceiling is 1.
    private mutating func ageConfidence(_ timestamp: Double) {
        guard lastEstimateTimestamp > 0 else { return }
        let age = Swift.max(0, timestamp - lastEstimateTimestamp)
        confidence = Swift.min(confidence, Self.confidenceCeiling(forAge: age))
    }

    /// RMSSD pooled only WITHIN runs of genuinely consecutive beats, and the runs themselves — the
    /// one place both are assigned, so "the runs are current" and "RMSSD is current" hold together.
    /// Unconditional: a minimum-count hold here left a stale RMSSD beside a fresh pNN50.
    private mutating func calculateRMSSD() {
        rrSegments = RRAdjacency.segments(intervalsMs: rrIntervalsMs, endTimesSeconds: beatTimes)
        rmssd = HRVMetrics.rmssd(segments: rrSegments)
    }

    private mutating func updateSignalQuality() {
        var quality: Double = 0
        if isFingerDetected { quality += 0.3 }
        quality += confidence * 0.4
        // A good PPG signal has a small but measurable pulsatile share of the red level — judged
        // RELATIVE to it (coefficient of variation), 0.1 % … 10 % is the fingertip band.
        if rawRedSignal.count >= 30 {
            let recent = rawRedSignal.suffix(30)
            var mean: Float = 0
            for value in recent { mean += value }
            mean /= 30
            var variance: Float = 0
            for value in recent {
                let deviation = value - mean
                variance += deviation * deviation
            }
            variance /= 30
            let meanD = Double(mean)
            if meanD > 0.01 {
                let cv = Double(sqrt(Swift.max(0, variance))) / meanD
                if cv > 0.001 && cv < 0.1 { quality += 0.3 }
            }
        }
        signalQuality = signalQuality * 0.9 + quality * 0.1
    }

    // MARK: - Waveform

    /// The band-passed pulse, normalized to about −1 … 1, for a live trace: the last
    /// `waveformDisplaySamples` for the shape, divided by the largest magnitude over the last
    /// `waveformGainSamples` for the height. Empty until samples exist.
    public var waveform: [Float] {
        Self.normalizedTrace(filteredRedSignal, display: Self.waveformDisplaySamples,
                             gainWindow: Self.waveformGainSamples)
    }

    /// The trace law, pure. Not clamped: a beat above the recent maximum clips at the edge rather
    /// than rescaling everything around it.
    public static func normalizedTrace(_ signal: [Float], display: Int, gainWindow: Int) -> [Float] {
        let n = Swift.min(signal.count, Swift.max(display, 0))
        guard n > 1 else { return [] }
        let slice = Array(signal.suffix(n))
        let g = Swift.min(signal.count, Swift.max(gainWindow, n))
        var maxAbs: Float = 0
        for value in signal.suffix(g) where abs(value) > maxAbs { maxAbs = abs(value) }
        let norm = Swift.max(maxAbs, 0.0001)
        return slice.map { $0 / norm }
    }

    // MARK: - Pure laws

    /// Per-frame finger test with red-floor HYSTERESIS: acquire hard (red above 0.28), hold easy
    /// (0.12), and while a real periodicity is being measured hold down to 0.05 — the measurement
    /// is the evidence a finger is there, and the app's own dark exposure lock can put a held
    /// finger below the hold floor. The red-dominance ratios always gate a non-finger scene; a
    /// saturated frame (all channels clipped, finger pressed hard) still counts as present.
    public static func isFingerFrame(red: Float, green: Float, blue: Float,
                                     wasDetected: Bool, pulseCorroborated: Bool) -> Bool {
        let saturated = Swift.min(red, green, blue) > 0.92
        let redFloor: Float = wasDetected ? (pulseCorroborated ? 0.05 : 0.12) : 0.28
        return saturated || (red > redFloor && red > green * 1.2 && red > blue * 1.3)
    }

    /// Octave anchor against the autocorrelation fundamental: a GRADUAL half/double drift steps
    /// inside the per-window ratio gate and accumulates. When a confident periodicity says the rate
    /// is about ½× or 2× the fundamental, correct by exactly ×2 / ×0.5 — never inside the
    /// 0.625 … 1.6 band where a genuine change lives.
    public static func octaveCorrected(raw: Double, autoBPM: Double, autoStrength: Double) -> Double {
        guard raw > 0, autoBPM > 40, autoStrength > 0.45 else { return raw }
        let ratio = raw / autoBPM
        if ratio > 0.42 && ratio < 0.6, raw * 2 <= 220 { return raw * 2 }
        if ratio > 1.7 && ratio < 2.4, raw * 0.5 >= 35 { return raw * 0.5 }
        return raw
    }

    /// Confidence-weighted pull of the estimate toward the autocorrelation fundamental — for the
    /// NON-octave inflation a dicrotic notch causes (an extra peak per beat, ~1.3–1.7×). Usable from
    /// strength 0.4, up to 80 % of the way at 0.85.
    public static func autoTrust(estimate: Double, autoBPM: Double, autoStrength: Double) -> Double {
        guard estimate > 0, autoBPM > 40, autoStrength > 0.4 else { return estimate }
        let weight = Swift.min(0.8, (autoStrength - 0.4) / 0.45 * 0.8)
        return estimate * (1 - weight) + autoBPM * weight
    }

    /// `target` clamped to within `maxDelta` of `previous`; no elapsed time returns `target`.
    public static func slewLimited(previous: Double, target: Double, maxDelta: Double) -> Double {
        guard maxDelta > 0 else { return target }
        return Swift.min(previous + maxDelta, Swift.max(previous - maxDelta, target))
    }

    /// Whether a band-passed window amplitude is MOTION, not a pulse: real locks top out near
    /// 0.16 of the normalized red level, a re-grip or hard press reads 0.22 and above.
    public static func isMotionAmplitude(_ amplitude: Float) -> Bool {
        amplitude > motionAmplitude
    }

    /// A mid-amplitude window with essentially no periodicity — a ripple the peak counter would
    /// turn into a steady false rate. A low-amplitude lock and any window with some periodicity
    /// pass untouched.
    public static func isUncorroboratedRipple(amplitude: Float, autoStrength: Double) -> Bool {
        amplitude > 0.05 && amplitude <= motionAmplitude && autoStrength < 0.15
    }

    /// Per-sample confidence multiplier for a motion window: nearly 1 while the autocorrelation
    /// still confirms a strong pulse (a blip on a good lock survives a batch), 0.6 otherwise.
    public static func motionBleed(autoStrength: Double) -> Double {
        autoStrength > 0.4 ? 0.98 : 0.6
    }

    /// The highest confidence the age of the last real measurement can justify: 1 up to
    /// `confidenceHoldSeconds`, 0 from `confidenceZeroSeconds`, linear between. A ceiling on age
    /// cannot compound with the frame rate, the scan throttle or the batch size, which a per-call
    /// decay factor does.
    public static func confidenceCeiling(forAge age: Double) -> Double {
        guard age.isFinite else { return 0 }
        if age <= confidenceHoldSeconds { return 1 }
        if age >= confidenceZeroSeconds { return 0 }
        let span = confidenceZeroSeconds - confidenceHoldSeconds
        return Swift.max(0, Swift.min(1, 1 - (age - confidenceHoldSeconds) / span))
    }

    /// Minimum inter-beat distance in seconds: half the autocorrelation period, clamped to
    /// 0.3 … 0.6 s, so real beats (1.0× apart) pass and the dicrotic notch (~0.4× in) does not;
    /// 0.3 s without a plausible period.
    public static func refractorySeconds(autoBPM: Double) -> Double {
        guard autoBPM >= 40, autoBPM <= 180 else { return 0.3 }
        return Swift.min(0.6, Swift.max(0.3, 0.5 * 60 / autoBPM))
    }

    /// Whether a candidate peak falls inside the previous peak's refractory, asked in TIME: a
    /// sample-count version rejected nothing at low frame rates. Fails open on a non-finite
    /// timestamp; a negative gap is out-of-order data and is refused.
    public static func isWithinRefractory(previous: Double, candidate: Double, autoBPM: Double) -> Bool {
        let gap = candidate - previous
        guard gap.isFinite else { return false }
        return gap < refractorySeconds(autoBPM: autoBPM)
    }
}
