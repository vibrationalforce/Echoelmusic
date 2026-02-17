// BioSignalDSPTests.swift
// Tests for Rausch-inspired bio-signal processing algorithms

import XCTest
@testable import Echoelmusic

final class BioSignalDSPTests: XCTestCase {

    // MARK: - BioEventGraph Tests

    func testBioEventGraphInit() {
        let graph = BioEventGraph(maxEvents: 256, clusterCount: 3)
        XCTAssertEqual(graph.maxEvents, 256)
        XCTAssertEqual(graph.clusterCount, 3)
        XCTAssertTrue(graph.clusters.isEmpty)
    }

    func testBioEventGraphDetectsPeaks() {
        let graph = BioEventGraph(maxEvents: 128, clusterCount: 2)
        graph.anomalyThreshold = 1.5

        // Feed a sine-like signal — should detect peaks
        for i in 0..<120 {
            let value = sin(Float(i) * 0.2) * 0.5 + 0.5
            graph.feedSample(value, channel: .coherence)
        }

        // After enough samples, clusters should form
        XCTAssertFalse(graph.clusters.isEmpty, "Should detect patterns and form clusters")
    }

    func testBioEventGraphAnomalyDetection() {
        let graph = BioEventGraph(maxEvents: 128, clusterCount: 2)
        graph.anomalyThreshold = 2.0

        // Feed steady baseline
        for _ in 0..<60 {
            graph.feedSample(0.5, channel: .heartRate)
        }

        // Inject spike — should register as anomaly
        graph.feedSample(1.0, channel: .heartRate)
        graph.feedSample(0.5, channel: .heartRate)
        graph.feedSample(0.5, channel: .heartRate)

        let density = graph.recentAnomalyDensity(windowSeconds: 10.0)
        XCTAssertGreaterThan(density, 0, "Spike should produce anomaly events")
    }

    func testBioEventGraphReset() {
        let graph = BioEventGraph(maxEvents: 64, clusterCount: 2)

        for i in 0..<30 {
            graph.feedSample(Float(i) * 0.03, channel: .breathing)
        }

        graph.reset()
        XCTAssertTrue(graph.clusters.isEmpty)
        XCTAssertEqual(graph.dominantClusterIndex(), 0)
    }

    func testBioEventGraphMultiChannel() {
        let graph = BioEventGraph(maxEvents: 256, clusterCount: 4)

        // Feed multiple channels simultaneously
        for i in 0..<100 {
            let t = Float(i) * 0.1
            graph.feedSample(sin(t) * 0.4 + 0.5, channel: .heartRate)
            graph.feedSample(cos(t * 0.5) * 0.3 + 0.5, channel: .breathing)
            graph.feedSample(sin(t * 2) * 0.2 + 0.5, channel: .coherence)
        }

        // Should produce non-trivial cluster state
        let dominant = graph.dominantClusterIndex()
        XCTAssertGreaterThanOrEqual(dominant, 0)
        XCTAssertLessThan(dominant, 4)
    }

    // MARK: - HilbertSensorMapper Tests

    func testHilbertMapperInit() {
        let mapper = HilbertSensorMapper(order: 4)
        XCTAssertEqual(mapper.order, 4)
        XCTAssertEqual(mapper.gridSize, 16)
        XCTAssertEqual(mapper.curveLength, 256)
    }

    func testHilbertMapperFeedSample() {
        let mapper = HilbertSensorMapper(order: 3)  // 8x8 = 64 points

        let point = mapper.feedSample(0.75)
        XCTAssertGreaterThanOrEqual(point.x, 0)
        XCTAssertLessThanOrEqual(point.x, 1)
        XCTAssertGreaterThanOrEqual(point.y, 0)
        XCTAssertLessThanOrEqual(point.y, 1)
        XCTAssertEqual(point.value, 0.75)
        XCTAssertEqual(point.index, 0)
    }

    func testHilbertMapperLocality() {
        let mapper = HilbertSensorMapper(order: 4)

        // Adjacent samples should map to nearby 2D positions
        let p1 = mapper.feedSample(0.5)
        let p2 = mapper.feedSample(0.5)

        let distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
        // Adjacent Hilbert curve points should be within ~2 grid cells
        let maxExpectedDist: Float = 2.0 / Float(mapper.gridSize - 1)
        XCTAssertLessThanOrEqual(distance, maxExpectedDist,
                                 "Adjacent Hilbert points should be spatially close")
    }

    func testHilbertMapperBatchFeed() {
        let mapper = HilbertSensorMapper(order: 3)
        let values: [Float] = (0..<20).map { sin(Float($0) * 0.3) }

        let points = mapper.feedBatch(values)
        XCTAssertEqual(points.count, 20)
        XCTAssertEqual(points[0].index, 0)
        XCTAssertEqual(points[19].index, 19)
    }

    func testHilbertMapperDensityGrid() {
        let mapper = HilbertSensorMapper(order: 3)

        // Feed many samples
        for i in 0..<64 {
            mapper.feedSample(Float(i) / 64.0)
        }

        let grid = mapper.getDensityGrid()
        XCTAssertEqual(grid.count, 64) // 8x8
        // At least some cells should have non-zero density
        let nonZero = grid.filter { $0 > 0 }.count
        XCTAssertGreaterThan(nonZero, 0, "Density grid should have non-zero cells")
    }

    func testHilbertMapperRecentPoints() {
        let mapper = HilbertSensorMapper(order: 3)

        for i in 0..<10 {
            mapper.feedSample(Float(i) * 0.1)
        }

        let recent = mapper.recentPoints(count: 5)
        XCTAssertEqual(recent.count, 5)
    }

    func testHilbertMapperReset() {
        let mapper = HilbertSensorMapper(order: 3)
        mapper.feedSample(1.0)
        mapper.feedSample(0.5)

        mapper.reset()
        let grid = mapper.getDensityGrid()
        let total = grid.reduce(0, +)
        XCTAssertEqual(total, 0, "Reset should zero out density grid")
    }

    func testHilbertMapperXY2D() {
        let mapper = HilbertSensorMapper(order: 4)

        // Round-trip: d → (x,y) → d should produce consistent indices
        let point = mapper.feedSample(0.5) // index 0
        let gridX = Int(point.x * Float(mapper.gridSize - 1))
        let gridY = Int(point.y * Float(mapper.gridSize - 1))
        let d = mapper.xy2d(x: gridX, y: gridY)
        XCTAssertEqual(d, 0, "Round-trip Hilbert index should match")
    }

    // MARK: - BioSignalDeconvolver Tests

    func testDeconvolverInit() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)
        XCTAssertEqual(dec.sampleRate, 60.0)
    }

    func testDeconvolverProcessReturns4Components() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)
        let components = dec.process(0.5)
        XCTAssertEqual(components.count, 4, "Should return baseline, respiratory, cardiac, artifact")
        XCTAssertEqual(components[0].band, .baseline)
        XCTAssertEqual(components[1].band, .respiratory)
        XCTAssertEqual(components[2].band, .cardiac)
        XCTAssertEqual(components[3].band, .artifact)
    }

    func testDeconvolverSeparatesFrequencies() {
        let sampleRate: Float = 60.0
        let dec = BioSignalDeconvolver(sampleRate: sampleRate)

        // Generate 1 Hz signal (cardiac range: 0.5-3 Hz)
        let cardiacFreq: Float = 1.0
        for i in 0..<600 { // 10 seconds at 60 Hz
            let t = Float(i) / sampleRate
            let signal = sin(2.0 * Float.pi * cardiacFreq * t)
            _ = dec.process(signal)
        }

        // Cardiac component should have highest amplitude
        let components = dec.process(sin(2.0 * Float.pi * cardiacFreq * 10.0))
        let cardiac = components.first(where: { $0.band == .cardiac })
        let baseline = components.first(where: { $0.band == .baseline })

        XCTAssertNotNil(cardiac)
        XCTAssertNotNil(baseline)
        XCTAssertGreaterThan(cardiac!.amplitude, baseline!.amplitude,
                             "Cardiac band should capture 1 Hz signal better than baseline")
    }

    func testDeconvolverCardiacValue() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)

        // Feed some data
        for i in 0..<120 {
            let t = Float(i) / 60.0
            _ = dec.process(sin(2.0 * Float.pi * 1.2 * t))
        }

        // Should return a non-zero value for cardiac
        let cardiacVal = dec.cardiacValue()
        XCTAssertNotEqual(cardiacVal, 0, "Cardiac value should be non-zero after feeding 1.2 Hz signal")
    }

    func testDeconvolverRespiratoryValue() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)

        // Feed 0.25 Hz signal (respiratory range: 0.1-0.5 Hz, ~15 breaths/min)
        for i in 0..<600 {
            let t = Float(i) / 60.0
            _ = dec.process(sin(2.0 * Float.pi * 0.25 * t))
        }

        let respVal = dec.respiratoryValue()
        // After 10s of 0.25 Hz, respiratory band should capture signal
        XCTAssertNotEqual(respVal, 0, "Respiratory value should be non-zero for 0.25 Hz signal")
    }

    func testDeconvolverArtifactLevel() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)

        // Feed clean low-frequency signal
        for i in 0..<300 {
            let t = Float(i) / 60.0
            _ = dec.process(sin(2.0 * Float.pi * 0.3 * t))
        }

        let artifactClean = dec.artifactLevel()

        // Now feed high-frequency noise (artifact range)
        let dec2 = BioSignalDeconvolver(sampleRate: 60.0)
        for i in 0..<300 {
            let t = Float(i) / 60.0
            _ = dec2.process(sin(2.0 * Float.pi * 8.0 * t))
        }

        let artifactNoisy = dec2.artifactLevel()
        XCTAssertGreaterThan(artifactNoisy, artifactClean,
                             "High-frequency input should produce higher artifact level")
    }

    func testDeconvolverReset() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)

        for i in 0..<60 {
            _ = dec.process(Float(i) * 0.01)
        }

        dec.reset()
        let val = dec.cardiacValue()
        XCTAssertEqual(val, 0, "After reset, cardiac value should be zero")
    }

    func testDeconvolverConfidencesSumToOne() {
        let dec = BioSignalDeconvolver(sampleRate: 60.0)

        // Feed mixed signal
        for i in 0..<120 {
            let t = Float(i) / 60.0
            let mixed = sin(2.0 * Float.pi * 0.25 * t) + sin(2.0 * Float.pi * 1.0 * t) * 0.5
            _ = dec.process(mixed)
        }

        let components = dec.process(0.5)
        let totalConfidence = components.reduce(Float(0)) { $0 + $1.confidence }
        XCTAssertEqual(totalConfidence, 1.0, accuracy: 0.01,
                       "Component confidences should sum to ~1.0")
    }
}
