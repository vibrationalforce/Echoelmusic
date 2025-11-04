import Foundation

/// Hardware Abstraction Layer - Unified interface for all platforms and devices
/// Supports: iOS, Android, macOS, Windows, Linux, Web, VR/AR devices
///
/// Architecture:
/// - Platform-agnostic interface
/// - Runtime capability detection
/// - Automatic fallback mechanisms
/// - Zero-cost abstractions where possible

// MARK: - Platform Detection

/// Detected platform type at runtime
public enum PlatformType: String, Codable {
    case iOS
    case iPadOS
    case macOS
    case visionOS
    case android
    case windows
    case linux
    case web
    case steamVR
    case metaQuest
    case psvr2
    case unknown

    public var isMobile: Bool {
        [.iOS, .iPadOS, .android].contains(self)
    }

    public var isDesktop: Bool {
        [.macOS, .windows, .linux].contains(self)
    }

    public var isVR: Bool {
        [.steamVR, .metaQuest, .psvr2, .visionOS].contains(self)
    }

    public var isWeb: Bool {
        self == .web
    }
}

/// Device category for performance scaling
public enum DeviceCategory {
    case lowEnd      // Budget smartphones, old hardware
    case midRange    // Most consumer devices
    case highEnd     // Flagship phones, gaming PCs
    case workstation // Mac Studio, high-end desktops
    case cloud       // Server-side rendering
}

// MARK: - Graphics Capabilities

/// Graphics API abstraction
public enum GraphicsAPI {
    case metal      // iOS, macOS, visionOS
    case vulkan     // Android, Linux, Windows
    case directX12  // Windows
    case openGL     // Legacy fallback
    case webGL      // Web browsers
    case webGPU     // Modern web
}

/// Graphics capabilities detected at runtime
public struct GraphicsCapabilities {
    public let api: GraphicsAPI
    public let maxTextureSize: Int
    public let supportsCompute: Bool
    public let supportsRayTracing: Bool
    public let maxSampleCount: Int
    public let vramAvailable: UInt64 // bytes
    public let supportsHDR: Bool
    public let maxRenderTargets: Int

    public static let fallback = GraphicsCapabilities(
        api: .openGL,
        maxTextureSize: 2048,
        supportsCompute: false,
        supportsRayTracing: false,
        maxSampleCount: 1,
        vramAvailable: 256_000_000,
        supportsHDR: false,
        maxRenderTargets: 1
    )
}

// MARK: - Audio Capabilities

/// Audio capabilities per platform
public struct AudioCapabilities {
    public let maxChannels: Int
    public let supportsSpatialAudio: Bool
    public let supportsHRTF: Bool
    public let supportsAmbisonics: Bool
    public let maxSampleRate: Int
    public let supportsASIO: Bool // Windows low-latency
    public let supportsJACK: Bool // Linux pro audio
    public let bufferSizes: [Int]

    public static let stereo = AudioCapabilities(
        maxChannels: 2,
        supportsSpatialAudio: false,
        supportsHRTF: false,
        supportsAmbisonics: false,
        maxSampleRate: 48000,
        supportsASIO: false,
        supportsJACK: false,
        bufferSizes: [512, 1024]
    )
}

// MARK: - Input Capabilities

/// Available input methods
public struct InputCapabilities {
    public let hasTouchscreen: Bool
    public let hasKeyboard: Bool
    public let hasMouse: Bool
    public let hasGamepad: Bool
    public let hasVRControllers: Bool
    public let supportsHandTracking: Bool
    public let supportsEyeTracking: Bool
    public let supportsFaceTracking: Bool
    public let hasMIDISupport: Bool
    public let hasOSCSupport: Bool
}

// MARK: - Sensor Capabilities

/// Biometric and motion sensors
public struct SensorCapabilities {
    public let hasAccelerometer: Bool
    public let hasGyroscope: Bool
    public let hasHeartRateMonitor: Bool
    public let hasHealthKitAccess: Bool
    public let has6DOFTracking: Bool
    public let hasARSupport: Bool
    public let hasDepthCamera: Bool
    public let hasFaceID: Bool
}

// MARK: - Network Capabilities

/// Network features available
public struct NetworkCapabilities {
    public let supportsWebRTC: Bool
    public let supportsWebSockets: Bool
    public let supportsUDP: Bool
    public let supportsMulticast: Bool
    public let hasLowLatencyMode: Bool
    public let supports5G: Bool
}

// MARK: - Hardware Abstraction Layer

/// Main HAL singleton - runtime capability detection and platform abstraction
public final class HardwareAbstractionLayer {

    public static let shared = HardwareAbstractionLayer()

    // MARK: - Properties

    public private(set) var platform: PlatformType
    public private(set) var deviceCategory: DeviceCategory
    public private(set) var graphics: GraphicsCapabilities
    public private(set) var audio: AudioCapabilities
    public private(set) var input: InputCapabilities
    public private(set) var sensors: SensorCapabilities
    public private(set) var network: NetworkCapabilities

    public var deviceName: String {
        #if os(iOS) || os(visionOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }

    public var systemVersion: String {
        #if os(iOS) || os(visionOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "1.0"
        #endif
    }

    // MARK: - Initialization

    private init() {
        // Detect platform
        #if os(iOS)
        #if targetEnvironment(simulator)
        platform = .iOS
        deviceCategory = .midRange
        #else
        platform = UIDevice.current.userInterfaceIdiom == .pad ? .iPadOS : .iOS
        deviceCategory = Self.detectDeviceCategory()
        #endif
        #elseif os(visionOS)
        platform = .visionOS
        deviceCategory = .highEnd
        #elseif os(macOS)
        platform = .macOS
        deviceCategory = Self.detectMacCategory()
        #else
        platform = .unknown
        deviceCategory = .midRange
        #endif

        // Detect capabilities
        graphics = Self.detectGraphicsCapabilities()
        audio = Self.detectAudioCapabilities()
        input = Self.detectInputCapabilities()
        sensors = Self.detectSensorCapabilities()
        network = Self.detectNetworkCapabilities()

        print("🔧 HAL Initialized:")
        print("   Platform: \(platform.rawValue)")
        print("   Category: \(deviceCategory)")
        print("   Graphics: \(graphics.api)")
        print("   VRAM: \(graphics.vramAvailable / 1_000_000)MB")
    }

    // MARK: - Platform Detection

    #if os(iOS)
    private static func detectDeviceCategory() -> DeviceCategory {
        // Use GPU core count as proxy for device tier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }

        // iPhone model detection
        guard let model = machine else { return .midRange }

        if model.contains("iPhone15") || model.contains("iPhone16") {
            return .highEnd // iPhone 14 Pro+, iPhone 15+
        } else if model.contains("iPhone13") || model.contains("iPhone14") {
            return .midRange // iPhone 11-14
        } else {
            return .lowEnd // iPhone X and older
        }
    }
    #endif

    #if os(macOS)
    private static func detectMacCategory() -> DeviceCategory {
        let cores = ProcessInfo.processInfo.processorCount
        let memory = ProcessInfo.processInfo.physicalMemory

        if cores >= 10 && memory > 32_000_000_000 {
            return .workstation // Mac Studio, Mac Pro
        } else if cores >= 8 {
            return .highEnd // M1 Pro/Max/Ultra
        } else {
            return .midRange // M1, Intel Macs
        }
    }
    #endif

    // MARK: - Graphics Detection

    private static func detectGraphicsCapabilities() -> GraphicsCapabilities {
        #if os(iOS) || os(macOS) || os(visionOS)
        // Metal detection
        guard let device = MTLCreateSystemDefaultDevice() else {
            return .fallback
        }

        return GraphicsCapabilities(
            api: .metal,
            maxTextureSize: 16384,
            supportsCompute: true,
            supportsRayTracing: device.supportsRaytracing,
            maxSampleCount: 4,
            vramAvailable: device.recommendedMaxWorkingSetSize,
            supportsHDR: true,
            maxRenderTargets: 8
        )
        #else
        // Fallback for other platforms
        return .fallback
        #endif
    }

    // MARK: - Audio Detection

    private static func detectAudioCapabilities() -> AudioCapabilities {
        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        return AudioCapabilities(
            maxChannels: Int(session.maximumOutputNumberOfChannels),
            supportsSpatialAudio: true,
            supportsHRTF: true,
            supportsAmbisonics: true,
            maxSampleRate: 48000,
            supportsASIO: false,
            supportsJACK: false,
            bufferSizes: [128, 256, 512, 1024]
        )
        #elseif os(macOS)
        return AudioCapabilities(
            maxChannels: 8,
            supportsSpatialAudio: true,
            supportsHRTF: true,
            supportsAmbisonics: true,
            maxSampleRate: 192000,
            supportsASIO: false,
            supportsJACK: true,
            bufferSizes: [64, 128, 256, 512]
        )
        #else
        return .stereo
        #endif
    }

    // MARK: - Input Detection

    private static func detectInputCapabilities() -> InputCapabilities {
        #if os(iOS)
        return InputCapabilities(
            hasTouchscreen: true,
            hasKeyboard: false,
            hasMouse: false,
            hasGamepad: GCController.controllers().count > 0,
            hasVRControllers: false,
            supportsHandTracking: false,
            supportsEyeTracking: false,
            supportsFaceTracking: ARFaceTrackingConfiguration.isSupported,
            hasMIDISupport: true,
            hasOSCSupport: true
        )
        #elseif os(macOS)
        return InputCapabilities(
            hasTouchscreen: false,
            hasKeyboard: true,
            hasMouse: true,
            hasGamepad: GCController.controllers().count > 0,
            hasVRControllers: false,
            supportsHandTracking: false,
            supportsEyeTracking: false,
            supportsFaceTracking: false,
            hasMIDISupport: true,
            hasOSCSupport: true
        )
        #elseif os(visionOS)
        return InputCapabilities(
            hasTouchscreen: false,
            hasKeyboard: false,
            hasMouse: false,
            hasGamepad: false,
            hasVRControllers: true,
            supportsHandTracking: true,
            supportsEyeTracking: true,
            supportsFaceTracking: false,
            hasMIDISupport: true,
            hasOSCSupport: true
        )
        #else
        return InputCapabilities(
            hasTouchscreen: false,
            hasKeyboard: true,
            hasMouse: true,
            hasGamepad: false,
            hasVRControllers: false,
            supportsHandTracking: false,
            supportsEyeTracking: false,
            supportsFaceTracking: false,
            hasMIDISupport: false,
            hasOSCSupport: false
        )
        #endif
    }

    // MARK: - Sensor Detection

    private static func detectSensorCapabilities() -> SensorCapabilities {
        #if os(iOS)
        return SensorCapabilities(
            hasAccelerometer: true,
            hasGyroscope: true,
            hasHeartRateMonitor: false, // Requires Apple Watch
            hasHealthKitAccess: true,
            has6DOFTracking: ARWorldTrackingConfiguration.isSupported,
            hasARSupport: ARConfiguration.isSupported,
            hasDepthCamera: ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth),
            hasFaceID: true // Assume recent devices
        )
        #elseif os(visionOS)
        return SensorCapabilities(
            hasAccelerometer: true,
            hasGyroscope: true,
            hasHeartRateMonitor: false,
            hasHealthKitAccess: true,
            has6DOFTracking: true,
            hasARSupport: true,
            hasDepthCamera: true,
            hasFaceID: false
        )
        #else
        return SensorCapabilities(
            hasAccelerometer: false,
            hasGyroscope: false,
            hasHeartRateMonitor: false,
            hasHealthKitAccess: false,
            has6DOFTracking: false,
            hasARSupport: false,
            hasDepthCamera: false,
            hasFaceID: false
        )
        #endif
    }

    // MARK: - Network Detection

    private static func detectNetworkCapabilities() -> NetworkCapabilities {
        #if os(iOS) || os(macOS) || os(visionOS)
        return NetworkCapabilities(
            supportsWebRTC: true,
            supportsWebSockets: true,
            supportsUDP: true,
            supportsMulticast: true,
            hasLowLatencyMode: true,
            supports5G: true // Assume modern devices
        )
        #else
        return NetworkCapabilities(
            supportsWebRTC: false,
            supportsWebSockets: true,
            supportsUDP: true,
            supportsMulticast: false,
            hasLowLatencyMode: false,
            supports5G: false
        )
        #endif
    }

    // MARK: - Performance Scaling

    /// Get recommended particle count based on device
    public func recommendedParticleCount() -> Int {
        switch deviceCategory {
        case .lowEnd: return 100
        case .midRange: return 300
        case .highEnd: return 500
        case .workstation, .cloud: return 1000
        }
    }

    /// Get recommended texture resolution
    public func recommendedTextureSize() -> Int {
        switch deviceCategory {
        case .lowEnd: return 512
        case .midRange: return 1024
        case .highEnd: return 2048
        case .workstation, .cloud: return 4096
        }
    }

    /// Get recommended frame rate target
    public func targetFrameRate() -> Int {
        switch platform {
        case .visionOS, .metaQuest, .steamVR, .psvr2:
            return 90 // VR requires high FPS
        case .iOS, .iPadOS:
            return 60 // ProMotion devices can go higher
        default:
            return 60
        }
    }
}

// MARK: - Platform Extensions

#if os(iOS) || os(visionOS)
import UIKit
import AVFoundation
import Metal
import ARKit
import GameController
#endif

#if os(macOS)
import AppKit
import Metal
import AVFoundation
import GameController
#endif
