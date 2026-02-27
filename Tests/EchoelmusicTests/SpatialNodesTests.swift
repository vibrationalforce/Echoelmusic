import XCTest
@testable import Echoelmusic

/// Tests for Spatial Audio nodes wired into the audio graph.
/// Validates AmbisonicsNode, RoomSimulationNode, DopplerNode, HRTFNode
/// signal processing, bio-reactivity, and NodeFactory registration.
@MainActor
final class SpatialNodesTests: XCTestCase {

    // MARK: - Helpers

    /// Create a mono AVAudioPCMBuffer with a constant value
    private func makeMonoBuffer(value: Float, frameCount: Int = 512) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return nil }
        for i in 0..<frameCount {
            channelData[0][i] = value
        }
        return buffer
    }

    /// Create a stereo AVAudioPCMBuffer with a constant value
    private func makeStereoBuffer(value: Float, frameCount: Int = 512) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return nil }
        for i in 0..<frameCount {
            channelData[0][i] = value
            channelData[1][i] = value
        }
        return buffer
    }

    /// Calculate peak level of a buffer channel
    private func peakLevel(buffer: AVAudioPCMBuffer, channel: Int = 0) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var peak: Float = 0
        for i in 0..<frameCount {
            peak = max(peak, abs(channelData[channel][i]))
        }
        return peak
    }

    // MARK: - AmbisonicsNode Tests

    func testAmbisonicsNodeInitialization() {
        let node = AmbisonicsNode()
        XCTAssertEqual(node.name, "Ambisonics")
        XCTAssertEqual(node.type, .effect)
        XCTAssertTrue(node.isBioReactive)
        XCTAssertFalse(node.parameters.isEmpty)
    }

    func testAmbisonicsNodeBypassPassthrough() {
        let node = AmbisonicsNode()
        node.isBypassed = true
        node.start()

        guard let buffer = makeMonoBuffer(value: 0.5) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)

        // Bypassed node should return input unchanged
        XCTAssertEqual(peakLevel(buffer: result), 0.5, accuracy: 0.01)
    }

    func testAmbisonicsNodeProcessesAudio() {
        let node = AmbisonicsNode()
        node.prepare(sampleRate: 44100, maxFrames: 512)
        node.start()

        guard let buffer = makeStereoBuffer(value: 0.5, frameCount: 256) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)

        // Processed audio should produce output (may differ from input due to encoding/decoding)
        XCTAssertEqual(Int(result.frameLength), 256)
    }

    func testAmbisonicsNodeParameterSetGet() {
        let node = AmbisonicsNode()
        node.setParameter(name: "azimuth", value: 90.0)
        XCTAssertEqual(node.getParameter(name: "azimuth"), 90.0, accuracy: 0.1)

        node.setParameter(name: "elevation", value: 45.0)
        XCTAssertEqual(node.getParameter(name: "elevation"), 45.0, accuracy: 0.1)

        node.setParameter(name: "distance", value: 5.0)
        XCTAssertEqual(node.getParameter(name: "distance"), 5.0, accuracy: 0.1)
    }

    func testAmbisonicsNodeParameterClamping() {
        let node = AmbisonicsNode()
        node.setParameter(name: "azimuth", value: 999.0) // Should clamp to 180
        XCTAssertEqual(node.getParameter(name: "azimuth"), 180.0, accuracy: 0.1)

        node.setParameter(name: "azimuth", value: -999.0) // Should clamp to -180
        XCTAssertEqual(node.getParameter(name: "azimuth"), -180.0, accuracy: 0.1)
    }

    func testAmbisonicsNodeBioReactivity() {
        let node = AmbisonicsNode()
        let signal = BioSignal(coherence: 80) // High coherence

        node.react(to: signal)

        let width = node.getParameter(name: "width")
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width!, 1.0) // High coherence → wider field
    }

    // MARK: - RoomSimulationNode Tests

    func testRoomSimulationNodeInitialization() {
        let node = RoomSimulationNode()
        XCTAssertEqual(node.name, "Room Simulation")
        XCTAssertEqual(node.type, .effect)
        XCTAssertTrue(node.isBioReactive)
    }

    func testRoomSimulationNodeBypass() {
        let node = RoomSimulationNode()
        node.isBypassed = true
        node.start()

        guard let buffer = makeMonoBuffer(value: 0.5) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(peakLevel(buffer: result), 0.5, accuracy: 0.01)
    }

    func testRoomSimulationNodeProcesses() {
        let node = RoomSimulationNode()
        node.prepare(sampleRate: 44100, maxFrames: 512)
        node.start()

        guard let buffer = makeMonoBuffer(value: 0.5, frameCount: 256) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(Int(result.frameLength), 256)
    }

    func testRoomSimulationNodeDryWetBlend() {
        let node = RoomSimulationNode()
        node.setParameter(name: "dryWet", value: 0.0) // Fully dry
        XCTAssertEqual(node.getParameter(name: "dryWet"), 0.0, accuracy: 0.01)

        node.setParameter(name: "dryWet", value: 1.0) // Fully wet
        XCTAssertEqual(node.getParameter(name: "dryWet"), 1.0, accuracy: 0.01)
    }

    // MARK: - DopplerNode Tests

    func testDopplerNodeInitialization() {
        let node = DopplerNode()
        XCTAssertEqual(node.name, "Doppler Effect")
        XCTAssertEqual(node.type, .effect)
        XCTAssertTrue(node.isBioReactive)
    }

    func testDopplerNodeBypass() {
        let node = DopplerNode()
        node.isBypassed = true
        node.start()

        guard let buffer = makeMonoBuffer(value: 0.5) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(peakLevel(buffer: result), 0.5, accuracy: 0.01)
    }

    func testDopplerNodeProcessesWithVelocity() {
        let node = DopplerNode()
        node.prepare(sampleRate: 44100, maxFrames: 512)
        node.start()
        // Set source moving toward listener
        node.sourcePosition = SIMD3<Float>(0, 0, 10)
        node.sourceVelocity = SIMD3<Float>(0, 0, -50) // Moving toward listener

        guard let buffer = makeMonoBuffer(value: 0.5, frameCount: 256) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(Int(result.frameLength), 256)
    }

    func testDopplerNodeParameterClamping() {
        let node = DopplerNode()
        node.setParameter(name: "intensity", value: 3.0) // Should clamp to 2.0
        XCTAssertEqual(node.getParameter(name: "intensity"), 2.0, accuracy: 0.01)
    }

    // MARK: - HRTFNode Tests

    func testHRTFNodeInitialization() {
        let node = HRTFNode()
        XCTAssertEqual(node.name, "HRTF Binaural")
        XCTAssertEqual(node.type, .effect)
        XCTAssertTrue(node.isBioReactive)
    }

    func testHRTFNodeBypass() {
        let node = HRTFNode()
        node.isBypassed = true
        node.start()

        guard let buffer = makeStereoBuffer(value: 0.5) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(peakLevel(buffer: result), 0.5, accuracy: 0.01)
    }

    func testHRTFNodeProcessesStereo() {
        let node = HRTFNode()
        node.prepare(sampleRate: 44100, maxFrames: 512)
        node.start()

        guard let buffer = makeStereoBuffer(value: 0.5, frameCount: 256) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)
        XCTAssertEqual(Int(result.frameLength), 256)
        XCTAssertEqual(Int(result.format.channelCount), 2)
    }

    func testHRTFNodeAzimuthElevationConversion() {
        let node = HRTFNode()
        node.setParameter(name: "azimuth", value: 90.0)
        node.setParameter(name: "elevation", value: 45.0)
        node.setParameter(name: "distance", value: 2.0)

        XCTAssertEqual(node.getParameter(name: "azimuth"), 90.0, accuracy: 0.1)
        XCTAssertEqual(node.getParameter(name: "elevation"), 45.0, accuracy: 0.1)
        XCTAssertEqual(node.getParameter(name: "distance"), 2.0, accuracy: 0.1)
    }

    func testHRTFNodeBioReactivity() {
        let node = HRTFNode()
        let signal = BioSignal(coherence: 90) // Very high coherence

        node.react(to: signal)

        let spread = node.getParameter(name: "spread")
        XCTAssertNotNil(spread)
        XCTAssertGreaterThan(spread!, 0.0) // High coherence → increased spread
    }

    // MARK: - NodeFactory Registration Tests

    func testNodeFactoryCreatesAmbisonicsNode() {
        let manifest = NodeManifest(
            id: UUID().uuidString,
            type: .effect,
            className: "AmbisonicsNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        let node = NodeFactory.createNode(from: manifest)
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.name, "Ambisonics")
    }

    func testNodeFactoryCreatesRoomSimulationNode() {
        let manifest = NodeManifest(
            id: UUID().uuidString,
            type: .effect,
            className: "RoomSimulationNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        let node = NodeFactory.createNode(from: manifest)
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.name, "Room Simulation")
    }

    func testNodeFactoryCreatesDopplerNode() {
        let manifest = NodeManifest(
            id: UUID().uuidString,
            type: .effect,
            className: "DopplerNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        let node = NodeFactory.createNode(from: manifest)
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.name, "Doppler Effect")
    }

    func testNodeFactoryCreatesHRTFNode() {
        let manifest = NodeManifest(
            id: UUID().uuidString,
            type: .effect,
            className: "HRTFNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        let node = NodeFactory.createNode(from: manifest)
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.name, "HRTF Binaural")
    }

    func testAvailableNodeClassesIncludesSpatial() {
        let classes = NodeFactory.availableNodeClasses
        XCTAssertTrue(classes.contains("AmbisonicsNode"))
        XCTAssertTrue(classes.contains("RoomSimulationNode"))
        XCTAssertTrue(classes.contains("DopplerNode"))
        XCTAssertTrue(classes.contains("HRTFNode"))
    }

    // MARK: - Lifecycle Tests

    func testNodeStartStop() {
        let nodes: [BaseEchoelmusicNode] = [
            AmbisonicsNode(),
            RoomSimulationNode(),
            DopplerNode(),
            HRTFNode()
        ]

        for node in nodes {
            XCTAssertFalse(node.isActive, "\(node.name) should start inactive")
            node.start()
            XCTAssertTrue(node.isActive, "\(node.name) should be active after start")
            node.stop()
            XCTAssertFalse(node.isActive, "\(node.name) should be inactive after stop")
        }
    }

    func testNodeReset() {
        let node = AmbisonicsNode()
        node.setParameter(name: "azimuth", value: 90.0)
        node.setParameter(name: "elevation", value: 45.0)

        node.reset()

        XCTAssertEqual(node.getParameter(name: "azimuth"), 0.0, accuracy: 0.1)
        XCTAssertEqual(node.getParameter(name: "elevation"), 0.0, accuracy: 0.1)
    }

    // MARK: - Edge Cases

    func testProcessWithEmptyBuffer() {
        let nodes: [BaseEchoelmusicNode] = [
            AmbisonicsNode(), RoomSimulationNode(), DopplerNode(), HRTFNode()
        ]

        for node in nodes {
            node.prepare(sampleRate: 44100, maxFrames: 512)
            node.start()

            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0) else {
                continue
            }
            buffer.frameLength = 0

            let time = AVAudioTime(sampleTime: 0, atRate: 44100)
            let result = node.process(buffer, time: time)
            XCTAssertEqual(result.frameLength, 0, "\(node.name) should handle empty buffer")
        }
    }

    func testProcessWithInactiveNode() {
        let node = AmbisonicsNode()
        // Don't call start() — node is inactive

        guard let buffer = makeMonoBuffer(value: 0.5) else {
            XCTFail("Failed to create buffer")
            return
        }

        let time = AVAudioTime(sampleTime: 0, atRate: 44100)
        let result = node.process(buffer, time: time)

        // Inactive node should pass through
        XCTAssertEqual(peakLevel(buffer: result), 0.5, accuracy: 0.01)
    }
}
