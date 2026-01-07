import Foundation
import Combine

#if os(tvOS) || os(iOS)
import GroupActivities

// MARK: - Echoelmusic Group Activity

/// SharePlay activity for synchronized bio-reactive experiences
struct EchoelmusicActivity: GroupActivity {

    /// Activity metadata
    static let activityIdentifier = "com.echoelmusic.shareplay"

    /// Session type
    let sessionType: SessionType

    /// Session configuration
    let configuration: SessionConfiguration

    /// Activity metadata for SharePlay UI
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Echoelmusic: \(sessionType.displayName)"
        meta.subtitle = "Bio-Reactive Audio Experience"
        meta.previewImage = nil // Add app icon here
        meta.type = .generic
        return meta
    }

    // MARK: - Session Types

    enum SessionType: String, Codable {
        case meditation = "meditation"
        case breathing = "breathing"
        case coherenceTraining = "coherence"
        case musicCreation = "music"
        case visualization = "visualization"

        var displayName: String {
            switch self {
            case .meditation: return "Group Meditation"
            case .breathing: return "Synchronized Breathing"
            case .coherenceTraining: return "Coherence Training"
            case .musicCreation: return "Collaborative Music"
            case .visualization: return "Shared Visualization"
            }
        }
    }

    // MARK: - Session Configuration

    struct SessionConfiguration: Codable {
        let targetDuration: TimeInterval
        let breathingRate: Double
        let binauralFrequency: Float
        let visualizationMode: String

        static let `default` = SessionConfiguration(
            targetDuration: 600, // 10 minutes
            breathingRate: 6.0,
            binauralFrequency: 10.0, // Alpha waves
            visualizationMode: "mandala"
        )
    }
}

// MARK: - Group Session Manager

/// Manages SharePlay sessions for synchronized experiences
@MainActor
@Observable
class GroupSessionManager {

    // MARK: - Singleton

    static let shared = GroupSessionManager()

    // MARK: - Published Properties

    /// Current group session
    private(set) var groupSession: GroupSession<EchoelmusicActivity>?

    /// Is SharePlay active
    var isSharePlayActive: Bool { groupSession != nil }

    /// Connected participants
    private(set) var participants: [Participant] = []

    /// Synchronized state
    private(set) var synchronizedState: SynchronizedState = SynchronizedState()

    /// Session messages
    private(set) var messages: [SessionMessage] = []

    // MARK: - Private Properties

    private var messenger: GroupSessionMessenger?
    private var tasks = Set<Task<Void, Never>>()
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Types

    struct Participant: Identifiable {
        let id: UUID
        let name: String
        var bioMetrics: BioMetrics?
        var isLocal: Bool

        struct BioMetrics: Codable {
            var heartRate: Double
            var hrv: Double
            var coherence: Double
            var breathingPhase: Double // 0-1, for sync visualization
        }
    }

    struct SynchronizedState: Codable {
        var isPlaying: Bool = false
        var currentTime: TimeInterval = 0
        var breathingPhase: Double = 0
        var visualizationIntensity: Double = 0.5
        var groupCoherence: Double = 0 // Average of all participants
    }

    struct SessionMessage: Codable, Identifiable {
        let id: UUID
        let type: MessageType
        let senderId: UUID
        let timestamp: Date
        let payload: Data?

        enum MessageType: String, Codable {
            case bioUpdate
            case stateChange
            case reaction
            case chat
        }
    }

    // MARK: - Initialization

    private init() {
        observeGroupSessions()
    }

    // MARK: - Public Methods

    /// Start a new SharePlay session
    func startSession(type: EchoelmusicActivity.SessionType, configuration: EchoelmusicActivity.SessionConfiguration = .default) async throws {
        let activity = EchoelmusicActivity(sessionType: type, configuration: configuration)

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            _ = try await activity.activate()
            log.collaboration("📺 SharePlay session started: \(type.displayName)")

        case .activationDisabled:
            throw GroupSessionError.activationDisabled

        case .cancelled:
            throw GroupSessionError.cancelled

        @unknown default:
            throw GroupSessionError.unknown
        }
    }

    /// End the current SharePlay session
    func endSession() {
        groupSession?.end()
        groupSession = nil
        messenger = nil
        participants.removeAll()
        synchronizedState = SynchronizedState()
        log.collaboration("📺 SharePlay session ended")
    }

    /// Send bio metrics update to all participants
    func sendBioUpdate(heartRate: Double, hrv: Double, coherence: Double, breathingPhase: Double) async throws {
        guard let messenger = messenger else { return }

        let bioMetrics = Participant.BioMetrics(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            breathingPhase: breathingPhase
        )

        let message = SessionMessage(
            id: UUID(),
            type: .bioUpdate,
            senderId: UUID(), // Local user ID
            timestamp: Date(),
            payload: try JSONEncoder().encode(bioMetrics)
        )

        try await messenger.send(message)
    }

    /// Send synchronized state update
    func sendStateUpdate(_ state: SynchronizedState) async throws {
        guard let messenger = messenger else { return }

        let message = SessionMessage(
            id: UUID(),
            type: .stateChange,
            senderId: UUID(),
            timestamp: Date(),
            payload: try JSONEncoder().encode(state)
        )

        try await messenger.send(message)
    }

    /// Send a reaction (emoji, haptic feedback trigger, etc.)
    func sendReaction(_ reaction: String) async throws {
        guard let messenger = messenger else { return }

        let message = SessionMessage(
            id: UUID(),
            type: .reaction,
            senderId: UUID(),
            timestamp: Date(),
            payload: reaction.data(using: .utf8)
        )

        try await messenger.send(message)
    }

    // MARK: - Private Methods

    private func observeGroupSessions() {
        Task {
            for await session in EchoelmusicActivity.sessions() {
                await configureSession(session)
            }
        }
    }

    private func configureSession(_ session: GroupSession<EchoelmusicActivity>) async {
        self.groupSession = session

        // Create messenger for synchronized communication
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger

        // Observe session state
        let stateTask = Task {
            for await state in session.$state.values {
                await handleSessionState(state)
            }
        }
        tasks.insert(stateTask)

        // Observe participants
        let participantsTask = Task {
            for await activeParticipants in session.$activeParticipants.values {
                await handleParticipantsChange(activeParticipants)
            }
        }
        tasks.insert(participantsTask)

        // Receive messages
        let messagesTask = Task {
            for await (message, _) in messenger.messages(of: SessionMessage.self) {
                await handleMessage(message)
            }
        }
        tasks.insert(messagesTask)

        // Join the session
        session.join()

        log.collaboration("📺 Joined SharePlay session: \(session.activity.sessionType.displayName)")
    }

    private func handleSessionState(_ state: GroupSession<EchoelmusicActivity>.State) async {
        switch state {
        case .waiting:
            log.collaboration("📺 Waiting for participants...")
        case .joined:
            log.collaboration("📺 Session joined!")
        case .invalidated(let reason):
            log.collaboration("📺 Session invalidated: \(reason)", level: .warning)
            endSession()
        @unknown default:
            break
        }
    }

    private func handleParticipantsChange(_ activeParticipants: Set<GroupActivities.Participant>) async {
        // Update local participants list
        participants = activeParticipants.map { participant in
            Participant(
                id: participant.id.hashValue > 0 ? UUID() : UUID(),
                name: "Participant",
                bioMetrics: nil,
                isLocal: participant == groupSession?.localParticipant
            )
        }

        // Recalculate group coherence
        updateGroupCoherence()

        log.collaboration("📺 Participants updated: \(participants.count) active")
    }

    private func handleMessage(_ message: SessionMessage) async {
        messages.append(message)

        switch message.type {
        case .bioUpdate:
            if let payload = message.payload,
               let bioMetrics = try? JSONDecoder().decode(Participant.BioMetrics.self, from: payload) {
                // Update participant's bio metrics
                if let index = participants.firstIndex(where: { $0.id == message.senderId }) {
                    participants[index].bioMetrics = bioMetrics
                }
                updateGroupCoherence()
            }

        case .stateChange:
            if let payload = message.payload,
               let state = try? JSONDecoder().decode(SynchronizedState.self, from: payload) {
                synchronizedState = state
            }

        case .reaction:
            if let payload = message.payload,
               let reaction = String(data: payload, encoding: .utf8) {
                // Trigger visual/haptic feedback for reaction
                log.collaboration("📺 Reaction received: \(reaction)", level: .debug)
            }

        case .chat:
            // Handle chat messages
            break
        }
    }

    private func updateGroupCoherence() {
        let coherenceValues = participants.compactMap { $0.bioMetrics?.coherence }
        if !coherenceValues.isEmpty {
            synchronizedState.groupCoherence = coherenceValues.reduce(0, +) / Double(coherenceValues.count)
        }
    }

    // MARK: - Errors

    enum GroupSessionError: Error, LocalizedError {
        case activationDisabled
        case cancelled
        case unknown

        var errorDescription: String? {
            switch self {
            case .activationDisabled:
                return "SharePlay is not available. Please enable it in Settings."
            case .cancelled:
                return "SharePlay session was cancelled."
            case .unknown:
                return "An unknown error occurred."
            }
        }
    }
}

#endif
