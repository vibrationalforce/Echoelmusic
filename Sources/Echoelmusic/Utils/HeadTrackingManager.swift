import Foundation
#if canImport(CoreMotion)
import CoreMotion
#endif
import Combine

// MARK: - Data Structures (Platform Independent)

/// Head rotation in 3D space
public struct HeadRotation: Sendable {
    public var yaw: Double = 0.0     // Left-right rotation (looking left/right)
    public var pitch: Double = 0.0   // Up-down rotation (looking up/down)
    public var roll: Double = 0.0    // Tilt rotation (head tilt)

    /// Convert to degrees for debugging
    public var degrees: (yaw: Double, pitch: Double, roll: Double) {
        (yaw * 180 / .pi, pitch * 180 / .pi, roll * 180 / .pi)
    }

    public init(yaw: Double = 0.0, pitch: Double = 0.0, roll: Double = 0.0) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}

/// Normalized position for UI display (-1.0 to 1.0)
public struct NormalizedPosition: Sendable {
    public var x: Double = 0.0  // -1.0 (left) to 1.0 (right)
    public var y: Double = 0.0  // -1.0 (down) to 1.0 (up)
    public var z: Double = 0.0  // -1.0 (back) to 1.0 (forward)

    public init(x: Double = 0.0, y: Double = 0.0, z: Double = 0.0) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - HeadTrackingManager

#if canImport(CoreMotion)

/// Manages head tracking using CMHeadphoneMotionManager
/// Provides real-time head orientation data for spatial audio
/// Requires: AirPods Pro/Max with iOS 14+
@MainActor
public class HeadTrackingManager: ObservableObject {

    // MARK: - Published Properties

    /// Whether head tracking is currently active
    @Published public var isTracking: Bool = false

    /// Whether head tracking is available (requires compatible AirPods)
    @Published public var isAvailable: Bool = false

    /// Current head rotation (yaw, pitch, roll) in radians
    @Published public var headRotation: HeadRotation = HeadRotation()

    /// Normalized head position (-1.0 to 1.0 for UI display)
    @Published public var normalizedPosition: NormalizedPosition = NormalizedPosition()


    // MARK: - Private Properties

    /// CoreMotion manager for headphone motion
    private let motionManager = CMHeadphoneMotionManager()

    /// Update frequency (Hz)
    private let updateFrequency: Double = 60.0  // 60 Hz for smooth tracking

    /// Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()

    /// Smoothing factor for head rotation (0.0 = no smoothing, 1.0 = max smoothing)
    private let smoothingFactor: Double = 0.7


    // MARK: - Initialization

    public init() {
        checkAvailability()
    }


    // MARK: - Availability Check

    /// Check if head tracking is available
    private func checkAvailability() {
        isAvailable = motionManager.isDeviceMotionAvailable

        if isAvailable {
            log.spatial("✅ Head tracking available")
        } else {
            log.spatial("⚠️  Head tracking not available", level: .warning)
            log.spatial("   Requires: AirPods Pro/Max with iOS 14+", level: .warning)
        }
    }


    // MARK: - Tracking Control

    /// Start head tracking
    public func startTracking() {
        guard isAvailable else {
            log.spatial("❌ Cannot start head tracking: Not available", level: .error)
            return
        }

        guard !isTracking else {
            log.spatial("⚠️  Head tracking already active", level: .warning)
            return
        }

        // Start receiving motion updates (CMHeadphoneMotionManager uses system update rate)
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                log.spatial("❌ Head tracking error: \(error.localizedDescription)", level: .error)
                Task { @MainActor in
                    self.stopTracking()
                }
                return
            }

            guard let motion = motion else { return }

            // Update head rotation
            Task { @MainActor in
                self.updateHeadRotation(from: motion)
            }
        }

        isTracking = true
        log.spatial("🎧 Head tracking started (\(updateFrequency) Hz)")
    }

    /// Stop head tracking
    public func stopTracking() {
        guard isTracking else { return }

        motionManager.stopDeviceMotionUpdates()
        isTracking = false

        // Reset to neutral position
        headRotation = HeadRotation()
        normalizedPosition = NormalizedPosition()

        log.spatial("🎧 Head tracking stopped")
    }


    // MARK: - Motion Processing

    /// Update head rotation from motion data
    private func updateHeadRotation(from motion: CMDeviceMotion) {
        let attitude = motion.attitude

        // Get raw rotation values (in radians)
        let rawYaw = attitude.yaw
        let rawPitch = attitude.pitch
        let rawRoll = attitude.roll

        // Apply exponential smoothing for smoother motion
        headRotation.yaw = smooth(headRotation.yaw, target: rawYaw)
        headRotation.pitch = smooth(headRotation.pitch, target: rawPitch)
        headRotation.roll = smooth(headRotation.roll, target: rawRoll)

        // Normalize for UI display (-1.0 to 1.0)
        updateNormalizedPosition()

        // Log debug info (throttled to avoid spam)
        #if DEBUG
        if Int(Date().timeIntervalSince1970 * 2) % 2 == 0 {  // Every 0.5 seconds
            let degrees = headRotation.degrees
            log.spatial("🎧 Head: Y:\(Int(degrees.yaw))° P:\(Int(degrees.pitch))° R:\(Int(degrees.roll))°")
        }
        #endif
    }

    /// Exponential smoothing for smoother motion
    private func smooth(_ current: Double, target: Double) -> Double {
        return current * smoothingFactor + target * (1.0 - smoothingFactor)
    }

    /// Update normalized position for UI display
    private func updateNormalizedPosition() {
        // Map rotation angles to -1.0 to 1.0 range

        // Yaw: -π to π → -1.0 to 1.0 (left-right)
        normalizedPosition.x = headRotation.yaw / .pi

        // Pitch: -π/2 to π/2 → -1.0 to 1.0 (up-down)
        normalizedPosition.y = headRotation.pitch / (.pi / 2.0)

        // Roll: -π to π → -1.0 to 1.0 (tilt)
        normalizedPosition.z = headRotation.roll / .pi

        // Clamp to -1.0 to 1.0 range
        normalizedPosition.x = max(-1.0, min(1.0, normalizedPosition.x))
        normalizedPosition.y = max(-1.0, min(1.0, normalizedPosition.y))
        normalizedPosition.z = max(-1.0, min(1.0, normalizedPosition.z))
    }


    // MARK: - Utility Methods

    /// Reset head tracking to neutral position
    public func resetOrientation() {
        guard isTracking else { return }

        // Reset the reference frame
        motionManager.stopDeviceMotionUpdates()

        // Restart with new reference frame
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                log.spatial("❌ Head tracking error: \(error.localizedDescription)", level: .error)
                return
            }

            guard let motion = motion else { return }
            Task { @MainActor in
                self.updateHeadRotation(from: motion)
            }
        }

        log.spatial("🔄 Head tracking orientation reset")
    }

    /// Get human-readable status
    public var statusDescription: String {
        if !isAvailable {
            return "Head tracking not available"
        } else if isTracking {
            let degrees = headRotation.degrees
            return "Tracking: Y:\(Int(degrees.yaw))° P:\(Int(degrees.pitch))° R:\(Int(degrees.roll))°"
        } else {
            return "Head tracking ready"
        }
    }


    // MARK: - Cleanup

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}


// MARK: - Spatial Audio Integration

extension HeadTrackingManager {

    /// Get 3D position for spatial audio
    /// Returns (x, y, z) coordinates suitable for AVAudioEnvironmentNode
    public func get3DAudioPosition() -> (x: Float, y: Float, z: Float) {
        // Convert head rotation to 3D audio position
        // In AVAudioEnvironmentNode:
        // - X axis: left (-) to right (+)
        // - Y axis: down (-) to up (+)
        // - Z axis: front (+) to back (-)

        let x = Float(normalizedPosition.x)  // Left-right
        let y = Float(normalizedPosition.y)  // Up-down
        let z = Float(-normalizedPosition.z) // Front-back (inverted)

        return (x, y, z)
    }

    /// Get listener orientation for spatial audio
    /// Returns (yaw, pitch, roll) in radians
    public func getListenerOrientation() -> (yaw: Float, pitch: Float, roll: Float) {
        let yaw = Float(headRotation.yaw)
        let pitch = Float(headRotation.pitch)
        let roll = Float(headRotation.roll)

        return (yaw, pitch, roll)
    }
}


// MARK: - UI Helpers

extension HeadTrackingManager {

    /// Get color based on head position (for visualization)
    public func getVisualizationColor() -> (red: Double, green: Double, blue: Double) {
        // Map normalized position to RGB colors
        let r = (normalizedPosition.x + 1.0) / 2.0  // 0.0 to 1.0
        let g = (normalizedPosition.y + 1.0) / 2.0  // 0.0 to 1.0
        let b = (normalizedPosition.z + 1.0) / 2.0  // 0.0 to 1.0

        return (r, g, b)
    }

    /// Get arrow direction for UI (→ ← ↑ ↓)
    public func getDirectionArrow() -> String {
        let threshold = 0.3

        if normalizedPosition.x > threshold {
            return "→"
        } else if normalizedPosition.x < -threshold {
            return "←"
        } else if normalizedPosition.y > threshold {
            return "↑"
        } else if normalizedPosition.y < -threshold {
            return "↓"
        } else {
            return "○"  // Neutral
        }
    }
}

#else

// MARK: - Stub for Platforms without CoreMotion

/// Stub implementation for platforms without CoreMotion
@MainActor
public class HeadTrackingManager: ObservableObject {

    @Published public var isTracking: Bool = false
    @Published public var isAvailable: Bool = false
    @Published public var headRotation: HeadRotation = HeadRotation()
    @Published public var normalizedPosition: NormalizedPosition = NormalizedPosition()

    public init() {
        log.spatial("⚠️ CoreMotion not available on this platform", level: .warning)
    }

    public func startTracking() {
        log.spatial("⚠️ Head tracking not available on this platform", level: .warning)
    }

    public func stopTracking() {}

    public func resetOrientation() {}

    public var statusDescription: String {
        return "Head tracking not available on this platform"
    }

    public func get3DAudioPosition() -> (x: Float, y: Float, z: Float) {
        return (0, 0, 0)
    }

    public func getListenerOrientation() -> (yaw: Float, pitch: Float, roll: Float) {
        return (0, 0, 0)
    }

    public func getVisualizationColor() -> (red: Double, green: Double, blue: Double) {
        return (0.5, 0.5, 0.5)
    }

    public func getDirectionArrow() -> String {
        return "○"
    }
}

#endif
