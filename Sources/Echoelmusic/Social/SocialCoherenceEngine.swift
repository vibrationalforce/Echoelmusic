// SocialCoherenceEngine.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Social Coherence & Group Flow System
// Synchronize bio-rhythms across multiple participants for collective flow states
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - Social Constants

/// Constants for social coherence calculations
public enum SocialCoherenceConstants {
    public static let maxParticipants: Int = 1000
    public static let coherenceWindow: TimeInterval = 30.0  // seconds
    public static let syncThreshold: Float = 0.7
    public static let flowThreshold: Float = 0.8
    public static let entanglementThreshold: Float = 0.9
    public static let updateInterval: TimeInterval = 1.0/30.0  // 30 Hz
    public static let phi: Float = 1.618033988749895
}

// MARK: - Social Participant

/// Individual participant in a social coherence session (renamed to avoid conflict with WorldwideCollaborationHub.Participant)
public struct SocialParticipant: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String
    public var avatarURL: URL?
    public var bio: ParticipantBioData
    public var connectionQuality: Float  // 0-1
    public var lastUpdate: Date
    public var isActive: Bool
    public var location: ParticipantLocation?
    public var role: ParticipantRole

    public struct ParticipantBioData: Equatable, Sendable {
        public var heartRate: Double = 70.0
        public var hrv: Double = 50.0
        public var coherence: Float = 0.5
        public var breathingRate: Double = 12.0
        public var breathPhase: Float = 0.0

        public init() {}
    }

    public struct ParticipantLocation: Equatable, Sendable {
        public var latitude: Double
        public var longitude: Double
        public var city: String?
        public var country: String?
        public var timezone: String

        public init(latitude: Double, longitude: Double, timezone: String) {
            self.latitude = latitude
            self.longitude = longitude
            self.timezone = timezone
        }
    }

    public enum ParticipantRole: String, CaseIterable, Sendable {
        case participant = "Participant"
        case facilitator = "Facilitator"
        case observer = "Observer"
        case researcher = "Researcher"
    }

    public init(id: UUID = UUID(), displayName: String, role: ParticipantRole = .participant) {
        self.id = id
        self.displayName = displayName
        self.bio = ParticipantBioData()
        self.connectionQuality = 1.0
        self.lastUpdate = Date()
        self.isActive = true
        self.role = role
    }
}

// MARK: - Group State

/// Collective state of the group
public struct GroupState: Equatable, Sendable {
    public var participants: [SocialParticipant]
    public var groupCoherence: Float  // 0-1
    public var groupFlowScore: Float  // 0-1
    public var heartRateSync: Float  // Synchronization score
    public var breathSync: Float
    public var hrvSync: Float
    public var collectiveEnergy: Float
    public var resonanceField: Float  // Strength of group field
    public var dominantFrequency: Float  // Hz
    public var entrainmentLevel: Float  // How well group is entrained
    public var timestamp: Date

    public init() {
        self.participants = []
        self.groupCoherence = 0.0
        self.groupFlowScore = 0.0
        self.heartRateSync = 0.0
        self.breathSync = 0.0
        self.hrvSync = 0.0
        self.collectiveEnergy = 0.0
        self.resonanceField = 0.0
        self.dominantFrequency = 7.83  // Schumann resonance
        self.entrainmentLevel = 0.0
        self.timestamp = Date()
    }

    public var activeParticipants: [SocialParticipant] {
        participants.filter { $0.isActive }
    }

    public var participantCount: Int {
        activeParticipants.count
    }

    public var isInGroupFlow: Bool {
        groupFlowScore > SocialCoherenceConstants.flowThreshold
    }

    public var isEntangled: Bool {
        entrainmentLevel > SocialCoherenceConstants.entanglementThreshold
    }
}

// MARK: - Coherence Event

/// Events in a social coherence session
public struct CoherenceEvent: Identifiable, Sendable {
    public let id = UUID()
    public var type: EventType
    public var timestamp: Date
    public var participantId: UUID?
    public var description: String
    public var magnitude: Float

    public enum EventType: String, CaseIterable, Sendable {
        case participantJoined = "Participant Joined"
        case participantLeft = "Participant Left"
        case coherenceSpike = "Coherence Spike"
        case flowStateAchieved = "Flow State Achieved"
        case groupEntanglement = "Group Entanglement"
        case breathSyncAchieved = "Breath Sync Achieved"
        case heartSyncAchieved = "Heart Sync Achieved"
        case resonancePeak = "Resonance Peak"
        case collectiveShift = "Collective Shift"
        case coherenceDrop = "Coherence Drop"
    }

    public init(type: EventType, description: String = "", participantId: UUID? = nil, magnitude: Float = 1.0) {
        self.type = type
        self.timestamp = Date()
        self.participantId = participantId
        self.description = description.isEmpty ? type.rawValue : description
        self.magnitude = magnitude
    }
}

// MARK: - Session Configuration

/// Configuration for a social coherence session
public struct SessionConfiguration: Sendable {
    public var name: String
    public var type: SessionType
    public var maxParticipants: Int
    public var isPrivate: Bool
    public var passcode: String?
    public var guidedExercise: GuidedExercise?
    public var bioSyncEnabled: Bool
    public var breathGuidanceEnabled: Bool
    public var heartGuidanceEnabled: Bool
    public var visualSyncEnabled: Bool
    public var hapticSyncEnabled: Bool
    public var audioSyncEnabled: Bool

    public enum SessionType: String, CaseIterable, Sendable {
        case openMeditation = "Open Meditation"
        case guidedBreathing = "Guided Breathing"
        case coherenceCircle = "Coherence Circle"
        case musicJam = "Music Jam"
        case researchStudy = "Research Study"
        case wellnessCircle = "Wellness Circle"  // Renamed from "Healing" - scientific terminology
        case creativeFusion = "Creative Fusion"
        case quantumEntanglement = "Quantum Entanglement"
    }

    public enum GuidedExercise: String, CaseIterable, Sendable {
        case boxBreathing = "Box Breathing"
        case coherenceBreathing = "Coherence Breathing"
        case heartMeditation = "Heart Meditation"
        case bodyRelaxation = "Body Relaxation"
        case groupVisualization = "Group Visualization"
        case soundBath = "Sound Bath"
    }

    public init(name: String = "Coherence Session", type: SessionType = .openMeditation) {
        self.name = name
        self.type = type
        self.maxParticipants = 100
        self.isPrivate = false
        self.bioSyncEnabled = true
        self.breathGuidanceEnabled = true
        self.heartGuidanceEnabled = false
        self.visualSyncEnabled = true
        self.hapticSyncEnabled = true
        self.audioSyncEnabled = true
    }
}

// MARK: - Social Coherence Engine

/// Main engine for social coherence and group flow
@MainActor
public final class SocialCoherenceEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: EngineState = .idle
    @Published public private(set) var groupState = GroupState()
    @Published public private(set) var events: [CoherenceEvent] = []
    @Published public private(set) var sessionDuration: TimeInterval = 0
    @Published public private(set) var localParticipant: SocialParticipant?

    @Published public var configuration = SessionConfiguration()

    // MARK: - State

    public enum EngineState: String, CaseIterable, Sendable {
        case idle = "Idle"
        case connecting = "Connecting"
        case active = "Active"
        case paused = "Paused"
        case ending = "Ending"
        case error = "Error"
    }

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var coherenceHistory: [Float] = []
    private var flowHistory: [Float] = []

    // MARK: - Initialization

    public init() {
        setupLocalParticipant()
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func setupLocalParticipant() {
        localParticipant = SocialParticipant(
            displayName: "You",
            role: .participant
        )
    }

    // MARK: - Session Lifecycle

    /// Start a new session
    public func startSession(with config: SessionConfiguration) {
        configuration = config
        state = .connecting

        // Initialize group state
        groupState = GroupState()

        // Add local participant
        if var local = localParticipant {
            local.isActive = true
            groupState.participants.append(local)
        }

        // Start update loop
        sessionStartTime = Date()
        startUpdateLoop()

        state = .active
        addEvent(.participantJoined, description: "Session started: \(config.name)")

        log.social("SocialCoherenceEngine: Session started - \(config.name)")
    }

    /// Join an existing session
    public func joinSession(sessionId: String) async throws {
        state = .connecting

        // Simulate network connection
        try await Task.sleep(nanoseconds: 500_000_000)

        // Add local participant
        if var local = localParticipant {
            local.isActive = true
            groupState.participants.append(local)
        }

        // Add some simulated participants
        simulateParticipants(count: Int.random(in: 3...10))

        sessionStartTime = Date()
        startUpdateLoop()

        state = .active
        addEvent(.participantJoined, description: "Joined session")

        log.social("SocialCoherenceEngine: Joined session \(sessionId)")
    }

    /// Leave the current session
    public func leaveSession() {
        addEvent(.participantLeft, description: "Left session")

        stopUpdateLoop()
        state = .idle

        // Remove local participant
        if let local = localParticipant {
            groupState.participants.removeAll { $0.id == local.id }
        }

        log.social("SocialCoherenceEngine: Left session")
    }

    /// End the session (for facilitators)
    public func endSession() {
        state = .ending
        addEvent(.collectiveShift, description: "Session ended by facilitator")

        stopUpdateLoop()

        // Calculate final stats
        let finalCoherence = groupState.groupCoherence
        let duration = sessionDuration
        log.social("SocialCoherenceEngine: Session ended - Duration: \(Int(duration))s, Final coherence: \(String(format: "%.2f", finalCoherence))")

        state = .idle
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: SocialCoherenceConstants.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func update() {
        guard state == .active else { return }

        // Update session duration
        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }

        // Simulate bio data updates for all participants
        updateParticipantsBioData()

        // Calculate group metrics
        calculateGroupMetrics()

        // Check for events
        checkForEvents()
    }

    // MARK: - Bio Data Updates

    /// Update local participant bio data
    public func updateLocalBioData(heartRate: Double, hrv: Double, coherence: Float, breathingRate: Double, breathPhase: Float) {
        guard var local = localParticipant else { return }

        local.bio.heartRate = heartRate
        local.bio.hrv = hrv
        local.bio.coherence = coherence
        local.bio.breathingRate = breathingRate
        local.bio.breathPhase = breathPhase
        local.lastUpdate = Date()

        localParticipant = local

        // Update in group
        if let index = groupState.participants.firstIndex(where: { $0.id == local.id }) {
            groupState.participants[index] = local
        }
    }

    private func updateParticipantsBioData() {
        // Simulate bio data for non-local participants
        for i in 0..<groupState.participants.count {
            guard groupState.participants[i].id != localParticipant?.id else { continue }

            // Simulate realistic variations
            let baseHR = Double.random(in: 60...80)
            let hrVariation = sin(sessionDuration * 0.1 + Double(i)) * 5
            groupState.participants[i].bio.heartRate = baseHR + hrVariation

            let baseHRV = Double.random(in: 40...70)
            groupState.participants[i].bio.hrv = baseHRV + Double.random(in: -5...5)

            // Coherence tends to increase over time in group settings
            let coherenceTrend = Float(min(0.3, sessionDuration / 600))  // Max +0.3 over 10 min
            let baseCoherence = Float.random(in: 0.4...0.7)
            groupState.participants[i].bio.coherence = min(1.0, baseCoherence + coherenceTrend)

            let baseBR = Double.random(in: 10...16)
            groupState.participants[i].bio.breathingRate = baseBR

            // Breath phase cycles
            let breathCycle = sessionDuration / 5.0  // 5 second breath cycle
            groupState.participants[i].bio.breathPhase = Float(fmod(breathCycle + Double(i) * 0.1, 1.0))

            groupState.participants[i].lastUpdate = Date()
        }
    }

    // MARK: - Group Metrics Calculation

    private func calculateGroupMetrics() {
        let active = groupState.activeParticipants
        guard active.count > 0 else {
            groupState.groupCoherence = 0
            groupState.groupFlowScore = 0
            return
        }

        // Calculate average coherence
        let avgCoherence = active.map { $0.bio.coherence }.reduce(0, +) / Float(active.count)

        // Calculate heart rate synchronization
        let heartRates = active.map { $0.bio.heartRate }
        let hrSync = calculateSynchronization(values: heartRates)

        // Calculate breath synchronization
        let breathPhases = active.map { Double($0.bio.breathPhase) }
        let breathSync = calculatePhaseSynchronization(phases: breathPhases)

        // Calculate HRV synchronization
        let hrvValues = active.map { $0.bio.hrv }
        let hrvSync = calculateSynchronization(values: hrvValues)

        // Calculate collective energy (based on average HR and coherence)
        let avgHR = heartRates.reduce(0, +) / Double(heartRates.count)
        let energy = Float((avgHR - 60) / 40) * avgCoherence  // Normalized

        // Calculate resonance field strength
        let resonance = (hrSync + breathSync + Float(avgCoherence)) / 3.0

        // Calculate entrainment level
        let entrainment = (hrSync * 0.3 + breathSync * 0.4 + hrvSync * 0.3) * avgCoherence

        // Calculate group flow score
        let flowScore = calculateFlowScore(coherence: avgCoherence, sync: entrainment, energy: energy)

        // Update group state
        groupState.groupCoherence = avgCoherence
        groupState.heartRateSync = hrSync
        groupState.breathSync = breathSync
        groupState.hrvSync = hrvSync
        groupState.collectiveEnergy = energy.clamped(to: 0...1)
        groupState.resonanceField = resonance.clamped(to: 0...1)
        groupState.entrainmentLevel = entrainment.clamped(to: 0...1)
        groupState.groupFlowScore = flowScore
        groupState.timestamp = Date()

        // Update history - LAMBDA LOOP: Batch removal for 10x less O(n) overhead
        coherenceHistory.append(avgCoherence)
        flowHistory.append(flowScore)
        // Remove 100 at once instead of 1 at a time (10x fewer array shifts)
        if coherenceHistory.count > 1100 { coherenceHistory.removeFirst(100) }
        if flowHistory.count > 1100 { flowHistory.removeFirst(100) }
    }

    private func calculateSynchronization(values: [Double]) -> Float {
        guard values.count > 1 else { return 1.0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)

        // Lower standard deviation = higher sync
        // Normalize: stdDev of 0 = 1.0 sync, stdDev of 20+ = 0 sync
        return Float(max(0, 1.0 - stdDev / 20.0))
    }

    private func calculatePhaseSynchronization(phases: [Double]) -> Float {
        guard phases.count > 1 else { return 1.0 }

        // Calculate mean resultant length (measure of phase coherence)
        var sumCos: Double = 0
        var sumSin: Double = 0

        for phase in phases {
            let angle = phase * 2 * Double.pi
            sumCos += cos(angle)
            sumSin += sin(angle)
        }

        let meanResultant = sqrt(sumCos * sumCos + sumSin * sumSin) / Double(phases.count)
        return Float(meanResultant)
    }

    private func calculateFlowScore(coherence: Float, sync: Float, energy: Float) -> Float {
        // Flow emerges from coherence, synchronization, and balanced energy
        let phi = SocialCoherenceConstants.phi

        // Golden ratio weighted combination
        let baseFlow = coherence * (1/phi) + sync * (1/phi/phi) + energy * (1 - 1/phi - 1/phi/phi)

        // Bonus for high sync
        let syncBonus = sync > 0.7 ? (sync - 0.7) * 0.5 : 0

        // Penalty for low coherence
        let coherencePenalty = coherence < 0.3 ? (0.3 - coherence) * 0.5 : 0

        return (baseFlow + syncBonus - coherencePenalty).clamped(to: 0...1)
    }

    // MARK: - Event Detection

    private func checkForEvents() {
        let state = groupState

        // Check for flow state achievement
        if state.groupFlowScore > SocialCoherenceConstants.flowThreshold {
            if !flowHistory.dropLast().contains(where: { $0 > SocialCoherenceConstants.flowThreshold }) {
                addEvent(.flowStateAchieved, description: "Group entered flow state!", magnitude: state.groupFlowScore)
            }
        }

        // Check for breath synchronization
        if state.breathSync > SocialCoherenceConstants.syncThreshold {
            // Don't spam events
            if events.filter({ $0.type == .breathSyncAchieved }).count < Int(sessionDuration / 60) {
                addEvent(.breathSyncAchieved, description: "Breath synchronized across group", magnitude: state.breathSync)
            }
        }

        // Check for heart synchronization
        if state.heartRateSync > SocialCoherenceConstants.syncThreshold {
            if events.filter({ $0.type == .heartSyncAchieved }).count < Int(sessionDuration / 60) {
                addEvent(.heartSyncAchieved, description: "Heart rates synchronized", magnitude: state.heartRateSync)
            }
        }

        // Check for quantum entanglement (highest level of sync)
        if state.entrainmentLevel > SocialCoherenceConstants.entanglementThreshold {
            if events.filter({ $0.type == .groupEntanglement }).isEmpty {
                addEvent(.groupEntanglement, description: "Quantum entanglement achieved!", magnitude: state.entrainmentLevel)
            }
        }

        // Check for coherence spike
        if coherenceHistory.count > 10 {
            let recent = Array(coherenceHistory.suffix(5))
            let earlier = Array(coherenceHistory.dropLast(5).suffix(5))
            guard !recent.isEmpty, !earlier.isEmpty else { return }
            let recentAvg = recent.reduce(0, +) / Float(recent.count)
            let earlierAvg = earlier.reduce(0, +) / Float(earlier.count)

            if recentAvg - earlierAvg > 0.15 {
                addEvent(.coherenceSpike, description: "Coherence spike detected", magnitude: recentAvg)
            }
        }
    }

    private func addEvent(_ type: CoherenceEvent.EventType, description: String = "", participantId: UUID? = nil, magnitude: Float = 1.0) {
        let event = CoherenceEvent(type: type, description: description, participantId: participantId, magnitude: magnitude)
        events.append(event)

        // Keep last 100 events
        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }
    }

    // MARK: - Participant Management

    private func simulateParticipants(count: Int) {
        let names = ["Alex", "Jordan", "Sam", "Taylor", "Morgan", "Casey", "Riley", "Avery", "Quinn", "Sage"]

        for i in 0..<min(count, names.count) {
            let participant = SocialParticipant(
                displayName: names[i],
                role: i == 0 ? .facilitator : .participant
            )
            groupState.participants.append(participant)
        }
    }

    /// Add a participant to the session
    public func addParticipant(_ participant: SocialParticipant) {
        guard groupState.participants.count < configuration.maxParticipants else {
            log.social("SocialCoherenceEngine: Session full", level: .warning)
            return
        }

        groupState.participants.append(participant)
        addEvent(.participantJoined, description: "\(participant.displayName) joined", participantId: participant.id)
    }

    /// Remove a participant from the session
    public func removeParticipant(_ participantId: UUID) {
        if let participant = groupState.participants.first(where: { $0.id == participantId }) {
            addEvent(.participantLeft, description: "\(participant.displayName) left", participantId: participantId)
        }
        groupState.participants.removeAll { $0.id == participantId }
    }

    // MARK: - Guided Exercises

    /// Start a guided breathing exercise
    public func startGuidedBreathing(pattern: SessionConfiguration.GuidedExercise) {
        configuration.guidedExercise = pattern
        addEvent(.collectiveShift, description: "Started \(pattern.rawValue)")
    }

    /// Get current breath guidance phase
    public func getBreathGuidance() -> (phase: String, progress: Float) {
        guard configuration.breathGuidanceEnabled else {
            return ("", 0)
        }

        let cycleTime: TimeInterval
        switch configuration.guidedExercise {
        case .boxBreathing:
            cycleTime = 16.0  // 4 phases x 4 seconds
        case .coherenceBreathing:
            cycleTime = 10.0  // 5 in, 5 out
        default:
            cycleTime = 10.0
        }

        let progress = Float(fmod(sessionDuration, cycleTime) / cycleTime)
        let phase: String

        if progress < 0.25 {
            phase = "Inhale"
        } else if progress < 0.5 {
            phase = configuration.guidedExercise == .boxBreathing ? "Hold" : "Exhale"
        } else if progress < 0.75 {
            phase = configuration.guidedExercise == .boxBreathing ? "Exhale" : "Inhale"
        } else {
            phase = configuration.guidedExercise == .boxBreathing ? "Hold" : "Exhale"
        }

        return (phase, progress)
    }

    // MARK: - Analytics

    /// Get session statistics
    public func getSessionStats() -> SessionStats {
        SessionStats(
            duration: sessionDuration,
            peakCoherence: coherenceHistory.max() ?? 0,
            averageCoherence: coherenceHistory.isEmpty ? 0 : coherenceHistory.reduce(0, +) / Float(coherenceHistory.count),
            peakFlow: flowHistory.max() ?? 0,
            flowDuration: TimeInterval(flowHistory.filter { $0 > SocialCoherenceConstants.flowThreshold }.count) * SocialCoherenceConstants.updateInterval,
            participantCount: groupState.participantCount,
            eventCount: events.count,
            entanglementAchieved: events.contains { $0.type == .groupEntanglement }
        )
    }

    public struct SessionStats: Sendable {
        public var duration: TimeInterval
        public var peakCoherence: Float
        public var averageCoherence: Float
        public var peakFlow: Float
        public var flowDuration: TimeInterval
        public var participantCount: Int
        public var eventCount: Int
        public var entanglementAchieved: Bool
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift
