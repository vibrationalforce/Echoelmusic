import Foundation

/// Audio routing graph for dynamic signal flow
/// Manages connections between audio nodes with topological sorting
public final class RoutingGraph: Sendable {

    /// Node connection
    public struct Connection: Sendable, Hashable {
        public let sourceID: UUID
        public let destinationID: UUID
        public let channel: Int

        public init(sourceID: UUID, destinationID: UUID, channel: Int = 0) {
            self.sourceID = sourceID
            self.destinationID = destinationID
            self.channel = channel
        }
    }

    /// Routing graph state
    private struct State: Sendable {
        var connections: Set<Connection> = []
        var nodeIDs: Set<UUID> = []
    }

    private let lock = NSLock()
    private var state = State()

    public init() {}

    /// Add a node to the graph
    /// - Parameter nodeID: Node identifier
    public func addNode(_ nodeID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        state.nodeIDs.insert(nodeID)
    }

    /// Remove a node from the graph
    /// - Parameter nodeID: Node identifier
    public func removeNode(_ nodeID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        // Remove all connections involving this node
        state.connections.removeAll { connection in
            connection.sourceID == nodeID || connection.destinationID == nodeID
        }
        state.nodeIDs.remove(nodeID)
    }

    /// Connect two nodes
    /// - Parameter connection: Connection to add
    /// - Throws: If connection would create a cycle
    public func connect(_ connection: Connection) throws {
        lock.lock()
        defer { lock.unlock() }

        // Check for cycles
        if wouldCreateCycle(connection) {
            throw RoutingError.cyclicDependency
        }

        state.connections.insert(connection)
    }

    /// Disconnect two nodes
    /// - Parameter connection: Connection to remove
    public func disconnect(_ connection: Connection) {
        lock.lock()
        defer { lock.unlock() }
        state.connections.remove(connection)
    }

    /// Get processing order (topological sort)
    /// - Returns: Ordered array of node IDs
    public func getProcessingOrder() -> [UUID] {
        lock.lock()
        let connections = state.connections
        let nodeIDs = state.nodeIDs
        lock.unlock()

        var result: [UUID] = []
        var visited = Set<UUID>()
        var temp = Set<UUID>()

        func visit(_ nodeID: UUID) {
            if temp.contains(nodeID) {
                return // Cycle detected
            }
            if visited.contains(nodeID) {
                return
            }

            temp.insert(nodeID)

            // Visit dependencies
            let dependencies = connections
                .filter { $0.destinationID == nodeID }
                .map { $0.sourceID }

            for depID in dependencies {
                visit(depID)
            }

            temp.remove(nodeID)
            visited.insert(nodeID)
            result.append(nodeID)
        }

        for nodeID in nodeIDs {
            visit(nodeID)
        }

        return result
    }

    private func wouldCreateCycle(_ newConnection: Connection) -> Bool {
        // Simple cycle detection: check if destination has path back to source
        var visited = Set<UUID>()
        var queue = [newConnection.destinationID]

        while !queue.isEmpty {
            let current = queue.removeFirst()

            if current == newConnection.sourceID {
                return true
            }

            if visited.contains(current) {
                continue
            }

            visited.insert(current)

            let outgoing = state.connections
                .filter { $0.sourceID == current }
                .map { $0.destinationID }

            queue.append(contentsOf: outgoing)
        }

        return false
    }
}

public enum RoutingError: Error {
    case cyclicDependency
    case nodeNotFound
}
