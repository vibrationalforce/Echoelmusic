import Foundation
import Accelerate

// MARK: - Lifestyle Science Engine
// Circadian rhythms, chronobiology, stress management, and flow states
// References: Roenneberg (2012), Csikszentmihalyi (1990), Sapolsky (2004)

/// LifestyleScienceEngine: Integrates lifestyle science with audio
/// Adapts audio experience based on time of day, activity, and psychological state
///
/// Scientific foundations:
/// - Roenneberg, T. (2012). Internal Time: Chronotypes. Harvard University Press
/// - Csikszentmihalyi, M. (1990). Flow: The Psychology of Optimal Experience
/// - Sapolsky, R.M. (2004). Why Zebras Don't Get Ulcers. Holt
/// - Walker, M. (2017). Why We Sleep. Scribner
/// - Huberman, A. (2021). Huberman Lab Podcast protocols
public final class LifestyleScienceEngine {

    // MARK: - Circadian System

    /// Chronotype classification (Roenneberg)
    public enum Chronotype: String, CaseIterable {
        case extremeEarly = "Extreme Early (Lark)"      // Wake 4-5am
        case moderateEarly = "Moderate Early"            // Wake 5-6am
        case slightlyEarly = "Slightly Early"            // Wake 6-7am
        case intermediate = "Intermediate"               // Wake 7-8am
        case slightlyLate = "Slightly Late"             // Wake 8-9am
        case moderateLate = "Moderate Late"              // Wake 9-10am
        case extremeLate = "Extreme Late (Owl)"         // Wake 10am+

        /// Midpoint of sleep (MSF) in hours
        var sleepMidpoint: Float {
            switch self {
            case .extremeEarly: return 1.5      // 1:30 AM
            case .moderateEarly: return 2.5
            case .slightlyEarly: return 3.0
            case .intermediate: return 3.5      // 3:30 AM
            case .slightlyLate: return 4.5
            case .moderateLate: return 5.5
            case .extremeLate: return 6.5       // 6:30 AM
            }
        }

        /// Optimal wake time
        var optimalWakeTime: Float {
            return sleepMidpoint + 4  // ~8 hours sleep
        }
    }

    /// Circadian phase
    public enum CircadianPhase: String, CaseIterable {
        case waking = "Waking"                    // 0-2h after wake
        case morningPeak = "Morning Peak"         // 2-4h after wake
        case middayDip = "Midday Dip"            // 6-8h after wake
        case afternoonRecovery = "Afternoon Recovery"  // 8-10h after wake
        case eveningPeak = "Evening Peak"         // 10-12h after wake
        case windDown = "Wind Down"              // 12-14h after wake
        case sleepPressure = "Sleep Pressure"    // 14-16h after wake
        case sleep = "Sleep"

        /// Energy level for this phase (0-1)
        var energyLevel: Float {
            switch self {
            case .waking: return 0.5
            case .morningPeak: return 0.9
            case .middayDip: return 0.4
            case .afternoonRecovery: return 0.7
            case .eveningPeak: return 0.8
            case .windDown: return 0.5
            case .sleepPressure: return 0.3
            case .sleep: return 0.1
            }
        }

        /// Optimal activities for this phase
        var optimalActivities: [String] {
            switch self {
            case .waking: return ["Light stretching", "Hydration", "Light exposure"]
            case .morningPeak: return ["Deep work", "Complex tasks", "Creative work"]
            case .middayDip: return ["Light tasks", "Exercise", "Power nap"]
            case .afternoonRecovery: return ["Collaborative work", "Meetings"]
            case .eveningPeak: return ["Physical activity", "Social time"]
            case .windDown: return ["Relaxation", "Light reading", "Dim lights"]
            case .sleepPressure: return ["Sleep preparation", "No screens"]
            case .sleep: return ["Sleep"]
            }
        }

        /// Recommended audio characteristics
        var audioRecommendation: AudioRecommendation {
            switch self {
            case .waking:
                return AudioRecommendation(
                    tempo: (60, 80),
                    brightness: 0.4,
                    energy: 0.4,
                    frequencies: [10, 12],  // Alpha
                    description: "Gentle awakening, gradual brightness increase"
                )
            case .morningPeak:
                return AudioRecommendation(
                    tempo: (100, 130),
                    brightness: 0.7,
                    energy: 0.8,
                    frequencies: [14, 20],  // Beta
                    description: "Energizing, focus-enhancing, bright"
                )
            case .middayDip:
                return AudioRecommendation(
                    tempo: (70, 90),
                    brightness: 0.5,
                    energy: 0.4,
                    frequencies: [8, 10],  // Alpha
                    description: "Relaxed, prevent drowsiness without overstimulating"
                )
            case .afternoonRecovery:
                return AudioRecommendation(
                    tempo: (90, 110),
                    brightness: 0.6,
                    energy: 0.6,
                    frequencies: [12, 16],  // SMR/Beta
                    description: "Balanced, supportive for social interaction"
                )
            case .eveningPeak:
                return AudioRecommendation(
                    tempo: (100, 120),
                    brightness: 0.6,
                    energy: 0.7,
                    frequencies: [10, 14],  // Alpha-Beta
                    description: "Active but not overstimulating"
                )
            case .windDown:
                return AudioRecommendation(
                    tempo: (60, 80),
                    brightness: 0.3,
                    energy: 0.3,
                    frequencies: [6, 10],  // Theta-Alpha
                    description: "Calming, reduce blue light equivalent in sound"
                )
            case .sleepPressure:
                return AudioRecommendation(
                    tempo: (50, 65),
                    brightness: 0.2,
                    energy: 0.2,
                    frequencies: [2, 6],  // Delta-Theta
                    description: "Very calming, sleep-promoting"
                )
            case .sleep:
                return AudioRecommendation(
                    tempo: (40, 55),
                    brightness: 0.1,
                    energy: 0.1,
                    frequencies: [0.5, 4],  // Delta
                    description: "Sleep maintenance, very low energy"
                )
            }
        }
    }

    /// Audio recommendation for circadian phase
    public struct AudioRecommendation {
        public var tempo: (Float, Float)
        public var brightness: Float
        public var energy: Float
        public var frequencies: [Float]  // Entrainment frequencies
        public var description: String
    }

    // MARK: - Flow State System

    /// Flow state conditions (Csikszentmihalyi)
    public struct FlowConditions {
        /// Challenge level (0-1)
        public var challenge: Float = 0.5

        /// Skill level (0-1)
        public var skill: Float = 0.5

        /// Clear goals present
        public var clearGoals: Bool = true

        /// Immediate feedback available
        public var immediateFeedback: Bool = true

        /// Deep concentration possible
        public var focusPossible: Bool = true

        /// Sense of control
        public var senseOfControl: Float = 0.7

        /// Loss of self-consciousness
        public var selfConsciousnessReduced: Bool = false

        /// Time perception altered
        public var timeDistorted: Bool = false

        public init() {}

        /// Calculate flow likelihood (0-1)
        public func flowLikelihood() -> Float {
            // Flow occurs when challenge matches skill
            let challengeSkillMatch = 1 - abs(challenge - skill)

            // Both must be above threshold
            let levelSufficient = min(challenge, skill) > 0.3 ? 1.0 : 0.0

            // Conditions bonus
            var conditionScore: Float = 0
            if clearGoals { conditionScore += 0.2 }
            if immediateFeedback { conditionScore += 0.2 }
            if focusPossible { conditionScore += 0.3 }
            conditionScore += senseOfControl * 0.3

            return challengeSkillMatch * Float(levelSufficient) * 0.5 + conditionScore * 0.5
        }

        /// Determine psychological state from challenge/skill
        public func psychologicalState() -> PsychologicalState {
            if challenge > skill + 0.3 {
                return challenge > 0.7 ? .anxiety : .worry
            } else if skill > challenge + 0.3 {
                return skill > 0.7 ? .boredom : .relaxation
            } else if challenge > 0.6 && skill > 0.6 {
                return .flow
            } else if challenge > 0.4 && skill > 0.4 {
                return .control
            } else {
                return .apathy
            }
        }
    }

    /// Psychological states from flow model
    public enum PsychologicalState: String, CaseIterable {
        case anxiety = "Anxiety"        // High challenge, low skill
        case worry = "Worry"            // Moderate-high challenge, low skill
        case apathy = "Apathy"          // Low challenge, low skill
        case boredom = "Boredom"        // Low challenge, high skill
        case relaxation = "Relaxation"  // Low challenge, moderate skill
        case control = "Control"        // Moderate challenge, high skill
        case arousal = "Arousal"        // High challenge, moderate skill
        case flow = "Flow"              // High challenge, high skill (matched)

        /// Audio intervention for this state
        var audioIntervention: String {
            switch self {
            case .anxiety: return "Calming, grounding, slower tempo, increase sense of control"
            case .worry: return "Moderately calming, supportive, build confidence"
            case .apathy: return "Gently activating, increase engagement, novel sounds"
            case .boredom: return "Increase complexity, add challenge, novel elements"
            case .relaxation: return "Maintain calm, pleasant, no change needed"
            case .control: return "Slightly increase intensity to reach flow"
            case .arousal: return "Support with energy, guide toward flow"
            case .flow: return "Maintain current state, subtle support"
            }
        }
    }

    // MARK: - Stress System

    /// Stress response phases (Selye's GAS)
    public enum StressPhase: String, CaseIterable {
        case baseline = "Baseline"           // Normal state
        case alarm = "Alarm"                 // Initial stress response
        case resistance = "Resistance"       // Adaptation phase
        case exhaustion = "Exhaustion"       // Chronic stress state
        case recovery = "Recovery"           // Post-stress recovery

        /// Cortisol level characteristic
        var cortisolPattern: String {
            switch self {
            case .baseline: return "Normal diurnal pattern"
            case .alarm: return "Acute spike"
            case .resistance: return "Elevated but stable"
            case .exhaustion: return "Dysregulated, often low"
            case .recovery: return "Returning to baseline"
            }
        }

        /// Recovery audio strategy
        var recoveryStrategy: String {
            switch self {
            case .baseline: return "Maintenance, prevention"
            case .alarm: return "Immediate calming, grounding, vagal activation"
            case .resistance: return "Regular recovery breaks, stress inoculation"
            case .exhaustion: return "Deep rest, minimal stimulation, healing frequencies"
            case .recovery: return "Gentle rebuilding, positive reinforcement"
            }
        }
    }

    /// Comprehensive lifestyle state
    public struct LifestyleState {
        // Time-based
        public var currentTime: Date = Date()
        public var wakeTime: Date?
        public var sleepTime: Date?
        public var chronotype: Chronotype = .intermediate

        // Activity
        public var currentActivity: ActivityType = .rest
        public var activityDuration: TimeInterval = 0
        public var physicalActivityToday: TimeInterval = 0

        // Sleep
        public var hoursSleptLastNight: Float = 7
        public var sleepQuality: Float = 0.7
        public var sleepDebt: Float = 0

        // Stress
        public var stressPhase: StressPhase = .baseline
        public var acuteStressLevel: Float = 0
        public var chronicStressLevel: Float = 0
        public var recoveryNeed: Float = 0

        // Flow
        public var flowConditions = FlowConditions()
        public var flowDurationToday: TimeInterval = 0

        // Energy
        public var currentEnergy: Float = 0.5
        public var caffeineLevelEstimate: Float = 0

        // Environment
        public var lightExposure: Float = 0.5  // 0 = dark, 1 = bright
        public var noiseLevel: Float = 0.3
        public var socialContext: SocialContext = .alone

        public init() {}
    }

    public enum ActivityType: String, CaseIterable {
        case sleep = "Sleep"
        case rest = "Rest"
        case lightActivity = "Light Activity"
        case moderateActivity = "Moderate Activity"
        case intenseActivity = "Intense Activity"
        case focusedWork = "Focused Work"
        case creativeWork = "Creative Work"
        case socialInteraction = "Social"
        case meditation = "Meditation"
        case eating = "Eating"
    }

    public enum SocialContext: String, CaseIterable {
        case alone = "Alone"
        case oneOnOne = "One-on-One"
        case smallGroup = "Small Group"
        case largeGroup = "Large Group"
        case crowded = "Crowded"
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Current lifestyle state
    public var state = LifestyleState()

    /// User's chronotype
    public var chronotype: Chronotype = .intermediate

    /// Auto-adapt to time of day
    public var circadianAdaptationEnabled: Bool = true

    /// Flow support enabled
    public var flowSupportEnabled: Bool = true

    /// Stress intervention enabled
    public var stressInterventionEnabled: Bool = true

    // Processing state
    private var modulationPhase: Float = 0
    private var entrainmentPhase: Float = 0
    private var envelopeFollower: Float = 0

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - Circadian Calculation

    /// Calculate current circadian phase
    public func getCurrentCircadianPhase() -> CircadianPhase {
        let now = state.currentTime
        let calendar = Calendar.current

        // Get hours since wake
        var hoursSinceWake: Float
        if let wakeTime = state.wakeTime {
            hoursSinceWake = Float(now.timeIntervalSince(wakeTime) / 3600)
        } else {
            // Estimate from chronotype
            let hour = Float(calendar.component(.hour, from: now))
            let minute = Float(calendar.component(.minute, from: now)) / 60
            let currentHour = hour + minute

            let estimatedWake = chronotype.optimalWakeTime
            hoursSinceWake = currentHour - estimatedWake
            if hoursSinceWake < 0 { hoursSinceWake += 24 }
        }

        // Map to circadian phase
        switch hoursSinceWake {
        case 0..<2: return .waking
        case 2..<4: return .morningPeak
        case 6..<8: return .middayDip
        case 8..<10: return .afternoonRecovery
        case 10..<12: return .eveningPeak
        case 12..<14: return .windDown
        case 14..<16: return .sleepPressure
        default: return .sleep
        }
    }

    /// Get circadian-appropriate audio parameters
    public func getCircadianAudioParameters() -> CircadianAudioParameters {
        let phase = getCurrentCircadianPhase()
        let recommendation = phase.audioRecommendation

        var params = CircadianAudioParameters()

        // Base on recommendation
        params.targetTempo = (recommendation.tempo.0 + recommendation.tempo.1) / 2
        params.targetBrightness = recommendation.brightness
        params.targetEnergy = recommendation.energy
        params.entrainmentFrequency = recommendation.frequencies.first ?? 10

        // Adjust for sleep debt
        if state.sleepDebt > 1 {
            params.targetEnergy *= 0.8
            params.targetBrightness *= 0.9
        }

        // Adjust for activity
        switch state.currentActivity {
        case .intenseActivity, .focusedWork:
            params.targetEnergy = min(1, params.targetEnergy + 0.2)
        case .meditation, .rest:
            params.targetEnergy = max(0.1, params.targetEnergy - 0.2)
        default:
            break
        }

        params.phase = phase
        params.description = recommendation.description

        return params
    }

    /// Circadian-adjusted audio parameters
    public struct CircadianAudioParameters {
        public var targetTempo: Float = 100
        public var targetBrightness: Float = 0.5
        public var targetEnergy: Float = 0.5
        public var entrainmentFrequency: Float = 10
        public var phase: CircadianPhase = .intermediate
        public var description: String = ""
    }

    // MARK: - Flow Support

    /// Get flow-supportive audio parameters
    public func getFlowAudioParameters() -> FlowAudioParameters {
        let flowLikelihood = state.flowConditions.flowLikelihood()
        let psychState = state.flowConditions.psychologicalState()

        var params = FlowAudioParameters()
        params.flowLikelihood = flowLikelihood
        params.currentState = psychState

        // Adjust audio based on psychological state
        switch psychState {
        case .anxiety, .worry:
            // Calm down
            params.targetComplexity = 0.3
            params.targetPredictability = 0.8
            params.entrainmentFrequency = 8  // Alpha
            params.intervention = "Reduce tempo, increase predictability, grounding bass"

        case .apathy, .boredom:
            // Activate
            params.targetComplexity = 0.7
            params.targetPredictability = 0.4
            params.entrainmentFrequency = 14  // Beta
            params.intervention = "Increase complexity, add novel elements, raise energy"

        case .relaxation:
            // Slight activation toward control
            params.targetComplexity = 0.5
            params.targetPredictability = 0.6
            params.entrainmentFrequency = 10
            params.intervention = "Gentle complexity increase"

        case .control:
            // Push toward flow
            params.targetComplexity = 0.65
            params.targetPredictability = 0.5
            params.entrainmentFrequency = 12
            params.intervention = "Slight challenge increase"

        case .arousal:
            // Guide toward flow
            params.targetComplexity = 0.6
            params.targetPredictability = 0.55
            params.entrainmentFrequency = 11
            params.intervention = "Maintain energy, add structure"

        case .flow:
            // Maintain flow state
            params.targetComplexity = 0.7
            params.targetPredictability = 0.5
            params.entrainmentFrequency = 10  // Alpha-Theta border
            params.intervention = "Maintain current parameters, subtle variation"
        }

        return params
    }

    /// Flow-supportive audio parameters
    public struct FlowAudioParameters {
        public var flowLikelihood: Float = 0
        public var currentState: PsychologicalState = .relaxation
        public var targetComplexity: Float = 0.5
        public var targetPredictability: Float = 0.5
        public var entrainmentFrequency: Float = 10
        public var intervention: String = ""
    }

    // MARK: - Stress Intervention

    /// Get stress-appropriate audio parameters
    public func getStressAudioParameters() -> StressAudioParameters {
        var params = StressAudioParameters()

        params.stressPhase = state.stressPhase
        params.acuteLevel = state.acuteStressLevel
        params.chronicLevel = state.chronicStressLevel

        switch state.stressPhase {
        case .baseline:
            params.targetCalmness = 0.6
            params.vagalActivation = 0.3
            params.entrainmentFrequency = 10
            params.intervention = "Maintenance mode"

        case .alarm:
            // Immediate calming
            params.targetCalmness = 0.9
            params.vagalActivation = 0.8
            params.entrainmentFrequency = 6  // Theta - vagal activation
            params.breathingGuideRate = 5   // Slow breathing
            params.intervention = "Immediate vagal activation, slow breathing, grounding"

        case .resistance:
            // Prevent escalation
            params.targetCalmness = 0.7
            params.vagalActivation = 0.5
            params.entrainmentFrequency = 8
            params.breathingGuideRate = 6
            params.intervention = "Regular recovery micro-breaks"

        case .exhaustion:
            // Deep recovery
            params.targetCalmness = 1.0
            params.vagalActivation = 0.9
            params.entrainmentFrequency = 4  // Delta - deep rest
            params.breathingGuideRate = 4
            params.intervention = "Deep rest, healing frequencies, minimal stimulation"

        case .recovery:
            // Gentle rebuilding
            params.targetCalmness = 0.7
            params.vagalActivation = 0.6
            params.entrainmentFrequency = 8
            params.intervention = "Gentle positive reinforcement"
        }

        // Adjust for acute stress level
        if state.acuteStressLevel > 0.7 {
            params.vagalActivation = min(1, params.vagalActivation + 0.2)
            params.entrainmentFrequency = max(4, params.entrainmentFrequency - 2)
        }

        return params
    }

    /// Stress-intervention audio parameters
    public struct StressAudioParameters {
        public var stressPhase: StressPhase = .baseline
        public var acuteLevel: Float = 0
        public var chronicLevel: Float = 0
        public var targetCalmness: Float = 0.5
        public var vagalActivation: Float = 0.3
        public var entrainmentFrequency: Float = 10
        public var breathingGuideRate: Float = 6
        public var intervention: String = ""
    }

    // MARK: - Audio Processing

    /// Process audio with lifestyle adaptations
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Get current parameters from all systems
        let circadianParams = circadianAdaptationEnabled ? getCircadianAudioParameters() : nil
        let flowParams = flowSupportEnabled ? getFlowAudioParameters() : nil
        let stressParams = stressInterventionEnabled ? getStressAudioParameters() : nil

        // Determine dominant system (priority: stress > flow > circadian)
        let dominantEntrainment: Float
        let targetEnergy: Float

        if let stress = stressParams, state.acuteStressLevel > 0.5 {
            dominantEntrainment = stress.entrainmentFrequency
            targetEnergy = 1 - stress.targetCalmness
        } else if let flow = flowParams, state.flowConditions.flowLikelihood() > 0.5 {
            dominantEntrainment = flow.entrainmentFrequency
            targetEnergy = flow.targetComplexity
        } else if let circadian = circadianParams {
            dominantEntrainment = circadian.entrainmentFrequency
            targetEnergy = circadian.targetEnergy
        } else {
            dominantEntrainment = 10
            targetEnergy = 0.5
        }

        // Apply processing
        for i in 0..<frameCount {
            var sample = buffer[i]

            // Energy adjustment (dynamics)
            let energyMod = 0.5 + targetEnergy * 0.5
            sample *= energyMod

            // Subtle entrainment
            let entrainmentMod = 0.95 + 0.05 * sin(entrainmentPhase)
            sample *= entrainmentMod

            // Update entrainment phase
            entrainmentPhase += dominantEntrainment / sampleRate * 2 * .pi
            if entrainmentPhase > 2 * .pi { entrainmentPhase -= 2 * .pi }

            buffer[i] = sample
        }
    }

    // MARK: - State Updates

    /// Update current activity
    public func setActivity(_ activity: ActivityType) {
        state.currentActivity = activity
        state.activityDuration = 0
    }

    /// Update stress level
    public func updateStress(acute: Float, chronic: Float? = nil) {
        state.acuteStressLevel = min(1, max(0, acute))

        if let chronic = chronic {
            state.chronicStressLevel = min(1, max(0, chronic))
        }

        // Determine stress phase from levels
        if acute > 0.7 {
            state.stressPhase = .alarm
        } else if chronic > 0.6 {
            state.stressPhase = chronic > 0.8 ? .exhaustion : .resistance
        } else if state.stressPhase == .alarm || state.stressPhase == .resistance {
            state.stressPhase = .recovery
        } else {
            state.stressPhase = .baseline
        }

        state.recoveryNeed = (acute + chronic * 0.5) / 1.5
    }

    /// Update flow conditions
    public func updateFlowConditions(challenge: Float, skill: Float) {
        state.flowConditions.challenge = min(1, max(0, challenge))
        state.flowConditions.skill = min(1, max(0, skill))
    }

    /// Log wake time
    public func logWakeTime(_ time: Date = Date()) {
        state.wakeTime = time
    }

    /// Log sleep
    public func logSleep(hours: Float, quality: Float) {
        state.hoursSleptLastNight = hours
        state.sleepQuality = min(1, max(0, quality))

        // Calculate sleep debt (target 7-9 hours)
        let optimalSleep: Float = 8
        state.sleepDebt = max(0, optimalSleep - hours)
    }

    // MARK: - Recommendations

    /// Get current lifestyle recommendation
    public func getCurrentRecommendation() -> LifestyleRecommendation {
        let phase = getCurrentCircadianPhase()
        let psychState = state.flowConditions.psychologicalState()

        var rec = LifestyleRecommendation()
        rec.circadianPhase = phase
        rec.psychologicalState = psychState
        rec.stressPhase = state.stressPhase
        rec.energyLevel = phase.energyLevel * (1 - state.sleepDebt * 0.1)

        // Activities
        rec.suggestedActivities = phase.optimalActivities

        // Audio settings
        let audioRec = phase.audioRecommendation
        rec.audioDescription = audioRec.description

        // Priority interventions
        if state.acuteStressLevel > 0.6 {
            rec.priorityIntervention = "Stress reduction: slow breathing, calming audio"
        } else if state.sleepDebt > 2 {
            rec.priorityIntervention = "Sleep debt recovery: consider power nap or earlier bedtime"
        } else if psychState == .boredom || psychState == .apathy {
            rec.priorityIntervention = "Engagement: increase challenge or novelty"
        }

        return rec
    }

    /// Lifestyle recommendation
    public struct LifestyleRecommendation {
        public var circadianPhase: CircadianPhase = .intermediate
        public var psychologicalState: PsychologicalState = .relaxation
        public var stressPhase: StressPhase = .baseline
        public var energyLevel: Float = 0.5
        public var suggestedActivities: [String] = []
        public var audioDescription: String = ""
        public var priorityIntervention: String?
    }

    // MARK: - Utility

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
    }

    /// Reset state
    public func reset() {
        state = LifestyleState()
        modulationPhase = 0
        entrainmentPhase = 0
    }
}

// MARK: - Presets

extension LifestyleScienceEngine {

    /// Time-of-day presets
    public enum TimeOfDayPreset: String, CaseIterable {
        case morningWakeUp = "Morning Wake-Up"
        case morningFocus = "Morning Focus"
        case middayReset = "Midday Reset"
        case afternoonPush = "Afternoon Push"
        case eveningWindDown = "Evening Wind-Down"
        case sleepPreparation = "Sleep Preparation"
        case deepSleep = "Deep Sleep"

        public func apply(to engine: LifestyleScienceEngine) {
            switch self {
            case .morningWakeUp:
                engine.state.currentActivity = .lightActivity
                // Simulate morning phase
            case .morningFocus:
                engine.state.currentActivity = .focusedWork
                engine.updateFlowConditions(challenge: 0.6, skill: 0.6)
            case .middayReset:
                engine.state.currentActivity = .rest
                engine.updateStress(acute: 0.3)
            case .afternoonPush:
                engine.state.currentActivity = .focusedWork
                engine.updateFlowConditions(challenge: 0.7, skill: 0.65)
            case .eveningWindDown:
                engine.state.currentActivity = .rest
                engine.updateStress(acute: 0.2)
            case .sleepPreparation:
                engine.state.currentActivity = .rest
                engine.updateStress(acute: 0.1)
            case .deepSleep:
                engine.state.currentActivity = .sleep
            }
        }
    }
}
