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

/// Fetches weather data via WeatherKit. Falls back to neutral values if unavailable.
@MainActor @Observable
final class WeatherProvider: NSObject, CLLocationManagerDelegate {

    var current: WeatherSnapshot = .init()

    private let locationManager = CLLocationManager()
    private var lastUpdate: Date = .distantPast
    private let updateInterval: TimeInterval = 600 // 10 minutes

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func startUpdating() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard Date().timeIntervalSince(lastUpdate) > updateInterval else { return }
            lastUpdate = Date()
            await fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            applyTimeBasedFallback()
        }
        log.log(.warning, category: .system, "Weather location unavailable — using time-based fallback")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted:
                applyTimeBasedFallback()
                log.log(.info, category: .system, "Location denied — weather using time-based fallback")
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            default:
                break
            }
        }
    }

    /// Time-based weather approximation when location is unavailable
    private func applyTimeBasedFallback() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Simulate temperature curve: coolest at 5am, warmest at 15pm
        let tempCurve = sin(Double(hour - 5) / 24.0 * .pi * 2) * 0.3 + 0.5
        current = WeatherSnapshot(
            temperature: tempCurve.clamped(to: 0...1),
            condition: .clear,
            windSpeed: 0.05,
            humidity: 0.5
        )
    }

    private func fetchWeather(for location: CLLocation) async {
        #if canImport(WeatherKit)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let temp = weather.currentWeather.temperature.converted(to: .celsius).value
            // Normalize: -10°C = 0.0, 40°C = 1.0
            let normalizedTemp = ((temp + 10) / 50).clamped(to: 0...1)
            let normalizedWind = (weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value / 80).clamped(to: 0...1)
            let normalizedHumidity = weather.currentWeather.humidity

            let condition: WeatherCondition
            switch weather.currentWeather.condition {
            case .clear, .mostlyClear, .hot:
                condition = .clear
            case .cloudy, .mostlyCloudy, .partlyCloudy:
                condition = .cloudy
            case .rain, .drizzle, .heavyRain:
                condition = .rain
            case .snow, .heavySnow, .sleet, .freezingRain:
                condition = .snow
            case .thunderstorms, .tropicalStorm, .hurricane:
                condition = .storm
            case .foggy, .haze, .smoky:
                condition = .fog
            case .windy, .breezy:
                condition = .wind
            default:
                condition = .clear
            }

            current = WeatherSnapshot(
                temperature: normalizedTemp,
                condition: condition,
                windSpeed: normalizedWind,
                humidity: normalizedHumidity
            )
            log.log(.info, category: .system, "Weather updated: \(condition.rawValue), \(Int(temp))°C")
        } catch {
            log.log(.warning, category: .system, "WeatherKit error: \(error.localizedDescription)")
        }
        #endif
    }
}
#endif
