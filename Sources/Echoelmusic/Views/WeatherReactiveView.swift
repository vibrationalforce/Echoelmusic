// WeatherReactiveView.swift
// Echoelmusic
//
// SwiftUI view for weather-reactive controls and status display
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import SwiftUI
import CoreLocation

// MARK: - Main Weather View

@MainActor
public struct WeatherReactiveView: View {
    @StateObject private var weatherManager = WeatherKitManager.shared
    @StateObject private var weatherEngine = WeatherReactiveEngine.shared
    @StateObject private var usageMonitor = WeatherKitUsageMonitor()
    @StateObject private var locationManager = LocationManagerWrapper()

    @State private var showUsageDetails = false
    @State private var showPresetPicker = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            if weatherEngine.isEnabled {
                // Current Weather Card
                currentWeatherCard

                // Parameter Displays
                parameterSection

                // Preset Selection
                presetSection

                // Usage Stats (collapsible)
                usageSection
            } else {
                enablePrompt
            }
        }
        .padding()
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if let location = newLocation {
                Task {
                    await weatherEngine.updateWeather(for: location)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather Reactive")
                    .font(.headline)
                Text("Umwelt → Audio/Visual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { weatherEngine.isEnabled },
                set: { enabled in
                    if enabled {
                        weatherEngine.enable()
                    } else {
                        weatherEngine.disable()
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Current Weather Card

    private var currentWeatherCard: some View {
        GroupBox {
            if weatherManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let weather = weatherEngine.currentWeather {
                HStack(spacing: 16) {
                    // Weather Icon
                    weatherIcon(for: weather.condition)
                        .font(.system(size: 40))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.condition.rawValue.capitalized)
                            .font(.headline)
                        Text("\(Int(weather.temperature))°C • \(Int(weather.humidity * 100))% Luftfeuchtigkeit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Stimmung: \(weather.suggestedMood.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    // Energy indicator
                    VStack {
                        CircularProgressView(
                            progress: weather.energyLevel,
                            label: "Energie"
                        )
                        .frame(width: 50, height: 50)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("Keine Wetterdaten verfügbar")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        } label: {
            Label("Aktuelles Wetter", systemImage: "cloud.sun")
        }
    }

    // MARK: - Parameter Section

    private var parameterSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                // Audio Parameters
                ParameterRow(
                    icon: "waveform",
                    label: "Filter",
                    value: "\(Int(weatherEngine.audioParameters.filterCutoff)) Hz"
                )

                ParameterRow(
                    icon: "water.waves",
                    label: "Reverb",
                    value: "\(Int(weatherEngine.audioParameters.reverbMix * 100))%"
                )

                ParameterRow(
                    icon: "wind",
                    label: "Modulation",
                    value: "\(String(format: "%.1f", weatherEngine.audioParameters.modulationRate)) Hz"
                )

                ParameterRow(
                    icon: "thermometer",
                    label: "Wärme",
                    value: "\(Int(weatherEngine.audioParameters.warmth * 100))%"
                )

                Divider()

                ParameterRow(
                    icon: "metronome",
                    label: "Vorgeschl. BPM",
                    value: "\(Int(weatherEngine.audioParameters.suggestedBPM))"
                )
            }
        } label: {
            Label("Audio Parameter", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Text(weatherEngine.activePreset.name)
                        .font(.headline)
                    Spacer()
                    Button("Ändern") {
                        showPresetPicker = true
                    }
                    .buttonStyle(.bordered)
                }

                Text(weatherEngine.activePreset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Influence sliders
                HStack(spacing: 20) {
                    InfluenceIndicator(
                        label: "Audio",
                        value: weatherEngine.activePreset.audioInfluence
                    )
                    InfluenceIndicator(
                        label: "Visual",
                        value: weatherEngine.activePreset.visualInfluence
                    )
                    InfluenceIndicator(
                        label: "Licht",
                        value: weatherEngine.activePreset.lightingInfluence
                    )
                }
                .padding(.top, 4)
            }
        } label: {
            Label("Preset", systemImage: "square.stack.3d.up")
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                selectedPreset: $weatherEngine.activePreset,
                isPresented: $showPresetPicker
            )
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $showUsageDetails) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Calls diesen Monat:")
                        Spacer()
                        Text("\(usageMonitor.callsThisMonth)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Verbleibend:")
                        Spacer()
                        Text("\(usageMonitor.remainingCalls)")
                            .fontWeight(.medium)
                            .foregroundStyle(usageMonitor.isWarning ? .orange : .primary)
                    }

                    if let days = usageMonitor.daysUntilLimit {
                        HStack {
                            Text("Reichweite:")
                            Spacer()
                            Text("~\(days) Tage")
                                .fontWeight(.medium)
                        }
                    }

                    // Usage bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usageBarColor)
                                .frame(width: geo.size.width * usageMonitor.usagePercentage)
                        }
                    }
                    .frame(height: 8)

                    Text("Free Tier: 500.000 Calls/Monat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("API Nutzung")
                    Spacer()
                    Text("\(Int(usageMonitor.usagePercentage * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var usageBarColor: Color {
        if usageMonitor.isCritical { return .red }
        if usageMonitor.isWarning { return .orange }
        return .green
    }

    // MARK: - Enable Prompt

    private var enablePrompt: some View {
        GroupBox {
            VStack(spacing: 12) {
                Image(systemName: "cloud.sun.rain")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Wetter-Reaktive Musik")
                    .font(.headline)

                Text("Lass das Wetter deine Musik beeinflussen. Luftdruck, Wind, UV-Index und mehr werden zu Audio- und Visual-Parametern.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    weatherEngine.enable()
                    if let location = locationManager.location {
                        Task {
                            await weatherEngine.updateWeather(for: location)
                        }
                    }
                } label: {
                    Text("Aktivieren")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func weatherIcon(for condition: EchoelWeatherData.WeatherCondition) -> some View {
        let iconName: String
        switch condition {
        case .clear: iconName = "sun.max.fill"
        case .partlyCloudy: iconName = "cloud.sun.fill"
        case .cloudy: iconName = "cloud.fill"
        case .overcast: iconName = "smoke.fill"
        case .rain: iconName = "cloud.rain.fill"
        case .drizzle: iconName = "cloud.drizzle.fill"
        case .heavyRain: iconName = "cloud.heavyrain.fill"
        case .thunderstorm: iconName = "cloud.bolt.rain.fill"
        case .snow: iconName = "cloud.snow.fill"
        case .sleet, .hail: iconName = "cloud.sleet.fill"
        case .freezingRain: iconName = "thermometer.snowflake"
        case .fog, .mist: iconName = "cloud.fog.fill"
        case .haze, .smoky: iconName = "sun.haze.fill"
        case .windy, .blustery: iconName = "wind"
        case .hot: iconName = "thermometer.sun.fill"
        case .cold: iconName = "thermometer.snowflake"
        case .unknown: iconName = "questionmark.circle"
        }
        return Image(systemName: iconName)
            .symbolRenderingMode(.multicolor)
    }
}

// MARK: - Supporting Views

struct ParameterRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
        }
    }
}

struct InfluenceIndicator: View {
    let label: String
    let value: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(width: 36, height: 36)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }

    private var progressColor: Color {
        if progress > 0.7 { return .green }
        if progress > 0.4 { return .orange }
        return .blue
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @Binding var selectedPreset: WeatherReactivePreset
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(WeatherReactivePreset.allPresets) { preset in
                    Button {
                        selectedPreset = preset
                        Task { @MainActor in
                            WeatherReactiveEngine.shared.applyPreset(preset)
                        }
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 16) {
                                    Label("\(Int(preset.audioInfluence * 100))%", systemImage: "waveform")
                                    Label("\(Int(preset.visualInfluence * 100))%", systemImage: "eye")
                                    Label("\(Int(preset.lightingInfluence * 100))%", systemImage: "lightbulb")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if preset.id == selectedPreset.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Preset wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Location Manager Wrapper

@MainActor
class LocationManagerWrapper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // Low accuracy is fine for weather
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            location = locations.first?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Use a default location on error (Berlin as fallback)
        Task { @MainActor in
            location = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}

// MARK: - Compact Weather Widget

/// A compact version for embedding in other views
public struct WeatherReactiveCompactView: View {
    @StateObject private var weatherEngine = WeatherReactiveEngine.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            if let weather = weatherEngine.currentWeather {
                Image(systemName: iconName(for: weather.condition))
                    .symbolRenderingMode(.multicolor)

                Text("\(Int(weather.temperature))°")
                    .font(.caption)
                    .fontWeight(.medium)

                if weatherEngine.isEnabled {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            } else {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(.secondary)
                Text("--")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func iconName(for condition: EchoelWeatherData.WeatherCondition) -> String {
        switch condition {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .overcast: return "cloud.fill"
        case .rain, .drizzle, .heavyRain: return "cloud.rain.fill"
        case .thunderstorm: return "cloud.bolt.fill"
        case .snow: return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    WeatherReactiveView()
}
