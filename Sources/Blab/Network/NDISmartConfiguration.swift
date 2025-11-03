import Foundation
import SystemConfiguration
import UIKit

/// Smart NDI Configuration - Automatic optimization for any device/network
///
/// Features:
/// - Auto-detect device capabilities (CPU, RAM, iOS version)
/// - Network quality monitoring (WiFi vs Ethernet, bandwidth)
/// - Adaptive quality selection
/// - Battery-aware optimizations
/// - One-tap optimal setup
///
/// Usage:
/// ```swift
/// let smartConfig = NDISmartConfiguration.shared
/// smartConfig.applyOptimalSettings()  // That's it!
/// ```
@available(iOS 15.0, *)
public class NDISmartConfiguration: ObservableObject {

    // MARK: - Singleton

    public static let shared = NDISmartConfiguration()

    // MARK: - Published Properties

    @Published public private(set) var currentProfile: QualityProfile = .balanced
    @Published public private(set) var deviceCapability: DeviceCapability = .medium
    @Published public private(set) var networkQuality: NetworkQuality = .unknown
    @Published public private(set) var isOptimized: Bool = false

    // MARK: - Device Capability

    public enum DeviceCapability: String, CaseIterable {
        case low = "Budget Device"          // iPhone SE, older iPads
        case medium = "Standard Device"     // iPhone 12-14
        case high = "High-End Device"       // iPhone 15 Pro, M-series iPads
        case max = "Pro Device"             // iPhone 15 Pro Max, iPad Pro M2/M4

        var maxSampleRate: Double {
            switch self {
            case .low: return 44100
            case .medium: return 48000
            case .high: return 96000
            case .max: return 96000
            }
        }

        var recommendedBufferSize: Int {
            switch self {
            case .low: return 512       // Stable
            case .medium: return 256    // Balanced
            case .high: return 128      // Low latency
            case .max: return 128       // Low latency
            }
        }

        var canUseFloat: Bool {
            // All modern devices support float
            return true
        }
    }

    // MARK: - Network Quality

    public enum NetworkQuality: String, CaseIterable {
        case unknown = "Unknown"
        case poor = "Poor (2.4 GHz WiFi)"
        case fair = "Fair (5 GHz WiFi)"
        case good = "Good (Fast WiFi)"
        case excellent = "Excellent (Ethernet/WiFi 6)"

        var maxSampleRate: Double {
            switch self {
            case .unknown: return 48000
            case .poor: return 44100
            case .fair: return 48000
            case .good: return 96000
            case .excellent: return 96000
            }
        }

        var recommendedBufferSize: Int {
            switch self {
            case .unknown: return 256
            case .poor: return 512      // Larger buffer for stability
            case .fair: return 256
            case .good: return 128
            case .excellent: return 128
            }
        }
    }

    // MARK: - Quality Profile

    public enum QualityProfile: String, CaseIterable {
        case minimal = "Minimal (Battery Saver)"
        case balanced = "Balanced (Recommended)"
        case performance = "Performance (Low Latency)"
        case maximum = "Maximum (Pro Quality)"

        var displayName: String { rawValue }

        var description: String {
            switch self {
            case .minimal:
                return "Optimized for battery life, lower quality"
            case .balanced:
                return "Best balance of quality, latency, and stability"
            case .performance:
                return "Lowest latency for live performance"
            case .maximum:
                return "Highest quality for recording/production"
            }
        }

        var emoji: String {
            switch self {
            case .minimal: return "🔋"
            case .balanced: return "⚖️"
            case .performance: return "⚡"
            case .maximum: return "💎"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        detectDeviceCapability()
        detectNetworkQuality()
    }

    // MARK: - Auto-Detection

    /// Detect device capabilities automatically
    public func detectDeviceCapability() {
        let device = UIDevice.current

        // Get device info
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        let memory = ProcessInfo.processInfo.physicalMemory / 1_073_741_824 // GB

        // Detect based on model (simplified)
        if device.userInterfaceIdiom == .pad {
            // iPad
            if memory >= 8 {
                deviceCapability = .max  // iPad Pro M2/M4
            } else if memory >= 4 {
                deviceCapability = .high  // iPad Air, Pro
            } else {
                deviceCapability = .medium
            }
        } else {
            // iPhone
            if processorCount >= 6 && memory >= 6 {
                deviceCapability = .max  // iPhone 15 Pro
            } else if processorCount >= 6 {
                deviceCapability = .high  // iPhone 13-15
            } else if processorCount >= 4 {
                deviceCapability = .medium  // iPhone 11-12
            } else {
                deviceCapability = .low  // iPhone SE, older
            }
        }

        print("[Smart NDI] Device capability: \(deviceCapability.rawValue)")
        print("[Smart NDI]   Processors: \(processorCount)")
        print("[Smart NDI]   Memory: \(memory) GB")
    }

    /// Detect network quality automatically
    public func detectNetworkQuality() {
        // Check network type
        if isConnectedViaEthernet() {
            networkQuality = .excellent
        } else if isConnectedViaWiFi() {
            // Try to determine WiFi quality
            if isWiFi6() {
                networkQuality = .excellent
            } else if is5GHzWiFi() {
                networkQuality = .good
            } else {
                networkQuality = .fair  // Assume 5GHz if can't detect
            }
        } else {
            networkQuality = .poor  // Cellular or unknown
        }

        print("[Smart NDI] Network quality: \(networkQuality.rawValue)")
    }

    // MARK: - Network Detection Helpers

    private func isConnectedViaEthernet() -> Bool {
        // Ethernet adapter detection (via USB-C)
        // This is simplified - real implementation would check network interfaces
        return false  // iOS doesn't have easy Ethernet detection
    }

    private func isConnectedViaWiFi() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else {
            return false
        }

        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)

        return flags.contains(.reachable) && !flags.contains(.isWWAN)
    }

    private func isWiFi6() -> Bool {
        // Check for WiFi 6 (802.11ax)
        // This requires private APIs or iOS 15+ CWWiFiClient
        // Simplified: return false for now
        return false
    }

    private func is5GHzWiFi() -> Bool {
        // Check for 5 GHz WiFi
        // Simplified heuristic: assume 5GHz if device is modern
        return deviceCapability == .high || deviceCapability == .max
    }

    // MARK: - Smart Configuration

    /// Apply optimal settings automatically based on device & network
    public func applyOptimalSettings(profile: QualityProfile? = nil) {
        let targetProfile = profile ?? determineOptimalProfile()
        currentProfile = targetProfile

        let config = NDIConfiguration.shared

        // Determine sample rate (limited by device AND network)
        let maxDeviceSampleRate = deviceCapability.maxSampleRate
        let maxNetworkSampleRate = networkQuality.maxSampleRate
        let maxSampleRate = min(maxDeviceSampleRate, maxNetworkSampleRate)

        // Apply settings based on profile
        switch targetProfile {
        case .minimal:
            config.sampleRate = 44100
            config.channelCount = 2
            config.bitDepth = 16
            config.bufferSize = 512
            config.sendBiometricMetadata = false

        case .balanced:
            config.sampleRate = min(48000, maxSampleRate)
            config.channelCount = 2
            config.bitDepth = 24
            config.bufferSize = max(deviceCapability.recommendedBufferSize, networkQuality.recommendedBufferSize)
            config.sendBiometricMetadata = true
            config.metadataInterval = 1.0  // Less frequent

        case .performance:
            config.sampleRate = min(48000, maxSampleRate)
            config.channelCount = 2
            config.bitDepth = 24
            config.bufferSize = deviceCapability.recommendedBufferSize
            config.sendBiometricMetadata = true
            config.metadataInterval = 0.5

        case .maximum:
            config.sampleRate = maxSampleRate
            config.channelCount = 2
            config.bitDepth = 32
            config.bufferSize = max(256, deviceCapability.recommendedBufferSize)  // Ensure stability
            config.sendBiometricMetadata = true
            config.metadataInterval = 0.25
        }

        // Always use float (modern devices support it)
        config.useFloat = deviceCapability.canUseFloat

        // Optimize source name
        if config.sourceName == "BLAB iOS" {
            config.sourceName = "BLAB \(UIDevice.current.name)"
        }

        isOptimized = true

        print("""
        [Smart NDI] ✅ Applied profile: \(targetProfile.rawValue)
          Sample Rate: \(config.sampleRate) Hz
          Buffer Size: \(config.bufferSize) frames
          Bit Depth: \(config.bitDepth)-bit
          Estimated Latency: \(estimateLatency())ms
        """)
    }

    /// Determine optimal profile based on context
    private func determineOptimalProfile() -> QualityProfile {
        // Check battery level
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowBattery = batteryLevel > 0 && batteryLevel < 0.2

        if isLowBattery {
            return .minimal  // Save battery
        }

        // Check if low-power mode is enabled
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .minimal
        }

        // Based on device + network
        if deviceCapability == .max && networkQuality == .excellent {
            return .maximum
        } else if deviceCapability == .high && networkQuality == .good {
            return .performance
        } else if deviceCapability == .low || networkQuality == .poor {
            return .minimal
        } else {
            return .balanced
        }
    }

    /// Estimate latency based on current settings
    public func estimateLatency() -> Double {
        let config = NDIConfiguration.shared
        let bufferLatency = (Double(config.bufferSize) / config.sampleRate) * 1000
        let networkLatency: Double = {
            switch networkQuality {
            case .unknown: return 10
            case .poor: return 20
            case .fair: return 10
            case .good: return 5
            case .excellent: return 2
            }
        }()

        return bufferLatency + networkLatency
    }

    // MARK: - User-Friendly Recommendations

    /// Get recommendation for user
    public func getRecommendation() -> String {
        let latency = estimateLatency()

        if latency < 5 {
            return "✅ Perfect for live performance!"
        } else if latency < 10 {
            return "✅ Great for most use cases"
        } else if latency < 20 {
            return "⚠️ Good for recording, may be noticeable live"
        } else {
            return "⚠️ Consider improving network or reducing quality"
        }
    }

    /// Get optimization tips for user
    public func getOptimizationTips() -> [String] {
        var tips: [String] = []

        // Network tips
        if networkQuality == .poor || networkQuality == .fair {
            tips.append("📡 Switch to 5 GHz WiFi for better performance")
            tips.append("📡 Move closer to WiFi router")
        }

        // Device tips
        if deviceCapability == .low || deviceCapability == .medium {
            tips.append("📱 Close background apps to free up CPU")
            tips.append("🔋 Connect to power for best performance")
        }

        // Battery tips
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            tips.append("🔋 Disable Low Power Mode for better quality")
        }

        // General tips
        tips.append("💡 Use Ethernet adapter for lowest latency")
        tips.append("💡 Restart router if experiencing dropouts")

        return tips
    }

    // MARK: - Compatibility Check

    /// Check if current settings are compatible with target
    public func checkCompatibility(targetDevice: String = "DAW") -> CompatibilityResult {
        let config = NDIConfiguration.shared

        var issues: [String] = []
        var warnings: [String] = []

        // Check sample rate
        if config.sampleRate > 48000 {
            warnings.append("Sample rate > 48kHz may not be supported by all receivers")
        }

        // Check channel count
        if config.channelCount > 2 {
            warnings.append("Multi-channel audio may require professional receivers")
        }

        // Check network
        if networkQuality == .poor {
            issues.append("Poor network quality - expect dropouts")
        }

        // Check device
        if deviceCapability == .low && currentProfile == .maximum {
            warnings.append("Device may struggle with Maximum quality")
        }

        let isCompatible = issues.isEmpty
        let level: CompatibilityLevel = {
            if !isCompatible { return .incompatible }
            if !warnings.isEmpty { return .partiallyCompatible }
            return .fullyCompatible
        }()

        return CompatibilityResult(
            level: level,
            issues: issues,
            warnings: warnings
        )
    }

    public struct CompatibilityResult {
        public let level: CompatibilityLevel
        public let issues: [String]
        public let warnings: [String]

        public var emoji: String {
            switch level {
            case .fullyCompatible: return "✅"
            case .partiallyCompatible: return "⚠️"
            case .incompatible: return "❌"
            }
        }
    }

    public enum CompatibilityLevel {
        case fullyCompatible
        case partiallyCompatible
        case incompatible
    }

    // MARK: - Debug Info

    public func printDebugInfo() {
        print("""
        [Smart NDI] Debug Info:
          Device: \(deviceCapability.rawValue)
          Network: \(networkQuality.rawValue)
          Profile: \(currentProfile.rawValue)
          Latency: \(String(format: "%.1f", estimateLatency()))ms
          Battery: \(UIDevice.current.batteryLevel * 100)%
          Low Power: \(ProcessInfo.processInfo.isLowPowerModeEnabled)
          Optimized: \(isOptimized)
        """)
    }
}
