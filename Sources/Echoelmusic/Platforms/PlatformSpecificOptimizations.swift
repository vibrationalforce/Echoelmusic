import Foundation
import Combine

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(Accelerate)
import Accelerate
#endif

#if canImport(Metal)
import Metal
#endif

#if canImport(CoreML)
import CoreML
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// PLATFORM-SPECIFIC OPTIMIZATIONS FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// This module provides platform-optimized implementations for:
// • iOS/iPadOS: ARM64 NEON SIMD, Neural Engine, Metal
// • macOS: Apple Silicon + Intel (AVX2/SSE4.2), Metal
// • watchOS: Low-power optimizations, minimal footprint
// • tvOS: Living room audio, 4K visuals
// • visionOS: Spatial computing, hand/eye tracking
// • Android: Oboe audio, Vulkan graphics, ARM NEON
// • Windows: ASIO, DirectX, AVX2/AVX-512
// • Linux: JACK audio, Vulkan/OpenGL, SIMD
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Platform Optimizer Protocol

/// Protocol for platform-specific optimization strategies
public protocol PlatformOptimizer {
    /// Platform identifier
    var platform: PlatformType { get }

    /// Apply all optimizations
    func applyOptimizations()

    /// Get recommended audio settings
    func getAudioOptimizations() -> AudioOptimizations

    /// Get recommended visual settings
    func getVisualOptimizations() -> VisualOptimizations

    /// Get recommended processing settings
    func getProcessingOptimizations() -> ProcessingOptimizations
}

// MARK: - Optimization Configurations

public struct AudioOptimizations {
    public var sampleRate: Double = 48000
    public var bufferSize: Int = 256
    public var useSIMD: Bool = true
    public var useHardwareAcceleration: Bool = true
    public var enableSpatialProcessing: Bool = false
    public var maxConcurrentStreams: Int = 8
    public var preferredFormat: String = "Float32"

    // Platform-specific flags
    public var useNEON: Bool = false
    public var useAVX2: Bool = false
    public var useAVX512: Bool = false
    public var useAccelerate: Bool = false
    public var useOboe: Bool = false
    public var useASIO: Bool = false
    public var useJACK: Bool = false
}

public struct VisualOptimizations {
    public var targetFPS: Int = 60
    public var maxResolution: CGSize = CGSize(width: 1920, height: 1080)
    public var useGPU: Bool = true
    public var maxParticles: Int = 5000
    public var shadowQuality: Int = 2  // 0=off, 1=low, 2=medium, 3=high
    public var antiAliasing: Int = 2  // MSAA samples
    public var enableHDR: Bool = false
    public var enableBloom: Bool = true
    public var textureQuality: Float = 1.0

    // Platform-specific flags
    public var useMetal: Bool = false
    public var useVulkan: Bool = false
    public var useDirectX: Bool = false
    public var useOpenGL: Bool = false
    public var useMetalFX: Bool = false
}

public struct ProcessingOptimizations {
    public var useMultiThreading: Bool = true
    public var maxThreads: Int = 4
    public var useNeuralEngine: Bool = false
    public var useCoreML: Bool = false
    public var memoryLimit: Int = 512  // MB
    public var enablePowerOptimization: Bool = false
    public var batchProcessingSize: Int = 64

    // SIMD configuration
    public var simdWidth: Int = 4
    public var vectorizeLoops: Bool = true
    public var prefetchDistance: Int = 64
}

// MARK: - iOS Optimizer

#if os(iOS)
@MainActor
public final class iOSOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .iOS

    @Published public private(set) var isOptimized: Bool = false

    public init() {}

    public func applyOptimizations() {
        print("=== iOS Optimizations Applied ===")

        // Configure audio session
        configureAudioSession()

        // Enable Neural Engine for ML
        configureNeuralEngine()

        // Configure Metal for GPU
        configureMetal()

        isOptimized = true
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            // Request low latency
            try session.setCategory(.playAndRecord, mode: .default, options: [
                .allowBluetooth,
                .allowBluetoothA2DP,
                .defaultToSpeaker,
                .mixWithOthers
            ])

            // Optimal buffer duration for real-time audio
            try session.setPreferredIOBufferDuration(0.005)  // 5ms

            // High sample rate
            try session.setPreferredSampleRate(48000)

            try session.setActive(true)

            print("  Audio Session: 48kHz, 5ms buffer")
        } catch {
            print("  Audio Session Error: \(error)")
        }
    }

    private func configureNeuralEngine() {
        // Neural Engine is automatically used by CoreML when available
        print("  Neural Engine: Enabled (automatic)")
    }

    private func configureMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("  Metal: Not available")
            return
        }

        print("  Metal GPU: \(device.name)")
        print("  Metal Family: \(device.supportsFamily(.apple7) ? "Apple7+" : "Older")")
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 48000
        opts.bufferSize = 128  // Low latency on modern iOS
        opts.useSIMD = true
        opts.useNEON = true
        opts.useAccelerate = true
        opts.useHardwareAcceleration = true
        opts.enableSpatialProcessing = true
        opts.maxConcurrentStreams = 16

        // Adjust for device capability
        if ProcessInfo.processInfo.processorCount >= 6 {
            opts.bufferSize = 64  // Ultra-low latency on Pro devices
        }

        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.useMetal = true
        opts.enableHDR = true
        opts.enableBloom = true

        // Detect ProMotion
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        opts.targetFPS = maxFPS >= 120 ? 120 : 60

        // Scale based on device
        let scale = UIScreen.main.scale
        let screenSize = UIScreen.main.bounds.size
        opts.maxResolution = CGSize(
            width: screenSize.width * scale,
            height: screenSize.height * scale
        )

        // Adjust quality based on device
        if ProcessInfo.processInfo.processorCount >= 6 {
            opts.maxParticles = 10000
            opts.shadowQuality = 3
            opts.antiAliasing = 4
            opts.useMetalFX = true
        } else {
            opts.maxParticles = 3000
            opts.shadowQuality = 2
            opts.antiAliasing = 2
        }

        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = true
        opts.maxThreads = ProcessInfo.processInfo.activeProcessorCount
        opts.useNeuralEngine = true
        opts.useCoreML = true
        opts.simdWidth = 4  // NEON is 128-bit = 4x float
        opts.vectorizeLoops = true

        // Memory based on device RAM
        let ramGB = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        opts.memoryLimit = Int(ramGB * 128)  // ~12.5% of RAM

        // Power optimization on battery
        opts.enablePowerOptimization = ProcessInfo.processInfo.isLowPowerModeEnabled

        return opts
    }
}
#endif

// MARK: - macOS Optimizer

#if os(macOS)
@MainActor
public final class macOSOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .macOS

    @Published public private(set) var isOptimized: Bool = false
    @Published public private(set) var isAppleSilicon: Bool = false

    public init() {
        #if arch(arm64)
        isAppleSilicon = true
        #else
        isAppleSilicon = false
        #endif
    }

    public func applyOptimizations() {
        print("=== macOS Optimizations Applied ===")
        print("  Architecture: \(isAppleSilicon ? "Apple Silicon (ARM64)" : "Intel (x86_64)")")

        configureMetal()

        isOptimized = true
    }

    private func configureMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("  Metal: Not available")
            return
        }

        print("  Metal GPU: \(device.name)")

        // Check for Apple Silicon GPU families
        if device.supportsFamily(.apple7) {
            print("  GPU Family: Apple7+ (Pro/Max/Ultra)")
        } else if device.supportsFamily(.mac2) {
            print("  GPU Family: Mac2 (Intel Mac)")
        }
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 96000  // Higher sample rate on Mac
        opts.bufferSize = 64  // Ultra-low latency
        opts.useSIMD = true
        opts.useAccelerate = true
        opts.useHardwareAcceleration = true
        opts.enableSpatialProcessing = true
        opts.maxConcurrentStreams = 64  // Mac can handle more

        if isAppleSilicon {
            opts.useNEON = true
            opts.bufferSize = 32  // Even lower on Apple Silicon
        } else {
            opts.useAVX2 = true
        }

        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.useMetal = true
        opts.useMetalFX = isAppleSilicon
        opts.enableHDR = true
        opts.enableBloom = true
        opts.targetFPS = 120  // ProMotion displays
        opts.maxParticles = 50000  // Mac can handle many more
        opts.shadowQuality = 3
        opts.antiAliasing = 4

        // Get screen resolution
        if let screen = NSScreen.main {
            let size = screen.frame.size
            let scale = screen.backingScaleFactor
            opts.maxResolution = CGSize(
                width: size.width * scale,
                height: size.height * scale
            )
        }

        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = true
        opts.maxThreads = ProcessInfo.processInfo.activeProcessorCount
        opts.useNeuralEngine = isAppleSilicon
        opts.useCoreML = true
        opts.vectorizeLoops = true

        if isAppleSilicon {
            opts.simdWidth = 4  // NEON
        } else {
            opts.simdWidth = 8  // AVX2
        }

        // More memory on Mac
        let ramGB = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        opts.memoryLimit = Int(ramGB * 256)  // 25% of RAM

        return opts
    }
}
#endif

// MARK: - watchOS Optimizer

#if os(watchOS)
@MainActor
public final class watchOSOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .watchOS

    @Published public private(set) var isOptimized: Bool = false

    public init() {}

    public func applyOptimizations() {
        print("=== watchOS Optimizations Applied ===")
        print("  Focus: Low power, bio-data collection")

        isOptimized = true
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 44100  // Lower to save power
        opts.bufferSize = 512  // Higher latency is acceptable
        opts.useSIMD = true
        opts.useNEON = true
        opts.useAccelerate = true
        opts.maxConcurrentStreams = 2  // Minimal audio
        opts.enableSpatialProcessing = false  // Not needed on Watch

        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.useMetal = true
        opts.targetFPS = 30  // Power saving
        opts.maxResolution = CGSize(width: 396, height: 484)  // Series 9
        opts.maxParticles = 200  // Minimal
        opts.shadowQuality = 0  // Off
        opts.antiAliasing = 0
        opts.enableHDR = false
        opts.enableBloom = false
        opts.textureQuality = 0.5

        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = false  // Single-threaded to save power
        opts.maxThreads = 1
        opts.useNeuralEngine = true  // Efficient for ML
        opts.useCoreML = true
        opts.simdWidth = 4
        opts.memoryLimit = 64  // Very limited
        opts.enablePowerOptimization = true  // Always on Watch
        opts.batchProcessingSize = 16  // Small batches

        return opts
    }
}
#endif

// MARK: - tvOS Optimizer

#if os(tvOS)
@MainActor
public final class tvOSOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .tvOS

    @Published public private(set) var isOptimized: Bool = false

    public init() {}

    public func applyOptimizations() {
        print("=== tvOS Optimizations Applied ===")
        print("  Focus: Living room audio, 4K visuals")

        isOptimized = true
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 48000
        opts.bufferSize = 256
        opts.useSIMD = true
        opts.useNEON = true
        opts.useAccelerate = true
        opts.enableSpatialProcessing = true  // Spatial audio for living room
        opts.maxConcurrentStreams = 16

        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.useMetal = true
        opts.targetFPS = 60  // 4K@60
        opts.maxResolution = CGSize(width: 3840, height: 2160)  // 4K
        opts.maxParticles = 20000
        opts.shadowQuality = 3
        opts.antiAliasing = 4
        opts.enableHDR = true
        opts.enableBloom = true
        opts.textureQuality = 1.0

        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = true
        opts.maxThreads = ProcessInfo.processInfo.activeProcessorCount
        opts.useNeuralEngine = true
        opts.useCoreML = true
        opts.simdWidth = 4
        opts.memoryLimit = 1024  // Apple TV has decent RAM

        return opts
    }
}
#endif

// MARK: - visionOS Optimizer

#if os(visionOS)
@MainActor
public final class visionOSOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .visionOS

    @Published public private(set) var isOptimized: Bool = false

    public init() {}

    public func applyOptimizations() {
        print("=== visionOS Optimizations Applied ===")
        print("  Focus: Spatial computing, immersive audio")

        isOptimized = true
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 48000
        opts.bufferSize = 128
        opts.useSIMD = true
        opts.useNEON = true
        opts.useAccelerate = true
        opts.enableSpatialProcessing = true  // Critical for spatial audio
        opts.maxConcurrentStreams = 32  // Many spatial audio sources

        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.useMetal = true
        opts.useMetalFX = true
        opts.targetFPS = 90  // Vision Pro runs at 90Hz
        opts.maxResolution = CGSize(width: 3660, height: 3200)  // Per eye
        opts.maxParticles = 30000
        opts.shadowQuality = 3
        opts.antiAliasing = 4
        opts.enableHDR = true
        opts.enableBloom = true

        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = true
        opts.maxThreads = ProcessInfo.processInfo.activeProcessorCount
        opts.useNeuralEngine = true
        opts.useCoreML = true
        opts.simdWidth = 4
        opts.memoryLimit = 2048  // Vision Pro has significant RAM

        return opts
    }
}
#endif

// MARK: - Cross-Platform Optimizer Factory

@MainActor
public final class PlatformOptimizerFactory {

    /// Create the appropriate optimizer for the current platform
    public static func createOptimizer() -> any PlatformOptimizer {
        #if os(iOS)
        return iOSOptimizer()
        #elseif os(macOS)
        return macOSOptimizer()
        #elseif os(watchOS)
        return watchOSOptimizer()
        #elseif os(tvOS)
        return tvOSOptimizer()
        #elseif os(visionOS)
        return visionOSOptimizer()
        #else
        return GenericOptimizer()
        #endif
    }
}

// MARK: - Generic Optimizer (Fallback)

@MainActor
public final class GenericOptimizer: PlatformOptimizer, ObservableObject {

    public let platform: PlatformType = .unknown

    public init() {}

    public func applyOptimizations() {
        print("=== Generic Optimizations Applied ===")
    }

    public func getAudioOptimizations() -> AudioOptimizations {
        var opts = AudioOptimizations()
        opts.sampleRate = 44100
        opts.bufferSize = 512
        opts.useSIMD = true
        opts.maxConcurrentStreams = 4
        return opts
    }

    public func getVisualOptimizations() -> VisualOptimizations {
        var opts = VisualOptimizations()
        opts.targetFPS = 30
        opts.maxParticles = 1000
        opts.shadowQuality = 1
        return opts
    }

    public func getProcessingOptimizations() -> ProcessingOptimizations {
        var opts = ProcessingOptimizations()
        opts.useMultiThreading = true
        opts.maxThreads = 2
        opts.memoryLimit = 256
        return opts
    }
}

// MARK: - Android Bridge (JNI Interface)

/// Bridge to Android native code via JNI
/// Used when building for Android via Kotlin Multiplatform
public struct AndroidBridge {

    /// Audio optimizations for Android via Oboe
    public struct OboeConfig {
        public var sampleRate: Int32 = 48000
        public var framesPerBuffer: Int32 = 128
        public var channelCount: Int32 = 2
        public var performanceMode: Int32 = 12  // LowLatency
        public var sharingMode: Int32 = 0  // Exclusive
        public var deviceId: Int32 = 0  // Default device

        /// Convert to JNI-compatible format
        public func toJNI() -> [String: Any] {
            return [
                "sampleRate": sampleRate,
                "framesPerBuffer": framesPerBuffer,
                "channelCount": channelCount,
                "performanceMode": performanceMode,
                "sharingMode": sharingMode,
                "deviceId": deviceId
            ]
        }
    }

    /// Visual optimizations for Android via Vulkan
    public struct VulkanConfig {
        public var maxFrameRate: Int32 = 60
        public var msaaSamples: Int32 = 4
        public var enableHDR: Bool = false
        public var maxTextureSize: Int32 = 4096
        public var enableCompute: Bool = true

        public func toJNI() -> [String: Any] {
            return [
                "maxFrameRate": maxFrameRate,
                "msaaSamples": msaaSamples,
                "enableHDR": enableHDR,
                "maxTextureSize": maxTextureSize,
                "enableCompute": enableCompute
            ]
        }
    }

    /// Health Connect integration config
    public struct HealthConnectConfig {
        public var readHeartRate: Bool = true
        public var readHRV: Bool = true
        public var readSteps: Bool = false
        public var readSleep: Bool = false
        public var syncInterval: Int32 = 5  // seconds

        public func toJNI() -> [String: Any] {
            return [
                "readHeartRate": readHeartRate,
                "readHRV": readHRV,
                "readSteps": readSteps,
                "readSleep": readSleep,
                "syncInterval": syncInterval
            ]
        }
    }
}

// MARK: - Windows Bridge (VST3/CLAP Interface)

/// Bridge to Windows native code
/// Used for VST3 and CLAP plugin builds
public struct WindowsBridge {

    /// ASIO configuration for low-latency audio
    public struct ASIOConfig {
        public var sampleRate: Int = 48000
        public var bufferSize: Int = 64
        public var driverName: String = ""
        public var inputChannels: Int = 2
        public var outputChannels: Int = 2

        /// Convert to C++ compatible format
        public func toCPP() -> [String: Any] {
            return [
                "sampleRate": sampleRate,
                "bufferSize": bufferSize,
                "driverName": driverName,
                "inputChannels": inputChannels,
                "outputChannels": outputChannels
            ]
        }
    }

    /// DirectX configuration for graphics
    public struct DirectXConfig {
        public var version: Int = 12  // DirectX 12
        public var maxFrameRate: Int = 144
        public var enableRayTracing: Bool = false
        public var msaaSamples: Int = 4
        public var hdrEnabled: Bool = false

        public func toCPP() -> [String: Any] {
            return [
                "version": version,
                "maxFrameRate": maxFrameRate,
                "enableRayTracing": enableRayTracing,
                "msaaSamples": msaaSamples,
                "hdrEnabled": hdrEnabled
            ]
        }
    }

    /// SIMD configuration for Windows (AVX2/AVX-512)
    public struct WindowsSIMDConfig {
        public var useAVX2: Bool = true
        public var useAVX512: Bool = false
        public var useFMA: Bool = true
        public var vectorWidth: Int = 8  // AVX2 = 8 floats

        public func toCPP() -> [String: Any] {
            return [
                "useAVX2": useAVX2,
                "useAVX512": useAVX512,
                "useFMA": useFMA,
                "vectorWidth": vectorWidth
            ]
        }
    }
}

// MARK: - Linux Bridge (JACK/Vulkan Interface)

/// Bridge to Linux native code
/// Used for VST3 and CLAP plugin builds on Linux
public struct LinuxBridge {

    /// JACK configuration for professional audio
    public struct JACKConfig {
        public var sampleRate: Int = 48000
        public var bufferSize: Int = 128
        public var clientName: String = "Echoelmusic"
        public var autoConnect: Bool = true
        public var realtime: Bool = true

        public func toCPP() -> [String: Any] {
            return [
                "sampleRate": sampleRate,
                "bufferSize": bufferSize,
                "clientName": clientName,
                "autoConnect": autoConnect,
                "realtime": realtime
            ]
        }
    }

    /// PipeWire configuration (modern Linux audio)
    public struct PipeWireConfig {
        public var sampleRate: Int = 48000
        public var bufferSize: Int = 64
        public var nodeName: String = "Echoelmusic"
        public var quantumMin: Int = 32
        public var quantumMax: Int = 2048

        public func toCPP() -> [String: Any] {
            return [
                "sampleRate": sampleRate,
                "bufferSize": bufferSize,
                "nodeName": nodeName,
                "quantumMin": quantumMin,
                "quantumMax": quantumMax
            ]
        }
    }

    /// Vulkan configuration for Linux graphics
    public struct LinuxVulkanConfig {
        public var maxFrameRate: Int = 60
        public var msaaSamples: Int = 4
        public var enableCompute: Bool = true
        public var preferDiscreteGPU: Bool = true

        public func toCPP() -> [String: Any] {
            return [
                "maxFrameRate": maxFrameRate,
                "msaaSamples": msaaSamples,
                "enableCompute": enableCompute,
                "preferDiscreteGPU": preferDiscreteGPU
            ]
        }
    }
}

// MARK: - SIMD Optimization Utilities

/// Cross-platform SIMD utilities
public enum SIMDPlatformUtils {

    /// Detect best available SIMD instruction set
    public static func detectSIMDCapabilities() -> SIMDCapabilities {
        var caps = SIMDCapabilities()

        #if arch(arm64)
        caps.hasNEON = true
        caps.vectorWidth = 4  // 128-bit / 32-bit float
        caps.preferredAlignment = 16
        #elseif arch(x86_64)
        // On x86_64, we assume at least SSE4.2
        caps.hasSSE42 = true
        caps.vectorWidth = 4

        // AVX2 detection would require CPUID in production
        // For now, assume modern CPUs have AVX2
        caps.hasAVX2 = true
        caps.vectorWidth = 8  // 256-bit / 32-bit float
        caps.preferredAlignment = 32
        #endif

        return caps
    }

    public struct SIMDCapabilities {
        public var hasNEON: Bool = false
        public var hasSSE42: Bool = false
        public var hasAVX2: Bool = false
        public var hasAVX512: Bool = false
        public var vectorWidth: Int = 1  // floats per SIMD register
        public var preferredAlignment: Int = 4  // bytes
    }

    /// Get optimal loop unroll factor for current platform
    public static func optimalUnrollFactor() -> Int {
        let caps = detectSIMDCapabilities()
        if caps.hasAVX512 { return 16 }
        if caps.hasAVX2 { return 8 }
        if caps.hasNEON || caps.hasSSE42 { return 4 }
        return 1
    }

    /// Get optimal memory alignment for SIMD operations
    public static func optimalAlignment() -> Int {
        let caps = detectSIMDCapabilities()
        return caps.preferredAlignment
    }
}

// MARK: - Thermal Management

/// Cross-platform thermal management
@MainActor
public final class ThermalManager: ObservableObject {

    public static let shared = ThermalManager()

    @Published public private(set) var thermalState: ThermalState = .nominal
    @Published public private(set) var shouldThrottle: Bool = false

    private var cancellables = Set<AnyCancellable>()

    public enum ThermalState: String {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"

        public var throttleMultiplier: Float {
            switch self {
            case .nominal: return 1.0
            case .fair: return 0.9
            case .serious: return 0.7
            case .critical: return 0.5
            }
        }
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)

        updateThermalState()
    }

    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            thermalState = .nominal
            shouldThrottle = false
        case .fair:
            thermalState = .fair
            shouldThrottle = false
        case .serious:
            thermalState = .serious
            shouldThrottle = true
        case .critical:
            thermalState = .critical
            shouldThrottle = true
        @unknown default:
            thermalState = .nominal
            shouldThrottle = false
        }

        if shouldThrottle {
            print("Thermal throttling: \(thermalState.rawValue)")
        }
    }

    /// Get recommended settings for current thermal state
    public func getThrottledSettings() -> ThrottledSettings {
        ThrottledSettings(
            audioBufferMultiplier: 1.0 / thermalState.throttleMultiplier,
            fpsMultiplier: thermalState.throttleMultiplier,
            particleMultiplier: thermalState.throttleMultiplier,
            qualityMultiplier: thermalState.throttleMultiplier
        )
    }

    public struct ThrottledSettings {
        public let audioBufferMultiplier: Float
        public let fpsMultiplier: Float
        public let particleMultiplier: Float
        public let qualityMultiplier: Float
    }
}
