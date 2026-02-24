// ScienceDataExport.swift
// Echoelmusic — Science-Grade CSV/JSON Data Export
//
// Research-quality export of biometric, audio, and session data for scientific analysis.
// Supports CSV (tabular), JSON (structured), and bundled export packages.
//
// Output includes:
//   - Time-series bio data (HRV, HR, coherence, breathing) at sample resolution
//   - Descriptive statistics (mean, SD, min, max, RMSSD, pNN50)
//   - Spectral analysis summaries (LF/HF ratio, dominant frequencies)
//   - Session metadata (protocol, duration, participant ID)
//   - Audio feature time-series (spectral centroid, RMS, pitch)
//   - ISO 8601 timestamps, UTC timezone
//
// DISCLAIMER: For research and education only. Not a certified medical device.
//
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

// MARK: - Science Data Point

/// A single timestamped biometric observation
public struct ScienceDataPoint: Codable {
    /// Seconds since session start
    public let timestamp: Double
    /// ISO 8601 wall-clock time
    public let wallClock: String
    /// Heart rate (bpm)
    public let heartRate: Float
    /// HRV RMSSD (ms)
    public let hrvRMSSD: Float
    /// HeartMath-style coherence score (0-100)
    public let coherence: Float
    /// Breathing rate (breaths/min), NaN-safe
    public let breathingRate: Float
    /// Breath phase (0-1 cycle)
    public let breathPhase: Float
    /// LF/HF ratio from spectral analysis
    public let lfHfRatio: Float
    /// Spectral centroid of audio (Hz)
    public let audioSpectralCentroid: Float
    /// Audio RMS level (0-1)
    public let audioRMS: Float
    /// Detected fundamental pitch (Hz), 0 if none
    public let audioPitch: Float
    /// Active entrainment frequency (Hz), 0 if none
    public let entrainmentFrequency: Float

    public init(
        timestamp: Double,
        wallClock: String = "",
        heartRate: Float = 0,
        hrvRMSSD: Float = 0,
        coherence: Float = 0,
        breathingRate: Float = 0,
        breathPhase: Float = 0,
        lfHfRatio: Float = 0,
        audioSpectralCentroid: Float = 0,
        audioRMS: Float = 0,
        audioPitch: Float = 0,
        entrainmentFrequency: Float = 0
    ) {
        self.timestamp = timestamp
        self.wallClock = wallClock.isEmpty ? ISO8601DateFormatter().string(from: Date()) : wallClock
        self.heartRate = heartRate
        self.hrvRMSSD = hrvRMSSD
        self.coherence = coherence
        self.breathingRate = breathingRate
        self.breathPhase = breathPhase
        self.lfHfRatio = lfHfRatio
        self.audioSpectralCentroid = audioSpectralCentroid
        self.audioRMS = audioRMS
        self.audioPitch = audioPitch
        self.entrainmentFrequency = entrainmentFrequency
    }
}

// MARK: - Session Metadata

/// Metadata for a science export session
public struct ScienceSessionMetadata: Codable {
    public var sessionID: String
    public var participantID: String
    public var protocolName: String
    public var startTime: String     // ISO 8601
    public var endTime: String       // ISO 8601
    public var durationSeconds: Double
    public var sampleRate: Float     // Bio sample rate (not audio)
    public var deviceModel: String
    public var appVersion: String
    public var notes: String

    public init(
        sessionID: String = UUID().uuidString,
        participantID: String = "anonymous",
        protocolName: String = "freeform",
        startTime: String = "",
        endTime: String = "",
        durationSeconds: Double = 0,
        sampleRate: Float = 1.0,
        deviceModel: String = "",
        appVersion: String = "",
        notes: String = ""
    ) {
        self.sessionID = sessionID
        self.participantID = participantID
        self.protocolName = protocolName
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.notes = notes
    }
}

// MARK: - Descriptive Statistics

/// Computed statistics for a set of values
public struct DescriptiveStats: Codable {
    public let count: Int
    public let mean: Float
    public let standardDeviation: Float
    public let min: Float
    public let max: Float
    public let median: Float

    public static func compute(from values: [Float]) -> DescriptiveStats {
        guard !values.isEmpty else {
            return DescriptiveStats(count: 0, mean: 0, standardDeviation: 0, min: 0, max: 0, median: 0)
        }
        let n = Float(values.count)
        let sum = values.reduce(0, +)
        let mean = sum / n
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
        let sd = sqrt(variance)
        let sorted = values.sorted()
        let median: Float
        if values.count % 2 == 0 {
            median = (sorted[values.count / 2 - 1] + sorted[values.count / 2]) / 2.0
        } else {
            median = sorted[values.count / 2]
        }
        return DescriptiveStats(
            count: values.count,
            mean: mean,
            standardDeviation: sd,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            median: median
        )
    }
}

// MARK: - HRV-Specific Statistics

/// HRV domain statistics (time-domain + frequency-domain)
public struct HRVStatistics: Codable {
    public let rmssd: Float         // Root mean square of successive differences
    public let sdnn: Float          // Standard deviation of NN intervals
    public let pnn50: Float         // % of successive intervals differing > 50ms
    public let meanRR: Float        // Mean RR interval (ms)
    public let lfPower: Float       // Low-frequency power (0.04-0.15 Hz)
    public let hfPower: Float       // High-frequency power (0.15-0.40 Hz)
    public let lfHfRatio: Float     // LF/HF ratio

    public static func compute(rrIntervals: [Float], lfPower: Float = 0, hfPower: Float = 0) -> HRVStatistics {
        guard rrIntervals.count > 1 else {
            return HRVStatistics(rmssd: 0, sdnn: 0, pnn50: 0, meanRR: 0,
                                 lfPower: lfPower, hfPower: hfPower, lfHfRatio: 0)
        }
        let n = Float(rrIntervals.count)
        let meanRR = rrIntervals.reduce(0, +) / n

        // SDNN
        let sdnn = sqrt(rrIntervals.map { ($0 - meanRR) * ($0 - meanRR) }.reduce(0, +) / n)

        // Successive differences
        var diffs: [Float] = []
        for i in 1..<rrIntervals.count {
            diffs.append(rrIntervals[i] - rrIntervals[i - 1])
        }

        // RMSSD
        let rmssd = sqrt(diffs.map { $0 * $0 }.reduce(0, +) / Float(diffs.count))

        // pNN50
        let nn50Count = diffs.filter { abs($0) > 50.0 }.count
        let pnn50 = Float(nn50Count) / Float(diffs.count) * 100.0

        let ratio: Float = hfPower > 0 ? lfPower / hfPower : 0

        return HRVStatistics(
            rmssd: rmssd, sdnn: sdnn, pnn50: pnn50, meanRR: meanRR,
            lfPower: lfPower, hfPower: hfPower, lfHfRatio: ratio
        )
    }
}

// MARK: - Science Export Package

/// Full science export containing time-series + statistics + metadata
public struct ScienceExportPackage: Codable {
    public let metadata: ScienceSessionMetadata
    public let timeSeries: [ScienceDataPoint]
    public let heartRateStats: DescriptiveStats
    public let hrvStats: HRVStatistics
    public let coherenceStats: DescriptiveStats
    public let breathingRateStats: DescriptiveStats
    public let audioRMSStats: DescriptiveStats

    public init(
        metadata: ScienceSessionMetadata,
        timeSeries: [ScienceDataPoint],
        rrIntervals: [Float] = [],
        lfPower: Float = 0,
        hfPower: Float = 0
    ) {
        self.metadata = metadata
        self.timeSeries = timeSeries
        self.heartRateStats = DescriptiveStats.compute(from: timeSeries.map(\.heartRate))
        self.hrvStats = HRVStatistics.compute(rrIntervals: rrIntervals, lfPower: lfPower, hfPower: hfPower)
        self.coherenceStats = DescriptiveStats.compute(from: timeSeries.map(\.coherence))
        self.breathingRateStats = DescriptiveStats.compute(from: timeSeries.map(\.breathingRate))
        self.audioRMSStats = DescriptiveStats.compute(from: timeSeries.map(\.audioRMS))
    }
}

// MARK: - Science Data Exporter

/// Exports science data to CSV and JSON formats
public final class ScienceDataExporter {

    // MARK: - CSV Export

    /// Export time-series data as CSV
    public static func exportCSV(
        timeSeries: [ScienceDataPoint],
        metadata: ScienceSessionMetadata? = nil
    ) -> String {
        var csv = ""

        // Metadata header (as comments)
        if let meta = metadata {
            csv += "# Session: \(meta.sessionID)\n"
            csv += "# Participant: \(meta.participantID)\n"
            csv += "# Protocol: \(meta.protocolName)\n"
            csv += "# Start: \(meta.startTime)\n"
            csv += "# Duration: \(meta.durationSeconds)s\n"
            csv += "# Sample Rate: \(meta.sampleRate) Hz\n"
            csv += "# Device: \(meta.deviceModel)\n"
            csv += "# App Version: \(meta.appVersion)\n"
            if !meta.notes.isEmpty {
                csv += "# Notes: \(meta.notes)\n"
            }
            csv += "#\n"
        }

        // Column headers
        csv += "timestamp_s,wall_clock,heart_rate_bpm,hrv_rmssd_ms,coherence_pct,"
        csv += "breathing_rate_bpm,breath_phase,lf_hf_ratio,"
        csv += "audio_spectral_centroid_hz,audio_rms,audio_pitch_hz,entrainment_freq_hz\n"

        // Data rows
        for dp in timeSeries {
            csv += String(format: "%.3f", dp.timestamp) + ","
            csv += dp.wallClock + ","
            csv += String(format: "%.1f", dp.heartRate) + ","
            csv += String(format: "%.2f", dp.hrvRMSSD) + ","
            csv += String(format: "%.1f", dp.coherence) + ","
            csv += String(format: "%.1f", dp.breathingRate) + ","
            csv += String(format: "%.3f", dp.breathPhase) + ","
            csv += String(format: "%.3f", dp.lfHfRatio) + ","
            csv += String(format: "%.1f", dp.audioSpectralCentroid) + ","
            csv += String(format: "%.4f", dp.audioRMS) + ","
            csv += String(format: "%.1f", dp.audioPitch) + ","
            csv += String(format: "%.1f", dp.entrainmentFrequency) + "\n"
        }

        return csv
    }

    /// Export full science package as JSON
    public static func exportJSON(package: ScienceExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(package)
    }

    /// Export statistics summary as CSV
    public static func exportStatisticsCSV(package: ScienceExportPackage) -> String {
        var csv = "# Statistics Summary\n"
        csv += "# Session: \(package.metadata.sessionID)\n#\n"

        csv += "metric,count,mean,sd,min,max,median\n"

        func row(_ name: String, _ s: DescriptiveStats) -> String {
            "\(name),\(s.count),"
            + String(format: "%.3f,%.3f,%.3f,%.3f,%.3f", s.mean, s.standardDeviation, s.min, s.max, s.median)
            + "\n"
        }

        csv += row("heart_rate_bpm", package.heartRateStats)
        csv += row("coherence_pct", package.coherenceStats)
        csv += row("breathing_rate_bpm", package.breathingRateStats)
        csv += row("audio_rms", package.audioRMSStats)

        // HRV-specific stats
        csv += "\n# HRV Statistics\n"
        csv += "metric,value\n"
        csv += "rmssd_ms,\(String(format: "%.2f", package.hrvStats.rmssd))\n"
        csv += "sdnn_ms,\(String(format: "%.2f", package.hrvStats.sdnn))\n"
        csv += "pnn50_pct,\(String(format: "%.1f", package.hrvStats.pnn50))\n"
        csv += "mean_rr_ms,\(String(format: "%.1f", package.hrvStats.meanRR))\n"
        csv += "lf_power,\(String(format: "%.4f", package.hrvStats.lfPower))\n"
        csv += "hf_power,\(String(format: "%.4f", package.hrvStats.hfPower))\n"
        csv += "lf_hf_ratio,\(String(format: "%.3f", package.hrvStats.lfHfRatio))\n"

        return csv
    }

    // MARK: - File Export

    /// Write CSV time-series to file
    public static func writeCSV(
        timeSeries: [ScienceDataPoint],
        metadata: ScienceSessionMetadata? = nil,
        to url: URL
    ) throws {
        let csv = exportCSV(timeSeries: timeSeries, metadata: metadata)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Write full JSON package to file
    public static func writeJSON(
        package: ScienceExportPackage,
        to url: URL
    ) throws {
        let data = try exportJSON(package: package)
        try data.write(to: url)
    }

    /// Write statistics summary CSV to file
    public static func writeStatisticsCSV(
        package: ScienceExportPackage,
        to url: URL
    ) throws {
        let csv = exportStatisticsCSV(package: package)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Export complete science bundle (time-series CSV + stats CSV + JSON package)
    public static func exportBundle(
        package: ScienceExportPackage,
        to directory: URL
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sessionID = package.metadata.sessionID.prefix(8)
        let dateStr = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let timeSeriesURL = directory.appendingPathComponent("timeseries_\(sessionID)_\(dateStr).csv")
        let statsURL = directory.appendingPathComponent("statistics_\(sessionID)_\(dateStr).csv")
        let jsonURL = directory.appendingPathComponent("session_\(sessionID)_\(dateStr).json")

        try writeCSV(timeSeries: package.timeSeries, metadata: package.metadata, to: timeSeriesURL)
        try writeStatisticsCSV(package: package, to: statsURL)
        try writeJSON(package: package, to: jsonURL)

        return [timeSeriesURL, statsURL, jsonURL]
    }
}
