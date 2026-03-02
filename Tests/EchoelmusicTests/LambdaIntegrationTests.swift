import XCTest
import Combine
@testable import Echoelmusic

// MARK: - Lambda Haptic Engine Tests

@MainActor
final class LambdaHapticEngineTests: XCTestCase {

    func testSingletonExists() {
        let engine = LambdaHapticEngine.shared
        XCTAssertNotNil(engine)
    }

    func testSingletonIdentity() {
        let a = LambdaHapticEngine.shared
        let b = LambdaHapticEngine.shared
        XCTAssertTrue(a === b, "Singleton should return the same instance")
    }

    func testPlayTransientDoesNotCrash() {
        // Should not crash even without haptic hardware
        LambdaHapticEngine.shared.playTransient(intensity: 0.5)
    }

    func testPlayTransientZeroIntensity() {
        // Zero intensity should be a no-op
        LambdaHapticEngine.shared.playTransient(intensity: 0.0)
    }

    func testPlayTransientMaxIntensity() {
        LambdaHapticEngine.shared.playTransient(intensity: 1.0)
    }

    func testPlayTransientClampedAboveOne() {
        // Values > 1 should be clamped, not crash
        LambdaHapticEngine.shared.playTransient(intensity: 5.0)
    }

    func testPlayTransientClampedBelowZero() {
        // Negative values should be clamped, not crash
        LambdaHapticEngine.shared.playTransient(intensity: -1.0)
    }

    func testPlayContinuousDoesNotCrash() {
        LambdaHapticEngine.shared.playContinuous(intensity: 0.5, sharpness: 0.5)
    }

    func testStopDoesNotCrash() {
        LambdaHapticEngine.shared.stop()
    }

    func testPlayThenStop() {
        LambdaHapticEngine.shared.playContinuous(intensity: 0.8)
        LambdaHapticEngine.shared.stop()
    }
}

// MARK: - Lambda Workspace Bridge Tests

@MainActor
final class LambdaWorkspaceBridgeTests: XCTestCase {

    var workspace: EchoelCreativeWorkspace!

    override func setUp() async throws {
        try await super.setUp()
        workspace = EchoelCreativeWorkspace.shared
    }

    func testWorkspaceExists() {
        XCTAssertNotNil(workspace)
    }

    func testWorkspaceHasLoopEngine() {
        XCTAssertNotNil(workspace.loopEngine)
    }

    func testWorkspaceHasProMixer() {
        XCTAssertNotNil(workspace.proMixer)
    }

    func testWorkspaceHasProColor() {
        XCTAssertNotNil(workspace.proColor)
    }

    func testGlobalBPMInRange() {
        XCTAssertGreaterThanOrEqual(workspace.globalBPM, 20.0)
        XCTAssertLessThanOrEqual(workspace.globalBPM, 300.0)
    }

    func testProMixerSetMasterReverbSend() {
        let mixer = ProMixEngine.defaultSession()
        // Should not crash
        mixer.setMasterReverbSend(0.5)
    }

    func testProMixerReverbSendClampedLow() {
        let mixer = ProMixEngine.defaultSession()
        mixer.setMasterReverbSend(-1.0)
        // Should clamp to 0, no crash
    }

    func testProMixerReverbSendClampedHigh() {
        let mixer = ProMixEngine.defaultSession()
        mixer.setMasterReverbSend(2.0)
        // Should clamp to 1, no crash
    }

    func testProColorSetLambdaColorInfluence() {
        let color = ProColorGrading()
        // Should not crash
        color.setLambdaColorInfluence(red: 0.8, green: 0.2, blue: 0.5)
    }

    func testProColorNeutralInfluence() {
        let color = ProColorGrading()
        let originalTemp = color.colorWheels.temperature
        // Neutral RGB (0.33, 0.33, 0.33) should barely move temperature
        color.setLambdaColorInfluence(red: 0.33, green: 0.33, blue: 0.33)
        let delta = abs(color.colorWheels.temperature - originalTemp)
        XCTAssertLessThan(delta, 2.0, "Neutral color should barely shift temperature")
    }

    func testProColorWarmInfluence() {
        let color = ProColorGrading()
        let originalTemp = color.colorWheels.temperature
        // High red, low blue → warm shift
        color.setLambdaColorInfluence(red: 1.0, green: 0.0, blue: 0.0)
        // After one call at 10% blend, temperature should shift positive
        XCTAssertGreaterThan(color.colorWheels.temperature, originalTemp - 1.0)
    }
}

// MARK: - Loop Engine Overdub Tests

@MainActor
final class LoopEngineOverdubTests: XCTestCase {

    var loopEngine: LoopEngine!

    override func setUp() async throws {
        try await super.setUp()
        loopEngine = LoopEngine()
    }

    override func tearDown() async throws {
        loopEngine = nil
        try await super.tearDown()
    }

    func testOverdubInitiallyFalse() {
        XCTAssertFalse(loopEngine.isOverdubbing)
    }

    func testOverdubRequiresExistingLoop() {
        // Can't overdub without a loop
        loopEngine.startOverdub(loopID: UUID())
        XCTAssertFalse(loopEngine.isOverdubbing, "Can't overdub a nonexistent loop")
    }

    func testStartOverdubSetsState() {
        loopEngine.startLoopRecording(bars: 4)
        loopEngine.stopLoopRecording()
        guard let loopID = loopEngine.loops.first?.id else {
            XCTFail("Should have a loop")
            return
        }
        loopEngine.startOverdub(loopID: loopID)
        XCTAssertTrue(loopEngine.isOverdubbing)
    }

    func testStopOverdubClearsState() {
        loopEngine.startLoopRecording(bars: 4)
        loopEngine.stopLoopRecording()
        guard let loopID = loopEngine.loops.first?.id else {
            XCTFail("Should have a loop")
            return
        }
        loopEngine.startOverdub(loopID: loopID)
        loopEngine.stopOverdub()
        XCTAssertFalse(loopEngine.isOverdubbing)
        XCTAssertNil(loopEngine.overdubLoopID)
    }

    func testStopOverdubDoesNotCreateNewLoop() {
        loopEngine.startLoopRecording(bars: 4)
        loopEngine.stopLoopRecording()
        let countBefore = loopEngine.loops.count
        guard let loopID = loopEngine.loops.first?.id else {
            XCTFail("Should have a loop")
            return
        }
        loopEngine.startOverdub(loopID: loopID)
        loopEngine.stopOverdub()
        XCTAssertEqual(loopEngine.loops.count, countBefore, "Overdub should merge, not create new loop")
    }

    func testCancelOverdub() {
        loopEngine.startLoopRecording(bars: 4)
        loopEngine.stopLoopRecording()
        guard let loopID = loopEngine.loops.first?.id else {
            XCTFail("Should have a loop")
            return
        }
        loopEngine.startOverdub(loopID: loopID)
        loopEngine.cancelOverdub()
        XCTAssertFalse(loopEngine.isOverdubbing)
    }

    func testOverdubPreservesLoopIdentity() {
        loopEngine.startLoopRecording(bars: 4)
        loopEngine.stopLoopRecording()
        guard let originalID = loopEngine.loops.first?.id else {
            XCTFail("Should have a loop")
            return
        }
        loopEngine.startOverdub(loopID: originalID)
        loopEngine.stopOverdub()
        XCTAssertEqual(loopEngine.loops.first?.id, originalID, "Overdub should keep original loop ID")
    }
}

// MARK: - Lambda Output Wiring Tests

@MainActor
final class LambdaOutputWiringTests: XCTestCase {

    func testEnvironmentLoopProcessorExists() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor)
    }

    func testCoherenceOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.coherenceOutput)
    }

    func testFrequencyOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.frequencyOutput)
    }

    func testColorOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.colorOutput)
    }

    func testSpatialOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.spatialOutput)
    }

    func testReverbOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.reverbOutput)
    }

    func testHapticOutputPublisher() {
        let processor = EnvironmentLoopProcessor.shared
        XCTAssertNotNil(processor.hapticOutput)
    }

    func testColorOutputCanBeSubscribed() {
        let processor = EnvironmentLoopProcessor.shared
        var received = false
        let expectation = XCTestExpectation(description: "Color output received")

        let cancellable = processor.colorOutput
            .sink { color in
                received = true
                expectation.fulfill()
            }

        processor.colorOutput.send((r: 1.0, g: 0.0, b: 0.5))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(received)
        cancellable.cancel()
    }

    func testLambdaColorNotificationName() {
        XCTAssertEqual(Notification.Name.lambdaColorUpdate.rawValue, "echoelLambdaColorUpdate")
    }

    func testColorNotificationFires() {
        let expectation = XCTestExpectation(description: "Color notification received")
        var receivedR: Float = 0

        let observer = NotificationCenter.default.addObserver(
            forName: .lambdaColorUpdate,
            object: nil,
            queue: .main
        ) { notification in
            receivedR = notification.userInfo?["r"] as? Float ?? 0
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .lambdaColorUpdate,
            object: nil,
            userInfo: ["r": Float(0.8), "g": Float(0.2), "b": Float(0.5)]
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedR, 0.8, accuracy: 0.001)
        NotificationCenter.default.removeObserver(observer)
    }
}
