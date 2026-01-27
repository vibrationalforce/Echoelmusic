// WeatherReactiveEngine.swift
// Echoelmusic
//
// Maps weather data to audio and visual parameters
// Part of the bio-reactive + environmental awareness system
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import CoreLocation
import Combine

// MARK: - Weather Audio Parameters

/// Audio parameters derived from weather conditions
public struct WeatherAudioParameters: Sendable {
    // Filter
    public var filterCutoff: Float        // 200-20000 Hz
    public var filterResonance: Float     // 0-1
    public var filterType: FilterType

    // Reverb
    public var reverbMix: Float           // 0-1
    public var reverbDecay: Float         // 0.1-10 seconds
    public var reverbDamping: Float       // 0-1

    // Delay
    public var delayTime: Float           // 0-2 seconds
    public var delayFeedback: Float       // 0-0.9
    public var delayMix: Float            // 0-1

    // Modulation
    public var modulationRate: Float      // 0.1-20 Hz
    public var modulationDepth: Float     // 0-1
    public var chorusAmount: Float        // 0-1

    // Dynamics
    public var bassBoost: Float           // -6 to +6 dB
    public var brightness: Float          // -6 to +6 dB
    public var warmth: Float              // 0-1 (saturation)

    // Tempo suggestion
    public var suggestedBPM: Float        // 60-180

    public enum FilterType: String, Sendable {
        case lowPass, highPass, bandPass, notch
    }

    public static let neutral = WeatherAudioParameters(
        filterCutoff: 8000,
        filterResonance: 0.3,
        filterType: .lowPass,
        reverbMix: 0.3,
        reverbDecay: 2.0,
        reverbDamping: 0.5,
        delayTime: 0.25,
        delayFeedback: 0.3,
        delayMix: 0.2,
        modulationRate: 1.0,
        modulationDepth: 0.3,
        chorusAmount: 0.2,
        bassBoost: 0,
        brightness: 0,
        warmth: 0.5,
        suggestedBPM: 100
    )
}

// MARK: - Weather Visual Parameters

/// Visual parameters derived from weather conditions
public struct WeatherVisualParameters: Sendable {
    // Colors
    public var primaryHue: Float          // 0-360
    public var saturation: Float          // 0-1
    public var brightness: Float          // 0-1
    public var colorTemperature: Float    // 2000-10000K

    // Particles
    public var particleDensity: Float     // 0-1
    public var particleSpeed: Float       // 0-1
    public var particleSize: Float        // 0.5-2.0 multiplier
    public var particleType: ParticleType

    // Animation
    public var animationSpeed: Float      // 0.1-3.0 multiplier
    public var pulseIntensity: Float      // 0-1
    public var flowDirection: Float       // 0-360 degrees

    // Effects
    public var blurAmount: Float          // 0-20
    public var glowIntensity: Float       // 0-1
    public var noiseAmount: Float         // 0-1

    // Scene
    public var fogDensity: Float          // 0-1
    public var ambientLight: Float        // 0-1
    public var contrastLevel: Float       // 0.5-1.5

    public enum ParticleType: String, Sendable {
        case rain, snow, dust, leaves, sparkles, clouds, none
    }

    public static let neutral = WeatherVisualParameters(
        primaryHue: 200,
        saturation: 0.5,
        brightness: 0.7,
        colorTemperature: 6500,
        particleDensity: 0.3,
        particleSpeed: 0.5,
        particleSize: 1.0,
        particleType: .none,
        animationSpeed: 1.0,
        pulseIntensity: 0.5,
        flowDirection: 180,
        blurAmount: 0,
        glowIntensity: 0.3,
        noiseAmount: 0,
        fogDensity: 0,
        ambientLight: 0.7,
        contrastLevel: 1.0
    )
}

// MARK: - Weather Lighting Parameters

/// DMX/LED lighting parameters from weather
public struct WeatherLightingParameters: Sendable {
    public var masterIntensity: Float     // 0-1
    public var colorR: Float              // 0-1
    public var colorG: Float              // 0-1
    public var colorB: Float              // 0-1
    public var colorW: Float              // 0-1 (warm white)
    public var strobeRate: Float          // 0-20 Hz (0 = off)
    public var movementSpeed: Float       // 0-1 (for moving heads)
    public var goboPattern: Int           // 0-10

    public static let neutral = WeatherLightingParameters(
        masterIntensity: 0.7,
        colorR: 0.5,
        colorG: 0.5,
        colorB: 0.7,
        colorW: 0.3,
        strobeRate: 0,
        movementSpeed: 0.3,
        goboPattern: 0
    )
}

// MARK: - Weather Reactive Preset

/// A complete preset mapping weather to all parameters
public struct WeatherReactivePreset: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String

    // Mapping strengths (0-1)
    public var audioInfluence: Float
    public var visualInfluence: Float
    public var lightingInfluence: Float

    // Specific parameter mappings
    public var pressureToFilter: Bool
    public var humidityToReverb: Bool
    public var windToModulation: Bool
    public var uvToBrightness: Bool
    public var temperatureToWarmth: Bool
    public var conditionToParticles: Bool

    public static let immersive = WeatherReactivePreset(
        id: UUID(),
        name: "Immersive",
        description: "Full weather immersion - all parameters active",
        audioInfluence: 1.0,
        visualInfluence: 1.0,
        lightingInfluence: 1.0,
        pressureToFilter: true,
        humidityToReverb: true,
        windToModulation: true,
        uvToBrightness: true,
        temperatureToWarmth: true,
        conditionToParticles: true
    )

    public static let subtle = WeatherReactivePreset(
        id: UUID(),
        name: "Subtle",
        description: "Gentle weather influence for background awareness",
        audioInfluence: 0.3,
        visualInfluence: 0.5,
        lightingInfluence: 0.4,
        pressureToFilter: true,
        humidityToReverb: true,
        windToModulation: false,
        uvToBrightness: true,
        temperatureToWarmth: true,
        conditionToParticles: false
    )

    public static let visualOnly = WeatherReactivePreset(
        id: UUID(),
        name: "Visual Only",
        description: "Weather affects visuals and lighting, not audio",
        audioInfluence: 0.0,
        visualInfluence: 1.0,
        lightingInfluence: 1.0,
        pressureToFilter: false,
        humidityToReverb: false,
        windToModulation: false,
        uvToBrightness: true,
        temperatureToWarmth: false,
        conditionToParticles: true
    )

    public static let meditation = WeatherReactivePreset(
        id: UUID(),
        name: "Meditation",
        description: "Calming weather awareness for mindfulness",
        audioInfluence: 0.5,
        visualInfluence: 0.7,
        lightingInfluence: 0.6,
        pressureToFilter: true,
        humidityToReverb: true,
        windToModulation: false,
        uvToBrightness: true,
        temperatureToWarmth: true,
        conditionToParticles: true
    )
}

// MARK: - Weather Reactive Engine

/// Main engine that converts weather data to audio/visual/lighting parameters
@MainActor
public final class WeatherReactiveEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = WeatherReactiveEngine()

    // MARK: - Published State

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var currentWeather: EchoelWeatherData?
    @Published public private(set) var audioParameters: WeatherAudioParameters = .neutral
    @Published public private(set) var visualParameters: WeatherVisualParameters = .neutral
    @Published public private(set) var lightingParameters: WeatherLightingParameters = .neutral
    @Published public var activePreset: WeatherReactivePreset = .immersive

    // MARK: - Smoothing

    /// Smoothing factor for parameter transitions (0-1, higher = faster)
    public var smoothingFactor: Float = 0.1

    private var targetAudioParams: WeatherAudioParameters = .neutral
    private var targetVisualParams: WeatherVisualParameters = .neutral
    private var targetLightingParams: WeatherLightingParameters = .neutral

    // MARK: - Dependencies

    private let weatherManager = WeatherKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Callbacks

    public var onAudioParametersChanged: ((WeatherAudioParameters) -> Void)?
    public var onVisualParametersChanged: ((WeatherVisualParameters) -> Void)?
    public var onLightingParametersChanged: ((WeatherLightingParameters) -> Void)?

    // MARK: - Initialization

    private init() {
        setupWeatherObserver()
    }

    // MARK: - Public API

    /// Enable weather-reactive features
    public func enable() {
        isEnabled = true
        startSmoothingLoop()
    }

    /// Disable weather-reactive features
    public func disable() {
        isEnabled = false
        stopSmoothingLoop()
        resetToNeutral()
    }

    /// Fetch weather and update parameters
    public func updateWeather(for location: CLLocationCoordinate2D) async {
        do {
            let weather = try await weatherManager.fetchWeather(for: location)
            processWeatherUpdate(weather)
        } catch {
            // Use cached if available
            if let cached = weatherManager.getCachedWeather() {
                processWeatherUpdate(cached)
            }
        }
    }

    /// Apply a preset
    public func applyPreset(_ preset: WeatherReactivePreset) {
        activePreset = preset
        if let weather = currentWeather {
            processWeatherUpdate(weather)
        }
    }

    /// Get current weather condition description
    public var weatherDescription: String {
        guard let weather = currentWeather else {
            return "Weather data not available"
        }
        return "\(weather.condition.rawValue.capitalized), \(Int(weather.temperature))°C"
    }

    /// Get suggested mood for current weather
    public var currentMood: String {
        return currentWeather?.suggestedMood ?? "neutral"
    }

    // MARK: - Private Methods

    private func setupWeatherObserver() {
        weatherManager.$currentWeather
            .compactMap { $0 }
            .sink { [weak self] weather in
                self?.processWeatherUpdate(weather)
            }
            .store(in: &cancellables)
    }

    private func processWeatherUpdate(_ weather: EchoelWeatherData) {
        currentWeather = weather

        guard isEnabled else { return }

        // Calculate target parameters
        targetAudioParams = calculateAudioParameters(from: weather)
        targetVisualParams = calculateVisualParameters(from: weather)
        targetLightingParams = calculateLightingParameters(from: weather)
    }

    // MARK: - Audio Parameter Calculation

    private func calculateAudioParameters(from weather: EchoelWeatherData) -> WeatherAudioParameters {
        var params = WeatherAudioParameters.neutral
        let preset = activePreset

        guard preset.audioInfluence > 0 else { return params }

        let influence = preset.audioInfluence

        // Barometric pressure → Filter cutoff
        // Low pressure (storms) = darker sound, high pressure (clear) = brighter
        if preset.pressureToFilter {
            let pressureNorm = weather.normalizedPressure
            params.filterCutoff = lerp(2000, 12000, pressureNorm) * influence + 8000 * (1 - influence)
        }

        // Humidity → Reverb
        // High humidity = more reverb (sound travels differently in humid air)
        if preset.humidityToReverb {
            params.reverbMix = lerp(0.1, 0.7, Float(weather.humidity)) * influence + 0.3 * (1 - influence)
            params.reverbDecay = lerp(1.0, 5.0, Float(weather.humidity)) * influence + 2.0 * (1 - influence)
        }

        // Wind → Modulation
        // Wind speed affects chorus/modulation rate
        if preset.windToModulation {
            let windNorm = Float(min(weather.windSpeed / 15.0, 1.0))
            params.modulationRate = lerp(0.5, 8.0, windNorm) * influence + 1.0 * (1 - influence)
            params.modulationDepth = lerp(0.1, 0.6, windNorm) * influence + 0.3 * (1 - influence)
            params.chorusAmount = lerp(0.1, 0.5, windNorm) * influence + 0.2 * (1 - influence)
        }

        // UV Index → Brightness (high frequencies)
        if preset.uvToBrightness {
            let uvNorm = Float(min(weather.uvIndex, 11)) / 11.0
            params.brightness = lerp(-3, 6, uvNorm) * influence
        }

        // Temperature → Warmth (saturation)
        if preset.temperatureToWarmth {
            // Map temperature: 0°C = cold, 25°C = warm
            let tempNorm = Float(max(0, min(weather.temperature, 35)) / 35.0)
            params.warmth = lerp(0.2, 0.8, tempNorm) * influence + 0.5 * (1 - influence)
        }

        // Weather condition affects overall mood
        params.suggestedBPM = suggestBPM(for: weather.condition, energy: Float(weather.energyLevel))

        // Condition-specific adjustments
        switch weather.condition {
        case .thunderstorm:
            params.bassBoost = 4 * influence
            params.delayFeedback = 0.6 * influence
        case .rain, .drizzle:
            params.delayTime = 0.4 * influence + 0.25 * (1 - influence)
            params.delayMix = 0.4 * influence + 0.2 * (1 - influence)
        case .snow:
            params.filterCutoff = min(params.filterCutoff, 6000)
            params.reverbMix = max(params.reverbMix, 0.5 * influence)
        case .fog, .mist:
            params.filterCutoff = min(params.filterCutoff, 4000)
            params.reverbDecay = max(params.reverbDecay, 4.0 * influence)
        case .clear where weather.isDaylight:
            params.brightness = max(params.brightness, 3 * influence)
        default:
            break
        }

        return params
    }

    // MARK: - Visual Parameter Calculation

    private func calculateVisualParameters(from weather: EchoelWeatherData) -> WeatherVisualParameters {
        var params = WeatherVisualParameters.neutral
        let preset = activePreset

        guard preset.visualInfluence > 0 else { return params }

        let influence = preset.visualInfluence

        // Base color from weather condition
        let (hue, sat, bri) = colorForCondition(weather.condition, isDaylight: weather.isDaylight)
        params.primaryHue = hue
        params.saturation = sat * influence + 0.5 * (1 - influence)
        params.brightness = bri * influence + 0.7 * (1 - influence)

        // UV → Color temperature
        if preset.uvToBrightness {
            let uvNorm = Float(min(weather.uvIndex, 11)) / 11.0
            params.colorTemperature = lerp(4000, 8000, uvNorm)
            params.ambientLight = lerp(0.4, 1.0, uvNorm) * influence + 0.7 * (1 - influence)
        }

        // Wind → Animation speed and flow
        if preset.windToModulation {
            let windNorm = Float(min(weather.windSpeed / 15.0, 1.0))
            params.animationSpeed = lerp(0.5, 2.5, windNorm) * influence + 1.0 * (1 - influence)
            params.flowDirection = Float(weather.windDirection)
        }

        // Particles from weather condition
        if preset.conditionToParticles {
            params.particleType = particleTypeFor(weather.condition)
            params.particleDensity = particleDensityFor(weather.condition, intensity: Float(weather.precipitationIntensity)) * influence
            params.particleSpeed = lerp(0.3, 1.0, Float(weather.energyLevel)) * influence + 0.5 * (1 - influence)
        }

        // Cloud cover → Fog/blur
        params.fogDensity = Float(weather.cloudCover) * 0.5 * influence
        if weather.condition == .fog || weather.condition == .mist {
            params.fogDensity = 0.8 * influence
            params.blurAmount = 5 * influence
        }

        // Visibility affects contrast
        let visNorm = Float(min(weather.visibility / 10000, 1.0))
        params.contrastLevel = lerp(0.7, 1.2, visNorm) * influence + 1.0 * (1 - influence)

        return params
    }

    // MARK: - Lighting Parameter Calculation

    private func calculateLightingParameters(from weather: EchoelWeatherData) -> WeatherLightingParameters {
        var params = WeatherLightingParameters.neutral
        let preset = activePreset

        guard preset.lightingInfluence > 0 else { return params }

        let influence = preset.lightingInfluence

        // Base color from condition
        let (r, g, b) = rgbForCondition(weather.condition, isDaylight: weather.isDaylight)
        params.colorR = r * influence + 0.5 * (1 - influence)
        params.colorG = g * influence + 0.5 * (1 - influence)
        params.colorB = b * influence + 0.7 * (1 - influence)

        // Temperature → Warm white
        if preset.temperatureToWarmth {
            let tempNorm = Float(max(0, min(weather.temperature, 35)) / 35.0)
            params.colorW = lerp(0.1, 0.7, tempNorm) * influence + 0.3 * (1 - influence)
        }

        // UV/daylight → Intensity
        if preset.uvToBrightness {
            let uvNorm = Float(min(weather.uvIndex, 11)) / 11.0
            params.masterIntensity = lerp(0.4, 1.0, uvNorm) * influence + 0.7 * (1 - influence)
        }

        // Wind → Movement speed (for moving heads)
        if preset.windToModulation {
            let windNorm = Float(min(weather.windSpeed / 15.0, 1.0))
            params.movementSpeed = lerp(0.1, 0.8, windNorm) * influence + 0.3 * (1 - influence)
        }

        // Condition-specific effects
        switch weather.condition {
        case .thunderstorm:
            params.strobeRate = 3.0 * influence  // Lightning effect
            params.goboPattern = 5  // Storm pattern
        case .clear where weather.isDaylight:
            params.goboPattern = 1  // Sun rays
        case .snow:
            params.goboPattern = 3  // Snowflake pattern
        case .rain:
            params.goboPattern = 4  // Rain pattern
        default:
            params.goboPattern = 0
        }

        return params
    }

    // MARK: - Smoothing Loop

    private func startSmoothingLoop() {
        stopSmoothingLoop()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.smoothParameters()
            }
        }
    }

    private func stopSmoothingLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func smoothParameters() {
        // Smooth audio parameters
        audioParameters = smoothAudioParams(audioParameters, towards: targetAudioParams)
        onAudioParametersChanged?(audioParameters)

        // Smooth visual parameters
        visualParameters = smoothVisualParams(visualParameters, towards: targetVisualParams)
        onVisualParametersChanged?(visualParameters)

        // Smooth lighting parameters
        lightingParameters = smoothLightingParams(lightingParameters, towards: targetLightingParams)
        onLightingParametersChanged?(lightingParameters)
    }

    private func smoothAudioParams(_ current: WeatherAudioParameters, towards target: WeatherAudioParameters) -> WeatherAudioParameters {
        let s = smoothingFactor
        return WeatherAudioParameters(
            filterCutoff: lerp(current.filterCutoff, target.filterCutoff, s),
            filterResonance: lerp(current.filterResonance, target.filterResonance, s),
            filterType: target.filterType,
            reverbMix: lerp(current.reverbMix, target.reverbMix, s),
            reverbDecay: lerp(current.reverbDecay, target.reverbDecay, s),
            reverbDamping: lerp(current.reverbDamping, target.reverbDamping, s),
            delayTime: lerp(current.delayTime, target.delayTime, s),
            delayFeedback: lerp(current.delayFeedback, target.delayFeedback, s),
            delayMix: lerp(current.delayMix, target.delayMix, s),
            modulationRate: lerp(current.modulationRate, target.modulationRate, s),
            modulationDepth: lerp(current.modulationDepth, target.modulationDepth, s),
            chorusAmount: lerp(current.chorusAmount, target.chorusAmount, s),
            bassBoost: lerp(current.bassBoost, target.bassBoost, s),
            brightness: lerp(current.brightness, target.brightness, s),
            warmth: lerp(current.warmth, target.warmth, s),
            suggestedBPM: lerp(current.suggestedBPM, target.suggestedBPM, s)
        )
    }

    private func smoothVisualParams(_ current: WeatherVisualParameters, towards target: WeatherVisualParameters) -> WeatherVisualParameters {
        let s = smoothingFactor
        return WeatherVisualParameters(
            primaryHue: lerpAngle(current.primaryHue, target.primaryHue, s),
            saturation: lerp(current.saturation, target.saturation, s),
            brightness: lerp(current.brightness, target.brightness, s),
            colorTemperature: lerp(current.colorTemperature, target.colorTemperature, s),
            particleDensity: lerp(current.particleDensity, target.particleDensity, s),
            particleSpeed: lerp(current.particleSpeed, target.particleSpeed, s),
            particleSize: lerp(current.particleSize, target.particleSize, s),
            particleType: target.particleType,
            animationSpeed: lerp(current.animationSpeed, target.animationSpeed, s),
            pulseIntensity: lerp(current.pulseIntensity, target.pulseIntensity, s),
            flowDirection: lerpAngle(current.flowDirection, target.flowDirection, s),
            blurAmount: lerp(current.blurAmount, target.blurAmount, s),
            glowIntensity: lerp(current.glowIntensity, target.glowIntensity, s),
            noiseAmount: lerp(current.noiseAmount, target.noiseAmount, s),
            fogDensity: lerp(current.fogDensity, target.fogDensity, s),
            ambientLight: lerp(current.ambientLight, target.ambientLight, s),
            contrastLevel: lerp(current.contrastLevel, target.contrastLevel, s)
        )
    }

    private func smoothLightingParams(_ current: WeatherLightingParameters, towards target: WeatherLightingParameters) -> WeatherLightingParameters {
        let s = smoothingFactor
        return WeatherLightingParameters(
            masterIntensity: lerp(current.masterIntensity, target.masterIntensity, s),
            colorR: lerp(current.colorR, target.colorR, s),
            colorG: lerp(current.colorG, target.colorG, s),
            colorB: lerp(current.colorB, target.colorB, s),
            colorW: lerp(current.colorW, target.colorW, s),
            strobeRate: lerp(current.strobeRate, target.strobeRate, s),
            movementSpeed: lerp(current.movementSpeed, target.movementSpeed, s),
            goboPattern: target.goboPattern
        )
    }

    private func resetToNeutral() {
        targetAudioParams = .neutral
        targetVisualParams = .neutral
        targetLightingParams = .neutral
    }

    // MARK: - Helper Functions

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    private func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        // Handle circular interpolation for angles
        var delta = b - a
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var result = a + delta * t
        if result < 0 { result += 360 }
        if result >= 360 { result -= 360 }
        return result
    }

    private func suggestBPM(for condition: EchoelWeatherData.WeatherCondition, energy: Float) -> Float {
        let baseBPM: Float
        switch condition {
        case .thunderstorm: baseBPM = 140
        case .heavyRain: baseBPM = 120
        case .rain, .drizzle: baseBPM = 90
        case .windy: baseBPM = 130
        case .clear where energy > 0.6: baseBPM = 120
        case .clear: baseBPM = 100
        case .cloudy, .overcast: baseBPM = 80
        case .fog, .mist: baseBPM = 70
        case .snow: baseBPM = 75
        default: baseBPM = 100
        }
        return baseBPM * lerp(0.8, 1.2, energy)
    }

    private func colorForCondition(_ condition: EchoelWeatherData.WeatherCondition, isDaylight: Bool) -> (hue: Float, saturation: Float, brightness: Float) {
        switch condition {
        case .clear where isDaylight: return (45, 0.7, 0.9)    // Warm yellow
        case .clear: return (240, 0.6, 0.4)                    // Night blue
        case .partlyCloudy: return (200, 0.5, 0.7)             // Light blue
        case .cloudy, .overcast: return (220, 0.3, 0.5)        // Gray blue
        case .rain, .drizzle: return (210, 0.6, 0.5)           // Blue
        case .heavyRain: return (230, 0.7, 0.4)                // Dark blue
        case .thunderstorm: return (270, 0.8, 0.6)             // Purple
        case .snow: return (200, 0.2, 0.9)                     // Pale blue-white
        case .fog, .mist: return (180, 0.2, 0.6)               // Pale cyan
        case .hot: return (30, 0.8, 0.8)                       // Orange
        case .cold: return (200, 0.5, 0.6)                     // Cold blue
        default: return (200, 0.5, 0.7)
        }
    }

    private func rgbForCondition(_ condition: EchoelWeatherData.WeatherCondition, isDaylight: Bool) -> (r: Float, g: Float, b: Float) {
        switch condition {
        case .clear where isDaylight: return (1.0, 0.9, 0.5)
        case .clear: return (0.2, 0.2, 0.5)
        case .partlyCloudy: return (0.6, 0.7, 0.9)
        case .cloudy, .overcast: return (0.5, 0.5, 0.6)
        case .rain, .drizzle: return (0.3, 0.4, 0.7)
        case .heavyRain: return (0.2, 0.3, 0.6)
        case .thunderstorm: return (0.5, 0.2, 0.7)
        case .snow: return (0.9, 0.9, 1.0)
        case .fog, .mist: return (0.6, 0.7, 0.7)
        case .hot: return (1.0, 0.6, 0.3)
        case .cold: return (0.4, 0.6, 0.9)
        default: return (0.5, 0.5, 0.7)
        }
    }

    private func particleTypeFor(_ condition: EchoelWeatherData.WeatherCondition) -> WeatherVisualParameters.ParticleType {
        switch condition {
        case .rain, .drizzle, .heavyRain: return .rain
        case .snow, .sleet, .hail: return .snow
        case .fog, .mist, .haze: return .dust
        case .windy where condition != .clear: return .leaves
        case .clear: return .sparkles
        default: return .none
        }
    }

    private func particleDensityFor(_ condition: EchoelWeatherData.WeatherCondition, intensity: Float) -> Float {
        switch condition {
        case .heavyRain: return 0.9
        case .rain: return 0.6
        case .drizzle: return 0.3
        case .snow: return 0.5
        case .fog, .mist: return 0.4
        case .windy: return 0.3
        case .clear: return 0.1
        default: return 0.2
        }
    }
}

// MARK: - All Presets

extension WeatherReactivePreset {
    public static let allPresets: [WeatherReactivePreset] = [
        .immersive,
        .subtle,
        .visualOnly,
        .meditation,
        .energetic,
        .ambient,
        .performance
    ]

    public static let energetic = WeatherReactivePreset(
        id: UUID(),
        name: "Energetic",
        description: "Amplifies weather energy for dynamic performances",
        audioInfluence: 1.0,
        visualInfluence: 1.0,
        lightingInfluence: 1.0,
        pressureToFilter: true,
        humidityToReverb: false,
        windToModulation: true,
        uvToBrightness: true,
        temperatureToWarmth: true,
        conditionToParticles: true
    )

    public static let ambient = WeatherReactivePreset(
        id: UUID(),
        name: "Ambient",
        description: "Smooth, atmospheric weather integration",
        audioInfluence: 0.6,
        visualInfluence: 0.8,
        lightingInfluence: 0.5,
        pressureToFilter: true,
        humidityToReverb: true,
        windToModulation: false,
        uvToBrightness: true,
        temperatureToWarmth: true,
        conditionToParticles: true
    )

    public static let performance = WeatherReactivePreset(
        id: UUID(),
        name: "Performance",
        description: "Optimized for live shows with dramatic lighting",
        audioInfluence: 0.4,
        visualInfluence: 0.8,
        lightingInfluence: 1.0,
        pressureToFilter: false,
        humidityToReverb: false,
        windToModulation: true,
        uvToBrightness: true,
        temperatureToWarmth: false,
        conditionToParticles: true
    )
}
