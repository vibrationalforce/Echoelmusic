import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION ORCHESTRATOR - UNIFIED PERFORMANCE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════
//
// Central coordination of all optimization systems
// Automatically adapts to system conditions and workload
//
// Systems managed:
// • UltraMath - SIMD/Accelerate operations
// • MetalOptimization - GPU pipelines and resources
// • MemoryOptimization - Allocation pools and caching
// • PerformanceMonitor - Real-time metrics
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Optimization Orchestrator

@MainActor
public final class OptimizationOrchestrator: ObservableObject {

    public static let shared = OptimizationOrchestrator()

    // MARK: - Published State

    @Published public private(set) var isOptimized: Bool = false
    @Published public private(set) var performanceLevel: PerformanceLevel = .balanced
    @Published public private(set) var currentMetrics: PerformanceMetrics = .init()
    @Published public private(set) var recommendations: [OptimizationRecommendation] = []

    // MARK: - Subsystems

    private let performanceMonitor = UltraPerformanceMonitor.shared
    private let mpsOptimizer = MPSOptimizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    private var config = OptimizationConfig.current

    // MARK: - Private State

    private var isMonitoring = false
    private var adaptiveThrottling = false
    private let signpostLog = OSLog(subsystem: "com.echoelmusic.optimization", category: "Orchestrator")

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    // MARK: - Public API

    /// Initialize all optimization systems
    public func initialize() async {
        os_signpost(.begin, log: signpostLog, name: "OptimizationInit")
        defer { os_signpost(.end, log: signpostLog, name: "OptimizationInit") }

        print("🚀 Initializing Echoelmusic Optimization Systems...")

        // Initialize Metal subsystems
        _ = MetalDeviceManager.shared
        print("   ✓ Metal Device: \(MetalDeviceManager.shared.capabilities.gpuFamily)")

        // Pre-warm shader cache
        await ShaderLibraryManager.shared.precompileCommonShaders()
        print("   ✓ Shader cache pre-warmed")

        // Initialize buffer pools
        _ = FloatBufferPool.shared
        _ = TexturePool.shared
        print("   ✓ Memory pools initialized")

        // Start monitoring
        startMonitoring()
        print("   ✓ Performance monitoring active")

        // Determine initial performance level
        await calibratePerformanceLevel()
        print("   ✓ Performance level: \(performanceLevel)")

        isOptimized = true
        print("✅ Optimization systems ready!")
    }

    /// Set performance level
    public func setPerformanceLevel(_ level: PerformanceLevel) {
        performanceLevel = level
        applyPerformanceLevel(level)
    }

    /// Get optimization status report
    public func statusReport() -> String {
        let pipelineStats = PipelineStateCache.shared.stats
        let textureStats = TexturePool.shared.stats
        let bufferStats = FloatBufferPool.shared.stats

        return """
        ══════════════════════════════════════════
        ECHOELMUSIC OPTIMIZATION STATUS
        ══════════════════════════════════════════

        📊 Performance Level: \(performanceLevel)

        🖥️ GPU (\(MetalDeviceManager.shared.capabilities.gpuFamily))
           Cached Compute Pipelines: \(pipelineStats.compute)
           Cached Render Pipelines: \(pipelineStats.render)
           Texture Pool: \(textureStats)

        💾 Memory
           Float Buffers: \(bufferStats)
           Pressure: \(MemoryPressureMonitor.shared.pressure.emoji)
           Used: \(String(format: "%.0f", MemoryPressureMonitor.shared.usedMemoryMB))MB

        ⏱️ Timing (avg)
           Audio Callback: \(String(format: "%.2f", performanceMonitor.audioCallbackTime))ms
           Video Frame: \(String(format: "%.2f", performanceMonitor.videoFrameTime))ms
           Bio Processing: \(String(format: "%.2f", performanceMonitor.bioProcessingTime))ms
           CPU Usage: \(String(format: "%.1f", performanceMonitor.cpuUsage))%

        🎯 Health: \(performanceMonitor.isHealthy ? "✅ Optimal" : "⚠️ Degraded")

        ══════════════════════════════════════════
        """
    }

    /// Perform optimization cleanup
    public func cleanup() {
        print("🧹 Performing optimization cleanup...")

        // Clear caches
        PipelineStateCache.shared.clearCache()
        TexturePool.shared.drain()
        ScratchBuffer.reset()

        print("   ✓ Caches cleared")
    }

    /// Analyze and provide recommendations
    public func analyzePerformance() -> [OptimizationRecommendation] {
        var recs: [OptimizationRecommendation] = []

        // Check audio latency
        if performanceMonitor.audioCallbackTime > 1.0 {
            recs.append(.init(
                category: .audio,
                severity: .warning,
                title: "High Audio Latency",
                description: "Audio callback taking \(String(format: "%.2f", performanceMonitor.audioCallbackTime))ms (target: <1ms)",
                action: "Consider reducing buffer size or disabling effects"
            ))
        }

        // Check video frame time
        if performanceMonitor.videoFrameTime > 8.0 {
            recs.append(.init(
                category: .video,
                severity: .warning,
                title: "Frame Time Too High",
                description: "Video frame taking \(String(format: "%.2f", performanceMonitor.videoFrameTime))ms (target: <8ms for 120fps)",
                action: "Reduce visual complexity or resolution"
            ))
        }

        // Check memory
        let memoryMB = performanceMonitor.memoryUsageMB
        if memoryMB > 800 {
            recs.append(.init(
                category: .memory,
                severity: memoryMB > 1000 ? .critical : .warning,
                title: "High Memory Usage",
                description: "Using \(String(format: "%.0f", memoryMB))MB (recommended: <500MB)",
                action: "Close unused sessions or reduce history depth"
            ))
        }

        // Check CPU
        if performanceMonitor.cpuUsage > 80 {
            recs.append(.init(
                category: .cpu,
                severity: .warning,
                title: "High CPU Usage",
                description: "CPU at \(String(format: "%.0f", performanceMonitor.cpuUsage))%",
                action: "Reduce active processing or lower quality settings"
            ))
        }

        recommendations = recs
        return recs
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Monitor memory pressure
        Task { @MainActor in
            MemoryPressureMonitor.shared.$pressure
                .sink { [weak self] pressure in
                    self?.handleMemoryPressure(pressure)
                }
                .store(in: &cancellables)
        }
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Periodic performance check
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
                _ = self?.analyzePerformance()
            }
        }
    }

    private func updateMetrics() {
        currentMetrics = PerformanceMetrics(
            audioLatencyMS: performanceMonitor.audioCallbackTime,
            videoFrameTimeMS: performanceMonitor.videoFrameTime,
            bioProcessingTimeMS: performanceMonitor.bioProcessingTime,
            memoryUsageMB: performanceMonitor.memoryUsageMB,
            cpuUsage: performanceMonitor.cpuUsage,
            isHealthy: performanceMonitor.isHealthy
        )

        // Auto-adapt if enabled
        if adaptiveThrottling && !currentMetrics.isHealthy {
            adaptPerformance()
        }
    }

    private func calibratePerformanceLevel() async {
        let capabilities = MetalDeviceManager.shared.capabilities

        // Determine optimal level based on GPU
        if capabilities.gpuFamily.contains("M2") || capabilities.gpuFamily.contains("Apple8") {
            performanceLevel = .maximum
        } else if capabilities.gpuFamily.contains("M1") || capabilities.gpuFamily.contains("Apple7") {
            performanceLevel = .high
        } else if capabilities.gpuFamily.contains("Apple6") {
            performanceLevel = .balanced
        } else {
            performanceLevel = .efficiency
        }

        applyPerformanceLevel(performanceLevel)
    }

    private func applyPerformanceLevel(_ level: PerformanceLevel) {
        switch level {
        case .maximum:
            config.useParallelProcessing = true
            config.useSIMD = true
            config.parallelThreshold = 256
            config.targetAudioLatency = 0.5
            config.targetVideoFrameTime = 4.0 // 240fps capable

        case .high:
            config.useParallelProcessing = true
            config.useSIMD = true
            config.parallelThreshold = 512
            config.targetAudioLatency = 1.0
            config.targetVideoFrameTime = 8.0 // 120fps

        case .balanced:
            config.useParallelProcessing = true
            config.useSIMD = true
            config.parallelThreshold = 1024
            config.targetAudioLatency = 2.0
            config.targetVideoFrameTime = 16.0 // 60fps

        case .efficiency:
            config.useParallelProcessing = false
            config.useSIMD = true
            config.parallelThreshold = 2048
            config.targetAudioLatency = 5.0
            config.targetVideoFrameTime = 33.0 // 30fps
        }

        OptimizationConfig.current = config
    }

    private func handleMemoryPressure(_ pressure: MemoryPressureMonitor.MemoryPressure) {
        switch pressure {
        case .critical:
            // Emergency measures
            cleanup()
            if performanceLevel != .efficiency {
                setPerformanceLevel(.efficiency)
            }

        case .warning:
            // Reduce caches
            TexturePool.shared.drain()

        case .normal:
            break
        }
    }

    private func adaptPerformance() {
        // Automatically reduce performance level if struggling
        switch performanceLevel {
        case .maximum:
            setPerformanceLevel(.high)
        case .high:
            setPerformanceLevel(.balanced)
        case .balanced:
            setPerformanceLevel(.efficiency)
        case .efficiency:
            break // Already at minimum
        }
    }
}

// MARK: - Performance Level

public enum PerformanceLevel: String, CaseIterable {
    case maximum = "Maximum"
    case high = "High"
    case balanced = "Balanced"
    case efficiency = "Efficiency"

    public var description: String {
        switch self {
        case .maximum: return "Maximum performance, highest quality"
        case .high: return "High performance for capable devices"
        case .balanced: return "Balanced performance and efficiency"
        case .efficiency: return "Power saving mode"
        }
    }

    public var emoji: String {
        switch self {
        case .maximum: return "🚀"
        case .high: return "⚡"
        case .balanced: return "⚖️"
        case .efficiency: return "🔋"
        }
    }
}

// MARK: - Performance Metrics

public struct PerformanceMetrics {
    public var audioLatencyMS: Double = 0
    public var videoFrameTimeMS: Double = 0
    public var bioProcessingTimeMS: Double = 0
    public var memoryUsageMB: Double = 0
    public var cpuUsage: Double = 0
    public var isHealthy: Bool = true
}

// MARK: - Optimization Recommendation

public struct OptimizationRecommendation: Identifiable {
    public let id = UUID()
    public let category: Category
    public let severity: Severity
    public let title: String
    public let description: String
    public let action: String

    public enum Category {
        case audio, video, memory, cpu, gpu

        public var emoji: String {
            switch self {
            case .audio: return "🔊"
            case .video: return "🎬"
            case .memory: return "💾"
            case .cpu: return "🖥️"
            case .gpu: return "🎮"
            }
        }
    }

    public enum Severity {
        case info, warning, critical

        public var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .critical: return "🔴"
            }
        }
    }
}

// MARK: - Optimized Processing Helpers

/// Convenient wrappers for optimized operations
public enum OptimizedProcessing {

    /// Process audio buffer with optimal SIMD operations
    @inlinable
    public static func processAudio(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        gain: Float
    ) {
        var g = gain
        vDSP_vsmul(input, 1, &g, output, 1, vDSP_Length(count))
    }

    /// Mix two audio buffers
    @inlinable
    public static func mixAudio(
        buffer1: UnsafePointer<Float>,
        buffer2: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        mix: Float
    ) {
        // output = buffer1 * (1-mix) + buffer2 * mix
        var mixA = 1.0 - mix
        var mixB = mix
        vDSP_vsmsma(buffer1, 1, &mixA, buffer2, 1, &mixB, output, 1, vDSP_Length(count))
    }

    /// Apply soft clipping using tanh
    @inlinable
    public static func softClip(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        drive: Float
    ) {
        var d = drive
        vDSP_vsmul(buffer, 1, &d, buffer, 1, vDSP_Length(count))

        var c = Int32(count)
        vvtanhf(buffer, buffer, &c)

        var invDrive = 1.0 / drive
        vDSP_vsmul(buffer, 1, &invDrive, buffer, 1, vDSP_Length(count))
    }

    /// Fast FFT-based spectrum analysis
    public static func computeSpectrum(
        input: [Float],
        magnitudes: inout [Float]
    ) {
        let count = input.count
        guard count.isPowerOfTwo else { return }

        let log2n = vDSP_Length(log2(Float(count)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realp = [Float](repeating: 0, count: count / 2)
        var imagp = [Float](repeating: 0, count: count / 2)

        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        input.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: count / 2) { ptr in
                vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(count / 2))
            }
        }

        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Compute magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(count / 2))

        // Normalize
        var scale = 1.0 / Float(count)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(count / 2))
    }
}

// MARK: - Int Extension

private extension Int {
    var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
}

// MARK: - Optimization Bootstrap

/// Call this at app startup
public func initializeOptimizations() async {
    await OptimizationOrchestrator.shared.initialize()
}
