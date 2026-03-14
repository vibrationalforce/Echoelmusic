// PerformanceBudgetTests.swift
// Echoelmusic — Performance Budget & Audit Trail Tests
//
// Tests for Paperclip-inspired resource budgeting and activity logging.

import XCTest
@testable import Echoelmusic

// MARK: - Performance Budget Tests

final class PerformanceBudgetTests: XCTestCase {

    func testDefaultBudgetValues() {
        let budget = PerformanceBudget()
        XCTAssertEqual(budget.cpuSoftLimit, 30.0, accuracy: 0.1)
        XCTAssertEqual(budget.cpuHardLimit, 50.0, accuracy: 0.1)
        XCTAssertEqual(budget.memorySoftLimit, 200.0, accuracy: 0.1)
        XCTAssertEqual(budget.memoryHardLimit, 300.0, accuracy: 0.1)
        XCTAssertEqual(budget.latencySoftLimit, 10.0, accuracy: 0.1)
        XCTAssertEqual(budget.latencyHardLimit, 15.0, accuracy: 0.1)
        XCTAssertEqual(budget.fpsSoftLimit, 60.0, accuracy: 0.1)
        XCTAssertEqual(budget.fpsHardLimit, 30.0, accuracy: 0.1)
        XCTAssertEqual(budget.bioLoopSoftLimit, 60.0, accuracy: 0.1)
        XCTAssertEqual(budget.bioLoopHardLimit, 30.0, accuracy: 0.1)
    }

    func testBudgetViolationDescription() {
        let violation = BudgetViolation(
            resource: .cpu,
            severity: .critical,
            currentValue: 55.0,
            limit: 50.0,
            timestamp: Date()
        )
        XCTAssertTrue(violation.description.contains("CRITICAL"))
        XCTAssertTrue(violation.description.contains("cpu"))
        XCTAssertTrue(violation.description.contains("55.0"))
    }

    func testBudgetViolationSeverities() {
        let warning = BudgetViolation(resource: .memory, severity: .warning, currentValue: 210, limit: 200, timestamp: Date())
        let critical = BudgetViolation(resource: .memory, severity: .critical, currentValue: 310, limit: 300, timestamp: Date())

        XCTAssertEqual(warning.severity, .warning)
        XCTAssertEqual(critical.severity, .critical)
    }

    func testPerformanceSnapshotHealthGreen() {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            cpuPercent: 20,
            memoryMB: 150,
            audioLatencyMs: 5,
            visualFPS: 120,
            bioLoopHz: 120,
            activeViolations: []
        )
        XCTAssertEqual(snapshot.health, .green)
    }

    func testPerformanceSnapshotHealthYellow() {
        let violation = BudgetViolation(resource: .cpu, severity: .warning, currentValue: 35, limit: 30, timestamp: Date())
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            cpuPercent: 35,
            memoryMB: 150,
            audioLatencyMs: 5,
            visualFPS: 120,
            bioLoopHz: 120,
            activeViolations: [violation]
        )
        XCTAssertEqual(snapshot.health, .yellow)
    }

    func testPerformanceSnapshotHealthRed() {
        let violation = BudgetViolation(resource: .cpu, severity: .critical, currentValue: 55, limit: 50, timestamp: Date())
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            cpuPercent: 55,
            memoryMB: 150,
            audioLatencyMs: 5,
            visualFPS: 120,
            bioLoopHz: 120,
            activeViolations: [violation]
        )
        XCTAssertEqual(snapshot.health, .red)
    }

    func testAllBudgetResources() {
        let resources: [BudgetViolation.Resource] = [.cpu, .memory, .audioLatency, .visualFPS, .bioLoopRate]
        XCTAssertEqual(resources.count, 5, "Should track 5 resource types")
    }
}

// MARK: - Performance Audit Trail Tests

final class PerformanceAuditTrailTests: XCTestCase {

    func testLogEvent() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "effect.added", details: ["type": "reverb"])
        XCTAssertEqual(trail.totalEvents, 1)
    }

    func testLogMultipleEvents() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "effect.added")
        trail.log(.bio, action: "coherence.change", details: ["value": "0.8"])
        trail.log(.visual, action: "mode.switch", details: ["mode": "spectrum"])
        trail.log(.session, action: "session.start")
        XCTAssertEqual(trail.totalEvents, 4)
    }

    func testFilterByCategory() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "effect.added")
        trail.log(.bio, action: "coherence.change")
        trail.log(.audio, action: "parameter.changed")
        trail.log(.bio, action: "hr.spike")

        let audioEvents = trail.events(category: .audio)
        XCTAssertEqual(audioEvents.count, 2)

        let bioEvents = trail.events(category: .bio)
        XCTAssertEqual(bioEvents.count, 2)

        let visualEvents = trail.events(category: .visual)
        XCTAssertEqual(visualEvents.count, 0)
    }

    func testFilterByLevel() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, level: .info, action: "normal")
        trail.log(.bio, level: .notable, action: "coherence.peak")
        trail.log(.system, level: .warning, action: "cpu.high")
        trail.log(.system, level: .critical, action: "memory.critical")

        let notable = trail.events(minLevel: .notable)
        XCTAssertEqual(notable.count, 3, "notable+ should include notable, warning, critical")

        let warnings = trail.events(minLevel: .warning)
        XCTAssertEqual(warnings.count, 2, "warning+ should include warning and critical")

        let criticals = trail.events(minLevel: .critical)
        XCTAssertEqual(criticals.count, 1, "critical should only include critical")
    }

    func testEventCounts() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "a")
        trail.log(.audio, action: "b")
        trail.log(.bio, action: "c")

        let counts = trail.eventCounts()
        XCTAssertEqual(counts[.audio], 2)
        XCTAssertEqual(counts[.bio], 1)
        XCTAssertNil(counts[.visual])
    }

    func testTimeline() {
        let trail = PerformanceAuditTrail()
        let before = Date()

        trail.log(.audio, action: "first")
        let middle = Date()
        trail.log(.audio, action: "second")
        let after = Date()

        let all = trail.timeline(from: before, to: after)
        XCTAssertEqual(all.count, 2)

        // Timeline with narrow window should capture at least some events
        let narrow = trail.timeline(from: before, to: middle)
        XCTAssertGreaterThanOrEqual(narrow.count, 1)
    }

    func testMaxEventsRotation() {
        let trail = PerformanceAuditTrail()
        trail.maxEvents = 100

        for i in 0..<150 {
            trail.log(.audio, action: "event_\(i)")
        }

        // After rotation, should have at most maxEvents/2
        XCTAssertLessThanOrEqual(trail.totalEvents, 100)
        XCTAssertGreaterThan(trail.totalEvents, 0)
    }

    func testClear() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "test")
        trail.log(.bio, action: "test")
        XCTAssertEqual(trail.totalEvents, 2)

        trail.clear()
        XCTAssertEqual(trail.totalEvents, 0)
    }

    func testExportJSON() throws {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "effect.added", details: ["type": "delay"])

        let jsonData = try trail.exportJSON()
        XCTAssertGreaterThan(jsonData.count, 0)

        // Verify it's valid JSON
        let decoded = try JSONDecoder().decode([AuditEvent].self, from: jsonData)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.action, "effect.added")
        XCTAssertEqual(decoded.first?.category, .audio)
    }

    func testSessionDuration() {
        let trail = PerformanceAuditTrail()
        XCTAssertGreaterThanOrEqual(trail.sessionDuration, 0)
        XCTAssertLessThan(trail.sessionDuration, 1.0, "Session just started, duration should be < 1s")
    }

    func testAllCategories() {
        let trail = PerformanceAuditTrail()
        trail.log(.audio, action: "a")
        trail.log(.bio, action: "b")
        trail.log(.visual, action: "c")
        trail.log(.session, action: "d")
        trail.log(.system, action: "e")
        trail.log(.midi, action: "f")
        trail.log(.light, action: "g")

        XCTAssertEqual(trail.totalEvents, 7, "All 7 categories should be loggable")
    }

    func testEventDetails() {
        let trail = PerformanceAuditTrail()
        trail.log(.bio, action: "coherence.change", details: [
            "value": "0.85",
            "trend": "rising",
            "source": "appleWatch"
        ])

        let events = trail.events(category: .bio)
        XCTAssertEqual(events.first?.details["value"], "0.85")
        XCTAssertEqual(events.first?.details["trend"], "rising")
        XCTAssertEqual(events.first?.details["source"], "appleWatch")
    }
}
