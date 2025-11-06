import Foundation
import Combine

/// Manages biofeedback sessions on Apple TV
/// Coordinates group sessions and individual sessions
@MainActor
class TVSessionManager: ObservableObject {

    // MARK: - Published Properties

    /// Current session state
    @Published private(set) var sessionState: SessionState = .idle

    /// Current session type
    @Published var sessionType: SessionType = .solo

    /// Session duration (in seconds)
    @Published private(set) var sessionDuration: TimeInterval = 0

    /// Target session duration
    @Published var targetDuration: TimeInterval = 600 // 10 minutes default

    /// Session participants (for group sessions)
    @Published private(set) var participants: [SessionParticipant] = []

    // MARK: - Private Properties

    private var sessionTimer: Timer?
    private var sessionStartTime: Date?

    // MARK: - Session Control

    /// Start a new session
    func startSession(type: SessionType = .solo) {
        sessionType = type
        sessionState = .active
        sessionStartTime = Date()
        sessionDuration = 0

        startSessionTimer()

        print("[TVSession] ✅ Session started: \(type)")
    }

    /// Pause current session
    func pauseSession() {
        guard sessionState == .active else { return }

        sessionState = .paused
        stopSessionTimer()

        print("[TVSession] ⏸️ Session paused")
    }

    /// Resume paused session
    func resumeSession() {
        guard sessionState == .paused else { return }

        sessionState = .active
        startSessionTimer()

        print("[TVSession] ▶️ Session resumed")
    }

    /// End current session
    func endSession() {
        sessionState = .idle
        stopSessionTimer()

        let duration = sessionDuration
        sessionDuration = 0
        sessionStartTime = nil

        print("[TVSession] ⏹️ Session ended (Duration: \(Int(duration))s)")
    }

    // MARK: - Participant Management

    /// Add participant to group session
    func addParticipant(_ participant: SessionParticipant) {
        participants.append(participant)
        print("[TVSession] 👤 Participant added: \(participant.name)")
    }

    /// Remove participant from group session
    func removeParticipant(_ participantId: UUID) {
        participants.removeAll { $0.id == participantId }
        print("[TVSession] 👤 Participant removed")
    }

    /// Update participant's biofeedback data
    func updateParticipant(_ participantId: UUID, hrv: Double, heartRate: Double, coherence: Double) {
        if let index = participants.firstIndex(where: { $0.id == participantId }) {
            participants[index].currentHRV = hrv
            participants[index].heartRate = heartRate
            participants[index].coherence = coherence
        }
    }

    // MARK: - Timer Management

    private func startSessionTimer() {
        stopSessionTimer()

        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                if let startTime = self.sessionStartTime {
                    self.sessionDuration = Date().timeIntervalSince(startTime)

                    // Auto-end when target duration reached
                    if self.sessionDuration >= self.targetDuration {
                        self.endSession()
                    }
                }
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Computed Properties

    /// Average coherence across all participants
    var averageCoherence: Double {
        guard !participants.isEmpty else { return 0.0 }

        let total = participants.reduce(0.0) { $0 + $1.coherence }
        return total / Double(participants.count)
    }

    /// Progress towards target duration (0.0 - 1.0)
    var sessionProgress: Double {
        guard targetDuration > 0 else { return 0.0 }
        return min(sessionDuration / targetDuration, 1.0)
    }

    // MARK: - Cleanup

    deinit {
        stopSessionTimer()
    }
}

// MARK: - Supporting Types

enum SessionState {
    case idle
    case active
    case paused
}

enum SessionType {
    case solo         // Individual session
    case group        // Multiple participants
    case ambient      // Background/screensaver mode
}

struct SessionParticipant: Identifiable {
    let id: UUID
    let name: String
    let deviceId: String

    var currentHRV: Double = 0.0
    var heartRate: Double = 70.0
    var coherence: Double = 50.0

    init(id: UUID = UUID(), name: String, deviceId: String) {
        self.id = id
        self.name = name
        self.deviceId = deviceId
    }
}
