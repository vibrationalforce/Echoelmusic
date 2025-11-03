import Foundation
import Combine

/// NDI Auto-Recovery - Automatic error recovery and quality adaptation
///
/// Features:
/// - Automatic reconnection on network loss
/// - Adaptive quality reduction on poor network
/// - Smart retry with exponential backoff
/// - User-friendly error messages
/// - Recovery notifications
///
/// Usage:
/// ```swift
/// let recovery = NDIAutoRecovery(controlHub: hub)
/// recovery.enable()
/// // Automatic recovery on network issues!
/// ```
@available(iOS 15.0, *)
@MainActor
public class NDIAutoRecovery: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var recoveryAttempts: Int = 0
    @Published public private(set) var lastRecoveryAction: RecoveryAction?
    @Published public private(set) var currentError: UserFriendlyError?

    // MARK: - Recovery Action

    public enum RecoveryAction {
        case reconnecting
        case reducingQuality
        case increasingBuffer
        case switchingNetwork
        case waitingForNetwork
        case recovered

        var message: String {
            switch self {
            case .reconnecting:
                return "Reconnecting to network..."
            case .reducingQuality:
                return "Adjusting quality for better stability..."
            case .increasingBuffer:
                return "Increasing buffer to prevent dropouts..."
            case .switchingNetwork:
                return "Switching to better network..."
            case .waitingForNetwork:
                return "Waiting for network connection..."
            case .recovered:
                return "Connection recovered! ✅"
            }
        }

        var emoji: String {
            switch self {
            case .reconnecting: return "🔄"
            case .reducingQuality: return "📉"
            case .increasingBuffer: return "🛡️"
            case .switchingNetwork: return "📡"
            case .waitingForNetwork: return "⏳"
            case .recovered: return "✅"
            }
        }
    }

    // MARK: - User-Friendly Errors

    public struct UserFriendlyError {
        let title: String
        let message: String
        let suggestedActions: [String]
        let severity: Severity

        enum Severity {
            case info
            case warning
            case error
            case critical

            var emoji: String {
                switch self {
                case .info: return "ℹ️"
                case .warning: return "⚠️"
                case .error: return "❌"
                case .critical: return "🚨"
                }
            }
        }

        // Common errors
        static let networkLost = UserFriendlyError(
            title: "Network Connection Lost",
            message: "Your device lost network connection. NDI streaming paused.",
            suggestedActions: [
                "Check WiFi connection",
                "Move closer to router",
                "Restart WiFi on device"
            ],
            severity: .error
        )

        static let poorQuality = UserFriendlyError(
            title: "Poor Network Quality",
            message: "Network quality is too low for smooth streaming.",
            suggestedActions: [
                "Reduce quality settings",
                "Switch to 5 GHz WiFi",
                "Close other apps using network",
                "Use Ethernet adapter"
            ],
            severity: .warning
        )

        static let noReceivers = UserFriendlyError(
            title: "No Receivers Found",
            message: "NDI is running but no devices are receiving your audio.",
            suggestedActions: [
                "Check receiver is on same network",
                "Restart receiver application",
                "Manually add receiver IP address",
                "Check firewall settings"
            ],
            severity: .info
        )

        static let bufferOverrun = UserFriendlyError(
            title: "Audio Buffer Overrun",
            message: "Device can't keep up with audio processing.",
            suggestedActions: [
                "Close background apps",
                "Reduce sample rate",
                "Increase buffer size",
                "Connect to power"
            ],
            severity: .warning
        )
    }

    // MARK: - Dependencies

    private let controlHub: UnifiedControlHub
    private let networkMonitor = NDINetworkMonitor.shared
    private let smartConfig = NDISmartConfiguration.shared

    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    private var qualityAdaptationTimer: Timer?

    // Recovery state
    private var lastNetworkQuality: NDINetworkMonitor.NetworkStatus.Quality = .good
    private var consecutiveFailures: Int = 0
    private let maxRetryAttempts = 5
    private var hasReduced Quality = false

    // MARK: - Initialization

    public init(controlHub: UnifiedControlHub) {
        self.controlHub = controlHub
    }

    // MARK: - Enable/Disable

    /// Enable auto-recovery
    public func enable() {
        guard !isEnabled else { return }

        isEnabled = true
        setupNetworkMonitoring()
        setupQualityAdaptation()

        print("[Auto-Recovery] ✅ Enabled")
    }

    /// Disable auto-recovery
    public func disable() {
        guard isEnabled else { return }

        isEnabled = false
        cancellables.removeAll()
        retryTimer?.invalidate()
        qualityAdaptationTimer?.invalidate()

        print("[Auto-Recovery] Disabled")
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        // Monitor network status changes
        networkMonitor.$networkStatus
            .sink { [weak self] status in
                self?.handleNetworkStatusChange(status)
            }
            .store(in: &cancellables)
    }

    private func handleNetworkStatusChange(_ status: NDINetworkMonitor.NetworkStatus) {
        let newQuality = status.quality

        // Network improved
        if newQuality > lastNetworkQuality {
            handleNetworkImprovement(newQuality)
        }
        // Network degraded
        else if newQuality < lastNetworkQuality {
            handleNetworkDegradation(newQuality)
        }

        lastNetworkQuality = newQuality
    }

    private func handleNetworkImprovement(_ quality: NDINetworkMonitor.NetworkStatus.Quality) {
        print("[Auto-Recovery] 📈 Network improved: \(quality.rawValue)")

        // If we had reduced quality, try to restore
        if hasReducedQuality && quality == .excellent {
            Task {
                await restoreQuality()
            }
        }

        // If we were in error state, attempt recovery
        if currentError != nil {
            Task {
                await attemptRecovery()
            }
        }
    }

    private func handleNetworkDegradation(_ quality: NDINetworkMonitor.NetworkStatus.Quality) {
        print("[Auto-Recovery] 📉 Network degraded: \(quality.rawValue)")

        if quality == .poor {
            currentError = .poorQuality
            Task {
                await reduceQualityForStability()
            }
        } else if quality == .unavailable {
            currentError = .networkLost
            Task {
                await handleNetworkLoss()
            }
        }
    }

    // MARK: - Quality Adaptation

    private func setupQualityAdaptation() {
        // Check every 5 seconds if quality needs adjustment
        qualityAdaptationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.adaptQualityIfNeeded()
            }
        }
    }

    private func adaptQualityIfNeeded() async {
        guard controlHub.isNDIEnabled else { return }

        let networkQuality = networkMonitor.networkStatus.quality
        let healthScore = networkMonitor.getHealthScore()

        // If health score < 60, reduce quality
        if healthScore < 60 && !hasReducedQuality {
            await reduceQualityForStability()
        }
        // If health score > 80 and we had reduced quality, restore
        else if healthScore > 80 && hasReducedQuality {
            await restoreQuality()
        }
    }

    private func reduceQualityForStability() async {
        guard !hasReducedQuality else { return }

        lastRecoveryAction = .reducingQuality
        print("[Auto-Recovery] 📉 Reducing quality for stability")

        // Apply minimal profile
        smartConfig.applyOptimalSettings(profile: .minimal)

        // Restart NDI with new settings
        controlHub.disableNDI()
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        try? controlHub.enableNDI()

        hasReducedQuality = true

        // Notify user
        print("[Auto-Recovery] ✅ Quality reduced to ensure stable connection")
    }

    private func restoreQuality() async {
        guard hasReducedQuality else { return }

        print("[Auto-Recovery] 📈 Restoring quality")

        // Apply balanced profile
        smartConfig.applyOptimalSettings(profile: .balanced)

        // Restart NDI
        controlHub.disableNDI()
        try? await Task.sleep(nanoseconds: 500_000_000)
        try? controlHub.enableNDI()

        hasReducedQuality = false
        lastRecoveryAction = .recovered

        print("[Auto-Recovery] ✅ Quality restored")
    }

    // MARK: - Connection Recovery

    private func handleNetworkLoss() async {
        lastRecoveryAction = .waitingForNetwork
        print("[Auto-Recovery] 📵 Network lost - waiting for reconnection")

        // Disable NDI (stop trying to send)
        controlHub.disableNDI()

        // Wait for network to come back (monitored by networkMonitor)
        // When it does, handleNetworkImprovement will trigger recovery
    }

    private func attemptRecovery() async {
        guard recoveryAttempts < maxRetryAttempts else {
            print("[Auto-Recovery] ❌ Max retry attempts reached")
            currentError = UserFriendlyError(
                title: "Recovery Failed",
                message: "Could not recover NDI connection after \(maxRetryAttempts) attempts.",
                suggestedActions: [
                    "Check network connection",
                    "Restart NDI manually",
                    "Contact support if issue persists"
                ],
                severity: .critical
            )
            return
        }

        recoveryAttempts += 1
        lastRecoveryAction = .reconnecting
        print("[Auto-Recovery] 🔄 Attempt \(recoveryAttempts)/\(maxRetryAttempts)")

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = pow(2.0, Double(recoveryAttempts - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Try to re-enable NDI
        do {
            try controlHub.enableNDI()
            print("[Auto-Recovery] ✅ Recovery successful!")

            // Reset state
            recoveryAttempts = 0
            currentError = nil
            lastRecoveryAction = .recovered
            consecutiveFailures = 0

        } catch {
            print("[Auto-Recovery] ❌ Recovery attempt failed: \(error)")
            consecutiveFailures += 1

            // Try again
            await attemptRecovery()
        }
    }

    // MARK: - Error Handling

    /// Handle a specific error with auto-recovery
    public func handleError(_ error: Error) {
        print("[Auto-Recovery] 🚨 Error: \(error.localizedDescription)")

        // Determine user-friendly error
        let friendlyError = interpretError(error)
        currentError = friendlyError

        // Attempt appropriate recovery action
        Task {
            await recoverFromError(friendlyError)
        }
    }

    private func interpretError(_ error: Error) -> UserFriendlyError {
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkLost
        } else if errorDescription.contains("buffer") {
            return .bufferOverrun
        } else {
            return UserFriendlyError(
                title: "NDI Error",
                message: error.localizedDescription,
                suggestedActions: [
                    "Try restarting NDI",
                    "Check network connection",
                    "Review NDI settings"
                ],
                severity: .error
            )
        }
    }

    private func recoverFromError(_ error: UserFriendlyError) async {
        switch error {
        case .networkLost:
            await handleNetworkLoss()
        case .poorQuality:
            await reduceQualityForStability()
        case .bufferOverrun:
            await increaseBufferSize()
        case .noReceivers:
            // No action needed - just informational
            break
        default:
            await attemptRecovery()
        }
    }

    private func increaseBufferSize() async {
        lastRecoveryAction = .increasingBuffer
        print("[Auto-Recovery] 🛡️ Increasing buffer size")

        let config = NDIConfiguration.shared
        config.bufferSize = min(config.bufferSize * 2, 1024)

        // Restart NDI
        controlHub.disableNDI()
        try? await Task.sleep(nanoseconds: 500_000_000)
        try? controlHub.enableNDI()

        print("[Auto-Recovery] ✅ Buffer increased to \(config.bufferSize) frames")
    }

    // MARK: - Status

    /// Get current recovery status message
    public func getStatusMessage() -> String {
        if let error = currentError {
            return "\(error.severity.emoji) \(error.title): \(error.message)"
        } else if let action = lastRecoveryAction {
            return "\(action.emoji) \(action.message)"
        } else {
            return "✅ Everything is running smoothly"
        }
    }

    /// Get suggested actions for user
    public func getSuggestedActions() -> [String] {
        return currentError?.suggestedActions ?? []
    }

    /// Reset recovery state
    public func reset() {
        recoveryAttempts = 0
        consecutiveFailures = 0
        currentError = nil
        lastRecoveryAction = nil
        hasReducedQuality = false
        print("[Auto-Recovery] 🔄 Reset")
    }
}

// MARK: - Comparable for NetworkQuality

extension NDINetworkMonitor.NetworkStatus.Quality: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self] = [.unavailable, .poor, .fair, .good, .excellent]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
