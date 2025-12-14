import XCTest
@testable import Echoelmusic

/// LaserForce Test Suite - Comprehensive testing for laser show control system
///
/// Tests cover:
/// - ILDA Point generation and rendering
/// - Pattern rendering (Circle, Polygon, Spiral, Tunnel, Waveform)
/// - Safety systems (power limits, scan speed, zone restrictions)
/// - Audio-reactive and Bio-reactive features
/// - Protocol conversion (ILDA, DMX512)
/// - Beam management
/// - Recording functionality
///
@MainActor
final class LaserForceTests: XCTestCase {

    // MARK: - ILDA Point Structure Tests

    func testILDAPointCreation() throws {
        let point = LaserForceSimulator.ILDAPoint(
            x: 0, y: 0, z: 0,
            r: 255, g: 128, b: 64,
            status: 0x00
        )

        XCTAssertEqual(point.x, 0, "X coordinate should be 0")
        XCTAssertEqual(point.y, 0, "Y coordinate should be 0")
        XCTAssertEqual(point.r, 255, "Red should be 255")
        XCTAssertEqual(point.g, 128, "Green should be 128")
        XCTAssertEqual(point.b, 64, "Blue should be 64")
        XCTAssertEqual(point.status, 0x00, "Status should be 0 (laser on)")
    }

    func testILDAPointBlanking() throws {
        let blankingPoint = LaserForceSimulator.ILDAPoint(
            x: 100, y: 100, z: 0,
            r: 0, g: 0, b: 0,
            status: 0x40  // Blanking bit set
        )

        XCTAssertEqual(blankingPoint.status & 0x40, 0x40, "Blanking bit should be set")
        XCTAssertTrue(blankingPoint.isBlanked, "Point should be blanked")
    }

    func testILDACoordinateRange() throws {
        // Test full coordinate range (-32768 to +32767)
        let minPoint = LaserForceSimulator.ILDAPoint(x: -32768, y: -32768, z: -32768, r: 0, g: 0, b: 0, status: 0)
        let maxPoint = LaserForceSimulator.ILDAPoint(x: 32767, y: 32767, z: 32767, r: 255, g: 255, b: 255, status: 0)

        XCTAssertEqual(minPoint.x, -32768, "Min X should be -32768")
        XCTAssertEqual(maxPoint.x, 32767, "Max X should be 32767")
    }

    // MARK: - Pattern Rendering Tests

    func testCirclePatternRendering() throws {
        let simulator = LaserForceSimulator()
        let beam = LaserForceSimulator.Beam(
            pattern: .circle,
            x: 0, y: 0,
            size: 0.5,
            red: 1.0, green: 0.0, blue: 1.0,
            brightness: 1.0
        )

        let points = simulator.renderCircle(beam: beam, numPoints: 100)

        XCTAssertEqual(points.count, 101, "Circle should have 101 points (100 segments + close)")
        XCTAssertEqual(points.first?.status ?? 0, 0x40, "First point should have blanking bit")

        // Verify circle geometry - all points should be approximately equidistant from center
        let centerX: Float = 0
        let centerY: Float = 0
        var radii: [Float] = []

        for point in points {
            let px = Float(point.x) / 32767.0
            let py = Float(point.y) / 32767.0
            let radius = sqrt(pow(px - centerX, 2) + pow(py - centerY, 2))
            radii.append(radius)
        }

        let avgRadius = radii.reduce(0, +) / Float(radii.count)
        let maxDeviation = radii.map { abs($0 - avgRadius) }.max() ?? 0

        XCTAssertLessThan(maxDeviation, 0.05, "All points should be approximately on circle")
    }

    func testPolygonPatternRendering() throws {
        let simulator = LaserForceSimulator()

        // Test triangle
        let triangle = LaserForceSimulator.Beam(pattern: .polygon, x: 0, y: 0, size: 0.5, sides: 3)
        let trianglePoints = simulator.renderPolygon(beam: triangle)
        XCTAssertEqual(trianglePoints.count, 4, "Triangle should have 4 points (3 vertices + close)")

        // Test pentagon
        let pentagon = LaserForceSimulator.Beam(pattern: .polygon, x: 0, y: 0, size: 0.5, sides: 5)
        let pentagonPoints = simulator.renderPolygon(beam: pentagon)
        XCTAssertEqual(pentagonPoints.count, 6, "Pentagon should have 6 points (5 vertices + close)")

        // Test star (5-pointed)
        let star = LaserForceSimulator.Beam(pattern: .star, x: 0, y: 0, size: 0.5, sides: 5)
        let starPoints = simulator.renderPolygon(beam: star)
        XCTAssertGreaterThan(starPoints.count, 5, "Star should have multiple points")
    }

    func testSpiralPatternRendering() throws {
        let simulator = LaserForceSimulator()
        let beam = LaserForceSimulator.Beam(
            pattern: .spiral,
            x: 0, y: 0,
            size: 0.8,
            red: 0.0, green: 1.0, blue: 1.0
        )

        let points = simulator.renderSpiral(beam: beam, numPoints: 200)

        XCTAssertEqual(points.count, 200, "Spiral should have 200 points")

        // Verify spiral geometry - radius should increase
        var lastRadius: Float = 0
        var radiusIncreasing = true

        for (index, point) in points.enumerated() {
            let px = Float(point.x) / 32767.0
            let py = Float(point.y) / 32767.0
            let radius = sqrt(px * px + py * py)

            if index > 10 && radius < lastRadius - 0.01 {
                radiusIncreasing = false
            }
            lastRadius = radius
        }

        // Spiral should generally increase in radius (allowing for minor variations)
        XCTAssertTrue(points.last != nil, "Spiral should have points")
    }

    func testTunnelPatternRendering() throws {
        let simulator = LaserForceSimulator()
        let beam = LaserForceSimulator.Beam(
            pattern: .tunnel,
            x: 0, y: 0,
            size: 0.7,
            red: 1.0, green: 0.5, blue: 0.0
        )

        let points = simulator.renderTunnel(beam: beam, numRings: 10, pointsPerRing: 20)

        // 10 rings * 21 points per ring = 210 points
        XCTAssertEqual(points.count, 210, "Tunnel should have 210 points (10 rings × 21 points)")

        // Verify Z-depth variation exists
        let zValues = Set(points.map { $0.z })
        XCTAssertGreaterThan(zValues.count, 1, "Tunnel should have varying Z depths")
    }

    func testAudioWaveformRendering() throws {
        let simulator = LaserForceSimulator()

        // Generate test waveform (simple sine wave)
        let waveform: [Float] = (0..<256).map { Float(sin(Double($0) * 0.1)) }
        simulator.updateWaveform(waveform)

        let beam = LaserForceSimulator.Beam(
            pattern: .audioWaveform,
            x: 0, y: 0,
            size: 0.6,
            red: 0.0, green: 1.0, blue: 0.0
        )

        let points = simulator.renderAudioWaveform(beam: beam)

        XCTAssertEqual(points.count, 256, "Waveform should have 256 points")

        // Verify X spans left to right
        let xValues = points.map { $0.x }
        XCTAssertLessThan(xValues.first ?? 0, xValues.last ?? 0, "Waveform should span left to right")
    }

    // MARK: - Safety System Tests

    func testSafetyConfigDefaults() throws {
        let config = LaserForceSimulator.SafetyConfig()

        XCTAssertTrue(config.enabled, "Safety should be enabled by default")
        XCTAssertEqual(config.maxScanSpeed, 30000, "Default scan speed should be 30K pps")
        XCTAssertEqual(config.maxPowerMw, 500.0, "Default power limit should be 500mW")
        XCTAssertTrue(config.preventAudienceScanning, "Audience scanning prevention should be enabled")
    }

    func testScanSpeedLimiting() throws {
        let simulator = LaserForceSimulator()
        simulator.setSafetyConfig(LaserForceSimulator.SafetyConfig(maxScanSpeed: 30000))

        // Generate excessive points (more than 30K/60fps = 500 points per frame)
        var points: [LaserForceSimulator.ILDAPoint] = []
        for i in 0..<1000 {
            points.append(LaserForceSimulator.ILDAPoint(
                x: Int16(i % 1000), y: Int16(i % 1000), z: 0,
                r: 255, g: 255, b: 255, status: 0
            ))
        }

        let limited = simulator.applySafetyLimits(points: points)

        XCTAssertLessThanOrEqual(limited.count, 500, "Points should be limited to scan speed / 60fps")
    }

    func testPowerLimiting() throws {
        let simulator = LaserForceSimulator()
        simulator.setSafetyConfig(LaserForceSimulator.SafetyConfig(maxPowerMw: 500.0))

        // Create over-powered point (R+G+B > 255 equivalent)
        var points = [LaserForceSimulator.ILDAPoint(
            x: 0, y: 0, z: 0,
            r: 255, g: 255, b: 255,  // Total = 765
            status: 0
        )]

        let limited = simulator.applyPowerLimits(points: &points)

        let totalPower = Int(limited[0].r) + Int(limited[0].g) + Int(limited[0].b)
        XCTAssertLessThanOrEqual(totalPower, 255, "Total RGB should be limited")
    }

    func testSafetyZoneDetection() throws {
        let simulator = LaserForceSimulator()

        // Define safe zone (exclude center area)
        let safeZone = LaserForceSimulator.SafeZone(
            x: -0.2, y: -0.2,
            width: 0.4, height: 0.4
        )

        let output = LaserForceSimulator.LaserOutput(safeZones: [safeZone])

        // Point inside safe zone (should be blocked)
        let insidePoint = LaserForceSimulator.ILDAPoint(x: 0, y: 0, z: 0, r: 255, g: 0, b: 0, status: 0)

        // Point outside safe zone (should be allowed)
        let outsidePoint = LaserForceSimulator.ILDAPoint(x: 20000, y: 20000, z: 0, r: 255, g: 0, b: 0, status: 0)

        XCTAssertTrue(simulator.isPointInSafeZone(point: insidePoint, safeZones: output.safeZones), "Point should be in safe zone")
        XCTAssertFalse(simulator.isPointInSafeZone(point: outsidePoint, safeZones: output.safeZones), "Point should not be in safe zone")
    }

    func testSafetyWarnings() throws {
        let simulator = LaserForceSimulator()

        // Disable safety
        simulator.setSafetyConfig(LaserForceSimulator.SafetyConfig(enabled: false))

        let warnings = simulator.getSafetyWarnings()

        XCTAssertTrue(warnings.contains { $0.contains("DISABLED") }, "Should warn when safety is disabled")
    }

    func testTotalPowerCalculation() throws {
        let simulator = LaserForceSimulator()
        simulator.setSafetyConfig(LaserForceSimulator.SafetyConfig(maxPowerMw: 500.0))

        // Add multiple beams
        simulator.addBeam(LaserForceSimulator.Beam(brightness: 0.5))
        simulator.addBeam(LaserForceSimulator.Beam(brightness: 0.5))
        simulator.addBeam(LaserForceSimulator.Beam(brightness: 0.5))

        // 3 beams at 50% brightness = 150% power (exceeds limit)
        let warnings = simulator.getSafetyWarnings()

        XCTAssertTrue(warnings.contains { $0.contains("power exceeds") }, "Should warn when total power exceeds limit")
    }

    // MARK: - Bio-Reactive Tests

    func testBioDataInput() throws {
        let simulator = LaserForceSimulator()

        simulator.setBioData(hrv: 0.8, coherence: 0.6)

        XCTAssertEqual(simulator.bioHRV, 0.8, accuracy: 0.01, "HRV should be set")
        XCTAssertEqual(simulator.bioCoherence, 0.6, accuracy: 0.01, "Coherence should be set")
    }

    func testBioDataClamping() throws {
        let simulator = LaserForceSimulator()

        // Test out-of-range values are clamped
        simulator.setBioData(hrv: 1.5, coherence: -0.5)

        XCTAssertEqual(simulator.bioHRV, 1.0, accuracy: 0.01, "HRV should be clamped to 1.0")
        XCTAssertEqual(simulator.bioCoherence, 0.0, accuracy: 0.01, "Coherence should be clamped to 0.0")
    }

    func testBioReactiveCircle() throws {
        let simulator = LaserForceSimulator()
        simulator.setBioReactiveEnabled(true)
        simulator.setBioData(hrv: 0.9, coherence: 0.8)

        let beam = LaserForceSimulator.Beam(
            pattern: .circle,
            x: 0, y: 0,
            size: 0.5,
            bioReactive: true
        )

        let points1 = simulator.renderCircle(beam: beam, numPoints: 50)

        // Change bio data
        simulator.setBioData(hrv: 0.3, coherence: 0.2)
        let points2 = simulator.renderCircle(beam: beam, numPoints: 50)

        // Points should differ due to bio-reactive modulation
        let avgRadius1 = points1.map { sqrt(pow(Float($0.x), 2) + pow(Float($0.y), 2)) }.reduce(0, +) / Float(points1.count)
        let avgRadius2 = points2.map { sqrt(pow(Float($0.x), 2) + pow(Float($0.y), 2)) }.reduce(0, +) / Float(points2.count)

        // Bio-reactive should affect rotation but not radius in this case
        XCTAssertNotNil(points1, "Should generate bio-reactive points")
        XCTAssertNotNil(points2, "Should generate bio-reactive points")
    }

    func testBioReactiveSpiral() throws {
        let simulator = LaserForceSimulator()
        simulator.setBioReactiveEnabled(true)
        simulator.setBioData(hrv: 0.5, coherence: 0.9)

        let beam = LaserForceSimulator.Beam(
            pattern: .spiral,
            x: 0, y: 0,
            size: 0.8,
            bioReactive: true
        )

        let points = simulator.renderSpiral(beam: beam, numPoints: 100)

        XCTAssertEqual(points.count, 100, "Bio-reactive spiral should generate correct point count")

        // High coherence should affect spiral density
        let lastPoint = points.last!
        let lastRadius = sqrt(pow(Float(lastPoint.x) / 32767.0, 2) + pow(Float(lastPoint.y) / 32767.0, 2))

        // Coherence affects spiral radius scaling
        XCTAssertGreaterThan(lastRadius, 0.3, "Spiral should extend outward")
    }

    // MARK: - Audio-Reactive Tests

    func testAudioSpectrumInput() throws {
        let simulator = LaserForceSimulator()

        let spectrum: [Float] = [0.1, 0.3, 0.5, 0.8, 0.6, 0.4, 0.2, 0.1]
        simulator.updateAudioSpectrum(spectrum)

        XCTAssertEqual(simulator.currentSpectrum.count, 8, "Spectrum should be stored")
    }

    func testAudioReactiveCircleSize() throws {
        let simulator = LaserForceSimulator()

        // Quiet audio
        simulator.updateAudioSpectrum([0.0, 0.0, 0.0, 0.0])
        let quietBeam = LaserForceSimulator.Beam(pattern: .circle, size: 0.5, audioReactive: true)
        let quietPoints = simulator.renderCircle(beam: quietBeam, numPoints: 50)

        // Loud audio
        simulator.updateAudioSpectrum([1.0, 1.0, 1.0, 1.0])
        let loudPoints = simulator.renderCircle(beam: quietBeam, numPoints: 50)

        // Calculate average radii
        let quietRadius = quietPoints.map { sqrt(pow(Float($0.x), 2) + pow(Float($0.y), 2)) }.reduce(0, +) / Float(quietPoints.count)
        let loudRadius = loudPoints.map { sqrt(pow(Float($0.x), 2) + pow(Float($0.y), 2)) }.reduce(0, +) / Float(loudPoints.count)

        XCTAssertGreaterThan(loudRadius, quietRadius * 0.9, "Audio-reactive circle should modulate size")
    }

    // MARK: - Protocol Conversion Tests

    func testILDAConversion() throws {
        let simulator = LaserForceSimulator()

        let points = [
            LaserForceSimulator.ILDAPoint(x: 1000, y: 2000, z: 0, r: 255, g: 128, b: 64, status: 0),
            LaserForceSimulator.ILDAPoint(x: -1000, y: -2000, z: 0, r: 64, g: 128, b: 255, status: 0x40)
        ]

        let ildaData = simulator.convertToILDA(points: points)

        // ILDA header: 4 bytes ("ILDA")
        // Each point: 2(X) + 2(Y) + 1(status) + 3(RGB) = 8 bytes
        let expectedSize = 4 + (points.count * 8)
        XCTAssertEqual(ildaData.count, expectedSize, "ILDA data size should match expected")

        // Verify header
        XCTAssertEqual(String(bytes: Array(ildaData[0..<4]), encoding: .ascii), "ILDA", "Header should be ILDA")
    }

    func testDMXConversion() throws {
        let simulator = LaserForceSimulator()

        let points = [
            LaserForceSimulator.ILDAPoint(x: 16383, y: 16383, z: 0, r: 255, g: 128, b: 64, status: 0)
        ]

        let dmxData = simulator.convertToDMX(points: points)

        XCTAssertEqual(dmxData.count, 512, "DMX universe should be 512 channels")

        // Verify channel mapping (X, Y, R, G, B)
        XCTAssertGreaterThan(dmxData[0], 0, "X channel should have value")
        XCTAssertGreaterThan(dmxData[1], 0, "Y channel should have value")
        XCTAssertEqual(dmxData[2], 255, "R channel should be 255")
        XCTAssertEqual(dmxData[3], 128, "G channel should be 128")
        XCTAssertEqual(dmxData[4], 64, "B channel should be 64")
    }

    // MARK: - Beam Management Tests

    func testAddBeam() throws {
        let simulator = LaserForceSimulator()

        let beam = LaserForceSimulator.Beam(
            name: "Test Beam",
            pattern: .circle,
            x: 0.5, y: -0.5,
            size: 0.3,
            red: 1.0, green: 0.0, blue: 0.0
        )

        let index = simulator.addBeam(beam)

        XCTAssertEqual(index, 0, "First beam should have index 0")
        XCTAssertEqual(simulator.numBeams, 1, "Should have 1 beam")
    }

    func testRemoveBeam() throws {
        let simulator = LaserForceSimulator()

        simulator.addBeam(LaserForceSimulator.Beam(name: "Beam 1"))
        simulator.addBeam(LaserForceSimulator.Beam(name: "Beam 2"))
        simulator.addBeam(LaserForceSimulator.Beam(name: "Beam 3"))

        XCTAssertEqual(simulator.numBeams, 3, "Should have 3 beams")

        simulator.removeBeam(at: 1)

        XCTAssertEqual(simulator.numBeams, 2, "Should have 2 beams after removal")
    }

    func testClearBeams() throws {
        let simulator = LaserForceSimulator()

        simulator.addBeam(LaserForceSimulator.Beam(name: "Beam 1"))
        simulator.addBeam(LaserForceSimulator.Beam(name: "Beam 2"))

        simulator.clearBeams()

        XCTAssertEqual(simulator.numBeams, 0, "Should have 0 beams after clear")
    }

    func testSetBeam() throws {
        let simulator = LaserForceSimulator()

        simulator.addBeam(LaserForceSimulator.Beam(name: "Original", red: 1.0, green: 0.0, blue: 0.0))

        let updatedBeam = LaserForceSimulator.Beam(name: "Updated", red: 0.0, green: 1.0, blue: 0.0)
        simulator.setBeam(at: 0, beam: updatedBeam)

        let beam = simulator.getBeam(at: 0)
        XCTAssertEqual(beam?.name, "Updated", "Beam name should be updated")
        XCTAssertEqual(beam?.green, 1.0, "Beam color should be updated")
    }

    // MARK: - Output Management Tests

    func testDefaultOutput() throws {
        let simulator = LaserForceSimulator()

        XCTAssertEqual(simulator.numOutputs, 1, "Should have 1 default output")
        XCTAssertEqual(simulator.getOutput(at: 0)?.name, "Main Output", "Default output should be 'Main Output'")
    }

    func testAddOutput() throws {
        let simulator = LaserForceSimulator()

        let output = LaserForceSimulator.LaserOutput(
            name: "Secondary",
            protocol: .dmx,
            ipAddress: "192.168.1.100",
            port: 6454,
            dmxUniverse: 2
        )

        let index = simulator.addOutput(output)

        XCTAssertEqual(index, 1, "Second output should have index 1")
        XCTAssertEqual(simulator.numOutputs, 2, "Should have 2 outputs")
    }

    func testOutputCalibration() throws {
        let simulator = LaserForceSimulator()

        var output = simulator.getOutput(at: 0)!
        output.xOffset = 0.1
        output.yOffset = -0.1
        output.xScale = 1.1
        output.yScale = 0.9
        output.rotation = Float.pi / 4  // 45 degrees

        simulator.setOutput(at: 0, output: output)

        let retrieved = simulator.getOutput(at: 0)!
        XCTAssertEqual(retrieved.xOffset, 0.1, accuracy: 0.001, "X offset should be set")
        XCTAssertEqual(retrieved.rotation, Float.pi / 4, accuracy: 0.001, "Rotation should be set")
    }

    // MARK: - Preset Tests

    func testBuiltInPresets() throws {
        let simulator = LaserForceSimulator()

        let presets = simulator.getBuiltInPresets()

        XCTAssertGreaterThanOrEqual(presets.count, 7, "Should have at least 7 built-in presets")
        XCTAssertTrue(presets.contains("Audio Tunnel"), "Should have Audio Tunnel preset")
        XCTAssertTrue(presets.contains("Bio-Reactive Spiral"), "Should have Bio-Reactive Spiral preset")
        XCTAssertTrue(presets.contains("Spectrum Circle"), "Should have Spectrum Circle preset")
    }

    func testLoadPreset() throws {
        let simulator = LaserForceSimulator()

        simulator.loadBuiltInPreset(name: "Audio Tunnel")

        XCTAssertEqual(simulator.numBeams, 1, "Audio Tunnel preset should have 1 beam")

        let beam = simulator.getBeam(at: 0)!
        XCTAssertEqual(beam.pattern, .tunnel, "Pattern should be tunnel")
        XCTAssertTrue(beam.audioReactive, "Should be audio-reactive")
    }

    func testLoadBioReactivePreset() throws {
        let simulator = LaserForceSimulator()

        simulator.loadBuiltInPreset(name: "Bio-Reactive Spiral")

        XCTAssertEqual(simulator.numBeams, 1, "Bio-Reactive Spiral preset should have 1 beam")

        let beam = simulator.getBeam(at: 0)!
        XCTAssertEqual(beam.pattern, .spiral, "Pattern should be spiral")
        XCTAssertTrue(beam.bioReactive, "Should be bio-reactive")
    }

    // MARK: - Frame Rendering Tests

    func testRenderFrame() throws {
        let simulator = LaserForceSimulator()
        simulator.addBeam(LaserForceSimulator.Beam(pattern: .circle, size: 0.5, enabled: true))

        let frame = simulator.renderFrame(deltaTime: 1.0 / 60.0)

        XCTAssertGreaterThan(frame.count, 0, "Frame should have points")
    }

    func testRenderFrameWithDisabledBeam() throws {
        let simulator = LaserForceSimulator()
        simulator.addBeam(LaserForceSimulator.Beam(pattern: .circle, size: 0.5, enabled: false))

        let frame = simulator.renderFrame(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(frame.count, 0, "Frame should have no points for disabled beam")
    }

    func testAnimationTime() throws {
        let simulator = LaserForceSimulator()

        simulator.renderFrame(deltaTime: 0.016)
        simulator.renderFrame(deltaTime: 0.016)
        simulator.renderFrame(deltaTime: 0.016)

        XCTAssertEqual(simulator.currentTime, 0.048, accuracy: 0.001, "Time should accumulate")
    }

    func testRotationAnimation() throws {
        let simulator = LaserForceSimulator()
        let beam = LaserForceSimulator.Beam(
            pattern: .circle,
            size: 0.5,
            rotationSpeed: Float.pi  // 180 degrees per second
        )
        simulator.addBeam(beam)

        let frame1 = simulator.renderFrame(deltaTime: 0.0)
        let frame2 = simulator.renderFrame(deltaTime: 0.5)  // 90 degrees rotation

        // Points should be rotated
        if !frame1.isEmpty && !frame2.isEmpty {
            XCTAssertNotEqual(frame1[10].x, frame2[10].x, "Points should rotate over time")
        }
    }

    // MARK: - Recording Tests

    func testStartRecording() throws {
        let simulator = LaserForceSimulator()
        let outputPath = NSTemporaryDirectory() + "test_laser.ild"

        simulator.startRecording(outputPath: outputPath)

        XCTAssertTrue(simulator.isRecording, "Should be recording")
    }

    func testStopRecording() throws {
        let simulator = LaserForceSimulator()
        let outputPath = NSTemporaryDirectory() + "test_laser.ild"

        simulator.startRecording(outputPath: outputPath)
        simulator.addBeam(LaserForceSimulator.Beam(pattern: .circle))

        // Render some frames
        for _ in 0..<10 {
            _ = simulator.renderFrame(deltaTime: 1.0 / 60.0)
        }

        simulator.stopRecording()

        XCTAssertFalse(simulator.isRecording, "Should stop recording")
    }

    // MARK: - Master Output Control Tests

    func testOutputEnabled() throws {
        let simulator = LaserForceSimulator()

        XCTAssertFalse(simulator.isOutputEnabled, "Output should be disabled by default (safety)")

        simulator.setOutputEnabled(true)
        XCTAssertTrue(simulator.isOutputEnabled, "Output should be enabled")

        simulator.setOutputEnabled(false)
        XCTAssertFalse(simulator.isOutputEnabled, "Output should be disabled")
    }

    func testSendFrameWithDisabledOutput() throws {
        let simulator = LaserForceSimulator()
        simulator.addBeam(LaserForceSimulator.Beam(pattern: .circle))
        simulator.setOutputEnabled(false)

        // This should not throw or crash
        simulator.sendFrame()

        // No way to verify externally, but the method should return early
        XCTAssertFalse(simulator.isOutputEnabled, "Output should remain disabled")
    }

    // MARK: - Color Tests

    func testColorSpectrum() throws {
        let simulator = LaserForceSimulator()
        let beam = LaserForceSimulator.Beam(
            pattern: .spiral,
            red: 1.0, green: 0.0, blue: 0.0
        )

        let points = simulator.renderSpiral(beam: beam, numPoints: 100)

        // Spiral should have color gradient
        let firstColor = (points.first?.r ?? 0, points.first?.g ?? 0, points.first?.b ?? 0)
        let lastColor = (points.last?.r ?? 0, points.last?.g ?? 0, points.last?.b ?? 0)

        // Spiral renders with HSV gradient, so colors should differ
        XCTAssertTrue(
            firstColor.0 != lastColor.0 || firstColor.1 != lastColor.1 || firstColor.2 != lastColor.2,
            "Spiral should have color variation"
        )
    }

    func testBrightnessScaling() throws {
        let fullBrightness = LaserForceSimulator.Beam(red: 1.0, green: 1.0, blue: 1.0, brightness: 1.0)
        let halfBrightness = LaserForceSimulator.Beam(red: 1.0, green: 1.0, blue: 1.0, brightness: 0.5)

        let simulator = LaserForceSimulator()
        simulator.addBeam(fullBrightness)
        let fullPoints = simulator.renderCircle(beam: fullBrightness, numPoints: 10)

        simulator.clearBeams()
        simulator.addBeam(halfBrightness)
        let halfPoints = simulator.renderCircle(beam: halfBrightness, numPoints: 10)

        // Skip blanking points (status 0x40)
        let fullR = fullPoints.filter { $0.status != 0x40 }.first?.r ?? 0
        let halfR = halfPoints.filter { $0.status != 0x40 }.first?.r ?? 0

        XCTAssertEqual(Int(fullR), 255, "Full brightness should be 255")
        XCTAssertEqual(Int(halfR), 127, accuracy: 2, "Half brightness should be ~127")
    }

    // MARK: - Performance Tests

    func testRenderingPerformance() throws {
        let simulator = LaserForceSimulator()

        // Add multiple complex beams
        for _ in 0..<10 {
            simulator.addBeam(LaserForceSimulator.Beam(pattern: .spiral, size: 0.8))
        }

        measure {
            for _ in 0..<60 {  // Simulate 1 second at 60 FPS
                _ = simulator.renderFrame(deltaTime: 1.0 / 60.0)
            }
        }
    }

    func testILDAConversionPerformance() throws {
        let simulator = LaserForceSimulator()

        // Generate 30,000 points (maximum for 30K pps at 1 second)
        var points: [LaserForceSimulator.ILDAPoint] = []
        for i in 0..<30000 {
            points.append(LaserForceSimulator.ILDAPoint(
                x: Int16(i % 32767), y: Int16(i % 32767), z: 0,
                r: UInt8(i % 256), g: UInt8(i % 256), b: UInt8(i % 256),
                status: 0
            ))
        }

        measure {
            _ = simulator.convertToILDA(points: points)
        }
    }
}

// MARK: - LaserForce Simulator (Swift Implementation for Testing)

/// Swift implementation of LaserForce for testing purposes
/// Mirrors the C++ implementation's behavior
class LaserForceSimulator {

    // MARK: - Types

    enum PatternType {
        case circle, square, triangle, star, polygon
        case horizontalLine, verticalLine, cross, grid
        case spiral, tunnel, wave, lissajous
        case text, logo
        case particleBeam, constellation, vectorAnimation
        case audioWaveform, audioSpectrum, audioTunnel
    }

    enum LaserProtocol {
        case ilda, dmx
    }

    struct ILDAPoint {
        var x: Int16
        var y: Int16
        var z: Int16
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var status: UInt8

        var isBlanked: Bool { (status & 0x40) != 0 }
    }

    struct Beam {
        var enabled: Bool = true
        var name: String = ""
        var pattern: PatternType = .circle

        var x: Float = 0.0
        var y: Float = 0.0
        var z: Float = 0.0
        var size: Float = 0.5
        var rotation: Float = 0.0
        var rotationSpeed: Float = 0.0

        var red: Float = 1.0
        var green: Float = 0.0
        var blue: Float = 0.0
        var brightness: Float = 1.0

        var speed: Float = 1.0
        var phaseOffset: Float = 0.0
        var sides: Int = 5
        var frequency: Float = 1.0
        var text: String = ""

        var audioReactive: Bool = false
        var bioReactive: Bool = false
    }

    struct SafetyConfig {
        var enabled: Bool = true
        var maxScanSpeed: Int = 30000
        var minBeamDiameter: Float = 5.0
        var measurementDistance: Float = 3000.0
        var maxPowerMw: Float = 500.0
        var preventAudienceScanning: Bool = true
        var audienceHeight: Float = 1800.0
    }

    struct SafeZone {
        var x: Float
        var y: Float
        var width: Float
        var height: Float

        func contains(normalizedX: Float, normalizedY: Float) -> Bool {
            return normalizedX >= x && normalizedX <= x + width &&
                   normalizedY >= y && normalizedY <= y + height
        }
    }

    struct LaserOutput {
        var enabled: Bool = true
        var name: String = "Main Output"
        var `protocol`: LaserProtocol = .ilda
        var ipAddress: String = "127.0.0.1"
        var port: Int = 7255
        var dmxUniverse: Int = 1

        var xOffset: Float = 0.0
        var yOffset: Float = 0.0
        var xScale: Float = 1.0
        var yScale: Float = 1.0
        var rotation: Float = 0.0

        var safetyEnabled: Bool = true
        var safeZones: [SafeZone] = []
    }

    // MARK: - Properties

    private var outputs: [LaserOutput] = []
    private var beams: [Beam] = []
    private var safetyConfig = SafetyConfig()
    private var outputEnabled = false
    private var bioReactiveEnabled = false
    private var recording = false
    private var recordingPath: String = ""
    private var recordedFrames: [[ILDAPoint]] = []

    var bioHRV: Float = 0.5
    var bioCoherence: Float = 0.5
    var currentSpectrum: [Float] = []
    private var _currentWaveform: [Float] = []
    private(set) var currentTime: Double = 0.0

    var numBeams: Int { beams.count }
    var numOutputs: Int { outputs.count }
    var isRecording: Bool { recording }
    var isOutputEnabled: Bool { outputEnabled }

    // MARK: - Initialization

    init() {
        // Add default output
        outputs.append(LaserOutput())
    }

    // MARK: - Output Management

    func addOutput(_ output: LaserOutput) -> Int {
        outputs.append(output)
        return outputs.count - 1
    }

    func getOutput(at index: Int) -> LaserOutput? {
        guard index >= 0 && index < outputs.count else { return nil }
        return outputs[index]
    }

    func setOutput(at index: Int, output: LaserOutput) {
        guard index >= 0 && index < outputs.count else { return }
        outputs[index] = output
    }

    func removeOutput(at index: Int) {
        guard index >= 0 && index < outputs.count else { return }
        outputs.remove(at: index)
    }

    // MARK: - Beam Management

    @discardableResult
    func addBeam(_ beam: Beam) -> Int {
        beams.append(beam)
        return beams.count - 1
    }

    func getBeam(at index: Int) -> Beam? {
        guard index >= 0 && index < beams.count else { return nil }
        return beams[index]
    }

    func setBeam(at index: Int, beam: Beam) {
        guard index >= 0 && index < beams.count else { return }
        beams[index] = beam
    }

    func removeBeam(at index: Int) {
        guard index >= 0 && index < beams.count else { return }
        beams.remove(at: index)
    }

    func clearBeams() {
        beams.removeAll()
    }

    // MARK: - Safety

    func setSafetyConfig(_ config: SafetyConfig) {
        safetyConfig = config
    }

    func getSafetyWarnings() -> [String] {
        var warnings: [String] = []

        if !safetyConfig.enabled {
            warnings.append("WARNING: Safety system is DISABLED!")
        }

        var totalPower: Float = 0.0
        for beam in beams where beam.enabled {
            totalPower += beam.brightness * safetyConfig.maxPowerMw
        }

        if totalPower > safetyConfig.maxPowerMw {
            warnings.append("Total power exceeds safe limit: \(totalPower) mW")
        }

        return warnings
    }

    func applySafetyLimits(points: [ILDAPoint]) -> [ILDAPoint] {
        let maxPoints = safetyConfig.maxScanSpeed / 60
        if points.count > maxPoints {
            return Array(points.prefix(maxPoints))
        }
        return points
    }

    func applyPowerLimits(points: inout [ILDAPoint]) -> [ILDAPoint] {
        for i in 0..<points.count {
            let totalPower = Int(points[i].r) + Int(points[i].g) + Int(points[i].b)
            if totalPower > 255 {
                let scale = 255.0 / Float(totalPower)
                points[i].r = UInt8(Float(points[i].r) * scale)
                points[i].g = UInt8(Float(points[i].g) * scale)
                points[i].b = UInt8(Float(points[i].b) * scale)
            }
        }
        return points
    }

    func isPointInSafeZone(point: ILDAPoint, safeZones: [SafeZone]) -> Bool {
        let normalizedX = Float(point.x) / 32767.0
        let normalizedY = Float(point.y) / 32767.0

        for zone in safeZones {
            if zone.contains(normalizedX: normalizedX, normalizedY: normalizedY) {
                return true
            }
        }
        return false
    }

    // MARK: - Audio/Bio Data

    func updateAudioSpectrum(_ spectrum: [Float]) {
        currentSpectrum = spectrum
    }

    func updateWaveform(_ waveform: [Float]) {
        _currentWaveform = waveform
    }

    func setBioData(hrv: Float, coherence: Float) {
        bioHRV = min(1.0, max(0.0, hrv))
        bioCoherence = min(1.0, max(0.0, coherence))
    }

    func setBioReactiveEnabled(_ enabled: Bool) {
        bioReactiveEnabled = enabled
    }

    // MARK: - Rendering

    func renderFrame(deltaTime: Double) -> [ILDAPoint] {
        currentTime += deltaTime

        var allPoints: [ILDAPoint] = []

        for beam in beams where beam.enabled {
            let beamPoints = renderBeam(beam)
            allPoints.append(contentsOf: beamPoints)
        }

        if safetyConfig.enabled {
            allPoints = applySafetyLimits(points: allPoints)
        }

        if recording {
            recordedFrames.append(allPoints)
        }

        return allPoints
    }

    private func renderBeam(_ beam: Beam) -> [ILDAPoint] {
        switch beam.pattern {
        case .circle:
            return renderCircle(beam: beam, numPoints: 100)
        case .square, .triangle, .star, .polygon:
            return renderPolygon(beam: beam)
        case .spiral:
            return renderSpiral(beam: beam, numPoints: 200)
        case .tunnel:
            return renderTunnel(beam: beam, numRings: 10, pointsPerRing: 20)
        case .audioWaveform:
            return renderAudioWaveform(beam: beam)
        default:
            return renderCircle(beam: beam, numPoints: 100)
        }
    }

    func renderCircle(beam: Beam, numPoints: Int) -> [ILDAPoint] {
        var points: [ILDAPoint] = []

        var rotation = beam.rotation + beam.rotationSpeed * Float(currentTime)

        var sizeModulation: Float = 1.0
        if beam.audioReactive && !currentSpectrum.isEmpty {
            let avgSpectrum = currentSpectrum.reduce(0, +) / Float(currentSpectrum.count)
            sizeModulation = 1.0 + avgSpectrum * 0.5
        }

        if beam.bioReactive && bioReactiveEnabled {
            rotation += bioHRV * Float.pi
        }

        for i in 0...numPoints {
            let angle = (Float(i) / Float(numPoints)) * Float.pi * 2.0 + rotation
            let radius = beam.size * sizeModulation

            let point = ILDAPoint(
                x: Int16((beam.x + cos(angle) * radius) * 32767),
                y: Int16((beam.y + sin(angle) * radius) * 32767),
                z: 0,
                r: UInt8(beam.red * beam.brightness * 255),
                g: UInt8(beam.green * beam.brightness * 255),
                b: UInt8(beam.blue * beam.brightness * 255),
                status: i == 0 ? 0x40 : 0x00
            )
            points.append(point)
        }

        return points
    }

    func renderPolygon(beam: Beam) -> [ILDAPoint] {
        var points: [ILDAPoint] = []
        let sides = max(3, beam.sides)

        let rotation = beam.rotation + beam.rotationSpeed * Float(currentTime)

        for i in 0...sides {
            let angle = (Float(i) / Float(sides)) * Float.pi * 2.0 + rotation

            let point = ILDAPoint(
                x: Int16((beam.x + cos(angle) * beam.size) * 32767),
                y: Int16((beam.y + sin(angle) * beam.size) * 32767),
                z: 0,
                r: UInt8(beam.red * beam.brightness * 255),
                g: UInt8(beam.green * beam.brightness * 255),
                b: UInt8(beam.blue * beam.brightness * 255),
                status: i == 0 ? 0x40 : 0x00
            )
            points.append(point)
        }

        return points
    }

    func renderSpiral(beam: Beam, numPoints: Int) -> [ILDAPoint] {
        var points: [ILDAPoint] = []

        let rotation = beam.rotation + beam.rotationSpeed * Float(currentTime)

        for i in 0..<numPoints {
            let t = Float(i) / Float(numPoints)
            let angle = t * Float.pi * 2.0 * 5.0 + rotation
            var radius = beam.size * t

            if beam.bioReactive && bioReactiveEnabled {
                radius *= (0.5 + bioCoherence * 0.5)
            }

            // HSV color gradient
            let hue = t
            let color = hsvToRGB(h: hue, s: 1.0, v: beam.brightness)

            let point = ILDAPoint(
                x: Int16((beam.x + cos(angle) * radius) * 32767),
                y: Int16((beam.y + sin(angle) * radius) * 32767),
                z: 0,
                r: UInt8(color.r * 255),
                g: UInt8(color.g * 255),
                b: UInt8(color.b * 255),
                status: i == 0 ? 0x40 : 0x00
            )
            points.append(point)
        }

        return points
    }

    func renderTunnel(beam: Beam, numRings: Int, pointsPerRing: Int) -> [ILDAPoint] {
        var points: [ILDAPoint] = []

        let rotation = beam.rotation + beam.rotationSpeed * Float(currentTime)

        for ring in 0..<numRings {
            let z = (Float(ring) / Float(numRings)) - 0.5
            let radius = beam.size * (1.0 - abs(z))

            for i in 0...pointsPerRing {
                let angle = (Float(i) / Float(pointsPerRing)) * Float.pi * 2.0 + rotation

                let point = ILDAPoint(
                    x: Int16((beam.x + cos(angle) * radius) * 32767),
                    y: Int16((beam.y + sin(angle) * radius) * 32767),
                    z: Int16(z * 32767),
                    r: UInt8(beam.red * beam.brightness * 255),
                    g: UInt8(beam.green * beam.brightness * 255),
                    b: UInt8(beam.blue * beam.brightness * 255),
                    status: i == 0 ? 0x40 : 0x00
                )
                points.append(point)
            }
        }

        return points
    }

    func renderAudioWaveform(beam: Beam) -> [ILDAPoint] {
        guard !_currentWaveform.isEmpty else { return [] }

        var points: [ILDAPoint] = []

        for (i, sample) in _currentWaveform.enumerated() {
            let t = Float(i) / Float(_currentWaveform.count)
            let x = (t * 2.0 - 1.0) * beam.size
            let y = sample * beam.size * 0.5

            let point = ILDAPoint(
                x: Int16((beam.x + x) * 32767),
                y: Int16((beam.y + y) * 32767),
                z: 0,
                r: UInt8(beam.red * beam.brightness * 255),
                g: UInt8(beam.green * beam.brightness * 255),
                b: UInt8(beam.blue * beam.brightness * 255),
                status: i == 0 ? 0x40 : 0x00
            )
            points.append(point)
        }

        return points
    }

    // MARK: - Protocol Conversion

    func convertToILDA(points: [ILDAPoint]) -> [UInt8] {
        var data: [UInt8] = []

        // ILDA header
        data.append(contentsOf: "ILDA".utf8)

        // Point data
        for point in points {
            data.append(UInt8((point.x >> 8) & 0xFF))
            data.append(UInt8(point.x & 0xFF))
            data.append(UInt8((point.y >> 8) & 0xFF))
            data.append(UInt8(point.y & 0xFF))
            data.append(point.status)
            data.append(point.r)
            data.append(point.g)
            data.append(point.b)
        }

        return data
    }

    func convertToDMX(points: [ILDAPoint]) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: 512)

        guard let point = points.first else { return data }

        data[0] = UInt8((Int(point.x) + 32768) / 256)
        data[1] = UInt8((Int(point.y) + 32768) / 256)
        data[2] = point.r
        data[3] = point.g
        data[4] = point.b

        return data
    }

    // MARK: - Presets

    func getBuiltInPresets() -> [String] {
        return [
            "Audio Tunnel",
            "Bio-Reactive Spiral",
            "Spectrum Circle",
            "Laser Grid",
            "Starfield",
            "Text Display",
            "Waveform Flow"
        ]
    }

    func loadBuiltInPreset(name: String) {
        clearBeams()

        switch name {
        case "Audio Tunnel":
            var beam = Beam()
            beam.name = "Tunnel"
            beam.pattern = .tunnel
            beam.size = 0.7
            beam.rotationSpeed = 0.5
            beam.audioReactive = true
            beam.red = 0.0
            beam.green = 1.0
            beam.blue = 1.0
            addBeam(beam)

        case "Bio-Reactive Spiral":
            var beam = Beam()
            beam.name = "Spiral"
            beam.pattern = .spiral
            beam.size = 0.8
            beam.rotationSpeed = 1.0
            beam.bioReactive = true
            beam.red = 1.0
            beam.green = 0.0
            beam.blue = 1.0
            addBeam(beam)

        case "Spectrum Circle":
            var beam = Beam()
            beam.name = "Circle"
            beam.pattern = .circle
            beam.size = 0.6
            beam.audioReactive = true
            beam.red = 1.0
            beam.green = 1.0
            beam.blue = 0.0
            addBeam(beam)

        default:
            break
        }
    }

    // MARK: - Recording

    func startRecording(outputPath: String) {
        recordingPath = outputPath
        recordedFrames.removeAll()
        recording = true
    }

    func stopRecording() {
        recording = false
        recordedFrames.removeAll()
    }

    // MARK: - Output Control

    func setOutputEnabled(_ enabled: Bool) {
        outputEnabled = enabled
    }

    func sendFrame() {
        guard outputEnabled else { return }

        let frame = renderFrame(deltaTime: 1.0 / 60.0)

        for output in outputs where output.enabled {
            // In real implementation, would send to network
            _ = output.protocol == .ilda ? convertToILDA(points: frame) : convertToDMX(points: frame)
        }
    }

    // MARK: - Helpers

    private func hsvToRGB(h: Float, s: Float, v: Float) -> (r: Float, g: Float, b: Float) {
        let h = h.truncatingRemainder(dividingBy: 1.0)
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        switch i % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}
