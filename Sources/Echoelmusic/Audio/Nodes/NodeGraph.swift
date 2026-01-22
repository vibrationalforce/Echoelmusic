import Foundation
import AVFoundation
import Combine
import os.log

/// Manages a graph of interconnected audio processing nodes
/// Handles signal routing, parameter automation, and bio-reactivity
@MainActor
class NodeGraph: ObservableObject {

    // MARK: - Published Properties

    /// All nodes in the graph
    @Published var nodes: [EchoelmusicNode] = []

    /// Active connections between nodes
    @Published var connections: [NodeConnection] = []

    /// Whether the graph is currently processing
    @Published var isProcessing: Bool = false


    // MARK: - Private Properties

    /// Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()

    /// Current bio-signal for reactivity
    private var currentBioSignal = BioSignal()

    /// Processing queue (audio thread)
    private let audioQueue = DispatchQueue(
        label: "com.echoelmusic.nodegraph.audio",
        qos: .userInteractive
    )

    // MARK: - Cached Processing Order (PERFORMANCE)
    /// Cached topological sort result - invalidated when graph changes
    /// Avoids recalculating processing order every audio frame
    private var cachedProcessingOrder: [UUID]?

    /// Invalidate cached processing order when graph structure changes
    private func invalidateCache() {
        cachedProcessingOrder = nil
    }


    // MARK: - Node Management

    /// Add a node to the graph
    func addNode(_ node: EchoelmusicNode) {
        nodes.append(node)
        invalidateCache() // Graph structure changed
        log.audio("📊 Added node: \(node.name) (\(node.type.rawValue))")
    }

    /// Remove a node from the graph
    func removeNode(id: UUID) {
        // Remove connections involving this node
        connections.removeAll { connection in
            connection.sourceNodeID == id || connection.destinationNodeID == id
        }

        // Remove node
        nodes.removeAll { $0.id == id }
        invalidateCache() // Graph structure changed
    }

    /// Get node by ID
    func node(withID id: UUID) -> EchoelmusicNode? {
        return nodes.first { $0.id == id }
    }


    // MARK: - Connection Management

    /// Connect two nodes
    func connect(from sourceID: UUID, to destinationID: UUID) throws {
        guard let source = node(withID: sourceID),
              let destination = node(withID: destinationID) else {
            throw NodeGraphError.nodeNotFound
        }

        // Check for circular dependencies
        if wouldCreateCycle(connecting: sourceID, to: destinationID) {
            throw NodeGraphError.circularDependency
        }

        let connection = NodeConnection(
            sourceNodeID: sourceID,
            destinationNodeID: destinationID
        )

        connections.append(connection)
        invalidateCache() // Graph structure changed

        log.audio("📊 Connected: \(source.name) → \(destination.name)")
    }

    /// Disconnect two nodes
    func disconnect(from sourceID: UUID, to destinationID: UUID) {
        connections.removeAll { connection in
            connection.sourceNodeID == sourceID &&
            connection.destinationNodeID == destinationID
        }
        invalidateCache() // Graph structure changed
    }

    /// Check if connecting two nodes would create a cycle
    private func wouldCreateCycle(connecting sourceID: UUID, to destinationID: UUID) -> Bool {
        // Simple cycle detection: check if destination has path back to source
        var visited = Set<UUID>()
        var queue = [destinationID]

        while !queue.isEmpty {
            let current = queue.removeFirst()

            if current == sourceID {
                return true  // Cycle detected
            }

            if visited.contains(current) {
                continue
            }

            visited.insert(current)

            // Find all nodes connected from current
            let outgoing = connections
                .filter { $0.sourceNodeID == current }
                .map { $0.destinationNodeID }

            queue.append(contentsOf: outgoing)
        }

        return false
    }


    // MARK: - Audio Processing

    /// Process audio buffer through the node graph
    /// PERFORMANCE: Uses cached topological sort instead of recalculating every frame
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard isProcessing else { return buffer }

        // Get cached processing order (only recalculate when graph changes)
        if cachedProcessingOrder == nil {
            cachedProcessingOrder = topologicalSort()
        }

        let orderedNodes = cachedProcessingOrder ?? []

        var currentBuffer = buffer

        // Process through each node in order
        for nodeID in orderedNodes {
            guard let node = node(withID: nodeID) else { continue }

            // Skip bypassed nodes
            if node.isBypassed || !node.isActive {
                continue
            }

            // Process buffer
            currentBuffer = node.process(currentBuffer, time: time)
        }

        return currentBuffer
    }

    /// Topological sort for processing order
    private func topologicalSort() -> [UUID] {
        var result: [UUID] = []
        var visited = Set<UUID>()
        var temp = Set<UUID>()

        func visit(_ nodeID: UUID) {
            if temp.contains(nodeID) {
                // Cycle detected - shouldn't happen with our checks
                return
            }

            if visited.contains(nodeID) {
                return
            }

            temp.insert(nodeID)

            // Visit all dependencies (incoming connections)
            let dependencies = connections
                .filter { $0.destinationNodeID == nodeID }
                .map { $0.sourceNodeID }

            for depID in dependencies {
                visit(depID)
            }

            temp.remove(nodeID)
            visited.insert(nodeID)
            result.append(nodeID)
        }

        // Visit all nodes
        for node in nodes {
            visit(node.id)
        }

        return result
    }


    // MARK: - Bio-Reactivity

    /// Update all nodes with new bio-signal data
    func updateBioSignal(_ signal: BioSignal) {
        currentBioSignal = signal

        // Update all nodes
        for node in nodes {
            node.react(to: signal)
        }
    }


    // MARK: - Lifecycle

    /// Start processing
    func start(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        // Prepare all nodes
        for node in nodes {
            node.prepare(sampleRate: sampleRate, maxFrames: maxFrames)
            node.start()
        }

        isProcessing = true
        log.audio("📊 NodeGraph started (\(nodes.count) nodes)")
    }

    /// Stop processing
    func stop() {
        // Stop all nodes
        for node in nodes {
            node.stop()
        }

        isProcessing = false
        log.audio("📊 NodeGraph stopped")
    }

    /// Reset all nodes
    func reset() {
        for node in nodes {
            node.reset()
        }
    }


    // MARK: - Presets

    /// Load a preset node configuration
    func loadPreset(_ preset: NodeGraphPreset) {
        // Clear existing
        nodes.removeAll()
        connections.removeAll()
        invalidateCache()

        // Track created node IDs for connection mapping
        var nodeIDMap: [String: UUID] = [:]

        // Load nodes from preset using factory pattern
        for manifest in preset.nodes {
            if let node = NodeFactory.createNode(from: manifest) {
                // Apply saved parameters
                for (paramName, paramValue) in manifest.parameters {
                    node.setParameter(name: paramName, value: paramValue)
                }

                // Apply bypass state
                node.isBypassed = manifest.isBypassed

                // Track ID mapping
                nodeIDMap[manifest.id] = node.id

                // Add to graph
                nodes.append(node)
            } else {
                log.audio("⚠️ Failed to create node: \(manifest.className)", level: .warning)
            }
        }

        // Restore connections using ID mapping
        for connectionManifest in preset.connections {
            guard let sourceID = nodeIDMap[connectionManifest.sourceNodeID],
                  let destID = nodeIDMap[connectionManifest.destinationNodeID] else {
                log.audio("⚠️ Connection node not found", level: .warning)
                continue
            }

            do {
                try connect(from: sourceID, to: destID)
            } catch {
                log.audio("⚠️ Failed to restore connection: \(error)", level: .warning)
            }
        }

        log.audio("📊 Loaded preset: \(preset.name) (\(nodes.count) nodes, \(connections.count) connections)")
    }

    /// Save current configuration as preset
    func savePreset(name: String) -> NodeGraphPreset {
        let nodeManifests = nodes.map { node in
            (node as? BaseEchoelmusicNode)?.createManifest()
        }.compactMap { $0 }

        return NodeGraphPreset(
            name: name,
            nodes: nodeManifests,
            connections: connections
        )
    }


    // MARK: - Errors

    enum NodeGraphError: Error, LocalizedError {
        case nodeNotFound
        case circularDependency
        case invalidConnection

        var errorDescription: String? {
            switch self {
            case .nodeNotFound:
                return "Node not found in graph"
            case .circularDependency:
                return "Connection would create circular dependency"
            case .invalidConnection:
                return "Invalid node connection"
            }
        }
    }
}


// MARK: - Supporting Types

/// Connection between two nodes
struct NodeConnection: Identifiable {
    let id = UUID()
    let sourceNodeID: UUID
    let destinationNodeID: UUID
}

/// Node graph preset
struct NodeGraphPreset: Codable, Identifiable {
    let id = UUID()
    let name: String
    let nodes: [NodeManifest]
    let connections: [ConnectionManifest]

    struct ConnectionManifest: Codable {
        let sourceNodeID: String
        let destinationNodeID: String
    }
}


// MARK: - Node Factory

/// Factory for creating nodes from manifests
enum NodeFactory {

    /// Create a node from a manifest using the className
    @MainActor
    static func createNode(from manifest: NodeManifest) -> EchoelmusicNode? {
        switch manifest.className {
        case "FilterNode":
            return FilterNode()
        case "ReverbNode":
            return ReverbNode()
        case "DelayNode":
            return DelayNode()
        case "CompressorNode":
            return CompressorNode()
        default:
            // Try to create a generic node for unknown types
            log.audio("⚠️ Unknown node class: \(manifest.className)", level: .warning)
            return nil
        }
    }

    /// Get all available node class names
    static var availableNodeClasses: [String] {
        ["FilterNode", "ReverbNode", "DelayNode", "CompressorNode"]
    }
}


// MARK: - Parameter Types for UnifiedControlHub

extension NodeGraph {

    /// Standard audio parameters that can be controlled from UnifiedControlHub
    enum AudioParameter {
        case filterCutoff
        case filterResonance
        case reverbWet
        case reverbSize
        case delayTime
        case masterVolume
        case tempo
    }

    /// Set a standard audio parameter across all relevant nodes
    func setParameter(_ parameter: AudioParameter, value: Float) {
        switch parameter {
        case .filterCutoff:
            for node in nodes where node.type == .filter {
                node.setParameter(name: "cutoffFrequency", value: value)
            }
        case .filterResonance:
            for node in nodes where node.type == .filter {
                node.setParameter(name: "resonance", value: value)
            }
        case .reverbWet:
            for node in nodes where node.type == .reverb {
                node.setParameter(name: "wetDry", value: value * 100) // 0-1 to 0-100
            }
        case .reverbSize:
            for node in nodes where node.type == .reverb {
                node.setParameter(name: "roomSize", value: value * 100)
            }
        case .delayTime:
            for node in nodes where node.type == .delay {
                node.setParameter(name: "delayTime", value: value)
            }
        case .masterVolume:
            // Apply to output nodes
            for node in nodes where node.type == .output {
                node.setParameter(name: "volume", value: value)
            }
        case .tempo:
            // Apply to tempo-synced effects
            for node in nodes {
                node.setParameter(name: "tempo", value: value)
            }
        }
    }
}


extension NodeGraph {

    /// Create default biofeedback processing chain
    static func createBiofeedbackChain() -> NodeGraph {
        let graph = NodeGraph()

        // Create nodes
        let filter = FilterNode()
        let reverb = ReverbNode()

        // Add to graph
        graph.addNode(filter)
        graph.addNode(reverb)

        // Connect: Input → Filter → Reverb → Output
        try? graph.connect(from: filter.id, to: reverb.id)

        return graph
    }

    /// Create ambient healing preset
    static func createHealingPreset() -> NodeGraph {
        let graph = NodeGraph()

        let reverb = ReverbNode()
        reverb.setParameter(name: "wetDry", value: 60.0)  // More wet

        graph.addNode(reverb)

        return graph
    }

    /// Create energizing preset
    static func createEnergizingPreset() -> NodeGraph {
        let graph = NodeGraph()

        let filter = FilterNode()
        filter.setParameter(name: "cutoffFrequency", value: 4000.0)  // Brighter

        graph.addNode(filter)

        return graph
    }
}
