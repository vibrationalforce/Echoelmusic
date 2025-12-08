import Foundation
import Accelerate
import Combine

#if canImport(AVFoundation)
import AVFoundation
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// MUSICAL ENTRAINMENT ENGINE FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Aesthetic brainwave entrainment through musical modulation.
// Instead of crude binaural beats or isochronic pulses, this engine embeds
// entrainment frequencies into the musical fabric itself.
//
// SCIENTIFIC BASIS:
// ───────────────────────────────────────────────────────────────────────────────
// [1] Thaut, M. H. (2005). "Rhythm, Music, and the Brain: Scientific Foundations
//     and Clinical Applications." Routledge.
//     - Rhythmic Auditory Stimulation (RAS) entrains motor and cognitive systems
//
// [2] Nozaradan, S., et al. (2011). "Tagging the Neuronal Entrainment to Beat
//     and Meter." Journal of Neuroscience, 31(28), 10234-10240.
//     - Neural oscillations synchronize to musical beat structure
//
// [3] Large, E. W., & Palmer, C. (2002). "Perceiving temporal regularity in
//     music." Cognitive Science, 26(1), 1-37.
//     - Dynamic attending theory - attention oscillates with rhythm
//
// [4] Trost, W., et al. (2017). "Rhythmic entrainment as a musical affect
//     induction mechanism." Neuropsychologia, 96, 96-110.
//     - Entrainment to groove affects emotional state
//
// [5] Levitin, D. J. (2006). "This Is Your Brain on Music."
//     - Dopamine release tied to musical expectation/resolution
//
// APPROACH:
// ───────────────────────────────────────────────────────────────────────────────
// Rather than adding artificial tones, we modulate musical parameters:
// • Amplitude envelope (breathing rhythm)
// • Stereo field movement (spatial entrainment)
// • Filter resonance sweeps (harmonic breathing)
// • Tempo micro-variations (groove entrainment)
// • Harmonic density modulation (complexity waves)
// • Reverb/space modulation (environmental breathing)
//
// This creates entrainment that IS the music, not layered on top.
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Entrainment Target States

/// Target brainwave states with musical characteristics
public enum EntrainmentState: String, CaseIterable, Identifiable {
    case deepSleep      // Delta: 0.5-4 Hz
    case meditation     // Theta: 4-8 Hz
    case relaxation     // Alpha: 8-13 Hz
    case focus          // Low Beta: 13-20 Hz
    case flow           // SMR: 12-15 Hz (Sensorimotor Rhythm)
    case alertness      // High Beta: 20-30 Hz
    case insight        // Gamma: 30-50 Hz

    public var id: String { rawValue }

    /// Target frequency for this state
    public var targetFrequency: Float {
        switch self {
        case .deepSleep: return 2.0
        case .meditation: return 6.0
        case .relaxation: return 10.0
        case .focus: return 15.0
        case .flow: return 13.0
        case .alertness: return 25.0
        case .insight: return 40.0
        }
    }

    /// Musical characteristics for this state
    public var musicalCharacteristics: MusicalCharacteristics {
        switch self {
        case .deepSleep:
            return MusicalCharacteristics(
                tempoRange: 40...60,
                dynamicRange: 0.1...0.3,
                harmonicComplexity: 0.2,
                rhythmicDensity: 0.1,
                spatialMovement: 0.3,
                filterBrightness: 0.2
            )
        case .meditation:
            return MusicalCharacteristics(
                tempoRange: 50...70,
                dynamicRange: 0.2...0.4,
                harmonicComplexity: 0.3,
                rhythmicDensity: 0.2,
                spatialMovement: 0.5,
                filterBrightness: 0.3
            )
        case .relaxation:
            return MusicalCharacteristics(
                tempoRange: 60...80,
                dynamicRange: 0.3...0.5,
                harmonicComplexity: 0.4,
                rhythmicDensity: 0.3,
                spatialMovement: 0.6,
                filterBrightness: 0.5
            )
        case .focus:
            return MusicalCharacteristics(
                tempoRange: 90...120,
                dynamicRange: 0.4...0.6,
                harmonicComplexity: 0.5,
                rhythmicDensity: 0.5,
                spatialMovement: 0.4,
                filterBrightness: 0.6
            )
        case .flow:
            return MusicalCharacteristics(
                tempoRange: 78...96,
                dynamicRange: 0.4...0.6,
                harmonicComplexity: 0.6,
                rhythmicDensity: 0.5,
                spatialMovement: 0.5,
                filterBrightness: 0.6
            )
        case .alertness:
            return MusicalCharacteristics(
                tempoRange: 100...140,
                dynamicRange: 0.5...0.8,
                harmonicComplexity: 0.7,
                rhythmicDensity: 0.7,
                spatialMovement: 0.3,
                filterBrightness: 0.8
            )
        case .insight:
            return MusicalCharacteristics(
                tempoRange: 120...160,
                dynamicRange: 0.6...0.9,
                harmonicComplexity: 0.8,
                rhythmicDensity: 0.8,
                spatialMovement: 0.7,
                filterBrightness: 0.9
            )
        }
    }

    /// Scientific reference for this state
    public var scientificBasis: String {
        switch self {
        case .deepSleep:
            return "Delta waves (0.5-4 Hz) dominate during deep, dreamless sleep. Associated with healing and regeneration."
        case .meditation:
            return "Theta waves (4-8 Hz) appear during deep meditation, creativity, and light sleep. Associated with insight and memory consolidation."
        case .relaxation:
            return "Alpha waves (8-13 Hz) indicate relaxed alertness. Prominent when eyes are closed and mind is calm."
        case .focus:
            return "Low Beta (13-20 Hz) indicates active concentration and problem-solving. Ideal for cognitive tasks."
        case .flow:
            return "Sensorimotor Rhythm (12-15 Hz) is associated with flow states and calm focus. Used in neurofeedback for ADHD."
        case .alertness:
            return "High Beta (20-30 Hz) indicates active thinking and alertness. Can indicate anxiety if excessive."
        case .insight:
            return "Gamma (30-50 Hz) is associated with higher cognitive functions, insight moments, and binding of perceptions."
        }
    }
}

/// Musical characteristics for entrainment states
public struct MusicalCharacteristics {
    public var tempoRange: ClosedRange<Float>
    public var dynamicRange: ClosedRange<Float>
    public var harmonicComplexity: Float  // 0-1
    public var rhythmicDensity: Float     // 0-1
    public var spatialMovement: Float     // 0-1
    public var filterBrightness: Float    // 0-1
}

// MARK: - Musical Modulation Engine

/// Core engine for aesthetic entrainment through musical modulation
@MainActor
public final class MusicalEntrainmentEngine: ObservableObject {

    // MARK: Singleton
    public static let shared = MusicalEntrainmentEngine()

    // MARK: Published State
    @Published public var isActive: Bool = false
    @Published public var targetState: EntrainmentState = .relaxation
    @Published public var currentPhase: Float = 0  // 0-1 within entrainment cycle
    @Published public var entrainmentDepth: Float = 0.5  // How strongly to modulate (0-1)
    @Published public var transitionDuration: TimeInterval = 60.0  // Seconds to transition between states

    // MARK: Modulation Outputs (for other engines to read)
    @Published public private(set) var amplitudeModulation: Float = 1.0
    @Published public private(set) var stereoPosition: Float = 0.0  // -1 to 1
    @Published public private(set) var filterModulation: Float = 0.5
    @Published public private(set) var reverbModulation: Float = 0.3
    @Published public private(set) var tempoModulation: Float = 1.0
    @Published public private(set) var harmonicModulation: Float = 0.5

    // MARK: Private
    private var phase: Double = 0
    private var sampleRate: Double = 48000
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()

    // Modulation LFOs (Low Frequency Oscillators)
    private var primaryLFO: LFOState = LFOState()
    private var secondaryLFO: LFOState = LFOState()
    private var tertiaryLFO: LFOState = LFOState()

    private struct LFOState {
        var phase: Double = 0
        var frequency: Double = 1.0
        var depth: Float = 1.0
        var shape: LFOShape = .sine
    }

    public enum LFOShape: String, CaseIterable {
        case sine
        case triangle
        case smoothSquare
        case breath  // Custom shape mimicking natural breathing
        case heartbeat  // Custom shape mimicking heart rhythm
    }

    // MARK: Initialization
    private init() {
        setupLFOs()
        print("=== MusicalEntrainmentEngine Initialized ===")
    }

    // MARK: - Public API

    /// Start the entrainment engine
    public func start() {
        guard !isActive else { return }

        isActive = true
        startModulationLoop()

        print("Musical Entrainment started")
        print("  Target: \(targetState.rawValue)")
        print("  Frequency: \(targetState.targetFrequency) Hz")
    }

    /// Stop the entrainment engine
    public func stop() {
        isActive = false
        displayLink?.invalidate()
        displayLink = nil

        // Reset modulations to neutral
        amplitudeModulation = 1.0
        stereoPosition = 0.0
        filterModulation = 0.5
        reverbModulation = 0.3
        tempoModulation = 1.0
        harmonicModulation = 0.5

        print("Musical Entrainment stopped")
    }

    /// Transition to a new state over time
    public func transitionTo(_ state: EntrainmentState, duration: TimeInterval? = nil) {
        let actualDuration = duration ?? transitionDuration

        print("Transitioning to \(state.rawValue) over \(actualDuration)s")

        // Smoothly interpolate LFO frequencies
        let targetFreq = Double(state.targetFrequency)

        withAnimation(.easeInOut(duration: actualDuration)) {
            self.targetState = state
        }

        // Gradually change LFO frequency
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .prefix(Int(actualDuration * 10))
            .sink { [weak self] _ in
                guard let self = self else { return }
                let progress = 1.0 - (self.primaryLFO.frequency - targetFreq) / targetFreq
                self.primaryLFO.frequency += (targetFreq - self.primaryLFO.frequency) * 0.05
            }
            .store(in: &cancellables)
    }

    /// Set entrainment based on bio-data
    public func adaptToBioState(heartRate: Float, hrv: Float, coherence: Float) {
        // High coherence + high HRV = already in good state, gentle entrainment
        // Low coherence + low HRV = needs more support, deeper entrainment

        let needsSupport = (1.0 - coherence) * (1.0 - min(hrv / 80.0, 1.0))
        entrainmentDepth = 0.3 + needsSupport * 0.5  // 0.3 to 0.8

        // Adjust target based on current state
        if coherence > 0.7 {
            // Already coherent, support current state
        } else if heartRate > 90 {
            // Elevated heart rate, guide toward relaxation
            if targetState != .relaxation && targetState != .meditation {
                transitionTo(.relaxation, duration: 120)
            }
        }
    }

    // MARK: - Private Implementation

    private func setupLFOs() {
        // Primary LFO: Main entrainment frequency
        primaryLFO.frequency = Double(targetState.targetFrequency)
        primaryLFO.shape = .breath
        primaryLFO.depth = 1.0

        // Secondary LFO: Slower modulation for variation (1/4 of primary)
        secondaryLFO.frequency = primaryLFO.frequency / 4.0
        secondaryLFO.shape = .sine
        secondaryLFO.depth = 0.3

        // Tertiary LFO: Very slow drift (1/16 of primary)
        tertiaryLFO.frequency = primaryLFO.frequency / 16.0
        tertiaryLFO.shape = .triangle
        tertiaryLFO.depth = 0.15
    }

    private func startModulationLoop() {
        // Use display link for smooth, synchronized updates
        displayLink = CADisplayLink(target: self, selector: #selector(updateModulations))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateModulations() {
        guard isActive else { return }

        let deltaTime = displayLink?.targetTimestamp ?? (1.0 / 60.0)

        // Update LFO phases
        updateLFOPhase(&primaryLFO, deltaTime: deltaTime)
        updateLFOPhase(&secondaryLFO, deltaTime: deltaTime)
        updateLFOPhase(&tertiaryLFO, deltaTime: deltaTime)

        // Get LFO values
        let primary = getLFOValue(primaryLFO)
        let secondary = getLFOValue(secondaryLFO)
        let tertiary = getLFOValue(tertiaryLFO)

        // Combine LFOs with different weights
        let combined = primary * 0.6 + secondary * 0.25 + tertiary * 0.15

        // Apply entrainment depth
        let modAmount = combined * entrainmentDepth

        // Update current phase for UI
        currentPhase = Float(primaryLFO.phase)

        // Calculate modulations
        calculateModulations(baseModulation: modAmount, primary: primary, secondary: secondary)
    }

    private func updateLFOPhase(_ lfo: inout LFOState, deltaTime: TimeInterval) {
        lfo.phase += lfo.frequency * deltaTime
        if lfo.phase >= 1.0 {
            lfo.phase -= 1.0
        }
    }

    private func getLFOValue(_ lfo: LFOState) -> Float {
        let phase = Float(lfo.phase)

        switch lfo.shape {
        case .sine:
            return sin(phase * 2 * .pi) * lfo.depth

        case .triangle:
            let tri = abs(phase * 2 - 1) * 2 - 1
            return tri * lfo.depth

        case .smoothSquare:
            // Soft square wave using tanh
            let square = tanh(sin(phase * 2 * .pi) * 3)
            return square * lfo.depth

        case .breath:
            // Natural breathing pattern: longer exhale than inhale
            // Inhale: 0-0.4, Exhale: 0.4-1.0
            let breathPhase: Float
            if phase < 0.4 {
                // Inhale (smooth rise)
                breathPhase = sin(phase / 0.4 * .pi / 2)
            } else {
                // Exhale (smooth fall, slower)
                breathPhase = cos((phase - 0.4) / 0.6 * .pi / 2)
            }
            return (breathPhase * 2 - 1) * lfo.depth

        case .heartbeat:
            // Double-peak heartbeat pattern
            let t = phase * 2 * .pi
            let beat1 = exp(-pow((phase - 0.1) * 10, 2))
            let beat2 = exp(-pow((phase - 0.25) * 15, 2)) * 0.6
            return Float((beat1 + beat2) * 2 - 1) * lfo.depth
        }
    }

    private func calculateModulations(baseModulation: Float, primary: Float, secondary: Float) {
        let characteristics = targetState.musicalCharacteristics

        // Amplitude Modulation: Subtle breathing of overall volume
        // Range: 0.85 - 1.0 (never drops too low)
        amplitudeModulation = 1.0 - (1.0 - baseModulation) * 0.15

        // Stereo Position: Gentle swaying left-right
        // Uses slower secondary LFO for smooth movement
        stereoPosition = secondary * characteristics.spatialMovement * 0.5

        // Filter Modulation: Brightness breathing
        // Maps entrainment to filter cutoff movement
        let baseFilter = characteristics.filterBrightness
        filterModulation = baseFilter + primary * 0.2 * entrainmentDepth

        // Reverb Modulation: Space breathing
        // Expands on inhale, contracts on exhale
        let baseReverb: Float = 0.3
        reverbModulation = baseReverb + (baseModulation + 1) * 0.15

        // Tempo Modulation: Micro-timing variations
        // Very subtle, creates "groove" feeling
        tempoModulation = 1.0 + primary * 0.02 * entrainmentDepth

        // Harmonic Modulation: Complexity breathing
        // More harmonics on "bright" phase, fewer on "dark"
        harmonicModulation = characteristics.harmonicComplexity + primary * 0.1
    }

    // MARK: - Audio Processing Integration

    /// Process audio buffer with entrainment modulations
    public func processAudioBuffer(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int = 2
    ) {
        guard isActive else { return }

        // Apply amplitude modulation
        var amp = amplitudeModulation
        vDSP_vsmul(buffer, 1, &amp, buffer, 1, vDSP_Length(frameCount * channelCount))

        // Apply stereo modulation if stereo
        if channelCount == 2 {
            applyStereoModulation(buffer, frameCount: frameCount)
        }
    }

    private func applyStereoModulation(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Convert stereo position to left/right gains
        let pan = stereoPosition
        let leftGain = sqrt(0.5 * (1.0 - pan))
        let rightGain = sqrt(0.5 * (1.0 + pan))

        for i in 0..<frameCount {
            buffer[i * 2] *= leftGain      // Left
            buffer[i * 2 + 1] *= rightGain // Right
        }
    }

    // MARK: - Modulation Curves for External Systems

    /// Get current modulation values as a dictionary for other systems
    public var currentModulations: [String: Float] {
        [
            "amplitude": amplitudeModulation,
            "stereo": stereoPosition,
            "filter": filterModulation,
            "reverb": reverbModulation,
            "tempo": tempoModulation,
            "harmonic": harmonicModulation,
            "phase": currentPhase,
            "depth": entrainmentDepth
        ]
    }

    /// Get modulation value for a specific parameter at a specific phase
    public func modulationValue(for parameter: ModulationParameter, atPhase phase: Float) -> Float {
        // Allow external systems to query what modulation would be at any phase
        let tempLFO = LFOState(
            phase: Double(phase),
            frequency: primaryLFO.frequency,
            depth: primaryLFO.depth,
            shape: primaryLFO.shape
        )
        let value = getLFOValue(tempLFO)

        switch parameter {
        case .amplitude:
            return 1.0 - (1.0 - value) * 0.15
        case .stereo:
            return value * targetState.musicalCharacteristics.spatialMovement * 0.5
        case .filter:
            return targetState.musicalCharacteristics.filterBrightness + value * 0.2
        case .reverb:
            return 0.3 + (value + 1) * 0.15
        case .tempo:
            return 1.0 + value * 0.02
        case .harmonic:
            return targetState.musicalCharacteristics.harmonicComplexity + value * 0.1
        }
    }

    public enum ModulationParameter: String, CaseIterable {
        case amplitude
        case stereo
        case filter
        case reverb
        case tempo
        case harmonic
    }
}

// MARK: - Entrainment-Aware Effects

/// Filter that breathes with the entrainment rhythm
public final class BreathingFilter {

    private var cutoffFrequency: Float = 1000
    private var resonance: Float = 0.5
    private var previousSample: Float = 0

    /// Base cutoff frequency (Hz)
    public var baseCutoff: Float = 2000

    /// Cutoff modulation range (Hz)
    public var modulationRange: Float = 1500

    /// Process with entrainment modulation
    public func process(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        filterModulation: Float
    ) {
        // Calculate current cutoff from modulation
        cutoffFrequency = baseCutoff + (filterModulation - 0.5) * modulationRange

        // Simple one-pole lowpass for demonstration
        let coefficient = exp(-2.0 * Float.pi * cutoffFrequency / 48000.0)

        for i in 0..<frameCount {
            let input = buffer[i]
            let output = previousSample + (1.0 - coefficient) * (input - previousSample)
            buffer[i] = output
            previousSample = output
        }
    }
}

/// Reverb that expands/contracts with entrainment
public final class BreathingReverb {

    private var decayTime: Float = 2.0
    private var wetDry: Float = 0.3

    /// Base reverb mix
    public var baseMix: Float = 0.2

    /// Process with entrainment modulation
    public func process(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        reverbModulation: Float
    ) {
        // Modulate wet/dry mix
        wetDry = baseMix + reverbModulation * 0.3

        // Actual reverb processing would go here
        // This is a placeholder for the concept
    }
}

// MARK: - Musical Tempo Entrainment

/// Aligns musical tempo to entrainment-friendly values
public struct TempoEntrainment {

    /// Calculate tempo that aligns with target brainwave frequency
    /// Based on musical subdivisions that create entrainment
    public static func alignedTempo(
        targetBrainwaveHz: Float,
        preferredSubdivision: Subdivision = .eighth
    ) -> Float {
        // Tempo in BPM = Brainwave Hz * 60 / subdivision factor
        let subdivisionFactor = preferredSubdivision.beatsPerMeasure

        var tempo = targetBrainwaveHz * 60.0 / subdivisionFactor

        // Ensure tempo is in musical range (40-200 BPM)
        while tempo < 40 { tempo *= 2 }
        while tempo > 200 { tempo /= 2 }

        return tempo
    }

    public enum Subdivision: Float, CaseIterable {
        case whole = 1
        case half = 2
        case quarter = 4
        case eighth = 8
        case sixteenth = 16

        var beatsPerMeasure: Float { rawValue }
    }

    /// Example calculations:
    /// - Alpha (10 Hz) + eighth notes = 10 * 60 / 8 = 75 BPM
    /// - Theta (6 Hz) + quarter notes = 6 * 60 / 4 = 90 BPM
    /// - Beta (15 Hz) + sixteenth notes = 15 * 60 / 16 = 56.25 BPM → doubled = 112.5 BPM
}

// MARK: - Integration with Existing Systems

public extension MusicalEntrainmentEngine {

    /// Generate modulation data for visual system
    func visualModulationData() -> VisualModulationData {
        VisualModulationData(
            pulseIntensity: (1.0 + amplitudeModulation) / 2.0,
            colorShift: currentPhase,
            particleSpeed: 0.5 + harmonicModulation * 0.5,
            bloomIntensity: reverbModulation,
            rotationSpeed: stereoPosition * 0.5
        )
    }

    struct VisualModulationData {
        public var pulseIntensity: Float
        public var colorShift: Float
        public var particleSpeed: Float
        public var bloomIntensity: Float
        public var rotationSpeed: Float
    }

    /// Generate modulation data for spatial audio
    func spatialModulationData() -> SpatialModulationData {
        SpatialModulationData(
            azimuth: stereoPosition * 45.0,  // ±45 degrees
            elevation: (harmonicModulation - 0.5) * 20.0,  // ±10 degrees
            distance: 1.0 + (1.0 - reverbModulation) * 0.5,
            spread: reverbModulation * 30.0
        )
    }

    struct SpatialModulationData {
        public var azimuth: Float       // Degrees
        public var elevation: Float     // Degrees
        public var distance: Float      // Relative
        public var spread: Float        // Degrees
    }
}

// MARK: - Scientific Disclaimer

public enum EntrainmentDisclaimer {
    public static let text = """
    SCIENTIFIC NOTICE
    ─────────────────────────────────────────────────────────────────

    Musical entrainment in Echoelmusic is based on peer-reviewed research
    on rhythm perception and neural oscillations. However:

    1. Brainwave entrainment through music is a wellness practice,
       NOT a medical treatment.

    2. Individual responses vary significantly. Not everyone experiences
       noticeable effects.

    3. Claims about specific brainwave states are based on EEG research
       averages and may not reflect your personal brain activity.

    4. If you have epilepsy or are sensitive to rhythmic stimuli,
       consult a healthcare provider before use.

    5. This is NOT a substitute for professional mental health care.

    References:
    • Thaut, M.H. (2005). Rhythm, Music, and the Brain. Routledge.
    • Nozaradan et al. (2011). J Neurosci 31(28):10234-10240.
    • Large & Palmer (2002). Cognitive Science 26(1):1-37.

    ─────────────────────────────────────────────────────────────────
    """
}
