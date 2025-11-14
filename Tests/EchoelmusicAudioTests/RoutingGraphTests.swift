import XCTest
@testable import EchoelmusicAudio

final class RoutingGraphTests: XCTestCase {

    func testAddRemoveNode() {
        let graph = RoutingGraph()

        let nodeID = UUID()
        graph.addNode(nodeID)

        let processingOrder = graph.getProcessingOrder()
        XCTAssertTrue(processingOrder.contains(nodeID))

        graph.removeNode(nodeID)
        let updatedOrder = graph.getProcessingOrder()
        XCTAssertFalse(updatedOrder.contains(nodeID))
    }

    func testConnect() throws {
        let graph = RoutingGraph()

        let sourceID = UUID()
        let destID = UUID()

        graph.addNode(sourceID)
        graph.addNode(destID)

        let connection = RoutingGraph.Connection(
            sourceID: sourceID,
            destinationID: destID,
            channel: 0
        )

        XCTAssertNoThrow(try graph.connect(connection))
    }

    func testCyclicDependencyDetection() {
        let graph = RoutingGraph()

        let node1 = UUID()
        let node2 = UUID()
        let node3 = UUID()

        graph.addNode(node1)
        graph.addNode(node2)
        graph.addNode(node3)

        // Create chain: node1 → node2 → node3
        XCTAssertNoThrow(try graph.connect(.init(sourceID: node1, destinationID: node2)))
        XCTAssertNoThrow(try graph.connect(.init(sourceID: node2, destinationID: node3)))

        // Attempting to connect node3 → node1 should fail (creates cycle)
        XCTAssertThrowsError(try graph.connect(.init(sourceID: node3, destinationID: node1)))
    }
}
