import Foundation
import Accelerate

// MARK: - Psychosomatic Mapper
// Body-mind connection for audio-biofeedback integration
// References: Porges (2011), Thayer & Lane (2000), Critchley (2005)

/// PsychosomaticMapper: Maps bodily states to audio parameters and vice versa
/// Implements the bidirectional body-mind-sound connection
///
/// Scientific foundations:
/// - Porges, S.W. (2011). The Polyvagal Theory. Norton
/// - Thayer, J.F. & Lane, R.D. (2000). A model of neurovisceral integration. Journal of Affective Disorders
/// - Critchley, H.D. (2005). Neural mechanisms of autonomic, affective, and cognitive integration. J Comp Neurol
/// - Damasio, A.R. (1999). The Feeling of What Happens. Harcourt
/// - Craig, A.D. (2002). How do you feel? Interoception. Nature Reviews Neuroscience
public final class PsychosomaticMapper {

    // MARK: - Body State Types

    /// Autonomic nervous system state (Polyvagal Theory)
    public enum PolyvagalState: String, CaseIterable {
        case ventral = "Ventral Vagal"          // Social engagement, safe
        case sympathetic = "Sympathetic"         // Fight/flight, mobilized
        case dorsal = "Dorsal Vagal"            // Freeze, shutdown

        var description: String {
            switch self {
            case .ventral: return "Safe, socially engaged, calm but alert"
            case .sympathetic: return "Activated, mobilized, fight-or-flight ready"
            case .dorsal: return "Withdrawn, shutdown, conservation mode"
            }
        }

        /// Audio characteristics that support this state
        var audioCharacteristics: AudioCharacteristics {
            switch self {
            case .ventral:
                return AudioCharacteristics(
                    frequencyRange: (200, 4000),     // Human voice range
                    rhythm: .regular,
                    tempo: (60, 80),                  // Resting heart rate range
                    dynamics: .moderate,
                    prosody: .melodic,
                    harmonyType: .consonant
                )
            case .sympathetic:
                return AudioCharacteristics(
                    frequencyRange: (2000, 8000),    // Alerting frequencies
                    rhythm: .irregular,
                    tempo: (100, 140),
                    dynamics: .high,
                    prosody: .staccato,
                    harmonyType: .tense
                )
            case .dorsal:
                return AudioCharacteristics(
                    frequencyRange: (40, 200),       // Low, grounding frequencies
                    rhythm: .slow,
                    tempo: (40, 60),
                    dynamics: .low,
                    prosody: .monotone,
                    harmonyType: .simple
                )
            }
        }
    }

    /// Audio characteristics for polyvagal states
    public struct AudioCharacteristics {
        public var frequencyRange: (Float, Float)
        public var rhythm: RhythmType
        public var tempo: (Float, Float)
        public var dynamics: DynamicsLevel
        public var prosody: ProsodyType
        public var harmonyType: HarmonyType

        public enum RhythmType { case regular, irregular, slow }
        public enum DynamicsLevel { case low, moderate, high }
        public enum ProsodyType { case melodic, staccato, monotone }
        public enum HarmonyType { case consonant, tense, simple }
    }

    /// Comprehensive body state
    public struct BodyState {
        // Cardiovascular
        public var heartRate: Float = 70           // BPM
        public var heartRateVariability: Float = 50 // RMSSD in ms
        public var coherenceScore: Float = 0       // 0-100

        // Respiratory
        public var breathingRate: Float = 12      // Breaths per minute
        public var breathingDepth: Float = 0.5    // 0-1
        public var breathingPattern: BreathingPattern = .normal

        // Electrodermal
        public var skinConductance: Float = 0.5   // Normalized 0-1
        public var skinConductanceResponse: Float = 0 // Phasic SCR

        // Muscular
        public var muscularTension: Float = 0.3   // Normalized 0-1
        public var posture: PostureState = .neutral

        // Temperature
        public var peripheralTemperature: Float = 32 // Celsius (finger)

        // Movement
        public var movementLevel: Float = 0       // 0-1
        public var movementQuality: MovementQuality = .still

        // Derived states
        public var autonomicBalance: Float = 0    // -1 (parasympathetic) to +1 (sympathetic)
        public var stressLevel: Float = 0         // 0-1
        public var energyLevel: Float = 0.5       // 0-1
        public var relaxationDepth: Float = 0     // 0-1

        public init() {}
    }

    public enum BreathingPattern: String, CaseIterable {
        case normal = "Normal"
        case deep = "Deep Diaphragmatic"
        case shallow = "Shallow Chest"
        case coherent = "Coherent (6/min)"
        case held = "Breath Held"
        case sighing = "Sighing"
    }

    public enum PostureState: String, CaseIterable {
        case upright = "Upright"
        case relaxed = "Relaxed"
        case slouched = "Slouched"
        case tense = "Tense"
        case neutral = "Neutral"
    }

    public enum MovementQuality: String, CaseIterable {
        case still = "Still"
        case restless = "Restless"
        case flowing = "Flowing"
        case rhythmic = "Rhythmic"
        case erratic = "Erratic"
    }

    // MARK: - Somatic Audio Mapping

    /// Maps body parameters to audio parameters
    public struct SomaticAudioMap {
        // HRV → Audio mappings
        public var hrvToReverb: Float = 0.5       // High HRV = more space
        public var hrvToDelay: Float = 0.3
        public var hrvToModulation: Float = 0.4

        // Heart Rate → Audio
        public var hrToTempo: Float = 0.7
        public var hrToFilter: Float = 0.5
        public var hrToPulsing: Float = 0.8

        // Breathing → Audio
        public var breathToVolume: Float = 0.6
        public var breathToFilter: Float = 0.5
        public var breathToPitch: Float = 0.3

        // Skin conductance → Audio
        public var scrToIntensity: Float = 0.5
        public var scrToBrightness: Float = 0.6

        // Tension → Audio
        public var tensionToDissonance: Float = 0.4
        public var tensionToHarshness: Float = 0.5

        // Movement → Audio
        public var movementToEnergy: Float = 0.7
        public var movementToSpatial: Float = 0.5

        public init() {}
    }

    /// Interoceptive feedback configuration
    public struct InteroceptiveConfig {
        /// Heartbeat sonification
        public var heartbeatAudible: Bool = true
        public var heartbeatVolume: Float = 0.2
        public var heartbeatFrequency: Float = 60  // Base tone Hz

        /// Breathing guidance
        public var breathingGuideEnabled: Bool = true
        public var breathingGuideRate: Float = 6   // Target breaths/min
        public var breathingGuideVolume: Float = 0.3

        /// HRV feedback
        public var hrvFeedbackEnabled: Bool = true
        public var coherenceToneEnabled: Bool = true

        /// Stress alert
        public var stressAlertEnabled: Bool = true
        public var stressThreshold: Float = 0.7

        public init() {}
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Current body state
    public var bodyState = BodyState()

    /// Somatic-audio mapping
    public var mapping = SomaticAudioMap()

    /// Interoceptive configuration
    public var interoceptiveConfig = InteroceptiveConfig()

    /// Current polyvagal state
    public private(set) var polyvagalState: PolyvagalState = .ventral

    /// Smoothing factor for state transitions
    public var smoothingFactor: Float = 0.1

    // Processing state
    private var heartbeatPhase: Float = 0
    private var breathingPhase: Float = 0
    private var lastHeartbeatTime: Float = 0
    private var heartbeatEnvelope: Float = 0
    private var breathingEnvelope: Float = 0

    // State history for trend analysis
    private var stateHistory: [BodyState] = []
    private let maxHistorySize = 300  // 5 minutes at 1Hz

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - State Analysis

    /// Update body state and analyze
    public func updateState(_ newState: BodyState) {
        // Store in history
        stateHistory.append(newState)
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }

        // Smooth transition
        bodyState.heartRate = lerp(bodyState.heartRate, newState.heartRate, smoothingFactor)
        bodyState.heartRateVariability = lerp(bodyState.heartRateVariability, newState.heartRateVariability, smoothingFactor)
        bodyState.coherenceScore = lerp(bodyState.coherenceScore, newState.coherenceScore, smoothingFactor)
        bodyState.breathingRate = lerp(bodyState.breathingRate, newState.breathingRate, smoothingFactor)
        bodyState.skinConductance = lerp(bodyState.skinConductance, newState.skinConductance, smoothingFactor)
        bodyState.muscularTension = lerp(bodyState.muscularTension, newState.muscularTension, smoothingFactor)
        bodyState.movementLevel = lerp(bodyState.movementLevel, newState.movementLevel, smoothingFactor)

        // Copy discrete states
        bodyState.breathingPattern = newState.breathingPattern
        bodyState.posture = newState.posture
        bodyState.movementQuality = newState.movementQuality

        // Calculate derived states
        calculateDerivedStates()

        // Determine polyvagal state
        determinePolyvagalState()
    }

    /// Calculate derived states from raw measurements
    private func calculateDerivedStates() {
        // Autonomic balance: HRV indicates vagal tone
        // High HRV = parasympathetic, Low HRV = sympathetic dominance
        let hrvNormalized = min(1, bodyState.heartRateVariability / 100)
        let hrNormalized = (bodyState.heartRate - 60) / 60  // 60-120 BPM range

        bodyState.autonomicBalance = hrNormalized - hrvNormalized  // -1 to +1

        // Stress level: composite of multiple indicators
        let hrStress = max(0, (bodyState.heartRate - 80) / 40)
        let hrvStress = max(0, 1 - bodyState.heartRateVariability / 50)
        let scrStress = bodyState.skinConductance
        let tensionStress = bodyState.muscularTension

        bodyState.stressLevel = (hrStress + hrvStress + scrStress + tensionStress) / 4
        bodyState.stressLevel = min(1, max(0, bodyState.stressLevel))

        // Energy level
        let movementEnergy = bodyState.movementLevel
        let hrEnergy = (bodyState.heartRate - 50) / 100
        let breathEnergy = bodyState.breathingRate / 20

        bodyState.energyLevel = (movementEnergy + hrEnergy + breathEnergy) / 3
        bodyState.energyLevel = min(1, max(0, bodyState.energyLevel))

        // Relaxation depth
        let coherenceRelax = bodyState.coherenceScore / 100
        let hrvRelax = min(1, bodyState.heartRateVariability / 80)
        let breathRelax = bodyState.breathingPattern == .coherent || bodyState.breathingPattern == .deep ? 0.8 : 0.3

        bodyState.relaxationDepth = (coherenceRelax + hrvRelax + breathRelax) / 3
        bodyState.relaxationDepth = min(1, max(0, bodyState.relaxationDepth))
    }

    /// Determine polyvagal state from body measurements
    private func determinePolyvagalState() {
        // Porges' Polyvagal Theory hierarchy
        // Ventral vagal: high HRV, normal HR, relaxed muscles
        // Sympathetic: low HRV, high HR, tense muscles
        // Dorsal vagal: very low HRV, low HR, collapse

        let hrv = bodyState.heartRateVariability
        let hr = bodyState.heartRate
        let tension = bodyState.muscularTension

        if hr < 55 && hrv < 20 && tension < 0.2 {
            // Very low HR, very low HRV, low tone = dorsal shutdown
            polyvagalState = .dorsal
        } else if hr > 90 || hrv < 30 || tension > 0.6 {
            // High HR, low HRV, high tension = sympathetic activation
            polyvagalState = .sympathetic
        } else {
            // Normal range = ventral vagal safety
            polyvagalState = .ventral
        }
    }

    // MARK: - Audio Processing

    /// Process audio with somatic modulation
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let samplesPerSecond = sampleRate

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Apply HRV-based reverb/space (simplified as echo)
            let hrvAmount = bodyState.heartRateVariability / 100 * mapping.hrvToReverb
            // (Full reverb would need delay buffer)

            // Apply heart rate pulsing
            if mapping.hrToPulsing > 0 {
                let pulseFreq = bodyState.heartRate / 60  // Hz
                let pulsePhase = heartbeatPhase
                let pulse = 1.0 - mapping.hrToPulsing * 0.3 * (1 - sin(pulsePhase))
                sample *= pulse
            }

            // Apply breathing modulation
            if mapping.breathToVolume > 0 {
                let breathFreq = bodyState.breathingRate / 60  // Hz
                let breathMod = 1.0 - mapping.breathToVolume * 0.2 * (1 - sin(breathingPhase))
                sample *= breathMod
            }

            // Apply tension → harshness (soft saturation based on tension)
            if bodyState.muscularTension > 0.5 && mapping.tensionToHarshness > 0 {
                let harshness = (bodyState.muscularTension - 0.5) * 2 * mapping.tensionToHarshness
                sample = tanh(sample * (1 + harshness * 2))
            }

            // Update phases
            heartbeatPhase += (bodyState.heartRate / 60) / samplesPerSecond * 2 * .pi
            breathingPhase += (bodyState.breathingRate / 60) / samplesPerSecond * 2 * .pi

            if heartbeatPhase > 2 * .pi { heartbeatPhase -= 2 * .pi }
            if breathingPhase > 2 * .pi { breathingPhase -= 2 * .pi }

            buffer[i] = sample
        }

        // Add interoceptive feedback
        if interoceptiveConfig.heartbeatAudible || interoceptiveConfig.breathingGuideEnabled {
            addInteroceptiveFeedback(buffer: buffer, frameCount: frameCount)
        }
    }

    /// Add interoceptive feedback sounds
    private func addInteroceptiveFeedback(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            var feedbackSample: Float = 0

            // Heartbeat sound
            if interoceptiveConfig.heartbeatAudible {
                // Generate heartbeat at current HR
                let heartPeriod = 60.0 / bodyState.heartRate * sampleRate
                let heartPhaseNorm = heartbeatPhase / (2 * .pi)

                // Two-phase heartbeat (lub-dub)
                if heartPhaseNorm < 0.1 {
                    // Lub
                    let t = heartPhaseNorm / 0.1
                    feedbackSample += sin(t * .pi) * sin(2 * .pi * interoceptiveConfig.heartbeatFrequency * heartPhaseNorm)
                        * interoceptiveConfig.heartbeatVolume
                } else if heartPhaseNorm > 0.15 && heartPhaseNorm < 0.25 {
                    // Dub
                    let t = (heartPhaseNorm - 0.15) / 0.1
                    feedbackSample += sin(t * .pi) * sin(2 * .pi * interoceptiveConfig.heartbeatFrequency * 0.8 * heartPhaseNorm)
                        * interoceptiveConfig.heartbeatVolume * 0.7
                }
            }

            // Breathing guide
            if interoceptiveConfig.breathingGuideEnabled {
                let breathFreq = interoceptiveConfig.breathingGuideRate / 60  // Hz
                let breathPhaseNorm = fmod(breathingPhase, 2 * .pi) / (2 * .pi)

                // Inhale (rising pitch) first half, Exhale (falling pitch) second half
                let guideFreq: Float
                if breathPhaseNorm < 0.5 {
                    // Inhale
                    guideFreq = 200 + breathPhaseNorm * 200
                } else {
                    // Exhale
                    guideFreq = 300 - (breathPhaseNorm - 0.5) * 200
                }

                let guidePhase = Float(i) * guideFreq / sampleRate * 2 * .pi
                feedbackSample += sin(guidePhase) * interoceptiveConfig.breathingGuideVolume * 0.3
            }

            // Coherence tone (when coherent)
            if interoceptiveConfig.coherenceToneEnabled && bodyState.coherenceScore > 50 {
                let coherenceAmount = (bodyState.coherenceScore - 50) / 50
                let coherenceFreq: Float = 528  // "Love frequency" / Solfeggio
                let coherencePhase = Float(i) * coherenceFreq / sampleRate * 2 * .pi
                feedbackSample += sin(coherencePhase) * coherenceAmount * 0.1
            }

            buffer[i] += feedbackSample
        }
    }

    // MARK: - Audio Parameter Generation

    /// Generate audio parameters from current body state
    public func generateAudioParameters() -> AudioParameters {
        var params = AudioParameters()

        // Base parameters from polyvagal state
        let characteristics = polyvagalState.audioCharacteristics

        // Tempo from heart rate (with mapping)
        params.tempo = bodyState.heartRate * mapping.hrToTempo +
                      (1 - mapping.hrToTempo) * (characteristics.tempo.0 + characteristics.tempo.1) / 2

        // Filter from multiple sources
        let hrvFilter = bodyState.heartRateVariability / 100 * mapping.hrvToFilter
        let breathFilter = (sin(breathingPhase) + 1) / 2 * mapping.breathToFilter
        params.filterCutoff = 500 + (hrvFilter + breathFilter) * 4000

        // Reverb/space from HRV
        params.reverbAmount = bodyState.heartRateVariability / 100 * mapping.hrvToReverb

        // Modulation depth from HRV
        params.modulationDepth = bodyState.heartRateVariability / 100 * mapping.hrvToModulation

        // Intensity from skin conductance
        params.intensity = 0.5 + (bodyState.skinConductance - 0.5) * mapping.scrToIntensity

        // Brightness from SCR
        params.brightness = 0.5 + bodyState.skinConductanceResponse * mapping.scrToBrightness

        // Dissonance from tension
        params.dissonance = bodyState.muscularTension * mapping.tensionToDissonance

        // Energy from movement
        params.energy = bodyState.movementLevel * mapping.movementToEnergy

        // Spatial from movement
        params.spatialWidth = 0.5 + (bodyState.movementLevel - 0.5) * mapping.movementToSpatial

        return params
    }

    /// Audio parameters generated from body state
    public struct AudioParameters {
        public var tempo: Float = 100
        public var filterCutoff: Float = 2000
        public var reverbAmount: Float = 0.3
        public var modulationDepth: Float = 0.3
        public var intensity: Float = 0.5
        public var brightness: Float = 0.5
        public var dissonance: Float = 0
        public var energy: Float = 0.5
        public var spatialWidth: Float = 0.5

        public init() {}
    }

    // MARK: - Trend Analysis

    /// Analyze trends in body state
    public func analyzeTrends() -> TrendAnalysis {
        guard stateHistory.count >= 10 else {
            return TrendAnalysis()
        }

        var analysis = TrendAnalysis()

        // Calculate trends from recent vs older data
        let recentCount = min(30, stateHistory.count / 3)
        let recent = Array(stateHistory.suffix(recentCount))
        let older = Array(stateHistory.prefix(stateHistory.count - recentCount))

        // HR trend
        let recentHR = recent.map { $0.heartRate }.reduce(0, +) / Float(recent.count)
        let olderHR = older.map { $0.heartRate }.reduce(0, +) / Float(older.count)
        analysis.heartRateTrend = (recentHR - olderHR) / olderHR

        // HRV trend
        let recentHRV = recent.map { $0.heartRateVariability }.reduce(0, +) / Float(recent.count)
        let olderHRV = older.map { $0.heartRateVariability }.reduce(0, +) / Float(older.count)
        analysis.hrvTrend = (recentHRV - olderHRV) / max(1, olderHRV)

        // Stress trend
        let recentStress = recent.map { $0.stressLevel }.reduce(0, +) / Float(recent.count)
        let olderStress = older.map { $0.stressLevel }.reduce(0, +) / Float(older.count)
        analysis.stressTrend = recentStress - olderStress

        // Relaxation trend
        let recentRelax = recent.map { $0.relaxationDepth }.reduce(0, +) / Float(recent.count)
        let olderRelax = older.map { $0.relaxationDepth }.reduce(0, +) / Float(older.count)
        analysis.relaxationTrend = recentRelax - olderRelax

        // Overall direction
        if analysis.stressTrend < -0.1 && analysis.hrvTrend > 0 {
            analysis.overallDirection = .improving
        } else if analysis.stressTrend > 0.1 && analysis.hrvTrend < 0 {
            analysis.overallDirection = .declining
        } else {
            analysis.overallDirection = .stable
        }

        return analysis
    }

    /// Trend analysis results
    public struct TrendAnalysis {
        public var heartRateTrend: Float = 0
        public var hrvTrend: Float = 0
        public var stressTrend: Float = 0
        public var relaxationTrend: Float = 0
        public var overallDirection: Direction = .stable

        public enum Direction: String {
            case improving = "Improving"
            case stable = "Stable"
            case declining = "Declining"
        }
    }

    // MARK: - Utility

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    /// Reset state
    public func reset() {
        bodyState = BodyState()
        stateHistory.removeAll()
        heartbeatPhase = 0
        breathingPhase = 0
    }

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
    }
}

// MARK: - Somatic Presets

extension PsychosomaticMapper {

    /// Preset somatic-audio mappings
    public enum SomaticPreset: String, CaseIterable {
        case meditation = "Meditation"
        case energizing = "Energizing"
        case focus = "Focus"
        case sleep = "Sleep Preparation"
        case stressRelief = "Stress Relief"
        case bodyAwareness = "Body Awareness"
        case performance = "Performance"
        case healing = "Healing"

        public func apply(to mapper: PsychosomaticMapper) {
            switch self {
            case .meditation:
                mapper.mapping.hrvToReverb = 0.8
                mapper.mapping.breathToVolume = 0.7
                mapper.mapping.hrToPulsing = 0.3
                mapper.interoceptiveConfig.breathingGuideEnabled = true
                mapper.interoceptiveConfig.breathingGuideRate = 6
                mapper.interoceptiveConfig.coherenceToneEnabled = true

            case .energizing:
                mapper.mapping.hrToTempo = 0.9
                mapper.mapping.movementToEnergy = 0.9
                mapper.mapping.scrToIntensity = 0.7
                mapper.interoceptiveConfig.breathingGuideEnabled = false
                mapper.interoceptiveConfig.heartbeatAudible = true

            case .focus:
                mapper.mapping.hrvToModulation = 0.5
                mapper.mapping.tensionToDissonance = 0.2
                mapper.interoceptiveConfig.heartbeatAudible = false
                mapper.interoceptiveConfig.breathingGuideEnabled = false
                mapper.interoceptiveConfig.stressAlertEnabled = true

            case .sleep:
                mapper.mapping.hrvToReverb = 0.9
                mapper.mapping.breathToVolume = 0.8
                mapper.mapping.hrToPulsing = 0.5
                mapper.interoceptiveConfig.breathingGuideEnabled = true
                mapper.interoceptiveConfig.breathingGuideRate = 4
                mapper.interoceptiveConfig.heartbeatVolume = 0.1

            case .stressRelief:
                mapper.mapping.hrvToReverb = 0.7
                mapper.mapping.tensionToHarshness = 0.1  // Reduce harsh sounds
                mapper.mapping.breathToFilter = 0.6
                mapper.interoceptiveConfig.breathingGuideEnabled = true
                mapper.interoceptiveConfig.coherenceToneEnabled = true
                mapper.interoceptiveConfig.stressAlertEnabled = true

            case .bodyAwareness:
                mapper.mapping.hrvToReverb = 0.5
                mapper.mapping.breathToVolume = 0.9
                mapper.mapping.hrToPulsing = 0.8
                mapper.interoceptiveConfig.heartbeatAudible = true
                mapper.interoceptiveConfig.heartbeatVolume = 0.4
                mapper.interoceptiveConfig.breathingGuideEnabled = true

            case .performance:
                mapper.mapping.hrToTempo = 0.6
                mapper.mapping.movementToEnergy = 0.8
                mapper.mapping.hrvToModulation = 0.4
                mapper.interoceptiveConfig.stressAlertEnabled = true
                mapper.interoceptiveConfig.stressThreshold = 0.8

            case .healing:
                mapper.mapping.hrvToReverb = 0.9
                mapper.mapping.breathToVolume = 0.6
                mapper.mapping.tensionToDissonance = 0
                mapper.mapping.tensionToHarshness = 0
                mapper.interoceptiveConfig.coherenceToneEnabled = true
                mapper.interoceptiveConfig.breathingGuideRate = 5
            }
        }
    }

    /// Apply somatic preset
    public func applyPreset(_ preset: SomaticPreset) {
        preset.apply(to: self)
    }
}
