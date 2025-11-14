import Foundation
import Combine

/// Intelligence Connector - Connects IntelligenceEngine to real data sources
///
/// This component acts as a bridge between the IntelligenceEngine and all
/// real data sources (AudioIOManager, HealthKitManager, GestureRecognizer, etc.)
/// ensuring the AI has access to real-time data.
@MainActor
class IntelligenceConnector: ObservableObject {

    // MARK: - Dependencies

    private weak var intelligenceEngine: IntelligenceEngine?
    private weak var audioIOManager: AudioIOManager?
    private weak var healthKitManager: HealthKitManager?
    private weak var gestureRecognizer: GestureRecognizer?
    private weak var faceTrackingManager: ARFaceTrackingManager?


    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

    init() {
        print("🔌 IntelligenceConnector initialized")
    }


    // MARK: - Connection Methods

    /// Connect Intelligence Engine to all data sources
    func connect(
        intelligence: IntelligenceEngine,
        audioIO: AudioIOManager?,
        healthKit: HealthKitManager?,
        gestures: GestureRecognizer?,
        faceTracking: ARFaceTrackingManager?
    ) {
        self.intelligenceEngine = intelligence
        self.audioIOManager = audioIO
        self.healthKitManager = healthKit
        self.gestureRecognizer = gestures
        self.faceTrackingManager = faceTracking

        // Setup data bindings
        setupAudioIOBinding()
        setupHealthKitBinding()
        setupGestureBinding()
        setupFaceTrackingBinding()

        print("🔌 IntelligenceConnector connected to all data sources")
    }


    // MARK: - Audio I/O Binding

    private func setupAudioIOBinding() {
        guard let audioIO = audioIOManager else { return }

        // Observe audio level changes
        audioIO.$audioLevel
            .sink { [weak self] level in
                self?.updateAudioLevel(level)
            }
            .store(in: &cancellables)

        // Observe latency mode changes (user actions)
        audioIO.$latencyMode
            .dropFirst() // Skip initial value
            .sink { [weak self] mode in
                self?.intelligenceEngine?.recordUserAction(.changeLatency)
            }
            .store(in: &cancellables)

        // Observe wet/dry mix changes
        audioIO.$wetDryMix
            .dropFirst()
            .sink { [weak self] _ in
                self?.intelligenceEngine?.recordUserAction(.adjustMix)
            }
            .store(in: &cancellables)

        // Observe input gain changes
        audioIO.$inputGainDB
            .dropFirst()
            .sink { [weak self] _ in
                self?.intelligenceEngine?.recordUserAction(.adjustGain)
            }
            .store(in: &cancellables)

        // Observe direct monitoring changes
        audioIO.$directMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                let action: UserAction = enabled ? .enableDirectMonitoring : .disableDirectMonitoring
                self?.intelligenceEngine?.recordUserAction(action)
            }
            .store(in: &cancellables)

        print("   ✅ Audio I/O binding established")
    }


    // MARK: - HealthKit Binding

    private func setupHealthKitBinding() {
        guard let healthKit = healthKitManager else { return }

        // Observe HRV changes
        healthKit.$hrvCoherence
            .sink { [weak self] hrv in
                self?.updateHRV(hrv)
            }
            .store(in: &cancellables)

        // Observe heart rate changes
        healthKit.$heartRate
            .sink { [weak self] hr in
                self?.updateHeartRate(hr)
            }
            .store(in: &cancellables)

        print("   ✅ HealthKit binding established")
    }


    // MARK: - Gesture Binding

    private func setupGestureBinding() {
        guard let gestures = gestureRecognizer else { return }

        // Observe left hand gesture changes
        gestures.$leftHandGesture
            .sink { [weak self] gesture in
                self?.updateGestureActivity(gesture)
            }
            .store(in: &cancellables)

        // Observe right hand gesture changes
        gestures.$rightHandGesture
            .sink { [weak self] gesture in
                self?.updateGestureActivity(gesture)
            }
            .store(in: &cancellables)

        print("   ✅ Gesture binding established")
    }


    // MARK: - Face Tracking Binding

    private func setupFaceTrackingBinding() {
        guard let faceTracking = faceTrackingManager else { return }

        // Observe face expression changes
        faceTracking.$faceExpression
            .sink { [weak self] expression in
                self?.updateFaceExpression(expression)
            }
            .store(in: &cancellables)

        print("   ✅ Face tracking binding established")
    }


    // MARK: - Data Update Methods

    private func updateAudioLevel(_ level: Float) {
        // Audio level is now available to IntelligenceEngine
        // through the connector's cached values
    }

    private func updateHRV(_ hrv: Double) {
        // HRV is now available
    }

    private func updateHeartRate(_ hr: Double) {
        // Heart rate is now available
    }

    private func updateGestureActivity(_ gesture: GestureType) {
        // Gesture activity is now available
    }

    private func updateFaceExpression(_ expression: FaceExpression) {
        // Face expression is now available
    }


    // MARK: - Public Accessors (for IntelligenceEngine)

    func getCurrentAudioLevel() -> Float {
        return audioIOManager?.audioLevel ?? 0.0
    }

    func getCurrentHRVCoherence() -> Double {
        return healthKitManager?.hrvCoherence ?? 50.0
    }

    func getCurrentHeartRate() -> Double {
        return healthKitManager?.heartRate ?? 70.0
    }

    func getCurrentGestureActivity() -> Float {
        // Calculate gesture activity score
        guard let gestures = gestureRecognizer else { return 0.0 }

        // Active gesture = 1.0, idle = 0.0
        let leftActive = gestures.leftHandGesture != .idle ? 0.5 : 0.0
        let rightActive = gestures.rightHandGesture != .idle ? 0.5 : 0.0

        return Float(leftActive + rightActive)
    }

    func getCurrentFaceExpression() -> String {
        return faceTrackingManager?.faceExpression.rawValue ?? "neutral"
    }

    func getCurrentLatencyMode() -> AudioConfiguration.LatencyMode {
        return audioIOManager?.latencyMode ?? .low
    }

    func getCurrentWetDryMix() -> Float {
        return audioIOManager?.wetDryMix ?? 0.3
    }

    func getCurrentInputGain() -> Float {
        return audioIOManager?.inputGainDB ?? 0.0
    }

    func getCurrentInputLevel() -> Float {
        return audioIOManager?.inputLevelDB ?? -96.0
    }

    func getCurrentOutputLevel() -> Float {
        return audioIOManager?.outputLevelDB ?? -96.0
    }

    func getCurrentLatency() -> TimeInterval {
        return audioIOManager?.measuredLatencyMS ?? 5.0 / 1000.0
    }

    func getCurrentPitch() -> Float {
        return audioIOManager?.currentPitch ?? 0.0
    }


    // MARK: - Cleanup

    deinit {
        cancellables.removeAll()
        print("🔌 IntelligenceConnector disconnected")
    }
}
