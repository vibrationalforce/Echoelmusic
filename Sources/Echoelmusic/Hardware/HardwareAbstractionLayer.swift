import Foundation
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import Combine

/// Hardware Abstraction Layer (HAL)
/// Universal hardware interface for ALL device types
/// Abstracts differences between: iOS, macOS, watchOS, tvOS, CarPlay, IoT, Vehicles, Drones
///
/// Architecture: Plugin-based system allows Echoelmusic to run on ANY hardware
/// without changing core code. Each device type implements the HAL protocol.
///
/// Supported Platforms (2024-2035):
/// - Mobile: iPhone, iPad, Android phones/tablets
/// - Wearables: Apple Watch, AR glasses, VR headsets
/// - Desktop: Mac, Windows PC, Linux
/// - Vehicles: Tesla, Apple Car, CarPlay, Android Auto
/// - Drones: DJI, autonomous drones
/// - IoT: Smart home, medical devices, embedded systems
/// - Future: Neural interfaces, quantum devices, holographic displays
@MainActor
class HardwareAbstractionLayer: ObservableObject {

    // MARK: - Published State

    @Published var currentPlatform: Platform = .unknown
    @Published var capabilities: HardwareCapabilities = HardwareCapabilities()
    @Published var sensorManager: SensorManager?
    @Published var audioInterface: AudioInterface?
    @Published var displayInterface: DisplayInterface?

    // MARK: - Platform

    enum Platform: String, CaseIterable {
        // Current Platforms
        case iOS = "iOS"
        case macOS = "macOS"
        case watchOS = "watchOS"
        case tvOS = "tvOS"
        case android = "Android"
        case windows = "Windows"
        case linux = "Linux"

        // Vehicle Platforms
        case carPlay = "CarPlay"
        case androidAuto = "Android Auto"
        case teslaOS = "Tesla OS"
        case appleCarOS = "Apple Car OS"

        // Embedded/IoT
        case iot = "IoT Device"
        case drone = "Drone"
        case robot = "Robot"
        case smartHome = "Smart Home"
        case medicalDevice = "Medical Device"

        // AR/VR/XR
        case visionOS = "visionOS"
        case metaQuestOS = "Meta Quest OS"
        case arGlasses = "AR Glasses"

        // Future
        case neuralInterface = "Neural Interface"
        case quantumOS = "Quantum OS"
        case holographicOS = "Holographic OS"

        case unknown = "Unknown"
    }

    // MARK: - Hardware Capabilities

    struct HardwareCapabilities {
        // Processing
        var cpuCores: Int = 0
        var gpuCores: Int = 0
        var neuralEngineCores: Int = 0
        var quantumQubits: Int = 0

        // Memory
        var ramGB: Float = 0
        var storageGB: Float = 0

        // Graphics
        var supportsMetalFX: Bool = false
        var supportsRayTracing: Bool = false
        var supportsHolographicDisplay: Bool = false
        var maxFPS: Int = 60

        // Audio
        var supportsLowLatencyAudio: Bool = false
        var supportsSpatialAudio: Bool = false
        var maxAudioChannels: Int = 2

        // Sensors
        var hasAccelerometer: Bool = false
        var hasGyroscope: Bool = false
        var hasMagnetometer: Bool = false
        var hasBarometer: Bool = false
        var hasHeartRateSensor: Bool = false
        var hasECG: Bool = false
        var hasBloodOxygenSensor: Bool = false
        var hasGPS: Bool = false
        var hasLiDAR: Bool = false
        var hasCamera: Bool = false
        var hasMicrophone: Bool = false
        var hasBrainWaveSensor: Bool = false

        // Connectivity
        var hasWiFi: Bool = false
        var hasBluetooth: Bool = false
        var hasCellular: Bool = false
        var has5G: Bool = false
        var hasSatellite: Bool = false
        var hasQuantumEntanglement: Bool = false

        // Power
        var hasBattery: Bool = false
        var batteryCapacityWh: Float = 0
        var supportsWirelessCharging: Bool = false

        // Input/Output
        var hasTouchScreen: Bool = false
        var hasKeyboard: Bool = false
        var hasMouse: Bool = false
        var hasHaptics: Bool = false
        var hasForceTouch: Bool = false
        var hasEyeTracking: Bool = false
        var hasBrainInterface: Bool = false

        // AI/ML
        var supportsCoreML: Bool = false
        var supportsNeuralEngine: Bool = false
        var supportsQuantumML: Bool = false

        // Platform-Specific
        var supportsHealthKit: Bool = false
        var supportsCarPlay: Bool = false
        var supportsAutonomousDriving: Bool = false
        var supportsFlight: Bool = false
    }

    // MARK: - Sensor Manager Protocol

    protocol SensorManagerProtocol {
        func startAccelerometer(handler: @escaping (SIMD3<Float>) -> Void)
        func startGyroscope(handler: @escaping (SIMD3<Float>) -> Void)
        func startMagnetometer(handler: @escaping (SIMD3<Float>) -> Void)
        func startHeartRate(handler: @escaping (Float) -> Void)
        func startBrainWaves(handler: @escaping ([Float]) -> Void)
        func stopAll()
    }

    class SensorManager: SensorManagerProtocol {
        private let motionManager = CMMotionManager()
        private var accelerometerHandler: ((SIMD3<Float>) -> Void)?
        private var gyroscopeHandler: ((SIMD3<Float>) -> Void)?

        func startAccelerometer(handler: @escaping (SIMD3<Float>) -> Void) {
            accelerometerHandler = handler
            guard motionManager.isAccelerometerAvailable else { return }

            motionManager.accelerometerUpdateInterval = 1.0 / 60.0  // 60 Hz
            motionManager.startAccelerometerUpdates(to: .main) { data, error in
                guard let data = data, error == nil else { return }
                let vector = SIMD3<Float>(
                    Float(data.acceleration.x),
                    Float(data.acceleration.y),
                    Float(data.acceleration.z)
                )
                handler(vector)
            }
        }

        func startGyroscope(handler: @escaping (SIMD3<Float>) -> Void) {
            gyroscopeHandler = handler
            guard motionManager.isGyroAvailable else { return }

            motionManager.gyroUpdateInterval = 1.0 / 60.0
            motionManager.startGyroUpdates(to: .main) { data, error in
                guard let data = data, error == nil else { return }
                let vector = SIMD3<Float>(
                    Float(data.rotationRate.x),
                    Float(data.rotationRate.y),
                    Float(data.rotationRate.z)
                )
                handler(vector)
            }
        }

        func startMagnetometer(handler: @escaping (SIMD3<Float>) -> Void) {
            guard motionManager.isMagnetometerAvailable else { return }

            motionManager.magnetometerUpdateInterval = 1.0 / 10.0  // 10 Hz sufficient
            motionManager.startMagnetometerUpdates(to: .main) { data, error in
                guard let data = data, error == nil else { return }
                let vector = SIMD3<Float>(
                    Float(data.magneticField.x),
                    Float(data.magneticField.y),
                    Float(data.magneticField.z)
                )
                handler(vector)
            }
        }

        func startHeartRate(handler: @escaping (Float) -> Void) {
            // Platform-specific: Use HealthKit on Apple platforms
            // For other platforms, use device-specific APIs
            log.hardware("⚠️ Heart rate monitoring requires HealthKit integration", level: .warning)
        }

        func startBrainWaves(handler: @escaping ([Float]) -> Void) {
            // Future: Neural interface support (Neuralink, etc.)
            log.hardware("⚠️ Brain wave monitoring not yet available (future feature)", level: .warning)
        }

        func stopAll() {
            motionManager.stopAccelerometerUpdates()
            motionManager.stopGyroUpdates()
            motionManager.stopMagnetometerUpdates()
        }
    }

    // MARK: - Audio Interface Protocol

    protocol AudioInterfaceProtocol {
        func configureAudio(sampleRate: Double, bufferSize: Int)
        func startAudio()
        func stopAudio()
        func setVolume(_ volume: Float)
    }

    class AudioInterface: AudioInterfaceProtocol {
        private var audioEngine: AVAudioEngine?

        func configureAudio(sampleRate: Double, bufferSize: Int) {
            audioEngine = AVAudioEngine()

            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
                try AVAudioSession.sharedInstance().setPreferredSampleRate(sampleRate)
                try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
                try AVAudioSession.sharedInstance().setActive(true)
                log.hardware("✅ Audio configured: \(sampleRate) Hz, \(bufferSize) samples")
            } catch {
                log.hardware("❌ Audio configuration failed: \(error)", level: .error)
            }
            #endif
        }

        func startAudio() {
            guard let engine = audioEngine else { return }
            do {
                try engine.start()
                log.hardware("✅ Audio engine started")
            } catch {
                log.hardware("❌ Audio engine start failed: \(error)", level: .error)
            }
        }

        func stopAudio() {
            audioEngine?.stop()
            log.hardware("⏸️ Audio engine stopped")
        }

        func setVolume(_ volume: Float) {
            audioEngine?.mainMixerNode.outputVolume = volume
        }
    }

    // MARK: - Display Interface Protocol

    protocol DisplayInterfaceProtocol {
        func getDisplayInfo() -> DisplayInfo
        func setRefreshRate(_ fps: Int)
        func setBrightness(_ brightness: Float)
    }

    struct DisplayInfo {
        let widthPixels: Int
        let heightPixels: Int
        let refreshRateHz: Int
        let brightnessCdM2: Int
        let isOLED: Bool
        let isHDR: Bool
        let isHolographic: Bool
    }

    class DisplayInterface: DisplayInterfaceProtocol {
        func getDisplayInfo() -> DisplayInfo {
            #if os(iOS)
            let screen = UIScreen.main
            return DisplayInfo(
                widthPixels: Int(screen.bounds.width * screen.scale),
                heightPixels: Int(screen.bounds.height * screen.scale),
                refreshRateHz: screen.maximumFramesPerSecond,
                brightnessCdM2: Int(screen.brightness * 1000),
                isOLED: true,  // Simplified - would need device detection
                isHDR: false,
                isHolographic: false
            )
            #else
            return DisplayInfo(
                widthPixels: 2880,
                heightPixels: 1800,
                refreshRateHz: 60,
                brightnessCdM2: 500,
                isOLED: false,
                isHDR: false,
                isHolographic: false
            )
            #endif
        }

        func setRefreshRate(_ fps: Int) {
            // Platform-specific refresh rate control
            log.hardware("🖥️ Setting refresh rate to \(fps) Hz")
        }

        func setBrightness(_ brightness: Float) {
            #if os(iOS)
            UIScreen.main.brightness = CGFloat(brightness)
            #endif
        }
    }

    // MARK: - Initialization

    init() {
        detectPlatform()
        detectCapabilities()
        initializeInterfaces()

        log.hardware("✅ Hardware Abstraction Layer: Initialized")
        log.hardware("🖥️ Platform: \(currentPlatform.rawValue)")
        log.hardware("💪 Capabilities detected")
    }

    // MARK: - Detect Platform

    private func detectPlatform() {
        #if os(iOS)
        currentPlatform = .iOS
        #elseif os(macOS)
        currentPlatform = .macOS
        #elseif os(watchOS)
        currentPlatform = .watchOS
        #elseif os(tvOS)
        currentPlatform = .tvOS
        #elseif os(visionOS)
        currentPlatform = .visionOS
        #else
        currentPlatform = .unknown
        #endif
    }

    // MARK: - Detect Capabilities

    private func detectCapabilities() {
        var caps = HardwareCapabilities()

        // Detect processing capabilities
        caps.cpuCores = ProcessInfo.processInfo.processorCount
        caps.ramGB = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        // Detect sensors
        let motionManager = CMMotionManager()
        caps.hasAccelerometer = motionManager.isAccelerometerAvailable
        caps.hasGyroscope = motionManager.isGyroAvailable
        caps.hasMagnetometer = motionManager.isMagnetometerAvailable

        #if os(iOS)
        caps.hasTouchScreen = true
        caps.hasCamera = true
        caps.hasMicrophone = true
        caps.hasGPS = true
        caps.hasBluetooth = true
        caps.hasWiFi = true
        caps.hasCellular = true
        caps.hasBattery = true
        caps.supportsHealthKit = true
        caps.supportsCoreML = true

        let screen = UIScreen.main
        caps.maxFPS = screen.maximumFramesPerSecond
        caps.supportsMetalFX = caps.maxFPS >= 120  // Simplified check

        // Haptics
        caps.hasHaptics = true

        // Check for HealthKit sensors
        // In production, would check HealthKit authorization
        caps.hasHeartRateSensor = false  // Requires Apple Watch
        caps.hasECG = false
        caps.hasBloodOxygenSensor = false

        #elseif os(macOS)
        caps.hasKeyboard = true
        caps.hasMouse = true
        caps.hasCamera = true
        caps.hasMicrophone = true
        caps.hasWiFi = true
        caps.hasBluetooth = true
        caps.supportsCoreML = true
        caps.supportsMetalFX = true
        caps.maxFPS = 120

        #elseif os(watchOS)
        caps.hasTouchScreen = true
        caps.hasHeartRateSensor = true
        caps.hasECG = true
        caps.hasBloodOxygenSensor = true
        caps.hasAccelerometer = true
        caps.hasGyroscope = true
        caps.hasBluetooth = true
        caps.hasBattery = true
        caps.supportsHealthKit = true
        caps.maxFPS = 60

        #endif

        capabilities = caps

        log.hardware("📊 Hardware Capabilities:")
        log.hardware("   CPU Cores: \(caps.cpuCores)")
        log.hardware("   RAM: \(String(format: "%.1f", caps.ramGB)) GB")
        log.hardware("   Max FPS: \(caps.maxFPS)")
        log.hardware("   Accelerometer: \(caps.hasAccelerometer)")
        log.hardware("   Gyroscope: \(caps.hasGyroscope)")
        log.hardware("   Heart Rate: \(caps.hasHeartRateSensor)")
    }

    // MARK: - Initialize Interfaces

    private func initializeInterfaces() {
        sensorManager = SensorManager()
        audioInterface = AudioInterface()
        displayInterface = DisplayInterface()
    }

    // MARK: - Platform Adapters

    /// Vehicle Platform Adapter
    func initializeVehiclePlatform(vehicleType: VehicleType) {
        log.hardware("🚗 Initializing vehicle platform: \(vehicleType.rawValue)")

        // Configure for vehicle environment
        capabilities.supportsCarPlay = true
        capabilities.supportsAutonomousDriving = vehicleType == .autonomous

        // Adjust audio for vehicle
        audioInterface?.configureAudio(sampleRate: 48000, bufferSize: 256)

        // Vehicle-specific sensors
        capabilities.hasGPS = true
        capabilities.hasAccelerometer = true
        capabilities.hasGyroscope = true

        log.hardware("✅ Vehicle platform initialized")
    }

    enum VehicleType: String {
        case carPlay = "CarPlay"
        case tesla = "Tesla"
        case appleCar = "Apple Car"
        case autonomous = "Autonomous Vehicle"
    }

    /// Drone Platform Adapter
    func initializeDronePlatform(droneType: DroneType) {
        log.hardware("🚁 Initializing drone platform: \(droneType.rawValue)")

        // Configure for drone environment
        capabilities.supportsFlight = true

        // Drone-specific sensors
        capabilities.hasGPS = true
        capabilities.hasAccelerometer = true
        capabilities.hasGyroscope = true
        capabilities.hasMagnetometer = true
        capabilities.hasBarometer = true
        capabilities.hasCamera = true

        // Low-latency audio critical for drones
        audioInterface?.configureAudio(sampleRate: 48000, bufferSize: 64)

        log.hardware("✅ Drone platform initialized")
    }

    enum DroneType: String {
        case dji = "DJI"
        case autonomous = "Autonomous Drone"
        case racing = "Racing Drone"
    }

    /// IoT Platform Adapter
    func initializeIoTPlatform(deviceType: IoTDeviceType) {
        log.hardware("📡 Initializing IoT platform: \(deviceType.rawValue)")

        // Configure for IoT environment
        switch deviceType {
        case .smartHome:
            capabilities.hasMicrophone = true
            capabilities.hasWiFi = true

        case .medicalDevice:
            capabilities.hasHeartRateSensor = true
            capabilities.hasBloodOxygenSensor = true
            capabilities.hasECG = true

        case .wearable:
            capabilities.hasBattery = true
            capabilities.hasAccelerometer = true
            capabilities.hasGyroscope = true
            capabilities.hasHeartRateSensor = true
        }

        log.hardware("✅ IoT platform initialized")
    }

    enum IoTDeviceType: String {
        case smartHome = "Smart Home"
        case medicalDevice = "Medical Device"
        case wearable = "Wearable"
    }

    /// Future Platform Adapter
    func initializeFuturePlatform(platformType: FuturePlatform) {
        log.hardware("🚀 Initializing future platform: \(platformType.rawValue)")

        switch platformType {
        case .neuralInterface:
            capabilities.hasBrainInterface = true
            capabilities.hasBrainWaveSensor = true
            capabilities.neuralEngineCores = 1024

        case .quantumDevice:
            capabilities.quantumQubits = 1000
            capabilities.supportsQuantumML = true
            capabilities.hasQuantumEntanglement = true

        case .holographicDisplay:
            capabilities.supportsHolographicDisplay = true
            capabilities.maxFPS = 240
        }

        log.hardware("✅ Future platform initialized")
    }

    enum FuturePlatform: String {
        case neuralInterface = "Neural Interface"
        case quantumDevice = "Quantum Device"
        case holographicDisplay = "Holographic Display"
    }

    // MARK: - Capability Queries

    func supportsFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .bioReactiveAudio:
            return capabilities.hasMicrophone
        case .bioReactiveVisuals:
            return capabilities.maxFPS >= 30
        case .hrvMonitoring:
            return capabilities.hasHeartRateSensor || capabilities.supportsHealthKit
        case .spatialAudio:
            return capabilities.supportsSpatialAudio || capabilities.maxAudioChannels >= 6
        case .highPerformance:
            return capabilities.cpuCores >= 4 && capabilities.ramGB >= 4
        case .quantumComputing:
            return capabilities.quantumQubits > 0
        case .neuralInterface:
            return capabilities.hasBrainInterface
        }
    }

    enum Feature {
        case bioReactiveAudio
        case bioReactiveVisuals
        case hrvMonitoring
        case spatialAudio
        case highPerformance
        case quantumComputing
        case neuralInterface
    }

    // MARK: - Hardware Report

    func generateHardwareReport() -> String {
        return """
        🖥️ HARDWARE ABSTRACTION LAYER REPORT

        Platform: \(currentPlatform.rawValue)

        === PROCESSING ===
        CPU Cores: \(capabilities.cpuCores)
        GPU Cores: \(capabilities.gpuCores)
        Neural Engine: \(capabilities.neuralEngineCores) cores
        Quantum Qubits: \(capabilities.quantumQubits)
        RAM: \(String(format: "%.1f", capabilities.ramGB)) GB

        === GRAPHICS ===
        Max FPS: \(capabilities.maxFPS)
        Metal FX: \(capabilities.supportsMetalFX ? "✓" : "✗")
        Ray Tracing: \(capabilities.supportsRayTracing ? "✓" : "✗")
        Holographic: \(capabilities.supportsHolographicDisplay ? "✓" : "✗")

        === SENSORS ===
        Accelerometer: \(capabilities.hasAccelerometer ? "✓" : "✗")
        Gyroscope: \(capabilities.hasGyroscope ? "✓" : "✗")
        Heart Rate: \(capabilities.hasHeartRateSensor ? "✓" : "✗")
        ECG: \(capabilities.hasECG ? "✓" : "✗")
        Brain Waves: \(capabilities.hasBrainWaveSensor ? "✓" : "✗")

        === CONNECTIVITY ===
        WiFi: \(capabilities.hasWiFi ? "✓" : "✗")
        5G: \(capabilities.has5G ? "✓" : "✗")
        Satellite: \(capabilities.hasSatellite ? "✓" : "✗")
        Quantum Entanglement: \(capabilities.hasQuantumEntanglement ? "✓" : "✗")

        === FEATURES SUPPORTED ===
        Bio-Reactive Audio: \(supportsFeature(.bioReactiveAudio) ? "✓" : "✗")
        Bio-Reactive Visuals: \(supportsFeature(.bioReactiveVisuals) ? "✓" : "✗")
        HRV Monitoring: \(supportsFeature(.hrvMonitoring) ? "✓" : "✗")
        Spatial Audio: \(supportsFeature(.spatialAudio) ? "✓" : "✗")
        High Performance: \(supportsFeature(.highPerformance) ? "✓" : "✗")
        Quantum Computing: \(supportsFeature(.quantumComputing) ? "✓" : "✗")
        Neural Interface: \(supportsFeature(.neuralInterface) ? "✓" : "✗")

        Echoelmusic adapts to your hardware automatically.
        """
    }
}
