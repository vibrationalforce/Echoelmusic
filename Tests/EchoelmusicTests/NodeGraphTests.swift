import XCTest
import AVFoundation
@testable import Echoelmusic

/// Unit tests for NodeGraph
/// Tests graph operations, parameter control, and processing order
@MainActor
final class NodeGraphTests: XCTestCase {

    var nodeGraph: NodeGraph!

    override func setUp() async throws {
        nodeGraph = NodeGraph()
    }

    override func tearDown() async throws {
        nodeGraph?.stop()
        nodeGraph = nil
    }


    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(nodeGraph)
        XCTAssertTrue(nodeGraph.nodes.isEmpty)
        XCTAssertTrue(nodeGraph.connections.isEmpty)
        XCTAssertFalse(nodeGraph.isProcessing)
    }


    // MARK: - Node Management Tests

    func testAddNode() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        XCTAssertEqual(nodeGraph.nodes.count, 1)
        XCTAssertEqual(nodeGraph.nodes.first?.id, filter.id)
    }

    func testAddMultipleNodes() {
        let filter = FilterNode()
        let reverb = ReverbNode()
        let delay = DelayNode()

        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)
        nodeGraph.addNode(delay)

        XCTAssertEqual(nodeGraph.nodes.count, 3)
    }

    func testRemoveNode() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)
        XCTAssertEqual(nodeGraph.nodes.count, 1)

        nodeGraph.removeNode(id: filter.id)
        XCTAssertTrue(nodeGraph.nodes.isEmpty)
    }

    func testNodeLookup() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        let foundNode = nodeGraph.node(withID: filter.id)
        XCTAssertNotNil(foundNode)
        XCTAssertEqual(foundNode?.id, filter.id)
    }

    func testNodeLookupNotFound() {
        let randomID = UUID()
        let foundNode = nodeGraph.node(withID: randomID)
        XCTAssertNil(foundNode)
    }


    // MARK: - Connection Tests

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

    func testDisconnectNodes() throws {
        let filter = FilterNode()
        let reverb = ReverbNode()

        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)

        try nodeGraph.connect(from: filter.id, to: reverb.id)
        XCTAssertEqual(nodeGraph.connections.count, 1)

        nodeGraph.disconnect(from: filter.id, to: reverb.id)
        XCTAssertTrue(nodeGraph.connections.isEmpty)
    }

    func testConnectNonexistentNode() {
        let filter = FilterNode()
        let randomID = UUID()

        nodeGraph.addNode(filter)

        XCTAssertThrowsError(try nodeGraph.connect(from: filter.id, to: randomID)) { error in
            XCTAssertEqual(error as? NodeGraph.NodeGraphError, .nodeNotFound)
        }
    }

    func testRemoveNodeRemovesConnections() throws {
        let filter = FilterNode()
        let reverb = ReverbNode()

        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)
        try nodeGraph.connect(from: filter.id, to: reverb.id)

        nodeGraph.removeNode(id: filter.id)

        XCTAssertTrue(nodeGraph.connections.isEmpty, "Connections should be removed with node")
    }


    // MARK: - Circular Dependency Tests

    func testDirectCyclePrevented() {
        let nodeA = FilterNode()
        let nodeB = ReverbNode()

        nodeGraph.addNode(nodeA)
        nodeGraph.addNode(nodeB)

        // A → B is fine
        try? nodeGraph.connect(from: nodeA.id, to: nodeB.id)

        // B → A would create cycle - should throw
        XCTAssertThrowsError(try nodeGraph.connect(from: nodeB.id, to: nodeA.id)) { error in
            XCTAssertEqual(error as? NodeGraph.NodeGraphError, .circularDependency)
        }
    }

    func testIndirectCyclePrevented() {
        let nodeA = FilterNode()
        let nodeB = ReverbNode()
        let nodeC = DelayNode()

        nodeGraph.addNode(nodeA)
        nodeGraph.addNode(nodeB)
        nodeGraph.addNode(nodeC)

        // A → B → C chain
        try? nodeGraph.connect(from: nodeA.id, to: nodeB.id)
        try? nodeGraph.connect(from: nodeB.id, to: nodeC.id)

        // C → A would create cycle - should throw
        XCTAssertThrowsError(try nodeGraph.connect(from: nodeC.id, to: nodeA.id)) { error in
            XCTAssertEqual(error as? NodeGraph.NodeGraphError, .circularDependency)
        }
    }

    func testSelfLoopPrevented() {
        let nodeA = FilterNode()
        nodeGraph.addNode(nodeA)

        // A → A is a self-loop - should throw
        XCTAssertThrowsError(try nodeGraph.connect(from: nodeA.id, to: nodeA.id)) { error in
            XCTAssertEqual(error as? NodeGraph.NodeGraphError, .circularDependency)
        }
    }

    func testValidDAGAllowed() throws {
        let nodeA = FilterNode()
        let nodeB = ReverbNode()
        let nodeC = DelayNode()
        let nodeD = CompressorNode()

        nodeGraph.addNode(nodeA)
        nodeGraph.addNode(nodeB)
        nodeGraph.addNode(nodeC)
        nodeGraph.addNode(nodeD)

        // Diamond pattern (A → B → D, A → C → D) is valid DAG
        try nodeGraph.connect(from: nodeA.id, to: nodeB.id)
        try nodeGraph.connect(from: nodeA.id, to: nodeC.id)
        try nodeGraph.connect(from: nodeB.id, to: nodeD.id)
        try nodeGraph.connect(from: nodeC.id, to: nodeD.id)

        XCTAssertEqual(nodeGraph.connections.count, 4)
    }

    func testLongChainNoCycle() throws {
        var nodes: [FilterNode] = []
        for _ in 0..<10 {
            let node = FilterNode()
            nodeGraph.addNode(node)
            nodes.append(node)
        }

        // Create linear chain
        for i in 0..<(nodes.count - 1) {
            try nodeGraph.connect(from: nodes[i].id, to: nodes[i + 1].id)
        }

        XCTAssertEqual(nodeGraph.connections.count, 9)

        // Last → First would create cycle
        XCTAssertThrowsError(try nodeGraph.connect(from: nodes.last!.id, to: nodes.first!.id)) { error in
            XCTAssertEqual(error as? NodeGraph.NodeGraphError, .circularDependency)
        }
    }


    // MARK: - Audio Parameter Tests

    func testSetFilterCutoff() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        nodeGraph.setParameter(.filterCutoff, value: 2000.0)
        // Verify no crash - actual value depends on node implementation
    }

    func testSetFilterResonance() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        nodeGraph.setParameter(.filterResonance, value: 0.5)
    }

    func testSetReverbWet() {
        let reverb = ReverbNode()
        nodeGraph.addNode(reverb)

        nodeGraph.setParameter(.reverbWet, value: 0.3)
    }

    func testSetReverbSize() {
        let reverb = ReverbNode()
        nodeGraph.addNode(reverb)

        nodeGraph.setParameter(.reverbSize, value: 0.7)
    }

    func testSetDelayTime() {
        let delay = DelayNode()
        nodeGraph.addNode(delay)

        nodeGraph.setParameter(.delayTime, value: 0.25)
    }

    func testSetMasterVolume() {
        nodeGraph.setParameter(.masterVolume, value: 0.8)
    }

    func testSetTempo() {
        nodeGraph.setParameter(.tempo, value: 120.0)
    }


    // MARK: - Preset Tests

    func testCreateBiofeedbackChain() {
        let graph = NodeGraph.createBiofeedbackChain()

        XCTAssertGreaterThanOrEqual(graph.nodes.count, 2, "Should have at least filter and reverb")
        XCTAssertFalse(graph.connections.isEmpty, "Should have connections")
    }

    func testCreateHealingPreset() {
        let graph = NodeGraph.createHealingPreset()

        XCTAssertGreaterThanOrEqual(graph.nodes.count, 1, "Should have at least reverb node")
    }

    func testCreateEnergizingPreset() {
        let graph = NodeGraph.createEnergizingPreset()

        XCTAssertGreaterThanOrEqual(graph.nodes.count, 1, "Should have at least filter node")
    }


    // MARK: - Lifecycle Tests

    func testStartStop() {
        nodeGraph.start(sampleRate: 48000.0, maxFrames: 512)
        XCTAssertTrue(nodeGraph.isProcessing)

        nodeGraph.stop()
        XCTAssertFalse(nodeGraph.isProcessing)
    }

    func testReset() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        nodeGraph.reset()
        // Verify no crash
    }


    // MARK: - Bio-Reactivity Tests

    func testUpdateBioSignal() {
        let filter = FilterNode()
        nodeGraph.addNode(filter)

        let bioSignal = BioSignal()
        nodeGraph.updateBioSignal(bioSignal)
        // Verify no crash
    }


    // MARK: - Performance Tests

    func testNodeAdditionPerformance() {
        measure {
            for _ in 0..<100 {
                let filter = FilterNode()
                nodeGraph.addNode(filter)
            }
        }
    }

    func testConnectionPerformance() {
        // Add nodes first
        var nodes: [FilterNode] = []
        for _ in 0..<50 {
            let filter = FilterNode()
            nodeGraph.addNode(filter)
            nodes.append(filter)
        }

        measure {
            for i in 0..<(nodes.count - 1) {
                try? nodeGraph.connect(from: nodes[i].id, to: nodes[i + 1].id)
            }
        }
    }

    func testParameterUpdatePerformance() {
        let filter = FilterNode()
        let reverb = ReverbNode()
        nodeGraph.addNode(filter)
        nodeGraph.addNode(reverb)

        measure {
            for i in 0..<1000 {
                nodeGraph.setParameter(.filterCutoff, value: Float(200 + i))
                nodeGraph.setParameter(.reverbWet, value: Float(i % 100) / 100.0)
            }
        }
    }
}
