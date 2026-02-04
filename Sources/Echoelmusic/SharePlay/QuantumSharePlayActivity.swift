//
//  QuantumSharePlayActivity.swift
//  Echoelmusic
//
//  SharePlay Group Quantum Sessions - Entangled Consciousness
//  Multiple users share synchronized quantum coherence
//
//  Created: 2026-01-05
//

import Foundation
import Combine

#if canImport(GroupActivities)
import GroupActivities
#endif

// MARK: - Quantum SharePlay Activity

#if canImport(GroupActivities)
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct QuantumSharePlayActivity: GroupActivity {

    public static let activityIdentifier = "com.echoelmusic.quantum-session"

    public var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Quantum Light Session"
        meta.subtitle = "Entangled Consciousness Experience"
        meta.previewImage = nil // Add app icon
        meta.type = .generic
        return meta
    }

    // Session configuration
    public let sessionId: String
    public let hostDeviceId: String
    public let quantumMode: String
    public let coherenceTarget: Float

    public init(
        sessionId: String = UUID().uuidString,
        hostDeviceId: String,
        quantumMode: String = "bioCoherent",
        coherenceTarget: Float = 0.7
    ) {
        self.sessionId = sessionId
        self.hostDeviceId = hostDeviceId
        self.quantumMode = quantumMode
        self.coherenceTarget = coherenceTarget
    }
}
#endif

// MARK: - SharePlay Session Manager

@MainActor
public class QuantumSharePlayManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var participantCount: Int = 0
    @Published public private(set) var participants: [QuantumParticipant] = []
    @Published public private(set) var groupCoherence: Float = 0.0
    @Published public private(set) var entanglementStrength: Float = 0.0
    @Published public private(set) var sessionPhase: SessionPhase = .idle

    public enum SessionPhase: String {
        case idle = "Idle"
        case preparing = "Preparing"
        case syncing = "Synchronizing"
        case entangled = "Entangled"
        case coherent = "Group Coherent"
        case transcendent = "Transcendent"
    }

    // MARK: - Participant Model

    public struct QuantumParticipant: Identifiable, Sendable {
        public let id: String
        public let displayName: String
        public var coherenceLevel: Float
        public var heartRate: Double
        public var hrvCoherence: Double
        public var isHost: Bool
        public var connectionQuality: Float

        public init(
            id: String,
            displayName: String,
            coherenceLevel: Float = 0.5,
            heartRate: Double = 72,
            hrvCoherence: Double = 50,
            isHost: Bool = false,
            connectionQuality: Float = 1.0
        ) {
            self.id = id
            self.displayName = displayName
            self.coherenceLevel = coherenceLevel
            self.heartRate = heartRate
            self.hrvCoherence = hrvCoherence
            self.isHost = isHost
            self.connectionQuality = connectionQuality
        }
    }

    // MARK: - Message Types

    public enum SharePlayMessage: Codable, Sendable {
        case coherenceUpdate(participantId: String, coherence: Float)
        case bioDataUpdate(participantId: String, heartRate: Double, hrv: Double)
        case quantumStateSync(stateData: Data)
        case lightFieldSync(fieldData: Data)
        case phaseTransition(newPhase: String)
        case entanglementPulse(timestamp: Double)
        case collectiveIntention(intention: String)
    }

    // MARK: - Private Properties

    #if canImport(GroupActivities)
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    private var groupSession: GroupSession<QuantumSharePlayActivity>?
    private var messenger: GroupSessionMessenger?
    #endif

    private var cancellables = Set<AnyCancellable>()
    private weak var quantumEmulator: QuantumLightEmulator?
    private var coherenceUpdateTimer: Timer?

    // MARK: - Singleton

    public static let shared = QuantumSharePlayManager()

    private init() {
        setupActivityObserver()
    }

    // MARK: - Setup

    private func setupActivityObserver() {
        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            Task {
                for await session in QuantumSharePlayActivity.sessions() {
                    await configureSession(session)
                }
            }
        }
        #endif
    }

    // MARK: - Public Methods

    /// Connect quantum emulator for syncing
    public func connect(emulator: QuantumLightEmulator) {
        self.quantumEmulator = emulator

        // Observe emulator coherence changes
        emulator.$coherenceLevel
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] coherence in
                self?.broadcastCoherenceUpdate(coherence)
            }
            .store(in: &cancellables)
    }

    /// Start a new quantum session
    public func startSession() async throws {
        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            let activity = QuantumSharePlayActivity(
                hostDeviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
                quantumMode: quantumEmulator?.emulationMode.rawValue ?? "bioCoherent",
                coherenceTarget: 0.7
            )

            do {
                _ = try await activity.activate()
                sessionPhase = .preparing
                log.collaboration("[SharePlay] Quantum session started")
            } catch {
                log.collaboration("[SharePlay] Failed to start: \(error)", level: .error)
                throw error
            }
        }
        #endif
    }

    /// Join existing session
    public func joinSession() {
        sessionPhase = .syncing
        startCoherenceSync()
    }

    /// Leave current session
    public func leaveSession() {
        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            groupSession?.leave()
            groupSession = nil
            messenger = nil
        }
        #endif

        isSessionActive = false
        participants.removeAll()
        participantCount = 0
        groupCoherence = 0
        entanglementStrength = 0
        sessionPhase = .idle
        coherenceUpdateTimer?.invalidate()
    }

    /// Send collective intention to all participants
    public func sendCollectiveIntention(_ intention: String) async {
        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            let message = SharePlayMessage.collectiveIntention(intention: intention)
            try? await messenger?.send(message)
        }
        #endif
    }

    /// Trigger entanglement pulse (synchronize quantum states)
    public func triggerEntanglementPulse() async {
        let timestamp = CACurrentMediaTime()

        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            let message = SharePlayMessage.entanglementPulse(timestamp: timestamp)
            try? await messenger?.send(message)
        }
        #endif

        // Local pulse effect
        quantumEmulator?.updateBioInputs(
            hrvCoherence: 100,
            heartRate: 60,
            breathingRate: 6
        )
    }

    // MARK: - Private Methods

    #if canImport(GroupActivities)
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    private func configureSession(_ session: GroupSession<QuantumSharePlayActivity>) async {
        self.groupSession = session
        self.messenger = GroupSessionMessenger(session: session)

        // Observe session state
        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .joined:
                    self?.isSessionActive = true
                    self?.sessionPhase = .syncing
                    self?.startCoherenceSync()
                case .waiting:
                    self?.sessionPhase = .preparing
                case .invalidated:
                    self?.leaveSession()
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe participants
        session.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeParticipants in
                self?.participantCount = activeParticipants.count
                self?.updateParticipantsList(from: activeParticipants)
            }
            .store(in: &cancellables)

        // Receive messages
        Task {
            guard let messenger = messenger else { return }
            for await (message, _) in messenger.messages(of: SharePlayMessage.self) {
                await handleMessage(message)
            }
        }

        // Join the session
        session.join()
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    private func updateParticipantsList(from activeParticipants: some Collection<GroupActivities.Participant>) {
        // Update or add participants
        for participant in activeParticipants {
            if let index = participants.firstIndex(where: { $0.id == participant.id.uuidString }) {
                // Update existing
                participants[index].connectionQuality = 1.0
            } else {
                // Add new
                let newParticipant = QuantumParticipant(
                    id: participant.id.uuidString,
                    displayName: "Participant \(participants.count + 1)"
                )
                participants.append(newParticipant)
            }
        }

        // Remove disconnected
        let activeIds = Set(activeParticipants.map { $0.id.uuidString })
        participants.removeAll { !activeIds.contains($0.id) }
    }
    #endif

    private func handleMessage(_ message: SharePlayMessage) async {
        switch message {
        case .coherenceUpdate(let participantId, let coherence):
            updateParticipantCoherence(participantId: participantId, coherence: coherence)

        case .bioDataUpdate(let participantId, let heartRate, let hrv):
            updateParticipantBioData(participantId: participantId, heartRate: heartRate, hrv: hrv)

        case .quantumStateSync(let stateData):
            syncQuantumState(stateData)

        case .lightFieldSync(let fieldData):
            syncLightField(fieldData)

        case .phaseTransition(let newPhase):
            if let phase = SessionPhase(rawValue: newPhase) {
                sessionPhase = phase
            }

        case .entanglementPulse(let timestamp):
            handleEntanglementPulse(timestamp: timestamp)

        case .collectiveIntention(let intention):
            handleCollectiveIntention(intention)
        }
    }

    private func updateParticipantCoherence(participantId: String, coherence: Float) {
        if let index = participants.firstIndex(where: { $0.id == participantId }) {
            participants[index].coherenceLevel = coherence
        }
        calculateGroupCoherence()
    }

    private func updateParticipantBioData(participantId: String, heartRate: Double, hrv: Double) {
        if let index = participants.firstIndex(where: { $0.id == participantId }) {
            participants[index].heartRate = heartRate
            participants[index].hrvCoherence = hrv
        }
    }

    private func calculateGroupCoherence() {
        guard !participants.isEmpty else {
            groupCoherence = 0
            return
        }

        let totalCoherence = participants.map(\.coherenceLevel).reduce(0, +)
        groupCoherence = totalCoherence / Float(participants.count)

        // Calculate entanglement strength based on coherence variance
        let mean = groupCoherence
        let variance = participants.map { pow($0.coherenceLevel - mean, 2) }.reduce(0, +) / Float(participants.count)
        entanglementStrength = 1.0 - min(1.0, sqrt(variance) * 2)

        // Update phase based on group state
        updateSessionPhase()
    }

    private func updateSessionPhase() {
        if groupCoherence > 0.9 && entanglementStrength > 0.9 {
            sessionPhase = .transcendent
        } else if groupCoherence > 0.7 && entanglementStrength > 0.7 {
            sessionPhase = .coherent
        } else if entanglementStrength > 0.5 {
            sessionPhase = .entangled
        } else {
            sessionPhase = .syncing
        }
    }

    private func syncQuantumState(_ data: Data) {
        // Decode and apply quantum state from another participant
        // Would deserialize QuantumAudioState here
    }

    private func syncLightField(_ data: Data) {
        // Decode and blend light field from group
    }

    private func handleEntanglementPulse(timestamp: Double) {
        // Synchronize all emulators to the pulse
        let localTime = CACurrentMediaTime()
        let latency = localTime - timestamp

        log.collaboration("[SharePlay] Entanglement pulse received, latency: \(latency * 1000)ms")

        // Flash coherence to maximum briefly
        Task {
            quantumEmulator?.updateBioInputs(hrvCoherence: 100, heartRate: 60, breathingRate: 6)
            try? await Task.sleep(nanoseconds: 500_000_000)
            // Return to normal
        }
    }

    private func handleCollectiveIntention(_ intention: String) {
        log.collaboration("[SharePlay] Collective intention: \(intention)")
        // Could trigger specific visualization or audio response
    }

    private func broadcastCoherenceUpdate(_ coherence: Float) {
        guard isSessionActive else { return }

        #if canImport(GroupActivities)
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            let message = SharePlayMessage.coherenceUpdate(participantId: deviceId, coherence: coherence)

            Task {
                try? await messenger?.send(message)
            }
        }
        #endif
    }

    private func startCoherenceSync() {
        coherenceUpdateTimer?.invalidate()
        coherenceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateGroupCoherence()
            }
        }
    }
}

// MARK: - SharePlay UI Components

import SwiftUI

#if canImport(GroupActivities)
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct SharePlayControlView: View {
    @ObservedObject var manager = QuantumSharePlayManager.shared
    @State private var showIntentionInput = false
    @State private var intentionText = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "shareplay")
                    .font(.title2)
                    .foregroundColor(manager.isSessionActive ? .green : .secondary)

                Text("Quantum SharePlay")
                    .font(.headline)

                Spacer()

                Text(manager.sessionPhase.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(phaseColor.opacity(0.2))
                    .clipShape(Capsule())
            }

            if manager.isSessionActive {
                // Active session UI
                VStack(spacing: 12) {
                    // Group coherence meter
                    GroupCoherenceMeter(
                        groupCoherence: manager.groupCoherence,
                        entanglement: manager.entanglementStrength
                    )

                    // Participants
                    ParticipantsList(participants: manager.participants)

                    // Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            Task { await manager.triggerEntanglementPulse() }
                        }) {
                            Label("Pulse", systemImage: "bolt.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { showIntentionInput = true }) {
                            Label("Intention", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { manager.leaveSession() }) {
                            Label("Leave", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            } else {
                // Start session UI
                Button(action: {
                    Task { try? await manager.startSession() }
                }) {
                    Label("Start Quantum Session", systemImage: "shareplay")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("Set Collective Intention", isPresented: $showIntentionInput) {
            TextField("Intention", text: $intentionText)
            Button("Send") {
                Task { await manager.sendCollectiveIntention(intentionText) }
                intentionText = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var phaseColor: Color {
        switch manager.sessionPhase {
        case .idle: return .gray
        case .preparing: return .yellow
        case .syncing: return .orange
        case .entangled: return .blue
        case .coherent: return .green
        case .transcendent: return .purple
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct GroupCoherenceMeter: View {
    let groupCoherence: Float
    let entanglement: Float

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Group Coherence")
                    .font(.caption)
                Spacer()
                Text("\(Int(groupCoherence * 100))%")
                    .font(.caption.bold())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(groupCoherence))
                }
            }
            .frame(height: 8)

            HStack {
                Text("Entanglement")
                    .font(.caption)
                Spacer()
                Text("\(Int(entanglement * 100))%")
                    .font(.caption.bold())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cyan)
                        .frame(width: geo.size.width * CGFloat(entanglement))
                }
            }
            .frame(height: 8)
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ParticipantsList: View {
    let participants: [QuantumSharePlayManager.QuantumParticipant]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(participants) { participant in
                    ParticipantBubble(participant: participant)
                }
            }
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ParticipantBubble: View {
    let participant: QuantumSharePlayManager.QuantumParticipant

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(coherenceColor, lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .fill(coherenceColor.opacity(0.3))
                    .frame(width: 44, height: 44)

                Text(participant.displayName.prefix(1))
                    .font(.headline)
            }

            Text("\(Int(participant.coherenceLevel * 100))%")
                .font(.caption2)

            if participant.isHost {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
    }

    private var coherenceColor: Color {
        if participant.coherenceLevel > 0.7 {
            return .green
        } else if participant.coherenceLevel > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }
}
#endif // canImport(GroupActivities)

// MARK: - Platform Compatibility

#if !canImport(GroupActivities)
// Stub for platforms without GroupActivities
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct SharePlayControlView: View {
    public init() {}
    public var body: some View {
        Text("SharePlay requires iOS 15+ / macOS 12+")
            .foregroundColor(.secondary)
    }
}
#endif
