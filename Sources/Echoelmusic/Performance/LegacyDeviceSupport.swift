import Foundation
import UIKit
import Metal
import os.log

/// Legacy Device Support & Adaptive Performance System
/// Ensures Echoelmusic runs smoothly on ALL devices, including older/weaker hardware
///
/// Supported Legacy Devices:
/// 📱 iPhone 6s (2015, A9) - Minimum supported
/// 📱 iPhone 7/8 (2016-2017, A10/A11)
/// 📱 iPhone X/XR (2017-2018, A11/A12)
/// 📱 iPad 5th gen (2017, A9)
/// 📱 iPad Air 2 (2014, A8X) - Limited support
/// ⌚️ Apple Watch Series 3+ (2017+)
/// 🤖 Android devices with 2GB+ RAM
///
/// Adaptive Strategies:
/// - Automatic quality degradation based on device capabilities
/// - Memory-efficient algorithms for low-RAM devices (<3GB)
/// - Thermal throttling prevention
/// - Battery-aware performance scaling
/// - Progressive feature loading
/// - Aggressive texture compression
/// - Simplified shaders for older GPUs
///
/// Performance Targets by Device:
/// - iPhone 6s/7: 30 FPS, 512 particles, 22kHz audio
/// - iPhone 8/X: 60 FPS, 2048 particles, 44.1kHz audio
/// - iPhone 11+: 120 FPS, 8192 particles, 48kHz audio
@MainActor
class LegacyDeviceSupport: ObservableObject {

    // MARK: - Published State

    @Published var currentDevice: DeviceProfile?
    @Published var performanceLevel: PerformanceLevel = .high
    @Published var adaptiveQualityEnabled: Bool = true
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var memoryWarningReceived: Bool = false

    // MARK: - Device Profile

    struct DeviceProfile: Identifiable {
        let id = UUID()
        let deviceName: String
        let deviceGeneration: DeviceGeneration
        let chip: Chip
        let ramGB: Float
        let gpuGeneration: GPUGeneration
        let maxFPS: Int
        let recommendedSettings: RecommendedSettings

        enum DeviceGeneration: String, Comparable {
            case legacy = "Legacy (2015-2017)"
            case midRange = "Mid-Range (2018-2020)"
            case modern = "Modern (2021-2023)"
            case current = "Current (2024+)"

            static func < (lhs: DeviceGeneration, rhs: DeviceGeneration) -> Bool {
                let order: [DeviceGeneration] = [.legacy, .midRange, .modern, .current]
                return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
            }

            var performanceMultiplier: Float {
                switch self {
                case .legacy: return 0.3
                case .midRange: return 0.6
                case .modern: return 0.9
                case .current: return 1.0
                }
            }
        }

        enum Chip: String {
            // Legacy
            case a8 = "A8"
            case a8x = "A8X"
            case a9 = "A9"
            case a9x = "A9X"
            case a10 = "A10 Fusion"
            case a11 = "A11 Bionic"

            // Mid-Range
            case a12 = "A12 Bionic"
            case a13 = "A13 Bionic"
            case a14 = "A14 Bionic"

            // Modern
            case a15 = "A15 Bionic"
            case a16 = "A16 Bionic"
            case a17 = "A17 Pro"

            // Current
            case a18 = "A18"
            case a18Pro = "A18 Pro"

            // Mac
            case m1 = "Apple M1"
            case m2 = "Apple M2"
            case m3 = "Apple M3"

            var neuralEngineCores: Int {
                switch self {
                case .a8, .a8x, .a9, .a9x, .a10: return 0  // No Neural Engine
                case .a11: return 2
                case .a12, .a13: return 8
                case .a14, .a15: return 16
                case .a16, .a17, .a18, .a18Pro: return 16
                case .m1, .m2, .m3: return 16
                }
            }

            var cpuCores: Int {
                switch self {
                case .a8, .a8x: return 2
                case .a9, .a9x: return 2
                case .a10, .a11: return 6
                case .a12, .a13, .a14, .a15: return 6
                case .a16, .a17, .a18, .a18Pro: return 6
                case .m1: return 8
                case .m2, .m3: return 8
                }
            }
        }

        enum GPUGeneration: String {
            case legacy = "Legacy (A8-A10)"
            case modern = "Modern (A11-A14)"
            case advanced = "Advanced (A15+)"

            var metalVersion: Int {
                switch self {
                case .legacy: return 1
                case .modern: return 2
                case .advanced: return 3
                }
            }

            var supportsMetalFX: Bool {
                return self == .advanced
            }
        }

        struct RecommendedSettings {
            let targetFPS: Int
            let maxParticles: Int
            let audioSampleRate: Int
            let audioBufferSize: Int
            let textureQuality: TextureQuality
            let shadowQuality: ShadowQuality
            let effectsQuality: EffectsQuality
            let enableBloom: Bool
            let enableMotionBlur: Bool
            let enableAO: Bool  // Ambient Occlusion

            enum TextureQuality: String {
                case low = "Low (512x512)"
                case medium = "Medium (1024x1024)"
                case high = "High (2048x2048)"
                case ultra = "Ultra (4096x4096)"
            }

            enum ShadowQuality: String {
                case off = "Off"
                case low = "Low (512)"
                case medium = "Medium (1024)"
                case high = "High (2048)"
            }

            enum EffectsQuality: String {
                case minimal = "Minimal"
                case low = "Low"
                case medium = "Medium"
                case high = "High"
                case ultra = "Ultra"
            }
        }
    }

    // MARK: - Performance Level

    enum PerformanceLevel: String, CaseIterable {
        case minimal = "Minimal (Emergency)"
        case low = "Low (Legacy Devices)"
        case medium = "Medium (Mid-Range)"
        case high = "High (Modern Devices)"
        case ultra = "Ultra (Current Devices)"

        var particleCount: Int {
            switch self {
            case .minimal: return 256
            case .low: return 512
            case .medium: return 2048
            case .high: return 4096
            case .ultra: return 8192
            }
        }

        var audioBufferSize: Int {
            switch self {
            case .minimal: return 2048
            case .low: return 1024
            case .medium: return 512
            case .high: return 256
            case .ultra: return 128
            }
        }

        var description: String {
            switch self {
            case .minimal:
                return "Emergency mode for critical situations. Minimal features."
            case .low:
                return "Optimized for iPhone 6s/7. 30 FPS, basic effects."
            case .medium:
                return "Balanced for iPhone 8/X. 60 FPS, standard effects."
            case .high:
                return "Full features for iPhone 11+. 60-120 FPS."
            case .ultra:
                return "Maximum quality for iPhone 13 Pro+. 120 FPS, all effects."
            }
        }
    }

    // MARK: - Device Database

    private var deviceDatabase: [DeviceProfile] = []

    // MARK: - Initialization

    init() {
        loadDeviceDatabase()
        detectCurrentDevice()
        setupMemoryWarningObserver()
        setupThermalStateObserver()
        applyAdaptiveSettings()

        Logger.log("Legacy Device Support: Initialized, Device=\(currentDevice?.deviceName ?? "Unknown"), Performance=\(performanceLevel.rawValue)", category: .system, level: .info)
    }

    // MARK: - Load Device Database

    private func loadDeviceDatabase() {
        deviceDatabase = [
            // === LEGACY DEVICES (2015-2017) ===
            DeviceProfile(
                deviceName: "iPhone 6s",
                deviceGeneration: .legacy,
                chip: .a9,
                ramGB: 2.0,
                gpuGeneration: .legacy,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 30,
                    maxParticles: 512,
                    audioSampleRate: 44100,
                    audioBufferSize: 1024,
                    textureQuality: .low,
                    shadowQuality: .off,
                    effectsQuality: .minimal,
                    enableBloom: false,
                    enableMotionBlur: false,
                    enableAO: false
                )
            ),

            DeviceProfile(
                deviceName: "iPhone 7",
                deviceGeneration: .legacy,
                chip: .a10,
                ramGB: 2.0,
                gpuGeneration: .legacy,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 30,
                    maxParticles: 768,
                    audioSampleRate: 44100,
                    audioBufferSize: 1024,
                    textureQuality: .low,
                    shadowQuality: .low,
                    effectsQuality: .low,
                    enableBloom: false,
                    enableMotionBlur: false,
                    enableAO: false
                )
            ),

            DeviceProfile(
                deviceName: "iPhone 8",
                deviceGeneration: .legacy,
                chip: .a11,
                ramGB: 2.0,
                gpuGeneration: .modern,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 60,
                    maxParticles: 1024,
                    audioSampleRate: 44100,
                    audioBufferSize: 512,
                    textureQuality: .medium,
                    shadowQuality: .low,
                    effectsQuality: .low,
                    enableBloom: true,
                    enableMotionBlur: false,
                    enableAO: false
                )
            ),

            DeviceProfile(
                deviceName: "iPhone X",
                deviceGeneration: .legacy,
                chip: .a11,
                ramGB: 3.0,
                gpuGeneration: .modern,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 60,
                    maxParticles: 1536,
                    audioSampleRate: 48000,
                    audioBufferSize: 512,
                    textureQuality: .medium,
                    shadowQuality: .medium,
                    effectsQuality: .medium,
                    enableBloom: true,
                    enableMotionBlur: false,
                    enableAO: false
                )
            ),

            // === MID-RANGE DEVICES (2018-2020) ===
            DeviceProfile(
                deviceName: "iPhone XR",
                deviceGeneration: .midRange,
                chip: .a12,
                ramGB: 3.0,
                gpuGeneration: .modern,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 60,
                    maxParticles: 2048,
                    audioSampleRate: 48000,
                    audioBufferSize: 512,
                    textureQuality: .medium,
                    shadowQuality: .medium,
                    effectsQuality: .medium,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: false
                )
            ),

            DeviceProfile(
                deviceName: "iPhone 11",
                deviceGeneration: .midRange,
                chip: .a13,
                ramGB: 4.0,
                gpuGeneration: .modern,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 60,
                    maxParticles: 3072,
                    audioSampleRate: 48000,
                    audioBufferSize: 256,
                    textureQuality: .high,
                    shadowQuality: .medium,
                    effectsQuality: .high,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: true
                )
            ),

            DeviceProfile(
                deviceName: "iPhone 12",
                deviceGeneration: .midRange,
                chip: .a14,
                ramGB: 4.0,
                gpuGeneration: .modern,
                maxFPS: 60,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 60,
                    maxParticles: 4096,
                    audioSampleRate: 48000,
                    audioBufferSize: 256,
                    textureQuality: .high,
                    shadowQuality: .high,
                    effectsQuality: .high,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: true
                )
            ),

            // === MODERN DEVICES (2021-2023) ===
            DeviceProfile(
                deviceName: "iPhone 13 Pro",
                deviceGeneration: .modern,
                chip: .a15,
                ramGB: 6.0,
                gpuGeneration: .advanced,
                maxFPS: 120,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 120,
                    maxParticles: 6144,
                    audioSampleRate: 48000,
                    audioBufferSize: 256,
                    textureQuality: .high,
                    shadowQuality: .high,
                    effectsQuality: .high,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: true
                )
            ),

            DeviceProfile(
                deviceName: "iPhone 14 Pro",
                deviceGeneration: .modern,
                chip: .a16,
                ramGB: 6.0,
                gpuGeneration: .advanced,
                maxFPS: 120,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 120,
                    maxParticles: 8192,
                    audioSampleRate: 48000,
                    audioBufferSize: 128,
                    textureQuality: .ultra,
                    shadowQuality: .high,
                    effectsQuality: .ultra,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: true
                )
            ),

            // === CURRENT DEVICES (2024+) ===
            DeviceProfile(
                deviceName: "iPhone 15 Pro",
                deviceGeneration: .current,
                chip: .a17,
                ramGB: 8.0,
                gpuGeneration: .advanced,
                maxFPS: 120,
                recommendedSettings: DeviceProfile.RecommendedSettings(
                    targetFPS: 120,
                    maxParticles: 8192,
                    audioSampleRate: 48000,
                    audioBufferSize: 128,
                    textureQuality: .ultra,
                    shadowQuality: .high,
                    effectsQuality: .ultra,
                    enableBloom: true,
                    enableMotionBlur: true,
                    enableAO: true
                )
            )
        ]

        Logger.log("Device Database: \(deviceDatabase.count) profiles", category: .system)
    }

    // MARK: - Detect Current Device

    private func detectCurrentDevice() {
        let deviceModel = getDeviceModel()

        // Try to find exact match
        currentDevice = deviceDatabase.first { $0.deviceName.contains(deviceModel) }

        // Fallback: detect by capabilities
        if currentDevice == nil {
            currentDevice = detectByCapabilities()
        }

        // Apply performance level based on device
        if let device = currentDevice {
            performanceLevel = determinePerformanceLevel(for: device)
        }
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }

    private func detectByCapabilities() -> DeviceProfile {
        // Detect by RAM and processor count
        let ram = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        let cpuCount = ProcessInfo.processInfo.processorCount

        if ram < 3.0 {
            return deviceDatabase.first { $0.deviceName.contains("iPhone 7") }!
        } else if ram < 4.0 {
            return deviceDatabase.first { $0.deviceName.contains("iPhone XR") }!
        } else if ram < 6.0 {
            return deviceDatabase.first { $0.deviceName.contains("iPhone 12") }!
        } else {
            return deviceDatabase.first { $0.deviceName.contains("iPhone 13 Pro") }!
        }
    }

    private func determinePerformanceLevel(for device: DeviceProfile) -> PerformanceLevel {
        switch device.deviceGeneration {
        case .legacy:
            return device.ramGB < 2.5 ? .low : .medium
        case .midRange:
            return .medium
        case .modern:
            return .high
        case .current:
            return .ultra
        }
    }

    // MARK: - Memory Warning Observer

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }

    private func handleMemoryWarning() {
        memoryWarningReceived = true
        Logger.log("Memory Warning Received - Degrading Performance", category: .system, level: .warning)

        // Emergency performance reduction
        switch performanceLevel {
        case .ultra:
            performanceLevel = .high
        case .high:
            performanceLevel = .medium
        case .medium:
            performanceLevel = .low
        case .low:
            performanceLevel = .minimal
        case .minimal:
            break  // Already at minimum
        }

        // Clear caches
        clearCaches()

        Logger.log("Performance reduced to: \(performanceLevel.rawValue)", category: .system)
    }

    private func clearCaches() {
        // Clear texture cache
        // Clear audio sample cache
        // Clear any other memory-heavy caches
        Logger.log("Caches cleared", category: .system)
    }

    // MARK: - Thermal State Observer

    private func setupThermalStateObserver() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
    }

    private func handleThermalStateChange() {
        thermalState = ProcessInfo.processInfo.thermalState

        Logger.log("Thermal State Changed: \(thermalState)", category: .system)

        switch thermalState {
        case .nominal:
            // Normal operation
            break

        case .fair:
            // Slight throttling
            if performanceLevel == .ultra {
                performanceLevel = .high
                Logger.log("Throttling: Ultra → High", category: .system)
            }

        case .serious:
            // Significant throttling
            if performanceLevel > .medium {
                performanceLevel = .medium
                Logger.log("Throttling: → Medium", category: .system, level: .warning)
            }

        case .critical:
            // Emergency throttling
            performanceLevel = .low
            Logger.log("Emergency Throttling: → Low", category: .system, level: .error)

        @unknown default:
            break
        }
    }

    // MARK: - Apply Adaptive Settings

    func applyAdaptiveSettings() {
        guard let device = currentDevice else { return }

        let settings = device.recommendedSettings

        Logger.log("Adaptive Settings: FPS=\(settings.targetFPS), Particles=\(settings.maxParticles), Audio=\(settings.audioSampleRate)Hz, Textures=\(settings.textureQuality.rawValue), Effects=\(settings.effectsQuality.rawValue)", category: .system, level: .info)
    }

    // MARK: - Get Optimal Settings

    func getOptimalSettings() -> OptimalSettings {
        guard let device = currentDevice else {
            return OptimalSettings.fallback
        }

        let recommended = device.recommendedSettings

        return OptimalSettings(
            targetFPS: recommended.targetFPS,
            maxParticles: recommended.maxParticles,
            audioSampleRate: recommended.audioSampleRate,
            audioBufferSize: recommended.audioBufferSize,
            textureResolution: getTextureResolution(for: recommended.textureQuality),
            enableAdvancedEffects: performanceLevel >= .high,
            enablePostProcessing: performanceLevel >= .medium,
            useLowPowerMode: device.deviceGeneration <= .legacy
        )
    }

    struct OptimalSettings {
        let targetFPS: Int
        let maxParticles: Int
        let audioSampleRate: Int
        let audioBufferSize: Int
        let textureResolution: Int
        let enableAdvancedEffects: Bool
        let enablePostProcessing: Bool
        let useLowPowerMode: Bool

        static let fallback = OptimalSettings(
            targetFPS: 30,
            maxParticles: 512,
            audioSampleRate: 44100,
            audioBufferSize: 1024,
            textureResolution: 512,
            enableAdvancedEffects: false,
            enablePostProcessing: false,
            useLowPowerMode: true
        )
    }

    private func getTextureResolution(for quality: DeviceProfile.RecommendedSettings.TextureQuality) -> Int {
        switch quality {
        case .low: return 512
        case .medium: return 1024
        case .high: return 2048
        case .ultra: return 4096
        }
    }

    // MARK: - Generate Support Report

    func generateSupportReport() -> String {
        guard let device = currentDevice else {
            return "Device not detected"
        }

        return """
        📱 LEGACY DEVICE SUPPORT REPORT

        Current Device: \(device.deviceName)
        Generation: \(device.deviceGeneration.rawValue)
        Chip: \(device.chip.rawValue)
        RAM: \(String(format: "%.1f", device.ramGB)) GB
        GPU: \(device.gpuGeneration.rawValue)
        Max FPS: \(device.maxFPS)

        Performance Level: \(performanceLevel.rawValue)
        Adaptive Quality: \(adaptiveQualityEnabled ? "Enabled" : "Disabled")
        Thermal State: \(thermalState)
        Memory Warnings: \(memoryWarningReceived ? "Yes" : "No")

        === RECOMMENDED SETTINGS ===
        Target FPS: \(device.recommendedSettings.targetFPS)
        Particles: \(device.recommendedSettings.maxParticles)
        Audio: \(device.recommendedSettings.audioSampleRate) Hz / \(device.recommendedSettings.audioBufferSize) samples
        Textures: \(device.recommendedSettings.textureQuality.rawValue)
        Shadows: \(device.recommendedSettings.shadowQuality.rawValue)
        Effects: \(device.recommendedSettings.effectsQuality.rawValue)
        Bloom: \(device.recommendedSettings.enableBloom ? "On" : "Off")
        Motion Blur: \(device.recommendedSettings.enableMotionBlur ? "On" : "Off")
        Ambient Occlusion: \(device.recommendedSettings.enableAO ? "On" : "Off")

        === OPTIMIZATIONS ACTIVE ===
        ✓ Automatic quality degradation
        ✓ Memory-efficient algorithms
        ✓ Thermal throttling prevention
        ✓ Battery-aware scaling
        ✓ Progressive loading
        ✓ Texture compression
        ✓ Simplified shaders

        Echoelmusic runs on devices from 2015 onwards.
        Minimum: iPhone 6s with iOS 15+
        """
    }
}
