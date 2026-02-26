// UniversalEnvironmentEngine.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
//
// Universelle Umgebungs-Abstraktion für JEDES Environment
// Von Brache Bahrenfeld bis Tiefsee, Stratosphäre, Orbit und darüber hinaus
//
// "Me fail English? That's unpossible!" - Ralph Wiggum, Universal Scientist
//
// ═══════════════════════════════════════════════════════════════════════════════
// CORE PRINCIPLE: Jedes Environment ist ein Zustandsvektor im Phasenraum.
// Parameter sind Observable. Sensoren sind Messoperatoren.
// Bio-reaktives Mapping ist die unitäre Transformation |ψ_env⟩ → |ψ_audio⟩
// ═══════════════════════════════════════════════════════════════════════════════
//
// DISCLAIMER: Creative/artistic wellness tool. NOT medical or safety equipment.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Universal Environment Classification

/// Jedes denkbare Environment — vollständig, erweiterbar, universell
public enum EnvironmentClass: String, CaseIterable, Codable, Sendable {
    // Terrestrisch
    case urban = "Urban"
    case suburban = "Suburban"
    case rural = "Ländlich"
    case forest = "Wald"
    case desert = "Wüste"
    case mountain = "Gebirge"
    case arctic = "Arktis"
    case tropical = "Tropen"
    case cave = "Höhle"
    case underground = "Untergrund"

    // Aquatisch
    case freshwater = "Süßwasser"
    case ocean = "Ozean"
    case deepSea = "Tiefsee"
    case coral = "Korallenriff"
    case riverDelta = "Flussdelta"

    // Atmosphärisch
    case lowAltitude = "Niedrige Höhe"
    case highAltitude = "Große Höhe"
    case stratosphere = "Stratosphäre"

    // Extraterrestrisch
    case orbit = "Orbit"
    case lunarSurface = "Mondoberfläche"
    case martianSurface = "Marsoberfläche"
    case deepSpace = "Tiefer Weltraum"

    // Fahrzeuge & Plattformen
    case automobile = "Automobil"
    case train = "Zug"
    case aircraft = "Flugzeug"
    case helicopter = "Helikopter"
    case submarine = "U-Boot"
    case spacecraft = "Raumschiff"
    case bicycle = "Fahrrad"
    case boat = "Boot"
    case eVTOL = "eVTOL"

    // Gebäude & Innenräume
    case studio = "Studio"
    case gym = "Fitnessstudio"
    case hospital = "Krankenhaus"
    case school = "Schule"
    case office = "Büro"
    case home = "Zuhause"
    case greenhouse = "Gewächshaus"
    case laboratory = "Labor"
    case theater = "Theater"
    case museum = "Museum"

    // Forschung & Spezial
    case cleanRoom = "Reinraum"
    case anechoicChamber = "Reflexionsarmer Raum"
    case floatTank = "Floattank"
    case sauna = "Sauna"
    case cryoChamber = "Kryokammer"

    /// Physikalische Domäne
    public var domain: EnvironmentDomain {
        switch self {
        case .freshwater, .ocean, .deepSea, .coral, .riverDelta, .submarine:
            return .aquatic
        case .lowAltitude, .highAltitude, .stratosphere, .aircraft, .helicopter, .eVTOL:
            return .aerial
        case .orbit, .lunarSurface, .martianSurface, .deepSpace, .spacecraft:
            return .extraterrestrial
        case .automobile, .train, .bicycle, .boat:
            return .vehicular
        case .cave, .underground:
            return .subterranean
        default:
            return .terrestrial
        }
    }

    /// Relevante messbare Dimensionen für dieses Environment
    public var relevantDimensions: [EnvironmentDimension] {
        switch domain {
        case .aquatic:
            return [.temperature, .pressure, .salinity, .dissolvedOxygen,
                    .turbidity, .current, .depth, .lightPenetration, .pH]
        case .aerial:
            return [.temperature, .pressure, .humidity, .windSpeed,
                    .windDirection, .altitude, .airDensity, .turbulence,
                    .visibility, .uvRadiation]
        case .extraterrestrial:
            return [.temperature, .pressure, .radiation, .gravity,
                    .magneticField, .solarWind, .cosmicRays, .vacuum]
        case .vehicular:
            return [.temperature, .humidity, .noise, .vibration,
                    .acceleration, .velocity, .airQuality, .co2]
        case .subterranean:
            return [.temperature, .humidity, .pressure, .airQuality,
                    .radon, .co2, .noise, .lightLevel]
        case .terrestrial:
            return [.temperature, .humidity, .pressure, .airQuality,
                    .noise, .lightLevel, .uvRadiation, .windSpeed,
                    .pm25, .co2]
        }
    }

    /// Erwarteter Kohärenz-Basis-Einfluss (einige Environments sind natürlich förderlicher)
    public var baseCoherenceAffinity: Double {
        switch self {
        case .forest: return 0.85
        case .coral, .freshwater: return 0.80
        case .mountain: return 0.75
        case .rural, .tropical: return 0.70
        case .floatTank: return 0.95
        case .sauna: return 0.70
        case .greenhouse: return 0.75
        case .studio, .anechoicChamber: return 0.80
        case .deepSpace, .orbit: return 0.60
        case .deepSea, .submarine: return 0.55
        case .urban, .office: return 0.45
        case .automobile, .train: return 0.40
        case .aircraft, .helicopter, .eVTOL: return 0.35
        case .hospital: return 0.50
        case .cryoChamber: return 0.65
        case .arctic, .desert: return 0.60
        default: return 0.50
        }
    }
}

// MARK: - Environment Domain

/// Physikalische Domäne eines Environments
public enum EnvironmentDomain: String, CaseIterable, Codable, Sendable {
    case terrestrial = "Terrestrisch"
    case aquatic = "Aquatisch"
    case aerial = "Atmosphärisch"
    case extraterrestrial = "Extraterrestrisch"
    case vehicular = "Fahrzeug"
    case subterranean = "Unterirdisch"

    /// Physikalisches Medium
    public var medium: String {
        switch self {
        case .terrestrial: return "Luft (1 atm)"
        case .aquatic: return "Wasser"
        case .aerial: return "Luft (variabel)"
        case .extraterrestrial: return "Vakuum / dünne Atmosphäre"
        case .vehicular: return "Geschlossener Raum (bewegt)"
        case .subterranean: return "Luft (eingeschlossen)"
        }
    }

    /// Schallgeschwindigkeit im Medium (m/s) — kritisch für Spatial Audio
    public var speedOfSound: Double {
        switch self {
        case .terrestrial: return 343.0        // 20°C Luft
        case .aquatic: return 1481.0           // Salzwasser
        case .aerial: return 295.0             // Mittlere Troposphäre
        case .extraterrestrial: return 0.0     // Vakuum — kein Schall
        case .vehicular: return 343.0
        case .subterranean: return 340.0
        }
    }
}

// MARK: - Universal Environment Dimensions

/// Jede messbare physikalische Dimension — das universelle Sensorvokabular
public enum EnvironmentDimension: String, CaseIterable, Codable, Sendable {
    // Thermodynamisch
    case temperature = "Temperatur"
    case humidity = "Feuchtigkeit"
    case pressure = "Druck"

    // Atmosphärisch
    case airQuality = "Luftqualität"
    case pm25 = "PM2.5"
    case pm10 = "PM10"
    case co2 = "CO₂"
    case ozone = "Ozon"
    case radon = "Radon"
    case airDensity = "Luftdichte"

    // Optisch
    case lightLevel = "Lichtstärke"
    case uvRadiation = "UV-Strahlung"
    case lightPenetration = "Lichtdurchdringung"
    case visibility = "Sichtweite"

    // Akustisch
    case noise = "Lärmpegel"
    case vibration = "Vibration"

    // Mechanisch / Kinematisch
    case windSpeed = "Windgeschwindigkeit"
    case windDirection = "Windrichtung"
    case current = "Strömung"
    case turbulence = "Turbulenz"
    case acceleration = "Beschleunigung"
    case velocity = "Geschwindigkeit"
    case altitude = "Höhe"
    case depth = "Tiefe"
    case gravity = "Gravitation"

    // Chemisch / Aquatisch
    case pH = "pH-Wert"
    case salinity = "Salzgehalt"
    case dissolvedOxygen = "Gelöster Sauerstoff"
    case turbidity = "Trübung"

    // Elektromagnetisch
    case magneticField = "Magnetfeld"
    case radiation = "Strahlung"
    case solarWind = "Sonnenwind"
    case cosmicRays = "Kosmische Strahlung"
    case vacuum = "Vakuumqualität"

    /// SI-Einheit
    public var unit: String {
        switch self {
        case .temperature: return "°C"
        case .humidity: return "%"
        case .pressure: return "hPa"
        case .airQuality: return "AQI"
        case .pm25, .pm10: return "µg/m³"
        case .co2: return "ppm"
        case .ozone: return "µg/m³"
        case .radon: return "Bq/m³"
        case .airDensity: return "kg/m³"
        case .lightLevel: return "lux"
        case .uvRadiation: return "UV-Index"
        case .lightPenetration: return "m"
        case .visibility: return "km"
        case .noise: return "dB(A)"
        case .vibration: return "m/s²"
        case .windSpeed: return "m/s"
        case .windDirection: return "°"
        case .current: return "m/s"
        case .turbulence: return "m/s²"
        case .acceleration: return "g"
        case .velocity: return "m/s"
        case .altitude: return "m"
        case .depth: return "m"
        case .gravity: return "m/s²"
        case .pH: return ""
        case .salinity: return "‰"
        case .dissolvedOxygen: return "mg/L"
        case .turbidity: return "NTU"
        case .magneticField: return "µT"
        case .radiation: return "µSv/h"
        case .solarWind: return "km/s"
        case .cosmicRays: return "particles/cm²/s"
        case .vacuum: return "Pa"
        }
    }

    /// Menschlicher Komfortbereich (wo anwendbar)
    public var humanComfortRange: ClosedRange<Double>? {
        switch self {
        case .temperature: return 18.0...26.0
        case .humidity: return 30.0...60.0
        case .pressure: return 980.0...1040.0
        case .airQuality: return 0.0...50.0
        case .pm25: return 0.0...15.0
        case .co2: return 380.0...1000.0
        case .noise: return 25.0...55.0
        case .lightLevel: return 300.0...5000.0
        case .uvRadiation: return 0.0...5.0
        case .gravity: return 9.5...10.0
        case .vibration: return 0.0...0.3
        case .acceleration: return 0.8...1.2
        default: return nil
        }
    }
}

// MARK: - Universal Environment State Vector

/// Der Zustandsvektor eines Environments — wie |ψ⟩ in der Quantenmechanik
/// Jede Dimension hat einen Wert, eine Konfidenz und einen Trend
public struct EnvironmentStateVector: Sendable {
    public let timestamp: Date
    public let environmentClass: EnvironmentClass
    public var dimensions: [EnvironmentDimension: DimensionState]

    /// Gesamter Komfortscore (0 = lebensfeindlich, 1 = optimal)
    public var comfortScore: Double {
        var totalScore: Double = 0.0
        var count: Int = 0

        for (dimension, state) in dimensions {
            guard let comfort = dimension.humanComfortRange else { continue }
            let range = comfort.upperBound - comfort.lowerBound
            guard range > 0 else { continue }

            let deviation: Double
            if state.value < comfort.lowerBound {
                deviation = (comfort.lowerBound - state.value) / range
            } else if state.value > comfort.upperBound {
                deviation = (state.value - comfort.upperBound) / range
            } else {
                deviation = 0.0
            }

            totalScore += Swift.max(0.0, 1.0 - deviation)
            count += 1
        }

        guard count > 0 else { return 0.5 }
        return totalScore / Double(count)
    }

    public init(environmentClass: EnvironmentClass, dimensions: [EnvironmentDimension: DimensionState] = [:]) {
        self.timestamp = Date()
        self.environmentClass = environmentClass
        self.dimensions = dimensions
    }
}

/// Zustand einer einzelnen Dimension
public struct DimensionState: Sendable {
    public let value: Double
    public let confidence: Double    // 0–1 Sensor-Vertrauen
    public let trend: Double         // Änderungsrate pro Sekunde
    public let sensorID: String?

    public init(value: Double, confidence: Double = 1.0, trend: Double = 0.0, sensorID: String? = nil) {
        self.value = value
        self.confidence = confidence
        self.trend = trend
        self.sensorID = sensorID
    }
}

// MARK: - Environment Transition

/// Übergang zwischen zwei Environments (z.B. Auto → Gebäude, Tauchen → Oberfläche)
public struct EnvironmentTransition: Sendable {
    public let from: EnvironmentClass
    public let to: EnvironmentClass
    public let startTime: Date
    public let estimatedDuration: TimeInterval
    public let blendFactor: Double  // 0 = voll "from", 1 = voll "to"

    /// Ist der Übergang physiologisch kritisch? (Druckausgleich, Temperaturschwankung, etc.)
    public var isCritical: Bool {
        // Domänenwechsel sind immer kritisch
        if from.domain != to.domain { return true }
        // Bestimmte Übergänge innerhalb einer Domäne auch
        switch (from, to) {
        case (.deepSea, .freshwater), (.deepSea, .ocean):
            return true  // Dekompressionsgefahr
        case (.highAltitude, .lowAltitude), (.stratosphere, .highAltitude):
            return true  // Druckwechsel
        case (.cryoChamber, _), (_, .cryoChamber):
            return true  // Extremer Temperaturwechsel
        case (.sauna, _):
            return true  // Kreislaufbelastung
        default:
            return false
        }
    }
}

// MARK: - Universal Environment Engine

/// Universelle Engine, die JEDES Environment modelliert und in bio-reaktive
/// Audio/Visual-Signale transformiert. λ∞ Loop-kompatibel.
@MainActor
public class UniversalEnvironmentEngine: ObservableObject {

    public static let shared = UniversalEnvironmentEngine()

    // MARK: - Published State

    @Published public var currentEnvironment: EnvironmentClass = .home
    @Published public var stateVector: EnvironmentStateVector
    @Published public var comfortScore: Double = 0.5
    @Published public var isMonitoring: Bool = false
    @Published public var activeTransition: EnvironmentTransition? = nil
    @Published public var environmentHistory: [EnvironmentClass] = []

    // MARK: - Configuration

    @Published public var autoDetectEnvironment: Bool = true
    @Published public var bioReactiveMappingEnabled: Bool = true
    @Published public var transitionAlertEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.stateVector = EnvironmentStateVector(environmentClass: .home)
    }

    // MARK: - Environment Lifecycle

    /// Environment manuell setzen
    public func setEnvironment(_ env: EnvironmentClass) {
        let previous = currentEnvironment
        if previous != env {
            let transition = EnvironmentTransition(
                from: previous,
                to: env,
                startTime: Date(),
                estimatedDuration: 30.0,
                blendFactor: 0.0
            )
            activeTransition = transition
            environmentHistory.append(previous)
        }
        currentEnvironment = env
        stateVector = EnvironmentStateVector(environmentClass: env)
    }

    /// Monitoring starten
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
    }

    /// Monitoring stoppen
    public func stopMonitoring() {
        isMonitoring = false
    }

    // MARK: - Dimension Updates

    /// Einzelne Dimension updaten (von IoT-Sensor, GPS, Barometer, etc.)
    public func updateDimension(_ dimension: EnvironmentDimension, state: DimensionState) {
        stateVector.dimensions[dimension] = state
        comfortScore = stateVector.comfortScore
    }

    /// Mehrere Dimensionen gleichzeitig updaten
    public func updateDimensions(_ updates: [EnvironmentDimension: DimensionState]) {
        for (dim, state) in updates {
            stateVector.dimensions[dim] = state
        }
        comfortScore = stateVector.comfortScore
    }

    // MARK: - Bio-Reactive Output

    /// Environment → Kohärenz-Modifier (kombiniert Komfort + Environment-Affinität)
    public var coherenceModifier: Double {
        guard bioReactiveMappingEnabled else { return 0.0 }
        let comfort = comfortScore
        let affinity = currentEnvironment.baseCoherenceAffinity
        let blended = (comfort * 0.6 + affinity * 0.4)
        return (blended - 0.5) * 0.3  // ±0.15
    }

    /// Empfohlene Carrier-Frequenz basierend auf Environment (12-TET)
    public var recommendedCarrierFrequency: Double {
        switch currentEnvironment.domain {
        case .aquatic:
            return 440.0    // A4 standard
        case .aerial:
            return 523.251  // C5
        case .extraterrestrial:
            return 392.0    // G4
        case .subterranean:
            return 261.626  // C4 (middle C, 12-TET)
        case .vehicular:
            return 440.0    // A4 standard
        case .terrestrial:
            return 440.0    // A4 standard
        }
    }

    /// Empfohlene Entrainment-Frequenz (Hz) basierend auf Komfort
    public var recommendedEntrainmentFrequency: Double {
        let comfort = comfortScore
        // Niedriger Komfort → beruhigendes Theta
        // Hoher Komfort → energetisches Alpha/Beta
        return 4.0 + comfort * 16.0  // 4–20 Hz
    }

    /// Ambient-Farbe basierend auf Environment-Domäne und Komfort
    public var ambientColor: (r: Float, g: Float, b: Float) {
        let domainColor = currentEnvironment.domain.baseColor
        let comfort = Float(comfortScore)
        // Hoher Komfort → satte Domänenfarbe, niedriger → entsättigt
        return (
            r: domainColor.r * comfort + 0.4 * (1 - comfort),
            g: domainColor.g * comfort + 0.4 * (1 - comfort),
            b: domainColor.b * comfort + 0.4 * (1 - comfort)
        )
    }

    /// Spatial Audio Anpassung basierend auf Medium
    public var spatialAudioConfig: SpatialAudioEnvironmentConfig {
        let domain = currentEnvironment.domain
        return SpatialAudioEnvironmentConfig(
            speedOfSound: domain.speedOfSound,
            reverbPreset: domain.reverbPreset,
            attenuationFactor: domain.attenuationFactor,
            dopplerEnabled: domain != .extraterrestrial
        )
    }
}

// MARK: - Domain Extensions

extension EnvironmentDomain {
    /// Basis-Visualisierungsfarbe pro Domäne
    public var baseColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .terrestrial: return (0.2, 0.8, 0.3)       // Grün
        case .aquatic: return (0.1, 0.4, 0.9)           // Tiefblau
        case .aerial: return (0.5, 0.8, 1.0)            // Himmelsblau
        case .extraterrestrial: return (0.15, 0.0, 0.3) // Tiefviolett
        case .vehicular: return (0.8, 0.5, 0.1)         // Warm-Orange
        case .subterranean: return (0.5, 0.35, 0.2)     // Erdbraun
        }
    }

    /// Reverb-Preset für Spatial Audio
    public var reverbPreset: String {
        switch self {
        case .terrestrial: return "medium_room"
        case .aquatic: return "underwater_cathedral"
        case .aerial: return "open_air_infinite"
        case .extraterrestrial: return "vacuum_resonance"
        case .vehicular: return "enclosed_cabin"
        case .subterranean: return "deep_cave"
        }
    }

    /// Schall-Abschwächungsfaktor
    public var attenuationFactor: Double {
        switch self {
        case .terrestrial: return 1.0
        case .aquatic: return 0.5       // Weniger Abschwächung in Wasser
        case .aerial: return 1.5        // Mehr Abschwächung in dünner Luft
        case .extraterrestrial: return 100.0  // Quasi kein Schall
        case .vehicular: return 0.7     // Reflektionen im Innenraum
        case .subterranean: return 0.8  // Höhlen-Echo
        }
    }
}

// MARK: - Spatial Audio Config

/// Konfiguration für domänenspezifisches Spatial Audio
public struct SpatialAudioEnvironmentConfig: Sendable {
    public let speedOfSound: Double
    public let reverbPreset: String
    public let attenuationFactor: Double
    public let dopplerEnabled: Bool
}
