import Foundation
import Metal
import MetalKit
import CoreGraphics
import AVFoundation

// MARK: - Shader Uniforms Structure

/// Uniforms structure matching Metal shader
struct Uniforms {
    var time: Float
    var audioLevel: Float
    var frequency: Float
    var hrvCoherence: Float
    var heartRate: Float
    var resolution: SIMD2<Float>
}

/// Renders visualizations to Metal textures for video export
/// Supports all visualization modes: Particles, Cymatics, Waveform, Spectral, Mandala
@MainActor
class VisualizationVideoRenderer {

    // MARK: - Metal Components

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState?

    // MARK: - Render Targets

    private var renderTexture: MTLTexture?
    private var renderPassDescriptor: MTLRenderPassDescriptor?

    // MARK: - Configuration

    private let size: CGSize
    private let pixelFormat: MTLPixelFormat = .bgra8Unorm
    private let fftExtractor: AudioFFTExtractor

    // MARK: - Visualization Renderers

    // TODO: These would be actual renderer instances
    // For now, we'll create a basic rendering framework


    // MARK: - Initialization

    init(device: MTLDevice, size: CGSize, fftExtractor: AudioFFTExtractor) throws {
        self.device = device
        self.size = size
        self.fftExtractor = fftExtractor

        guard let commandQueue = device.makeCommandQueue() else {
            throw VideoExportError.unsupportedFormat
        }
        self.commandQueue = commandQueue

        try setupRenderTarget()
        try setupPipeline()

        print("🎨 VisualizationVideoRenderer initialized")
        print("   Size: \(Int(size.width))x\(Int(size.height))")
    }


    // MARK: - Setup

    private func setupRenderTarget() throws {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw VideoExportError.pixelBufferCreationFailed
        }

        renderTexture = texture

        // Setup render pass descriptor
        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor?.colorAttachments[0].texture = texture
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    private func setupPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            print("⚠️ Could not load default Metal library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "vertexShader") else {
            print("⚠️ Could not load vertex shader")
            return
        }

        // We'll set the fragment function per-mode, so just store the vertex function
        print("✅ Metal shaders loaded successfully")
    }


    // MARK: - Rendering

    /// Render visualization to texture
    /// - Parameters:
    ///   - mode: Visualization mode to render
    ///   - audioData: Current audio FFT data
    ///   - bioData: Current bio-feedback data
    ///   - time: Current time for animations
    /// - Returns: Metal texture containing rendered frame
    func renderFrame(
        mode: VisualizationMode,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) throws -> MTLTexture {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw VideoExportError.encodingFailed("Could not create command buffer")
        }

        guard let renderPassDescriptor = renderPassDescriptor,
              let renderTexture = renderTexture else {
            throw VideoExportError.pixelBufferCreationFailed
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw VideoExportError.encodingFailed("Could not create render encoder")
        }

        // Render based on mode
        switch mode {
        case .particles:
            renderParticles(encoder: renderEncoder, audioData: audioData, bioData: bioData, time: time)
        case .cymatics:
            renderCymatics(encoder: renderEncoder, audioData: audioData, bioData: bioData, time: time)
        case .waveform:
            renderWaveform(encoder: renderEncoder, audioData: audioData, bioData: bioData, time: time)
        case .spectral:
            renderSpectral(encoder: renderEncoder, audioData: audioData, bioData: bioData, time: time)
        case .mandala:
            renderMandala(encoder: renderEncoder, audioData: audioData, bioData: bioData, time: time)
        }

        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return renderTexture
    }


    // MARK: - Mode-Specific Rendering

    private func renderParticles(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        renderWithShader(
            encoder: encoder,
            shaderName: "particleFragment",
            audioData: audioData,
            bioData: bioData,
            time: time
        )
    }

    private func renderCymatics(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        renderWithShader(
            encoder: encoder,
            shaderName: "cymaticsFragment",
            audioData: audioData,
            bioData: bioData,
            time: time
        )
    }

    private func renderWaveform(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        renderWithShader(
            encoder: encoder,
            shaderName: "waveformFragment",
            audioData: audioData,
            bioData: bioData,
            time: time
        )
    }

    private func renderSpectral(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        renderWithShader(
            encoder: encoder,
            shaderName: "spectralFragment",
            audioData: audioData,
            bioData: bioData,
            time: time
        )
    }

    private func renderMandala(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        renderWithShader(
            encoder: encoder,
            shaderName: "mandalaFragment",
            audioData: audioData,
            bioData: bioData,
            time: time
        )
    }

    /// Render with Metal shader
    private func renderWithShader(
        encoder: MTLRenderCommandEncoder,
        shaderName: String,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: shaderName) else {
            // Fallback to solid color if shader not available
            let audioLevel = audioData.reduce(0, +) / Float(max(audioData.count, 1))
            renderSolidColor(encoder: encoder, red: audioLevel, green: 0.5, blue: 1.0)
            return
        }

        // Create pipeline state for this shader
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)

        // Create uniforms
        let audioLevel = audioData.reduce(0, +) / Float(max(audioData.count, 1))
        let frequency: Float = fftExtractor.getDominantFrequency(from: audioData)

        var uniforms = Uniforms(
            time: Float(time),
            audioLevel: audioLevel,
            frequency: frequency,
            hrvCoherence: Float(bioData.hrvCoherence),
            heartRate: Float(bioData.heartRate),
            resolution: SIMD2<Float>(Float(size.width), Float(size.height))
        )

        // Set uniforms
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        // Draw fullscreen quad
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }


    // MARK: - Helper Methods

    /// Render a solid color (fallback when shaders not available)
    private func renderSolidColor(
        encoder: MTLRenderCommandEncoder,
        red: Float,
        green: Float,
        blue: Float
    ) {
        // Set clear color for this frame
        if let renderPassDescriptor = renderPassDescriptor {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: 1.0
            )
        }
    }


    // MARK: - Texture Access

    /// Get current render texture
    var currentTexture: MTLTexture? {
        return renderTexture
    }
}


// MARK: - Bio Render Data

/// Bio-feedback data formatted for rendering
struct BioRenderData {
    let hrvCoherence: Double
    let heartRate: Double
    let breathingRate: Double
    let audioLevel: Float

    init(
        hrvCoherence: Double = 50.0,
        heartRate: Double = 72.0,
        breathingRate: Double = 6.0,
        audioLevel: Float = 0.5
    ) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.breathingRate = breathingRate
        self.audioLevel = audioLevel
    }

    /// Create from HealthKit manager
    static func from(healthKit: HealthKitManager, audioLevel: Float) -> BioRenderData {
        return BioRenderData(
            hrvCoherence: healthKit.hrvCoherence,
            heartRate: healthKit.heartRate,
            breathingRate: 6.0,  // TODO: Calculate from HRV
            audioLevel: audioLevel
        )
    }
}


// MARK: - Audio Data Helper

extension VisualizationVideoRenderer {
    /// Generate mock audio data for testing
    static func mockAudioData(frequency: Float = 440.0, sampleCount: Int = 512) -> [Float] {
        var data = [Float]()
        for i in 0..<sampleCount {
            let phase = Float(i) / Float(sampleCount) * 2.0 * .pi
            data.append(sin(phase * frequency / 440.0))
        }
        return data
    }
}
