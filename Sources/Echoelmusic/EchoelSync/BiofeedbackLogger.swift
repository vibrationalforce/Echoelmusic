//
//  BiofeedbackLogger.swift
//  Echoelmusic
//
//  Biofeedback data logging and session tracking
//  Records bio-signals for analysis and playback synchronization
//
//  Note: Audio recording is delegated to DAWs (Ableton, Logic, etc.)
//  This module ONLY handles biometric data capture.
//

import Foundation
import Combine

// MARK: - Biofeedback Logger

/// Records biometric data during sessions
/// Synchronized with external DAW recordings via timecode
@MainActor
final class BiofeedbackLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = BiofeedbackLogger()

    // MARK: - Published State

    @Published var isLogging = false
    @Published var currentSession: BiofeedbackSession?
    @Published var sessionDuration: TimeInterval = 0

    // MARK: - Private Properties

    private var logTimer: Timer?
    private var startTime: Date?
    private let logInterval: TimeInterval = 0.1 // 10 Hz logging rate

    /// Storage directory
    private let logsDirectory: URL

    // MARK: - Initialization

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logsDirectory = documentsPath.appendingPathComponent("BiofeedbackLogs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        print("📊 BiofeedbackLogger initialized")
    }

    // MARK: - Session Control

    /// Start a new biofeedback logging session
    func startSession(name: String? = nil) -> BiofeedbackSession {
        let session = BiofeedbackSession(
            name: name ?? "Session \(Date().formatted(date: .abbreviated, time: .shortened))"
        )

        currentSession = session
        startTime = Date()
        isLogging = true
        sessionDuration = 0

        // Start logging timer
        logTimer = Timer.scheduledTimer(withTimeInterval: logInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logCurrentBioState()
            }
        }

        print("📊 Biofeedback session started: \(session.name)")
        return session
    }

    /// Stop logging session
    func stopSession() -> BiofeedbackSession? {
        logTimer?.invalidate()
        logTimer = nil
        isLogging = false

        guard var session = currentSession else { return nil }

        session.endTime = Date()
        session.duration = sessionDuration

        // Calculate statistics
        session.statistics = calculateStatistics(session)

        // Auto-save
        try? saveSession(session)

        print("📊 Biofeedback session ended: \(session.name) (\(String(format: "%.1f", sessionDuration))s)")

        let completedSession = session
        currentSession = nil
        return completedSession
    }

    /// Pause logging (e.g., during breaks)
    func pauseLogging() {
        logTimer?.invalidate()
        isLogging = false
    }

    /// Resume logging
    func resumeLogging() {
        guard currentSession != nil else { return }

        isLogging = true
        logTimer = Timer.scheduledTimer(withTimeInterval: logInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logCurrentBioState()
            }
        }
    }

    // MARK: - Data Logging

    private func logCurrentBioState() {
        guard var session = currentSession else { return }

        let bioState = EchoelSync.shared.bioState
        let timestamp = Date().timeIntervalSince(startTime ?? Date())
        sessionDuration = timestamp

        let dataPoint = BioDataPoint(
            timestamp: timestamp,
            heartRate: bioState.heartRate,
            hrvSDNN: bioState.hrvSDNN,
            coherence: Double(bioState.coherenceScore),
            breathingRate: Double(bioState.breathingRate),
            breathPhase: Double(bioState.breathPhase),
            motionEnergy: Double(bioState.motionEnergy),
            flowState: Double(bioState.flowState),
            arousal: Double(bioState.arousal),
            valence: Double(bioState.valence)
        )

        session.dataPoints.append(dataPoint)
        currentSession = session
    }

    // MARK: - Manual Data Point Addition

    /// Add data point manually (e.g., from external sensor)
    func addDataPoint(
        heartRate: Double? = nil,
        hrv: Double? = nil,
        coherence: Double? = nil,
        breathRate: Double? = nil,
        custom: [String: Double]? = nil
    ) {
        guard var session = currentSession else { return }

        let bioState = EchoelSync.shared.bioState
        let timestamp = Date().timeIntervalSince(startTime ?? Date())

        var dataPoint = BioDataPoint(
            timestamp: timestamp,
            heartRate: heartRate ?? bioState.heartRate,
            hrvSDNN: hrv ?? bioState.hrvSDNN,
            coherence: coherence ?? Double(bioState.coherenceScore),
            breathingRate: breathRate ?? Double(bioState.breathingRate),
            breathPhase: Double(bioState.breathPhase),
            motionEnergy: Double(bioState.motionEnergy),
            flowState: Double(bioState.flowState),
            arousal: Double(bioState.arousal),
            valence: Double(bioState.valence)
        )

        dataPoint.customValues = custom

        session.dataPoints.append(dataPoint)
        currentSession = session
    }

    // MARK: - Session Statistics

    private func calculateStatistics(_ session: BiofeedbackSession) -> BiofeedbackSession.Statistics {
        guard !session.dataPoints.isEmpty else {
            return BiofeedbackSession.Statistics()
        }

        let heartRates = session.dataPoints.map { $0.heartRate }
        let hrvValues = session.dataPoints.map { $0.hrvSDNN }
        let coherenceValues = session.dataPoints.map { $0.coherence }
        let flowValues = session.dataPoints.map { $0.flowState }

        return BiofeedbackSession.Statistics(
            averageHeartRate: heartRates.reduce(0, +) / Double(heartRates.count),
            minHeartRate: heartRates.min() ?? 0,
            maxHeartRate: heartRates.max() ?? 0,
            averageHRV: hrvValues.reduce(0, +) / Double(hrvValues.count),
            averageCoherence: coherenceValues.reduce(0, +) / Double(coherenceValues.count),
            peakCoherence: coherenceValues.max() ?? 0,
            coherenceTime: calculateTimeAboveThreshold(coherenceValues, threshold: 0.5),
            averageFlowState: flowValues.reduce(0, +) / Double(flowValues.count),
            flowStateTime: calculateTimeAboveThreshold(flowValues, threshold: 0.6),
            dataPointCount: session.dataPoints.count
        )
    }

    private func calculateTimeAboveThreshold(_ values: [Double], threshold: Double) -> TimeInterval {
        let aboveCount = values.filter { $0 >= threshold }.count
        return TimeInterval(aboveCount) * logInterval
    }

    // MARK: - Persistence

    /// Save session to disk
    func saveSession(_ session: BiofeedbackSession) throws {
        let fileURL = logsDirectory.appendingPathComponent("\(session.id.uuidString).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(session)
        try data.write(to: fileURL)

        print("💾 Saved biofeedback session: \(session.name)")
    }

    /// Load session from disk
    func loadSession(id: UUID) throws -> BiofeedbackSession {
        let fileURL = logsDirectory.appendingPathComponent("\(id.uuidString).json")

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(BiofeedbackSession.self, from: data)
    }

    /// List all saved sessions
    func listSessions() -> [BiofeedbackSessionSummary] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BiofeedbackSessionSummary? in
                guard let data = try? Data(contentsOf: url),
                      let session = try? JSONDecoder().decode(BiofeedbackSession.self, from: data) else {
                    return nil
                }

                return BiofeedbackSessionSummary(
                    id: session.id,
                    name: session.name,
                    startTime: session.startTime,
                    duration: session.duration,
                    averageCoherence: session.statistics.averageCoherence
                )
            }
            .sorted { $0.startTime > $1.startTime }
    }

    /// Delete session
    func deleteSession(id: UUID) throws {
        let fileURL = logsDirectory.appendingPathComponent("\(id.uuidString).json")
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Export

    /// Export session to CSV (for analysis in Excel, etc.)
    func exportToCSV(_ session: BiofeedbackSession) throws -> URL {
        var csv = "timestamp,heart_rate,hrv_sdnn,coherence,breathing_rate,breath_phase,motion_energy,flow_state,arousal,valence\n"

        for point in session.dataPoints {
            csv += "\(point.timestamp),\(point.heartRate),\(point.hrvSDNN),\(point.coherence),"
            csv += "\(point.breathingRate),\(point.breathPhase),\(point.motionEnergy),"
            csv += "\(point.flowState),\(point.arousal),\(point.valence)\n"
        }

        let fileURL = logsDirectory.appendingPathComponent("\(session.id.uuidString).csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    /// Export session to OSC log (for replay in TouchDesigner/Max)
    func exportToOSCLog(_ session: BiofeedbackSession) throws -> URL {
        var oscLog = "# EchoelSync OSC Log\n"
        oscLog += "# Session: \(session.name)\n"
        oscLog += "# Date: \(session.startTime.ISO8601Format())\n\n"

        for point in session.dataPoints {
            oscLog += "\(String(format: "%.3f", point.timestamp)) /echoelmusic/bio/heart/bpm \(point.heartRate)\n"
            oscLog += "\(String(format: "%.3f", point.timestamp)) /echoelmusic/bio/heart/hrv \(point.hrvSDNN / 100.0)\n"
            oscLog += "\(String(format: "%.3f", point.timestamp)) /echoelmusic/bio/heart/coherence \(point.coherence)\n"
            oscLog += "\(String(format: "%.3f", point.timestamp)) /echoelmusic/bio/breath/rate \(point.breathingRate)\n"
            oscLog += "\(String(format: "%.3f", point.timestamp)) /echoelmusic/bio/flow \(point.flowState)\n"
        }

        let fileURL = logsDirectory.appendingPathComponent("\(session.id.uuidString)_osc.txt")
        try oscLog.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }
}

// MARK: - Data Models

/// Single biofeedback data point
struct BioDataPoint: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval

    // Core biometrics
    var heartRate: Double           // BPM
    var hrvSDNN: Double             // ms
    var coherence: Double           // 0-1

    // Breathing
    var breathingRate: Double       // breaths/min
    var breathPhase: Double         // 0-1

    // Activity
    var motionEnergy: Double        // 0-1

    // Derived
    var flowState: Double           // 0-1
    var arousal: Double             // 0-1
    var valence: Double             // 0-1

    // Custom values for extensibility
    var customValues: [String: Double]?
}

/// Biofeedback recording session
struct BiofeedbackSession: Codable, Identifiable {
    let id: UUID
    var name: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var dataPoints: [BioDataPoint]
    var statistics: Statistics
    var metadata: Metadata

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.startTime = Date()
        self.duration = 0
        self.dataPoints = []
        self.statistics = Statistics()
        self.metadata = Metadata()
    }

    struct Statistics: Codable {
        var averageHeartRate: Double = 0
        var minHeartRate: Double = 0
        var maxHeartRate: Double = 0
        var averageHRV: Double = 0
        var averageCoherence: Double = 0
        var peakCoherence: Double = 0
        var coherenceTime: TimeInterval = 0    // Time spent above 0.5 coherence
        var averageFlowState: Double = 0
        var flowStateTime: TimeInterval = 0    // Time spent in flow
        var dataPointCount: Int = 0
    }

    struct Metadata: Codable {
        var tags: [String] = []
        var notes: String = ""
        var dawProject: String?                // Associated DAW project name
        var dawTimecodeOffset: TimeInterval?   // Sync offset with DAW
    }
}

/// Lightweight session summary for listing
struct BiofeedbackSessionSummary: Identifiable {
    let id: UUID
    let name: String
    let startTime: Date
    let duration: TimeInterval
    let averageCoherence: Double
}
