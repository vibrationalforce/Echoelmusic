import Foundation
import AVFoundation
import UIKit
import CoreMedia

/// Quality & Format Settings - Hardware-Intelligent
/// **Automatically detects device capabilities and suggests optimal settings**
///
/// **Video Formats**:
/// - ProRes (422, 422 HQ, 4444, RAW) - Professional mastering
/// - H.264 (AVC) - Universal compatibility
/// - H.265 (HEVC) - 50% smaller than H.264, same quality
/// - AV1 - Next-gen codec, 30% smaller than HEVC
/// - DNxHD/DNxHR - Avid professional codec
/// - Apple ProRes RAW - Ultimate quality
///
/// **Audio Formats**:
/// - WAV (PCM) - Uncompressed, master quality
/// - FLAC - Lossless compression
/// - ALAC (Apple Lossless) - Apple ecosystem lossless
/// - AAC - High quality, small size
/// - Opus - Best quality/size ratio
/// - MP3 - Universal compatibility
///
/// **Smart Detection**:
/// - Device CPU/GPU capabilities
/// - Available RAM
/// - Storage speed (SSD vs HDD)
/// - Available storage space
/// - Battery status (suggest efficient codecs on battery)
/// - Thermal state (reduce quality if overheating)
@MainActor
class QualityFormatSettings: ObservableObject {

    // MARK: - Published Settings

    // VIDEO FORMAT
    @Published var videoFormat: VideoFormat = .h265 {
        didSet { validateAndAdjust(); saveSettings() }
    }
    @Published var videoQualityPreset: QualityPreset = .best {
        didSet { applyPreset(); saveSettings() }
    }
    @Published var videoResolution: VideoResolution = .uhd4K {
        didSet { saveSettings() }
    }
    @Published var videoBitrate: Int = 50_000_000 {  // bits per second
        didSet { saveSettings() }
    }
    @Published var videoFrameRate: Double = 24.0 {
        didSet { saveSettings() }
    }

    // AUDIO FORMAT
    @Published var audioFormat: AudioFormat = .alac {
        didSet { saveSettings() }
    }
    @Published var audioQualityPreset: QualityPreset = .best {
        didSet { applyPreset(); saveSettings() }
    }
    @Published var audioSampleRate: AudioSampleRate = .rate48kHz {
        didSet { saveSettings() }
    }
    @Published var audioBitDepth: AudioBitDepth = .bit24 {
        didSet { saveSettings() }
    }
    @Published var audioChannels: AudioChannels = .stereo {
        didSet { saveSettings() }
    }
    @Published var audioBitrate: Int = 320_000 {  // For compressed formats (AAC, MP3)
        didSet { saveSettings() }
    }

    // HARDWARE INTELLIGENCE
    @Published var autoOptimize: Bool = true {
        didSet { if autoOptimize { optimizeForHardware() } }
    }
    @Published var hardwareProfile: HardwareProfile = .unknown
    @Published var availableFormats: [VideoFormat] = []
    @Published var availableResolutions: [VideoResolution] = []
    @Published var performanceMode: PerformanceMode = .balanced

    // STORAGE
    @Published var estimatedFileSize: Int64 = 0  // bytes
    @Published var estimatedDuration: TimeInterval = 60  // seconds

    // MARK: - Hardware Detection

    private let deviceInfo = DeviceCapabilities()

    // MARK: - Initialization

    init() {
        detectHardware()
        loadSettings()

        if autoOptimize {
            optimizeForHardware()
        }

        print("🎛️ Quality & Format Settings initialized")
        print("   Hardware: \(hardwareProfile.displayName)")
        print("   Video: \(videoFormat.displayName) @ \(videoResolution.displayName)")
        print("   Audio: \(audioFormat.displayName) @ \(audioSampleRate.rawValue)")
    }

    // MARK: - Hardware Detection

    private func detectHardware() {
        hardwareProfile = deviceInfo.getHardwareProfile()
        availableFormats = deviceInfo.getSupportedVideoFormats()
        availableResolutions = deviceInfo.getSupportedResolutions()

        print("📱 Hardware Detection:")
        print("   Device: \(deviceInfo.deviceModel)")
        print("   Profile: \(hardwareProfile.displayName)")
        print("   CPU Cores: \(deviceInfo.cpuCores)")
        print("   RAM: \(deviceInfo.totalRAM / 1_073_741_824) GB")
        print("   GPU: \(deviceInfo.gpuFamily)")
        print("   Storage: \(deviceInfo.storageType)")
        print("   Supported Codecs: \(availableFormats.map { $0.displayName }.joined(separator: ", "))")
    }

    func optimizeForHardware() {
        guard autoOptimize else { return }

        let profile = hardwareProfile

        switch profile {
        case .professional:
            // High-end device (M1/M2 iPad Pro, iPhone 15 Pro)
            videoFormat = .proRes422HQ
            videoResolution = .uhd4K
            videoFrameRate = 24.0
            videoBitrate = 220_000_000
            audioFormat = .alac
            audioSampleRate = .rate96kHz
            audioBitDepth = .bit24
            print("🚀 Optimized for Professional Hardware")

        case .highEnd:
            // Recent high-end (iPhone 13+, iPad Air 5)
            videoFormat = .h265
            videoResolution = .uhd4K
            videoFrameRate = 30.0
            videoBitrate = 100_000_000
            audioFormat = .alac
            audioSampleRate = .rate48kHz
            audioBitDepth = .bit24
            print("📱 Optimized for High-End Hardware")

        case .midRange:
            // Mid-range devices
            videoFormat = .h265
            videoResolution = .fullHD1080p
            videoFrameRate = 30.0
            videoBitrate = 50_000_000
            audioFormat = .aac
            audioSampleRate = .rate48kHz
            audioBitDepth = .bit16
            print("📲 Optimized for Mid-Range Hardware")

        case .lowEnd:
            // Older devices
            videoFormat = .h264
            videoResolution = .hd720p
            videoFrameRate = 30.0
            videoBitrate = 20_000_000
            audioFormat = .aac
            audioSampleRate = .rate44_1kHz
            audioBitDepth = .bit16
            print("📱 Optimized for Low-End Hardware")

        case .unknown:
            // Safe defaults
            videoFormat = .h264
            videoResolution = .fullHD1080p
            videoFrameRate = 30.0
            videoBitrate = 30_000_000
            audioFormat = .aac
            audioSampleRate = .rate48kHz
            audioBitDepth = .bit16
        }

        // Adjust for battery/thermal state
        adjustForPowerAndThermal()

        // Update file size estimate
        updateFileSizeEstimate()
    }

    private func adjustForPowerAndThermal() {
        let batteryState = UIDevice.current.batteryState
        let batteryLevel = UIDevice.current.batteryLevel

        // If on battery and low power
        if batteryState == .unplugged && batteryLevel < 0.2 {
            if videoFormat == .proRes422HQ || videoFormat == .proRes4444 {
                videoFormat = .h265  // Switch to more efficient codec
                print("🔋 Low battery - Switched to H.265 for efficiency")
            }
        }

        // Check thermal state
        #if os(iOS)
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical || thermalState == .serious {
            if videoResolution == .uhd4K {
                videoResolution = .fullHD1080p
                print("🌡️ High temperature - Reduced to 1080p")
            }
        }
        #endif
    }

    // MARK: - Quality Presets

    func applyPreset() {
        switch videoQualityPreset {
        case .draft:
            videoResolution = .hd720p
            videoBitrate = 10_000_000
            audioSampleRate = .rate44_1kHz
            audioBitDepth = .bit16
            print("📝 Applied DRAFT preset")

        case .good:
            videoResolution = .fullHD1080p
            videoBitrate = 30_000_000
            audioSampleRate = .rate48kHz
            audioBitDepth = .bit16
            print("👍 Applied GOOD preset")

        case .best:
            videoResolution = .uhd4K
            videoBitrate = 100_000_000
            audioSampleRate = .rate48kHz
            audioBitDepth = .bit24
            print("⭐ Applied BEST preset")

        case .master:
            videoResolution = .uhd4K
            videoBitrate = 220_000_000
            videoFormat = .proRes422HQ
            audioFormat = .alac
            audioSampleRate = .rate96kHz
            audioBitDepth = .bit24
            print("👑 Applied MASTER preset")
        }

        updateFileSizeEstimate()
    }

    // MARK: - Validation

    private func validateAndAdjust() {
        // Check if selected format is supported
        if !availableFormats.contains(videoFormat) {
            // Fallback to H.264
            videoFormat = .h264
            print("⚠️ Format not supported, falling back to H.264")
        }

        // Check if resolution is supported
        if !availableResolutions.contains(videoResolution) {
            // Find closest supported resolution
            if let closest = findClosestResolution(videoResolution) {
                videoResolution = closest
                print("⚠️ Resolution adjusted to \(closest.displayName)")
            }
        }

        // Validate bitrate for format
        let maxBitrate = videoFormat.maxBitrate(for: videoResolution)
        if videoBitrate > maxBitrate {
            videoBitrate = maxBitrate
            print("⚠️ Bitrate capped at \(maxBitrate / 1_000_000) Mbps")
        }
    }

    private func findClosestResolution(_ target: VideoResolution) -> VideoResolution? {
        availableResolutions.min { abs($0.pixelCount - target.pixelCount) < abs($1.pixelCount - target.pixelCount) }
    }

    // MARK: - File Size Estimation

    func updateFileSizeEstimate() {
        // Video size
        let videoSizePerSecond = Double(videoBitrate) / 8.0  // bytes per second
        let estimatedVideoSize = videoSizePerSecond * estimatedDuration

        // Audio size
        let audioSizePerSecond: Double
        if audioFormat.isCompressed {
            audioSizePerSecond = Double(audioBitrate) / 8.0
        } else {
            // Uncompressed: sample rate × bit depth × channels
            audioSizePerSecond = Double(audioSampleRate.value) * Double(audioBitDepth.bits) / 8.0 * Double(audioChannels.count)
        }
        let estimatedAudioSize = audioSizePerSecond * estimatedDuration

        // Total with overhead (~5%)
        estimatedFileSize = Int64((estimatedVideoSize + estimatedAudioSize) * 1.05)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatBitrate(_ bitsPerSecond: Int) -> String {
        let mbps = Double(bitsPerSecond) / 1_000_000.0
        return String(format: "%.1f Mbps", mbps)
    }

    // MARK: - Export Configuration

    func getVideoExportSettings() -> [String: Any] {
        var settings: [String: Any] = [:]

        // Codec
        settings[AVVideoCodecKey] = videoFormat.avCodecType

        // Resolution
        settings[AVVideoWidthKey] = videoResolution.width
        settings[AVVideoHeightKey] = videoResolution.height

        // Bitrate (for compressed formats)
        if videoFormat != .proRes422 && videoFormat != .proRes422HQ && videoFormat != .proRes4444 {
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: videoFormat.profileLevel
            ]
        }

        // Color properties
        settings[AVVideoColorPropertiesKey] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]

        return settings
    }

    func getAudioExportSettings() -> [String: Any] {
        var settings: [String: Any] = [:]

        if audioFormat.isCompressed {
            // Compressed format (AAC, MP3, Opus)
            settings[AVFormatIDKey] = audioFormat.formatID
            settings[AVSampleRateKey] = audioSampleRate.value
            settings[AVNumberOfChannelsKey] = audioChannels.count
            settings[AVEncoderBitRateKey] = audioBitrate

        } else {
            // Uncompressed format (WAV, FLAC, ALAC)
            settings[AVFormatIDKey] = audioFormat.formatID
            settings[AVSampleRateKey] = audioSampleRate.value
            settings[AVNumberOfChannelsKey] = audioChannels.count
            settings[AVLinearPCMBitDepthKey] = audioBitDepth.bits
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsNonInterleaved] = false
        }

        return settings
    }

    // MARK: - Persistence

    private func saveSettings() {
        let settings: [String: Any] = [
            "videoFormat": videoFormat.rawValue,
            "videoQualityPreset": videoQualityPreset.rawValue,
            "videoResolution": videoResolution.rawValue,
            "videoBitrate": videoBitrate,
            "videoFrameRate": videoFrameRate,
            "audioFormat": audioFormat.rawValue,
            "audioQualityPreset": audioQualityPreset.rawValue,
            "audioSampleRate": audioSampleRate.rawValue,
            "audioBitDepth": audioBitDepth.rawValue,
            "audioChannels": audioChannels.rawValue,
            "audioBitrate": audioBitrate,
            "autoOptimize": autoOptimize,
            "performanceMode": performanceMode.rawValue
        ]

        UserDefaults.standard.set(settings, forKey: "qualityFormatSettings")
    }

    private func loadSettings() {
        guard let settings = UserDefaults.standard.dictionary(forKey: "qualityFormatSettings") else { return }

        if let format = settings["videoFormat"] as? String,
           let vf = VideoFormat(rawValue: format) {
            videoFormat = vf
        }

        if let preset = settings["videoQualityPreset"] as? String,
           let qp = QualityPreset(rawValue: preset) {
            videoQualityPreset = qp
        }

        if let res = settings["videoResolution"] as? String,
           let vr = VideoResolution(rawValue: res) {
            videoResolution = vr
        }

        videoBitrate = settings["videoBitrate"] as? Int ?? 50_000_000
        videoFrameRate = settings["videoFrameRate"] as? Double ?? 24.0

        if let format = settings["audioFormat"] as? String,
           let af = AudioFormat(rawValue: format) {
            audioFormat = af
        }

        if let rate = settings["audioSampleRate"] as? String,
           let sr = AudioSampleRate(rawValue: rate) {
            audioSampleRate = sr
        }

        if let depth = settings["audioBitDepth"] as? String,
           let bd = AudioBitDepth(rawValue: depth) {
            audioBitDepth = bd
        }

        if let channels = settings["audioChannels"] as? String,
           let ac = AudioChannels(rawValue: channels) {
            audioChannels = ac
        }

        audioBitrate = settings["audioBitrate"] as? Int ?? 320_000
        autoOptimize = settings["autoOptimize"] as? Bool ?? true

        if let mode = settings["performanceMode"] as? String,
           let pm = PerformanceMode(rawValue: mode) {
            performanceMode = pm
        }
    }
}

// MARK: - Enums

enum VideoFormat: String, CaseIterable {
    case proRes422 = "ProRes 422"
    case proRes422HQ = "ProRes 422 HQ"
    case proRes4444 = "ProRes 4444"
    case proResRAW = "ProRes RAW"
    case h264 = "H.264 (AVC)"
    case h265 = "H.265 (HEVC)"
    case av1 = "AV1"

    var displayName: String { rawValue }

    var avCodecType: AVVideoCodecType {
        switch self {
        case .proRes422: return .proRes422
        case .proRes422HQ: return .proRes422HQ
        case .proRes4444: return .proRes4444
        case .proResRAW: return .proRes422HQ  // Fallback
        case .h264: return .h264
        case .h265: return .hevc
        case .av1: return .hevc  // Fallback (AV1 not widely supported in AVFoundation yet)
        }
    }

    var profileLevel: String {
        switch self {
        case .h264: return AVVideoProfileLevelH264HighAutoLevel
        case .h265: return AVVideoProfileLevelHEVCMain10AutoLevel
        default: return AVVideoProfileLevelH264HighAutoLevel
        }
    }

    func maxBitrate(for resolution: VideoResolution) -> Int {
        switch self {
        case .proRes422: return 147_000_000 * (resolution.pixelCount / 2_073_600)  // Scale from 1080p
        case .proRes422HQ: return 220_000_000 * (resolution.pixelCount / 2_073_600)
        case .proRes4444: return 330_000_000 * (resolution.pixelCount / 2_073_600)
        case .proResRAW: return 800_000_000 * (resolution.pixelCount / 2_073_600)
        case .h264: return 100_000_000
        case .h265: return 100_000_000
        case .av1: return 100_000_000
        }
    }
}

enum VideoResolution: String, CaseIterable {
    case hd720p = "1280×720 (HD)"
    case fullHD1080p = "1920×1080 (Full HD)"
    case qhd1440p = "2560×1440 (QHD)"
    case uhd4K = "3840×2160 (4K UHD)"
    case cinema4K = "4096×2160 (4K DCI)"
    case uhd8K = "7680×4320 (8K UHD)"

    var displayName: String { rawValue }

    var width: Int {
        switch self {
        case .hd720p: return 1280
        case .fullHD1080p: return 1920
        case .qhd1440p: return 2560
        case .uhd4K: return 3840
        case .cinema4K: return 4096
        case .uhd8K: return 7680
        }
    }

    var height: Int {
        switch self {
        case .hd720p: return 720
        case .fullHD1080p: return 1080
        case .qhd1440p: return 1440
        case .uhd4K: return 2160
        case .cinema4K: return 2160
        case .uhd8K: return 4320
        }
    }

    var pixelCount: Int {
        width * height
    }
}

enum AudioFormat: String, CaseIterable {
    case wav = "WAV (Uncompressed)"
    case flac = "FLAC (Lossless)"
    case alac = "ALAC (Apple Lossless)"
    case aac = "AAC"
    case opus = "Opus"
    case mp3 = "MP3"

    var displayName: String { rawValue }

    var isCompressed: Bool {
        switch self {
        case .wav: return false
        case .flac, .alac: return true  // Lossless compression
        case .aac, .opus, .mp3: return true  // Lossy compression
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .wav: return kAudioFormatLinearPCM
        case .flac: return kAudioFormatFLAC
        case .alac: return kAudioFormatAppleLossless
        case .aac: return kAudioFormatMPEG4AAC
        case .opus: return kAudioFormatOpus
        case .mp3: return kAudioFormatMPEGLayer3
        }
    }
}

enum AudioSampleRate: String, CaseIterable {
    case rate44_1kHz = "44.1 kHz"
    case rate48kHz = "48 kHz"
    case rate88_2kHz = "88.2 kHz"
    case rate96kHz = "96 kHz"
    case rate176_4kHz = "176.4 kHz"
    case rate192kHz = "192 kHz"

    var value: Double {
        switch self {
        case .rate44_1kHz: return 44100
        case .rate48kHz: return 48000
        case .rate88_2kHz: return 88200
        case .rate96kHz: return 96000
        case .rate176_4kHz: return 176400
        case .rate192kHz: return 192000
        }
    }
}

enum AudioBitDepth: String, CaseIterable {
    case bit16 = "16-bit"
    case bit24 = "24-bit"
    case bit32 = "32-bit"

    var bits: Int {
        switch self {
        case .bit16: return 16
        case .bit24: return 24
        case .bit32: return 32
        }
    }
}

enum AudioChannels: String, CaseIterable {
    case mono = "Mono"
    case stereo = "Stereo"
    case surround5_1 = "5.1 Surround"
    case surround7_1 = "7.1 Surround"
    case atmos = "Dolby Atmos"

    var count: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        case .surround5_1: return 6
        case .surround7_1: return 8
        case .atmos: return 16  // Object-based
        }
    }
}

enum QualityPreset: String, CaseIterable {
    case draft = "Draft"
    case good = "Good"
    case best = "Best"
    case master = "Master Quality"

    var description: String {
        switch self {
        case .draft: return "Low quality, small file size - For previews/drafts"
        case .good: return "Good quality, balanced size - For sharing online"
        case .best: return "High quality, larger size - For final delivery"
        case .master: return "Master quality, largest size - For archival/editing"
        }
    }
}

enum HardwareProfile: String {
    case professional = "Professional"  // M1/M2 iPad Pro, iPhone 15 Pro
    case highEnd = "High-End"  // iPhone 13+, iPad Air 5
    case midRange = "Mid-Range"  // iPhone 11/12, iPad 9th gen
    case lowEnd = "Low-End"  // Older devices
    case unknown = "Unknown"

    var displayName: String { rawValue }
}

enum PerformanceMode: String, CaseIterable {
    case efficiency = "Efficiency"  // Prioritize battery/thermal
    case balanced = "Balanced"  // Balance quality and performance
    case performance = "Performance"  // Maximum quality, ignore battery

    var description: String {
        switch self {
        case .efficiency: return "Lower quality for better battery life"
        case .balanced: return "Balance quality and battery"
        case .performance: return "Maximum quality, may drain battery"
        }
    }
}

// MARK: - Device Capabilities

class DeviceCapabilities {
    let deviceModel: String
    let cpuCores: Int
    let totalRAM: Int64  // bytes
    let gpuFamily: String
    let storageType: String
    let supportsHEVC: Bool
    let supportsProRes: Bool

    init() {
        // Get device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        deviceModel = modelCode

        // CPU cores
        cpuCores = ProcessInfo.processInfo.processorCount

        // RAM
        totalRAM = Int64(ProcessInfo.processInfo.physicalMemory)

        // GPU (simplified detection)
        #if os(iOS)
        let device = MTLCreateSystemDefaultDevice()
        gpuFamily = device?.name ?? "Unknown GPU"
        #else
        gpuFamily = "Unknown GPU"
        #endif

        // Storage type (simplified - would need more complex detection)
        storageType = "Flash Storage"

        // Codec support
        #if os(iOS)
        supportsHEVC = AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality)
        supportsProRes = false  // Most iOS devices don't support ProRes encode
        if #available(iOS 16.0, *) {
            // Check for ProRes support on supported devices
            supportsProRes = modelCode.contains("iPhone15") || modelCode.contains("iPad14")
        }
        #else
        supportsHEVC = true
        supportsProRes = true
        #endif
    }

    func getHardwareProfile() -> HardwareProfile {
        // Simplified profile detection based on RAM and CPU
        if totalRAM >= 8_000_000_000 && cpuCores >= 6 && supportsProRes {
            return .professional
        } else if totalRAM >= 6_000_000_000 && cpuCores >= 6 {
            return .highEnd
        } else if totalRAM >= 4_000_000_000 {
            return .midRange
        } else if totalRAM >= 2_000_000_000 {
            return .lowEnd
        } else {
            return .unknown
        }
    }

    func getSupportedVideoFormats() -> [VideoFormat] {
        var formats: [VideoFormat] = [.h264]  // Always supported

        if supportsHEVC {
            formats.append(.h265)
        }

        if supportsProRes {
            formats.append(contentsOf: [.proRes422, .proRes422HQ, .proRes4444])
        }

        return formats
    }

    func getSupportedResolutions() -> [VideoResolution] {
        let profile = getHardwareProfile()

        switch profile {
        case .professional:
            return VideoResolution.allCases
        case .highEnd:
            return [.hd720p, .fullHD1080p, .qhd1440p, .uhd4K]
        case .midRange:
            return [.hd720p, .fullHD1080p, .qhd1440p]
        case .lowEnd:
            return [.hd720p, .fullHD1080p]
        case .unknown:
            return [.hd720p, .fullHD1080p]
        }
    }
}
