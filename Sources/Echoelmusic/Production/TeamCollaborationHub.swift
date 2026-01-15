import Foundation
import Combine

// MARK: - Team Collaboration Hub

/// Real-time collaboration system for distributed teams
/// Supports async and sync workflows with built-in wellness features
@MainActor
class TeamCollaborationHub: ObservableObject {

    private let log = ProfessionalLogger.shared

    // MARK: - Singleton

    static let shared = TeamCollaborationHub()

    // MARK: - Published State

    @Published private(set) var activeSessions: [CollaborationSession] = []
    @Published private(set) var pendingInvitations: [CollaborationInvitation] = []
    @Published private(set) var recentActivity: [ActivityItem] = []
    @Published private(set) var onlineMembers: [UUID] = []

    // MARK: - Communication

    @Published var unreadMessages: Int = 0
    @Published var activeVoiceChannel: VoiceChannel?

    // MARK: - Wellness

    @Published private(set) var teamWellnessScore: Double = 0.8
    @Published private(set) var wellnessAlerts: [WellnessNotification] = []

    // MARK: - Initialization

    private init() {
        startWellnessMonitoring()
        log.info(category: .social, "✅ TeamCollaborationHub: Initialized")
    }

    // MARK: - Session Management

    func createSession(
        name: String,
        type: SessionType,
        participants: [UUID],
        projectId: UUID? = nil
    ) -> CollaborationSession {
        let session = CollaborationSession(
            name: name,
            type: type,
            hostId: UUID(), // Current user
            participantIds: participants,
            projectId: projectId
        )

        activeSessions.append(session)

        // Send invitations
        for participantId in participants {
            sendInvitation(sessionId: session.id, to: participantId)
        }

        logActivity(.sessionCreated(session.name))

        return session
    }

    func joinSession(_ sessionId: UUID) -> Bool {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            return false
        }

        // Mark as joined
        activeSessions[index].joinedParticipants.append(UUID()) // Current user

        logActivity(.joinedSession(activeSessions[index].name))

        return true
    }

    func leaveSession(_ sessionId: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        activeSessions[index].joinedParticipants.removeAll { $0 == UUID() } // Current user

        logActivity(.leftSession(activeSessions[index].name))
    }

    func endSession(_ sessionId: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        var session = activeSessions[index]
        session.endedAt = Date()
        session.status = .ended

        activeSessions[index] = session

        logActivity(.sessionEnded(session.name))
    }

    // MARK: - Invitations

    private func sendInvitation(sessionId: UUID, to userId: UUID) {
        let invitation = CollaborationInvitation(
            sessionId: sessionId,
            fromUserId: UUID(), // Current user
            toUserId: userId
        )

        pendingInvitations.append(invitation)
    }

    func acceptInvitation(_ invitationId: UUID) {
        guard let index = pendingInvitations.firstIndex(where: { $0.id == invitationId }) else {
            return
        }

        let invitation = pendingInvitations.remove(at: index)
        _ = joinSession(invitation.sessionId)
    }

    func declineInvitation(_ invitationId: UUID) {
        pendingInvitations.removeAll { $0.id == invitationId }
    }

    // MARK: - Real-Time Features

    func shareScreen(in sessionId: UUID) {
        logActivity(.startedScreenShare)
    }

    func stopScreenShare(in sessionId: UUID) {
        logActivity(.stoppedScreenShare)
    }

    func shareAudio(in sessionId: UUID) {
        logActivity(.startedAudioShare)
    }

    func shareBioData(in sessionId: UUID, coherence: Double, heartRate: Double) {
        // Share real-time bio-data with session participants
        logActivity(.sharedBioData)
    }

    // MARK: - Voice Communication

    func joinVoiceChannel(_ channelId: UUID) {
        activeVoiceChannel = VoiceChannel(
            id: channelId,
            name: "Session Voice",
            participants: []
        )
        logActivity(.joinedVoiceChannel)
    }

    func leaveVoiceChannel() {
        activeVoiceChannel = nil
        logActivity(.leftVoiceChannel)
    }

    func muteAudio() {
        // Mute local audio
    }

    func unmuteAudio() {
        // Unmute local audio
    }

    // MARK: - Async Collaboration

    func createReviewRequest(
        projectId: UUID,
        title: String,
        description: String,
        reviewers: [UUID],
        deadline: Date?
    ) -> ReviewRequest {
        let request = ReviewRequest(
            projectId: projectId,
            title: title,
            description: description,
            requesterId: UUID(),
            reviewerIds: reviewers,
            deadline: deadline
        )

        logActivity(.createdReviewRequest(title))

        return request
    }

    func submitReview(
        requestId: UUID,
        feedback: String,
        approval: ReviewApproval,
        suggestions: [String]
    ) -> Review {
        let review = Review(
            requestId: requestId,
            reviewerId: UUID(),
            feedback: feedback,
            approval: approval,
            suggestions: suggestions
        )

        logActivity(.submittedReview)

        return review
    }

    // MARK: - File Sharing

    func shareFile(_ fileId: UUID, with sessionId: UUID) -> SharedFile {
        let file = SharedFile(
            originalId: fileId,
            sharedBy: UUID(),
            sessionId: sessionId
        )

        logActivity(.sharedFile)

        return file
    }

    func requestFileAccess(_ fileId: UUID, from ownerId: UUID) {
        logActivity(.requestedFileAccess)
    }

    // MARK: - Comments & Annotations

    func addComment(
        to targetId: UUID,
        targetType: CommentTargetType,
        content: String,
        timestamp: TimeInterval? = nil
    ) -> Comment {
        let comment = Comment(
            targetId: targetId,
            targetType: targetType,
            authorId: UUID(),
            content: content,
            timestamp: timestamp
        )

        logActivity(.addedComment)

        return comment
    }

    func resolveComment(_ commentId: UUID) {
        logActivity(.resolvedComment)
    }

    // MARK: - Wellness Monitoring

    private func startWellnessMonitoring() {
        // Monitor team wellness metrics
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTeamWellness()
            }
        }
    }

    private func checkTeamWellness() {
        // Check for overwork
        let workHoursToday = calculateTeamWorkHours()

        if workHoursToday > 8 {
            wellnessAlerts.append(WellnessNotification(
                type: .overwork,
                message: "Team has been working for \(Int(workHoursToday)) hours today. Consider wrapping up.",
                severity: workHoursToday > 10 ? .high : .medium
            ))
        }

        // Check for break reminders
        let timeSinceLastBreak = calculateTimeSinceLastBreak()
        if timeSinceLastBreak > 7200 { // 2 hours
            wellnessAlerts.append(WellnessNotification(
                type: .breakReminder,
                message: "It's been 2+ hours since your last break. Time to stretch!",
                severity: .low
            ))
        }

        // Update team wellness score
        updateTeamWellnessScore()
    }

    private func calculateTeamWorkHours() -> Double {
        // Placeholder - would calculate from activity logs
        return 6.5
    }

    private func calculateTimeSinceLastBreak() -> TimeInterval {
        // Placeholder
        return 5400 // 1.5 hours
    }

    private func updateTeamWellnessScore() {
        // Calculate based on various factors
        let workloadBalance = 0.8
        let breakCompliance = 0.7
        let collaborationQuality = 0.9
        let communicationHealth = 0.85

        teamWellnessScore = (workloadBalance + breakCompliance + collaborationQuality + communicationHealth) / 4
    }

    func dismissWellnessAlert(_ alertId: UUID) {
        wellnessAlerts.removeAll { $0.id == alertId }
    }

    func takeBreak(duration: TimeInterval) {
        logActivity(.tookBreak(Int(duration / 60)))

        // Schedule return reminder
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.wellnessAlerts.append(WellnessNotification(
                type: .breakComplete,
                message: "Break time is over. Ready to continue?",
                severity: .low
            ))
        }
    }

    // MARK: - Activity Logging

    private func logActivity(_ type: ActivityType) {
        let item = ActivityItem(
            type: type,
            userId: UUID()
        )

        recentActivity.insert(item, at: 0)

        // Keep only last 100 items
        if recentActivity.count > 100 {
            recentActivity.removeLast()
        }
    }

    // MARK: - Notifications

    func subscribeToUpdates(for sessionId: UUID, handler: @escaping (SessionUpdate) -> Void) -> AnyCancellable {
        // Return cancellable subscription
        return Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Check for updates
            }
    }
}

// MARK: - Types

struct CollaborationSession: Identifiable {
    let id = UUID()
    var name: String
    var type: SessionType
    var hostId: UUID
    var participantIds: [UUID]
    var joinedParticipants: [UUID] = []
    var projectId: UUID?
    var status: SessionStatus = .active
    var createdAt: Date = Date()
    var endedAt: Date?

    // Real-time state
    var sharedScreen: UUID?
    var sharedAudio: Bool = false
    var sharedBioData: Bool = false

    enum SessionStatus: String {
        case pending
        case active
        case paused
        case ended
    }
}

enum SessionType: String, CaseIterable {
    case coCreation = "Co-Creation"
    case review = "Review"
    case brainstorm = "Brainstorm"
    case feedback = "Feedback"
    case meditation = "Group Meditation"
    case performance = "Live Performance"
    case learning = "Learning Session"

    var maxParticipants: Int {
        switch self {
        case .coCreation: return 4
        case .review: return 10
        case .brainstorm: return 20
        case .feedback: return 5
        case .meditation: return 100
        case .performance: return 1000
        case .learning: return 50
        }
    }
}

struct CollaborationInvitation: Identifiable {
    let id = UUID()
    var sessionId: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var status: InvitationStatus = .pending
    var sentAt: Date = Date()
    var expiresAt: Date?

    enum InvitationStatus: String {
        case pending
        case accepted
        case declined
        case expired
    }
}

struct VoiceChannel: Identifiable {
    let id: UUID
    var name: String
    var participants: [UUID]
    var isMuted: Bool = false
    var isDeafened: Bool = false
}

// MARK: - Review System

struct ReviewRequest: Identifiable {
    let id = UUID()
    var projectId: UUID
    var title: String
    var description: String
    var requesterId: UUID
    var reviewerIds: [UUID]
    var status: ReviewStatus = .pending
    var deadline: Date?
    var createdAt: Date = Date()

    enum ReviewStatus: String {
        case pending
        case inProgress
        case completed
        case cancelled
    }
}

struct Review: Identifiable {
    let id = UUID()
    var requestId: UUID
    var reviewerId: UUID
    var feedback: String
    var approval: ReviewApproval
    var suggestions: [String]
    var submittedAt: Date = Date()
}

enum ReviewApproval: String {
    case approved = "Approved"
    case approvedWithChanges = "Approved with Changes"
    case changesRequested = "Changes Requested"
    case rejected = "Rejected"
}

// MARK: - File Sharing

struct SharedFile: Identifiable {
    let id = UUID()
    var originalId: UUID
    var sharedBy: UUID
    var sessionId: UUID
    var sharedAt: Date = Date()
    var accessPermissions: [UUID: FilePermission] = [:]

    enum FilePermission: String {
        case view
        case comment
        case edit
        case admin
    }
}

// MARK: - Comments

struct Comment: Identifiable {
    let id = UUID()
    var targetId: UUID
    var targetType: CommentTargetType
    var authorId: UUID
    var content: String
    var timestamp: TimeInterval?  // For time-based comments on audio/video
    var createdAt: Date = Date()
    var isResolved: Bool = false
    var replies: [Comment] = []
}

enum CommentTargetType: String {
    case project
    case session
    case file
    case track
    case timepoint
}

// MARK: - Activity

struct ActivityItem: Identifiable {
    let id = UUID()
    var type: ActivityType
    var userId: UUID
    var timestamp: Date = Date()
}

enum ActivityType {
    case sessionCreated(String)
    case joinedSession(String)
    case leftSession(String)
    case sessionEnded(String)
    case startedScreenShare
    case stoppedScreenShare
    case startedAudioShare
    case sharedBioData
    case joinedVoiceChannel
    case leftVoiceChannel
    case createdReviewRequest(String)
    case submittedReview
    case sharedFile
    case requestedFileAccess
    case addedComment
    case resolvedComment
    case tookBreak(Int)

    var description: String {
        switch self {
        case .sessionCreated(let name): return "Created session '\(name)'"
        case .joinedSession(let name): return "Joined session '\(name)'"
        case .leftSession(let name): return "Left session '\(name)'"
        case .sessionEnded(let name): return "Ended session '\(name)'"
        case .startedScreenShare: return "Started screen sharing"
        case .stoppedScreenShare: return "Stopped screen sharing"
        case .startedAudioShare: return "Started audio sharing"
        case .sharedBioData: return "Shared bio-data"
        case .joinedVoiceChannel: return "Joined voice channel"
        case .leftVoiceChannel: return "Left voice channel"
        case .createdReviewRequest(let title): return "Created review request '\(title)'"
        case .submittedReview: return "Submitted review"
        case .sharedFile: return "Shared a file"
        case .requestedFileAccess: return "Requested file access"
        case .addedComment: return "Added a comment"
        case .resolvedComment: return "Resolved a comment"
        case .tookBreak(let minutes): return "Took a \(minutes)-minute break"
        }
    }
}

// MARK: - Wellness

struct WellnessNotification: Identifiable {
    let id = UUID()
    var type: WellnessType
    var message: String
    var severity: Severity
    var createdAt: Date = Date()
    var isDismissed: Bool = false

    enum WellnessType: String {
        case overwork = "Overwork Warning"
        case breakReminder = "Break Reminder"
        case breakComplete = "Break Complete"
        case ergonomics = "Ergonomics Reminder"
        case hydration = "Hydration Reminder"
        case eyeStrain = "Eye Strain Alert"
    }

    enum Severity: String {
        case low, medium, high
    }
}

// MARK: - Session Updates

enum SessionUpdate {
    case participantJoined(UUID)
    case participantLeft(UUID)
    case screenShareStarted(UUID)
    case screenShareStopped
    case audioShareStarted(UUID)
    case bioDataUpdated(UUID, Double, Double)  // userId, coherence, heartRate
    case commentAdded(Comment)
    case fileShared(SharedFile)
    case sessionEnded
}

// MARK: - Team Analytics

extension TeamCollaborationHub {

    func getCollaborationMetrics(for period: DateInterval) -> CollaborationMetrics {
        let sessionsInPeriod = activeSessions.filter {
            period.contains($0.createdAt)
        }

        return CollaborationMetrics(
            totalSessions: sessionsInPeriod.count,
            totalParticipants: Set(sessionsInPeriod.flatMap { $0.participantIds }).count,
            averageSessionDuration: calculateAverageSessionDuration(sessionsInPeriod),
            mostActiveHours: calculateMostActiveHours(),
            collaborationScore: calculateCollaborationScore(sessionsInPeriod),
            wellnessCompliance: teamWellnessScore
        )
    }

    private func calculateAverageSessionDuration(_ sessions: [CollaborationSession]) -> TimeInterval {
        let durations = sessions.compactMap { session -> TimeInterval? in
            guard let end = session.endedAt else { return nil }
            return end.timeIntervalSince(session.createdAt)
        }

        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private func calculateMostActiveHours() -> [Int] {
        // Analyze recentActivity timestamps to find most active hours
        var hourCounts = [Int: Int]()

        for activity in recentActivity {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: activity.timestamp)
            hourCounts[hour, default: 0] += 1
        }

        // Sort hours by activity count and return top 5
        let sortedHours = hourCounts.sorted { $0.value > $1.value }
        let topHours = sortedHours.prefix(5).map { $0.key }.sorted()

        // If no activity data, return typical work hours
        return topHours.isEmpty ? [10, 11, 14, 15, 16] : topHours
    }

    private func calculateCollaborationScore(_ sessions: [CollaborationSession]) -> Double {
        // Calculate collaboration score based on multiple factors
        guard !sessions.isEmpty else { return 0.0 }

        var totalScore: Double = 0.0

        for session in sessions {
            var sessionScore: Double = 0.0

            // Factor 1: Participation rate (joined vs invited)
            let invitedCount = Double(session.participantIds.count)
            let joinedCount = Double(session.joinedParticipants.count)
            if invitedCount > 0 {
                sessionScore += (joinedCount / invitedCount) * 0.3
            }

            // Factor 2: Session completion (ended properly vs abandoned)
            if session.endedAt != nil && session.status == .ended {
                sessionScore += 0.25
            }

            // Factor 3: Duration quality (optimal is 30-90 minutes)
            if let endTime = session.endedAt {
                let durationMinutes = endTime.timeIntervalSince(session.createdAt) / 60.0
                if durationMinutes >= 30 && durationMinutes <= 90 {
                    sessionScore += 0.25  // Optimal duration
                } else if durationMinutes > 10 && durationMinutes < 120 {
                    sessionScore += 0.15  // Acceptable duration
                } else {
                    sessionScore += 0.05  // Too short or too long
                }
            }

            // Factor 4: Multi-participant sessions are more valuable
            if session.joinedParticipants.count >= 3 {
                sessionScore += 0.2
            } else if session.joinedParticipants.count >= 2 {
                sessionScore += 0.1
            }

            totalScore += sessionScore
        }

        // Average score across sessions, normalized to 0-1
        return min(totalScore / Double(sessions.count), 1.0)
    }
}

struct CollaborationMetrics {
    var totalSessions: Int
    var totalParticipants: Int
    var averageSessionDuration: TimeInterval
    var mostActiveHours: [Int]
    var collaborationScore: Double
    var wellnessCompliance: Double

    var formattedDuration: String {
        let hours = Int(averageSessionDuration) / 3600
        let minutes = (Int(averageSessionDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
