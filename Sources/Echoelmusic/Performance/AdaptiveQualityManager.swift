import Foundation
import SwiftUI
import Combine

/// Real-time adaptive quality system that monitors performance
/// and dynamically adjusts visual quality to maintain target FPS
///
/// **Goal:** Smooth 30-60 FPS even on stressed/old hardware
///
/// **How it Works:**
/// 1. Monitor actual FPS every second
/// 2. If FPS drops below target for 3+ seconds → reduce quality
/// 3. If FPS stable above target for 10+ seconds → increase quality
/// 4. Adjust particle counts, effects intensity, visual complexity
///
/// **Prevents:**
/// - Frame drops and stuttering
/// - App termination from memory pressure
/// - Poor user experience on old hardware
///
/// **Usage:**
/// ```swift
/// let adaptiveQuality = AdaptiveQualityManager()
/// adaptiveQuality.start()
///
/// // In render loop:
/// adaptiveQuality.recordFrameTime(deltaTime)
///
/// // Apply recommendations:
/// let quality = adaptiveQuality.currentQuality
/// particleCount = quality.maxParticles
/// ```
@MainActor
public class AdaptiveQualityManager: ObservableObject {

    // MARK: - Published State

    /// Current adaptive quality level
    @Published public private(set) var currentQuality: AdaptiveQuality = .high

    /// Current measured FPS
    @Published public private(set) var currentFPS: Double = 60.0

    /// Whether adaptive quality is enabled
    @Published public var isEnabled: Bool = true

    /// Whether currently adjusting quality
    @Published public private(set) var isAdjusting: Bool = false

    // MARK: - Configuration

    /// Target FPS (will try to maintain this)
    public var targetFPS: Double = 60.0

    /// Minimum acceptable FPS before reducing quality
    public var minimumFPS: Double = 25.0

    /// FPS buffer above target before increasing quality
    public var fpsBuffer: Double = 10.0

    /// Seconds below target before reducing quality
    public var reductionDelay: TimeInterval = 3.0

    /// Seconds above target before increasing quality
    public var increaseDelay: TimeInterval = 10.0

    // MARK: - Performance Monitoring

    private var frameTimes: [TimeInterval] = []
    private let frameTimeWindowSize: Int = 60  // Last 60 frames
    private var lastFrameTime: Date = Date()

    // MARK: - Quality Adjustment State

    private var lowFPSStartTime: Date?
    private var highFPSStartTime: Date?
    private var lastAdjustmentTime: Date = Date()

    // MARK: - Statistics

    private var totalFrames: Int = 0
    private var droppedFrames: Int = 0
    private var qualityAdjustments: Int = 0

    // MARK: - Timer

    private var analysisTimer: Timer?

    // MARK: - Hardware Capability

    private let hardwareCapability = HardwareCapability.shared

    // MARK: - Initialization

    public init() {
        // Set initial quality based on hardware
        currentQuality = AdaptiveQuality.fromHardware(hardwareCapability)
        targetFPS = Double(currentQuality.targetFPS)

        print("[AdaptiveQuality] Initialized")
        print("   Initial Quality: \(currentQuality.level)")
        print("   Target FPS: \(targetFPS)")
        print("   Device: \(hardwareCapability.deviceModel)")
    }

    // MARK: - Lifecycle

    /// Start adaptive quality monitoring
    public func start() {
        guard !isRunning else { return }

        // Start analysis timer (every 1 second)
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.analyzePerformance()
            }
        }

        print("[AdaptiveQuality] ✅ Started monitoring")
    }

    /// Stop adaptive quality monitoring
    public func stop() {
        analysisTimer?.invalidate()
        analysisTimer = nil

        print("[AdaptiveQuality] ⏹️  Stopped monitoring")
    }

    private var isRunning: Bool {
        analysisTimer != nil
    }

    // MARK: - Frame Recording

    /// Record a frame time for FPS calculation
    /// Call this in your render loop with frame delta time
    public func recordFrameTime(_ deltaTime: TimeInterval) {
        guard isEnabled else { return }

        frameTimes.append(deltaTime)

        // Keep window size limited
        if frameTimes.count > frameTimeWindowSize {
            frameTimes.removeFirst()
        }

        totalFrames += 1

        // Detect dropped frames (>100ms = likely dropped)
        if deltaTime > 0.1 {
            droppedFrames += 1
        }

        // Update current FPS
        calculateCurrentFPS()
    }

    // MARK: - FPS Calculation

    private func calculateCurrentFPS() {
        guard !frameTimes.isEmpty else {
            currentFPS = 0
            return
        }

        // Average frame time over window
        let averageFrameTime = frameTimes.reduce(0.0, +) / Double(frameTimes.count)

        // Convert to FPS
        if averageFrameTime > 0 {
            currentFPS = 1.0 / averageFrameTime
        }
    }

    // MARK: - Performance Analysis

    private func analyzePerformance() {
        guard isEnabled else { return }
        guard !frameTimes.isEmpty else { return }

        let now = Date()

        // Check if FPS is below target
        if currentFPS < minimumFPS {
            // FPS is too low - track how long
            if lowFPSStartTime == nil {
                lowFPSStartTime = now
                print("[AdaptiveQuality] ⚠️  FPS dropped to \(String(format: "%.1f", currentFPS))")
            }

            // If below target for long enough, reduce quality
            if let startTime = lowFPSStartTime,
               now.timeIntervalSince(startTime) >= reductionDelay,
               now.timeIntervalSince(lastAdjustmentTime) >= 5.0 {  // Don't adjust too frequently

                reduceQuality()
                lowFPSStartTime = nil
            }

            // Reset high FPS tracking
            highFPSStartTime = nil

        } else if currentFPS > targetFPS + fpsBuffer {
            // FPS is comfortably above target - maybe can increase quality
            if highFPSStartTime == nil {
                highFPSStartTime = now
            }

            // If above target for long enough, increase quality
            if let startTime = highFPSStartTime,
               now.timeIntervalSince(startTime) >= increaseDelay,
               now.timeIntervalSince(lastAdjustmentTime) >= 15.0 {  // Be conservative about increasing

                increaseQuality()
                highFPSStartTime = nil
            }

            // Reset low FPS tracking
            lowFPSStartTime = nil

        } else {
            // FPS is in acceptable range - reset tracking
            lowFPSStartTime = nil
            highFPSStartTime = nil
        }
    }

    // MARK: - Quality Adjustment

    private func reduceQuality() {
        let oldQuality = currentQuality

        // Reduce quality level
        switch currentQuality.level {
        case .ultra:
            currentQuality = .high
        case .high:
            currentQuality = .medium
        case .medium:
            currentQuality = .low
        case .low:
            // Already at lowest - can't reduce further
            print("[AdaptiveQuality] ⚠️  Already at lowest quality, cannot reduce further")
            return
        }

        lastAdjustmentTime = Date()
        qualityAdjustments += 1
        isAdjusting = true

        print("[AdaptiveQuality] 📉 Reduced quality: \(oldQuality.level) → \(currentQuality.level)")
        print("   Reason: FPS \(String(format: "%.1f", currentFPS)) < \(String(format: "%.1f", minimumFPS))")
        print("   New Max Particles: \(currentQuality.maxParticles)")
        print("   New Target FPS: \(currentQuality.targetFPS)")

        // Update target FPS
        targetFPS = Double(currentQuality.targetFPS)

        // Reset adjusting flag after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isAdjusting = false
        }
    }

    private func increaseQuality() {
        let oldQuality = currentQuality

        // Increase quality level
        switch currentQuality.level {
        case .low:
            currentQuality = .medium
        case .medium:
            currentQuality = .high
        case .high:
            // Check if hardware supports ultra before upgrading
            if hardwareCapability.performanceTier == .veryHigh {
                currentQuality = .ultra
            } else {
                print("[AdaptiveQuality] ℹ️  Hardware doesn't support ultra quality")
                return
            }
        case .ultra:
            // Already at highest - can't increase further
            print("[AdaptiveQuality] ✅ Already at highest quality")
            return
        }

        lastAdjustmentTime = Date()
        qualityAdjustments += 1
        isAdjusting = true

        print("[AdaptiveQuality] 📈 Increased quality: \(oldQuality.level) → \(currentQuality.level)")
        print("   Reason: FPS stable at \(String(format: "%.1f", currentFPS))")
        print("   New Max Particles: \(currentQuality.maxParticles)")
        print("   New Target FPS: \(currentQuality.targetFPS)")

        // Update target FPS
        targetFPS = Double(currentQuality.targetFPS)

        // Reset adjusting flag after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isAdjusting = false
        }
    }

    // MARK: - Manual Quality Control

    /// Manually set quality level (disables adaptive adjustment temporarily)
    public func setQuality(_ quality: AdaptiveQuality, temporary: Bool = false) {
        let oldQuality = currentQuality
        currentQuality = quality
        targetFPS = Double(quality.targetFPS)

        print("[AdaptiveQuality] 🎚️  Manual quality change: \(oldQuality.level) → \(quality.level)")

        if temporary {
            // Re-enable adaptive after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                self.isEnabled = true
                print("[AdaptiveQuality] 🔄 Re-enabled adaptive quality")
            }
        }
    }

    // MARK: - Statistics

    /// Get performance statistics
    public var statistics: PerformanceStatistics {
        let dropRate = totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) : 0

        return PerformanceStatistics(
            currentFPS: currentFPS,
            targetFPS: targetFPS,
            averageFrameTime: frameTimes.isEmpty ? 0 : frameTimes.reduce(0, +) / Double(frameTimes.count),
            totalFrames: totalFrames,
            droppedFrames: droppedFrames,
            dropRate: dropRate,
            qualityLevel: currentQuality.level,
            qualityAdjustments: qualityAdjustments
        )
    }

    /// Human-readable status
    public var statusDescription: String {
        let stats = statistics

        return """
        [Adaptive Quality]
        Quality: \(currentQuality.level.rawValue)
        FPS: \(String(format: "%.1f", currentFPS)) / \(String(format: "%.0f", targetFPS)) target
        Adjustments: \(qualityAdjustments)
        Drop Rate: \(String(format: "%.2f", stats.dropRate * 100))%
        Max Particles: \(currentQuality.maxParticles)
        Effects Intensity: \(String(format: "%.0f", currentQuality.effectsIntensity * 100))%
        """
    }

    // MARK: - Cleanup

    deinit {
        stop()
    }
}

// MARK: - Supporting Types

/// Adaptive quality configuration
public struct AdaptiveQuality {
    public let level: VisualQuality
    public let maxParticles: Int
    public let targetFPS: Int
    public let effectsIntensity: Float  // 0.0 - 1.0
    public let enableBloom: Bool
    public let enableMotionBlur: Bool
    public let shadowQuality: ShadowQuality

    public enum ShadowQuality: String {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    // MARK: - Presets

    public static let ultra = AdaptiveQuality(
        level: .ultra,
        maxParticles: 2000,
        targetFPS: 60,
        effectsIntensity: 1.0,
        enableBloom: true,
        enableMotionBlur: true,
        shadowQuality: .high
    )

    public static let high = AdaptiveQuality(
        level: .high,
        maxParticles: 1000,
        targetFPS: 60,
        effectsIntensity: 0.8,
        enableBloom: true,
        enableMotionBlur: false,
        shadowQuality: .medium
    )

    public static let medium = AdaptiveQuality(
        level: .medium,
        maxParticles: 500,
        targetFPS: 30,
        effectsIntensity: 0.5,
        enableBloom: false,
        enableMotionBlur: false,
        shadowQuality: .low
    )

    public static let low = AdaptiveQuality(
        level: .low,
        maxParticles: 250,
        targetFPS: 30,
        effectsIntensity: 0.3,
        enableBloom: false,
        enableMotionBlur: false,
        shadowQuality: .none
    )

    // MARK: - Hardware-based Selection

    public static func fromHardware(_ capability: HardwareCapability) -> AdaptiveQuality {
        switch capability.performanceTier {
        case .veryHigh:
            return .ultra
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }
}

/// Performance statistics for monitoring
public struct PerformanceStatistics {
    public let currentFPS: Double
    public let targetFPS: Double
    public let averageFrameTime: TimeInterval
    public let totalFrames: Int
    public let droppedFrames: Int
    public let dropRate: Double  // 0.0 - 1.0
    public let qualityLevel: VisualQuality
    public let qualityAdjustments: Int

    public var isHealthy: Bool {
        currentFPS >= targetFPS * 0.9 && dropRate < 0.05
    }

    public var performanceGrade: String {
        if currentFPS >= targetFPS * 0.95 && dropRate < 0.02 {
            return "A+ (Excellent)"
        } else if currentFPS >= targetFPS * 0.85 && dropRate < 0.05 {
            return "A (Good)"
        } else if currentFPS >= targetFPS * 0.7 && dropRate < 0.10 {
            return "B (Fair)"
        } else if currentFPS >= targetFPS * 0.5 && dropRate < 0.20 {
            return "C (Poor)"
        } else {
            return "D (Critical)"
        }
    }
}
