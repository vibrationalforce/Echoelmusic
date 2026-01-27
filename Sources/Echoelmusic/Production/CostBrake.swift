// CostBrake.swift
// Echoelmusic
//
// Kostenbremse - Cost Limiter System
// Prevents costs from exceeding configurable maximum (default: 500,000)
//
// Created: 2026-01-25
// Phase 10000 ULTIMATE MODE - Production Safety Feature

import Foundation

// MARK: - Cost Brake Error

/// Errors thrown when cost limits are exceeded
public enum CostBrakeError: Error, LocalizedError, Equatable {
    case limitExceeded(current: Double, limit: Double)
    case operationBlocked(reason: String)
    case insufficientBudget(required: Double, available: Double)
    case costBrakeActive

    public var errorDescription: String? {
        switch self {
        case .limitExceeded(let current, let limit):
            return "Kostenlimit überschritten: \(formatCurrency(current)) von \(formatCurrency(limit)) Maximum"
        case .operationBlocked(let reason):
            return "Operation blockiert: \(reason)"
        case .insufficientBudget(let required, let available):
            return "Unzureichendes Budget: \(formatCurrency(required)) benötigt, \(formatCurrency(available)) verfügbar"
        case .costBrakeActive:
            return "Kostenbremse aktiv - keine weiteren Kosten erlaubt"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) EUR"
    }
}

// MARK: - Cost Category

/// Categories for tracking different types of costs
public enum CostCategory: String, CaseIterable, Codable, Sendable {
    case compute = "compute"           // Server/compute costs
    case storage = "storage"           // Data storage costs
    case network = "network"           // Bandwidth/network costs
    case streaming = "streaming"       // Live streaming costs
    case api = "api"                   // External API calls
    case ai = "ai"                     // AI/ML model inference
    case licensing = "licensing"       // Software licensing
    case infrastructure = "infrastructure"  // General infrastructure
    case other = "other"               // Miscellaneous costs

    public var displayName: String {
        switch self {
        case .compute: return "Compute"
        case .storage: return "Speicher"
        case .network: return "Netzwerk"
        case .streaming: return "Streaming"
        case .api: return "API"
        case .ai: return "KI/ML"
        case .licensing: return "Lizenzierung"
        case .infrastructure: return "Infrastruktur"
        case .other: return "Sonstiges"
        }
    }
}

// MARK: - Cost Entry

/// A single cost entry for tracking
public struct CostEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let amount: Double
    public let category: CostCategory
    public let description: String
    public let operationId: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        amount: Double,
        category: CostCategory,
        description: String,
        operationId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.amount = amount
        self.category = category
        self.description = description
        self.operationId = operationId
    }
}

// MARK: - Warning Level

/// Warning levels for cost thresholds
public enum CostWarningLevel: String, CaseIterable, Codable, Sendable {
    case normal = "normal"           // < 50% of limit
    case elevated = "elevated"       // 50-80% of limit
    case warning = "warning"         // 80-90% of limit
    case critical = "critical"       // 90-95% of limit
    case blocked = "blocked"         // >= 95% of limit (operations blocked)

    public var threshold: Double {
        switch self {
        case .normal: return 0.0
        case .elevated: return 0.5
        case .warning: return 0.8
        case .critical: return 0.9
        case .blocked: return 0.95
        }
    }

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Erhöht"
        case .warning: return "Warnung"
        case .critical: return "Kritisch"
        case .blocked: return "Blockiert"
        }
    }

    public var emoji: String {
        switch self {
        case .normal: return "✅"
        case .elevated: return "📊"
        case .warning: return "⚠️"
        case .critical: return "🚨"
        case .blocked: return "🛑"
        }
    }
}

// MARK: - Cost Brake Configuration

/// Configuration for the cost brake system
public struct CostBrakeConfiguration: Codable, Sendable, Equatable {
    /// Maximum allowed total cost (default: 500,000)
    public var maxTotalCost: Double

    /// Whether the cost brake is enabled
    public var isEnabled: Bool

    /// Threshold for blocking new operations (0.0-1.0, default: 0.95 = 95%)
    public var blockingThreshold: Double

    /// Warning thresholds (percentage of max cost)
    public var warningThresholds: [Double]

    /// Per-category limits (optional)
    public var categoryLimits: [CostCategory: Double]

    /// Daily spending limit (optional, 0 = unlimited)
    public var dailyLimit: Double

    /// Monthly spending limit (optional, 0 = unlimited)
    public var monthlyLimit: Double

    /// Whether to persist cost history
    public var persistHistory: Bool

    /// Maximum history entries to keep
    public var maxHistoryEntries: Int

    public static let `default` = CostBrakeConfiguration(
        maxTotalCost: 500_000,
        isEnabled: true,
        blockingThreshold: 0.95,
        warningThresholds: [0.5, 0.8, 0.9, 0.95],
        categoryLimits: [:],
        dailyLimit: 0,
        monthlyLimit: 0,
        persistHistory: true,
        maxHistoryEntries: 10_000
    )

    public static let strict = CostBrakeConfiguration(
        maxTotalCost: 500_000,
        isEnabled: true,
        blockingThreshold: 0.90,
        warningThresholds: [0.3, 0.5, 0.7, 0.9],
        categoryLimits: [
            .ai: 100_000,
            .streaming: 50_000,
            .compute: 150_000
        ],
        dailyLimit: 5_000,
        monthlyLimit: 100_000,
        persistHistory: true,
        maxHistoryEntries: 50_000
    )

    public static let lenient = CostBrakeConfiguration(
        maxTotalCost: 500_000,
        isEnabled: true,
        blockingThreshold: 0.99,
        warningThresholds: [0.8, 0.95],
        categoryLimits: [:],
        dailyLimit: 0,
        monthlyLimit: 0,
        persistHistory: true,
        maxHistoryEntries: 5_000
    )

    public init(
        maxTotalCost: Double = 500_000,
        isEnabled: Bool = true,
        blockingThreshold: Double = 0.95,
        warningThresholds: [Double] = [0.5, 0.8, 0.9, 0.95],
        categoryLimits: [CostCategory: Double] = [:],
        dailyLimit: Double = 0,
        monthlyLimit: Double = 0,
        persistHistory: Bool = true,
        maxHistoryEntries: Int = 10_000
    ) {
        self.maxTotalCost = maxTotalCost
        self.isEnabled = isEnabled
        self.blockingThreshold = min(1.0, max(0.0, blockingThreshold))
        self.warningThresholds = warningThresholds.sorted()
        self.categoryLimits = categoryLimits
        self.dailyLimit = dailyLimit
        self.monthlyLimit = monthlyLimit
        self.persistHistory = persistHistory
        self.maxHistoryEntries = maxHistoryEntries
    }
}

// MARK: - Cost Brake Status

/// Current status of the cost brake system
public struct CostBrakeStatus: Codable, Sendable, Equatable {
    public let totalCost: Double
    public let remainingBudget: Double
    public let usagePercentage: Double
    public let warningLevel: CostWarningLevel
    public let isBlocked: Bool
    public let costByCategory: [CostCategory: Double]
    public let dailyCost: Double
    public let monthlyCost: Double
    public let lastUpdated: Date

    public var formattedTotalCost: String {
        formatCurrency(totalCost)
    }

    public var formattedRemainingBudget: String {
        formatCurrency(remainingBudget)
    }

    public var formattedUsagePercentage: String {
        String(format: "%.1f%%", usagePercentage * 100)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) EUR"
    }
}

// MARK: - Cost Brake Delegate

/// Protocol for receiving cost brake notifications
public protocol CostBrakeDelegate: AnyObject {
    func costBrake(_ brake: CostBrake, didReachWarningLevel level: CostWarningLevel, currentCost: Double, limit: Double)
    func costBrake(_ brake: CostBrake, didBlockOperation description: String, estimatedCost: Double)
    func costBrakeDidReset(_ brake: CostBrake)
}

// Provide default implementations
public extension CostBrakeDelegate {
    func costBrake(_ brake: CostBrake, didReachWarningLevel level: CostWarningLevel, currentCost: Double, limit: Double) {}
    func costBrake(_ brake: CostBrake, didBlockOperation description: String, estimatedCost: Double) {}
    func costBrakeDidReset(_ brake: CostBrake) {}
}

// MARK: - Cost Brake

/// Main cost brake system that enforces cost limits
///
/// Die Kostenbremse verhindert, dass Kosten 500.000 EUR überschreiten.
/// Sie bietet Warnungen bei 50%, 80%, 90% und blockiert neue Operationen bei 95%.
///
/// Usage:
/// ```swift
/// let brake = CostBrake.shared
///
/// // Check if an operation is allowed
/// if brake.canAfford(estimatedCost: 1000, category: .compute) {
///     // Proceed with operation
///     try brake.recordCost(1000, category: .compute, description: "VM usage")
/// }
///
/// // Get current status
/// let status = brake.getStatus()
/// print("Verbleibend: \(status.formattedRemainingBudget)")
/// ```
@MainActor
public final class CostBrake: ObservableObject {

    // MARK: - Singleton

    public static let shared = CostBrake()

    // MARK: - Published Properties

    @Published public private(set) var configuration: CostBrakeConfiguration
    @Published public private(set) var totalCost: Double = 0
    @Published public private(set) var warningLevel: CostWarningLevel = .normal
    @Published public private(set) var isBlocked: Bool = false
    @Published public private(set) var costHistory: [CostEntry] = []
    @Published public private(set) var costByCategory: [CostCategory: Double] = [:]

    // MARK: - Private Properties

    private var dailyCosts: [Date: Double] = [:]
    private var monthlyCosts: [String: Double] = [:]
    private var lastNotifiedWarningLevel: CostWarningLevel = .normal
    private let userDefaultsKey = "echoelmusic.costbrake.data"

    public weak var delegate: CostBrakeDelegate?

    // MARK: - Computed Properties

    /// Remaining budget before limit is reached
    public var remainingBudget: Double {
        max(0, configuration.maxTotalCost - totalCost)
    }

    /// Current usage as percentage (0.0 - 1.0)
    public var usagePercentage: Double {
        guard configuration.maxTotalCost > 0 else { return 0 }
        return min(1.0, totalCost / configuration.maxTotalCost)
    }

    /// Amount available before blocking threshold
    public var availableBeforeBlocking: Double {
        let blockingLimit = configuration.maxTotalCost * configuration.blockingThreshold
        return max(0, blockingLimit - totalCost)
    }

    /// Today's total cost
    public var todaysCost: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyCosts[today] ?? 0
    }

    /// This month's total cost
    public var thisMonthsCost: Double {
        let key = monthKey(for: Date())
        return monthlyCosts[key] ?? 0
    }

    // MARK: - Initialization

    public init(configuration: CostBrakeConfiguration = .default) {
        self.configuration = configuration

        // Initialize category costs
        for category in CostCategory.allCases {
            costByCategory[category] = 0
        }

        // Load persisted data if enabled
        if configuration.persistHistory {
            loadPersistedData()
        }

        updateWarningLevel()
    }

    // MARK: - Public Methods

    /// Check if an operation with estimated cost can proceed
    /// - Parameters:
    ///   - estimatedCost: The estimated cost of the operation
    ///   - category: The cost category
    /// - Returns: True if the operation can proceed
    public func canAfford(estimatedCost: Double, category: CostCategory = .other) -> Bool {
        guard configuration.isEnabled else { return true }

        // Check total limit
        let projectedTotal = totalCost + estimatedCost
        let blockingLimit = configuration.maxTotalCost * configuration.blockingThreshold

        if projectedTotal > blockingLimit {
            return false
        }

        // Check category limit if defined
        if let categoryLimit = configuration.categoryLimits[category] {
            let currentCategoryCost = costByCategory[category] ?? 0
            if currentCategoryCost + estimatedCost > categoryLimit {
                return false
            }
        }

        // Check daily limit
        if configuration.dailyLimit > 0 {
            if todaysCost + estimatedCost > configuration.dailyLimit {
                return false
            }
        }

        // Check monthly limit
        if configuration.monthlyLimit > 0 {
            if thisMonthsCost + estimatedCost > configuration.monthlyLimit {
                return false
            }
        }

        return true
    }

    /// Record a cost entry
    /// - Parameters:
    ///   - amount: The cost amount
    ///   - category: The cost category
    ///   - description: Description of what incurred the cost
    ///   - operationId: Optional operation ID for tracking
    /// - Throws: CostBrakeError if recording would exceed limits
    public func recordCost(
        _ amount: Double,
        category: CostCategory,
        description: String,
        operationId: String? = nil
    ) throws {
        guard configuration.isEnabled else { return }
        guard amount > 0 else { return }

        // Check if we can afford this
        if !canAfford(estimatedCost: amount, category: category) {
            delegate?.costBrake(self, didBlockOperation: description, estimatedCost: amount)
            throw CostBrakeError.insufficientBudget(required: amount, available: availableBeforeBlocking)
        }

        // Create entry
        let entry = CostEntry(
            amount: amount,
            category: category,
            description: description,
            operationId: operationId
        )

        // Update totals
        totalCost += amount
        costByCategory[category, default: 0] += amount

        // Update daily/monthly tracking
        let today = Calendar.current.startOfDay(for: Date())
        dailyCosts[today, default: 0] += amount

        let monthKey = self.monthKey(for: Date())
        monthlyCosts[monthKey, default: 0] += amount

        // Add to history
        costHistory.append(entry)

        // Trim history if needed
        if costHistory.count > configuration.maxHistoryEntries {
            costHistory = Array(costHistory.suffix(configuration.maxHistoryEntries))
        }

        // Update warning level
        updateWarningLevel()

        // Persist if enabled
        if configuration.persistHistory {
            persistData()
        }
    }

    /// Attempt to execute an operation, checking cost first
    /// - Parameters:
    ///   - estimatedCost: The estimated cost
    ///   - category: The cost category
    ///   - description: Description of the operation
    ///   - operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: CostBrakeError if the operation cannot proceed
    public func executeIfAffordable<T>(
        estimatedCost: Double,
        category: CostCategory,
        description: String,
        operation: () async throws -> T
    ) async throws -> T {
        guard canAfford(estimatedCost: estimatedCost, category: category) else {
            delegate?.costBrake(self, didBlockOperation: description, estimatedCost: estimatedCost)
            throw CostBrakeError.insufficientBudget(required: estimatedCost, available: availableBeforeBlocking)
        }

        // Execute the operation
        let result = try await operation()

        // Record the cost after successful execution
        try recordCost(estimatedCost, category: category, description: description)

        return result
    }

    /// Get the current status of the cost brake
    /// - Returns: Current CostBrakeStatus
    public func getStatus() -> CostBrakeStatus {
        CostBrakeStatus(
            totalCost: totalCost,
            remainingBudget: remainingBudget,
            usagePercentage: usagePercentage,
            warningLevel: warningLevel,
            isBlocked: isBlocked,
            costByCategory: costByCategory,
            dailyCost: todaysCost,
            monthlyCost: thisMonthsCost,
            lastUpdated: Date()
        )
    }

    /// Reset all cost tracking (use with caution!)
    /// - Parameter confirmationCode: Must be "RESET_COSTS" to confirm
    public func reset(confirmationCode: String) {
        guard confirmationCode == "RESET_COSTS" else { return }

        totalCost = 0
        costHistory = []
        dailyCosts = [:]
        monthlyCosts = [:]

        for category in CostCategory.allCases {
            costByCategory[category] = 0
        }

        warningLevel = .normal
        isBlocked = false
        lastNotifiedWarningLevel = .normal

        if configuration.persistHistory {
            persistData()
        }

        delegate?.costBrakeDidReset(self)
    }

    /// Update the configuration
    /// - Parameter newConfiguration: New configuration to apply
    public func updateConfiguration(_ newConfiguration: CostBrakeConfiguration) {
        self.configuration = newConfiguration
        updateWarningLevel()

        if newConfiguration.persistHistory {
            persistData()
        }
    }

    /// Set a new maximum cost limit
    /// - Parameter limit: New maximum total cost (must be > 0)
    public func setMaxCost(_ limit: Double) {
        guard limit > 0 else { return }
        configuration = CostBrakeConfiguration(
            maxTotalCost: limit,
            isEnabled: configuration.isEnabled,
            blockingThreshold: configuration.blockingThreshold,
            warningThresholds: configuration.warningThresholds,
            categoryLimits: configuration.categoryLimits,
            dailyLimit: configuration.dailyLimit,
            monthlyLimit: configuration.monthlyLimit,
            persistHistory: configuration.persistHistory,
            maxHistoryEntries: configuration.maxHistoryEntries
        )
        updateWarningLevel()
    }

    /// Enable or disable the cost brake
    /// - Parameter enabled: Whether to enable the brake
    public func setEnabled(_ enabled: Bool) {
        configuration = CostBrakeConfiguration(
            maxTotalCost: configuration.maxTotalCost,
            isEnabled: enabled,
            blockingThreshold: configuration.blockingThreshold,
            warningThresholds: configuration.warningThresholds,
            categoryLimits: configuration.categoryLimits,
            dailyLimit: configuration.dailyLimit,
            monthlyLimit: configuration.monthlyLimit,
            persistHistory: configuration.persistHistory,
            maxHistoryEntries: configuration.maxHistoryEntries
        )
    }

    /// Get cost history for a specific category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of cost entries for that category
    public func getHistory(for category: CostCategory) -> [CostEntry] {
        costHistory.filter { $0.category == category }
    }

    /// Get cost history for a date range
    /// - Parameters:
    ///   - startDate: Start of the range
    ///   - endDate: End of the range
    /// - Returns: Array of cost entries in that range
    public func getHistory(from startDate: Date, to endDate: Date) -> [CostEntry] {
        costHistory.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get a summary of costs by category
    /// - Returns: Dictionary mapping categories to their totals
    public func getCostSummary() -> [CostCategory: Double] {
        costByCategory
    }

    /// Check if the current cost exceeds a threshold
    /// - Parameter threshold: Threshold percentage (0.0-1.0)
    /// - Returns: True if current cost exceeds the threshold
    public func isAboveThreshold(_ threshold: Double) -> Bool {
        usagePercentage >= threshold
    }

    // MARK: - Private Methods

    private func updateWarningLevel() {
        let percentage = usagePercentage

        // Determine warning level based on percentage
        var newLevel: CostWarningLevel = .normal

        for threshold in configuration.warningThresholds.sorted().reversed() {
            if percentage >= threshold {
                if threshold >= 0.95 {
                    newLevel = .blocked
                } else if threshold >= 0.9 {
                    newLevel = .critical
                } else if threshold >= 0.8 {
                    newLevel = .warning
                } else if threshold >= 0.5 {
                    newLevel = .elevated
                }
                break
            }
        }

        // Update blocking status
        isBlocked = percentage >= configuration.blockingThreshold

        // Notify delegate if warning level changed
        if newLevel != warningLevel && newLevel.rawValue != lastNotifiedWarningLevel.rawValue {
            warningLevel = newLevel
            lastNotifiedWarningLevel = newLevel
            delegate?.costBrake(self, didReachWarningLevel: newLevel, currentCost: totalCost, limit: configuration.maxTotalCost)
        } else {
            warningLevel = newLevel
        }
    }

    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var totalCost: Double
        var costByCategory: [String: Double]
        var costHistory: [CostEntry]
        var dailyCosts: [String: Double]
        var monthlyCosts: [String: Double]
    }

    private func persistData() {
        // Convert category dict to string keys for Codable
        var categoryDict: [String: Double] = [:]
        for (key, value) in costByCategory {
            categoryDict[key.rawValue] = value
        }

        // Convert daily costs to string keys
        var dailyDict: [String: Double] = [:]
        let formatter = ISO8601DateFormatter()
        for (date, cost) in dailyCosts {
            dailyDict[formatter.string(from: date)] = cost
        }

        let data = PersistedData(
            totalCost: totalCost,
            costByCategory: categoryDict,
            costHistory: costHistory,
            dailyCosts: dailyDict,
            monthlyCosts: monthlyCosts
        )

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadPersistedData() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else {
            return
        }

        totalCost = decoded.totalCost
        costHistory = decoded.costHistory
        monthlyCosts = decoded.monthlyCosts

        // Convert category dict from string keys
        for (key, value) in decoded.costByCategory {
            if let category = CostCategory(rawValue: key) {
                costByCategory[category] = value
            }
        }

        // Convert daily costs from string keys
        let formatter = ISO8601DateFormatter()
        for (key, value) in decoded.dailyCosts {
            if let date = formatter.date(from: key) {
                dailyCosts[date] = value
            }
        }
    }
}

// MARK: - Convenience Extensions

public extension CostBrake {

    /// Quick check if any new costs can be incurred
    var canIncurCosts: Bool {
        !isBlocked && configuration.isEnabled
    }

    /// Formatted display string for current status
    var statusDisplay: String {
        let status = getStatus()
        return """
        \(status.warningLevel.emoji) Kostenstatus: \(status.warningLevel.displayName)
        Gesamt: \(status.formattedTotalCost) / \(formatCurrency(configuration.maxTotalCost))
        Verbleibend: \(status.formattedRemainingBudget)
        Auslastung: \(status.formattedUsagePercentage)
        """
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) EUR"
    }
}

// MARK: - ResourceManager Integration

/// Extension to integrate CostBrake with existing ResourceManager
public extension CostBrake {

    /// Record cost from a ResourceEstimate
    /// - Parameters:
    ///   - estimate: The resource estimate from ResourceManager
    ///   - description: Description of what incurred the cost
    func recordFromResourceEstimate(
        computeHours: Double,
        storageGB: Double,
        networkGB: Double,
        estimatedCost: Double,
        description: String
    ) throws {
        // Record the estimated cost
        try recordCost(estimatedCost, category: .compute, description: description)
    }
}
