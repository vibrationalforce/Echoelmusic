import Foundation
import Accelerate

/// Intelligent Resonance Suppressor (Priority 3)
///
/// **Inspired by**:
/// - iZotope Ozone Clarity Module (adaptive spectral optimization)
/// - Oeksound Soothe2 (resonance detection + dynamic suppression)
/// - FabFilter Pro-Q 3 Dynamic EQ (frequency-specific compression)
///
/// **Unique Feature**: Bio-Reactive Modulation
/// - High HRV + coherence → gentle, musical suppression (relaxed state)
/// - Low HRV → aggressive clarity enhancement (stressed, needs focus)
/// - Flow state → transparent, intelligent processing
///
/// **Algorithm**:
/// 1. FFT-based spectral analysis (512-2048 bins)
/// 2. Resonance detection via spectral peak tracking
/// 3. Calculate suppression amount based on bio-data
/// 4. Apply multiband dynamic EQ
///
/// **Performance**: SIMD-optimized for real-time use
@MainActor
class IntelligentResonanceSuppressor {

    // MARK: - Configuration

    /// FFT size for spectral analysis
    private let fftSize: Int = 1024

    /// Number of dynamic EQ bands
    private let numBands: Int = 32

    /// Sensitivity (0-1): How aggressively to detect resonances
    var sensitivity: Float = 0.5

    /// Bio-reactivity amount (0-1)
    var bioReactivity: Float = 0.7

    /// Enable/disable bio-reactive processing
    var isBioReactive: Bool = true

    /// Dry/wet mix (0-1)
    var mix: Float = 1.0

    // MARK: - FFT Components

    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length

    /// Split complex buffer for FFT
    private var splitComplex: DSPSplitComplex

    /// Real buffer
    private var realBuffer: [Float]

    /// Imaginary buffer
    private var imagBuffer: [Float]

    /// Magnitude spectrum
    private var magnitudeSpectrum: [Float]

    /// Phase spectrum
    private var phaseSpectrum: [Float]

    // MARK: - Resonance Detection

    /// Detected resonances from previous frame
    private var detectedResonances: [Resonance] = []

    /// Resonance detector state
    private var resonanceDetector: ResonanceDetector

    // MARK: - Dynamic EQ Bands

    /// Array of biquad filters for dynamic EQ
    private var dynamicEQBands: [DynamicEQBand] = []

    /// Filter states for each band
    private var filterStates: [[Float]]

    // MARK: - Sample Rate

    private let sampleRate: Float

    // MARK: - Initialization

    init(sampleRate: Float = 48000, fftSize: Int = 1024) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))

        // Initialize FFT setup
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Allocate FFT buffers
        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudeSpectrum = [Float](repeating: 0, count: fftSize / 2)
        self.phaseSpectrum = [Float](repeating: 0, count: fftSize / 2)

        // Create split complex
        self.splitComplex = DSPSplitComplex(
            realp: UnsafeMutablePointer(&realBuffer),
            imagp: UnsafeMutablePointer(&imagBuffer)
        )

        // Initialize resonance detector
        self.resonanceDetector = ResonanceDetector(
            fftSize: fftSize,
            sampleRate: sampleRate
        )

        // Initialize dynamic EQ bands
        self.filterStates = Array(repeating: [0, 0, 0, 0], count: numBands)
        self.dynamicEQBands = (0..<numBands).map { index in
            let frequency = frequencyForBand(index)
            return DynamicEQBand(
                frequency: frequency,
                q: 4.0,
                maxReduction: -12.0,  // Max 12dB reduction
                attackMs: 5.0,
                releaseMs: 50.0,
                sampleRate: sampleRate
            )
        }

        print("🎛️ Intelligent Resonance Suppressor initialized")
        print("   FFT Size: \(fftSize)")
        print("   Dynamic EQ Bands: \(numBands)")
        print("   Bio-Reactive: \(isBioReactive)")
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Main Processing

    /// Process audio buffer with intelligent resonance suppression
    ///
    /// - Parameters:
    ///   - input: Input audio buffer
    ///   - systemState: Current biosignal state (HRV, coherence, etc.)
    /// - Returns: Processed audio buffer
    func process(_ input: [Float], systemState: EchoelUniversalCore.SystemState) -> [Float] {
        guard input.count >= fftSize else { return input }

        // 1. Analyze spectrum (FFT)
        analyzeSpectrum(input)

        // 2. Detect resonances
        let resonances = resonanceDetector.detect(
            magnitudeSpectrum: magnitudeSpectrum,
            sensitivity: sensitivity
        )
        detectedResonances = resonances

        // 3. Calculate bio-reactive suppression factor
        let suppressionFactor = calculateBioReactiveSuppression(
            hrv: systemState.hrvRMSSD,
            coherence: systemState.hrvCoherence,
            lfHfRatio: systemState.hrvLFHFRatio
        )

        // 4. Update dynamic EQ bands based on resonances
        updateDynamicEQBands(resonances: resonances, suppressionFactor: suppressionFactor)

        // 5. Apply dynamic EQ
        var output = input
        for (index, band) in dynamicEQBands.enumerated() {
            output = band.process(output, state: &filterStates[index])
        }

        // 6. Apply mix
        return applyMix(dry: input, wet: output, mix: mix)
    }

    // MARK: - Spectral Analysis

    /// Perform FFT and extract magnitude spectrum
    private func analyzeSpectrum(_ input: [Float]) {
        guard let fftSetup = fftSetup else { return }

        // Window the input (Hann window)
        var windowed = [Float](repeating: 0, count: fftSize)
        applyHannWindow(input: input, output: &windowed)

        // Convert to split complex format
        windowed.withUnsafeBufferPointer { inputPtr in
            var complexBuffer = DSPSplitComplex(
                realp: &realBuffer,
                imagp: &imagBuffer
            )

            // Pack into split complex (real/imag interleaved → split)
            inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &complexBuffer, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Calculate magnitude spectrum
        vDSP_zvmags(&splitComplex, 1, &magnitudeSpectrum, 1, vDSP_Length(fftSize / 2))

        // Convert to dB
        var ref: Float = 1.0
        vDSP_vdbcon(magnitudeSpectrum, 1, &ref, &magnitudeSpectrum, 1, vDSP_Length(fftSize / 2), 1)
    }

    /// Apply Hann window to input
    private func applyHannWindow(input: [Float], output: inout [Float]) {
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let copyCount = min(input.count, fftSize)
        vDSP_vmul(input, 1, window, 1, &output, 1, vDSP_Length(copyCount))
    }

    // MARK: - Bio-Reactive Modulation (UNIQUE FEATURE)

    /// Calculate suppression factor based on biosignals
    /// This is Echoelmusic's unique differentiator
    ///
    /// - Parameters:
    ///   - hrv: Heart rate variability (RMSSD, ms)
    ///   - coherence: HeartMath coherence score (0-100)
    ///   - lfHfRatio: LF/HF ratio (autonomic balance)
    /// - Returns: Suppression factor (0-1, 0=gentle, 1=aggressive)
    private func calculateBioReactiveSuppression(hrv: Double, coherence: Double, lfHfRatio: Double) -> Float {
        guard isBioReactive else { return 0.5 }  // Default if not bio-reactive

        // Normalize inputs
        let hrvNormalized = Float(min(hrv / 100.0, 1.0))  // 0-100ms → 0-1
        let coherenceNormalized = Float(coherence / 100.0)  // 0-100 → 0-1
        let stressLevel = Float(min(lfHfRatio / 5.0, 1.0))  // 0-5 → 0-1

        // Algorithm:
        // High HRV + high coherence = relaxed → gentle suppression (0.2-0.4)
        // Low HRV + low coherence = stressed → aggressive suppression (0.6-0.9)
        // High LF/HF ratio = stressed → more aggressive

        let relaxationFactor = (hrvNormalized + coherenceNormalized) / 2.0
        let suppressionAmount = 0.9 - (relaxationFactor * 0.7)  // Inverted: relaxed = less suppression

        // Modulate by stress level (LF/HF ratio)
        let finalSuppression = suppressionAmount * (0.5 + stressLevel * 0.5)

        // Apply bio-reactivity blend
        return finalSuppression * bioReactivity + 0.5 * (1.0 - bioReactivity)
    }

    // MARK: - Dynamic EQ Management

    /// Update dynamic EQ bands based on detected resonances
    private func updateDynamicEQBands(resonances: [Resonance], suppressionFactor: Float) {
        // Reset all bands
        for band in dynamicEQBands {
            band.currentGainReduction = 0.0
        }

        // Map resonances to nearest EQ bands
        for resonance in resonances {
            let bandIndex = bandIndexForFrequency(resonance.frequency)
            guard bandIndex < dynamicEQBands.count else { continue }

            let band = dynamicEQBands[bandIndex]

            // Calculate gain reduction based on resonance strength and bio-reactive factor
            let targetReduction = -resonance.strength * 12.0 * suppressionFactor  // Up to -12dB
            band.targetGainReduction = targetReduction
        }
    }

    /// Get frequency for EQ band index (logarithmic distribution)
    private func frequencyForBand(_ index: Int) -> Float {
        let minFreq: Float = 100.0  // 100 Hz
        let maxFreq: Float = 16000.0  // 16 kHz
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = logMin + (logMax - logMin) * Float(index) / Float(numBands - 1)
        return pow(10.0, logFreq)
    }

    /// Get band index for frequency
    private func bandIndexForFrequency(_ frequency: Float) -> Int {
        let minFreq: Float = 100.0
        let maxFreq: Float = 16000.0
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = log10(max(min(frequency, maxFreq), minFreq))
        let normalized = (logFreq - logMin) / (logMax - logMin)
        return Int(normalized * Float(numBands - 1))
    }

    // MARK: - Mix

    /// Apply dry/wet mix using SIMD
    private func applyMix(dry: [Float], wet: [Float], mix: Float) -> [Float] {
        return SIMDHelpers.mixBuffersSIMD(dry, gain1: 1.0 - mix, wet, gain2: mix)
    }

    // MARK: - Analysis

    /// Get current resonances for visualization
    func getCurrentResonances() -> [Resonance] {
        return detectedResonances
    }

    /// Get magnitude spectrum for visualization
    func getMagnitudeSpectrum() -> [Float] {
        return magnitudeSpectrum
    }
}

// MARK: - Supporting Structures

/// Detected resonance
struct Resonance {
    let frequency: Float  // Hz
    let strength: Float   // 0-1
    let bandwidth: Float  // Hz
}

/// Resonance detector (spectral peak tracking)
class ResonanceDetector {
    private let fftSize: Int
    private let sampleRate: Float
    private var previousSpectrum: [Float]

    init(fftSize: Int, sampleRate: Float) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.previousSpectrum = [Float](repeating: 0, count: fftSize / 2)
    }

    /// Detect resonances from magnitude spectrum
    func detect(magnitudeSpectrum: [Float], sensitivity: Float) -> [Resonance] {
        var resonances: [Resonance] = []

        // Find spectral peaks
        let threshold = -20.0 + (sensitivity * 20.0)  // -20dB to 0dB threshold

        for i in 2..<(magnitudeSpectrum.count - 2) {
            let current = magnitudeSpectrum[i]

            // Check if local maximum
            if current > magnitudeSpectrum[i - 1] &&
               current > magnitudeSpectrum[i + 1] &&
               current > threshold {

                // Check for excessive narrowband energy (resonance indicator)
                let leftSlope = current - magnitudeSpectrum[i - 1]
                let rightSlope = current - magnitudeSpectrum[i + 1]

                if leftSlope > 6.0 && rightSlope > 6.0 {  // Sharp peak (>6dB/bin)
                    let frequency = Float(i) * sampleRate / Float(fftSize)
                    let strength = min((current - threshold) / 20.0, 1.0)
                    let bandwidth = estimateBandwidth(spectrum: magnitudeSpectrum, peakIndex: i)

                    resonances.append(Resonance(
                        frequency: frequency,
                        strength: strength,
                        bandwidth: bandwidth
                    ))
                }
            }
        }

        // Limit to top 8 resonances (performance)
        resonances.sort { $0.strength > $1.strength }
        return Array(resonances.prefix(8))
    }

    private func estimateBandwidth(spectrum: [Float], peakIndex: Int) -> Float {
        let peakLevel = spectrum[peakIndex]
        let halfPowerLevel = peakLevel - 3.0  // -3dB points

        // Find left -3dB point
        var leftIndex = peakIndex
        while leftIndex > 0 && spectrum[leftIndex] > halfPowerLevel {
            leftIndex -= 1
        }

        // Find right -3dB point
        var rightIndex = peakIndex
        while rightIndex < spectrum.count - 1 && spectrum[rightIndex] > halfPowerLevel {
            rightIndex += 1
        }

        let bandwidthBins = Float(rightIndex - leftIndex)
        return bandwidthBins * sampleRate / Float(fftSize)
    }
}

/// Dynamic EQ band (like Soothe2)
class DynamicEQBand {
    let frequency: Float
    let q: Float
    let maxReduction: Float
    let attackCoeff: Float
    let releaseCoeff: Float
    let sampleRate: Float

    var targetGainReduction: Float = 0.0
    var currentGainReduction: Float = 0.0

    init(frequency: Float, q: Float, maxReduction: Float,
         attackMs: Float, releaseMs: Float, sampleRate: Float) {
        self.frequency = frequency
        self.q = q
        self.maxReduction = maxReduction
        self.sampleRate = sampleRate

        // Calculate coefficients
        self.attackCoeff = exp(-1000.0 / (attackMs * sampleRate))
        self.releaseCoeff = exp(-1000.0 / (releaseMs * sampleRate))
    }

    /// Process audio with dynamic EQ
    func process(_ input: [Float], state: inout [Float]) -> [Float] {
        // Smooth gain changes (attack/release)
        if targetGainReduction < currentGainReduction {
            // Attack
            currentGainReduction = attackCoeff * currentGainReduction + (1.0 - attackCoeff) * targetGainReduction
        } else {
            // Release
            currentGainReduction = releaseCoeff * currentGainReduction + (1.0 - releaseCoeff) * targetGainReduction
        }

        // Skip if no reduction
        guard abs(currentGainReduction) > 0.1 else { return input }

        // Calculate biquad coefficients for peak filter
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = pow(10.0, currentGainReduction / 40.0)

        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cosOmega
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha / A

        // Apply biquad filter
        let coeff = BiquadCoefficients(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)
        var states = [state]
        return SIMDHelpers.applyBiquadsSIMD(input, coefficients: [coeff], state: &states)
    }
}
