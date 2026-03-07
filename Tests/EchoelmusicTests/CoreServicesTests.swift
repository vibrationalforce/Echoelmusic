#if canImport(AVFoundation)
// CoreServicesTests.swift
// Echoelmusic — Phase 3 Test Coverage: Core Services
//
// Tests for UndoRedoManager, CrashSafeStatePersistence,
// MemoryPressureHandler, and MemoryAwareCache.

import XCTest
@testable import Echoelmusic

// MARK: - UndoRedoManager Tests

@MainActor
final class UndoRedoManagerTests: XCTestCase {

    func testSharedInstance() {
        let manager = UndoRedoManager.shared
        XCTAssertNotNil(manager)
    }

    func testInitialState() {
        let manager = UndoRedoManager.shared
        manager.clear()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertTrue(manager.undoActionName.isEmpty)
        XCTAssertTrue(manager.redoActionName.isEmpty)
    }

    func testExecuteEnablesUndo() {
        let manager = UndoRedoManager.shared
        manager.clear()

        let command = GenericTrackCommand(
            actionName: "Set Volume",
            trackID: UUID(),
            execute: {},
            undo: {}
        )
        manager.execute(command)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testUndoEnablesRedo() {
        let manager = UndoRedoManager.shared
        manager.clear()

        let command = GenericTrackCommand(
            actionName: "Test",
            trackID: UUID(),
            execute: {},
            undo: {}
        )
        manager.execute(command)
        manager.undo()
        XCTAssertTrue(manager.canRedo)
    }

    func testRedoDisablesRedo() {
        let manager = UndoRedoManager.shared
        manager.clear()

        let command = GenericTrackCommand(
            actionName: "Test",
            trackID: UUID(),
            execute: {},
            undo: {}
        )
        manager.execute(command)
        manager.undo()
        manager.redo()
        XCTAssertFalse(manager.canRedo)
        XCTAssertTrue(manager.canUndo)
    }

    func testNewExecuteClearsRedoStack() {
        let manager = UndoRedoManager.shared
        manager.clear()

        let cmd1 = GenericTrackCommand(actionName: "A", trackID: UUID(), execute: {}, undo: {})
        let cmd2 = GenericTrackCommand(actionName: "B", trackID: UUID(), execute: {}, undo: {})

        manager.execute(cmd1)
        manager.undo()
        XCTAssertTrue(manager.canRedo)

        manager.execute(cmd2)
        XCTAssertFalse(manager.canRedo)
    }

    func testClear() {
        let manager = UndoRedoManager.shared
        let command = GenericTrackCommand(actionName: "X", trackID: UUID(), execute: {}, undo: {})
        manager.execute(command)
        manager.clear()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testUndoHistory() {
        let manager = UndoRedoManager.shared
        manager.clear()

        manager.execute(GenericTrackCommand(actionName: "Step 1", trackID: UUID(), execute: {}, undo: {}))
        manager.execute(GenericTrackCommand(actionName: "Step 2", trackID: UUID(), execute: {}, undo: {}))

        let history = manager.undoHistory
        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.contains("Step 1"))
        XCTAssertTrue(history.contains("Step 2"))
    }

    func testExecuteCallsAction() {
        let manager = UndoRedoManager.shared
        manager.clear()

        var executed = false
        let command = GenericTrackCommand(
            actionName: "Test",
            trackID: UUID(),
            execute: { executed = true },
            undo: {}
        )
        manager.execute(command)
        XCTAssertTrue(executed)
    }

    func testUndoCallsUndoAction() {
        let manager = UndoRedoManager.shared
        manager.clear()

        var undone = false
        let command = GenericTrackCommand(
            actionName: "Test",
            trackID: UUID(),
            execute: {},
            undo: { undone = true }
        )
        manager.execute(command)
        manager.undo()
        XCTAssertTrue(undone)
    }
}

// MARK: - SessionState Tests

final class SessionStateTests: XCTestCase {

    func testDefaultInit() {
        let state = SessionState()
        XCTAssertNotNil(state.sessionId)
        XCTAssertNotNil(state.startedAt)
        XCTAssertEqual(state.durationSeconds, 0)
        XCTAssertNil(state.activePreset)
    }

    func testBioSettingsDefaults() {
        let bio = SessionState.BioSettings()
        XCTAssertTrue(bio.enabled)
        XCTAssertEqual(bio.coherenceThreshold, 0.6, accuracy: 0.001)
        XCTAssertEqual(bio.smoothingFactor, 0.3, accuracy: 0.01)
    }

    func testAudioSettingsDefaults() {
        let audio = SessionState.AudioSettings()
        XCTAssertEqual(audio.volume, 0.8, accuracy: 0.001)
        XCTAssertEqual(audio.bpm, 120, accuracy: 0.001)
        XCTAssertEqual(audio.carrierFrequency, 440, accuracy: 0.001)
    }

    func testVisualSettingsDefaults() {
        let visual = SessionState.VisualSettings()
        XCTAssertNotNil(visual.mode)
        XCTAssertGreaterThanOrEqual(visual.intensity, 0)
        XCTAssertLessThanOrEqual(visual.intensity, 1)
    }

    func testLightSettingsDefaults() {
        let light = SessionState.LightSettings()
        XCTAssertFalse(light.dmxEnabled)
        XCTAssertFalse(light.artNetEnabled)
        XCTAssertFalse(light.laserEnabled)
    }

    func testSessionMetricsDefaults() {
        let metrics = SessionState.SessionMetrics()
        XCTAssertEqual(metrics.averageCoherence, 0)
        XCTAssertEqual(metrics.peakCoherence, 0)
        XCTAssertEqual(metrics.coherenceReadings, 0)
        XCTAssertEqual(metrics.totalBreaths, 0)
    }

    func testCodableRoundtrip() throws {
        let state = SessionState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SessionState.self, from: data)
        XCTAssertEqual(state.sessionId, decoded.sessionId)
    }

    func testBioSettingsCodable() throws {
        let settings = SessionState.BioSettings()
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SessionState.BioSettings.self, from: data)
        XCTAssertEqual(settings.enabled, decoded.enabled)
        XCTAssertEqual(settings.coherenceThreshold, decoded.coherenceThreshold, accuracy: 0.001)
    }
}

// MARK: - SessionStateBuilder Tests

@MainActor
final class SessionStateBuilderTests: XCTestCase {

    func testBuildDefault() {
        let builder = SessionStateBuilder()
        let state = builder.build()
        XCTAssertNotNil(state.sessionId)
    }

    func testWithPreset() {
        let state = SessionStateBuilder()
            .withPreset("Meditation")
            .build()
        XCTAssertEqual(state.activePreset, "Meditation")
    }

    func testWithUserData() {
        let state = SessionStateBuilder()
            .withUserData("mood", value: "calm")
            .build()
        XCTAssertEqual(state.userData["mood"], "calm")
    }

    func testWithCoherenceReading() {
        let state = SessionStateBuilder()
            .withCoherenceReading(0.8)
            .withCoherenceReading(0.6)
            .build()
        XCTAssertEqual(state.metrics.coherenceReadings, 2)
        XCTAssertEqual(state.metrics.averageCoherence, 0.7, accuracy: 0.01)
        XCTAssertEqual(state.metrics.peakCoherence, 0.8, accuracy: 0.01)
    }

    func testBuildFromExisting() {
        let original = SessionState()
        let builder = SessionStateBuilder(from: original)
        let rebuilt = builder.build()
        XCTAssertEqual(original.sessionId, rebuilt.sessionId)
    }
}

// MARK: - MemoryPressureLevel Tests (Extended)

final class MemoryPressureLevelExtendedTests: XCTestCase {

    func testAllLevels() {
        XCTAssertEqual(MemoryPressureLevel.normal.rawValue, 0)
        XCTAssertEqual(MemoryPressureLevel.warning.rawValue, 1)
        XCTAssertEqual(MemoryPressureLevel.critical.rawValue, 2)
        XCTAssertEqual(MemoryPressureLevel.terminal.rawValue, 3)
    }

    func testOrdering() {
        XCTAssertTrue(MemoryPressureLevel.normal < .warning)
        XCTAssertTrue(MemoryPressureLevel.warning < .critical)
        XCTAssertTrue(MemoryPressureLevel.critical < .terminal)
    }

    func testDescriptions() {
        for level in [MemoryPressureLevel.normal, .warning, .critical, .terminal] {
            XCTAssertFalse(level.description.isEmpty)
        }
    }
}

// MARK: - MemoryAwareCache Tests

final class MemoryAwareCacheTests: XCTestCase {

    func testSetAndGet() {
        let cache = MemoryAwareCache<String, String>(maxSize: 1000)
        cache.set("key1", value: "value1", size: 100)
        XCTAssertEqual(cache.get("key1"), "value1")
    }

    func testGetMissReturnsNil() {
        let cache = MemoryAwareCache<String, String>(maxSize: 1000)
        XCTAssertNil(cache.get("nonexistent"))
    }

    func testRemove() {
        let cache = MemoryAwareCache<String, String>(maxSize: 1000)
        cache.set("key1", value: "value1", size: 100)
        cache.remove("key1")
        XCTAssertNil(cache.get("key1"))
    }

    func testClear() {
        let cache = MemoryAwareCache<String, String>(maxSize: 1000)
        cache.set("a", value: "1", size: 100)
        cache.set("b", value: "2", size: 100)
        cache.clear()
        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.currentSize, 0)
    }

    func testEvictionWhenFull() {
        let cache = MemoryAwareCache<String, String>(maxSize: 200)
        cache.set("a", value: "1", size: 100)
        cache.set("b", value: "2", size: 100)
        // Adding beyond max should evict
        cache.set("c", value: "3", size: 100)
        XCTAssertLessThanOrEqual(cache.currentSize, 200)
        XCTAssertEqual(cache.get("c"), "3")
    }

    func testOverwrite() {
        let cache = MemoryAwareCache<String, String>(maxSize: 1000)
        cache.set("key", value: "old", size: 50)
        cache.set("key", value: "new", size: 50)
        XCTAssertEqual(cache.get("key"), "new")
    }

    func testMaxSizeProperty() {
        let cache = MemoryAwareCache<String, Int>(maxSize: 5000)
        XCTAssertEqual(cache.maxSize, 5000)
    }
}

// MARK: - MemoryPressureHandler Tests

@MainActor
final class MemoryPressureHandlerTests: XCTestCase {

    func testSharedInstance() {
        let handler = MemoryPressureHandler.shared
        XCTAssertNotNil(handler)
    }

    func testInitialLevel() {
        let handler = MemoryPressureHandler.shared
        // Should start at normal or respond to current system state
        XCTAssertNotNil(handler.currentLevel)
    }

    func testMemoryUsage() {
        let handler = MemoryPressureHandler.shared
        let usage = handler.memoryUsage
        XCTAssertGreaterThan(usage.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(usage.usedBytes, 0)
        XCTAssertGreaterThanOrEqual(usage.usagePercent, 0)
        XCTAssertLessThanOrEqual(usage.usagePercent, 1.0)
    }

    func testMemoryUsageComputedProperties() {
        let usage = MemoryPressureHandler.MemoryUsage(
            usedBytes: 100_000_000,
            availableBytes: 900_000_000,
            totalBytes: 1_000_000_000
        )
        XCTAssertEqual(usage.usedMB, 100.0, accuracy: 1.0)
        XCTAssertEqual(usage.availableMB, 900.0, accuracy: 1.0)
        XCTAssertEqual(usage.totalMB, 1000.0, accuracy: 1.0)
        XCTAssertEqual(usage.usagePercent, 0.1, accuracy: 0.01)
    }

    func testThresholds() {
        let thresholds = MemoryPressureHandler.Thresholds()
        XCTAssertEqual(thresholds.warning, 0.70, accuracy: 0.01)
        XCTAssertEqual(thresholds.critical, 0.85, accuracy: 0.01)
        XCTAssertEqual(thresholds.terminal, 0.95, accuracy: 0.01)
    }

    func testReleaseMemory() {
        let handler = MemoryPressureHandler.shared
        // Should not crash
        handler.releaseMemory(level: .warning)
    }

    func testForceCleanup() {
        let handler = MemoryPressureHandler.shared
        // Should not crash
        handler.forceCleanup()
    }
}
#endif
