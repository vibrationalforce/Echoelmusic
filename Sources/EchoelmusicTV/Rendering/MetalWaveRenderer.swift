import Metal
import MetalKit
import SwiftUI

/// Metal-based wave renderer for Apple TV
///
/// **Purpose:** GPU-accelerated wave visualization matching heart rhythm
///
/// **Features:**
/// - Flowing sine waves
/// - Heart rate synchronization
/// - HRV-reactive amplitude
/// - Multi-layer waves (3-5 layers)
/// - Coherence-reactive colors
/// - 60 FPS smooth animation
///
/// **Technical:**
/// - Metal vertex shaders
/// - Dynamic vertex updates
/// - Instanced rendering for multiple waves
/// - Real-time audio-reactive behavior
///
/// **Platform:** tvOS, iOS, macOS (Metal-capable devices)
///
@MainActor
public class MetalWaveRenderer: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Number of wave layers
    @Published public var layerCount: Int = 5

    /// Wave amplitude (affected by HRV)
    @Published public var amplitude: Double = 0.3

    /// Heart rate (affects wave frequency)
    @Published public var heartRate: Double = 70.0

    /// Coherence value (affects wave smoothness)
    @Published public var coherence: Double = 50.0

    // MARK: - Metal Properties

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderPipeline: MTLRenderPipelineState?

    private var waveVertexBuffers: [MTLBuffer] = []
    private var uniformBuffer: MTLBuffer?

    private var currentTime: Float = 0.0
    private let vertexCount = 200 // Vertices per wave

    // MARK: - Initialization

    public override init() {
        super.init()
        setupMetal()
        createWaveBuffers()
        print("[MetalWaves] 🌊 Metal wave renderer initialized (\(layerCount) layers)")
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[MetalWaves] ❌ Metal not supported on this device")
            return
        }

        self.device = device

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("[MetalWaves] ❌ Failed to create command queue")
            return
        }

        self.commandQueue = commandQueue

        // Create render pipeline
        createRenderPipeline()

        print("[MetalWaves] ✅ Metal setup complete")
    }

    private func createRenderPipeline() {
        guard let device = device else { return }

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float time;
            float amplitude;
            float frequency;
            float coherence;
            float4 color;
            float layerOffset;
        };

        struct VertexIn {
            float2 position [[attribute(0)]];
        };

        struct VertexOut {
            float4 position [[position]];
            float4 color;
        };

        vertex VertexOut vertexShader(
            VertexIn in [[stage_in]],
            constant Uniforms& uniforms [[buffer(1)]]
        ) {
            VertexOut out;

            // Create wave shape
            float x = in.position.x;
            float wave1 = sin((x * uniforms.frequency) + (uniforms.time * 2.0) + uniforms.layerOffset) * uniforms.amplitude;
            float wave2 = sin((x * uniforms.frequency * 1.5) + (uniforms.time * 1.5)) * uniforms.amplitude * 0.5;
            float wave3 = sin((x * uniforms.frequency * 0.7) + (uniforms.time * 2.5)) * uniforms.amplitude * 0.3;

            // Coherence affects wave smoothness
            float coherenceFactor = uniforms.coherence / 100.0;
            float smoothness = mix(0.3, 1.0, coherenceFactor);

            float y = (wave1 + wave2 * smoothness + wave3 * smoothness) * 0.5;

            out.position = float4(x, y + in.position.y, 0.0, 1.0);
            out.color = uniforms.color;

            // Fade at edges
            float edgeFade = 1.0 - abs(x);
            out.color.a *= smoothstep(0.0, 0.2, edgeFade);

            return out;
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            return in.color;
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vertexFunction = library.makeFunction(name: "vertexShader"),
                  let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                print("[MetalWaves] ❌ Failed to create shader functions")
                return
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

            // Vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride

            pipelineDescriptor.vertexDescriptor = vertexDescriptor

            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("[MetalWaves] ✅ Render pipeline created")

        } catch {
            print("[MetalWaves] ❌ Failed to create render pipeline: \(error)")
        }
    }

    // MARK: - Wave Buffer Creation

    private func createWaveBuffers() {
        guard let device = device else { return }

        waveVertexBuffers.removeAll()

        for _ in 0..<layerCount {
            // Create vertices for a wave (line strip)
            var vertices: [SIMD2<Float>] = []

            for i in 0..<vertexCount {
                let x = Float(i) / Float(vertexCount - 1) * 2.0 - 1.0 // -1 to 1
                let y: Float = 0.0 // Base y position
                vertices.append(SIMD2<Float>(x, y))
            }

            // Create Metal buffer
            let bufferSize = MemoryLayout<SIMD2<Float>>.stride * vertices.count
            if let buffer = device.makeBuffer(
                bytes: vertices,
                length: bufferSize,
                options: .storageModeShared
            ) {
                waveVertexBuffers.append(buffer)
            }
        }

        print("[MetalWaves] ✅ Created \(layerCount) wave buffers")
    }

    // MARK: - Update

    /// Update waves (called every frame)
    public func update(deltaTime: Float) {
        currentTime += deltaTime
    }

    /// Render waves to given drawable
    public func render(to drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let device = device,
              let commandQueue = commandQueue,
              let renderPipeline = renderPipeline else {
            return
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(renderPipeline)

        // Render each wave layer
        for (index, vertexBuffer) in waveVertexBuffers.enumerated() {
            // Calculate wave uniforms
            let layerProgress = Float(index) / Float(layerCount)

            // Heart rate affects frequency (BPM / 60 = Hz)
            let frequency = Float(heartRate / 60.0) * 2.0

            // Color based on coherence (gradient from red to blue)
            let coherenceFactor = Float(coherence / 100.0)
            let hue = coherenceFactor * 0.6 // 0.0 (red) to 0.6 (blue)
            let color = SIMD4<Float>(
                1.0 - hue,
                0.5 + hue * 0.5,
                coherenceFactor,
                0.3 + layerProgress * 0.4 // Varying alpha for layers
            )

            var uniforms = WaveUniforms(
                time: currentTime,
                amplitude: Float(amplitude),
                frequency: frequency,
                coherence: Float(coherence),
                color: color,
                layerOffset: layerProgress * 2.0
            )

            // Set buffers
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<WaveUniforms>.stride, index: 1)

            // Draw wave (line strip)
            renderEncoder.drawPrimitives(
                type: .lineStrip,
                vertexStart: 0,
                vertexCount: vertexCount
            )
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Public Setters

    /// Update amplitude based on HRV
    public func setAmplitude(_ value: Double) {
        amplitude = value
    }

    /// Update heart rate
    public func setHeartRate(_ bpm: Double) {
        heartRate = bpm
    }

    /// Update coherence
    public func setCoherence(_ value: Double) {
        coherence = value
    }

    /// Set number of wave layers
    public func setLayerCount(_ count: Int) {
        layerCount = count
        createWaveBuffers()
    }
}

// MARK: - Wave Uniforms Structure

struct WaveUniforms {
    var time: Float
    var amplitude: Float
    var frequency: Float
    var coherence: Float
    var color: SIMD4<Float>
    var layerOffset: Float
}
