import Foundation
import Accelerate

// MARK: - Mind-Body-Audio Bridge
// Unified integration of all psycho-physiological systems
// The central hub connecting psychology, somatics, lifestyle, and gesture to audio

/// MindBodyAudioBridge: Unified integration layer for embodied audio experience
/// Connects and coordinates all bio-reactive, psychological, and gestural systems
///
/// This is the master controller that:
/// - Aggregates input from all modalities
/// - Resolves conflicts between systems
/// - Generates unified audio control parameters
/// - Manages state transitions smoothly
/// - Provides holistic session insights
public final class MindBodyAudioBridge {

    // MARK: - Subsystems

    /// Psychoacoustic processing engine
    public let psychoacousticEngine: PsychoacousticEngine

    /// Psychosomatic body-mind mapper
    public let psychosomaticMapper: PsychosomaticMapper

    /// Lifestyle science engine
    public let lifestyleEngine: LifestyleScienceEngine

    /// Gesture and mimic controller
    public let gestureController: GestureMimicController

    /// Emotional resonance system
    public let emotionalResonance: EmotionalResonanceSystem

    // MARK: - Unified State

    /// Holistic user state combining all inputs
    public struct HolisticState {
        // Emotional
        public var emotionalValence: Float = 0
        public var emotionalArousal: Float = 0
        public var emotionalDominance: Float = 0
        public var dominantEmotion: EmotionalResonanceSystem.DiscreteEmotion = .neutral

        // Physical
        public var energyLevel: Float = 0.5
        public var relaxationLevel: Float = 0.5
        public var tensionLevel: Float = 0.3
        public var movementIntensity: Float = 0

        // Cognitive
        public var focusLevel: Float = 0.5
        public var flowLikelihood: Float = 0
        public var stressLevel: Float = 0

        // Temporal
        public var circadianPhase: LifestyleScienceEngine.CircadianPhase = .intermediate
        public var timeOfDayEnergy: Float = 0.5
        public var sessionDuration: TimeInterval = 0

        // Interaction
        public var interactionIntensity: Float = 0
        public var gestureActivity: Float = 0
        public var expressiveness: Float = 0

        // Overall
        public var overallWellbeing: Float = 0.5
        public var engagementLevel: Float = 0.5
        public var coherenceScore: Float = 0

        public init() {}
    }

    /// Unified audio control parameters
    public struct UnifiedAudioControl {
        // Core parameters
        public var masterVolume: Float = 0.8
        public var tempo: Float = 100
        public var pitch: Float = 0        // Semitones offset
        public var brightness: Float = 0.5
        public var warmth: Float = 0.5

        // Spatial
        public var stereoWidth: Float = 0.5
        public var reverbAmount: Float = 0.3
        public var spatialPosition: Float = 0.5  // Pan

        // Dynamics
        public var dynamicRange: Float = 0.5
        public var compression: Float = 0.3
        public var transientShaping: Float = 0.5

        // Modulation
        public var modulationDepth: Float = 0.3
        public var modulationRate: Float = 1.0
        public var vibratoAmount: Float = 0.1

        // Timbral
        public var filterCutoff: Float = 5000
        public var filterResonance: Float = 0.3
        public var harmonicContent: Float = 0.5
        public var noiseAmount: Float = 0

        // Synthesis
        public var grainDensity: Float = 0.5
        public var morphPosition: Float = 0.5
        public var attackTime: Float = 0.1
        public var releaseTime: Float = 0.3

        // Emotional
        public var emotionalIntensity: Float = 0.5
        public var emotionalValence: Float = 0  // Affects mode selection
        public var entrainmentFrequency: Float = 10

        // Biofeedback
        public var heartRateSync: Float = 0
        public var breathingSync: Float = 0
        public var coherenceTone: Float = 0

        public init() {}
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Current holistic state
    public private(set) var holisticState = HolisticState()

    /// Current unified audio control
    public private(set) var audioControl = UnifiedAudioControl()

    /// Session start time
    private var sessionStartTime: Date?

    /// System weights for priority resolution
    public var systemWeights = SystemWeights()

    /// Integration mode
    public var integrationMode: IntegrationMode = .balanced

    /// Smoothing for parameter transitions
    public var transitionSmoothing: Float = 0.15

    /// Enable/disable individual systems
    public var systemsEnabled = SystemsEnabled()

    // Processing state
    private var updateCounter: Int = 0
    private let updateRate: Int = 60  // Updates per second

    // MARK: - Configuration Types

    /// Weights for different input systems
    public struct SystemWeights {
        public var emotion: Float = 1.0
        public var somatic: Float = 0.8
        public var lifestyle: Float = 0.6
        public var gesture: Float = 1.0
        public var circadian: Float = 0.4

        public init() {}
    }

    /// Enable flags for systems
    public struct SystemsEnabled {
        public var psychoacoustic: Bool = true
        public var psychosomatic: Bool = true
        public var lifestyle: Bool = true
        public var gesture: Bool = true
        public var emotional: Bool = true

        public init() {}
    }

    /// Integration modes
    public enum IntegrationMode: String, CaseIterable {
        case balanced = "Balanced"           // Equal consideration of all inputs
        case emotionPriority = "Emotion Priority"  // Emotional state dominates
        case bodyPriority = "Body Priority"       // Physical state dominates
        case gesturePriority = "Gesture Priority" // Direct control prioritized
        case circadianAware = "Circadian Aware"   // Time-of-day emphasis
        case therapeutic = "Therapeutic"          // Wellness-focused
        case performance = "Performance"          // Maximum responsiveness

        var description: String {
            switch self {
            case .balanced: return "Harmonizes all input modalities equally"
            case .emotionPriority: return "Emotional state drives the experience"
            case .bodyPriority: return "Physical sensations guide audio response"
            case .gesturePriority: return "Direct gestural control takes precedence"
            case .circadianAware: return "Adapts to time of day and energy cycles"
            case .therapeutic: return "Optimized for relaxation and healing"
            case .performance: return "Maximum responsiveness for live use"
            }
        }
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate

        psychoacousticEngine = PsychoacousticEngine(sampleRate: sampleRate)
        psychosomaticMapper = PsychosomaticMapper(sampleRate: sampleRate)
        lifestyleEngine = LifestyleScienceEngine(sampleRate: sampleRate)
        gestureController = GestureMimicController()
        emotionalResonance = EmotionalResonanceSystem(sampleRate: sampleRate)

        sessionStartTime = Date()
    }

    // MARK: - State Updates

    /// Update with biometric data
    public func updateBiometrics(
        heartRate: Float? = nil,
        hrv: Float? = nil,
        coherence: Float? = nil,
        skinConductance: Float? = nil,
        breathingRate: Float? = nil,
        muscularTension: Float? = nil
    ) {
        guard systemsEnabled.psychosomatic else { return }

        var bodyState = psychosomaticMapper.bodyState

        if let hr = heartRate {
            bodyState.heartRate = hr
            emotionalResonance.updateHeartRate(hr)
        }
        if let hrv = hrv {
            bodyState.heartRateVariability = hrv
            emotionalResonance.updateHRV(hrv, coherence: coherence ?? 0)
        }
        if let coh = coherence {
            bodyState.coherenceScore = coh
        }
        if let scl = skinConductance {
            bodyState.skinConductance = scl
            emotionalResonance.updateSkinConductance(scl)
        }
        if let br = breathingRate {
            bodyState.breathingRate = br
        }
        if let tension = muscularTension {
            bodyState.muscularTension = tension
        }

        psychosomaticMapper.updateState(bodyState)
    }

    /// Update with facial expression data
    public func updateFacialExpression(
        happiness: Float = 0,
        sadness: Float = 0,
        anger: Float = 0,
        fear: Float = 0,
        surprise: Float = 0,
        disgust: Float = 0,
        mouthOpen: Float = 0
    ) {
        guard systemsEnabled.emotional else { return }

        emotionalResonance.updateFacialExpression(
            happiness: happiness,
            sadness: sadness,
            anger: anger,
            fear: fear,
            surprise: surprise,
            disgust: disgust
        )

        // Also update gesture controller
        var facialState = gestureController.facialState
        facialState.mouthSmileLeft = happiness
        facialState.mouthSmileRight = happiness
        facialState.mouthFrownLeft = sadness
        facialState.mouthFrownRight = sadness
        facialState.mouthOpen = mouthOpen
        facialState.calculateDerivedEmotions()
        gestureController.updateFacial(facialState)
    }

    /// Update with gesture/motion data
    public func updateGesture(
        touchState: GestureMimicController.TouchState? = nil,
        motionState: GestureMimicController.MotionState? = nil,
        leftHand: GestureMimicController.HandState? = nil,
        rightHand: GestureMimicController.HandState? = nil,
        bodyPose: GestureMimicController.BodyPoseState? = nil
    ) {
        guard systemsEnabled.gesture else { return }

        if let touch = touchState {
            gestureController.updateTouch(touch)
        }
        if let motion = motionState {
            gestureController.updateMotion(motion)
        }
        gestureController.updateHands(left: leftHand, right: rightHand)
        if let pose = bodyPose {
            gestureController.updateBodyPose(pose)
        }

        // Update emotional resonance with movement
        let gestureParams = gestureController.getAllParameters()
        let energy = gestureParams[.volume] ?? 0.5
        emotionalResonance.updateMovement(energy: energy, smoothness: 0.5)
    }

    /// Update lifestyle context
    public func updateLifestyleContext(
        activity: LifestyleScienceEngine.ActivityType? = nil,
        stressLevel: Float? = nil,
        challenge: Float? = nil,
        skill: Float? = nil
    ) {
        guard systemsEnabled.lifestyle else { return }

        if let activity = activity {
            lifestyleEngine.setActivity(activity)
        }
        if let stress = stressLevel {
            lifestyleEngine.updateStress(acute: stress)
        }
        if let challenge = challenge, let skill = skill {
            lifestyleEngine.updateFlowConditions(challenge: challenge, skill: skill)
        }

        lifestyleEngine.state.currentTime = Date()
    }

    /// Update target emotion for regulation
    public func setTargetEmotion(valence: Float, arousal: Float) {
        let target = EmotionalResonanceSystem.DimensionalEmotion(
            valence: valence,
            arousal: arousal,
            dominance: 0
        )
        emotionalResonance.targetEmotion = target
        psychoacousticEngine.setTargetEmotion(valence: valence, arousal: arousal)
    }

    // MARK: - Main Integration

    /// Integrate all systems and update unified state
    public func integrate() {
        updateCounter += 1

        // Update session duration
        if let start = sessionStartTime {
            holisticState.sessionDuration = Date().timeIntervalSince(start)
        }

        // Gather from all subsystems
        integrateEmotional()
        integrateSomatic()
        integrateLifestyle()
        integrateGesture()

        // Calculate derived holistic metrics
        calculateHolisticMetrics()

        // Generate unified audio control
        generateAudioControl()
    }

    /// Integrate emotional state
    private func integrateEmotional() {
        guard systemsEnabled.emotional else { return }

        emotionalResonance.fuseEvidence()
        let emotion = emotionalResonance.currentEmotion

        holisticState.emotionalValence = emotion.dimensional.valence
        holisticState.emotionalArousal = emotion.dimensional.arousal
        holisticState.emotionalDominance = emotion.dimensional.dominance
        holisticState.dominantEmotion = emotion.discrete
    }

    /// Integrate somatic/body state
    private func integrateSomatic() {
        guard systemsEnabled.psychosomatic else { return }

        let bodyState = psychosomaticMapper.bodyState

        holisticState.relaxationLevel = bodyState.relaxationDepth
        holisticState.tensionLevel = bodyState.muscularTension
        holisticState.energyLevel = bodyState.energyLevel
        holisticState.stressLevel = bodyState.stressLevel
        holisticState.coherenceScore = bodyState.coherenceScore / 100
    }

    /// Integrate lifestyle/circadian state
    private func integrateLifestyle() {
        guard systemsEnabled.lifestyle else { return }

        let circadianPhase = lifestyleEngine.getCurrentCircadianPhase()
        let flowConditions = lifestyleEngine.state.flowConditions

        holisticState.circadianPhase = circadianPhase
        holisticState.timeOfDayEnergy = circadianPhase.energyLevel
        holisticState.flowLikelihood = flowConditions.flowLikelihood()
        holisticState.focusLevel = flowConditions.skill  // Proxy for cognitive engagement
    }

    /// Integrate gesture state
    private func integrateGesture() {
        guard systemsEnabled.gesture else { return }

        let gestureParams = gestureController.getAllParameters()

        holisticState.gestureActivity = gestureParams[.volume] ?? 0.5
        holisticState.interactionIntensity = gestureParams[.energy] ?? 0.5
        holisticState.expressiveness = (gestureParams[.brightness] ?? 0.5 +
                                        gestureParams[.modulation] ?? 0.5) / 2
    }

    /// Calculate holistic derived metrics
    private func calculateHolisticMetrics() {
        // Overall wellbeing: composite of valence, relaxation, low stress
        holisticState.overallWellbeing = (
            (holisticState.emotionalValence + 1) / 2 * 0.4 +
            holisticState.relaxationLevel * 0.3 +
            (1 - holisticState.stressLevel) * 0.3
        )

        // Engagement: arousal + gesture + interaction
        holisticState.engagementLevel = (
            (holisticState.emotionalArousal + 1) / 2 * 0.3 +
            holisticState.gestureActivity * 0.4 +
            holisticState.interactionIntensity * 0.3
        )
    }

    // MARK: - Audio Control Generation

    /// Generate unified audio control parameters
    private func generateAudioControl() {
        var control = UnifiedAudioControl()

        // Apply weights based on integration mode
        let weights = getWeightsForMode(integrationMode)

        // === Core parameters ===

        // Tempo: influenced by arousal, circadian, gesture
        let emotionTempo = 80 + (holisticState.emotionalArousal + 1) * 30
        let circadianTempo = lifestyleEngine.getCircadianAudioParameters().targetTempo
        let gestureTempo = gestureController.getValue(for: .tempo) * 100 + 60

        control.tempo = emotionTempo * weights.emotion +
                       circadianTempo * weights.circadian +
                       gestureTempo * weights.gesture

        // Brightness: valence, time of day, gesture
        let emotionBrightness = (holisticState.emotionalValence + 1) / 2 * 0.5 + 0.25
        let circadianBrightness = lifestyleEngine.getCircadianAudioParameters().targetBrightness
        let gestureBrightness = gestureController.getValue(for: .brightness)

        control.brightness = lerp(
            audioControl.brightness,
            emotionBrightness * weights.emotion +
            circadianBrightness * weights.circadian +
            gestureBrightness * weights.gesture,
            transitionSmoothing
        )

        // === Spatial ===

        control.spatialPosition = gestureController.getValue(for: .pan)
        control.stereoWidth = 0.5 + holisticState.relaxationLevel * 0.3
        control.reverbAmount = psychosomaticMapper.bodyState.heartRateVariability / 100 * 0.5

        // === Dynamics ===

        control.dynamicRange = 0.3 + holisticState.energyLevel * 0.4

        // === Filter ===

        let emotionFilter = 1000 + (holisticState.emotionalValence + 1) * 3000
        let gestureFilter = gestureController.getValue(for: .filter) * 10000 + 200

        control.filterCutoff = lerp(
            audioControl.filterCutoff,
            emotionFilter * weights.emotion + gestureFilter * weights.gesture,
            transitionSmoothing
        )

        // === Modulation ===

        control.modulationDepth = holisticState.expressiveness * 0.5
        control.modulationRate = 0.5 + holisticState.emotionalArousal * 0.5

        // === Synthesis parameters ===

        control.grainDensity = 0.3 + holisticState.engagementLevel * 0.5
        control.morphPosition = gestureController.getValue(for: .morphX)

        // === Emotional parameters ===

        control.emotionalIntensity = emotionalResonance.currentEmotion.intensity
        control.emotionalValence = holisticState.emotionalValence

        // Entrainment from lifestyle or stress
        let stressParams = lifestyleEngine.getStressAudioParameters()
        control.entrainmentFrequency = stressParams.entrainmentFrequency

        // === Biofeedback sync ===

        control.heartRateSync = psychosomaticMapper.bodyState.heartRate / 60 * 0.5
        control.breathingSync = psychosomaticMapper.bodyState.breathingRate / 20
        control.coherenceTone = holisticState.coherenceScore

        // Store with smoothing applied
        audioControl = smoothControl(from: audioControl, to: control)
    }

    /// Get weights for integration mode
    private func getWeightsForMode(_ mode: IntegrationMode) -> (emotion: Float, somatic: Float, gesture: Float, circadian: Float) {
        switch mode {
        case .balanced:
            return (0.33, 0.33, 0.33, 0.2)
        case .emotionPriority:
            return (0.6, 0.2, 0.2, 0.1)
        case .bodyPriority:
            return (0.2, 0.6, 0.2, 0.1)
        case .gesturePriority:
            return (0.15, 0.15, 0.7, 0.05)
        case .circadianAware:
            return (0.2, 0.2, 0.2, 0.5)
        case .therapeutic:
            return (0.3, 0.4, 0.1, 0.3)
        case .performance:
            return (0.2, 0.2, 0.6, 0.05)
        }
    }

    /// Apply smoothing to control parameters
    private func smoothControl(from old: UnifiedAudioControl, to new: UnifiedAudioControl) -> UnifiedAudioControl {
        var result = new

        result.tempo = lerp(old.tempo, new.tempo, transitionSmoothing)
        result.brightness = lerp(old.brightness, new.brightness, transitionSmoothing)
        result.warmth = lerp(old.warmth, new.warmth, transitionSmoothing)
        result.filterCutoff = lerp(old.filterCutoff, new.filterCutoff, transitionSmoothing)
        result.modulationDepth = lerp(old.modulationDepth, new.modulationDepth, transitionSmoothing)
        result.reverbAmount = lerp(old.reverbAmount, new.reverbAmount, transitionSmoothing)

        return result
    }

    // MARK: - Audio Processing

    /// Process audio with all integrated systems
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Run integration update at specified rate
        let samplesPerUpdate = Int(sampleRate) / updateRate
        if updateCounter % samplesPerUpdate == 0 {
            integrate()
        }

        // Apply each enabled system
        if systemsEnabled.psychoacoustic {
            psychoacousticEngine.process(buffer: buffer, frameCount: frameCount)
        }

        if systemsEnabled.psychosomatic {
            psychosomaticMapper.process(buffer: buffer, frameCount: frameCount)
        }

        if systemsEnabled.lifestyle {
            lifestyleEngine.process(buffer: buffer, frameCount: frameCount)
        }

        if systemsEnabled.emotional {
            emotionalResonance.process(buffer: buffer, frameCount: frameCount)
        }

        // Apply master volume
        var vol = audioControl.masterVolume
        vDSP_vsmul(buffer, 1, &vol, buffer, 1, vDSP_Length(frameCount))
    }

    // MARK: - Session Insights

    /// Get session summary
    public func getSessionSummary() -> SessionSummary {
        var summary = SessionSummary()

        summary.duration = holisticState.sessionDuration
        summary.averageWellbeing = holisticState.overallWellbeing
        summary.averageEngagement = holisticState.engagementLevel
        summary.dominantEmotion = holisticState.dominantEmotion
        summary.flowTimeRatio = holisticState.flowLikelihood > 0.5 ? 0.5 : 0.2  // Simplified
        summary.coherenceAchieved = holisticState.coherenceScore > 0.5

        // Trend from emotional resonance
        let trend = emotionalResonance.getEmotionTrend()
        summary.emotionalTrend = trend.overallTrend == .improving ? .positive :
                                (trend.overallTrend == .declining ? .negative : .neutral)

        return summary
    }

    /// Session summary
    public struct SessionSummary {
        public var duration: TimeInterval = 0
        public var averageWellbeing: Float = 0
        public var averageEngagement: Float = 0
        public var dominantEmotion: EmotionalResonanceSystem.DiscreteEmotion = .neutral
        public var flowTimeRatio: Float = 0
        public var coherenceAchieved: Bool = false
        public var emotionalTrend: Trend = .neutral

        public enum Trend { case positive, neutral, negative }
    }

    // MARK: - Utility

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    /// Reset all systems
    public func reset() {
        psychoacousticEngine.reset()
        psychosomaticMapper.reset()
        lifestyleEngine.reset()
        gestureController.reset()
        emotionalResonance.reset()

        holisticState = HolisticState()
        audioControl = UnifiedAudioControl()
        sessionStartTime = Date()
        updateCounter = 0
    }

    /// Set sample rate for all systems
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
        psychoacousticEngine.setSampleRate(rate)
        psychosomaticMapper.setSampleRate(rate)
        lifestyleEngine.setSampleRate(rate)
        emotionalResonance.setSampleRate(rate)
    }

    /// Start new session
    public func startSession() {
        reset()
        sessionStartTime = Date()
    }

    /// End session and get summary
    public func endSession() -> SessionSummary {
        let summary = getSessionSummary()
        // Could save session data here
        return summary
    }
}

// MARK: - Presets

extension MindBodyAudioBridge {

    /// Experience presets
    public enum ExperiencePreset: String, CaseIterable {
        case meditation = "Meditation"
        case creativity = "Creativity"
        case focus = "Focus"
        case relaxation = "Relaxation"
        case energy = "Energy"
        case healing = "Healing"
        case performance = "Performance"
        case sleep = "Sleep"
        case exploration = "Exploration"

        public func apply(to bridge: MindBodyAudioBridge) {
            switch self {
            case .meditation:
                bridge.integrationMode = .therapeutic
                bridge.psychoacousticEngine.mode = .relaxation
                bridge.psychosomaticMapper.applyPreset(.meditation)
                bridge.emotionalResonance.resonanceMode = .regulate
                bridge.setTargetEmotion(valence: 0.3, arousal: -0.5)

            case .creativity:
                bridge.integrationMode = .balanced
                bridge.psychoacousticEngine.mode = .flowState
                bridge.gestureController.applyPreset(.expressive)
                bridge.emotionalResonance.resonanceMode = .amplify

            case .focus:
                bridge.integrationMode = .circadianAware
                bridge.psychoacousticEngine.mode = .attention
                bridge.lifestyleEngine.setActivity(.focusedWork)
                bridge.emotionalResonance.resonanceMode = .neutral

            case .relaxation:
                bridge.integrationMode = .bodyPriority
                bridge.psychoacousticEngine.mode = .relaxation
                bridge.psychosomaticMapper.applyPreset(.stressRelief)
                bridge.emotionalResonance.resonanceMode = .regulate
                bridge.setTargetEmotion(valence: 0.4, arousal: -0.4)

            case .energy:
                bridge.integrationMode = .gesturePriority
                bridge.psychoacousticEngine.mode = .activation
                bridge.gestureController.applyPreset(.performance)
                bridge.emotionalResonance.resonanceMode = .amplify

            case .healing:
                bridge.integrationMode = .therapeutic
                bridge.psychoacousticEngine.mode = .musicalAnalgesia
                bridge.psychosomaticMapper.applyPreset(.healing)
                bridge.emotionalResonance.resonanceMode = .regulate
                bridge.setTargetEmotion(valence: 0.5, arousal: -0.3)

            case .performance:
                bridge.integrationMode = .performance
                bridge.gestureController.applyPreset(.performance)
                bridge.emotionalResonance.resonanceMode = .mirror

            case .sleep:
                bridge.integrationMode = .therapeutic
                bridge.psychoacousticEngine.mode = .relaxation
                bridge.psychosomaticMapper.applyPreset(.sleep)
                bridge.lifestyleEngine.applyPreset(.sleepPreparation)
                bridge.emotionalResonance.resonanceMode = .regulate
                bridge.setTargetEmotion(valence: 0.2, arousal: -0.8)

            case .exploration:
                bridge.integrationMode = .balanced
                bridge.gestureController.applyPreset(.theremin)
                bridge.emotionalResonance.resonanceMode = .mirror
            }
        }
    }

    /// Apply experience preset
    public func applyPreset(_ preset: ExperiencePreset) {
        preset.apply(to: self)
    }
}
