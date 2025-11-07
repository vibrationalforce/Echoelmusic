import TVServices
import Foundation

/// Top Shelf content provider for Apple TV
///
/// **Purpose:** Showcase Echoelmusic content when app is featured on TV home screen
///
/// **Content Types:**
/// - Recent sessions with statistics
/// - Active session in progress
/// - Quick actions (Start HRV, Start breathing)
/// - Achievements and milestones
/// - Group session invitations
///
/// **Layout Styles:**
/// - **Sectioned:** Multiple rows of content (default)
/// - **Inset:** Single featured item with actions
///
/// **Platform:** tvOS 15.0+
///
class TopShelfContentProvider: TVTopShelfContentProvider {

    // MARK: - Top Shelf Content

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        // Check if there's an active session
        if let activeSession = getActiveSession() {
            // Show active session
            let content = createActiveSessionContent(activeSession)
            completionHandler(content)
        } else if let recentSessions = getRecentSessions(), !recentSessions.isEmpty {
            // Show recent sessions + quick actions
            let content = createSectionedContent(recentSessions: recentSessions)
            completionHandler(content)
        } else {
            // Show quick actions only (first launch)
            let content = createQuickActionsContent()
            completionHandler(content)
        }
    }

    // MARK: - Active Session Content

    private func createActiveSessionContent(_ session: ActiveSession) -> TVTopShelfContent {
        let content = TVTopShelfInsetContent()

        // Title
        content.title = "Session in Progress"

        // Background image (optional)
        if let imageURL = getSessionBackgroundImageURL(for: session.type) {
            content.backgroundImageURL = imageURL
        }

        // Actions
        var actions: [TVTopShelfAction] = []

        // Resume action
        let resumeAction = TVTopShelfAction(title: "Resume Session")
        resumeAction.url = URL(string: "echoelmusic://resume-session?id=\(session.id)")!
        actions.append(resumeAction)

        // End action
        let endAction = TVTopShelfAction(title: "End Session")
        endAction.url = URL(string: "echoelmusic://end-session?id=\(session.id)")!
        actions.append(endAction)

        content.actions = actions

        // Display name
        content.displayName = session.type.displayName

        return content
    }

    // MARK: - Sectioned Content

    private func createSectionedContent(recentSessions: [RecentSession]) -> TVTopShelfContent {
        let content = TVTopShelfSectionedContent()

        var sections: [TVTopShelfItemCollection] = []

        // Section 1: Quick Actions
        sections.append(createQuickActionsSection())

        // Section 2: Recent Sessions
        sections.append(createRecentSessionsSection(recentSessions))

        // Section 3: Achievements (if any)
        if let achievementsSection = createAchievementsSection() {
            sections.append(achievementsSection)
        }

        content.sections = sections

        return content
    }

    // MARK: - Quick Actions Section

    private func createQuickActionsSection() -> TVTopShelfItemCollection {
        let section = TVTopShelfItemCollection(items: [])
        section.title = "Quick Actions"

        var items: [TVTopShelfItem] = []

        // HRV Monitoring
        let hrvItem = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "action-hrv", container: nil)!)
        hrvItem.title = "HRV Monitoring"
        hrvItem.imageShape = .square
        hrvItem.displayAction = createAction(url: "echoelmusic://start-hrv")
        hrvItem.imageURL = getQuickActionImageURL(for: "hrv")
        items.append(hrvItem)

        // Breathing Exercise
        let breathingItem = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "action-breathing", container: nil)!)
        breathingItem.title = "Breathing Exercise"
        breathingItem.imageShape = .square
        breathingItem.displayAction = createAction(url: "echoelmusic://start-breathing")
        breathingItem.imageURL = getQuickActionImageURL(for: "breathing")
        items.append(breathingItem)

        // Coherence Training
        let coherenceItem = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "action-coherence", container: nil)!)
        coherenceItem.title = "Coherence Training"
        coherenceItem.imageShape = .square
        coherenceItem.displayAction = createAction(url: "echoelmusic://start-coherence")
        coherenceItem.imageURL = getQuickActionImageURL(for: "coherence")
        items.append(coherenceItem)

        // Group Session
        let groupItem = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "action-group", container: nil)!)
        groupItem.title = "Group Session"
        groupItem.imageShape = .square
        groupItem.displayAction = createAction(url: "echoelmusic://start-group")
        groupItem.imageURL = getQuickActionImageURL(for: "group")
        items.append(groupItem)

        section.items = items

        return section
    }

    // MARK: - Recent Sessions Section

    private func createRecentSessionsSection(_ sessions: [RecentSession]) -> TVTopShelfItemCollection {
        let section = TVTopShelfItemCollection(items: [])
        section.title = "Recent Sessions"

        var items: [TVTopShelfItem] = []

        for session in sessions.prefix(5) {
            let item = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "session-\(session.id)", container: nil)!)

            // Title with date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            item.title = dateFormatter.string(from: session.startTime)

            // Subtitle with stats
            item.summary = String(format: "HRV: %.1f ms • Coherence: %.0f%%", session.averageHRV, session.averageCoherence)

            // Image
            item.imageShape = .poster
            item.imageURL = getSessionImageURL(for: session)

            // Action
            item.displayAction = createAction(url: "echoelmusic://view-session?id=\(session.id)")

            items.append(item)
        }

        section.items = items

        return section
    }

    // MARK: - Achievements Section

    private func createAchievementsSection() -> TVTopShelfItemCollection? {
        guard let achievements = getRecentAchievements(), !achievements.isEmpty else {
            return nil
        }

        let section = TVTopShelfItemCollection(items: [])
        section.title = "Achievements"

        var items: [TVTopShelfItem] = []

        for achievement in achievements.prefix(3) {
            let item = TVTopShelfItem(contentIdentifier: TVContentIdentifier(identifier: "achievement-\(achievement.id)", container: nil)!)

            item.title = achievement.title
            item.summary = achievement.description
            item.imageShape = .square
            item.imageURL = getAchievementImageURL(for: achievement)
            item.displayAction = createAction(url: "echoelmusic://achievements")

            items.append(item)
        }

        section.items = items

        return section
    }

    // MARK: - Quick Actions Only Content

    private func createQuickActionsContent() -> TVTopShelfContent {
        let content = TVTopShelfSectionedContent()
        content.sections = [createQuickActionsSection()]
        return content
    }

    // MARK: - Helper Methods

    private func createAction(url urlString: String) -> TVTopShelfAction? {
        guard let url = URL(string: urlString) else { return nil }
        return TVTopShelfAction(title: "", url: url)
    }

    // MARK: - Data Fetching (from App Groups)

    private let sharedDefaults = UserDefaults(suiteName: "group.com.echoelmusic.shared")

    private func getActiveSession() -> ActiveSession? {
        guard let defaults = sharedDefaults,
              let sessionID = defaults.string(forKey: "activeSessionID"),
              let sessionTypeString = defaults.string(forKey: "activeSessionType"),
              let sessionType = SessionType(rawValue: sessionTypeString) else {
            return nil
        }

        return ActiveSession(id: sessionID, type: sessionType)
    }

    private func getRecentSessions() -> [RecentSession]? {
        guard let defaults = sharedDefaults,
              let sessionsData = defaults.array(forKey: "sessions") as? [[String: Any]] else {
            return nil
        }

        return sessionsData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let startTimeInterval = dict["startTime"] as? TimeInterval,
                  let averageHRV = dict["averageHRV"] as? Double,
                  let averageCoherence = dict["averageCoherence"] as? Double else {
                return nil
            }

            return RecentSession(
                id: id,
                startTime: Date(timeIntervalSince1970: startTimeInterval),
                averageHRV: averageHRV,
                averageCoherence: averageCoherence
            )
        }
    }

    private func getRecentAchievements() -> [Achievement]? {
        // TODO: Implement achievements system
        return nil
    }

    // MARK: - Image URLs

    private func getSessionBackgroundImageURL(for type: SessionType) -> URL? {
        // Return URL to bundled asset or generated image
        return nil
    }

    private func getQuickActionImageURL(for action: String) -> URL? {
        // Return URL to bundled icon
        return nil
    }

    private func getSessionImageURL(for session: RecentSession) -> URL? {
        // Generate or return cached session preview image
        return nil
    }

    private func getAchievementImageURL(for achievement: Achievement) -> URL? {
        // Return achievement badge image
        return nil
    }
}

// MARK: - Supporting Types

struct ActiveSession {
    let id: String
    let type: SessionType
}

struct RecentSession {
    let id: String
    let startTime: Date
    let averageHRV: Double
    let averageCoherence: Double
}

struct Achievement {
    let id: String
    let title: String
    let description: String
    let imageURL: URL?
}

enum SessionType: String {
    case hrvMonitoring = "hrv"
    case breathing = "breathing"
    case coherence = "coherence"
    case group = "group"

    var displayName: String {
        switch self {
        case .hrvMonitoring:
            return "HRV Monitoring"
        case .breathing:
            return "Breathing Exercise"
        case .coherence:
            return "Coherence Training"
        case .group:
            return "Group Session"
        }
    }
}
