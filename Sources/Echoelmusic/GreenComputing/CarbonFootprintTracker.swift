// CarbonFootprintTracker.swift
// Echoelmusic - Carbon Footprint Tracking & Eco-Reporting
//
// Track, visualize, and reduce environmental impact
// Based on IEA and EPA carbon intensity data

import Foundation
import Combine
import os.log

private let carbonLogger = Logger(subsystem: "com.echoelmusic.green", category: "CarbonTracker")

// MARK: - Carbon Intensity by Region

public enum EnergyRegion: String, CaseIterable, Codable {
    case global = "Global Average"
    case europe = "Europe (EU)"
    case northAmerica = "North America"
    case asia = "Asia Pacific"
    case nordic = "Nordic Countries"
    case france = "France"
    case germany = "Germany"
    case usa = "United States"
    case china = "China"
    case india = "India"
    case australia = "Australia"
    case brazil = "Brazil"
    case uk = "United Kingdom"

    /// CO2 grams per kWh (2023 IEA data)
    public var carbonIntensity: Double {
        switch self {
        case .global: return 475
        case .europe: return 276
        case .northAmerica: return 388
        case .asia: return 555
        case .nordic: return 41      // High hydro/nuclear
        case .france: return 56      // Nuclear dominant
        case .germany: return 350
        case .usa: return 388
        case .china: return 581
        case .india: return 708
        case .australia: return 656
        case .brazil: return 103     // High hydro
        case .uk: return 238
        }
    }

    /// Renewable percentage
    public var renewablePercent: Double {
        switch self {
        case .global: return 29
        case .europe: return 44
        case .northAmerica: return 23
        case .asia: return 31
        case .nordic: return 98
        case .france: return 92
        case .germany: return 52
        case .usa: return 22
        case .china: return 31
        case .india: return 23
        case .australia: return 35
        case .brazil: return 83
        case .uk: return 43
        }
    }
}

// MARK: - Detailed Carbon Report

public struct CarbonReport: Codable {
    public var period: ReportPeriod
    public var startDate: Date
    public var endDate: Date
    public var region: EnergyRegion

    // Energy consumption
    public var totalWattHours: Double
    public var cpuWattHours: Double
    public var gpuWattHours: Double
    public var memoryWattHours: Double
    public var networkWattHours: Double
    public var storageWattHours: Double

    // Carbon emissions
    public var totalCO2Grams: Double
    public var co2Avoided: Double  // Through green optimizations

    // Comparisons
    public var equivalentCarKm: Double
    public var equivalentTreeDays: Double
    public var equivalentPhoneCharges: Double
    public var equivalentLEDHours: Double

    // Efficiency metrics
    public var efficiencyScore: Double
    public var greenModeMinutes: Double
    public var activeMinutes: Double
    public var averagePowerWatts: Double

    public enum ReportPeriod: String, Codable {
        case session
        case daily
        case weekly
        case monthly
        case yearly
        case lifetime
    }

    public init(period: ReportPeriod, region: EnergyRegion = .global) {
        self.period = period
        self.startDate = Date()
        self.endDate = Date()
        self.region = region
        self.totalWattHours = 0
        self.cpuWattHours = 0
        self.gpuWattHours = 0
        self.memoryWattHours = 0
        self.networkWattHours = 0
        self.storageWattHours = 0
        self.totalCO2Grams = 0
        self.co2Avoided = 0
        self.equivalentCarKm = 0
        self.equivalentTreeDays = 0
        self.equivalentPhoneCharges = 0
        self.equivalentLEDHours = 0
        self.efficiencyScore = 1.0
        self.greenModeMinutes = 0
        self.activeMinutes = 0
        self.averagePowerWatts = 0
    }
}

// MARK: - Eco Achievement

public struct EcoAchievement: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var icon: String
    public var unlockedDate: Date?
    public var progress: Double  // 0-1

    public var isUnlocked: Bool { unlockedDate != nil }

    public static let allAchievements: [EcoAchievement] = [
        EcoAchievement(
            id: "first_green_session",
            name: "Green Starter",
            description: "Complete your first session in low-power mode",
            icon: "leaf",
            progress: 0
        ),
        EcoAchievement(
            id: "tree_saver",
            name: "Tree Saver",
            description: "Save 1 tree-day worth of CO2",
            icon: "tree",
            progress: 0
        ),
        EcoAchievement(
            id: "power_optimizer",
            name: "Power Optimizer",
            description: "Maintain 80% efficiency score for a week",
            icon: "bolt",
            progress: 0
        ),
        EcoAchievement(
            id: "carbon_neutral_day",
            name: "Carbon Neutral",
            description: "Complete a day with near-zero emissions",
            icon: "globe",
            progress: 0
        ),
        EcoAchievement(
            id: "eco_warrior",
            name: "Eco Warrior",
            description: "Save 100 phone charges worth of energy",
            icon: "shield",
            progress: 0
        ),
        EcoAchievement(
            id: "green_champion",
            name: "Green Champion",
            description: "Reach lifetime efficiency score of 90%",
            icon: "crown",
            progress: 0
        )
    ]
}

// MARK: - Carbon Footprint Tracker

@MainActor
public final class CarbonFootprintTracker: ObservableObject {
    public static let shared = CarbonFootprintTracker()

    // MARK: - Published State

    @Published public private(set) var currentRegion: EnergyRegion = .global
    @Published public private(set) var sessionReport: CarbonReport
    @Published public private(set) var dailyReport: CarbonReport
    @Published public private(set) var lifetimeReport: CarbonReport
    @Published public private(set) var achievements: [EcoAchievement] = EcoAchievement.allAchievements
    @Published public private(set) var recommendations: [EcoRecommendation] = []

    // MARK: - Tracking State

    private var sessionStartTime: Date = Date()
    private var greenModeStartTime: Date?
    private var lastUpdateTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    // Historical data
    private var dailyHistory: [Date: CarbonReport] = [:]

    // MARK: - Initialization

    private init() {
        sessionReport = CarbonReport(period: .session)
        dailyReport = CarbonReport(period: .daily)
        lifetimeReport = CarbonReport(period: .lifetime)

        loadHistoricalData()
        detectRegion()
        setupTracking()

        carbonLogger.info("CarbonFootprintTracker initialized for region: \(self.currentRegion.rawValue)")
    }

    // MARK: - Public API

    /// Set the energy region for accurate carbon calculations
    public func setRegion(_ region: EnergyRegion) {
        currentRegion = region
        recalculateEmissions()
        carbonLogger.info("Region set to: \(region.rawValue) (\(region.carbonIntensity)g CO2/kWh)")
    }

    /// Record energy consumption
    public func recordConsumption(
        cpuWatts: Double = 0,
        gpuWatts: Double = 0,
        memoryWatts: Double = 0,
        networkWatts: Double = 0,
        storageWatts: Double = 0
    ) {
        let now = Date()
        let hours = now.timeIntervalSince(lastUpdateTime) / 3600.0
        lastUpdateTime = now

        // Calculate watt-hours for this period
        let cpuWh = cpuWatts * hours
        let gpuWh = gpuWatts * hours
        let memWh = memoryWatts * hours
        let netWh = networkWatts * hours
        let stoWh = storageWatts * hours

        // Update session
        sessionReport.cpuWattHours += cpuWh
        sessionReport.gpuWattHours += gpuWh
        sessionReport.memoryWattHours += memWh
        sessionReport.networkWattHours += netWh
        sessionReport.storageWattHours += stoWh
        sessionReport.totalWattHours = sessionReport.cpuWattHours +
                                       sessionReport.gpuWattHours +
                                       sessionReport.memoryWattHours +
                                       sessionReport.networkWattHours +
                                       sessionReport.storageWattHours

        // Update daily
        dailyReport.cpuWattHours += cpuWh
        dailyReport.gpuWattHours += gpuWh
        dailyReport.memoryWattHours += memWh
        dailyReport.networkWattHours += netWh
        dailyReport.storageWattHours += stoWh
        dailyReport.totalWattHours = dailyReport.cpuWattHours +
                                     dailyReport.gpuWattHours +
                                     dailyReport.memoryWattHours +
                                     dailyReport.networkWattHours +
                                     dailyReport.storageWattHours

        // Update lifetime
        lifetimeReport.cpuWattHours += cpuWh
        lifetimeReport.gpuWattHours += gpuWh
        lifetimeReport.memoryWattHours += memWh
        lifetimeReport.networkWattHours += netWh
        lifetimeReport.storageWattHours += stoWh
        lifetimeReport.totalWattHours = lifetimeReport.cpuWattHours +
                                        lifetimeReport.gpuWattHours +
                                        lifetimeReport.memoryWattHours +
                                        lifetimeReport.networkWattHours +
                                        lifetimeReport.storageWattHours

        // Recalculate emissions
        recalculateEmissions()

        // Update active time
        sessionReport.activeMinutes += hours * 60
        dailyReport.activeMinutes += hours * 60
        lifetimeReport.activeMinutes += hours * 60
    }

    /// Record CO2 savings from green optimizations
    public func recordSavings(wattsAvoided: Double, duration: TimeInterval) {
        let whAvoided = wattsAvoided * (duration / 3600.0)
        let co2Avoided = whAvoided * currentRegion.carbonIntensity / 1000.0

        sessionReport.co2Avoided += co2Avoided
        dailyReport.co2Avoided += co2Avoided
        lifetimeReport.co2Avoided += co2Avoided

        carbonLogger.debug("Recorded savings: \(co2Avoided)g CO2")
    }

    /// Track green mode usage
    public func enterGreenMode() {
        greenModeStartTime = Date()
    }

    public func exitGreenMode() {
        guard let startTime = greenModeStartTime else { return }
        let minutes = Date().timeIntervalSince(startTime) / 60.0

        sessionReport.greenModeMinutes += minutes
        dailyReport.greenModeMinutes += minutes
        lifetimeReport.greenModeMinutes += minutes

        greenModeStartTime = nil
        checkAchievements()
    }

    /// Generate detailed report
    public func generateReport(period: CarbonReport.ReportPeriod) -> CarbonReport {
        switch period {
        case .session:
            return sessionReport
        case .daily:
            return dailyReport
        case .lifetime:
            return lifetimeReport
        default:
            return generateHistoricalReport(period: period)
        }
    }

    /// Get eco-friendly recommendations
    public func getRecommendations() -> [EcoRecommendation] {
        var recs: [EcoRecommendation] = []

        // Check GPU usage
        if sessionReport.gpuWattHours > sessionReport.cpuWattHours * 2 {
            recs.append(EcoRecommendation(
                category: .visual,
                title: "Reduce Visual Quality",
                description: "GPU usage is high. Consider reducing visual effects to save energy.",
                potentialSavings: 30,
                action: "Lower visual quality in settings"
            ))
        }

        // Check efficiency score
        if sessionReport.efficiencyScore < 0.6 {
            recs.append(EcoRecommendation(
                category: .efficiency,
                title: "Enable Green Mode",
                description: "Your efficiency score is low. Enable green computing mode for better power management.",
                potentialSavings: 40,
                action: "Enable green mode"
            ))
        }

        // Check region
        if currentRegion.carbonIntensity > 400 {
            recs.append(EcoRecommendation(
                category: .general,
                title: "Consider Renewable Energy",
                description: "Your region has high carbon intensity (\(Int(currentRegion.carbonIntensity))g/kWh). Consider scheduling intensive tasks during low-carbon periods.",
                potentialSavings: 20,
                action: "Check grid carbon intensity"
            ))
        }

        // Check idle behavior
        let idleRatio = sessionReport.greenModeMinutes / max(sessionReport.activeMinutes, 1)
        if idleRatio < 0.1 {
            recs.append(EcoRecommendation(
                category: .behavior,
                title: "Use Auto-Sleep",
                description: "Enable auto-sleep to automatically reduce power during inactive periods.",
                potentialSavings: 25,
                action: "Enable auto-sleep in settings"
            ))
        }

        recommendations = recs
        return recs
    }

    /// Reset session tracking
    public func resetSession() {
        sessionReport = CarbonReport(period: .session, region: currentRegion)
        sessionStartTime = Date()
        lastUpdateTime = Date()
        carbonLogger.info("Session reset")
    }

    // MARK: - Private Methods

    private func setupTracking() {
        // Subscribe to green computing engine updates
        GreenComputingEngine.shared.$sessionFootprint
            .sink { [weak self] footprint in
                Task { @MainActor in
                    self?.syncWithGreenEngine(footprint)
                }
            }
            .store(in: &cancellables)

        // Daily reset timer
        scheduleDailyReset()
    }

    private func syncWithGreenEngine(_ footprint: CarbonFootprint) {
        sessionReport.cpuWattHours = footprint.cpuWattHours
        sessionReport.gpuWattHours = footprint.gpuWattHours
        sessionReport.memoryWattHours = footprint.memoryWattHours
        sessionReport.networkWattHours = footprint.networkWattHours
        sessionReport.storageWattHours = footprint.storageWattHours
        sessionReport.totalWattHours = footprint.totalWattHours

        recalculateEmissions()
    }

    private func recalculateEmissions() {
        let intensity = currentRegion.carbonIntensity

        // Session emissions
        sessionReport.totalCO2Grams = sessionReport.totalWattHours * intensity / 1000.0
        sessionReport.equivalentCarKm = sessionReport.totalCO2Grams / 120.0  // ~120g CO2/km average car
        sessionReport.equivalentTreeDays = sessionReport.totalCO2Grams / 60.0  // Tree absorbs ~60g/day
        sessionReport.equivalentPhoneCharges = sessionReport.totalWattHours / 10.0
        sessionReport.equivalentLEDHours = sessionReport.totalWattHours / 10.0  // 10W LED

        // Daily emissions
        dailyReport.totalCO2Grams = dailyReport.totalWattHours * intensity / 1000.0
        dailyReport.equivalentCarKm = dailyReport.totalCO2Grams / 120.0
        dailyReport.equivalentTreeDays = dailyReport.totalCO2Grams / 60.0
        dailyReport.equivalentPhoneCharges = dailyReport.totalWattHours / 10.0
        dailyReport.equivalentLEDHours = dailyReport.totalWattHours / 10.0

        // Lifetime emissions
        lifetimeReport.totalCO2Grams = lifetimeReport.totalWattHours * intensity / 1000.0
        lifetimeReport.equivalentCarKm = lifetimeReport.totalCO2Grams / 120.0
        lifetimeReport.equivalentTreeDays = lifetimeReport.totalCO2Grams / 60.0
        lifetimeReport.equivalentPhoneCharges = lifetimeReport.totalWattHours / 10.0
        lifetimeReport.equivalentLEDHours = lifetimeReport.totalWattHours / 10.0

        // Calculate efficiency scores
        calculateEfficiencyScores()
    }

    private func calculateEfficiencyScores() {
        // Efficiency = green time / active time * (1 - normalized power)
        let sessionGreenRatio = sessionReport.greenModeMinutes / max(sessionReport.activeMinutes, 1)
        let sessionPowerFactor = 1.0 - min(sessionReport.averagePowerWatts / 50.0, 1.0)
        sessionReport.efficiencyScore = (sessionGreenRatio * 0.5 + sessionPowerFactor * 0.5)

        let dailyGreenRatio = dailyReport.greenModeMinutes / max(dailyReport.activeMinutes, 1)
        let dailyPowerFactor = 1.0 - min(dailyReport.averagePowerWatts / 50.0, 1.0)
        dailyReport.efficiencyScore = (dailyGreenRatio * 0.5 + dailyPowerFactor * 0.5)

        let lifetimeGreenRatio = lifetimeReport.greenModeMinutes / max(lifetimeReport.activeMinutes, 1)
        let lifetimePowerFactor = 1.0 - min(lifetimeReport.averagePowerWatts / 50.0, 1.0)
        lifetimeReport.efficiencyScore = (lifetimeGreenRatio * 0.5 + lifetimePowerFactor * 0.5)
    }

    private func checkAchievements() {
        // Check and unlock achievements
        for i in 0..<achievements.count {
            switch achievements[i].id {
            case "first_green_session":
                if sessionReport.greenModeMinutes > 5 && achievements[i].unlockedDate == nil {
                    achievements[i].unlockedDate = Date()
                    achievements[i].progress = 1.0
                    carbonLogger.info("Achievement unlocked: \(achievements[i].name)")
                }

            case "tree_saver":
                let progress = lifetimeReport.equivalentTreeDays
                achievements[i].progress = min(progress, 1.0)
                if progress >= 1.0 && achievements[i].unlockedDate == nil {
                    achievements[i].unlockedDate = Date()
                }

            case "eco_warrior":
                let progress = lifetimeReport.equivalentPhoneCharges / 100.0
                achievements[i].progress = min(progress, 1.0)
                if progress >= 1.0 && achievements[i].unlockedDate == nil {
                    achievements[i].unlockedDate = Date()
                }

            case "green_champion":
                let progress = lifetimeReport.efficiencyScore / 0.9
                achievements[i].progress = min(progress, 1.0)
                if lifetimeReport.efficiencyScore >= 0.9 && achievements[i].unlockedDate == nil {
                    achievements[i].unlockedDate = Date()
                }

            default:
                break
            }
        }
    }

    private func detectRegion() {
        // Auto-detect region based on locale
        let regionCode = Locale.current.region?.identifier ?? "US"

        switch regionCode {
        case "FR": currentRegion = .france
        case "DE": currentRegion = .germany
        case "GB": currentRegion = .uk
        case "US": currentRegion = .usa
        case "CN": currentRegion = .china
        case "IN": currentRegion = .india
        case "AU": currentRegion = .australia
        case "BR": currentRegion = .brazil
        case "SE", "NO", "FI", "DK", "IS": currentRegion = .nordic
        default:
            if ["AT", "BE", "CZ", "DK", "EE", "ES", "FI", "GR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "NL", "PL", "PT", "RO", "SE", "SI", "SK"].contains(regionCode) {
                currentRegion = .europe
            } else if ["CA", "MX"].contains(regionCode) {
                currentRegion = .northAmerica
            } else if ["JP", "KR", "TW", "HK", "SG", "TH", "VN", "MY", "ID", "PH"].contains(regionCode) {
                currentRegion = .asia
            }
        }
    }

    private func generateHistoricalReport(period: CarbonReport.ReportPeriod) -> CarbonReport {
        var report = CarbonReport(period: period, region: currentRegion)

        let calendar = Calendar.current
        let now = Date()

        let daysToInclude: Int
        switch period {
        case .weekly: daysToInclude = 7
        case .monthly: daysToInclude = 30
        case .yearly: daysToInclude = 365
        default: daysToInclude = 1
        }

        report.startDate = calendar.date(byAdding: .day, value: -daysToInclude, to: now) ?? now
        report.endDate = now

        // Aggregate historical data
        for (date, dayReport) in dailyHistory {
            if date >= report.startDate && date <= report.endDate {
                report.totalWattHours += dayReport.totalWattHours
                report.cpuWattHours += dayReport.cpuWattHours
                report.gpuWattHours += dayReport.gpuWattHours
                report.memoryWattHours += dayReport.memoryWattHours
                report.networkWattHours += dayReport.networkWattHours
                report.storageWattHours += dayReport.storageWattHours
                report.greenModeMinutes += dayReport.greenModeMinutes
                report.activeMinutes += dayReport.activeMinutes
                report.co2Avoided += dayReport.co2Avoided
            }
        }

        // Calculate emissions for aggregated data
        report.totalCO2Grams = report.totalWattHours * currentRegion.carbonIntensity / 1000.0
        report.equivalentCarKm = report.totalCO2Grams / 120.0
        report.equivalentTreeDays = report.totalCO2Grams / 60.0
        report.equivalentPhoneCharges = report.totalWattHours / 10.0
        report.equivalentLEDHours = report.totalWattHours / 10.0

        return report
    }

    private func scheduleDailyReset() {
        // Reset daily report at midnight
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) {
            let interval = midnight.timeIntervalSince(Date())

            Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.performDailyReset()
                }
            }
        }
    }

    private func performDailyReset() {
        // Archive daily report
        let today = Calendar.current.startOfDay(for: Date())
        dailyHistory[today] = dailyReport

        // Reset daily
        dailyReport = CarbonReport(period: .daily, region: currentRegion)

        // Save and schedule next reset
        saveHistoricalData()
        scheduleDailyReset()

        carbonLogger.info("Daily carbon report reset")
    }

    // MARK: - Persistence

    private func saveHistoricalData() {
        if let data = try? JSONEncoder().encode(lifetimeReport) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.carbon.lifetime")
        }
    }

    private func loadHistoricalData() {
        if let data = UserDefaults.standard.data(forKey: "echoelmusic.carbon.lifetime"),
           let report = try? JSONDecoder().decode(CarbonReport.self, from: data) {
            lifetimeReport = report
        }
    }
}

// MARK: - Supporting Types

public struct EcoRecommendation: Identifiable {
    public var id = UUID()
    public var category: Category
    public var title: String
    public var description: String
    public var potentialSavings: Int  // Percentage
    public var action: String

    public enum Category: String {
        case visual = "Visual"
        case audio = "Audio"
        case efficiency = "Efficiency"
        case behavior = "Behavior"
        case general = "General"
    }
}
