import Foundation
import CoreMotion
import Combine

/// Gyroscope-based head tracking fallback
/// Works on ALL iPhones (iPhone 6s and later)
/// Alternative to AirPods spatial audio head tracking
@MainActor
public class GyroscopeHeadTracker: ObservableObject {

    // MARK: - Published State

    /// Current head orientation (yaw, pitch, roll in radians)
    @Published public private(set) var headOrientation = HeadOrientation.zero

    /// Whether tracking is active
    @Published public private(set) var isTracking: Bool = false

    /// Tracking quality (0-1, based on motion stability)
    @Published public private(set) var trackingQuality: Float = 0.0

    // MARK: - Core Motion

    private let motionManager = CMMotionManager()
    private var updateTimer: Timer?

    // MARK: - Configuration

    private let updateFrequency: Double = 60.0  // 60 Hz for smooth tracking
    private let motionSensitivity: Double = 1.0

    // MARK: - Calibration

    private var referenceOrientation: HeadOrientation?
    private var isCalibrated: Bool = false

    // MARK: - Smoothing

    private var smoothingBuffer: [HeadOrientation] = []
    private let smoothingWindowSize: Int = 5

    // MARK: - Initialization

    public init() {
        checkAvailability()
    }

    // MARK: - Availability

    private func checkAvailability() {
        if !motionManager.isDeviceMotionAvailable {
            print("⚠️ Device motion not available on this device")
        }

        if !motionManager.isGyroAvailable {
            print("⚠️ Gyroscope not available on this device")
        }
    }

    public var isAvailable: Bool {
        return motionManager.isDeviceMotionAvailable && motionManager.isGyroAvailable
    }

    // MARK: - Tracking Control

    public func startTracking() {
        guard isAvailable else {
            print("❌ Cannot start gyroscope head tracking - not available")
            return
        }

        guard !isTracking else { return }

        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = 1.0 / updateFrequency

        // Start device motion updates
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)

        // Start update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / updateFrequency, repeats: true) { [weak self] _ in
            self?.processMotionUpdate()
        }

        isTracking = true
        print("✅ Gyroscope head tracking started (60 Hz)")
    }

    public func stopTracking() {
        guard isTracking else { return }

        motionManager.stopDeviceMotionUpdates()
        updateTimer?.invalidate()
        updateTimer = nil

        isTracking = false
        print("✅ Gyroscope head tracking stopped")
    }

    // MARK: - Calibration

    /// Calibrate current position as "forward"
    public func calibrate() {
        guard let motion = motionManager.deviceMotion else { return }

        // Store current orientation as reference
        referenceOrientation = HeadOrientation(
            yaw: Float(motion.attitude.yaw),
            pitch: Float(motion.attitude.pitch),
            roll: Float(motion.attitude.roll)
        )

        isCalibrated = true
        print("✅ Gyroscope tracking calibrated")
    }

    /// Auto-calibrate if not calibrated after 2 seconds of tracking
    private func autoCalibrate() {
        guard !isCalibrated else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let self = self, !self.isCalibrated {
                self.calibrate()
                print("✅ Auto-calibrated gyroscope tracking")
            }
        }
    }

    // MARK: - Motion Processing

    private func processMotionUpdate() {
        guard let motion = motionManager.deviceMotion else {
            trackingQuality = 0.0
            return
        }

        // Get raw orientation
        var yaw = Float(motion.attitude.yaw)
        var pitch = Float(motion.attitude.pitch)
        var roll = Float(motion.attitude.roll)

        // Apply calibration offset
        if let reference = referenceOrientation {
            yaw -= reference.yaw
            pitch -= reference.pitch
            roll -= reference.roll
        }

        // Normalize angles to -π to π
        yaw = normalizeAngle(yaw)
        pitch = normalizeAngle(pitch)
        roll = normalizeAngle(roll)

        // Apply sensitivity
        yaw *= Float(motionSensitivity)
        pitch *= Float(motionSensitivity)
        roll *= Float(motionSensitivity)

        // Create orientation
        let newOrientation = HeadOrientation(yaw: yaw, pitch: pitch, roll: roll)

        // Apply smoothing
        let smoothedOrientation = applySmoothing(newOrientation)

        // Calculate tracking quality based on motion stability
        let rotationRate = motion.rotationRate
        let motionMagnitude = sqrt(
            pow(rotationRate.x, 2) +
            pow(rotationRate.y, 2) +
            pow(rotationRate.z, 2)
        )

        // Quality is inverse of motion magnitude (lower motion = higher quality)
        trackingQuality = Float(max(0.0, min(1.0, 1.0 - (motionMagnitude / 5.0))))

        // Update published value
        headOrientation = smoothedOrientation
    }

    // MARK: - Smoothing

    private func applySmoothing(_ orientation: HeadOrientation) -> HeadOrientation {
        // Add to buffer
        smoothingBuffer.append(orientation)

        // Keep buffer size limited
        if smoothingBuffer.count > smoothingWindowSize {
            smoothingBuffer.removeFirst()
        }

        // Return average of buffer
        guard !smoothingBuffer.isEmpty else { return orientation }

        let avgYaw = smoothingBuffer.reduce(0.0) { $0 + $1.yaw } / Float(smoothingBuffer.count)
        let avgPitch = smoothingBuffer.reduce(0.0) { $0 + $1.pitch } / Float(smoothingBuffer.count)
        let avgRoll = smoothingBuffer.reduce(0.0) { $0 + $1.roll } / Float(smoothingBuffer.count)

        return HeadOrientation(yaw: avgYaw, pitch: avgPitch, roll: avgRoll)
    }

    // MARK: - Utilities

    private func normalizeAngle(_ angle: Float) -> Float {
        var normalized = angle
        while normalized > .pi {
            normalized -= 2.0 * .pi
        }
        while normalized < -.pi {
            normalized += 2.0 * .pi
        }
        return normalized
    }

    // MARK: - Convenience

    /// Get orientation in degrees
    public var headOrientationDegrees: HeadOrientationDegrees {
        HeadOrientationDegrees(
            yaw: headOrientation.yaw * 180.0 / .pi,
            pitch: headOrientation.pitch * 180.0 / .pi,
            roll: headOrientation.roll * 180.0 / .pi
        )
    }

    // MARK: - Cleanup

    deinit {
        stopTracking()
    }
}

// MARK: - Supporting Types

/// Head orientation in radians
public struct HeadOrientation {
    public var yaw: Float    // Horizontal rotation (left/right)
    public var pitch: Float  // Vertical rotation (up/down)
    public var roll: Float   // Tilt rotation

    public init(yaw: Float, pitch: Float, roll: Float) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }

    public static var zero: HeadOrientation {
        HeadOrientation(yaw: 0, pitch: 0, roll: 0)
    }
}

/// Head orientation in degrees (for UI display)
public struct HeadOrientationDegrees {
    public var yaw: Float
    public var pitch: Float
    public var roll: Float

    public init(yaw: Float, pitch: Float, roll: Float) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}
