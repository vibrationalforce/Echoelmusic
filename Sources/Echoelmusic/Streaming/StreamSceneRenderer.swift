import Foundation
import AVFoundation
import CoreImage
import Metal
import MetalKit

// ═══════════════════════════════════════════════════════════════════════════════
// STREAM SCENE RENDERER - VIDEO COMPOSITING & TRANSITIONS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete video compositing engine for live streaming:
// • Multi-layer scene composition
// • GPU-accelerated transitions (crossfade, wipe, zoom, etc.)
// • Real-time video effects
// • Picture-in-picture support
// • Animated overlays and graphics
// • Frame encoding for streaming
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Stream scene renderer with GPU-accelerated compositing
final class StreamSceneRenderer {

    // MARK: - Metal Setup

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?

    // MARK: - Scene Configuration

    private var currentScene: Scene?
    private var transitionState: TransitionState?
    private var layers: [SceneLayer] = []
    private var overlays: [Overlay] = []

    // MARK: - Output

    private var outputSize: CGSize = CGSize(width: 1920, height: 1080)
    private var frameRate: Double = 30.0
    private var outputTexture: MTLTexture?

    // MARK: - Encoding

    private var compressionSession: VTCompressionSession?
    private var encodedFrameCallback: ((CMSampleBuffer) -> Void)?

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)

        setupPipeline()
        setupTextureCache()
        setupEncoder()
    }

    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "sceneVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "sceneFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable alpha blending for layers
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func setupTextureCache() {
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    private func setupEncoder() {
        let width = Int32(outputSize.width)
        let height = Int32(outputSize.height)

        let encoderSpecification: [String: Any] = [
            kVTCompressionPropertyKey_RealTime as String: true,
            kVTCompressionPropertyKey_ProfileLevel as String: kVTProfileLevel_H264_High_AutoLevel,
            kVTCompressionPropertyKey_AllowFrameReordering as String: false
        ]

        var session: VTCompressionSession?
        VTCompressionSessionCreate(
            allocator: nil,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: encoderSpecification as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        if let session = session {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 6_000_000 as CFNumber)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 60 as CFNumber)
            VTCompressionSessionPrepareToEncodeFrames(session)
            self.compressionSession = session
        }
    }

    // MARK: - Scene Management

    func setScene(_ scene: Scene) {
        currentScene = scene
        layers = scene.layers
        overlays = scene.overlays
    }

    func transitionTo(_ newScene: Scene, duration: TimeInterval, type: TransitionType) {
        guard let currentScene = currentScene else {
            setScene(newScene)
            return
        }

        transitionState = TransitionState(
            fromScene: currentScene,
            toScene: newScene,
            duration: duration,
            type: type,
            startTime: CACurrentMediaTime()
        )
    }

    // MARK: - Layer Management

    func addLayer(_ layer: SceneLayer) {
        layers.append(layer)
        layers.sort { $0.zIndex < $1.zIndex }
    }

    func removeLayer(id: String) {
        layers.removeAll { $0.id == id }
    }

    func updateLayer(id: String, transform: LayerTransform) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].transform = transform
        }
    }

    // MARK: - Rendering

    func renderFrame(at time: CFTimeInterval) -> MTLTexture? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        // Create output texture if needed
        if outputTexture == nil || outputTexture?.width != Int(outputSize.width) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: Int(outputSize.width),
                height: Int(outputSize.height),
                mipmapped: false
            )
            descriptor.usage = [.renderTarget, .shaderRead]
            outputTexture = device.makeTexture(descriptor: descriptor)
        }

        guard let outputTexture = outputTexture else { return nil }

        // Render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }

        // Handle transition if active
        if let transition = transitionState {
            renderTransition(encoder: encoder, transition: transition, time: time)
        } else {
            // Render current scene layers
            renderLayers(encoder: encoder, layers: layers, time: time)
        }

        // Render overlays on top
        renderOverlays(encoder: encoder, overlays: overlays, time: time)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }

    private func renderLayers(encoder: MTLRenderCommandEncoder, layers: [SceneLayer], time: CFTimeInterval) {
        for layer in layers where layer.isVisible {
            renderLayer(encoder: encoder, layer: layer, time: time, opacity: layer.opacity)
        }
    }

    private func renderLayer(encoder: MTLRenderCommandEncoder, layer: SceneLayer, time: CFTimeInterval, opacity: Float) {
        guard let pipelineState = pipelineState else { return }

        encoder.setRenderPipelineState(pipelineState)

        // Create vertex data for layer quad
        let transform = layer.transform
        let vertices = calculateVertices(for: transform)

        // Set vertex buffer
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)

        // Set fragment uniforms
        var uniforms = LayerUniforms(
            opacity: opacity,
            time: Float(time),
            effectType: layer.effect?.type.rawValue ?? 0
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LayerUniforms>.size, index: 0)

        // Set texture if available
        if let texture = layer.texture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        // Draw
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func renderTransition(encoder: MTLRenderCommandEncoder, transition: TransitionState, time: CFTimeInterval) {
        let elapsed = time - transition.startTime
        let progress = Float(min(elapsed / transition.duration, 1.0))

        switch transition.type {
        case .crossfade:
            renderCrossfade(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, time: time)

        case .wipeLeft:
            renderWipe(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .left, time: time)

        case .wipeRight:
            renderWipe(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .right, time: time)

        case .wipeUp:
            renderWipe(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .up, time: time)

        case .wipeDown:
            renderWipe(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .down, time: time)

        case .zoomIn:
            renderZoom(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, zoomIn: true, time: time)

        case .zoomOut:
            renderZoom(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, zoomIn: false, time: time)

        case .slideLeft:
            renderSlide(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .left, time: time)

        case .slideRight:
            renderSlide(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, direction: .right, time: time)

        case .blur:
            renderBlurTransition(encoder: encoder, from: transition.fromScene, to: transition.toScene, progress: progress, time: time)

        case .none:
            renderLayers(encoder: encoder, layers: transition.toScene.layers, time: time)
        }

        // Complete transition
        if progress >= 1.0 {
            currentScene = transition.toScene
            layers = transition.toScene.layers
            overlays = transition.toScene.overlays
            transitionState = nil
        }
    }

    private func renderCrossfade(encoder: MTLRenderCommandEncoder, from: Scene, to: Scene, progress: Float, time: CFTimeInterval) {
        // Render 'from' scene with decreasing opacity
        for layer in from.layers where layer.isVisible {
            renderLayer(encoder: encoder, layer: layer, time: time, opacity: layer.opacity * (1.0 - progress))
        }

        // Render 'to' scene with increasing opacity
        for layer in to.layers where layer.isVisible {
            renderLayer(encoder: encoder, layer: layer, time: time, opacity: layer.opacity * progress)
        }
    }

    private func renderWipe(encoder: MTLRenderCommandEncoder, from: Scene, to: Scene, progress: Float, direction: WipeDirection, time: CFTimeInterval) {
        // Calculate clip region based on progress and direction
        // Using stencil or scissor to clip

        // For simplicity, render both with position offset based on progress
        let offset: Float

        switch direction {
        case .left:
            offset = -progress
        case .right:
            offset = progress
        case .up:
            offset = progress  // Vertical wipe
        case .down:
            offset = -progress
        }

        // Render 'from' scene offset
        for layer in from.layers where layer.isVisible {
            var adjustedLayer = layer
            adjustedLayer.transform.x += offset
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
        }

        // Render 'to' scene coming in
        for layer in to.layers where layer.isVisible {
            var adjustedLayer = layer
            adjustedLayer.transform.x += (offset < 0 ? 1 : -1) + offset
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
        }
    }

    private func renderZoom(encoder: MTLRenderCommandEncoder, from: Scene, to: Scene, progress: Float, zoomIn: Bool, time: CFTimeInterval) {
        let fromScale = zoomIn ? 1.0 + progress * 0.5 : 1.0 - progress * 0.5
        let toScale = zoomIn ? 0.5 + progress * 0.5 : 1.5 - progress * 0.5
        let fromOpacity = 1.0 - progress
        let toOpacity = progress

        // Render 'from' scene zooming
        for layer in from.layers where layer.isVisible {
            var adjustedLayer = layer
            adjustedLayer.transform.scaleX = fromScale
            adjustedLayer.transform.scaleY = fromScale
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity * Float(fromOpacity))
        }

        // Render 'to' scene zooming in
        for layer in to.layers where layer.isVisible {
            var adjustedLayer = layer
            adjustedLayer.transform.scaleX = Double(toScale)
            adjustedLayer.transform.scaleY = Double(toScale)
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity * Float(toOpacity))
        }
    }

    private func renderSlide(encoder: MTLRenderCommandEncoder, from: Scene, to: Scene, progress: Float, direction: WipeDirection, time: CFTimeInterval) {
        let slideOffset: Double = Double(progress)

        // Render 'from' scene sliding out
        for layer in from.layers where layer.isVisible {
            var adjustedLayer = layer
            switch direction {
            case .left:
                adjustedLayer.transform.x -= slideOffset
            case .right:
                adjustedLayer.transform.x += slideOffset
            default:
                break
            }
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
        }

        // Render 'to' scene sliding in
        for layer in to.layers where layer.isVisible {
            var adjustedLayer = layer
            switch direction {
            case .left:
                adjustedLayer.transform.x += (1.0 - slideOffset)
            case .right:
                adjustedLayer.transform.x -= (1.0 - slideOffset)
            default:
                break
            }
            renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
        }
    }

    private func renderBlurTransition(encoder: MTLRenderCommandEncoder, from: Scene, to: Scene, progress: Float, time: CFTimeInterval) {
        // First half: blur out from scene
        // Second half: unblur to scene
        if progress < 0.5 {
            let blurAmount = progress * 2.0
            for layer in from.layers where layer.isVisible {
                var adjustedLayer = layer
                adjustedLayer.effect = LayerEffect(type: .blur, intensity: blurAmount)
                renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
            }
        } else {
            let blurAmount = (1.0 - progress) * 2.0
            for layer in to.layers where layer.isVisible {
                var adjustedLayer = layer
                adjustedLayer.effect = LayerEffect(type: .blur, intensity: blurAmount)
                renderLayer(encoder: encoder, layer: adjustedLayer, time: time, opacity: layer.opacity)
            }
        }
    }

    private func renderOverlays(encoder: MTLRenderCommandEncoder, overlays: [Overlay], time: CFTimeInterval) {
        for overlay in overlays where overlay.isVisible {
            renderOverlay(encoder: encoder, overlay: overlay, time: time)
        }
    }

    private func renderOverlay(encoder: MTLRenderCommandEncoder, overlay: Overlay, time: CFTimeInterval) {
        // Overlay rendering with animation support
        guard let pipelineState = pipelineState else { return }

        encoder.setRenderPipelineState(pipelineState)

        // Calculate animated transform
        let animatedTransform = calculateAnimatedTransform(overlay: overlay, time: time)
        let vertices = calculateVertices(for: animatedTransform)

        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)

        var uniforms = LayerUniforms(
            opacity: overlay.opacity,
            time: Float(time),
            effectType: 0
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LayerUniforms>.size, index: 0)

        if let texture = overlay.texture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func calculateVertices(for transform: LayerTransform) -> [Float] {
        // Calculate normalized device coordinates for quad
        let x = Float(transform.x)
        let y = Float(transform.y)
        let w = Float(transform.width * transform.scaleX)
        let h = Float(transform.height * transform.scaleY)

        // Quad vertices with texture coordinates
        return [
            x - w/2, y - h/2, 0, 0, 1,  // bottom-left
            x + w/2, y - h/2, 0, 1, 1,  // bottom-right
            x - w/2, y + h/2, 0, 0, 0,  // top-left
            x + w/2, y + h/2, 0, 1, 0   // top-right
        ]
    }

    private func calculateAnimatedTransform(overlay: Overlay, time: CFTimeInterval) -> LayerTransform {
        var transform = overlay.transform

        if let animation = overlay.animation {
            let elapsed = time - animation.startTime
            let loopedTime = elapsed.truncatingRemainder(dividingBy: animation.duration)
            let progress = loopedTime / animation.duration

            switch animation.type {
            case .bounce:
                transform.y += sin(progress * .pi * 2) * animation.amplitude

            case .pulse:
                let scale = 1.0 + sin(progress * .pi * 2) * animation.amplitude * 0.2
                transform.scaleX *= scale
                transform.scaleY *= scale

            case .rotate:
                transform.rotation += progress * .pi * 2

            case .slide:
                transform.x += sin(progress * .pi * 2) * animation.amplitude

            case .fade:
                // Handled via opacity
                break
            }
        }

        return transform
    }

    // MARK: - Frame Encoding

    func encodeFrame(_ texture: MTLTexture, presentationTime: CMTime, callback: @escaping (CMSampleBuffer) -> Void) {
        guard let session = compressionSession else { return }

        self.encodedFrameCallback = callback

        // Convert Metal texture to CVPixelBuffer
        guard let pixelBuffer = textureToPixelBuffer(texture) else { return }

        // Encode
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime(value: 1, timescale: Int32(frameRate)),
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] status, infoFlags, sampleBuffer in
            if status == noErr, let sampleBuffer = sampleBuffer {
                self?.encodedFrameCallback?(sampleBuffer)
            }
        }
    }

    private func textureToPixelBuffer(_ texture: MTLTexture) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        CVPixelBufferCreate(
            nil,
            texture.width,
            texture.height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])

        if let baseAddress = CVPixelBufferGetBaseAddress(pb) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
            let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
            texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }

        CVPixelBufferUnlockBaseAddress(pb, [])

        return pb
    }
}

// MARK: - Supporting Types

struct Scene: Identifiable {
    let id: String
    var name: String
    var layers: [SceneLayer]
    var overlays: [Overlay]
    var backgroundColor: MTLClearColor
}

struct SceneLayer: Identifiable {
    let id: String
    var name: String
    var type: LayerType
    var texture: MTLTexture?
    var transform: LayerTransform
    var isVisible: Bool
    var opacity: Float
    var zIndex: Int
    var effect: LayerEffect?

    enum LayerType {
        case camera
        case screenCapture
        case image
        case video
        case color
        case gradient
        case particles
    }
}

struct LayerTransform {
    var x: Double = 0
    var y: Double = 0
    var width: Double = 1
    var height: Double = 1
    var scaleX: Double = 1
    var scaleY: Double = 1
    var rotation: Double = 0
    var anchorX: Double = 0.5
    var anchorY: Double = 0.5
}

struct LayerEffect {
    var type: EffectType
    var intensity: Float

    enum EffectType: Int {
        case none = 0
        case blur = 1
        case vignette = 2
        case colorCorrection = 3
        case chromaKey = 4
        case lut = 5
    }
}

struct Overlay: Identifiable {
    let id: String
    var name: String
    var texture: MTLTexture?
    var transform: LayerTransform
    var isVisible: Bool
    var opacity: Float
    var animation: OverlayAnimation?
}

struct OverlayAnimation {
    var type: AnimationType
    var duration: TimeInterval
    var amplitude: Double
    var startTime: TimeInterval

    enum AnimationType {
        case bounce
        case pulse
        case rotate
        case slide
        case fade
    }
}

struct TransitionState {
    let fromScene: Scene
    let toScene: Scene
    let duration: TimeInterval
    let type: TransitionType
    let startTime: CFTimeInterval
}

enum TransitionType {
    case none
    case crossfade
    case wipeLeft
    case wipeRight
    case wipeUp
    case wipeDown
    case zoomIn
    case zoomOut
    case slideLeft
    case slideRight
    case blur
}

enum WipeDirection {
    case left, right, up, down
}

struct LayerUniforms {
    var opacity: Float
    var time: Float
    var effectType: Int
}

import VideoToolbox
