#if canImport(SwiftData)
import Foundation
import SwiftData

/// A recorded soundscape session with bio metrics summary.
@Model
final class SoundscapeSession {
    var startDate: Date
    var endDate: Date?
    var durationSeconds: Int

    // Bio averages
    var avgHeartRate: Double
    var avgHRV: Double
    var avgCoherence: Double
    var peakCoherence: Double

    // Context
    var primarySource: String
    var circadianPhase: String
    var weatherCondition: String

    init(
        startDate: Date = Date(),
        endDate: Date? = nil,
        durationSeconds: Int = 0,
        avgHeartRate: Double = 0,
        avgHRV: Double = 0,
        avgCoherence: Double = 0,
        peakCoherence: Double = 0,
        primarySource: String = "Simulated",
        circadianPhase: String = "active",
        weatherCondition: String = "clear"
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.avgHeartRate = avgHeartRate
        self.avgHRV = avgHRV
        self.avgCoherence = avgCoherence
        self.peakCoherence = peakCoherence
        self.primarySource = primarySource
        self.circadianPhase = circadianPhase
        self.weatherCondition = weatherCondition
    }
}

/// Tracks an active session and saves it on completion.
@MainActor @Observable
final class SessionTracker {

    var isActive: Bool = false
    var currentDuration: Int = 0

    private var startDate: Date?
    private var heartRates: [Double] = []
    private var hrvValues: [Double] = []
    private var coherenceValues: [Double] = []
    private var timer: Timer?

    func start(source: BioDataSource, phase: CircadianPhase, weather: WeatherCondition) {
        startDate = Date()
        heartRates = []
        hrvValues = []
        coherenceValues = []
        currentDuration = 0
        isActive = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentDuration += 1
            }
        }
    }

    /// Record a bio sample (call at ~1Hz from update loop)
    func recordSample(hr: Double, hrv: Double, coherence: Double) {
        guard isActive else { return }
        heartRates.append(hr)
        hrvValues.append(hrv)
        coherenceValues.append(coherence)
    }

    /// Stop and return the completed session
    func stop(source: BioDataSource, phase: CircadianPhase, weather: WeatherCondition) -> SoundscapeSession? {
        guard isActive, let start = startDate else { return nil }
        timer?.invalidate()
        timer = nil
        isActive = false

        let now = Date()
        let duration = Int(now.timeIntervalSince(start))
        guard duration >= 10 else { return nil } // Don't save sessions < 10s

        let avgHR = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)
        let avgHRV = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let avgCoh = coherenceValues.isEmpty ? 0 : coherenceValues.reduce(0, +) / Double(coherenceValues.count)
        let peakCoh = coherenceValues.max() ?? 0

        return SoundscapeSession(
            startDate: start,
            endDate: now,
            durationSeconds: duration,
            avgHeartRate: avgHR,
            avgHRV: avgHRV,
            avgCoherence: avgCoh,
            peakCoherence: peakCoh,
            primarySource: source.rawValue,
            circadianPhase: phase.rawValue,
            weatherCondition: weather.rawValue
        )
    }
}
#endif
