import Foundation
import UIKit
import Combine
import CoreMotion

/// Manages device orientation and motion sensor tracking
/// Tracks screen orientation (portrait/landscape) and device motion (accelerometer/gyroscope)
@MainActor
public class DeviceOrientationManager: ObservableObject {

    // MARK: - Published Properties

    /// Current device orientation
    @Published public private(set) var orientation: UIDeviceOrientation = .unknown

    /// Interface orientation (for UI layout)
    @Published public private(set) var interfaceOrientation: UIInterfaceOrientation = .portrait

    /// Whether device is in landscape mode
    @Published public var isLandscape: Bool = false

    /// Whether device is in portrait mode
    @Published public var isPortrait: Bool = true

    /// Whether device is face up
    @Published public var isFaceUp: Bool = false

    /// Whether device is face down
    @Published public var isFaceDown: Bool = false

    // Motion data
    /// Device attitude (pitch, roll, yaw in radians)
    @Published public private(set) var attitude: DeviceAttitude = DeviceAttitude()

    /// Device acceleration (m/s²)
    @Published public private(set) var acceleration: DeviceAcceleration = DeviceAcceleration()

    /// Device rotation rate (rad/s)
    @Published public private(set) var rotationRate: DeviceRotationRate = DeviceRotationRate()

    /// Whether motion tracking is active
    @Published public private(set) var isMotionTrackingActive: Bool = false


    // MARK: - Device Attitude

    public struct DeviceAttitude {
        /// Pitch (rotation around X-axis, forward/backward tilt) in radians
        public var pitch: Double = 0.0

        /// Roll (rotation around Y-axis, left/right tilt) in radians
        public var roll: Double = 0.0

        /// Yaw (rotation around Z-axis, rotation) in radians
        public var yaw: Double = 0.0

        /// Normalized pitch (-1 to 1)
        public var normalizedPitch: Double {
            return pitch / (.pi / 2)
        }

        /// Normalized roll (-1 to 1)
        public var normalizedRoll: Double {
            return roll / (.pi / 2)
        }

        /// Normalized yaw (-1 to 1)
        public var normalizedYaw: Double {
            return yaw / .pi
        }
    }

    public struct DeviceAcceleration {
        /// X-axis acceleration (m/s²)
        public var x: Double = 0.0

        /// Y-axis acceleration (m/s²)
        public var y: Double = 0.0

        /// Z-axis acceleration (m/s²)
        public var z: Double = 0.0

        /// Total acceleration magnitude
        public var magnitude: Double {
            return sqrt(x * x + y * y + z * z)
        }
    }

    public struct DeviceRotationRate {
        /// X-axis rotation rate (rad/s)
        public var x: Double = 0.0

        /// Y-axis rotation rate (rad/s)
        public var y: Double = 0.0

        /// Z-axis rotation rate (rad/s)
        public var z: Double = 0.0

        /// Total rotation rate magnitude
        public var magnitude: Double {
            return sqrt(x * x + y * y + z * z)
        }
    }


    // MARK: - Private Properties

    private var motionManager: CMMotionManager?
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz


    // MARK: - Initialization

    public init() {
        // Get initial orientation
        orientation = UIDevice.current.orientation
        updateOrientationFlags()

        // Start monitoring orientation changes
        startOrientationTracking()

        print("📱 DeviceOrientationManager initialized")
    }


    // MARK: - Orientation Tracking

    /// Start tracking device orientation changes
    public func startOrientationTracking() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleOrientationChange()
            }
            .store(in: &cancellables)

        print("📱 Orientation tracking started")
    }

    /// Stop tracking device orientation changes
    public func stopOrientationTracking() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cancellables.removeAll()

        print("📱 Orientation tracking stopped")
    }

    private func handleOrientationChange() {
        orientation = UIDevice.current.orientation
        updateOrientationFlags()

        print("📱 Orientation changed: \(orientation.description)")
    }

    private func updateOrientationFlags() {
        isLandscape = orientation.isLandscape
        isPortrait = orientation.isPortrait
        isFaceUp = orientation == .faceUp
        isFaceDown = orientation == .faceDown

        // Update interface orientation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            interfaceOrientation = windowScene.interfaceOrientation
        }
    }


    // MARK: - Motion Tracking

    /// Start tracking device motion (accelerometer + gyroscope)
    public func startMotionTracking() {
        guard motionManager == nil else {
            print("⚠️  Motion tracking already active")
            return
        }

        let manager = CMMotionManager()
        self.motionManager = manager

        // Check availability
        guard manager.isDeviceMotionAvailable else {
            print("❌ Device motion not available")
            return
        }

        // Configure update interval
        manager.deviceMotionUpdateInterval = updateInterval

        // Start updates
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive

        manager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("❌ Motion tracking error: \(error)")
                }
                return
            }

            DispatchQueue.main.async {
                self.updateMotionData(motion)
            }
        }

        isMotionTrackingActive = true
        print("📱 Motion tracking started (60 Hz)")
    }

    /// Stop tracking device motion
    public func stopMotionTracking() {
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
        isMotionTrackingActive = false

        print("📱 Motion tracking stopped")
    }

    private func updateMotionData(_ motion: CMDeviceMotion) {
        // Update attitude (pitch, roll, yaw)
        attitude = DeviceAttitude(
            pitch: motion.attitude.pitch,
            roll: motion.attitude.roll,
            yaw: motion.attitude.yaw
        )

        // Update acceleration (user acceleration + gravity)
        let userAccel = motion.userAcceleration
        acceleration = DeviceAcceleration(
            x: userAccel.x,
            y: userAccel.y,
            z: userAccel.z
        )

        // Update rotation rate
        let rotRate = motion.rotationRate
        rotationRate = DeviceRotationRate(
            x: rotRate.x,
            y: rotRate.y,
            z: rotRate.z
        )
    }


    // MARK: - Utility Methods

    /// Get orientation as a human-readable string
    public var orientationDescription: String {
        switch orientation {
        case .portrait:
            return "Portrait"
        case .portraitUpsideDown:
            return "Portrait Upside Down"
        case .landscapeLeft:
            return "Landscape Left"
        case .landscapeRight:
            return "Landscape Right"
        case .faceUp:
            return "Face Up"
        case .faceDown:
            return "Face Down"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }

    /// Get motion summary
    public var motionSummary: String {
        guard isMotionTrackingActive else {
            return "Motion tracking inactive"
        }

        return """
        Attitude: Pitch \(String(format: "%.2f", attitude.pitch))°, Roll \(String(format: "%.2f", attitude.roll))°, Yaw \(String(format: "%.2f", attitude.yaw))°
        Acceleration: \(String(format: "%.2f", acceleration.magnitude)) m/s²
        Rotation: \(String(format: "%.2f", rotationRate.magnitude)) rad/s
        """
    }


    // MARK: - Cleanup

    deinit {
        stopOrientationTracking()
        stopMotionTracking()
    }
}


// MARK: - UIDeviceOrientation Extension

extension UIDeviceOrientation {
    var description: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
