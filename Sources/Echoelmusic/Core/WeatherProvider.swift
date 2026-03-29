#if canImport(CoreLocation)
import Foundation
import CoreLocation

// MARK: - Weather Types

enum WeatherCondition: String, Sendable {
    case clear, cloudy, rain, snow, storm, fog, wind
}

struct WeatherSnapshot: Sendable {
    /// Normalized 0-1 (0 = freezing, 1 = hot)
    var temperature: Double = 0.5
    var condition: WeatherCondition = .clear
    /// Normalized 0-1
    var windSpeed: Double = 0.0
    /// Normalized 0-1
    var humidity: Double = 0.5
}

// MARK: - Weather Provider

/// Weather context for soundscape modulation.
/// Uses time-based approximation. WeatherKit can be enabled when entitlement is configured.
@MainActor @Observable
final class WeatherProvider: NSObject, CLLocationManagerDelegate {

    var current: WeatherSnapshot = .init()

    private let locationManager = CLLocationManager()
    private var lastUpdate: Date = .distantPast
    private let updateInterval: TimeInterval = 600

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func startUpdating() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        // Apply initial time-based weather
        applyTimeBasedFallback()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard Date().timeIntervalSince(lastUpdate) > updateInterval else { return }
            lastUpdate = Date()
            // WeatherKit disabled — using time-based approximation
            // Enable fetchWeatherKit() when WeatherKit entitlement is configured
            applyTimeBasedFallback()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            applyTimeBasedFallback()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted:
                applyTimeBasedFallback()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            default:
                break
            }
        }
    }

    /// Time-based weather approximation
    private func applyTimeBasedFallback() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Temperature curve: coolest at 5am, warmest at 3pm
        let tempCurve = sin(Double(hour - 5) / 24.0 * .pi * 2) * 0.3 + 0.5
        current = WeatherSnapshot(
            temperature: tempCurve.clamped(to: 0...1),
            condition: .clear,
            windSpeed: 0.05,
            humidity: 0.5
        )
    }

    // MARK: - WeatherKit (Enable when entitlement is ready)
    // To enable: add WeatherKit capability in Xcode, then uncomment below
    // and call fetchWeatherKit(for:) instead of applyTimeBasedFallback()
    //
    // private func fetchWeatherKit(for location: CLLocation) async {
    //     Add WeatherKit framework import
    //     let weather = try await WeatherService.shared.weather(for: location)
    //     ...
    // }
}
#endif
