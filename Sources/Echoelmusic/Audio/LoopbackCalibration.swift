import Foundation

// J0 (founder 2026-10-07, live-jam priority — input, self-monitoring, output): the PURE half of a loopback
// latency calibration — a stimulus, a detector, a quality gate across repeats, and a report
// that keeps four different numbers apart.
//
// ⭐ WHAT A CALIBRATION RUN WOULD MEASURE, said exactly, because the founder's targets are
// about something else: a short noise burst leaves the speaker and the microphone records it.
// The delay between the two is the ACOUSTIC ROUND TRIP — the output stack, the AIR PATH from
// speaker to microphone (about 0.03 ms per centimetre), and the input stack. It is not the
// heard latency of a jam (no network, no remote phone), and it is not the self-monitoring
// latency either (that would be input → output, the other direction). Half of it is NOT a
// one-way figure: input and output stacks need not be symmetric, and nothing here claims they
// are. The founder's targets (≤ 10 ms self-monitoring, ≤ 20 ms remote p95) are goals, not
// promises, and this file promises neither. (The remote target is ONE-WAY p95; nothing measured
// here, or in `LinkProbe`, is a one-way figure.)
//
// ⭐ WHY A MEASUREMENT CAN BE REFUSED: a wrong number is worse than no number. These ways the
// detector can be fooled are named refusals, never guesses: a clipped input; a reflection as
// strong as the direct sound — far away, or (#review 2026-10-07) an EARLIER separate peak inside
// the 1 ms guard band, which means the strongest arrival is not the first; a peak at the edge of
// the search window; a noise floor too close to the signal, too short to measure, or digitally
// silent (an unknown floor is not a quiet one); a stimulus rate that differs from the recording
// rate; repeats that disagree. This list is what the code checks — not a proof that nothing else
// can fool it. A change of rate DURING a recording is invisible here; the device runner must
// refuse a run across a route change.
//
// ⚠️ A KNOWN LIMIT, found in the transcription and not yet measured on a phone: the stimulus is
// white, so a chain that strips much of its band lowers the correlation peak below
// `minimumPeak`. Simulated at 48 kHz, a 300 Hz–10 kHz chain is found; an 800 Hz–6 kHz
// fourth-order chain is refused as `noPeak`. That is the safe direction — a refusal, never a
// wrong number — but a narrow speaker may never calibrate. A band-limited stimulus does not
// cure it (its correlation side lobes trip the first-arrival rule); the candidate repair is a
// whitened correlation, to be chosen after a device run shows how narrow the real chain is.
//
// ⭐ WHAT IS NOT HERE, on purpose: no audio API. No engine, no session category, no input
// node, no recorder, no permission request. The microphone path is a founder decision
// (FOUNDER_INBOX J0, #1302 crash family at the input node) and the device runner that would
// feed this core is a separate slice; this file only computes on arrays it is handed.
//
// Built: yes. Wired: NO — nothing in `Sources/` constructs these types. Device: no.
// Guard: `Tests/CISmoke/TheLoopbackCalibrationRejectsWhatItCannotMeasureTests.swift`.

/// The stimulus: a deterministic white-noise burst with raised-cosine fades, peak −12 dBFS.
/// White noise has one sharp correlation peak, so the delay it reveals is unambiguous in a
/// quiet room; the low peak keeps the speaker and the microphone far from clipping.
enum CalibrationStimulus {

    /// −12 dBFS: a quarter of full scale.
    static let peak: Float = 0.25
    static let sampleRates: ClosedRange<Double> = 8_000...192_000
    /// Seconds. Shorter than 10 ms has too little energy to find; longer than 250 ms only
    /// smears reflections into the window.
    static let durations: ClosedRange<Double> = 0.01...0.25
    static let fadeSeconds = 0.002
    static let defaultSeed: UInt64 = 0xEC40_1A7E

    /// The burst, or nil for a non-finite input or a rate outside `sampleRates`. The duration
    /// is clamped into `durations`; the same seed always yields the same samples.
    static func burst(sampleRate: Double, duration: Double, seed: UInt64 = defaultSeed) -> [Float]? {
        guard sampleRate.isFinite, duration.isFinite, sampleRates.contains(sampleRate) else { return nil }
        let seconds = Swift.min(Swift.max(duration, durations.lowerBound), durations.upperBound)
        let count = Int((seconds * sampleRate).rounded())
        guard count > 2 else { return nil }

        var samples = [Float](repeating: 0, count: count)
        var state = seed
        for index in 0..<count {
            // SplitMix64: neighbouring seeds decorrelate at once.
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            samples[index] = Float(z >> 40) / Float(1 << 23) - 1
        }

        let fade = Swift.min(Int((fadeSeconds * sampleRate).rounded()), count / 2)
        for index in 0..<fade {
            let gain = Float(0.5 - 0.5 * cos(Double.pi * Double(index) / Double(fade)))
            samples[index] *= gain
            samples[count - 1 - index] *= gain
        }

        let loudest = samples.reduce(Float(0)) { Swift.max($0, abs($1)) }
        guard loudest > 0 else { return nil }
        let scale = peak / loudest
        for index in 0..<count { samples[index] *= scale }
        return samples
    }
}

/// One accepted detection. `lagFrames` is interpolated between samples.
struct CalibrationEstimate: Equatable, Sendable {
    let lagFrames: Double
    /// Normalised correlation at the peak, 0…1.
    let peak: Double
    /// The strongest correlation OUTSIDE the guard band around the peak.
    let runnerUp: Double
    /// Matched segment power over the pre-arrival noise floor, in dB.
    let snrDB: Double
}

/// Every reason a measurement is refused. A refusal is a result, not an error.
enum CalibrationRejection: String, Sendable, CaseIterable {
    case nonFinite
    case clipped
    case rateMismatch
    case tooShort
    case noPeak
    case lagOutOfWindow
    case ambiguous
    case lowSNR
    /// The pre-arrival floor is digital silence: its level is unknown, not low.
    case silentFloor
    case tooFewRepeats
    case inconsistentRepeats
}

enum CalibrationVerdict: Equatable, Sendable {
    case accepted(CalibrationEstimate)
    case rejected(CalibrationRejection)
}

/// Finds the stimulus in a recording by normalised cross-correlation over a bounded lag window.
enum CalibrationDetector {

    /// A recorded sample at or above this is treated as clipped: the delay of a clipped
    /// recording may still be right, but its level is not, and the run was too loud.
    static let clipLevel: Float = 0.99
    static let minimumPeak = 0.5
    /// A second peak at least this fraction of the first makes the delay a guess.
    static let ambiguityRatio = 0.8
    static let minimumSNRdB = 10.0
    /// The window must leave at least this much BEFORE its first lag (and never fewer than
    /// `noiseFrames`): that stretch is the noise floor the SNR is measured against.
    static let noiseFrames = 32
    static let noiseFloorSeconds = 0.01
    static let guardSeconds = 0.001
    /// Inside the guard band, an EARLIER separate peak at least this fraction of the strongest
    /// one means a reflection out-shouted the direct sound.
    static let earlierArrivalRatio = 0.5

    static func minimumFloorFrames(sampleRate: Double) -> Int {
        Swift.max(noiseFrames, Int((noiseFloorSeconds * sampleRate).rounded(.up)))
    }

    /// - Parameters:
    ///   - lagWindow: the lags searched, in frames from the first stimulus sample. The
    ///     recording must cover `lagWindow.upperBound + stimulus.count` frames, and the
    ///     window's first lag must leave `minimumFloorFrames(sampleRate:)` before it.
    static func detect(stimulus: [Float], stimulusRate: Double,
                       recording: [Float], recordingRate: Double,
                       lagWindow: ClosedRange<Int>) -> CalibrationVerdict {
        guard stimulusRate.isFinite, recordingRate.isFinite,
              stimulus.allSatisfy({ $0.isFinite }), recording.allSatisfy({ $0.isFinite }) else {
            return .rejected(.nonFinite)
        }
        guard CalibrationStimulus.sampleRates.contains(stimulusRate), stimulusRate == recordingRate else {
            return .rejected(.rateMismatch)
        }
        let length = stimulus.count
        guard length > 0, lagWindow.lowerBound >= minimumFloorFrames(sampleRate: stimulusRate),
              lagWindow.count >= 3, recording.count - length >= lagWindow.upperBound else {
            return .rejected(.tooShort)
        }
        guard !recording.contains(where: { abs($0) >= clipLevel }) else { return .rejected(.clipped) }

        let stimulusEnergy = stimulus.reduce(0.0) { $0 + Double($1) * Double($1) }
        guard stimulusEnergy > 0 else { return .rejected(.noPeak) }

        var scores = [Double](repeating: 0, count: lagWindow.count)
        for (slot, lag) in lagWindow.enumerated() {
            var dot = 0.0
            var energy = 0.0
            for index in 0..<length {
                let sample = Double(recording[lag + index])
                dot += Double(stimulus[index]) * sample
                energy += sample * sample
            }
            // Absolute value: a speaker or microphone wired in reverse polarity delays the
            // burst just the same.
            scores[slot] = energy > 0 ? abs(dot) / (stimulusEnergy * energy).squareRoot() : 0
        }

        var best = 0
        for slot in 1..<scores.count where scores[slot] > scores[best] { best = slot }
        let peak = scores[best]
        guard peak >= minimumPeak else { return .rejected(.noPeak) }
        guard best > 0, best < scores.count - 1 else { return .rejected(.lagOutOfWindow) }

        let guardFrames = Swift.max(1, Int((guardSeconds * stimulusRate).rounded()))
        var runnerUp = 0.0
        for slot in scores.indices where abs(slot - best) > guardFrames {
            runnerUp = Swift.max(runnerUp, scores[slot])
        }
        guard runnerUp < ambiguityRatio * peak else { return .rejected(.ambiguous) }
        // First arrival, not strongest: a separate local peak EARLIER than the strongest, inside
        // the guard band, is the direct sound losing to a reflection — the strongest lag would be
        // up to 1 ms too late, and every repeat would agree on the wrong number.
        let earliest = Swift.max(1, best - guardFrames)
        if best - 1 > earliest {
            for slot in earliest..<(best - 1)
            where scores[slot] > scores[slot - 1] && scores[slot] >= scores[slot + 1]
                && scores[slot] >= earlierArrivalRatio * peak {
                return .rejected(.ambiguous)
            }
        }

        let bestLag = lagWindow.lowerBound + best
        var noise = 0.0
        for index in 0..<lagWindow.lowerBound { noise += Double(recording[index]) * Double(recording[index]) }
        guard noise > 0 else { return .rejected(.silentFloor) }
        noise /= Double(lagWindow.lowerBound)
        var signal = 0.0
        for index in bestLag..<(bestLag + length) { signal += Double(recording[index]) * Double(recording[index]) }
        signal /= Double(length)
        let snrDB = 10 * log10(signal / noise)
        guard snrDB >= minimumSNRdB else { return .rejected(.lowSNR) }

        // Parabolic interpolation through the peak and its two neighbours.
        let left = scores[best - 1], right = scores[best + 1]
        let curvature = left - 2 * peak + right
        var offset = curvature < 0 ? 0.5 * (left - right) / curvature : 0
        offset = Swift.min(Swift.max(offset, -0.5), 0.5)

        return .accepted(CalibrationEstimate(lagFrames: Double(bestLag) + offset, peak: peak,
                                             runnerUp: runnerUp, snrDB: snrDB))
    }
}

/// The result of several repeats taken together.
struct CalibrationSeries: Equatable, Sendable {
    /// Median of the accepted lags (for an even count, the mean of the middle two).
    let medianLagFrames: Double
    /// Largest minus smallest accepted lag.
    let spreadFrames: Double
    let accepted: Int
    let attempted: Int
    /// The rate the lags were measured at. Frames are converted with THIS rate, never with a
    /// later one — a route change between calibration and report would otherwise shift the
    /// number by the ratio of the two rates (48 → 44.1 kHz is 8.8 %).
    let sampleRate: Double
}

enum CalibrationSeriesVerdict: Equatable, Sendable {
    case accepted(CalibrationSeries)
    case rejected(CalibrationRejection)
}

/// One number from many runs, or a refusal. Repeats that disagree mean something moved — the
/// route, the phone, a person between speaker and microphone — and their median would hide it.
enum CalibrationQualityGate {

    static let minimumAccepted = 5
    /// At least four in five attempts must be accepted.
    static let minimumAcceptedShare = 0.8
    static let maxSpreadSeconds = 0.0005

    static func combine(_ verdicts: [CalibrationVerdict], sampleRate: Double) -> CalibrationSeriesVerdict {
        guard sampleRate.isFinite else { return .rejected(.nonFinite) }
        guard sampleRate > 0 else { return .rejected(.rateMismatch) }
        let lags = verdicts.compactMap { verdict -> Double? in
            if case .accepted(let estimate) = verdict, estimate.lagFrames.isFinite { return estimate.lagFrames }
            return nil
        }.sorted()
        guard lags.count >= minimumAccepted,
              Double(lags.count) >= minimumAcceptedShare * Double(verdicts.count) else {
            return .rejected(.tooFewRepeats)
        }
        guard let lowest = lags.first, let highest = lags.last else { return .rejected(.tooFewRepeats) }
        let spread = highest - lowest
        let tolerance = Swift.max(2, maxSpreadSeconds * sampleRate)
        guard spread <= tolerance else { return .rejected(.inconsistentRepeats) }
        let middle = lags.count / 2
        let median = lags.count % 2 == 1 ? lags[middle] : (lags[middle - 1] + lags[middle]) / 2
        return .accepted(CalibrationSeries(medianLagFrames: median, spreadFrames: spread,
                                           accepted: lags.count, attempted: verdicts.count,
                                           sampleRate: sampleRate))
    }
}

/// Four numbers that must never be confused, side by side, each under its own name.
/// · reported — what the audio session SAYS its latency is: a claim, not a measurement.
/// · acoustic round trip — measured by this core; includes the air path.
/// · network round trip — `LinkLatencySummary`, measured between two phones.
/// · heard end-to-end — NOT measured by anything in this app; printed as UNMEASURED.
struct LatencyBudgetReport: Equatable, Sendable {
    /// Port TYPES joined by ">" (e.g. "Speaker>MicrophoneBuiltIn"). The log keeps only tokens
    /// on `portTypes` — a port NAME can carry a person's name, and the diag log is exported.
    let route: String
    let sampleRate: Double
    let ioBufferFrames: Int
    let reportedMilliseconds: Double?
    let series: CalibrationSeriesVerdict?
    let network: LinkLatencySummary?

    /// Converted with the rate the series was MEASURED at, not with `sampleRate`.
    var acousticRoundTripMilliseconds: Double? {
        guard case .accepted(let accepted)? = series, accepted.sampleRate.isFinite, accepted.sampleRate > 0 else {
            return nil
        }
        return accepted.medianLagFrames / accepted.sampleRate * 1000
    }

    /// The raw values of iOS audio port types. Anything else in a route is logged as "other".
    static let portTypes: Set<String> = [
        "Speaker", "Receiver", "Headphones", "BluetoothA2DPOutput", "BluetoothHFP", "BluetoothLE",
        "HDMIOutput", "LineOut", "LineIn", "AirPlay", "USBAudio", "CarAudio", "MicrophoneBuiltIn",
        "MicrophoneWired", "Virtual", "PCI", "Firewire", "DisplayPort", "AVB", "Thunderbolt",
    ]

    /// The route reduced to known port types: at most four tokens, unknown ones as "other".
    static func sanitised(_ route: String) -> String {
        let tokens = route.split(separator: ">", omittingEmptySubsequences: false).prefix(4)
            .map { portTypes.contains(String($0)) ? String($0) : "other" }
        return route.isEmpty ? "-" : tokens.joined(separator: ">")
    }

    /// One diag-log line. Every number names what it is.
    func logLine() -> String {
        func ms(_ value: Double?) -> String {
            guard let value, value.isFinite else { return "-" }
            return String(format: "%.1f", value)
        }
        let rate = sampleRate.isFinite ? String(format: "%.0f", sampleRate) : "-"
        var line = "calib: route=\(Self.sanitised(route)) sr=\(rate) io=\(ioBufferFrames)"
        line += " reported=\(ms(reportedMilliseconds))ms"
        switch series {
        case .accepted(let accepted)?:
            let spread = accepted.spreadFrames / accepted.sampleRate * 1000
            line += " acousticRoundTrip=\(ms(acousticRoundTripMilliseconds))ms spread=\(ms(spread))ms"
            line += " n=\(accepted.accepted)/\(accepted.attempted) (includes the speaker-to-mic air path)"
            if accepted.sampleRate != sampleRate {
                line += " measuredAt=\(String(format: "%.0f", accepted.sampleRate)) (the rate has changed since)"
            }
        case .rejected(let reason)?:
            line += " acousticRoundTrip=- rejected=\(reason.rawValue)"
        case nil:
            line += " acousticRoundTrip=- (not run)"
        }
        line += " netRTT p50=\(ms(network?.p50)) p95=\(ms(network?.p95))ms"
        line += " heard=UNMEASURED"
        return line
    }
}
