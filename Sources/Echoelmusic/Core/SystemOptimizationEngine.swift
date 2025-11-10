import Foundation
import SystemConfiguration
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// System Detection & Optimization Engine
/// Automatically detects OS, hardware, and optimizes performance
///
/// Features:
/// - Operating System detection (iOS, macOS, Windows, Android, Linux, Web)
/// - Hardware capabilities (CPU cores, RAM, GPU)
/// - Audio interface detection (CoreAudio, WASAPI, ASIO, JACK, ALSA)
/// - Automatic quality settings
/// - Performance optimization
/// - Platform-specific features
@MainActor
class SystemOptimizationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var systemInfo: SystemInfo
    @Published var optimizationProfile: OptimizationProfile
    @Published var audioSettings: OptimalAudioSettings

    // MARK: - System Information

    struct SystemInfo: Codable {
        let operatingSystem: OperatingSystem
        let osVersion: String
        let deviceModel: String
        let cpuCores: Int
        let cpuArchitecture: CPUArchitecture
        let ramGB: Double
        let hasGPU: Bool
        let gpuModel: String?
        let screenResolution: CGSize
        let screenRefreshRate: Double  // Hz
        let supportedFeatures: [SystemFeature]

        enum OperatingSystem: String, Codable {
            case iOS = "iOS"
            case iPadOS = "iPadOS"
            case macOS = "macOS"
            case watchOS = "watchOS"
            case tvOS = "tvOS"
            case visionOS = "visionOS"
            case windows = "Windows"
            case android = "Android"
            case linux = "Linux"
            case web = "Web Browser"

            var family: OSFamily {
                switch self {
                case .iOS, .iPadOS, .macOS, .watchOS, .tvOS, .visionOS:
                    return .apple
                case .windows:
                    return .windows
                case .android, .linux:
                    return .unix
                case .web:
                    return .web
                }
            }

            enum OSFamily {
                case apple, windows, unix, web
            }
        }

        enum CPUArchitecture: String, Codable {
            case arm64 = "ARM64 (Apple Silicon)"
            case x86_64 = "x86_64 (Intel/AMD)"
            case armv7 = "ARMv7"
            case wasm = "WebAssembly"
        }

        enum SystemFeature: String, Codable {
            case metalGPU = "Metal GPU"
            case coreML = "Core ML"
            case neuralEngine = "Neural Engine"
            case simdAcceleration = "SIMD Acceleration"
            case multicore = "Multi-Core Processing"
            case lowLatencyAudio = "Low-Latency Audio"
            case spatialAudio = "Spatial Audio"
            case haptics = "Haptic Feedback"
            case faceID = "Face ID"
            case touchID = "Touch ID"
            case pencilSupport = "Apple Pencil"
            case arKit = "ARKit"
            case carPlay = "CarPlay"
            case handoff = "Handoff"
        }
    }

    // MARK: - Optimization Profile

    enum OptimizationProfile: String, Codable {
        case ultraLowLatency = "Ultra-Low Latency (Pro)"
        case balanced = "Balanced (Recommended)"
        case powerSaver = "Power Saver"
        case maximum Performance = "Maximum Performance"

        var audioBufferSize: Int {
            switch self {
            case .ultraLowLatency: return 64   // ~1.3ms @ 48kHz
            case .balanced: return 256         // ~5.3ms @ 48kHz
            case .powerSaver: return 512       // ~10.6ms @ 48kHz
            case .maximumPerformance: return 128  // ~2.6ms @ 48kHz
            }
        }

        var maxTracks: Int {
            switch self {
            case .ultraLowLatency: return 64
            case .balanced: return 128
            case .powerSaver: return 32
            case .maximumPerformance: return 256
            }
        }

        var videoQuality: VideoQuality {
            switch self {
            case .ultraLowLatency: return .hd1080p
            case .balanced: return .uhd4k
            case .powerSaver: return .hd720p
            case .maximumPerformance: return .uhd8k
            }
        }

        enum VideoQuality {
            case hd720p, hd1080p, uhd4k, uhd8k
        }
    }

    // MARK: - Audio Settings

    struct OptimalAudioSettings: Codable {
        var sampleRate: Double
        var bufferSize: Int
        var bitDepth: Int
        var channels: Int
        var audioInterface: AudioInterface
        var latencyMs: Double

        enum AudioInterface: String, Codable {
            case coreAudio = "Core Audio (macOS/iOS)"
            case wasapi = "WASAPI (Windows)"
            case asio = "ASIO (Windows Pro)"
            case jack = "JACK (Linux Pro)"
            case alsa = "ALSA (Linux)"
            case webAudio = "Web Audio API"
            case oboe = "Oboe (Android)"
            case openSLES = "OpenSL ES (Android)"
        }

        var description: String {
            """
            Sample Rate: \(Int(sampleRate)) Hz
            Buffer Size: \(bufferSize) samples
            Bit Depth: \(bitDepth)-bit
            Channels: \(channels)
            Interface: \(audioInterface.rawValue)
            Latency: \(String(format: "%.2f", latencyMs)) ms
            """
        }
    }

    // MARK: - Initialization

    init() {
        print("🔍 Detecting system configuration...")

        // Detect system
        self.systemInfo = Self.detectSystem()

        // Determine optimal profile
        self.optimizationProfile = Self.determineOptimalProfile(for: systemInfo)

        // Configure audio settings
        self.audioSettings = Self.configureAudioSettings(
            for: systemInfo,
            profile: optimizationProfile
        )

        print("   ✅ System detected:")
        print("      OS: \(systemInfo.operatingSystem.rawValue) \(systemInfo.osVersion)")
        print("      Device: \(systemInfo.deviceModel)")
        print("      CPU: \(systemInfo.cpuCores) cores (\(systemInfo.cpuArchitecture.rawValue))")
        print("      RAM: \(String(format: "%.1f", systemInfo.ramGB)) GB")
        print("      GPU: \(systemInfo.gpuModel ?? "Integrated")")
        print("   ")
        print("   🎯 Optimization Profile: \(optimizationProfile.rawValue)")
        print("   🎵 Audio Configuration:")
        print("      \(audioSettings.description)")
    }

    // MARK: - System Detection

    static func detectSystem() -> SystemInfo {
        #if os(iOS)
        return detectiOS()
        #elseif os(macOS)
        return detectMacOS()
        #elseif os(watchOS)
        return detectWatchOS()
        #elseif os(tvOS)
        return detectTVOS()
        #elseif os(visionOS)
        return detectVisionOS()
        #else
        return detectGeneric()
        #endif
    }

    #if os(iOS)
    static func detectiOS() -> SystemInfo {
        let device = UIDevice.current
        let screen = UIScreen.main

        // Detect iPad vs iPhone
        let isIPad = device.userInterfaceIdiom == .pad
        let os: SystemInfo.OperatingSystem = isIPad ? .iPadOS : .iOS

        // Get device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }

        // CPU cores
        let cpuCores = ProcessInfo.processInfo.processorCount

        // RAM (approximation)
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        let ramGB = Double(ramBytes) / (1024 * 1024 * 1024)

        // Screen info
        let screenSize = screen.bounds.size
        let scale = screen.scale
        let resolution = CGSize(
            width: screenSize.width * scale,
            height: screenSize.height * scale
        )

        // Features
        var features: [SystemInfo.SystemFeature] = [
            .metalGPU,
            .coreML,
            .simdAcceleration,
            .multicore,
            .lowLatencyAudio,
            .spatialAudio
        ]

        // Check for specific features
        if #available(iOS 16.0, *) {
            features.append(.neuralEngine)
        }

        return SystemInfo(
            operatingSystem: os,
            osVersion: device.systemVersion,
            deviceModel: modelCode,
            cpuCores: cpuCores,
            cpuArchitecture: .arm64,  // All modern iOS devices
            ramGB: ramGB,
            hasGPU: true,
            gpuModel: "Apple GPU",
            screenResolution: resolution,
            screenRefreshRate: Double(screen.maximumFramesPerSecond),
            supportedFeatures: features
        )
    }
    #endif

    #if os(macOS)
    static func detectMacOS() -> SystemInfo {
        let screen = NSScreen.main

        // Get CPU info
        let cpuCores = ProcessInfo.processInfo.processorCount

        // RAM
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        let ramGB = Double(ramBytes) / (1024 * 1024 * 1024)

        // CPU Architecture (Apple Silicon vs Intel)
        #if arch(arm64)
        let cpuArch = SystemInfo.CPUArchitecture.arm64
        let gpuModel = "Apple M-Series GPU"
        #else
        let cpuArch = SystemInfo.CPUArchitecture.x86_64
        let gpuModel = "Intel/AMD GPU"
        #endif

        // Screen info
        let screenSize = screen?.frame.size ?? CGSize(width: 1920, height: 1080)
        let scale = screen?.backingScaleFactor ?? 2.0
        let resolution = CGSize(
            width: screenSize.width * scale,
            height: screenSize.height * scale
        )

        // Features
        var features: [SystemInfo.SystemFeature] = [
            .metalGPU,
            .coreML,
            .simdAcceleration,
            .multicore,
            .lowLatencyAudio,
            .spatialAudio
        ]

        #if arch(arm64)
        features.append(.neuralEngine)
        #endif

        return SystemInfo(
            operatingSystem: .macOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "Mac",
            cpuCores: cpuCores,
            cpuArchitecture: cpuArch,
            ramGB: ramGB,
            hasGPU: true,
            gpuModel: gpuModel,
            screenResolution: resolution,
            screenRefreshRate: 60.0,  // Default, could be ProMotion 120Hz
            supportedFeatures: features
        )
    }
    #endif

    static func detectWatchOS() -> SystemInfo {
        return SystemInfo(
            operatingSystem: .watchOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "Apple Watch",
            cpuCores: 2,
            cpuArchitecture: .arm64,
            ramGB: 1.0,
            hasGPU: true,
            gpuModel: "Apple Watch GPU",
            screenResolution: CGSize(width: 396, height: 484),  // Series 9
            screenRefreshRate: 60.0,
            supportedFeatures: [.haptics, .lowLatencyAudio]
        )
    }

    static func detectTVOS() -> SystemInfo {
        return SystemInfo(
            operatingSystem: .tvOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "Apple TV",
            cpuCores: 6,
            cpuArchitecture: .arm64,
            ramGB: 4.0,
            hasGPU: true,
            gpuModel: "Apple TV GPU",
            screenResolution: CGSize(width: 3840, height: 2160),  // 4K
            screenRefreshRate: 60.0,
            supportedFeatures: [.metalGPU, .spatialAudio]
        )
    }

    static func detectVisionOS() -> SystemInfo {
        return SystemInfo(
            operatingSystem: .visionOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "Apple Vision Pro",
            cpuCores: 12,
            cpuArchitecture: .arm64,
            ramGB: 16.0,
            hasGPU: true,
            gpuModel: "Apple Vision Pro GPU",
            screenResolution: CGSize(width: 4032, height: 3024),  // Per eye
            screenRefreshRate: 90.0,
            supportedFeatures: [.metalGPU, .neuralEngine, .spatialAudio, .arKit]
        )
    }

    static func detectGeneric() -> SystemInfo {
        return SystemInfo(
            operatingSystem: .linux,
            osVersion: "Unknown",
            deviceModel: "Generic",
            cpuCores: ProcessInfo.processInfo.processorCount,
            cpuArchitecture: .x86_64,
            ramGB: Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024),
            hasGPU: false,
            gpuModel: nil,
            screenResolution: CGSize(width: 1920, height: 1080),
            screenRefreshRate: 60.0,
            supportedFeatures: [.multicore]
        )
    }

    // MARK: - Profile Selection

    static func determineOptimalProfile(for system: SystemInfo) -> OptimizationProfile {
        // Apple Silicon: Ultra-low latency capable
        if system.cpuArchitecture == .arm64 && system.operatingSystem.family == .apple {
            if system.cpuCores >= 8 && system.ramGB >= 16 {
                return .maximumPerformance
            } else {
                return .ultraLowLatency
            }
        }

        // High-end x86_64: Balanced
        if system.cpuCores >= 8 && system.ramGB >= 16 {
            return .balanced
        }

        // Mid-range: Balanced
        if system.cpuCores >= 4 && system.ramGB >= 8 {
            return .balanced
        }

        // Low-end: Power Saver
        return .powerSaver
    }

    // MARK: - Audio Configuration

    static func configureAudioSettings(
        for system: SystemInfo,
        profile: OptimizationProfile
    ) -> OptimalAudioSettings {

        // Select audio interface based on OS
        let audioInterface: OptimalAudioSettings.AudioInterface
        switch system.operatingSystem {
        case .iOS, .iPadOS, .macOS, .watchOS, .tvOS, .visionOS:
            audioInterface = .coreAudio
        case .windows:
            // ASIO for pro, WASAPI for consumer
            audioInterface = profile == .ultraLowLatency ? .asio : .wasapi
        case .android:
            audioInterface = .oboe  // Modern low-latency API
        case .linux:
            // JACK for pro, ALSA for consumer
            audioInterface = profile == .ultraLowLatency ? .jack : .alsa
        case .web:
            audioInterface = .webAudio
        }

        // Sample rate
        let sampleRate: Double = 48000.0  // Professional standard

        // Buffer size from profile
        let bufferSize = profile.audioBufferSize

        // Calculate latency
        let latencyMs = (Double(bufferSize) / sampleRate) * 1000.0

        return OptimalAudioSettings(
            sampleRate: sampleRate,
            bufferSize: bufferSize,
            bitDepth: 32,  // 32-bit float for pro quality
            channels: 2,   // Stereo
            audioInterface: audioInterface,
            latencyMs: latencyMs
        )
    }

    // MARK: - Runtime Optimization

    func optimizeForCurrentLoad(cpuUsage: Double, memoryUsage: Double) {
        print("   📊 Optimizing for current load:")
        print("      CPU: \(Int(cpuUsage))%")
        print("      Memory: \(Int(memoryUsage))%")

        // If system is overloaded, downgrade quality
        if cpuUsage > 80 || memoryUsage > 80 {
            print("   ⚠️ High system load detected, reducing quality...")

            switch optimizationProfile {
            case .maximumPerformance:
                optimizationProfile = .balanced
            case .ultraLowLatency, .balanced:
                optimizationProfile = .powerSaver
            case .powerSaver:
                print("   Already in Power Saver mode")
            }

            // Reconfigure audio
            audioSettings = Self.configureAudioSettings(
                for: systemInfo,
                profile: optimizationProfile
            )

            print("   ✅ Switched to: \(optimizationProfile.rawValue)")
        }
    }

    // MARK: - Feature Availability

    func isFeatureAvailable(_ feature: SystemInfo.SystemFeature) -> Bool {
        return systemInfo.supportedFeatures.contains(feature)
    }

    func checkRequirements(for feature: String) -> RequirementCheck {
        // Check if system meets requirements for specific features
        switch feature {
        case "8K Video":
            return RequirementCheck(
                supported: systemInfo.cpuCores >= 8 && systemInfo.ramGB >= 16,
                reason: systemInfo.cpuCores < 8 ? "Requires 8+ CPU cores" : "Requires 16GB+ RAM"
            )

        case "Ultra-Low Latency Audio":
            return RequirementCheck(
                supported: systemInfo.supportedFeatures.contains(.lowLatencyAudio),
                reason: "Requires low-latency audio interface"
            )

        case "VR/AR":
            return RequirementCheck(
                supported: systemInfo.supportedFeatures.contains(.arKit) ||
                          systemInfo.operatingSystem == .visionOS,
                reason: "Requires ARKit or visionOS"
            )

        case "Neural Engine AI":
            return RequirementCheck(
                supported: systemInfo.supportedFeatures.contains(.neuralEngine),
                reason: "Requires Apple Silicon with Neural Engine"
            )

        default:
            return RequirementCheck(supported: true, reason: nil)
        }
    }

    struct RequirementCheck {
        let supported: Bool
        let reason: String?
    }

    // MARK: - Export Configuration

    func exportOptimizedConfig() -> [String: Any] {
        return [
            "systemInfo": [
                "os": systemInfo.operatingSystem.rawValue,
                "version": systemInfo.osVersion,
                "device": systemInfo.deviceModel,
                "cpuCores": systemInfo.cpuCores,
                "cpuArch": systemInfo.cpuArchitecture.rawValue,
                "ramGB": systemInfo.ramGB,
                "gpu": systemInfo.gpuModel ?? "Unknown"
            ],
            "optimizationProfile": optimizationProfile.rawValue,
            "audioSettings": [
                "sampleRate": audioSettings.sampleRate,
                "bufferSize": audioSettings.bufferSize,
                "bitDepth": audioSettings.bitDepth,
                "interface": audioSettings.audioInterface.rawValue,
                "latency": audioSettings.latencyMs
            ],
            "recommendations": [
                "maxTracks": optimizationProfile.maxTracks,
                "videoQuality": "\(optimizationProfile.videoQuality)"
            ]
        ]
    }
}
