import Foundation

/// Pattern Learner - Learns from user behavior patterns over time
///
/// This component observes user actions, settings preferences, and context transitions
/// to learn patterns and make intelligent predictions.
class PatternLearner {

    /// Total training examples collected
    var trainingExamples: Int = 0

    /// Learned patterns per context
    private var contextPatterns: [ActivityContext: ContextPattern] = [:]

    /// Action sequences (for prediction)
    private var actionSequences: [[UserAction]] = []

    /// Context transition patterns
    private var transitionPatterns: [ContextTransition: Int] = [:]


    // MARK: - Observation

    /// Observe current state for learning
    func observe(
        context: ActivityContext,
        latencyMode: AudioConfiguration.LatencyMode,
        wetDryMix: Float,
        inputGain: Float,
        hrvCoherence: Double,
        timestamp: Date
    ) {
        // Get or create pattern for this context
        var pattern = contextPatterns[context] ?? ContextPattern(context: context)

        // Update pattern statistics
        pattern.addObservation(
            latencyMode: latencyMode,
            wetDryMix: wetDryMix,
            inputGain: inputGain,
            hrvCoherence: hrvCoherence,
            timestamp: timestamp
        )

        contextPatterns[context] = pattern
        trainingExamples += 1
    }

    /// Observe user action for pattern learning
    func observe(action: UserAction, context: ActivityContext) {
        // Add to action sequence
        if actionSequences.isEmpty {
            actionSequences.append([action])
        } else {
            actionSequences[actionSequences.count - 1].append(action)
        }

        trainingExamples += 1
    }

    /// Record context transition
    func recordContextChange(from: ActivityContext, to: ActivityContext, at time: Date) {
        let transition = ContextTransition(from: from, to: to)
        transitionPatterns[transition, default: 0] += 1
    }


    // MARK: - Prediction

    /// Predict next likely action based on patterns
    func predictNextAction(
        currentContext: ActivityContext,
        currentTime: Date,
        recentActions: [UserAction]
    ) -> PredictedAction? {

        guard !actionSequences.isEmpty else { return nil }

        // Find similar sequences in history
        var actionProbabilities: [UserAction: Int] = [:]

        for sequence in actionSequences {
            // Look for matching patterns in recent actions
            if sequence.count >= 2 && recentActions.count >= 1 {
                let lastAction = recentActions.last
                if let lastIdx = sequence.lastIndex(where: { $0 == lastAction }),
                   lastIdx < sequence.count - 1 {
                    let nextAction = sequence[lastIdx + 1]
                    actionProbabilities[nextAction, default: 0] += 1
                }
            }
        }

        // Find most probable next action
        guard let (action, count) = actionProbabilities.max(by: { $0.value < $1.value }),
              count > 0 else { return nil }

        let totalSequences = actionSequences.count
        let confidence = Float(count) / Float(totalSequences)

        return PredictedAction(
            action: action,
            confidence: confidence,
            timestamp: Date()
        )
    }

    /// Get learned optimal settings for a context
    func getOptimalSettings(for context: ActivityContext) -> ContextPattern? {
        return contextPatterns[context]
    }


    // MARK: - Persistence

    func export() -> [String: Any] {
        var patterns: [[String: Any]] = []

        for (context, pattern) in contextPatterns {
            patterns.append([
                "context": context.rawValue,
                "pattern": pattern.toDictionary()
            ])
        }

        return [
            "trainingExamples": trainingExamples,
            "patterns": patterns,
            "transitions": transitionPatterns.map { [
                "from": $0.key.from.rawValue,
                "to": $0.key.to.rawValue,
                "count": $0.value
            ]}
        ]
    }

    func restore(from data: [String: Any]) {
        trainingExamples = data["trainingExamples"] as? Int ?? 0

        if let patterns = data["patterns"] as? [[String: Any]] {
            for patternData in patterns {
                if let contextStr = patternData["context"] as? String,
                   let context = ActivityContext(rawValue: contextStr),
                   let patternDict = patternData["pattern"] as? [String: Any] {
                    contextPatterns[context] = ContextPattern(from: patternDict, context: context)
                }
            }
        }

        if let transitions = data["transitions"] as? [[String: Any]] {
            for transData in transitions {
                if let fromStr = transData["from"] as? String,
                   let toStr = transData["to"] as? String,
                   let from = ActivityContext(rawValue: fromStr),
                   let to = ActivityContext(rawValue: toStr),
                   let count = transData["count"] as? Int {
                    let transition = ContextTransition(from: from, to: to)
                    transitionPatterns[transition] = count
                }
            }
        }
    }
}


// MARK: - Supporting Types

struct ContextPattern {
    let context: ActivityContext

    // Observed settings
    var latencyModes: [AudioConfiguration.LatencyMode] = []
    var wetDryMixes: [Float] = []
    var inputGains: [Float] = []
    var hrvCoherences: [Double] = []
    var timestamps: [Date] = []

    // Computed optimal values
    var optimalLatencyMode: AudioConfiguration.LatencyMode {
        guard !latencyModes.isEmpty else { return .low }
        // Most common latency mode
        let counts = latencyModes.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? .low
    }

    var optimalWetDryMix: Float {
        guard !wetDryMixes.isEmpty else { return 0.3 }
        // Average wet/dry mix
        return wetDryMixes.reduce(0, +) / Float(wetDryMixes.count)
    }

    var optimalInputGain: Float {
        guard !inputGains.isEmpty else { return 0.0 }
        // Average input gain
        return inputGains.reduce(0, +) / Float(inputGains.count)
    }

    mutating func addObservation(
        latencyMode: AudioConfiguration.LatencyMode,
        wetDryMix: Float,
        inputGain: Float,
        hrvCoherence: Double,
        timestamp: Date
    ) {
        latencyModes.append(latencyMode)
        wetDryMixes.append(wetDryMix)
        inputGains.append(inputGain)
        hrvCoherences.append(hrvCoherence)
        timestamps.append(timestamp)

        // Keep last 100 observations per context
        if latencyModes.count > 100 {
            latencyModes.removeFirst()
            wetDryMixes.removeFirst()
            inputGains.removeFirst()
            hrvCoherences.removeFirst()
            timestamps.removeFirst()
        }
    }

    func toDictionary() -> [String: Any] {
        return [
            "latencyModes": latencyModes.map { $0.bufferSize },
            "wetDryMixes": wetDryMixes,
            "inputGains": inputGains,
            "hrvCoherences": hrvCoherences,
            "timestamps": timestamps.map { $0.timeIntervalSince1970 }
        ]
    }

    init(context: ActivityContext) {
        self.context = context
    }

    init(from dict: [String: Any], context: ActivityContext) {
        self.context = context

        if let modes = dict["latencyModes"] as? [AVAudioFrameCount] {
            latencyModes = modes.map { size in
                switch size {
                case 128: return .ultraLow
                case 256: return .low
                default: return .normal
                }
            }
        }
        wetDryMixes = dict["wetDryMixes"] as? [Float] ?? []
        inputGains = dict["inputGains"] as? [Float] ?? []
        hrvCoherences = dict["hrvCoherences"] as? [Double] ?? []

        if let times = dict["timestamps"] as? [TimeInterval] {
            timestamps = times.map { Date(timeIntervalSince1970: $0) }
        }
    }
}

struct ContextTransition: Hashable {
    let from: ActivityContext
    let to: ActivityContext
}
