import Foundation
import Metal
import MetalKit
import CoreGraphics
import AVFoundation

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

    // MARK: - Visualization Renderers

    // TODO: These would be actual renderer instances
    // For now, we'll create a basic rendering framework


    // MARK: - Initialization

    init(device: MTLDevice, size: CGSize) throws {
        self.device = device
        self.size = size

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
        // Basic pipeline for solid color rendering
        // In full implementation, this would load actual shaders for each visualization mode

        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("⚠️ Could not create render pipeline state (using fallback): \(error)")
            // Fallback: we'll render without shaders (solid colors)
        }
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
        // TODO: Implement particle system rendering
        // For now, render a solid color based on audio level
        let audioLevel = audioData.reduce(0, +) / Float(max(audioData.count, 1))
        renderSolidColor(encoder: encoder, red: audioLevel, green: 0.5, blue: 1.0 - audioLevel)
    }

    private func renderCymatics(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        // TODO: Implement cymatics pattern rendering
        renderSolidColor(encoder: encoder, red: 0.2, green: 0.5, blue: 0.8)
    }

    private func renderWaveform(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        // TODO: Implement waveform rendering
        renderSolidColor(encoder: encoder, red: 0.0, green: 1.0, blue: 0.0)
    }

    private func renderSpectral(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        // TODO: Implement spectral analyzer rendering
        renderSolidColor(encoder: encoder, red: 0.5, green: 0.0, blue: 1.0)
    }

    private func renderMandala(
        encoder: MTLRenderCommandEncoder,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) {
        // TODO: Implement mandala pattern rendering
        let hue = Float(bioData.hrvCoherence / 100.0)
        renderSolidColor(encoder: encoder, red: hue, green: 0.7, blue: 1.0 - hue)
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
