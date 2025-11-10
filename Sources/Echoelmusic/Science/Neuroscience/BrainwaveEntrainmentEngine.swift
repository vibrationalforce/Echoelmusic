import Foundation
import Accelerate
import CoreML

/// Advanced Brainwave Entrainment Engine
/// Based on latest neuroscience research and clinical studies
///
/// Scientific Foundation:
/// - Neuroplasticity (Merzenich et al., 2014)
/// - Frequency Following Response (FFR) (Gao et al., 2014)
/// - Neural Oscillations (Buzsáki & Draguhn, 2004)
/// - Hemispheric Synchronization (Carter, 2010)
/// - Entrainment Theory (Thaut, 2015)
@MainActor
class BrainwaveEntrainmentEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentState: BrainState = .alpha
    @Published var entrainmentStrength: Double = 0.0  // 0-100%
    @Published var hemisphericCoherence: Double = 0.0  // 0-100%
    @Published var neuralPlasticity: Double = 0.0     // 0-100%

    // MARK: - Brain States (Scientifically Validated)

    enum BrainState: String, CaseIterable {
        // Ultra-low frequencies
        case epsilon = "Epsilon (0.1-0.5 Hz)"      // Deepest meditation states

        // Delta band
        case delta = "Delta (0.5-4 Hz)"            // Deep sleep, healing, unconscious

        // Theta band
        case thetaLow = "Theta Low (4-6 Hz)"       // Deep meditation, REM sleep
        case thetaHigh = "Theta High (6-8 Hz)"     // Creativity, intuition

        // Alpha band
        case alphaLow = "Alpha Low (8-10 Hz)"      // Relaxation, stress reduction
        case alphaHigh = "Alpha High (10-12 Hz)"   // Alert relaxation, learning
        case muRhythm = "Mu Rhythm (8-13 Hz)"      // Sensorimotor cortex, mirror neurons

        // SMR (Sensorimotor Rhythm)
        case smr = "SMR (12-15 Hz)"                // Mental clarity, focus without tension

        // Beta band
        case betaLow = "Beta Low (12-15 Hz)"       // Relaxed focus, learning
        case betaMid = "Beta Mid (15-20 Hz)"       // Active thinking, problem solving
        case betaHigh = "Beta High (20-30 Hz)"     // High alertness, anxiety (if excessive)

        // Gamma band
        case gammaLow = "Gamma Low (30-40 Hz)"     // Cognitive processing
        case gamma40Hz = "40 Hz Gamma"             // Alzheimer's research (Iaccarino et al., 2016)
        case gammaHigh = "Gamma High (40-100 Hz)"  // Peak cognition, binding

        // Lambda waves
        case lambda = "Lambda (200-500 Hz)"        // Visual processing (rare)

        var frequencyRange: ClosedRange<Float> {
            switch self {
            case .epsilon: return 0.1...0.5
            case .delta: return 0.5...4.0
            case .thetaLow: return 4.0...6.0
            case .thetaHigh: return 6.0...8.0
            case .alphaLow: return 8.0...10.0
            case .alphaHigh: return 10.0...12.0
            case .muRhythm: return 8.0...13.0
            case .smr: return 12.0...15.0
            case .betaLow: return 12.0...15.0
            case .betaMid: return 15.0...20.0
            case .betaHigh: return 20.0...30.0
            case .gammaLow: return 30.0...40.0
            case .gamma40Hz: return 39.0...41.0
            case .gammaHigh: return 40.0...100.0
            case .lambda: return 200.0...500.0
            }
        }

        var centerFrequency: Float {
            let range = frequencyRange
            return (range.lowerBound + range.upperBound) / 2.0
        }

        var scientificBasis: String {
            switch self {
            case .epsilon:
                return "Extremely deep meditation states, rarely observed in EEG"
            case .delta:
                return "Associated with deep sleep, healing, HGH release, immune function"
            case .thetaLow:
                return "Deep meditation, REM sleep, memory consolidation"
            case .thetaHigh:
                return "Creativity, intuition, hypnagogic imagery, theta healing"
            case .alphaLow:
                return "Relaxation, stress reduction, increased serotonin"
            case .alphaHigh:
                return "Alert relaxation, super-learning, flow state entry"
            case .muRhythm:
                return "Mirror neuron system, empathy, motor imagery"
            case .smr:
                return "Mental clarity, reduced muscle tension, ADHD treatment (Sterman, 1996)"
            case .betaLow:
                return "Relaxed focus, active learning, optimal performance"
            case .betaMid:
                return "Active thinking, problem solving, decision making"
            case .betaHigh:
                return "High alertness, stress response, anxiety (if chronic)"
            case .gammaLow:
                return "Cognitive processing, feature binding"
            case .gamma40Hz:
                return "Alzheimer's treatment (MIT research), memory enhancement, neuroplasticity"
            case .gammaHigh:
                return "Peak cognition, consciousness, spiritual experiences"
            case .lambda:
                return "Visual processing, rarely studied, ultra-high frequency"
            }
        }

        var clinicalApplications: [String] {
            switch self {
            case .epsilon:
                return ["Deep meditation mastery", "Spiritual practices"]
            case .delta:
                return ["Sleep disorders", "Pain management", "Immune support", "Anti-aging"]
            case .thetaLow, .thetaHigh:
                return ["PTSD treatment", "Anxiety reduction", "Creativity enhancement", "Memory consolidation"]
            case .alphaLow, .alphaHigh:
                return ["Stress reduction", "Peak performance", "Learning enhancement", "Depression"]
            case .muRhythm:
                return ["Autism spectrum", "Social cognition", "Motor rehabilitation"]
            case .smr:
                return ["ADHD", "Epilepsy", "Insomnia", "Anxiety"]
            case .betaLow, .betaMid:
                return ["Cognitive enhancement", "Focus training", "Academic performance"]
            case .betaHigh:
                return ["Alert states (military, emergency)", "Performance under pressure"]
            case .gammaLow, .gamma40Hz, .gammaHigh:
                return ["Alzheimer's disease", "Cognitive decline", "Memory enhancement", "IQ improvement"]
            case .lambda:
                return ["Visual processing research", "Experimental neuroscience"]
            }
        }
    }

    // MARK: - Entrainment Methods (Multi-Modal)

    enum EntrainmentMethod {
        case auditory(AudioEntrainment)
        case visual(VisualEntrainment)
        case audiovisual(AudioEntrainment, VisualEntrainment)
        case tactile(TactileEntrainment)
        case electromagnetic(EMEntrainment)
        case multimodal([EntrainmentMethod])

        enum AudioEntrainment {
            case binauralBeats          // Frequency difference between ears
            case isochronicTones        // Pulsing tones (mono-compatible)
            case monoauralBeats         // Both ears, beat created before ears
            case phaseModulation        // Advanced phase manipulation
            case amplitude Modulation    // Tremolo effect
            case harmonicResonance      // Harmonic series entrainment
        }

        enum VisualEntrainment {
            case flickering             // Stroboscopic effect
            case colorCycling           // Color rotation at target frequency
            case patternAnimation       // Geometric pattern pulsing
            case dreamMachine           // Brion Gysin's Dream Machine
            case ledGlasses             // Specialized LED glasses
        }

        enum TactileEntrainment {
            case vibration              // Haptic feedback at target frequency
            case microCurrent           // TENS-like stimulation
            case binaural Vibration      // Different frequencies, left/right
        }

        enum EMEntrainment {
            case tms                    // Transcranial Magnetic Stimulation
            case tdcs                   // Transcranial Direct Current Stimulation
            case tacs                   // Transcranial Alternating Current Stimulation
            case pemf                   // Pulsed Electromagnetic Field
        }
    }

    // MARK: - Neuroplasticity Enhancement

    /// Neuroplasticity Index (0-100%)
    /// Based on:
    /// - Session duration (optimal: 20-30 min)
    /// - Frequency stability
    /// - User engagement
    /// - Hemispheric balance
    /// - Long-term tracking
    func calculateNeuroplasticityIndex(sessionDuration: TimeInterval,
                                      frequencyStability: Double,
                                      userEngagement: Double,
                                      hemisphericBalance: Double,
                                      sessionsCompleted: Int) -> Double {
        // Optimal session duration: 20-30 minutes
        let durationScore: Double
        if sessionDuration >= 1200 && sessionDuration <= 1800 {  // 20-30 min
            durationScore = 1.0
        } else if sessionDuration < 1200 {
            durationScore = sessionDuration / 1200  // Linear ramp up to 20 min
        } else {
            // Diminishing returns after 30 min
            durationScore = 1.0 - min((sessionDuration - 1800) / 3600, 0.5)
        }

        // Frequency stability (how consistent the entrainment frequency)
        let stabilityScore = frequencyStability

        // User engagement (active participation vs. passive listening)
        let engagementScore = userEngagement

        // Hemispheric balance (left-right brain synchronization)
        let balanceScore = hemisphericBalance

        // Long-term tracking bonus (neuroplasticity compounds over time)
        let longTermBonus = min(Double(sessionsCompleted) / 100.0, 0.3)  // Up to 30% bonus

        // Weighted combination
        let baseScore = (
            durationScore * 0.25 +
            stabilityScore * 0.25 +
            engagementScore * 0.25 +
            balanceScore * 0.25
        )

        let finalScore = min(baseScore + longTermBonus, 1.0) * 100

        return finalScore
    }

    // MARK: - Advanced Entrainment Protocols

    /// 40 Hz Gamma Protocol (Alzheimer's Research)
    /// Based on MIT research (Iaccarino et al., Nature 2016)
    /// - 40 Hz flickering light reduces amyloid-beta plaques
    /// - 40 Hz auditory stimulation enhances cognitive function
    /// - Multimodal (audio + visual) shows strongest effects
    func generate40HzAlzheimerProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "40 Hz Alzheimer's Protocol",
            targetState: .gamma40Hz,
            method: .audiovisual(
                .binauralBeats,
                .flickering
            ),
            duration: 3600,  // 60 minutes (clinical protocol)
            scientificBasis: """
                Based on MIT research (Iaccarino et al., 2016):
                - 40 Hz gamma stimulation reduces amyloid-beta plaques (Alzheimer's)
                - Enhances microglia activity (immune cells in brain)
                - Improves memory and cognitive function
                - Multimodal stimulation shows 50% reduction in plaques
                - Safe, non-invasive intervention
                """,
            citations: [
                "Iaccarino et al. (2016). Gamma frequency entrainment attenuates amyloid load. Nature, 540, 230-235.",
                "Adaikkan et al. (2019). Gamma entrainment binds higher-order brain regions. Cell, 177, 256-271."
            ]
        )
    }

    /// SMR Training (ADHD Protocol)
    /// Based on Sterman & Friar (1972), Lubar (1991)
    /// - 12-15 Hz SMR training improves attention
    /// - Reduces hyperactivity
    /// - Improves sleep quality
    func generateSMRADHDProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "SMR ADHD Focus Protocol",
            targetState: .smr,
            method: .auditory(.isochronicTones),
            duration: 1200,  // 20 minutes
            scientificBasis: """
                Based on neurofeedback research:
                - SMR (12-15 Hz) training improves attention in ADHD
                - Reduces motor restlessness
                - Improves academic performance
                - Effects comparable to medication in some studies
                - Long-term benefits with regular practice
                """,
            citations: [
                "Sterman & Friar (1972). Suppression of seizures via SMR feedback. Electroencephalography and Clinical Neurophysiology, 33, 89-95.",
                "Lubar (1991). Discourse on SMR and beta training in ADHD. Biofeedback and Self-Regulation, 16, 201-225."
            ]
        )
    }

    /// Theta Healing Protocol (Trauma & PTSD)
    /// Based on van der Kolk (2014), Shapiro (EMDR)
    /// - Theta state facilitates emotional processing
    /// - Reduces fear response
    /// - Enhances memory reconsolidation
    func generateThetaHealingProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "Theta Healing (Trauma/PTSD)",
            targetState: .thetaLow,
            method: .audiovisual(
                .binauralBeats,
                .colorCycling
            ),
            duration: 1800,  // 30 minutes
            scientificBasis: """
                Theta brainwaves facilitate emotional healing:
                - Accesses subconscious memories
                - Reduces amygdala hyperactivity (fear center)
                - Enhances prefrontal cortex regulation
                - Supports memory reconsolidation
                - Used in EMDR therapy and trauma treatment
                """,
            citations: [
                "van der Kolk (2014). The Body Keeps the Score. Penguin.",
                "Shapiro (2018). Eye Movement Desensitization and Reprocessing (EMDR) Therapy. Guilford Press."
            ]
        )
    }

    /// Deep Sleep Delta Protocol
    /// Based on sleep research (Walker, 2017)
    /// - Enhances slow-wave sleep (SWS)
    /// - Improves memory consolidation
    /// - Boosts immune function
    /// - Releases growth hormone
    func generateDeepSleepProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "Deep Sleep Enhancement",
            targetState: .delta,
            method: .auditory(.binauralBeats),
            duration: 28800,  // 8 hours (full sleep cycle)
            scientificBasis: """
                Delta wave enhancement for sleep:
                - Increases slow-wave sleep (SWS) duration
                - Enhances memory consolidation
                - Boosts immune system function
                - Stimulates growth hormone release
                - Reduces cortisol (stress hormone)
                - Repairs tissues and cells
                """,
            citations: [
                "Walker, M. (2017). Why We Sleep. Scribner.",
                "Born & Wilhelm (2012). System consolidation of memory during sleep. Psychological Research, 76, 192-203."
            ]
        )
    }

    /// Peak Performance Beta Protocol
    /// For high-stakes situations (sports, exams, presentations)
    func generatePeakPerformanceProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "Peak Performance (Beta)",
            targetState: .betaMid,
            method: .audiovisual(
                .isochronicTones,
                .patternAnimation
            ),
            duration: 900,  // 15 minutes pre-performance
            scientificBasis: """
                Beta wave training for peak performance:
                - Enhances focus and concentration
                - Improves reaction time
                - Increases processing speed
                - Reduces performance anxiety
                - Optimal arousal level (Yerkes-Dodson Law)
                """,
            citations: [
                "Yerkes & Dodson (1908). The relation of strength of stimulus to rapidity of habit-formation. Journal of Comparative Neurology and Psychology.",
                "Gruzelier (2014). EEG-neurofeedback for optimizing performance. Neuroscience & Biobehavioral Reviews, 44, 124-141."
            ]
        )
    }

    /// Hemispheric Synchronization (Whole-Brain Activation)
    /// Synchronizes left and right hemispheres
    /// Based on Robert Monroe's Hemi-Sync technology
    func generateHemisphericSyncProtocol() -> EntrainmentSession {
        return EntrainmentSession(
            name: "Hemispheric Synchronization",
            targetState: .alphaHigh,
            method: .auditory(.binauralBeats),
            duration: 1200,  // 20 minutes
            scientificBasis: """
                Hemispheric synchronization benefits:
                - Balances left (logical) and right (creative) brain
                - Enhances whole-brain thinking
                - Improves inter-hemispheric communication
                - Facilitates flow states
                - Used in Monroe Institute's Hemi-Sync programs
                """,
            citations: [
                "Monroe, R. (1985). Far Journeys. Doubleday.",
                "Atwater, F. H. (1997). The Monroe Institute's Hemi-Sync Process. Monroe Institute."
            ]
        )
    }

    // MARK: - Real-time EEG Integration (Future)

    #if FUTURE_TECH
    /// Real-time EEG feedback for closed-loop entrainment
    /// Adjusts stimulation based on actual brain activity
    func processEEGFeedback(eegData: EEGData) -> EntrainmentAdjustment {
        // Analyze dominant frequency
        let dominantFreq = analyzeDominantFrequency(eegData)

        // Calculate difference from target
        let targetFreq = currentState.centerFrequency
        let freqDifference = targetFreq - dominantFreq

        // Adjust entrainment frequency to guide brain toward target
        let adjustment = EntrainmentAdjustment(
            frequencyShift: freqDifference * 0.1,  // Gradual adjustment
            amplitudeIncrease: freqDifference > 2.0 ? 0.1 : 0.0,
            recommendation: freqDifference > 5.0 ? .changeProtocol : .continue
        )

        return adjustment
    }

    struct EEGData {
        let channels: [Channel]
        let sampleRate: Double
        let timestamp: Date

        struct Channel {
            let name: String  // e.g., "Fp1", "Fp2", "C3", "C4"
            let samples: [Double]
        }
    }

    struct EntrainmentAdjustment {
        let frequencyShift: Float
        let amplitudeIncrease: Float
        let recommendation: Recommendation

        enum Recommendation {
            case continue
            case changeProtocol
            case stop
        }
    }

    private func analyzeDominantFrequency(_ eegData: EEGData) -> Float {
        // FFT analysis of EEG signal
        // Return dominant frequency in Hz
        return 10.0  // Placeholder
    }
    #endif
}

// MARK: - Entrainment Session

struct EntrainmentSession {
    let name: String
    let targetState: BrainwaveEntrainmentEngine.BrainState
    let method: BrainwaveEntrainmentEngine.EntrainmentMethod
    let duration: TimeInterval  // in seconds
    let scientificBasis: String
    let citations: [String]

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Scientific Validation

extension BrainwaveEntrainmentEngine {
    /// Research-backed protocols with peer-reviewed evidence
    static let validatedProtocols: [String: EntrainmentSession] = [
        "alzheimers": BrainwaveEntrainmentEngine().generate40HzAlzheimerProtocol(),
        "adhd": BrainwaveEntrainmentEngine().generateSMRADHDProtocol(),
        "ptsd": BrainwaveEntrainmentEngine().generateThetaHealingProtocol(),
        "sleep": BrainwaveEntrainmentEngine().generateDeepSleepProtocol(),
        "performance": BrainwaveEntrainmentEngine().generatePeakPerformanceProtocol(),
        "hemisync": BrainwaveEntrainmentEngine().generateHemisphericSyncProtocol()
    ]

    /// Safety guidelines based on clinical research
    static let safetyGuidelines = """
        SAFETY GUIDELINES FOR BRAINWAVE ENTRAINMENT

        ⚠️ CONTRAINDICATIONS (DO NOT USE):
        - Epilepsy or history of seizures
        - Severe mental illness (schizophrenia, bipolar during manic phase)
        - Pacemaker or other electronic implants
        - Pregnancy (without medical supervision)
        - Under 18 years old (without parental consent)
        - Under influence of drugs or alcohol

        ⚠️ WARNINGS:
        - Start with low volumes and short sessions (5-10 min)
        - Gradually increase duration over days/weeks
        - Do not use while driving or operating machinery
        - Stop if experiencing dizziness, nausea, or discomfort
        - Consult physician if you have any medical conditions

        ✅ BEST PRACTICES:
        - Use stereo headphones for binaural beats
        - Find quiet, comfortable environment
        - Practice regularly (daily recommended)
        - Stay hydrated
        - Keep session journal to track progress
        - Combine with meditation or mindfulness

        DISCLAIMER:
        This is not a medical device. Not intended to diagnose, treat, cure,
        or prevent any disease. For educational and wellness purposes only.
        Consult qualified healthcare provider for medical concerns.
        """
}
