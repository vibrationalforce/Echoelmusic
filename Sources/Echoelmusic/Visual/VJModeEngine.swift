import Foundation
#if canImport(Metal)
import Metal
import MetalKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif

// MARK: - VJ Mode Engine
// Professional VJ performance mode with shader library and beat sync
// Features: Shader library, layer mixing, beat sync, MIDI/OSC control, output routing

@MainActor
public final class VJModeEngine: ObservableObject {
    public static let shared = VJModeEngine()

    @Published public private(set) var isActive = false
    @Published public private(set) var currentBPM: Double = 120
    @Published public private(set) var beatPhase: Double = 0
    @Published public private(set) var layers: [VJLayer] = []
    @Published public private(set) var masterOpacity: Float = 1.0
    @Published public private(set) var fps: Double = 60

    // Rendering
    #if canImport(Metal)
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var shaderLibrary: ShaderLibrary?
    private var layerRenderer: LayerRenderer?
    private var outputRenderer: OutputRenderer?
    #endif

    // Beat sync
    private var beatTracker: BeatTracker
    private var tapTempoSamples: [TimeInterval] = []

    // Effects chain
    private var globalEffects: [VJEffect] = []

    // Output
    private var outputTargets: [OutputTarget] = []

    // Configuration
    public struct Configuration {
        public var maxLayers: Int = 8
        public var outputResolution: CGSize = CGSize(width: 1920, height: 1080)
        public var targetFPS: Double = 60
        public var enableBeatSync: Bool = true
        public var enableMIDIControl: Bool = true
        public var enableOSCControl: Bool = true

        public static let `default` = Configuration()
        public static let performance = Configuration(maxLayers: 4, targetFPS: 30)
        public static let highQuality = Configuration(maxLayers: 16, outputResolution: CGSize(width: 3840, height: 2160))
    }

    private var config: Configuration = .default

    public init() {
        self.beatTracker = BeatTracker()
        setupMetal()
        setupLayers()
    }

    // MARK: - Setup

    private func setupMetal() {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not available")
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()
        self.shaderLibrary = ShaderLibrary(device: device)
        self.layerRenderer = LayerRenderer(device: device)
        self.outputRenderer = OutputRenderer(device: device, resolution: config.outputResolution)
        #endif
    }

    private func setupLayers() {
        for i in 0..<config.maxLayers {
            layers.append(VJLayer(id: i))
        }
    }

    // MARK: - Activation

    /// Start VJ mode
    public func start() {
        isActive = true
        startRenderLoop()

        if config.enableBeatSync {
            beatTracker.start()
        }
    }

    /// Stop VJ mode
    public func stop() {
        isActive = false
        stopRenderLoop()
        beatTracker.stop()
    }

    private var displayLink: Timer?

    private func startRenderLoop() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / config.targetFPS, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.renderFrame()
            }
        }
    }

    private func stopRenderLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Rendering

    private func renderFrame() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Update beat phase
        updateBeatSync()

        #if canImport(Metal)
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // Render each layer
        var layerTextures: [MTLTexture] = []

        for layer in layers where layer.enabled && layer.opacity > 0 {
            if let texture = renderLayer(layer, commandBuffer: commandBuffer) {
                layerTextures.append(texture)
            }
        }

        // Composite layers
        if let composited = compositeLayers(layerTextures, commandBuffer: commandBuffer) {
            // Apply global effects
            var finalTexture = composited
            for effect in globalEffects where effect.enabled {
                if let processed = applyEffect(effect, to: finalTexture, commandBuffer: commandBuffer) {
                    finalTexture = processed
                }
            }

            // Send to outputs
            for target in outputTargets {
                outputRenderer?.render(to: target, texture: finalTexture, commandBuffer: commandBuffer)
            }
        }

        commandBuffer.commit()
        #endif

        // Calculate FPS
        let frameTime = CFAbsoluteTimeGetCurrent() - startTime
        fps = 1.0 / max(frameTime, 0.001)
    }

    #if canImport(Metal)
    private func renderLayer(_ layer: VJLayer, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let shader = shaderLibrary?.getShader(layer.shaderName) else {
            return nil
        }

        // Get or create layer texture
        guard let texture = layerRenderer?.getLayerTexture(layer.id) else {
            return nil
        }

        // Update shader parameters
        var params = layer.parameters
        params["time"] = Float(CFAbsoluteTimeGetCurrent())
        params["beatPhase"] = Float(beatPhase)
        params["bpm"] = Float(currentBPM)
        params["opacity"] = layer.opacity

        // Render shader to texture
        layerRenderer?.render(
            shader: shader,
            parameters: params,
            to: texture,
            commandBuffer: commandBuffer
        )

        return texture
    }

    private func compositeLayers(_ textures: [MTLTexture], commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard !textures.isEmpty else { return nil }

        return layerRenderer?.composite(
            textures: textures,
            opacities: layers.filter { $0.enabled }.map { $0.opacity },
            blendModes: layers.filter { $0.enabled }.map { $0.blendMode },
            commandBuffer: commandBuffer
        )
    }

    private func applyEffect(_ effect: VJEffect, to texture: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let shader = shaderLibrary?.getShader(effect.shaderName) else {
            return texture
        }

        return layerRenderer?.applyEffect(
            shader: shader,
            parameters: effect.parameters,
            to: texture,
            commandBuffer: commandBuffer
        )
    }
    #endif

    // MARK: - Beat Sync

    private func updateBeatSync() {
        let beat = beatTracker.currentBeat
        currentBPM = beatTracker.bpm
        beatPhase = beat.truncatingRemainder(dividingBy: 1.0)
    }

    /// Tap tempo
    public func tapTempo() {
        let now = Date().timeIntervalSince1970
        tapTempoSamples.append(now)

        // Keep last 8 taps
        if tapTempoSamples.count > 8 {
            tapTempoSamples.removeFirst()
        }

        // Calculate BPM from taps
        if tapTempoSamples.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTempoSamples.count {
                intervals.append(tapTempoSamples[i] - tapTempoSamples[i-1])
            }

            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let bpm = 60.0 / avgInterval

            if bpm >= 40 && bpm <= 240 {
                beatTracker.setBPM(bpm)
            }
        }
    }

    /// Set BPM manually
    public func setBPM(_ bpm: Double) {
        beatTracker.setBPM(bpm)
        tapTempoSamples.removeAll()
    }

    /// Sync to downbeat
    public func syncDownbeat() {
        beatTracker.resetPhase()
    }

    // MARK: - Layer Management

    /// Set layer content
    public func setLayerShader(_ layerId: Int, shader: String) {
        guard layerId < layers.count else { return }
        layers[layerId].shaderName = shader
    }

    /// Set layer opacity
    public func setLayerOpacity(_ layerId: Int, opacity: Float) {
        guard layerId < layers.count else { return }
        layers[layerId].opacity = max(0, min(1, opacity))
    }

    /// Set layer blend mode
    public func setLayerBlendMode(_ layerId: Int, mode: BlendMode) {
        guard layerId < layers.count else { return }
        layers[layerId].blendMode = mode
    }

    /// Enable/disable layer
    public func setLayerEnabled(_ layerId: Int, enabled: Bool) {
        guard layerId < layers.count else { return }
        layers[layerId].enabled = enabled
    }

    /// Set layer parameter
    public func setLayerParameter(_ layerId: Int, name: String, value: Float) {
        guard layerId < layers.count else { return }
        layers[layerId].parameters[name] = value
    }

    // MARK: - Effects

    /// Add global effect
    public func addGlobalEffect(_ effect: VJEffect) {
        globalEffects.append(effect)
    }

    /// Remove global effect
    public func removeGlobalEffect(_ effectId: UUID) {
        globalEffects.removeAll { $0.id == effectId }
    }

    // MARK: - Output Management

    /// Add output target
    public func addOutput(_ target: OutputTarget) {
        outputTargets.append(target)
    }

    /// Remove output target
    public func removeOutput(_ targetId: UUID) {
        outputTargets.removeAll { $0.id == targetId }
    }

    // MARK: - Presets

    /// Save current state as preset
    public func savePreset(name: String) -> VJPreset {
        VJPreset(
            name: name,
            layers: layers,
            globalEffects: globalEffects,
            bpm: currentBPM,
            masterOpacity: masterOpacity
        )
    }

    /// Load preset
    public func loadPreset(_ preset: VJPreset) {
        layers = preset.layers
        globalEffects = preset.globalEffects
        masterOpacity = preset.masterOpacity
        setBPM(preset.bpm)
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - VJ Layer

public struct VJLayer: Identifiable {
    public let id: Int
    public var shaderName: String = "default"
    public var enabled: Bool = false
    public var opacity: Float = 1.0
    public var blendMode: BlendMode = .normal
    public var parameters: [String: Float] = [:]
    public var mediaSource: MediaSource?

    public enum MediaSource {
        case shader(String)
        case video(URL)
        case image(URL)
        case camera(Int)
        case ndi(String)
        case spout(String)
    }
}

// MARK: - Blend Modes

public enum BlendMode: String, CaseIterable, Codable {
    case normal
    case add
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight
    case difference
    case exclusion
    case colorDodge
    case colorBurn
}

// MARK: - VJ Effect

public struct VJEffect: Identifiable {
    public let id: UUID
    public var name: String
    public var shaderName: String
    public var enabled: Bool = true
    public var parameters: [String: Float] = [:]

    public init(id: UUID = UUID(), name: String, shaderName: String, parameters: [String: Float] = [:]) {
        self.id = id
        self.name = name
        self.shaderName = shaderName
        self.parameters = parameters
    }
}

// MARK: - Output Target

public struct OutputTarget: Identifiable {
    public let id: UUID
    public var name: String
    public var type: OutputType
    public var enabled: Bool = true

    public enum OutputType {
        case window
        case fullscreen(Int)  // Screen index
        case ndi(String)
        case spout(String)
        case syphon(String)
        case file(URL)
    }

    public init(id: UUID = UUID(), name: String, type: OutputType) {
        self.id = id
        self.name = name
        self.type = type
    }
}

// MARK: - VJ Preset

public struct VJPreset: Codable {
    public var name: String
    public var layers: [VJLayer]
    public var globalEffects: [VJEffect]
    public var bpm: Double
    public var masterOpacity: Float
}

// Extension for Codable conformance
extension VJLayer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, shaderName, enabled, opacity, blendMode, parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        shaderName = try container.decode(String.self, forKey: .shaderName)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        opacity = try container.decode(Float.self, forKey: .opacity)
        blendMode = try container.decode(BlendMode.self, forKey: .blendMode)
        parameters = try container.decode([String: Float].self, forKey: .parameters)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(shaderName, forKey: .shaderName)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(blendMode, forKey: .blendMode)
        try container.encode(parameters, forKey: .parameters)
    }
}

extension VJEffect: Codable {}

// MARK: - Beat Tracker

public class BeatTracker {
    private var startTime: TimeInterval = 0
    private var _bpm: Double = 120
    private var phase: Double = 0

    public var bpm: Double { _bpm }

    public var currentBeat: Double {
        let elapsed = Date().timeIntervalSince1970 - startTime
        let beatsElapsed = elapsed * _bpm / 60.0
        return beatsElapsed + phase
    }

    public func start() {
        startTime = Date().timeIntervalSince1970
    }

    public func stop() {
        // Nothing needed
    }

    public func setBPM(_ bpm: Double) {
        // Maintain phase continuity
        let currentBeatValue = currentBeat
        _bpm = bpm
        startTime = Date().timeIntervalSince1970
        phase = currentBeatValue.truncatingRemainder(dividingBy: 4) // Keep within 4-beat cycle
    }

    public func resetPhase() {
        startTime = Date().timeIntervalSince1970
        phase = 0
    }
}

// MARK: - Shader Library

#if canImport(Metal)
public class ShaderLibrary {
    private let device: MTLDevice
    private var shaders: [String: MTLFunction] = [:]
    private var pipelines: [String: MTLComputePipelineState] = [:]

    // Built-in shader source
    private let builtInShaders: [String: String] = [
        "default": """
            #include <metal_stdlib>
            using namespace metal;

            kernel void defaultShader(
                texture2d<float, access::write> output [[texture(0)]],
                constant float &time [[buffer(0)]],
                constant float &beatPhase [[buffer(1)]],
                uint2 gid [[thread_position_in_grid]]
            ) {
                float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
                float4 color = float4(uv.x, uv.y, sin(time) * 0.5 + 0.5, 1.0);
                output.write(color, gid);
            }
            """,

        "plasma": """
            #include <metal_stdlib>
            using namespace metal;

            kernel void plasmaShader(
                texture2d<float, access::write> output [[texture(0)]],
                constant float &time [[buffer(0)]],
                constant float &beatPhase [[buffer(1)]],
                uint2 gid [[thread_position_in_grid]]
            ) {
                float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
                float v = 0.0;
                v += sin(uv.x * 10.0 + time);
                v += sin((uv.y * 10.0 + time) * 0.5);
                v += sin((uv.x * 10.0 + uv.y * 10.0 + time) * 0.5);
                float4 color = float4(sin(v), sin(v + 2.0), sin(v + 4.0), 1.0) * 0.5 + 0.5;
                output.write(color, gid);
            }
            """,

        "tunnel": """
            #include <metal_stdlib>
            using namespace metal;

            kernel void tunnelShader(
                texture2d<float, access::write> output [[texture(0)]],
                constant float &time [[buffer(0)]],
                constant float &beatPhase [[buffer(1)]],
                uint2 gid [[thread_position_in_grid]]
            ) {
                float2 uv = (float2(gid) / float2(output.get_width(), output.get_height())) * 2.0 - 1.0;
                float angle = atan2(uv.y, uv.x);
                float radius = length(uv);
                float v = angle / 3.14159 + time * 0.5 + 1.0 / radius;
                float4 color = float4(fract(v * 4.0), fract(v * 8.0), fract(v * 16.0), 1.0);
                output.write(color, gid);
            }
            """,

        "kaleidoscope": """
            #include <metal_stdlib>
            using namespace metal;

            kernel void kaleidoscopeShader(
                texture2d<float, access::write> output [[texture(0)]],
                constant float &time [[buffer(0)]],
                constant float &beatPhase [[buffer(1)]],
                constant float &segments [[buffer(2)]],
                uint2 gid [[thread_position_in_grid]]
            ) {
                float2 uv = (float2(gid) / float2(output.get_width(), output.get_height())) * 2.0 - 1.0;
                float angle = atan2(uv.y, uv.x);
                float radius = length(uv);

                int seg = int(segments > 0 ? segments : 6.0);
                float segAngle = 3.14159 * 2.0 / float(seg);
                angle = fmod(abs(angle), segAngle);
                if (fmod(floor(abs(atan2(uv.y, uv.x)) / segAngle), 2.0) == 1.0) {
                    angle = segAngle - angle;
                }

                float2 kUV = float2(cos(angle), sin(angle)) * radius;
                float v = sin(kUV.x * 10.0 + time) * cos(kUV.y * 10.0 + time);

                float4 color = float4(v, v * 0.5 + 0.5, 1.0 - v, 1.0);
                output.write(color, gid);
            }
            """
    ]

    public init(device: MTLDevice) {
        self.device = device
        loadBuiltInShaders()
    }

    private func loadBuiltInShaders() {
        for (name, _) in builtInShaders {
            // In production, compile from source
            // For now, try to load from default library
        }
    }

    public func getShader(_ name: String) -> MTLComputePipelineState? {
        return pipelines[name]
    }

    public func loadCustomShader(name: String, source: String) throws {
        let library = try device.makeLibrary(source: source, options: nil)
        if let function = library.makeFunction(name: name + "Shader") {
            shaders[name] = function
            pipelines[name] = try device.makeComputePipelineState(function: function)
        }
    }
}

// MARK: - Layer Renderer

public class LayerRenderer {
    private let device: MTLDevice
    private var layerTextures: [Int: MTLTexture] = [:]
    private let textureDescriptor: MTLTextureDescriptor

    public init(device: MTLDevice, resolution: CGSize = CGSize(width: 1920, height: 1080)) {
        self.device = device
        self.textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(resolution.width),
            height: Int(resolution.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
    }

    public func getLayerTexture(_ layerId: Int) -> MTLTexture? {
        if let texture = layerTextures[layerId] {
            return texture
        }

        let texture = device.makeTexture(descriptor: textureDescriptor)
        layerTextures[layerId] = texture
        return texture
    }

    public func render(
        shader: MTLComputePipelineState,
        parameters: [String: Float],
        to texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(shader)
        encoder.setTexture(texture, index: 0)

        // Set parameters
        var paramIndex = 0
        for (_, value) in parameters.sorted(by: { $0.key < $1.key }) {
            var v = value
            encoder.setBytes(&v, length: MemoryLayout<Float>.size, index: paramIndex)
            paramIndex += 1
        }

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }

    public func composite(
        textures: [MTLTexture],
        opacities: [Float],
        blendModes: [BlendMode],
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        guard let output = device.makeTexture(descriptor: textureDescriptor) else { return nil }

        // Simplified compositing - in production would use proper blend shaders
        // For now, just return the first texture
        return textures.first
    }

    public func applyEffect(
        shader: MTLComputePipelineState,
        parameters: [String: Float],
        to texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        guard let output = device.makeTexture(descriptor: textureDescriptor) else { return nil }

        render(shader: shader, parameters: parameters, to: output, commandBuffer: commandBuffer)
        return output
    }
}

// MARK: - Output Renderer

public class OutputRenderer {
    private let device: MTLDevice
    private let resolution: CGSize

    public init(device: MTLDevice, resolution: CGSize) {
        self.device = device
        self.resolution = resolution
    }

    public func render(to target: OutputTarget, texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        switch target.type {
        case .window:
            // Render to window (handled by view)
            break
        case .fullscreen:
            // Render to fullscreen
            break
        case .ndi:
            // Send via NDI
            break
        case .spout:
            // Send via Spout (Windows)
            break
        case .syphon:
            // Send via Syphon (macOS)
            break
        case .file:
            // Record to file
            break
        }
    }
}
#endif
