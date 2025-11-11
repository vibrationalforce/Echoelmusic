import XCTest
@testable import Echoelmusic
import AVFoundation

/// Tests for NodeGraph audio processing pipeline
@MainActor
final class NodeGraphTests: XCTestCase {

    var nodeGraph: NodeGraph!

    override func setUp() async throws {
        nodeGraph = NodeGraph()
    }

    override func tearDown() async throws {
        nodeGraph = nil
    }

    /// Test adding nodes to graph
    func testAddNode() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        XCTAssertEqual(nodeGraph.nodes.count, 1)
        XCTAssertEqual(nodeGraph.nodes.first?.id, filter.id)
    }

    /// Test removing nodes from graph
    func testRemoveNode() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        nodeGraph.removeNode(id: filter.id)

        XCTAssertEqual(nodeGraph.nodes.count, 0)
    }

    /// Test connecting nodes
    func testConnectNodes() throws {
        let filter = FilterNode()
        let reverb = ReverbNode()

        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)

        try nodeGraph.connect(from: filter.id, to: reverb.id)

        XCTAssertEqual(nodeGraph.connections.count, 1)
        XCTAssertEqual(nodeGraph.connections.first?.sourceNodeID, filter.id)
        XCTAssertEqual(nodeGraph.connections.first?.destinationNodeID, reverb.id)
    }

    /// Test circular dependency detection
    func testCircularDependencyPrevention() {
        let filter1 = FilterNode()
        let filter2 = FilterNode()

        nodeGraph.addNode(filter1)
        nodeGraph.addNode(filter2)

        // Create connection A → B
        try? nodeGraph.connect(from: filter1.id, to: filter2.id)

        // Try to create cycle B → A (should fail)
        XCTAssertThrowsError(try nodeGraph.connect(from: filter2.id, to: filter1.id)) { error in
            guard case NodeGraph.NodeGraphError.circularDependency = error else {
                XCTFail("Expected circularDependency error")
                return
            }
        }
    }

    /// Test bio-reactive parameter updates
    func testBioReactiveParameterUpdates() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        let bioSignal = BioSignal(
            hrv: 75.0,
            heartRate: 70.0,
            coherence: 80.0,
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        filter.react(to: bioSignal)

        // Filter should update cutoff based on heart rate
        let cutoff = filter.getParameter(name: "cutoffFrequency")
        XCTAssertNotNil(cutoff)
    }

    /// Test preset saving and loading
    func testPresetSaveLoad() {
        let filter = FilterNode()
        filter.setParameter(name: "cutoffFrequency", value: 2000.0)

        let reverb = ReverbNode()
        reverb.setParameter(name: "wetDry", value: 50.0)

        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)

        try? nodeGraph.connect(from: filter.id, to: reverb.id)

        let preset = nodeGraph.savePreset(name: "Test Preset")

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.nodes.count, 2)
        XCTAssertEqual(preset.connections.count, 1)
    }

    /// Test node graph performance
    func testNodeGraphPerformance() {
        measure {
            let graph = NodeGraph()

            // Add 10 nodes
            for _ in 0..<10 {
                graph.addNode(FilterNode())
            }

            // Process 1000 times
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
            let time = AVAudioTime(hostTime: mach_absolute_time())

            for _ in 0..<1000 {
                _ = graph.process(buffer, time: time)
            }
        }
    }
}
