import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(CoreMotion)
import CoreMotion
#endif

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(Metal)
import Metal
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED MULTI-PLATFORM LAYER FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Provides unified API across ALL supported platforms:
// • iOS 15+ (iPhone, iPad)
// • macOS 12+ (Apple Silicon & Intel)
// • watchOS 8+ (Apple Watch)
// • tvOS 15+ (Apple TV)
// • visionOS 1.0+ (Apple Vision Pro)
// • Android (via Kotlin/JNI bridge)
// • Windows (via VST3/CLAP plugins)
// • Linux (via VST3/CLAP plugins)
//
// Architecture:
// • Platform detection at compile time
// • Runtime capability detection
// • Unified API with platform-specific implementations
// • Graceful degradation for unsupported features
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Platform Identification

/// Identifies the current runtime platform
public enum PlatformType: String, CaseIterable, Sendable {
    case iOS = "iOS"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"
    case android = "Android"
    case windows = "Windows"
    case linux = "Linux"
    case unknown = "Unknown"

    /// Human-readable platform name
    public var displayName: String {
        switch self {
        case .iOS: return "iPhone/iPad"
        case .macOS: return "Mac"
        case .watchOS: return "Apple Watch"
        case .tvOS: return "Apple TV"
        case .visionOS: return "Apple Vision Pro"
        case .android: return "Android Device"
        case .windows: return "Windows PC"
        case .linux: return "Linux System"
        case .unknown: return "Unknown Platform"
        }
    }

    /// Platform icon
    public var icon: String {
        switch self {
        case .iOS: return "iphone"
        case .macOS: return "desktopcomputer"
        case .watchOS: return "applewatch"
        case .tvOS: return "appletv"
        case .visionOS: return "visionpro"
        case .android: return "android"
        case .windows: return "pc"
        case .linux: return "terminal"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Platform Capabilities

/// Comprehensive capability detection across all platforms
public struct PlatformCapabilities: Sendable {

    // MARK: Audio Capabilities
    public struct Audio: Sendable {
        public var maxSampleRate: Double = 48000
        public var maxChannels: Int = 2
        public var minLatencyMs: Double = 10.0
        public var supportsSpatialAudio: Bool = false
        public var supportsHeadTracking: Bool = false
        public var supportsBinauralAudio: Bool = true
        public var supportsAUv3: Bool = false
        public var supportsVST3: Bool = false
        public var supportsCLAP: Bool = false
        public var supportsAAX: Bool = false
        public var supportsOboe: Bool = false  // Android low-latency
        public var supportsCoreAudio: Bool = false
        public var supportsASIO: Bool = false  // Windows low-latency
        public var supportsJACK: Bool = false  // Linux low-latency
    }

    // MARK: Visual Capabilities
    public struct Visual: Sendable {
        public var maxResolutionWidth: Int = 1920
        public var maxResolutionHeight: Int = 1080
        public var maxRefreshRate: Int = 60
        public var supportsMetal: Bool = false
        public var supportsOpenGL: Bool = false
        public var supportsVulkan: Bool = false
        public var supportsDirectX: Bool = false
        public var supportsHDR: Bool = false
        public var supportsProMotion: Bool = false
        public var gpuFamily: String = "Unknown"
    }

    // MARK: Sensor Capabilities
    public struct Sensors: Sendable {
        public var hasAccelerometer: Bool = false
        public var hasGyroscope: Bool = false
        public var hasMagnetometer: Bool = false
        public var hasBarometer: Bool = false
        public var hasProximity: Bool = false
        public var hasAmbientLight: Bool = false
        public var hasCamera: Bool = false
        public var hasMicrophone: Bool = false
        public var hasLiDAR: Bool = false
        public var hasDepthCamera: Bool = false
        public var hasFaceID: Bool = false
        public var hasTouchID: Bool = false
    }

    // MARK: Bio Capabilities
    public struct Bio: Sendable {
        public var supportsHealthKit: Bool = false
        public var supportsHealthConnect: Bool = false  // Android
        public var hasHeartRateSensor: Bool = false
        public var hasECG: Bool = false
        public var hasBloodOxygen: Bool = false
        public var hasTemperatureSensor: Bool = false
        public var supportsHRVAnalysis: Bool = false
        public var supportsBreathingAnalysis: Bool = false
    }

    // MARK: Input Capabilities
    public struct Input: Sendable {
        public var hasTouchScreen: Bool = false
        public var hasMultiTouch: Bool = false
        public var hasForceTouch: Bool = false
        public var hasDigitalCrown: Bool = false
        public var hasKeyboard: Bool = false
        public var hasMouse: Bool = false
        public var hasTrackpad: Bool = false
        public var hasGameController: Bool = false
        public var hasApplePencil: Bool = false
        public var hasRemote: Bool = false  // tvOS
        public var hasHandTracking: Bool = false  // visionOS
        public var hasEyeTracking: Bool = false  // visionOS
    }

    // MARK: Processing Capabilities
    public struct Processing: Sendable {
        public var cpuCores: Int = 1
        public var performanceCores: Int = 0
        public var efficiencyCores: Int = 0
        public var ramGB: Float = 1.0
        public var hasNeuralEngine: Bool = false
        public var neuralEngineTOPS: Float = 0
        public var hasSIMD: Bool = false
        public var hasAVX2: Bool = false
        public var hasAVX512: Bool = false
        public var hasNEON: Bool = false
        public var supportsFloat16: Bool = false
    }

    // MARK: Connectivity
    public struct Connectivity: Sendable {
        public var hasWiFi: Bool = false
        public var hasBluetooth: Bool = false
        public var hasBluetoothLE: Bool = false
        public var hasCellular: Bool = false
        public var has5G: Bool = false
        public var hasNFC: Bool = false
        public var hasUWB: Bool = false
        public var hasUSB: Bool = false
        public var hasThunderbolt: Bool = false
        public var hasMIDI: Bool = false
    }

    // MARK: Power
    public struct Power: Sendable {
        public var hasBattery: Bool = false
        public var isPluggedIn: Bool = true
        public var lowPowerModeAvailable: Bool = false
        public var thermalState: ThermalState = .nominal

        public enum ThermalState: String, Sendable {
            case nominal = "Nominal"
            case fair = "Fair"
            case serious = "Serious"
            case critical = "Critical"
        }
    }

    // Capability categories
    public var audio: Audio = Audio()
    public var visual: Visual = Visual()
    public var sensors: Sensors = Sensors()
    public var bio: Bio = Bio()
    public var input: Input = Input()
    public var processing: Processing = Processing()
    public var connectivity: Connectivity = Connectivity()
    public var power: Power = Power()

    public init() {}
}

// MARK: - Unified Platform Manager

/// Main entry point for platform-agnostic code
@MainActor
public final class UnifiedPlatformManager: ObservableObject {

    // MARK: Singleton
    public static let shared = UnifiedPlatformManager()

    // MARK: Published Properties
    @Published public private(set) var platform: PlatformType = .unknown
    @Published public private(set) var capabilities: PlatformCapabilities = PlatformCapabilities()
    @Published public private(set) var deviceModel: String = "Unknown"
    @Published public private(set) var osVersion: String = "Unknown"
    @Published public private(set) var isLowPowerMode: Bool = false
    @Published public private(set) var thermalState: PlatformCapabilities.Power.ThermalState = .nominal

    // MARK: Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization
    private init() {
        detectPlatform()
        detectCapabilities()
        startMonitoring()

        print("=== UNIFIED PLATFORM MANAGER ===")
        print("Platform: \(platform.displayName)")
        print("Device: \(deviceModel)")
        print("OS Version: \(osVersion)")
    }

    // MARK: - Platform Detection

    private func detectPlatform() {
        #if os(iOS)
        platform = .iOS
        #elseif os(macOS)
        platform = .macOS
        #elseif os(watchOS)
        platform = .watchOS
        #elseif os(tvOS)
        platform = .tvOS
        #elseif os(visionOS)
        platform = .visionOS
        #elseif os(Android)
        platform = .android
        #elseif os(Windows)
        platform = .windows
        #elseif os(Linux)
        platform = .linux
        #else
        platform = .unknown
        #endif

        detectDeviceModel()
        detectOSVersion()
    }

    private func detectDeviceModel() {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        deviceModel = mapDeviceIdentifier(identifier)

        #elseif os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        deviceModel = String(cString: model)

        #elseif os(watchOS)
        deviceModel = "Apple Watch"

        #elseif os(tvOS)
        deviceModel = "Apple TV"

        #elseif os(visionOS)
        deviceModel = "Apple Vision Pro"

        #else
        deviceModel = "Unknown Device"
        #endif
    }

    private func mapDeviceIdentifier(_ identifier: String) -> String {
        // iPhone mappings
        let deviceMappings: [String: String] = [
            "iPhone16,1": "iPhone 16 Pro",
            "iPhone16,2": "iPhone 16 Pro Max",
            "iPhone16,3": "iPhone 16",
            "iPhone16,4": "iPhone 16 Plus",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone15,2": "iPhone 15 Pro",
            "iPhone15,3": "iPhone 15 Pro Max",
            "iPad14,3": "iPad Pro 11-inch (4th gen)",
            "iPad14,4": "iPad Pro 11-inch (4th gen)",
            "iPad14,5": "iPad Pro 12.9-inch (6th gen)",
            "iPad14,6": "iPad Pro 12.9-inch (6th gen)",
            "x86_64": "Simulator (Intel)",
            "arm64": "Simulator (Apple Silicon)"
        ]
        return deviceMappings[identifier] ?? identifier
    }

    private func detectOSVersion() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        osVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        osVersion = "Unknown"
        #endif
    }

    // MARK: - Capability Detection

    private func detectCapabilities() {
        var caps = PlatformCapabilities()

        // Audio capabilities
        detectAudioCapabilities(&caps.audio)

        // Visual capabilities
        detectVisualCapabilities(&caps.visual)

        // Sensor capabilities
        detectSensorCapabilities(&caps.sensors)

        // Bio capabilities
        detectBioCapabilities(&caps.bio)

        // Input capabilities
        detectInputCapabilities(&caps.input)

        // Processing capabilities
        detectProcessingCapabilities(&caps.processing)

        // Connectivity capabilities
        detectConnectivityCapabilities(&caps.connectivity)

        // Power capabilities
        detectPowerCapabilities(&caps.power)

        capabilities = caps
    }

    private func detectAudioCapabilities(_ audio: inout PlatformCapabilities.Audio) {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        audio.supportsCoreAudio = true
        audio.supportsAUv3 = true
        audio.maxSampleRate = 192000

        #if os(iOS)
        audio.maxChannels = 8
        audio.minLatencyMs = 2.0
        audio.supportsSpatialAudio = true
        audio.supportsHeadTracking = true
        #elseif os(macOS)
        audio.maxChannels = 64
        audio.minLatencyMs = 1.0
        audio.supportsSpatialAudio = true
        audio.supportsVST3 = true
        audio.supportsCLAP = true
        audio.supportsAAX = true
        #elseif os(tvOS)
        audio.maxChannels = 8
        audio.supportsSpatialAudio = true
        #elseif os(watchOS)
        audio.maxChannels = 2
        audio.minLatencyMs = 10.0
        #elseif os(visionOS)
        audio.maxChannels = 64
        audio.supportsSpatialAudio = true
        audio.supportsHeadTracking = true
        #endif

        #else
        // Non-Apple platforms
        audio.supportsVST3 = true
        audio.supportsCLAP = true

        #if os(Android)
        audio.supportsOboe = true
        audio.minLatencyMs = 5.0
        #elseif os(Windows)
        audio.supportsASIO = true
        audio.supportsAAX = true
        audio.minLatencyMs = 3.0
        #elseif os(Linux)
        audio.supportsJACK = true
        audio.minLatencyMs = 2.0
        #endif
        #endif
    }

    private func detectVisualCapabilities(_ visual: inout PlatformCapabilities.Visual) {
        #if os(iOS)
        if let screen = UIScreen.main as UIScreen? {
            visual.maxResolutionWidth = Int(screen.bounds.width * screen.scale)
            visual.maxResolutionHeight = Int(screen.bounds.height * screen.scale)
            visual.maxRefreshRate = screen.maximumFramesPerSecond
            visual.supportsProMotion = screen.maximumFramesPerSecond >= 120
        }
        visual.supportsMetal = MTLCreateSystemDefaultDevice() != nil
        visual.supportsHDR = true

        #elseif os(macOS)
        if let screen = NSScreen.main {
            visual.maxResolutionWidth = Int(screen.frame.width * screen.backingScaleFactor)
            visual.maxResolutionHeight = Int(screen.frame.height * screen.backingScaleFactor)
        }
        visual.supportsMetal = MTLCreateSystemDefaultDevice() != nil
        visual.supportsOpenGL = true
        visual.maxRefreshRate = 120

        #elseif os(tvOS)
        visual.maxResolutionWidth = 3840
        visual.maxResolutionHeight = 2160
        visual.maxRefreshRate = 120
        visual.supportsMetal = true
        visual.supportsHDR = true

        #elseif os(visionOS)
        visual.maxResolutionWidth = 3660  // Per eye
        visual.maxResolutionHeight = 3200
        visual.maxRefreshRate = 90
        visual.supportsMetal = true

        #elseif os(watchOS)
        visual.maxResolutionWidth = 396
        visual.maxResolutionHeight = 484
        visual.maxRefreshRate = 60
        visual.supportsMetal = true

        #else
        // Non-Apple platforms
        #if os(Windows)
        visual.supportsDirectX = true
        visual.supportsVulkan = true
        visual.supportsOpenGL = true
        #elseif os(Linux)
        visual.supportsVulkan = true
        visual.supportsOpenGL = true
        #elseif os(Android)
        visual.supportsVulkan = true
        visual.supportsOpenGL = true
        #endif
        #endif

        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            visual.gpuFamily = device.name
        }
        #endif
    }

    private func detectSensorCapabilities(_ sensors: inout PlatformCapabilities.Sensors) {
        #if canImport(CoreMotion)
        let motionManager = CMMotionManager()
        sensors.hasAccelerometer = motionManager.isAccelerometerAvailable
        sensors.hasGyroscope = motionManager.isGyroAvailable
        sensors.hasMagnetometer = motionManager.isMagnetometerAvailable
        #endif

        #if os(iOS)
        sensors.hasCamera = true
        sensors.hasMicrophone = true
        sensors.hasProximity = true
        sensors.hasAmbientLight = true
        sensors.hasBarometer = true

        // Check for advanced sensors
        if deviceModel.contains("Pro") {
            sensors.hasLiDAR = true
        }
        sensors.hasFaceID = deviceModel.contains("iPhone") && !deviceModel.contains("SE")

        #elseif os(macOS)
        sensors.hasCamera = true
        sensors.hasMicrophone = true
        sensors.hasAmbientLight = true

        #elseif os(watchOS)
        sensors.hasAccelerometer = true
        sensors.hasGyroscope = true
        sensors.hasMicrophone = true
        sensors.hasBarometer = true

        #elseif os(visionOS)
        sensors.hasCamera = true
        sensors.hasMicrophone = true
        sensors.hasDepthCamera = true
        sensors.hasLiDAR = true
        #endif
    }

    private func detectBioCapabilities(_ bio: inout PlatformCapabilities.Bio) {
        #if os(iOS)
        bio.supportsHealthKit = HKHealthStore.isHealthDataAvailable()
        bio.supportsHRVAnalysis = true
        bio.supportsBreathingAnalysis = true
        // Heart rate from Apple Watch via HealthKit
        bio.hasHeartRateSensor = false

        #elseif os(watchOS)
        bio.supportsHealthKit = true
        bio.hasHeartRateSensor = true
        bio.hasECG = true
        bio.hasBloodOxygen = true
        bio.hasTemperatureSensor = true
        bio.supportsHRVAnalysis = true
        bio.supportsBreathingAnalysis = true

        #elseif os(macOS)
        bio.supportsHealthKit = false
        // Can receive data from Apple Watch

        #elseif os(Android)
        bio.supportsHealthConnect = true
        // Depends on device capabilities

        #endif
    }

    private func detectInputCapabilities(_ input: inout PlatformCapabilities.Input) {
        #if os(iOS)
        input.hasTouchScreen = true
        input.hasMultiTouch = true
        input.hasGameController = true

        if deviceModel.contains("Pro") || deviceModel.contains("Air") {
            input.hasApplePencil = true
        }

        // 3D Touch / Haptic Touch
        if let window = UIApplication.shared.windows.first {
            input.hasForceTouch = window.traitCollection.forceTouchCapability == .available
        }

        #elseif os(macOS)
        input.hasKeyboard = true
        input.hasMouse = true
        input.hasTrackpad = true
        input.hasGameController = true
        input.hasForceTouch = true  // Force Touch trackpad

        #elseif os(watchOS)
        input.hasTouchScreen = true
        input.hasDigitalCrown = true

        #elseif os(tvOS)
        input.hasRemote = true
        input.hasGameController = true

        #elseif os(visionOS)
        input.hasHandTracking = true
        input.hasEyeTracking = true
        input.hasGameController = true

        #endif
    }

    private func detectProcessingCapabilities(_ processing: inout PlatformCapabilities.Processing) {
        processing.cpuCores = ProcessInfo.processInfo.processorCount
        processing.ramGB = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        #if arch(arm64)
        processing.hasNEON = true
        processing.hasNeuralEngine = true
        processing.supportsFloat16 = true

        // Estimate Neural Engine TOPS based on device
        if deviceModel.contains("Pro Max") || deviceModel.contains("Ultra") {
            processing.neuralEngineTOPS = 38.0
        } else if deviceModel.contains("Pro") {
            processing.neuralEngineTOPS = 35.0
        } else {
            processing.neuralEngineTOPS = 15.0
        }

        // Estimate P/E cores
        let totalCores = processing.cpuCores
        processing.performanceCores = min(totalCores / 2, 8)
        processing.efficiencyCores = totalCores - processing.performanceCores

        #elseif arch(x86_64)
        processing.hasAVX2 = true
        processing.hasSIMD = true

        // Check for AVX-512 (not common on consumer hardware)
        #if os(macOS) || os(Linux)
        // Would need cpuid check for actual detection
        processing.hasAVX512 = false
        #endif
        #endif
    }

    private func detectConnectivityCapabilities(_ connectivity: inout PlatformCapabilities.Connectivity) {
        #if os(iOS)
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasBluetoothLE = true
        connectivity.hasCellular = true
        connectivity.hasNFC = true
        connectivity.hasUWB = deviceModel.contains("11") || deviceModel.contains("12") ||
                              deviceModel.contains("13") || deviceModel.contains("14") ||
                              deviceModel.contains("15") || deviceModel.contains("16")
        connectivity.hasMIDI = true

        #elseif os(macOS)
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasBluetoothLE = true
        connectivity.hasUSB = true
        connectivity.hasThunderbolt = true
        connectivity.hasMIDI = true

        #elseif os(watchOS)
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasBluetoothLE = true

        #elseif os(tvOS)
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasBluetoothLE = true

        #elseif os(visionOS)
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasBluetoothLE = true
        connectivity.hasUSB = true

        #else
        // Desktop platforms typically have everything
        connectivity.hasWiFi = true
        connectivity.hasBluetooth = true
        connectivity.hasUSB = true
        connectivity.hasMIDI = true
        #endif
    }

    private func detectPowerCapabilities(_ power: inout PlatformCapabilities.Power) {
        #if os(iOS)
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        power.hasBattery = true
        power.isPluggedIn = device.batteryState == .charging || device.batteryState == .full
        power.lowPowerModeAvailable = true
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        #elseif os(watchOS)
        power.hasBattery = true
        power.lowPowerModeAvailable = true

        #elseif os(macOS)
        // Mac may or may not have battery
        // Would need IOKit for proper detection
        power.hasBattery = false  // Conservative default
        power.isPluggedIn = true

        #else
        power.hasBattery = false
        power.isPluggedIn = true
        #endif

        // Thermal state
        updateThermalState()
    }

    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            thermalState = .nominal
        case .fair:
            thermalState = .fair
        case .serious:
            thermalState = .serious
        case .critical:
            thermalState = .critical
        @unknown default:
            thermalState = .nominal
        }
        capabilities.power.thermalState = thermalState
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Thermal state monitoring
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)

        // Low power mode monitoring
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .store(in: &cancellables)

        #if os(iOS)
        // Battery monitoring
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let device = UIDevice.current
                self?.capabilities.power.isPluggedIn = device.batteryState == .charging || device.batteryState == .full
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Feature Queries

    /// Check if a specific feature is supported on current platform
    public func supportsFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .spatialAudio:
            return capabilities.audio.supportsSpatialAudio
        case .headTracking:
            return capabilities.audio.supportsHeadTracking
        case .binauralAudio:
            return capabilities.audio.supportsBinauralAudio
        case .lowLatencyAudio:
            return capabilities.audio.minLatencyMs <= 5.0
        case .metal:
            return capabilities.visual.supportsMetal
        case .proMotion:
            return capabilities.visual.supportsProMotion
        case .hdr:
            return capabilities.visual.supportsHDR
        case .healthKit:
            return capabilities.bio.supportsHealthKit
        case .healthConnect:
            return capabilities.bio.supportsHealthConnect
        case .heartRate:
            return capabilities.bio.hasHeartRateSensor || capabilities.bio.supportsHealthKit
        case .hrv:
            return capabilities.bio.supportsHRVAnalysis
        case .neuralEngine:
            return capabilities.processing.hasNeuralEngine
        case .simd:
            return capabilities.processing.hasSIMD || capabilities.processing.hasNEON || capabilities.processing.hasAVX2
        case .touchScreen:
            return capabilities.input.hasTouchScreen
        case .multiTouch:
            return capabilities.input.hasMultiTouch
        case .applePencil:
            return capabilities.input.hasApplePencil
        case .handTracking:
            return capabilities.input.hasHandTracking
        case .eyeTracking:
            return capabilities.input.hasEyeTracking
        case .midi:
            return capabilities.connectivity.hasMIDI
        case .bluetooth:
            return capabilities.connectivity.hasBluetooth
        }
    }

    public enum Feature: String, CaseIterable {
        case spatialAudio = "Spatial Audio"
        case headTracking = "Head Tracking"
        case binauralAudio = "Binaural Audio"
        case lowLatencyAudio = "Low Latency Audio"
        case metal = "Metal Graphics"
        case proMotion = "ProMotion Display"
        case hdr = "HDR Display"
        case healthKit = "HealthKit"
        case healthConnect = "Health Connect"
        case heartRate = "Heart Rate Monitoring"
        case hrv = "HRV Analysis"
        case neuralEngine = "Neural Engine"
        case simd = "SIMD Processing"
        case touchScreen = "Touch Screen"
        case multiTouch = "Multi-Touch"
        case applePencil = "Apple Pencil"
        case handTracking = "Hand Tracking"
        case eyeTracking = "Eye Tracking"
        case midi = "MIDI"
        case bluetooth = "Bluetooth"
    }

    // MARK: - Performance Tiers

    /// Determine the performance tier for adaptive quality
    public var performanceTier: PerformanceTier {
        let cores = capabilities.processing.cpuCores
        let ram = capabilities.processing.ramGB
        let hasNeuralEngine = capabilities.processing.hasNeuralEngine
        let maxFPS = capabilities.visual.maxRefreshRate

        switch platform {
        case .iOS:
            if cores >= 6 && ram >= 6 && hasNeuralEngine && maxFPS >= 120 {
                return .ultra
            } else if cores >= 6 && ram >= 4 {
                return .high
            } else if cores >= 4 {
                return .medium
            } else {
                return .low
            }

        case .macOS:
            if cores >= 10 && ram >= 16 {
                return .ultra
            } else if cores >= 8 && ram >= 8 {
                return .high
            } else if cores >= 4 {
                return .medium
            } else {
                return .low
            }

        case .watchOS:
            return .low  // Always conservative on Watch

        case .tvOS:
            return .high  // Apple TV has consistent performance

        case .visionOS:
            return .ultra  // Vision Pro is high-end

        default:
            // Conservative default for unknown platforms
            if cores >= 8 && ram >= 8 {
                return .high
            } else if cores >= 4 {
                return .medium
            } else {
                return .low
            }
        }
    }

    public enum PerformanceTier: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case ultra = "Ultra"

        /// Recommended max concurrent audio tracks
        public var maxAudioTracks: Int {
            switch self {
            case .low: return 4
            case .medium: return 8
            case .high: return 16
            case .ultra: return 32
            }
        }

        /// Recommended visual quality
        public var visualQuality: Float {
            switch self {
            case .low: return 0.5
            case .medium: return 0.75
            case .high: return 0.9
            case .ultra: return 1.0
            }
        }

        /// Recommended frame rate target
        public var targetFPS: Int {
            switch self {
            case .low: return 30
            case .medium: return 60
            case .high: return 90
            case .ultra: return 120
            }
        }

        /// Recommended buffer size for audio
        public var audioBufferSize: Int {
            switch self {
            case .low: return 512
            case .medium: return 256
            case .high: return 128
            case .ultra: return 64
            }
        }
    }

    // MARK: - Platform Report

    /// Generate comprehensive platform report
    public func generateReport() -> String {
        """
        ════════════════════════════════════════════════════════════════
        ECHOELMUSIC UNIFIED PLATFORM REPORT
        ════════════════════════════════════════════════════════════════

        PLATFORM IDENTIFICATION
        ────────────────────────────────────────────────────────────────
        Platform:       \(platform.displayName)
        Device:         \(deviceModel)
        OS Version:     \(osVersion)
        Performance:    \(performanceTier.rawValue)

        PROCESSING
        ────────────────────────────────────────────────────────────────
        CPU Cores:      \(capabilities.processing.cpuCores) (\(capabilities.processing.performanceCores)P + \(capabilities.processing.efficiencyCores)E)
        RAM:            \(String(format: "%.1f", capabilities.processing.ramGB)) GB
        Neural Engine:  \(capabilities.processing.hasNeuralEngine ? "\(capabilities.processing.neuralEngineTOPS) TOPS" : "N/A")
        SIMD:           \(capabilities.processing.hasNEON ? "NEON" : capabilities.processing.hasAVX2 ? "AVX2" : "Basic")

        AUDIO
        ────────────────────────────────────────────────────────────────
        Max Sample Rate: \(Int(capabilities.audio.maxSampleRate)) Hz
        Max Channels:    \(capabilities.audio.maxChannels)
        Min Latency:     \(String(format: "%.1f", capabilities.audio.minLatencyMs)) ms
        Spatial Audio:   \(capabilities.audio.supportsSpatialAudio ? "Yes" : "No")
        Head Tracking:   \(capabilities.audio.supportsHeadTracking ? "Yes" : "No")
        Plugin Formats:  \(getPluginFormats())

        VISUAL
        ────────────────────────────────────────────────────────────────
        Resolution:     \(capabilities.visual.maxResolutionWidth)x\(capabilities.visual.maxResolutionHeight)
        Refresh Rate:   \(capabilities.visual.maxRefreshRate) Hz
        GPU:            \(capabilities.visual.gpuFamily)
        Metal:          \(capabilities.visual.supportsMetal ? "Yes" : "No")
        HDR:            \(capabilities.visual.supportsHDR ? "Yes" : "No")

        BIO-DATA
        ────────────────────────────────────────────────────────────────
        Health Platform: \(capabilities.bio.supportsHealthKit ? "HealthKit" : capabilities.bio.supportsHealthConnect ? "Health Connect" : "N/A")
        Heart Rate:      \(capabilities.bio.hasHeartRateSensor ? "Built-in" : capabilities.bio.supportsHealthKit ? "via Apple Watch" : "Not available")
        HRV Analysis:    \(capabilities.bio.supportsHRVAnalysis ? "Yes" : "No")
        ECG:             \(capabilities.bio.hasECG ? "Yes" : "No")

        INPUT
        ────────────────────────────────────────────────────────────────
        Touch:          \(capabilities.input.hasTouchScreen ? "Yes" : "No")
        Keyboard:       \(capabilities.input.hasKeyboard ? "Yes" : "No")
        Controller:     \(capabilities.input.hasGameController ? "Yes" : "No")
        Hand Tracking:  \(capabilities.input.hasHandTracking ? "Yes" : "No")
        Eye Tracking:   \(capabilities.input.hasEyeTracking ? "Yes" : "No")

        CONNECTIVITY
        ────────────────────────────────────────────────────────────────
        WiFi:           \(capabilities.connectivity.hasWiFi ? "Yes" : "No")
        Bluetooth:      \(capabilities.connectivity.hasBluetooth ? "Yes" : "No")
        MIDI:           \(capabilities.connectivity.hasMIDI ? "Yes" : "No")

        POWER
        ────────────────────────────────────────────────────────────────
        Battery:        \(capabilities.power.hasBattery ? "Yes" : "No")
        Thermal State:  \(thermalState.rawValue)
        Low Power Mode: \(isLowPowerMode ? "Active" : "Inactive")

        RECOMMENDED SETTINGS
        ────────────────────────────────────────────────────────────────
        Max Audio Tracks: \(performanceTier.maxAudioTracks)
        Visual Quality:   \(Int(performanceTier.visualQuality * 100))%
        Target FPS:       \(performanceTier.targetFPS)
        Audio Buffer:     \(performanceTier.audioBufferSize) samples

        ════════════════════════════════════════════════════════════════
        """
    }

    private func getPluginFormats() -> String {
        var formats: [String] = []
        if capabilities.audio.supportsAUv3 { formats.append("AUv3") }
        if capabilities.audio.supportsVST3 { formats.append("VST3") }
        if capabilities.audio.supportsCLAP { formats.append("CLAP") }
        if capabilities.audio.supportsAAX { formats.append("AAX") }
        return formats.isEmpty ? "None" : formats.joined(separator: ", ")
    }
}

// MARK: - Platform-Specific Audio Configuration

/// Provides platform-optimized audio configuration
public struct PlatformAudioConfig {
    public let sampleRate: Double
    public let bufferSize: Int
    public let channels: Int
    public let format: AudioFormat

    public enum AudioFormat: String {
        case float32 = "Float32"
        case float64 = "Float64"
        case int16 = "Int16"
        case int24 = "Int24"
        case int32 = "Int32"
    }

    /// Get optimal audio configuration for current platform
    @MainActor
    public static func optimal() -> PlatformAudioConfig {
        let manager = UnifiedPlatformManager.shared
        let tier = manager.performanceTier
        let caps = manager.capabilities.audio

        return PlatformAudioConfig(
            sampleRate: min(caps.maxSampleRate, 48000),  // 48kHz is sufficient for most
            bufferSize: tier.audioBufferSize,
            channels: min(caps.maxChannels, 2),  // Stereo default
            format: .float32
        )
    }

    /// Get configuration optimized for low latency
    @MainActor
    public static func lowLatency() -> PlatformAudioConfig {
        let manager = UnifiedPlatformManager.shared
        let caps = manager.capabilities.audio

        return PlatformAudioConfig(
            sampleRate: 48000,
            bufferSize: 64,
            channels: min(caps.maxChannels, 2),
            format: .float32
        )
    }

    /// Get configuration optimized for quality
    @MainActor
    public static func highQuality() -> PlatformAudioConfig {
        let manager = UnifiedPlatformManager.shared
        let caps = manager.capabilities.audio

        return PlatformAudioConfig(
            sampleRate: min(caps.maxSampleRate, 96000),
            bufferSize: 512,
            channels: min(caps.maxChannels, 8),
            format: .float32
        )
    }
}

// MARK: - Platform-Specific Visual Configuration

/// Provides platform-optimized visual configuration
public struct PlatformVisualConfig {
    public let targetFPS: Int
    public let quality: Float
    public let enableHDR: Bool
    public let enableProMotion: Bool
    public let maxParticles: Int
    public let shadowQuality: ShadowQuality

    public enum ShadowQuality: String {
        case off = "Off"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    /// Get optimal visual configuration for current platform
    @MainActor
    public static func optimal() -> PlatformVisualConfig {
        let manager = UnifiedPlatformManager.shared
        let tier = manager.performanceTier
        let caps = manager.capabilities.visual

        return PlatformVisualConfig(
            targetFPS: tier.targetFPS,
            quality: tier.visualQuality,
            enableHDR: caps.supportsHDR && tier != .low,
            enableProMotion: caps.supportsProMotion && tier == .ultra,
            maxParticles: tier == .ultra ? 10000 : tier == .high ? 5000 : tier == .medium ? 2000 : 500,
            shadowQuality: tier == .ultra ? .high : tier == .high ? .medium : tier == .medium ? .low : .off
        )
    }
}

// MARK: - Cross-Platform Type Aliases

#if os(iOS) || os(tvOS) || os(visionOS)
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
#elseif os(macOS)
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
#elseif os(watchOS)
import WatchKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
#endif
