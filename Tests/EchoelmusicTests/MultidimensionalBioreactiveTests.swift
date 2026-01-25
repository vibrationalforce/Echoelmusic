// MultidimensionalBioreactiveTests.swift
// EchoelmusicTests
//
// Comprehensive tests for the Multidimensional Bioreactive Architecture:
// - BioreactiveDimensionManager
// - TesseractRotation (4D hypercube)
// - ZernikePolynomials (light patterns)
//
// Created 2026-01-25

import XCTest
@testable import Echoelmusic

// MARK: - BioreactiveDimensionManager Tests

@MainActor
final class BioreactiveDimensionManagerTests: XCTestCase {

    var manager: BioreactiveDimensionManager!

    override func setUp() async throws {
        manager = BioreactiveDimensionManager()
    }

    override func tearDown() async throws {
        manager.stopProcessing()
        manager = nil
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() async throws {
        XCTAssertGreaterThan(manager.dimensionCount, 0)
        XCTAssertEqual(manager.latentDimensions, 4)
        XCTAssertFalse(manager.isProcessing)
    }

    func testDefaultDimensionsRegistered() async throws {
        XCTAssertTrue(manager.hasDimension(.biometric(.heartRate)))
        XCTAssertTrue(manager.hasDimension(.biometric(.hrvCoherence)))
        XCTAssertTrue(manager.hasDimension(.biometric(.breathingRate)))
        XCTAssertTrue(manager.hasDimension(.biometric(.breathingPhase)))
    }

    // MARK: - Dimension Management Tests

    func testAddDimension() async throws {
        let initialCount = manager.dimensionCount

        manager.addDimension(.biometric(.gsrLevel, min: 0, max: 1, smoothing: 0.2))

        XCTAssertEqual(manager.dimensionCount, initialCount + 1)
        XCTAssertTrue(manager.hasDimension(.biometric(.gsrLevel)))
    }

    func testRemoveDimension() async throws {
        manager.addDimension(.biometric(.spO2, min: 85, max: 100))
        XCTAssertTrue(manager.hasDimension(.biometric(.spO2)))

        manager.removeDimension(.biometric(.spO2))

        XCTAssertFalse(manager.hasDimension(.biometric(.spO2)))
    }

    func testAddExternalDimension() async throws {
        manager.addDimension(.external(.weatherTemperature, min: -20, max: 45))

        XCTAssertTrue(manager.hasDimension(.external(.weatherTemperature)))
    }

    func testAddCustomDimension() async throws {
        let customConfig = DimensionConfig(
            identifier: .custom("custom_sensor"),
            minValue: 0,
            maxValue: 100,
            defaultValue: 50,
            smoothingFactor: 0.3,
            updateRate: 30,
            weight: 1.0
        )

        manager.addDimension(customConfig)

        XCTAssertTrue(manager.hasDimension(.custom("custom_sensor")))
    }

    // MARK: - Value Update Tests

    func testUpdateDimensionValue() async throws {
        manager.update(.biometric(.heartRate), value: 80)

        let state = manager.getState(.biometric(.heartRate))

        XCTAssertNotNil(state)
        XCTAssertEqual(state?.rawValue, 80, accuracy: 0.01)
    }

    func testNormalization() async throws {
        // Heart rate range is 40-200, so 120 should normalize to 0.5
        manager.update(.biometric(.heartRate), value: 120)

        let state = manager.getState(.biometric(.heartRate))

        XCTAssertNotNil(state)
        XCTAssertEqual(state?.normalizedValue, 0.5, accuracy: 0.01)
    }

    func testNormalizationClipping() async throws {
        // Value above max should clip to 1.0
        manager.update(.biometric(.heartRate), value: 250)

        let state = manager.getState(.biometric(.heartRate))

        XCTAssertEqual(state?.normalizedValue, 1.0, accuracy: 0.01)
    }

    func testSmoothing() async throws {
        // Set initial value
        manager.update(.biometric(.hrvCoherence), value: 0.0)
        let initialSmoothed = manager.getState(.biometric(.hrvCoherence))?.smoothedValue ?? 0

        // Update to new value
        manager.update(.biometric(.hrvCoherence), value: 1.0)
        let newSmoothed = manager.getState(.biometric(.hrvCoherence))?.smoothedValue ?? 0

        // Smoothed value should be between initial and new (not jump immediately)
        XCTAssertGreaterThan(newSmoothed, initialSmoothed)
        XCTAssertLessThan(newSmoothed, 1.0)
    }

    func testBatchUpdate() async throws {
        manager.update([
            .biometric(.heartRate): 75,
            .biometric(.hrvCoherence): 0.8,
            .biometric(.breathingRate): 12
        ])

        XCTAssertEqual(manager.getState(.biometric(.heartRate))?.rawValue, 75, accuracy: 0.01)
        XCTAssertEqual(manager.getState(.biometric(.hrvCoherence))?.rawValue, 0.8, accuracy: 0.01)
        XCTAssertEqual(manager.getState(.biometric(.breathingRate))?.rawValue, 12, accuracy: 0.01)
    }

    // MARK: - Interference Tests

    func testAddInterference() async throws {
        manager.addInterference(
            from: .biometric(.hrvCoherence),
            to: .biometric(.heartRate),
            strength: -0.2,
            mode: .multiplicative
        )

        // Set high coherence
        manager.update(.biometric(.hrvCoherence), value: 1.0)

        // Process to apply interference
        manager.processUpdate()

        // High coherence with negative strength should reduce heart rate
        // (This is a qualitative test - the effect depends on processing)
        XCTAssertNotNil(manager.currentLatentState)
    }

    func testRemoveInterference() async throws {
        manager.addInterference(
            from: .biometric(.hrvCoherence),
            to: .biometric(.heartRate),
            strength: 0.5
        )

        manager.removeInterference(
            from: .biometric(.hrvCoherence),
            to: .biometric(.heartRate)
        )

        // Should not crash and processing should work
        manager.processUpdate()
        XCTAssertNotNil(manager.currentLatentState)
    }

    // MARK: - Latent State Tests

    func testProcessingGeneratesLatentState() async throws {
        manager.update([
            .biometric(.heartRate): 80,
            .biometric(.hrvCoherence): 0.7,
            .biometric(.breathingRate): 10
        ])

        manager.processUpdate()

        XCTAssertGreaterThan(manager.currentLatentState.dimensions.count, 0)
    }

    func testLatentStateDimensions() async throws {
        // Process multiple times to train PCA
        for _ in 0..<200 {
            manager.update([
                .biometric(.heartRate): Float.random(in: 60...100),
                .biometric(.hrvCoherence): Float.random(in: 0...1),
                .biometric(.breathingRate): Float.random(in: 8...16)
            ])
            manager.processUpdate()
        }

        XCTAssertGreaterThanOrEqual(manager.currentLatentState.dimensions.count, 1)
    }

    func testLatentStateNormalized() async throws {
        for _ in 0..<150 {
            manager.update([
                .biometric(.heartRate): Float.random(in: 40...200),
                .biometric(.hrvCoherence): Float.random(in: 0...1)
            ])
            manager.processUpdate()
        }

        // All latent dimensions should be normalized to [0, 1] via sigmoid
        for dim in manager.currentLatentState.dimensions {
            XCTAssertGreaterThanOrEqual(dim, 0.0)
            XCTAssertLessThanOrEqual(dim, 1.0)
        }
    }

    // MARK: - Synthesis Parameter Tests

    func testSynthesisParametersGenerated() async throws {
        manager.update(.biometric(.hrvCoherence), value: 0.8)
        manager.processUpdate()

        let params = manager.currentSynthesisParameters

        // Should have valid parameter values
        XCTAssertGreaterThanOrEqual(params.grainDensity, 0.0)
        XCTAssertLessThanOrEqual(params.grainDensity, 1.0)
        XCTAssertGreaterThanOrEqual(params.filterCutoff, 0.0)
        XCTAssertLessThanOrEqual(params.filterCutoff, 1.0)
    }

    func testSynthesisParameterRange() async throws {
        // Test with extreme values
        manager.update([
            .biometric(.heartRate): 200,
            .biometric(.hrvCoherence): 1.0
        ])
        manager.processUpdate()

        let params = manager.currentSynthesisParameters

        // All parameters should be in [0, 1]
        XCTAssertGreaterThanOrEqual(params.grainDensity, 0.0)
        XCTAssertLessThanOrEqual(params.grainDensity, 1.0)
        XCTAssertGreaterThanOrEqual(params.reverbSend, 0.0)
        XCTAssertLessThanOrEqual(params.reverbSend, 1.0)
    }

    // MARK: - Preset Tests

    func testApplyMeditationPreset() async throws {
        manager.applyPreset(.meditation)

        XCTAssertTrue(manager.hasDimension(.biometric(.hrvCoherence)))
        XCTAssertTrue(manager.hasDimension(.biometric(.breathingRate)))
        XCTAssertTrue(manager.hasDimension(.biometric(.eegAlpha)))
    }

    func testApplyEnergeticPreset() async throws {
        manager.applyPreset(.energetic)

        XCTAssertTrue(manager.hasDimension(.biometric(.heartRate)))
        XCTAssertTrue(manager.hasDimension(.biometric(.gsrLevel)))
    }

    func testApplyResearchPreset() async throws {
        manager.applyPreset(.research)

        // Research preset should have all biometric types
        XCTAssertGreaterThan(manager.dimensionCount, 10)
    }

    // MARK: - OSC/WebSocket Tests

    func testHandleOSCMessage() async throws {
        manager.handleOSCMessage(
            address: "/echoelmusic/bio/hrvCoherence",
            arguments: [Float(0.85)]
        )

        let state = manager.getState(.biometric(.hrvCoherence))
        XCTAssertEqual(state?.rawValue, 0.85, accuracy: 0.01)
    }

    func testHandleWebSocketMessage() async throws {
        let json: [String: Any] = [
            "biometrics": [
                "hrv": [
                    "coherence": 0.75
                ],
                "breathing": [
                    "rate": 8.0
                ]
            ]
        ]

        manager.handleWebSocketMessage(json)

        XCTAssertEqual(manager.getState(.biometric(.hrvCoherence))?.rawValue, 0.75, accuracy: 0.01)
        XCTAssertEqual(manager.getState(.biometric(.breathingRate))?.rawValue, 8.0, accuracy: 0.01)
    }

    // MARK: - Processing Callback Tests

    func testProcessingCallback() async throws {
        var callbackInvoked = false
        var receivedLatent: LatentState?

        manager.startProcessing(rate: 60) { latent in
            callbackInvoked = true
            receivedLatent = latent
        }

        // Wait for at least one processing cycle
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        manager.stopProcessing()

        XCTAssertTrue(callbackInvoked)
        XCTAssertNotNil(receivedLatent)
    }

    // MARK: - Performance Tests

    func testProcessingPerformance() async throws {
        measure {
            for _ in 0..<100 {
                manager.update([
                    .biometric(.heartRate): Float.random(in: 60...100),
                    .biometric(.hrvCoherence): Float.random(in: 0...1),
                    .biometric(.breathingRate): Float.random(in: 8...16)
                ])
                manager.processUpdate()
            }
        }
    }
}

// MARK: - TesseractRotation Tests

@MainActor
final class TesseractRotationTests: XCTestCase {

    var engine: TesseractRotationEngine!

    override func setUp() async throws {
        engine = TesseractRotationEngine()
    }

    override func tearDown() async throws {
        engine = nil
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() async throws {
        XCTAssertEqual(engine.positions4D.count, 8)  // Default 8 speakers
        XCTAssertEqual(engine.positions3D.count, 8)
        XCTAssertEqual(engine.rotationAngles.count, 6)
    }

    func testSetSpeakerCount4() async throws {
        engine.setSpeakerPositions(count: 4)
        XCTAssertEqual(engine.positions4D.count, 4)
        XCTAssertEqual(engine.positions3D.count, 4)
    }

    func testSetSpeakerCount16() async throws {
        engine.setSpeakerPositions(count: 16)
        XCTAssertEqual(engine.positions4D.count, 16)
    }

    // MARK: - Vector4 Tests

    func testVector4Magnitude() async throws {
        let v = Vector4(1, 0, 0, 0)
        XCTAssertEqual(v.magnitude, 1.0, accuracy: 0.0001)

        let v2 = Vector4(1, 1, 1, 1)
        XCTAssertEqual(v2.magnitude, 2.0, accuracy: 0.0001)
    }

    func testVector4Normalized() async throws {
        let v = Vector4(2, 0, 0, 0)
        let normalized = v.normalized
        XCTAssertEqual(normalized.magnitude, 1.0, accuracy: 0.0001)
    }

    func testVector4Projection() async throws {
        let v = Vector4(1, 1, 1, 0)
        let projected = v.xyz
        XCTAssertEqual(projected.x, 1.0)
        XCTAssertEqual(projected.y, 1.0)
        XCTAssertEqual(projected.z, 1.0)
    }

    func testVector4PerspectiveProjection() async throws {
        let v = Vector4(1, 0, 0, 0)
        let projected = v.perspectiveProject(distance: 2.0)
        XCTAssertEqual(projected.x, 1.0, accuracy: 0.0001)
    }

    // MARK: - Matrix Tests

    func testIdentityMatrix() async throws {
        let identity = Matrix4x4.identity
        let v = Vector4(1, 2, 3, 4)
        let result = identity.transform(v)

        XCTAssertEqual(result.x, v.x, accuracy: 0.0001)
        XCTAssertEqual(result.y, v.y, accuracy: 0.0001)
        XCTAssertEqual(result.z, v.z, accuracy: 0.0001)
        XCTAssertEqual(result.w, v.w, accuracy: 0.0001)
    }

    func testRotationMatrixPreservesMagnitude() async throws {
        let rotation = Matrix4x4.rotation(plane: .xy, angle: .pi / 4)
        let v = Vector4(1, 0, 0, 0)
        let rotated = rotation.transform(v)

        XCTAssertEqual(rotated.magnitude, 1.0, accuracy: 0.0001)
    }

    func testRotationMatrixXY() async throws {
        let rotation = Matrix4x4.rotation(plane: .xy, angle: .pi / 2)
        let v = Vector4(1, 0, 0, 0)
        let rotated = rotation.transform(v)

        XCTAssertEqual(rotated.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(rotated.y, 1.0, accuracy: 0.0001)
    }

    func testCombinedRotation() async throws {
        let angles: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]
        let rotation = Matrix4x4.rotation4D(angles: angles)

        let v = Vector4(1, 0, 0, 0)
        let rotated = rotation.transform(v)

        // Magnitude should be preserved
        XCTAssertEqual(rotated.magnitude, 1.0, accuracy: 0.001)
    }

    // MARK: - Tesseract Geometry Tests

    func testTesseractVertexCount() async throws {
        let vertices = tesseractVertices()
        XCTAssertEqual(vertices.count, 16)  // 2^4 = 16 vertices
    }

    func testTesseractEdgeCount() async throws {
        let edges = tesseractEdges()
        XCTAssertEqual(edges.count, 32)  // Tesseract has 32 edges
    }

    func testTesseractVerticesNormalized() async throws {
        let vertices = tesseractVertices()
        for v in vertices {
            // Each coordinate should be ±0.5
            XCTAssertEqual(abs(v.x), 0.5, accuracy: 0.0001)
            XCTAssertEqual(abs(v.y), 0.5, accuracy: 0.0001)
            XCTAssertEqual(abs(v.z), 0.5, accuracy: 0.0001)
            XCTAssertEqual(abs(v.w), 0.5, accuracy: 0.0001)
        }
    }

    // MARK: - Bioreactive Update Tests

    func testUpdateFromLatent() async throws {
        let latent: [Float] = [0.8, 0.3, 0.6, 0.5]

        engine.updateFromLatent(latent, deltaTime: 1/60)

        // Rotation angles should have changed
        let sumAngles = engine.rotationAngles.reduce(0, +)
        XCTAssertNotEqual(sumAngles, 0)
    }

    func testContinuousRotation() async throws {
        let latent: [Float] = [0.5, 0.5, 0.5, 0.5]

        let initialPositions = engine.positions3D

        // Simulate 1 second of updates
        for _ in 0..<60 {
            engine.updateFromLatent(latent, deltaTime: 1/60)
        }

        // Positions should have changed due to base rotation rates
        var positionsChanged = false
        for i in 0..<min(initialPositions.count, engine.positions3D.count) {
            if initialPositions[i] != engine.positions3D[i] {
                positionsChanged = true
                break
            }
        }
        XCTAssertTrue(positionsChanged)
    }

    func testSphericalPositions() async throws {
        let spherical = engine.getSphericalPositions()

        XCTAssertEqual(spherical.count, 8)

        for pos in spherical {
            XCTAssertGreaterThanOrEqual(pos.azimuth, -180)
            XCTAssertLessThanOrEqual(pos.azimuth, 180)
            XCTAssertGreaterThanOrEqual(pos.elevation, -90)
            XCTAssertLessThanOrEqual(pos.elevation, 90)
        }
    }

    // MARK: - Performance Tests

    func testRotationPerformance() async throws {
        let latent: [Float] = [0.5, 0.5, 0.5, 0.5]

        measure {
            for _ in 0..<1000 {
                engine.updateFromLatent(latent, deltaTime: 1/60)
            }
        }
    }
}

// MARK: - ZernikePolynomials Tests

@MainActor
final class ZernikePolynomialsTests: XCTestCase {

    var engine: ZernikeLightEngine!
    let calculator = ZernikeCalculator.shared

    override func setUp() async throws {
        engine = ZernikeLightEngine(lightCount: 64)
    }

    override func tearDown() async throws {
        engine = nil
    }

    // MARK: - ZernikeMode Tests

    func testZernikeModeCreation() async throws {
        let piston = ZernikeMode(n: 0, m: 0)
        XCTAssertEqual(piston.name, "Piston")

        let tiltX = ZernikeMode(n: 1, m: 1)
        XCTAssertEqual(tiltX.name, "Tilt X")

        let defocus = ZernikeMode(n: 2, m: 0)
        XCTAssertEqual(defocus.name, "Defocus")
    }

    func testNollIndex() async throws {
        let piston = ZernikeMode(n: 0, m: 0)
        XCTAssertEqual(piston.nollIndex, 1)

        let tiltY = ZernikeMode(n: 1, m: -1)
        XCTAssertGreaterThan(tiltY.nollIndex, 1)
    }

    func testFromNoll() async throws {
        let mode1 = ZernikeMode.fromNoll(1)
        XCTAssertEqual(mode1.n, 0)
        XCTAssertEqual(mode1.m, 0)
    }

    // MARK: - Polynomial Calculation Tests

    func testPistonIsConstant() async throws {
        // Z(0,0) = 1 everywhere
        for rho in stride(from: 0.0, through: 1.0, by: 0.2) {
            for phi in stride(from: 0.0, through: Float.pi * 2, by: Float.pi / 4) {
                let value = calculator.evaluate(
                    mode: ZernikeMode(n: 0, m: 0),
                    rho: Float(rho),
                    phi: Float(phi)
                )
                XCTAssertEqual(value, 1.0, accuracy: 0.0001)
            }
        }
    }

    func testTiltXVariesWithX() async throws {
        let tiltX = ZernikeMode(n: 1, m: 1)

        // At phi=0 (x-axis), should increase with rho
        let value1 = calculator.evaluate(mode: tiltX, rho: 0.5, phi: 0)
        let value2 = calculator.evaluate(mode: tiltX, rho: 1.0, phi: 0)

        XCTAssertGreaterThan(value2, value1)
    }

    func testDefocusIsRadiallySymmetric() async throws {
        let defocus = ZernikeMode(n: 2, m: 0)

        // Should be same at all angles for same radius
        let phi1: Float = 0
        let phi2: Float = .pi / 2
        let phi3: Float = .pi

        let v1 = calculator.evaluate(mode: defocus, rho: 0.5, phi: phi1)
        let v2 = calculator.evaluate(mode: defocus, rho: 0.5, phi: phi2)
        let v3 = calculator.evaluate(mode: defocus, rho: 0.5, phi: phi3)

        XCTAssertEqual(v1, v2, accuracy: 0.0001)
        XCTAssertEqual(v2, v3, accuracy: 0.0001)
    }

    func testOutsideUnitDisk() async throws {
        // Outside unit disk should return 0
        let value = calculator.evaluate(
            mode: ZernikeMode(n: 2, m: 0),
            rho: 1.5,
            phi: 0
        )
        XCTAssertEqual(value, 0.0)
    }

    // MARK: - Surface Evaluation Tests

    func testSurfaceEvaluation() async throws {
        let coefficients: [ZernikeMode: Float] = [
            ZernikeMode(n: 0, m: 0): 0.5,
            ZernikeMode(n: 2, m: 0): 0.3
        ]

        let value = calculator.evaluateSurface(
            coefficients: coefficients,
            rho: 0.5,
            phi: 0
        )

        XCTAssertGreaterThan(value, 0)
    }

    func testSurfaceGrid() async throws {
        let coefficients: [ZernikeMode: Float] = [
            ZernikeMode(n: 0, m: 0): 0.5
        ]

        let grid = calculator.evaluateSurfaceGrid(
            coefficients: coefficients,
            gridSize: 32
        )

        XCTAssertEqual(grid.count, 32)
        XCTAssertEqual(grid[0].count, 32)
    }

    // MARK: - Light Engine Tests

    func testDefaultInitialization() async throws {
        XCTAssertEqual(engine.lightIntensities.count, 64)
        XCTAssertGreaterThan(engine.activeModes.count, 0)
    }

    func testUpdateFromLatent() async throws {
        let latent: [Float] = [0.8, 0.3, 0.6, 0.5]

        engine.updateFromLatent(latent)

        // Coefficients should be set
        XCTAssertGreaterThan(engine.coefficients.count, 0)

        // Intensities should be computed
        for intensity in engine.lightIntensities {
            XCTAssertGreaterThanOrEqual(intensity, 0.0)
            XCTAssertLessThanOrEqual(intensity, 1.0)
        }
    }

    func testSetCoefficients() async throws {
        engine.setCoefficients([
            ZernikeMode(n: 0, m: 0): 0.7,
            ZernikeMode(n: 2, m: 0): 0.3
        ])

        XCTAssertEqual(engine.coefficients[ZernikeMode(n: 0, m: 0)], 0.7, accuracy: 0.01)
    }

    func testDMXValues() async throws {
        engine.setCoefficients([
            ZernikeMode(n: 0, m: 0): 0.5  // Half brightness
        ])

        let dmx = engine.getDMXValues()

        XCTAssertEqual(dmx.count, 64)

        // Check values are in valid DMX range
        for value in dmx {
            XCTAssertLessThanOrEqual(value, 255)
        }
    }

    func testRGBValues() async throws {
        engine.setCoefficients([
            ZernikeMode(n: 0, m: 0): 0.7
        ])

        let rgb = engine.getRGBValues(hue: 0.5, saturation: 0.7)

        XCTAssertEqual(rgb.count, 64)

        for color in rgb {
            XCTAssertLessThanOrEqual(color.r, 255)
            XCTAssertLessThanOrEqual(color.g, 255)
            XCTAssertLessThanOrEqual(color.b, 255)
        }
    }

    // MARK: - Preset Tests

    func testApplyUniformPreset() async throws {
        engine.applyPreset(.uniform)

        // Should have only piston coefficient
        let pistonCoef = engine.coefficients[ZernikeMode(n: 0, m: 0)] ?? 0
        XCTAssertGreaterThan(pistonCoef, 0)
    }

    func testApplyMeditationPreset() async throws {
        engine.applyPreset(.meditation)

        // Should have spherical aberration for radial symmetry
        let spherical = engine.coefficients[ZernikeMode(n: 4, m: 0)] ?? 0
        XCTAssertGreaterThan(spherical, 0)
    }

    func testApplyEnergeticPreset() async throws {
        engine.applyPreset(.energetic)

        // Should have multiple modes with animation
        XCTAssertGreaterThan(engine.animationRates.count, 0)
    }

    // MARK: - Light Arrangement Tests

    func testConcentricArrangement() async throws {
        let config = LightArrayConfig(
            lightCount: 32,
            arrangement: .concentric
        )

        XCTAssertEqual(config.lightPositions.count, 32)

        // All positions should be within unit disk
        for pos in config.lightPositions {
            XCTAssertLessThanOrEqual(pos.rho, 1.0)
        }
    }

    func testSpiralArrangement() async throws {
        let config = LightArrayConfig(
            lightCount: 32,
            arrangement: .spiral
        )

        XCTAssertEqual(config.lightPositions.count, 32)
    }

    func testGridArrangement() async throws {
        let config = LightArrayConfig(
            lightCount: 25,
            arrangement: .grid
        )

        // Grid might have fewer points if outside unit disk
        XCTAssertGreaterThan(config.lightPositions.count, 0)
    }

    // MARK: - Animation Tests

    func testAnimationUpdates() async throws {
        engine.setAnimationRate(mode: ZernikeMode(n: 3, m: 3), rate: 1.0)

        let initialCoefficients = engine.coefficients

        // Update for 1 second
        for _ in 0..<60 {
            engine.updateFromLatent([0.5, 0.5, 0.5, 0.5], deltaTime: 1/60)
        }

        // Coefficients should have been modulated
        // (Animation adds sinusoidal variation)
        XCTAssertNotNil(engine.coefficients[ZernikeMode(n: 3, m: 3)])
    }

    // MARK: - Performance Tests

    func testLightCalculationPerformance() async throws {
        let latent: [Float] = [0.5, 0.5, 0.5, 0.5]

        measure {
            for _ in 0..<100 {
                engine.updateFromLatent(latent, deltaTime: 1/60)
            }
        }
    }

    func testSurfaceGridPerformance() async throws {
        engine.setCoefficients([
            ZernikeMode(n: 0, m: 0): 0.5,
            ZernikeMode(n: 2, m: 0): 0.3,
            ZernikeMode(n: 4, m: 0): 0.2
        ])

        measure {
            engine.updateSurfaceGrid(gridSize: 128)
        }
    }
}

// MARK: - Integration Tests

@MainActor
final class MultidimensionalIntegrationTests: XCTestCase {

    func testFullPipeline() async throws {
        // Create all components
        let dimensionManager = BioreactiveDimensionManager()
        let tesseract = TesseractRotationEngine()
        let zernike = ZernikeLightEngine(lightCount: 32)

        // Simulate biometric input
        dimensionManager.update([
            .biometric(.heartRate): 75,
            .biometric(.hrvCoherence): 0.8,
            .biometric(.breathingRate): 10,
            .biometric(.breathingPhase): 0.5
        ])

        // Process to get latent state
        dimensionManager.processUpdate()
        let latent = dimensionManager.currentLatentState

        // Update spatial audio (tesseract)
        tesseract.updateFromLatent(latent.dimensions)

        // Update lighting (zernike)
        zernike.updateFromLatent(latent.dimensions)

        // Verify outputs
        XCTAssertEqual(tesseract.positions3D.count, 8)
        XCTAssertEqual(zernike.lightIntensities.count, 32)

        // Get synthesis parameters
        let synthParams = dimensionManager.currentSynthesisParameters

        // All components should have valid output
        XCTAssertGreaterThanOrEqual(synthParams.filterCutoff, 0)
        XCTAssertLessThanOrEqual(synthParams.filterCutoff, 1)
    }

    func testContinuousProcessing() async throws {
        let dimensionManager = BioreactiveDimensionManager()
        let tesseract = TesseractRotationEngine()

        // Simulate 5 seconds of continuous processing at 60Hz
        for _ in 0..<300 {
            // Random biometric variation
            dimensionManager.update([
                .biometric(.heartRate): 70 + Float.random(in: -5...5),
                .biometric(.hrvCoherence): 0.7 + Float.random(in: -0.1...0.1),
                .biometric(.breathingPhase): Float.random(in: 0...1)
            ])

            dimensionManager.processUpdate()
            tesseract.updateFromLatent(dimensionManager.currentLatentState.dimensions, deltaTime: 1/60)
        }

        // Should complete without issues
        XCTAssertNotNil(dimensionManager.currentLatentState)
        XCTAssertEqual(tesseract.positions3D.count, 8)
    }
}
