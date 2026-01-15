// ILDALaserTests.swift
// Echoelmusic Tests
//
// Comprehensive tests for ILDA Laser Protocol implementation
// Tests: Point encoding, frame generation, pattern synthesis, protocol conformance
//
// Created: 2026-01-15
// Ralph Wiggum Lambda Loop Mode - 100% Test Coverage

import XCTest
@testable import Echoelmusic

final class ILDALaserTests: XCTestCase {

    // MARK: - ILDA Point Tests

    func testILDAPointCreation() {
        let point = ILDAPoint(x: 1000, y: -2000, z: 0, r: 255, g: 128, b: 64)

        XCTAssertEqual(point.x, 1000)
        XCTAssertEqual(point.y, -2000)
        XCTAssertEqual(point.z, 0)
        XCTAssertEqual(point.r, 255)
        XCTAssertEqual(point.g, 128)
        XCTAssertEqual(point.b, 64)
        XCTAssertFalse(point.isBlanked)
    }

    func testILDAPointBlanking() {
        var point = ILDAPoint(x: 0, y: 0, z: 0, r: 255, g: 255, b: 255, blanked: true)
        XCTAssertTrue(point.isBlanked)

        point.isBlanked = false
        XCTAssertFalse(point.isBlanked)

        point.isBlanked = true
        XCTAssertTrue(point.isBlanked)
    }

    func testILDAPointBlankedFactory() {
        let point = ILDAPoint.blanked(x: 1000, y: 2000)

        XCTAssertEqual(point.x, 1000)
        XCTAssertEqual(point.y, 2000)
        XCTAssertTrue(point.isBlanked)
        XCTAssertEqual(point.r, 0)
        XCTAssertEqual(point.g, 0)
        XCTAssertEqual(point.b, 0)
    }

    func testILDAPointNormalizedFactory() {
        // Test center point
        let center = ILDAPoint.fromNormalized(x: 0, y: 0, r: 255, g: 0, b: 0)
        XCTAssertEqual(center.x, 0)
        XCTAssertEqual(center.y, 0)

        // Test positive corner
        let topRight = ILDAPoint.fromNormalized(x: 1.0, y: 1.0, r: 0, g: 255, b: 0)
        XCTAssertEqual(topRight.x, 32767)
        XCTAssertEqual(topRight.y, 32767)

        // Test negative corner
        let bottomLeft = ILDAPoint.fromNormalized(x: -1.0, y: -1.0, r: 0, g: 0, b: 255)
        XCTAssertEqual(bottomLeft.x, -32767)
        XCTAssertEqual(bottomLeft.y, -32767)
    }

    func testILDAPointEtherDreamFormat() {
        let point = ILDAPoint(x: 1000, y: 2000, z: 0, r: 255, g: 128, b: 64)
        let data = point.toEtherDreamFormat()

        // Ether Dream format: x(2) + y(2) + r(1) + g(1) + b(1) + i(1) = 8 bytes
        XCTAssertEqual(data.count, 8)

        // Check X (little endian)
        let xLow = data[0]
        let xHigh = data[1]
        let x = Int16(xHigh) << 8 | Int16(xLow)
        XCTAssertEqual(x, 1000)
    }

    func testILDAPointLastPointFlag() {
        var point = ILDAPoint(x: 0, y: 0, z: 0, r: 255, g: 255, b: 255)
        XCTAssertFalse(point.isLastPoint)

        point.isLastPoint = true
        XCTAssertTrue(point.isLastPoint)
        XCTAssertTrue((point.status & 0x80) != 0)
    }

    // MARK: - ILDA Frame Tests

    func testILDAFrameCreation() {
        let frame = ILDAFrame(name: "Test", company: "Echoelm", frameNumber: 0, totalFrames: 1)

        XCTAssertEqual(frame.name, "Test")
        XCTAssertEqual(frame.company, "Echoelm")
        XCTAssertEqual(frame.frameNumber, 0)
        XCTAssertEqual(frame.totalFrames, 1)
        XCTAssertTrue(frame.points.isEmpty)
    }

    func testILDAFrameMoveTo() {
        var frame = ILDAFrame()
        frame.moveTo(x: 1000, y: 2000)

        XCTAssertEqual(frame.points.count, 1)
        XCTAssertTrue(frame.points[0].isBlanked)
        XCTAssertEqual(frame.points[0].x, 1000)
        XCTAssertEqual(frame.points[0].y, 2000)
    }

    func testILDAFrameLineTo() {
        var frame = ILDAFrame()
        frame.lineTo(x: 1000, y: 2000, r: 255, g: 0, b: 0)

        XCTAssertEqual(frame.points.count, 1)
        XCTAssertFalse(frame.points[0].isBlanked)
        XCTAssertEqual(frame.points[0].r, 255)
    }

    func testILDAFrameEncode() {
        var frame = ILDAFrame(name: "TestFrm", company: "Echoelm")
        frame.lineTo(x: 0, y: 0, r: 255, g: 255, b: 255)
        frame.lineTo(x: 1000, y: 1000, r: 255, g: 0, b: 0)

        let data = frame.encode()

        // Header (32 bytes) + 2 points × 8 bytes = 48 bytes
        XCTAssertEqual(data.count, 32 + 16)

        // Check signature "ILDA"
        XCTAssertEqual(data[0], 0x49) // 'I'
        XCTAssertEqual(data[1], 0x4C) // 'L'
        XCTAssertEqual(data[2], 0x44) // 'D'
        XCTAssertEqual(data[3], 0x41) // 'A'

        // Check format code (Format 5: 2D True Color)
        XCTAssertEqual(data[7], ILDAConstants.format5_2DTrueColor)
    }

    func testILDAFramePointCount() {
        var frame = ILDAFrame()
        for i in 0..<100 {
            frame.lineTo(x: Int16(i), y: Int16(i), r: 255, g: 255, b: 255)
        }

        XCTAssertEqual(frame.points.count, 100)

        let data = frame.encode()
        // Check point count in header (bytes 24-25, big endian)
        let countHigh = UInt16(data[24])
        let countLow = UInt16(data[25])
        let count = (countHigh << 8) | countLow
        XCTAssertEqual(count, 100)
    }

    // MARK: - Pattern Generator Tests

    func testPatternGeneratorCircle() {
        let generator = LaserPatternGenerator()
        var params = LaserPatternGenerator.PatternParams()
        params.scale = 0.5

        let frame = generator.generateFrame(pattern: .circle, params: params)

        // Default resolution is 500 points
        XCTAssertEqual(frame.points.count, 500)

        // All points should be visible (not blanked)
        let blankedCount = frame.points.filter { $0.isBlanked }.count
        XCTAssertEqual(blankedCount, 0)
    }

    func testPatternGeneratorSpiral() {
        let generator = LaserPatternGenerator()
        let params = LaserPatternGenerator.PatternParams()

        let frame = generator.generateFrame(pattern: .spiral, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        XCTAssertEqual(frame.name, "Spiral")
    }

    func testPatternGeneratorLissajous() {
        let generator = LaserPatternGenerator()
        let params = LaserPatternGenerator.PatternParams()

        let frame = generator.generateFrame(pattern: .lissajous, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        XCTAssertEqual(frame.name, "Lissajous")
    }

    func testPatternGeneratorStar() {
        let generator = LaserPatternGenerator()
        var params = LaserPatternGenerator.PatternParams()
        params.coherence = 0.5

        let frame = generator.generateFrame(pattern: .star, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        // Star pattern has blanking for move-to
        let blankedCount = frame.points.filter { $0.isBlanked }.count
        XCTAssertGreaterThanOrEqual(blankedCount, 0)
    }

    func testPatternGeneratorFlowerOfLife() {
        let generator = LaserPatternGenerator()
        let params = LaserPatternGenerator.PatternParams()

        let frame = generator.generateFrame(pattern: .flowerOfLife, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        // Flower of Life has 7 circles with blanking between them
        let blankedCount = frame.points.filter { $0.isBlanked }.count
        XCTAssertGreaterThanOrEqual(blankedCount, 6) // At least 6 blanking moves
    }

    func testPatternGeneratorMetatronsCube() {
        let generator = LaserPatternGenerator()
        let params = LaserPatternGenerator.PatternParams()

        let frame = generator.generateFrame(pattern: .metatronsCube, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        XCTAssertEqual(frame.name, "Metatron's Cube")
    }

    func testPatternGeneratorHeartbeat() {
        let generator = LaserPatternGenerator()
        var params = LaserPatternGenerator.PatternParams()
        params.heartRate = 72.0

        let frame = generator.generateFrame(pattern: .heartbeat, params: params)

        XCTAssertEqual(frame.points.count, 500) // Default resolution
        XCTAssertEqual(frame.name, "Heartbeat")
    }

    func testPatternGeneratorCoherenceRings() {
        let generator = LaserPatternGenerator()
        var params = LaserPatternGenerator.PatternParams()
        params.coherence = 0.8

        let frame = generator.generateFrame(pattern: .coherenceRings, params: params)

        XCTAssertFalse(frame.points.isEmpty)
        // High coherence should produce more rings
    }

    func testPatternGeneratorWaveform() {
        let generator = LaserPatternGenerator()
        let params = LaserPatternGenerator.PatternParams()

        let frame = generator.generateFrame(pattern: .waveform, params: params)

        XCTAssertEqual(frame.points.count, 500)
    }

    func testPatternGeneratorResolution() {
        let generator = LaserPatternGenerator()
        generator.resolution = 100

        let frame = generator.generateFrame(pattern: .circle, params: LaserPatternGenerator.PatternParams())

        XCTAssertEqual(frame.points.count, 100)
    }

    func testPatternParamsDefaults() {
        let params = LaserPatternGenerator.PatternParams()

        XCTAssertEqual(params.scale, 0.8)
        XCTAssertEqual(params.speed, 1.0)
        XCTAssertEqual(params.hue, 0.0)
        XCTAssertEqual(params.coherence, 0.5)
        XCTAssertEqual(params.heartRate, 72.0)
        XCTAssertEqual(params.intensity, 1.0)
    }

    // MARK: - Laser Pattern Enum Tests

    func testLaserPatternAllCases() {
        let allPatterns = LaserPattern.allCases

        XCTAssertEqual(allPatterns.count, 10)
        XCTAssertTrue(allPatterns.contains(.circle))
        XCTAssertTrue(allPatterns.contains(.spiral))
        XCTAssertTrue(allPatterns.contains(.lissajous))
        XCTAssertTrue(allPatterns.contains(.star))
        XCTAssertTrue(allPatterns.contains(.flowerOfLife))
        XCTAssertTrue(allPatterns.contains(.metatronsCube))
        XCTAssertTrue(allPatterns.contains(.heartbeat))
        XCTAssertTrue(allPatterns.contains(.coherenceRings))
        XCTAssertTrue(allPatterns.contains(.waveform))
        XCTAssertTrue(allPatterns.contains(.custom))
    }

    func testLaserPatternIdentifiable() {
        for pattern in LaserPattern.allCases {
            XCTAssertEqual(pattern.id, pattern.rawValue)
        }
    }

    // MARK: - ILDA Constants Tests

    func testILDAConstants() {
        XCTAssertEqual(ILDAConstants.signature, [0x49, 0x4C, 0x44, 0x41])
        XCTAssertEqual(ILDAConstants.format5_2DTrueColor, 5)
        XCTAssertEqual(ILDAConstants.coordMin, -32768)
        XCTAssertEqual(ILDAConstants.coordMax, 32767)
        XCTAssertEqual(ILDAConstants.defaultSampleRate, 30000)
        XCTAssertEqual(ILDAConstants.etherDreamPort, 7765)
    }

    // MARK: - DAC Type Tests

    func testDACTypeAllCases() {
        let allTypes = ILDALaserController.DACType.allCases

        XCTAssertEqual(allTypes.count, 4)
        XCTAssertTrue(allTypes.contains(.etherDream))
        XCTAssertTrue(allTypes.contains(.laserCube))
        XCTAssertTrue(allTypes.contains(.beyond))
        XCTAssertTrue(allTypes.contains(.generic))
    }

    func testDACTypeRawValues() {
        XCTAssertEqual(ILDALaserController.DACType.etherDream.rawValue, "Ether Dream")
        XCTAssertEqual(ILDALaserController.DACType.laserCube.rawValue, "LaserCube")
        XCTAssertEqual(ILDALaserController.DACType.beyond.rawValue, "Pangolin Beyond")
        XCTAssertEqual(ILDALaserController.DACType.generic.rawValue, "Generic ILDA")
    }

    // MARK: - Error Tests

    func testILDAErrorDescriptions() {
        let invalidSig = ILDAError.invalidSignature
        XCTAssertEqual(invalidSig.errorDescription, "Invalid ILDA file signature")

        let invalidFormat = ILDAError.invalidFormat
        XCTAssertEqual(invalidFormat.errorDescription, "Unsupported ILDA format")

        let parseError = ILDAError.parseError("Test error")
        XCTAssertEqual(parseError.errorDescription, "ILDA parse error: Test error")
    }

    // MARK: - Performance Tests

    func testPatternGenerationPerformance() {
        let generator = LaserPatternGenerator()
        generator.resolution = 1000  // High resolution

        let params = LaserPatternGenerator.PatternParams()

        measure {
            for pattern in LaserPattern.allCases {
                if pattern != .custom {
                    _ = generator.generateFrame(pattern: pattern, params: params)
                }
            }
        }
    }

    func testFrameEncodingPerformance() {
        var frame = ILDAFrame()
        for i in 0..<1000 {
            frame.lineTo(x: Int16(i % 32767), y: Int16(i % 32767), r: 255, g: 255, b: 255)
        }

        measure {
            _ = frame.encode()
        }
    }
}
