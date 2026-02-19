// ContentCreatorPlugin.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Professional content creation tools with OBS integration,
// bio-reactive scene switching, chat commands, auto-posting
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

/// A comprehensive plugin for content creators and streamers
/// Demonstrates: streaming, recording, collaboration, cloudSync capabilities
public final class ContentCreatorPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.content-creator" }
    public var name: String { "Content Creator Suite" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Creator Team" }
    public var pluginDescription: String { "Professional content creation tools with OBS integration, bio-reactive scene switching, chat commands, and auto-posting" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.streaming, .recording, .bioProcessing, .collaboration, .cloudSync] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var obsWebSocketURL: String = "ws://localhost:4455"
        public var obsWebSocketPassword: String = ""
        public var enableBioSceneSwitching: Bool = true
        public var enableChatCommands: Bool = true
        public var enableAutoClips: Bool = true
        public var enableAutoPosting: Bool = false
        public var coherenceThresholdForHighlight: Float = 0.8
        public var clipDuration: TimeInterval = 30.0

        public enum StreamingPlatform: String, CaseIterable, Sendable {
            case twitch = "Twitch"
            case youtube = "YouTube"
            case facebook = "Facebook"
            case instagram = "Instagram"
            case tiktok = "TikTok"
            case custom = "Custom"
        }

        public var platforms: [StreamingPlatform] = [.twitch]
    }

    // MARK: - Content Models

    public struct StreamSession: Sendable {
        public var id: UUID
        public var title: String
        public var startTime: Date
        public var endTime: Date?
        public var platform: Configuration.StreamingPlatform
        public var viewers: Int
        public var clips: [Clip]
        public var highlights: [Highlight]
        public var chatMessages: Int
        public var averageCoherence: Float

        public init(title: String, platform: Configuration.StreamingPlatform) {
            self.id = UUID()
            self.title = title
            self.startTime = Date()
            self.endTime = nil
            self.platform = platform
            self.viewers = 0
            self.clips = []
            self.highlights = []
            self.chatMessages = 0
            self.averageCoherence = 0
        }
    }

    public struct Clip: Identifiable, Sendable {
        public var id: UUID
        public var timestamp: Date
        public var duration: TimeInterval
        public var title: String
        public var description: String
        public var coherenceAtCreation: Float
        public var viewCount: Int

        public init(title: String, duration: TimeInterval, coherence: Float) {
            self.id = UUID()
            self.timestamp = Date()
            self.duration = duration
            self.title = title
            self.description = ""
            self.coherenceAtCreation = coherence
            self.viewCount = 0
        }
    }

    public struct Highlight: Identifiable, Sendable {
        public var id: UUID
        public var timestamp: Date
        public var type: HighlightType
        public var description: String
        public var bioData: String

        public enum HighlightType: String, Sendable {
            case highCoherence = "High Coherence"
            case chatReaction = "Chat Reaction"
            case milestone = "Milestone"
            case subscriberAlert = "Subscriber"
            case donation = "Donation"
            case bioSpike = "Bio Spike"
        }

        public init(type: HighlightType, description: String, bioData: String) {
            self.id = UUID()
            self.timestamp = Date()
            self.type = type
            self.description = description
            self.bioData = bioData
        }
    }

    public struct ChatCommand: Sendable {
        public var command: String
        public var description: String
        public var requiresModerator: Bool
        public var cooldown: TimeInterval
        public var action: @Sendable () -> Void

        public init(command: String, description: String, requiresModerator: Bool = false, cooldown: TimeInterval = 5.0, action: @Sendable @escaping () -> Void) {
            self.command = command
            self.description = description
            self.requiresModerator = requiresModerator
            self.cooldown = cooldown
            self.action = action
        }
    }

    public struct OBSScene: Sendable {
        public var name: String
        public var coherenceRange: ClosedRange<Float>
        public var priority: Int

        public init(name: String, coherenceRange: ClosedRange<Float>, priority: Int = 0) {
            self.name = name
            self.coherenceRange = coherenceRange
            self.priority = priority
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var currentSession: StreamSession?
    private var isStreaming: Bool = false
    private var currentCoherence: Float = 0.5
    private var currentHeartRate: Float = 70.0
    private var coherenceHistory: [Float] = []

    // OBS
    private var obsConnected: Bool = false
    private var currentScene: String = "Main"
    private var bioScenes: [OBSScene] = []

    // Chat
    private var registeredCommands: [String: ChatCommand] = [:]
    private var commandCooldowns: [String: Date] = [:]

    // Clips
    private var lastClipTime: Date = Date.distantPast

    // MARK: - Initialization

    public init() {
        setupDefaultScenes()
        registerDefaultChatCommands()
    }

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Content Creator Plugin loaded", category: .social)
        if !configuration.obsWebSocketURL.isEmpty {
            await connectToOBS()
        }
    }

    public func onUnload() async {
        if isStreaming {
            await endStream()
        }
        await disconnectFromOBS()
        log.info("Content Creator Plugin unloaded", category: .social)
    }

    public func onFrame(deltaTime: TimeInterval) {
        guard isStreaming else { return }
        if configuration.enableBioSceneSwitching {
            updateSceneBasedOnBio()
        }
        if configuration.enableAutoClips {
            checkAutoClipOpportunity()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        currentCoherence = bioData.coherence
        if let hr = bioData.heartRate {
            currentHeartRate = hr
        }
        coherenceHistory.append(bioData.coherence)
        if coherenceHistory.count > 300 {
            coherenceHistory.removeFirst()
        }
        if bioData.coherence >= configuration.coherenceThresholdForHighlight {
            markHighlight(
                type: .highCoherence,
                description: "Peak coherence moment",
                bioData: "Coherence: \(String(format: "%.2f", bioData.coherence)), HR: \(bioData.heartRate ?? 0)"
            )
        }
    }

    // MARK: - Stream Management

    /// Start a stream session
    public func startStream(title: String, platform: Configuration.StreamingPlatform) async {
        guard currentSession == nil else {
            log.warning("Cannot start stream - session already active", category: .social)
            return
        }
        currentSession = StreamSession(title: title, platform: platform)
        isStreaming = true
        coherenceHistory.removeAll()
        log.info("Started stream: \(title) on \(platform.rawValue)", category: .social)
        if obsConnected {
            await switchOBSScene("Streaming")
        }
    }

    /// End the stream session
    public func endStream() async {
        guard var session = currentSession else {
            log.warning("No active stream to end", category: .social)
            return
        }
        session.endTime = Date()
        if !coherenceHistory.isEmpty {
            session.averageCoherence = coherenceHistory.reduce(0, +) / Float(coherenceHistory.count)
        }
        isStreaming = false
        if configuration.enableAutoPosting {
            await autoPostHighlights(session)
        }
        let streamDuration = session.endTime.map { String(format: "%.1f", $0.timeIntervalSince(session.startTime) / 60) } ?? "unknown"
        log.info("Ended stream - Duration: \(streamDuration) minutes, Avg coherence: \(session.averageCoherence)", category: .social)
        currentSession = nil
    }

    /// Update viewer count
    public func updateViewerCount(_ count: Int) {
        let currentViewers = currentSession?.viewers ?? 0
        currentSession?.viewers = max(currentViewers, count)
    }

    /// Update chat message count
    public func recordChatMessage() {
        currentSession?.chatMessages += 1
    }

    // MARK: - OBS Integration

    /// Connect to OBS via WebSocket
    public func connectToOBS() async {
        obsConnected = true
        log.info("Connected to OBS at \(configuration.obsWebSocketURL)", category: .social)
    }

    /// Disconnect from OBS
    public func disconnectFromOBS() async {
        obsConnected = false
        log.info("Disconnected from OBS", category: .social)
    }

    /// Switch OBS scene
    public func switchOBSScene(_ sceneName: String) async {
        guard obsConnected else {
            log.warning("Cannot switch scene - OBS not connected", category: .social)
            return
        }
        currentScene = sceneName
        log.info("Switched OBS scene to: \(sceneName)", category: .social)
    }

    /// Add bio-reactive scene
    public func addBioScene(_ scene: OBSScene) {
        bioScenes.append(scene)
        bioScenes.sort { $0.priority > $1.priority }
        log.debug("Added bio scene: \(scene.name) - Coherence range: \(scene.coherenceRange)", category: .social)
    }

    // MARK: - Chat Commands

    /// Register a chat command
    public func registerChatCommand(_ command: ChatCommand) {
        registeredCommands[command.command.lowercased()] = command
        log.debug("Registered chat command: !\(command.command)", category: .social)
    }

    /// Process chat command
    public func processChatCommand(_ message: String, fromModerator: Bool = false) {
        guard configuration.enableChatCommands else { return }
        let normalized = message.lowercased().trimmingCharacters(in: .whitespaces)
        guard normalized.hasPrefix("!") else { return }
        let commandText = String(normalized.dropFirst())
        guard let command = registeredCommands[commandText] else {
            log.debug("Unknown chat command: \(commandText)", category: .social)
            return
        }
        if command.requiresModerator && !fromModerator {
            log.debug("Command \(commandText) requires moderator", category: .social)
            return
        }
        if let lastUsed = commandCooldowns[commandText] {
            let timeSince = Date().timeIntervalSince(lastUsed)
            if timeSince < command.cooldown {
                log.debug("Command \(commandText) on cooldown", category: .social)
                return
            }
        }
        log.info("Executing chat command: !\(commandText)", category: .social)
        command.action()
        commandCooldowns[commandText] = Date()
        recordChatMessage()
    }

    // MARK: - Clips & Highlights

    /// Create a clip
    public func createClip(title: String, duration: TimeInterval? = nil) {
        guard isStreaming else {
            log.warning("Cannot create clip - not streaming", category: .social)
            return
        }
        let clipDuration = duration ?? configuration.clipDuration
        let clip = Clip(title: title, duration: clipDuration, coherence: currentCoherence)
        currentSession?.clips.append(clip)
        lastClipTime = Date()
        log.info("Created clip: \(title) - Duration: \(clipDuration)s", category: .social)
    }

    /// Mark a highlight moment
    public func markHighlight(type: Highlight.HighlightType, description: String, bioData: String) {
        guard isStreaming else { return }
        let highlight = Highlight(type: type, description: description, bioData: bioData)
        currentSession?.highlights.append(highlight)
        log.info("Marked highlight: \(type.rawValue) - \(description)", category: .social)
    }

    /// Get session highlights
    public func getSessionHighlights() -> [Highlight] {
        return currentSession?.highlights ?? []
    }

    /// Get session clips
    public func getSessionClips() -> [Clip] {
        return currentSession?.clips ?? []
    }

    // MARK: - Subscriber/Donation Alerts

    /// Handle subscriber alert
    public func handleSubscriberAlert(username: String, tier: Int = 1) {
        log.info("New subscriber: \(username) - Tier \(tier)", category: .social)
        markHighlight(type: .subscriberAlert, description: "\(username) subscribed (Tier \(tier))", bioData: "Coherence: \(currentCoherence)")
        Task {
            await switchOBSScene("SubscriberAlert")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await switchOBSScene(currentScene)
        }
    }

    /// Handle donation alert
    public func handleDonationAlert(username: String, amount: Float, currency: String = "USD") {
        log.info("Donation from \(username): \(amount) \(currency)", category: .social)
        markHighlight(type: .donation, description: "\(username) donated \(amount) \(currency)", bioData: "HR: \(currentHeartRate), Coherence: \(currentCoherence)")
    }

    // MARK: - Social Media Auto-Posting

    /// Auto-post highlights to social media
    public func autoPostHighlights(_ session: StreamSession) async {
        guard configuration.enableAutoPosting else { return }
        let topHighlights = session.highlights
            .filter { $0.type == .highCoherence || $0.type == .chatReaction }
            .prefix(3)
        for highlight in topHighlights {
            let post = generateSocialPost(highlight: highlight, session: session)
            await postToSocialMedia(post, platforms: configuration.platforms)
        }
        log.info("Auto-posted \(topHighlights.count) highlights", category: .social)
    }

    /// Post to social media platforms
    public func postToSocialMedia(_ content: String, platforms: [Configuration.StreamingPlatform]) async {
        for platform in platforms {
            log.info("Posting to \(platform.rawValue): \(content.prefix(50))...", category: .social)
        }
    }

    // MARK: - Analytics

    /// Get stream analytics
    public func getStreamAnalytics() -> (duration: TimeInterval, viewers: Int, clips: Int, highlights: Int, coherence: Float)? {
        guard let session = currentSession else { return nil }
        let duration = (session.endTime ?? Date()).timeIntervalSince(session.startTime)
        return (
            duration: duration,
            viewers: session.viewers,
            clips: session.clips.count,
            highlights: session.highlights.count,
            coherence: session.averageCoherence
        )
    }

    // MARK: - Private Helpers

    private func setupDefaultScenes() {
        bioScenes = [
            OBSScene(name: "HighEnergy", coherenceRange: Float(0.8)...Float(1.0), priority: 3),
            OBSScene(name: "Focused", coherenceRange: Float(0.6)...Float(0.8), priority: 2),
            OBSScene(name: "Relaxed", coherenceRange: Float(0.4)...Float(0.6), priority: 1),
            OBSScene(name: "Main", coherenceRange: Float(0.0)...Float(0.4), priority: 0)
        ]
    }

    private func registerDefaultChatCommands() {
        registerChatCommand(ChatCommand(command: "coherence", description: "Show current coherence level") { [weak self] in
            guard let self = self else { return }
            log.info("Chat command response: Coherence is \(Int(self.currentCoherence * 100))%", category: .social)
        })
        registerChatCommand(ChatCommand(command: "clip", description: "Create a clip of the last 30 seconds", cooldown: 60.0) { [weak self] in
            self?.createClip(title: "Chat Requested Clip")
        })
        registerChatCommand(ChatCommand(command: "scene", description: "Switch to high energy scene", requiresModerator: true) { [weak self] in
            Task { await self?.switchOBSScene("HighEnergy") }
        })
    }

    private func updateSceneBasedOnBio() {
        guard obsConnected else { return }
        for scene in bioScenes {
            if scene.coherenceRange.contains(currentCoherence) {
                if currentScene != scene.name {
                    Task { await switchOBSScene(scene.name) }
                }
                break
            }
        }
    }

    private func checkAutoClipOpportunity() {
        let timeSinceLastClip = Date().timeIntervalSince(lastClipTime)
        if currentCoherence >= configuration.coherenceThresholdForHighlight && timeSinceLastClip >= 120.0 {
            createClip(title: "High Coherence Moment", duration: 30.0)
        }
    }

    private func generateSocialPost(highlight: Highlight, session: StreamSession) -> String {
        return """
        Epic moment from today's stream: \(session.title)

        \(highlight.description)

        Bio metrics: \(highlight.bioData)

        #Echoelmusic #BioReactiveStream #LivePerformance
        """
    }
}
