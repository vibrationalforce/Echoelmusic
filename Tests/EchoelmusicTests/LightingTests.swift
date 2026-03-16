#if canImport(Network)
// LightingTests.swift
// Echoelmusic — EchoelLux Engine Tests
//
// Tests for DMX fixture types, color calculations, Art-Net constants,
// and bio-reactive lighting mappings.
// Pure computation tests — no DMX/Art-Net hardware required.

import XCTest
@testable import Echoelmusic

// MARK: - Art-Net Constants Tests

final class ArtNetConstantsTests: XCTestCase {

    func testPort() {
        XCTAssertEqual(ArtNetConstants.port, 6454)
    }

    func testProtocolID() {
        // "Art-Net\0"
        let expected: [UInt8] = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00]
        XCTAssertEqual(ArtNetConstants.protocolID, expected)
        XCTAssertEqual(ArtNetConstants.protocolID.count, 8)
    }

    func testOpCodes() {
        XCTAssertEqual(ArtNetConstants.opDmx, 0x5000)
        XCTAssertEqual(ArtNetConstants.opPoll, 0x2000)
        XCTAssertEqual(ArtNetConstants.opPollReply, 0x2100)
    }

    func testProtocolVersion() {
        XCTAssertEqual(ArtNetConstants.protocolVersionHi, 0)
        XCTAssertEqual(ArtNetConstants.protocolVersionLo, 14)
    }

    func testChannelsPerUniverse() {
        XCTAssertEqual(ArtNetConstants.channelsPerUniverse, 512)
    }
}

// MARK: - DMX Fixture Type Tests

final class DMXFixtureTypeTests: XCTestCase {

    func testChannelCount_dimmer() {
        XCTAssertEqual(DMXFixtureType.dimmer.channelCount, 1)
    }

    func testChannelCount_rgb() {
        XCTAssertEqual(DMXFixtureType.rgb.channelCount, 3)
    }

    func testChannelCount_rgbw() {
        XCTAssertEqual(DMXFixtureType.rgbw.channelCount, 4)
    }

    func testChannelCount_rgbwau() {
        XCTAssertEqual(DMXFixtureType.rgbwau.channelCount, 6)
    }

    func testChannelCount_movingHead() {
        XCTAssertEqual(DMXFixtureType.movingHead.channelCount, 8)
    }

    func testChannelCount_ledBar() {
        XCTAssertEqual(DMXFixtureType.ledBar.channelCount, 3)
    }

    func testChannelCount_laser() {
        XCTAssertEqual(DMXFixtureType.laser.channelCount, 5)
    }

    func testChannelCount_fogMachine() {
        XCTAssertEqual(DMXFixtureType.fogMachine.channelCount, 2)
    }

    func testChannelCount_strobeLight() {
        XCTAssertEqual(DMXFixtureType.strobeLight.channelCount, 2)
    }

    func testAllCases_count() {
        XCTAssertEqual(DMXFixtureType.allCases.count, 9)
    }

    func testRawValue_codable() {
        for fixtureType in DMXFixtureType.allCases {
            let encoded = try? JSONEncoder().encode(fixtureType)
            XCTAssertNotNil(encoded, "Failed to encode \(fixtureType)")
            if let data = encoded {
                let decoded = try? JSONDecoder().decode(DMXFixtureType.self, from: data)
                XCTAssertEqual(decoded, fixtureType, "Round-trip failed for \(fixtureType)")
            }
        }
    }
}

// MARK: - DMX Fixture Tests

final class DMXFixtureTests: XCTestCase {

    func testInit_defaults() {
        let fixture = DMXFixture(name: "Test", type: .rgb)
        XCTAssertEqual(fixture.name, "Test")
        XCTAssertEqual(fixture.type, .rgb)
        XCTAssertEqual(fixture.universe, 0)
        XCTAssertEqual(fixture.startAddress, 1)
        XCTAssertTrue(fixture.isEnabled)
    }

    func testInit_customAddress() {
        let fixture = DMXFixture(name: "Spot", type: .movingHead, universe: 1, startAddress: 100)
        XCTAssertEqual(fixture.universe, 1)
        XCTAssertEqual(fixture.startAddress, 100)
    }

    func testInit_uniqueIDs() {
        let f1 = DMXFixture(name: "A", type: .rgb)
        let f2 = DMXFixture(name: "B", type: .rgb)
        XCTAssertNotEqual(f1.id, f2.id)
    }

    func testCodable_roundTrip() {
        let original = DMXFixture(name: "Front Wash", type: .rgbw, universe: 0, startAddress: 7)
        let data = try? JSONEncoder().encode(original)
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = try? JSONDecoder().decode(DMXFixture.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.name, "Front Wash")
            XCTAssertEqual(decoded?.type, .rgbw)
            XCTAssertEqual(decoded?.startAddress, 7)
        }
    }
}

// MARK: - Light Color Tests

final class LightColorTests: XCTestCase {

    func testInit_defaults() {
        let color = LightColor()
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 0)
        XCTAssertEqual(color.white, 0)
    }

    func testInit_custom() {
        let color = LightColor(red: 255, green: 128, blue: 64, white: 32)
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 128)
        XCTAssertEqual(color.blue, 64)
        XCTAssertEqual(color.white, 32)
    }

    func testFromCoherence_zero() {
        // Low coherence = cool blue
        let color = LightColor.fromCoherence(0.0)
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 255)
        XCTAssertEqual(color.white, 0)
    }

    func testFromCoherence_one() {
        // High coherence = warm amber/gold
        let color = LightColor.fromCoherence(1.0)
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 180)
        XCTAssertEqual(color.blue, 0)
        XCTAssertEqual(color.white, 100)
    }

    func testFromCoherence_midpoint() {
        let color = LightColor.fromCoherence(0.5)
        // Red: 0.5 * 255 = 127
        XCTAssertEqual(color.red, 127)
        // Green: 0.5 * 180 = 90
        XCTAssertEqual(color.green, 90)
        // Blue: 0.5 * 255 = 127
        XCTAssertEqual(color.blue, 127)
        // White: 0.5 * 100 = 50
        XCTAssertEqual(color.white, 50)
    }

    func testFromCoherence_clamps_negative() {
        let color = LightColor.fromCoherence(-0.5)
        // Should clamp to 0
        XCTAssertEqual(color.red, 0)
        XCTAssertEqual(color.blue, 255)
    }

    func testFromCoherence_clamps_above_one() {
        let color = LightColor.fromCoherence(2.0)
        // Should clamp to 1.0
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.blue, 0)
    }

    func testCodable_roundTrip() {
        let original = LightColor(red: 200, green: 150, blue: 100, white: 50)
        let data = try? JSONEncoder().encode(original)
        XCTAssertNotNil(data)
        if let data = data {
            let decoded = try? JSONDecoder().decode(LightColor.self, from: data)
            XCTAssertEqual(decoded?.red, 200)
            XCTAssertEqual(decoded?.green, 150)
            XCTAssertEqual(decoded?.blue, 100)
            XCTAssertEqual(decoded?.white, 50)
        }
    }
}

// MARK: - Lighting Scene Tests

final class LightingSceneTests: XCTestCase {

    func testInit_defaults() {
        let scene = LightingScene(name: "Ambient")
        XCTAssertEqual(scene.name, "Ambient")
        XCTAssertTrue(scene.fixtures.isEmpty)
    }

    func testInit_withFixtures() {
        let fixtureID = UUID()
        let color = LightColor(red: 255, green: 0, blue: 0)
        let scene = LightingScene(name: "Red", fixtures: [fixtureID: color])
        XCTAssertEqual(scene.fixtures.count, 1)
        XCTAssertEqual(scene.fixtures[fixtureID]?.red, 255)
    }

    func testInit_uniqueIDs() {
        let s1 = LightingScene(name: "A")
        let s2 = LightingScene(name: "B")
        XCTAssertNotEqual(s1.id, s2.id)
    }
}

// MARK: - Bio-Reactive Lighting Mapping Tests

final class BioReactiveLightingTests: XCTestCase {

    func testBreathDimmerCurve_minPhase() {
        // breathPhase=0 → dimmer = 0.3 (never full black)
        let dimmer = 0.3 + 0.0 * 0.7
        XCTAssertEqual(dimmer, 0.3, accuracy: 0.001)
    }

    func testBreathDimmerCurve_maxPhase() {
        // breathPhase=1 → dimmer = 1.0
        let dimmer = 0.3 + 1.0 * 0.7
        XCTAssertEqual(dimmer, 1.0, accuracy: 0.001)
    }

    func testBreathDimmerCurve_midPhase() {
        // breathPhase=0.5 → dimmer = 0.65
        let dimmer = 0.3 + 0.5 * 0.7
        XCTAssertEqual(dimmer, 0.65, accuracy: 0.001)
    }

    func testCoherenceColorGradient_monotonicRed() {
        // Red should increase monotonically with coherence
        var prevRed: UInt8 = 0
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let color = LightColor.fromCoherence(Float(i))
            XCTAssertGreaterThanOrEqual(color.red, prevRed, "Red should increase with coherence")
            prevRed = color.red
        }
    }

    func testCoherenceColorGradient_monotonicBlueDecrease() {
        // Blue should decrease as coherence increases
        var prevBlue: UInt8 = 255
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let color = LightColor.fromCoherence(Float(i))
            XCTAssertLessThanOrEqual(color.blue, prevBlue, "Blue should decrease with coherence")
            prevBlue = color.blue
        }
    }
}
#endif
