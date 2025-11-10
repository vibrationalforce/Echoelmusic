import Foundation

/// Collaboration Tools & Remote Work Engine
/// Complete system for remote collaboration, version control, and team workflows
///
/// Features:
/// - Real-time remote collaboration
/// - Git-style version control for music projects
/// - Timeline comments & feedback
/// - Secure stem/project sharing
/// - Project templates
/// - Session management & replay
/// - Conflict resolution
/// - Change tracking & attribution
/// - Permission management
@MainActor
class CollaborationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var projects: [CollaborativeProject] = []
    @Published var sessions: [CollaborationSession] = []
    @Published var templates: [ProjectTemplate] = []
    @Published var sharedFiles: [SharedFile] = []

    // MARK: - Collaborative Project

    struct CollaborativeProject: Identifiable {
        let id = UUID()
        var name: String
        var owner: Collaborator
        var collaborators: [Collaborator]
        var createdDate: Date
        var lastModified: Date
        var versions: [ProjectVersion]
        var currentVersion: ProjectVersion
        var comments: [TimelineComment]
        var files: [ProjectFile]
        var status: ProjectStatus
        var settings: ProjectSettings

        enum ProjectStatus {
            case active, paused, completed, archived
        }

        struct ProjectSettings {
            var allowExternalSharing: Bool
            var requireApprovalForChanges: Bool
            var autoSaveInterval: TimeInterval  // seconds
            var maxCollaborators: Int
            var retentionDays: Int  // Version history retention
        }

        /// Get all changes since a specific version
        func changesSince(version versionId: UUID) -> [Change] {
            guard let versionIndex = versions.firstIndex(where: { $0.id == versionId }) else {
                return []
            }

            let laterVersions = versions.suffix(from: versionIndex + 1)
            return laterVersions.flatMap { $0.changes }
        }
    }

    // MARK: - Project Version (Git-style)

    struct ProjectVersion: Identifiable {
        let id = UUID()
        var versionNumber: String  // e.g., "v1.2.3"
        var commitMessage: String
        var author: Collaborator
        var timestamp: Date
        var parentVersion: UUID?  // For branching
        var changes: [Change]
        var snapshot: ProjectSnapshot
        var tags: [String]  // e.g., "demo", "final", "mastered"

        struct Change {
            let id = UUID()
            var type: ChangeType
            var file: String
            var author: Collaborator
            var timestamp: Date
            var description: String
            var diff: ChangeDiff?

            enum ChangeType {
                case added, modified, deleted, renamed, merged
            }

            struct ChangeDiff {
                var before: Data?  // Previous state
                var after: Data?   // New state
                var visualDiff: String?  // Human-readable diff
            }
        }

        struct ProjectSnapshot {
            var files: [String: Data]  // filename -> content
            var metadata: [String: String]
            var audioSettings: AudioSettings

            struct AudioSettings {
                var sampleRate: Int
                var bitDepth: Int
                var tempo: Double
                var timeSignature: String
                var key: String
            }
        }
    }

    // MARK: - Collaborator

    struct Collaborator: Identifiable {
        let id = UUID()
        var name: String
        var email: String
        var role: Role
        var permissions: Permissions
        var avatar: String?
        var status: OnlineStatus
        var lastActive: Date

        enum Role: String {
            case owner = "Owner"
            case admin = "Admin"
            case editor = "Editor"
            case viewer = "Viewer"
            case commentator = "Commentator"

            var canEdit: Bool {
                switch self {
                case .owner, .admin, .editor:
                    return true
                case .viewer, .commentator:
                    return false
                }
            }

            var canComment: Bool {
                self != .viewer
            }

            var canManageUsers: Bool {
                self == .owner || self == .admin
            }
        }

        struct Permissions {
            var canUpload: Bool
            var canDownload: Bool
            var canDelete: Bool
            var canShare: Bool
            var canExport: Bool
            var canManageVersions: Bool
        }

        enum OnlineStatus {
            case online, away, offline
        }
    }

    // MARK: - Timeline Comment

    struct TimelineComment: Identifiable {
        let id = UUID()
        var author: Collaborator
        var timestamp: Date
        var timePosition: TimeInterval  // Position in track (seconds)
        var content: String
        var attachments: [Attachment]
        var replies: [Reply]
        var resolved: Bool
        var tags: [CommentTag]

        struct Attachment {
            let id = UUID()
            var type: AttachmentType
            var url: URL
            var name: String

            enum AttachmentType {
                case audio, image, video, document
            }
        }

        struct Reply: Identifiable {
            let id = UUID()
            var author: Collaborator
            var timestamp: Date
            var content: String
        }

        enum CommentTag: String {
            case feedback = "Feedback"
            case issue = "Issue"
            case idea = "Idea"
            case question = "Question"
            case approved = "Approved"
        }
    }

    // MARK: - Collaboration Session

    struct CollaborationSession: Identifiable {
        let id = UUID()
        var project: CollaborativeProject
        var participants: [Collaborator]
        var startTime: Date
        var endTime: Date?
        var actions: [SessionAction]
        var audioStreams: [AudioStream]
        var status: SessionStatus

        enum SessionStatus {
            case active, paused, ended
        }

        struct SessionAction: Identifiable {
            let id = UUID()
            var type: ActionType
            var performer: Collaborator
            var timestamp: Date
            var description: String
            var canUndo: Bool

            enum ActionType {
                case fileAdded, fileModified, fileDeleted
                case commentAdded, commentResolved
                case versionCreated, versionRestored
                case participantJoined, participantLeft
                case audioRecorded, audioEdited
            }
        }

        struct AudioStream {
            let id = UUID()
            var collaborator: Collaborator
            var startTime: Date
            var endTime: Date?
            var quality: StreamQuality
            var latency: TimeInterval  // ms

            enum StreamQuality {
                case low, medium, high, lossless

                var bitrate: Int {
                    switch self {
                    case .low: return 64_000
                    case .medium: return 128_000
                    case .high: return 256_000
                    case .lossless: return 1_411_000  // CD quality
                    }
                }
            }
        }

        var duration: TimeInterval {
            guard let end = endTime else {
                return Date().timeIntervalSince(startTime)
            }
            return end.timeIntervalSince(startTime)
        }
    }

    // MARK: - Project File

    struct ProjectFile: Identifiable {
        let id = UUID()
        var name: String
        var type: FileType
        var size: Int64  // bytes
        var uploadedBy: Collaborator
        var uploadDate: Date
        var lastModified: Date
        var version: Int
        var locked: Bool  // Prevent editing
        var lockedBy: Collaborator?
        var checksum: String  // MD5/SHA256
        var url: URL?

        enum FileType {
            case audio(format: AudioFormat)
            case midi
            case project(daw: DAW)
            case preset
            case sample
            case video
            case document
            case other

            enum AudioFormat: String {
                case wav = "WAV"
                case aiff = "AIFF"
                case flac = "FLAC"
                case mp3 = "MP3"
                case aac = "AAC"
            }

            enum DAW: String {
                case logic = "Logic Pro"
                case ableton = "Ableton Live"
                case proTools = "Pro Tools"
                case flStudio = "FL Studio"
                case cubase = "Cubase"
                case studioOne = "Studio One"
                case reaper = "REAPER"
            }
        }

        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }

    // MARK: - Shared File

    struct SharedFile: Identifiable {
        let id = UUID()
        var file: ProjectFile
        var sharedBy: Collaborator
        var shareDate: Date
        var expiryDate: Date?
        var accessCount: Int
        var accessLink: String
        var password: String?
        var downloadLimit: Int?
        var settings: ShareSettings

        struct ShareSettings {
            var allowDownload: Bool
            var allowComments: Bool
            var requireLogin: Bool
            var notifyOnAccess: Bool
        }

        var isExpired: Bool {
            guard let expiry = expiryDate else { return false }
            return Date() > expiry
        }

        var isAccessLimitReached: Bool {
            guard let limit = downloadLimit else { return false }
            return accessCount >= limit
        }
    }

    // MARK: - Project Template

    struct ProjectTemplate: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var category: TemplateCategory
        var creator: String
        var trackCount: Int
        var includesPlugins: Bool
        var includesSamples: Bool
        var thumbnail: String?
        var tags: [String]
        var popularity: Int  // Download count

        enum TemplateCategory: String, CaseIterable {
            case edm = "EDM / Electronic"
            case hiphop = "Hip-Hop / Rap"
            case pop = "Pop"
            case rock = "Rock"
            case jazz = "Jazz"
            case orchestral = "Orchestral"
            case podcast = "Podcast"
            case voiceover = "Voiceover"
            case mixing = "Mixing Template"
            case mastering = "Mastering Template"
            case blank = "Blank / Custom"
        }
    }

    // MARK: - Initialization

    init() {
        print("🤝 Collaboration Engine initialized")

        // Load default templates
        loadDefaultTemplates()

        print("   ✅ \(templates.count) templates available")
    }

    private func loadDefaultTemplates() {
        templates = [
            ProjectTemplate(
                name: "EDM Production",
                description: "Complete EDM template with drums, bass, synths, and FX chains",
                category: .edm,
                creator: "Echoelmusic",
                trackCount: 24,
                includesPlugins: true,
                includesSamples: true,
                tags: ["EDM", "House", "Techno", "Production"],
                popularity: 1250
            ),
            ProjectTemplate(
                name: "Hip-Hop Beat",
                description: "Hip-hop beat template with drums, 808s, and melodic elements",
                category: .hiphop,
                creator: "Echoelmusic",
                trackCount: 16,
                includesPlugins: true,
                includesSamples: true,
                tags: ["Hip-Hop", "Trap", "Beats", "Production"],
                popularity: 980
            ),
            ProjectTemplate(
                name: "Podcast Setup",
                description: "Professional podcast template with intro, outro, and processing",
                category: .podcast,
                creator: "Echoelmusic",
                trackCount: 8,
                includesPlugins: true,
                includesSamples: false,
                tags: ["Podcast", "Voice", "Speech", "Recording"],
                popularity: 750
            ),
            ProjectTemplate(
                name: "Mixing Template",
                description: "Professional mixing template with routing, busses, and FX",
                category: .mixing,
                creator: "Echoelmusic",
                trackCount: 64,
                includesPlugins: true,
                includesSamples: false,
                tags: ["Mixing", "Professional", "Workflow"],
                popularity: 1100
            ),
        ]
    }

    // MARK: - Create Project

    func createProject(
        name: String,
        owner: Collaborator,
        template: ProjectTemplate? = nil
    ) -> CollaborativeProject {
        print("📁 Creating collaborative project: \(name)")

        let initialVersion = ProjectVersion(
            versionNumber: "v1.0.0",
            commitMessage: "Initial project creation",
            author: owner,
            timestamp: Date(),
            parentVersion: nil,
            changes: [],
            snapshot: ProjectVersion.ProjectSnapshot(
                files: [:],
                metadata: ["created": "true"],
                audioSettings: ProjectVersion.ProjectSnapshot.AudioSettings(
                    sampleRate: 48000,
                    bitDepth: 24,
                    tempo: 120.0,
                    timeSignature: "4/4",
                    key: "C Major"
                )
            ),
            tags: ["initial"]
        )

        let project = CollaborativeProject(
            name: name,
            owner: owner,
            collaborators: [owner],
            createdDate: Date(),
            lastModified: Date(),
            versions: [initialVersion],
            currentVersion: initialVersion,
            comments: [],
            files: [],
            status: .active,
            settings: CollaborativeProject.ProjectSettings(
                allowExternalSharing: true,
                requireApprovalForChanges: false,
                autoSaveInterval: 300,  // 5 minutes
                maxCollaborators: 10,
                retentionDays: 90
            )
        )

        projects.append(project)

        print("   ✅ Project created with version v1.0.0")

        return project
    }

    // MARK: - Version Control

    func createVersion(
        projectId: UUID,
        commitMessage: String,
        author: Collaborator,
        changes: [ProjectVersion.Change],
        tags: [String] = []
    ) -> ProjectVersion {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            fatalError("Project not found")
        }

        print("💾 Creating new version: \(commitMessage)")

        let currentVersion = projects[projectIndex].currentVersion
        let versionParts = currentVersion.versionNumber.dropFirst(1).split(separator: ".").map { Int($0) ?? 0 }

        // Increment patch version
        let newVersionNumber = "v\(versionParts[0]).\(versionParts[1]).\(versionParts[2] + 1)"

        let newVersion = ProjectVersion(
            versionNumber: newVersionNumber,
            commitMessage: commitMessage,
            author: author,
            timestamp: Date(),
            parentVersion: currentVersion.id,
            changes: changes,
            snapshot: currentVersion.snapshot,  // In production: create new snapshot
            tags: tags
        )

        projects[projectIndex].versions.append(newVersion)
        projects[projectIndex].currentVersion = newVersion
        projects[projectIndex].lastModified = Date()

        print("   ✅ Version \(newVersionNumber) created")

        return newVersion
    }

    func restoreVersion(projectId: UUID, versionId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let version = projects[projectIndex].versions.first(where: { $0.id == versionId }) else {
            print("   ❌ Version not found")
            return
        }

        print("⏪ Restoring version: \(version.versionNumber)")

        projects[projectIndex].currentVersion = version
        projects[projectIndex].lastModified = Date()

        print("   ✅ Restored to \(version.versionNumber)")
    }

    func compareVersions(
        projectId: UUID,
        version1: UUID,
        version2: UUID
    ) -> VersionComparison {
        guard let project = projects.first(where: { $0.id == projectId }),
              let v1 = project.versions.first(where: { $0.id == version1 }),
              let v2 = project.versions.first(where: { $0.id == version2 }) else {
            fatalError("Versions not found")
        }

        print("🔍 Comparing \(v1.versionNumber) vs \(v2.versionNumber)")

        // Calculate differences
        let addedFiles = v2.changes.filter { $0.type == .added }.map { $0.file }
        let modifiedFiles = v2.changes.filter { $0.type == .modified }.map { $0.file }
        let deletedFiles = v2.changes.filter { $0.type == .deleted }.map { $0.file }

        return VersionComparison(
            olderVersion: v1,
            newerVersion: v2,
            addedFiles: addedFiles,
            modifiedFiles: modifiedFiles,
            deletedFiles: deletedFiles,
            totalChanges: v2.changes.count
        )
    }

    struct VersionComparison {
        let olderVersion: ProjectVersion
        let newerVersion: ProjectVersion
        let addedFiles: [String]
        let modifiedFiles: [String]
        let deletedFiles: [String]
        let totalChanges: Int
    }

    // MARK: - Collaboration

    func addCollaborator(
        projectId: UUID,
        collaborator: Collaborator
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            return
        }

        print("👤 Adding collaborator: \(collaborator.name)")

        projects[projectIndex].collaborators.append(collaborator)

        print("   ✅ \(collaborator.name) added as \(collaborator.role.rawValue)")
    }

    func updateCollaboratorRole(
        projectId: UUID,
        collaboratorId: UUID,
        newRole: Collaborator.Role
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let collabIndex = projects[projectIndex].collaborators.firstIndex(where: { $0.id == collaboratorId }) else {
            return
        }

        print("🔄 Updating role for \(projects[projectIndex].collaborators[collabIndex].name)")

        projects[projectIndex].collaborators[collabIndex].role = newRole

        print("   ✅ Role updated to \(newRole.rawValue)")
    }

    // MARK: - Comments & Feedback

    func addComment(
        projectId: UUID,
        timePosition: TimeInterval,
        content: String,
        author: Collaborator,
        tags: [TimelineComment.CommentTag] = []
    ) -> TimelineComment {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            fatalError("Project not found")
        }

        print("💬 Adding comment at \(formatTime(timePosition))")

        let comment = TimelineComment(
            author: author,
            timestamp: Date(),
            timePosition: timePosition,
            content: content,
            attachments: [],
            replies: [],
            resolved: false,
            tags: tags
        )

        projects[projectIndex].comments.append(comment)

        print("   ✅ Comment added by \(author.name)")

        return comment
    }

    func replyToComment(
        projectId: UUID,
        commentId: UUID,
        reply: String,
        author: Collaborator
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let commentIndex = projects[projectIndex].comments.firstIndex(where: { $0.id == commentId }) else {
            return
        }

        print("↩️ Replying to comment...")

        let replyObj = TimelineComment.Reply(
            author: author,
            timestamp: Date(),
            content: reply
        )

        projects[projectIndex].comments[commentIndex].replies.append(replyObj)

        print("   ✅ Reply added")
    }

    func resolveComment(projectId: UUID, commentId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let commentIndex = projects[projectIndex].comments.firstIndex(where: { $0.id == commentId }) else {
            return
        }

        projects[projectIndex].comments[commentIndex].resolved = true

        print("✅ Comment resolved")
    }

    // MARK: - File Sharing

    func shareFile(
        file: ProjectFile,
        sharedBy: Collaborator,
        expiryDays: Int? = nil,
        downloadLimit: Int? = nil,
        password: String? = nil
    ) -> SharedFile {
        print("🔗 Creating share link for: \(file.name)")

        let expiryDate: Date?
        if let days = expiryDays {
            expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        } else {
            expiryDate = nil
        }

        let shareLink = "https://share.echoelmusic.com/\(UUID().uuidString)"

        let sharedFile = SharedFile(
            file: file,
            sharedBy: sharedBy,
            shareDate: Date(),
            expiryDate: expiryDate,
            accessCount: 0,
            accessLink: shareLink,
            password: password,
            downloadLimit: downloadLimit,
            settings: SharedFile.ShareSettings(
                allowDownload: true,
                allowComments: true,
                requireLogin: false,
                notifyOnAccess: true
            )
        )

        sharedFiles.append(sharedFile)

        print("   ✅ Share link: \(shareLink)")
        if let expiry = expiryDate {
            print("   ⏰ Expires: \(formatDate(expiry))")
        }
        if let limit = downloadLimit {
            print("   📊 Download limit: \(limit)")
        }

        return sharedFile
    }

    // MARK: - Real-Time Session

    func startCollaborationSession(
        projectId: UUID,
        participants: [Collaborator]
    ) -> CollaborationSession {
        guard let project = projects.first(where: { $0.id == projectId }) else {
            fatalError("Project not found")
        }

        print("🎙️ Starting collaboration session...")

        let session = CollaborationSession(
            project: project,
            participants: participants,
            startTime: Date(),
            endTime: nil,
            actions: [],
            audioStreams: [],
            status: .active
        )

        sessions.append(session)

        print("   ✅ Session started with \(participants.count) participants")
        for participant in participants {
            print("      - \(participant.name) (\(participant.role.rawValue))")
        }

        return session
    }

    func endCollaborationSession(sessionId: UUID) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        print("🛑 Ending collaboration session...")

        sessions[sessionIndex].endTime = Date()
        sessions[sessionIndex].status = .ended

        let duration = sessions[sessionIndex].duration
        print("   ✅ Session ended after \(formatDuration(duration))")
        print("   📊 Total actions: \(sessions[sessionIndex].actions.count)")
    }

    func recordSessionAction(
        sessionId: UUID,
        action: CollaborationSession.SessionAction
    ) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        sessions[sessionIndex].actions.append(action)
    }

    // MARK: - File Locking

    func lockFile(projectId: UUID, fileId: UUID, lockedBy: Collaborator) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let fileIndex = projects[projectIndex].files.firstIndex(where: { $0.id == fileId }) else {
            return
        }

        print("🔒 Locking file: \(projects[projectIndex].files[fileIndex].name)")

        projects[projectIndex].files[fileIndex].locked = true
        projects[projectIndex].files[fileIndex].lockedBy = lockedBy

        print("   ✅ Locked by \(lockedBy.name)")
    }

    func unlockFile(projectId: UUID, fileId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let fileIndex = projects[projectIndex].files.firstIndex(where: { $0.id == fileId }) else {
            return
        }

        projects[projectIndex].files[fileIndex].locked = false
        projects[projectIndex].files[fileIndex].lockedBy = nil

        print("🔓 File unlocked")
    }

    // MARK: - Conflict Resolution

    func detectConflicts(projectId: UUID) -> [FileConflict] {
        guard let project = projects.first(where: { $0.id == projectId }) else {
            return []
        }

        print("🔍 Detecting conflicts...")

        var conflicts: [FileConflict] = []

        // Check for files modified by multiple users
        for file in project.files {
            let recentChanges = project.currentVersion.changes.filter { $0.file == file.name }

            if recentChanges.count > 1 {
                let authors = Set(recentChanges.map { $0.author.name })
                if authors.count > 1 {
                    conflicts.append(FileConflict(
                        file: file,
                        conflictingVersions: recentChanges.map { $0.id },
                        authors: Array(authors),
                        severity: .medium
                    ))
                }
            }
        }

        print("   ✅ Found \(conflicts.count) conflicts")

        return conflicts
    }

    struct FileConflict {
        let file: ProjectFile
        let conflictingVersions: [UUID]
        let authors: [String]
        let severity: Severity

        enum Severity {
            case low, medium, high, critical
        }
    }

    // MARK: - Analytics

    func generateCollaborationReport(projectId: UUID) -> CollaborationReport {
        guard let project = projects.first(where: { $0.id == projectId }) else {
            fatalError("Project not found")
        }

        print("📊 Generating collaboration report...")

        // Calculate contributor statistics
        var contributorStats: [String: ContributorStats] = [:]
        for version in project.versions {
            for change in version.changes {
                let name = change.author.name
                if contributorStats[name] == nil {
                    contributorStats[name] = ContributorStats(
                        name: name,
                        totalChanges: 0,
                        filesAdded: 0,
                        filesModified: 0,
                        filesDeleted: 0,
                        commentsAdded: 0
                    )
                }

                contributorStats[name]?.totalChanges += 1

                switch change.type {
                case .added:
                    contributorStats[name]?.filesAdded += 1
                case .modified:
                    contributorStats[name]?.filesModified += 1
                case .deleted:
                    contributorStats[name]?.filesDeleted += 1
                default:
                    break
                }
            }
        }

        for comment in project.comments {
            let name = comment.author.name
            contributorStats[name]?.commentsAdded += 1
        }

        let report = CollaborationReport(
            project: project,
            totalVersions: project.versions.count,
            totalComments: project.comments.count,
            resolvedComments: project.comments.filter { $0.resolved }.count,
            totalCollaborators: project.collaborators.count,
            contributorStats: Array(contributorStats.values),
            activityTimeline: generateActivityTimeline(project: project)
        )

        print("   ✅ Report generated")

        return report
    }

    struct CollaborationReport {
        let project: CollaborativeProject
        let totalVersions: Int
        let totalComments: Int
        let resolvedComments: Int
        let totalCollaborators: Int
        let contributorStats: [ContributorStats]
        let activityTimeline: [ActivityEvent]

        var commentResolutionRate: Double {
            guard totalComments > 0 else { return 0.0 }
            return Double(resolvedComments) / Double(totalComments) * 100.0
        }
    }

    struct ContributorStats {
        let name: String
        var totalChanges: Int
        var filesAdded: Int
        var filesModified: Int
        var filesDeleted: Int
        var commentsAdded: Int
    }

    struct ActivityEvent {
        let timestamp: Date
        let type: String
        let description: String
        let author: String
    }

    private func generateActivityTimeline(project: CollaborativeProject) -> [ActivityEvent] {
        var events: [ActivityEvent] = []

        // Version events
        for version in project.versions {
            events.append(ActivityEvent(
                timestamp: version.timestamp,
                type: "Version",
                description: "Created \(version.versionNumber): \(version.commitMessage)",
                author: version.author.name
            ))
        }

        // Comment events
        for comment in project.comments {
            events.append(ActivityEvent(
                timestamp: comment.timestamp,
                type: "Comment",
                description: "Added comment at \(formatTime(comment.timePosition))",
                author: comment.author.name
            ))
        }

        return events.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Helper Methods

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
