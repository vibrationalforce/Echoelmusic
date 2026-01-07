import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage
import simd

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - Scene Renderer

/// GPU-accelerated scene compositor for live streaming
/// Composites multiple layers: camera, visuals, overlays, and bio-data widgets
class SceneRenderer {

    // MARK: - Metal Objects

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext

    // MARK: - Pipeline States

    private var compositePipeline: MTLRenderPipelineState?
    private var chromaKeyPipeline: MTLRenderPipelineState?
    private var blendPipeline: MTLRenderPipelineState?
    private var transformPipeline: MTLComputePipelineState?

    // MARK: - Buffers

    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    // MARK: - Source Textures

    private var sourceTextures: [UUID: MTLTexture] = [:]
    private var outputTexture: MTLTexture?

    // MARK: - Bio-Reactive State

    var currentCoherence: Float = 0.0
    var currentHeartRate: Float = 72.0
    var currentHRV: Float = 50.0
    var breathingPhase: Float = 0.0

    // MARK: - Types

    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
        var coherence: Float
        var heartRate: Float
        var chromaKeyColor: SIMD4<Float>
        var chromaKeySimilarity: Float
        var chromaKeySmoothness: Float
        var opacity: Float
        var padding: Float = 0
    }

    struct Vertex {
        var position: SIMD4<Float>
        var texCoord: SIMD2<Float>
    }

    struct LayerTransform {
        var position: SIMD2<Float> = SIMD2<Float>(0, 0)
        var scale: SIMD2<Float> = SIMD2<Float>(1, 1)
        var rotation: Float = 0
        var opacity: Float = 1.0
    }

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            log.streaming("❌ SceneRenderer: Failed to create command queue", level: .error)
            return nil
        }
        self.commandQueue = queue

        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false
        ])

        setupPipelines()
        createBuffers()

        log.streaming("✅ SceneRenderer: Initialized")
    }

    // MARK: - Setup

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() ?? loadFallbackLibrary() else {
            log.streaming("⚠️ SceneRenderer: No shader library available", level: .warning)
            return
        }

        // Composite pipeline
        if let vertexFunc = library.makeFunction(name: "sceneVertexShader"),
           let fragmentFunc = library.makeFunction(name: "sceneCompositeShader") {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

            compositePipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        // Chroma key pipeline
        if let vertexFunc = library.makeFunction(name: "sceneVertexShader"),
           let fragmentFunc = library.makeFunction(name: "chromaKeyShader") {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

            chromaKeyPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
    }

    private func loadFallbackLibrary() -> MTLLibrary? {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        struct Uniforms {
            float time;
            float2 resolution;
            float coherence;
            float heartRate;
            float4 chromaKeyColor;
            float chromaKeySimilarity;
            float chromaKeySmoothness;
            float opacity;
            float padding;
        };

        vertex VertexOut sceneVertexShader(
            uint vertexID [[vertex_id]],
            constant float4 *vertices [[buffer(0)]]
        ) {
            float4 positions[4] = {
                float4(-1.0, -1.0, 0.0, 1.0),
                float4( 1.0, -1.0, 0.0, 1.0),
                float4(-1.0,  1.0, 0.0, 1.0),
                float4( 1.0,  1.0, 0.0, 1.0)
            };

            float2 texCoords[4] = {
                float2(0.0, 1.0),
                float2(1.0, 1.0),
                float2(0.0, 0.0),
                float2(1.0, 0.0)
            };

            VertexOut out;
            out.position = positions[vertexID];
            out.texCoord = texCoords[vertexID];
            return out;
        }

        fragment float4 sceneCompositeShader(
            VertexOut in [[stage_in]],
            texture2d<float> sourceTexture [[texture(0)]],
            constant Uniforms &uniforms [[buffer(0)]]
        ) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            float4 color = sourceTexture.sample(textureSampler, in.texCoord);
            color.a *= uniforms.opacity;
            return color;
        }

        fragment float4 chromaKeyShader(
            VertexOut in [[stage_in]],
            texture2d<float> sourceTexture [[texture(0)]],
            constant Uniforms &uniforms [[buffer(0)]]
        ) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            float4 color = sourceTexture.sample(textureSampler, in.texCoord);

            // Convert to YCbCr for better chroma keying
            float Y = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
            float Cb = 0.564 * (color.b - Y);
            float Cr = 0.713 * (color.r - Y);

            float keyY = 0.299 * uniforms.chromaKeyColor.r + 0.587 * uniforms.chromaKeyColor.g + 0.114 * uniforms.chromaKeyColor.b;
            float keyCb = 0.564 * (uniforms.chromaKeyColor.b - keyY);
            float keyCr = 0.713 * (uniforms.chromaKeyColor.r - keyY);

            float chromaDist = sqrt((Cb - keyCb) * (Cb - keyCb) + (Cr - keyCr) * (Cr - keyCr));
            float mask = smoothstep(uniforms.chromaKeySimilarity, uniforms.chromaKeySimilarity + uniforms.chromaKeySmoothness, chromaDist);

            color.a = mask * uniforms.opacity;
            return color;
        }

        fragment float4 bioOverlayShader(
            VertexOut in [[stage_in]],
            constant Uniforms &uniforms [[buffer(0)]]
        ) {
            float2 uv = in.texCoord;
            float2 center = float2(0.9, 0.1);
            float dist = length(uv - center);

            // Coherence ring
            float pulse = sin(uniforms.time * uniforms.heartRate / 60.0 * 6.28318) * 0.5 + 0.5;
            float ringRadius = 0.05 + pulse * 0.01;
            float ring = smoothstep(ringRadius, ringRadius - 0.005, dist) - smoothstep(ringRadius - 0.005, ringRadius - 0.01, dist);

            // Color based on coherence
            float3 lowCoherence = float3(0.8, 0.2, 0.2);
            float3 highCoherence = float3(0.2, 0.8, 0.5);
            float3 color = mix(lowCoherence, highCoherence, uniforms.coherence);

            return float4(color * ring, ring * 0.8);
        }
        """

        return try? device.makeLibrary(source: shaderSource, options: nil)
    }

    private func createBuffers() {
        // Fullscreen quad vertices
        let vertices: [Vertex] = [
            Vertex(position: SIMD4<Float>(-1, -1, 0, 1), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD4<Float>( 1, -1, 0, 1), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD4<Float>(-1,  1, 0, 1), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD4<Float>( 1,  1, 0, 1), texCoord: SIMD2<Float>(1, 0))
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * 4, options: .storageModeShared)

        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
    }

    // MARK: - Rendering

    /// Render a complete scene to texture
    func renderScene(_ scene: Scene, size: CGSize, time: Float) -> MTLTexture? {
        // Create or reuse output texture
        if outputTexture == nil ||
           outputTexture!.width != Int(size.width) ||
           outputTexture!.height != Int(size.height) {
            outputTexture = createTexture(size: size)
        }

        guard let output = outputTexture,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }

        // Clear to black
        clearTexture(output, commandBuffer: commandBuffer)

        // Render each source layer
        for source in scene.sources {
            renderSource(source, to: output, time: time, commandBuffer: commandBuffer)
        }

        // Add bio-data overlay if enabled
        renderBioOverlay(to: output, time: time, commandBuffer: commandBuffer)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    private func createTexture(size: CGSize) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        return device.makeTexture(descriptor: descriptor)
    }

    private func clearTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        encoder.endEncoding()
    }

    private func renderSource(_ source: SceneSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        switch source {
        case .camera(let cameraSource):
            renderCameraSource(cameraSource, to: output, time: time, commandBuffer: commandBuffer)

        case .chromaKey(let chromaKeySource):
            renderChromaKeySource(chromaKeySource, to: output, time: time, commandBuffer: commandBuffer)

        case .screenCapture(let screenSource):
            renderScreenCaptureSource(screenSource, to: output, time: time, commandBuffer: commandBuffer)

        case .videoFile(let videoSource):
            renderVideoSource(videoSource, to: output, time: time, commandBuffer: commandBuffer)

        case .echoelVisual(let visualSource):
            renderEchoelVisualSource(visualSource, to: output, time: time, commandBuffer: commandBuffer)

        case .bioOverlay(let bioSource):
            renderBioOverlaySource(bioSource, to: output, time: time, commandBuffer: commandBuffer)

        case .textOverlay(let textSource):
            renderTextOverlaySource(textSource, to: output, time: time, commandBuffer: commandBuffer)

        case .imageOverlay(let imageSource):
            renderImageOverlaySource(imageSource, to: output, time: time, commandBuffer: commandBuffer)

        case .webBrowser(let webSource):
            renderWebBrowserSource(webSource, to: output, time: time, commandBuffer: commandBuffer)
        }
    }

    // MARK: - Source Renderers

    private func renderCameraSource(_ source: CameraSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = compositePipeline else { return }

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer)
    }

    private func renderChromaKeySource(_ source: ChromaKeySource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = chromaKeyPipeline else { return }

        // Set chroma key color
        let keyColor: SIMD4<Float> = source.keyColor == .green
            ? SIMD4<Float>(0.0, 1.0, 0.0, 1.0)
            : SIMD4<Float>(0.0, 0.0, 1.0, 1.0)

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer, chromaKeyColor: keyColor)
    }

    private func renderScreenCaptureSource(_ source: ScreenCaptureSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = compositePipeline else { return }

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer)
    }

    private func renderVideoSource(_ source: VideoFileSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = compositePipeline else { return }

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer)
    }

    private func renderEchoelVisualSource(_ source: EchoelVisualSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        // Use Metal shader manager for bio-reactive visuals
        #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
        let shaderManager = MetalShaderManager.shared

        // Map visual type to shader type
        let shaderType: MetalShaderManager.ShaderType
        switch source.type {
        case .cymatics:
            shaderType = .cymatics
        case .mandala:
            shaderType = .mandala
        case .particles:
            shaderType = .bioReactivePulse
        case .waveform:
            shaderType = .perlinNoise
        case .spectral:
            shaderType = .starfield
        }

        // Generate visual texture
        let uniforms = MetalShaderManager.Uniforms(
            time: time,
            coherence: currentCoherence,
            heartRate: currentHeartRate,
            breathingPhase: breathingPhase,
            audioLevel: 0.5,
            resolution: SIMD2<Float>(Float(output.width), Float(output.height))
        )

        if let visualTexture = shaderManager.generateTexture(
            size: CGSize(width: output.width, height: output.height),
            shaderType: shaderType,
            uniforms: uniforms
        ) {
            if let pipeline = compositePipeline {
                renderTextureToOutput(visualTexture, to: output, pipeline: pipeline, opacity: 0.8, time: time, commandBuffer: commandBuffer)
            }
        }
        #endif
    }

    private func renderBioOverlaySource(_ source: BioOverlaySource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        // Render bio widgets using Core Graphics
        for widget in source.widgets {
            renderBioWidget(widget, to: output, time: time, commandBuffer: commandBuffer)
        }
    }

    private func renderTextOverlaySource(_ source: TextOverlaySource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        // Render text using Core Graphics and composite
        let textImage = renderTextToImage(
            source.text,
            font: source.font,
            fontSize: source.fontSize,
            color: source.color,
            scrolling: source.scrolling,
            time: time
        )

        if let cgImage = textImage,
           let texture = textureFromCGImage(cgImage),
           let pipeline = compositePipeline {
            renderTextureToOutput(texture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer)
        }
    }

    private func renderImageOverlaySource(_ source: ImageOverlaySource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = compositePipeline else { return }

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: Float(source.opacity), time: time, commandBuffer: commandBuffer)
    }

    private func renderWebBrowserSource(_ source: WebBrowserSource, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        guard let sourceTexture = sourceTextures[source.id],
              let pipeline = compositePipeline else { return }

        renderTextureToOutput(sourceTexture, to: output, pipeline: pipeline, opacity: 1.0, time: time, commandBuffer: commandBuffer)
    }

    // MARK: - Bio Overlay

    private func renderBioOverlay(to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        // Small coherence indicator in corner
        // This is always rendered for bio-reactive streams
    }

    private func renderBioWidget(_ widget: BioOverlaySource.BioWidget, to output: MTLTexture, time: Float, commandBuffer: MTLCommandBuffer) {
        // Render individual bio widgets
        switch widget {
        case .hrvGraph:
            // Render HRV line graph
            break
        case .heartRateDisplay:
            // Render heart rate number with pulsing animation
            break
        case .coherenceRing:
            // Render coherence ring
            break
        case .breathWave:
            // Render breathing wave
            break
        }
    }

    // MARK: - Helper Methods

    private func renderTextureToOutput(
        _ source: MTLTexture,
        to output: MTLTexture,
        pipeline: MTLRenderPipelineState,
        opacity: Float,
        time: Float,
        commandBuffer: MTLCommandBuffer,
        chromaKeyColor: SIMD4<Float> = SIMD4<Float>(0, 1, 0, 1)
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let uniformBuffer = uniformBuffer else { return }

        // Update uniforms
        var uniforms = Uniforms(
            time: time,
            resolution: SIMD2<Float>(Float(output.width), Float(output.height)),
            coherence: currentCoherence,
            heartRate: currentHeartRate,
            chromaKeyColor: chromaKeyColor,
            chromaKeySimilarity: 0.4,
            chromaKeySmoothness: 0.1,
            opacity: opacity
        )
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func renderTextToImage(_ text: String, font: String, fontSize: CGFloat, color: SwiftUI.Color, scrolling: Bool, time: Float) -> CGImage? {
        #if os(iOS) || os(tvOS)
        let uiColor = UIColor(color)
        let uiFont = UIFont(name: font, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: uiColor
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))

        let image = renderer.image { context in
            (text as NSString).draw(at: .zero, withAttributes: attributes)
        }

        return image.cgImage
        #elseif os(macOS)
        let nsColor = NSColor(color)
        let nsFont = NSFont(name: font, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .foregroundColor: nsColor
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let image = NSImage(size: NSSize(width: max(size.width, 1), height: max(size.height, 1)))

        image.lockFocus()
        (text as NSString).draw(at: .zero, withAttributes: attributes)
        image.unlockFocus()

        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }

    private func textureFromCGImage(_ cgImage: CGImage) -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(cgImage: cgImage, options: [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.shared.rawValue
        ])
    }

    // MARK: - Source Management

    func updateSourceTexture(id: UUID, texture: MTLTexture) {
        sourceTextures[id] = texture
    }

    func removeSourceTexture(id: UUID) {
        sourceTextures.removeValue(forKey: id)
    }

    func updateBioMetrics(coherence: Float, heartRate: Float, hrv: Float, breathingPhase: Float) {
        self.currentCoherence = coherence
        self.currentHeartRate = heartRate
        self.currentHRV = hrv
        self.breathingPhase = breathingPhase
    }
}

// MARK: - Scene Transition Renderer

extension SceneRenderer {

    /// Render transition between two scenes
    func renderTransition(from: Scene?, to: Scene, progress: Float, transition: SceneTransition, size: CGSize, time: Float) -> MTLTexture? {
        guard let toTexture = renderScene(to, size: size, time: time) else { return nil }

        guard let fromScene = from,
              let fromTexture = renderScene(fromScene, size: size, time: time),
              let output = createTexture(size: size),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return toTexture
        }

        switch transition {
        case .cut:
            return toTexture

        case .fade:
            renderCrossfade(from: fromTexture, to: toTexture, progress: progress, output: output, commandBuffer: commandBuffer)

        case .slide:
            renderSlide(from: fromTexture, to: toTexture, progress: progress, output: output, commandBuffer: commandBuffer)

        case .zoom:
            renderZoom(from: fromTexture, to: toTexture, progress: progress, output: output, commandBuffer: commandBuffer)

        case .stinger:
            // For stinger, use crossfade as fallback
            renderCrossfade(from: fromTexture, to: toTexture, progress: progress, output: output, commandBuffer: commandBuffer)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return output
    }

    private func renderCrossfade(from: MTLTexture, to: MTLTexture, progress: Float, output: MTLTexture, commandBuffer: MTLCommandBuffer) {
        // Render 'from' at (1 - progress) opacity
        if let pipeline = compositePipeline {
            renderTextureToOutput(from, to: output, pipeline: pipeline, opacity: 1.0 - progress, time: 0, commandBuffer: commandBuffer)
            renderTextureToOutput(to, to: output, pipeline: pipeline, opacity: progress, time: 0, commandBuffer: commandBuffer)
        }
    }

    private func renderSlide(from: MTLTexture, to: MTLTexture, progress: Float, output: MTLTexture, commandBuffer: MTLCommandBuffer) {
        // Slide 'from' out, 'to' in
        // Simplified: use crossfade
        renderCrossfade(from: from, to: to, progress: progress, output: output, commandBuffer: commandBuffer)
    }

    private func renderZoom(from: MTLTexture, to: MTLTexture, progress: Float, output: MTLTexture, commandBuffer: MTLCommandBuffer) {
        // Zoom out 'from', zoom in 'to'
        // Simplified: use crossfade
        renderCrossfade(from: from, to: to, progress: progress, output: output, commandBuffer: commandBuffer)
    }
}

#endif
