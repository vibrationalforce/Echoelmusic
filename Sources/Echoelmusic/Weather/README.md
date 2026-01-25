# Weather Module

Weather-reactive features and WeatherKit integration for Echoelmusic.

## Overview

The Weather module integrates with Apple WeatherKit to provide weather-aware ambient experiences, adjusting visualizations and audio based on current weather conditions.

## Features

### Weather-Reactive Visuals

Visualizations adapt to current weather:

| Condition | Visual Effect |
|-----------|--------------|
| Sunny | Warm, bright colors |
| Cloudy | Muted, diffuse lighting |
| Rain | Water ripple effects |
| Snow | Particle snowfall |
| Thunderstorm | Lightning flashes |
| Fog | Atmospheric haze |
| Wind | Particle movement |

### Weather-Reactive Audio

Audio parameters modulate based on weather:

| Condition | Audio Effect |
|-----------|-------------|
| Rain | Increased reverb |
| Wind | Subtle noise texture |
| Clear | Crisp, open sound |
| Storm | Low-frequency rumble |

## Key Components

### WeatherManager

Main weather integration:

```swift
let weather = WeatherManager()

// Fetch current weather
let current = await weather.getCurrentWeather()
print("Temperature: \(current.temperature)")
print("Condition: \(current.condition)")

// Get forecast
let forecast = await weather.getDailyForecast(days: 7)

// Subscribe to updates
weather.weatherUpdates
    .sink { weather in
        updateVisualization(for: weather)
    }
    .store(in: &cancellables)
```

### WeatherCondition

```swift
enum WeatherCondition {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case snow
    case sleet
    case fog
    case wind
    case thunderstorm
    case hail
}
```

### WeatherReactiveView

SwiftUI view with weather effects:

```swift
WeatherReactiveView()
    .weatherCondition(.rain)
    .weatherIntensity(0.7)
```

## WeatherKit Integration

Uses Apple WeatherKit for accurate data:

```swift
// Requires WeatherKit capability
// Add in Xcode: Signing & Capabilities > WeatherKit

import WeatherKit

let weatherService = WeatherService.shared
let weather = try await weatherService.weather(for: location)
```

## Location Privacy

- Location used only for weather data
- No location history stored
- User can disable weather features
- Manual location input option

## Fallback

When weather unavailable:
- Uses neutral ambient settings
- Option for manual weather selection
- Cached last-known weather

## Audio Mapping

```swift
// Rain → Reverb
reverbMix = rainIntensity * 0.3 + 0.1

// Wind → Modulation
lfoRate = windSpeed * 0.01 + 0.5

// Temperature → Warmth
filterCutoff = temperature * 50 + 200
```

## Visual Mapping

```swift
// Sun position → Lighting
lightAngle = sunAzimuth
lightIntensity = sunAltitude / 90

// Clouds → Opacity
cloudLayer.opacity = cloudCover

// Rain → Particles
rainParticles.count = Int(rainIntensity * 1000)
```

## Presets

| Preset | Description |
|--------|-------------|
| Adaptive | Full weather reactivity |
| Sunny Day | Warm, clear ambiance |
| Rainy Mood | Cozy rain atmosphere |
| Storm | Dramatic thunderstorm |
| Peaceful | Gentle, calm weather |

## Files

| File | Description |
|------|-------------|
| `WeatherManager.swift` | WeatherKit integration |
| `WeatherReactiveView.swift` | Weather-aware visuals |
| `WeatherAudioModulator.swift` | Audio weather effects |
