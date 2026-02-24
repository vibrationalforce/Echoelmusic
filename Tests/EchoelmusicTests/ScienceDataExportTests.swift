// ScienceDataExportTests.swift
// Tests for ScienceDataExport — CSV/JSON Science-Grade Export

import XCTest
@testable import Echoelmusic

final class ScienceDataExportTests: XCTestCase {

    // MARK: - Helpers

    private func sampleTimeSeries(count: Int = 100) -> [ScienceDataPoint] {
        (0..<count).map { i in
            ScienceDataPoint(
                timestamp: Double(i) * 1.0,
                heartRate: 60 + Float.random(in: -5...5),
                hrvRMSSD: 40 + Float.random(in: -10...10),
                coherence: 50 + Float.random(in: -20...20),
                breathingRate: 6 + Float.random(in: -1...1),
                breathPhase: Float(i % 60) / 60.0,
                lfHfRatio: 1.5 + Float.random(in: -0.5...0.5),
                audioSpectralCentroid: 2000 + Float.random(in: -500...500),
                audioRMS: 0.3 + Float.random(in: -0.1...0.1),
                audioPitch: 440,
                entrainmentFrequency: 40
            )
        }
    }

    private func sampleMetadata() -> ScienceSessionMetadata {
        ScienceSessionMetadata(
            sessionID: "TEST-001",
            participantID: "P001",
            protocolName: "Resonance Frequency Training",
            startTime: "2026-02-24T10:00:00Z",
            endTime: "2026-02-24T10:20:00Z",
            durationSeconds: 1200,
            sampleRate: 1.0,
            deviceModel: "iPhone 15 Pro",
            appVersion: "3.1.0",
            notes: "Test session"
        )
    }

    // MARK: - Descriptive Statistics

    func testDescriptiveStatsCompute() {
        let values: [Float] = [1, 2, 3, 4, 5]
        let stats = DescriptiveStats.compute(from: values)
        XCTAssertEqual(stats.count, 5)
        XCTAssertEqual(stats.mean, 3.0, accuracy: 0.01)
        XCTAssertEqual(stats.min, 1.0)
        XCTAssertEqual(stats.max, 5.0)
        XCTAssertEqual(stats.median, 3.0)
    }

    func testDescriptiveStatsEmpty() {
        let stats = DescriptiveStats.compute(from: [])
        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.mean, 0)
    }

    func testDescriptiveStatsEvenCount() {
        let values: [Float] = [1, 2, 3, 4]
        let stats = DescriptiveStats.compute(from: values)
        XCTAssertEqual(stats.median, 2.5, accuracy: 0.01)
    }

    func testStandardDeviation() {
        // Known SD: [2, 4, 4, 4, 5, 5, 7, 9] → mean=5, SD≈2.0
        let values: [Float] = [2, 4, 4, 4, 5, 5, 7, 9]
        let stats = DescriptiveStats.compute(from: values)
        XCTAssertEqual(stats.mean, 5.0, accuracy: 0.01)
        XCTAssertEqual(stats.standardDeviation, 2.0, accuracy: 0.1)
    }

    // MARK: - HRV Statistics

    func testHRVStatistics() {
        let rrIntervals: [Float] = [800, 850, 810, 860, 790, 830, 870, 800, 840, 820]
        let stats = HRVStatistics.compute(rrIntervals: rrIntervals)
        XCTAssertGreaterThan(stats.rmssd, 0)
        XCTAssertGreaterThan(stats.sdnn, 0)
        XCTAssertGreaterThan(stats.meanRR, 0)
    }

    func testPNN50() {
        // Large successive differences → high pNN50
        let rrIntervals: [Float] = [700, 800, 700, 800, 700, 800]
        let stats = HRVStatistics.compute(rrIntervals: rrIntervals)
        XCTAssertEqual(stats.pnn50, 100.0, accuracy: 0.1, "All diffs > 50ms → pNN50 = 100%")
    }

    func testLFHFRatio() {
        let stats = HRVStatistics.compute(rrIntervals: [800], lfPower: 0.5, hfPower: 0.25)
        XCTAssertEqual(stats.lfHfRatio, 2.0, accuracy: 0.01)
    }

    // MARK: - CSV Export

    func testCSVExportContainsHeader() {
        let timeSeries = sampleTimeSeries(count: 5)
        let csv = ScienceDataExporter.exportCSV(timeSeries: timeSeries)
        XCTAssertTrue(csv.contains("timestamp_s,wall_clock,heart_rate_bpm"))
        XCTAssertTrue(csv.contains("hrv_rmssd_ms"))
        XCTAssertTrue(csv.contains("coherence_pct"))
    }

    func testCSVExportRowCount() {
        let count = 10
        let timeSeries = sampleTimeSeries(count: count)
        let csv = ScienceDataExporter.exportCSV(timeSeries: timeSeries)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        // 1 header + count data rows
        XCTAssertEqual(lines.count, count + 1)
    }

    func testCSVExportWithMetadata() {
        let timeSeries = sampleTimeSeries(count: 3)
        let metadata = sampleMetadata()
        let csv = ScienceDataExporter.exportCSV(timeSeries: timeSeries, metadata: metadata)
        XCTAssertTrue(csv.contains("# Session: TEST-001"))
        XCTAssertTrue(csv.contains("# Participant: P001"))
        XCTAssertTrue(csv.contains("# Protocol: Resonance Frequency Training"))
    }

    // MARK: - JSON Export

    func testJSONExportValid() throws {
        let timeSeries = sampleTimeSeries(count: 10)
        let metadata = sampleMetadata()
        let package = ScienceExportPackage(
            metadata: metadata,
            timeSeries: timeSeries,
            rrIntervals: [800, 850, 810, 860],
            lfPower: 0.3,
            hfPower: 0.2
        )

        let data = try ScienceDataExporter.exportJSON(package: package)
        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let decoded = try JSONDecoder().decode(ScienceExportPackage.self, from: data)
        XCTAssertEqual(decoded.metadata.sessionID, "TEST-001")
        XCTAssertEqual(decoded.timeSeries.count, 10)
        XCTAssertGreaterThan(decoded.heartRateStats.mean, 0)
    }

    func testJSONRoundTrip() throws {
        let timeSeries = sampleTimeSeries(count: 5)
        let package = ScienceExportPackage(
            metadata: sampleMetadata(),
            timeSeries: timeSeries
        )

        let data = try ScienceDataExporter.exportJSON(package: package)
        let decoded = try JSONDecoder().decode(ScienceExportPackage.self, from: data)

        XCTAssertEqual(decoded.timeSeries.count, 5)
        XCTAssertEqual(decoded.heartRateStats.count, 5)
        XCTAssertEqual(decoded.coherenceStats.count, 5)
    }

    // MARK: - Statistics CSV

    func testStatisticsCSVContainsMetrics() {
        let package = ScienceExportPackage(
            metadata: sampleMetadata(),
            timeSeries: sampleTimeSeries(count: 50),
            rrIntervals: [800, 850, 810, 860, 790]
        )

        let csv = ScienceDataExporter.exportStatisticsCSV(package: package)
        XCTAssertTrue(csv.contains("heart_rate_bpm"))
        XCTAssertTrue(csv.contains("coherence_pct"))
        XCTAssertTrue(csv.contains("rmssd_ms"))
        XCTAssertTrue(csv.contains("sdnn_ms"))
        XCTAssertTrue(csv.contains("pnn50_pct"))
        XCTAssertTrue(csv.contains("lf_hf_ratio"))
    }

    // MARK: - File Export

    func testWriteCSVToFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("test_timeseries.csv")

        let timeSeries = sampleTimeSeries(count: 20)
        try ScienceDataExporter.writeCSV(timeSeries: timeSeries, metadata: sampleMetadata(), to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("timestamp_s"))

        try? FileManager.default.removeItem(at: url)
    }

    func testExportBundle() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_bundle_\(UUID().uuidString)", isDirectory: true)

        let package = ScienceExportPackage(
            metadata: sampleMetadata(),
            timeSeries: sampleTimeSeries(count: 30),
            rrIntervals: [800, 850, 810]
        )

        let urls = try ScienceDataExporter.exportBundle(package: package, to: tmpDir)
        XCTAssertEqual(urls.count, 3, "Bundle should contain 3 files (timeseries CSV, stats CSV, JSON)")

        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent) should exist")
        }

        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Science Export Package

    func testPackageStatisticsComputed() {
        let timeSeries = sampleTimeSeries(count: 50)
        let package = ScienceExportPackage(
            metadata: sampleMetadata(),
            timeSeries: timeSeries
        )

        XCTAssertEqual(package.heartRateStats.count, 50)
        XCTAssertGreaterThan(package.heartRateStats.mean, 0)
        XCTAssertGreaterThan(package.coherenceStats.mean, 0)
        XCTAssertGreaterThan(package.breathingRateStats.mean, 0)
    }

    // MARK: - Data Point

    func testDataPointDefaults() {
        let dp = ScienceDataPoint(timestamp: 0)
        XCTAssertEqual(dp.heartRate, 0)
        XCTAssertEqual(dp.coherence, 0)
        XCTAssertFalse(dp.wallClock.isEmpty, "Wall clock should be auto-populated")
    }
}
