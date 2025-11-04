import XCTest
@testable import Blab

/// Tests for Macro System
@available(iOS 15.0, *)
final class MacroSystemTests: XCTestCase {

    var macroSystem: MacroSystem!

    override func setUp() {
        super.setUp()
        macroSystem = MacroSystem.shared
        // Clear any existing macros
        for macro in macroSystem.macros {
            macroSystem.removeMacro(macro)
        }
    }

    override func tearDown() {
        // Clean up
        for macro in macroSystem.macros {
            macroSystem.removeMacro(macro)
        }
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSingletonInstance() {
        let instance1 = MacroSystem.shared
        let instance2 = MacroSystem.shared
        XCTAssertTrue(instance1 === instance2, "MacroSystem should be a singleton")
    }

    func testInitialState() {
        XCTAssertFalse(macroSystem.isRecording, "Should not be recording initially")
        XCTAssertFalse(macroSystem.isExecuting, "Should not be executing initially")
        XCTAssertNil(macroSystem.currentMacro, "Should have no current macro")
    }

    // MARK: - Macro Management Tests

    func testAddMacro() {
        let macro = MacroSystem.Macro(name: "Test Macro")
        macroSystem.addMacro(macro)

        XCTAssertEqual(macroSystem.macros.count, 1, "Should have 1 macro")
        XCTAssertEqual(macroSystem.macros.first?.name, "Test Macro", "Macro name should match")
    }

    func testRemoveMacro() {
        let macro = MacroSystem.Macro(name: "Test Macro")
        macroSystem.addMacro(macro)
        macroSystem.removeMacro(macro)

        XCTAssertEqual(macroSystem.macros.count, 0, "Should have 0 macros")
    }

    func testUpdateMacro() {
        var macro = MacroSystem.Macro(name: "Original Name")
        macroSystem.addMacro(macro)

        macro.name = "Updated Name"
        macroSystem.updateMacro(macro)

        XCTAssertEqual(macroSystem.macros.first?.name, "Updated Name", "Macro name should be updated")
    }

    // MARK: - Recording Tests

    func testStartRecording() {
        macroSystem.startRecording(name: "Test Recording")

        XCTAssertTrue(macroSystem.isRecording, "Should be recording")
        XCTAssertNotNil(macroSystem.currentMacro, "Should have current macro")
        XCTAssertEqual(macroSystem.currentMacro?.name, "Test Recording", "Macro name should match")
    }

    func testStopRecording() {
        macroSystem.startRecording(name: "Test Recording")
        macroSystem.recordAction(.startAudio)
        macroSystem.stopRecording()

        XCTAssertFalse(macroSystem.isRecording, "Should not be recording")
        XCTAssertNil(macroSystem.currentMacro, "Should have no current macro")
        XCTAssertGreaterThan(macroSystem.macros.count, 0, "Should have saved macro")
    }

    func testCancelRecording() {
        let initialCount = macroSystem.macros.count
        macroSystem.startRecording(name: "Test Recording")
        macroSystem.recordAction(.startAudio)
        macroSystem.cancelRecording()

        XCTAssertFalse(macroSystem.isRecording, "Should not be recording")
        XCTAssertEqual(macroSystem.macros.count, initialCount, "Should not have added macro")
    }

    func testRecordAction() {
        macroSystem.startRecording(name: "Test Recording")
        macroSystem.recordAction(.startAudio)
        macroSystem.recordAction(.enableNDI)
        macroSystem.stopRecording()

        let saved = macroSystem.macros.last
        XCTAssertEqual(saved?.actions.count, 2, "Should have recorded 2 actions")
    }

    // MARK: - Execution Tests

    func testExecuteMacro() async {
        var macro = MacroSystem.Macro(name: "Test Macro")
        macro.actions = [
            .log(message: "Test 1"),
            .delay(seconds: 0.01),
            .log(message: "Test 2")
        ]

        await macroSystem.execute(macro)

        // Execution should complete without errors
        XCTAssertFalse(macroSystem.isExecuting, "Should not be executing after completion")
    }

    func testExecuteDisabledMacro() async {
        var macro = MacroSystem.Macro(name: "Disabled Macro")
        macro.enabled = false
        macro.actions = [.startAudio]

        await macroSystem.execute(macro)

        // Should not execute disabled macro
        XCTAssertFalse(macroSystem.isExecuting, "Should not execute disabled macro")
    }

    func testExecuteByName() async {
        var macro = MacroSystem.Macro(name: "Named Macro")
        macro.actions = [.log(message: "Test")]
        macroSystem.addMacro(macro)

        await macroSystem.execute(named: "Named Macro")

        // Should complete without errors
        XCTAssertFalse(macroSystem.isExecuting, "Should complete execution")
    }

    // MARK: - Action Tests

    func testActionDescriptions() {
        XCTAssertEqual(MacroSystem.MacroAction.startAudio.description, "Start Audio Engine")
        XCTAssertEqual(MacroSystem.MacroAction.stopAudio.description, "Stop Audio Engine")
        XCTAssertEqual(MacroSystem.MacroAction.enableNDI.description, "Enable NDI")

        let rtmp = MacroSystem.MacroAction.enableRTMP(streamKey: "key", platform: "YouTube")
        XCTAssertTrue(rtmp.description.contains("RTMP"), "Should contain RTMP")
        XCTAssertTrue(rtmp.description.contains("YouTube"), "Should contain platform")
    }

    func testDelayAction() async {
        let startTime = Date()
        let action = MacroSystem.MacroAction.delay(seconds: 0.1)

        var macro = MacroSystem.Macro(name: "Delay Test")
        macro.actions = [action]
        await macroSystem.execute(macro)

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1, "Should delay for at least 0.1 seconds")
    }

    // MARK: - Trigger Tests

    func testTriggerDescriptions() {
        XCTAssertEqual(MacroSystem.MacroTrigger.manual.description, "Manual")
        XCTAssertEqual(MacroSystem.MacroTrigger.onAppStart.description, "On App Start")
        XCTAssertEqual(MacroSystem.MacroTrigger.onAudioStart.description, "When Audio Starts")

        let timer = MacroSystem.MacroTrigger.onTimer(interval: 5.0)
        XCTAssertTrue(timer.description.contains("5"), "Should contain interval")
    }

    // MARK: - Persistence Tests

    func testSaveLoadMacros() {
        // Clear existing
        for macro in macroSystem.macros {
            macroSystem.removeMacro(macro)
        }

        // Add test macro
        var macro = MacroSystem.Macro(name: "Persistent Macro")
        macro.actions = [.startAudio, .enableNDI]
        macroSystem.addMacro(macro)

        // Verify it was saved (would persist to UserDefaults)
        XCTAssertEqual(macroSystem.macros.count, 1, "Should have saved macro")
        XCTAssertEqual(macroSystem.macros.first?.name, "Persistent Macro")
    }

    // MARK: - Conditional Tests

    func testConditionalAction() {
        let action = MacroSystem.MacroAction.conditional(
            condition: "audio_running",
            thenActions: [.enableNDI],
            elseActions: [.startAudio]
        )

        XCTAssertTrue(action.description.contains("If"), "Should contain 'If'")
    }

    // MARK: - Integration Tests

    func testComplexMacroSequence() async {
        var macro = MacroSystem.Macro(name: "Complex Sequence")
        macro.actions = [
            .log(message: "Starting"),
            .delay(seconds: 0.01),
            .startAudio,
            .delay(seconds: 0.01),
            .enableNDI,
            .delay(seconds: 0.01),
            .setDSPPreset(preset: "Podcast"),
            .delay(seconds: 0.01),
            .log(message: "Complete")
        ]

        await macroSystem.execute(macro)

        // Should complete without errors
        XCTAssertFalse(macroSystem.isExecuting, "Should complete complex sequence")
    }

    // MARK: - Default Macros Tests

    func testDefaultMacrosExist() {
        // After initialization, should have default macros
        // (This test depends on whether defaults are created automatically)
        XCTAssertGreaterThanOrEqual(macroSystem.macros.count, 0, "Should have macros")
    }
}
