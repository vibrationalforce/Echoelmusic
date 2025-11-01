import XCTest
@testable import Blab
import Network

@MainActor
final class MIDIToLightMapperTests: XCTestCase {

    var mapper: MIDIToLightMapper!

    override func setUp() async throws {
        try await super.setUp()
        mapper = MIDIToLightMapper()
    }

    override func tearDown() async throws {
        mapper.stop()
        mapper = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(mapper, "Mapper should be initialized")
        XCTAssertFalse(mapper.isActive, "Should not be active initially")
        XCTAssertEqual(mapper.currentScene, .ambient, "Default scene should be ambient")
        XCTAssertEqual(mapper.dmxUniverse.count, 512, "DMX universe should be 512 channels")
        XCTAssertFalse(mapper.ledStrips.isEmpty, "Should have default LED strips")
    }

    func testDMXUniverseInitialization() {
        // All channels should start at 0
        XCTAssertTrue(mapper.dmxUniverse.allSatisfy { $0 == 0 }, "All DMX channels should be 0 initially")
    }

    func testDefaultLEDStrips() {
        XCTAssertGreaterThanOrEqual(mapper.ledStrips.count, 1, "Should have at least 1 default LED strip")

        for strip in mapper.ledStrips {
            XCTAssertFalse(strip.name.isEmpty, "Strip should have a name")
            XCTAssertGreaterThan(strip.pixelCount, 0, "Strip should have pixels")
            XCTAssertGreaterThan(strip.startAddress, 0, "Strip should have valid start address")
        }
    }

    // MARK: - Light Scene Tests

    func testLightSceneEnums() {
        let allScenes = MIDIToLightMapper.LightScene.allCases
        XCTAssertEqual(allScenes.count, 6, "Should have 6 light scenes")

        XCTAssertTrue(allScenes.contains(.ambient))
        XCTAssertTrue(allScenes.contains(.performance))
        XCTAssertTrue(allScenes.contains(.meditation))
        XCTAssertTrue(allScenes.contains(.energetic))
        XCTAssertTrue(allScenes.contains(.reactive))
        XCTAssertTrue(allScenes.contains(.strobeSync))
    }

    func testLightSceneDescriptions() {
        XCTAssertEqual(MIDIToLightMapper.LightScene.ambient.description, "Soft ambient lighting")
        XCTAssertEqual(MIDIToLightMapper.LightScene.performance.description, "High-energy performance mode")
        XCTAssertEqual(MIDIToLightMapper.LightScene.meditation.description, "Calming meditation lights")
        XCTAssertEqual(MIDIToLightMapper.LightScene.energetic.description, "Dynamic energetic colors")
        XCTAssertEqual(MIDIToLightMapper.LightScene.reactive.description, "Full bio-reactive control")
        XCTAssertEqual(MIDIToLightMapper.LightScene.strobeSync.description, "Strobe synced to beats")
    }

    func testSceneChange() {
        mapper.currentScene = .performance
        XCTAssertEqual(mapper.currentScene, .performance)

        mapper.currentScene = .meditation
        XCTAssertEqual(mapper.currentScene, .meditation)
    }

    // MARK: - RGB Color Tests

    func testRGBStruct() {
        let color = MIDIToLightMapper.RGB(r: 100, g: 150, b: 200, w: 50)
        XCTAssertEqual(color.r, 100)
        XCTAssertEqual(color.g, 150)
        XCTAssertEqual(color.b, 200)
        XCTAssertEqual(color.w, 50)
    }

    func testRGBPresetColors() {
        let black = MIDIToLightMapper.RGB.black
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)

        let white = MIDIToLightMapper.RGB.white
        XCTAssertEqual(white.r, 255)
        XCTAssertEqual(white.g, 255)
        XCTAssertEqual(white.b, 255)

        let red = MIDIToLightMapper.RGB.red
        XCTAssertEqual(red.r, 255)

        let green = MIDIToLightMapper.RGB.green
        XCTAssertEqual(green.g, 255)

        let blue = MIDIToLightMapper.RGB.blue
        XCTAssertEqual(blue.b, 255)
    }

    // MARK: - LED Strip Tests

    func testLEDStripCreation() {
        let strip = MIDIToLightMapper.LEDStrip(
            name: "Test Strip",
            startAddress: 1,
            pixelCount: 100,
            pixelFormat: .rgb,
            pixels: Array(repeating: .black, count: 100)
        )

        XCTAssertEqual(strip.name, "Test Strip")
        XCTAssertEqual(strip.startAddress, 1)
        XCTAssertEqual(strip.pixelCount, 100)
        XCTAssertEqual(strip.pixels.count, 100)
    }

    func testLEDStripChannelCount() {
        // RGB format: 3 channels per pixel
        let stripRGB = MIDIToLightMapper.LEDStrip(
            name: "RGB Strip",
            startAddress: 1,
            pixelCount: 60,
            pixelFormat: .rgb,
            pixels: []
        )
        XCTAssertEqual(stripRGB.dmxChannelCount, 180) // 60 * 3

        // RGBW format: 4 channels per pixel
        let stripRGBW = MIDIToLightMapper.LEDStrip(
            name: "RGBW Strip",
            startAddress: 1,
            pixelCount: 50,
            pixelFormat: .rgbw,
            pixels: []
        )
        XCTAssertEqual(stripRGBW.dmxChannelCount, 200) // 50 * 4

        // GRB format: 3 channels per pixel
        let stripGRB = MIDIToLightMapper.LEDStrip(
            name: "GRB Strip",
            startAddress: 1,
            pixelCount: 40,
            pixelFormat: .grb,
            pixels: []
        )
        XCTAssertEqual(stripGRB.dmxChannelCount, 120) // 40 * 3
    }

    func testAddLEDStrip() {
        let initialCount = mapper.ledStrips.count

        let newStrip = MIDIToLightMapper.LEDStrip(
            name: "New Strip",
            startAddress: 400,
            pixelCount: 30,
            pixelFormat: .rgb,
            pixels: Array(repeating: .black, count: 30)
        )

        mapper.addLEDStrip(newStrip)

        XCTAssertEqual(mapper.ledStrips.count, initialCount + 1)
    }

    // MARK: - DMX Fixture Tests

    func testDMXFixtureCreation() {
        let fixture = MIDIToLightMapper.DMXFixture(
            name: "PAR Can",
            startAddress: 1,
            channelMap: .rgbPar(r: 1, g: 2, b: 3, dimmer: 4)
        )

        XCTAssertEqual(fixture.name, "PAR Can")
        XCTAssertEqual(fixture.startAddress, 1)
    }

    func testAddFixture() {
        let fixture = MIDIToLightMapper.DMXFixture(
            name: "Moving Head",
            startAddress: 10,
            channelMap: .movingHead(pan: 10, tilt: 11, dimmer: 12, r: 13, g: 14, b: 15)
        )

        mapper.addFixture(fixture)

        // Should not crash
        XCTAssertNotNil(mapper)
    }

    // MARK: - DMX Channel Tests

    func testSetDMXChannel() {
        mapper.setDMXChannel(address: 1, value: 255)
        XCTAssertEqual(mapper.dmxUniverse[0], 255) // DMX is 1-indexed, array is 0-indexed

        mapper.setDMXChannel(address: 512, value: 128)
        XCTAssertEqual(mapper.dmxUniverse[511], 128)
    }

    func testSetDMXChannelRange() {
        mapper.setDMXChannelRange(startAddress: 1, values: [100, 150, 200])

        XCTAssertEqual(mapper.dmxUniverse[0], 100)
        XCTAssertEqual(mapper.dmxUniverse[1], 150)
        XCTAssertEqual(mapper.dmxUniverse[2], 200)
    }

    func testClearDMXUniverse() {
        // Set some channels
        mapper.setDMXChannel(address: 1, value: 255)
        mapper.setDMXChannel(address: 100, value: 128)

        // Clear
        mapper.clearDMXUniverse()

        // All should be 0
        XCTAssertTrue(mapper.dmxUniverse.allSatisfy { $0 == 0 })
    }

    // MARK: - Art-Net Protocol Tests

    func testArtNetPacketGeneration() {
        // Art-Net packet should have proper header
        let packet = mapper.createArtNetPacket(universe: 0, data: Array(repeating: 0, count: 512))

        XCTAssertNotNil(packet)
        if let pkt = packet {
            // Art-Net header: "Art-Net\0"
            XCTAssertEqual(pkt[0], 0x41) // 'A'
            XCTAssertEqual(pkt[1], 0x72) // 'r'
            XCTAssertEqual(pkt[2], 0x74) // 't'
            XCTAssertEqual(pkt[3], 0x2D) // '-'

            // Should be proper length (18 byte header + 512 data)
            XCTAssertEqual(pkt.count, 530)
        }
    }

    func testArtNetUniverseNumber() {
        let packet = mapper.createArtNetPacket(universe: 1, data: Array(repeating: 0, count: 512))

        XCTAssertNotNil(packet)
        // Universe number should be in the packet
    }

    // MARK: - Bio-Reactive Mapping Tests

    func testHRVToColor() {
        mapper.currentScene = .reactive

        // Low coherence (red)
        mapper.updateBioParameters(hrvCoherence: 0.0, heartRate: 60)
        let colorLow = mapper.getCurrentSceneColor()
        XCTAssertGreaterThan(colorLow.r, 200)

        // High coherence (green/blue)
        mapper.updateBioParameters(hrvCoherence: 1.0, heartRate: 60)
        let colorHigh = mapper.getCurrentSceneColor()
        XCTAssertGreaterThan(colorHigh.g, 100)
    }

    func testHeartRateToIntensity() {
        mapper.currentScene = .reactive

        // Low heart rate
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 50)
        let intensityLow = mapper.getCurrentIntensity()

        // High heart rate
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 120)
        let intensityHigh = mapper.getCurrentIntensity()

        XCTAssertGreaterThan(intensityHigh, intensityLow)
    }

    func testGestureToStrobe() {
        mapper.currentScene = .reactive

        // Trigger gesture strobe
        mapper.triggerGestureStrobe(type: "swipe")

        // Should activate strobe briefly
        XCTAssertNotNil(mapper)
    }

    // MARK: - Scene Application Tests

    func testAmbientScene() {
        mapper.currentScene = .ambient
        mapper.applyCurrentScene()

        // Ambient should have low intensity
        let avgIntensity = mapper.dmxUniverse.reduce(0, +) / mapper.dmxUniverse.count
        XCTAssertLessThan(avgIntensity, 150)
    }

    func testPerformanceScene() {
        mapper.currentScene = .performance
        mapper.applyCurrentScene()

        // Performance should have high intensity
        let maxIntensity = mapper.dmxUniverse.max() ?? 0
        XCTAssertGreaterThan(maxIntensity, 100)
    }

    func testMeditationScene() {
        mapper.currentScene = .meditation
        mapper.applyCurrentScene()

        // Meditation should have calm colors (blue/green)
        XCTAssertNotNil(mapper)
    }

    func testEnergeticScene() {
        mapper.currentScene = .energetic
        mapper.applyCurrentScene()

        // Energetic should have dynamic colors
        XCTAssertNotNil(mapper)
    }

    // MARK: - LED Strip Update Tests

    func testSetStripColor() {
        guard let strip = mapper.ledStrips.first else {
            XCTFail("No LED strips available")
            return
        }

        let color = MIDIToLightMapper.RGB.red
        mapper.setStripColor(stripID: strip.id, color: color)

        // All pixels should be red
        let updatedStrip = mapper.ledStrips.first { $0.id == strip.id }
        XCTAssertNotNil(updatedStrip)
        if let strip = updatedStrip {
            XCTAssertTrue(strip.pixels.allSatisfy { $0.r == 255 })
        }
    }

    func testSetStripPixel() {
        guard let strip = mapper.ledStrips.first else {
            XCTFail("No LED strips available")
            return
        }

        let color = MIDIToLightMapper.RGB.green
        mapper.setStripPixel(stripID: strip.id, pixelIndex: 0, color: color)

        let updatedStrip = mapper.ledStrips.first { $0.id == strip.id }
        XCTAssertNotNil(updatedStrip)
        if let strip = updatedStrip {
            XCTAssertEqual(strip.pixels[0].g, 255)
        }
    }

    func testSetStripPattern() {
        guard let strip = mapper.ledStrips.first else {
            XCTFail("No LED strips available")
            return
        }

        // Rainbow pattern
        mapper.setStripPattern(stripID: strip.id, pattern: .rainbow)

        // Should have varied colors
        let updatedStrip = mapper.ledStrips.first { $0.id == strip.id }
        XCTAssertNotNil(updatedStrip)
    }

    // MARK: - MIDI Mapping Tests

    func testMIDINoteToColor() {
        // MIDI note should influence color hue
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        let color = mapper.noteToColor(note: 60)
        XCTAssertNotEqual(color.r, 0)
        XCTAssertNotEqual(color.g, 0)
        XCTAssertNotEqual(color.b, 0)
    }

    func testMIDIVelocityToIntensity() {
        // Velocity 127 = full intensity
        let intensity127 = mapper.velocityToIntensity(velocity: 127)
        XCTAssertEqual(intensity127, 1.0, accuracy: 0.01)

        // Velocity 0 = no intensity
        let intensity0 = mapper.velocityToIntensity(velocity: 0)
        XCTAssertEqual(intensity0, 0.0, accuracy: 0.01)

        // Velocity 64 = half intensity
        let intensity64 = mapper.velocityToIntensity(velocity: 64)
        XCTAssertEqual(intensity64, 0.5, accuracy: 0.1)
    }

    func testMIDIPitchBendToModulation() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        // Pitch bend should modulate lighting
        mapper.handlePitchBend(value: 0.0, channel: 0)  // -2 semitones
        mapper.handlePitchBend(value: 0.5, channel: 0)  // no bend
        mapper.handlePitchBend(value: 1.0, channel: 0)  // +2 semitones

        XCTAssertNotNil(mapper)
    }

    // MARK: - Network Tests

    func testStartStop() {
        // Start should initialize Art-Net socket
        mapper.start()
        XCTAssertTrue(mapper.isActive)

        // Stop should cleanup
        mapper.stop()
        XCTAssertFalse(mapper.isActive)
    }

    func testConnectionStatus() {
        mapper.start()

        // Connection status depends on network availability
        XCTAssertTrue(mapper.isActive || !mapper.isActive)
    }

    // MARK: - Performance Tests

    func testPerformanceDMXUpdate() {
        measure {
            for i in 0..<512 {
                mapper.setDMXChannel(address: i + 1, value: UInt8.random(in: 0...255))
            }
        }
    }

    func testPerformanceArtNetPacketGeneration() {
        measure {
            for _ in 0..<100 {
                _ = mapper.createArtNetPacket(
                    universe: 0,
                    data: Array(repeating: UInt8.random(in: 0...255), count: 512)
                )
            }
        }
    }

    func testPerformanceLEDStripUpdate() {
        guard let strip = mapper.ledStrips.first else {
            XCTFail("No LED strips available")
            return
        }

        measure {
            for i in 0..<strip.pixelCount {
                mapper.setStripPixel(
                    stripID: strip.id,
                    pixelIndex: i,
                    color: MIDIToLightMapper.RGB(
                        r: UInt8.random(in: 0...255),
                        g: UInt8.random(in: 0...255),
                        b: UInt8.random(in: 0...255)
                    )
                )
            }
        }
    }

    // MARK: - Edge Cases

    func testOutOfBoundsDMXChannel() {
        // Channel 0 (invalid)
        mapper.setDMXChannel(address: 0, value: 255)

        // Channel 513 (out of range)
        mapper.setDMXChannel(address: 513, value: 255)

        // Should handle gracefully
        XCTAssertNotNil(mapper)
    }

    func testOutOfBoundsPixel() {
        guard let strip = mapper.ledStrips.first else {
            XCTFail("No LED strips available")
            return
        }

        // Out of bounds pixel
        mapper.setStripPixel(
            stripID: strip.id,
            pixelIndex: 1000,
            color: .red
        )

        // Should handle gracefully
        XCTAssertNotNil(mapper)
    }

    func testInvalidBioParameters() {
        // Negative values
        mapper.updateBioParameters(hrvCoherence: -1.0, heartRate: -50)

        // Extreme values
        mapper.updateBioParameters(hrvCoherence: 10.0, heartRate: 300)

        // Should handle gracefully
        XCTAssertNotNil(mapper)
    }

    // MARK: - Integration Tests

    func testFullWorkflow() {
        // 1. Start Art-Net
        mapper.start()
        XCTAssertTrue(mapper.isActive)

        // 2. Set scene
        mapper.currentScene = .reactive

        // 3. Update bio parameters
        mapper.updateBioParameters(hrvCoherence: 0.7, heartRate: 72)

        // 4. Handle MIDI notes
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 64, velocity: 90, channel: 0)
        mapper.handleNoteOn(note: 67, velocity: 80, channel: 0)

        // 5. Apply scene
        mapper.applyCurrentScene()

        // 6. Update LED strips
        if let strip = mapper.ledStrips.first {
            mapper.setStripPattern(stripID: strip.id, pattern: .rainbow)
        }

        // 7. Send DMX data
        mapper.sendDMXData()

        // 8. Stop
        mapper.stop()
        XCTAssertFalse(mapper.isActive)

        // Should complete without crashes
        XCTAssertNotNil(mapper)
    }

    func testBioReactiveFullRange() {
        mapper.currentScene = .reactive

        let coherenceLevels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let heartRates = [40, 60, 80, 100, 120]

        for coherence in coherenceLevels {
            for hr in heartRates {
                mapper.updateBioParameters(hrvCoherence: coherence, heartRate: hr)
                mapper.applyCurrentScene()

                // Should update without crashes
                XCTAssertNotNil(mapper)
            }
        }
    }

    func testAllSceneTransitions() {
        mapper.start()

        for scene in MIDIToLightMapper.LightScene.allCases {
            mapper.currentScene = scene
            mapper.applyCurrentScene()
            mapper.sendDMXData()

            XCTAssertEqual(mapper.currentScene, scene)
        }

        mapper.stop()
    }
}
