import Foundation
import CoreMotion
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// Detects user activity context from motion sensors
/// Maps physical activity to appropriate audio presets
/// Scientifically-based activity classification using accelerometer + gyroscope
@MainActor
class ActivityContextManager: ObservableObject {

    // MARK: - Published State

    /// Current detected activity context
    @Published var currentContext: ActivityContext = .unknown

    /// Confidence level of detection (0.0 - 1.0)
    @Published var confidence: Float = 0.0

    /// Raw motion data for debugging
    @Published var motionIntensity: Float = 0.0

    /// Current step rate (for walking/running)
    @Published var stepRate: Float = 0.0  // steps per minute


    // MARK: - Motion Manager

    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private var motionUpdateTimer: Timer?


    // MARK: - Activity Detection State

    private var accelerationBuffer: [SIMD3<Float>] = []
    private var gyroBuffer: [SIMD3<Float>] = []
    private let bufferSize = 60  // 2 seconds at 30 Hz

    private var lastDetectedContext: ActivityContext = .unknown
    private var contextStabilityCounter = 0
    private let stabilityThreshold = 3  // Require 3 consistent readings


    // MARK: - Thresholds (Evidence-Based)

    private struct MotionThresholds {
        static let stillThreshold: Float = 0.05         // Very low motion
        static let sittingThreshold: Float = 0.15       // Low motion, mostly vertical
        static let standingThreshold: Float = 0.25      // Moderate motion
        static let walkingThreshold: Float = 0.5        // Periodic motion 1-2 Hz
        static let runningThreshold: Float = 1.2        // High periodic motion 2-3 Hz
        static let highIntensityThreshold: Float = 2.0  // Very high motion
    }

    private struct FrequencyRanges {
        static let walkingFreq: ClosedRange<Float> = 1.5...2.5    // Hz (90-150 BPM)
        static let runningFreq: ClosedRange<Float> = 2.5...3.5    // Hz (150-210 BPM)
        static let cyclingFreq: ClosedRange<Float> = 1.0...2.0    // Hz (60-120 RPM)
    }


    // MARK: - Initialization

    init() {
        print("🏃 ActivityContextManager initialized")
    }


    // MARK: - Start/Stop Monitoring

    /// Start monitoring device motion
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️  Device motion not available")
            return
        }

        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0  // 30 Hz
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
        motionManager.gyroUpdateInterval = 1.0 / 30.0

        // Start device motion updates
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()

        // Start pedometer for step counting
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let self = self, let data = data else { return }
                Task { @MainActor in
                    self.updateStepRate(from: data)
                }
            }
        }

        // Start periodic analysis
        motionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivityDetection()
            }
        }

        print("✅ Activity monitoring started (30 Hz)")
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        pedometer.stopUpdates()
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil

        print("⏹️  Activity monitoring stopped")
    }


    // MARK: - Activity Detection Algorithm

    private func updateActivityDetection() {
        guard let motion = motionManager.deviceMotion,
              let accel = motionManager.accelerometerData,
              let gyro = motionManager.gyroData else {
            return
        }

        // Get raw sensor data
        let acceleration = SIMD3<Float>(
            Float(accel.acceleration.x),
            Float(accel.acceleration.y),
            Float(accel.acceleration.z)
        )

        let rotation = SIMD3<Float>(
            Float(gyro.rotationRate.x),
            Float(gyro.rotationRate.y),
            Float(gyro.rotationRate.z)
        )

        // Update buffers
        accelerationBuffer.append(acceleration)
        gyroBuffer.append(rotation)

        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
            gyroBuffer.removeFirst()
        }

        // Need minimum data for analysis
        guard accelerationBuffer.count >= 30 else { return }  // At least 1 second

        // Calculate motion features
        let intensity = calculateMotionIntensity()
        let periodicity = detectPeriodicity()
        let orientation = detectOrientation(motion: motion)

        motionIntensity = intensity

        // Classify activity
        let detectedContext = classifyActivity(
            intensity: intensity,
            periodicity: periodicity,
            orientation: orientation
        )

        // Apply stability filtering
        updateContextWithStability(detectedContext)
    }


    // MARK: - Motion Analysis

    /// Calculate overall motion intensity (RMS of acceleration)
    private func calculateMotionIntensity() -> Float {
        let sumSquares = accelerationBuffer.reduce(0.0) { sum, accel in
            sum + (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        }
        return sqrt(sumSquares / Float(accelerationBuffer.count))
    }

    /// Detect periodic motion patterns (FFT-based)
    private func detectPeriodicity() -> (frequency: Float, strength: Float) {
        // Simplified peak detection (full FFT would be ideal)
        let windowSize = min(30, accelerationBuffer.count)
        let recentAccel = Array(accelerationBuffer.suffix(windowSize))

        // Calculate vertical (Y) acceleration variance
        let yValues = recentAccel.map { $0.y }
        let mean = yValues.reduce(0, +) / Float(yValues.count)
        let variance = yValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(yValues.count)

        // Detect zero-crossings for frequency estimation
        var crossings = 0
        for i in 1..<yValues.count {
            if (yValues[i-1] - mean) * (yValues[i] - mean) < 0 {
                crossings += 1
            }
        }

        let frequency = Float(crossings) / 2.0 * 30.0 / Float(windowSize)  // Convert to Hz
        let strength = variance  // Higher variance = stronger periodicity

        return (frequency, strength)
    }

    /// Detect device orientation (lying vs. sitting vs. standing)
    private func detectOrientation(motion: CMDeviceMotion) -> DeviceOrientation {
        let gravity = motion.gravity

        // Determine primary gravity direction
        let absX = abs(gravity.x)
        let absY = abs(gravity.y)
        let absZ = abs(gravity.z)

        if absZ > 0.8 {
            // Device flat (horizontal)
            return gravity.z > 0 ? .lyingFaceUp : .lyingFaceDown
        } else if absY > 0.7 {
            // Device upright (vertical)
            return .upright
        } else if absX > 0.7 {
            // Device on side
            return .onSide
        }

        return .tilted
    }


    // MARK: - Activity Classification

    /// Classify activity based on motion features
    /// Scientific basis: Accelerometer-based activity recognition (IEEE papers)
    private func classifyActivity(
        intensity: Float,
        periodicity: (frequency: Float, strength: Float),
        orientation: DeviceOrientation
    ) -> ActivityContext {

        // 1. Check for stationary states (orientation-based)
        if intensity < MotionThresholds.stillThreshold {
            switch orientation {
            case .lyingFaceUp:
                return .lyingSupine
            case .lyingFaceDown:
                return .lyingProne
            case .onSide:
                return .lyingSide
            case .upright:
                return .sitting
            case .tilted:
                return .reclining
            }
        }

        // 2. Check for low-motion states
        if intensity < MotionThresholds.sittingThreshold {
            return orientation == .upright ? .sitting : .reclining
        }

        // 3. Check for standing (moderate motion, upright)
        if intensity < MotionThresholds.standingThreshold && orientation == .upright {
            return .standing
        }

        // 4. Check for periodic motion (walking/running/cycling)
        if periodicity.strength > 0.1 {  // Significant periodicity

            // Walking detection (1.5-2.5 Hz, moderate intensity)
            if FrequencyRanges.walkingFreq.contains(periodicity.frequency) &&
               intensity < MotionThresholds.runningThreshold {

                if intensity < 0.3 {
                    return .walkingSlow
                } else if intensity < 0.45 {
                    return .walkingNormal
                } else {
                    return .walkingFast
                }
            }

            // Running detection (2.5-3.5 Hz, high intensity)
            if FrequencyRanges.runningFreq.contains(periodicity.frequency) &&
               intensity >= MotionThresholds.runningThreshold {

                if intensity < 1.5 {
                    return .jogging
                } else if intensity < 2.0 {
                    return .running
                } else {
                    return .sprinting
                }
            }

            // Cycling detection (1.0-2.0 Hz, moderate-high intensity)
            if FrequencyRanges.cyclingFreq.contains(periodicity.frequency) &&
               intensity > 0.4 {
                return intensity < 1.0 ? .cyclingLeisure : .cyclingIntense
            }
        }

        // 5. Check for high-intensity exercise
        if intensity >= MotionThresholds.highIntensityThreshold {
            return .hiit  // High-intensity interval training
        }

        // 6. Check for vehicle motion (low frequency, high smoothness)
        if periodicity.strength < 0.05 && intensity > 0.2 && intensity < 0.6 {
            return .driving
        }

        // Default: Unknown
        return .unknown
    }


    // MARK: - Stability Filtering

    /// Apply hysteresis to prevent rapid context switching
    private func updateContextWithStability(_ newContext: ActivityContext) {
        if newContext == lastDetectedContext {
            contextStabilityCounter += 1
        } else {
            contextStabilityCounter = 0
            lastDetectedContext = newContext
        }

        // Only update published context if stable
        if contextStabilityCounter >= stabilityThreshold {
            if currentContext != newContext {
                currentContext = newContext
                confidence = 0.8  // High confidence after stability check
                print("🎯 Activity detected: \(newContext.rawValue) (confidence: \(confidence))")
            }
        } else {
            confidence = Float(contextStabilityCounter) / Float(stabilityThreshold)
        }
    }


    // MARK: - Step Rate Calculation

    private func updateStepRate(from data: CMPedometerData) {
        guard let steps = data.numberOfSteps.intValue as? Int,
              let startDate = data.startDate as? Date else {
            return
        }

        let elapsed = Date().timeIntervalSince(startDate)
        guard elapsed > 0 else { return }

        // Steps per minute
        stepRate = Float(steps) / Float(elapsed / 60.0)
    }


    // MARK: - Manual Context Override

    /// Manually set activity context (overrides auto-detection temporarily)
    func setManualContext(_ context: ActivityContext, duration: TimeInterval = 300) {
        currentContext = context
        confidence = 1.0
        print("✋ Manual context override: \(context.rawValue)")

        // Auto-resume detection after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.confidence = 0.5
            print("🔄 Resuming auto-detection")
        }
    }


    // MARK: - Context Mapping to BioPreset

    /// Map detected activity to recommended BioPreset
    func recommendedPreset() -> BioParameterMapper.BioPreset {
        currentContext.toBioPreset()
    }
}


// MARK: - Supporting Types

/// Detected activity context from motion sensors
enum ActivityContext: String, CaseIterable {
    // Stationary
    case unknown = "Unknown"
    case sitting = "Sitting"
    case standing = "Standing"
    case reclining = "Reclining"
    case lyingSupine = "Lying Supine"
    case lyingProne = "Lying Prone"
    case lyingSide = "Lying Side"

    // Walking
    case walkingSlow = "Walking Slow"
    case walkingNormal = "Walking"
    case walkingFast = "Walking Fast"

    // Running
    case jogging = "Jogging"
    case running = "Running"
    case sprinting = "Sprinting"

    // Cycling
    case cyclingLeisure = "Cycling Leisure"
    case cyclingIntense = "Cycling Intense"

    // Exercise
    case hiit = "HIIT"

    // Vehicle
    case driving = "Driving"

    /// Map to corresponding BioPreset
    func toBioPreset() -> BioParameterMapper.BioPreset {
        switch self {
        case .unknown:
            return .focus
        case .sitting:
            return .sitting
        case .standing:
            return .standing
        case .reclining:
            return .reclining
        case .lyingSupine:
            return .lyingSupine
        case .lyingProne:
            return .lyingProne
        case .lyingSide:
            return .lyingSide
        case .walkingSlow:
            return .walkingSlow
        case .walkingNormal:
            return .walkingNormal
        case .walkingFast:
            return .walkingFast
        case .jogging:
            return .jogging
        case .running:
            return .running
        case .sprinting:
            return .sprinting
        case .cyclingLeisure:
            return .cyclingLeisure
        case .cyclingIntense:
            return .cyclingIntense
        case .hiit:
            return .hiit
        case .driving:
            return .driving
        }
    }
}

/// Device physical orientation
enum DeviceOrientation {
    case lyingFaceUp
    case lyingFaceDown
    case onSide
    case upright
    case tilted
}
