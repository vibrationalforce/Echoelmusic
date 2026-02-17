// EchoelToolkitTests.swift
// Tests for EchoelToolkit master registry, EngineBus, and tool integration

import XCTest
@testable import Echoelmusic

final class EchoelToolkitTests: XCTestCase {

    // MARK: - EngineBus Tests

    func testEngineBusSingleton() {
        let bus1 = EngineBus.shared
        let bus2 = EngineBus.shared
        XCTAssertTrue(bus1 === bus2, "EngineBus.shared should be a singleton")
    }

    func testEngineBusPublishAndSubscribe() {
        let bus = EngineBus.shared
        let expectation = XCTestExpectation(description: "Receive bio update")

        let sub = bus.subscribe(to: [.bio]) { msg in
            if case .bioUpdate(let snapshot) = msg {
                XCTAssertEqual(snapshot.coherence, 0.75, accuracy: 0.01)
                expectation.fulfill()
            }
        }

        var snapshot = BioSnapshot()
        snapshot.coherence = 0.75
        bus.publishBio(snapshot)

        wait(for: [expectation], timeout: 1.0)
        _ = sub  // Keep subscription alive
    }

    func testEngineBusParamPublish() {
        let bus = EngineBus.shared
        let expectation = XCTestExpectation(description: "Receive param change")

        let sub = bus.subscribe(to: [.dsp]) { msg in
            if case .parameterChange(let engineId, let param, let value) = msg {
                XCTAssertEqual(engineId, "synth")
                XCTAssertEqual(param, "freq")
                XCTAssertEqual(value, 440.0, accuracy: 0.01)
                expectation.fulfill()
            }
        }

        bus.publishParam(engine: "synth", param: "freq", value: 440.0)

        wait(for: [expectation], timeout: 1.0)
        _ = sub
    }

    func testEngineBusProvideAndRequest() {
        let bus = EngineBus.shared

        // Provide a value
        bus.provide("test.value") { 42.0 as Float }

        // Request it back
        let value: Float? = bus.request("test.value")
        XCTAssertEqual(value, 42.0)
    }

    // MARK: - BioSnapshot Tests

    func testBioSnapshotDefaults() {
        let snapshot = BioSnapshot()
        XCTAssertEqual(snapshot.coherence, 0)
        XCTAssertEqual(snapshot.heartRate, 70)
        XCTAssertEqual(snapshot.breathPhase, 0.5)
        XCTAssertEqual(snapshot.flowScore, 0)
        XCTAssertEqual(snapshot.hrvVariability, 0.5)
        XCTAssertEqual(snapshot.breathDepth, 0.5)
        XCTAssertEqual(snapshot.lfHfRatio, 0.5)
        XCTAssertEqual(snapshot.coherenceTrend, 0)
    }

    func testBioSnapshotExtendedFields() {
        var snapshot = BioSnapshot()
        snapshot.hrvVariability = 0.8
        snapshot.breathDepth = 0.6
        snapshot.lfHfRatio = 0.3
        snapshot.coherenceTrend = -0.5

        XCTAssertEqual(snapshot.hrvVariability, 0.8)
        XCTAssertEqual(snapshot.breathDepth, 0.6)
        XCTAssertEqual(snapshot.lfHfRatio, 0.3)
        XCTAssertEqual(snapshot.coherenceTrend, -0.5)
    }

    // MARK: - EchoelBio Integration Tests

    @MainActor
    func testEchoelBioIntegration() {
        let bio = EchoelBio()

        // Update with extended parameters
        bio.update(heartRate: 80, hrvMs: 65, coherence: 0.7,
                   breathPhase: 0.3, breathDepth: 0.6, lfHfRatio: 0.4, flowScore: 0.8)

        XCTAssertEqual(bio.heartRate, 80)
        XCTAssertEqual(bio.hrvMs, 65)
        XCTAssertEqual(bio.coherence, 0.7, accuracy: 0.01)
        XCTAssertEqual(bio.breathDepth, 0.6)
        XCTAssertEqual(bio.lfHfRatio, 0.4)
    }

    @MainActor
    func testEchoelBioEventGraphIntegration() {
        let bio = EchoelBio()

        // Feed multiple updates to trigger event detection
        for i in 0..<60 {
            let coherence = sin(Float(i) * 0.2) * 0.3 + 0.5
            bio.update(coherence: coherence, breathPhase: Float(i % 2))
        }

        // Event graph should have processed samples
        let state = bio.dominantBioState
        XCTAssertGreaterThanOrEqual(state, 0)
    }

    @MainActor
    func testEchoelBioDeconvolverIntegration() {
        let bio = EchoelBio()

        for i in 0..<120 {
            let t = Float(i) / 60.0
            let hr: Float = 70 + sin(2.0 * Float.pi * 1.0 * t) * 10
            let breath = sin(2.0 * Float.pi * 0.25 * t) * 0.5 + 0.5
            bio.update(heartRate: hr, breathPhase: breath)
        }

        // Signal quality should be reasonable
        let quality = bio.signalQuality
        XCTAssertGreaterThanOrEqual(quality, 0)
        XCTAssertLessThanOrEqual(quality, 1)
    }

    @MainActor
    func testEchoelBioStopStreamingResetsProcessors() {
        let bio = EchoelBio()

        bio.startStreaming()
        for _ in 0..<30 {
            bio.update(coherence: 0.8, breathPhase: 0.5)
        }

        bio.stopStreaming()
        XCTAssertFalse(bio.isStreaming)
        // After stop, event graph should be reset
        XCTAssertTrue(bio.eventGraph.clusters.isEmpty)
    }

    // MARK: - EchoelVis Hilbert Integration

    @MainActor
    func testEchoelVisHilbertMode() {
        let vis = EchoelVis()
        vis.mode = .hilbert
        XCTAssertEqual(vis.mode, .hilbert)
    }

    @MainActor
    func testEchoelVisHilbertMapper() {
        let vis = EchoelVis()

        // Feed samples via mapper
        for i in 0..<32 {
            vis.hilbertMapper.feedSample(Float(i) / 32.0)
        }

        let points = vis.hilbertParticles(count: 10)
        XCTAssertEqual(points.count, 10)

        let grid = vis.hilbertDensityGrid()
        XCTAssertEqual(grid.count, vis.hilbertMapper.gridSize * vis.hilbertMapper.gridSize)
    }

    // MARK: - EchoelSynth Extended Bio

    @MainActor
    func testEchoelSynthReceivesBio() {
        let synth = EchoelSynth()

        // Synth should have DDSP sub-engine
        XCTAssertNotNil(synth.ddsp)
        XCTAssertEqual(synth.ddsp.harmonicCount, 64)
    }
}
