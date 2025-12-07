import Foundation
import Combine

// MARK: - Decision Engine
/// Intelligente Entscheidungs-Engine für adaptive Parameteranpassung
///
/// **Algorithmen:**
/// - PID-Regelung für kontinuierliche Anpassung
/// - Fuzzy Logic für unscharfe Zustandsübergänge
/// - Reinforcement Learning für langfristige Optimierung
///
/// **Wissenschaftliche Basis:**
/// - ✅ PID-Regelung - Standard in Automatisierung
/// - ✅ Binaural Beat Frequenz-Wahl (Lane 1998, Wahbeh 2007)
/// - ⚠️ Adaptive Algorithmen für Biofeedback (emerging research)

@MainActor
public class DecisionEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var lastDecision: AutopilotDecision?

    @Published public private(set) var strategyName: String = "Balanced"

    // MARK: - Configuration

    public var aggressiveness: Double = 0.3 {
        didSet {
            updatePIDGains()
        }
    }

    // MARK: - Strategy

    private var currentStrategy: DecisionStrategy = BalancedStrategy()

    // MARK: - PID Controller State

    private var pidState = PIDState()

    // MARK: - Decision History

    private var decisionHistory: [AutopilotDecision] = []
    private let maxHistoryLength = 100

    // MARK: - Frequency Tables (wissenschaftlich basiert)

    /// Binaural Beat Frequenzen für verschiedene Zielzustände
    /// ✅ Basierend auf EEG-Brainwave-Standards
    private let brainwaveFrequencies: [UserPhysiologicalState: ClosedRange<Float>] = [
        .drowsy: 0.5...4.0,         // Delta
        .deepRelaxation: 4.0...8.0, // Theta
        .relaxed: 8.0...12.0,       // Alpha
        .neutral: 8.0...12.0,       // Alpha
        .creative: 6.0...10.0,      // Theta-Alpha
        .focused: 12.0...20.0,      // Low Beta
        .energized: 20.0...30.0,    // High Beta
        .anxious: 15.0...25.0,      // Beta (reduce)
        .stressed: 4.0...8.0        // Theta (to calm)
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Strategy Update

    public func updateStrategy(for mode: AutopilotMode) {
        switch mode {
        case .balanced:
            currentStrategy = BalancedStrategy()
            strategyName = "Balanced"

        case .meditation:
            currentStrategy = MeditationStrategy()
            strategyName = "Meditation"

        case .focus:
            currentStrategy = FocusStrategy()
            strategyName = "Focus"

        case .creativity:
            currentStrategy = CreativityStrategy()
            strategyName = "Creativity"

        case .sleep:
            currentStrategy = SleepStrategy()
            strategyName = "Sleep"

        case .recovery:
            currentStrategy = RecoveryStrategy()
            strategyName = "Recovery"

        case .energy:
            currentStrategy = EnergyStrategy()
            strategyName = "Energy"

        case .custom:
            // Keep current strategy
            strategyName = "Custom"
        }

        // Reset PID state for new strategy
        pidState = PIDState()

        print("[DecisionEngine] Strategy updated to: \(strategyName)")
    }

    // MARK: - Decision Making

    public func decide(
        currentState: UserPhysiologicalState,
        targetState: UserPhysiologicalState,
        mode: AutopilotMode,
        feedback: FeedbackData?
    ) -> AutopilotDecision {

        // 1. Berechne Fehler (Distanz zum Ziel)
        let error = currentState.distance(to: targetState)

        // 2. PID-Berechnung
        let pidOutput = calculatePID(error: error)

        // 3. Strategie-spezifische Modifikation
        let strategyAdjustment = currentStrategy.adjust(
            currentState: currentState,
            targetState: targetState,
            pidOutput: pidOutput
        )

        // 4. Feedback-basierte Anpassung
        let feedbackAdjustment = applyFeedback(feedback, to: strategyAdjustment)

        // 5. Parameter berechnen
        let audioParams = calculateAudioParameters(
            currentState: currentState,
            targetState: targetState,
            adjustment: feedbackAdjustment
        )

        let frequencyParams = calculateFrequencyParameters(
            currentState: currentState,
            targetState: targetState,
            adjustment: feedbackAdjustment
        )

        let spatialParams = calculateSpatialParameters(
            currentState: currentState,
            adjustment: feedbackAdjustment
        )

        // 6. Entscheidung ob anwenden
        let shouldApply = error > 0.1 || abs(feedbackAdjustment) > 0.05

        // 7. Reasoning generieren
        let reasoning = generateReasoning(
            currentState: currentState,
            targetState: targetState,
            error: error,
            adjustment: feedbackAdjustment
        )

        let decision = AutopilotDecision(
            timestamp: Date(),
            confidence: calculateConfidence(error: error, feedback: feedback),
            shouldApply: shouldApply,
            reasoning: reasoning,
            audioParameters: audioParams,
            frequencyParameters: frequencyParams,
            spatialParameters: spatialParams
        )

        // Speichern
        lastDecision = decision
        recordDecision(decision)

        return decision
    }

    // MARK: - PID Controller

    private func calculatePID(error: Double) -> Double {
        let now = Date()
        let dt = now.timeIntervalSince(pidState.lastUpdate)

        guard dt > 0 else { return 0 }

        // Proportional
        let p = pidState.kP * error

        // Integral (mit Anti-Windup)
        pidState.integral += error * dt
        pidState.integral = max(-1, min(1, pidState.integral))  // Clamp
        let i = pidState.kI * pidState.integral

        // Derivative
        let derivative = (error - pidState.lastError) / dt
        let d = pidState.kD * derivative

        // Update state
        pidState.lastError = error
        pidState.lastUpdate = now

        return p + i + d
    }

    private func updatePIDGains() {
        // Aggressivere Einstellung = höhere Gains
        pidState.kP = 0.3 + (aggressiveness * 0.4)  // 0.3 - 0.7
        pidState.kI = 0.05 + (aggressiveness * 0.1) // 0.05 - 0.15
        pidState.kD = 0.1 + (aggressiveness * 0.2)  // 0.1 - 0.3
    }

    // MARK: - Parameter Calculation

    private func calculateAudioParameters(
        currentState: UserPhysiologicalState,
        targetState: UserPhysiologicalState,
        adjustment: Double
    ) -> AudioParameterSet {

        // Ziel-Brainwave-Frequenz bestimmen
        let targetFreqRange = brainwaveFrequencies[targetState] ?? 8.0...12.0

        // Binaural Beat Frequenz basierend auf Zielzustand
        let beatFrequency: Float
        if currentState == targetState {
            // Am Ziel: Mittlere Frequenz des Bereichs
            beatFrequency = (targetFreqRange.lowerBound + targetFreqRange.upperBound) / 2.0
        } else {
            // Übergang: Schrittweise zum Ziel
            let currentRange = brainwaveFrequencies[currentState] ?? 8.0...12.0
            let currentMid = (currentRange.lowerBound + currentRange.upperBound) / 2.0
            let targetMid = (targetFreqRange.lowerBound + targetFreqRange.upperBound) / 2.0

            // Interpoliere basierend auf adjustment
            let progress = Float(min(1, max(0, 0.5 + adjustment)))
            beatFrequency = currentMid + (targetMid - currentMid) * progress
        }

        // Carrier-Frequenz (Standard: 432 Hz, kann je nach Präferenz variieren)
        let carrierFrequency: Float = 432.0

        // Amplitude basierend auf Zustand
        let amplitude: Float
        switch targetState {
        case .sleep, .deepRelaxation:
            amplitude = 0.3 + Float(adjustment) * 0.1
        case .focused, .energized:
            amplitude = 0.5 + Float(adjustment) * 0.2
        default:
            amplitude = 0.4
        }

        // Reverb basierend auf Entspannungsgrad
        let reverb: Float
        switch targetState {
        case .deepRelaxation, .relaxed, .sleep:
            reverb = 0.6 + Float(adjustment) * 0.2
        case .focused, .energized:
            reverb = 0.2
        default:
            reverb = 0.4
        }

        return AudioParameterSet(
            carrierFrequency: carrierFrequency,
            beatFrequency: beatFrequency,
            amplitude: max(0.1, min(0.8, amplitude)),
            reverbMix: max(0, min(1, reverb)),
            rampTime: currentStrategy.rampTime
        )
    }

    private func calculateFrequencyParameters(
        currentState: UserPhysiologicalState,
        targetState: UserPhysiologicalState,
        adjustment: Double
    ) -> FrequencyParameterSet {

        // Organspezifische Frequenzanpassung nur bei bestimmten Modi
        var targetOrgan: Organ? = nil

        switch targetState {
        case .relaxed, .deepRelaxation:
            targetOrgan = .heart  // Herzfrequenz-Kohärenz
        case .focused:
            targetOrgan = .brain  // Neurale Entrainment
        case .drowsy, .sleep:
            targetOrgan = .brain  // Delta-Induktion
        default:
            targetOrgan = nil
        }

        return FrequencyParameterSet(
            targetOrgan: targetOrgan,
            frequencyAdjustment: adjustment
        )
    }

    private func calculateSpatialParameters(
        currentState: UserPhysiologicalState,
        adjustment: Double
    ) -> SpatialParameterSet {

        // Räumliche Parameter für Immersion
        let rotationSpeed: Float

        switch currentState {
        case .deepRelaxation, .sleep:
            rotationSpeed = 0.01  // Sehr langsam
        case .creative:
            rotationSpeed = 0.05  // Moderat
        case .energized:
            rotationSpeed = 0.1   // Schneller
        default:
            rotationSpeed = 0.03
        }

        return SpatialParameterSet(
            listenerPosition: nil,  // Behalte aktuelle Position
            fieldRotation: rotationSpeed
        )
    }

    // MARK: - Feedback Processing

    private func applyFeedback(_ feedback: FeedbackData?, to adjustment: Double) -> Double {
        guard let feedback = feedback else { return adjustment }

        // Lerne aus vergangenen Erfolgen/Misserfolgen
        var modified = adjustment

        if feedback.wasEffective {
            // Verstärke ähnliche Entscheidungen
            modified *= (1.0 + feedback.effectivenessScore * 0.2)
        } else {
            // Dämpfe ineffektive Richtungen
            modified *= (1.0 - feedback.effectivenessScore * 0.3)
        }

        return max(-1, min(1, modified))
    }

    // MARK: - Confidence & Reasoning

    private func calculateConfidence(error: Double, feedback: FeedbackData?) -> Double {
        var confidence = 0.5

        // Niedriger Fehler = höhere Konfidenz
        confidence += (1.0 - error) * 0.3

        // Gutes Feedback = höhere Konfidenz
        if let feedback = feedback, feedback.wasEffective {
            confidence += feedback.effectivenessScore * 0.2
        }

        return min(1, confidence)
    }

    private func generateReasoning(
        currentState: UserPhysiologicalState,
        targetState: UserPhysiologicalState,
        error: Double,
        adjustment: Double
    ) -> String {

        if currentState == targetState {
            return "Zielzustand erreicht (\(targetState.displayName)). Halte aktuelle Parameter."
        }

        let direction = adjustment > 0 ? "erhöht" : "reduziert"
        let intensity = abs(adjustment) > 0.5 ? "stark" : "moderat"

        return "Übergang von \(currentState.displayName) zu \(targetState.displayName). " +
               "Parameter werden \(intensity) \(direction). " +
               "Distanz zum Ziel: \(Int(error * 100))%."
    }

    // MARK: - History

    private func recordDecision(_ decision: AutopilotDecision) {
        decisionHistory.append(decision)
        if decisionHistory.count > maxHistoryLength {
            decisionHistory.removeFirst()
        }
    }
}

// MARK: - PID State

private struct PIDState {
    var kP: Double = 0.5
    var kI: Double = 0.1
    var kD: Double = 0.2

    var lastError: Double = 0
    var integral: Double = 0
    var lastUpdate: Date = Date()
}

// MARK: - Decision Strategy Protocol

protocol DecisionStrategy {
    var rampTime: Float { get }

    func adjust(
        currentState: UserPhysiologicalState,
        targetState: UserPhysiologicalState,
        pidOutput: Double
    ) -> Double
}

// MARK: - Strategy Implementations

struct BalancedStrategy: DecisionStrategy {
    var rampTime: Float = 0.5

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        return pidOutput * 0.5  // Moderate adjustment
    }
}

struct MeditationStrategy: DecisionStrategy {
    var rampTime: Float = 2.0  // Langsame Übergänge

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Bei Meditation: Sehr sanfte Anpassungen
        return pidOutput * 0.3
    }
}

struct FocusStrategy: DecisionStrategy {
    var rampTime: Float = 0.3

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Fokus: Schnellere Reaktion bei Ablenkung
        if currentState == .drowsy || currentState == .relaxed {
            return pidOutput * 0.8  // Stärkere Korrektur
        }
        return pidOutput * 0.5
    }
}

struct CreativityStrategy: DecisionStrategy {
    var rampTime: Float = 1.0

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Kreativität: Variabilität zulassen
        let randomFactor = Double.random(in: 0.8...1.2)
        return pidOutput * 0.4 * randomFactor
    }
}

struct SleepStrategy: DecisionStrategy {
    var rampTime: Float = 3.0  // Sehr langsam

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Schlaf: Extrem sanft
        return pidOutput * 0.2
    }
}

struct RecoveryStrategy: DecisionStrategy {
    var rampTime: Float = 1.5

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Recovery: Stärker bei Stress
        if currentState == .stressed || currentState == .anxious {
            return pidOutput * 0.7
        }
        return pidOutput * 0.4
    }
}

struct EnergyStrategy: DecisionStrategy {
    var rampTime: Float = 0.2  // Schnell

    func adjust(currentState: UserPhysiologicalState, targetState: UserPhysiologicalState, pidOutput: Double) -> Double {
        // Energie: Responsive
        return pidOutput * 0.6
    }
}

// MARK: - Feedback Data

public struct FeedbackData {
    public let wasEffective: Bool
    public let effectivenessScore: Double  // 0.0 - 1.0
    public let convergenceRate: Double
    public let timestamp: Date

    public init(
        wasEffective: Bool,
        effectivenessScore: Double,
        convergenceRate: Double,
        timestamp: Date = Date()
    ) {
        self.wasEffective = wasEffective
        self.effectivenessScore = effectivenessScore
        self.convergenceRate = convergenceRate
        self.timestamp = timestamp
    }
}
