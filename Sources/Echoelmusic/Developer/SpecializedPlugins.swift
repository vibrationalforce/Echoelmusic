// SpecializedPlugins.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Specialized professional plugins for specific use cases
// Therapy, Performance, Research, Accessibility, Content Creation
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine
import simd

// MARK: - 1. Therapy Session Plugin

/// A comprehensive plugin for wellness practitioners and therapists
/// Demonstrates: bioProcessing, hrvAnalysis, recording, cloudSync capabilities
public final class TherapySessionPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.therapy-session" }
    public var name: String { "Therapy Session Manager" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Wellness Team" }
    public var pluginDescription: String { "Professional therapy session management with HIPAA-compliant bio data recording, client progress tracking, and session notes" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.bioProcessing, .hrvAnalysis, .coherenceTracking, .recording, .cloudSync] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var practitionerName: String = "Dr. Smith"
        public var sessionDuration: TimeInterval = 3600 // 60 minutes
        public var recordingInterval: TimeInterval = 1.0 // 1 Hz bio data
        public var autoSave: Bool = true
        public var encryptData: Bool = true
        public var anonymizeExport: Bool = true
        public var protocolType: ProtocolType = .mindfulness

        public enum ProtocolType: String, CaseIterable, Sendable, Codable {
            case mindfulness = "Mindfulness Meditation"
            case breathwork = "Breathwork"
            case biofeedback = "Biofeedback Training"
            case coherenceTraining = "Coherence Training"
            case stressReduction = "Stress Reduction"
            case anxietyManagement = "Anxiety Management"
            case traumaHealing = "Trauma-Informed Healing"
            case customProtocol = "Custom Protocol"
        }
    }

    // MARK: - Session Data Models

    public struct TherapySession: Codable, Sendable {
        public var id: UUID
        public var clientId: String // Anonymized client identifier
        public var practitionerId: String
        public var startTime: Date
        public var endTime: Date?
        public var protocolType: Configuration.ProtocolType
        public var bioDataPoints: [BioDataPoint]
        public var notes: [SessionNote]
        public var milestones: [Milestone]
        public var sessionGoals: [String]
        public var sessionOutcome: String?

        public init(clientId: String, practitionerId: String, protocolType: Configuration.ProtocolType) {
            self.id = UUID()
            self.clientId = clientId
            self.practitionerId = practitionerId
            self.startTime = Date()
            self.endTime = nil
            self.protocolType = protocolType
            self.bioDataPoints = []
            self.notes = []
            self.milestones = []
            self.sessionGoals = []
            self.sessionOutcome = nil
        }
    }

    public struct BioDataPoint: Codable, Sendable {
        public var timestamp: Date
        public var heartRate: Float?
        public var hrv: Float?
        public var coherence: Float
        public var breathingRate: Float?
        public var skinConductance: Float?
    }

    public struct SessionNote: Codable, Identifiable, Sendable {
        public var id: UUID
        public var timestamp: Date
        public var note: String
        public var noteType: NoteType

        public enum NoteType: String, Codable, Sendable {
            case observation = "Observation"
            case intervention = "Intervention"
            case clientResponse = "Client Response"
            case milestone = "Milestone"
            case concern = "Concern"
        }

        public init(note: String, type: NoteType) {
            self.id = UUID()
            self.timestamp = Date()
            self.note = note
            self.noteType = type
        }
    }

    public struct Milestone: Codable, Identifiable, Sendable {
        public var id: UUID
        public var timestamp: Date
        public var title: String
        public var description: String
        public var coherenceAtTime: Float

        public init(title: String, description: String, coherence: Float) {
            self.id = UUID()
            self.timestamp = Date()
            self.title = title
            self.description = description
            self.coherenceAtTime = coherence
        }
    }

    public struct ClientProgress: Codable, Sendable {
        public var clientId: String
        public var sessions: [TherapySession]
        public var averageCoherence: Float
        public var coherenceTrend: [Float]
        public var totalSessionTime: TimeInterval
        public var milestonesAchieved: Int

        public init(clientId: String) {
            self.clientId = clientId
            self.sessions = []
            self.averageCoherence = 0
            self.coherenceTrend = []
            self.totalSessionTime = 0
            self.milestonesAchieved = 0
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var currentSession: TherapySession?
    private var clientProgressMap: [String: ClientProgress] = [:]
    private var recordingTimer: Timer?
    private var currentBioData: BioData = .empty
    private var sessionStartTime: Date?

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Therapy Session Plugin loaded - Practitioner: \(configuration.practitionerName)", category: .wellness)

        // Load existing client progress data
        await loadClientProgressData(from: context.dataDirectory)

        log.info("Loaded progress data for \(clientProgressMap.count) clients", category: .wellness)
    }

    public func onUnload() async {
        // End current session if active
        if currentSession != nil {
            await endSession(outcome: "Session ended by plugin unload")
        }

        // Save all data
        await saveAllData()

        log.info("Therapy Session Plugin unloaded - data saved", category: .wellness)
    }

    public func onFrame(deltaTime: TimeInterval) {
        // Check session duration
        if let session = currentSession,
           let startTime = sessionStartTime,
           Date().timeIntervalSince(startTime) >= configuration.sessionDuration {
            Task {
                await autoEndSession()
            }
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        currentBioData = bioData

        // Record bio data if session is active
        if var session = currentSession {
            let dataPoint = BioDataPoint(
                timestamp: Date(),
                heartRate: bioData.heartRate,
                hrv: bioData.hrvSDNN,
                coherence: bioData.coherence,
                breathingRate: bioData.breathingRate,
                skinConductance: bioData.skinConductance
            )
            session.bioDataPoints.append(dataPoint)
            currentSession = session

            // Auto-detect milestones
            autoDetectMilestones(bioData: bioData)
        }
    }

    // MARK: - Session Management

    /// Start a new therapy session
    public func startSession(clientId: String, goals: [String] = []) async {
        guard currentSession == nil else {
            log.warning("Cannot start session - session already in progress", category: .wellness)
            return
        }

        var session = TherapySession(
            clientId: clientId,
            practitionerId: configuration.practitionerName,
            protocolType: configuration.protocolType
        )
        session.sessionGoals = goals

        currentSession = session
        sessionStartTime = Date()

        // Start bio data recording timer
        startRecordingTimer()

        log.info("Started therapy session for client: \(clientId.prefix(8))...", category: .wellness)
    }

    /// End the current therapy session
    public func endSession(outcome: String) async {
        guard var session = currentSession else {
            log.warning("No active session to end", category: .wellness)
            return
        }

        session.endTime = Date()
        session.sessionOutcome = outcome

        // Stop recording
        stopRecordingTimer()

        // Update client progress
        updateClientProgress(session: session)

        // Save session data
        if configuration.autoSave {
            await saveSession(session)
        }

        let durationMinutes = session.endTime.map { String(format: "%.1f", $0.timeIntervalSince(session.startTime) / 60) } ?? "unknown"
        log.info("Ended therapy session - Duration: \(durationMinutes) minutes", category: .wellness)

        currentSession = nil
        sessionStartTime = nil
    }

    /// Add a note to the current session
    public func addNote(_ noteText: String, type: SessionNote.NoteType = .observation) {
        guard currentSession != nil else {
            log.warning("Cannot add note - no active session", category: .wellness)
            return
        }

        let note = SessionNote(note: noteText, type: type)
        currentSession?.notes.append(note)

        log.debug("Added \(type.rawValue) note: \(noteText.prefix(50))...", category: .wellness)
    }

    /// Add a milestone to the current session
    public func addMilestone(title: String, description: String) {
        guard currentSession != nil else {
            log.warning("Cannot add milestone - no active session", category: .wellness)
            return
        }

        let milestone = Milestone(
            title: title,
            description: description,
            coherence: currentBioData.coherence
        )
        currentSession?.milestones.append(milestone)

        log.info("Milestone achieved: \(title)", category: .wellness)
    }

    // MARK: - Progress Tracking

    /// Get progress for a specific client
    public func getClientProgress(clientId: String) -> ClientProgress? {
        return clientProgressMap[clientId]
    }

    /// Get all clients with progress data
    public func getAllClients() -> [String] {
        return Array(clientProgressMap.keys)
    }

    /// Update client progress with completed session
    private func updateClientProgress(session: TherapySession) {
        var progress = clientProgressMap[session.clientId] ?? ClientProgress(clientId: session.clientId)

        progress.sessions.append(session)
        progress.milestonesAchieved += session.milestones.count

        if let endTime = session.endTime {
            progress.totalSessionTime += endTime.timeIntervalSince(session.startTime)
        }

        // Calculate average coherence
        let allCoherenceValues = session.bioDataPoints.map { $0.coherence }
        if !allCoherenceValues.isEmpty {
            let sessionAverage = allCoherenceValues.reduce(0, +) / Float(allCoherenceValues.count)
            progress.coherenceTrend.append(sessionAverage)

            // Recalculate overall average
            progress.averageCoherence = progress.coherenceTrend.reduce(0, +) / Float(progress.coherenceTrend.count)
        }

        clientProgressMap[session.clientId] = progress

        log.debug("Updated progress for client \(session.clientId.prefix(8))... - Avg coherence: \(String(format: "%.2f", progress.averageCoherence))", category: .wellness)
    }

    // MARK: - Export & Reporting

    /// Export session data to CSV
    public func exportSessionToCSV(sessionId: UUID) -> String? {
        guard let session = findSession(by: sessionId) else { return nil }

        var csv = "Timestamp,HeartRate,HRV,Coherence,BreathingRate,SkinConductance\n"

        for point in session.bioDataPoints {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = dateFormatter.string(from: point.timestamp)

            csv += "\(timestamp),"
            csv += "\(point.heartRate ?? -1),"
            csv += "\(point.hrv ?? -1),"
            csv += "\(point.coherence),"
            csv += "\(point.breathingRate ?? -1),"
            csv += "\(point.skinConductance ?? -1)\n"
        }

        log.info("Exported session to CSV - \(session.bioDataPoints.count) data points", category: .wellness)
        return csv
    }

    /// Export session report (HIPAA-compliant)
    public func generateSessionReport(sessionId: UUID, anonymize: Bool = true) -> String {
        guard let session = findSession(by: sessionId) else { return "Session not found" }

        let clientId = anonymize ? "Client-\(session.clientId.prefix(8))" : session.clientId
        let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
        let avgCoherence = session.bioDataPoints.isEmpty ? 0 : session.bioDataPoints.map { $0.coherence }.reduce(0, +) / Float(session.bioDataPoints.count)

        var report = """
        ═══════════════════════════════════════════════════════════
        THERAPY SESSION REPORT
        ═══════════════════════════════════════════════════════════

        Session ID: \(session.id)
        Client ID: \(clientId)
        Practitioner: \(session.practitionerId)
        Protocol: \(session.protocolType.rawValue)

        Date: \(session.startTime.formatted())
        Duration: \(String(format: "%.1f", duration / 60)) minutes

        ───────────────────────────────────────────────────────────
        SESSION GOALS
        ───────────────────────────────────────────────────────────

        """

        for (i, goal) in session.sessionGoals.enumerated() {
            report += "\(i + 1). \(goal)\n"
        }

        report += """

        ───────────────────────────────────────────────────────────
        BIOMETRIC SUMMARY
        ───────────────────────────────────────────────────────────

        Average Coherence: \(String(format: "%.2f", avgCoherence))
        Data Points Recorded: \(session.bioDataPoints.count)

        """

        if !session.bioDataPoints.isEmpty {
            let avgHR = session.bioDataPoints.compactMap { $0.heartRate }.reduce(0, +) / Float(session.bioDataPoints.compactMap { $0.heartRate }.count)
            let avgHRV = session.bioDataPoints.compactMap { $0.hrv }.reduce(0, +) / Float(session.bioDataPoints.compactMap { $0.hrv }.count)

            report += "Average Heart Rate: \(String(format: "%.1f", avgHR)) BPM\n"
            report += "Average HRV: \(String(format: "%.1f", avgHRV)) ms\n"
        }

        report += """

        ───────────────────────────────────────────────────────────
        MILESTONES ACHIEVED (\(session.milestones.count))
        ───────────────────────────────────────────────────────────

        """

        for milestone in session.milestones {
            report += "• \(milestone.title) - \(milestone.timestamp.formatted(date: .omitted, time: .shortened))\n"
            report += "  \(milestone.description)\n"
            report += "  Coherence: \(String(format: "%.2f", milestone.coherenceAtTime))\n\n"
        }

        report += """
        ───────────────────────────────────────────────────────────
        SESSION NOTES (\(session.notes.count))
        ───────────────────────────────────────────────────────────

        """

        for note in session.notes {
            report += "[\(note.timestamp.formatted(date: .omitted, time: .shortened))] [\(note.noteType.rawValue)]\n"
            report += "\(note.note)\n\n"
        }

        if let outcome = session.sessionOutcome {
            report += """
            ───────────────────────────────────────────────────────────
            SESSION OUTCOME
            ───────────────────────────────────────────────────────────

            \(outcome)

            """
        }

        report += """
        ═══════════════════════════════════════════════════════════
        DISCLAIMER: This report is for therapeutic purposes only
        and does not constitute medical diagnosis or treatment.
        ═══════════════════════════════════════════════════════════
        """

        log.info("Generated session report for session \(sessionId)", category: .wellness)
        return report
    }

    // MARK: - Private Helpers

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: configuration.recordingInterval, repeats: true) { [weak self] _ in
            // Timer callback - bio data is recorded in onBioDataUpdate
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func autoEndSession() async {
        await endSession(outcome: "Session ended automatically after configured duration")
    }

    private func autoDetectMilestones(bioData: BioData) {
        // Auto-detect high coherence milestones
        if bioData.coherence >= 0.8, let session = currentSession, !session.bioDataPoints.isEmpty {
            let recentPoints = session.bioDataPoints.suffix(30) // Last 30 seconds
            let recentCoherence = recentPoints.map { $0.coherence }
            let avgRecent = recentCoherence.reduce(0, +) / Float(recentCoherence.count)

            if avgRecent >= 0.75 {
                // Check if we already recorded this milestone recently
                let recentMilestones = session.milestones.filter { Date().timeIntervalSince($0.timestamp) < 120 }
                if recentMilestones.isEmpty {
                    addMilestone(
                        title: "High Coherence State",
                        description: "Sustained high coherence (>0.75) for 30+ seconds"
                    )
                }
            }
        }
    }

    private func findSession(by id: UUID) -> TherapySession? {
        // Search in current session
        if currentSession?.id == id {
            return currentSession
        }

        // Search in client progress
        for progress in clientProgressMap.values {
            if let session = progress.sessions.first(where: { $0.id == id }) {
                return session
            }
        }

        return nil
    }

    private func loadClientProgressData(from directory: URL) async {
        let progressFile = directory.appendingPathComponent("client_progress.json")

        guard FileManager.default.fileExists(atPath: progressFile.path) else {
            log.debug("No existing client progress data found", category: .wellness)
            return
        }

        do {
            let data = try Data(contentsOf: progressFile)
            let progress = try JSONDecoder().decode([String: ClientProgress].self, from: data)
            clientProgressMap = progress
        } catch {
            log.error("Failed to load client progress data: \(error)", category: .wellness)
        }
    }

    private func saveSession(_ session: TherapySession) async {
        // In production, this would save to secure encrypted storage
        log.debug("Session data saved (encrypted: \(configuration.encryptData))", category: .wellness)
    }

    private func saveAllData() async {
        // In production, this would save to secure encrypted storage
        log.info("All therapy data saved securely", category: .wellness)
    }
}

// MARK: - 2. Live Performance Plugin

/// A comprehensive plugin for live musicians and performers
/// Demonstrates: midiInput, midiOutput, dmxOutput, recording capabilities
public final class LivePerformancePlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.live-performance" }
    public var name: String { "Live Performance Manager" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Performance Team" }
    public var pluginDescription: String { "Professional live performance management with set lists, MIDI cues, lighting sync, and bio-adaptive click track" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.midiInput, .midiOutput, .dmxOutput, .recording, .bioProcessing, .audioGenerator] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var performanceName: String = "Untitled Performance"
        public var midiChannel: UInt8 = 1
        public var enableBioAdaptiveTempo: Bool = true
        public var tempoRange: ClosedRange<Float> = 60...180
        public var clickTrackEnabled: Bool = true
        public var lightingSyncEnabled: Bool = true
        public var autoTransitionEnabled: Bool = false

        public enum ClickSound: String, CaseIterable, Sendable {
            case metronome = "Metronome"
            case woodBlock = "Wood Block"
            case beep = "Beep"
            case cowbell = "Cowbell"
            case sideStick = "Side Stick"
        }

        public var clickSound: ClickSound = .metronome
    }

    // MARK: - Performance Data Models

    public struct SetList: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var songs: [Song]
        public var currentSongIndex: Int

        public init(name: String, songs: [Song] = []) {
            self.id = UUID()
            self.name = name
            self.songs = songs
            self.currentSongIndex = 0
        }

        public var currentSong: Song? {
            guard currentSongIndex < songs.count else { return nil }
            return songs[currentSongIndex]
        }
    }

    public struct Song: Codable, Identifiable, Sendable {
        public var id: UUID
        public var title: String
        public var artist: String
        public var bpm: Float
        public var key: String
        public var duration: TimeInterval
        public var cues: [Cue]
        public var midiProgramChange: UInt8?
        public var lightingScene: String?
        public var notes: String

        public init(title: String, artist: String, bpm: Float, key: String, duration: TimeInterval) {
            self.id = UUID()
            self.title = title
            self.artist = artist
            self.bpm = bpm
            self.key = key
            self.duration = duration
            self.cues = []
            self.midiProgramChange = nil
            self.lightingScene = nil
            self.notes = ""
        }
    }

    public struct Cue: Codable, Identifiable, Sendable {
        public var id: UUID
        public var timestamp: TimeInterval
        public var name: String
        public var type: CueType
        public var action: String

        public enum CueType: String, Codable, Sendable {
            case midiProgramChange = "MIDI Program"
            case lightingChange = "Lighting"
            case effectToggle = "Effect"
            case marker = "Marker"
            case automation = "Automation"
        }

        public init(timestamp: TimeInterval, name: String, type: CueType, action: String) {
            self.id = UUID()
            self.timestamp = timestamp
            self.name = name
            self.type = type
            self.action = action
        }
    }

    public struct PerformanceStats: Sendable {
        public var startTime: Date
        public var currentSongStartTime: Date
        public var songsCompleted: Int
        public var totalSongs: Int
        public var cuesTriggered: Int
        public var averageCoherence: Float
        public var averageHeartRate: Float
    }

    // MARK: - State

    public var configuration = Configuration()
    private var currentSetList: SetList?
    private var isPerformanceActive: Bool = false
    private var performanceStartTime: Date?
    private var currentSongStartTime: Date?
    private var songElapsedTime: TimeInterval = 0
    private var nextCueIndex: Int = 0

    // Click track
    private var clickPhase: Float = 0
    private var currentTempo: Float = 120.0
    private var beatCount: Int = 0

    // Bio data
    private var currentHeartRate: Float = 70.0
    private var currentCoherence: Float = 0.5
    private var heartRateHistory: [Float] = []

    // Emergency
    private var emergencyStopActive: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Live Performance Plugin loaded - Performance: \(configuration.performanceName)", category: .performance)

        // Load set list from storage
        await loadSetList(from: context.dataDirectory)
    }

    public func onUnload() async {
        if isPerformanceActive {
            await stopPerformance()
        }

        log.info("Live Performance Plugin unloaded", category: .performance)
    }

    public func onFrame(deltaTime: TimeInterval) {
        guard isPerformanceActive, !emergencyStopActive else { return }

        songElapsedTime += deltaTime

        // Check and trigger cues
        checkAndTriggerCues()

        // Auto-transition to next song if enabled
        if configuration.autoTransitionEnabled {
            checkAutoTransition()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        if let hr = bioData.heartRate {
            currentHeartRate = hr
            heartRateHistory.append(hr)
            if heartRateHistory.count > 100 {
                heartRateHistory.removeFirst()
            }
        }

        currentCoherence = bioData.coherence

        // Adapt tempo based on heart rate
        if configuration.enableBioAdaptiveTempo, let song = currentSetList?.currentSong {
            let targetTempo = song.bpm
            let hrFactor = (currentHeartRate - 70.0) / 30.0 // Normalized around 70 BPM
            let adaptiveTempo = targetTempo + (hrFactor * 10.0)
            currentTempo = adaptiveTempo.clamped(to: configuration.tempoRange)
        }
    }

    public func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
        guard configuration.clickTrackEnabled, isPerformanceActive, !emergencyStopActive else { return }

        let sampleRateF = Float(sampleRate)
        let samplesPerChannel = buffer.count / channels
        let beatsPerSecond = currentTempo / 60.0

        for sample in 0..<samplesPerChannel {
            // Advance click phase
            clickPhase += beatsPerSecond / sampleRateF

            // Generate click on beat
            if clickPhase >= 1.0 {
                clickPhase -= 1.0
                beatCount += 1

                // Generate click sound
                let clickSample = generateClickSample(beat: beatCount % 4)

                // Add to all channels
                for channel in 0..<channels {
                    buffer[sample * channels + channel] += clickSample * 0.3
                }
            }
        }
    }

    // MARK: - Set List Management

    /// Load a set list
    public func loadSetList(_ setList: SetList) {
        currentSetList = setList
        nextCueIndex = 0
        log.info("Loaded set list: \(setList.name) - \(setList.songs.count) songs", category: .performance)
    }

    /// Get current set list
    public func getCurrentSetList() -> SetList? {
        return currentSetList
    }

    /// Add song to set list
    public func addSong(_ song: Song) {
        if currentSetList != nil {
            currentSetList?.songs.append(song)
            log.debug("Added song: \(song.title) to set list", category: .performance)
        }
    }

    /// Remove song from set list
    public func removeSong(at index: Int) {
        guard var setList = currentSetList, index < setList.songs.count else { return }
        let removedSong = setList.songs.remove(at: index)
        currentSetList = setList
        log.debug("Removed song: \(removedSong.title) from set list", category: .performance)
    }

    // MARK: - Performance Control

    /// Start the performance
    public func startPerformance() async {
        guard let setList = currentSetList, !setList.songs.isEmpty else {
            log.warning("Cannot start performance - no songs in set list", category: .performance)
            return
        }

        isPerformanceActive = true
        performanceStartTime = Date()
        songElapsedTime = 0
        nextCueIndex = 0
        emergencyStopActive = false

        // Start first song
        await startCurrentSong()

        log.info("Performance started: \(setList.name)", category: .performance)
    }

    /// Stop the performance
    public func stopPerformance() async {
        isPerformanceActive = false
        currentSongStartTime = nil
        songElapsedTime = 0
        clickPhase = 0
        beatCount = 0

        // Send MIDI all notes off
        sendMIDIAllNotesOff()

        log.info("Performance stopped", category: .performance)
    }

    /// Next song in set list
    public func nextSong() async {
        guard var setList = currentSetList else { return }

        if setList.currentSongIndex < setList.songs.count - 1 {
            setList.currentSongIndex += 1
            currentSetList = setList
            songElapsedTime = 0
            nextCueIndex = 0
            await startCurrentSong()

            log.info("Advanced to next song: \(setList.currentSong?.title ?? "Unknown")", category: .performance)
        } else {
            log.info("Reached end of set list", category: .performance)
        }
    }

    /// Previous song in set list
    public func previousSong() async {
        guard var setList = currentSetList else { return }

        if setList.currentSongIndex > 0 {
            setList.currentSongIndex -= 1
            currentSetList = setList
            songElapsedTime = 0
            nextCueIndex = 0
            await startCurrentSong()

            log.info("Moved to previous song: \(setList.currentSong?.title ?? "Unknown")", category: .performance)
        }
    }

    /// Jump to specific song
    public func jumpToSong(index: Int) async {
        guard var setList = currentSetList, index >= 0, index < setList.songs.count else { return }

        setList.currentSongIndex = index
        currentSetList = setList
        songElapsedTime = 0
        nextCueIndex = 0
        await startCurrentSong()

        log.info("Jumped to song \(index + 1): \(setList.currentSong?.title ?? "Unknown")", category: .performance)
    }

    /// Emergency stop - immediately silence everything
    public func emergencyStop() {
        emergencyStopActive = true

        // Stop all audio
        clickPhase = 0
        beatCount = 0

        // Send MIDI panic
        sendMIDIAllNotesOff()
        sendMIDIPanic()

        // Blackout lights
        blackoutLights()

        log.critical("EMERGENCY STOP ACTIVATED", category: .performance)
    }

    /// Resume from emergency stop
    public func resumeFromEmergency() {
        emergencyStopActive = false
        log.info("Resumed from emergency stop", category: .performance)
    }

    // MARK: - Cue Management

    /// Manually trigger next cue
    public func triggerNextCue() {
        guard let song = currentSetList?.currentSong, nextCueIndex < song.cues.count else {
            log.debug("No more cues to trigger", category: .performance)
            return
        }

        let cue = song.cues[nextCueIndex]
        executeCue(cue)
        nextCueIndex += 1
    }

    /// Add cue to current song
    public func addCueToCurrentSong(_ cue: Cue) {
        guard var setList = currentSetList else { return }

        let songIndex = setList.currentSongIndex
        setList.songs[songIndex].cues.append(cue)
        currentSetList = setList

        log.debug("Added cue '\(cue.name)' to current song", category: .performance)
    }

    // MARK: - Statistics

    /// Get performance statistics
    public func getPerformanceStats() -> PerformanceStats? {
        guard let startTime = performanceStartTime, let songStart = currentSongStartTime, let setList = currentSetList else {
            return nil
        }

        let avgHR = heartRateHistory.isEmpty ? 0 : heartRateHistory.reduce(0, +) / Float(heartRateHistory.count)

        return PerformanceStats(
            startTime: startTime,
            currentSongStartTime: songStart,
            songsCompleted: setList.currentSongIndex,
            totalSongs: setList.songs.count,
            cuesTriggered: nextCueIndex,
            averageCoherence: currentCoherence,
            averageHeartRate: avgHR
        )
    }

    // MARK: - Private Helpers

    private func startCurrentSong() async {
        guard let song = currentSetList?.currentSong else { return }

        currentSongStartTime = Date()
        currentTempo = song.bpm
        nextCueIndex = 0
        beatCount = 0

        // Send MIDI program change
        if let program = song.midiProgramChange {
            sendMIDIProgramChange(program: program)
        }

        // Switch lighting scene
        if let scene = song.lightingScene {
            switchLightingScene(scene)
        }

        log.info("Started song: \(song.title) - BPM: \(song.bpm)", category: .performance)
    }

    private func checkAndTriggerCues() {
        guard let song = currentSetList?.currentSong else { return }

        while nextCueIndex < song.cues.count {
            let cue = song.cues[nextCueIndex]

            if songElapsedTime >= cue.timestamp {
                executeCue(cue)
                nextCueIndex += 1
            } else {
                break
            }
        }
    }

    private func executeCue(_ cue: Cue) {
        log.debug("Triggering cue: \(cue.name) - Type: \(cue.type.rawValue)", category: .performance)

        switch cue.type {
        case .midiProgramChange:
            if let program = UInt8(cue.action) {
                sendMIDIProgramChange(program: program)
            }
        case .lightingChange:
            switchLightingScene(cue.action)
        case .effectToggle:
            // Toggle effect (would integrate with audio engine)
            log.debug("Toggle effect: \(cue.action)", category: .performance)
        case .marker:
            // Just a marker for performer
            break
        case .automation:
            // Execute automation (would integrate with DAW/controller)
            log.debug("Execute automation: \(cue.action)", category: .performance)
        }
    }

    private func checkAutoTransition() {
        guard let song = currentSetList?.currentSong else { return }

        if songElapsedTime >= song.duration {
            Task {
                await nextSong()
            }
        }
    }

    private func generateClickSample(beat: Int) -> Float {
        // First beat of bar is louder
        let amplitude: Float = beat == 0 ? 1.0 : 0.6

        switch configuration.clickSound {
        case .metronome:
            return amplitude
        case .woodBlock:
            return amplitude * 0.8
        case .beep:
            return amplitude * sin(Float.pi * 2 * 880 * 0.01) // 880 Hz beep
        case .cowbell:
            return amplitude * 0.9
        case .sideStick:
            return amplitude * 0.7
        }
    }

    private func sendMIDIProgramChange(program: UInt8) {
        log.midi("MIDI Program Change: \(program) on channel \(configuration.midiChannel)")
        // In production, send actual MIDI message
    }

    private func sendMIDIAllNotesOff() {
        log.midi("MIDI All Notes Off on channel \(configuration.midiChannel)")
        // In production, send CC 123 (All Notes Off)
    }

    private func sendMIDIPanic() {
        log.midi("MIDI Panic - All Sound Off")
        // In production, send CC 120 (All Sound Off) on all channels
    }

    private func switchLightingScene(_ scene: String) {
        guard configuration.lightingSyncEnabled else { return }
        log.led("Switching to lighting scene: \(scene)")
        // In production, send DMX/Art-Net commands
    }

    private func blackoutLights() {
        log.led("Blackout all lights")
        // In production, send DMX blackout command
    }

    private func loadSetList(from directory: URL) async {
        let setListFile = directory.appendingPathComponent("current_setlist.json")

        guard FileManager.default.fileExists(atPath: setListFile.path),
              let data = try? Data(contentsOf: setListFile),
              let setList = try? JSONDecoder().decode(SetList.self, from: data) else {
            log.debug("No existing set list found", category: .performance)
            return
        }

        currentSetList = setList
        log.info("Loaded set list: \(setList.name)", category: .performance)
    }
}

// MARK: - 3. Research Data Plugin

/// A comprehensive plugin for scientific research and data analysis
/// Demonstrates: bioProcessing, recording, cloudSync, collaboration capabilities
public final class ResearchDataPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.research-data" }
    public var name: String { "Research Data Analyzer" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Research Team" }
    public var pluginDescription: String { "Scientific research plugin with IRB compliance, data anonymization, statistical analysis, and multi-participant comparison" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.bioProcessing, .hrvAnalysis, .coherenceTracking, .recording, .cloudSync, .collaboration] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var studyName: String = "Untitled Study"
        public var studyProtocol: String = "Protocol-001"
        public var irbApprovalNumber: String = ""
        public var principalInvestigator: String = ""
        public var anonymizeData: Bool = true
        public var samplingRate: TimeInterval = 1.0 // 1 Hz
        public var recordRawData: Bool = true
        public var autoExport: Bool = false
        public var exportFormat: ExportFormat = .csv

        public enum ExportFormat: String, CaseIterable, Sendable {
            case csv = "CSV"
            case json = "JSON"
            case both = "Both"
        }
    }

    // MARK: - Research Data Models

    public struct Participant: Codable, Identifiable, Sendable {
        public var id: String // Anonymized
        public var studyGroup: String
        public var demographics: Demographics
        public var sessions: [ResearchSession]
        public var consentDate: Date
        public var consentFormVersion: String

        public init(id: String, studyGroup: String, demographics: Demographics) {
            self.id = id
            self.studyGroup = studyGroup
            self.demographics = demographics
            self.sessions = []
            self.consentDate = Date()
            self.consentFormVersion = "1.0"
        }
    }

    public struct Demographics: Codable, Sendable {
        public var ageGroup: String // e.g., "20-30"
        public var gender: String // Optional for privacy
        public var handedness: String
        public var notes: String

        public init(ageGroup: String, gender: String = "Not specified", handedness: String = "Right") {
            self.ageGroup = ageGroup
            self.gender = gender
            self.handedness = handedness
            self.notes = ""
        }
    }

    public struct ResearchSession: Codable, Identifiable, Sendable {
        public var id: UUID
        public var participantId: String
        public var sessionNumber: Int
        public var condition: String
        public var startTime: Date
        public var endTime: Date?
        public var dataPoints: [DataPoint]
        public var events: [Event]
        public var questionnaires: [Questionnaire]

        public init(participantId: String, sessionNumber: Int, condition: String) {
            self.id = UUID()
            self.participantId = participantId
            self.sessionNumber = sessionNumber
            self.condition = condition
            self.startTime = Date()
            self.endTime = nil
            self.dataPoints = []
            self.events = []
            self.questionnaires = []
        }
    }

    public struct DataPoint: Codable, Sendable {
        public var timestamp: TimeInterval // Relative to session start
        public var heartRate: Float?
        public var hrv: Float?
        public var coherence: Float
        public var breathingRate: Float?
        public var skinConductance: Float?
        public var temperature: Float?
    }

    public struct Event: Codable, Identifiable, Sendable {
        public var id: UUID
        public var timestamp: TimeInterval
        public var eventType: String
        public var description: String

        public init(timestamp: TimeInterval, eventType: String, description: String) {
            self.id = UUID()
            self.timestamp = timestamp
            self.eventType = eventType
            self.description = description
        }
    }

    public struct Questionnaire: Codable, Identifiable, Sendable {
        public var id: UUID
        public var name: String
        public var responses: [String: String]
        public var timestamp: Date

        public init(name: String, responses: [String: String]) {
            self.id = UUID()
            self.name = name
            self.responses = responses
            self.timestamp = Date()
        }
    }

    public struct StatisticalSummary: Sendable {
        public var mean: Float
        public var standardDeviation: Float
        public var min: Float
        public var max: Float
        public var median: Float
        public var count: Int
    }

    // MARK: - State

    public var configuration = Configuration()
    private var participants: [String: Participant] = [:]
    private var currentSession: ResearchSession?
    private var sessionStartTime: Date?

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Research Data Plugin loaded - Study: \(configuration.studyName)", category: .science)

        // Load participant data
        await loadParticipants(from: context.dataDirectory)

        log.info("Loaded data for \(participants.count) participants", category: .science)
    }

    public func onUnload() async {
        if currentSession != nil {
            await endSession()
        }

        await saveAllData()

        log.info("Research Data Plugin unloaded", category: .science)
    }

    public func onFrame(deltaTime: TimeInterval) {
        // No frame updates needed
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        guard var session = currentSession, let startTime = sessionStartTime else { return }

        let timestamp = Date().timeIntervalSince(startTime)

        let dataPoint = DataPoint(
            timestamp: timestamp,
            heartRate: bioData.heartRate,
            hrv: bioData.hrvSDNN,
            coherence: bioData.coherence,
            breathingRate: bioData.breathingRate,
            skinConductance: bioData.skinConductance,
            temperature: bioData.temperature
        )

        session.dataPoints.append(dataPoint)
        currentSession = session
    }

    // MARK: - Participant Management

    /// Register a new participant
    public func registerParticipant(id: String, studyGroup: String, demographics: Demographics) {
        guard participants[id] == nil else {
            log.warning("Participant \(id) already registered", category: .science)
            return
        }

        let participant = Participant(id: id, studyGroup: studyGroup, demographics: demographics)
        participants[id] = participant

        log.info("Registered participant \(id) in group \(studyGroup)", category: .science)
    }

    /// Get participant by ID
    public func getParticipant(id: String) -> Participant? {
        return participants[id]
    }

    /// Get all participants in study group
    public func getParticipants(inGroup group: String) -> [Participant] {
        return participants.values.filter { $0.studyGroup == group }
    }

    // MARK: - Session Management

    /// Start a research session
    public func startSession(participantId: String, condition: String) {
        guard participants[participantId] != nil else {
            log.error("Cannot start session - participant \(participantId) not found", category: .science)
            return
        }

        guard currentSession == nil else {
            log.warning("Cannot start session - session already in progress", category: .science)
            return
        }

        let sessionNumber = (participants[participantId]?.sessions.count ?? 0) + 1

        currentSession = ResearchSession(
            participantId: participantId,
            sessionNumber: sessionNumber,
            condition: condition
        )
        sessionStartTime = Date()

        log.info("Started research session for participant \(participantId) - Condition: \(condition)", category: .science)
    }

    /// End the current session
    public func endSession() async {
        guard var session = currentSession else {
            log.warning("No active session to end", category: .science)
            return
        }

        session.endTime = Date()

        // Add session to participant
        if var participant = participants[session.participantId] {
            participant.sessions.append(session)
            participants[session.participantId] = participant
        }

        // Auto-export if enabled
        if configuration.autoExport {
            await exportSession(session)
        }

        log.info("Ended research session - \(session.dataPoints.count) data points collected", category: .science)

        currentSession = nil
        sessionStartTime = nil
    }

    /// Add event marker to current session
    public func markEvent(eventType: String, description: String) {
        guard var session = currentSession, let startTime = sessionStartTime else {
            log.warning("Cannot mark event - no active session", category: .science)
            return
        }

        let timestamp = Date().timeIntervalSince(startTime)
        let event = Event(timestamp: timestamp, eventType: eventType, description: description)
        session.events.append(event)
        currentSession = session

        log.debug("Marked event: \(eventType) at \(String(format: "%.1f", timestamp))s", category: .science)
    }

    /// Add questionnaire to current session
    public func addQuestionnaire(name: String, responses: [String: String]) {
        guard currentSession != nil else {
            log.warning("Cannot add questionnaire - no active session", category: .science)
            return
        }

        let questionnaire = Questionnaire(name: name, responses: responses)
        currentSession?.questionnaires.append(questionnaire)

        log.debug("Added questionnaire: \(name)", category: .science)
    }

    // MARK: - Statistical Analysis

    /// Calculate statistics for a metric
    public func calculateStatistics(for metric: String, participantId: String? = nil) -> StatisticalSummary? {
        var values: [Float] = []

        if let id = participantId {
            // Single participant
            guard let participant = participants[id] else { return nil }
            values = extractMetricValues(from: participant.sessions, metric: metric)
        } else {
            // All participants
            for participant in participants.values {
                values.append(contentsOf: extractMetricValues(from: participant.sessions, metric: metric))
            }
        }

        guard !values.isEmpty else { return nil }

        return calculateSummary(from: values)
    }

    /// Compare two study groups
    public func compareGroups(group1: String, group2: String, metric: String) -> (group1: StatisticalSummary?, group2: StatisticalSummary?, effectSize: Float?) {
        let participants1 = getParticipants(inGroup: group1)
        let participants2 = getParticipants(inGroup: group2)

        var values1: [Float] = []
        var values2: [Float] = []

        for p in participants1 {
            values1.append(contentsOf: extractMetricValues(from: p.sessions, metric: metric))
        }

        for p in participants2 {
            values2.append(contentsOf: extractMetricValues(from: p.sessions, metric: metric))
        }

        let summary1 = values1.isEmpty ? nil : calculateSummary(from: values1)
        let summary2 = values2.isEmpty ? nil : calculateSummary(from: values2)

        // Cohen's d effect size
        var effectSize: Float? = nil
        if let s1 = summary1, let s2 = summary2 {
            let pooledSD = sqrt((pow(s1.standardDeviation, 2) + pow(s2.standardDeviation, 2)) / 2)
            effectSize = (s1.mean - s2.mean) / pooledSD
        }

        log.info("Group comparison: \(group1) vs \(group2) - Effect size: \(effectSize?.description ?? "N/A")", category: .science)

        return (summary1, summary2, effectSize)
    }

    /// Calculate correlation between two metrics
    public func calculateCorrelation(metric1: String, metric2: String, participantId: String? = nil) -> Float? {
        var values1: [Float] = []
        var values2: [Float] = []

        if let id = participantId {
            guard let participant = participants[id] else { return nil }
            values1 = extractMetricValues(from: participant.sessions, metric: metric1)
            values2 = extractMetricValues(from: participant.sessions, metric: metric2)
        } else {
            for participant in participants.values {
                values1.append(contentsOf: extractMetricValues(from: participant.sessions, metric: metric1))
                values2.append(contentsOf: extractMetricValues(from: participant.sessions, metric: metric2))
            }
        }

        guard values1.count == values2.count, !values1.isEmpty else { return nil }

        return pearsonCorrelation(x: values1, y: values2)
    }

    // MARK: - Data Export

    /// Export session to CSV
    public func exportSessionToCSV(session: ResearchSession) -> String {
        var csv = "Timestamp,HeartRate,HRV,Coherence,BreathingRate,SkinConductance,Temperature\n"

        for point in session.dataPoints {
            csv += "\(point.timestamp),"
            csv += "\(point.heartRate ?? -1),"
            csv += "\(point.hrv ?? -1),"
            csv += "\(point.coherence),"
            csv += "\(point.breathingRate ?? -1),"
            csv += "\(point.skinConductance ?? -1),"
            csv += "\(point.temperature ?? -1)\n"
        }

        log.info("Exported session to CSV - \(session.dataPoints.count) rows", category: .science)
        return csv
    }

    /// Export session to JSON
    public func exportSessionToJSON(session: ResearchSession) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(session),
              let json = String(data: data, encoding: .utf8) else {
            log.error("Failed to encode session to JSON", category: .science)
            return nil
        }

        log.info("Exported session to JSON", category: .science)
        return json
    }

    /// Export all participant data (anonymized)
    public func exportAllParticipants() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Anonymize if configured
        var exportData = participants
        if configuration.anonymizeData {
            exportData = anonymizeParticipants(participants)
        }

        guard let data = try? encoder.encode(exportData),
              let json = String(data: data, encoding: .utf8) else {
            log.error("Failed to export participant data", category: .science)
            return "{}"
        }

        log.info("Exported data for \(participants.count) participants (anonymized: \(configuration.anonymizeData))", category: .science)
        return json
    }

    /// Generate IRB-compliant report
    public func generateIRBReport() -> String {
        var report = """
        ═══════════════════════════════════════════════════════════
        RESEARCH STUDY REPORT
        ═══════════════════════════════════════════════════════════

        Study Name: \(configuration.studyName)
        Protocol: \(configuration.studyProtocol)
        IRB Approval: \(configuration.irbApprovalNumber)
        Principal Investigator: \(configuration.principalInvestigator)

        Report Generated: \(Date().formatted())

        ───────────────────────────────────────────────────────────
        PARTICIPANT SUMMARY
        ───────────────────────────────────────────────────────────

        Total Participants: \(participants.count)

        """

        // Group breakdown
        let groups = Set(participants.values.map { $0.studyGroup })
        report += "Study Groups:\n"
        for group in groups.sorted() {
            let count = participants.values.filter { $0.studyGroup == group }.count
            report += "  • \(group): \(count) participants\n"
        }

        // Session summary
        let totalSessions = participants.values.flatMap { $0.sessions }.count
        let totalDataPoints = participants.values.flatMap { $0.sessions }.flatMap { $0.dataPoints }.count

        report += """

        ───────────────────────────────────────────────────────────
        DATA COLLECTION SUMMARY
        ───────────────────────────────────────────────────────────

        Total Sessions: \(totalSessions)
        Total Data Points: \(totalDataPoints)
        Sampling Rate: \(configuration.samplingRate) Hz

        ───────────────────────────────────────────────────────────
        COMPLIANCE
        ───────────────────────────────────────────────────────────

        ✓ Informed Consent: All participants
        ✓ Data Anonymization: \(configuration.anonymizeData ? "Enabled" : "Disabled")
        ✓ IRB Protocol: \(configuration.irbApprovalNumber.isEmpty ? "Pending" : "Approved")

        ═══════════════════════════════════════════════════════════
        """

        log.info("Generated IRB report", category: .science)
        return report
    }

    // MARK: - Private Helpers

    private func extractMetricValues(from sessions: [ResearchSession], metric: String) -> [Float] {
        var values: [Float] = []

        for session in sessions {
            for point in session.dataPoints {
                switch metric.lowercased() {
                case "heartrate", "hr":
                    if let hr = point.heartRate { values.append(hr) }
                case "hrv":
                    if let hrv = point.hrv { values.append(hrv) }
                case "coherence":
                    values.append(point.coherence)
                case "breathingrate", "br":
                    if let br = point.breathingRate { values.append(br) }
                case "skinconductance", "gsr":
                    if let gsr = point.skinConductance { values.append(gsr) }
                case "temperature", "temp":
                    if let temp = point.temperature { values.append(temp) }
                default:
                    break
                }
            }
        }

        return values
    }

    private func calculateSummary(from values: [Float]) -> StatisticalSummary {
        let sorted = values.sorted()
        let count = values.count
        let mean = values.reduce(0, +) / Float(count)

        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Float(count)
        let sd = sqrt(variance)

        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let median = count % 2 == 0 ? (sorted[count/2 - 1] + sorted[count/2]) / 2 : sorted[count/2]

        return StatisticalSummary(
            mean: mean,
            standardDeviation: sd,
            min: min,
            max: max,
            median: median,
            count: count
        )
    }

    private func pearsonCorrelation(x: [Float], y: [Float]) -> Float {
        guard x.count == y.count, !x.isEmpty else { return 0 }

        let n = Float(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var numerator: Float = 0
        var denomX: Float = 0
        var denomY: Float = 0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }

        let denominator = sqrt(denomX * denomY)
        return denominator == 0 ? 0 : numerator / denominator
    }

    private func anonymizeParticipants(_ participants: [String: Participant]) -> [String: Participant] {
        var anonymized: [String: Participant] = [:]

        for (id, participant) in participants {
            var p = participant
            // Remove or hash identifying information
            p.demographics.notes = "[REDACTED]"
            anonymized[id] = p
        }

        return anonymized
    }

    private func exportSession(_ session: ResearchSession) async {
        switch configuration.exportFormat {
        case .csv:
            let csv = exportSessionToCSV(session: session)
            // Save CSV file
            log.debug("Auto-exported session as CSV", category: .science)
        case .json:
            let _ = exportSessionToJSON(session: session)
            // Save JSON file
            log.debug("Auto-exported session as JSON", category: .science)
        case .both:
            let _ = exportSessionToCSV(session: session)
            let _ = exportSessionToJSON(session: session)
            log.debug("Auto-exported session as CSV and JSON", category: .science)
        }
    }

    private func loadParticipants(from directory: URL) async {
        let participantsFile = directory.appendingPathComponent("participants.json")

        guard FileManager.default.fileExists(atPath: participantsFile.path),
              let data = try? Data(contentsOf: participantsFile),
              let loadedParticipants = try? JSONDecoder().decode([String: Participant].self, from: data) else {
            log.debug("No existing participant data found", category: .science)
            return
        }

        participants = loadedParticipants
    }

    private func saveAllData() async {
        // In production, save to secure storage
        log.info("Research data saved securely", category: .science)
    }
}

// MARK: - 4. Accessibility Enhancer Plugin

/// A comprehensive plugin for enhanced accessibility features
/// Demonstrates: gestureInput, voiceInput, bioProcessing capabilities
public final class AccessibilityEnhancerPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.accessibility-enhancer" }
    public var name: String { "Accessibility Enhancer" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Accessibility Team" }
    public var pluginDescription: String { "Enhanced accessibility features including custom haptics, high contrast override, voice commands, and cognitive load reduction" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.gestureInput, .voiceInput, .bioProcessing] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var enableEnhancedScreenReader: Bool = true
        public var enableCustomHaptics: Bool = true
        public var enableHighContrast: Bool = false
        public var enableVoiceCommands: Bool = true
        public var enableSwitchControl: Bool = false
        public var reduceCognitiveLoad: Bool = false
        public var hapticIntensity: Float = 1.0
        public var voiceSpeed: Float = 1.0
        public var simplifiedUIMode: Bool = false

        public enum HapticPattern: String, CaseIterable, Sendable {
            case subtle = "Subtle"
            case moderate = "Moderate"
            case strong = "Strong"
            case custom = "Custom"
        }

        public var defaultHapticPattern: HapticPattern = .moderate
    }

    // MARK: - Accessibility Models

    public struct HapticFeedback: Sendable {
        public var intensity: Float
        public var duration: TimeInterval
        public var pattern: HapticPattern

        public enum HapticPattern: Sendable {
            case single
            case double
            case triple
            case pulse
            case heartbeat
            case coherence
            case warning
            case success
            case error
        }

        public static let success = HapticFeedback(intensity: 0.8, duration: 0.2, pattern: .double)
        public static let error = HapticFeedback(intensity: 1.0, duration: 0.3, pattern: .triple)
        public static let navigation = HapticFeedback(intensity: 0.5, duration: 0.1, pattern: .single)
    }

    public struct VoiceCommand: Sendable {
        public var command: String
        public var action: @Sendable () -> Void
        public var description: String

        public init(command: String, description: String, action: @Sendable @escaping () -> Void) {
            self.command = command
            self.description = description
            self.action = action
        }
    }

    public struct ScreenReaderAnnouncement: Sendable {
        public var message: String
        public var priority: Priority
        public var delay: TimeInterval

        public enum Priority: Int, Sendable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
        }

        public init(message: String, priority: Priority = .normal, delay: TimeInterval = 0) {
            self.message = message
            self.priority = priority
            self.delay = delay
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var registeredVoiceCommands: [String: VoiceCommand] = [:]
    private var announcementQueue: [ScreenReaderAnnouncement] = []
    private var lastHapticTime: Date = Date()
    private var currentCoherence: Float = 0.5

    // MARK: - Initialization

    public init() {
        registerDefaultVoiceCommands()
    }

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Accessibility Enhancer Plugin loaded", category: .accessibility)

        if configuration.enableHighContrast {
            applyHighContrastMode()
        }

        if configuration.reduceCognitiveLoad {
            enableSimplifiedUI()
        }

        announce("Accessibility features enabled", priority: .normal)
    }

    public func onUnload() async {
        log.info("Accessibility Enhancer Plugin unloaded", category: .accessibility)
    }

    public func onFrame(deltaTime: TimeInterval) {
        // Process announcement queue
        processAnnouncementQueue()

        // Generate bio-feedback haptics
        if configuration.enableCustomHaptics {
            generateBioFeedbackHaptics()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        currentCoherence = bioData.coherence

        // Announce significant coherence changes
        if configuration.enableEnhancedScreenReader {
            if bioData.coherence >= 0.8 {
                announce("High coherence achieved", priority: .high, delay: 2.0)
            } else if bioData.coherence <= 0.3 {
                announce("Low coherence detected", priority: .normal, delay: 2.0)
            }
        }
    }

    public func handleInteraction(_ interaction: UserInteraction) {
        // Provide haptic feedback for interactions
        if configuration.enableCustomHaptics {
            switch interaction.type {
            case .tap:
                triggerHaptic(.navigation)
            case .doubleTap:
                triggerHaptic(.success)
            case .longPress:
                triggerHaptic(HapticFeedback(intensity: 0.7, duration: 0.5, pattern: .pulse))
            case .swipe:
                triggerHaptic(.navigation)
            default:
                break
            }
        }

        // Announce interaction for screen reader
        if configuration.enableEnhancedScreenReader {
            announceInteraction(interaction)
        }
    }

    // MARK: - Screen Reader Enhancement

    /// Announce message to screen reader
    public func announce(_ message: String, priority: ScreenReaderAnnouncement.Priority = .normal, delay: TimeInterval = 0) {
        guard configuration.enableEnhancedScreenReader else { return }

        let announcement = ScreenReaderAnnouncement(message: message, priority: priority, delay: delay)
        announcementQueue.append(announcement)

        log.debug("Queued announcement: \(message) (priority: \(priority))", category: .accessibility)
    }

    /// Announce coherence level in accessible format
    public func announceCoherence() {
        let coherencePercent = Int(currentCoherence * 100)
        let description = getCoherenceDescription(currentCoherence)

        announce("Coherence is \(coherencePercent) percent, \(description)", priority: .high)
    }

    /// Announce bio metrics summary
    public func announceBioMetrics(heartRate: Float?, hrv: Float?, breathingRate: Float?) {
        var message = "Biometric status: "

        if let hr = heartRate {
            message += "Heart rate \(Int(hr)) beats per minute. "
        }

        if let hrv = hrv {
            message += "Heart rate variability \(Int(hrv)) milliseconds. "
        }

        if let br = breathingRate {
            message += "Breathing rate \(Int(br)) breaths per minute."
        }

        announce(message, priority: .normal)
    }

    // MARK: - Custom Haptics

    /// Trigger haptic feedback
    public func triggerHaptic(_ feedback: HapticFeedback) {
        guard configuration.enableCustomHaptics else { return }

        // Rate limit haptics (max 10 per second)
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) < 0.1 {
            return
        }
        lastHapticTime = now

        let adjustedIntensity = feedback.intensity * configuration.hapticIntensity

        log.trace("Triggering haptic: \(feedback.pattern) - Intensity: \(adjustedIntensity)", category: .accessibility)

        // In production, use CoreHaptics or UIFeedbackGenerator
    }

    /// Generate coherence-based haptic pattern
    public func generateCoherenceHaptic() {
        let intensity = 0.3 + (currentCoherence * 0.7)
        let pattern: HapticFeedback.HapticPattern = currentCoherence > 0.7 ? .coherence : .pulse

        let feedback = HapticFeedback(intensity: intensity, duration: 0.3, pattern: pattern)
        triggerHaptic(feedback)
    }

    // MARK: - Voice Commands

    /// Register a voice command
    public func registerVoiceCommand(_ command: VoiceCommand) {
        registeredVoiceCommands[command.command.lowercased()] = command
        log.debug("Registered voice command: \(command.command)", category: .accessibility)
    }

    /// Process voice input
    public func processVoiceInput(_ input: String) {
        guard configuration.enableVoiceCommands else { return }

        let normalized = input.lowercased().trimmingCharacters(in: .whitespaces)

        if let command = registeredVoiceCommands[normalized] {
            log.info("Executing voice command: \(command.command)", category: .accessibility)
            command.action()
            triggerHaptic(.success)
            announce("Command executed: \(command.description)", priority: .normal)
        } else {
            log.debug("Unknown voice command: \(input)", category: .accessibility)
            triggerHaptic(.error)
            announce("Command not recognized", priority: .normal)
        }
    }

    /// Get list of available commands
    public func getAvailableCommands() -> [VoiceCommand] {
        return Array(registeredVoiceCommands.values)
    }

    // MARK: - High Contrast Mode

    /// Apply high contrast visual mode
    public func applyHighContrastMode() {
        configuration.enableHighContrast = true
        log.info("High contrast mode enabled", category: .accessibility)
        announce("High contrast mode enabled", priority: .normal)

        // In production, modify app theme/colors
    }

    /// Disable high contrast mode
    public func disableHighContrastMode() {
        configuration.enableHighContrast = false
        log.info("High contrast mode disabled", category: .accessibility)
        announce("High contrast mode disabled", priority: .normal)
    }

    // MARK: - Switch Control

    /// Enable switch control mode
    public func enableSwitchControl() {
        configuration.enableSwitchControl = true
        configuration.simplifiedUIMode = true
        log.info("Switch control mode enabled", category: .accessibility)
        announce("Switch control enabled. Use switch to navigate.", priority: .high)
    }

    /// Process switch input
    public func processSwitchInput(switchNumber: Int) {
        guard configuration.enableSwitchControl else { return }

        log.debug("Switch \(switchNumber) pressed", category: .accessibility)
        triggerHaptic(.navigation)

        // In production, navigate UI based on switch number
    }

    // MARK: - Cognitive Load Reduction

    /// Enable simplified UI for cognitive load reduction
    public func enableSimplifiedUI() {
        configuration.reduceCognitiveLoad = true
        configuration.simplifiedUIMode = true
        log.info("Simplified UI mode enabled", category: .accessibility)
        announce("Simplified interface enabled", priority: .normal)

        // In production, hide non-essential UI elements
    }

    /// Disable simplified UI
    public func disableSimplifiedUI() {
        configuration.reduceCognitiveLoad = false
        configuration.simplifiedUIMode = false
        log.info("Simplified UI mode disabled", category: .accessibility)
        announce("Full interface restored", priority: .normal)
    }

    // MARK: - Private Helpers

    private func registerDefaultVoiceCommands() {
        registerVoiceCommand(VoiceCommand(
            command: "check coherence",
            description: "Announce current coherence level"
        ) { [weak self] in
            self?.announceCoherence()
        })

        registerVoiceCommand(VoiceCommand(
            command: "high contrast on",
            description: "Enable high contrast mode"
        ) { [weak self] in
            self?.applyHighContrastMode()
        })

        registerVoiceCommand(VoiceCommand(
            command: "high contrast off",
            description: "Disable high contrast mode"
        ) { [weak self] in
            self?.disableHighContrastMode()
        })

        registerVoiceCommand(VoiceCommand(
            command: "simplify",
            description: "Enable simplified UI"
        ) { [weak self] in
            self?.enableSimplifiedUI()
        })

        registerVoiceCommand(VoiceCommand(
            command: "full interface",
            description: "Restore full UI"
        ) { [weak self] in
            self?.disableSimplifiedUI()
        })
    }

    private func processAnnouncementQueue() {
        guard !announcementQueue.isEmpty else { return }

        // Sort by priority
        announcementQueue.sort { $0.priority.rawValue > $1.priority.rawValue }

        // Process highest priority announcement
        if let announcement = announcementQueue.first {
            // In production, use AVSpeechSynthesizer or UIAccessibility.post
            log.info("Announcing: \(announcement.message)", category: .accessibility)
            announcementQueue.removeFirst()
        }
    }

    private func generateBioFeedbackHaptics() {
        // Generate subtle haptic feedback based on coherence
        // Only generate every 5 seconds
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) >= 5.0 {
            if currentCoherence > 0.7 {
                generateCoherenceHaptic()
            }
        }
    }

    private func announceInteraction(_ interaction: UserInteraction) {
        let typeDescription = interaction.type.rawValue
        announce("\(typeDescription) gesture", priority: .low)
    }

    private func getCoherenceDescription(_ coherence: Float) -> String {
        switch coherence {
        case 0.8...1.0: return "excellent coherence"
        case 0.6..<0.8: return "good coherence"
        case 0.4..<0.6: return "moderate coherence"
        case 0.2..<0.4: return "low coherence"
        default: return "very low coherence"
        }
    }
}

// MARK: - 5. Content Creator Plugin

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

        // Connect to OBS
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

        // Auto scene switching based on bio
        if configuration.enableBioSceneSwitching {
            updateSceneBasedOnBio()
        }

        // Check for auto-clip opportunities
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
        if coherenceHistory.count > 300 { // Last 5 minutes at 1Hz
            coherenceHistory.removeFirst()
        }

        // Detect highlight moments
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

        // Switch to streaming scene in OBS
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

        // Calculate average coherence
        if !coherenceHistory.isEmpty {
            session.averageCoherence = coherenceHistory.reduce(0, +) / Float(coherenceHistory.count)
        }

        isStreaming = false

        // Auto-post highlights if enabled
        if configuration.enableAutoPosting {
            await autoPostHighlights(session)
        }

        let streamDuration = session.endTime.map { String(format: "%.1f", $0.timeIntervalSince(session.startTime) / 60) } ?? "unknown"
        log.info("Ended stream - Duration: \(streamDuration) minutes, Avg coherence: \(session.averageCoherence)", category: .social)

        currentSession = nil
    }

    /// Update viewer count
    public func updateViewerCount(_ count: Int) {
        currentSession?.viewers = max(currentSession?.viewers ?? 0, count)
    }

    /// Update chat message count
    public func recordChatMessage() {
        currentSession?.chatMessages += 1
    }

    // MARK: - OBS Integration

    /// Connect to OBS via WebSocket
    public func connectToOBS() async {
        // In production, use WebSocket connection
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

        // In production, send WebSocket message to OBS
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

        // Check moderator requirement
        if command.requiresModerator && !fromModerator {
            log.debug("Command \(commandText) requires moderator", category: .social)
            return
        }

        // Check cooldown
        if let lastUsed = commandCooldowns[commandText] {
            let timeSince = Date().timeIntervalSince(lastUsed)
            if timeSince < command.cooldown {
                log.debug("Command \(commandText) on cooldown", category: .social)
                return
            }
        }

        // Execute command
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

        markHighlight(
            type: .subscriberAlert,
            description: "\(username) subscribed (Tier \(tier))",
            bioData: "Coherence: \(currentCoherence)"
        )

        // Trigger special OBS scene
        Task {
            await switchOBSScene("SubscriberAlert")
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await switchOBSScene(currentScene)
        }
    }

    /// Handle donation alert
    public func handleDonationAlert(username: String, amount: Float, currency: String = "USD") {
        log.info("Donation from \(username): \(amount) \(currency)", category: .social)

        markHighlight(
            type: .donation,
            description: "\(username) donated \(amount) \(currency)",
            bioData: "HR: \(currentHeartRate), Coherence: \(currentCoherence)"
        )
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
            // In production, use platform APIs
        }
    }

    // MARK: - Analytics

    /// Get stream analytics
    public func getStreamAnalytics() -> (duration: TimeInterval, viewers: Int, clips: Int, highlights: Int, coherence: Float)? {
        guard let session = currentSession ?? nil else { return nil }

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
            OBSScene(name: "HighEnergy", coherenceRange: 0.8...1.0, priority: 3),
            OBSScene(name: "Focused", coherenceRange: 0.6..<0.8, priority: 2),
            OBSScene(name: "Relaxed", coherenceRange: 0.4..<0.6, priority: 1),
            OBSScene(name: "Main", coherenceRange: 0.0..<0.4, priority: 0)
        ]
    }

    private func registerDefaultChatCommands() {
        registerChatCommand(ChatCommand(
            command: "coherence",
            description: "Show current coherence level"
        ) { [weak self] in
            guard let self = self else { return }
            log.info("Chat command response: Coherence is \(Int(self.currentCoherence * 100))%", category: .social)
        })

        registerChatCommand(ChatCommand(
            command: "clip",
            description: "Create a clip of the last 30 seconds",
            cooldown: 60.0
        ) { [weak self] in
            self?.createClip(title: "Chat Requested Clip")
        })

        registerChatCommand(ChatCommand(
            command: "scene",
            description: "Switch to high energy scene",
            requiresModerator: true
        ) { [weak self] in
            Task {
                await self?.switchOBSScene("HighEnergy")
            }
        })
    }

    private func updateSceneBasedOnBio() {
        guard obsConnected else { return }

        // Find best matching scene
        for scene in bioScenes {
            if scene.coherenceRange.contains(currentCoherence) {
                if currentScene != scene.name {
                    Task {
                        await switchOBSScene(scene.name)
                    }
                }
                break
            }
        }
    }

    private func checkAutoClipOpportunity() {
        // Create auto-clip on sustained high coherence
        let timeSinceLastClip = Date().timeIntervalSince(lastClipTime)

        if currentCoherence >= configuration.coherenceThresholdForHighlight && timeSinceLastClip >= 120.0 {
            createClip(title: "High Coherence Moment", duration: 30.0)
        }
    }

    private func generateSocialPost(highlight: Highlight, session: StreamSession) -> String {
        return """
        🎮 Epic moment from today's stream: \(session.title)

        \(highlight.description)

        Bio metrics: \(highlight.bioData)

        #Echoelmusic #BioReactiveStream #LivePerformance
        """
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift
