import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// SESSION MANAGEMENT SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete session lifecycle management:
// • Session discovery and browsing
// • Session creation and configuration
// • Participant management
// • Session persistence and history
// • Invitation system
// • Session analytics
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Session Types

/// Complete session information
public struct SessionInfo: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var description: String?
    public var hostId: String
    public var hostName: String
    public var createdAt: TimeInterval
    public var startedAt: TimeInterval?
    public var endedAt: TimeInterval?
    public var config: SessionConfiguration
    public var state: SessionState
    public var participantCount: Int
    public var maxParticipants: Int
    public var tags: [String]
    public var thumbnailURL: String?
    public var isPublic: Bool
    public var accessCode: String?

    public enum SessionState: String, Codable, Sendable {
        case draft = "draft"
        case scheduled = "scheduled"
        case waiting = "waiting"
        case active = "active"
        case paused = "paused"
        case ended = "ended"
        case archived = "archived"
    }
}

/// Session configuration
public struct SessionConfiguration: Codable, Sendable {
    public var mode: SessionMode
    public var syncOptions: SyncOptions
    public var bioOptions: BioOptions
    public var audioOptions: AudioOptions
    public var visualOptions: VisualOptions
    public var moderationOptions: ModerationOptions

    public enum SessionMode: String, Codable, Sendable {
        case freeform = "freeform"           // Everyone independent
        case guided = "guided"               // Host leads
        case collaborative = "collaborative"  // Shared control
        case entrainment = "entrainment"     // Bio-sync focused
        case performance = "performance"     // Audience mode
    }

    public struct SyncOptions: Codable, Sendable {
        public var enableRealTimeSync: Bool = true
        public var syncLatencyTarget: Float = 50    // ms
        public var enableBioSync: Bool = true
        public var enableAudioSync: Bool = true
        public var enableVisualSync: Bool = true
        public var enableParameterSync: Bool = true
    }

    public struct BioOptions: Codable, Sendable {
        public var shareHeartRate: Bool = true
        public var shareBreathing: Bool = true
        public var shareCoherence: Bool = true
        public var anonymizeBioData: Bool = false
        public var entrainmentTarget: Float = 6.0   // breaths/min
    }

    public struct AudioOptions: Codable, Sendable {
        public var enableVoiceChat: Bool = false
        public var enableMusicSync: Bool = true
        public var sharedPlayback: Bool = true
        public var allowParticipantAudio: Bool = false
    }

    public struct VisualOptions: Codable, Sendable {
        public var shareVisuals: Bool = true
        public var syncParticles: Bool = true
        public var syncColors: Bool = true
        public var allowParticipantVisuals: Bool = false
    }

    public struct ModerationOptions: Codable, Sendable {
        public var requireApproval: Bool = false
        public var allowChat: Bool = true
        public var allowReactions: Bool = true
        public var recordSession: Bool = false
    }

    public init() {
        mode = .collaborative
        syncOptions = SyncOptions()
        bioOptions = BioOptions()
        audioOptions = AudioOptions()
        visualOptions = VisualOptions()
        moderationOptions = ModerationOptions()
    }
}

/// Participant info
public struct ParticipantInfo: Codable, Identifiable, Sendable {
    public let id: String
    public var userId: String?
    public var displayName: String
    public var avatarURL: String?
    public var role: ParticipantRole
    public var joinedAt: TimeInterval
    public var leftAt: TimeInterval?
    public var status: ParticipantStatus
    public var permissions: ParticipantPermissions

    public enum ParticipantRole: String, Codable, Sendable {
        case host = "host"
        case coHost = "co_host"
        case moderator = "moderator"
        case participant = "participant"
        case observer = "observer"
    }

    public enum ParticipantStatus: String, Codable, Sendable {
        case pending = "pending"
        case connected = "connected"
        case away = "away"
        case disconnected = "disconnected"
    }

    public struct ParticipantPermissions: Codable, Sendable {
        public var canShareBio: Bool = true
        public var canShareAudio: Bool = false
        public var canShareVisuals: Bool = false
        public var canChat: Bool = true
        public var canReact: Bool = true
        public var canInvite: Bool = false
        public var canModerate: Bool = false
    }
}

/// Session invitation
public struct SessionInvitation: Codable, Identifiable, Sendable {
    public let id: String
    public var sessionId: String
    public var sessionName: String
    public var hostName: String
    public var inviterId: String
    public var inviterName: String
    public var recipientId: String?
    public var recipientEmail: String?
    public var createdAt: TimeInterval
    public var expiresAt: TimeInterval
    public var status: InvitationStatus
    public var accessCode: String?
    public var message: String?

    public enum InvitationStatus: String, Codable, Sendable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case expired = "expired"
        case revoked = "revoked"
    }
}

// MARK: - Session Manager

/// Central session management
public final class SessionManager: ObservableObject {

    public static let shared = SessionManager()

    // Published state
    @Published public private(set) var currentSession: SessionInfo?
    @Published public private(set) var availableSessions: [SessionInfo] = []
    @Published public private(set) var sessionHistory: [SessionInfo] = []
    @Published public private(set) var participants: [ParticipantInfo] = []
    @Published public private(set) var pendingInvitations: [SessionInvitation] = []

    // Callbacks
    public var onSessionCreated: ((SessionInfo) -> Void)?
    public var onSessionJoined: ((SessionInfo) -> Void)?
    public var onSessionLeft: ((SessionInfo) -> Void)?
    public var onParticipantJoined: ((ParticipantInfo) -> Void)?
    public var onParticipantLeft: ((ParticipantInfo) -> Void)?
    public var onInvitationReceived: ((SessionInvitation) -> Void)?

    // Configuration
    public var sessionDiscoveryEnabled: Bool = true
    public var autoReconnect: Bool = true

    // Internal
    private var localUserId: String = UUID().uuidString
    private var localUserName: String = "User"
    private var refreshTimer: Timer?
    private var sessionPersistence: SessionPersistence

    private init() {
        sessionPersistence = SessionPersistence()
        loadSessionHistory()
    }

    // MARK: - Session Discovery

    /// Start discovering available sessions
    public func startDiscovery() {
        guard sessionDiscoveryEnabled else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshAvailableSessions()
        }
        refreshAvailableSessions()
    }

    /// Stop session discovery
    public func stopDiscovery() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Refresh available sessions list
    public func refreshAvailableSessions() {
        // In real implementation, this would query the server
        // For now, filter active public sessions from local cache
        availableSessions = sessionHistory.filter { session in
            session.isPublic &&
            session.state == .active || session.state == .waiting
        }
    }

    /// Search sessions by criteria
    public func searchSessions(
        query: String? = nil,
        tags: [String]? = nil,
        mode: SessionConfiguration.SessionMode? = nil,
        hasSpace: Bool = true
    ) -> [SessionInfo] {
        return availableSessions.filter { session in
            // Text search
            if let q = query, !q.isEmpty {
                let searchText = "\(session.name) \(session.description ?? "") \(session.hostName)".lowercased()
                if !searchText.contains(q.lowercased()) { return false }
            }

            // Tag filter
            if let filterTags = tags, !filterTags.isEmpty {
                let hasMatchingTag = filterTags.contains { session.tags.contains($0) }
                if !hasMatchingTag { return false }
            }

            // Mode filter
            if let filterMode = mode {
                if session.config.mode != filterMode { return false }
            }

            // Space check
            if hasSpace && session.participantCount >= session.maxParticipants {
                return false
            }

            return true
        }
    }

    // MARK: - Session Creation

    /// Create a new session
    public func createSession(
        name: String,
        description: String? = nil,
        config: SessionConfiguration = SessionConfiguration(),
        maxParticipants: Int = 10,
        isPublic: Bool = true,
        tags: [String] = []
    ) -> SessionInfo {
        let session = SessionInfo(
            id: UUID().uuidString,
            name: name,
            description: description,
            hostId: localUserId,
            hostName: localUserName,
            createdAt: Date().timeIntervalSince1970,
            startedAt: nil,
            endedAt: nil,
            config: config,
            state: .waiting,
            participantCount: 1,
            maxParticipants: maxParticipants,
            tags: tags,
            thumbnailURL: nil,
            isPublic: isPublic,
            accessCode: isPublic ? nil : generateAccessCode()
        )

        currentSession = session

        // Add host as participant
        let hostParticipant = ParticipantInfo(
            id: localUserId,
            userId: localUserId,
            displayName: localUserName,
            avatarURL: nil,
            role: .host,
            joinedAt: Date().timeIntervalSince1970,
            leftAt: nil,
            status: .connected,
            permissions: ParticipantInfo.ParticipantPermissions(
                canShareBio: true,
                canShareAudio: true,
                canShareVisuals: true,
                canChat: true,
                canReact: true,
                canInvite: true,
                canModerate: true
            )
        )
        participants = [hostParticipant]

        // Save to history
        saveSessionToHistory(session)

        onSessionCreated?(session)

        return session
    }

    /// Create session from template
    public func createSessionFromTemplate(_ template: SessionTemplate) -> SessionInfo {
        return createSession(
            name: template.name,
            description: template.description,
            config: template.config,
            maxParticipants: template.defaultMaxParticipants,
            isPublic: template.defaultIsPublic,
            tags: template.defaultTags
        )
    }

    // MARK: - Session Joining

    /// Join a session by ID
    public func joinSession(
        sessionId: String,
        accessCode: String? = nil,
        displayName: String? = nil
    ) async throws -> SessionInfo {
        // Find session
        guard let session = availableSessions.first(where: { $0.id == sessionId }) ??
              sessionHistory.first(where: { $0.id == sessionId }) else {
            throw SessionError.sessionNotFound
        }

        // Check access code
        if let requiredCode = session.accessCode {
            guard accessCode == requiredCode else {
                throw SessionError.invalidAccessCode
            }
        }

        // Check capacity
        guard session.participantCount < session.maxParticipants else {
            throw SessionError.sessionFull
        }

        // Create participant
        let participant = ParticipantInfo(
            id: localUserId,
            userId: localUserId,
            displayName: displayName ?? localUserName,
            avatarURL: nil,
            role: .participant,
            joinedAt: Date().timeIntervalSince1970,
            leftAt: nil,
            status: .connected,
            permissions: ParticipantInfo.ParticipantPermissions()
        )

        var updatedSession = session
        updatedSession.participantCount += 1

        currentSession = updatedSession
        participants.append(participant)

        onSessionJoined?(updatedSession)

        return updatedSession
    }

    /// Join session via invitation
    public func acceptInvitation(_ invitation: SessionInvitation) async throws -> SessionInfo {
        guard invitation.status == .pending else {
            throw SessionError.invitationExpired
        }

        // Mark invitation as accepted
        updateInvitationStatus(invitation.id, status: .accepted)

        return try await joinSession(
            sessionId: invitation.sessionId,
            accessCode: invitation.accessCode
        )
    }

    /// Decline invitation
    public func declineInvitation(_ invitation: SessionInvitation) {
        updateInvitationStatus(invitation.id, status: .declined)
    }

    // MARK: - Session Control

    /// Start the session (host only)
    public func startSession() throws {
        guard var session = currentSession else {
            throw SessionError.noActiveSession
        }

        guard session.hostId == localUserId else {
            throw SessionError.notHost
        }

        session.state = .active
        session.startedAt = Date().timeIntervalSince1970
        currentSession = session

        saveSessionToHistory(session)
    }

    /// Pause session (host/moderator)
    public func pauseSession() throws {
        guard var session = currentSession else {
            throw SessionError.noActiveSession
        }

        guard canModerate() else {
            throw SessionError.insufficientPermissions
        }

        session.state = .paused
        currentSession = session
    }

    /// Resume session
    public func resumeSession() throws {
        guard var session = currentSession else {
            throw SessionError.noActiveSession
        }

        guard canModerate() else {
            throw SessionError.insufficientPermissions
        }

        session.state = .active
        currentSession = session
    }

    /// End session (host only)
    public func endSession() throws {
        guard var session = currentSession else {
            throw SessionError.noActiveSession
        }

        guard session.hostId == localUserId else {
            throw SessionError.notHost
        }

        session.state = .ended
        session.endedAt = Date().timeIntervalSince1970
        currentSession = nil

        saveSessionToHistory(session)
        onSessionLeft?(session)
    }

    /// Leave current session
    public func leaveSession() {
        guard let session = currentSession else { return }

        // Remove self from participants
        participants.removeAll { $0.id == localUserId }

        currentSession = nil
        onSessionLeft?(session)
    }

    // MARK: - Participant Management

    /// Get participant by ID
    public func getParticipant(_ id: String) -> ParticipantInfo? {
        return participants.first { $0.id == id }
    }

    /// Update participant role (host/moderator only)
    public func updateParticipantRole(
        participantId: String,
        newRole: ParticipantInfo.ParticipantRole
    ) throws {
        guard canModerate() else {
            throw SessionError.insufficientPermissions
        }

        guard let index = participants.firstIndex(where: { $0.id == participantId }) else {
            throw SessionError.participantNotFound
        }

        // Can't demote host
        guard participants[index].role != .host else {
            throw SessionError.cannotModifyHost
        }

        participants[index].role = newRole
        participants[index].permissions = permissionsForRole(newRole)
    }

    /// Remove participant (host/moderator only)
    public func removeParticipant(_ participantId: String) throws {
        guard canModerate() else {
            throw SessionError.insufficientPermissions
        }

        guard let index = participants.firstIndex(where: { $0.id == participantId }) else {
            throw SessionError.participantNotFound
        }

        // Can't remove host
        guard participants[index].role != .host else {
            throw SessionError.cannotModifyHost
        }

        let participant = participants.remove(at: index)
        onParticipantLeft?(participant)
    }

    /// Transfer host role
    public func transferHost(to participantId: String) throws {
        guard currentSession?.hostId == localUserId else {
            throw SessionError.notHost
        }

        guard let newHostIndex = participants.firstIndex(where: { $0.id == participantId }) else {
            throw SessionError.participantNotFound
        }

        guard let currentHostIndex = participants.firstIndex(where: { $0.id == localUserId }) else {
            return
        }

        // Update roles
        participants[currentHostIndex].role = .coHost
        participants[newHostIndex].role = .host

        // Update session
        currentSession?.hostId = participantId
    }

    // MARK: - Invitations

    /// Send invitation
    public func sendInvitation(
        recipientId: String? = nil,
        recipientEmail: String? = nil,
        message: String? = nil,
        expiresIn: TimeInterval = 86400  // 24 hours
    ) throws -> SessionInvitation {
        guard let session = currentSession else {
            throw SessionError.noActiveSession
        }

        guard canInvite() else {
            throw SessionError.insufficientPermissions
        }

        let invitation = SessionInvitation(
            id: UUID().uuidString,
            sessionId: session.id,
            sessionName: session.name,
            hostName: session.hostName,
            inviterId: localUserId,
            inviterName: localUserName,
            recipientId: recipientId,
            recipientEmail: recipientEmail,
            createdAt: Date().timeIntervalSince1970,
            expiresAt: Date().timeIntervalSince1970 + expiresIn,
            status: .pending,
            accessCode: session.accessCode,
            message: message
        )

        return invitation
    }

    /// Generate shareable invite link
    public func generateInviteLink() throws -> String {
        guard let session = currentSession else {
            throw SessionError.noActiveSession
        }

        var link = "echoelmusic://join/\(session.id)"
        if let code = session.accessCode {
            link += "?code=\(code)"
        }

        return link
    }

    // MARK: - Session History

    /// Get recent sessions
    public func getRecentSessions(limit: Int = 10) -> [SessionInfo] {
        return Array(sessionHistory.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    /// Get sessions hosted by user
    public func getHostedSessions() -> [SessionInfo] {
        return sessionHistory.filter { $0.hostId == localUserId }
    }

    /// Get sessions participated in
    public func getParticipatedSessions() -> [SessionInfo] {
        return sessionHistory.filter { $0.hostId != localUserId }
    }

    /// Clear session history
    public func clearHistory() {
        sessionHistory.removeAll()
        sessionPersistence.clearAll()
    }

    // MARK: - Analytics

    /// Get session statistics
    public func getSessionStats(_ sessionId: String) -> SessionStats? {
        guard let session = sessionHistory.first(where: { $0.id == sessionId }) else {
            return nil
        }

        let duration: TimeInterval
        if let start = session.startedAt, let end = session.endedAt {
            duration = end - start
        } else if let start = session.startedAt {
            duration = Date().timeIntervalSince1970 - start
        } else {
            duration = 0
        }

        return SessionStats(
            sessionId: sessionId,
            duration: duration,
            peakParticipants: session.maxParticipants,
            totalParticipants: session.participantCount,
            mode: session.config.mode,
            wasPublic: session.isPublic
        )
    }

    public struct SessionStats: Codable {
        public let sessionId: String
        public let duration: TimeInterval
        public let peakParticipants: Int
        public let totalParticipants: Int
        public let mode: SessionConfiguration.SessionMode
        public let wasPublic: Bool
    }

    // MARK: - Private Helpers

    private func canModerate() -> Bool {
        guard let participant = participants.first(where: { $0.id == localUserId }) else {
            return false
        }
        return participant.role == .host ||
               participant.role == .coHost ||
               participant.role == .moderator ||
               participant.permissions.canModerate
    }

    private func canInvite() -> Bool {
        guard let participant = participants.first(where: { $0.id == localUserId }) else {
            return false
        }
        return participant.permissions.canInvite
    }

    private func permissionsForRole(_ role: ParticipantInfo.ParticipantRole) -> ParticipantInfo.ParticipantPermissions {
        switch role {
        case .host:
            return ParticipantInfo.ParticipantPermissions(
                canShareBio: true,
                canShareAudio: true,
                canShareVisuals: true,
                canChat: true,
                canReact: true,
                canInvite: true,
                canModerate: true
            )
        case .coHost:
            return ParticipantInfo.ParticipantPermissions(
                canShareBio: true,
                canShareAudio: true,
                canShareVisuals: true,
                canChat: true,
                canReact: true,
                canInvite: true,
                canModerate: true
            )
        case .moderator:
            return ParticipantInfo.ParticipantPermissions(
                canShareBio: true,
                canShareAudio: false,
                canShareVisuals: false,
                canChat: true,
                canReact: true,
                canInvite: true,
                canModerate: true
            )
        case .participant:
            return ParticipantInfo.ParticipantPermissions(
                canShareBio: true,
                canShareAudio: false,
                canShareVisuals: false,
                canChat: true,
                canReact: true,
                canInvite: false,
                canModerate: false
            )
        case .observer:
            return ParticipantInfo.ParticipantPermissions(
                canShareBio: false,
                canShareAudio: false,
                canShareVisuals: false,
                canChat: false,
                canReact: true,
                canInvite: false,
                canModerate: false
            )
        }
    }

    private func generateAccessCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    private func updateInvitationStatus(_ id: String, status: SessionInvitation.InvitationStatus) {
        if let index = pendingInvitations.firstIndex(where: { $0.id == id }) {
            pendingInvitations[index].status = status
            if status != .pending {
                pendingInvitations.remove(at: index)
            }
        }
    }

    private func saveSessionToHistory(_ session: SessionInfo) {
        if let index = sessionHistory.firstIndex(where: { $0.id == session.id }) {
            sessionHistory[index] = session
        } else {
            sessionHistory.append(session)
        }
        sessionPersistence.save(sessionHistory)
    }

    private func loadSessionHistory() {
        sessionHistory = sessionPersistence.load()
    }
}

// MARK: - Session Templates

/// Predefined session templates
public struct SessionTemplate: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let config: SessionConfiguration
    public let defaultMaxParticipants: Int
    public let defaultIsPublic: Bool
    public let defaultTags: [String]
    public let icon: String

    public static let templates: [SessionTemplate] = [
        SessionTemplate(
            id: "meditation",
            name: "Group Meditation",
            description: "Guided meditation with bio-sync for deep relaxation",
            config: {
                var config = SessionConfiguration()
                config.mode = .entrainment
                config.bioOptions.entrainmentTarget = 5.0
                config.audioOptions.enableVoiceChat = false
                config.audioOptions.sharedPlayback = true
                return config
            }(),
            defaultMaxParticipants: 20,
            defaultIsPublic: true,
            defaultTags: ["meditation", "relaxation", "bio-sync"],
            icon: "leaf.fill"
        ),
        SessionTemplate(
            id: "breathwork",
            name: "Breathwork Session",
            description: "Synchronized breathing exercises with entrainment guidance",
            config: {
                var config = SessionConfiguration()
                config.mode = .guided
                config.bioOptions.entrainmentTarget = 6.0
                config.bioOptions.shareBreathing = true
                return config
            }(),
            defaultMaxParticipants: 30,
            defaultIsPublic: true,
            defaultTags: ["breathwork", "coherence", "wellness"],
            icon: "wind"
        ),
        SessionTemplate(
            id: "jam",
            name: "Music Jam",
            description: "Collaborative music creation with shared audio/visual",
            config: {
                var config = SessionConfiguration()
                config.mode = .collaborative
                config.audioOptions.enableMusicSync = true
                config.audioOptions.allowParticipantAudio = true
                config.visualOptions.allowParticipantVisuals = true
                return config
            }(),
            defaultMaxParticipants: 8,
            defaultIsPublic: false,
            defaultTags: ["music", "creative", "collaborative"],
            icon: "music.note.list"
        ),
        SessionTemplate(
            id: "performance",
            name: "Live Performance",
            description: "Host performs for audience with bio-reactive visuals",
            config: {
                var config = SessionConfiguration()
                config.mode = .performance
                config.audioOptions.sharedPlayback = true
                config.visualOptions.shareVisuals = true
                config.visualOptions.allowParticipantVisuals = false
                return config
            }(),
            defaultMaxParticipants: 100,
            defaultIsPublic: true,
            defaultTags: ["performance", "live", "audience"],
            icon: "star.fill"
        ),
        SessionTemplate(
            id: "freeform",
            name: "Freeform Hangout",
            description: "Casual session with independent exploration",
            config: {
                var config = SessionConfiguration()
                config.mode = .freeform
                config.syncOptions.enableRealTimeSync = false
                config.moderationOptions.allowChat = true
                return config
            }(),
            defaultMaxParticipants: 15,
            defaultIsPublic: true,
            defaultTags: ["casual", "social", "explore"],
            icon: "person.3.fill"
        )
    ]
}

// MARK: - Session Errors

public enum SessionError: Error, LocalizedError {
    case sessionNotFound
    case invalidAccessCode
    case sessionFull
    case noActiveSession
    case notHost
    case insufficientPermissions
    case participantNotFound
    case cannotModifyHost
    case invitationExpired

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound: return "Session not found"
        case .invalidAccessCode: return "Invalid access code"
        case .sessionFull: return "Session is full"
        case .noActiveSession: return "No active session"
        case .notHost: return "Only the host can perform this action"
        case .insufficientPermissions: return "Insufficient permissions"
        case .participantNotFound: return "Participant not found"
        case .cannotModifyHost: return "Cannot modify host"
        case .invitationExpired: return "Invitation has expired"
        }
    }
}

// MARK: - Session Persistence

/// Handles session history persistence
final class SessionPersistence {

    private let fileManager = FileManager.default
    private let fileName = "session_history.json"

    private var filePath: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    func save(_ sessions: [SessionInfo]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: filePath)
        } catch {
            print("Failed to save session history: \(error)")
        }
    }

    func load() -> [SessionInfo] {
        do {
            let data = try Data(contentsOf: filePath)
            return try JSONDecoder().decode([SessionInfo].self, from: data)
        } catch {
            return []
        }
    }

    func clearAll() {
        try? fileManager.removeItem(at: filePath)
    }
}

// MARK: - Session Notifications

extension Notification.Name {
    static let sessionCreated = Notification.Name("com.echoelmusic.sessionCreated")
    static let sessionJoined = Notification.Name("com.echoelmusic.sessionJoined")
    static let sessionLeft = Notification.Name("com.echoelmusic.sessionLeft")
    static let sessionEnded = Notification.Name("com.echoelmusic.sessionEnded")
    static let participantJoined = Notification.Name("com.echoelmusic.participantJoined")
    static let participantLeft = Notification.Name("com.echoelmusic.participantLeft")
    static let invitationReceived = Notification.Name("com.echoelmusic.invitationReceived")
}
