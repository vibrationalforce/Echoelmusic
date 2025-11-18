// EchoelRing.swift
// Oura Ring Integration for Sleep, Recovery & Wellness Data
// API: Oura Cloud API v2 (OAuth 2.0)
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

import Foundation
import Combine

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Oura sleep data structure
public struct OuraSleepData: Codable {
    // Sleep Stages (from accelerometer + heart rate + temperature)
    public var deepSleepMinutes: Int = 0           // Restorative sleep
    public var remSleepMinutes: Int = 0            // Dream & learning consolidation
    public var lightSleepMinutes: Int = 0          // Transition phases
    public var awakeMinutes: Int = 0               // Interruptions

    // Sleep Quality
    public var sleepScore: Float = 0               // 0-100 (Oura algorithm)
    public var sleepEfficiency: Float = 0          // % of time in bed asleep
    public var sleepLatency: Int = 0               // Minutes to fall asleep
    public var restlessPeriods: Int = 0            // Movement count

    // Timing
    public var bedtimeStart: String = ""           // ISO 8601 timestamp
    public var bedtimeEnd: String = ""             // Wake time
    public var totalSleepDuration: Int = 0         // Minutes

    // HRV During Sleep
    public var nightlyHRV: Float = 0               // Average RMSSD (ms)
    public var lowestRestingHR: Float = 0          // BPM (parasympathetic tone)

    public init() {}
}

/// Oura readiness data structure
public struct OuraReadinessData: Codable {
    public var readinessScore: Float = 0           // 0-100 (recovery level)
    public var previousDayActivity: Float = 0      // Recovery debt from exercise
    public var sleepBalance: Float = 0             // Sleep debt/surplus
    public var bodyTemperature: Float = 0          // °C deviation from baseline
    public var hrvBalance: Float = 0               // HRV trend (improving/declining)
    public var restingHeartRate: Float = 0         // BPM (lower = better recovery)
    public var recoveryIndex: Float = 0            // Overall parasympathetic tone

    public init() {}
}

/// Oura activity data structure
public struct OuraActivityData: Codable {
    public var steps: Int = 0                      // Daily step count
    public var caloriesBurned: Float = 0           // Active calories
    public var activeMinutes: Int = 0              // Movement time
    public var inactivityAlerts: Int = 0           // Sedentary periods
    public var metMinutesHigh: Float = 0           // High-intensity minutes
    public var metMinutesMedium: Float = 0         // Medium-intensity minutes

    public init() {}
}

/// Oura heart rate monitoring data
public struct OuraHeartRateData: Codable {
    public var currentHR: Float = 0                // Real-time BPM
    public var restingHR: Float = 0                // Daily resting HR
    public var hrvRMSSD: Float = 0                 // Current HRV (ms)
    public var timestamp: UInt64 = 0               // μs since epoch

    public init() {}
}

/// Circadian rhythm phase
public enum CircadianPhase {
    case morning        // 0-4 hours since wake
    case midday         // 4-8 hours since wake
    case afternoon      // 8-12 hours since wake
    case evening        // 12-16 hours since wake
    case night          // 16+ hours since wake

    var description: String {
        switch self {
        case .morning: return "Morning - Peak Alertness"
        case .midday: return "Midday - Focus Window"
        case .afternoon: return "Afternoon - Creative Peak"
        case .evening: return "Evening - Social Peak"
        case .night: return "Night - Recovery Time"
        }
    }
}

/// Oura Ring API client
public class EchoelRingAPI {

    // MARK: - Properties

    private let baseURL = "https://api.ouraring.com/v2/usercollection"
    private var accessToken: String = ""

    private let session: URLSession

    // MARK: - Initialization

    public init(accessToken: String) {
        self.accessToken = accessToken

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Requests

    /// Fetch sleep data for a specific date
    public func fetchSleepData(date: String, completion: @escaping (Result<OuraSleepData, Error>) -> Void) {
        let endpoint = "\(baseURL)/sleep?start_date=\(date)&end_date=\(date)"

        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "EchoelRing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "EchoelRing", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let sleepData = self.parseSleepData(from: json)
                completion(.success(sleepData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Fetch readiness score for a specific date
    public func fetchReadinessData(date: String, completion: @escaping (Result<OuraReadinessData, Error>) -> Void) {
        let endpoint = "\(baseURL)/daily_readiness?start_date=\(date)&end_date=\(date)"

        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "EchoelRing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "EchoelRing", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let readinessData = self.parseReadinessData(from: json)
                completion(.success(readinessData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Fetch activity data for a specific date
    public func fetchActivityData(date: String, completion: @escaping (Result<OuraActivityData, Error>) -> Void) {
        let endpoint = "\(baseURL)/daily_activity?start_date=\(date)&end_date=\(date)"

        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "EchoelRing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "EchoelRing", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let activityData = self.parseActivityData(from: json)
                completion(.success(activityData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Parsing

    private func parseSleepData(from json: [String: Any]?) -> OuraSleepData {
        var data = OuraSleepData()

        guard let json = json, let dataArray = json["data"] as? [[String: Any]], let firstItem = dataArray.first else {
            return data
        }

        data.deepSleepMinutes = (firstItem["deep_sleep_duration"] as? Int ?? 0) / 60
        data.remSleepMinutes = (firstItem["rem_sleep_duration"] as? Int ?? 0) / 60
        data.lightSleepMinutes = (firstItem["light_sleep_duration"] as? Int ?? 0) / 60
        data.awakeMinutes = (firstItem["awake_time"] as? Int ?? 0) / 60

        data.sleepScore = firstItem["score"] as? Float ?? 0
        data.sleepEfficiency = firstItem["efficiency"] as? Float ?? 0
        data.sleepLatency = (firstItem["latency"] as? Int ?? 0) / 60
        data.restlessPeriods = firstItem["restless_periods"] as? Int ?? 0

        data.bedtimeStart = firstItem["bedtime_start"] as? String ?? ""
        data.bedtimeEnd = firstItem["bedtime_end"] as? String ?? ""
        data.totalSleepDuration = (firstItem["total_sleep_duration"] as? Int ?? 0) / 60

        if let hrv = firstItem["heart_rate"] as? [String: Any] {
            data.nightlyHRV = hrv["average_hrv"] as? Float ?? 0
            data.lowestRestingHR = hrv["lowest"] as? Float ?? 0
        }

        return data
    }

    private func parseReadinessData(from json: [String: Any]?) -> OuraReadinessData {
        var data = OuraReadinessData()

        guard let json = json, let dataArray = json["data"] as? [[String: Any]], let firstItem = dataArray.first else {
            return data
        }

        data.readinessScore = firstItem["score"] as? Float ?? 0

        if let contributors = firstItem["contributors"] as? [String: Any] {
            data.previousDayActivity = contributors["activity_balance"] as? Float ?? 0
            data.sleepBalance = contributors["sleep_balance"] as? Float ?? 0
            data.bodyTemperature = contributors["body_temperature"] as? Float ?? 0
            data.hrvBalance = contributors["hrv_balance"] as? Float ?? 0
            data.restingHeartRate = contributors["resting_heart_rate"] as? Float ?? 0
            data.recoveryIndex = contributors["recovery_index"] as? Float ?? 0
        }

        return data
    }

    private func parseActivityData(from json: [String: Any]?) -> OuraActivityData {
        var data = OuraActivityData()

        guard let json = json, let dataArray = json["data"] as? [[String: Any]], let firstItem = dataArray.first else {
            return data
        }

        data.steps = firstItem["steps"] as? Int ?? 0
        data.caloriesBurned = firstItem["active_calories"] as? Float ?? 0
        data.activeMinutes = (firstItem["active_time"] as? Int ?? 0) / 60
        data.inactivityAlerts = firstItem["inactivity_alerts"] as? Int ?? 0
        data.metMinutesHigh = firstItem["high_activity_met_minutes"] as? Float ?? 0
        data.metMinutesMedium = firstItem["medium_activity_met_minutes"] as? Float ?? 0

        return data
    }
}

/// Circadian rhythm optimizer based on Oura data
public class CircadianEngine {

    private var sleepData: OuraSleepData?
    private var readinessData: OuraReadinessData?

    // MARK: - Circadian Phase Detection

    /// Get current circadian phase based on wake time
    public func getCurrentCircadianPhase() -> CircadianPhase {
        guard let sleepData = sleepData else { return .midday }

        let now = Date()
        let formatter = ISO8601DateFormatter()

        guard let wakeTime = formatter.date(from: sleepData.bedtimeEnd) else { return .midday }

        let hoursSinceWake = now.timeIntervalSince(wakeTime) / 3600.0

        switch hoursSinceWake {
        case 0..<4: return .morning
        case 4..<8: return .midday
        case 8..<12: return .afternoon
        case 12..<16: return .evening
        default: return .night
        }
    }

    /// Get optimal creativity window (REM-influenced)
    public func getOptimalCreativityWindow() -> (start: Date, end: Date)? {
        guard let sleepData = sleepData else { return nil }

        let formatter = ISO8601DateFormatter()
        guard let wakeTime = formatter.date(from: sleepData.bedtimeEnd) else { return nil }

        // Peak creativity: 4-8 hours after waking (post-cortisol surge)
        let start = wakeTime.addingTimeInterval(4 * 3600)
        let end = wakeTime.addingTimeInterval(8 * 3600)

        return (start, end)
    }

    /// Get optimal focus window (peak alertness)
    public func getOptimalFocusWindow() -> (start: Date, end: Date)? {
        guard let sleepData = sleepData else { return nil }

        let formatter = ISO8601DateFormatter()
        guard let wakeTime = formatter.date(from: sleepData.bedtimeEnd) else { return nil }

        // Peak focus: 2-4 hours after waking (cortisol peak)
        let start = wakeTime.addingTimeInterval(2 * 3600)
        let end = wakeTime.addingTimeInterval(4 * 3600)

        return (start, end)
    }

    /// Get optimal recovery window (rest recommendation)
    public func getOptimalRecoveryWindow() -> (start: Date, end: Date)? {
        guard let sleepData = sleepData else { return nil }

        let formatter = ISO8601DateFormatter()
        guard let wakeTime = formatter.date(from: sleepData.bedtimeEnd) else { return nil }

        // Optimal rest: 14-16 hours after waking
        let start = wakeTime.addingTimeInterval(14 * 3600)
        let end = wakeTime.addingTimeInterval(16 * 3600)

        return (start, end)
    }

    // MARK: - Audio Adaptation

    /// Adjust audio parameters based on circadian phase
    public func getAudioParametersForCircadianPhase() -> [String: Float] {
        let phase = getCurrentCircadianPhase()

        switch phase {
        case .morning:
            // Energizing, bright tones
            return [
                "filter_brightness": 0.8,      // Bright
                "tempo_multiplier": 1.1,       // Slightly faster
                "reverb_size": 0.3,            // Tight
                "harmonic_content": 0.7,       // Rich
            ]

        case .midday:
            // Focused, clear mix
            return [
                "filter_brightness": 0.6,      // Clear
                "tempo_multiplier": 1.0,       // Normal
                "reverb_size": 0.4,            // Medium
                "harmonic_content": 0.5,       // Balanced
            ]

        case .afternoon:
            // Creative, experimental
            return [
                "filter_brightness": 0.5,      // Warm
                "tempo_multiplier": 0.95,      // Slightly slower
                "reverb_size": 0.6,            // Spacious
                "harmonic_content": 0.8,       // Very rich
            ]

        case .evening:
            // Relaxing, warm tones
            return [
                "filter_brightness": 0.4,      // Warm
                "tempo_multiplier": 0.85,      // Slower
                "reverb_size": 0.7,            // Large
                "harmonic_content": 0.4,       // Softer
            ]

        case .night:
            // Minimal, dark ambient
            return [
                "filter_brightness": 0.2,      // Dark
                "tempo_multiplier": 0.7,       // Much slower
                "reverb_size": 0.9,            // Vast
                "harmonic_content": 0.2,       // Minimal
            ]
        }
    }

    /// Update sleep and readiness data
    public func updateData(sleep: OuraSleepData, readiness: OuraReadinessData) {
        self.sleepData = sleep
        self.readinessData = readiness
    }
}

/// EchoelRing Manager - Main interface
public class EchoelRingManager {

    public static let shared = EchoelRingManager()

    private var api: EchoelRingAPI?
    private var circadianEngine = CircadianEngine()

    private var sleepPublisher = PassthroughSubject<OuraSleepData, Never>()
    private var readinessPublisher = PassthroughSubject<OuraReadinessData, Never>()
    private var activityPublisher = PassthroughSubject<OuraActivityData, Never>()

    private init() {}

    /// Configure with Oura API access token
    public func configure(accessToken: String) {
        self.api = EchoelRingAPI(accessToken: accessToken)
        print("[EchoelRing] Configured with access token")
    }

    /// Fetch today's wellness data
    public func fetchTodaysData() {
        guard let api = api else {
            print("[EchoelRing] Not configured - call configure(accessToken:) first")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        // Fetch sleep data
        api.fetchSleepData(date: today) { [weak self] result in
            switch result {
            case .success(let sleepData):
                self?.sleepPublisher.send(sleepData)
                print("[EchoelRing] Sleep score: \(sleepData.sleepScore)")

                // Update circadian engine
                if let readiness = self?.circadianEngine.readinessData {
                    self?.circadianEngine.updateData(sleep: sleepData, readiness: readiness)
                }

            case .failure(let error):
                print("[EchoelRing] Failed to fetch sleep data: \(error.localizedDescription)")
            }
        }

        // Fetch readiness data
        api.fetchReadinessData(date: today) { [weak self] result in
            switch result {
            case .success(let readinessData):
                self?.readinessPublisher.send(readinessData)
                print("[EchoelRing] Readiness score: \(readinessData.readinessScore)")

                // Update circadian engine
                if let sleep = self?.circadianEngine.sleepData {
                    self?.circadianEngine.updateData(sleep: sleep, readiness: readinessData)
                }

            case .failure(let error):
                print("[EchoelRing] Failed to fetch readiness data: \(error.localizedDescription)")
            }
        }

        // Fetch activity data
        api.fetchActivityData(date: today) { [weak self] result in
            switch result {
            case .success(let activityData):
                self?.activityPublisher.send(activityData)
                print("[EchoelRing] Steps: \(activityData.steps)")

            case .failure(let error):
                print("[EchoelRing] Failed to fetch activity data: \(error.localizedDescription)")
            }
        }
    }

    /// Subscribe to sleep data updates
    public func subscribeToSleepData() -> AnyPublisher<OuraSleepData, Never> {
        return sleepPublisher.eraseToAnyPublisher()
    }

    /// Subscribe to readiness data updates
    public func subscribeToReadinessData() -> AnyPublisher<OuraReadinessData, Never> {
        return readinessPublisher.eraseToAnyPublisher()
    }

    /// Subscribe to activity data updates
    public func subscribeToActivityData() -> AnyPublisher<OuraActivityData, Never> {
        return activityPublisher.eraseToAnyPublisher()
    }

    /// Get current circadian phase
    public func getCurrentCircadianPhase() -> CircadianPhase {
        return circadianEngine.getCurrentCircadianPhase()
    }

    /// Get audio parameters optimized for current circadian phase
    public func getCircadianAudioParameters() -> [String: Float] {
        return circadianEngine.getAudioParametersForCircadianPhase()
    }
}
