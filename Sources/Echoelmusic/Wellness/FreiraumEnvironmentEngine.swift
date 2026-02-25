// FreiraumEnvironmentEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Freiraum- und Bewegungsforschung für Forschungsinstitut Brache Bahrenfeld
// Umgebungssensorik: Luftqualität, Temperatur, Feuchtigkeit, Lärm, UV, Wind
// Bewegungsanalyse: Outdoor-Fitness, Yoga, Tai Chi, Laufen, Radfahren
//
// Verbindet Freiraum-Qualität mit bio-reaktivem Audio/Visual-Feedback:
// Gute Luft + Bewegung → höhere Kohärenz, harmonischere Klänge
//
// HINWEIS: Forschungstool. Kein Ersatz für professionelle Umweltanalyse.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Environmental Parameters

/// Messbare Umgebungsparameter im Freiraum
public enum FreiraumParameter: String, CaseIterable, Codable, Sendable {
    case airQualityIndex = "Luftqualitätsindex"
    case pm25 = "PM2.5"
    case pm10 = "PM10"
    case co2 = "CO₂"
    case ozone = "Ozon"
    case temperature = "Temperatur"
    case humidity = "Luftfeuchtigkeit"
    case uvIndex = "UV-Index"
    case windSpeed = "Windgeschwindigkeit"
    case noiseLevel = "Lärmpegel"
    case barometricPressure = "Luftdruck"
    case naturalLight = "Natürliches Licht"

    /// Einheit der Messung
    public var unit: String {
        switch self {
        case .airQualityIndex: return "AQI"
        case .pm25: return "µg/m³"
        case .pm10: return "µg/m³"
        case .co2: return "ppm"
        case .ozone: return "µg/m³"
        case .temperature: return "°C"
        case .humidity: return "%"
        case .uvIndex: return ""
        case .windSpeed: return "m/s"
        case .noiseLevel: return "dB(A)"
        case .barometricPressure: return "hPa"
        case .naturalLight: return "lux"
        }
    }

    /// Optimaler Bereich für Outdoor-Aktivitäten
    public var optimalRange: ClosedRange<Double> {
        switch self {
        case .airQualityIndex: return 0.0...50.0        // Gut (WHO)
        case .pm25: return 0.0...15.0                   // WHO 2021
        case .pm10: return 0.0...45.0
        case .co2: return 380.0...600.0                 // Frischluft
        case .ozone: return 0.0...100.0
        case .temperature: return 15.0...25.0           // Komfortzone
        case .humidity: return 40.0...60.0
        case .uvIndex: return 0.0...5.0                 // Moderat
        case .windSpeed: return 0.5...5.0               // Leichter Wind
        case .noiseLevel: return 30.0...55.0            // Angenehm ruhig
        case .barometricPressure: return 1010.0...1025.0
        case .naturalLight: return 2000.0...50000.0     // Tageslicht
        }
    }

    /// IoT-Sensor Abtastrate in Hz
    public var sensorSampleRate: Double {
        switch self {
        case .airQualityIndex: return 0.017  // alle 60s
        case .pm25: return 0.1               // alle 10s
        case .pm10: return 0.1
        case .co2: return 0.2                // alle 5s
        case .ozone: return 0.017
        case .temperature: return 0.1
        case .humidity: return 0.1
        case .uvIndex: return 0.017
        case .windSpeed: return 1.0          // jede Sekunde
        case .noiseLevel: return 2.0         // 2 Hz
        case .barometricPressure: return 0.1
        case .naturalLight: return 1.0
        }
    }
}

// MARK: - Movement Research Types

/// Bewegungsarten im Freiraum
public enum FreiraumMovementType: String, CaseIterable, Codable, Sendable {
    case walking = "Gehen"
    case running = "Laufen"
    case cycling = "Radfahren"
    case yoga = "Yoga"
    case taiChi = "Tai Chi"
    case qiGong = "Qi Gong"
    case calisthenics = "Calisthenics"
    case meditation = "Meditation"
    case gardening = "Gartenarbeit"
    case swimming = "Schwimmen"
    case climbing = "Klettern"
    case dance = "Tanz"

    /// Optimale Umgebungsbedingungen für diese Aktivität
    public var optimalConditions: FreiraumConditions {
        switch self {
        case .walking:
            return FreiraumConditions(tempRange: 10...25, maxWindSpeed: 8, maxUV: 6, maxNoise: 65)
        case .running:
            return FreiraumConditions(tempRange: 8...20, maxWindSpeed: 10, maxUV: 5, maxNoise: 70)
        case .cycling:
            return FreiraumConditions(tempRange: 10...28, maxWindSpeed: 6, maxUV: 6, maxNoise: 60)
        case .yoga:
            return FreiraumConditions(tempRange: 18...28, maxWindSpeed: 3, maxUV: 4, maxNoise: 45)
        case .taiChi:
            return FreiraumConditions(tempRange: 15...25, maxWindSpeed: 4, maxUV: 5, maxNoise: 50)
        case .qiGong:
            return FreiraumConditions(tempRange: 15...25, maxWindSpeed: 4, maxUV: 5, maxNoise: 50)
        case .calisthenics:
            return FreiraumConditions(tempRange: 10...25, maxWindSpeed: 8, maxUV: 6, maxNoise: 65)
        case .meditation:
            return FreiraumConditions(tempRange: 18...26, maxWindSpeed: 2, maxUV: 3, maxNoise: 40)
        case .gardening:
            return FreiraumConditions(tempRange: 12...28, maxWindSpeed: 6, maxUV: 5, maxNoise: 60)
        case .swimming:
            return FreiraumConditions(tempRange: 22...32, maxWindSpeed: 5, maxUV: 5, maxNoise: 60)
        case .climbing:
            return FreiraumConditions(tempRange: 10...25, maxWindSpeed: 5, maxUV: 6, maxNoise: 60)
        case .dance:
            return FreiraumConditions(tempRange: 15...28, maxWindSpeed: 4, maxUV: 5, maxNoise: 55)
        }
    }

    /// Bio-reaktive Frequenz für diese Bewegungsart
    public var bioReactiveFrequency: Double {
        switch self {
        case .walking: return 10.0       // Alpha — entspannter Fokus
        case .running: return 18.0       // Beta — Energie
        case .cycling: return 15.0       // Beta — rhythmisch
        case .yoga: return 7.5           // Theta — Achtsamkeit
        case .taiChi: return 8.0         // Alpha — fließend
        case .qiGong: return 7.0         // Theta — innere Ruhe
        case .calisthenics: return 20.0  // Beta — Kraft
        case .meditation: return 4.0     // Theta/Delta — Stille
        case .gardening: return 10.0     // Alpha — geerdet
        case .swimming: return 12.0      // Alpha — rhythmisch
        case .climbing: return 16.0      // Beta — Konzentration
        case .dance: return 14.0         // Alpha/Beta — Ausdruck
        }
    }

    /// Erwarteter HRV-Kohärenz-Einfluss (positiv = fördernd)
    public var coherenceImpact: Double {
        switch self {
        case .walking: return 0.6
        case .running: return 0.4
        case .cycling: return 0.5
        case .yoga: return 0.9
        case .taiChi: return 0.85
        case .qiGong: return 0.85
        case .calisthenics: return 0.3
        case .meditation: return 0.95
        case .gardening: return 0.7
        case .swimming: return 0.6
        case .climbing: return 0.4
        case .dance: return 0.7
        }
    }
}

/// Optimale Umgebungsbedingungen für eine Aktivität
public struct FreiraumConditions: Sendable {
    public let tempRange: ClosedRange<Double>
    public let maxWindSpeed: Double
    public let maxUV: Double
    public let maxNoise: Double
}

// MARK: - Freiraum Zone Types

/// Zonen im Forschungsgelände Brache Bahrenfeld
public enum FreiraumZone: String, CaseIterable, Codable, Sendable {
    case movementPark = "Bewegungspark"
    case meditationGarden = "Meditationsgarten"
    case aquaponicsHall = "Aquaponik-Halle"
    case urbanFarm = "Stadtfarm"
    case playgroundLab = "Spielplatz-Labor"
    case forestBathing = "Waldbaden-Bereich"
    case waterFeature = "Wasserlandschaft"
    case communityKitchen = "Gemeinschaftsküche"
    case researchLab = "Forschungslabor"
    case openStage = "Freilichtbühne"

    /// Primäre Bewegungsarten in dieser Zone
    public var primaryActivities: [FreiraumMovementType] {
        switch self {
        case .movementPark:
            return [.running, .calisthenics, .cycling]
        case .meditationGarden:
            return [.meditation, .yoga, .taiChi, .qiGong]
        case .aquaponicsHall:
            return [.gardening]
        case .urbanFarm:
            return [.gardening, .walking]
        case .playgroundLab:
            return [.climbing, .dance, .calisthenics]
        case .forestBathing:
            return [.walking, .meditation]
        case .waterFeature:
            return [.swimming, .meditation]
        case .communityKitchen:
            return [.walking]
        case .researchLab:
            return [.meditation]
        case .openStage:
            return [.dance, .yoga, .taiChi]
        }
    }

    /// Prioritäts-Umgebungsparameter für diese Zone
    public var priorityParameters: [FreiraumParameter] {
        switch self {
        case .movementPark:
            return [.temperature, .uvIndex, .airQualityIndex, .windSpeed]
        case .meditationGarden:
            return [.noiseLevel, .temperature, .naturalLight, .airQualityIndex]
        case .aquaponicsHall:
            return [.temperature, .humidity, .co2, .naturalLight]
        case .urbanFarm:
            return [.temperature, .humidity, .uvIndex, .windSpeed]
        case .playgroundLab:
            return [.temperature, .uvIndex, .noiseLevel, .pm25]
        case .forestBathing:
            return [.airQualityIndex, .noiseLevel, .naturalLight, .humidity]
        case .waterFeature:
            return [.temperature, .humidity, .windSpeed, .uvIndex]
        case .communityKitchen:
            return [.temperature, .humidity, .co2, .pm25]
        case .researchLab:
            return [.temperature, .humidity, .co2, .noiseLevel]
        case .openStage:
            return [.noiseLevel, .temperature, .windSpeed, .naturalLight]
        }
    }
}

// MARK: - Environment Reading

/// Einzelne Umgebungsmessung
public struct FreiraumReading: Sendable {
    public let timestamp: Date
    public let zone: FreiraumZone
    public let parameter: FreiraumParameter
    public let value: Double
    public let sensorID: String

    /// Ist der Messwert im optimalen Bereich?
    public var isOptimal: Bool {
        parameter.optimalRange.contains(value)
    }

    /// Abweichung vom Optimum
    public var deviationFromOptimal: Double {
        let range = parameter.optimalRange
        if value < range.lowerBound {
            return (range.lowerBound - value) / (range.upperBound - range.lowerBound)
        } else if value > range.upperBound {
            return (value - range.upperBound) / (range.upperBound - range.lowerBound)
        }
        return 0.0
    }
}

// MARK: - Freiraum Environment Engine

/// Zentrale Engine für Freiraum- und Bewegungsforschung
@MainActor
public class FreiraumEnvironmentEngine: ObservableObject {

    public static let shared = FreiraumEnvironmentEngine()

    // MARK: - Published State

    @Published public var isMonitoring: Bool = false
    @Published public var activeZones: Set<FreiraumZone> = []
    @Published public var latestReadings: [FreiraumZone: [FreiraumParameter: FreiraumReading]] = [:]
    @Published public var overallEnvironmentScore: Double = 1.0  // 0.0–1.0
    @Published public var currentActivityRecommendations: [FreiraumMovementType] = []
    @Published public var activeMovementSessions: [MovementSession] = []

    // MARK: - Configuration

    @Published public var bioReactiveMappingEnabled: Bool = true
    @Published public var activityRecommendationsEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Zone Management

    /// Zone aktivieren
    public func activateZone(_ zone: FreiraumZone) {
        activeZones.insert(zone)
    }

    /// Zone deaktivieren
    public func deactivateZone(_ zone: FreiraumZone) {
        activeZones.remove(zone)
    }

    // MARK: - Monitoring Control

    /// Monitoring starten
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
    }

    /// Monitoring stoppen
    public func stopMonitoring() {
        isMonitoring = false
    }

    // MARK: - Reading Processing

    /// Neue Umgebungsmessung verarbeiten
    public func processReading(_ reading: FreiraumReading) {
        var zoneReadings = latestReadings[reading.zone] ?? [:]
        zoneReadings[reading.parameter] = reading
        latestReadings[reading.zone] = zoneReadings

        updateEnvironmentScore()
        if activityRecommendationsEnabled {
            updateActivityRecommendations()
        }
    }

    // MARK: - Environment Score

    private func updateEnvironmentScore() {
        var totalDeviation: Double = 0.0
        var readingCount: Int = 0

        for (_, paramReadings) in latestReadings {
            for (_, reading) in paramReadings {
                totalDeviation += reading.deviationFromOptimal
                readingCount += 1
            }
        }

        guard readingCount > 0 else {
            overallEnvironmentScore = 1.0
            return
        }

        let avgDeviation = totalDeviation / Double(readingCount)
        overallEnvironmentScore = Swift.max(0.0, 1.0 - avgDeviation)
    }

    // MARK: - Activity Recommendations

    /// Aktivitätsempfehlungen basierend auf aktuellen Bedingungen
    private func updateActivityRecommendations() {
        var recommendations: [(FreiraumMovementType, Double)] = []

        for movement in FreiraumMovementType.allCases {
            let conditions = movement.optimalConditions
            var suitabilityScore: Double = 1.0

            // Prüfe Temperatur über alle aktiven Zonen
            for (_, params) in latestReadings {
                if let tempReading = params[.temperature] {
                    if !conditions.tempRange.contains(tempReading.value) {
                        suitabilityScore -= 0.3
                    }
                }
                if let windReading = params[.windSpeed] {
                    if windReading.value > conditions.maxWindSpeed {
                        suitabilityScore -= 0.2
                    }
                }
                if let uvReading = params[.uvIndex] {
                    if uvReading.value > conditions.maxUV {
                        suitabilityScore -= 0.2
                    }
                }
                if let noiseReading = params[.noiseLevel] {
                    if noiseReading.value > conditions.maxNoise {
                        suitabilityScore -= 0.2
                    }
                }
            }

            if suitabilityScore > 0.5 {
                recommendations.append((movement, suitabilityScore))
            }
        }

        currentActivityRecommendations = recommendations
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    // MARK: - Movement Sessions

    /// Bewegungssession starten
    public func startMovementSession(type: FreiraumMovementType, zone: FreiraumZone) -> String {
        let session = MovementSession(
            id: UUID().uuidString,
            type: type,
            zone: zone,
            startTime: Date()
        )
        activeMovementSessions.append(session)
        return session.id
    }

    /// Bewegungssession beenden
    public func endMovementSession(id: String) {
        activeMovementSessions.removeAll { $0.id == id }
    }

    // MARK: - Bio-Reactive Mapping

    /// Umgebungsqualität → Kohärenz-Einfluss
    public var environmentCoherenceModifier: Double {
        guard bioReactiveMappingEnabled else { return 0.0 }
        return (overallEnvironmentScore - 0.5) * 0.2
    }

    /// Empfohlene Ambient-Farbe basierend auf Umgebungsqualität
    public var ambientColor: (r: Float, g: Float, b: Float) {
        let score = Float(overallEnvironmentScore)
        // Gute Luft → Himmelsblau, Schlechte Luft → Grau
        return (
            r: 0.5 * (1 - score) + 0.3 * score,
            g: 0.5 * (1 - score) + 0.7 * score,
            b: 0.5 * (1 - score) + 0.95 * score
        )
    }
}

// MARK: - Supporting Types

/// Aktive Bewegungssession
public struct MovementSession: Identifiable, Sendable {
    public let id: String
    public let type: FreiraumMovementType
    public let zone: FreiraumZone
    public let startTime: Date
}
