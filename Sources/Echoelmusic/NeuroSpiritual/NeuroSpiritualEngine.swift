// NeuroSpiritualEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Neuro-Spiritual Psychosomatic Data Science Engine
// Integration von Mimik, Gestik, Bewegung, Biofeedback und Bewusstseinszuständen
//
// Wissenschaftliche Basis:
// - Polyvagal Theory (Stephen Porges)
// - Embodied Cognition (Varela, Thompson, Rosch)
// - Psychoneuroimmunology (PNI)
// - Heart-Brain Communication (HeartMath Institute)
// - Somatic Experiencing (Peter Levine)
//
// HINWEIS: Spirituelle Features sind für kreative/meditative Zwecke.
// Keine religiösen oder medizinischen Ansprüche.

import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(ARKit)
import ARKit
#endif
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Consciousness States

/// Bewusstseinszustände basierend auf Brainwave-Korrelaten
public enum ConsciousnessState: String, CaseIterable, Codable {
    // Primäre Bewusstseinszustände
    case deepSleep = "deep_sleep"           // Delta 0.5-4 Hz
    case dreamState = "dream_state"          // Theta 4-8 Hz (REM)
    case relaxedAwareness = "relaxed"        // Alpha 8-12 Hz
    case focusedAttention = "focused"        // Beta 12-30 Hz
    case highPerformance = "high_performance" // High Beta 20-30 Hz
    case transcendent = "transcendent"       // Gamma 30-100 Hz

    // Erweiterte Bewusstseinszustände
    case flowState = "flow"                  // Theta-Alpha Border + Gamma
    case meditativeAbsorption = "absorption" // Tiefes Theta + Gamma
    case lucidDreaming = "lucid"             // Theta + Gamma awareness
    case unitiveExperience = "unitive"       // Gamma Hypersynchrony

    public var dominantBrainwave: String {
        switch self {
        case .deepSleep: return "Delta (0.5-4 Hz)"
        case .dreamState: return "Theta (4-8 Hz)"
        case .relaxedAwareness: return "Alpha (8-12 Hz)"
        case .focusedAttention: return "Low Beta (12-20 Hz)"
        case .highPerformance: return "High Beta (20-30 Hz)"
        case .transcendent: return "Gamma (30-100 Hz)"
        case .flowState: return "Theta-Alpha-Gamma Mix"
        case .meditativeAbsorption: return "Deep Theta + Gamma Bursts"
        case .lucidDreaming: return "Theta + Frontal Gamma"
        case .unitiveExperience: return "Global Gamma Synchrony (40Hz)"
        }
    }

    public var hrvSignature: (lowSDNN: Double, highSDNN: Double, coherence: Double) {
        switch self {
        case .deepSleep: return (30, 60, 0.3)
        case .dreamState: return (40, 80, 0.4)
        case .relaxedAwareness: return (50, 100, 0.7)
        case .focusedAttention: return (40, 70, 0.5)
        case .highPerformance: return (35, 60, 0.4)
        case .transcendent: return (60, 120, 0.9)
        case .flowState: return (50, 90, 0.8)
        case .meditativeAbsorption: return (70, 150, 0.95)
        case .lucidDreaming: return (50, 100, 0.6)
        case .unitiveExperience: return (80, 180, 0.98)
        }
    }

    public var audioFrequency: Double {
        switch self {
        case .deepSleep: return 2.0
        case .dreamState: return 6.0
        case .relaxedAwareness: return 10.0
        case .focusedAttention: return 15.0
        case .highPerformance: return 25.0
        case .transcendent: return 40.0
        case .flowState: return 10.0  // Alpha dominant
        case .meditativeAbsorption: return 6.0
        case .lucidDreaming: return 7.83  // Schumann Resonance
        case .unitiveExperience: return 40.0  // Gamma
        }
    }
}

// MARK: - Polyvagal States (Stephen Porges)

/// Autonomes Nervensystem Zustände nach Polyvagal Theory
public enum PolyvagalState: String, CaseIterable, Codable {
    case ventralVagal = "ventral_vagal"      // Social engagement, safe
    case sympathetic = "sympathetic"          // Fight/Flight
    case dorsalVagal = "dorsal_vagal"        // Freeze/Shutdown
    case blendedVentralSympathetic = "play"  // Play, healthy mobilization
    case blendedVentralDorsal = "stillness"  // Deep rest, intimacy

    public var description: String {
        switch self {
        case .ventralVagal:
            return "Soziales Engagement: Sicher, verbunden, präsent"
        case .sympathetic:
            return "Mobilisierung: Kampf/Flucht, Stress, Angst"
        case .dorsalVagal:
            return "Immobilisierung: Erstarrung, Dissoziation, Shutdown"
        case .blendedVentralSympathetic:
            return "Spiel: Sichere Mobilisierung, Sport, Tanz, Lachen"
        case .blendedVentralDorsal:
            return "Tiefe Ruhe: Meditation, Intimität, Geborgenheit"
        }
    }

    public var facialIndicators: [String] {
        switch self {
        case .ventralVagal:
            return ["Entspannte Augenbrauen", "Echtes Lächeln (Duchenne)", "Weiches Gesicht", "Augenkontakt"]
        case .sympathetic:
            return ["Weite Augen", "Angespannte Kiefer", "Zusammengepresste Lippen", "Flacher Blick"]
        case .dorsalVagal:
            return ["Leerer Blick", "Gesenkter Kopf", "Flaches Gesicht", "Vermeidung Augenkontakt"]
        case .blendedVentralSympathetic:
            return ["Leuchtende Augen", "Spielerisches Lächeln", "Bewegtes Gesicht"]
        case .blendedVentralDorsal:
            return ["Sanfter Blick", "Entspannte Züge", "Weiche Augen"]
        }
    }

    public var bodyIndicators: [String] {
        switch self {
        case .ventralVagal:
            return ["Aufrechte Haltung", "Offene Gestik", "Fließende Bewegungen", "Entspannte Schultern"]
        case .sympathetic:
            return ["Anspannung", "Schnelle Bewegungen", "Unruhe", "Erhöhte Schultern"]
        case .dorsalVagal:
            return ["Zusammengesunken", "Wenig Bewegung", "Langsam", "Schwere"]
        case .blendedVentralSympathetic:
            return ["Energetisch", "Rhythmisch", "Spielerisch", "Koordiniert"]
        case .blendedVentralDorsal:
            return ["Tiefe Entspannung", "Stillheit", "Schwere aber sicher"]
        }
    }

    public var coherenceCorrelation: Double {
        switch self {
        case .ventralVagal: return 0.85
        case .sympathetic: return 0.35
        case .dorsalVagal: return 0.25
        case .blendedVentralSympathetic: return 0.7
        case .blendedVentralDorsal: return 0.9
        }
    }
}

// MARK: - Facial Expression Analysis

/// Emotionale Ausdrücke basierend auf FACS (Facial Action Coding System)
public struct FacialExpressionData: Codable {
    // Primäre Emotionen (Ekman)
    public var joy: Double = 0          // 0-1
    public var sadness: Double = 0
    public var anger: Double = 0
    public var fear: Double = 0
    public var disgust: Double = 0
    public var surprise: Double = 0
    public var contempt: Double = 0

    // Komplexere States
    public var engagement: Double = 0    // Aufmerksamkeit
    public var confusion: Double = 0
    public var frustration: Double = 0
    public var determination: Double = 0
    public var serenity: Double = 0      // Friedlich
    public var awe: Double = 0           // Ehrfurcht

    // FACS Action Units
    public var browRaise: Double = 0     // AU1+2
    public var browFurrow: Double = 0    // AU4
    public var eyeWiden: Double = 0      // AU5
    public var cheekRaise: Double = 0    // AU6 (echter Smile)
    public var lipCornerPull: Double = 0 // AU12 (Lächeln)
    public var lipCornerDepress: Double = 0 // AU15 (Traurigkeit)
    public var jawDrop: Double = 0       // AU26

    // Duchenne Smile Detection (echtes Lächeln)
    public var isDuchenneSmile: Bool {
        return cheekRaise > 0.5 && lipCornerPull > 0.5
    }

    // Polyvagal State Inference
    public var inferredPolyvagalState: PolyvagalState {
        if isDuchenneSmile && engagement > 0.5 {
            return .ventralVagal
        } else if fear > 0.4 || anger > 0.4 {
            return .sympathetic
        } else if sadness > 0.5 && engagement < 0.3 {
            return .dorsalVagal
        } else if joy > 0.5 && surprise > 0.3 {
            return .blendedVentralSympathetic
        } else if serenity > 0.6 {
            return .blendedVentralDorsal
        }
        return .ventralVagal
    }
}

// MARK: - Gesture Analysis

/// Gestik-Daten für psychosomatische Analyse
public struct GestureData: Codable {
    // Hand Position
    public var leftHandPosition: SIMD3<Float> = .zero
    public var rightHandPosition: SIMD3<Float> = .zero

    // Hand Openness (0 = Faust, 1 = offen)
    public var leftHandOpenness: Double = 0.5
    public var rightHandOpenness: Double = 0.5

    // Gesture Types
    public var isPointing: Bool = false
    public var isWaving: Bool = false
    public var isGrasping: Bool = false
    public var isPushingAway: Bool = false
    public var isPullingIn: Bool = false
    public var isShielding: Bool = false
    public var isOpenPalm: Bool = false

    // Heart-Centered Gestures
    public var handsNearHeart: Bool = false
    public var handsNearHead: Bool = false
    public var handsNearGut: Bool = false

    // Gesture Quality
    public var gestureSpeed: Double = 0      // m/s
    public var gestureAmplitude: Double = 0  // Bewegungsbereich
    public var gestureSymmetry: Double = 0.5 // 0-1 wie symmetrisch

    // Psychosomatic Interpretation
    public var opennesScore: Double {
        return (leftHandOpenness + rightHandOpenness) / 2 *
               (isOpenPalm ? 1.2 : 1.0) *
               (isPushingAway ? 0.5 : 1.0)
    }

    public var expressivityScore: Double {
        return min(1.0, gestureAmplitude * gestureSpeed)
    }
}

// MARK: - Body Movement Analysis

/// Körperbewegungsdaten für somatische Analyse
public struct BodyMovementData: Codable {
    // Posture
    public var headTilt: Double = 0          // Grad, 0 = gerade
    public var shoulderSymmetry: Double = 1  // 0-1
    public var spineAlignment: Double = 1    // 0-1

    // Center of Mass
    public var centerOfMassX: Float = 0
    public var centerOfMassY: Float = 0
    public var centerOfMassZ: Float = 0

    // Movement Quality
    public var overallMovement: Double = 0   // 0-1 Aktivitätslevel
    public var movementFluidity: Double = 0  // 0-1 fließend vs. ruckartig
    public var movementRhythmicity: Double = 0  // 0-1 rhythmisch

    // Breathing-Correlated Movement
    public var breathingDepth: Double = 0    // 0-1
    public var breathingRate: Double = 12    // Atemzüge/Minute
    public var chestExpansion: Double = 0    // 0-1

    // Grounding
    public var groundingScore: Double = 0    // 0-1 wie geerdet

    // Reich/Lowen Body Segments (Somatische Psychologie)
    public var ocularTension: Double = 0     // Augen
    public var oralTension: Double = 0       // Mund/Kiefer
    public var cervicalTension: Double = 0   // Nacken
    public var thoracicTension: Double = 0   // Brust
    public var diaphragmaticTension: Double = 0  // Zwerchfell
    public var abdominalTension: Double = 0  // Bauch
    public var pelvicTension: Double = 0     // Becken

    // Overall Tension Score
    public var overallTension: Double {
        return (ocularTension + oralTension + cervicalTension + thoracicTension +
                diaphragmaticTension + abdominalTension + pelvicTension) / 7.0
    }
}

// MARK: - Psychosomatic Integration

/// Integrierte psychosomatische Daten
public struct PsychosomaticState: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date

    // Input Data
    public var facialExpression: FacialExpressionData
    public var gesture: GestureData
    public var bodyMovement: BodyMovementData

    // Biometric Integration
    public var heartRate: Double = 70
    public var hrvSDNN: Double = 50
    public var hrvRMSSD: Double = 40
    public var coherenceRatio: Double = 0.5
    public var breathingRate: Double = 12

    // Inferred States
    public var polyvagalState: PolyvagalState = .ventralVagal
    public var consciousnessState: ConsciousnessState = .relaxedAwareness
    public var emotionalValence: Double = 0  // -1 (negative) to +1 (positive)
    public var emotionalArousal: Double = 0.5  // 0 (calm) to 1 (activated)

    // Composite Scores
    public var wellbeingScore: Double = 0.5      // 0-1
    public var presenceScore: Double = 0.5       // 0-1 (mindfulness)
    public var embodimentScore: Double = 0.5     // 0-1 (body awareness)
    public var connectionScore: Double = 0.5     // 0-1 (social engagement ready)

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        facialExpression: FacialExpressionData = FacialExpressionData(),
        gesture: GestureData = GestureData(),
        bodyMovement: BodyMovementData = BodyMovementData()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.facialExpression = facialExpression
        self.gesture = gesture
        self.bodyMovement = bodyMovement
    }
}

// MARK: - Neuro-Spiritual Engine

@MainActor
public final class NeuroSpiritualEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentState: PsychosomaticState = PsychosomaticState()
    @Published public private(set) var polyvagalState: PolyvagalState = .ventralVagal
    @Published public private(set) var consciousnessState: ConsciousnessState = .relaxedAwareness
    @Published public private(set) var overallCoherence: Double = 0.5
    @Published public private(set) var spiritualResonance: Double = 0.5

    // Session Tracking
    @Published public private(set) var sessionDuration: TimeInterval = 0
    @Published public private(set) var peakExperiences: [PsychosomaticState] = []
    @Published public private(set) var stateHistory: [PsychosomaticState] = []

    // MARK: - Private Properties

    #if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    #endif
    private var sessionStartTime: Date?
    private var updateTimer: Timer?

    // MARK: - Constants

    /// Schumann Resonance (Erd-Resonanzfrequenz - scientifically measured at ~7.83Hz)
    public static let schumannResonance: Double = 7.83

    /// 528Hz - Traditional Solfeggio Frequency (Cultural/Historical - NOT scientifically proven for "healing")
    /// NOTE: Used for subjective wellness/relaxation experience. No medical claims.
    public static let solfeggioMI: Double = 528.0

    /// Coherence Breathing Rate (6/min = 0.1Hz)
    public static let coherenceBreathingRate: Double = 6.0

    // MARK: - Singleton

    public static let shared = NeuroSpiritualEngine()

    // MARK: - Initialization

    public init() {
        startMotionTracking()
    }

    deinit {
        stopMotionTracking()
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Startet eine Neuro-Spiritual Session
    public func startSession() {
        sessionStartTime = Date()
        stateHistory = []
        peakExperiences = []

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSession()
            }
        }
    }

    /// Stoppt die aktuelle Session
    public func stopSession() {
        updateTimer?.invalidate()
        updateTimer = nil

        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }
        sessionStartTime = nil
    }

    /// Aktualisiert Gesichtsdaten (von ARKit/Vision)
    public func updateFacialExpression(_ expression: FacialExpressionData) {
        currentState.facialExpression = expression
        polyvagalState = expression.inferredPolyvagalState
        calculateCompositeScores()
    }

    /// Aktualisiert Gestik-Daten
    public func updateGesture(_ gesture: GestureData) {
        currentState.gesture = gesture
        calculateCompositeScores()
    }

    /// Aktualisiert Bewegungsdaten
    public func updateBodyMovement(_ movement: BodyMovementData) {
        currentState.bodyMovement = movement
        calculateCompositeScores()
    }

    /// Aktualisiert Biometrie (HRV, HR)
    public func updateBiometrics(heartRate: Double, hrvSDNN: Double, hrvRMSSD: Double, coherence: Double) {
        currentState.heartRate = heartRate
        currentState.hrvSDNN = hrvSDNN
        currentState.hrvRMSSD = hrvRMSSD
        currentState.coherenceRatio = coherence
        overallCoherence = coherence

        inferConsciousnessState()
        calculateCompositeScores()
    }

    /// Berechnet optimale Audio-Parameter für aktuellen Zustand
    public func getOptimalAudioParameters() -> (frequency: Double, carrier: Double, volume: Double) {
        let targetFrequency = consciousnessState.audioFrequency

        // Carrier basierend auf Zustand (traditionelle Solfeggio-Frequenzen für subjektives Wohlbefinden)
        // HINWEIS: Keine medizinischen Wirkungen wissenschaftlich nachgewiesen
        let carrier: Double
        switch polyvagalState {
        case .ventralVagal, .blendedVentralDorsal:
            carrier = Self.solfeggioMI  // 528Hz - traditionell mit Wohlbefinden assoziiert
        case .sympathetic:
            carrier = 432.0  // Traditionell "entspannend" genannt
        case .dorsalVagal:
            carrier = 396.0  // Traditionell "UT" Solfeggio
        case .blendedVentralSympathetic:
            carrier = 440.0  // Aktivierend
        }

        // Lautstärke basierend auf Zustand
        let volume = 0.3 + (overallCoherence * 0.4)  // 30-70%

        return (targetFrequency, carrier, volume)
    }

    /// Berechnet optimale Lichtfarbe für aktuellen Zustand
    /// Farben basieren auf Chromotherapie-Tradition (subjektives Wohlbefinden, keine medizinischen Ansprüche)
    public func getOptimalLightColor() -> (r: Float, g: Float, b: Float) {
        switch polyvagalState {
        case .ventralVagal:
            // Smaragdgrün - traditionell mit Ruhe assoziiert
            return (0.0, 0.79, 0.34)
        case .sympathetic:
            // Warmes Orange - traditionell beruhigend
            return (1.0, 0.6, 0.3)
        case .dorsalVagal:
            // Sanftes Rosa - warm und einladend
            return (1.0, 0.7, 0.8)
        case .blendedVentralSympathetic:
            // Energetisches Cyan - aktivierend
            return (0.0, 0.9, 0.9)
        case .blendedVentralDorsal:
            // Tiefes Indigo - meditativ
            return (0.3, 0.3, 0.7)
        }
    }

    // MARK: - Private Methods

    private func startMotionTracking() {
        #if canImport(CoreMotion)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates()
        }
        #endif
    }

    private func stopMotionTracking() {
        #if canImport(CoreMotion)
        motionManager.stopDeviceMotionUpdates()
        #endif
    }

    private func updateSession() {
        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }

        // Speichere aktuellen State
        let stateCopy = currentState
        stateHistory.append(stateCopy)

        // Erkenne Peak Experiences
        if currentState.coherenceRatio > 0.9 && currentState.wellbeingScore > 0.85 {
            peakExperiences.append(stateCopy)
        }

        // Limitiere History
        if stateHistory.count > 3600 {  // 1 Stunde bei 1Hz
            stateHistory.removeFirst()
        }
    }

    private func inferConsciousnessState() {
        let hrv = currentState.hrvSDNN
        let coherence = currentState.coherenceRatio
        let arousal = currentState.emotionalArousal

        if coherence > 0.9 && hrv > 100 {
            consciousnessState = .meditativeAbsorption
        } else if coherence > 0.8 && arousal < 0.3 {
            consciousnessState = .transcendent
        } else if coherence > 0.7 && arousal > 0.5 && arousal < 0.7 {
            consciousnessState = .flowState
        } else if arousal > 0.7 {
            consciousnessState = .highPerformance
        } else if arousal > 0.4 {
            consciousnessState = .focusedAttention
        } else if coherence > 0.5 {
            consciousnessState = .relaxedAwareness
        } else if hrv < 30 {
            consciousnessState = .deepSleep
        } else {
            consciousnessState = .dreamState
        }
    }

    private func calculateCompositeScores() {
        // Wellbeing Score
        let emotionalPositivity = max(0, currentState.emotionalValence) + 0.5
        let physiologicalBalance = currentState.coherenceRatio
        let bodyRelaxation = 1.0 - currentState.bodyMovement.overallTension
        currentState.wellbeingScore = (emotionalPositivity + physiologicalBalance + bodyRelaxation) / 3.0

        // Presence Score (Mindfulness)
        let facialEngagement = currentState.facialExpression.engagement
        let breathingRegularity = currentState.bodyMovement.breathingDepth
        let movementStillness = 1.0 - currentState.bodyMovement.overallMovement
        currentState.presenceScore = (facialEngagement + breathingRegularity + movementStillness * 0.5) / 2.5

        // Embodiment Score
        let gestureExpressivity = currentState.gesture.expressivityScore
        let movementFluidity = currentState.bodyMovement.movementFluidity
        let grounding = currentState.bodyMovement.groundingScore
        currentState.embodimentScore = (gestureExpressivity + movementFluidity + grounding) / 3.0

        // Connection Score (Social Engagement Readiness)
        let ventralVagalActive = polyvagalState == .ventralVagal ? 1.0 :
                                 polyvagalState == .blendedVentralSympathetic ? 0.8 : 0.4
        let facialOpenness = currentState.facialExpression.isDuchenneSmile ? 1.0 : 0.5
        let gestureOpenness = currentState.gesture.opennesScore
        currentState.connectionScore = (ventralVagalActive + facialOpenness + gestureOpenness) / 3.0

        // Spiritual Resonance (Composite)
        spiritualResonance = (currentState.wellbeingScore +
                              currentState.presenceScore +
                              currentState.coherenceRatio +
                              (consciousnessState == .transcendent ? 0.3 : 0)) / 3.3
    }
}

// MARK: - Spiritual Disclaimer

public struct NeuroSpiritualDisclaimer {
    public static let text = """
    HINWEIS ZU SPIRITUELLEN FUNKTIONEN
    ===================================

    Die in dieser App verwendeten Begriffe wie "spirituell", "Bewusstsein",
    "Transzendenz" und ähnliche werden im Kontext von:

    - Wissenschaftlicher Psychologie (Flow-Zustände, Achtsamkeit)
    - Neurowissenschaft (Brainwave-Zustände, Default Mode Network)
    - Polyvagale Theorie (Autonomes Nervensystem)
    - Herzkohärenz-Forschung (HeartMath Institute)

    verwendet und beziehen sich NICHT auf religiöse Überzeugungen.

    Diese Funktionen sind für:
    ✓ Meditation und Entspannung
    ✓ Kreative Exploration
    ✓ Selbstreflexion
    ✓ Stressmanagement

    Sie sind NICHT für:
    ✗ Religiöse Praktiken
    ✗ Medizinische Diagnose oder Behandlung
    ✗ Therapeutische Interventionen

    Bei psychischen Belastungen wenden Sie sich an einen
    qualifizierten Therapeuten oder Arzt.
    """
}
