import Foundation
import Accelerate

// MARK: - Emotional Resonance System
// Multi-modal emotion detection and audio-emotional response
// References: Picard (1997), Scherer (2005), Juslin (2013)

/// EmotionalResonanceSystem: Detects emotional state and creates resonant audio response
/// Integrates multiple input modalities to infer emotional state and respond musically
///
/// Scientific foundations:
/// - Picard, R.W. (1997). Affective Computing. MIT Press
/// - Scherer, K.R. (2005). What are emotions? Social Science Information
/// - Juslin, P.N. (2013). From everyday emotions to aesthetic emotions. Physics of Life Reviews
/// - Ekman, P. (1992). An argument for basic emotions. Cognition & Emotion
/// - Barrett, L.F. (2017). How Emotions Are Made. Houghton Mifflin
public final class EmotionalResonanceSystem {

    // MARK: - Emotion Models

    /// Discrete emotion categories (Ekman's basic emotions + extensions)
    public enum DiscreteEmotion: String, CaseIterable {
        // Basic 6 (Ekman)
        case happiness = "Happiness"
        case sadness = "Sadness"
        case anger = "Anger"
        case fear = "Fear"
        case surprise = "Surprise"
        case disgust = "Disgust"

        // Extended emotions
        case contempt = "Contempt"
        case love = "Love"
        case awe = "Awe"
        case pride = "Pride"
        case shame = "Shame"
        case guilt = "Guilt"
        case envy = "Envy"
        case gratitude = "Gratitude"
        case hope = "Hope"
        case nostalgia = "Nostalgia"
        case serenity = "Serenity"
        case interest = "Interest"
        case amusement = "Amusement"
        case ecstasy = "Ecstasy"
        case anxiety = "Anxiety"
        case boredom = "Boredom"
        case confusion = "Confusion"
        case neutral = "Neutral"

        /// Musical characteristics for this emotion
        var musicalCharacteristics: MusicalEmotionProfile {
            switch self {
            case .happiness:
                return MusicalEmotionProfile(
                    mode: .major,
                    tempo: (100, 140),
                    dynamics: .loud,
                    articulation: .staccato,
                    pitch: .high,
                    timbre: .bright,
                    rhythm: .regular,
                    harmony: .consonant
                )
            case .sadness:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (40, 70),
                    dynamics: .soft,
                    articulation: .legato,
                    pitch: .low,
                    timbre: .dark,
                    rhythm: .slow,
                    harmony: .consonant
                )
            case .anger:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (120, 160),
                    dynamics: .loud,
                    articulation: .marcato,
                    pitch: .low,
                    timbre: .harsh,
                    rhythm: .irregular,
                    harmony: .dissonant
                )
            case .fear:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (100, 140),
                    dynamics: .variable,
                    articulation: .staccato,
                    pitch: .high,
                    timbre: .harsh,
                    rhythm: .irregular,
                    harmony: .dissonant
                )
            case .surprise:
                return MusicalEmotionProfile(
                    mode: .major,
                    tempo: (100, 130),
                    dynamics: .sudden,
                    articulation: .accented,
                    pitch: .high,
                    timbre: .bright,
                    rhythm: .syncopated,
                    harmony: .complex
                )
            case .disgust:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (60, 90),
                    dynamics: .soft,
                    articulation: .legato,
                    pitch: .low,
                    timbre: .harsh,
                    rhythm: .slow,
                    harmony: .dissonant
                )
            case .love:
                return MusicalEmotionProfile(
                    mode: .major,
                    tempo: (60, 90),
                    dynamics: .soft,
                    articulation: .legato,
                    pitch: .medium,
                    timbre: .warm,
                    rhythm: .flowing,
                    harmony: .rich
                )
            case .awe:
                return MusicalEmotionProfile(
                    mode: .major,
                    tempo: (50, 80),
                    dynamics: .crescendo,
                    articulation: .sustained,
                    pitch: .wide,
                    timbre: .bright,
                    rhythm: .slow,
                    harmony: .rich
                )
            case .serenity:
                return MusicalEmotionProfile(
                    mode: .major,
                    tempo: (50, 70),
                    dynamics: .soft,
                    articulation: .legato,
                    pitch: .medium,
                    timbre: .warm,
                    rhythm: .regular,
                    harmony: .simple
                )
            case .anxiety:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (80, 120),
                    dynamics: .variable,
                    articulation: .staccato,
                    pitch: .high,
                    timbre: .thin,
                    rhythm: .irregular,
                    harmony: .tense
                )
            case .nostalgia:
                return MusicalEmotionProfile(
                    mode: .minor,
                    tempo: (60, 80),
                    dynamics: .soft,
                    articulation: .legato,
                    pitch: .medium,
                    timbre: .warm,
                    rhythm: .regular,
                    harmony: .bittersweet
                )
            default:
                return MusicalEmotionProfile(
                    mode: .neutral,
                    tempo: (80, 100),
                    dynamics: .moderate,
                    articulation: .normal,
                    pitch: .medium,
                    timbre: .neutral,
                    rhythm: .regular,
                    harmony: .simple
                )
            }
        }
    }

    /// Musical characteristics profile
    public struct MusicalEmotionProfile {
        public var mode: Mode
        public var tempo: (Float, Float)
        public var dynamics: Dynamics
        public var articulation: Articulation
        public var pitch: PitchRange
        public var timbre: Timbre
        public var rhythm: RhythmType
        public var harmony: HarmonyType

        public enum Mode { case major, minor, neutral }
        public enum Dynamics { case soft, moderate, loud, variable, sudden, crescendo }
        public enum Articulation { case legato, staccato, marcato, accented, sustained, normal }
        public enum PitchRange { case low, medium, high, wide }
        public enum Timbre { case bright, dark, warm, harsh, thin, neutral }
        public enum RhythmType { case slow, regular, fast, irregular, syncopated, flowing }
        public enum HarmonyType { case simple, consonant, dissonant, rich, tense, complex, bittersweet }
    }

    /// Dimensional emotion model (Valence-Arousal-Dominance)
    public struct DimensionalEmotion {
        /// Pleasantness: negative (-1) to positive (+1)
        public var valence: Float = 0

        /// Activation: calm (-1) to excited (+1)
        public var arousal: Float = 0

        /// Power: weak (-1) to strong (+1)
        public var dominance: Float = 0

        public init(valence: Float = 0, arousal: Float = 0, dominance: Float = 0) {
            self.valence = max(-1, min(1, valence))
            self.arousal = max(-1, min(1, arousal))
            self.dominance = max(-1, min(1, dominance))
        }

        /// Convert to closest discrete emotion
        public func toDiscrete() -> DiscreteEmotion {
            // Map VAD space to discrete emotions
            if valence > 0.3 && arousal > 0.3 {
                return arousal > 0.7 ? .ecstasy : .happiness
            } else if valence > 0.3 && arousal < -0.3 {
                return .serenity
            } else if valence < -0.3 && arousal > 0.3 {
                return dominance > 0 ? .anger : .fear
            } else if valence < -0.3 && arousal < -0.3 {
                return .sadness
            } else if arousal > 0.5 && abs(valence) < 0.3 {
                return .surprise
            } else if valence > 0.5 && dominance < -0.3 {
                return .awe
            } else if valence > 0.3 && arousal < 0 && dominance < 0 {
                return .love
            } else {
                return .neutral
            }
        }

        /// Create from discrete emotion
        public static func from(_ emotion: DiscreteEmotion) -> DimensionalEmotion {
            switch emotion {
            case .happiness: return DimensionalEmotion(valence: 0.8, arousal: 0.5, dominance: 0.5)
            case .sadness: return DimensionalEmotion(valence: -0.7, arousal: -0.4, dominance: -0.5)
            case .anger: return DimensionalEmotion(valence: -0.6, arousal: 0.7, dominance: 0.6)
            case .fear: return DimensionalEmotion(valence: -0.7, arousal: 0.6, dominance: -0.7)
            case .surprise: return DimensionalEmotion(valence: 0.2, arousal: 0.8, dominance: 0)
            case .disgust: return DimensionalEmotion(valence: -0.6, arousal: 0.2, dominance: 0.3)
            case .love: return DimensionalEmotion(valence: 0.9, arousal: 0.2, dominance: -0.2)
            case .awe: return DimensionalEmotion(valence: 0.6, arousal: 0.3, dominance: -0.4)
            case .serenity: return DimensionalEmotion(valence: 0.6, arousal: -0.5, dominance: 0.2)
            case .anxiety: return DimensionalEmotion(valence: -0.5, arousal: 0.5, dominance: -0.5)
            case .nostalgia: return DimensionalEmotion(valence: 0.2, arousal: -0.3, dominance: -0.2)
            default: return DimensionalEmotion()
            }
        }
    }

    // MARK: - Multi-Modal Input

    /// Emotional evidence from different modalities
    public struct EmotionalEvidence {
        // From biometrics
        public var heartRateEvidence: DimensionalEmotion?
        public var hrvEvidence: DimensionalEmotion?
        public var skinConductanceEvidence: DimensionalEmotion?

        // From facial expression
        public var facialEvidence: DimensionalEmotion?

        // From voice analysis
        public var voiceEvidence: DimensionalEmotion?

        // From movement
        public var movementEvidence: DimensionalEmotion?

        // From context
        public var timeOfDayEvidence: DimensionalEmotion?
        public var activityEvidence: DimensionalEmotion?

        // Confidence weights (0-1)
        public var heartRateConfidence: Float = 0.5
        public var hrvConfidence: Float = 0.6
        public var skinConductanceConfidence: Float = 0.4
        public var facialConfidence: Float = 0.8
        public var voiceConfidence: Float = 0.7
        public var movementConfidence: Float = 0.3
        public var contextConfidence: Float = 0.2

        public init() {}
    }

    /// Fused emotional state
    public struct FusedEmotion {
        public var dimensional: DimensionalEmotion
        public var discrete: DiscreteEmotion
        public var confidence: Float
        public var stability: Float  // How stable over time
        public var intensity: Float  // Strength of emotion

        public init() {
            dimensional = DimensionalEmotion()
            discrete = .neutral
            confidence = 0
            stability = 0
            intensity = 0
        }
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Current emotional evidence
    public var evidence = EmotionalEvidence()

    /// Current fused emotion
    public private(set) var currentEmotion = FusedEmotion()

    /// Target emotion (for mood regulation)
    public var targetEmotion: DimensionalEmotion?

    /// Emotion history for trend analysis
    private var emotionHistory: [FusedEmotion] = []
    private let maxHistorySize = 300  // 5 minutes at 1Hz

    /// Resonance mode
    public var resonanceMode: ResonanceMode = .mirror

    /// Transition speed for emotional changes
    public var transitionSpeed: Float = 0.1

    /// Response intensity
    public var responseIntensity: Float = 0.7

    // Processing state
    private var phase: Float = 0
    private var modulationPhase: Float = 0

    // MARK: - Resonance Modes

    /// How the system responds to detected emotions
    public enum ResonanceMode: String, CaseIterable {
        case mirror = "Mirror"           // Reflect detected emotion
        case amplify = "Amplify"         // Intensify detected emotion
        case complement = "Complement"   // Provide complementary emotion
        case regulate = "Regulate"       // Guide toward target emotion
        case contrast = "Contrast"       // Provide contrasting emotion
        case neutral = "Neutral"         // Maintain neutral baseline

        var description: String {
            switch self {
            case .mirror: return "Reflects the user's current emotional state"
            case .amplify: return "Intensifies the current emotional experience"
            case .complement: return "Adds complementary emotional qualities"
            case .regulate: return "Guides toward a target emotional state"
            case .contrast: return "Provides contrasting emotional colors"
            case .neutral: return "Maintains a neutral, stable baseline"
            }
        }
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - Emotion Fusion

    /// Fuse multi-modal evidence into unified emotional state
    public func fuseEvidence() {
        var totalWeight: Float = 0
        var fusedValence: Float = 0
        var fusedArousal: Float = 0
        var fusedDominance: Float = 0

        // Heart rate → arousal
        if let hrEvidence = evidence.heartRateEvidence {
            let weight = evidence.heartRateConfidence
            fusedArousal += hrEvidence.arousal * weight
            totalWeight += weight
        }

        // HRV → valence and arousal
        if let hrvEvidence = evidence.hrvEvidence {
            let weight = evidence.hrvConfidence
            fusedValence += hrvEvidence.valence * weight
            fusedArousal += hrvEvidence.arousal * weight * 0.5
            totalWeight += weight
        }

        // Skin conductance → arousal
        if let scrEvidence = evidence.skinConductanceEvidence {
            let weight = evidence.skinConductanceConfidence
            fusedArousal += scrEvidence.arousal * weight
            totalWeight += weight
        }

        // Facial expression → full VAD
        if let facialEvidence = evidence.facialEvidence {
            let weight = evidence.facialConfidence
            fusedValence += facialEvidence.valence * weight
            fusedArousal += facialEvidence.arousal * weight
            fusedDominance += facialEvidence.dominance * weight
            totalWeight += weight
        }

        // Voice analysis → full VAD
        if let voiceEvidence = evidence.voiceEvidence {
            let weight = evidence.voiceConfidence
            fusedValence += voiceEvidence.valence * weight
            fusedArousal += voiceEvidence.arousal * weight
            fusedDominance += voiceEvidence.dominance * weight
            totalWeight += weight
        }

        // Movement → arousal and dominance
        if let movementEvidence = evidence.movementEvidence {
            let weight = evidence.movementConfidence
            fusedArousal += movementEvidence.arousal * weight
            fusedDominance += movementEvidence.dominance * weight
            totalWeight += weight
        }

        // Normalize
        if totalWeight > 0 {
            fusedValence /= totalWeight
            fusedArousal /= totalWeight
            fusedDominance /= totalWeight
        }

        // Create fused emotion
        let dimensional = DimensionalEmotion(
            valence: fusedValence,
            arousal: fusedArousal,
            dominance: fusedDominance
        )

        var fused = FusedEmotion()
        fused.dimensional = dimensional
        fused.discrete = dimensional.toDiscrete()
        fused.confidence = min(1, totalWeight / 3)  // Normalize confidence

        // Calculate intensity from distance from neutral
        fused.intensity = sqrt(
            fusedValence * fusedValence +
            fusedArousal * fusedArousal +
            fusedDominance * fusedDominance
        ) / sqrt(3)

        // Calculate stability from history
        if emotionHistory.count > 5 {
            let recent = emotionHistory.suffix(5)
            var variance: Float = 0
            for prev in recent {
                let diff = abs(prev.dimensional.valence - dimensional.valence) +
                          abs(prev.dimensional.arousal - dimensional.arousal)
                variance += diff
            }
            fused.stability = max(0, 1 - variance / 5)
        }

        // Smooth transition
        currentEmotion.dimensional.valence = lerp(
            currentEmotion.dimensional.valence,
            fused.dimensional.valence,
            transitionSpeed
        )
        currentEmotion.dimensional.arousal = lerp(
            currentEmotion.dimensional.arousal,
            fused.dimensional.arousal,
            transitionSpeed
        )
        currentEmotion.dimensional.dominance = lerp(
            currentEmotion.dimensional.dominance,
            fused.dimensional.dominance,
            transitionSpeed
        )
        currentEmotion.discrete = currentEmotion.dimensional.toDiscrete()
        currentEmotion.confidence = fused.confidence
        currentEmotion.intensity = fused.intensity
        currentEmotion.stability = fused.stability

        // Store in history
        emotionHistory.append(currentEmotion)
        if emotionHistory.count > maxHistorySize {
            emotionHistory.removeFirst()
        }
    }

    // MARK: - Evidence Updates

    /// Update heart rate evidence
    public func updateHeartRate(_ hr: Float, baseline: Float = 70) {
        // HR above baseline → arousal
        let deviation = (hr - baseline) / 30  // Normalize around ±30 BPM
        evidence.heartRateEvidence = DimensionalEmotion(
            valence: 0,
            arousal: max(-1, min(1, deviation)),
            dominance: 0
        )
    }

    /// Update HRV evidence
    public func updateHRV(_ hrv: Float, coherence: Float = 0) {
        // High HRV → positive valence, low arousal
        let hrvNorm = min(1, hrv / 100)
        let coherenceNorm = coherence / 100

        evidence.hrvEvidence = DimensionalEmotion(
            valence: coherenceNorm * 0.5 + hrvNorm * 0.3,
            arousal: -hrvNorm * 0.5,
            dominance: coherenceNorm * 0.3
        )
    }

    /// Update skin conductance evidence
    public func updateSkinConductance(_ scl: Float, scr: Float = 0) {
        // High SCR → arousal
        evidence.skinConductanceEvidence = DimensionalEmotion(
            valence: 0,
            arousal: scr,
            dominance: 0
        )
    }

    /// Update facial expression evidence
    public func updateFacialExpression(
        happiness: Float = 0,
        sadness: Float = 0,
        anger: Float = 0,
        fear: Float = 0,
        surprise: Float = 0,
        disgust: Float = 0
    ) {
        // Combine facial expressions into VAD
        let valence = happiness - (sadness + anger + fear + disgust) / 4
        let arousal = (happiness + anger + fear + surprise) / 4 - (sadness) / 2
        let dominance = (anger + happiness) / 2 - (fear + sadness) / 2

        evidence.facialEvidence = DimensionalEmotion(
            valence: max(-1, min(1, valence)),
            arousal: max(-1, min(1, arousal)),
            dominance: max(-1, min(1, dominance))
        )
    }

    /// Update voice analysis evidence
    public func updateVoiceAnalysis(
        pitch: Float,       // Normalized (0 = low, 1 = high)
        intensity: Float,   // Volume (0-1)
        tempo: Float,       // Speech rate (0 = slow, 1 = fast)
        jitter: Float = 0   // Voice tremor (0-1)
    ) {
        // High pitch + fast + loud → arousal
        let arousal = (pitch - 0.5) * 0.5 + (tempo - 0.5) * 0.3 + (intensity - 0.5) * 0.4

        // Smooth voice (low jitter) → positive valence
        let valence = -jitter * 0.5 + (pitch - 0.5) * 0.2

        // Loud → dominance
        let dominance = (intensity - 0.5) * 0.6

        evidence.voiceEvidence = DimensionalEmotion(
            valence: max(-1, min(1, valence)),
            arousal: max(-1, min(1, arousal)),
            dominance: max(-1, min(1, dominance))
        )
    }

    /// Update movement evidence
    public func updateMovement(energy: Float, smoothness: Float) {
        // High energy → arousal
        // Smooth movement → positive valence
        evidence.movementEvidence = DimensionalEmotion(
            valence: (smoothness - 0.5) * 0.4,
            arousal: (energy - 0.5) * 0.8,
            dominance: energy * 0.3
        )
    }

    // MARK: - Audio Response Generation

    /// Generate audio parameters based on resonance mode
    public func generateAudioResponse() -> EmotionalAudioResponse {
        fuseEvidence()

        var response = EmotionalAudioResponse()

        let sourceEmotion: DimensionalEmotion
        let targetProfile: MusicalEmotionProfile

        switch resonanceMode {
        case .mirror:
            sourceEmotion = currentEmotion.dimensional
            targetProfile = currentEmotion.discrete.musicalCharacteristics

        case .amplify:
            // Intensify current emotion
            sourceEmotion = DimensionalEmotion(
                valence: currentEmotion.dimensional.valence * 1.5,
                arousal: currentEmotion.dimensional.arousal * 1.5,
                dominance: currentEmotion.dimensional.dominance * 1.5
            )
            targetProfile = sourceEmotion.toDiscrete().musicalCharacteristics

        case .complement:
            // Complementary emotion (rotate in VAD space)
            sourceEmotion = DimensionalEmotion(
                valence: currentEmotion.dimensional.valence,
                arousal: -currentEmotion.dimensional.arousal * 0.5,
                dominance: currentEmotion.dimensional.dominance
            )
            targetProfile = sourceEmotion.toDiscrete().musicalCharacteristics

        case .regulate:
            // Move toward target
            if let target = targetEmotion {
                sourceEmotion = target
            } else {
                // Default target: calm, positive
                sourceEmotion = DimensionalEmotion(valence: 0.3, arousal: -0.2, dominance: 0)
            }
            targetProfile = sourceEmotion.toDiscrete().musicalCharacteristics

        case .contrast:
            // Opposite emotion
            sourceEmotion = DimensionalEmotion(
                valence: -currentEmotion.dimensional.valence,
                arousal: -currentEmotion.dimensional.arousal,
                dominance: -currentEmotion.dimensional.dominance
            )
            targetProfile = sourceEmotion.toDiscrete().musicalCharacteristics

        case .neutral:
            sourceEmotion = DimensionalEmotion()
            targetProfile = DiscreteEmotion.neutral.musicalCharacteristics
        }

        // Generate parameters from profile
        response.tempo = (targetProfile.tempo.0 + targetProfile.tempo.1) / 2
        response.tempo += sourceEmotion.arousal * 20  // Arousal modifies tempo

        // Mode
        response.mode = targetProfile.mode == .major ? 1 : (targetProfile.mode == .minor ? -1 : 0)

        // Dynamics
        switch targetProfile.dynamics {
        case .soft: response.dynamics = 0.3
        case .moderate: response.dynamics = 0.5
        case .loud: response.dynamics = 0.8
        case .variable: response.dynamics = 0.5 + currentEmotion.intensity * 0.3
        case .sudden: response.dynamics = 0.7
        case .crescendo: response.dynamics = 0.6
        }

        // Timbre/brightness
        switch targetProfile.timbre {
        case .bright: response.brightness = 0.8
        case .dark: response.brightness = 0.2
        case .warm: response.brightness = 0.5
        case .harsh: response.brightness = 0.9
        case .thin: response.brightness = 0.7
        case .neutral: response.brightness = 0.5
        }
        response.brightness += sourceEmotion.valence * 0.2

        // Harmony/dissonance
        switch targetProfile.harmony {
        case .simple: response.harmonyComplexity = 0.2
        case .consonant: response.harmonyComplexity = 0.3
        case .rich: response.harmonyComplexity = 0.6
        case .tense: response.harmonyComplexity = 0.7
        case .dissonant: response.harmonyComplexity = 0.9
        case .complex: response.harmonyComplexity = 0.7
        case .bittersweet: response.harmonyComplexity = 0.5
        }

        // Rhythm
        switch targetProfile.rhythm {
        case .slow: response.rhythmDensity = 0.3
        case .regular: response.rhythmDensity = 0.5
        case .fast: response.rhythmDensity = 0.8
        case .irregular: response.rhythmDensity = 0.6
        case .syncopated: response.rhythmDensity = 0.7
        case .flowing: response.rhythmDensity = 0.4
        }

        // Articulation
        switch targetProfile.articulation {
        case .legato: response.articulation = 0.9
        case .staccato: response.articulation = 0.2
        case .marcato: response.articulation = 0.3
        case .accented: response.articulation = 0.4
        case .sustained: response.articulation = 1.0
        case .normal: response.articulation = 0.5
        }

        // Apply response intensity
        response.intensity = currentEmotion.intensity * responseIntensity

        return response
    }

    /// Audio response parameters
    public struct EmotionalAudioResponse {
        public var tempo: Float = 100
        public var mode: Float = 0              // -1 = minor, 0 = neutral, 1 = major
        public var dynamics: Float = 0.5
        public var brightness: Float = 0.5
        public var harmonyComplexity: Float = 0.5
        public var rhythmDensity: Float = 0.5
        public var articulation: Float = 0.5   // 0 = staccato, 1 = legato
        public var intensity: Float = 0.5

        public init() {}
    }

    // MARK: - Audio Processing

    /// Process audio buffer with emotional modulation
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let response = generateAudioResponse()

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Dynamics modulation
            sample *= response.dynamics + 0.3

            // Brightness (simple high-frequency emphasis based on brightness)
            // (Full implementation would use proper EQ)

            // Articulation (envelope follower effect)
            let articulationMod = 0.7 + response.articulation * 0.3

            // Subtle entrainment based on tempo
            let entrainmentFreq = response.tempo / 60  // BPM to Hz
            let entrainment = 0.95 + 0.05 * sin(modulationPhase)
            sample *= entrainment * articulationMod

            modulationPhase += entrainmentFreq / sampleRate * 2 * .pi
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    // MARK: - Utility

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    /// Get emotion trend
    public func getEmotionTrend() -> EmotionTrend {
        guard emotionHistory.count >= 10 else {
            return EmotionTrend()
        }

        var trend = EmotionTrend()

        let recent = Array(emotionHistory.suffix(10))
        let older = emotionHistory.count > 20 ?
            Array(emotionHistory.prefix(10)) :
            Array(emotionHistory.prefix(emotionHistory.count / 2))

        let recentValence = recent.map { $0.dimensional.valence }.reduce(0, +) / Float(recent.count)
        let olderValence = older.map { $0.dimensional.valence }.reduce(0, +) / Float(older.count)

        let recentArousal = recent.map { $0.dimensional.arousal }.reduce(0, +) / Float(recent.count)
        let olderArousal = older.map { $0.dimensional.arousal }.reduce(0, +) / Float(older.count)

        trend.valenceTrend = recentValence - olderValence
        trend.arousalTrend = recentArousal - olderArousal

        if trend.valenceTrend > 0.1 {
            trend.overallTrend = .improving
        } else if trend.valenceTrend < -0.1 {
            trend.overallTrend = .declining
        } else {
            trend.overallTrend = .stable
        }

        return trend
    }

    /// Emotion trend
    public struct EmotionTrend {
        public var valenceTrend: Float = 0
        public var arousalTrend: Float = 0
        public var overallTrend: Trend = .stable

        public enum Trend { case improving, stable, declining }
    }

    /// Reset system
    public func reset() {
        evidence = EmotionalEvidence()
        currentEmotion = FusedEmotion()
        emotionHistory.removeAll()
        phase = 0
        modulationPhase = 0
    }

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
    }
}
