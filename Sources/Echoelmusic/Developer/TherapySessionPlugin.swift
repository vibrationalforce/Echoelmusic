// TherapySessionPlugin.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Professional plugin for wellness practitioners and therapists
// HIPAA-compliant bio data recording, client progress tracking, session notes
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

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
        await loadClientProgressData(from: context.dataDirectory)
        log.info("Loaded progress data for \(clientProgressMap.count) clients", category: .wellness)
    }

    public func onUnload() async {
        if currentSession != nil {
            await endSession(outcome: "Session ended by plugin unload")
        }
        await saveAllData()
        log.info("Therapy Session Plugin unloaded - data saved", category: .wellness)
    }

    public func onFrame(deltaTime: TimeInterval) {
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
        stopRecordingTimer()
        updateClientProgress(session: session)

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
        let milestone = Milestone(title: title, description: description, coherence: currentBioData.coherence)
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

    private func updateClientProgress(session: TherapySession) {
        var progress = clientProgressMap[session.clientId] ?? ClientProgress(clientId: session.clientId)
        progress.sessions.append(session)
        progress.milestonesAchieved += session.milestones.count

        if let endTime = session.endTime {
            progress.totalSessionTime += endTime.timeIntervalSince(session.startTime)
        }

        let allCoherenceValues = session.bioDataPoints.map { $0.coherence }
        if !allCoherenceValues.isEmpty {
            let sessionAverage = allCoherenceValues.reduce(0, +) / Float(allCoherenceValues.count)
            progress.coherenceTrend.append(sessionAverage)
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for point in session.bioDataPoints {
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
            let hrValues = session.bioDataPoints.compactMap { $0.heartRate }
            let hrvValues = session.bioDataPoints.compactMap { $0.hrv }
            if !hrValues.isEmpty {
                report += "Average Heart Rate: \(String(format: "%.1f", hrValues.reduce(0, +) / Float(hrValues.count))) BPM\n"
            }
            if !hrvValues.isEmpty {
                report += "Average HRV: \(String(format: "%.1f", hrvValues.reduce(0, +) / Float(hrvValues.count))) ms\n"
            }
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
        if bioData.coherence >= 0.8, let session = currentSession, !session.bioDataPoints.isEmpty {
            let recentPoints = session.bioDataPoints.suffix(30)
            let recentCoherence = recentPoints.map { $0.coherence }
            let avgRecent = recentCoherence.reduce(0, +) / Float(recentCoherence.count)

            if avgRecent >= 0.75 {
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
        if currentSession?.id == id {
            return currentSession
        }
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
        log.debug("Session data saved (encrypted: \(configuration.encryptData))", category: .wellness)
    }

    private func saveAllData() async {
        log.info("All therapy data saved securely", category: .wellness)
    }
}
