// LazyShaderCompiler.swift
// Echoelmusic - Lazy Shader Compilation & Caching
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Compiles Metal shaders on-demand and caches compiled pipelines.
// Reduces app launch time and memory usage.
//
// Supported Platforms: iOS 13+, macOS 10.15+, tvOS 13+, visionOS 1+
// Created 2026-01-16

#if canImport(Metal)
import Metal
import Foundation

// MARK: - Shader Identifier

/// Unique identifier for a shader configuration
public struct ShaderIdentifier: Hashable, Sendable {
    public let name: String
    public let variant: String
    public let options: [String: String]

    public init(name: String, variant: String = "default", options: [String: String] = [:]) {
        self.name = name
        self.variant = variant
        self.options = options
    }

    public var cacheKey: String {
        let optionsString = options.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(name)_\(variant)_\(optionsString)"
    }
}

// MARK: - Lazy Shader Compiler

/// Lazy shader compilation manager
///
/// Features:
/// - On-demand shader compilation
/// - Pipeline state caching
/// - Background compilation queue
/// - Compile-time validation
/// - Shader variant management
///
/// Usage:
/// ```swift
/// let compiler = LazyShaderCompiler(device: device)
///
/// // Get or compile shader
/// let pipeline = try await compiler.getPipeline(
///     for: ShaderIdentifier(name: "CoherenceVisual", variant: "high")
/// )
///
/// // Pre-warm commonly used shaders
/// await compiler.prewarm(shaders: [
///     ShaderIdentifier(name: "BasicVisual"),
///     ShaderIdentifier(name: "ParticleSystem")
/// ])
/// ```
@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public actor LazyShaderCompiler {

    // MARK: - Types

    /// Compiled pipeline info
    public struct CompiledPipeline {
        public let pipelineState: MTLRenderPipelineState
        public let identifier: ShaderIdentifier
        public let compiledAt: Date
        public let compilationTime: TimeInterval
    }

    /// Compilation error
    public enum CompilationError: Error, LocalizedError {
        case deviceNotAvailable
        case libraryNotFound
        case functionNotFound(name: String)
        case pipelineCreationFailed(Error)
        case invalidConfiguration(String)

        public var errorDescription: String? {
            switch self {
            case .deviceNotAvailable:
                return "Metal device not available"
            case .libraryNotFound:
                return "Metal shader library not found"
            case .functionNotFound(let name):
                return "Shader function '\(name)' not found"
            case .pipelineCreationFailed(let error):
                return "Pipeline creation failed: \(error.localizedDescription)"
            case .invalidConfiguration(let message):
                return "Invalid shader configuration: \(message)"
            }
        }
    }

    // MARK: - Properties

    private let device: MTLDevice
    private let library: MTLLibrary
    private var pipelineCache: [String: CompiledPipeline] = [:]
    private var pendingCompilations: [String: Task<CompiledPipeline, Error>] = [:]

    // MARK: - Statistics

    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var totalCompilationTime: TimeInterval = 0

    // MARK: - Initialization

    public init(device: MTLDevice) throws {
        self.device = device

        guard let library = device.makeDefaultLibrary() else {
            throw CompilationError.libraryNotFound
        }
        self.library = library
    }

    // MARK: - Pipeline Access

    /// Get or compile a render pipeline
    public func getPipeline(for identifier: ShaderIdentifier) async throws -> MTLRenderPipelineState {
        let key = identifier.cacheKey

        // Check cache
        if let cached = pipelineCache[key] {
            cacheHits += 1
            return cached.pipelineState
        }

        // Check if compilation is already in progress
        if let pending = pendingCompilations[key] {
            let result = try await pending.value
            return result.pipelineState
        }

        // Start compilation
        cacheMisses += 1

        let task = Task<CompiledPipeline, Error> {
            try await compilePipeline(for: identifier)
        }

        pendingCompilations[key] = task

        do {
            let result = try await task.value
            pipelineCache[key] = result
            pendingCompilations.removeValue(forKey: key)
            return result.pipelineState
        } catch {
            pendingCompilations.removeValue(forKey: key)
            throw error
        }
    }

    /// Get compute pipeline
    public func getComputePipeline(functionName: String) async throws -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: functionName) else {
            throw CompilationError.functionNotFound(name: functionName)
        }

        return try await device.makeComputePipelineState(function: function)
    }

    // MARK: - Compilation

    private func compilePipeline(for identifier: ShaderIdentifier) async throws -> CompiledPipeline {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get vertex and fragment functions
        let vertexName = identifier.options["vertexFunction"] ?? "\(identifier.name)Vertex"
        let fragmentName = identifier.options["fragmentFunction"] ?? "\(identifier.name)Fragment"

        guard let vertexFunction = library.makeFunction(name: vertexName) else {
            throw CompilationError.functionNotFound(name: vertexName)
        }

        guard let fragmentFunction = library.makeFunction(name: fragmentName) else {
            throw CompilationError.functionNotFound(name: fragmentName)
        }

        // Create pipeline descriptor
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Apply variant-specific settings
        applyVariantSettings(to: descriptor, variant: identifier.variant)

        // Apply custom options
        applyCustomOptions(to: descriptor, options: identifier.options)

        // Create pipeline state
        let pipelineState: MTLRenderPipelineState
        do {
            pipelineState = try await device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw CompilationError.pipelineCreationFailed(error)
        }

        let compilationTime = CFAbsoluteTimeGetCurrent() - startTime
        totalCompilationTime += compilationTime

        log.video("LazyShaderCompiler: Compiled '\(identifier.name)' in \(String(format: "%.2f", compilationTime * 1000))ms")

        return CompiledPipeline(
            pipelineState: pipelineState,
            identifier: identifier,
            compiledAt: Date(),
            compilationTime: compilationTime
        )
    }

    private func applyVariantSettings(to descriptor: MTLRenderPipelineDescriptor, variant: String) {
        switch variant {
        case "high":
            descriptor.sampleCount = 4 // MSAA
        case "low":
            descriptor.sampleCount = 1
        case "additive":
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        case "alpha":
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        default:
            break
        }
    }

    private func applyCustomOptions(to descriptor: MTLRenderPipelineDescriptor, options: [String: String]) {
        if let pixelFormat = options["pixelFormat"] {
            switch pixelFormat {
            case "rgba16float":
                descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            case "rgba32float":
                descriptor.colorAttachments[0].pixelFormat = .rgba32Float
            default:
                break
            }
        }
    }

    // MARK: - Pre-warming

    /// Pre-compile shaders in background
    public func prewarm(shaders: [ShaderIdentifier]) async {
        await withTaskGroup(of: Void.self) { group in
            for identifier in shaders {
                group.addTask {
                    do {
                        _ = try await self.getPipeline(for: identifier)
                    } catch {
                        log.warning("LazyShaderCompiler: Failed to prewarm '\(identifier.name)': \(error)")
                    }
                }
            }
        }

        log.info("LazyShaderCompiler: Prewarmed \(shaders.count) shaders")
    }

    /// Pre-compile common shader variants
    public func prewarmCommonShaders() async {
        let commonShaders: [ShaderIdentifier] = [
            ShaderIdentifier(name: "BasicVisual", variant: "alpha"),
            ShaderIdentifier(name: "ParticleSystem", variant: "additive"),
            ShaderIdentifier(name: "CoherenceField", variant: "high"),
            ShaderIdentifier(name: "SacredGeometry", variant: "alpha"),
            ShaderIdentifier(name: "QuantumWave", variant: "additive"),
            ShaderIdentifier(name: "BiofeedbackPulse", variant: "alpha")
        ]

        await prewarm(shaders: commonShaders)
    }

    // MARK: - Cache Management

    /// Clear compiled pipeline cache
    public func clearCache() {
        pipelineCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }

    /// Remove specific pipeline from cache
    public func invalidate(_ identifier: ShaderIdentifier) {
        pipelineCache.removeValue(forKey: identifier.cacheKey)
    }

    /// Get cache statistics
    public var statistics: CacheStatistics {
        CacheStatistics(
            cachedPipelines: pipelineCache.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: cacheHits + cacheMisses > 0
                ? Double(cacheHits) / Double(cacheHits + cacheMisses)
                : 1.0,
            totalCompilationTime: totalCompilationTime
        )
    }

    /// Cache statistics
    public struct CacheStatistics: Sendable {
        public let cachedPipelines: Int
        public let cacheHits: Int
        public let cacheMisses: Int
        public let hitRate: Double
        public let totalCompilationTime: TimeInterval
    }
}

// MARK: - Predefined Shader Identifiers

public extension ShaderIdentifier {

    // MARK: - Bio-Reactive Shaders

    static let coherenceField = ShaderIdentifier(name: "CoherenceField", variant: "high")
    static let biofeedbackPulse = ShaderIdentifier(name: "BiofeedbackPulse", variant: "alpha")
    static let heartbeatRipple = ShaderIdentifier(name: "HeartbeatRipple", variant: "additive")
    static let breathingWave = ShaderIdentifier(name: "BreathingWave", variant: "alpha")

    // MARK: - Quantum Shaders

    static let quantumWave = ShaderIdentifier(name: "QuantumWave", variant: "additive")
    static let superposition = ShaderIdentifier(name: "Superposition", variant: "additive")
    static let entanglement = ShaderIdentifier(name: "Entanglement", variant: "alpha")
    static let waveCollapse = ShaderIdentifier(name: "WaveCollapse", variant: "high")

    // MARK: - Sacred Geometry

    static let flowerOfLife = ShaderIdentifier(name: "FlowerOfLife", variant: "alpha")
    static let metatronsCube = ShaderIdentifier(name: "MetatronsCube", variant: "alpha")
    static let sriYantra = ShaderIdentifier(name: "SriYantra", variant: "alpha")
    static let torus = ShaderIdentifier(name: "Torus", variant: "high")

    // MARK: - Particle Systems

    static let particleSystem = ShaderIdentifier(name: "ParticleSystem", variant: "additive")
    static let starField = ShaderIdentifier(name: "StarField", variant: "additive")
    static let dustCloud = ShaderIdentifier(name: "DustCloud", variant: "alpha")

    // MARK: - Effects

    static let bloom = ShaderIdentifier(name: "Bloom", variant: "additive")
    static let blur = ShaderIdentifier(name: "GaussianBlur")
    static let chromaticAberration = ShaderIdentifier(name: "ChromaticAberration")
    static let vignette = ShaderIdentifier(name: "Vignette", variant: "alpha")
}

// MARK: - Shader Library Extension

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension LazyShaderCompiler {

    /// Check if a shader function exists
    func hasFunction(named name: String) -> Bool {
        library.makeFunction(name: name) != nil
    }

    /// List all available function names
    var availableFunctions: [String] {
        library.functionNames
    }
}

#endif // canImport(Metal)

// MARK: - Non-Metal Stub

#if !canImport(Metal)

public struct ShaderIdentifier: Hashable, Sendable {
    public let name: String
    public let variant: String
    public let options: [String: String]

    public init(name: String, variant: String = "default", options: [String: String] = [:]) {
        self.name = name
        self.variant = variant
        self.options = options
    }
}

public final class LazyShaderCompiler {
    public init(device: Any) throws {
        throw NSError(domain: "Metal", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
    }
}

#endif
