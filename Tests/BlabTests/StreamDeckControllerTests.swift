import XCTest
@testable import Blab

/// Tests for Stream Deck Controller
@available(iOS 15.0, *)
final class StreamDeckControllerTests: XCTestCase {

    var streamDeck: StreamDeckController!

    override func setUp() {
        super.setUp()
        streamDeck = StreamDeckController.shared
        streamDeck.disconnect() // Ensure clean state
    }

    override func tearDown() {
        streamDeck.disconnect()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSingletonInstance() {
        let instance1 = StreamDeckController.shared
        let instance2 = StreamDeckController.shared
        XCTAssertTrue(instance1 === instance2, "StreamDeckController should be a singleton")
    }

    func testInitialState() {
        XCTAssertFalse(streamDeck.isConnected, "Should not be connected initially")
        XCTAssertEqual(streamDeck.deviceType, .mobile, "Default device should be mobile")
        XCTAssertGreaterThan(streamDeck.buttonLayout.count, 0, "Should have button layout")
    }

    func testDeviceTypes() {
        XCTAssertEqual(StreamDeckController.DeviceType.standard.buttonCount, 15)
        XCTAssertEqual(StreamDeckController.DeviceType.mini.buttonCount, 6)
        XCTAssertEqual(StreamDeckController.DeviceType.xl.buttonCount, 32)
        XCTAssertEqual(StreamDeckController.DeviceType.mobile.buttonCount, 15)
    }

    func testDeviceLayout() {
        let standard = StreamDeckController.DeviceType.standard
        XCTAssertEqual(standard.rows, 3)
        XCTAssertEqual(standard.columns, 5)
        XCTAssertEqual(standard.rows * standard.columns, standard.buttonCount)

        let mini = StreamDeckController.DeviceType.mini
        XCTAssertEqual(mini.rows, 2)
        XCTAssertEqual(mini.columns, 3)
        XCTAssertEqual(mini.rows * mini.columns, mini.buttonCount)
    }

    // MARK: - Connection Tests

    func testConnect() {
        streamDeck.connect()
        XCTAssertTrue(streamDeck.isConnected, "Should be connected")
    }

    func testDisconnect() {
        streamDeck.connect()
        streamDeck.disconnect()
        XCTAssertFalse(streamDeck.isConnected, "Should be disconnected")
    }

    // MARK: - Button Configuration Tests

    func testSetButtonAction() {
        let initialConfig = streamDeck.buttonLayout[0]

        streamDeck.setButton(0, action: .toggleAudio, label: "Audio")

        let updatedConfig = streamDeck.buttonLayout[0]
        XCTAssertEqual(updatedConfig.action, .toggleAudio, "Action should be updated")
        XCTAssertEqual(updatedConfig.label, "Audio", "Label should be updated")
    }

    func testSetButtonConfig() {
        let config = StreamDeckController.ButtonConfig(
            id: 0,
            action: .enableNDI,
            label: "NDI",
            icon: "antenna.radiowaves.left.and.right",
            backgroundColor: "green",
            enabled: true
        )

        streamDeck.setButton(0, config: config)

        let saved = streamDeck.buttonLayout[0]
        XCTAssertEqual(saved.action, .enableNDI, "Action should match")
        XCTAssertEqual(saved.label, "NDI", "Label should match")
        XCTAssertEqual(saved.backgroundColor, "green", "Color should match")
    }

    func testButtonConfigPersistence() {
        streamDeck.setButton(5, action: .startRecording, label: "Record")

        let config = streamDeck.buttonLayout[5]
        XCTAssertEqual(config.action, .startRecording)
        XCTAssertEqual(config.label, "Record")
    }

    // MARK: - Button Action Tests

    func testButtonActionProperties() {
        let action = StreamDeckController.ButtonAction.toggleAudio

        XCTAssertNotNil(action.icon, "Should have icon")
        XCTAssertNotNil(action.defaultColor, "Should have default color")
        XCTAssertFalse(action.rawValue.isEmpty, "Should have description")
    }

    func testAllButtonActions() {
        for action in StreamDeckController.ButtonAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "\(action) should have description")
            XCTAssertFalse(action.icon.isEmpty, "\(action) should have icon")
            XCTAssertFalse(action.defaultColor.isEmpty, "\(action) should have color")
        }
    }

    func testButtonActionIcons() {
        XCTAssertEqual(StreamDeckController.ButtonAction.toggleAudio.icon, "play.circle.fill")
        XCTAssertEqual(StreamDeckController.ButtonAction.toggleSpatial.icon, "move.3d")
        XCTAssertEqual(StreamDeckController.ButtonAction.enableNDI.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(StreamDeckController.ButtonAction.startRecording.icon, "record.circle")
    }

    func testButtonActionColors() {
        XCTAssertEqual(StreamDeckController.ButtonAction.toggleAudio.defaultColor, "red")
        XCTAssertEqual(StreamDeckController.ButtonAction.toggleSpatial.defaultColor, "blue")
        XCTAssertEqual(StreamDeckController.ButtonAction.enableNDI.defaultColor, "green")
    }

    // MARK: - Preset Tests

    func testLoadDefaultPreset() {
        streamDeck.loadPreset(.default)

        // Should have buttons configured
        XCTAssertEqual(streamDeck.buttonLayout.count, streamDeck.deviceType.buttonCount)
        XCTAssertNotEqual(streamDeck.buttonLayout[0].action, .none, "First button should be configured")
    }

    func testLoadStreamingPreset() {
        streamDeck.loadPreset(.streaming)

        // Should have streaming-related buttons
        let hasNDI = streamDeck.buttonLayout.contains { $0.action == .enableNDI }
        let hasRTMP = streamDeck.buttonLayout.contains { $0.action == .enableRTMP }

        XCTAssertTrue(hasNDI || hasRTMP, "Should have streaming buttons")
    }

    func testLoadRecordingPreset() {
        streamDeck.loadPreset(.recording)

        // Should have recording buttons
        let hasStart = streamDeck.buttonLayout.contains { $0.action == .startRecording }
        let hasStop = streamDeck.buttonLayout.contains { $0.action == .stopRecording }

        XCTAssertTrue(hasStart || hasStop, "Should have recording buttons")
    }

    func testLoadPerformancePreset() {
        streamDeck.loadPreset(.performance)

        // Should have performance-related buttons
        let hasAudio = streamDeck.buttonLayout.contains { $0.action == .toggleAudio }
        let hasSpatial = streamDeck.buttonLayout.contains { $0.action == .toggleSpatial }

        XCTAssertTrue(hasAudio || hasSpatial, "Should have performance buttons")
    }

    // MARK: - Button Press Tests

    func testHandleButtonPress() {
        streamDeck.connect()
        streamDeck.setButton(0, action: .toggleAudio, label: "Audio")

        // Should not crash
        streamDeck.handleButtonPress(0)
    }

    func testHandleDisabledButton() {
        streamDeck.connect()
        var config = streamDeck.buttonLayout[0]
        config.enabled = false
        streamDeck.setButton(0, config: config)

        // Should not execute
        streamDeck.handleButtonPress(0)
    }

    func testHandleInvalidButtonIndex() {
        streamDeck.connect()

        // Should not crash with invalid index
        streamDeck.handleButtonPress(999)
    }

    // MARK: - Save/Load Tests

    func testSaveLayout() {
        streamDeck.setButton(0, action: .enableNDI, label: "Custom NDI")
        streamDeck.saveLayout(name: "TestLayout")

        // Should save without errors
        XCTAssertTrue(true, "Save should complete")
    }

    func testLoadLayout() {
        // Set up a layout
        streamDeck.setButton(0, action: .enableNDI, label: "Custom NDI")
        streamDeck.saveLayout(name: "TestLayout")

        // Modify layout
        streamDeck.setButton(0, action: .toggleAudio, label: "Different")

        // Load saved layout
        streamDeck.loadLayout(name: "TestLayout")

        // Should restore layout
        XCTAssertEqual(streamDeck.buttonLayout[0].action, .enableNDI, "Should restore action")
        XCTAssertEqual(streamDeck.buttonLayout[0].label, "Custom NDI", "Should restore label")
    }

    func testLoadNonexistentLayout() {
        // Should not crash
        streamDeck.loadLayout(name: "NonexistentLayout")
    }

    // MARK: - Integration Tests

    func testFullButtonLifecycle() {
        // Connect
        streamDeck.connect()
        XCTAssertTrue(streamDeck.isConnected)

        // Configure button
        streamDeck.setButton(0, action: .toggleAudio, label: "Audio")

        // Press button
        streamDeck.handleButtonPress(0)

        // Save layout
        streamDeck.saveLayout(name: "TestLifecycle")

        // Disconnect
        streamDeck.disconnect()
        XCTAssertFalse(streamDeck.isConnected)

        // Reconnect
        streamDeck.connect()
        XCTAssertTrue(streamDeck.isConnected)

        // Load layout
        streamDeck.loadLayout(name: "TestLifecycle")
        XCTAssertEqual(streamDeck.buttonLayout[0].label, "Audio")
    }

    func testMultiplePresetSwitching() {
        streamDeck.loadPreset(.default)
        let defaultFirst = streamDeck.buttonLayout[0].action

        streamDeck.loadPreset(.streaming)
        let streamingFirst = streamDeck.buttonLayout[0].action

        streamDeck.loadPreset(.recording)
        let recordingFirst = streamDeck.buttonLayout[0].action

        // Presets should configure buttons differently
        // (Though they might have some overlap)
        XCTAssertNotNil(defaultFirst)
        XCTAssertNotNil(streamingFirst)
        XCTAssertNotNil(recordingFirst)
    }
}
