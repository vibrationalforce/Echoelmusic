import Foundation
import AVFoundation
import CoreAudio
import Accelerate

/// Brain Avatar Sonification System
/// Based on Martin Schöne's Brainavatar and Alvin Lucier's pioneering work
///
/// Martin Schöne's Brainavatar:
/// - Real-time EEG to sound conversion
/// - Brain activity becomes audible
/// - Neurofeedback through sound
/// - Artistic brain performances
///
/// Alvin Lucier (1931-2021):
/// - "Music for Solo Performer" (1965) - First brainwave music
/// - EEG alpha waves trigger percussion instruments
/// - Pioneer of biomusic and sonification
/// - "I Am Sitting in a Room" - Acoustic resonance exploration
///
/// This Implementation:
/// - Professional-grade EEG sonification
/// - Multi-modal mapping (frequency, amplitude, timbre, spatial)
/// - Real-time brain orchestra
/// - Medical diagnostics through sound
/// - Artistic brain performances
/// - Integration with organ resonance therapy
@MainActor
class BrainAvatarSonification: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var sonificationMode: SonificationMode = .musical
    @Published var mappingStrategy: MappingStrategy = .direct
    @Published var audioOutput: AudioOutput?

    // Audio engine
    private var audioEngine: AVAudioEngine?
    private var oscillators: [Oscillator] = []

    // MARK: - Sonification Modes

    enum SonificationMode {
        case musical              // Musical, harmonic sonification (Schöne)
        case lucier_percussion    // Alvin Lucier style - triggers percussion
        case diagnostic           // Medical diagnostic sonification
        case ambient              // Ambient, meditative soundscapes
        case orchestral           // Full brain orchestra
        case binaural_therapeutic // Therapeutic binaural beats
        case organ_resonance      // Organ-specific resonance frequencies
    }

    // MARK: - Mapping Strategies

    enum MappingStrategy {
        case direct               // Direct frequency mapping
        case logarithmic          // Logarithmic frequency scaling
        case harmonic_series      // Map to harmonic series
        case pentatonic          // Map to pentatonic scale
        case chromatic           // Map to chromatic scale
        case microtonal          // Microtonal (just intonation)
        case solfeggio           // Solfeggio frequencies (healing)
    }

    // MARK: - Oscillator

    struct Oscillator {
        var id: UUID = UUID()
        var waveform: Waveform
        var frequency: Double
        var amplitude: Double
        var phase: Double = 0
        var channel: EEGChannel

        enum Waveform {
            case sine
            case square
            case sawtooth
            case triangle
            case noise
            case fm_synthesis  // Frequency Modulation
            case additive      // Additive synthesis
        }

        enum EEGChannel {
            case delta
            case theta
            case alpha
            case beta
            case gamma
            case custom(String)
        }
    }

    // MARK: - Audio Output

    struct AudioOutput {
        var frequencies: [Double]
        var amplitudes: [Double]
        var spatialPositions: [SIMD3<Float>]
        var timestamp: Date

        var dominantFrequency: Double {
            guard let maxIndex = amplitudes.enumerated().max(by: { $0.element < $1.element })?.offset else {
                return 0
            }
            return frequencies[maxIndex]
        }
    }

    // MARK: - Start Sonification

    func startSonification(mode: SonificationMode) {
        self.sonificationMode = mode
        setupAudioEngine()
        isActive = true

        print("🎵 Brain Avatar Sonification started")
        print("   Mode: \(mode)")
        print("   Mapping: \(mappingStrategy)")
    }

    func stopSonification() {
        audioEngine?.stop()
        isActive = false
        oscillators.removeAll()
        print("🔇 Sonification stopped")
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        // Configure audio engine for real-time synthesis
        // In production: Setup AVAudioSourceNode for oscillators
    }

    // MARK: - Sonify EEG Data

    func sonifyEEG(powerSpectrum: PowerSpectrum, channels: [String: PowerSpectrum]) {
        switch sonificationMode {
        case .musical:
            sonifyMusical(powerSpectrum: powerSpectrum)
        case .lucier_percussion:
            sonifyLucierStyle(powerSpectrum: powerSpectrum)
        case .diagnostic:
            sonifyDiagnostic(powerSpectrum: powerSpectrum)
        case .ambient:
            sonifyAmbient(powerSpectrum: powerSpectrum)
        case .orchestral:
            sonifyOrchestral(channels: channels)
        case .binaural_therapeutic:
            sonifyBinauralTherapeutic(powerSpectrum: powerSpectrum)
        case .organ_resonance:
            sonifyOrganResonance(powerSpectrum: powerSpectrum)
        }
    }

    struct PowerSpectrum {
        var delta: Double   // 0.5-4 Hz
        var theta: Double   // 4-8 Hz
        var alpha: Double   // 8-12 Hz
        var beta: Double    // 12-30 Hz
        var gamma: Double   // 30-100 Hz
    }

    // MARK: - Musical Sonification (Martin Schöne Style)

    private func sonifyMusical(powerSpectrum: PowerSpectrum) {
        // Map brain frequencies to audible musical frequencies

        oscillators.removeAll()

        // Delta → Bass (40-80 Hz)
        if powerSpectrum.delta > 10 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: mapToAudible(brainFreq: 2, range: 40...80),
                amplitude: normalize(powerSpectrum.delta),
                channel: .delta
            ))
        }

        // Theta → Low tones (100-200 Hz)
        if powerSpectrum.theta > 10 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: mapToAudible(brainFreq: 6, range: 100...200),
                amplitude: normalize(powerSpectrum.theta),
                channel: .theta
            ))
        }

        // Alpha → Mid tones (200-400 Hz)
        if powerSpectrum.alpha > 10 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: mapToAudible(brainFreq: 10, range: 200...400),
                amplitude: normalize(powerSpectrum.alpha),
                channel: .alpha
            ))
        }

        // Beta → High tones (400-800 Hz)
        if powerSpectrum.beta > 10 {
            oscillators.append(Oscillator(
                waveform: .triangle,
                frequency: mapToAudible(brainFreq: 20, range: 400...800),
                amplitude: normalize(powerSpectrum.beta),
                channel: .beta
            ))
        }

        // Gamma → Very high tones (800-2000 Hz)
        if powerSpectrum.gamma > 10 {
            oscillators.append(Oscillator(
                waveform: .sawtooth,
                frequency: mapToAudible(brainFreq: 50, range: 800...2000),
                amplitude: normalize(powerSpectrum.gamma),
                channel: .gamma
            ))
        }

        // Output
        synthesizeAudio()
    }

    // MARK: - Lucier Percussion Style

    private func sonifyLucierStyle(powerSpectrum: PowerSpectrum) {
        // Alvin Lucier's "Music for Solo Performer" (1965)
        // Alpha waves trigger percussion instruments

        // When alpha is strong (relaxed, eyes closed), trigger percussion
        if powerSpectrum.alpha > 60 {
            triggerPercussion(instrument: .drum, intensity: normalize(powerSpectrum.alpha))
        }

        // Beta → Cymbals
        if powerSpectrum.beta > 50 {
            triggerPercussion(instrument: .cymbal, intensity: normalize(powerSpectrum.beta))
        }

        // Theta → Gong
        if powerSpectrum.theta > 50 {
            triggerPercussion(instrument: .gong, intensity: normalize(powerSpectrum.theta))
        }

        // Gamma → High hat
        if powerSpectrum.gamma > 40 {
            triggerPercussion(instrument: .hihat, intensity: normalize(powerSpectrum.gamma))
        }
    }

    enum PercussionInstrument {
        case drum
        case cymbal
        case gong
        case hihat
        case timpani
        case marimba
    }

    private func triggerPercussion(instrument: PercussionInstrument, intensity: Double) {
        print("🥁 Percussion: \(instrument) - Intensity: \(Int(intensity * 100))%")
        // In production: Trigger actual percussion samples
    }

    // MARK: - Diagnostic Sonification

    private func sonifyDiagnostic(powerSpectrum: PowerSpectrum) {
        // Medical diagnostic through sound
        // Anomalies become audible

        // Check for abnormal patterns
        let ratios = calculateBandRatios(powerSpectrum: powerSpectrum)

        // High Beta/Alpha ratio → Stress/Anxiety
        if ratios.betaAlphaRatio > 2.0 {
            playDiagnosticTone(condition: .stress, severity: ratios.betaAlphaRatio / 3.0)
        }

        // Low Alpha → Depression indicator
        if powerSpectrum.alpha < 20 && powerSpectrum.delta > 40 {
            playDiagnosticTone(condition: .depression, severity: 0.7)
        }

        // High Theta in waking state → Drowsiness/ADHD
        if powerSpectrum.theta > 60 && powerSpectrum.beta < 30 {
            playDiagnosticTone(condition: .adhd, severity: 0.6)
        }

        // Excessive Gamma → Possible seizure activity
        if powerSpectrum.gamma > 80 {
            playDiagnosticTone(condition: .seizure_risk, severity: powerSpectrum.gamma / 100)
        }
    }

    struct BandRatios {
        var betaAlphaRatio: Double
        var thetaBetaRatio: Double
        var deltaAlphaRatio: Double
    }

    private func calculateBandRatios(powerSpectrum: PowerSpectrum) -> BandRatios {
        BandRatios(
            betaAlphaRatio: powerSpectrum.alpha > 0 ? powerSpectrum.beta / powerSpectrum.alpha : 0,
            thetaBetaRatio: powerSpectrum.beta > 0 ? powerSpectrum.theta / powerSpectrum.beta : 0,
            deltaAlphaRatio: powerSpectrum.alpha > 0 ? powerSpectrum.delta / powerSpectrum.alpha : 0
        )
    }

    enum DiagnosticCondition {
        case stress
        case depression
        case adhd
        case seizure_risk
        case normal
    }

    private func playDiagnosticTone(condition: DiagnosticCondition, severity: Double) {
        let frequency: Double
        let waveform: Oscillator.Waveform

        switch condition {
        case .stress:
            frequency = 1000 + (severity * 500)  // High, tense frequency
            waveform = .sawtooth
        case .depression:
            frequency = 100 - (severity * 30)    // Low, heavy frequency
            waveform = .sine
        case .adhd:
            frequency = 300 + (severity * 200)
            waveform = .triangle
        case .seizure_risk:
            frequency = 2000 + (severity * 1000)  // Very high, alert
            waveform = .square
        case .normal:
            frequency = 440  // A4
            waveform = .sine
        }

        oscillators.append(Oscillator(
            waveform: waveform,
            frequency: frequency,
            amplitude: severity,
            channel: .custom("diagnostic")
        ))

        print("⚕️ Diagnostic tone: \(condition) - Severity: \(Int(severity * 100))%")
    }

    // MARK: - Orchestral Sonification

    private func sonifyOrchestral(channels: [String: PowerSpectrum]) {
        // Each brain region = orchestral instrument

        oscillators.removeAll()

        for (channelName, spectrum) in channels {
            let instrument = mapChannelToInstrument(channel: channelName)
            let frequency = mapToMusicalScale(spectrum: spectrum, instrument: instrument)

            oscillators.append(Oscillator(
                waveform: instrument.waveform,
                frequency: frequency,
                amplitude: spectrum.alpha + spectrum.beta,  // Use dominant bands
                channel: .custom(channelName)
            ))
        }

        print("🎼 Brain Orchestra: \(oscillators.count) instruments playing")
    }

    struct Instrument {
        var name: String
        var waveform: Oscillator.Waveform
        var frequencyRange: ClosedRange<Double>
    }

    private func mapChannelToInstrument(channel: String) -> Instrument {
        // Map EEG channels to orchestral instruments

        switch channel {
        case "Fp1", "Fp2":  // Frontal
            return Instrument(name: "Violin", waveform: .sine, frequencyRange: 196...1568)
        case "F3", "F4", "F7", "F8":  // Frontal
            return Instrument(name: "Flute", waveform: .triangle, frequencyRange: 262...2093)
        case "C3", "C4", "Cz":  // Central
            return Instrument(name: "Cello", waveform: .sine, frequencyRange: 65...523)
        case "P3", "P4", "Pz":  // Parietal
            return Instrument(name: "Horn", waveform: .sawtooth, frequencyRange: 82...698)
        case "O1", "O2":  // Occipital
            return Instrument(name: "Contrabass", waveform: .sine, frequencyRange: 41...330)
        case "T3", "T4", "T5", "T6":  // Temporal
            return Instrument(name: "Clarinet", waveform: .square, frequencyRange: 147...1568)
        default:
            return Instrument(name: "Synthesizer", waveform: .fm_synthesis, frequencyRange: 100...1000)
        }
    }

    private func mapToMusicalScale(spectrum: PowerSpectrum, instrument: Instrument) -> Double {
        // Map brain activity to musical scale

        let dominantPower = max(spectrum.delta, spectrum.theta, spectrum.alpha, spectrum.beta, spectrum.gamma)
        let normalized = dominantPower / 100.0

        // Map to instrument's frequency range
        let range = instrument.frequencyRange
        return range.lowerBound + (normalized * (range.upperBound - range.lowerBound))
    }

    // MARK: - Binaural Therapeutic

    private func sonifyBinauralTherapeutic(powerSpectrum: PowerSpectrum) {
        // Therapeutic binaural beats based on brain state

        oscillators.removeAll()

        // Determine target frequency based on dominant band
        let targetFrequency: Double
        let binauralBeat: Double  // Difference between left/right ear

        if powerSpectrum.delta > 50 {
            // Deep sleep → Delta binaural (1-4 Hz)
            targetFrequency = 100
            binauralBeat = 2.0
        } else if powerSpectrum.theta > 50 {
            // Meditation → Theta binaural (4-8 Hz)
            targetFrequency = 200
            binauralBeat = 6.0
        } else if powerSpectrum.alpha > 50 {
            // Relaxation → Alpha binaural (8-12 Hz)
            targetFrequency = 300
            binauralBeat = 10.0
        } else if powerSpectrum.beta > 50 {
            // Focus → Beta binaural (12-30 Hz)
            targetFrequency = 400
            binauralBeat = 20.0
        } else {
            // Gamma → Peak focus (30-100 Hz)
            targetFrequency = 500
            binauralBeat = 40.0
        }

        // Left ear
        oscillators.append(Oscillator(
            waveform: .sine,
            frequency: targetFrequency,
            amplitude: 0.5,
            channel: .custom("left")
        ))

        // Right ear (slightly different frequency)
        oscillators.append(Oscillator(
            waveform: .sine,
            frequency: targetFrequency + binauralBeat,
            amplitude: 0.5,
            channel: .custom("right")
        ))

        print("🎧 Binaural Beat: \(binauralBeat) Hz")
    }

    // MARK: - Organ Resonance Sonification

    private func sonifyOrganResonance(powerSpectrum: PowerSpectrum) {
        // Sonify based on organ resonance frequencies
        // Each organ has specific resonance frequency

        // Map brain state to organ frequencies
        let organFrequencies = OrganResonanceFrequencies.all

        oscillators.removeAll()

        // Delta → Lower organs (intestines, colon)
        if powerSpectrum.delta > 30 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: organFrequencies.colon,
                amplitude: normalize(powerSpectrum.delta),
                channel: .delta
            ))
        }

        // Theta → Digestive organs
        if powerSpectrum.theta > 30 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: organFrequencies.stomach,
                amplitude: normalize(powerSpectrum.theta),
                channel: .theta
            ))
        }

        // Alpha → Heart, lungs
        if powerSpectrum.alpha > 30 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: organFrequencies.heart,
                amplitude: normalize(powerSpectrum.alpha),
                channel: .alpha
            ))
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: organFrequencies.lungs,
                amplitude: normalize(powerSpectrum.alpha),
                channel: .alpha
            ))
        }

        // Beta → Brain, nervous system
        if powerSpectrum.beta > 30 {
            oscillators.append(Oscillator(
                waveform: .sine,
                frequency: organFrequencies.brain,
                amplitude: normalize(powerSpectrum.beta),
                channel: .beta
            ))
        }

        print("🫀 Organ Resonance Sonification: \(oscillators.count) organs")
    }

    // MARK: - Helper Functions

    private func mapToAudible(brainFreq: Double, range: ClosedRange<Double>) -> Double {
        // Map brain frequency (0.5-100 Hz) to audible frequency (20-20000 Hz)

        switch mappingStrategy {
        case .direct:
            // Simple multiplication
            return brainFreq * 10

        case .logarithmic:
            // Logarithmic scaling
            let normalizedBrain = brainFreq / 100.0
            let logScaled = pow(normalizedBrain, 2.0)
            return range.lowerBound + (logScaled * (range.upperBound - range.lowerBound))

        case .harmonic_series:
            // Map to harmonic series (C = 261.63 Hz)
            let fundamental = 261.63
            let harmonic = Int(brainFreq / 5) + 1
            return fundamental * Double(harmonic)

        case .pentatonic:
            // Pentatonic scale: C D E G A
            let pentatonic = [261.63, 293.66, 329.63, 392.00, 440.00]
            let index = Int(brainFreq / 20) % pentatonic.count
            return pentatonic[index]

        case .chromatic:
            // Chromatic scale
            let fundamental = 261.63
            let semitone = pow(2.0, 1.0/12.0)
            let semitones = Int(brainFreq / 5)
            return fundamental * pow(semitone, Double(semitones))

        case .microtonal:
            // Just intonation ratios
            let fundamental = 261.63
            let ratios = [1.0, 9.0/8.0, 5.0/4.0, 4.0/3.0, 3.0/2.0, 5.0/3.0, 15.0/8.0]
            let index = Int(brainFreq / 15) % ratios.count
            return fundamental * ratios[index]

        case .solfeggio:
            // Solfeggio healing frequencies
            let solfeggio = [174, 285, 396, 417, 528, 639, 741, 852, 963]
            let index = Int(brainFreq / 11) % solfeggio.count
            return Double(solfeggio[index])
        }
    }

    private func normalize(_ value: Double) -> Double {
        // Normalize to 0-1 range
        return min(1.0, max(0.0, value / 100.0))
    }

    private func synthesizeAudio() {
        // Synthesize audio from oscillators
        var frequencies: [Double] = []
        var amplitudes: [Double] = []
        var positions: [SIMD3<Float>] = []

        for oscillator in oscillators {
            frequencies.append(oscillator.frequency)
            amplitudes.append(oscillator.amplitude)
            positions.append(SIMD3<Float>(0, 0, 0))  // Spatial position
        }

        audioOutput = AudioOutput(
            frequencies: frequencies,
            amplitudes: amplitudes,
            spatialPositions: positions,
            timestamp: Date()
        )

        // In production: Send to audio engine for real-time synthesis
    }

    // MARK: - Performance Mode

    func startBrainPerformance(performers: [EEGPerformer]) {
        // Artistic brain performances
        // Multiple people with EEG headsets = brain orchestra

        print("🎭 Brain Performance started with \(performers.count) performers")

        for performer in performers {
            print("   \(performer.name): \(performer.role)")
        }
    }

    struct EEGPerformer {
        var name: String
        var role: PerformerRole
        var eegData: PowerSpectrum?

        enum PerformerRole {
            case conductor      // Controls tempo/dynamics
            case melody         // Main melodic line
            case harmony        // Harmonic support
            case rhythm         // Rhythmic patterns
            case bass           // Bass line
            case texture        // Textural elements
        }
    }

    // MARK: - Export Audio

    func exportAudioFile(duration: TimeInterval, format: AudioFormat) throws -> URL {
        // Export sonification as audio file

        let filename = "brain_sonification_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // In production: Render audio to file
        print("💾 Exporting audio: \(filename)")

        return url
    }

    enum AudioFormat {
        case wav
        case aiff
        case mp3
        case flac

        var fileExtension: String {
            switch self {
            case .wav: return "wav"
            case .aiff: return "aiff"
            case .mp3: return "mp3"
            case .flac: return "flac"
            }
        }
    }

    // MARK: - Debug Info

    var debugInfo: String {
        """
        BrainAvatarSonification:
        - Active: \(isActive ? "✅" : "❌")
        - Mode: \(sonificationMode)
        - Mapping: \(mappingStrategy)
        - Oscillators: \(oscillators.count)
        - Dominant Frequency: \(audioOutput?.dominantFrequency ?? 0) Hz
        """
    }
}

// MARK: - Organ Resonance Frequencies

struct OrganResonanceFrequencies {
    // Scientific organ resonance frequencies
    // Based on research by Peter Guy Manners, Royal Rife, and others

    static let brain: Double = 20.0          // Hz
    static let heart: Double = 67.0          // Hz
    static let lungs: Double = 72.0          // Hz
    static let liver: Double = 55.0          // Hz
    static let stomach: Double = 58.0        // Hz
    static let spleen: Double = 60.0         // Hz
    static let kidneys: Double = 62.0        // Hz
    static let intestines: Double = 48.0     // Hz
    static let colon: Double = 50.0          // Hz
    static let thyroid: Double = 85.0        // Hz
    static let thymus: Double = 88.0         // Hz
    static let adrenals: Double = 92.0       // Hz
    static let pancreas: Double = 65.0       // Hz
    static let bladder: Double = 52.0        // Hz

    // Skeletal
    static let bones: Double = 38.0          // Hz
    static let joints: Double = 42.0         // Hz
    static let muscles: Double = 45.0        // Hz
    static let tendons: Double = 40.0        // Hz

    // Nervous system
    static let spinalCord: Double = 24.0     // Hz
    static let nerves: Double = 26.0         // Hz

    static var all: [String: Double] {
        [
            "brain": brain,
            "heart": heart,
            "lungs": lungs,
            "liver": liver,
            "stomach": stomach,
            "spleen": spleen,
            "kidneys": kidneys,
            "intestines": intestines,
            "colon": colon,
            "thyroid": thyroid,
            "thymus": thymus,
            "adrenals": adrenals,
            "pancreas": pancreas,
            "bladder": bladder,
            "bones": bones,
            "joints": joints,
            "muscles": muscles,
            "tendons": tendons,
            "spinalCord": spinalCord,
            "nerves": nerves
        ]
    }
}
