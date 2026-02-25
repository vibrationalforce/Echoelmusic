// EnvironmentPresets.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
//
// Vorkonfigurierte Environment-Presets für alle Domänen
// Jedes Preset definiert erwartete Sensorwerte, optimale Bereiche,
// Spatial Audio Konfiguration und bio-reaktive Mapping-Parameter
//
// "When I grow up, I want to be a principal or a caterpillar" - Ralph Wiggum
//
// ═══════════════════════════════════════════════════════════════════════════════
// DISCLAIMER: Creative/artistic wellness tool. NOT safety equipment.
// In Extremumgebungen (Tiefsee, Höhe, Weltraum) IMMER professionelle
// Sicherheitsausrüstung verwenden!
// ═══════════════════════════════════════════════════════════════════════════════
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation

// MARK: - Environment Preset

/// Vollständiges Preset für ein Environment
public struct EnvironmentPreset: Sendable {
    public let name: String
    public let environmentClass: EnvironmentClass
    public let description: String
    public let expectedDimensions: [EnvironmentDimension: ExpectedRange]
    public let audioProfile: EnvironmentAudioProfile
    public let visualProfile: EnvironmentVisualProfile
    public let safetyNotes: [String]
}

/// Erwarteter Wertebereich einer Dimension in einem Environment
public struct ExpectedRange: Sendable {
    public let typical: ClosedRange<Double>
    public let extreme: ClosedRange<Double>
    public let unit: String
}

/// Audio-Profil für ein Environment
public struct EnvironmentAudioProfile: Sendable {
    public let baseFrequency: Double
    public let reverbMix: Float          // 0–1
    public let reverbDecay: Float        // Sekunden
    public let lowPassCutoff: Float      // Hz
    public let highPassCutoff: Float     // Hz
    public let dopplerIntensity: Float   // 0–1
    public let spatialWidth: Float       // 0–1 (0 = mono, 1 = voll immersiv)
    public let dynamicRange: Float       // dB
}

/// Visuelles Profil für ein Environment
public struct EnvironmentVisualProfile: Sendable {
    public let primaryColor: (r: Float, g: Float, b: Float)
    public let secondaryColor: (r: Float, g: Float, b: Float)
    public let particleDensity: Float    // 0–1
    public let motionBlur: Float         // 0–1
    public let lightIntensity: Float     // 0–1
    public let fogDensity: Float         // 0–1
}

// MARK: - Preset Registry

/// Registry aller verfügbaren Environment-Presets
public enum EnvironmentPresetRegistry {

    // MARK: - Aquatic Presets

    public static let scubaDive = EnvironmentPreset(
        name: "Gerätetauchen",
        environmentClass: .ocean,
        description: "SCUBA-Tauchen im offenen Ozean, 10-40m Tiefe",
        expectedDimensions: [
            .depth: ExpectedRange(typical: 10...30, extreme: 0...60, unit: "m"),
            .temperature: ExpectedRange(typical: 15...25, extreme: 2...35, unit: "°C"),
            .pressure: ExpectedRange(typical: 2000...5000, extreme: 1000...7000, unit: "hPa"),
            .visibility: ExpectedRange(typical: 5...30, extreme: 0.5...50, unit: "m"),
            .current: ExpectedRange(typical: 0.0...0.5, extreme: 0.0...3.0, unit: "m/s"),
            .salinity: ExpectedRange(typical: 33...37, extreme: 30...40, unit: "‰")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 432.0,
            reverbMix: 0.8,
            reverbDecay: 4.0,
            lowPassCutoff: 2000,
            highPassCutoff: 20,
            dopplerIntensity: 0.3,
            spatialWidth: 0.9,
            dynamicRange: 40
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.0, 0.2, 0.6),
            secondaryColor: (0.0, 0.5, 0.8),
            particleDensity: 0.7,
            motionBlur: 0.3,
            lightIntensity: 0.4,
            fogDensity: 0.5
        ),
        safetyNotes: [
            "Dekompressionsstopps einhalten",
            "Aufstiegsgeschwindigkeit max. 9m/min",
            "Druckausgleich alle 3m beim Abstieg"
        ]
    )

    public static let deepSeaSubmersible = EnvironmentPreset(
        name: "Tiefsee-Tauchfahrt",
        environmentClass: .deepSea,
        description: "Tiefseeforschung in Submersible, 200-11000m",
        expectedDimensions: [
            .depth: ExpectedRange(typical: 200...4000, extreme: 0...11000, unit: "m"),
            .temperature: ExpectedRange(typical: 1...4, extreme: -2...15, unit: "°C"),
            .pressure: ExpectedRange(typical: 20000...400000, extreme: 1000...1100000, unit: "hPa"),
            .lightPenetration: ExpectedRange(typical: 0...0, extreme: 0...1, unit: "m")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 256.0,
            reverbMix: 0.95,
            reverbDecay: 8.0,
            lowPassCutoff: 800,
            highPassCutoff: 10,
            dopplerIntensity: 0.1,
            spatialWidth: 1.0,
            dynamicRange: 30
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.0, 0.02, 0.1),
            secondaryColor: (0.0, 0.3, 0.5),
            particleDensity: 0.2,
            motionBlur: 0.1,
            lightIntensity: 0.05,
            fogDensity: 0.9
        ),
        safetyNotes: [
            "Nur in zertifizierten Druckkörpern",
            "Lebenserhaltung prüfen",
            "Kommunikation mit Oberfläche sicherstellen"
        ]
    )

    public static let aquaponicsLab = EnvironmentPreset(
        name: "Aquaponik-Labor",
        environmentClass: .greenhouse,
        description: "Geschlossenes Aquaponik-Kreislaufsystem",
        expectedDimensions: [
            .temperature: ExpectedRange(typical: 22...28, extreme: 18...35, unit: "°C"),
            .humidity: ExpectedRange(typical: 60...80, extreme: 40...95, unit: "%"),
            .pH: ExpectedRange(typical: 6.0...7.5, extreme: 5.0...9.0, unit: ""),
            .dissolvedOxygen: ExpectedRange(typical: 5...8, extreme: 2...14, unit: "mg/L"),
            .lightLevel: ExpectedRange(typical: 5000...20000, extreme: 200...50000, unit: "lux")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 528.0,
            reverbMix: 0.4,
            reverbDecay: 1.5,
            lowPassCutoff: 8000,
            highPassCutoff: 40,
            dopplerIntensity: 0.0,
            spatialWidth: 0.6,
            dynamicRange: 50
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.1, 0.7, 0.3),
            secondaryColor: (0.0, 0.4, 0.8),
            particleDensity: 0.3,
            motionBlur: 0.0,
            lightIntensity: 0.7,
            fogDensity: 0.1
        ),
        safetyNotes: []
    )

    // MARK: - Aerial Presets

    public static let paragliding = EnvironmentPreset(
        name: "Paragliding",
        environmentClass: .lowAltitude,
        description: "Gleitschirmfliegen, 500-3000m über Grund",
        expectedDimensions: [
            .altitude: ExpectedRange(typical: 500...2500, extreme: 0...5000, unit: "m"),
            .temperature: ExpectedRange(typical: 5...20, extreme: -10...35, unit: "°C"),
            .windSpeed: ExpectedRange(typical: 2...8, extreme: 0...20, unit: "m/s"),
            .turbulence: ExpectedRange(typical: 0...2, extreme: 0...8, unit: "m/s²"),
            .pressure: ExpectedRange(typical: 750...950, extreme: 500...1013, unit: "hPa"),
            .uvRadiation: ExpectedRange(typical: 3...8, extreme: 0...12, unit: "UV-Index")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 528.0,
            reverbMix: 0.1,
            reverbDecay: 0.5,
            lowPassCutoff: 12000,
            highPassCutoff: 100,
            dopplerIntensity: 0.8,
            spatialWidth: 1.0,
            dynamicRange: 70
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.4, 0.7, 1.0),
            secondaryColor: (0.9, 0.9, 1.0),
            particleDensity: 0.1,
            motionBlur: 0.4,
            lightIntensity: 0.95,
            fogDensity: 0.2
        ),
        safetyNotes: [
            "Thermik und Windscherungen beachten",
            "Luftraumklassifizierung prüfen",
            "Rettungsschirm immer einsatzbereit"
        ]
    )

    public static let eVTOLFlight = EnvironmentPreset(
        name: "eVTOL Flugtaxi",
        environmentClass: .eVTOL,
        description: "Elektrisches Senkrechtstarter-Flugtaxi, Urban Air Mobility",
        expectedDimensions: [
            .altitude: ExpectedRange(typical: 100...600, extreme: 0...1000, unit: "m"),
            .velocity: ExpectedRange(typical: 50...250, extreme: 0...350, unit: "km/h"),
            .noise: ExpectedRange(typical: 55...70, extreme: 50...85, unit: "dB(A)"),
            .vibration: ExpectedRange(typical: 0.1...0.5, extreme: 0...2, unit: "m/s²"),
            .temperature: ExpectedRange(typical: 20...24, extreme: 15...30, unit: "°C")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 440.0,
            reverbMix: 0.2,
            reverbDecay: 0.8,
            lowPassCutoff: 6000,
            highPassCutoff: 80,
            dopplerIntensity: 0.5,
            spatialWidth: 0.7,
            dynamicRange: 45
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.3, 0.6, 0.9),
            secondaryColor: (0.6, 0.3, 0.8),
            particleDensity: 0.05,
            motionBlur: 0.6,
            lightIntensity: 0.8,
            fogDensity: 0.15
        ),
        safetyNotes: [
            "Gurt anlegen",
            "Flugbewegungen nicht stören",
            "Notfall-Autoland-System vorhanden"
        ]
    )

    public static let stratosphericBalloon = EnvironmentPreset(
        name: "Stratosphären-Ballon",
        environmentClass: .stratosphere,
        description: "Touristischer Stratosphärenflug, 25-35km Höhe",
        expectedDimensions: [
            .altitude: ExpectedRange(typical: 25000...35000, extreme: 18000...40000, unit: "m"),
            .temperature: ExpectedRange(typical: -56...(-40), extreme: -70...(-20), unit: "°C"),
            .pressure: ExpectedRange(typical: 10...50, extreme: 3...100, unit: "hPa"),
            .radiation: ExpectedRange(typical: 5...15, extreme: 1...50, unit: "µSv/h"),
            .uvRadiation: ExpectedRange(typical: 8...12, extreme: 5...15, unit: "UV-Index")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 396.0,
            reverbMix: 0.0,
            reverbDecay: 0.0,
            lowPassCutoff: 4000,
            highPassCutoff: 30,
            dopplerIntensity: 0.0,
            spatialWidth: 1.0,
            dynamicRange: 60
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.0, 0.0, 0.15),
            secondaryColor: (0.3, 0.5, 1.0),
            particleDensity: 0.0,
            motionBlur: 0.0,
            lightIntensity: 1.0,
            fogDensity: 0.0
        ),
        safetyNotes: [
            "Druckkabine erforderlich",
            "Strahlenschutz beachten",
            "UV-Schutz Klasse 4"
        ]
    )

    // MARK: - Extraterrestrial Presets

    public static let orbitalStation = EnvironmentPreset(
        name: "Orbitale Raumstation",
        environmentClass: .orbit,
        description: "ISS-ähnliche Raumstation, 400km LEO",
        expectedDimensions: [
            .gravity: ExpectedRange(typical: 0.0...0.001, extreme: 0.0...0.01, unit: "g"),
            .radiation: ExpectedRange(typical: 10...30, extreme: 5...100, unit: "µSv/h"),
            .temperature: ExpectedRange(typical: 20...25, extreme: 18...27, unit: "°C"),
            .humidity: ExpectedRange(typical: 40...60, extreme: 25...75, unit: "%"),
            .co2: ExpectedRange(typical: 2000...5000, extreme: 1000...10000, unit: "ppm"),
            .noise: ExpectedRange(typical: 55...72, extreme: 50...80, unit: "dB(A)")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 396.0,
            reverbMix: 0.3,
            reverbDecay: 2.0,
            lowPassCutoff: 8000,
            highPassCutoff: 30,
            dopplerIntensity: 0.0,
            spatialWidth: 1.0,
            dynamicRange: 35
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.05, 0.0, 0.2),
            secondaryColor: (0.0, 0.3, 0.8),
            particleDensity: 0.0,
            motionBlur: 0.0,
            lightIntensity: 0.6,
            fogDensity: 0.0
        ),
        safetyNotes: [
            "Mikrogravitation — Orientierungsverlust möglich",
            "Strahlenbelastung monitoren",
            "CO₂-Level beachten — kognitive Beeinträchtigung ab 5000ppm"
        ]
    )

    // MARK: - Vehicle Presets

    public static let electricCar = EnvironmentPreset(
        name: "Elektroauto",
        environmentClass: .automobile,
        description: "Vollelektrisches Fahrzeug im Straßenverkehr",
        expectedDimensions: [
            .velocity: ExpectedRange(typical: 0...130, extreme: 0...250, unit: "km/h"),
            .acceleration: ExpectedRange(typical: 0.8...1.5, extreme: 0...3, unit: "g"),
            .noise: ExpectedRange(typical: 30...65, extreme: 25...80, unit: "dB(A)"),
            .vibration: ExpectedRange(typical: 0.05...0.3, extreme: 0...1, unit: "m/s²"),
            .temperature: ExpectedRange(typical: 20...24, extreme: 15...30, unit: "°C"),
            .co2: ExpectedRange(typical: 400...800, extreme: 380...2000, unit: "ppm")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 440.0,
            reverbMix: 0.15,
            reverbDecay: 0.5,
            lowPassCutoff: 10000,
            highPassCutoff: 50,
            dopplerIntensity: 0.6,
            spatialWidth: 0.5,
            dynamicRange: 50
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.6, 0.6, 0.7),
            secondaryColor: (0.2, 0.5, 0.3),
            particleDensity: 0.0,
            motionBlur: 0.5,
            lightIntensity: 0.5,
            fogDensity: 0.0
        ),
        safetyNotes: [
            "Nicht vom Fahren ablenken lassen",
            "Nur mit Audio-only Modus im Verkehr",
            "Visuelle Effekte nur für Beifahrer"
        ]
    )

    public static let highSpeedTrain = EnvironmentPreset(
        name: "Hochgeschwindigkeitszug",
        environmentClass: .train,
        description: "ICE / Shinkansen / TGV, 200-350 km/h",
        expectedDimensions: [
            .velocity: ExpectedRange(typical: 200...320, extreme: 0...380, unit: "km/h"),
            .vibration: ExpectedRange(typical: 0.05...0.2, extreme: 0...0.5, unit: "m/s²"),
            .noise: ExpectedRange(typical: 60...72, extreme: 55...80, unit: "dB(A)"),
            .pressure: ExpectedRange(typical: 990...1020, extreme: 950...1040, unit: "hPa"),
            .temperature: ExpectedRange(typical: 21...24, extreme: 18...28, unit: "°C")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 440.0,
            reverbMix: 0.2,
            reverbDecay: 0.6,
            lowPassCutoff: 8000,
            highPassCutoff: 60,
            dopplerIntensity: 0.4,
            spatialWidth: 0.4,
            dynamicRange: 45
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.5, 0.5, 0.6),
            secondaryColor: (0.3, 0.5, 0.7),
            particleDensity: 0.0,
            motionBlur: 0.7,
            lightIntensity: 0.4,
            fogDensity: 0.0
        ),
        safetyNotes: []
    )

    public static let sailboat = EnvironmentPreset(
        name: "Segelboot",
        environmentClass: .boat,
        description: "Segelboot auf See oder Küstengewässer",
        expectedDimensions: [
            .windSpeed: ExpectedRange(typical: 3...12, extreme: 0...30, unit: "m/s"),
            .temperature: ExpectedRange(typical: 12...28, extreme: 0...38, unit: "°C"),
            .humidity: ExpectedRange(typical: 60...90, extreme: 40...100, unit: "%"),
            .vibration: ExpectedRange(typical: 0.2...1.0, extreme: 0...5, unit: "m/s²"),
            .noise: ExpectedRange(typical: 40...65, extreme: 30...85, unit: "dB(A)"),
            .uvRadiation: ExpectedRange(typical: 4...9, extreme: 0...12, unit: "UV-Index")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 432.0,
            reverbMix: 0.1,
            reverbDecay: 0.3,
            lowPassCutoff: 14000,
            highPassCutoff: 30,
            dopplerIntensity: 0.2,
            spatialWidth: 1.0,
            dynamicRange: 65
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.1, 0.3, 0.7),
            secondaryColor: (0.9, 0.9, 1.0),
            particleDensity: 0.4,
            motionBlur: 0.2,
            lightIntensity: 0.9,
            fogDensity: 0.3
        ),
        safetyNotes: [
            "Seekrankheit möglich — Horizont fixieren",
            "UV-Schutz auf dem Wasser besonders wichtig"
        ]
    )

    // MARK: - Subterranean Presets

    public static let caveExploration = EnvironmentPreset(
        name: "Höhlenforschung",
        environmentClass: .cave,
        description: "Speläologie in natürlichen Höhlen",
        expectedDimensions: [
            .temperature: ExpectedRange(typical: 8...14, extreme: 0...25, unit: "°C"),
            .humidity: ExpectedRange(typical: 85...100, extreme: 60...100, unit: "%"),
            .noise: ExpectedRange(typical: 15...30, extreme: 10...50, unit: "dB(A)"),
            .lightLevel: ExpectedRange(typical: 0...0, extreme: 0...10, unit: "lux"),
            .radon: ExpectedRange(typical: 100...500, extreme: 0...5000, unit: "Bq/m³"),
            .co2: ExpectedRange(typical: 600...2000, extreme: 380...10000, unit: "ppm")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 256.0,
            reverbMix: 0.9,
            reverbDecay: 6.0,
            lowPassCutoff: 6000,
            highPassCutoff: 20,
            dopplerIntensity: 0.0,
            spatialWidth: 1.0,
            dynamicRange: 40
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.1, 0.08, 0.05),
            secondaryColor: (0.3, 0.2, 0.15),
            particleDensity: 0.15,
            motionBlur: 0.0,
            lightIntensity: 0.02,
            fogDensity: 0.4
        ),
        safetyNotes: [
            "Radon-Belastung begrenzen (max. 2-4h)",
            "Immer mindestens 3 Lichtquellen",
            "Kletter- und Atemschutzausrüstung"
        ]
    )

    // MARK: - Wellness Presets

    public static let floatTankSession = EnvironmentPreset(
        name: "Floattank-Session",
        environmentClass: .floatTank,
        description: "Sensorische Deprivation in Magnesiumsulfat-Lösung",
        expectedDimensions: [
            .temperature: ExpectedRange(typical: 34.5...35.5, extreme: 33...37, unit: "°C"),
            .salinity: ExpectedRange(typical: 250...280, extreme: 200...350, unit: "‰"),
            .noise: ExpectedRange(typical: 0...10, extreme: 0...20, unit: "dB(A)"),
            .lightLevel: ExpectedRange(typical: 0...0, extreme: 0...5, unit: "lux"),
            .humidity: ExpectedRange(typical: 90...100, extreme: 80...100, unit: "%")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 432.0,
            reverbMix: 0.6,
            reverbDecay: 3.0,
            lowPassCutoff: 2000,
            highPassCutoff: 10,
            dopplerIntensity: 0.0,
            spatialWidth: 1.0,
            dynamicRange: 20
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.0, 0.0, 0.0),
            secondaryColor: (0.05, 0.0, 0.1),
            particleDensity: 0.0,
            motionBlur: 0.0,
            lightIntensity: 0.0,
            fogDensity: 0.0
        ),
        safetyNotes: [
            "Maximale Kohärenz-Förderung möglich",
            "Ideale Umgebung für Theta-Entrainment"
        ]
    )

    // MARK: - Research Institute Preset

    public static let bahrenfeldBrache = EnvironmentPreset(
        name: "Brache Bahrenfeld",
        environmentClass: .greenhouse,
        description: "Forschungsinstitut für Bewegung, Freiraum, Wasser und Pflanzen/Ernährung",
        expectedDimensions: [
            .temperature: ExpectedRange(typical: 15...28, extreme: -5...38, unit: "°C"),
            .humidity: ExpectedRange(typical: 40...75, extreme: 20...100, unit: "%"),
            .airQuality: ExpectedRange(typical: 20...50, extreme: 0...100, unit: "AQI"),
            .noise: ExpectedRange(typical: 30...55, extreme: 20...75, unit: "dB(A)"),
            .lightLevel: ExpectedRange(typical: 2000...50000, extreme: 0...100000, unit: "lux"),
            .pH: ExpectedRange(typical: 6.0...7.5, extreme: 5.0...9.0, unit: ""),
            .dissolvedOxygen: ExpectedRange(typical: 6...12, extreme: 2...14, unit: "mg/L")
        ],
        audioProfile: EnvironmentAudioProfile(
            baseFrequency: 432.0,
            reverbMix: 0.3,
            reverbDecay: 1.5,
            lowPassCutoff: 12000,
            highPassCutoff: 30,
            dopplerIntensity: 0.1,
            spatialWidth: 0.8,
            dynamicRange: 60
        ),
        visualProfile: EnvironmentVisualProfile(
            primaryColor: (0.2, 0.7, 0.3),
            secondaryColor: (0.1, 0.5, 0.8),
            particleDensity: 0.2,
            motionBlur: 0.0,
            lightIntensity: 0.8,
            fogDensity: 0.1
        ),
        safetyNotes: []
    )

    // MARK: - All Presets

    public static let all: [EnvironmentPreset] = [
        scubaDive, deepSeaSubmersible, aquaponicsLab,
        paragliding, eVTOLFlight, stratosphericBalloon,
        orbitalStation,
        electricCar, highSpeedTrain, sailboat,
        caveExploration,
        floatTankSession,
        bahrenfeldBrache
    ]

    /// Preset für eine EnvironmentClass finden
    public static func preset(for environmentClass: EnvironmentClass) -> EnvironmentPreset? {
        all.first { $0.environmentClass == environmentClass }
    }
}
