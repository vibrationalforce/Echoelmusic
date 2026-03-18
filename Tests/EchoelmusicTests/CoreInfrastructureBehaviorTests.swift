#if canImport(AVFoundation)
// CoreInfrastructureBehaviorTests.swift
// Echoelmusic — Behavioral tests for core infrastructure:
// UndoRedoManager and CrashSafeStatePersistence.

import XCTest
@testable import Echoelmusic

// MARK: - UndoRedoManager Behavior Tests

@MainActor
final class UndoRedoManagerBehaviorTests: XCTestCase {

    /// Fresh manager for each test (avoids singleton shared state leaking between tests)
    private var manager: UndoRedoManager {
        // Use the singleton but clear it each test
        let m = UndoRedoManager.shared
        m.clear()
        return m
    }

    // MARK: - Empty Stack Edge Cases

    func testUndoRedoManager_InitialState_CannotUndoOrRedo() {
        let m = manager
        XCTAssertFalse(m.canUndo, "Empty manager cannot undo")
        XCTAssertFalse(m.canRedo, "Empty manager cannot redo")
        XCTAssertTrue(m.undoActionName.isEmpty)
        XCTAssertTrue(m.redoActionName.isEmpty)
    }

    func testUndoRedoManager_UndoOnEmptyStack_DoesNotCrash() {
        let m = manager
        // Should be a no-op
        m.undo()
        XCTAssertFalse(m.canUndo)
        XCTAssertFalse(m.canRedo)
    }

    func testUndoRedoManager_RedoOnEmptyStack_DoesNotCrash() {
        let m = manager
        m.redo()
        XCTAssertFalse(m.canRedo)
    }

    func testUndoRedoManager_Clear_ResetsAllState() {
        let m = manager
        var value: Float = 0
        let cmd = TrackVolumeCommand(
            trackID: UUID(),
            oldValue: 0,
            newValue: 0.5,
            applyChange: { _, v in value = v }
        )
        m.execute(cmd)
        XCTAssertTrue(m.canUndo)

        m.clear()
        XCTAssertFalse(m.canUndo)
        XCTAssertFalse(m.canRedo)
        XCTAssertTrue(m.undoHistory.isEmpty)
        XCTAssertTrue(m.redoHistory.isEmpty)
        XCTAssertEqual(value, 0.5, "Clear does not revert executed commands")
    }

    // MARK: - Push / Pop / Execute

    func testUndoRedoManager_Execute_RunsCommandAndEnablesUndo() {
        let m = manager
        var value: Float = 0
        let trackId = UUID()
        let cmd = TrackVolumeCommand(
            trackID: trackId,
            oldValue: 0,
            newValue: 0.8,
            applyChange: { _, v in value = v }
        )

        m.execute(cmd)
        XCTAssertEqual(value, 0.8, accuracy: 0.01, "Command must execute")
        XCTAssertTrue(m.canUndo)
        XCTAssertFalse(m.canRedo)
        XCTAssertEqual(m.undoActionName, "Change Track Volume")
    }

    func testUndoRedoManager_Undo_ReversesLastAction() {
        let m = manager
        var value: Float = 0
        let cmd = TrackVolumeCommand(
            trackID: UUID(),
            oldValue: 0.2,
            newValue: 0.9,
            applyChange: { _, v in value = v }
        )

        m.execute(cmd)
        XCTAssertEqual(value, 0.9, accuracy: 0.01)

        m.undo()
        XCTAssertEqual(value, 0.2, accuracy: 0.01, "Undo must restore old value")
        XCTAssertFalse(m.canUndo)
        XCTAssertTrue(m.canRedo)
    }

    func testUndoRedoManager_Redo_ReappliesUndoneAction() {
        let m = manager
        var value: Float = 0
        let cmd = TrackVolumeCommand(
            trackID: UUID(),
            oldValue: 0,
            newValue: 0.7,
            applyChange: { _, v in value = v }
        )

        m.execute(cmd)
        m.undo()
        XCTAssertEqual(value, 0, accuracy: 0.01)

        m.redo()
        XCTAssertEqual(value, 0.7, accuracy: 0.01, "Redo must reapply the command")
        XCTAssertTrue(m.canUndo)
        XCTAssertFalse(m.canRedo)
    }

    // MARK: - Multiple Actions

    func testUndoRedoManager_MultipleActions_UndoInReverseOrder() {
        let m = manager
        var value: Float = 0

        let cmd1 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0, newValue: 0.3,
            applyChange: { _, v in value = v }
        )
        let cmd2 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0.3, newValue: 0.6,
            applyChange: { _, v in value = v }
        )
        let cmd3 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0.6, newValue: 0.9,
            applyChange: { _, v in value = v }
        )

        m.execute(cmd1)
        m.execute(cmd2)
        m.execute(cmd3)
        XCTAssertEqual(value, 0.9, accuracy: 0.01)

        m.undo()
        XCTAssertEqual(value, 0.6, accuracy: 0.01, "First undo reverts last action")

        m.undo()
        XCTAssertEqual(value, 0.3, accuracy: 0.01, "Second undo reverts second action")

        m.undo()
        XCTAssertEqual(value, 0, accuracy: 0.01, "Third undo reverts first action")

        XCTAssertFalse(m.canUndo)
    }

    func testUndoRedoManager_NewAction_ClearsRedoStack() {
        let m = manager
        var value: Float = 0

        let cmd1 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0, newValue: 0.5,
            applyChange: { _, v in value = v }
        )
        let cmd2 = TrackPanCommand(
            trackID: UUID(), oldValue: 0, newValue: -0.5,
            applyChange: { _, _ in }
        )

        m.execute(cmd1)
        m.undo()
        XCTAssertTrue(m.canRedo)

        m.execute(cmd2)
        XCTAssertFalse(m.canRedo, "New action must clear redo stack")
    }

    // MARK: - Max Depth

    func testUndoRedoManager_MaxDepth_OldestActionsDropped() {
        let m = manager
        var counter = 0

        // Push more than maxUndoSteps (1000)
        for i in 0..<1010 {
            let cmd = TrackVolumeCommand(
                trackID: UUID(),
                oldValue: Float(i),
                newValue: Float(i + 1),
                applyChange: { _, _ in counter += 1 }
            )
            m.execute(cmd)
        }

        // Undo history should be capped at 1000
        XCTAssertLessThanOrEqual(m.undoHistory.count, 1000,
                                  "Undo stack must not exceed max depth")
    }

    // MARK: - History

    func testUndoRedoManager_UndoHistory_ReturnsActionNamesReversed() {
        let m = manager
        let cmd1 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0, newValue: 1,
            applyChange: { _, _ in }
        )
        let cmd2 = TrackMuteCommand(
            trackID: UUID(), isMuted: true,
            applyChange: { _, _ in }
        )

        m.execute(cmd1)
        m.execute(cmd2)

        let history = m.undoHistory
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0], "Mute Track", "Most recent should be first")
        XCTAssertEqual(history[1], "Change Track Volume")
    }

    func testUndoRedoManager_RedoHistory_ReturnsActionNamesReversed() {
        let m = manager
        let cmd1 = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0, newValue: 1,
            applyChange: { _, _ in }
        )
        let cmd2 = TrackMuteCommand(
            trackID: UUID(), isMuted: true,
            applyChange: { _, _ in }
        )

        m.execute(cmd1)
        m.execute(cmd2)
        m.undo()
        m.undo()

        let history = m.redoHistory
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0], "Change Track Volume", "First undone should be first in redo")
        XCTAssertEqual(history[1], "Mute Track")
    }

    // MARK: - Compound Command

    func testUndoRedoManager_CompoundCommand_UndoesAllAtOnce() {
        let m = manager
        var valueA: Float = 0
        var valueB: Float = 0

        let cmdA = TrackVolumeCommand(
            trackID: UUID(), oldValue: 0, newValue: 0.5,
            applyChange: { _, v in valueA = v }
        )
        let cmdB = TrackPanCommand(
            trackID: UUID(), oldValue: 0, newValue: -1.0,
            applyChange: { _, v in valueB = v }
        )

        let compound = CompoundCommand(commands: [cmdA, cmdB], name: "Batch Edit")
        m.execute(compound)

        XCTAssertEqual(valueA, 0.5, accuracy: 0.01)
        XCTAssertEqual(valueB, -1.0, accuracy: 0.01)

        m.undo()
        XCTAssertEqual(valueA, 0.0, accuracy: 0.01, "Compound undo should revert all")
        XCTAssertEqual(valueB, 0.0, accuracy: 0.01, "Compound undo should revert all")
    }
}

// MARK: - CrashSafeStatePersistence Behavior Tests

@MainActor
final class CrashSafeStatePersistenceBehaviorTests: XCTestCase {

    // MARK: - SessionState Construction

    func testSessionState_DefaultInit_HasValidDefaults() {
        let state = SessionState()
        XCTAssertNotEqual(state.sessionId, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        XCTAssertEqual(state.durationSeconds, 0)
        XCTAssertNil(state.activePreset)
        XCTAssertTrue(state.bioSettings.enabled)
        XCTAssertEqual(state.audioSettings.volume, 0.8, accuracy: 0.01)
        XCTAssertEqual(state.audioSettings.bpm, 120, accuracy: 0.01)
        XCTAssertTrue(state.userData.isEmpty)
    }

    func testSessionState_Codable_RoundTrips() throws {
        var state = SessionState()
        state.activePreset = "Meditation"
        state.audioSettings.volume = 0.6
        state.bioSettings.coherenceThreshold = 0.75
        state.userData["testKey"] = "testValue"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionState.self, from: data)

        XCTAssertEqual(decoded.sessionId, state.sessionId)
        XCTAssertEqual(decoded.activePreset, "Meditation")
        XCTAssertEqual(decoded.audioSettings.volume, 0.6, accuracy: 0.01)
        XCTAssertEqual(decoded.bioSettings.coherenceThreshold, 0.75, accuracy: 0.01)
        XCTAssertEqual(decoded.userData["testKey"], "testValue")
    }

    func testSessionState_CorruptData_FailsGracefully() {
        let corrupt = Data("not valid json at all".utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let result = try? decoder.decode(SessionState.self, from: corrupt)
        XCTAssertNil(result, "Corrupt data should not decode")
    }

    func testSessionState_EmptyJSON_FailsGracefully() {
        let emptyJSON = Data("{}".utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let result = try? decoder.decode(SessionState.self, from: emptyJSON)
        XCTAssertNil(result, "Incomplete JSON should not decode")
    }

    // MARK: - SessionStateBuilder

    func testSessionStateBuilder_BuildsWithPreset() {
        let state = SessionStateBuilder()
            .withPreset("Focus")
            .build()
        XCTAssertEqual(state.activePreset, "Focus")
    }

    func testSessionStateBuilder_BuildsWithAudioSettings() {
        let state = SessionStateBuilder()
            .withAudioSettings(volume: 0.5, bpm: 140)
            .build()
        XCTAssertEqual(state.audioSettings.volume, 0.5, accuracy: 0.01)
        XCTAssertEqual(state.audioSettings.bpm, 140, accuracy: 0.01)
    }

    func testSessionStateBuilder_CoherenceReading_UpdatesMetrics() {
        let state = SessionStateBuilder()
            .withCoherenceReading(0.8)
            .withCoherenceReading(0.6)
            .build()
        XCTAssertEqual(state.metrics.coherenceReadings, 2)
        XCTAssertEqual(state.metrics.peakCoherence, 0.8, accuracy: 0.01)
        // Average should be (0.8 + 0.6) / 2 = 0.7 via running average
        XCTAssertEqual(state.metrics.averageCoherence, 0.7, accuracy: 0.01)
    }

    func testSessionStateBuilder_UserData_Stored() {
        let state = SessionStateBuilder()
            .withUserData("theme", value: "dark")
            .build()
        XCTAssertEqual(state.userData["theme"], "dark")
    }

    func testSessionStateBuilder_ChainedCalls_ProducesValidState() {
        let state = SessionStateBuilder()
            .withPreset("Live")
            .withAudioSettings(volume: 0.9, bpm: 128)
            .withBioSettings(enabled: true, coherenceThreshold: 0.5)
            .withCoherenceReading(0.85)
            .withUserData("mode", value: "performance")
            .build()

        XCTAssertEqual(state.activePreset, "Live")
        XCTAssertEqual(state.audioSettings.volume, 0.9, accuracy: 0.01)
        XCTAssertEqual(state.audioSettings.bpm, 128, accuracy: 0.01)
        XCTAssertTrue(state.bioSettings.enabled)
        XCTAssertEqual(state.bioSettings.coherenceThreshold, 0.5, accuracy: 0.01)
        XCTAssertEqual(state.metrics.peakCoherence, 0.85, accuracy: 0.01)
        XCTAssertEqual(state.userData["mode"], "performance")
    }

    // MARK: - CrashSafeStatePersistence Singleton

    func testCrashSafeStatePersistence_SharedInstance_Exists() {
        let persistence = CrashSafeStatePersistence.shared
        XCTAssertNotNil(persistence, "Shared instance must exist")
    }

    func testCrashSafeStatePersistence_ClearAllState_ResetsPendingRecovery() {
        let persistence = CrashSafeStatePersistence.shared
        persistence.clearAllState()
        XCTAssertFalse(persistence.hasPendingRecovery, "No recovery after clearing")
    }

    func testCrashSafeStatePersistence_DismissRecovery_ClearsPendingFlag() {
        let persistence = CrashSafeStatePersistence.shared
        persistence.dismissRecovery()
        XCTAssertFalse(persistence.hasPendingRecovery)
    }
}

#endif
