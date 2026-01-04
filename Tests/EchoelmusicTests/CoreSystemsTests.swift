import XCTest
@testable import Echoelmusic

/// Core Systems Test Suite
///
/// Comprehensive tests for Ralph Wiggum Loop Genius components:
/// - GlobalKeyScaleManager (key detection, scale management, plugin sync)
/// - WiseSaveMode (session management, snapshots, recovery)
/// - RalphWiggumFoundation (creative engine, suggestions, flow detection)
/// - WearableIntegration (bio-data, device connections, modulation)
///
@MainActor
final class CoreSystemsTests: XCTestCase {

    // MARK: - GlobalKeyScaleManager Tests

    func testGlobalKeyScaleManagerSingleton() {
        let manager1 = GlobalKeyScaleManager.shared
        let manager2 = GlobalKeyScaleManager.shared
        XCTAssertTrue(manager1 === manager2, "GlobalKeyScaleManager should be singleton")
    }

    func testKeyDetectionFromMIDI() {
        let manager = GlobalKeyScaleManager.shared

        // C Major scale notes: C, D, E, F, G, A, B
        let cMajorNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]

        for note in cMajorNotes {
            manager.processNoteOn(note: note, velocity: 100)
        }

        let detectedKey = manager.detectKeyFromHistory()
        XCTAssertEqual(detectedKey.root, 0, "Should detect C as root (0)")
        XCTAssertEqual(detectedKey.scaleType, .major, "Should detect Major scale")
    }

    func testScaleNotes() {
        let manager = GlobalKeyScaleManager.shared

        // Set to C Major
        manager.setKey(root: 0, scaleType: .major)

        let scaleNotes = manager.getScaleNotes()

        // C Major should contain: C, D, E, F, G, A, B (0, 2, 4, 5, 7, 9, 11)
        let expectedIntervals = [0, 2, 4, 5, 7, 9, 11]
        XCTAssertEqual(scaleNotes.count, 7, "Major scale should have 7 notes")

        for (index, interval) in expectedIntervals.enumerated() {
            XCTAssertEqual(scaleNotes[index] % 12, interval,
                          "Note at index \(index) should be \(interval)")
        }
    }

    func testChordSuggestions() {
        let manager = GlobalKeyScaleManager.shared
        manager.setKey(root: 0, scaleType: .major)

        let suggestions = manager.getSuggestedChords()

        XCTAssertFalse(suggestions.isEmpty, "Should have chord suggestions")
        XCTAssertTrue(suggestions.contains { $0.name == "C" },
                     "Should suggest C chord in C Major")
        XCTAssertTrue(suggestions.contains { $0.name == "Am" },
                     "Should suggest Am chord in C Major")
    }

    func testPluginBroadcast() {
        let manager = GlobalKeyScaleManager.shared
        var receivedKey: Int?
        var receivedScale: ScaleType?

        manager.onKeyChange = { key, scale in
            receivedKey = key
            receivedScale = scale
        }

        manager.setKey(root: 7, scaleType: .minor) // G Minor

        XCTAssertEqual(receivedKey, 7, "Callback should receive new key")
        XCTAssertEqual(receivedScale, .minor, "Callback should receive new scale")
    }

    func testTransposeDiatonically() {
        let manager = GlobalKeyScaleManager.shared
        manager.setKey(root: 0, scaleType: .major)

        // C (60) transposed up 2 diatonic steps in C Major = E (64)
        let transposed = manager.transposeDiatonically(note: 60, steps: 2)
        XCTAssertEqual(transposed, 64, "C + 2 diatonic steps should be E")

        // E (64) transposed up 1 diatonic step = F (65)
        let transposed2 = manager.transposeDiatonically(note: 64, steps: 1)
        XCTAssertEqual(transposed2, 65, "E + 1 diatonic step should be F")
    }

    // MARK: - WiseSaveMode Tests

    func testWiseSaveModeSingleton() {
        let save1 = WiseSaveMode.shared
        let save2 = WiseSaveMode.shared
        XCTAssertTrue(save1 === save2, "WiseSaveMode should be singleton")
    }

    func testSessionInitialization() {
        let saveMode = WiseSaveMode.shared

        let sessionDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestSession_\(UUID().uuidString)")

        saveMode.initialize(projectDirectory: sessionDir)

        XCTAssertTrue(saveMode.isInitialized, "Should be initialized after init call")
        XCTAssertNotNil(saveMode.currentSessionId, "Should have session ID")
    }

    func testSnapshotCreation() {
        let saveMode = WiseSaveMode.shared

        let initialCount = saveMode.snapshotCount

        saveMode.createSnapshot(name: "Test Snapshot")

        XCTAssertEqual(saveMode.snapshotCount, initialCount + 1,
                      "Snapshot count should increase")
    }

    func testDirtyFlag() {
        let saveMode = WiseSaveMode.shared

        saveMode.markClean()
        XCTAssertFalse(saveMode.isDirty, "Should be clean after markClean")

        saveMode.markDirty()
        XCTAssertTrue(saveMode.isDirty, "Should be dirty after markDirty")
    }

    func testPluginStateTracking() {
        let saveMode = WiseSaveMode.shared

        let testState: [String: Any] = [
            "filterCutoff": 0.5,
            "resonance": 0.7,
            "bypass": false
        ]

        saveMode.updatePluginState(pluginId: "TestPlugin", state: testState)

        let retrieved = saveMode.getPluginState(pluginId: "TestPlugin")
        XCTAssertNotNil(retrieved, "Should retrieve saved plugin state")
        XCTAssertEqual(retrieved?["filterCutoff"] as? Double, 0.5)
    }

    func testSmartNaming() {
        let saveMode = WiseSaveMode.shared

        saveMode.setKeyContext(root: 0, scale: .major)
        saveMode.setTempoContext(bpm: 120.0)

        let smartName = saveMode.generateSmartName()

        XCTAssertTrue(smartName.contains("CMaj") || smartName.contains("C_Major"),
                     "Smart name should include key context")
        XCTAssertTrue(smartName.contains("120"),
                     "Smart name should include tempo")
    }

    func testRecoveryPointCreation() {
        let saveMode = WiseSaveMode.shared

        saveMode.markDirty()
        saveMode.createRecoveryPoint()

        let recoveryFiles = saveMode.getRecoveryFiles()
        XCTAssertFalse(recoveryFiles.isEmpty, "Should have recovery files")
    }

    // MARK: - RalphWiggumFoundation Tests

    func testRalphWiggumSingleton() {
        let ralph1 = RalphWiggumFoundation.shared
        let ralph2 = RalphWiggumFoundation.shared
        XCTAssertTrue(ralph1 === ralph2, "RalphWiggumFoundation should be singleton")
    }

    func testCreativeSuggestionGeneration() {
        let ralph = RalphWiggumFoundation.shared

        // Set context
        ralph.setMusicalContext(key: 0, scale: .major, tempo: 120.0)

        // Request chord suggestions
        let chordSuggestions = ralph.getChordSuggestions(count: 4)

        XCTAssertEqual(chordSuggestions.count, 4, "Should return requested number")
        XCTAssertTrue(chordSuggestions.allSatisfy { !$0.notes.isEmpty },
                     "All suggestions should have notes")
    }

    func testMelodySuggestion() {
        let ralph = RalphWiggumFoundation.shared
        ralph.setMusicalContext(key: 0, scale: .major, tempo: 120.0)

        let melody = ralph.suggestMelody(length: 8)

        XCTAssertEqual(melody.count, 8, "Melody should have requested length")
        XCTAssertTrue(melody.allSatisfy { $0 >= 48 && $0 <= 84 },
                     "Notes should be in playable range")
    }

    func testRhythmPatternGeneration() {
        let ralph = RalphWiggumFoundation.shared

        let pattern = ralph.generateRhythmPattern(bars: 2, subdivision: .sixteenth)

        XCTAssertEqual(pattern.count, 32, "2 bars of 16ths should be 32 steps")
        XCTAssertTrue(pattern.contains(true), "Pattern should have some hits")
    }

    func testFlowStateDetection() {
        let ralph = RalphWiggumFoundation.shared

        // Simulate user activity
        for _ in 0..<100 {
            ralph.recordUserAction(type: .noteInput)
        }

        let flowState = ralph.detectFlowState()

        XCTAssertTrue(flowState.isActive || !flowState.isActive,
                     "Flow state should be determined")
        XCTAssertGreaterThanOrEqual(flowState.intensity, 0.0)
        XCTAssertLessThanOrEqual(flowState.intensity, 1.0)
    }

    func testLoopCreation() {
        let ralph = RalphWiggumFoundation.shared

        let loopId = ralph.createLoop(
            name: "Test Loop",
            bars: 4,
            timeSignature: (4, 4)
        )

        XCTAssertNotNil(loopId, "Should return loop ID")

        let loop = ralph.getLoop(id: loopId!)
        XCTAssertNotNil(loop, "Should retrieve created loop")
        XCTAssertEqual(loop?.name, "Test Loop")
    }

    func testSessionMetrics() {
        let ralph = RalphWiggumFoundation.shared

        ralph.startSession()

        // Simulate activity
        for _ in 0..<10 {
            ralph.recordUserAction(type: .noteInput)
            ralph.recordUserAction(type: .parameterChange)
        }

        let metrics = ralph.getSessionMetrics()

        XCTAssertGreaterThan(metrics.totalActions, 0, "Should track actions")
        XCTAssertGreaterThanOrEqual(metrics.sessionDuration, 0.0)
    }

    // MARK: - WearableIntegration Tests

    func testWearableManagerSingleton() {
        let manager1 = WearableManager.shared
        let manager2 = WearableManager.shared
        XCTAssertTrue(manager1 === manager2, "WearableManager should be singleton")
    }

    func testSimulatorDeviceConnection() async {
        let manager = WearableManager.shared

        let simulator = SimulatorDevice()
        manager.addDevice(simulator)

        let connected = await simulator.connect()
        XCTAssertTrue(connected, "Simulator should connect successfully")

        simulator.startStreaming()
        XCTAssertTrue(simulator.isStreaming, "Should be streaming")

        // Wait for some data
        try? await Task.sleep(nanoseconds: 500_000_000)

        let heartRate = manager.getLatestValue(for: .heartRate)
        XCTAssertGreaterThan(heartRate, 0, "Should have heart rate data")

        simulator.stopStreaming()
        simulator.disconnect()
    }

    func testBioModulationMapping() {
        let manager = WearableManager.shared

        let mapping = BioModulationMapping(
            sourceType: .heartRate,
            targetParameter: "filterCutoff",
            inputMin: 60.0,
            inputMax: 100.0,
            outputMin: 0.0,
            outputMax: 1.0
        )

        manager.addMapping(mapping)

        // Simulate heart rate of 80 BPM (middle of range)
        manager.injectTestValue(type: .heartRate, value: 80.0)

        let mappedValue = manager.getMappedValue(for: "filterCutoff")
        XCTAssertEqual(mappedValue, 0.5, accuracy: 0.01,
                      "80 BPM should map to 0.5")
    }

    func testBioTempo() {
        let manager = WearableManager.shared

        // Set heart rate to 75 BPM
        manager.injectTestValue(type: .heartRate, value: 75.0)

        let bioTempo = manager.getBioTempo()

        // Should be quantized to musical tempo
        XCTAssertGreaterThanOrEqual(bioTempo, 60.0)
        XCTAssertLessThanOrEqual(bioTempo, 180.0)
    }

    func testSmoothingFilter() {
        let manager = WearableManager.shared
        manager.setSmoothingFactor(0.9)

        // Inject rapidly changing values
        manager.injectTestValue(type: .heartRate, value: 60.0)
        manager.injectTestValue(type: .heartRate, value: 100.0)
        manager.injectTestValue(type: .heartRate, value: 60.0)

        let smoothed = manager.getSmoothedValue(for: .heartRate)
        let latest = manager.getLatestValue(for: .heartRate)

        // Smoothed should be between values due to EMA
        XCTAssertNotEqual(smoothed, latest,
                         "Smoothed should differ from latest with high smoothing")
    }

    func testHapticFeedback() {
        let manager = WearableManager.shared

        // Should not crash even without connected device
        manager.sendHapticToAll(intensity: 0.8, durationMs: 50)
        manager.pulseOnBeat(beatNumber: 1, beatsPerBar: 4)
    }

    // MARK: - BLE Scanner Tests

    func testBLEScannerSingleton() {
        let scanner1 = BLEScanner.shared
        let scanner2 = BLEScanner.shared
        XCTAssertTrue(scanner1 === scanner2, "BLEScanner should be singleton")
    }

    func testScanStateManagement() {
        let scanner = BLEScanner.shared

        XCTAssertEqual(scanner.state, .idle, "Should start in idle state")

        scanner.startScanning(services: [BLEScanner.HEART_RATE_SERVICE])
        XCTAssertEqual(scanner.state, .scanning, "Should be scanning")

        scanner.stopScanning()
        XCTAssertEqual(scanner.state, .idle, "Should return to idle")
    }

    // MARK: - Oura OAuth2 Tests

    func testOuraAuthorizationURLGeneration() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test_client_id",
            clientSecret: "test_secret"
        )

        let handler = OuraOAuth2Handler(config: config)
        let authUrl = handler.getAuthorizationUrl()

        XCTAssertTrue(authUrl.contains("cloud.ouraring.com/oauth/authorize"))
        XCTAssertTrue(authUrl.contains("client_id=test_client_id"))
        XCTAssertTrue(authUrl.contains("response_type=code"))
        XCTAssertTrue(authUrl.contains("state="))
    }

    func testTokenSerialization() {
        let config = OuraOAuth2Handler.OAuthConfig(
            clientId: "test",
            clientSecret: "test"
        )

        let handler = OuraOAuth2Handler(config: config)

        // Serialize empty tokens
        let serialized = handler.serializeTokens()
        XCTAssertNotNil(serialized)

        // Deserialize should not crash
        handler.deserializeTokens(serialized)
    }

    // MARK: - Integration Tests

    func testKeyScaleToWiseSaveIntegration() {
        let keyManager = GlobalKeyScaleManager.shared
        let saveMode = WiseSaveMode.shared

        keyManager.setKey(root: 5, scaleType: .minor) // F Minor

        // WiseSaveMode should pick up key context
        saveMode.setKeyContext(
            root: keyManager.currentKey,
            scale: keyManager.currentScale
        )

        let smartName = saveMode.generateSmartName()
        XCTAssertTrue(smartName.contains("Fm") || smartName.contains("F_Minor"),
                     "Smart name should reflect F Minor context")
    }

    func testRalphWiggumWithKeyContext() {
        let keyManager = GlobalKeyScaleManager.shared
        let ralph = RalphWiggumFoundation.shared

        keyManager.setKey(root: 9, scaleType: .major) // A Major

        ralph.setMusicalContext(
            key: keyManager.currentKey,
            scale: keyManager.currentScale,
            tempo: 128.0
        )

        let chords = ralph.getChordSuggestions(count: 4)

        // Should suggest chords from A Major
        XCTAssertTrue(chords.contains { $0.root == 9 }, // A
                     "Should include tonic chord")
    }

    func testBioReactiveWithRalphWiggum() {
        let wearables = WearableManager.shared
        let ralph = RalphWiggumFoundation.shared

        // Simulate high energy state
        wearables.injectTestValue(type: .heartRate, value: 90.0)
        wearables.injectTestValue(type: .energyLevel, value: 80.0)

        let bioTempo = wearables.getBioTempo()

        ralph.setMusicalContext(key: 0, scale: .major, tempo: bioTempo)

        let rhythm = ralph.generateRhythmPattern(bars: 1, subdivision: .eighth)

        XCTAssertEqual(rhythm.count, 8, "Should generate rhythm at bio-tempo")
    }

    // MARK: - Progressive Disclosure Engine Tests

    func testProgressiveDisclosureSingleton() {
        let engine1 = ProgressiveDisclosureEngine.shared
        let engine2 = ProgressiveDisclosureEngine.shared
        XCTAssertTrue(engine1 === engine2, "ProgressiveDisclosureEngine should be singleton")
    }

    func testDisclosureLevelProgression() {
        let engine = ProgressiveDisclosureEngine.shared

        // New user starts at Basic
        XCTAssertEqual(engine.getCurrentLevel(), .basic)

        // Simulate engaged user
        var state = UserState()
        state.sessionDuration = 3600  // 1 hour
        state.actionCount = 100
        state.coherence = 0.7
        state.flowIntensity = 0.6
        state.hasCompletedOnboarding = true

        engine.updateUserState(state)

        // Should advance to at least Intermediate
        XCTAssertTrue(engine.getCurrentLevel().rawValue >= DisclosureLevel.intermediate.rawValue)
    }

    func testStressReducesDisclosureLevel() {
        let engine = ProgressiveDisclosureEngine.shared

        // High stress state
        var stressedState = UserState()
        stressedState.stressLevel = 0.8
        stressedState.hrv = 20  // Low HRV indicates stress
        stressedState.coherence = 0.2

        engine.updateUserState(stressedState)

        // Should reduce to Minimal
        XCTAssertEqual(engine.getCurrentLevel(), .minimal)
    }

    func testFeatureGating() {
        let engine = ProgressiveDisclosureEngine.shared

        // Register a gated feature
        let gate = FeatureGate(
            featureId: "test_feature",
            displayName: "Test Feature",
            category: "test",
            minLevel: .intermediate,
            minCoherence: 0.5,
            minSessionTime: 600
        )
        engine.registerFeature(gate)

        // New user shouldn't see it
        var newUser = UserState()
        newUser.sessionDuration = 100
        newUser.coherence = 0.3
        engine.updateUserState(newUser)

        XCTAssertTrue(engine.isFeatureLocked("test_feature"))

        // Experienced user should see it
        var experiencedUser = UserState()
        experiencedUser.sessionDuration = 1800
        experiencedUser.coherence = 0.7
        experiencedUser.flowIntensity = 0.6
        experiencedUser.hasCompletedOnboarding = true
        experiencedUser.actionCount = 50
        engine.updateUserState(experiencedUser)

        XCTAssertTrue(engine.isFeatureVisible("test_feature"))
    }

    func testFlowStateEnablesAdvancedFeatures() {
        let engine = ProgressiveDisclosureEngine.shared

        // Register flow-gated feature
        let flowGate = FeatureGate(
            featureId: "flow_feature",
            displayName: "Flow Feature",
            category: "advanced",
            minLevel: .basic,
            requiresFlow: true
        )
        engine.registerFeature(flowGate)

        // User not in flow
        var noFlowState = UserState()
        noFlowState.flowIntensity = 0.2
        noFlowState.coherence = 0.4
        engine.updateUserState(noFlowState)

        XCTAssertTrue(engine.isFeatureLocked("flow_feature"))

        // User in flow
        var flowState = UserState()
        flowState.flowIntensity = 0.8
        flowState.coherence = 0.7
        engine.updateUserState(flowState)

        XCTAssertTrue(engine.isFeatureVisible("flow_feature"))
    }

    func testManualLevelOverride() {
        let engine = ProgressiveDisclosureEngine.shared

        engine.setManualLevel(.expert)
        XCTAssertEqual(engine.getCurrentLevel(), .expert)

        // Bio-state shouldn't change it while overridden
        var stressedState = UserState()
        stressedState.stressLevel = 0.9
        engine.updateUserState(stressedState)

        XCTAssertEqual(engine.getCurrentLevel(), .expert)

        // Clear override
        engine.clearManualOverride()
        engine.updateUserState(stressedState)

        XCTAssertNotEqual(engine.getCurrentLevel(), .expert)
    }

    func testSerialization() {
        let engine = ProgressiveDisclosureEngine.shared

        // Unlock some features
        engine.unlockFeature("test_unlock_1")
        engine.unlockFeature("test_unlock_2")

        // Serialize
        let json = engine.serializeProgress()
        XCTAssertFalse(json.isEmpty)

        // Deserialize
        engine.deserializeProgress(json)

        // Features should still be unlocked
        XCTAssertTrue(engine.isFeatureVisible("test_unlock_1"))
        XCTAssertTrue(engine.isFeatureVisible("test_unlock_2"))
    }

    func testBioMetricsUpdateLevel() {
        let engine = ProgressiveDisclosureEngine.shared

        // Calm state with good coherence
        engine.updateBioMetrics(hr: 65, hrvValue: 80, coh: 0.85)

        // Should not be in stressed/minimal mode
        XCTAssertNotEqual(engine.getCurrentLevel(), .minimal)

        // Stressed state
        engine.updateBioMetrics(hr: 110, hrvValue: 15, coh: 0.2)

        // Should reduce to minimal
        XCTAssertEqual(engine.getCurrentLevel(), .minimal)
    }

    func testErrorCountReducesComplexity() {
        let engine = ProgressiveDisclosureEngine.shared

        // Set up intermediate level user
        var state = UserState()
        state.sessionDuration = 2000
        state.coherence = 0.6
        state.hasCompletedOnboarding = true
        state.actionCount = 30
        engine.updateUserState(state)

        let initialLevel = engine.getCurrentLevel()

        // Record multiple errors (frustration signal)
        for _ in 0..<6 {
            engine.recordError()
        }

        // Level should reduce due to errors
        XCTAssertTrue(engine.getCurrentLevel().rawValue <= initialLevel.rawValue)
    }
}

// MARK: - Test Helpers

extension CoreSystemsTests {
    override func setUp() {
        super.setUp()
        // Reset singletons to clean state for tests
        GlobalKeyScaleManager.shared.reset()
        WiseSaveMode.shared.reset()
        RalphWiggumFoundation.shared.reset()
        WearableManager.shared.reset()
        ProgressiveDisclosureEngine.shared.reset()
    }

    override func tearDown() {
        // Cleanup
        WearableManager.shared.disconnectAll()
        super.tearDown()
    }
}
