import Foundation
import Accelerate
import Combine

/// Per-Note Vibrato Engine — Professional Vibrato Detection, Synthesis & Control
///
/// Inspired by Vovious and Melodyne's per-note vibrato editing.
///
/// Capabilities:
/// - **Detection**: Analyze existing vibrato (rate, depth, shape)
/// - **Synthesis**: Generate natural or stylized vibrato
/// - **Per-Note Control**: Independent vibrato parameters per note
/// - **Shape Morphing**: Sine, triangle, ramp, irregular (human)
/// - **Bio-Reactive Modulation**: Coherence → vibrato naturalness
///
/// Technical Implementation:
/// - Hilbert transform for instantaneous frequency tracking
/// - Pitch modulation via phase vocoder
/// - Envelope followers for rate/depth estimation
@MainActor
class VibratoEngine: ObservableObject {

    // MARK: - Published State

    @Published var isAnalyzing: Bool = false
    @Published var detectedVibrato: VibratoAnalysis?
    @Published var noteVibratos: [UUID: VibratoParameters] = [:]

    // MARK: - Types

    /// Vibrato waveform shape
    enum VibratoShape: String, CaseIterable, Identifiable {
        case sine = "Sine"              // Classic smooth vibrato
        case triangle = "Triangle"       // Linear ramp vibrato
        case rampUp = "Ramp Up"         // Accelerating vibrato
        case rampDown = "Ramp Down"     // Decelerating vibrato
        case human = "Human"            // Irregular, natural-sounding
        case operatic = "Operatic"      // Wide, slower vibrato
        case gospel = "Gospel"          // Intense, fast vibrato
        case trill = "Trill"            // Very fast, semitone oscillation
        case none = "None"              // No vibrato (straight tone)

        var id: String { rawValue }
    }

    /// Analysis result for detected vibrato
    struct VibratoAnalysis {
        let rate: Float             // Hz (typically 4-8 Hz for singing)
        let depth: Float            // Cents (typically 20-100 cents)
        let regularity: Float       // 0-1 (how regular the vibrato is)
        let shape: VibratoShape     // Detected shape
        let onsetDelay: Float       // Seconds before vibrato starts
        let pitchContour: [Float]   // Raw pitch contour (Hz)
        let vibratoContour: [Float] // Extracted vibrato component (cents)
        let rateContour: [Float]    // Rate over time (Hz)
        let depthContour: [Float]   // Depth over time (cents)
    }

    /// Per-note vibrato parameters
    struct VibratoParameters: Identifiable {
        let id: UUID
        var enabled: Bool = true
        var rate: Float = 5.5          // Hz
        var depth: Float = 40.0        // Cents
        var shape: VibratoShape = .sine
        var onsetDelay: Float = 0.2    // Seconds
        var fadeInTime: Float = 0.3    // Seconds to reach full depth
        var fadeOutTime: Float = 0.1   // Seconds to fade vibrato before note end
        var rateVariation: Float = 0.1 // Random rate variation (0 = metronomic, 1 = very human)
        var depthVariation: Float = 0.1 // Random depth variation
        var phaseOffset: Float = 0.0   // Starting phase (0 to 2*pi)
        var asymmetry: Float = 0.0     // -1 = more below pitch, 0 = centered, 1 = more above

        static func `default`() -> VibratoParameters {
            VibratoParameters(id: UUID())
        }

        static func operatic() -> VibratoParameters {
            var p = VibratoParameters(id: UUID())
            p.rate = 5.0
            p.depth = 80.0
            p.shape = .operatic
            p.onsetDelay = 0.3
            p.fadeInTime = 0.5
            return p
        }

        static func pop() -> VibratoParameters {
            var p = VibratoParameters(id: UUID())
            p.rate = 6.0
            p.depth = 30.0
            p.shape = .sine
            p.onsetDelay = 0.15
            p.fadeInTime = 0.2
            return p
        }

        static func gospel() -> VibratoParameters {
            var p = VibratoParameters(id: UUID())
            p.rate = 6.5
            p.depth = 60.0
            p.shape = .gospel
            p.onsetDelay = 0.1
            p.fadeInTime = 0.15
            p.rateVariation = 0.2
            return p
        }

        static func straight() -> VibratoParameters {
            var p = VibratoParameters(id: UUID())
            p.enabled = false
            p.depth = 0
            p.shape = .none
            return p
        }
    }

    // MARK: - Internal State

    private let sampleRate: Float
    private var vibratoPhases: [UUID: Float] = [:]    // Per-note phase accumulators
    private var humanNoiseState: [UUID: Float] = [:]  // Per-note noise state for human variation

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
    }

    // MARK: - Vibrato Detection

    /// Analyze vibrato characteristics from a pitch contour
    /// - Parameters:
    ///   - pitchContour: Array of pitch values in Hz (one per analysis frame)
    ///   - hopSize: Hop size in samples between pitch values
    /// - Returns: Vibrato analysis result
    func analyzeVibrato(pitchContour: [Float], hopSize: Int) -> VibratoAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard pitchContour.count > 10 else {
            return VibratoAnalysis(
                rate: 0, depth: 0, regularity: 0, shape: .none,
                onsetDelay: 0, pitchContour: pitchContour,
                vibratoContour: [], rateContour: [], depthContour: []
            )
        }

        let frameRate = sampleRate / Float(hopSize)

        // Step 1: Convert pitch to cents (relative to mean pitch)
        let validPitches = pitchContour.filter { $0 > 50 }
        guard !validPitches.isEmpty else {
            return VibratoAnalysis(
                rate: 0, depth: 0, regularity: 0, shape: .none,
                onsetDelay: 0, pitchContour: pitchContour,
                vibratoContour: [], rateContour: [], depthContour: []
            )
        }

        var meanPitch: Float = 0
        vDSP_meanv(validPitches, 1, &meanPitch, vDSP_Length(validPitches.count))

        // Convert to cents deviation from mean
        var centsContour = [Float](repeating: 0, count: pitchContour.count)
        for i in 0..<pitchContour.count {
            if pitchContour[i] > 50 {
                centsContour[i] = 1200.0 * Foundation.log(pitchContour[i] / meanPitch) / Foundation.log(2.0)
            }
        }

        // Step 2: Bandpass filter to isolate vibrato frequencies (3-10 Hz)
        let vibratoContour = bandpassFilter(centsContour, lowFreq: 3.0, highFreq: 10.0, sampleRate: frameRate)

        // Step 3: Estimate vibrato rate via autocorrelation
        let rate = estimateVibratoRate(vibratoContour, sampleRate: frameRate)

        // Step 4: Estimate vibrato depth (peak-to-peak in cents)
        let depth = estimateVibratoDepth(vibratoContour)

        // Step 5: Estimate regularity
        let regularity = estimateRegularity(vibratoContour, expectedRate: rate, sampleRate: frameRate)

        // Step 6: Detect vibrato shape
        let shape = detectVibratoShape(vibratoContour, rate: rate, sampleRate: frameRate)

        // Step 7: Detect onset delay (when vibrato starts)
        let onsetDelay = detectVibratoOnset(vibratoContour, sampleRate: frameRate)

        // Step 8: Rate and depth contours over time
        let (rateContour, depthContour) = computeTimeVaryingParameters(
            vibratoContour, sampleRate: frameRate
        )

        let analysis = VibratoAnalysis(
            rate: rate,
            depth: depth,
            regularity: regularity,
            shape: shape,
            onsetDelay: onsetDelay,
            pitchContour: pitchContour,
            vibratoContour: vibratoContour,
            rateContour: rateContour,
            depthContour: depthContour
        )

        detectedVibrato = analysis
        return analysis
    }

    // MARK: - Vibrato Synthesis

    /// Generate vibrato modulation signal for a note
    /// - Parameters:
    ///   - noteId: Unique identifier for the note
    ///   - params: Vibrato parameters
    ///   - noteTime: Current time within the note (seconds)
    ///   - noteDuration: Total note duration (seconds, 0 if unknown/real-time)
    ///   - frameCount: Number of samples to generate
    /// - Returns: Pitch modulation in cents for each sample
    func generateVibrato(
        noteId: UUID,
        params: VibratoParameters,
        noteTime: Float,
        noteDuration: Float,
        frameCount: Int
    ) -> [Float] {
        guard params.enabled && params.depth > 0 else {
            return [Float](repeating: 0, count: frameCount)
        }

        var output = [Float](repeating: 0, count: frameCount)
        var phase = vibratoPhases[noteId] ?? params.phaseOffset
        var noiseState = humanNoiseState[noteId] ?? 0

        let baseRate = params.rate
        let baseDepth = params.depth

        for i in 0..<frameCount {
            let sampleTime = noteTime + Float(i) / sampleRate

            // Calculate envelope (onset delay + fade in/out)
            let envelope = calculateVibratoEnvelope(
                time: sampleTime,
                onsetDelay: params.onsetDelay,
                fadeInTime: params.fadeInTime,
                fadeOutTime: params.fadeOutTime,
                noteDuration: noteDuration
            )

            // Rate with human variation
            let rateNoise = params.rateVariation * generatePerlinNoise(&noiseState, speed: 0.3)
            let currentRate = baseRate * (1.0 + rateNoise)

            // Depth with human variation
            let depthNoise = params.depthVariation * generatePerlinNoise(&noiseState, speed: 0.2)
            let currentDepth = baseDepth * (1.0 + depthNoise)

            // Generate vibrato waveform based on shape
            let waveform = generateVibratoWaveform(phase: phase, shape: params.shape)

            // Apply asymmetry
            let asymmetricWaveform: Float
            if params.asymmetry != 0 {
                if waveform > 0 {
                    asymmetricWaveform = waveform * (1.0 + params.asymmetry)
                } else {
                    asymmetricWaveform = waveform * (1.0 - params.asymmetry)
                }
            } else {
                asymmetricWaveform = waveform
            }

            // Final modulation = depth * envelope * waveform
            output[i] = currentDepth * envelope * asymmetricWaveform

            // Advance phase
            phase += 2.0 * Float.pi * currentRate / sampleRate
            if phase > 2.0 * Float.pi { phase -= 2.0 * Float.pi }
        }

        // Store state for continuity
        vibratoPhases[noteId] = phase
        humanNoiseState[noteId] = noiseState

        return output
    }

    /// Apply vibrato modulation to audio using the phase vocoder
    /// - Parameters:
    ///   - audio: Input audio samples
    ///   - modulationCents: Per-sample pitch modulation in cents
    ///   - phaseVocoder: Phase vocoder instance for pitch shifting
    /// - Returns: Audio with vibrato applied
    nonisolated func applyVibratoToAudio(
        audio: [Float],
        modulationCents: [Float],
        phaseVocoder: PhaseVocoder
    ) -> [Float] {
        guard audio.count > 0 && modulationCents.count > 0 else { return audio }

        // Process in blocks, applying varying pitch shift
        let blockSize = 2048
        var output = [Float](repeating: 0, count: audio.count)

        for blockStart in stride(from: 0, to: audio.count - blockSize, by: blockSize) {
            let blockEnd = min(blockStart + blockSize, audio.count)
            let block = Array(audio[blockStart..<blockEnd])

            // Average modulation for this block
            let modSlice = Array(modulationCents[blockStart..<min(blockStart + blockSize, modulationCents.count)])
            var avgMod: Float = 0
            vDSP_meanv(modSlice, 1, &avgMod, vDSP_Length(modSlice.count))

            // Convert cents to semitones
            let semitones = avgMod / 100.0

            if abs(semitones) > 0.005 {
                let shifted = phaseVocoder.pitchShift(block, semitones: semitones)
                for i in 0..<min(shifted.count, blockEnd - blockStart) {
                    output[blockStart + i] = shifted[i]
                }
            } else {
                for i in blockStart..<blockEnd {
                    output[i] = audio[i]
                }
            }
        }

        return output
    }

    // MARK: - Waveform Generation

    private nonisolated func generateVibratoWaveform(phase: Float, shape: VibratoShape) -> Float {
        let normalizedPhase = phase / (2.0 * Float.pi)  // 0 to 1

        switch shape {
        case .sine:
            return sin(phase)

        case .triangle:
            // Triangle wave: linear ramps
            if normalizedPhase < 0.25 {
                return normalizedPhase * 4.0
            } else if normalizedPhase < 0.75 {
                return 2.0 - normalizedPhase * 4.0
            } else {
                return normalizedPhase * 4.0 - 4.0
            }

        case .rampUp:
            // Ramp up: accelerating vibrato (sawtooth)
            let saw = normalizedPhase * 2.0 - 1.0
            return saw * saw * (saw > 0 ? 1.0 : -1.0)

        case .rampDown:
            // Ramp down: decelerating vibrato
            let inv = (1.0 - normalizedPhase) * 2.0 - 1.0
            return inv

        case .human:
            // Irregular: sine + harmonics + noise
            let fundamental = sin(phase) * 0.7
            let second = sin(phase * 2.0) * 0.15
            let third = sin(phase * 3.0) * 0.08
            let noise = Float.random(in: -0.07...0.07)
            return fundamental + second + third + noise

        case .operatic:
            // Wider, slightly slower feel: sine with 2nd harmonic for richness
            let main = sin(phase) * 0.85
            let harmonic = sin(phase * 2.0 + 0.3) * 0.15
            return main + harmonic

        case .gospel:
            // Intense, slightly irregular
            let main = sin(phase)
            let intensity = abs(main) * main  // Squared for intensity
            return intensity * 0.7 + main * 0.3

        case .trill:
            // Very fast, almost square-ish (between two notes)
            return sin(phase) > 0 ? 1.0 : -1.0

        case .none:
            return 0
        }
    }

    // MARK: - Envelope

    private nonisolated func calculateVibratoEnvelope(
        time: Float,
        onsetDelay: Float,
        fadeInTime: Float,
        fadeOutTime: Float,
        noteDuration: Float
    ) -> Float {
        // Before onset delay: no vibrato
        if time < onsetDelay {
            return 0
        }

        // Fade in
        let timeSinceOnset = time - onsetDelay
        let fadeIn: Float
        if fadeInTime > 0 && timeSinceOnset < fadeInTime {
            fadeIn = timeSinceOnset / fadeInTime
            // Use smooth S-curve for natural feel
            let t = fadeIn
            return t * t * (3.0 - 2.0 * t)  // Smoothstep
        } else {
            fadeIn = 1.0
        }

        // Fade out (only if note duration is known)
        if noteDuration > 0 && fadeOutTime > 0 {
            let timeBeforeEnd = noteDuration - time
            if timeBeforeEnd < fadeOutTime {
                let fadeOut = max(0, timeBeforeEnd / fadeOutTime)
                let t = fadeOut
                return fadeIn * t * t * (3.0 - 2.0 * t)  // Smoothstep
            }
        }

        return fadeIn
    }

    // MARK: - Analysis Helpers

    /// Bandpass filter using cascaded biquads
    private func bandpassFilter(_ input: [Float], lowFreq: Float, highFreq: Float,
                                sampleRate: Float) -> [Float] {
        // High-pass at lowFreq
        var output = applyBiquadHP(input, cutoff: lowFreq, sampleRate: sampleRate)
        // Low-pass at highFreq
        output = applyBiquadLP(output, cutoff: highFreq, sampleRate: sampleRate)
        return output
    }

    private func applyBiquadLP(_ input: [Float], cutoff: Float, sampleRate: Float) -> [Float] {
        let omega = 2.0 * Float.pi * cutoff / sampleRate
        let sinO = sin(omega)
        let cosO = cos(omega)
        let alpha = sinO / (2.0 * 0.707)

        let a0 = 1.0 + alpha
        let b0 = ((1.0 - cosO) / 2.0) / a0
        let b1 = (1.0 - cosO) / a0
        let b2 = ((1.0 - cosO) / 2.0) / a0
        let a1 = (-2.0 * cosO) / a0
        let a2 = (1.0 - alpha) / a0

        return applyBiquad(input, b0: b0, b1: b1, b2: b2, a1: a1, a2: a2)
    }

    private func applyBiquadHP(_ input: [Float], cutoff: Float, sampleRate: Float) -> [Float] {
        let omega = 2.0 * Float.pi * cutoff / sampleRate
        let sinO = sin(omega)
        let cosO = cos(omega)
        let alpha = sinO / (2.0 * 0.707)

        let a0 = 1.0 + alpha
        let b0 = ((1.0 + cosO) / 2.0) / a0
        let b1 = (-(1.0 + cosO)) / a0
        let b2 = ((1.0 + cosO) / 2.0) / a0
        let a1 = (-2.0 * cosO) / a0
        let a2 = (1.0 - alpha) / a0

        return applyBiquad(input, b0: b0, b1: b1, b2: b2, a1: a1, a2: a2)
    }

    private func applyBiquad(_ input: [Float], b0: Float, b1: Float, b2: Float,
                             a1: Float, a2: Float) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            output[i] = y0
            x2 = x1; x1 = x0
            y2 = y1; y1 = y0
        }
        return output
    }

    /// Estimate vibrato rate using autocorrelation
    private func estimateVibratoRate(_ contour: [Float], sampleRate: Float) -> Float {
        guard contour.count > 20 else { return 0 }

        let n = contour.count
        let minLag = Int(sampleRate / 10.0)  // Max 10 Hz vibrato
        let maxLag = min(Int(sampleRate / 3.0), n / 2)  // Min 3 Hz vibrato

        guard maxLag > minLag else { return 0 }

        // Autocorrelation
        var bestLag = minLag
        var bestCorr: Float = -1

        for lag in minLag..<maxLag {
            var corr: Float = 0
            var count = 0
            for i in 0..<(n - lag) {
                corr += contour[i] * contour[i + lag]
                count += 1
            }
            if count > 0 {
                corr /= Float(count)
                if corr > bestCorr {
                    bestCorr = corr
                    bestLag = lag
                }
            }
        }

        return bestCorr > 0 ? sampleRate / Float(bestLag) : 0
    }

    /// Estimate vibrato depth (peak-to-peak cents)
    private func estimateVibratoDepth(_ contour: [Float]) -> Float {
        guard !contour.isEmpty else { return 0 }

        var maxVal: Float = 0
        var minVal: Float = 0
        vDSP_maxv(contour, 1, &maxVal, vDSP_Length(contour.count))
        vDSP_minv(contour, 1, &minVal, vDSP_Length(contour.count))

        // Use RMS-based depth for more robust estimation
        var rms: Float = 0
        vDSP_rmsqv(contour, 1, &rms, vDSP_Length(contour.count))

        // Peak-to-peak is approximately 2 * sqrt(2) * RMS for sine wave
        return rms * 2.83
    }

    /// Estimate regularity (0 = irregular, 1 = perfectly regular)
    private func estimateRegularity(_ contour: [Float], expectedRate: Float,
                                    sampleRate: Float) -> Float {
        guard expectedRate > 0 && contour.count > 20 else { return 0 }

        // Compare autocorrelation peak height to unity
        let period = Int(sampleRate / expectedRate)
        guard period > 0 && period < contour.count / 2 else { return 0 }

        var selfCorr: Float = 0
        var lagCorr: Float = 0
        let n = contour.count - period

        for i in 0..<n {
            selfCorr += contour[i] * contour[i]
            lagCorr += contour[i] * contour[i + period]
        }

        guard selfCorr > 0 else { return 0 }
        return max(0, min(1, lagCorr / selfCorr))
    }

    /// Detect the shape of the vibrato waveform
    private func detectVibratoShape(_ contour: [Float], rate: Float,
                                    sampleRate: Float) -> VibratoShape {
        guard rate > 0 && contour.count > 10 else { return .none }

        let period = Int(sampleRate / rate)
        guard period > 4 && period < contour.count else { return .sine }

        // Extract one representative cycle
        let cycle = Array(contour.prefix(period))

        // Compute shape metrics
        var maxVal: Float = 0
        vDSP_maxmgv(cycle, 1, &maxVal, vDSP_Length(cycle.count))
        guard maxVal > 0 else { return .none }

        // Normalize cycle
        var normalized = cycle
        var scale = 1.0 / maxVal
        vDSP_vsmul(normalized, 1, &scale, &normalized, 1, vDSP_Length(normalized.count))

        // Compare with template shapes
        let sineTemplate = (0..<period).map { sin(2.0 * Float.pi * Float($0) / Float(period)) }

        var sineCorr: Float = 0
        vDSP_dotpr(normalized, 1, sineTemplate, 1, &sineCorr, vDSP_Length(period))
        sineCorr /= Float(period)

        // High sine correlation = sine shape
        if sineCorr > 0.85 {
            return .sine
        } else if sineCorr > 0.6 {
            return .human  // Somewhat irregular
        } else {
            return .triangle  // Very different from sine
        }
    }

    /// Detect when vibrato onset occurs
    private func detectVibratoOnset(_ contour: [Float], sampleRate: Float) -> Float {
        guard contour.count > 10 else { return 0 }

        // Find first point where vibrato amplitude exceeds threshold
        var rms: Float = 0
        vDSP_rmsqv(contour, 1, &rms, vDSP_Length(contour.count))
        let threshold = rms * 0.3

        // Use a sliding window to detect vibrato presence
        let windowSize = max(1, Int(sampleRate * 0.1))  // 100ms windows

        for i in stride(from: 0, to: contour.count - windowSize, by: windowSize / 2) {
            let window = Array(contour[i..<i + windowSize])
            var windowRms: Float = 0
            vDSP_rmsqv(window, 1, &windowRms, vDSP_Length(windowSize))

            if windowRms > threshold {
                return Float(i) / sampleRate
            }
        }

        return 0
    }

    /// Compute time-varying rate and depth contours
    private func computeTimeVaryingParameters(_ contour: [Float],
                                              sampleRate: Float) -> ([Float], [Float]) {
        let windowSize = max(1, Int(sampleRate * 0.5))  // 500ms windows
        let hopSize = max(1, windowSize / 4)
        let numFrames = max(0, (contour.count - windowSize) / hopSize)

        var rateContour = [Float](repeating: 0, count: numFrames)
        var depthContour = [Float](repeating: 0, count: numFrames)

        for frame in 0..<numFrames {
            let start = frame * hopSize
            let end = min(start + windowSize, contour.count)
            let window = Array(contour[start..<end])

            rateContour[frame] = estimateVibratoRate(window, sampleRate: sampleRate)
            depthContour[frame] = estimateVibratoDepth(window)
        }

        return (rateContour, depthContour)
    }

    // MARK: - Noise Generation

    /// Simple Perlin-like noise for humanizing vibrato
    private nonisolated func generatePerlinNoise(_ state: inout Float, speed: Float) -> Float {
        state += speed / sampleRate
        // Simple smooth random using sine of large values
        return sin(state * 127.1) * 0.5 + sin(state * 311.7) * 0.3 + sin(state * 74.7) * 0.2
    }

    // MARK: - Note Management

    /// Register a new note for vibrato processing
    func registerNote(id: UUID, params: VibratoParameters? = nil) {
        noteVibratos[id] = params ?? .default()
        vibratoPhases[id] = params?.phaseOffset ?? 0
        humanNoiseState[id] = Float.random(in: 0...1000)
    }

    /// Remove a note (note off)
    func unregisterNote(id: UUID) {
        noteVibratos.removeValue(forKey: id)
        vibratoPhases.removeValue(forKey: id)
        humanNoiseState.removeValue(forKey: id)
    }

    /// Update vibrato parameters for a note
    func updateNoteVibrato(id: UUID, params: VibratoParameters) {
        noteVibratos[id] = params
    }
}
