import Foundation
import UIKit
import AVFoundation
import ARKit

/// Comprehensive hardware capability detection for graceful degradation
/// Enables maximum compatibility across iPhone generations
@MainActor
public class HardwareCapability {

    // MARK: - Singleton

    public static let shared = HardwareCapability()

    private init() {
        detectCapabilities()
    }

    // MARK: - Device Info

    public private(set) var deviceModel: String = ""
    public private(set) var deviceGeneration: DeviceGeneration = .unknown
    public private(set) var chipGeneration: ChipGeneration = .unknown
    public private(set) var iOSVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion

    // MARK: - Capabilities

    /// TrueDepth camera for face tracking
    public private(set) var hasTrueDepthCamera: Bool = false

    /// LiDAR scanner for depth sensing
    public private(set) var hasLiDAR: Bool = false

    /// Gyroscope for head tracking fallback
    public private(set) var hasGyroscope: Bool = false

    /// Neural Engine for ML processing
    public private(set) var hasNeuralEngine: Bool = false

    /// Metal 3 support for advanced graphics
    public private(set) var hasMetal3: Bool = false

    /// Spatial audio support (headphones)
    public private(set) var supportsSpatialAudio: Bool = false

    /// Dynamic Island (iPhone 14 Pro+)
    public private(set) var hasDynamicIsland: Bool = false

    /// Performance tier for adaptive quality
    public private(set) var performanceTier: PerformanceTier = .medium

    // MARK: - Feature Availability

    /// Can use ARKit face tracking
    public var canUseFaceTracking: Bool {
        return hasTrueDepthCamera && ARFaceTrackingConfiguration.isSupported
    }

    /// Can use Vision-based face detection (fallback)
    public var canUseVisionFaceDetection: Bool {
        // Available on all devices with front camera
        return true
    }

    /// Can use device gyroscope for head tracking
    public var canUseGyroscopeHeadTracking: Bool {
        return hasGyroscope
    }

    /// Can use hardware spatial audio
    public var canUseHardwareSpatialAudio: Bool {
        return supportsSpatialAudio
    }

    /// Should use software binaural fallback
    public var shouldUseSoftwareBinaural: Bool {
        return !supportsSpatialAudio
    }

    /// Recommended FFT size based on performance
    public var recommendedFFTSize: Int {
        switch performanceTier {
        case .high, .veryHigh:
            return 4096
        case .medium:
            return 2048
        case .low:
            return 1024
        }
    }

    /// Recommended visual quality
    public var recommendedVisualQuality: VisualQuality {
        switch performanceTier {
        case .veryHigh:
            return .ultra
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }

    /// Maximum recommended particle count
    public var maxParticleCount: Int {
        switch performanceTier {
        case .veryHigh:
            return 2000
        case .high:
            return 1000
        case .medium:
            return 500
        case .low:
            return 250
        }
    }

    // MARK: - Detection

    private func detectCapabilities() {
        detectDeviceModel()
        detectChipGeneration()
        detectPerformanceTier()
        detectSensors()
        detectGraphicsCapabilities()
        detectAudioCapabilities()
    }

    private func detectDeviceModel() {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        deviceModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Determine generation
        if deviceModel.contains("iPhone") {
            if let versionString = deviceModel.components(separatedBy: "iPhone").last,
               let version = Double(versionString.replacingOccurrences(of: ",", with: ".")) {
                switch version {
                case 15.0...:
                    deviceGeneration = .iphone15Plus  // iPhone 15 Pro and later
                case 14.0..<15.0:
                    deviceGeneration = .iphone14      // iPhone 14 Pro
                case 13.0..<14.0:
                    deviceGeneration = .iphone13      // iPhone 13 Pro
                case 12.0..<13.0:
                    deviceGeneration = .iphone12      // iPhone 12 series
                case 11.0..<12.0:
                    deviceGeneration = .iphone11      // iPhone 11 series
                case 10.0..<11.0:
                    deviceGeneration = .iphoneX       // iPhone X, XS, XR
                default:
                    deviceGeneration = .iphoneLegacy  // iPhone 8 and older
                }
            }
        }
    }

    private func detectChipGeneration() {
        // Correlate device generation with chip
        switch deviceGeneration {
        case .iphone15Plus:
            chipGeneration = .a17Pro  // A17 Pro
        case .iphone14:
            chipGeneration = .a16     // A16 Bionic
        case .iphone13:
            chipGeneration = .a15     // A15 Bionic
        case .iphone12:
            chipGeneration = .a14     // A14 Bionic
        case .iphone11:
            chipGeneration = .a13     // A13 Bionic
        case .iphoneX:
            chipGeneration = .a12     // A12 Bionic
        case .iphoneLegacy:
            chipGeneration = .a11     // A11 and older
        case .unknown:
            chipGeneration = .unknown
        }

        // Detect Neural Engine
        hasNeuralEngine = chipGeneration.rawValue >= ChipGeneration.a12.rawValue
    }

    private func detectPerformanceTier() {
        switch chipGeneration {
        case .a17Pro:
            performanceTier = .veryHigh
        case .a16, .a15:
            performanceTier = .high
        case .a14, .a13:
            performanceTier = .medium
        case .a12, .a11:
            performanceTier = .low
        case .unknown:
            performanceTier = .low
        }
    }

    private func detectSensors() {
        // TrueDepth camera (Face ID devices)
        hasTrueDepthCamera = ARFaceTrackingConfiguration.isSupported

        // LiDAR (Pro models from iPhone 12 Pro onwards)
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

        // Gyroscope (all modern iPhones have this)
        hasGyroscope = true  // Assume true for iPhone 6s and later

        // Dynamic Island (iPhone 14 Pro and later)
        hasDynamicIsland = deviceGeneration == .iphone14 || deviceGeneration == .iphone15Plus
    }

    private func detectGraphicsCapabilities() {
        // Metal 3 support (iOS 16+ with A14 or later)
        if #available(iOS 16.0, *) {
            hasMetal3 = chipGeneration.rawValue >= ChipGeneration.a14.rawValue
        } else {
            hasMetal3 = false
        }
    }

    private func detectAudioCapabilities() {
        // Check for spatial audio capability
        // This is primarily a headphone feature, but we can detect device support
        supportsSpatialAudio = iOSVersion.majorVersion >= 14
    }

    // MARK: - Recommendations

    /// Get recommended audio buffer size
    public func recommendedAudioBufferSize() -> AVAudioFrameCount {
        switch performanceTier {
        case .veryHigh, .high:
            return 512  // Lower latency
        case .medium:
            return 1024 // Balanced
        case .low:
            return 2048 // Higher latency but more stable
        }
    }

    /// Get recommended sample rate
    public func recommendedSampleRate() -> Double {
        switch performanceTier {
        case .veryHigh, .high:
            return 48000.0
        case .medium:
            return 44100.0
        case .low:
            return 44100.0
        }
    }

    /// Should enable advanced features
    public func shouldEnableAdvancedFeatures() -> Bool {
        return performanceTier == .veryHigh || performanceTier == .high
    }

    // MARK: - Debug Info

    public var debugDescription: String {
        """
        📱 Hardware Capability Report

        Device: \(deviceModel)
        Generation: \(deviceGeneration)
        Chip: \(chipGeneration)
        iOS: \(iOSVersion.majorVersion).\(iOSVersion.minorVersion).\(iOSVersion.patchVersion)
        Performance Tier: \(performanceTier)

        Sensors:
        - TrueDepth Camera: \(hasTrueDepthCamera ? "✅" : "❌")
        - LiDAR: \(hasLiDAR ? "✅" : "❌")
        - Gyroscope: \(hasGyroscope ? "✅" : "❌")
        - Neural Engine: \(hasNeuralEngine ? "✅" : "❌")

        Features:
        - Face Tracking: \(canUseFaceTracking ? "✅ Native" : "⚠️ Fallback")
        - Head Tracking: \(canUseGyroscopeHeadTracking ? "✅" : "❌")
        - Spatial Audio: \(canUseHardwareSpatialAudio ? "✅ Hardware" : "⚠️ Software")
        - Metal 3: \(hasMetal3 ? "✅" : "❌")
        - Dynamic Island: \(hasDynamicIsland ? "✅" : "❌")

        Recommendations:
        - FFT Size: \(recommendedFFTSize)
        - Buffer Size: \(recommendedAudioBufferSize())
        - Sample Rate: \(recommendedSampleRate()) Hz
        - Visual Quality: \(recommendedVisualQuality)
        - Max Particles: \(maxParticleCount)
        """
    }
}

// MARK: - Supporting Types

public enum DeviceGeneration: String {
    case iphone15Plus = "iPhone 15 Pro+"
    case iphone14 = "iPhone 14"
    case iphone13 = "iPhone 13"
    case iphone12 = "iPhone 12"
    case iphone11 = "iPhone 11"
    case iphoneX = "iPhone X/XS/XR"
    case iphoneLegacy = "iPhone 8 and older"
    case unknown = "Unknown"
}

public enum ChipGeneration: Int {
    case unknown = 0
    case a11 = 11
    case a12 = 12
    case a13 = 13
    case a14 = 14
    case a15 = 15
    case a16 = 16
    case a17Pro = 17
}

public enum PerformanceTier: String {
    case veryHigh = "Very High"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

public enum VisualQuality: String {
    case ultra = "Ultra"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var particleMultiplier: Float {
        switch self {
        case .ultra: return 1.0
        case .high: return 0.75
        case .medium: return 0.5
        case .low: return 0.25
        }
    }

    var targetFPS: Int {
        switch self {
        case .ultra: return 60
        case .high: return 60
        case .medium: return 30
        case .low: return 30
        }
    }
}
