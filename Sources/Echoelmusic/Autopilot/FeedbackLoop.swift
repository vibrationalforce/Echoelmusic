import Foundation
import Combine

// MARK: - Feedback Loop
/// Adaptiver Feedback-Mechanismus für kontinuierliche Optimierung
///
/// **Funktionsweise:**
/// 1. Beobachte Ergebnis jeder Entscheidung
/// 2. Vergleiche mit erwartetem Ergebnis
/// 3. Passe interne Modelle an
///
/// **Wissenschaftliche Basis:**
/// - ✅ Closed-loop Biofeedback (Lehrer 2007)
/// - ⚠️ Reinforcement Learning für physiologische Adaptation (emerging)

@MainActor
public class FeedbackLoop: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentFeedback: FeedbackData?

    @Published public private(set) var overallEffectiveness: Double = 0.5

    @Published public private(set) var learningProgress: Double = 0.0

    // MARK: - Configuration

    public var learningRate: Double = 0.1

    /// Wie viele Samples für Effektivitätsberechnung
    public var evaluationWindow: Int = 30

    // MARK: - Internal State

    private var decisionOutcomes: [DecisionOutcome] = []
    private let maxOutcomes = 500

    /// Effektivitäts-Score pro Zustandsübergang
    private var transitionScores: [StateTransition: MovingAverage] = [:]

    /// Konvergenz-Raten über Zeit
    private var convergenceHistory: [Double] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Update

    public func update(decision: AutopilotDecision, resultingState: UserPhysiologicalState) {
        guard let previousOutcome = decisionOutcomes.last else {
            // Erste Entscheidung - nur speichern
            recordOutcome(decision: decision, resultingState: resultingState)
            return
        }

        // Berechne Effektivität der letzten Entscheidung
        let effectiveness = evaluateEffectiveness(
            previousDecision: previousOutcome.decision,
            previousState: previousOutcome.resultingState,
            currentState: resultingState
        )

        // Update Feedback
        currentFeedback = FeedbackData(
            wasEffective: effectiveness > 0.5,
            effectivenessScore: effectiveness,
            convergenceRate: calculateConvergenceRate(),
            timestamp: Date()
        )

        // Lerne aus diesem Outcome
        learn(
            transition: StateTransition(
                from: previousOutcome.resultingState,
                to: resultingState
            ),
            effectiveness: effectiveness
        )

        // Speichere
        recordOutcome(decision: decision, resultingState: resultingState)

        // Update Gesamteffektivität
        updateOverallEffectiveness()
    }

    // MARK: - Effectiveness Evaluation

    private func evaluateEffectiveness(
        previousDecision: AutopilotDecision,
        previousState: UserPhysiologicalState,
        currentState: UserPhysiologicalState
    ) -> Double {

        // War die Entscheidung, zu ändern?
        guard previousDecision.shouldApply else {
            // Entscheidung war zu halten - prüfe ob Zustand stabil blieb
            return previousState == currentState ? 0.6 : 0.4
        }

        // Berechne Verbesserung zum Zielzustand
        // (aus Audio-Parametern das implizite Ziel ableiten)

        var score = 0.5

        // Prüfe ob Bewegung in richtige Richtung
        if let audioParams = previousDecision.audioParameters {
            let targetBeat = audioParams.beatFrequency ?? 10.0

            // Mapping: Beat-Frequenz → erwarteter Zustand
            let expectedState = estimateTargetState(beatFrequency: targetBeat)

            if currentState == expectedState {
                score += 0.3  // Ziel erreicht
            } else if currentState.distance(to: expectedState) < previousState.distance(to: expectedState) {
                score += 0.2  // Näher am Ziel
            } else {
                score -= 0.1  // Entfernt vom Ziel
            }
        }

        // Bonus für Stabilität (kein Oszillieren)
        if isStable() {
            score += 0.1
        }

        return max(0, min(1, score))
    }

    private func estimateTargetState(beatFrequency: Float) -> UserPhysiologicalState {
        // Reverse-Mapping von Frequenz zu Zustand
        switch beatFrequency {
        case 0.5...4:
            return .drowsy
        case 4...8:
            return .deepRelaxation
        case 8...12:
            return .relaxed
        case 12...20:
            return .focused
        case 20...40:
            return .energized
        default:
            return .neutral
        }
    }

    private func isStable() -> Bool {
        // Prüfe letzte 5 Outcomes auf Oszillation
        guard decisionOutcomes.count >= 5 else { return true }

        let recentStates = decisionOutcomes.suffix(5).map { $0.resultingState }
        let uniqueStates = Set(recentStates)

        // Wenn weniger als 3 verschiedene Zustände = stabil
        return uniqueStates.count < 3
    }

    // MARK: - Learning

    private func learn(transition: StateTransition, effectiveness: Double) {
        // Update Moving Average für diese Transition
        if var avg = transitionScores[transition] {
            avg.add(effectiveness)
            transitionScores[transition] = avg
        } else {
            var avg = MovingAverage(windowSize: evaluationWindow)
            avg.add(effectiveness)
            transitionScores[transition] = avg
        }

        // Tracking für Learning-Progress
        learningProgress = calculateLearningProgress()
    }

    private func calculateLearningProgress() -> Double {
        // Learning Progress basierend auf:
        // 1. Anzahl gelernter Übergänge
        // 2. Durchschnittliche Konfidenz

        let possibleTransitions = Double(UserPhysiologicalState.allCases.count * UserPhysiologicalState.allCases.count)
        let learnedTransitions = Double(transitionScores.count)

        let coverageScore = learnedTransitions / possibleTransitions

        let avgConfidence = transitionScores.values.compactMap { $0.average }.reduce(0, +) / max(1, Double(transitionScores.count))

        return (coverageScore * 0.4 + avgConfidence * 0.6)
    }

    // MARK: - Convergence

    private func calculateConvergenceRate() -> Double {
        guard decisionOutcomes.count >= 2 else { return 0 }

        let recent = decisionOutcomes.suffix(evaluationWindow)
        var improvements = 0

        for i in 1..<recent.count {
            let array = Array(recent)
            let prev = array[i-1]
            let curr = array[i]

            // Prüfe ob sich der Zustand verbessert hat (näher am Ziel)
            // Vereinfachung: Kohärenz als Proxy für "Verbesserung"
            if prev.decision.confidence < curr.decision.confidence {
                improvements += 1
            }
        }

        let rate = Double(improvements) / Double(recent.count - 1)
        convergenceHistory.append(rate)

        if convergenceHistory.count > 100 {
            convergenceHistory.removeFirst()
        }

        return rate
    }

    // MARK: - Overall Effectiveness

    private func updateOverallEffectiveness() {
        let recentOutcomes = decisionOutcomes.suffix(evaluationWindow)

        guard !recentOutcomes.isEmpty else { return }

        let scores = recentOutcomes.compactMap { outcome -> Double? in
            // Berechne Score basierend auf Konfidenz
            return outcome.decision.confidence
        }

        guard !scores.isEmpty else { return }

        overallEffectiveness = scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Recording

    private func recordOutcome(decision: AutopilotDecision, resultingState: UserPhysiologicalState) {
        let outcome = DecisionOutcome(
            timestamp: Date(),
            decision: decision,
            resultingState: resultingState
        )

        decisionOutcomes.append(outcome)

        if decisionOutcomes.count > maxOutcomes {
            decisionOutcomes.removeFirst()
        }
    }

    // MARK: - Query Methods

    /// Hole gelernte Effektivität für einen bestimmten Übergang
    public func getEffectiveness(from: UserPhysiologicalState, to: UserPhysiologicalState) -> Double? {
        let transition = StateTransition(from: from, to: to)
        return transitionScores[transition]?.average
    }

    /// Exportiere Lern-Daten
    public func exportLearningData() -> LearningExport {
        return LearningExport(
            transitionScores: transitionScores.mapValues { $0.average ?? 0 },
            overallEffectiveness: overallEffectiveness,
            samplesCollected: decisionOutcomes.count,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types

struct DecisionOutcome {
    let timestamp: Date
    let decision: AutopilotDecision
    let resultingState: UserPhysiologicalState
}

struct StateTransition: Hashable {
    let from: UserPhysiologicalState
    let to: UserPhysiologicalState
}

struct MovingAverage {
    private var values: [Double] = []
    let windowSize: Int

    init(windowSize: Int) {
        self.windowSize = windowSize
    }

    var average: Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    mutating func add(_ value: Double) {
        values.append(value)
        if values.count > windowSize {
            values.removeFirst()
        }
    }
}

public struct LearningExport: Codable {
    public let transitionScores: [String: Double]
    public let overallEffectiveness: Double
    public let samplesCollected: Int
    public let timestamp: Date

    init(
        transitionScores: [StateTransition: Double],
        overallEffectiveness: Double,
        samplesCollected: Int,
        timestamp: Date
    ) {
        // Convert StateTransition keys to String for Codable
        var stringScores: [String: Double] = [:]
        for (transition, score) in transitionScores {
            let key = "\(transition.from.rawValue)_to_\(transition.to.rawValue)"
            stringScores[key] = score
        }
        self.transitionScores = stringScores
        self.overallEffectiveness = overallEffectiveness
        self.samplesCollected = samplesCollected
        self.timestamp = timestamp
    }
}
