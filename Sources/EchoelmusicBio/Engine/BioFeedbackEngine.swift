import Foundation
import Combine
import EchoelmusicCore

/// Central engine for bio-reactive audio synthesis
/// Coordinates between HealthKit data, parameter mapping, and audio engine
/// Subscribes to BioSignalUpdatedEvents and publishes mapped audio parameters
@MainActor
public class BioFeedbackEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current bio-reactive audio parameters
    @Published public var reverbWet: Float = 0.3
    @Published public var filterCutoff: Float = 1000.0
    @Published public var amplitude: Float = 0.5
    @Published public var baseFrequency: Float = 432.0
    @Published public var tempo: Float = 60.0

    /// Current bio signal data (for UI display)
    @Published public var currentHeartRate: Double = 60.0
    @Published public var currentHRV: Double = 0.0
    @Published public var currentCoherence: Double = 0.0

    /// Bio-feedback enabled state
    @Published public var isEnabled: Bool = false

    /// Audio level from external source (microphone, audio buffer)
    @Published public var audioLevel: Float = 0.0

    /// Voice pitch from external source (pitch detector)
    @Published public var voicePitch: Float = 0.0


    // MARK: - Private Properties

    /// Parameter mapper for bio-to-audio conversion
    private let parameterMapper = BioParameterMapper()

    /// EventBus subscription cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Throttle updates to avoid overwhelming the audio engine
    private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 0.1  // 10 Hz update rate


    // MARK: - Initialization

    public init() {
        setupEventBusSubscriptions()
        observeParameterMapper()
    }


    // MARK: - EventBus Subscriptions

    /// Subscribe to bio signal events from EventBus
    private func setupEventBusSubscriptions() {
        // Subscribe to bio signal updates from HealthKit
        EventBus.shared.subscribe(to: BioSignalUpdatedEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handleBioSignalUpdate(event)
            }
        }

        print("🧠 BioFeedbackEngine: Subscribed to EventBus")
    }


    // MARK: - Bio Signal Processing

    /// Handle incoming bio signal update from HealthKit
    private func handleBioSignalUpdate(_ event: BioSignalUpdatedEvent) async {
        guard isEnabled else { return }

        // Throttle updates to avoid overwhelming the system
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval else {
            return
        }
        lastUpdateTime = now

        // Update current bio data for UI
        currentHeartRate = event.heartRate
        currentHRV = event.hrv
        currentCoherence = event.coherence

        // Update parameter mapper with bio data
        parameterMapper.updateParameters(
            hrvCoherence: event.coherence,
            heartRate: event.heartRate,
            voicePitch: voicePitch,
            audioLevel: audioLevel
        )

        // Log updates periodically
        logBioFeedbackStatus()
    }


    // MARK: - Parameter Mapper Observation

    /// Observe parameter mapper changes and republish as our own @Published properties
    private func observeParameterMapper() {
        // Observe reverb
        parameterMapper.$reverbWet
            .sink { [weak self] value in
                self?.reverbWet = value
            }
            .store(in: &cancellables)

        // Observe filter
        parameterMapper.$filterCutoff
            .sink { [weak self] value in
                self?.filterCutoff = value
            }
            .store(in: &cancellables)

        // Observe amplitude
        parameterMapper.$amplitude
            .sink { [weak self] value in
                self?.amplitude = value
            }
            .store(in: &cancellables)

        // Observe frequency
        parameterMapper.$baseFrequency
            .sink { [weak self] value in
                self?.baseFrequency = value
            }
            .store(in: &cancellables)

        // Observe tempo
        parameterMapper.$tempo
            .sink { [weak self] value in
                self?.tempo = value
            }
            .store(in: &cancellables)
    }


    // MARK: - Public Control

    /// Enable bio-reactive audio processing
    public func enable() {
        isEnabled = true
        print("✅ BioFeedbackEngine: Enabled")
    }

    /// Disable bio-reactive audio processing
    public func disable() {
        isEnabled = false
        print("⏸️ BioFeedbackEngine: Disabled")
    }

    /// Toggle bio-reactive audio processing
    public func toggle() {
        isEnabled.toggle()
        print(isEnabled ? "✅ BioFeedbackEngine: Enabled" : "⏸️ BioFeedbackEngine: Disabled")
    }

    /// Apply a preset configuration
    public func applyPreset(_ preset: BioParameterMapper.BioPreset) {
        parameterMapper.applyPreset(preset)
    }


    // MARK: - External Input Updates

    /// Update audio level from microphone or audio buffer
    /// Call this from AudioEngine when processing buffers
    public func updateAudioLevel(_ level: Float) {
        audioLevel = max(0.0, min(1.0, level))
    }

    /// Update voice pitch from pitch detector
    /// Call this from pitch detection algorithm
    public func updateVoicePitch(_ pitch: Float) {
        voicePitch = pitch
    }


    // MARK: - Status & Debugging

    /// Get current bio-feedback status summary
    public var statusSummary: String {
        """
        🧠 BioFeedback Engine Status:
        - Enabled: \(isEnabled ? "✅" : "❌")
        - Heart Rate: \(Int(currentHeartRate)) BPM
        - HRV: \(String(format: "%.1f", currentHRV)) ms
        - Coherence: \(Int(currentCoherence))%

        🎛️ Mapped Audio Parameters:
        - Reverb: \(Int(reverbWet * 100))%
        - Filter: \(Int(filterCutoff)) Hz
        - Amplitude: \(Int(amplitude * 100))%
        - Frequency: \(Int(baseFrequency)) Hz
        - Tempo: \(String(format: "%.1f", tempo)) breaths/min
        """
    }

    /// Log bio-feedback status (throttled)
    private var lastLogTime: Date = Date()
    private let logThrottleInterval: TimeInterval = 5.0  // Log every 5 seconds

    private func logBioFeedbackStatus() {
        let now = Date()
        guard now.timeIntervalSince(lastLogTime) >= logThrottleInterval else {
            return
        }
        lastLogTime = now

        print("""
            🧠 BioFeedback: HR:\(Int(currentHeartRate)) HRV:\(String(format: "%.0f", currentHRV))ms \
            Coherence:\(Int(currentCoherence))% → \
            Rev:\(Int(reverbWet*100))% Filt:\(Int(filterCutoff))Hz \
            Freq:\(Int(baseFrequency))Hz
            """)
    }


    // MARK: - Validation

    /// Check if all parameters are valid
    public var isValid: Bool {
        parameterMapper.isValid
    }

    /// Get detailed parameter summary
    public var parameterSummary: String {
        parameterMapper.parameterSummary
    }
}


// MARK: - Coherence Helpers

extension BioFeedbackEngine {

    /// Get coherence state as enum
    public var coherenceState: CoherenceState {
        if currentCoherence >= 60 {
            return .high
        } else if currentCoherence >= 40 {
            return .medium
        } else {
            return .low
        }
    }

    /// Coherence state classification
    public enum CoherenceState: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        public var description: String {
            switch self {
            case .low:
                return "Stress/Anxiety"
            case .medium:
                return "Transitional"
            case .high:
                return "Flow State"
            }
        }

        public var color: String {
            switch self {
            case .low:
                return "red"
            case .medium:
                return "yellow"
            case .high:
                return "green"
            }
        }

        public var emoji: String {
            switch self {
            case .low:
                return "😰"
            case .medium:
                return "😐"
            case .high:
                return "✨"
            }
        }
    }
}
