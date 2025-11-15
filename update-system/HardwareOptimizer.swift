import Foundation
import AVFoundation
import Metal

// MARK: - Hardware Optimizer
/// Automatic hardware detection and optimization
/// Adapts app performance to device capabilities
///
/// Features:
/// 1. Automatic quality adjustment (low/medium/high)
/// 2. Latency optimization (buffer size tuning)
/// 3. GPU vs CPU selection
/// 4. Memory management
/// 5. Battery optimization
/// 6. Thermal throttling detection
/// 7. Legacy device support
/// 8. Future-proof scaling
class HardwareOptimizer: ObservableObject {

    // MARK: - Published State
    @Published var currentProfile: PerformanceProfile = .balanced
    @Published var hardwareCapabilities: HardwareCapabilities
    @Published var thermalState: ThermalState = .nominal
    @Published var batteryLevel: Float = 1.0
    @Published var isPluggedIn: Bool = false

    // MARK: - Optimization Settings
    @Published var audioBufferSize: Int = 512
    @Published var videoQuality: VideoQuality = .high
    @Published var useGPUAcceleration: Bool = true
    @Published var maxConcurrentTasks: Int = 4

    // MARK: - Monitoring
    private var thermalStateObserver: NSObjectProtocol?
    private var batteryObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        self.hardwareCapabilities = HardwareCapabilities.detect()
        self.currentProfile = determineOptimalProfile()

        setupMonitoring()
        applyOptimizations()
    }

    deinit {
        cleanupMonitoring()
    }

    // MARK: - Profile Determination

    private func determineOptimalProfile() -> PerformanceProfile {
        let caps = hardwareCapabilities

        // High-end devices (latest flagships)
        if caps.isHighEnd {
            return .performance
        }

        // Mid-range devices (2-3 years old flagships, current mid-range)
        if caps.isMidRange {
            return .balanced
        }

        // Low-end devices (old devices, budget phones)
        if caps.isLowEnd {
            return .efficiency
        }

        return .balanced
    }

    /// Apply current performance profile
    func applyOptimizations() {
        switch currentProfile {
        case .performance:
            applyPerformanceSettings()
        case .balanced:
            applyBalancedSettings()
        case .efficiency:
            applyEfficiencySettings()
        case .custom:
            // Use custom settings
            break
        }
    }

    // MARK: - Performance Profiles

    private func applyPerformanceSettings() {
        // Audio: Minimum latency
        audioBufferSize = hardwareCapabilities.supportsLowLatency ? 128 : 256

        // Video: Maximum quality
        if hardwareCapabilities.supports4K {
            videoQuality = .ultra
        } else {
            videoQuality = .high
        }

        // GPU: Always use if available
        useGPUAcceleration = hardwareCapabilities.hasMetalGPU

        // Concurrency: Maximum threads
        maxConcurrentTasks = hardwareCapabilities.cpuCoreCount
    }

    private func applyBalancedSettings() {
        // Audio: Balanced latency
        audioBufferSize = 512

        // Video: High quality
        videoQuality = .high

        // GPU: Use for heavy tasks
        useGPUAcceleration = hardwareCapabilities.hasMetalGPU

        // Concurrency: Half of cores
        maxConcurrentTasks = max(2, hardwareCapabilities.cpuCoreCount / 2)
    }

    private func applyEfficiencySettings() {
        // Audio: Higher latency for stability
        audioBufferSize = 1024

        // Video: Lower quality
        videoQuality = hardwareCapabilities.ramGB < 2 ? .low : .medium

        // GPU: Only for critical tasks
        useGPUAcceleration = false

        // Concurrency: Limited threads
        maxConcurrentTasks = 2
    }

    // MARK: - Audio Optimization

    /// Get optimal audio settings for device
    func getOptimalAudioSettings() -> AudioSettings {
        let sampleRate: Double

        // Determine sample rate
        if hardwareCapabilities.supports48kHz {
            sampleRate = 48000.0
        } else {
            sampleRate = 44100.0
        }

        // Determine buffer size based on profile and latency requirements
        let bufferSize: Int
        if currentProfile == .performance && hardwareCapabilities.supportsLowLatency {
            bufferSize = 128  // ~2.7ms latency at 48kHz
        } else if currentProfile == .balanced {
            bufferSize = 512  // ~10.7ms latency at 48kHz
        } else {
            bufferSize = 1024 // ~21.3ms latency at 48kHz
        }

        // Determine channel count
        let maxChannels = min(hardwareCapabilities.maxAudioChannels, 32)

        return AudioSettings(
            sampleRate: sampleRate,
            bufferSize: bufferSize,
            channels: maxChannels,
            bitDepth: 32 // Always use 32-bit float
        )
    }

    /// Adjust audio latency based on current conditions
    func optimizeAudioLatency() {
        // Check thermal state
        if thermalState == .critical || thermalState == .serious {
            // Increase buffer size to reduce CPU load
            audioBufferSize = min(audioBufferSize * 2, 2048)
        }

        // Check battery
        if !isPluggedIn && batteryLevel < 0.2 {
            // Increase buffer size to save battery
            audioBufferSize = 1024
        }

        // Check CPU load
        let cpuUsage = getCPUUsage()
        if cpuUsage > 0.9 {
            // System is overloaded, increase buffer size
            audioBufferSize = min(audioBufferSize * 2, 2048)
        }
    }

    // MARK: - Video Optimization

    /// Get optimal video settings for device
    func getOptimalVideoSettings() -> VideoSettings {
        let resolution: VideoResolution
        let frameRate: Int
        let codec: VideoCodec

        // Determine resolution based on capabilities and profile
        if currentProfile == .performance && hardwareCapabilities.supports4K {
            resolution = .uhd4K
        } else if currentProfile == .performance || currentProfile == .balanced {
            resolution = .fullHD
        } else if hardwareCapabilities.ramGB < 2 {
            resolution = .hd720
        } else {
            resolution = .fullHD
        }

        // Determine frame rate
        if hardwareCapabilities.supportsHighFrameRate && currentProfile == .performance {
            frameRate = 60
        } else {
            frameRate = 30
        }

        // Determine codec (hardware vs software)
        if hardwareCapabilities.hasHardwareEncoder {
            codec = .h265_hardware
        } else {
            codec = .h264_software
        }

        return VideoSettings(
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            bitrate: calculateOptimalBitrate(resolution: resolution),
            useGPU: useGPUAcceleration && hardwareCapabilities.hasMetalGPU
        )
    }

    private func calculateOptimalBitrate(resolution: VideoResolution) -> Int {
        // Calculate bitrate based on resolution and quality
        let baseMultiplier: Float

        switch videoQuality {
        case .low:
            baseMultiplier = 0.5
        case .medium:
            baseMultiplier = 1.0
        case .high:
            baseMultiplier = 1.5
        case .ultra:
            baseMultiplier = 2.0
        }

        let baseBitrate: Int
        switch resolution {
        case .hd720:
            baseBitrate = 5_000_000  // 5 Mbps
        case .fullHD:
            baseBitrate = 10_000_000 // 10 Mbps
        case .uhd4K:
            baseBitrate = 40_000_000 // 40 Mbps
        case .uhd8K:
            baseBitrate = 100_000_000 // 100 Mbps
        }

        return Int(Float(baseBitrate) * baseMultiplier)
    }

    // MARK: - GPU Optimization

    /// Check if GPU should be used for specific task
    func shouldUseGPU(for task: GPUTask) -> Bool {
        guard hardwareCapabilities.hasMetalGPU else { return false }

        // Check thermal state
        if thermalState == .critical {
            return false
        }

        // Check battery
        if !isPluggedIn && batteryLevel < 0.1 {
            return false
        }

        switch task {
        case .videoRendering, .imageProcessing:
            // Always use GPU for video/image tasks if available
            return true

        case .audioProcessing:
            // Use GPU for audio only on high-end devices
            return hardwareCapabilities.isHighEnd

        case .aiInference:
            // Use GPU for AI if available
            return hardwareCapabilities.hasNeuralEngine || hardwareCapabilities.hasMetalGPU
        }
    }

    /// Get optimal Metal device
    func getOptimalMetalDevice() -> MTLDevice? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        // Check GPU family
        #if os(iOS) || os(tvOS)
        if device.supportsFamily(.apple7) {
            // Latest Apple GPU (A15+, M1+)
            return device
        }
        #endif

        return device
    }

    // MARK: - Memory Optimization

    /// Get optimal memory limits
    func getMemoryLimits() -> MemoryLimits {
        let totalRAM = hardwareCapabilities.ramGB
        let availableRAM = getAvailableRAM()

        // Calculate safe limits (use max 70% of available RAM)
        let maxUsage = Int64(Float(availableRAM) * 0.7)

        // Allocate to different components
        let audioBufferMemory = Int64(audioBufferSize * 4 * 64) // 64 tracks max
        let videoFrameMemory: Int64

        if videoQuality == .ultra {
            videoFrameMemory = 100 * 1024 * 1024  // 100MB for frame cache
        } else if videoQuality == .high {
            videoFrameMemory = 50 * 1024 * 1024   // 50MB
        } else {
            videoFrameMemory = 25 * 1024 * 1024   // 25MB
        }

        let projectDataMemory = maxUsage - audioBufferMemory - videoFrameMemory

        return MemoryLimits(
            totalLimit: maxUsage,
            audioBuffers: audioBufferMemory,
            videoFrames: videoFrameMemory,
            projectData: projectDataMemory
        )
    }

    private func getAvailableRAM() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Int64(ProcessInfo.processInfo.physicalMemory - UInt64(info.resident_size))
        }

        return Int64(ProcessInfo.processInfo.physicalMemory)
    }

    // MARK: - Thermal Management

    private func setupMonitoring() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Monitor thermal state
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalStateChange()
        }

        // Monitor battery
        UIDevice.current.isBatteryMonitoringEnabled = true

        batteryObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBatteryChange()
        }
        #endif
    }

    private func cleanupMonitoring() {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = batteryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleThermalStateChange() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let state = ProcessInfo.processInfo.thermalState

        switch state {
        case .nominal:
            thermalState = .nominal
        case .fair:
            thermalState = .fair
        case .serious:
            thermalState = .serious
            // Reduce performance
            if currentProfile == .performance {
                currentProfile = .balanced
                applyOptimizations()
            }
        case .critical:
            thermalState = .critical
            // Emergency performance reduction
            currentProfile = .efficiency
            applyOptimizations()
        @unknown default:
            thermalState = .nominal
        }
        #endif
    }

    private func handleBatteryChange() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        batteryLevel = UIDevice.current.batteryLevel
        isPluggedIn = UIDevice.current.batteryState == .charging ||
                      UIDevice.current.batteryState == .full

        // Adjust settings based on battery
        if !isPluggedIn && batteryLevel < 0.2 {
            // Low battery, switch to efficiency mode
            if currentProfile != .efficiency {
                currentProfile = .efficiency
                applyOptimizations()
            }
        }
        #endif
    }

    // MARK: - CPU Monitoring

    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    continue
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }

            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        return totalUsageOfCPU
    }

    // MARK: - Legacy Device Support

    /// Check if device is legacy (old) and needs special handling
    func isLegacyDevice() -> Bool {
        return hardwareCapabilities.deviceAge > 4 || hardwareCapabilities.ramGB < 2
    }

    /// Get legacy-optimized settings
    func getLegacySettings() -> LegacySettings {
        return LegacySettings(
            maxTracks: 8,
            maxEffects: 4,
            disableGPU: true,
            simplifiedUI: true,
            reducedAnimations: true,
            lowerSampleRate: true,
            increaseBufferSize: true
        )
    }
}

// MARK: - Supporting Types

enum PerformanceProfile: String, CaseIterable {
    case performance    // Maximum performance, high power usage
    case balanced       // Balance between performance and efficiency
    case efficiency     // Maximum battery life, lower performance
    case custom         // User-defined settings
}

struct HardwareCapabilities {
    // CPU
    let cpuCoreCount: Int
    let cpuFrequency: Double  // GHz
    let cpuArchitecture: String

    // Memory
    let ramGB: Float
    let storageGB: Int

    // GPU
    let hasMetalGPU: Bool
    let hasNeuralEngine: Bool
    let gpuCoreCount: Int

    // Audio
    let supportsLowLatency: Bool
    let supports48kHz: Bool
    let maxAudioChannels: Int

    // Video
    let supports4K: Bool
    let supports8K: Bool
    let supportsHighFrameRate: Bool
    let hasHardwareEncoder: Bool

    // Device Classification
    let isHighEnd: Bool
    let isMidRange: Bool
    let isLowEnd: Bool
    let deviceAge: Int  // Years since release

    static func detect() -> HardwareCapabilities {
        // CPU detection
        let cpuCoreCount = ProcessInfo.processInfo.activeProcessorCount
        let cpuFrequency = 2.0 // Placeholder

        #if arch(arm64)
        let cpuArchitecture = "ARM64"
        #elseif arch(x86_64)
        let cpuArchitecture = "x86_64"
        #else
        let cpuArchitecture = "unknown"
        #endif

        // Memory detection
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        let ramGB = Float(ramBytes) / 1_000_000_000.0

        let storageGB = Int(getStorageSize() / 1_000_000_000)

        // GPU detection
        let hasMetalGPU = MTLCreateSystemDefaultDevice() != nil
        let hasNeuralEngine = detectNeuralEngine()
        let gpuCoreCount = detectGPUCores()

        // Audio capabilities
        let supportsLowLatency = ramGB > 4
        let supports48kHz = true
        let maxAudioChannels = 32

        // Video capabilities
        let supports4K = ramGB > 4
        let supports8K = ramGB > 8
        let supportsHighFrameRate = hasMetalGPU && ramGB > 4
        let hasHardwareEncoder = detectHardwareEncoder()

        // Classification
        let isHighEnd = ramGB >= 8 && hasMetalGPU && cpuCoreCount >= 6
        let isLowEnd = ramGB < 4 || cpuCoreCount < 4
        let isMidRange = !isHighEnd && !isLowEnd

        let deviceAge = estimateDeviceAge(ramGB: ramGB, cpuCores: cpuCoreCount)

        return HardwareCapabilities(
            cpuCoreCount: cpuCoreCount,
            cpuFrequency: cpuFrequency,
            cpuArchitecture: cpuArchitecture,
            ramGB: ramGB,
            storageGB: storageGB,
            hasMetalGPU: hasMetalGPU,
            hasNeuralEngine: hasNeuralEngine,
            gpuCoreCount: gpuCoreCount,
            supportsLowLatency: supportsLowLatency,
            supports48kHz: supports48kHz,
            maxAudioChannels: maxAudioChannels,
            supports4K: supports4K,
            supports8K: supports8K,
            supportsHighFrameRate: supportsHighFrameRate,
            hasHardwareEncoder: hasHardwareEncoder,
            isHighEnd: isHighEnd,
            isMidRange: isMidRange,
            isLowEnd: isLowEnd,
            deviceAge: deviceAge
        )
    }

    static func getStorageSize() -> Int64 {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
            return Int64(values.volumeTotalCapacity ?? 0)
        } catch {
            return 0
        }
    }

    static func detectNeuralEngine() -> Bool {
        // Detect Neural Engine (A11+, M1+)
        return false // Placeholder
    }

    static func detectGPUCores() -> Int {
        // Detect GPU core count
        return 4 // Placeholder
    }

    static func detectHardwareEncoder() -> Bool {
        // Check for hardware video encoder
        return true // Placeholder
    }

    static func estimateDeviceAge(ramGB: Float, cpuCores: Int) -> Int {
        // Rough estimation based on specs
        if ramGB >= 8 && cpuCores >= 8 {
            return 0  // Current year
        } else if ramGB >= 6 && cpuCores >= 6 {
            return 1  // 1 year old
        } else if ramGB >= 4 && cpuCores >= 4 {
            return 2  // 2 years old
        } else if ramGB >= 2 {
            return 3  // 3 years old
        } else {
            return 5  // 5+ years old
        }
    }
}

enum ThermalState {
    case nominal, fair, serious, critical
}

enum VideoQuality {
    case low, medium, high, ultra
}

enum GPUTask {
    case videoRendering
    case imageProcessing
    case audioProcessing
    case aiInference
}

struct AudioSettings {
    let sampleRate: Double
    let bufferSize: Int
    let channels: Int
    let bitDepth: Int

    var latencyMs: Double {
        return (Double(bufferSize) / sampleRate) * 1000.0
    }
}

struct VideoSettings {
    let resolution: VideoResolution
    let frameRate: Int
    let codec: VideoCodec
    let bitrate: Int
    let useGPU: Bool
}

enum VideoResolution {
    case hd720     // 1280x720
    case fullHD    // 1920x1080
    case uhd4K     // 3840x2160
    case uhd8K     // 7680x4320

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .hd720: return (1280, 720)
        case .fullHD: return (1920, 1080)
        case .uhd4K: return (3840, 2160)
        case .uhd8K: return (7680, 4320)
        }
    }
}

enum VideoCodec {
    case h264_software
    case h264_hardware
    case h265_hardware
    case av1
}

struct MemoryLimits {
    let totalLimit: Int64
    let audioBuffers: Int64
    let videoFrames: Int64
    let projectData: Int64
}

struct LegacySettings {
    let maxTracks: Int
    let maxEffects: Int
    let disableGPU: Bool
    let simplifiedUI: Bool
    let reducedAnimations: Bool
    let lowerSampleRate: Bool
    let increaseBufferSize: Bool
}
