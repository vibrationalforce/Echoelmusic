import Foundation
import MetalKit
import Accelerate
import Combine

// MARK: - Node-Based Visual Programming Engine
// TouchDesigner/Notch-inspired visual programming system
//
// Operator Types (matching TouchDesigner conventions):
// - TOP (Texture Operators): Image/video processing
// - CHOP (Channel Operators): Audio/data/animation
// - SOP (Surface Operators): 3D geometry
// - MAT (Material Operators): Shaders/materials
// - COMP (Component Operators): UI/containers
// - DAT (Data Operators): Tables/text/scripts
//
// Competitive with: TouchDesigner, Notch, Resolume Wire, vvvv

// MARK: - Base Node Protocol

protocol VisualNode: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var nodeType: NodeType { get }
    var position: CGPoint { get set }
    var inputs: [NodeInput] { get }
    var outputs: [NodeOutput] { get }
    var parameters: [NodeParameter] { get set }
    var isEnabled: Bool { get set }
    var cookTime: TimeInterval { get }

    func cook() async throws
    func reset()
}

enum NodeType: String, CaseIterable, Codable {
    case top = "TOP"       // Texture Operator
    case chop = "CHOP"     // Channel Operator
    case sop = "SOP"       // Surface Operator
    case mat = "MAT"       // Material Operator
    case comp = "COMP"     // Component Operator
    case dat = "DAT"       // Data Operator
}

// MARK: - Node I/O

struct NodeInput: Identifiable {
    let id: UUID
    let name: String
    let dataType: NodeDataType
    var connectedOutput: NodeOutput?
    var isRequired: Bool

    init(name: String, dataType: NodeDataType, isRequired: Bool = false) {
        self.id = UUID()
        self.name = name
        self.dataType = dataType
        self.isRequired = isRequired
    }
}

struct NodeOutput: Identifiable {
    let id: UUID
    let name: String
    let dataType: NodeDataType
    weak var node: (any VisualNode)?

    init(name: String, dataType: NodeDataType) {
        self.id = UUID()
        self.name = name
        self.dataType = dataType
    }
}

enum NodeDataType: String, CaseIterable {
    case texture = "Texture"
    case channels = "Channels"
    case geometry = "Geometry"
    case material = "Material"
    case data = "Data"
    case any = "Any"
}

// MARK: - Node Parameters

struct NodeParameter: Identifiable, Codable {
    let id: UUID
    let name: String
    var value: ParameterValue
    let valueType: ParameterType
    let range: ClosedRange<Double>?
    let options: [String]?

    enum ParameterType: String, Codable {
        case float, int, bool, string, color, vector2, vector3, menu, file
    }

    enum ParameterValue: Codable, Equatable {
        case float(Double)
        case int(Int)
        case bool(Bool)
        case string(String)
        case color(r: Double, g: Double, b: Double, a: Double)
        case vector2(x: Double, y: Double)
        case vector3(x: Double, y: Double, z: Double)
    }

    init(name: String, value: ParameterValue, type: ParameterType, range: ClosedRange<Double>? = nil, options: [String]? = nil) {
        self.id = UUID()
        self.name = name
        self.value = value
        self.valueType = type
        self.range = range
        self.options = options
    }
}

// MARK: - TOP (Texture Operators)

/// Base class for all texture operations
class TOPNode: VisualNode, ObservableObject {
    let id = UUID()
    @Published var name: String
    let nodeType: NodeType = .top
    @Published var position: CGPoint = .zero
    @Published var inputs: [NodeInput] = []
    @Published var outputs: [NodeOutput] = []
    @Published var parameters: [NodeParameter] = []
    @Published var isEnabled: Bool = true
    @Published private(set) var cookTime: TimeInterval = 0

    // Texture output
    var outputTexture: MTLTexture?
    var resolution: (width: Int, height: Int) = (1920, 1080)

    init(name: String) {
        self.name = name
        self.outputs = [NodeOutput(name: "out", dataType: .texture)]
    }

    func cook() async throws {
        let start = CFAbsoluteTimeGetCurrent()
        // Override in subclasses
        cookTime = CFAbsoluteTimeGetCurrent() - start
    }

    func reset() {
        outputTexture = nil
    }
}

// Noise Generator TOP
class NoiseTOP: TOPNode {
    enum NoiseType: String, CaseIterable {
        case perlin = "Perlin"
        case simplex = "Simplex"
        case voronoi = "Voronoi"
        case cellular = "Cellular"
        case fbm = "FBM"
        case turbulence = "Turbulence"
    }

    init() {
        super.init(name: "Noise")
        parameters = [
            NodeParameter(name: "Type", value: .string("Perlin"), type: .menu, options: NoiseType.allCases.map { $0.rawValue }),
            NodeParameter(name: "Scale", value: .float(1.0), type: .float, range: 0.01...100.0),
            NodeParameter(name: "Octaves", value: .int(4), type: .int, range: 1...8),
            NodeParameter(name: "Persistence", value: .float(0.5), type: .float, range: 0...1),
            NodeParameter(name: "Seed", value: .int(0), type: .int),
            NodeParameter(name: "Animate", value: .bool(true), type: .bool),
            NodeParameter(name: "Speed", value: .float(1.0), type: .float, range: 0...10)
        ]
    }
}

// Movie File In TOP
class MovieFileInTOP: TOPNode {
    init() {
        super.init(name: "Movie File In")
        parameters = [
            NodeParameter(name: "File", value: .string(""), type: .file),
            NodeParameter(name: "Play", value: .bool(true), type: .bool),
            NodeParameter(name: "Loop", value: .bool(true), type: .bool),
            NodeParameter(name: "Speed", value: .float(1.0), type: .float, range: -4...4),
            NodeParameter(name: "Index", value: .float(0.0), type: .float, range: 0...1),
            NodeParameter(name: "Cue", value: .bool(false), type: .bool)
        ]
    }
}

// NDI In TOP (Network Device Interface)
class NDIInTOP: TOPNode {
    init() {
        super.init(name: "NDI In")
        parameters = [
            NodeParameter(name: "Source", value: .string(""), type: .menu, options: []),
            NodeParameter(name: "Bandwidth", value: .string("Highest"), type: .menu, options: ["Highest", "Lowest", "Audio Only"]),
            NodeParameter(name: "Deinterlace", value: .bool(false), type: .bool)
        ]
    }
}

// Composite TOP (layer blending)
class CompositeTOP: TOPNode {
    enum BlendMode: String, CaseIterable {
        case over = "Over"
        case add = "Add"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case softLight = "Soft Light"
        case hardLight = "Hard Light"
        case difference = "Difference"
        case exclusion = "Exclusion"
    }

    init() {
        super.init(name: "Composite")
        inputs = [
            NodeInput(name: "input1", dataType: .texture, isRequired: true),
            NodeInput(name: "input2", dataType: .texture, isRequired: true)
        ]
        parameters = [
            NodeParameter(name: "Mode", value: .string("Over"), type: .menu, options: BlendMode.allCases.map { $0.rawValue }),
            NodeParameter(name: "Opacity", value: .float(1.0), type: .float, range: 0...1)
        ]
    }
}

// Feedback TOP (infinite zoom, trails)
class FeedbackTOP: TOPNode {
    init() {
        super.init(name: "Feedback")
        inputs = [NodeInput(name: "input", dataType: .texture, isRequired: true)]
        parameters = [
            NodeParameter(name: "Opacity", value: .float(0.9), type: .float, range: 0...1),
            NodeParameter(name: "Scale", value: .float(1.01), type: .float, range: 0.9...1.1),
            NodeParameter(name: "Rotate", value: .float(0.0), type: .float, range: -180...180),
            NodeParameter(name: "Translate", value: .vector2(x: 0, y: 0), type: .vector2)
        ]
    }
}

// GLSL TOP (custom shaders)
class GLSLTOP: TOPNode {
    init() {
        super.init(name: "GLSL")
        inputs = [
            NodeInput(name: "input0", dataType: .texture),
            NodeInput(name: "input1", dataType: .texture),
            NodeInput(name: "input2", dataType: .texture),
            NodeInput(name: "input3", dataType: .texture)
        ]
        parameters = [
            NodeParameter(name: "Pixel Shader", value: .string(defaultFragmentShader), type: .string),
            NodeParameter(name: "Vertex Shader", value: .string(defaultVertexShader), type: .string)
        ]
    }

    private let defaultFragmentShader = """
    #version 450
    layout(location = 0) in vec2 uv;
    layout(location = 0) out vec4 fragColor;

    uniform sampler2D sTD2DInputs[4];
    uniform float uTime;
    uniform vec2 uResolution;

    void main() {
        vec4 color = texture(sTD2DInputs[0], uv);
        fragColor = color;
    }
    """

    private let defaultVertexShader = """
    #version 450
    layout(location = 0) in vec3 position;
    layout(location = 1) in vec2 texcoord;
    layout(location = 0) out vec2 uv;

    void main() {
        uv = texcoord;
        gl_Position = vec4(position, 1.0);
    }
    """
}

// MARK: - CHOP (Channel Operators)

/// Base class for channel/data operations
class CHOPNode: VisualNode, ObservableObject {
    let id = UUID()
    @Published var name: String
    let nodeType: NodeType = .chop
    @Published var position: CGPoint = .zero
    @Published var inputs: [NodeInput] = []
    @Published var outputs: [NodeOutput] = []
    @Published var parameters: [NodeParameter] = []
    @Published var isEnabled: Bool = true
    @Published private(set) var cookTime: TimeInterval = 0

    // Channel data
    var channels: [[Float]] = []
    var channelNames: [String] = []
    var sampleRate: Double = 60.0

    init(name: String) {
        self.name = name
        self.outputs = [NodeOutput(name: "out", dataType: .channels)]
    }

    func cook() async throws {
        let start = CFAbsoluteTimeGetCurrent()
        // Override in subclasses
        cookTime = CFAbsoluteTimeGetCurrent() - start
    }

    func reset() {
        channels.removeAll()
    }
}

// Audio Device In CHOP
class AudioDeviceInCHOP: CHOPNode {
    init() {
        super.init(name: "Audio Device In")
        parameters = [
            NodeParameter(name: "Device", value: .string("Default"), type: .menu, options: ["Default"]),
            NodeParameter(name: "Channels", value: .int(2), type: .int, range: 1...32),
            NodeParameter(name: "Sample Rate", value: .int(48000), type: .menu, options: ["44100", "48000", "96000"]),
            NodeParameter(name: "Buffer Size", value: .int(512), type: .menu, options: ["128", "256", "512", "1024", "2048"])
        ]
    }
}

// Audio Spectrum CHOP (FFT analysis)
class AudioSpectrumCHOP: CHOPNode {
    init() {
        super.init(name: "Audio Spectrum")
        inputs = [NodeInput(name: "audio", dataType: .channels, isRequired: true)]
        parameters = [
            NodeParameter(name: "FFT Size", value: .int(1024), type: .menu, options: ["256", "512", "1024", "2048", "4096"]),
            NodeParameter(name: "Window", value: .string("Hanning"), type: .menu, options: ["Rectangle", "Hanning", "Hamming", "Blackman"]),
            NodeParameter(name: "Bands", value: .int(32), type: .int, range: 8...256),
            NodeParameter(name: "Log Scale", value: .bool(true), type: .bool)
        ]
    }
}

// LFO CHOP (oscillators)
class LFOCHOP: CHOPNode {
    enum Waveform: String, CaseIterable {
        case sine, triangle, square, sawtooth, noise
    }

    init() {
        super.init(name: "LFO")
        parameters = [
            NodeParameter(name: "Waveform", value: .string("sine"), type: .menu, options: Waveform.allCases.map { $0.rawValue }),
            NodeParameter(name: "Frequency", value: .float(1.0), type: .float, range: 0.001...100),
            NodeParameter(name: "Amplitude", value: .float(1.0), type: .float, range: 0...10),
            NodeParameter(name: "Offset", value: .float(0.0), type: .float, range: -10...10),
            NodeParameter(name: "Phase", value: .float(0.0), type: .float, range: 0...1)
        ]
    }
}

// OSC In CHOP (receive OSC data)
class OSCInCHOP: CHOPNode {
    init() {
        super.init(name: "OSC In")
        parameters = [
            NodeParameter(name: "Port", value: .int(7000), type: .int, range: 1024...65535),
            NodeParameter(name: "Address Pattern", value: .string("/*"), type: .string)
        ]
    }
}

// MIDI In CHOP
class MIDIInCHOP: CHOPNode {
    init() {
        super.init(name: "MIDI In")
        parameters = [
            NodeParameter(name: "Device", value: .string("All"), type: .menu, options: ["All"]),
            NodeParameter(name: "Channel", value: .int(0), type: .int, range: 0...16), // 0 = all
            NodeParameter(name: "Note On", value: .bool(true), type: .bool),
            NodeParameter(name: "Note Off", value: .bool(true), type: .bool),
            NodeParameter(name: "Control Change", value: .bool(true), type: .bool)
        ]
    }
}

// Bio-Reactive CHOP (Echoelmusic unique!)
class BioReactiveCHOP: CHOPNode {
    init() {
        super.init(name: "Bio Reactive")
        parameters = [
            NodeParameter(name: "Source", value: .string("HealthKit"), type: .menu, options: ["HealthKit", "Apple Watch", "External HRV"]),
            NodeParameter(name: "Heart Rate", value: .bool(true), type: .bool),
            NodeParameter(name: "HRV (RMSSD)", value: .bool(true), type: .bool),
            NodeParameter(name: "Coherence", value: .bool(true), type: .bool),
            NodeParameter(name: "Stress Index", value: .bool(true), type: .bool),
            NodeParameter(name: "Smoothing", value: .float(0.5), type: .float, range: 0...1)
        ]
    }
}

// MARK: - SOP (Surface Operators)

/// Base class for 3D geometry operations
class SOPNode: VisualNode, ObservableObject {
    let id = UUID()
    @Published var name: String
    let nodeType: NodeType = .sop
    @Published var position: CGPoint = .zero
    @Published var inputs: [NodeInput] = []
    @Published var outputs: [NodeOutput] = []
    @Published var parameters: [NodeParameter] = []
    @Published var isEnabled: Bool = true
    @Published private(set) var cookTime: TimeInterval = 0

    // Geometry data
    var vertices: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    init(name: String) {
        self.name = name
        self.outputs = [NodeOutput(name: "out", dataType: .geometry)]
    }

    func cook() async throws {
        let start = CFAbsoluteTimeGetCurrent()
        cookTime = CFAbsoluteTimeGetCurrent() - start
    }

    func reset() {
        vertices.removeAll()
        normals.removeAll()
        uvs.removeAll()
        indices.removeAll()
    }
}

// Sphere SOP
class SphereSOP: SOPNode {
    init() {
        super.init(name: "Sphere")
        parameters = [
            NodeParameter(name: "Radius", value: .float(1.0), type: .float, range: 0.001...100),
            NodeParameter(name: "Rows", value: .int(32), type: .int, range: 3...256),
            NodeParameter(name: "Columns", value: .int(32), type: .int, range: 3...256),
            NodeParameter(name: "Center", value: .vector3(x: 0, y: 0, z: 0), type: .vector3)
        ]
    }
}

// Box SOP
class BoxSOP: SOPNode {
    init() {
        super.init(name: "Box")
        parameters = [
            NodeParameter(name: "Size", value: .vector3(x: 1, y: 1, z: 1), type: .vector3),
            NodeParameter(name: "Center", value: .vector3(x: 0, y: 0, z: 0), type: .vector3),
            NodeParameter(name: "Divisions X", value: .int(1), type: .int, range: 1...100),
            NodeParameter(name: "Divisions Y", value: .int(1), type: .int, range: 1...100),
            NodeParameter(name: "Divisions Z", value: .int(1), type: .int, range: 1...100)
        ]
    }
}

// Particle SOP
class ParticleSOP: SOPNode {
    init() {
        super.init(name: "Particle")
        inputs = [NodeInput(name: "source", dataType: .geometry)]
        parameters = [
            NodeParameter(name: "Birth Rate", value: .float(100.0), type: .float, range: 0...10000),
            NodeParameter(name: "Life", value: .float(2.0), type: .float, range: 0.01...100),
            NodeParameter(name: "Life Variance", value: .float(0.5), type: .float, range: 0...1),
            NodeParameter(name: "Initial Velocity", value: .vector3(x: 0, y: 1, z: 0), type: .vector3),
            NodeParameter(name: "Gravity", value: .vector3(x: 0, y: -9.8, z: 0), type: .vector3),
            NodeParameter(name: "Wind", value: .vector3(x: 0, y: 0, z: 0), type: .vector3),
            NodeParameter(name: "Turbulence", value: .float(0.0), type: .float, range: 0...10)
        ]
    }
}

// MARK: - Node Graph Manager

/// Manages the complete node network
@MainActor
class NodeGraphManager: ObservableObject {

    @Published var nodes: [any VisualNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var selectedNodes: Set<UUID> = []
    @Published var isRunning: Bool = false

    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFAbsoluteTime = 0
    @Published var fps: Double = 0
    @Published var totalCookTime: TimeInterval = 0

    struct NodeConnection: Identifiable {
        let id = UUID()
        let sourceNodeId: UUID
        let sourceOutputId: UUID
        let destinationNodeId: UUID
        let destinationInputId: UUID
    }

    // MARK: - Node Management

    func addNode(_ node: any VisualNode) {
        nodes.append(node)
    }

    func removeNode(_ id: UUID) {
        nodes.removeAll { $0.id == id }
        connections.removeAll { $0.sourceNodeId == id || $0.destinationNodeId == id }
    }

    func connect(sourceNode: UUID, outputId: UUID, destNode: UUID, inputId: UUID) -> Bool {
        // Validate connection
        guard let source = nodes.first(where: { $0.id == sourceNode }),
              let dest = nodes.first(where: { $0.id == destNode }),
              let output = source.outputs.first(where: { $0.id == outputId }),
              let input = dest.inputs.first(where: { $0.id == inputId }) else {
            return false
        }

        // Check type compatibility
        guard output.dataType == input.dataType || input.dataType == .any else {
            return false
        }

        // Remove existing connection to this input
        connections.removeAll { $0.destinationInputId == inputId }

        // Add new connection
        let connection = NodeConnection(
            sourceNodeId: sourceNode,
            sourceOutputId: outputId,
            destinationNodeId: destNode,
            destinationInputId: inputId
        )
        connections.append(connection)

        return true
    }

    func disconnect(inputId: UUID) {
        connections.removeAll { $0.destinationInputId == inputId }
    }

    // MARK: - Execution

    func start() {
        isRunning = true
        lastFrameTime = CFAbsoluteTimeGetCurrent()

        // Run cook loop
        Task {
            while isRunning {
                await cookGraph()
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60 FPS
            }
        }
    }

    func stop() {
        isRunning = false
    }

    private func cookGraph() async {
        let frameStart = CFAbsoluteTimeGetCurrent()

        // Topological sort for correct execution order
        let sortedNodes = topologicalSort()

        // Cook each node
        for node in sortedNodes {
            if node.isEnabled {
                try? await node.cook()
            }
        }

        totalCookTime = CFAbsoluteTimeGetCurrent() - frameStart
        fps = 1.0 / (CFAbsoluteTimeGetCurrent() - lastFrameTime)
        lastFrameTime = CFAbsoluteTimeGetCurrent()
    }

    private func topologicalSort() -> [any VisualNode] {
        var visited = Set<UUID>()
        var result: [any VisualNode] = []

        func visit(_ node: any VisualNode) {
            guard !visited.contains(node.id) else { return }
            visited.insert(node.id)

            // Visit all inputs first
            for input in node.inputs {
                if let connection = connections.first(where: { $0.destinationInputId == input.id }),
                   let sourceNode = nodes.first(where: { $0.id == connection.sourceNodeId }) {
                    visit(sourceNode)
                }
            }

            result.append(node)
        }

        for node in nodes {
            visit(node)
        }

        return result
    }

    // MARK: - Presets

    func savePreset() -> NodeGraphPreset {
        // Serialize entire graph
        return NodeGraphPreset(
            name: "Untitled",
            nodes: nodes.map { NodeSnapshot(node: $0) },
            connections: connections
        )
    }

    func loadPreset(_ preset: NodeGraphPreset) {
        // Clear and rebuild
        nodes.removeAll()
        connections = preset.connections

        for snapshot in preset.nodes {
            if let node = createNode(type: snapshot.nodeClass, name: snapshot.name) {
                node.position = snapshot.position
                node.parameters = snapshot.parameters
                nodes.append(node)
            }
        }
    }

    private func createNode(type: String, name: String) -> (any VisualNode)? {
        switch type {
        case "NoiseTOP": return NoiseTOP()
        case "MovieFileInTOP": return MovieFileInTOP()
        case "NDIInTOP": return NDIInTOP()
        case "CompositeTOP": return CompositeTOP()
        case "FeedbackTOP": return FeedbackTOP()
        case "GLSLTOP": return GLSLTOP()
        case "AudioDeviceInCHOP": return AudioDeviceInCHOP()
        case "AudioSpectrumCHOP": return AudioSpectrumCHOP()
        case "LFOCHOP": return LFOCHOP()
        case "OSCInCHOP": return OSCInCHOP()
        case "MIDIInCHOP": return MIDIInCHOP()
        case "BioReactiveCHOP": return BioReactiveCHOP()
        case "SphereSOP": return SphereSOP()
        case "BoxSOP": return BoxSOP()
        case "ParticleSOP": return ParticleSOP()
        default: return nil
        }
    }
}

struct NodeSnapshot: Codable {
    let id: UUID
    let name: String
    let nodeClass: String
    let position: CGPoint
    let parameters: [NodeParameter]

    init(node: any VisualNode) {
        self.id = node.id
        self.name = node.name
        self.nodeClass = String(describing: type(of: node))
        self.position = node.position
        self.parameters = node.parameters
    }
}

struct NodeGraphPreset: Codable {
    let name: String
    let nodes: [NodeSnapshot]
    let connections: [NodeGraphManager.NodeConnection]
}

extension NodeGraphManager.NodeConnection: Codable {}
extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey { case x, y }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x), y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
}
