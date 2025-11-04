import Foundation

/// Cross-Platform Graphics API Abstraction
/// Supports: Metal (iOS/macOS), Vulkan (Android/Linux), DirectX 12 (Windows), WebGPU (Web)
///
/// Unified interface for:
/// - Shader compilation
/// - Texture management
/// - Render pipeline creation
/// - Compute operations
/// - Video encoding

// MARK: - Shader Language Abstraction

/// Unified shader representation
public struct UnifiedShader {
    public let name: String
    public let vertexSource: String
    public let fragmentSource: String
    public let computeSource: String?

    // Platform-specific compiled versions (lazy-loaded)
    private var metalLibrary: Any? // MTLLibrary
    private var vulkanModule: Any? // VkShaderModule
    private var dx12Bytecode: Data?
    private var webGPUModule: Any?

    public init(name: String, vertex: String, fragment: String, compute: String? = nil) {
        self.name = name
        self.vertexSource = vertex
        self.fragmentSource = fragment
        self.computeSource = compute
    }
}

/// Shader language converter
public final class ShaderTranspiler {

    /// Convert MSL (Metal Shading Language) to target platform
    public static func convert(msl: String, to target: GraphicsAPI) -> String {
        switch target {
        case .metal:
            return msl // No conversion needed

        case .vulkan:
            return convertMSLtoGLSL(msl) // Convert to SPIR-V via GLSL

        case .directX12:
            return convertMSLtoHLSL(msl)

        case .webGPU:
            return convertMSLtoWGSL(msl)

        case .openGL, .webGL:
            return convertMSLtoGLSL(msl)
        }
    }

    // MARK: - Conversion Helpers

    private static func convertMSLtoGLSL(_ msl: String) -> String {
        // Basic MSL -> GLSL conversion
        var glsl = msl

        // Type conversions
        glsl = glsl.replacingOccurrences(of: "float4", with: "vec4")
        glsl = glsl.replacingOccurrences(of: "float3", with: "vec3")
        glsl = glsl.replacingOccurrences(of: "float2", with: "vec2")
        glsl = glsl.replacingOccurrences(of: "half4", with: "vec4")
        glsl = glsl.replacingOccurrences(of: "half3", with: "vec3")
        glsl = glsl.replacingOccurrences(of: "half2", with: "vec2")

        // Function conversions
        glsl = glsl.replacingOccurrences(of: "metal::", with: "")

        // Attribute conversions
        glsl = glsl.replacingOccurrences(of: "[[position]]", with: "")
        glsl = glsl.replacingOccurrences(of: "[[color(0)]]", with: "")

        return glsl
    }

    private static func convertMSLtoHLSL(_ msl: String) -> String {
        // MSL -> HLSL conversion
        var hlsl = msl

        // Type conversions (MSL and HLSL are similar)
        hlsl = hlsl.replacingOccurrences(of: "half4", with: "float4")
        hlsl = hlsl.replacingOccurrences(of: "half3", with: "float3")
        hlsl = hlsl.replacingOccurrences(of: "half2", with: "float2")

        // Semantic conversions
        hlsl = hlsl.replacingOccurrences(of: "[[position]]", with: ": SV_Position")
        hlsl = hlsl.replacingOccurrences(of: "[[color(0)]]", with: ": SV_Target0")

        return hlsl
    }

    private static func convertMSLtoWGSL(_ msl: String) -> String {
        // MSL -> WGSL (WebGPU Shading Language) conversion
        var wgsl = msl

        // Type conversions
        wgsl = wgsl.replacingOccurrences(of: "float4", with: "vec4<f32>")
        wgsl = wgsl.replacingOccurrences(of: "float3", with: "vec3<f32>")
        wgsl = wgsl.replacingOccurrences(of: "float2", with: "vec2<f32>")

        // Attribute conversions
        wgsl = wgsl.replacingOccurrences(of: "[[position]]", with: "@builtin(position)")
        wgsl = wgsl.replacingOccurrences(of: "[[color(0)]]", with: "@location(0)")

        return wgsl
    }
}

// MARK: - Texture Abstraction

/// Platform-agnostic texture descriptor
public struct UnifiedTextureDescriptor {
    public let width: Int
    public let height: Int
    public let depth: Int
    public let format: TextureFormat
    public let usage: TextureUsage
    public let mipmapped: Bool

    public init(
        width: Int,
        height: Int,
        depth: Int = 1,
        format: TextureFormat = .rgba8,
        usage: TextureUsage = [.renderTarget, .sampled],
        mipmapped: Bool = false
    ) {
        self.width = width
        self.height = height
        self.depth = depth
        self.format = format
        self.usage = usage
        self.mipmapped = mipmapped
    }
}

public enum TextureFormat {
    case rgba8
    case rgba16Float
    case rgba32Float
    case bgra8
    case depth32Float
    case r8
    case r32Float

    #if os(iOS) || os(macOS) || os(visionOS)
    import Metal
    var metalFormat: MTLPixelFormat {
        switch self {
        case .rgba8: return .rgba8Unorm
        case .rgba16Float: return .rgba16Float
        case .rgba32Float: return .rgba32Float
        case .bgra8: return .bgra8Unorm
        case .depth32Float: return .depth32Float
        case .r8: return .r8Unorm
        case .r32Float: return .r32Float
        }
    }
    #endif
}

public struct TextureUsage: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sampled = TextureUsage(rawValue: 1 << 0)
    public static let renderTarget = TextureUsage(rawValue: 1 << 1)
    public static let storage = TextureUsage(rawValue: 1 << 2)
}

// MARK: - Render Pipeline Abstraction

/// Unified render pipeline descriptor
public struct UnifiedRenderPipelineDescriptor {
    public let vertexShader: String
    public let fragmentShader: String
    public let colorAttachments: [ColorAttachment]
    public let depthFormat: TextureFormat?
    public let sampleCount: Int

    public init(
        vertexShader: String,
        fragmentShader: String,
        colorAttachments: [ColorAttachment],
        depthFormat: TextureFormat? = nil,
        sampleCount: Int = 1
    ) {
        self.vertexShader = vertexShader
        self.fragmentShader = fragmentShader
        self.colorAttachments = colorAttachments
        self.depthFormat = depthFormat
        self.sampleCount = sampleCount
    }

    public struct ColorAttachment {
        public let format: TextureFormat
        public let blendingEnabled: Bool

        public init(format: TextureFormat, blendingEnabled: Bool = false) {
            self.format = format
            self.blendingEnabled = blendingEnabled
        }
    }
}

// MARK: - Graphics Device Protocol

/// Platform-agnostic graphics device
public protocol GraphicsDevice {
    var api: GraphicsAPI { get }
    var name: String { get }

    func createTexture(descriptor: UnifiedTextureDescriptor) -> GraphicsTexture?
    func createRenderPipeline(descriptor: UnifiedRenderPipelineDescriptor) -> GraphicsRenderPipeline?
    func createCommandQueue() -> GraphicsCommandQueue?
}

public protocol GraphicsTexture {
    var width: Int { get }
    var height: Int { get }
    func replace(region: TextureRegion, data: Data)
}

public struct TextureRegion {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public protocol GraphicsRenderPipeline {}

public protocol GraphicsCommandQueue {
    func makeCommandBuffer() -> GraphicsCommandBuffer?
}

public protocol GraphicsCommandBuffer {
    func commit()
    func waitUntilCompleted()
}

// MARK: - Metal Implementation

#if os(iOS) || os(macOS) || os(visionOS)
import Metal

public final class MetalDevice: GraphicsDevice {
    private let device: MTLDevice

    public var api: GraphicsAPI { .metal }
    public var name: String { device.name }

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
    }

    public func createTexture(descriptor: UnifiedTextureDescriptor) -> GraphicsTexture? {
        let mtlDescriptor = MTLTextureDescriptor()
        mtlDescriptor.width = descriptor.width
        mtlDescriptor.height = descriptor.height
        mtlDescriptor.depth = descriptor.depth
        mtlDescriptor.pixelFormat = descriptor.format.metalFormat
        mtlDescriptor.usage = []

        if descriptor.usage.contains(.sampled) {
            mtlDescriptor.usage.insert(.shaderRead)
        }
        if descriptor.usage.contains(.renderTarget) {
            mtlDescriptor.usage.insert(.renderTarget)
        }
        if descriptor.usage.contains(.storage) {
            mtlDescriptor.usage.insert(.shaderWrite)
        }

        if descriptor.mipmapped {
            mtlDescriptor.mipmapLevelCount = Int(log2(Float(max(descriptor.width, descriptor.height)))) + 1
        }

        guard let texture = device.makeTexture(descriptor: mtlDescriptor) else { return nil }
        return MetalTexture(texture: texture)
    }

    public func createRenderPipeline(descriptor: UnifiedRenderPipelineDescriptor) -> GraphicsRenderPipeline? {
        // Metal pipeline creation
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        // ... configure pipeline
        return nil // TODO: Implement
    }

    public func createCommandQueue() -> GraphicsCommandQueue? {
        guard let queue = device.makeCommandQueue() else { return nil }
        return MetalCommandQueue(queue: queue)
    }
}

private final class MetalTexture: GraphicsTexture {
    private let texture: MTLTexture

    var width: Int { texture.width }
    var height: Int { texture.height }

    init(texture: MTLTexture) {
        self.texture = texture
    }

    func replace(region: TextureRegion, data: Data) {
        let mtlRegion = MTLRegionMake2D(region.x, region.y, region.width, region.height)
        data.withUnsafeBytes { ptr in
            texture.replace(
                region: mtlRegion,
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: region.width * 4
            )
        }
    }
}

private final class MetalCommandQueue: GraphicsCommandQueue {
    private let queue: MTLCommandQueue

    init(queue: MTLCommandQueue) {
        self.queue = queue
    }

    func makeCommandBuffer() -> GraphicsCommandBuffer? {
        guard let buffer = queue.makeCommandBuffer() else { return nil }
        return MetalCommandBuffer(buffer: buffer)
    }
}

private final class MetalCommandBuffer: GraphicsCommandBuffer {
    private let buffer: MTLCommandBuffer

    init(buffer: MTLCommandBuffer) {
        self.buffer = buffer
    }

    func commit() {
        buffer.commit()
    }

    func waitUntilCompleted() {
        buffer.waitUntilCompleted()
    }
}
#endif

// MARK: - Graphics Device Factory

public final class GraphicsDeviceFactory {

    public static func createDevice() -> GraphicsDevice? {
        let hal = HardwareAbstractionLayer.shared

        switch hal.graphics.api {
        case .metal:
            #if os(iOS) || os(macOS) || os(visionOS)
            return MetalDevice()
            #else
            return nil
            #endif

        case .vulkan:
            // TODO: Implement VulkanDevice for Android/Linux
            return nil

        case .directX12:
            // TODO: Implement D3D12Device for Windows
            return nil

        case .webGPU:
            // TODO: Implement WebGPUDevice for web
            return nil

        case .openGL, .webGL:
            // TODO: Implement OpenGLDevice as fallback
            return nil
        }
    }
}

// MARK: - Compute Shader Support

/// Unified compute pipeline for GPU-accelerated effects
public struct UnifiedComputePipelineDescriptor {
    public let computeShader: String
    public let threadgroupSize: (width: Int, height: Int, depth: Int)

    public init(computeShader: String, threadgroupSize: (Int, Int, Int) = (8, 8, 1)) {
        self.computeShader = computeShader
        self.threadgroupSize = threadgroupSize
    }
}

public protocol ComputePipeline {
    func dispatch(
        threadgroups: (width: Int, height: Int, depth: Int),
        threadsPerThreadgroup: (width: Int, height: Int, depth: Int)
    )
}
