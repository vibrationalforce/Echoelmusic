//
//  QuantumTherapyEngine.swift
//  Echoelmusic
//
//  Quantum Science Therapy & Frequency Healing System
//  Created: 2025-11-20
//

import Foundation
import AVFoundation
import HealthKit

// MARK: - Quantum Therapy Engine

/// Advanced frequency therapy system based on quantum resonance and healing frequencies
@available(iOS 15.0, *)
class QuantumTherapyEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var currentTherapy: TherapyMode = .solfeggio528
    @Published var isActive: Bool = false
    @Published var intensity: Float = 0.5  // 0.0 to 1.0
    @Published var duration: TimeInterval = 600  // 10 minutes default
    @Published var heartRateCoherence: Float = 0.0  // 0.0 to 1.0
    @Published var currentFrequency: Float = 528.0

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let mixer = AVAudioMixerNode()

    private var phase: Float = 0.0
    private var sampleRate: Float = 44100.0

    // MARK: - Therapy Modes

    enum TherapyMode: String, CaseIterable, Identifiable {
        case solfeggio174  = "174 Hz - Pain Relief"
        case solfeggio285  = "285 Hz - Tissue Healing"
        case solfeggio396  = "396 Hz - Liberation from Fear"
        case solfeggio417  = "417 Hz - Facilitating Change"
        case solfeggio528  = "528 Hz - DNA Repair & Love"
        case solfeggio639  = "639 Hz - Relationships"
        case solfeggio741  = "741 Hz - Awakening Intuition"
        case solfeggio852  = "852 Hz - Spiritual Order"
        case solfeggio963  = "963 Hz - Divine Consciousness"

        case schumann     = "7.83 Hz - Schumann Resonance"

        case binaural_delta   = "Delta (0.5-4 Hz) - Deep Sleep"
        case binaural_theta   = "Theta (4-8 Hz) - Meditation"
        case binaural_alpha   = "Alpha (8-13 Hz) - Relaxation"
        case binaural_beta    = "Beta (13-30 Hz) - Focus"
        case binaural_gamma   = "Gamma (30-100 Hz) - Cognition"

        case chakra_root      = "Root Chakra - 194.18 Hz"
        case chakra_sacral    = "Sacral Chakra - 210.42 Hz"
        case chakra_solar     = "Solar Plexus - 126.22 Hz"
        case chakra_heart     = "Heart Chakra - 136.10 Hz"
        case chakra_throat    = "Throat Chakra - 141.27 Hz"
        case chakra_thirdEye  = "Third Eye - 221.23 Hz"
        case chakra_crown     = "Crown Chakra - 172.06 Hz"

        case quantum_coherence = "Quantum Coherence Field"
        case golden_ratio      = "Golden Ratio (1.618 × base)"

        var id: String { rawValue }

        var frequency: Float {
            switch self {
            // Solfeggio Frequencies
            case .solfeggio174: return 174.0
            case .solfeggio285: return 285.0
            case .solfeggio396: return 396.0
            case .solfeggio417: return 417.0
            case .solfeggio528: return 528.0
            case .solfeggio639: return 639.0
            case .solfeggio741: return 741.0
            case .solfeggio852: return 852.0
            case .solfeggio963: return 963.0

            // Schumann Resonance
            case .schumann: return 7.83

            // Binaural Beat Base Frequencies (carrier)
            case .binaural_delta: return 200.0  // Carrier, beat is 2 Hz
            case .binaural_theta: return 200.0  // Carrier, beat is 6 Hz
            case .binaural_alpha: return 200.0  // Carrier, beat is 10 Hz
            case .binaural_beta: return 200.0   // Carrier, beat is 20 Hz
            case .binaural_gamma: return 200.0  // Carrier, beat is 40 Hz

            // Chakra Frequencies (Planetary/Cosmic Tuning)
            case .chakra_root: return 194.18
            case .chakra_sacral: return 210.42
            case .chakra_solar: return 126.22
            case .chakra_heart: return 136.10
            case .chakra_throat: return 141.27
            case .chakra_thirdEye: return 221.23
            case .chakra_crown: return 172.06

            // Advanced
            case .quantum_coherence: return 432.0  // A=432 Hz tuning
            case .golden_ratio: return 528.0 * 1.618  // Golden ratio applied
            }
        }

        var beatFrequency: Float? {
            // For binaural beats, return the difference frequency
            switch self {
            case .binaural_delta: return 2.0
            case .binaural_theta: return 6.0
            case .binaural_alpha: return 10.0
            case .binaural_beta: return 20.0
            case .binaural_gamma: return 40.0
            default: return nil
            }
        }

        var category: TherapyCategory {
            switch self {
            case .solfeggio174, .solfeggio285, .solfeggio396, .solfeggio417,
                 .solfeggio528, .solfeggio639, .solfeggio741, .solfeggio852, .solfeggio963:
                return .solfeggio
            case .schumann:
                return .earthResonance
            case .binaural_delta, .binaural_theta, .binaural_alpha, .binaural_beta, .binaural_gamma:
                return .binauralBeats
            case .chakra_root, .chakra_sacral, .chakra_solar, .chakra_heart,
                 .chakra_throat, .chakra_thirdEye, .chakra_crown:
                return .chakra
            case .quantum_coherence, .golden_ratio:
                return .quantum
            }
        }

        var description: String {
            switch self {
            case .solfeggio174:
                return "Pain relief, tension release, and grounding. Foundation frequency for physical healing."
            case .solfeggio285:
                return "Tissue regeneration, quantum healing field. Repairs cellular structures and organs."
            case .solfeggio396:
                return "Liberation from fear, guilt, and negative beliefs. Root chakra activation."
            case .solfeggio417:
                return "Facilitating change, removing negative influences. Sacral chakra resonance."
            case .solfeggio528:
                return "DNA repair, love frequency, miracles. The 'Love Frequency' - most powerful healing tone."
            case .solfeggio639:
                return "Harmonious relationships, connection, and communication. Heart chakra opening."
            case .solfeggio741:
                return "Awakening intuition, purification, and problem-solving. Expression and solutions."
            case .solfeggio852:
                return "Spiritual order, awakening of inner strength. Return to spiritual harmony."
            case .solfeggio963:
                return "Divine consciousness, pineal gland activation. Crown chakra, oneness frequency."
            case .schumann:
                return "Earth's natural resonance. Synchronizes with Earth's electromagnetic field. Deep grounding."
            case .binaural_delta:
                return "Deep dreamless sleep, healing, regeneration. HGH release and immune system boost."
            case .binaural_theta:
                return "Deep meditation, creativity, REM sleep. Enhanced learning and intuition."
            case .binaural_alpha:
                return "Relaxed focus, stress reduction, visualization. Light meditation and learning."
            case .binaural_beta:
                return "Active thinking, focus, concentration. Problem-solving and alertness."
            case .binaural_gamma:
                return "Higher cognition, peak awareness, spiritual insights. Transcendental states."
            case .chakra_root:
                return "Root chakra (Muladhara). Grounding, survival, security. Earth element."
            case .chakra_sacral:
                return "Sacral chakra (Svadhisthana). Creativity, sexuality, emotions. Water element."
            case .chakra_solar:
                return "Solar Plexus (Manipura). Personal power, confidence, will. Fire element."
            case .chakra_heart:
                return "Heart chakra (Anahata). Love, compassion, healing. Air element."
            case .chakra_throat:
                return "Throat chakra (Vishuddha). Communication, truth, expression. Ether element."
            case .chakra_thirdEye:
                return "Third Eye (Ajna). Intuition, vision, insight. Light element."
            case .chakra_crown:
                return "Crown chakra (Sahasrara). Divine connection, enlightenment. Cosmic consciousness."
            case .quantum_coherence:
                return "Quantum field harmonization. A=432 Hz natural tuning. Universal resonance."
            case .golden_ratio:
                return "Golden ratio (φ = 1.618) applied to healing frequencies. Sacred geometry in sound."
            }
        }
    }

    enum TherapyCategory: String, CaseIterable {
        case solfeggio = "Solfeggio Frequencies"
        case earthResonance = "Earth Resonance"
        case binauralBeats = "Binaural Beats"
        case chakra = "Chakra Tuning"
        case quantum = "Quantum Healing"
    }

    // MARK: - Initialization

    init() {
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Configure audio session for therapy
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)

        // Attach mixer
        audioEngine.attach(mixer)
        audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: nil)

        // Prepare engine
        audioEngine.prepare()
    }

    // MARK: - Start/Stop Therapy

    func startTherapy(mode: TherapyMode) {
        currentTherapy = mode
        currentFrequency = mode.frequency

        // Create audio source node
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // Generate therapy tone based on mode
                let sample = self.generateTherapyTone(frame: frame, mode: mode)

                // Apply to both channels (stereo)
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample * self.intensity
                }
            }

            return noErr
        }

        // Attach and connect
        if let sourceNode = sourceNode {
            audioEngine.attach(sourceNode)
            audioEngine.connect(sourceNode, to: mixer, format: format)
        }

        // Start engine
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }

        isActive = true
    }

    func stopTherapy() {
        if let sourceNode = sourceNode {
            audioEngine.detach(sourceNode)
            self.sourceNode = nil
        }

        isActive = false
        phase = 0.0
    }

    // MARK: - Therapy Tone Generation

    private func generateTherapyTone(frame: Int, mode: TherapyMode) -> Float {
        let frequency = mode.frequency
        let phaseIncrement = frequency / sampleRate

        var sample: Float = 0.0

        if let beatFreq = mode.beatFrequency {
            // Binaural beat: Generate two slightly different frequencies for L/R
            // For simplicity in mono source, we'll generate the "beat" effect
            let carrier = frequency
            let beat = beatFreq

            // Amplitude modulation creates the "beat" effect
            let modulator = sin(2.0 * .pi * beat * Float(frame) / sampleRate)
            sample = sin(2.0 * .pi * phase) * (0.5 + 0.5 * modulator)
        } else {
            // Pure sine wave for most therapies
            sample = sin(2.0 * .pi * phase)

            // Add harmonics for richer tone (subtle)
            sample += sin(2.0 * .pi * phase * 2.0) * 0.1  // 2nd harmonic
            sample += sin(2.0 * .pi * phase * 3.0) * 0.05  // 3rd harmonic

            // Normalize
            sample /= 1.15
        }

        // Update phase
        phase += phaseIncrement
        if phase >= 1.0 {
            phase -= 1.0
        }

        // Apply envelope (fade in/out for smooth transitions)
        // This would be enhanced with proper session duration handling

        return sample
    }

    // MARK: - Heart Rate Coherence

    func updateHeartRateCoherence(heartRate: Double, hrv: Double) {
        // Calculate coherence based on HRV and heart rate stability
        // Higher HRV = better coherence
        // Stable heart rate = better coherence

        let idealHRV: Double = 50.0  // ms (RMSSD)
        let hrvScore = min(Float(hrv / idealHRV), 1.0)

        // Coherence is combination of HRV and resonance with therapy
        heartRateCoherence = hrvScore
    }

    // MARK: - Preset Sessions

    struct TherapySession {
        let name: String
        let modes: [TherapyMode]
        let durations: [TimeInterval]  // Duration for each mode
        let description: String
    }

    static let presetSessions: [TherapySession] = [
        TherapySession(
            name: "Deep Healing",
            modes: [.solfeggio528, .solfeggio285, .solfeggio174],
            durations: [600, 600, 600],  // 10 min each = 30 min total
            description: "Complete healing session: DNA repair, tissue regeneration, pain relief"
        ),
        TherapySession(
            name: "Chakra Alignment",
            modes: [.chakra_root, .chakra_sacral, .chakra_solar, .chakra_heart,
                   .chakra_throat, .chakra_thirdEye, .chakra_crown],
            durations: [300, 300, 300, 300, 300, 300, 300],  // 5 min each = 35 min
            description: "Full chakra balancing from root to crown"
        ),
        TherapySession(
            name: "Meditation Journey",
            modes: [.binaural_alpha, .binaural_theta, .binaural_delta],
            durations: [600, 900, 600],  // 10-15-10 min = 35 min
            description: "Deep meditation progression: relaxation → theta → deep rest"
        ),
        TherapySession(
            name: "Focus & Productivity",
            modes: [.binaural_alpha, .binaural_beta, .binaural_gamma],
            durations: [300, 1200, 300],  // 5-20-5 min = 30 min
            description: "Enhanced focus and cognitive performance"
        ),
        TherapySession(
            name: "Sleep Preparation",
            modes: [.binaural_alpha, .binaural_theta, .binaural_delta, .schumann],
            durations: [600, 900, 1200, 1800],  // Progressive to deep sleep
            description: "Gentle progression into deep, restful sleep"
        ),
        TherapySession(
            name: "Quantum Healing",
            modes: [.quantum_coherence, .golden_ratio, .solfeggio528, .schumann],
            durations: [900, 600, 900, 600],  // 15-10-15-10 min = 50 min
            description: "Advanced quantum field therapy with sacred geometry"
        ),
        TherapySession(
            name: "Stress Relief",
            modes: [.solfeggio396, .binaural_alpha, .chakra_heart, .schumann],
            durations: [600, 600, 600, 600],  // 10 min each = 40 min
            description: "Release fear, relax, open heart, ground to Earth"
        )
    ]
}

// MARK: - Audio Super Scan Engine

/// Professional-grade audio analysis and visualization
@available(iOS 15.0, *)
class AudioSuperScanEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var spectrumData: [Float] = []
    @Published var spectrogramData: [[Float]] = []
    @Published var peakLevel: Float = 0.0
    @Published var rmsLevel: Float = 0.0
    @Published var lufsLevel: Float = -23.0  // EBU R128 target
    @Published var phaseCorrelation: Float = 1.0  // -1 to +1
    @Published var dominantFrequency: Float = 440.0
    @Published var harmonicContent: [Float] = []

    // MARK: - FFT Configuration

    private let fftSize: vDSP_Length = 8192  // High resolution
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?

    // MARK: - Audio Buffers

    private var audioBuffer: [Float] = []
    private let maxBufferSize = 8192

    // MARK: - Analysis Modes

    enum ScanMode: String, CaseIterable {
        case spectrum = "Spectrum Analyzer"
        case spectrogram = "Spectrogram (Waterfall)"
        case harmonic = "Harmonic Analysis"
        case phase = "Phase Correlation"
        case loudness = "Loudness Meter (LUFS)"
        case frequency = "Frequency Response"
        case resonance = "Resonance Detector"
    }

    @Published var currentMode: ScanMode = .spectrum

    // MARK: - Initialization

    init() {
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Initialize spectrum data
        spectrumData = [Float](repeating: 0, count: Int(fftSize / 2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Process Audio Buffer

    func processAudioBuffer(_ buffer: [Float]) {
        // Add to circular buffer
        audioBuffer.append(contentsOf: buffer)
        if audioBuffer.count > maxBufferSize {
            audioBuffer.removeFirst(audioBuffer.count - maxBufferSize)
        }

        // Perform analysis based on current mode
        switch currentMode {
        case .spectrum:
            analyzeSpectrum()
        case .spectrogram:
            analyzeSpectrogram()
        case .harmonic:
            analyzeHarmonics()
        case .phase:
            analyzePhaseCorrelation()
        case .loudness:
            analyzeLoudness()
        case .frequency:
            analyzeFrequencyResponse()
        case .resonance:
            detectResonances()
        }

        // Always calculate peak and RMS
        calculateLevels()
    }

    // MARK: - Spectrum Analysis

    private func analyzeSpectrum() {
        guard let setup = fftSetup, audioBuffer.count >= fftSize else { return }

        let frameCount = Int(fftSize)
        var realPart = [Float](repeating: 0, count: frameCount)
        var imagPart = [Float](repeating: 0, count: frameCount)

        // Copy audio data
        realPart[0..<min(audioBuffer.count, frameCount)] =
            ArraySlice(audioBuffer.suffix(frameCount))

        // Apply window (Hamming)
        var window = [Float](repeating: 0, count: frameCount)
        vDSP_hamm_window(&window, vDSP_Length(frameCount), 0)
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(frameCount))

        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude
        var magnitudes = [Float](repeating: 0, count: frameCount / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))

        // Convert to dB
        var dB = [Float](repeating: 0, count: frameCount / 2)
        var zeroReference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &zeroReference, &dB, 1, vDSP_Length(frameCount / 2), 1)

        // Update spectrum data
        DispatchQueue.main.async {
            self.spectrumData = dB

            // Find dominant frequency
            if let maxIndex = dB.enumerated().max(by: { $0.element < $1.element })?.offset {
                let sampleRate: Float = 44100.0
                self.dominantFrequency = Float(maxIndex) * sampleRate / Float(frameCount)
            }
        }
    }

    // MARK: - Spectrogram (Waterfall)

    private func analyzeSpectrogram() {
        analyzeSpectrum()  // Get current spectrum

        // Add to spectrogram history
        DispatchQueue.main.async {
            self.spectrogramData.append(self.spectrumData)

            // Keep last 100 frames
            if self.spectrogramData.count > 100 {
                self.spectrogramData.removeFirst()
            }
        }
    }

    // MARK: - Harmonic Analysis

    private func analyzeHarmonics() {
        analyzeSpectrum()

        // Detect harmonics of dominant frequency
        let fundamental = dominantFrequency
        var harmonics: [Float] = []

        let sampleRate: Float = 44100.0
        let binSize = sampleRate / Float(fftSize)

        // Analyze first 8 harmonics
        for harmonic in 1...8 {
            let targetFreq = fundamental * Float(harmonic)
            let targetBin = Int(targetFreq / binSize)

            if targetBin < spectrumData.count {
                harmonics.append(spectrumData[targetBin])
            } else {
                harmonics.append(-100.0)  // Below noise floor
            }
        }

        DispatchQueue.main.async {
            self.harmonicContent = harmonics
        }
    }

    // MARK: - Phase Correlation

    private func analyzePhaseCorrelation() {
        // Simplified phase correlation (would need stereo input for true correlation)
        // For now, analyze mono signal coherence

        guard audioBuffer.count >= 1024 else { return }

        let frameCount = 1024
        let leftChannel = Array(audioBuffer.suffix(frameCount))

        // Calculate auto-correlation at lag 1
        var correlation: Float = 0.0
        vDSP_dotpr(leftChannel, 1, leftChannel, 1, &correlation, vDSP_Length(frameCount - 1))

        // Normalize
        var power: Float = 0.0
        vDSP_svesq(leftChannel, 1, &power, vDSP_Length(frameCount))

        let normalizedCorrelation = power > 0 ? correlation / power : 0.0

        DispatchQueue.main.async {
            self.phaseCorrelation = normalizedCorrelation
        }
    }

    // MARK: - Loudness (LUFS)

    private func analyzeLoudness() {
        // Simplified LUFS calculation (EBU R128)
        // Real implementation would use K-weighting filter

        guard audioBuffer.count > 0 else { return }

        // Calculate RMS over 400ms window (short-term loudness)
        let windowSize = min(audioBuffer.count, 17640)  // 400ms at 44.1kHz
        let window = Array(audioBuffer.suffix(windowSize))

        var rms: Float = 0.0
        vDSP_rmsqv(window, 1, &rms, vDSP_Length(windowSize))

        // Convert to LUFS (simplified)
        let lufs = 20.0 * log10(rms) - 0.691  // Approximate LUFS conversion

        DispatchQueue.main.async {
            self.lufsLevel = lufs
        }
    }

    // MARK: - Frequency Response

    private func analyzeFrequencyResponse() {
        // Same as spectrum but with smoothing
        analyzeSpectrum()

        // Apply smoothing to spectrum data
        var smoothed = spectrumData
        let smoothingFactor: Float = 0.3

        for i in 1..<smoothed.count - 1 {
            smoothed[i] = spectrumData[i] * (1.0 - smoothingFactor) +
                         (spectrumData[i-1] + spectrumData[i+1]) * 0.5 * smoothingFactor
        }

        DispatchQueue.main.async {
            self.spectrumData = smoothed
        }
    }

    // MARK: - Resonance Detection

    private func detectResonances() {
        analyzeSpectrum()

        // Find peaks in spectrum (potential resonances)
        var peaks: [Int] = []
        let threshold: Float = -20.0  // dB

        for i in 1..<spectrumData.count - 1 {
            if spectrumData[i] > threshold &&
               spectrumData[i] > spectrumData[i-1] &&
               spectrumData[i] > spectrumData[i+1] {
                peaks.append(i)
            }
        }

        // Resonances detected (would be visualized in UI)
    }

    // MARK: - Level Calculation

    private func calculateLevels() {
        guard audioBuffer.count > 0 else { return }

        // Peak level
        var peak: Float = 0.0
        vDSP_maxv(audioBuffer, 1, &peak, vDSP_Length(audioBuffer.count))

        // RMS level
        var rms: Float = 0.0
        vDSP_rmsqv(audioBuffer, 1, &rms, vDSP_Length(audioBuffer.count))

        DispatchQueue.main.async {
            self.peakLevel = 20.0 * log10(peak + 1e-10)  // Convert to dB
            self.rmsLevel = 20.0 * log10(rms + 1e-10)
        }
    }
}
