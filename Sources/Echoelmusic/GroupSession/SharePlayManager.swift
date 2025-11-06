import Foundation
import GroupActivities
import Combine

/// SharePlay manager for remote group biofeedback sessions
///
/// **Purpose:** Enable synchronized biofeedback sessions over FaceTime
///
/// **Features:**
/// - Start group sessions via FaceTime
/// - Sync breathing exercises across participants
/// - Share coherence data
/// - Synchronized visualization state
/// - Group coherence calculation
///
/// **Requirements:**
/// - iOS 15+
/// - FaceTime call active
/// - Participant permission
///
/// **Use Cases:**
/// - Remote meditation with friends/family
/// - Long-distance wellness sessions
/// - Virtual group therapy
/// - Couples breathing exercises
///
@available(iOS 15.0, *)
@MainActor
public class SharePlayManager: ObservableObject {

    // MARK: - Published Properties

    /// Current group session
    @Published public private(set) var groupSession: GroupSession<BiofeedbackActivity>?

    /// Participants in current session
    @Published public private(set) var participants: [Participant] = []

    /// Whether SharePlay is available (FaceTime active)
    @Published public private(set) var isAvailable: Bool = false

    /// Session state
    @Published public private(set) var sessionState: SessionState = .notStarted

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var messenger: GroupSessionMessenger?
    private var tasks = Set<Task<Void, Never>>()

    // MARK: - Initialization

    public init() {
        setupGroupSessionObserver()
        print("[SharePlay] 🎭 SharePlay manager initialized")
    }

    // MARK: - Setup

    private func setupGroupSessionObserver() {
        // Observe new group sessions
        Task {
            for await session in BiofeedbackActivity.sessions() {
                handleNewSession(session)
            }
        }
    }

    // MARK: - Session Management

    /// Start a new SharePlay session
    public func startSession() async throws {
        let activity = BiofeedbackActivity()

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
                print("[SharePlay] ✅ Session started")
            } catch {
                print("[SharePlay] ❌ Failed to activate: \(error)")
                throw error
            }

        case .activationDisabled:
            print("[SharePlay] ⚠️ SharePlay disabled by user")

        case .cancelled:
            print("[SharePlay] ⚠️ Activation cancelled")

        @unknown default:
            print("[SharePlay] ⚠️ Unknown activation result")
        }
    }

    /// Leave current session
    public func leaveSession() {
        groupSession?.leave()
        groupSession = nil
        messenger = nil
        participants.removeAll()
        sessionState = .notStarted

        print("[SharePlay] 👋 Left session")
    }

    // MARK: - Handle New Session

    private func handleNewSession(_ session: GroupSession<BiofeedbackActivity>) {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)

        // Update session state
        session.$state
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleSessionStateChange(state)
                }
            }
            .store(in: &cancellables)

        // Update participants
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                Task { @MainActor [weak self] in
                    self?.updateParticipants(activeParticipants)
                }
            }
            .store(in: &cancellables)

        // Start receiving messages
        startReceivingMessages()

        // Join session
        session.join()

        print("[SharePlay] 🎭 Joined group session")
    }

    private func handleSessionStateChange(_ state: GroupSession<BiofeedbackActivity>.State) {
        switch state {
        case .waiting:
            sessionState = .waiting
            print("[SharePlay] ⏳ Waiting for participants")

        case .joined:
            sessionState = .active
            print("[SharePlay] ✅ Session joined")

        case .invalidated(let reason):
            sessionState = .ended
            print("[SharePlay] ⏹️ Session invalidated: \(reason)")

        @unknown default:
            break
        }
    }

    private func updateParticipants(_ activeParticipants: Set<Participant>) {
        participants = Array(activeParticipants)
        print("[SharePlay] 👥 Participants updated: \(participants.count)")
    }

    // MARK: - Messaging

    /// Send breathing state to all participants
    public func sendBreathingState(phase: BreathingPhase, duration: TimeInterval) async {
        guard let messenger = messenger else { return }

        let message = BreathingStateMessage(phase: phase, duration: duration)

        do {
            try await messenger.send(message)
            print("[SharePlay] 📤 Sent breathing state: \(phase)")
        } catch {
            print("[SharePlay] ❌ Failed to send breathing state: \(error)")
        }
    }

    /// Send coherence update to all participants
    public func sendCoherenceUpdate(hrv: Double, heartRate: Double, coherence: Double) async {
        guard let messenger = messenger else { return }

        let message = CoherenceUpdateMessage(hrv: hrv, heartRate: heartRate, coherence: coherence)

        do {
            try await messenger.send(message)
            print("[SharePlay] 📤 Sent coherence update")
        } catch {
            print("[SharePlay] ❌ Failed to send coherence: \(error)")
        }
    }

    /// Send visualization sync
    public func sendVisualizationSync(style: String, intensity: Double) async {
        guard let messenger = messenger else { return }

        let message = VisualizationSyncMessage(style: style, intensity: intensity)

        do {
            try await messenger.send(message)
            print("[SharePlay] 📤 Sent visualization sync")
        } catch {
            print("[SharePlay] ❌ Failed to send visualization: \(error)")
        }
    }

    private func startReceivingMessages() {
        guard let messenger = messenger else { return }

        // Receive breathing state messages
        let breathingTask = Task {
            for await (message, _) in messenger.messages(of: BreathingStateMessage.self) {
                await handleBreathingState(message)
            }
        }
        tasks.insert(breathingTask)

        // Receive coherence updates
        let coherenceTask = Task {
            for await (message, _) in messenger.messages(of: CoherenceUpdateMessage.self) {
                await handleCoherenceUpdate(message)
            }
        }
        tasks.insert(coherenceTask)

        // Receive visualization sync
        let visualizationTask = Task {
            for await (message, _) in messenger.messages(of: VisualizationSyncMessage.self) {
                await handleVisualizationSync(message)
            }
        }
        tasks.insert(visualizationTask)
    }

    // MARK: - Message Handlers

    private func handleBreathingState(_ message: BreathingStateMessage) async {
        print("[SharePlay] 📥 Received breathing state: \(message.phase)")

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .sharePlayBreathingStateReceived,
            object: nil,
            userInfo: ["phase": message.phase, "duration": message.duration]
        )
    }

    private func handleCoherenceUpdate(_ message: CoherenceUpdateMessage) async {
        print("[SharePlay] 📥 Received coherence update")

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .sharePlayCoherenceReceived,
            object: nil,
            userInfo: [
                "hrv": message.hrv,
                "heartRate": message.heartRate,
                "coherence": message.coherence
            ]
        )
    }

    private func handleVisualizationSync(_ message: VisualizationSyncMessage) async {
        print("[SharePlay] 📥 Received visualization sync: \(message.style)")

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .sharePlayVisualizationReceived,
            object: nil,
            userInfo: ["style": message.style, "intensity": message.intensity]
        )
    }

    // MARK: - Cleanup

    deinit {
        tasks.forEach { $0.cancel() }
    }
}

// MARK: - Activity Definition

@available(iOS 15.0, *)
struct BiofeedbackActivity: GroupActivity {
    static let activityIdentifier = "com.echoelmusic.biofeedback"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Echoelmusic Session"
        metadata.subtitle = "Group biofeedback & breathing"
        metadata.type = .generic
        return metadata
    }
}

// MARK: - Messages

@available(iOS 15.0, *)
struct BreathingStateMessage: Codable {
    let phase: BreathingPhase
    let duration: TimeInterval
}

@available(iOS 15.0, *)
struct CoherenceUpdateMessage: Codable {
    let hrv: Double
    let heartRate: Double
    let coherence: Double
}

@available(iOS 15.0, *)
struct VisualizationSyncMessage: Codable {
    let style: String
    let intensity: Double
}

// MARK: - Supporting Types

public enum BreathingPhase: String, Codable {
    case inhale
    case hold
    case exhale
}

public enum SessionState {
    case notStarted
    case waiting
    case active
    case ended
}

// MARK: - Notifications

public extension Notification.Name {
    static let sharePlayBreathingStateReceived = Notification.Name("sharePlayBreathingStateReceived")
    static let sharePlayCoherenceReceived = Notification.Name("sharePlayCoherenceReceived")
    static let sharePlayVisualizationReceived = Notification.Name("sharePlayVisualizationReceived")
}
