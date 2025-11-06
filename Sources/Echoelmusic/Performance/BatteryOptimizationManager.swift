import Foundation
import UIKit
import Combine

/// Battery optimization manager that automatically adjusts app behavior
/// based on battery level and Low Power Mode status
///
/// **Features:**
/// - Low Power Mode detection
/// - Battery level monitoring (0-100%)
/// - Automatic quality/frequency adjustments
/// - Configurable thresholds
/// - Integration with AdaptiveQualityManager
///
/// **Usage:**
/// ```swift
/// let batteryManager = BatteryOptimizationManager()
/// batteryManager.start()
///
/// // Listen to recommendations
/// batteryManager.$recommendedUpdateFrequency
///     .sink { frequency in
///         // Adjust update rate
///     }
/// ```
@MainActor
public class BatteryOptimizationManager: ObservableObject {

    // MARK: - Published State

    /// Whether Low Power Mode is currently enabled
    @Published public private(set) var isLowPowerModeEnabled: Bool = false

    /// Current battery level (0.0 - 1.0)
    @Published public private(set) var batteryLevel: Float = 1.0

    /// Current battery state
    @Published public private(set) var batteryState: UIDevice.BatteryState = .unknown

    /// Whether battery optimization is enabled
    @Published public var isEnabled: Bool = true

    /// Whether currently applying optimizations
    @Published public private(set) var isOptimizing: Bool = false

    /// Recommended update frequency (Hz) based on battery status
    @Published public private(set) var recommendedUpdateFrequency: Double = 60.0

    /// Recommended quality level based on battery status
    @Published public private(set) var recommendedQuality: AdaptiveQuality?

    // MARK: - Configuration

    /// Battery level threshold for aggressive optimization (0-1)
    public var lowBatteryThreshold: Float = 0.20  // 20%

    /// Battery level threshold for moderate optimization (0-1)
    public var mediumBatteryThreshold: Float = 0.50  // 50%

    // MARK: - Optimization Levels

    public enum OptimizationLevel {
        case none          // Full performance
        case moderate      // Reduce non-critical operations
        case aggressive    // Minimize all battery usage

        var updateFrequency: Double {
            switch self {
            case .none: return 60.0        // 60 Hz
            case .moderate: return 30.0    // 30 Hz
            case .aggressive: return 15.0  // 15 Hz
            }
        }

        var recommendedQuality: VisualQuality {
            switch self {
            case .none: return .high
            case .moderate: return .medium
            case .aggressive: return .low
            }
        }
    }

    // MARK: - Current Optimization Level

    private var currentOptimizationLevel: OptimizationLevel = .none {
        didSet {
            if oldValue != currentOptimizationLevel {
                applyOptimizations()
            }
        }
    }

    // MARK: - Monitoring

    private var cancellables = Set<AnyCancellable>()
    private var batteryMonitorTimer: Timer?

    // MARK: - Statistics

    private var optimizationChanges: Int = 0
    private var totalBatterySaved: Double = 0.0  // Estimated %

    // MARK: - Initialization

    public init() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Get initial state
        updateBatteryState()
        checkLowPowerMode()

        print("[BatteryOptimization] ✅ Initialized")
        print("   Low Power Mode: \(isLowPowerModeEnabled ? "ON" : "OFF")")
        print("   Battery Level: \(Int(batteryLevel * 100))%")
        print("   Battery State: \(batteryState)")
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Start battery monitoring and optimization
    public func start() {
        guard isEnabled else { return }

        // Start monitoring timer (every 10 seconds)
        batteryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryState()
                self?.updateOptimizationLevel()
            }
        }

        // Listen for Low Power Mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkLowPowerMode()
                    self?.updateOptimizationLevel()
                }
            }
            .store(in: &cancellables)

        // Listen for battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryState()
                    self?.updateOptimizationLevel()
                }
            }
            .store(in: &cancellables)

        // Listen for battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryState()
                    self?.updateOptimizationLevel()
                }
            }
            .store(in: &cancellables)

        print("[BatteryOptimization] ▶️  Started monitoring")
    }

    /// Stop battery monitoring
    public func stop() {
        batteryMonitorTimer?.invalidate()
        batteryMonitorTimer = nil
        cancellables.removeAll()

        print("[BatteryOptimization] ⏹️  Stopped monitoring")
    }

    // MARK: - Battery State Updates

    private func updateBatteryState() {
        let device = UIDevice.current

        batteryLevel = device.batteryLevel
        batteryState = device.batteryState

        // batteryLevel returns -1 if battery monitoring is disabled
        if batteryLevel < 0 {
            batteryLevel = 1.0  // Assume full if unknown
        }
    }

    private func checkLowPowerMode() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Optimization Level Update

    private func updateOptimizationLevel() {
        guard isEnabled else { return }

        let newLevel: OptimizationLevel

        if isLowPowerModeEnabled {
            // Low Power Mode enabled → always aggressive
            newLevel = .aggressive
        } else if batteryLevel < lowBatteryThreshold {
            // Low battery → aggressive
            newLevel = .aggressive
        } else if batteryLevel < mediumBatteryThreshold && !isCharging {
            // Medium battery and not charging → moderate
            newLevel = .moderate
        } else {
            // Good battery or charging → no optimization
            newLevel = .none
        }

        if newLevel != currentOptimizationLevel {
            let oldLevel = currentOptimizationLevel
            currentOptimizationLevel = newLevel

            print("[BatteryOptimization] 🔋 Level changed: \(oldLevel) → \(newLevel)")
            print("   Battery: \(Int(batteryLevel * 100))%")
            print("   Low Power Mode: \(isLowPowerModeEnabled ? "ON" : "OFF")")
            print("   Charging: \(isCharging ? "YES" : "NO")")

            optimizationChanges += 1
        }
    }

    // MARK: - Apply Optimizations

    private func applyOptimizations() {
        isOptimizing = currentOptimizationLevel != .none

        // Update recommended values
        recommendedUpdateFrequency = currentOptimizationLevel.updateFrequency

        switch currentOptimizationLevel {
        case .none:
            recommendedQuality = nil  // No recommendation, use default

        case .moderate:
            recommendedQuality = AdaptiveQuality.medium
            estimateBatterySavings(10.0)  // ~10% savings

        case .aggressive:
            recommendedQuality = AdaptiveQuality.low
            estimateBatterySavings(25.0)  // ~25% savings
        }

        print("[BatteryOptimization] ⚡ Applied optimizations")
        print("   Update Frequency: \(recommendedUpdateFrequency) Hz")
        print("   Quality: \(recommendedQuality?.level.rawValue ?? "Default")")
    }

    // MARK: - Utilities

    /// Whether device is currently charging
    public var isCharging: Bool {
        return batteryState == .charging || batteryState == .full
    }

    /// Whether battery is critically low (<10%)
    public var isCriticallyLow: Bool {
        return batteryLevel < 0.10 && !isCharging
    }

    /// Estimated time remaining (hours) based on current level
    public var estimatedTimeRemaining: Double? {
        guard !isCharging && batteryLevel > 0 else { return nil }

        // Rough estimate: assume 8 hours at 100%
        let baseHours: Double = 8.0
        return baseHours * Double(batteryLevel)
    }

    /// Estimate battery savings from optimization
    private func estimateBatterySavings(_ percentage: Double) {
        totalBatterySaved += percentage
    }

    // MARK: - Statistics

    /// Get battery optimization statistics
    public var statistics: BatteryStatistics {
        BatteryStatistics(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            isCharging: isCharging,
            isCriticallyLow: isCriticallyLow,
            optimizationLevel: currentOptimizationLevel,
            recommendedUpdateFrequency: recommendedUpdateFrequency,
            optimizationChanges: optimizationChanges,
            estimatedBatterySaved: totalBatterySaved,
            estimatedTimeRemaining: estimatedTimeRemaining
        )
    }

    /// Human-readable status
    public var statusDescription: String {
        let stats = statistics

        let chargingStatus: String
        switch batteryState {
        case .charging:
            chargingStatus = "Charging"
        case .full:
            chargingStatus = "Full"
        case .unplugged:
            chargingStatus = "Unplugged"
        case .unknown:
            chargingStatus = "Unknown"
        @unknown default:
            chargingStatus = "Unknown"
        }

        return """
        [Battery Optimization]
        Battery: \(Int(batteryLevel * 100))% (\(chargingStatus))
        Low Power Mode: \(isLowPowerModeEnabled ? "ON ⚡" : "OFF")
        Optimization: \(currentOptimizationLevel)
        Update Frequency: \(recommendedUpdateFrequency) Hz
        Quality: \(recommendedQuality?.level.rawValue ?? "Default")
        Estimated Savings: ~\(String(format: "%.1f", totalBatterySaved))%
        """
    }
}

// MARK: - Supporting Types

/// Battery optimization statistics
public struct BatteryStatistics {
    public let batteryLevel: Float
    public let batteryState: UIDevice.BatteryState
    public let isLowPowerModeEnabled: Bool
    public let isCharging: Bool
    public let isCriticallyLow: Bool
    public let optimizationLevel: BatteryOptimizationManager.OptimizationLevel
    public let recommendedUpdateFrequency: Double
    public let optimizationChanges: Int
    public let estimatedBatterySaved: Double
    public let estimatedTimeRemaining: Double?

    public var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }

    public var isHealthy: Bool {
        batteryLevel > 0.20 || isCharging
    }

    public var warningLevel: WarningLevel {
        if isCriticallyLow {
            return .critical
        } else if batteryLevel < 0.20 {
            return .warning
        } else if batteryLevel < 0.50 {
            return .notice
        } else {
            return .none
        }
    }

    public enum WarningLevel: String {
        case none = "None"
        case notice = "Notice"
        case warning = "Warning"
        case critical = "Critical"
    }
}
