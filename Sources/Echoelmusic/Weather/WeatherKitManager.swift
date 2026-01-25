// WeatherKitManager.swift
// Echoelmusic
//
// Smart WeatherKit integration with caching and rate limiting
// to stay within the free tier (500,000 calls/month)
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Weather Data Model

/// Unified weather data model for cross-platform use
public struct EchoelWeatherData: Codable, Sendable {
    // Temperature & Humidity
    public let temperature: Double           // Celsius
    public let apparentTemperature: Double   // "Feels like" Celsius
    public let humidity: Double              // 0-1

    // Pressure
    public let pressure: Double              // hPa (hectopascals)
    public let pressureTrend: PressureTrend

    // Wind
    public let windSpeed: Double             // m/s
    public let windGust: Double?             // m/s
    public let windDirection: Double         // Degrees (0-360)

    // Sun & UV
    public let uvIndex: Int                  // 0-11+
    public let cloudCover: Double            // 0-1
    public let visibility: Double            // meters

    // Conditions
    public let condition: WeatherCondition
    public let isDaylight: Bool

    // Precipitation
    public let precipitationIntensity: Double  // mm/h
    public let precipitationChance: Double     // 0-1

    // Metadata
    public let timestamp: Date
    public let location: CLLocationCoordinate2D

    public enum PressureTrend: String, Codable, Sendable {
        case rising, falling, steady, unknown
    }

    public enum WeatherCondition: String, Codable, Sendable {
        case clear, partlyCloudy, cloudy, overcast
        case rain, drizzle, heavyRain, thunderstorm
        case snow, sleet, hail, freezingRain
        case fog, mist, haze, smoky
        case windy, blustery
        case hot, cold
        case unknown
    }

    // MARK: - Derived Bio-Reactive Parameters

    /// Normalized pressure for audio modulation (0-1, centered at 1013 hPa)
    public var normalizedPressure: Double {
        // Normal range: 980-1040 hPa, centered at 1013
        let minPressure: Double = 980
        let maxPressure: Double = 1040
        return (pressure - minPressure) / (maxPressure - minPressure)
    }

    /// Weather "energy" level for modulation (0-1)
    public var energyLevel: Double {
        var energy = 0.5

        // Wind adds energy
        energy += min(windSpeed / 20.0, 0.3)

        // Storms add energy
        if condition == .thunderstorm { energy += 0.3 }
        if condition == .heavyRain { energy += 0.15 }

        // Clear sunny weather adds positive energy
        if condition == .clear && isDaylight { energy += 0.2 }

        // Fog/mist reduces energy
        if condition == .fog || condition == .mist { energy -= 0.2 }

        return max(0, min(1, energy))
    }

    /// Weather "calmness" level (inverse of energy)
    public var calmnessLevel: Double {
        return 1.0 - energyLevel
    }

    /// Mood suggestion based on weather
    public var suggestedMood: String {
        switch condition {
        case .clear where isDaylight: return "uplifting"
        case .clear: return "peaceful"
        case .partlyCloudy: return "contemplative"
        case .cloudy, .overcast: return "introspective"
        case .rain, .drizzle: return "melancholic"
        case .heavyRain, .thunderstorm: return "dramatic"
        case .snow: return "ethereal"
        case .fog, .mist: return "mysterious"
        default: return "neutral"
        }
    }
}

// MARK: - Rate Limiting Configuration

/// Configuration for staying within free tier limits
public struct WeatherKitRateLimitConfig {
    /// Maximum calls per month (free tier = 500,000)
    public let monthlyLimit: Int

    /// Minimum cache duration in seconds
    public let minimumCacheDuration: TimeInterval

    /// Warning threshold (percentage of monthly limit)
    public let warningThreshold: Double

    /// Critical threshold - stop making calls
    public let criticalThreshold: Double

    /// Minimum location change to trigger refresh (meters)
    public let minimumLocationChange: Double

    public static let freeTier = WeatherKitRateLimitConfig(
        monthlyLimit: 500_000,
        minimumCacheDuration: 30 * 60,      // 30 minutes minimum
        warningThreshold: 0.8,               // Warn at 80%
        criticalThreshold: 0.95,             // Stop at 95%
        minimumLocationChange: 5000          // 5km minimum move
    )

    public static let conservative = WeatherKitRateLimitConfig(
        monthlyLimit: 500_000,
        minimumCacheDuration: 60 * 60,      // 1 hour minimum
        warningThreshold: 0.7,
        criticalThreshold: 0.9,
        minimumLocationChange: 10000         // 10km minimum move
    )

    public static let ultraConservative = WeatherKitRateLimitConfig(
        monthlyLimit: 500_000,
        minimumCacheDuration: 2 * 60 * 60,  // 2 hours minimum
        warningThreshold: 0.5,
        criticalThreshold: 0.8,
        minimumLocationChange: 20000         // 20km minimum move
    )
}

// MARK: - Usage Statistics

/// Tracks API usage to prevent exceeding limits
public struct WeatherKitUsageStats: Codable {
    public var monthlyCallCount: Int
    public var lastResetDate: Date
    public var lastCallDate: Date?
    public var callHistory: [Date]  // Last 100 calls for debugging

    public init() {
        self.monthlyCallCount = 0
        self.lastResetDate = Date()
        self.lastCallDate = nil
        self.callHistory = []
    }

    public var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    public var resetMonth: Int {
        Calendar.current.component(.month, from: lastResetDate)
    }

    public var needsMonthlyReset: Bool {
        return currentMonth != resetMonth
    }

    public mutating func resetIfNeeded() {
        if needsMonthlyReset {
            monthlyCallCount = 0
            lastResetDate = Date()
            callHistory = []
        }
    }

    public mutating func recordCall() {
        monthlyCallCount += 1
        lastCallDate = Date()
        callHistory.append(Date())

        // Keep only last 100 calls
        if callHistory.count > 100 {
            callHistory = Array(callHistory.suffix(100))
        }
    }

    public func usagePercentage(limit: Int) -> Double {
        return Double(monthlyCallCount) / Double(limit)
    }
}

// MARK: - WeatherKit Manager

/// Main manager for WeatherKit integration with smart caching and rate limiting
@MainActor
public final class WeatherKitManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = WeatherKitManager()

    // MARK: - Published Properties

    @Published public private(set) var currentWeather: EchoelWeatherData?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: Error?
    @Published public private(set) var usageStats: WeatherKitUsageStats
    @Published public private(set) var isRateLimited: Bool = false

    // MARK: - Configuration

    public var config: WeatherKitRateLimitConfig {
        didSet { saveConfiguration() }
    }

    // MARK: - Private Properties

    #if canImport(WeatherKit)
    private let weatherService = WeatherService.shared
    #endif

    private var cachedWeather: EchoelWeatherData?
    private var cacheTimestamp: Date?
    private var lastLocation: CLLocationCoordinate2D?

    private let userDefaults = UserDefaults.standard
    private let statsKey = "echoelmusic.weatherkit.usage"
    private let configKey = "echoelmusic.weatherkit.config"
    private let cacheKey = "echoelmusic.weatherkit.cache"

    // MARK: - Callbacks

    public var onWeatherUpdate: ((EchoelWeatherData) -> Void)?
    public var onRateLimitWarning: ((Double) -> Void)?

    // MARK: - Initialization

    private init() {
        self.config = .conservative  // Default to conservative
        self.usageStats = WeatherKitUsageStats()

        loadPersistedData()
        checkRateLimitStatus()
    }

    // MARK: - Public API

    /// Fetch weather for current location with smart caching
    public func fetchWeather(for location: CLLocationCoordinate2D, force: Bool = false) async throws -> EchoelWeatherData {
        // Check if we should use cache
        if !force, let cached = getCachedWeatherIfValid(for: location) {
            return cached
        }

        // Check rate limits
        guard canMakeAPICall() else {
            isRateLimited = true
            if let cached = cachedWeather {
                return cached  // Return stale cache if available
            }
            throw WeatherKitError.rateLimitExceeded
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let weather = try await fetchFromAPI(location: location)

            // Update cache and stats
            cacheWeather(weather, for: location)
            recordAPICall()

            // Notify listeners
            onWeatherUpdate?(weather)

            return weather
        } catch {
            lastError = error
            throw error
        }
    }

    /// Get current weather without making API call (cache only)
    public func getCachedWeather() -> EchoelWeatherData? {
        return cachedWeather
    }

    /// Check if weather data is available and fresh
    public var hasValidWeather: Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < config.minimumCacheDuration
    }

    /// Remaining API calls this month
    public var remainingCalls: Int {
        usageStats.resetIfNeeded()
        return max(0, config.monthlyLimit - usageStats.monthlyCallCount)
    }

    /// Usage percentage (0-1)
    public var usagePercentage: Double {
        usageStats.resetIfNeeded()
        return usageStats.usagePercentage(limit: config.monthlyLimit)
    }

    /// Estimated calls per day based on current usage
    public var estimatedDailyUsage: Int {
        guard let firstCall = usageStats.callHistory.first else { return 0 }
        let daysSinceFirstCall = max(1, Calendar.current.dateComponents([.day], from: firstCall, to: Date()).day ?? 1)
        return usageStats.monthlyCallCount / daysSinceFirstCall
    }

    /// Days remaining at current usage rate
    public var daysUntilLimitAtCurrentRate: Int? {
        guard estimatedDailyUsage > 0 else { return nil }
        return remainingCalls / estimatedDailyUsage
    }

    // MARK: - Configuration

    public func setConservativeMode(_ conservative: Bool) {
        config = conservative ? .ultraConservative : .conservative
    }

    public func setCustomCacheDuration(_ duration: TimeInterval) {
        var newConfig = config
        config = WeatherKitRateLimitConfig(
            monthlyLimit: newConfig.monthlyLimit,
            minimumCacheDuration: max(duration, 15 * 60),  // Minimum 15 min
            warningThreshold: newConfig.warningThreshold,
            criticalThreshold: newConfig.criticalThreshold,
            minimumLocationChange: newConfig.minimumLocationChange
        )
    }

    // MARK: - Private Methods

    private func getCachedWeatherIfValid(for location: CLLocationCoordinate2D) -> EchoelWeatherData? {
        guard let cached = cachedWeather,
              let timestamp = cacheTimestamp,
              let lastLoc = lastLocation else {
            return nil
        }

        // Check cache age
        let cacheAge = Date().timeIntervalSince(timestamp)
        if cacheAge > config.minimumCacheDuration {
            return nil
        }

        // Check location change
        let distance = Self.distance(from: lastLoc, to: location)
        if distance > config.minimumLocationChange {
            return nil
        }

        return cached
    }

    private func canMakeAPICall() -> Bool {
        usageStats.resetIfNeeded()

        let usage = usageStats.usagePercentage(limit: config.monthlyLimit)

        // Check critical threshold
        if usage >= config.criticalThreshold {
            return false
        }

        // Warn if approaching limit
        if usage >= config.warningThreshold {
            onRateLimitWarning?(usage)
        }

        return true
    }

    private func fetchFromAPI(location: CLLocationCoordinate2D) async throws -> EchoelWeatherData {
        #if canImport(WeatherKit)
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let weather = try await weatherService.weather(for: clLocation)

        return EchoelWeatherData(
            temperature: weather.currentWeather.temperature.value,
            apparentTemperature: weather.currentWeather.apparentTemperature.value,
            humidity: weather.currentWeather.humidity,
            pressure: weather.currentWeather.pressure.value,
            pressureTrend: mapPressureTrend(weather.currentWeather.pressureTrend),
            windSpeed: weather.currentWeather.wind.speed.value,
            windGust: weather.currentWeather.wind.gust?.value,
            windDirection: weather.currentWeather.wind.direction.value,
            uvIndex: weather.currentWeather.uvIndex.value,
            cloudCover: weather.currentWeather.cloudCover,
            visibility: weather.currentWeather.visibility.value,
            condition: mapCondition(weather.currentWeather.condition),
            isDaylight: weather.currentWeather.isDaylight,
            precipitationIntensity: weather.currentWeather.precipitationIntensity?.value ?? 0,
            precipitationChance: weather.dailyForecast.first?.precipitationChance ?? 0,
            timestamp: Date(),
            location: location
        )
        #else
        // Fallback for platforms without WeatherKit
        throw WeatherKitError.notAvailable
        #endif
    }

    #if canImport(WeatherKit)
    private func mapPressureTrend(_ trend: PressureTrend) -> EchoelWeatherData.PressureTrend {
        switch trend {
        case .rising: return .rising
        case .falling: return .falling
        case .steady: return .steady
        @unknown default: return .unknown
        }
    }

    private func mapCondition(_ condition: WeatherCondition) -> EchoelWeatherData.WeatherCondition {
        switch condition {
        case .clear: return .clear
        case .partlyCloudy, .mostlyClear: return .partlyCloudy
        case .cloudy, .mostlyCloudy: return .cloudy
        case .rain: return .rain
        case .drizzle: return .drizzle
        case .heavyRain: return .heavyRain
        case .thunderstorms, .tropicalStorm, .hurricane: return .thunderstorm
        case .snow, .flurries, .heavySnow, .blizzard: return .snow
        case .sleet: return .sleet
        case .hail: return .hail
        case .freezingRain, .freezingDrizzle: return .freezingRain
        case .foggy: return .fog
        case .haze: return .haze
        case .smoky: return .smoky
        case .windy, .breezy: return .windy
        case .hot: return .hot
        case .frigid: return .cold
        default: return .unknown
        }
    }
    #endif

    private func cacheWeather(_ weather: EchoelWeatherData, for location: CLLocationCoordinate2D) {
        cachedWeather = weather
        cacheTimestamp = Date()
        lastLocation = location
        currentWeather = weather

        saveCache()
    }

    private func recordAPICall() {
        usageStats.resetIfNeeded()
        usageStats.recordCall()
        saveUsageStats()
        checkRateLimitStatus()
    }

    private func checkRateLimitStatus() {
        let usage = usageStats.usagePercentage(limit: config.monthlyLimit)
        isRateLimited = usage >= config.criticalThreshold
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        // Load usage stats
        if let data = userDefaults.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode(WeatherKitUsageStats.self, from: data) {
            usageStats = stats
            usageStats.resetIfNeeded()
        }

        // Load cached weather
        if let data = userDefaults.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode(CachedWeatherData.self, from: data) {
            cachedWeather = cache.weather
            cacheTimestamp = cache.timestamp
            lastLocation = cache.location
            currentWeather = cache.weather
        }
    }

    private func saveUsageStats() {
        if let data = try? JSONEncoder().encode(usageStats) {
            userDefaults.set(data, forKey: statsKey)
        }
    }

    private func saveConfiguration() {
        // Configuration is value type, save relevant parts
        userDefaults.set(config.minimumCacheDuration, forKey: "\(configKey).cacheDuration")
    }

    private func saveCache() {
        guard let weather = cachedWeather,
              let timestamp = cacheTimestamp,
              let location = lastLocation else { return }

        let cache = CachedWeatherData(weather: weather, timestamp: timestamp, location: location)
        if let data = try? JSONEncoder().encode(cache) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Helpers

    private static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Cache Data Structure

private struct CachedWeatherData: Codable {
    let weather: EchoelWeatherData
    let timestamp: Date
    let location: CLLocationCoordinate2D
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

// MARK: - Errors

public enum WeatherKitError: Error, LocalizedError {
    case rateLimitExceeded
    case notAvailable
    case locationNotAvailable
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "Weather API rate limit exceeded. Using cached data."
        case .notAvailable:
            return "WeatherKit is not available on this platform."
        case .locationNotAvailable:
            return "Location services not available."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Usage Monitor View Model

/// View model for displaying usage statistics
@MainActor
public class WeatherKitUsageMonitor: ObservableObject {
    @Published public var callsThisMonth: Int = 0
    @Published public var remainingCalls: Int = 500_000
    @Published public var usagePercentage: Double = 0
    @Published public var estimatedDailyUsage: Int = 0
    @Published public var daysUntilLimit: Int?
    @Published public var isWarning: Bool = false
    @Published public var isCritical: Bool = false

    private let manager = WeatherKitManager.shared

    public init() {
        refresh()
    }

    public func refresh() {
        callsThisMonth = manager.usageStats.monthlyCallCount
        remainingCalls = manager.remainingCalls
        usagePercentage = manager.usagePercentage
        estimatedDailyUsage = manager.estimatedDailyUsage
        daysUntilLimit = manager.daysUntilLimitAtCurrentRate
        isWarning = usagePercentage >= manager.config.warningThreshold
        isCritical = usagePercentage >= manager.config.criticalThreshold
    }
}
