import Foundation
import Combine

/// NDI Configuration - Settings and preferences for NDI output
///
/// Features:
/// - Persistent settings (UserDefaults)
/// - Audio format configuration
/// - Network settings
/// - Performance tuning
///
/// Usage:
/// ```swift
/// let config = NDIConfiguration.shared
/// config.sourceName = "BLAB Studio"
/// config.enabled = true
/// ```
@available(iOS 15.0, *)
public class NDIConfiguration: ObservableObject {

    // MARK: - Singleton

    public static let shared = NDIConfiguration()

    // MARK: - Settings

    /// Enable/Disable NDI output
    @Published public var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "ndi.enabled")
        }
    }

    /// NDI source name (appears on network)
    @Published public var sourceName: String {
        didSet {
            UserDefaults.standard.set(sourceName, forKey: "ndi.sourceName")
        }
    }

    /// Audio sample rate (44.1kHz, 48kHz, 96kHz)
    @Published public var sampleRate: Double {
        didSet {
            UserDefaults.standard.set(sampleRate, forKey: "ndi.sampleRate")
        }
    }

    /// Channel count (2 = Stereo, 8 = 7.1 Surround)
    @Published public var channelCount: Int {
        didSet {
            UserDefaults.standard.set(channelCount, forKey: "ndi.channelCount")
        }
    }

    /// Audio bit depth (16, 24, 32)
    @Published public var bitDepth: Int {
        didSet {
            UserDefaults.standard.set(bitDepth, forKey: "ndi.bitDepth")
        }
    }

    /// Use floating-point audio (recommended)
    @Published public var useFloat: Bool {
        didSet {
            UserDefaults.standard.set(useFloat, forKey: "ndi.useFloat")
        }
    }

    /// NDI groups (comma-separated, empty = public)
    @Published public var groups: String {
        didSet {
            UserDefaults.standard.set(groups, forKey: "ndi.groups")
        }
    }

    /// Send biometric metadata
    @Published public var sendBiometricMetadata: Bool {
        didSet {
            UserDefaults.standard.set(sendBiometricMetadata, forKey: "ndi.sendBiometricMetadata")
        }
    }

    /// Metadata update interval (seconds)
    @Published public var metadataInterval: Double {
        didSet {
            UserDefaults.standard.set(metadataInterval, forKey: "ndi.metadataInterval")
        }
    }

    // MARK: - Network Settings

    /// Multicast TTL (1-255, lower = local network only)
    @Published public var multicastTTL: Int {
        didSet {
            UserDefaults.standard.set(multicastTTL, forKey: "ndi.multicastTTL")
        }
    }

    /// Prefer TCP over UDP (more reliable, higher latency)
    @Published public var preferTCP: Bool {
        didSet {
            UserDefaults.standard.set(preferTCP, forKey: "ndi.preferTCP")
        }
    }

    // MARK: - Performance Settings

    /// Buffer size in frames (128, 256, 512)
    @Published public var bufferSize: Int {
        didSet {
            UserDefaults.standard.set(bufferSize, forKey: "ndi.bufferSize")
        }
    }

    /// Maximum send queue size (prevent memory buildup)
    @Published public var maxQueueSize: Int {
        didSet {
            UserDefaults.standard.set(maxQueueSize, forKey: "ndi.maxQueueSize")
        }
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable {
        case lowLatency = "Low Latency"
        case balanced = "Balanced"
        case highQuality = "High Quality"
        case broadcast = "Broadcast"

        var sampleRate: Double {
            switch self {
            case .lowLatency: return 44100
            case .balanced: return 48000
            case .highQuality: return 96000
            case .broadcast: return 48000
            }
        }

        var bufferSize: Int {
            switch self {
            case .lowLatency: return 128
            case .balanced: return 256
            case .highQuality: return 512
            case .broadcast: return 256
            }
        }

        var bitDepth: Int {
            switch self {
            case .lowLatency: return 16
            case .balanced: return 24
            case .highQuality: return 32
            case .broadcast: return 24
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults
        self.enabled = UserDefaults.standard.bool(forKey: "ndi.enabled")
        self.sourceName = UserDefaults.standard.string(forKey: "ndi.sourceName") ?? "BLAB iOS"
        self.sampleRate = UserDefaults.standard.double(forKey: "ndi.sampleRate").orDefault(48000)
        self.channelCount = UserDefaults.standard.integer(forKey: "ndi.channelCount").orDefault(2)
        self.bitDepth = UserDefaults.standard.integer(forKey: "ndi.bitDepth").orDefault(32)
        self.useFloat = UserDefaults.standard.bool(forKey: "ndi.useFloat", default: true)
        self.groups = UserDefaults.standard.string(forKey: "ndi.groups") ?? ""
        self.sendBiometricMetadata = UserDefaults.standard.bool(forKey: "ndi.sendBiometricMetadata", default: true)
        self.metadataInterval = UserDefaults.standard.double(forKey: "ndi.metadataInterval").orDefault(0.5)

        // Network
        self.multicastTTL = UserDefaults.standard.integer(forKey: "ndi.multicastTTL").orDefault(1)
        self.preferTCP = UserDefaults.standard.bool(forKey: "ndi.preferTCP")

        // Performance
        self.bufferSize = UserDefaults.standard.integer(forKey: "ndi.bufferSize").orDefault(256)
        self.maxQueueSize = UserDefaults.standard.integer(forKey: "ndi.maxQueueSize").orDefault(10)
    }

    // MARK: - Preset Management

    /// Apply a preset configuration
    public func applyPreset(_ preset: Preset) {
        sampleRate = preset.sampleRate
        bufferSize = preset.bufferSize
        bitDepth = preset.bitDepth
        useFloat = true

        print("[NDI Config] Applied preset: \(preset.rawValue)")
        print("[NDI Config]   Sample rate: \(sampleRate) Hz")
        print("[NDI Config]   Buffer size: \(bufferSize) frames")
        print("[NDI Config]   Bit depth: \(bitDepth)-bit")
    }

    // MARK: - Validation

    /// Validate current configuration
    public func validate() -> [String] {
        var warnings: [String] = []

        // Sample rate
        if ![44100, 48000, 88200, 96000].contains(sampleRate) {
            warnings.append("Unusual sample rate: \(sampleRate) Hz")
        }

        // Channel count
        if channelCount < 1 || channelCount > 64 {
            warnings.append("Invalid channel count: \(channelCount)")
        }

        // Buffer size
        if ![64, 128, 256, 512, 1024].contains(bufferSize) {
            warnings.append("Unusual buffer size: \(bufferSize)")
        }

        // Source name
        if sourceName.isEmpty {
            warnings.append("Source name is empty")
        }

        return warnings
    }

    /// Get current audio format
    public func audioFormat() -> NDIAudioSender.AudioFormat {
        return NDIAudioSender.AudioFormat(
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            isFloat: useFloat
        )
    }

    // MARK: - Debug

    /// Print current configuration
    public func printConfiguration() {
        print("""
        [NDI Configuration]
          Enabled: \(enabled)
          Source Name: \(sourceName)
          Sample Rate: \(sampleRate) Hz
          Channels: \(channelCount)
          Bit Depth: \(bitDepth)-bit
          Float: \(useFloat)
          Groups: \(groups.isEmpty ? "public" : groups)
          Biometric Metadata: \(sendBiometricMetadata)
          Metadata Interval: \(metadataInterval)s
          Buffer Size: \(bufferSize) frames
          Max Queue: \(maxQueueSize) frames
        """)
    }

    // MARK: - Reset

    /// Reset to default settings
    public func resetToDefaults() {
        enabled = false
        sourceName = "BLAB iOS"
        sampleRate = 48000
        channelCount = 2
        bitDepth = 32
        useFloat = true
        groups = ""
        sendBiometricMetadata = true
        metadataInterval = 0.5
        multicastTTL = 1
        preferTCP = false
        bufferSize = 256
        maxQueueSize = 10

        print("[NDI Config] Reset to defaults")
    }
}

// MARK: - UserDefaults Extensions

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

private extension Double {
    func orDefault(_ defaultValue: Double) -> Double {
        return self == 0 ? defaultValue : self
    }
}

private extension Int {
    func orDefault(_ defaultValue: Int) -> Int {
        return self == 0 ? defaultValue : self
    }
}
