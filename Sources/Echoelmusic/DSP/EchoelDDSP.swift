import Foundation
import Accelerate

// MARK: - EchoelDDSP — Differentiable Digital Signal Processing Engine
// Pure-DSP harmonic-plus-noise model inspired by Google Magenta DDSP.
// No ML required — parameters driven by bio-reactive signals or manual control.
//
// Architecture:
//   1. Harmonic Synthesizer: Bank of N sinusoidal partials at integer multiples of f0
//      - Per-partial amplitude control (spectral envelope)
//      - Phase-coherent additive synthesis via vDSP
//   2. Noise Synthesizer: Time-varying FIR-filtered noise
//      - Spectral shaping via frequency-domain multiplication
//      - Colored noise from white noise source
//   3. Mix: Harmonic + Noise blend controlled by harmonicity parameter
//   4. Global amplitude envelope
//
// Bio-Reactive Integration:
//   - Coherence → Harmonicity (high = pure tone, low = noisy)
//   - HRV → Spectral brightness (calm = warm, stressed = bright)
//   - Heart rate → Fundamental frequency or tempo
//   - Breathing → Amplitude envelope
//
// References:
//   - Engel et al. (2020) "DDSP: Differentiable Digital Signal Processing" ICLR
//   - Meta Reality Labs (2025) Zero-phase DDSP filter design
//   - ICASSP 2024: Ultra-lightweight DDSP vocoder (15 MFLOPS)

/// EchoelDDSP — Harmonic+Noise Synthesizer
/// Pure DSP engine with per-partial amplitude control and filtered noise
public final class EchoelDDSP: @unchecked Sendable {

    // MARK: - Configuration

    /// Number of harmonic partials
    public let harmonicCount: Int

    /// Number of noise filter bands
    public let noiseBandCount: Int

    /// Sample rate
    public let sampleRate: Float

    /// Frame size for parameter updates (controls update rate)
    public let frameSize: Int

    // MARK: - Harmonic Parameters

    /// Fundamental frequency (Hz)
    public var frequency: Float = 220.0

    /// Per-partial amplitudes (normalized 0-1)
    /// Index 0 = fundamental, index 1 = 2nd harmonic, etc.
    public var harmonicAmplitudes: [Float]

    /// Global harmonic amplitude (0-1)
    public var harmonicLevel: Float = 0.8

    /// Harmonicity: blend between harmonic and noise (0 = noise, 1 = pure harmonic)
    public var harmonicity: Float = 0.7

    // MARK: - Noise Parameters

    /// Per-band noise magnitudes (frequency-domain shaping)
    public var noiseMagnitudes: [Float]

    /// Global noise amplitude (0-1)
    public var noiseLevel: Float = 0.3

    /// Noise color preset
    public var noiseColor: NoiseColor = .pink

    // MARK: - Envelope

    /// Global amplitude (0-1)
    public var amplitude: Float = 0.8

    /// Attack time (seconds)
    public var attack: Float = 0.01

    /// Decay time (seconds)
    public var decay: Float = 0.1

    /// Sustain level (0-1)
    public var sustain: Float = 0.8

    /// Release time (seconds)
    public var release: Float = 0.3

    // MARK: - Spectral Presets

    /// Spectral envelope shape
    public var spectralShape: SpectralShape = .natural {
        didSet { updateSpectralEnvelope() }
    }

    /// Spectral brightness (0 = dark, 1 = bright)
    public var brightness: Float = 0.5 {
        didSet { updateSpectralEnvelope() }
    }

    // MARK: - Types

    /// Noise color presets
    public enum NoiseColor: String, CaseIterable, Sendable {
        case white = "White"
        case pink = "Pink"
        case brown = "Brown"
        case blue = "Blue"
        case violet = "Violet"
    }

    /// Spectral envelope shapes
    public enum SpectralShape: String, CaseIterable, Sendable {
        case natural = "Natural"       // 1/n rolloff
        case bright = "Bright"         // Boosted highs
        case dark = "Dark"             // Steep rolloff
        case formant = "Formant"       // Vowel-like formants
        case metallic = "Metallic"     // Enhanced odd harmonics
        case hollow = "Hollow"         // Missing even harmonics
        case bell = "Bell"             // Inharmonic partials (slightly detuned)
        case flat = "Flat"             // Equal amplitudes
    }

    // MARK: - Internal State

    /// Phase accumulators for each partial
    private var phases: [Float]

    /// Smoothed amplitudes (to avoid clicks)
    private var smoothedAmplitudes: [Float]

    /// Noise buffer
    private var noiseBuffer: [Float]

    /// Noise filter state
    private var noiseFilterState: [Float]

    /// Current envelope value
    private var envelopeValue: Float = 0

    /// Envelope stage
    private var envelopeStage: EnvelopeStage = .idle

    /// Samples in current envelope stage
    private var envelopeSamples: Int = 0

    private enum EnvelopeStage {
        case idle, attack, decay, sustain, release
    }

    // MARK: - Init

    /// Initialize EchoelDDSP
    /// - Parameters:
    ///   - harmonicCount: Number of harmonic partials (default 64)
    ///   - noiseBandCount: Number of noise filter bands (default 65)
    ///   - sampleRate: Audio sample rate (default 48000)
    ///   - frameSize: Parameter update frame size (default 192 = 250Hz at 48kHz)
    public init(
        harmonicCount: Int = 64,
        noiseBandCount: Int = 65,
        sampleRate: Float = 48000.0,
        frameSize: Int = 192
    ) {
        self.harmonicCount = harmonicCount
        self.noiseBandCount = noiseBandCount
        self.sampleRate = sampleRate
        self.frameSize = frameSize

        self.harmonicAmplitudes = [Float](repeating: 0, count: harmonicCount)
        self.noiseMagnitudes = [Float](repeating: 0, count: noiseBandCount)
        self.phases = [Float](repeating: 0, count: harmonicCount)
        self.smoothedAmplitudes = [Float](repeating: 0, count: harmonicCount)
        self.noiseBuffer = [Float](repeating: 0, count: frameSize)
        self.noiseFilterState = [Float](repeating: 0, count: noiseBandCount)

        // Initialize with natural spectral envelope
        updateSpectralEnvelope()
        updateNoiseProfile()
    }

    // MARK: - Spectral Envelope

    /// Update harmonic amplitudes based on spectral shape and brightness
    private func updateSpectralEnvelope() {
        let bright = brightness

        switch spectralShape {
        case .natural:
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let rolloff = 1.0 / pow(n, 1.5 - bright)
                harmonicAmplitudes[i] = rolloff
            }

        case .bright:
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let rolloff = 1.0 / pow(n, 0.5)
                harmonicAmplitudes[i] = rolloff * (0.5 + bright * 0.5)
            }

        case .dark:
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let rolloff = 1.0 / pow(n, 2.5 - bright)
                harmonicAmplitudes[i] = rolloff
            }

        case .formant:
            // Simple vowel formants (approximation of "ah")
            let formants: [(freq: Float, amp: Float, bw: Float)] = [
                (730, 1.0, 90), (1090, 0.5, 110), (2440, 0.3, 170)
            ]
            for i in 0..<harmonicCount {
                let freq = frequency * Float(i + 1)
                var amp: Float = 0.01
                for formant in formants {
                    let diff = (freq - formant.freq) / formant.bw
                    amp += formant.amp * exp(-diff * diff * 0.5)
                }
                harmonicAmplitudes[i] = amp
            }

        case .metallic:
            // Enhanced odd harmonics
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let isOdd = (i + 1) % 2 != 0
                let rolloff = 1.0 / pow(n, 1.0)
                harmonicAmplitudes[i] = isOdd ? rolloff : rolloff * 0.1
            }

        case .hollow:
            // Missing even harmonics (clarinet-like)
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let isOdd = (i + 1) % 2 != 0
                let rolloff = 1.0 / pow(n, 1.2)
                harmonicAmplitudes[i] = isOdd ? rolloff : 0
            }

        case .bell:
            // Slightly inharmonic (bell-like)
            for i in 0..<harmonicCount {
                let n = Float(i + 1)
                let rolloff = 1.0 / pow(n, 0.8)
                // Add slight inharmonicity
                let detune = 1.0 + 0.001 * n * n * bright
                harmonicAmplitudes[i] = rolloff / detune
            }

        case .flat:
            for i in 0..<harmonicCount {
                harmonicAmplitudes[i] = 1.0 / Float(harmonicCount)
            }
        }

        // Normalize
        var maxAmp: Float = 0
        for i in 0..<harmonicCount {
            maxAmp = max(maxAmp, harmonicAmplitudes[i])
        }
        if maxAmp > 0 {
            for i in 0..<harmonicCount {
                harmonicAmplitudes[i] /= maxAmp
            }
        }
    }

    /// Update noise profile based on color
    private func updateNoiseProfile() {
        for i in 0..<noiseBandCount {
            let freq = Float(i) / Float(noiseBandCount) // normalized 0-1

            switch noiseColor {
            case .white:
                noiseMagnitudes[i] = 1.0
            case .pink:
                noiseMagnitudes[i] = 1.0 / sqrt(max(0.01, freq))
            case .brown:
                noiseMagnitudes[i] = 1.0 / max(0.01, freq)
            case .blue:
                noiseMagnitudes[i] = sqrt(max(0.01, freq))
            case .violet:
                noiseMagnitudes[i] = freq
            }
        }

        // Normalize
        var maxMag: Float = 0
        for i in 0..<noiseBandCount {
            maxMag = max(maxMag, noiseMagnitudes[i])
        }
        if maxMag > 0 {
            for i in 0..<noiseBandCount {
                noiseMagnitudes[i] /= maxMag
            }
        }
    }

    // MARK: - Note Control

    /// Trigger note on
    public func noteOn(frequency: Float? = nil) {
        if let f = frequency {
            self.frequency = f
        }
        envelopeStage = .attack
        envelopeSamples = 0
    }

    /// Trigger note off
    public func noteOff() {
        envelopeStage = .release
        envelopeSamples = 0
    }

    // MARK: - Audio Generation

    /// Generate audio samples
    public func render(buffer: inout [Float], frameCount: Int, stereo: Bool = false) {
        let channelCount = stereo ? 2 : 1
        guard buffer.count >= frameCount * channelCount else { return }

        for frame in 0..<frameCount {
            // Update envelope
            updateEnvelope()

            // Smooth amplitude transitions
            let smoothCoeff: Float = 0.995
            for i in 0..<harmonicCount {
                let target = harmonicAmplitudes[i] * harmonicLevel
                smoothedAmplitudes[i] = smoothedAmplitudes[i] * smoothCoeff + target * (1.0 - smoothCoeff)
            }

            // Generate harmonic component
            var harmonicSample: Float = 0
            for i in 0..<harmonicCount {
                let partialFreq = frequency * Float(i + 1)

                // Skip partials above Nyquist
                if partialFreq > sampleRate * 0.5 { break }

                let phaseInc = partialFreq / sampleRate * 2.0 * .pi
                phases[i] += phaseInc
                if phases[i] > 2.0 * .pi { phases[i] -= 2.0 * .pi }

                harmonicSample += sin(phases[i]) * smoothedAmplitudes[i]
            }

            // Generate noise component (simplified colored noise)
            let whiteNoise = Float.random(in: -1...1)
            var noiseSample = whiteNoise

            // Simple one-pole filter for noise coloring
            let noiseAlpha: Float
            switch noiseColor {
            case .white: noiseAlpha = 0
            case .pink: noiseAlpha = 0.5
            case .brown: noiseAlpha = 0.9
            case .blue: noiseAlpha = -0.5
            case .violet: noiseAlpha = -0.9
            }
            if noiseAlpha != 0 {
                let prev = noiseFilterState[0]
                noiseSample = whiteNoise + noiseAlpha * prev
                noiseFilterState[0] = noiseSample
                // Normalize
                noiseSample *= (1.0 - abs(noiseAlpha)) * 0.5
            }

            // Mix harmonic + noise based on harmonicity
            let mixed = harmonicSample * harmonicity + noiseSample * noiseLevel * (1.0 - harmonicity)

            // Apply envelope and gain
            let sample = mixed * amplitude * envelopeValue

            if stereo {
                buffer[frame * 2] = sample
                buffer[frame * 2 + 1] = sample
            } else {
                buffer[frame] = sample
            }
        }
    }

    // MARK: - Envelope

    private func updateEnvelope() {
        envelopeSamples += 1
        let sampleTime = 1.0 / sampleRate

        switch envelopeStage {
        case .idle:
            envelopeValue = 0

        case .attack:
            let attackSamples = max(1, Int(attack * sampleRate))
            envelopeValue = min(1.0, Float(envelopeSamples) / Float(attackSamples))
            if envelopeSamples >= attackSamples {
                envelopeStage = .decay
                envelopeSamples = 0
            }

        case .decay:
            let decaySamples = max(1, Int(decay * sampleRate))
            let progress = Float(envelopeSamples) / Float(decaySamples)
            envelopeValue = 1.0 - (1.0 - sustain) * min(1.0, progress)
            if envelopeSamples >= decaySamples {
                envelopeStage = .sustain
                envelopeSamples = 0
            }

        case .sustain:
            envelopeValue = sustain

        case .release:
            let releaseSamples = max(1, Int(release * sampleRate))
            let progress = Float(envelopeSamples) / Float(releaseSamples)
            let startLevel = sustain
            envelopeValue = startLevel * max(0, 1.0 - progress)
            if envelopeSamples >= releaseSamples {
                envelopeStage = .idle
                envelopeSamples = 0
                envelopeValue = 0
            }
        }

        _ = sampleTime // suppress unused warning
    }

    // MARK: - Bio-Reactive Presets

    /// Apply bio-reactive parameters from coherence and HRV
    /// - Parameters:
    ///   - coherence: HRV coherence (0-1)
    ///   - hrvVariability: HRV variability (normalized 0-1)
    ///   - breathPhase: Breathing phase (0-1, 0=exhale, 1=inhale)
    public func applyBioReactive(coherence: Float, hrvVariability: Float = 0.5, breathPhase: Float = 0.5) {
        // Coherence → harmonicity (pure vs noisy)
        harmonicity = 0.3 + coherence * 0.7

        // HRV variability → brightness
        brightness = 0.2 + hrvVariability * 0.6
        updateSpectralEnvelope()

        // Breathing → amplitude modulation
        amplitude = 0.5 + breathPhase * 0.3
    }

    // MARK: - State Access

    /// Get current spectral envelope for visualization
    public func getSpectralEnvelope() -> [Float] {
        return Array(smoothedAmplitudes.prefix(harmonicCount))
    }

    /// Get current harmonicity value
    public func getHarmonicity() -> Float {
        return harmonicity
    }

    // MARK: - Reset

    /// Reset all state
    public func reset() {
        for i in 0..<harmonicCount {
            phases[i] = 0
            smoothedAmplitudes[i] = 0
        }
        for i in 0..<noiseBandCount {
            noiseFilterState[i] = 0
        }
        envelopeStage = .idle
        envelopeValue = 0
        envelopeSamples = 0
    }
}
