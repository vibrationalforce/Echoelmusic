import Foundation
import Accelerate

// MARK: - Psychoacoustic Engine
// Evidence-based psychological audio processing
// References: Juslin & Västfjäll (2008), Koelsch (2014), Thaut (2005)

/// PsychoacousticEngine: Psychology-informed audio processing
/// Implements research-backed relationships between sound and psychological states
///
/// Scientific foundations:
/// - Juslin, P.N. & Västfjäll, D. (2008). Emotional responses to music. Behavioral and Brain Sciences
/// - Koelsch, S. (2014). Brain correlates of music-evoked emotions. Nature Reviews Neuroscience
/// - Thaut, M.H. (2005). Rhythm, Music, and the Brain. Routledge
/// - Levitin, D.J. (2006). This Is Your Brain on Music. Dutton
/// - Sacks, O. (2007). Musicophilia. Knopf
public final class PsychoacousticEngine {

    // MARK: - Psychological States

    /// Core emotional dimensions (Russell's Circumplex Model)
    public struct AffectState {
        /// Valence: negative (-1) to positive (+1)
        public var valence: Float = 0

        /// Arousal: calm (-1) to excited (+1)
        public var arousal: Float = 0

        /// Dominance: submissive (-1) to dominant (+1)
        public var dominance: Float = 0

        public init(valence: Float = 0, arousal: Float = 0, dominance: Float = 0) {
            self.valence = valence
            self.arousal = arousal
            self.dominance = dominance
        }

        /// Named emotional states mapped to VAD space
        public static let emotions: [String: AffectState] = [
            "joy": AffectState(valence: 0.8, arousal: 0.6, dominance: 0.6),
            "serenity": AffectState(valence: 0.6, arousal: -0.5, dominance: 0.3),
            "ecstasy": AffectState(valence: 0.9, arousal: 0.9, dominance: 0.7),
            "love": AffectState(valence: 0.9, arousal: 0.3, dominance: 0.4),
            "sadness": AffectState(valence: -0.7, arousal: -0.4, dominance: -0.5),
            "melancholy": AffectState(valence: -0.4, arousal: -0.3, dominance: -0.2),
            "fear": AffectState(valence: -0.8, arousal: 0.7, dominance: -0.8),
            "anger": AffectState(valence: -0.7, arousal: 0.8, dominance: 0.6),
            "surprise": AffectState(valence: 0.2, arousal: 0.8, dominance: 0.0),
            "anticipation": AffectState(valence: 0.4, arousal: 0.5, dominance: 0.3),
            "trust": AffectState(valence: 0.6, arousal: -0.1, dominance: 0.4),
            "disgust": AffectState(valence: -0.8, arousal: 0.3, dominance: 0.2),
            "contempt": AffectState(valence: -0.5, arousal: 0.1, dominance: 0.6),
            "awe": AffectState(valence: 0.7, arousal: 0.4, dominance: -0.3),
            "nostalgia": AffectState(valence: 0.3, arousal: -0.2, dominance: -0.1),
            "flow": AffectState(valence: 0.7, arousal: 0.3, dominance: 0.5),
            "transcendence": AffectState(valence: 0.9, arousal: 0.2, dominance: 0.0)
        ]
    }

    /// Musical features that influence emotion (Gabrielsson & Lindström, 2010)
    public struct MusicalFeatures {
        // Temporal
        public var tempo: Float = 120           // BPM
        public var tempoVariability: Float = 0  // Rubato amount
        public var rhythmComplexity: Float = 0.5
        public var syncopation: Float = 0

        // Pitch
        public var mode: Float = 0              // -1 = minor, +1 = major
        public var pitch: Float = 0.5           // Register (low to high)
        public var pitchVariability: Float = 0.3
        public var melodicContour: Float = 0    // -1 = descending, +1 = ascending

        // Dynamics
        public var loudness: Float = 0.5
        public var dynamicRange: Float = 0.5
        public var attackSharpness: Float = 0.5

        // Timbre
        public var brightness: Float = 0.5
        public var roughness: Float = 0
        public var warmth: Float = 0.5

        // Harmony
        public var harmonicComplexity: Float = 0.5
        public var dissonance: Float = 0
        public var tension: Float = 0.3

        // Articulation
        public var staccato: Float = 0          // 0 = legato, 1 = staccato
        public var vibrato: Float = 0.3

        public init() {}
    }

    // MARK: - Emotion-Music Mappings

    /// Research-based mappings from musical features to emotions
    /// Based on meta-analysis by Gabrielsson & Lindström (2010)
    public struct EmotionMusicMapping {

        /// Get musical features that evoke target emotion
        public static func featuresFor(emotion: AffectState) -> MusicalFeatures {
            var features = MusicalFeatures()

            // Tempo: High arousal → fast tempo
            // Juslin (2000): tempo is primary cue for arousal
            features.tempo = 80 + (emotion.arousal + 1) * 60  // 80-200 BPM

            // Mode: Positive valence → major mode
            // Hevner (1935): major = happy, minor = sad
            features.mode = emotion.valence

            // Pitch register: High arousal → higher pitch
            features.pitch = 0.5 + emotion.arousal * 0.3

            // Loudness: High arousal → louder
            features.loudness = 0.5 + emotion.arousal * 0.3

            // Brightness: Positive valence + high arousal → brighter
            features.brightness = 0.5 + (emotion.valence + emotion.arousal) * 0.25

            // Attack: High arousal → sharper attacks
            features.attackSharpness = 0.5 + emotion.arousal * 0.4

            // Articulation: High arousal → more staccato
            features.staccato = max(0, emotion.arousal * 0.5)

            // Harmonic complexity: Low valence → more complex/dissonant
            features.dissonance = max(0, -emotion.valence * 0.3)
            features.harmonicComplexity = 0.5 - emotion.valence * 0.2

            // Tension follows arousal
            features.tension = 0.3 + emotion.arousal * 0.4

            // Warmth: Positive valence → warmer
            features.warmth = 0.5 + emotion.valence * 0.3

            // Vibrato: Sadness and tenderness increase vibrato
            if emotion.valence < 0 && emotion.arousal < 0 {
                features.vibrato = 0.6
            }

            // Melodic contour
            features.melodicContour = emotion.valence * 0.5

            return features
        }

        /// Estimate emotion from musical features
        public static func emotionFrom(features: MusicalFeatures) -> AffectState {
            var emotion = AffectState()

            // Arousal estimation
            let tempoContribution = (features.tempo - 100) / 100
            let loudnessContribution = features.loudness - 0.5
            let attackContribution = features.attackSharpness - 0.5
            let pitchContribution = features.pitch - 0.5

            emotion.arousal = (tempoContribution + loudnessContribution +
                              attackContribution + pitchContribution) / 2
            emotion.arousal = max(-1, min(1, emotion.arousal))

            // Valence estimation
            let modeContribution = features.mode
            let brightnessContribution = (features.brightness - 0.5) * 0.5
            let dissonanceContribution = -features.dissonance
            let warmthContribution = (features.warmth - 0.5) * 0.3

            emotion.valence = (modeContribution + brightnessContribution +
                              dissonanceContribution + warmthContribution) / 2
            emotion.valence = max(-1, min(1, emotion.valence))

            // Dominance estimation
            emotion.dominance = (features.loudness - 0.5 + features.attackSharpness - 0.5) / 2
            emotion.dominance = max(-1, min(1, emotion.dominance))

            return emotion
        }
    }

    // MARK: - Psychoacoustic Phenomena

    /// Psychoacoustic constants and phenomena
    public struct PsychoacousticConstants {
        /// Critical bandwidth (Bark scale) - Zwicker (1961)
        public static func criticalBandwidth(frequency: Float) -> Float {
            return 25 + 75 * pow(1 + 1.4 * pow(frequency / 1000, 2), 0.69)
        }

        /// Bark scale conversion - perceptual frequency scale
        public static func hertzToBark(_ hz: Float) -> Float {
            return 13 * atan(0.00076 * hz) + 3.5 * atan(pow(hz / 7500, 2))
        }

        /// Mel scale conversion - pitch perception
        public static func hertzToMel(_ hz: Float) -> Float {
            return 2595 * log10(1 + hz / 700)
        }

        /// Equal loudness contour (ISO 226:2003) - simplified
        public static func loudnessContour(frequency: Float, phon: Float) -> Float {
            // Simplified A-weighting approximation
            let f2 = frequency * frequency
            let f4 = f2 * f2
            let aWeight = (12194 * 12194 * f4) /
                         ((f2 + 20.6 * 20.6) * sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) * (f2 + 12194 * 12194))
            return phon + 20 * log10(aWeight)
        }

        /// Masking threshold - frequency masking
        public static func maskingThreshold(maskerFreq: Float, maskerLevel: Float, targetFreq: Float) -> Float {
            let barkDiff = abs(hertzToBark(targetFreq) - hertzToBark(maskerFreq))
            let spreadingFunction = max(0, maskerLevel - 10 * barkDiff)
            return spreadingFunction
        }

        /// Just Noticeable Difference (JND) for pitch
        public static let pitchJND: Float = 0.5  // Cents (at 1000 Hz)

        /// JND for loudness
        public static let loudnessJND: Float = 1.0  // dB

        /// JND for tempo
        public static let tempoJND: Float = 4.0  // Percent

        /// Temporal integration window
        public static let temporalIntegration: Float = 200  // ms

        /// Auditory scene analysis - stream segregation threshold
        public static let streamSegregationThreshold: Float = 3.0  // semitones
    }

    // MARK: - Therapeutic Frequencies

    /// Evidence-based therapeutic frequencies
    public struct TherapeuticFrequencies {
        /// Frequencies with research support
        public static let database: [(name: String, frequency: Float, effect: String, evidence: String)] = [
            // Brainwave entrainment (Thaut, 2005)
            ("Delta", 2.0, "Deep sleep, healing", "EEG studies, Hobson 1988"),
            ("Theta", 6.0, "Meditation, creativity", "Lagopoulos et al. 2009"),
            ("Alpha", 10.0, "Relaxation, calm focus", "Klimesch 1999"),
            ("SMR", 14.0, "Mental clarity, calm", "Sterman 1996"),
            ("Beta", 20.0, "Active thinking, focus", "Ray & Cole 1985"),
            ("Gamma", 40.0, "Cognitive processing", "Engel & Singer 2001"),

            // Schumann resonances (geophysical)
            ("Schumann 1", 7.83, "Earth resonance, grounding", "Schumann 1952"),
            ("Schumann 2", 14.3, "Second harmonic", "Geophysical research"),
            ("Schumann 3", 20.8, "Third harmonic", "Geophysical research"),

            // Heart coherence (HeartMath Institute)
            ("Heart Coherence", 0.1, "HRV coherence frequency", "McCraty et al. 2009"),

            // Respiratory sinus arrhythmia
            ("Resonant Breathing", 0.1, "Optimal HRV, vagal tone", "Lehrer et al. 2000"),

            // Music therapy specific
            ("ISO Principle Start", 60.0, "Match agitated state", "Altshuler 1948"),
            ("ISO Principle Target", 60.0, "Guide to calm", "Music therapy practice")
        ]

        /// Get frequency for target state
        public static func frequencyFor(state: String) -> Float? {
            return database.first { $0.name.lowercased() == state.lowercased() }?.frequency
        }
    }

    // MARK: - Processing Modes

    /// Psychoacoustic processing modes
    public enum ProcessingMode: String, CaseIterable {
        case emotionInduction = "Emotion Induction"
        case moodRegulation = "Mood Regulation"
        case entrainment = "Brainwave Entrainment"
        case isochronic = "Isochronic Tones"
        case binaural = "Binaural Beats"
        case musicalAnalgesia = "Musical Analgesia"
        case attention = "Attention Enhancement"
        case relaxation = "Relaxation Response"
        case activation = "Activation/Energizing"
        case flowState = "Flow State Induction"
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Current target emotion
    public var targetEmotion: AffectState = AffectState()

    /// Current musical features
    public var features: MusicalFeatures = MusicalFeatures()

    /// Processing mode
    public var mode: ProcessingMode = .emotionInduction

    /// Entrainment frequency (Hz)
    public var entrainmentFrequency: Float = 10.0

    /// Transition speed (0-1, higher = faster)
    public var transitionSpeed: Float = 0.1

    /// ISO principle enabled (gradual state change)
    public var isoPrincipleEnabled: Bool = true

    /// Current state (for ISO principle)
    private var currentState: AffectState = AffectState()

    // Processing state
    private var phase: Float = 0
    private var modulationPhase: Float = 0
    private var envelopeFollower: Float = 0

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - Emotion-Based Processing

    /// Set target emotion by name
    public func setTargetEmotion(_ emotionName: String) {
        if let emotion = AffectState.emotions[emotionName.lowercased()] {
            targetEmotion = emotion
            features = EmotionMusicMapping.featuresFor(emotion: emotion)
        }
    }

    /// Set target emotion directly
    public func setTargetEmotion(valence: Float, arousal: Float, dominance: Float = 0) {
        targetEmotion = AffectState(valence: valence, arousal: arousal, dominance: dominance)
        features = EmotionMusicMapping.featuresFor(emotion: targetEmotion)
    }

    /// Process audio with emotion-based modifications
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Update current state using ISO principle (gradual transition)
        if isoPrincipleEnabled {
            currentState.valence += (targetEmotion.valence - currentState.valence) * transitionSpeed * 0.01
            currentState.arousal += (targetEmotion.arousal - currentState.arousal) * transitionSpeed * 0.01
            currentState.dominance += (targetEmotion.dominance - currentState.dominance) * transitionSpeed * 0.01
        } else {
            currentState = targetEmotion
        }

        // Get features for current state
        let currentFeatures = EmotionMusicMapping.featuresFor(emotion: currentState)

        // Process based on mode
        switch mode {
        case .emotionInduction:
            processEmotionInduction(buffer: buffer, frameCount: frameCount, features: currentFeatures)

        case .moodRegulation:
            processMoodRegulation(buffer: buffer, frameCount: frameCount, features: currentFeatures)

        case .entrainment:
            processEntrainment(buffer: buffer, frameCount: frameCount)

        case .isochronic:
            processIsochronic(buffer: buffer, frameCount: frameCount)

        case .binaural:
            processBinaural(buffer: buffer, frameCount: frameCount)

        case .musicalAnalgesia:
            processMusicalAnalgesia(buffer: buffer, frameCount: frameCount)

        case .attention:
            processAttention(buffer: buffer, frameCount: frameCount)

        case .relaxation:
            processRelaxation(buffer: buffer, frameCount: frameCount)

        case .activation:
            processActivation(buffer: buffer, frameCount: frameCount)

        case .flowState:
            processFlowState(buffer: buffer, frameCount: frameCount)
        }
    }

    // MARK: - Processing Methods

    /// Emotion induction through timbral modification
    private func processEmotionInduction(buffer: UnsafeMutablePointer<Float>, frameCount: Int, features: MusicalFeatures) {
        for i in 0..<frameCount {
            var sample = buffer[i]

            // Brightness modification (spectral tilt)
            let brightnessFilter = features.brightness * 2 - 1
            if brightnessFilter > 0 {
                // High shelf boost
                sample *= 1 + brightnessFilter * 0.3
            } else {
                // High shelf cut
                sample *= 1 + brightnessFilter * 0.2
            }

            // Warmth (low-mid emphasis)
            let warmthAmount = features.warmth
            envelopeFollower = envelopeFollower * 0.99 + abs(sample) * 0.01
            sample += sin(phase) * envelopeFollower * warmthAmount * 0.1
            phase += 150 / sampleRate * 2 * .pi

            // Attack shaping (transient modification)
            let attackMod = features.attackSharpness
            let envelope = abs(sample)
            if envelope > envelopeFollower * 1.5 {
                sample *= 1 + (attackMod - 0.5) * 0.3
            }

            buffer[i] = sample
        }
    }

    /// Mood regulation with gradual spectral changes
    private func processMoodRegulation(buffer: UnsafeMutablePointer<Float>, frameCount: Int, features: MusicalFeatures) {
        // Add subtle harmonic content based on target mood
        let harmonicFreq = features.mode > 0 ? 523.25 : 440.0  // C5 (major feel) vs A4 (neutral/minor)

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Envelope following
            envelopeFollower = envelopeFollower * 0.995 + abs(sample) * 0.005

            // Add subtle harmonic reinforcement
            let harmonicAmount = envelopeFollower * 0.05 * abs(features.mode)
            sample += sin(phase) * harmonicAmount
            phase += harmonicFreq / sampleRate * 2 * .pi
            if phase > 2 * .pi { phase -= 2 * .pi }

            // Dynamics processing based on arousal
            let compressionRatio = 1.0 + (1 - features.loudness) * 2
            if abs(sample) > 0.5 {
                sample = sign(sample) * (0.5 + (abs(sample) - 0.5) / compressionRatio)
            }

            buffer[i] = sample
        }
    }

    /// Brainwave entrainment processing
    private func processEntrainment(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let entrainmentPhaseInc = entrainmentFrequency / sampleRate * 2 * .pi

        for i in 0..<frameCount {
            // Amplitude modulation at entrainment frequency
            let modulation = 0.5 + 0.5 * sin(modulationPhase)
            buffer[i] *= Float(modulation)

            modulationPhase += entrainmentPhaseInc
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }
        }
    }

    /// Isochronic tones (pulsed tones)
    private func processIsochronic(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let pulseFrequency = entrainmentFrequency
        let toneFrequency: Float = 200  // Carrier frequency

        for i in 0..<frameCount {
            // Generate isochronic pulse
            let pulsePhase = modulationPhase * pulseFrequency / entrainmentFrequency
            let pulse: Float = sin(pulsePhase) > 0 ? 1 : 0

            // Generate tone
            let tone = sin(phase) * pulse * 0.3

            // Mix with input
            buffer[i] = buffer[i] * 0.7 + tone

            phase += toneFrequency / sampleRate * 2 * .pi
            modulationPhase += entrainmentFrequency / sampleRate * 2 * .pi

            if phase > 2 * .pi { phase -= 2 * .pi }
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }
        }
    }

    /// Binaural beats processing (requires stereo output)
    private func processBinaural(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // For mono buffer, add beating pattern
        let carrierFreq: Float = 200
        let beatFreq = entrainmentFrequency

        for i in 0..<frameCount {
            let beat = sin(phase) * cos(modulationPhase) * 0.2
            buffer[i] += beat

            phase += carrierFreq / sampleRate * 2 * .pi
            modulationPhase += beatFreq / sampleRate * 2 * .pi

            if phase > 2 * .pi { phase -= 2 * .pi }
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }
        }
    }

    /// Musical analgesia (pain reduction through music)
    /// Based on Garza-Villarreal et al. (2014)
    private func processMusicalAnalgesia(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Smooth, predictable, consonant processing
        // Reduces arousal, increases valence

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Soft limiting (remove harsh transients)
            sample = tanh(sample * 0.8)

            // Add warmth
            envelopeFollower = envelopeFollower * 0.998 + abs(sample) * 0.002
            let warmth = sin(phase) * envelopeFollower * 0.05
            sample += warmth

            phase += 100 / sampleRate * 2 * .pi
            if phase > 2 * .pi { phase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    /// Attention enhancement (beta entrainment + clarity)
    private func processAttention(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        entrainmentFrequency = 18  // Beta range

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Enhance clarity (presence boost)
            // Simplified high-mid emphasis
            sample *= 1.1

            // Beta entrainment modulation
            let betaMod = 0.9 + 0.1 * sin(modulationPhase)
            sample *= betaMod

            modulationPhase += entrainmentFrequency / sampleRate * 2 * .pi
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    /// Relaxation response (alpha entrainment + warmth)
    private func processRelaxation(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        entrainmentFrequency = 10  // Alpha range

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Soften transients
            envelopeFollower = envelopeFollower * 0.99 + abs(sample) * 0.01
            let transientReduction = min(1, envelopeFollower * 5)
            sample *= transientReduction

            // Alpha entrainment
            let alphaMod = 0.85 + 0.15 * sin(modulationPhase)
            sample *= alphaMod

            // Add subtle low frequency content
            sample += sin(phase) * 0.02
            phase += 80 / sampleRate * 2 * .pi

            modulationPhase += entrainmentFrequency / sampleRate * 2 * .pi

            if phase > 2 * .pi { phase -= 2 * .pi }
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    /// Activation/energizing processing
    private func processActivation(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        entrainmentFrequency = 25  // High beta

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Enhance transients
            envelopeFollower = envelopeFollower * 0.95 + abs(sample) * 0.05
            if abs(sample) > envelopeFollower * 1.2 {
                sample *= 1.3
            }

            // Add brightness
            sample *= 1.1

            // Beta modulation
            let betaMod = 0.8 + 0.2 * sin(modulationPhase)
            sample *= betaMod

            modulationPhase += entrainmentFrequency / sampleRate * 2 * .pi
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    /// Flow state induction
    /// Based on Csikszentmihalyi's flow theory + neural correlates
    private func processFlowState(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Flow correlates with alpha-theta border (7-10 Hz)
        entrainmentFrequency = 8.5

        for i in 0..<frameCount {
            var sample = buffer[i]

            // Balanced processing - not too arousing, not too calming
            // Optimal challenge-skill balance in audio terms

            // Moderate dynamics
            sample = tanh(sample * 1.2) * 0.9

            // Subtle entrainment
            let flowMod = 0.95 + 0.05 * sin(modulationPhase)
            sample *= flowMod

            modulationPhase += entrainmentFrequency / sampleRate * 2 * .pi
            if modulationPhase > 2 * .pi { modulationPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    // MARK: - Analysis

    /// Analyze audio for emotional content
    public func analyzeEmotion(buffer: UnsafePointer<Float>, frameCount: Int) -> AffectState {
        // Simple analysis based on spectral centroid and RMS
        var rms: Float = 0
        var zeroCrossings: Int = 0
        var prevSample: Float = 0

        for i in 0..<frameCount {
            let sample = buffer[i]
            rms += sample * sample

            if (prevSample >= 0 && sample < 0) || (prevSample < 0 && sample >= 0) {
                zeroCrossings += 1
            }
            prevSample = sample
        }

        rms = sqrt(rms / Float(frameCount))
        let brightness = Float(zeroCrossings) / Float(frameCount) * sampleRate / 2000

        // Map to emotion
        var emotion = AffectState()
        emotion.arousal = (rms - 0.1) * 5  // RMS → arousal
        emotion.valence = (brightness - 0.5) * 2  // Brightness → valence (simplified)

        return emotion
    }

    // MARK: - Utility

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
    }

    /// Reset processing state
    public func reset() {
        phase = 0
        modulationPhase = 0
        envelopeFollower = 0
        currentState = AffectState()
    }

    /// Get current state (for visualization)
    public func getCurrentState() -> AffectState {
        return currentState
    }
}

// MARK: - Helper

private func sign(_ x: Float) -> Float {
    return x >= 0 ? 1 : -1
}
