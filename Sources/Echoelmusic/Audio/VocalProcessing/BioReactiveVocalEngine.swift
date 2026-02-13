import Foundation
import Accelerate
import Combine

/// Bio-Reactive Vocal Engine — Biometric Modulation of Vocal Processing
///
/// The unique Echoelmusic layer that NO competitor has.
/// Maps biometric signals (HRV, coherence, breathing, heart rate)
/// to vocal processing parameters in real-time.
///
/// Bio-Reactive Mappings:
/// - **Coherence → Pitch Correction**: High coherence = stricter correction, low = more natural
/// - **Coherence → Vibrato**: High = smooth/regular, low = irregular/tense
/// - **Heart Rate → Processing Intensity**: Elevated HR = more dramatic effects
/// - **Breathing Phase → Formant Modulation**: Inhale/exhale shapes vocal timbre
/// - **HRV → Spatial Width**: High HRV = wider stereo, low = more focused
/// - **Coherence → Harmonic Richness**: High = warm overtones, low = raw/edgy
///
/// This creates vocals that literally breathe with the performer.
@MainActor
class BioReactiveVocalEngine: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentMappings: BioVocalMappings = .default()
    @Published var bioState: BioState = BioState()
    @Published var modulationValues: ModulationValues = ModulationValues()

    // MARK: - Types

    /// Current biometric state
    struct BioState {
        var coherence: Float = 50.0       // 0-100 (from UnifiedHealthKitEngine)
        var heartRate: Float = 72.0       // BPM
        var hrv: Float = 45.0             // SDNN in ms
        var breathingRate: Float = 14.0   // BPM
        var breathPhase: Float = 0.5      // 0-1 (0 = start inhale, 0.5 = start exhale)
        var stressLevel: Float = 0.3      // 0-1 (derived from HRV/coherence)
        var relaxationLevel: Float = 0.7  // 0-1 (inverse of stress, smoothed)
    }

    /// Mapping configuration: which bio signal maps to which vocal parameter
    struct BioVocalMappings {
        // Pitch correction mappings
        var coherenceToCorrectionSpeed: MappingCurve
        var coherenceToCorrectionStrength: MappingCurve

        // Vibrato mappings
        var coherenceToVibratoRegularity: MappingCurve
        var heartRateToVibratoRate: MappingCurve
        var breathingToVibratoDepth: MappingCurve
        var stressToVibratoTension: MappingCurve

        // Formant mappings
        var breathPhaseToFormant: MappingCurve
        var coherenceToFormantWarmth: MappingCurve

        // Effect mappings
        var hrvToSpatialWidth: MappingCurve
        var coherenceToHarmonics: MappingCurve
        var heartRateToEffectIntensity: MappingCurve
        var breathPhaseToVolume: MappingCurve

        // Master sensitivity (0 = no bio-reactive, 1 = full)
        var sensitivity: Float

        static func `default`() -> BioVocalMappings {
            BioVocalMappings(
                coherenceToCorrectionSpeed: MappingCurve(
                    inputRange: 0...100, outputRange: 20...200,
                    curve: .inverseLinear, label: "Coherence → Correction Speed"
                ),
                coherenceToCorrectionStrength: MappingCurve(
                    inputRange: 0...100, outputRange: 0.3...1.0,
                    curve: .linear, label: "Coherence → Correction Strength"
                ),
                coherenceToVibratoRegularity: MappingCurve(
                    inputRange: 0...100, outputRange: 0...1,
                    curve: .sCurve, label: "Coherence → Vibrato Regularity"
                ),
                heartRateToVibratoRate: MappingCurve(
                    inputRange: 50...120, outputRange: 4.5...7.0,
                    curve: .linear, label: "Heart Rate → Vibrato Rate"
                ),
                breathingToVibratoDepth: MappingCurve(
                    inputRange: 6...20, outputRange: 60...20,
                    curve: .inverseLinear, label: "Breathing → Vibrato Depth"
                ),
                stressToVibratoTension: MappingCurve(
                    inputRange: 0...1, outputRange: 0...0.5,
                    curve: .exponential, label: "Stress → Vibrato Tension"
                ),
                breathPhaseToFormant: MappingCurve(
                    inputRange: 0...1, outputRange: -1...1,
                    curve: .sine, label: "Breath Phase → Formant"
                ),
                coherenceToFormantWarmth: MappingCurve(
                    inputRange: 0...100, outputRange: 0...1,
                    curve: .linear, label: "Coherence → Formant Warmth"
                ),
                hrvToSpatialWidth: MappingCurve(
                    inputRange: 10...100, outputRange: 0.3...1.5,
                    curve: .logarithmic, label: "HRV → Spatial Width"
                ),
                coherenceToHarmonics: MappingCurve(
                    inputRange: 0...100, outputRange: 0...0.6,
                    curve: .sCurve, label: "Coherence → Harmonics"
                ),
                heartRateToEffectIntensity: MappingCurve(
                    inputRange: 50...140, outputRange: 0.2...1.0,
                    curve: .linear, label: "Heart Rate → Effect Intensity"
                ),
                breathPhaseToVolume: MappingCurve(
                    inputRange: 0...1, outputRange: 0.85...1.0,
                    curve: .sine, label: "Breath Phase → Volume"
                ),
                sensitivity: 0.7
            )
        }

        /// Preset: Meditation mode (calm, smooth, wide)
        static func meditation() -> BioVocalMappings {
            var m = BioVocalMappings.default()
            m.sensitivity = 0.9
            m.coherenceToCorrectionStrength = MappingCurve(
                inputRange: 0...100, outputRange: 0.5...1.0,
                curve: .sCurve, label: "Coherence → Correction"
            )
            m.coherenceToHarmonics = MappingCurve(
                inputRange: 0...100, outputRange: 0.2...0.8,
                curve: .sCurve, label: "Coherence → Harmonics"
            )
            return m
        }

        /// Preset: Performance mode (responsive, dramatic)
        static func performance() -> BioVocalMappings {
            var m = BioVocalMappings.default()
            m.sensitivity = 1.0
            m.heartRateToEffectIntensity = MappingCurve(
                inputRange: 60...160, outputRange: 0.3...1.0,
                curve: .exponential, label: "Heart Rate → Intensity"
            )
            return m
        }

        /// Preset: Subtle mode (minimal bio modulation)
        static func subtle() -> BioVocalMappings {
            var m = BioVocalMappings.default()
            m.sensitivity = 0.3
            return m
        }
    }

    /// Mapping curve between bio input and vocal parameter
    struct MappingCurve {
        var inputRange: ClosedRange<Float>
        var outputRange: ClosedRange<Float>
        var curve: CurveType
        var label: String
        var inverted: Bool = false

        enum CurveType {
            case linear
            case inverseLinear
            case exponential
            case logarithmic
            case sCurve
            case sine
        }

        /// Map an input value through this curve
        func map(_ input: Float) -> Float {
            // Normalize input to 0-1
            let rangeSize = inputRange.upperBound - inputRange.lowerBound
            guard rangeSize > 0 else { return outputRange.lowerBound }
            let normalized = (input.clamped(to: inputRange) - inputRange.lowerBound) / rangeSize

            // Apply curve shape
            let curved: Float
            switch curve {
            case .linear:
                curved = normalized
            case .inverseLinear:
                curved = 1.0 - normalized
            case .exponential:
                curved = normalized * normalized
            case .logarithmic:
                curved = sqrt(normalized)
            case .sCurve:
                // Smoothstep
                curved = normalized * normalized * (3.0 - 2.0 * normalized)
            case .sine:
                curved = sin(normalized * Float.pi)
            }

            let final = inverted ? (1.0 - curved) : curved

            // Map to output range
            let outSize = outputRange.upperBound - outputRange.lowerBound
            return outputRange.lowerBound + final * outSize
        }
    }

    /// Current modulation output values (what's actually being applied)
    struct ModulationValues {
        var correctionSpeed: Float = 50.0
        var correctionStrength: Float = 0.8
        var vibratoRate: Float = 5.5
        var vibratoDepth: Float = 40.0
        var vibratoRegularity: Float = 0.5
        var formantShift: Float = 0.0
        var formantWarmth: Float = 0.5
        var spatialWidth: Float = 1.0
        var harmonicRichness: Float = 0.3
        var effectIntensity: Float = 0.5
        var volumeModulation: Float = 1.0
    }

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var smoothingAlpha: Float = 0.1  // Smoothing factor for bio changes

    // Smoothed values (prevent jumpy modulation)
    private var smoothedCoherence: Float = 50
    private var smoothedHeartRate: Float = 72
    private var smoothedHRV: Float = 45
    private var smoothedBreathPhase: Float = 0.5
    private var smoothedStress: Float = 0.3

    // MARK: - Initialization

    init() {}

    // MARK: - Bio Data Update

    /// Update biometric state from HealthKit/sensors
    /// Call this at regular intervals (e.g., 10-60 Hz)
    func updateBioState(_ state: BioState) {
        self.bioState = state

        guard isActive else { return }

        // Smooth bio signals to prevent jumpy modulation
        smoothedCoherence += (state.coherence - smoothedCoherence) * smoothingAlpha
        smoothedHeartRate += (state.heartRate - smoothedHeartRate) * smoothingAlpha
        smoothedHRV += (state.hrv - smoothedHRV) * smoothingAlpha
        smoothedBreathPhase = state.breathPhase  // Breath phase should be responsive
        smoothedStress += (state.stressLevel - smoothedStress) * smoothingAlpha

        // Calculate all modulation values
        recalculateModulations()
    }

    /// Recalculate all modulation values from current bio state
    private func recalculateModulations() {
        let m = currentMappings
        let s = m.sensitivity

        // Pitch correction
        let rawCorrSpeed = m.coherenceToCorrectionSpeed.map(smoothedCoherence)
        modulationValues.correctionSpeed = mix(50.0, rawCorrSpeed, amount: s)

        let rawCorrStrength = m.coherenceToCorrectionStrength.map(smoothedCoherence)
        modulationValues.correctionStrength = mix(0.8, rawCorrStrength, amount: s)

        // Vibrato
        let rawVibRate = m.heartRateToVibratoRate.map(smoothedHeartRate)
        modulationValues.vibratoRate = mix(5.5, rawVibRate, amount: s)

        let rawVibDepth = m.breathingToVibratoDepth.map(bioState.breathingRate)
        modulationValues.vibratoDepth = mix(40.0, rawVibDepth, amount: s)

        let rawVibReg = m.coherenceToVibratoRegularity.map(smoothedCoherence)
        modulationValues.vibratoRegularity = mix(0.5, rawVibReg, amount: s)

        // Formant
        let rawFormant = m.breathPhaseToFormant.map(smoothedBreathPhase)
        modulationValues.formantShift = mix(0.0, rawFormant, amount: s * 0.5)

        let rawWarmth = m.coherenceToFormantWarmth.map(smoothedCoherence)
        modulationValues.formantWarmth = mix(0.5, rawWarmth, amount: s)

        // Effects
        let rawWidth = m.hrvToSpatialWidth.map(smoothedHRV)
        modulationValues.spatialWidth = mix(1.0, rawWidth, amount: s)

        let rawHarmonics = m.coherenceToHarmonics.map(smoothedCoherence)
        modulationValues.harmonicRichness = mix(0.3, rawHarmonics, amount: s)

        let rawIntensity = m.heartRateToEffectIntensity.map(smoothedHeartRate)
        modulationValues.effectIntensity = mix(0.5, rawIntensity, amount: s)

        let rawVolume = m.breathPhaseToVolume.map(smoothedBreathPhase)
        modulationValues.volumeModulation = mix(1.0, rawVolume, amount: s)
    }

    /// Linear mix between default and modulated value
    private func mix(_ defaultVal: Float, _ modulated: Float, amount: Float) -> Float {
        return defaultVal + (modulated - defaultVal) * amount
    }

    // MARK: - Apply to Vocal Processing

    /// Apply bio-reactive modulations to a pitch corrector
    func applyToPitchCorrector(_ corrector: RealTimePitchCorrector) {
        guard isActive else { return }
        corrector.correctionSpeed = modulationValues.correctionSpeed
        corrector.correctionStrength = modulationValues.correctionStrength
        corrector.vibratoDepth = modulationValues.vibratoDepth
        corrector.vibratoRate = modulationValues.vibratoRate
    }

    /// Apply bio-reactive modulations to vibrato parameters
    func applyToVibratoParams(_ params: inout VibratoEngine.VibratoParameters) {
        guard isActive else { return }
        params.rate = modulationValues.vibratoRate
        params.depth = modulationValues.vibratoDepth
        params.rateVariation = 1.0 - modulationValues.vibratoRegularity
    }

    /// Process audio with bio-reactive volume/warmth modulation
    nonisolated func processAudio(_ input: [Float], modValues: ModulationValues) -> [Float] {
        var output = input

        // Volume modulation (breath-synced)
        if abs(modValues.volumeModulation - 1.0) > 0.01 {
            var vol = modValues.volumeModulation
            vDSP_vsmul(output, 1, &vol, &output, 1, vDSP_Length(output.count))
        }

        // Harmonic warmth (subtle saturation based on coherence)
        if modValues.harmonicRichness > 0.05 {
            let amount = modValues.harmonicRichness
            for i in 0..<output.count {
                // Soft saturation proportional to harmonic richness
                let x = output[i]
                let saturated = tanh(x * (1.0 + amount * 2.0)) / (1.0 + amount)
                output[i] = x * (1.0 - amount) + saturated * amount
            }
        }

        return output
    }

    // MARK: - Preset Management

    func loadPreset(_ preset: MappingPreset) {
        switch preset {
        case .default:
            currentMappings = .default()
        case .meditation:
            currentMappings = .meditation()
        case .performance:
            currentMappings = .performance()
        case .subtle:
            currentMappings = .subtle()
        }
    }

    enum MappingPreset: String, CaseIterable, Identifiable {
        case `default` = "Default"
        case meditation = "Meditation"
        case performance = "Performance"
        case subtle = "Subtle"

        var id: String { rawValue }
    }

    // MARK: - State Machine

    func start() {
        isActive = true
        log.log(.info, category: .audio, "BioReactiveVocalEngine: Started")
    }

    func stop() {
        isActive = false
        log.log(.info, category: .audio, "BioReactiveVocalEngine: Stopped")
    }
}
