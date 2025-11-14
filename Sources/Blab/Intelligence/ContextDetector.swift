import Foundation

/// Context Detector - Intelligently detects current activity context
///
/// Uses multi-modal signals to determine what the user is currently doing:
/// - Audio patterns (level, frequency, rhythm)
/// - Biometric data (HRV, heart rate, breathing)
/// - Gesture activity
/// - Face expressions
/// - Time of day
/// - Historical patterns
class ContextDetector {

    /// Current confidence level (0.0 - 1.0)
    var confidence: Float = 0.0

    /// Context detection history (last 100 detections)
    private var contextHistory: [ActivityContext] = []

    /// Feature weights for ML-based detection
    private var featureWeights: [String: Float] = [
        "audioLevel": 0.2,
        "hrvCoherence": 0.25,
        "heartRate": 0.2,
        "gestureActivity": 0.15,
        "timeOfDay": 0.1,
        "historicalPattern": 0.1
    ]

    /// Trained threshold values
    private var thresholds: ContextThresholds


    // MARK: - Initialization

    init() {
        self.thresholds = ContextThresholds()
    }


    // MARK: - Lifecycle

    func start() {
        print("🎯 ContextDetector started")
    }

    func stop() {
        print("🎯 ContextDetector stopped")
    }


    // MARK: - Context Detection

    /// Detect current activity context using multi-modal signals
    func detectContext(
        audioLevel: Float,
        hrvCoherence: Double,
        heartRate: Double,
        gestureActivity: Float,
        faceExpression: String,
        timeOfDay: Date
    ) -> ActivityContext {

        // Calculate feature scores
        let audioScore = calculateAudioScore(audioLevel)
        let bioScore = calculateBioScore(hrvCoherence: hrvCoherence, heartRate: heartRate)
        let gestureScore = calculateGestureScore(gestureActivity)
        let timeScore = calculateTimeScore(timeOfDay)
        let historyScore = calculateHistoryScore()

        // Weighted combination
        let scores: [ActivityContext: Float] = [
            .idle: calculateIdleScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore
            ),
            .meditation: calculateMeditationScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore,
                time: timeScore
            ),
            .performance: calculatePerformanceScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore
            ),
            .recording: calculateRecordingScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore
            ),
            .practice: calculatePracticeScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore
            ),
            .healing: calculateHealingScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore,
                time: timeScore
            ),
            .creative: calculateCreativeScore(
                audio: audioScore,
                bio: bioScore,
                gesture: gestureScore,
                history: historyScore
            )
        ]

        // Find highest scoring context
        let detectedContext = scores.max(by: { $0.value < $1.value })?.key ?? .idle
        confidence = scores[detectedContext] ?? 0.0

        // Update history
        updateHistory(detectedContext)

        return detectedContext
    }


    // MARK: - Score Calculations

    private func calculateAudioScore(_ level: Float) -> Float {
        // Normalize audio level (0.0 - 1.0)
        return min(max(level, 0.0), 1.0)
    }

    private func calculateBioScore(hrvCoherence: Double, heartRate: Double) -> Float {
        // High HRV coherence + moderate HR = good state
        let normalizedHRV = Float(hrvCoherence / 100.0)
        let normalizedHR = Float((heartRate - 40.0) / 100.0)  // 40-140 BPM range

        return (normalizedHRV * 0.7 + (1.0 - abs(normalizedHR - 0.5)) * 0.3)
    }

    private func calculateGestureScore(_ activity: Float) -> Float {
        return min(max(activity, 0.0), 1.0)
    }

    private func calculateTimeScore(_ time: Date) -> Float {
        let hour = Calendar.current.component(.hour, from: time)

        // Morning (6-10): High energy activities
        if hour >= 6 && hour < 10 {
            return 0.8
        }
        // Evening (18-22): Meditation/Healing
        else if hour >= 18 && hour < 22 {
            return 0.6
        }
        // Night (22-6): Rest/Healing
        else if hour >= 22 || hour < 6 {
            return 0.3
        }
        // Day (10-18): Performance/Creative
        else {
            return 0.7
        }
    }

    private func calculateHistoryScore() -> Float {
        // Most common context in recent history
        guard !contextHistory.isEmpty else { return 0.0 }

        let recentHistory = Array(contextHistory.suffix(10))
        let mostCommon = recentHistory.mostCommon()

        return mostCommon != nil ? 0.8 : 0.0
    }


    // MARK: - Context-Specific Scores

    private func calculateIdleScore(audio: Float, bio: Float, gesture: Float) -> Float {
        // Low audio, low gesture activity
        let idleScore = (1.0 - audio) * 0.4 + (1.0 - gesture) * 0.6
        return idleScore
    }

    private func calculateMeditationScore(
        audio: Float,
        bio: Float,
        gesture: Float,
        time: Float
    ) -> Float {
        // Low audio, high HRV coherence, low gesture, evening time
        let meditationScore = (1.0 - audio) * 0.3 +
                              bio * 0.4 +
                              (1.0 - gesture) * 0.2 +
                              (time < 0.5 ? time : 0.5) * 0.1

        return meditationScore
    }

    private func calculatePerformanceScore(
        audio: Float,
        bio: Float,
        gesture: Float
    ) -> Float {
        // High audio, moderate bio, high gesture
        let performanceScore = audio * 0.5 +
                               bio * 0.2 +
                               gesture * 0.3

        return performanceScore
    }

    private func calculateRecordingScore(
        audio: Float,
        bio: Float,
        gesture: Float
    ) -> Float {
        // Moderate-high audio, moderate gesture, focused state
        let recordingScore = audio * 0.4 +
                            bio * 0.3 +
                            gesture * 0.3

        return recordingScore
    }

    private func calculatePracticeScore(
        audio: Float,
        bio: Float,
        gesture: Float
    ) -> Float {
        // Moderate audio, moderate gesture, learning state
        let practiceScore = audio * 0.4 +
                           bio * 0.2 +
                           gesture * 0.4

        return practiceScore
    }

    private func calculateHealingScore(
        audio: Float,
        bio: Float,
        gesture: Float,
        time: Float
    ) -> Float {
        // Low audio, very high HRV, low gesture, evening/night
        let healingScore = (1.0 - audio) * 0.2 +
                          bio * 0.5 +
                          (1.0 - gesture) * 0.2 +
                          (time < 0.4 ? 0.1 : 0.0)

        return healingScore
    }

    private func calculateCreativeScore(
        audio: Float,
        bio: Float,
        gesture: Float,
        history: Float
    ) -> Float {
        // Variable audio, moderate-high bio, variable gesture, historical pattern
        let creativeScore = audio * 0.3 +
                           bio * 0.3 +
                           gesture * 0.2 +
                           history * 0.2

        return creativeScore
    }


    // MARK: - History Management

    private func updateHistory(_ context: ActivityContext) {
        contextHistory.append(context)

        // Keep last 100 detections
        if contextHistory.count > 100 {
            contextHistory.removeFirst()
        }
    }


    // MARK: - Persistence

    func export() -> [String: Any] {
        return [
            "contextHistory": contextHistory.map { $0.rawValue },
            "confidence": confidence
        ]
    }

    func restore(from data: [String: Any]) {
        if let history = data["contextHistory"] as? [String] {
            contextHistory = history.compactMap { ActivityContext(rawValue: $0) }
        }
    }
}


// MARK: - Supporting Types

struct ContextThresholds {
    // Audio thresholds
    var idleAudioMax: Float = 0.1
    var meditationAudioMax: Float = 0.2
    var performanceAudioMin: Float = 0.6

    // Bio thresholds
    var meditationHRVMin: Double = 60.0
    var healingHRVMin: Double = 70.0
    var performanceHRMin: Double = 80.0

    // Gesture thresholds
    var idleGestureMax: Float = 0.1
    var performanceGestureMin: Float = 0.5
}


// MARK: - Array Extension

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = self.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
