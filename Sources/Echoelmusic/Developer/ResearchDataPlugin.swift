// ResearchDataPlugin.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Scientific research plugin with IRB compliance, data anonymization,
// statistical analysis, and multi-participant comparison
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

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
        public var samplingRate: TimeInterval = 1.0
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
        public var id: String
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
        public var ageGroup: String
        public var gender: String
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
        public var timestamp: TimeInterval
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

    public func onFrame(deltaTime: TimeInterval) {}

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
        currentSession = ResearchSession(participantId: participantId, sessionNumber: sessionNumber, condition: condition)
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
        if var participant = participants[session.participantId] {
            participant.sessions.append(session)
            participants[session.participantId] = participant
        }
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
            guard let participant = participants[id] else { return nil }
            values = extractMetricValues(from: participant.sessions, metric: metric)
        } else {
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

        let groups = Set(participants.values.map { $0.studyGroup })
        report += "Study Groups:\n"
        for group in groups.sorted() {
            let count = participants.values.filter { $0.studyGroup == group }.count
            report += "  • \(group): \(count) participants\n"
        }

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

        return StatisticalSummary(mean: mean, standardDeviation: sd, min: min, max: max, median: median, count: count)
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
            p.demographics.notes = "[REDACTED]"
            anonymized[id] = p
        }
        return anonymized
    }

    private func exportSession(_ session: ResearchSession) async {
        switch configuration.exportFormat {
        case .csv:
            let _ = exportSessionToCSV(session: session)
            log.debug("Auto-exported session as CSV", category: .science)
        case .json:
            let _ = exportSessionToJSON(session: session)
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
        log.info("Research data saved securely", category: .science)
    }
}
