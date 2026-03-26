#if canImport(CoreMotion) && canImport(SwiftUI)
import CoreMotion
import SwiftUI
import Observation

/// Maps iPhone motion sensors to musical parameters.
/// Tilt, shake, and rotate the phone to shape sound in real-time.
///
/// No user permission required — CoreMotion runs on dedicated coprocessor.
/// CPU impact: ~1-2% at 60Hz. Does not interfere with AVAudioEngine.
@MainActor
@Observable
final class MotionMusicController {

    // MARK: - Musical Parameters (0-1 normalized)

    /// Forward/back tilt → filter cutoff (tilt forward = open, back = close)
    var filterAmount: Float = 0.5

    /// Left/right tilt → stereo pan (-1 left, +1 right)
    var panAmount: Float = 0.0

    /// Rotation speed → effect intensity (LFO rate, phaser sweep)
    var rotationIntensity: Float = 0.0

    /// Shake detected → trigger one-shot effect
    var shakeDetected: Bool = false

    /// Whether motion control is active
    var isActive: Bool = false

    // MARK: - Private

    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private let motionQueue = OperationQueue()
    @ObservationIgnored private var lastShakeTime: TimeInterval = 0

    // MARK: - Lifecycle

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            log.log(.info, category: .system, "MotionMusic: DeviceMotion not available")
            return
        }
        guard !isActive else { return }

        motionQueue.name = "com.echoelmusic.motion"
        motionQueue.maxConcurrentOperationCount = 1

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60Hz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let motion, error == nil else { return }
            self?.processMotion(motion)
        }

        isActive = true
        log.log(.info, category: .system, "MotionMusic: Started (60Hz)")
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        filterAmount = 0.5
        panAmount = 0.0
        rotationIntensity = 0.0
        shakeDetected = false
        log.log(.info, category: .system, "MotionMusic: Stopped")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        // Pitch: forward/back tilt (-π/2 to π/2 when upright)
        // Normalize to 0-1 for filter cutoff
        let pitch = Float(motion.attitude.pitch)
        let normalizedPitch = (pitch + .pi / 2) / .pi // 0 (tilted back) to 1 (tilted forward)
        let smoothedFilter = filterAmount * 0.85 + normalizedPitch * 0.15 // EMA smoothing

        // Roll: left/right tilt (-π to π)
        // Normalize to -1...+1 for stereo pan
        let roll = Float(motion.attitude.roll)
        let normalizedPan = max(-1.0, min(1.0, roll / (.pi / 3))) // ±60° range
        let smoothedPan = panAmount * 0.85 + normalizedPan * 0.15

        // Rotation rate magnitude → effect intensity
        let rotRate = Float(
            sqrt(
                motion.rotationRate.x * motion.rotationRate.x +
                motion.rotationRate.y * motion.rotationRate.y +
                motion.rotationRate.z * motion.rotationRate.z
            )
        )
        let normalizedRotation = min(1.0, rotRate / 5.0) // 5 rad/s = max
        let smoothedRotation = rotationIntensity * 0.9 + normalizedRotation * 0.1

        // Shake detection: high acceleration spike
        let accelMag = Float(
            sqrt(
                motion.userAcceleration.x * motion.userAcceleration.x +
                motion.userAcceleration.y * motion.userAcceleration.y +
                motion.userAcceleration.z * motion.userAcceleration.z
            )
        )
        let now = CACurrentMediaTime()
        let isShake = accelMag > 2.5 && (now - lastShakeTime) > 0.5 // 0.5s cooldown

        if isShake {
            lastShakeTime = now
        }

        // Dispatch to MainActor
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.filterAmount = max(0, min(1, smoothedFilter))
            self.panAmount = max(-1, min(1, smoothedPan))
            self.rotationIntensity = smoothedRotation
            if isShake {
                self.shakeDetected = true
                // Auto-reset after brief period
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.shakeDetected = false
                }
            }
        }
    }
}
#endif
