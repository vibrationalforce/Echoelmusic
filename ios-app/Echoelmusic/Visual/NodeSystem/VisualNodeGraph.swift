import Foundation
import MetalKit
import SwiftUI
import Combine

// MARK: - Advanced Visual Node System
// Touch Designer / Resolume inspired node-based visual programming

/// Visual Node Graph System
/// Allows creating complex visual effects by connecting nodes
@MainActor
class VisualNodeGraph: ObservableObject {

    // MARK: - Published Properties
    @Published var nodes: [VisualNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var selectedNodeIDs: Set<UUID> = []
    @Published var isPlaying = false

    // MARK: - Rendering
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: [UUID: MTLTexture] = [:]

    var fps: Int = 60
    var resolution: CGSize = CGSize(width: 1920, height: 1080)

    // MARK: - Init
    init() {
        setupMetal()
    }

    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
    }

    // MARK: - Node Management
    func addNode(_ node: VisualNode) {
        nodes.append(node)
    }

    func removeNode(_ nodeID: UUID) {
        // Remove connections
        connections.removeAll { $0.from.nodeID == nodeID || $0.to.nodeID == nodeID }

        // Remove node
        nodes.removeAll { $0.id == nodeID }

        // Clear from selection
        selectedNodeIDs.remove(nodeID)

        // Clear texture cache
        textureCache.removeValue(forKey: nodeID)
    }

    func getNode(_ id: UUID) -> VisualNode? {
        return nodes.first { $0.id == id }
    }

    // MARK: - Connection Management
    func connect(from: NodeSocket, to: NodeSocket) -> Bool {
        // Validate connection
        guard from.direction == .output && to.direction == .input else { return false }
        guard from.dataType == to.dataType else { return false }

        // Check for cycles
        if wouldCreateCycle(from: from, to: to) {
            return false
        }

        // Remove existing connection to input (inputs can only have one connection)
        connections.removeAll { $0.to == to }

        // Create connection
        let connection = NodeConnection(from: from, to: to)
        connections.append(connection)

        return true
    }

    func disconnect(_ connection: NodeConnection) {
        connections.removeAll { $0.id == connection.id }
    }

    private func wouldCreateCycle(from: NodeSocket, to: NodeSocket) -> Bool {
        // Simplified cycle detection - would implement full DFS in production
        return from.nodeID == to.nodeID
    }

    // MARK: - Execution
    func execute() async -> MTLTexture? {
        guard let device = metalDevice,
              let commandQueue = commandQueue else { return nil }

        // Topologically sort nodes
        let sortedNodes = topologicalSort()

        // Execute each node in order
        for node in sortedNodes {
            // Gather inputs
            let inputs = gatherInputs(for: node)

            // Process node
            if let texture = await processNode(node, inputs: inputs, device: device, commandQueue: commandQueue) {
                textureCache[node.id] = texture
            }
        }

        // Find output nodes
        let outputNodes = nodes.filter { $0.type == .output }
        if let firstOutput = outputNodes.first {
            return textureCache[firstOutput.id]
        }

        return nil
    }

    private func topologicalSort() -> [VisualNode] {
        // Kahn's algorithm for topological sorting
        var sorted: [VisualNode] = []
        var inDegree: [UUID: Int] = [:]

        // Calculate in-degrees
        for node in nodes {
            inDegree[node.id] = 0
        }

        for connection in connections {
            inDegree[connection.to.nodeID, default: 0] += 1
        }

        // Queue nodes with no dependencies
        var queue: [VisualNode] = []
        for node in nodes {
            if inDegree[node.id] == 0 {
                queue.append(node)
            }
        }

        // Process queue
        while !queue.isEmpty {
            let node = queue.removeFirst()
            sorted.append(node)

            // Find outgoing connections
            let outgoing = connections.filter { $0.from.nodeID == node.id }

            for connection in outgoing {
                guard let toNode = getNode(connection.to.nodeID) else { continue }

                inDegree[toNode.id, default: 0] -= 1

                if inDegree[toNode.id] == 0 {
                    queue.append(toNode)
                }
            }
        }

        return sorted
    }

    private func gatherInputs(for node: VisualNode) -> [String: MTLTexture] {
        var inputs: [String: MTLTexture] = [:]

        for input in node.inputs {
            // Find connection to this input
            if let connection = connections.first(where: { $0.to == input.socket }) {
                // Get texture from source node
                if let texture = textureCache[connection.from.nodeID] {
                    inputs[input.socket.name] = texture
                }
            }
        }

        return inputs
    }

    private func processNode(
        _ node: VisualNode,
        inputs: [String: MTLTexture],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> MTLTexture? {
        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(resolution.width),
            height: Int(resolution.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        // Process based on node type
        switch node.type {
        case .audioInput:
            return await processAudioInput(node, output: outputTexture, device: device, commandQueue: commandQueue)

        case .generator:
            return await processGenerator(node, output: outputTexture, device: device, commandQueue: commandQueue)

        case .filter:
            return await processFilter(node, inputs: inputs, output: outputTexture, device: device, commandQueue: commandQueue)

        case .operator:
            return await processOperator(node, inputs: inputs, output: outputTexture, device: device, commandQueue: commandQueue)

        case .output:
            return inputs.first?.value  // Pass through

        default:
            return nil
        }
    }

    // MARK: - Node Processing
    private func processAudioInput(
        _ node: VisualNode,
        output: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> MTLTexture? {
        // In production, would read from audio engine
        // For now, return blank texture
        return output
    }

    private func processGenerator(
        _ node: VisualNode,
        output: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> MTLTexture? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        // Get generator type
        let generatorType = node.parameters["type"]?.stringValue ?? "noise"

        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        // Load appropriate shader
        let shaderName = "generator_\(generatorType)"
        if let shader = loadShader(named: shaderName, device: device) {
            computeEncoder.setComputePipelineState(shader)
            computeEncoder.setTexture(output, index: 0)

            // Set parameters
            setShaderParameters(computeEncoder, node: node)

            // Dispatch
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (output.width + 15) / 16,
                height: (output.height + 15) / 16,
                depth: 1
            )

            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        }

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    private func processFilter(
        _ node: VisualNode,
        inputs: [String: MTLTexture],
        output: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> MTLTexture? {
        guard let input = inputs["input"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        let filterType = node.parameters["type"]?.stringValue ?? "blur"
        let shaderName = "filter_\(filterType)"

        if let shader = loadShader(named: shaderName, device: device) {
            computeEncoder.setComputePipelineState(shader)
            computeEncoder.setTexture(input, index: 0)
            computeEncoder.setTexture(output, index: 1)

            setShaderParameters(computeEncoder, node: node)

            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (output.width + 15) / 16,
                height: (output.height + 15) / 16,
                depth: 1
            )

            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        }

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    private func processOperator(
        _ node: VisualNode,
        inputs: [String: MTLTexture],
        output: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> MTLTexture? {
        guard let input1 = inputs["input1"],
              let input2 = inputs["input2"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        let operatorType = node.parameters["type"]?.stringValue ?? "add"
        let shaderName = "operator_\(operatorType)"

        if let shader = loadShader(named: shaderName, device: device) {
            computeEncoder.setComputePipelineState(shader)
            computeEncoder.setTexture(input1, index: 0)
            computeEncoder.setTexture(input2, index: 1)
            computeEncoder.setTexture(output, index: 2)

            setShaderParameters(computeEncoder, node: node)

            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (output.width + 15) / 16,
                height: (output.height + 15) / 16,
                depth: 1
            )

            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        }

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    // MARK: - Shader Management
    private var shaderCache: [String: MTLComputePipelineState] = [:]

    private func loadShader(named name: String, device: MTLDevice) -> MTLComputePipelineState? {
        if let cached = shaderCache[name] {
            return cached
        }

        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: name) else {
            return nil
        }

        do {
            let pipeline = try device.makeComputePipelineState(function: function)
            shaderCache[name] = pipeline
            return pipeline
        } catch {
            print("Failed to create shader: \(error)")
            return nil
        }
    }

    private func setShaderParameters(_ encoder: MTLComputeCommandEncoder, node: VisualNode) {
        var paramIndex: Int = 3  // Start after textures

        for (_, param) in node.parameters {
            switch param {
            case .float(let value):
                var val = value
                encoder.setBytes(&val, length: MemoryLayout<Float>.size, index: paramIndex)

            case .vector2(let value):
                var val = value
                encoder.setBytes(&val, length: MemoryLayout<SIMD2<Float>>.size, index: paramIndex)

            case .vector3(let value):
                var val = value
                encoder.setBytes(&val, length: MemoryLayout<SIMD3<Float>>.size, index: paramIndex)

            case .vector4(let value):
                var val = value
                encoder.setBytes(&val, length: MemoryLayout<SIMD4<Float>>.size, index: paramIndex)

            case .int(let value):
                var val = value
                encoder.setBytes(&val, length: MemoryLayout<Int32>.size, index: paramIndex)

            default:
                break
            }

            paramIndex += 1
        }
    }

    // MARK: - Preset Management
    func savePreset(name: String, to url: URL) throws {
        let preset = NodeGraphPreset(
            name: name,
            nodes: nodes,
            connections: connections
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)
        try data.write(to: url)
    }

    func loadPreset(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let preset = try decoder.decode(NodeGraphPreset.self, from: data)

        nodes = preset.nodes
        connections = preset.connections
    }

    struct NodeGraphPreset: Codable {
        var name: String
        var nodes: [VisualNode]
        var connections: [NodeConnection]
    }
}

// MARK: - Visual Node
class VisualNode: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var type: NodeType
    @Published var position: CGPoint
    @Published var parameters: [String: NodeParameter]
    @Published var inputs: [NodeInput]
    @Published var outputs: [NodeOutput]

    enum NodeType: String, Codable {
        case audioInput      // FFT, Waveform, Beat Detection
        case generator       // Noise, Gradients, Shapes
        case filter          // Blur, Color, Distort
        case operator        // Math, Blend
        case output          // Screen, Recording
        case threeD          // 3D rendering
    }

    init(id: UUID = UUID(), name: String, type: NodeType, position: CGPoint = .zero) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.parameters = [:]
        self.inputs = []
        self.outputs = []

        setupDefaultSockets()
    }

    private func setupDefaultSockets() {
        switch type {
        case .audioInput:
            outputs.append(NodeOutput(socket: NodeSocket(
                nodeID: id, name: "FFT", dataType: .texture, direction: .output
            )))

        case .generator:
            outputs.append(NodeOutput(socket: NodeSocket(
                nodeID: id, name: "output", dataType: .texture, direction: .output
            )))

        case .filter:
            inputs.append(NodeInput(socket: NodeSocket(
                nodeID: id, name: "input", dataType: .texture, direction: .input
            )))
            outputs.append(NodeOutput(socket: NodeSocket(
                nodeID: id, name: "output", dataType: .texture, direction: .output
            )))

        case .operator:
            inputs.append(NodeInput(socket: NodeSocket(
                nodeID: id, name: "input1", dataType: .texture, direction: .input
            )))
            inputs.append(NodeInput(socket: NodeSocket(
                nodeID: id, name: "input2", dataType: .texture, direction: .input
            )))
            outputs.append(NodeOutput(socket: NodeSocket(
                nodeID: id, name: "output", dataType: .texture, direction: .output
            )))

        case .output:
            inputs.append(NodeInput(socket: NodeSocket(
                nodeID: id, name: "input", dataType: .texture, direction: .input
            )))

        case .threeD:
            outputs.append(NodeOutput(socket: NodeSocket(
                nodeID: id, name: "output", dataType: .texture, direction: .output
            )))
        }
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, type, position, parameters, inputs, outputs
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(NodeType.self, forKey: .type)

        let posArray = try container.decode([CGFloat].self, forKey: .position)
        position = CGPoint(x: posArray[0], y: posArray[1])

        parameters = try container.decode([String: NodeParameter].self, forKey: .parameters)
        inputs = try container.decode([NodeInput].self, forKey: .inputs)
        outputs = try container.decode([NodeOutput].self, forKey: .outputs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode([position.x, position.y], forKey: .position)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(outputs, forKey: .outputs)
    }
}

// MARK: - Node Socket
struct NodeSocket: Identifiable, Hashable, Codable {
    let id: UUID
    var nodeID: UUID
    var name: String
    var dataType: DataType
    var direction: Direction

    enum DataType: String, Codable {
        case texture, number, vector, color, audio
    }

    enum Direction: String, Codable {
        case input, output
    }

    init(id: UUID = UUID(), nodeID: UUID, name: String, dataType: DataType, direction: Direction) {
        self.id = id
        self.nodeID = nodeID
        self.name = name
        self.dataType = dataType
        self.direction = direction
    }
}

// MARK: - Node Input/Output
struct NodeInput: Identifiable, Codable {
    let id: UUID
    var socket: NodeSocket

    init(id: UUID = UUID(), socket: NodeSocket) {
        self.id = id
        self.socket = socket
    }
}

struct NodeOutput: Identifiable, Codable {
    let id: UUID
    var socket: NodeSocket

    init(id: UUID = UUID(), socket: NodeSocket) {
        self.id = id
        self.socket = socket
    }
}

// MARK: - Node Connection
struct NodeConnection: Identifiable, Hashable, Codable {
    let id: UUID
    var from: NodeSocket
    var to: NodeSocket

    init(id: UUID = UUID(), from: NodeSocket, to: NodeSocket) {
        self.id = id
        self.from = from
        self.to = to
    }
}

// MARK: - Node Parameter
enum NodeParameter: Codable, Hashable {
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case vector2(SIMD2<Float>)
    case vector3(SIMD3<Float>)
    case vector4(SIMD4<Float>)
    case color(SIMD4<Float>)

    var floatValue: Float? {
        if case .float(let val) = self { return val }
        return nil
    }

    var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }
}
