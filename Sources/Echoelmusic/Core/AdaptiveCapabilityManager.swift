import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(ARKit)
import ARKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif
#if canImport(Metal)
import Metal
#endif

/// Adaptive Capability Manager
///
/// Central runtime detection of hardware capabilities + permission states.
/// Features are only enabled when BOTH hardware is present AND permission granted.
/// Monitors changes (audio route, permissions) and adapts in real-time.
///
/// Usage:
/// ```swift
/// let caps = AdaptiveCapabilityManager.shared
/// if caps.canUse(.faceTracking) { startFaceTracking() }
/// if caps.canUse(.microphone) { startRecording() }
/// ```
@MainActor
public final class AdaptiveCapabilityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AdaptiveCapabilityManager()

    // MARK: - Capability States

    /// State of each capability: hardware presence + permission combined
    @Published private(set) var states: [Capability: CapabilityState] = [:]

    /// Device performance tier (determines quality defaults)
    @Published private(set) var performanceTier: PerformanceTier = .standard

    /// Human-readable device name
    @Published private(set) var deviceName: String = ""

    // MARK: - Types

    /// All capabilities the app can adaptively use
    enum Capability: String, CaseIterable {
        case microphone
        case camera
        case faceTracking
        case eyeTracking
        case lidar
        case haptics
        case healthKit
        case spatialAudio
        case motionSensors
        case bluetooth
        case metalGPU
        case locationServices
    }

    /// Combined hardware + permission state
    enum CapabilityState: Comparable {
        case available           // Hardware present, permission granted
        case permissionNeeded    // Hardware present, permission not yet requested
        case denied              // Hardware present, permission explicitly denied
        case unavailable         // Hardware not present on this device

        var isUsable: Bool { self == .available }
        var hasHardware: Bool { self != .unavailable }
    }

    /// Device performance classification
    enum PerformanceTier {
        case pro          // 6+ cores, 6+ GB RAM (iPhone Pro, iPad Pro)
        case standard     // 4+ cores, 4+ GB RAM
        case limited      // Older devices, Watch, etc.

        var maxActiveEngines: Int {
            switch self {
            case .pro: return 8
            case .standard: return 5
            case .limited: return 3
            }
        }

        var recommendedBufferSize: Int {
            switch self {
            case .pro: return 128
            case .standard: return 256
            case .limited: return 512
            }
        }
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    #if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    #endif

    // MARK: - Init

    private init() {
        probeAll()
        startMonitoring()
        log.log(.info, category: .system, "AdaptiveCapabilityManager: probed \(states.count) capabilities")
    }

    // MARK: - Public API

    /// Check if a capability is usable (hardware present + permission granted)
    func canUse(_ capability: Capability) -> Bool {
        states[capability]?.isUsable ?? false
    }

    /// Check if hardware exists but permission is needed
    func needsPermission(_ capability: Capability) -> Bool {
        states[capability] == .permissionNeeded
    }

    /// Check if permission was explicitly denied
    func isDenied(_ capability: Capability) -> Bool {
        states[capability] == .denied
    }

    /// Re-probe a specific capability (e.g., after permission granted)
    func refresh(_ capability: Capability) {
        switch capability {
        case .microphone: probeMicrophone()
        case .camera: probeCamera()
        case .faceTracking: probeFaceTracking()
        case .eyeTracking: probeEyeTracking()
        case .lidar: probeLiDAR()
        case .haptics: probeHaptics()
        case .healthKit: probeHealthKit()
        case .spatialAudio: probeSpatialAudio()
        case .motionSensors: probeMotionSensors()
        case .bluetooth: probeBluetooth()
        case .metalGPU: probeMetalGPU()
        case .locationServices: probeLocation()
        }
    }

    /// Re-probe everything (e.g., after returning from Settings)
    func refreshAll() {
        probeAll()
    }

    /// Summary of all capability states for diagnostics
    var diagnosticSummary: String {
        var lines: [String] = ["Device: \(deviceName) | Tier: \(performanceTier)"]
        for cap in Capability.allCases {
            let state = states[cap] ?? .unavailable
            let icon: String
            switch state {
            case .available: icon = "[OK]"
            case .permissionNeeded: icon = "[?]"
            case .denied: icon = "[X]"
            case .unavailable: icon = "[-]"
            }
            lines.append("  \(icon) \(cap.rawValue)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Probe All

    private func probeAll() {
        detectDeviceTier()
        probeMicrophone()
        probeCamera()
        probeFaceTracking()
        probeEyeTracking()
        probeLiDAR()
        probeHaptics()
        probeHealthKit()
        probeSpatialAudio()
        probeMotionSensors()
        probeBluetooth()
        probeMetalGPU()
        probeLocation()
    }

    // MARK: - Device Tier Detection

    private func detectDeviceTier() {
        let cores = ProcessInfo.processInfo.processorCount
        let ramGB = Float(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        if cores >= 6 && ramGB >= 6 {
            performanceTier = .pro
        } else if cores >= 4 && ramGB >= 4 {
            performanceTier = .standard
        } else {
            performanceTier = .limited
        }

        #if canImport(UIKit) && !os(watchOS)
        // Defer UIDevice access — safe even before UIWindowScene connects
        deviceName = ProcessInfo.processInfo.hostName
        #else
        deviceName = Host.current().localizedName ?? "Unknown"
        #endif
    }

    // MARK: - Individual Probes

    private func probeMicrophone() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                states[.microphone] = .available
            case .denied:
                states[.microphone] = .denied
            case .undetermined:
                states[.microphone] = .permissionNeeded
            @unknown default:
                states[.microphone] = .permissionNeeded
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                states[.microphone] = .available
            case .denied:
                states[.microphone] = .denied
            case .undetermined:
                states[.microphone] = .permissionNeeded
            @unknown default:
                states[.microphone] = .permissionNeeded
            }
        }
        #elseif os(macOS)
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                states[.microphone] = .available
            case .denied:
                states[.microphone] = .denied
            case .undetermined:
                states[.microphone] = .permissionNeeded
            @unknown default:
                states[.microphone] = .permissionNeeded
            }
        } else {
            states[.microphone] = .permissionNeeded
        }
        #elseif os(watchOS) || os(tvOS)
        states[.microphone] = .unavailable
        #endif
    }

    private func probeCamera() {
        #if os(iOS) || os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            states[.camera] = .available
        case .denied, .restricted:
            states[.camera] = .denied
        case .notDetermined:
            states[.camera] = .permissionNeeded
        @unknown default:
            states[.camera] = .permissionNeeded
        }
        #else
        states[.camera] = .unavailable
        #endif
    }

    private func probeFaceTracking() {
        #if canImport(ARKit) && !os(macOS) && !os(watchOS) && !os(tvOS)
        if ARFaceTrackingConfiguration.isSupported {
            // Face tracking needs camera permission
            let cameraState = states[.camera] ?? .unavailable
            switch cameraState {
            case .available:
                states[.faceTracking] = .available
            case .denied:
                states[.faceTracking] = .denied
            case .permissionNeeded:
                states[.faceTracking] = .permissionNeeded
            case .unavailable:
                states[.faceTracking] = .unavailable
            }
        } else {
            states[.faceTracking] = .unavailable
        }
        #else
        states[.faceTracking] = .unavailable
        #endif
    }

    private func probeEyeTracking() {
        #if os(visionOS)
        // visionOS always has eye tracking hardware
        states[.eyeTracking] = .available
        #else
        states[.eyeTracking] = .unavailable
        #endif
    }

    private func probeLiDAR() {
        #if canImport(ARKit) && !os(macOS) && !os(watchOS) && !os(tvOS)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            states[.lidar] = .available  // LiDAR doesn't need separate permission
        } else {
            states[.lidar] = .unavailable
        }
        #else
        states[.lidar] = .unavailable
        #endif
    }

    private func probeHaptics() {
        #if canImport(CoreHaptics)
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            states[.haptics] = .available
        } else {
            states[.haptics] = .unavailable
        }
        #else
        states[.haptics] = .unavailable
        #endif
    }

    private func probeHealthKit() {
        #if canImport(HealthKit) && !os(tvOS)
        if HKHealthStore.isHealthDataAvailable() {
            // HealthKit authorization is per-type, not global binary.
            // Mark as available if the store itself works; individual type
            // authorization is handled by UnifiedHealthKitEngine.
            states[.healthKit] = .available
        } else {
            states[.healthKit] = .unavailable
        }
        #else
        states[.healthKit] = .unavailable
        #endif
    }

    private func probeSpatialAudio() {
        // Spatial audio requires iOS 15+ and is always available on compatible hardware
        #if os(iOS)
        states[.spatialAudio] = .available
        #elseif os(macOS) || os(visionOS) || os(tvOS)
        states[.spatialAudio] = .available
        #else
        states[.spatialAudio] = .unavailable
        #endif
    }

    private func probeMotionSensors() {
        #if canImport(CoreMotion) && !os(macOS)
        if motionManager.isAccelerometerAvailable || motionManager.isGyroAvailable {
            states[.motionSensors] = .available
        } else {
            states[.motionSensors] = .unavailable
        }
        #else
        states[.motionSensors] = .unavailable
        #endif
    }

    private func probeBluetooth() {
        #if os(iOS) || os(macOS) || os(watchOS) || os(tvOS)
        // Bluetooth availability is checked at usage time by CoreBluetooth.
        // Permission is implicitly requested on first CBCentralManager init.
        states[.bluetooth] = .available
        #else
        states[.bluetooth] = .unavailable
        #endif
    }

    private func probeMetalGPU() {
        #if canImport(Metal)
        if MTLCreateSystemDefaultDevice() != nil {
            states[.metalGPU] = .available
        } else {
            states[.metalGPU] = .unavailable
        }
        #else
        states[.metalGPU] = .unavailable
        #endif
    }

    private func probeLocation() {
        #if canImport(CoreLocation)
        // Don't create CLLocationManager here - just check general availability
        states[.locationServices] = .permissionNeeded
        #else
        states[.locationServices] = .unavailable
        #endif
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Re-probe when app returns from Settings (user may have toggled permissions)
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)
        #endif

        // Monitor audio route changes (AirPods connect/disconnect)
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.probeSpatialAudio()
                    self?.probeMicrophone()
                }
            }
            .store(in: &cancellables)
        #endif
    }
}
