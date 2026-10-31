import CoreGraphics
import CoreVideo
import EchoelCore
import Foundation
import Metal

/// The Field over a video frame on the GPU (wave W15): one pass that places the frame in the
/// output — scaled, turned upright, black where it does not reach — and lays the Field over it by
/// `FieldLayer`'s one formula, `v·video + f·field + v·f·product`. The video export's compositor and
/// the video window's preview both draw through it, so the window shows what the file will hold.
/// The Field itself is the window's own shader (`MetalFieldRenderer.encode`): no second Field.
///
/// Light is linear in the pass: the textures are read and written as sRGB, so the GPU decodes the
/// picture and encodes the result, as it does for the Field window. Built on the main thread (the
/// Field's pipeline cache lives there); after that one thread at a time draws with it — the
/// export's frames take a lock, the preview draws on the main thread.
final class FieldLayerPass: @unchecked Sendable {
    let device: MTLDevice
    let queue: MTLCommandQueue
    private let fieldPipeline: MTLRenderPipelineState
    private let layerPipeline: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    /// The Field before it is laid over the picture, kept while the output size holds.
    private var canvas: MTLTexture?

    /// The layer's pipeline per device, built once like the Field's.
    @MainActor private static var built: (device: MTLDevice, pipeline: MTLRenderPipelineState)?

    private init(device: MTLDevice, queue: MTLCommandQueue, fieldPipeline: MTLRenderPipelineState,
                 layerPipeline: MTLRenderPipelineState, textureCache: CVMetalTextureCache) {
        self.device = device
        self.queue = queue
        self.fieldPipeline = fieldPipeline
        self.layerPipeline = layerPipeline
        self.textureCache = textureCache
    }

    /// Nil on a device without Metal, or when a shader does not build (the log says which).
    @MainActor
    static func make() -> FieldLayerPass? {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        guard let field = MetalFieldRenderer.pipeline(for: device), let layer = makeLayerPipeline(on: device) else { return nil }
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess, let cache else { return nil }
        return FieldLayerPass(device: device, queue: queue, fieldPipeline: field, layerPipeline: layer, textureCache: cache)
    }

    /// A BGRA pixel buffer as a texture this pass reads or writes, in linear light. Keep the
    /// returned object alive until the GPU has finished with its texture.
    func texture(_ pixel: CVPixelBuffer) -> CVMetalTexture? {
        var made: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixel, nil, .bgra8Unorm_srgb,
                                                               CVPixelBufferGetWidth(pixel), CVPixelBufferGetHeight(pixel),
                                                               0, &made)
        return status == kCVReturnSuccess ? made : nil
    }

    /// Lets the cache drop the textures of buffers that are gone.
    func flush() {
        CVMetalTextureCacheFlush(textureCache, 0)
    }

    /// Draws the Field from `shown` and lays it over `picture`, placed by `placement` (all black
    /// without a picture), into `target`, on `buffer`. False when a pass could not be encoded.
    func encode(field shown: FieldMotion.Shown, over picture: MTLTexture?, placement: FieldLayerPlacement?,
                layer: FieldLayer, into target: MTLTexture, on buffer: MTLCommandBuffer) -> Bool {
        guard let field = fieldTexture(width: target.width, height: target.height) else { return false }
        let aspect = target.height > 0 ? Float(target.width) / Float(target.height) : 1
        guard MetalFieldRenderer.encode(shown, aspect: aspect, pipeline: fieldPipeline, into: field, on: buffer) else {
            return false
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        // The triangle covers every pixel, so what was there is never read.
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        let placed = picture == nil ? nil : placement
        var uniforms = LayerUniforms(placement: placed, layer: layer)
        encoder.setRenderPipelineState(layerPipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LayerUniforms>.stride, index: 0)
        // Without a picture the slot still holds a texture; the shader does not read it then.
        encoder.setFragmentTexture(placed == nil ? field : picture, index: 0)
        encoder.setFragmentTexture(field, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    private func fieldTexture(width: Int, height: Int) -> MTLTexture? {
        guard width > 0, height > 0 else { return nil }
        if let kept = canvas, kept.width == width, kept.height == height { return kept }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width,
                                                                  height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        canvas = device.makeTexture(descriptor: descriptor)
        return canvas
    }

    @MainActor
    private static func makeLayerPipeline(on device: MTLDevice) -> MTLRenderPipelineState? {
        if let cached = built, cached.device === device { return cached.pipeline }
        // As for the Field: only the log and the export's error say that this shader failed.
        DiagnosticLog.app.note("field layer: shader compiling")
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            DiagnosticLog.app.note("field layer: shader compile failed", error: error)
            return nil
        }
        guard let vertex = library.makeFunction(name: "layer_vertex"),
              let fragment = library.makeFunction(name: "layer_fragment") else {
            DiagnosticLog.app.note("field layer: shader entry point missing")
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            built = (device, pipeline)
            DiagnosticLog.app.note("field layer: shader ready")
            return pipeline
        } catch {
            DiagnosticLog.app.note("field layer: pipeline failed", error: error)
            return nil
        }
    }

    /// The numbers the layer shader reads. Mirrored by BYTE LAYOUT in the MSL `Layer` struct in
    /// `shaderSource` — twelve floats, no compiler checks the two agree: a field is only ever
    /// appended at the end, in both places, in one commit.
    private struct LayerUniforms {
        // From an output pixel back to the picture's: x' = a·x + c·y + tx, y' = b·x + d·y + ty.
        var a: Float = 1
        var b: Float = 0
        var c: Float = 0
        var d: Float = 1
        var tx: Float = 0
        var ty: Float = 0
        var sourceWidth: Float = 1
        var sourceHeight: Float = 1
        var hasPicture: Float = 0
        // `FieldLayer.coefficients`: the one formula.
        var video: Float = 1
        var field: Float = 0
        var product: Float = 0

        init(placement: FieldLayerPlacement?, layer: FieldLayer) {
            let k = layer.coefficients
            video = Float(k.video)
            field = Float(k.field)
            product = Float(k.product)
            guard let placement else { return }
            a = placement.a
            b = placement.b
            c = placement.c
            d = placement.d
            tx = placement.tx
            ty = placement.ty
            sourceWidth = placement.sourceWidth
            sourceHeight = placement.sourceHeight
            hasPicture = 1
        }
    }

    // MARK: - Shader (Metal Shading Language, compiled at runtime like the Field's)

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct LayerOut { float4 pos [[position]]; };
    struct Layer { float a; float b; float c; float d; float tx; float ty;
                   float sourceWidth; float sourceHeight; float hasPicture;
                   float video; float field; float product; };

    // A full-screen triangle from the vertex id: no vertex buffer.
    vertex LayerOut layer_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        LayerOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return o;
    }

    fragment float4 layer_fragment(LayerOut in [[stage_in]],
                                   constant Layer& u [[buffer(0)]],
                                   texture2d<float> picture [[texture(0)]],
                                   texture2d<float> field [[texture(1)]]) {
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        // Pixel coordinates, origin top left: AVFoundation's placement works in the same space.
        float2 p = in.pos.xy;
        float2 s = float2(u.a * p.x + u.c * p.y + u.tx, u.b * p.x + u.d * p.y + u.ty);
        float3 v = float3(0.0);
        if (u.hasPicture > 0.5 && s.x >= 0.0 && s.y >= 0.0 && s.x < u.sourceWidth && s.y < u.sourceHeight) {
            v = picture.sample(smooth, s / float2(u.sourceWidth, u.sourceHeight)).rgb;
        }
        float3 f = field.read(uint2(p)).rgb;
        float3 o = v * u.video + f * u.field + v * f * u.product;
        return float4(clamp(o, 0.0, 1.0), 1.0);
    }
    """
}

/// Where the picture sits in the output, as the layer pass reads it: the way from an output pixel
/// back to the picture's pixel — the inverse of the transform that places the picture — and the
/// picture's size. Pixel coordinates with the origin top left, as AVFoundation and Metal both use.
struct FieldLayerPlacement: Sendable, Equatable {
    let a: Float
    let b: Float
    let c: Float
    let d: Float
    let tx: Float
    let ty: Float
    let sourceWidth: Float
    let sourceHeight: Float

    /// For a `sourceWidth` × `sourceHeight` picture placed by `transform` (its own orientation and
    /// the fill or fit, as the export's layer instruction takes it). Nil when it places nothing.
    init?(placing transform: CGAffineTransform, sourceWidth: Double, sourceHeight: Double) {
        guard sourceWidth.isFinite, sourceHeight.isFinite, sourceWidth >= 1, sourceHeight >= 1 else { return nil }
        let determinant = Double(transform.a * transform.d - transform.b * transform.c)
        guard determinant.isFinite, Swift.abs(determinant) > 1e-12 else { return nil }
        let inverse = transform.inverted()
        let values = [inverse.a, inverse.b, inverse.c, inverse.d, inverse.tx, inverse.ty].map { Double($0) }
        guard values.allSatisfy(\.isFinite) else { return nil }
        a = Float(inverse.a)
        b = Float(inverse.b)
        c = Float(inverse.c)
        d = Float(inverse.d)
        tx = Float(inverse.tx)
        ty = Float(inverse.ty)
        self.sourceWidth = Float(sourceWidth)
        self.sourceHeight = Float(sourceHeight)
    }
}
