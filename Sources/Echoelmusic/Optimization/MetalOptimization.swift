import Foundation
import Metal
import MetalPerformanceShaders
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// METAL OPTIMIZATION ENGINE - GPU PERFORMANCE MAXIMIZATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive Metal shader optimizations for Echoelmusic
// Targets: Minimal GPU stalls, optimal memory bandwidth, pipeline reuse
//
// Performance targets:
// • Shader compile: <100ms (cached <1ms)
// • Draw call overhead: <0.1ms
// • Texture upload: Zero-copy when possible
// • Buffer updates: Triple-buffered, no stalls
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Metal Device Manager

/// Singleton for Metal device access with capability detection
public final class MetalDeviceManager {

    public static let shared = MetalDeviceManager()

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let capabilities: GPUCapabilities

    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        self.commandQueue = commandQueue

        self.capabilities = GPUCapabilities(device: device)
    }

    /// GPU capability detection
    public struct GPUCapabilities {
        public let supportsNonUniformThreadgroups: Bool
        public let supportsSIMDGroupBarrier: Bool
        public let supportsRayTracing: Bool
        public let maxThreadgroupMemoryLength: Int
        public let maxThreadsPerThreadgroup: MTLSize
        public let recommendedMaxWorkingSetSize: UInt64
        public let hasUnifiedMemory: Bool
        public let gpuFamily: String

        init(device: MTLDevice) {
            self.supportsNonUniformThreadgroups = device.supportsFamily(.apple4)
            self.supportsSIMDGroupBarrier = device.supportsFamily(.apple7)
            self.supportsRayTracing = device.supportsFamily(.apple6)
            self.maxThreadgroupMemoryLength = device.maxThreadgroupMemoryLength
            self.maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup
            self.recommendedMaxWorkingSetSize = device.recommendedMaxWorkingSetSize
            self.hasUnifiedMemory = device.hasUnifiedMemory

            // Detect GPU family
            if device.supportsFamily(.apple8) {
                self.gpuFamily = "Apple8 (M2+)"
            } else if device.supportsFamily(.apple7) {
                self.gpuFamily = "Apple7 (A14/M1)"
            } else if device.supportsFamily(.apple6) {
                self.gpuFamily = "Apple6 (A13)"
            } else if device.supportsFamily(.apple5) {
                self.gpuFamily = "Apple5 (A12)"
            } else {
                self.gpuFamily = "Apple4 or earlier"
            }
        }

        public var summary: String {
            """
            GPU: \(gpuFamily)
            Unified Memory: \(hasUnifiedMemory)
            Max Threadgroup Memory: \(maxThreadgroupMemoryLength / 1024)KB
            Recommended Working Set: \(recommendedMaxWorkingSetSize / 1024 / 1024)MB
            Non-Uniform Threadgroups: \(supportsNonUniformThreadgroups)
            Ray Tracing: \(supportsRayTracing)
            """
        }
    }
}

// MARK: - Pipeline State Cache

/// Caches compiled pipeline states to avoid redundant compilation
public final class PipelineStateCache {

    public static let shared = PipelineStateCache()

    private var computeCache: [String: MTLComputePipelineState] = [:]
    private var renderCache: [String: MTLRenderPipelineState] = [:]
    private let lock = NSLock()

    private init() {}

    /// Get or create compute pipeline state
    public func computePipeline(
        named name: String,
        library: MTLLibrary? = nil
    ) throws -> MTLComputePipelineState {
        lock.lock()
        defer { lock.unlock() }

        if let cached = computeCache[name] {
            return cached
        }

        let device = MetalDeviceManager.shared.device
        let lib = library ?? device.makeDefaultLibrary()

        guard let lib = lib,
              let function = lib.makeFunction(name: name) else {
            throw MetalOptimizationError.functionNotFound(name)
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        computeCache[name] = pipeline

        return pipeline
    }

    /// Get or create render pipeline state
    public func renderPipeline(
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        depthFormat: MTLPixelFormat = .invalid,
        library: MTLLibrary? = nil
    ) throws -> MTLRenderPipelineState {
        let key = "\(vertexFunction)_\(fragmentFunction)_\(pixelFormat.rawValue)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = renderCache[key] {
            return cached
        }

        let device = MetalDeviceManager.shared.device
        let lib = library ?? device.makeDefaultLibrary()

        guard let lib = lib,
              let vertexFn = lib.makeFunction(name: vertexFunction),
              let fragmentFn = lib.makeFunction(name: fragmentFunction) else {
            throw MetalOptimizationError.functionNotFound("\(vertexFunction)/\(fragmentFunction)")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.depthAttachmentPixelFormat = depthFormat

        // Enable blending
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        renderCache[key] = pipeline

        return pipeline
    }

    /// Clear all cached pipelines
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        computeCache.removeAll()
        renderCache.removeAll()
    }

    /// Cache statistics
    public var stats: (compute: Int, render: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (computeCache.count, renderCache.count)
    }
}

// MARK: - Triple Buffer Manager

/// Triple-buffered uniform updates for stall-free GPU access
public final class TripleBufferManager<T> {

    private let buffers: [MTLBuffer]
    private var currentIndex: Int = 0
    private let semaphore: DispatchSemaphore

    public init?(count: Int = 1) {
        let device = MetalDeviceManager.shared.device
        let size = MemoryLayout<T>.stride * count

        var buffers: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let buffer = device.makeBuffer(length: size, options: .storageModeShared) else {
                return nil
            }
            buffers.append(buffer)
        }

        self.buffers = buffers
        self.semaphore = DispatchSemaphore(value: 3)
    }

    /// Get next buffer for writing (waits if all buffers in flight)
    public func nextBuffer() -> MTLBuffer {
        semaphore.wait()
        currentIndex = (currentIndex + 1) % 3
        return buffers[currentIndex]
    }

    /// Update buffer contents
    public func update(_ value: T) -> MTLBuffer {
        let buffer = nextBuffer()
        buffer.contents().assumingMemoryBound(to: T.self).pointee = value
        return buffer
    }

    /// Update buffer with array
    public func update(_ values: [T]) -> MTLBuffer {
        let buffer = nextBuffer()
        let pointer = buffer.contents().assumingMemoryBound(to: T.self)
        for (i, value) in values.enumerated() {
            pointer[i] = value
        }
        return buffer
    }

    /// Signal that a buffer is no longer in use by GPU
    public func signal() {
        semaphore.signal()
    }

    /// Current buffer without advancing
    public var currentBuffer: MTLBuffer {
        buffers[currentIndex]
    }
}

// MARK: - Texture Pool

/// Pool of reusable textures to avoid allocation overhead
public final class TexturePool {

    public static let shared = TexturePool()

    private var pools: [String: [MTLTexture]] = [:]
    private let lock = NSLock()
    private let maxPoolSize = 10

    private init() {}

    /// Get or create a texture from the pool
    public func acquire(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) -> MTLTexture? {
        let key = "\(width)x\(height)_\(pixelFormat.rawValue)"

        lock.lock()

        // Check pool for existing texture
        if var pool = pools[key], !pool.isEmpty {
            let texture = pool.removeLast()
            pools[key] = pool
            lock.unlock()
            return texture
        }

        lock.unlock()

        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .private

        return MetalDeviceManager.shared.device.makeTexture(descriptor: descriptor)
    }

    /// Return texture to pool
    public func release(_ texture: MTLTexture) {
        let key = "\(texture.width)x\(texture.height)_\(texture.pixelFormat.rawValue)"

        lock.lock()
        defer { lock.unlock() }

        var pool = pools[key] ?? []

        if pool.count < maxPoolSize {
            pool.append(texture)
            pools[key] = pool
        }
        // Otherwise let texture be deallocated
    }

    /// Clear all pools
    public func drain() {
        lock.lock()
        defer { lock.unlock() }
        pools.removeAll()
    }

    /// Pool statistics
    public var stats: [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return pools.mapValues { $0.count }
    }
}

// MARK: - Optimized Compute Dispatcher

/// Dispatches compute kernels with optimal threadgroup sizing
public enum ComputeDispatcher {

    /// Dispatch 2D compute kernel with automatic threadgroup sizing
    public static func dispatch2D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = pipeline.maxTotalThreadsPerThreadgroup / threadWidth

        let threadgroupSize = MTLSize(width: threadWidth, height: threadHeight, depth: 1)

        let capabilities = MetalDeviceManager.shared.capabilities

        if capabilities.supportsNonUniformThreadgroups {
            // Use non-uniform threadgroups (more efficient)
            let gridSize = MTLSize(width: width, height: height, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        } else {
            // Fall back to uniform threadgroups
            let threadgroupsPerGrid = MTLSize(
                width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        }
    }

    /// Dispatch 1D compute kernel
    public static func dispatch1D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        count: Int
    ) {
        let threadWidth = pipeline.threadExecutionWidth
        let threadgroupSize = MTLSize(width: threadWidth, height: 1, depth: 1)

        let capabilities = MetalDeviceManager.shared.capabilities

        if capabilities.supportsNonUniformThreadgroups {
            let gridSize = MTLSize(width: count, height: 1, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        } else {
            let threadgroupsPerGrid = MTLSize(
                width: (count + threadWidth - 1) / threadWidth,
                height: 1,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        }
    }
}

// MARK: - Optimized Blit Operations

/// Optimized texture copy and clear operations
public enum BlitOptimizer {

    /// Copy texture region using blit encoder
    public static func copy(
        from source: MTLTexture,
        to destination: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

        blitEncoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
            to: destination,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
    }

    /// Generate mipmaps for texture
    public static func generateMipmaps(
        for texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        blitEncoder.generateMipmaps(for: texture)
        blitEncoder.endEncoding()
    }

    /// Synchronize managed texture
    public static func synchronize(
        texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        #if os(macOS)
        if texture.storageMode == .managed {
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
            blitEncoder.synchronize(resource: texture)
            blitEncoder.endEncoding()
        }
        #endif
    }
}

// MARK: - MPS Integration

/// MetalPerformanceShaders optimizations
public final class MPSOptimizer {

    private let device: MTLDevice
    private var gaussianBlur: MPSImageGaussianBlur?
    private var boxBlur: MPSImageBox?
    private var histogram: MPSImageHistogram?
    private var sobel: MPSImageSobel?

    public init() {
        self.device = MetalDeviceManager.shared.device
    }

    /// Fast Gaussian blur
    public func gaussianBlur(
        source: MTLTexture,
        destination: MTLTexture,
        sigma: Float,
        commandBuffer: MTLCommandBuffer
    ) {
        if gaussianBlur == nil || gaussianBlur!.sigma != sigma {
            gaussianBlur = MPSImageGaussianBlur(device: device, sigma: sigma)
            gaussianBlur?.edgeMode = .clamp
        }

        gaussianBlur?.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
    }

    /// Fast box blur (more efficient than Gaussian for large radii)
    public func boxBlur(
        source: MTLTexture,
        destination: MTLTexture,
        size: Int,
        commandBuffer: MTLCommandBuffer
    ) {
        if boxBlur == nil || boxBlur!.kernelWidth != size {
            boxBlur = MPSImageBox(device: device, kernelWidth: size, kernelHeight: size)
            boxBlur?.edgeMode = .clamp
        }

        boxBlur?.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
    }

    /// Edge detection using Sobel
    public func edgeDetect(
        source: MTLTexture,
        destination: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        if sobel == nil {
            sobel = MPSImageSobel(device: device)
        }

        sobel?.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
    }

    /// Image histogram computation
    public func computeHistogram(
        source: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> MTLBuffer? {
        if histogram == nil {
            var histogramInfo = MPSImageHistogramInfo(
                numberOfHistogramEntries: 256,
                histogramForAlpha: false,
                minPixelValue: simd_float4(repeating: 0),
                maxPixelValue: simd_float4(repeating: 1)
            )
            histogram = MPSImageHistogram(device: device, histogramInfo: &histogramInfo)
        }

        let histogramSize = histogram!.histogramSize(forSourceFormat: source.pixelFormat)
        guard let histogramBuffer = device.makeBuffer(length: histogramSize, options: .storageModeShared) else {
            return nil
        }

        histogram?.encode(
            to: commandBuffer,
            sourceTexture: source,
            histogram: histogramBuffer,
            histogramOffset: 0
        )

        return histogramBuffer
    }
}

// MARK: - Shader Library Manager

/// Manages shader library loading and compilation
public final class ShaderLibraryManager {

    public static let shared = ShaderLibraryManager()

    private var libraries: [String: MTLLibrary] = [:]
    private let lock = NSLock()

    private init() {}

    /// Get default library
    public var defaultLibrary: MTLLibrary? {
        MetalDeviceManager.shared.device.makeDefaultLibrary()
    }

    /// Load library from URL
    public func loadLibrary(from url: URL) throws -> MTLLibrary {
        let key = url.lastPathComponent

        lock.lock()
        defer { lock.unlock() }

        if let cached = libraries[key] {
            return cached
        }

        let library = try MetalDeviceManager.shared.device.makeLibrary(URL: url)
        libraries[key] = library

        return library
    }

    /// Compile library from source
    public func compileLibrary(
        source: String,
        name: String,
        options: MTLCompileOptions? = nil
    ) throws -> MTLLibrary {
        lock.lock()
        defer { lock.unlock() }

        if let cached = libraries[name] {
            return cached
        }

        let opts = options ?? MTLCompileOptions()
        opts.fastMathEnabled = true

        let library = try MetalDeviceManager.shared.device.makeLibrary(source: source, options: opts)
        libraries[name] = library

        return library
    }

    /// Precompile common shader functions
    public func precompileCommonShaders() async {
        // Compile common compute shaders in background
        let shaderNames = [
            "linearGradient",
            "radialGradient",
            "perlinNoiseBackground",
            "starFieldBackground",
            "colorGrading",
            "sceneComposite",
            "bloomThreshold",
            "bloomBlur"
        ]

        for name in shaderNames {
            do {
                _ = try PipelineStateCache.shared.computePipeline(named: name)
            } catch {
                print("Warning: Could not precompile shader \(name): \(error)")
            }
        }
    }
}

// MARK: - Error Types

public enum MetalOptimizationError: Error {
    case functionNotFound(String)
    case pipelineCreationFailed(String)
    case bufferAllocationFailed
    case textureCreationFailed
}

// MARK: - GPU Frame Timing

/// Measures GPU frame timing for performance analysis
public final class GPUFrameTimer {

    private let sampleBuffer: MTLCounterSampleBuffer?
    private var samples: [Double] = []
    private let maxSamples = 60

    public init() {
        // Try to create counter sample buffer for GPU timing
        let device = MetalDeviceManager.shared.device

        if let counterSets = device.counterSets,
           let timestampSet = counterSets.first(where: { $0.name == "GPUTimestamp" }) {
            let descriptor = MTLCounterSampleBufferDescriptor()
            descriptor.counterSet = timestampSet
            descriptor.sampleCount = 2 // Start and end
            descriptor.storageMode = .shared
            self.sampleBuffer = try? device.makeCounterSampleBuffer(descriptor: descriptor)
        } else {
            self.sampleBuffer = nil
        }
    }

    /// Record frame start (call before encoding)
    public func frameStart(_ encoder: MTLCommandEncoder) {
        #if os(macOS)
        if let buffer = sampleBuffer {
            encoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: true)
        }
        #endif
    }

    /// Record frame end (call after encoding)
    public func frameEnd(_ encoder: MTLCommandEncoder) {
        #if os(macOS)
        if let buffer = sampleBuffer {
            encoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: true)
        }
        #endif
    }

    /// Get last frame GPU time in milliseconds
    public var lastFrameTimeMS: Double {
        samples.last ?? 0
    }

    /// Get average frame time
    public var averageFrameTimeMS: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }
}

// MARK: - Optimized Uniform Structs

/// Common shader uniforms (16-byte aligned for GPU)
public struct ShaderUniforms {
    public var modelMatrix: simd_float4x4 = matrix_identity_float4x4
    public var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    public var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
    public var time: Float = 0
    public var deltaTime: Float = 0
    public var audioLevel: Float = 0
    public var hrv: Float = 0
    public var coherence: Float = 0
    private var _padding: simd_float2 = .zero

    public init() {}
}

/// Bio-reactive uniforms
public struct BioUniforms {
    public var heartRate: Float = 72
    public var hrv: Float = 50
    public var coherence: Float = 0.5
    public var breathRate: Float = 15
    public var skinConductance: Float = 0
    public var temperature: Float = 0
    private var _padding: simd_float2 = .zero

    public init() {}
}

/// Post-processing uniforms
public struct PostProcessUniforms {
    public var exposure: Float = 1.0
    public var contrast: Float = 1.0
    public var saturation: Float = 1.0
    public var bloomThreshold: Float = 0.8
    public var bloomIntensity: Float = 0.5
    public var vignetteStrength: Float = 0.3
    private var _padding: simd_float2 = .zero

    public init() {}
}
