// PlantBioReactiveEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Pflanzen-Gesundheits- und Ernährungs-Monitoring für Forschungsinstitut Brache Bahrenfeld
// Computer Vision, IoT-Bodensensoren, Spektralanalyse und Wachstumstracking
//
// Verbindet Pflanzen-Vitalität mit bio-reaktivem Audio/Visual-Feedback:
// Gesunde Pflanzen → harmonische Klänge, grüne Visuals, hohe Kohärenz
//
// HINWEIS: Forschungstool. Kein Ersatz für professionelle Agrarwissenschaft.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Plant Health Parameters

/// Messbare Pflanzen-Gesundheitsparameter
public enum PlantHealthParameter: String, CaseIterable, Codable, Sendable {
    case ndvi = "NDVI"                        // Normalized Difference Vegetation Index
    case chlorophyllContent = "Chlorophyll"    // Blattgrün-Gehalt
    case leafTemperature = "Blatttemperatur"
    case soilMoisture = "Bodenfeuchte"
    case soilPH = "Boden-pH"
    case soilNutrientN = "Stickstoff (N)"
    case soilNutrientP = "Phosphor (P)"
    case soilNutrientK = "Kalium (K)"
    case lightPAR = "PAR-Licht"               // Photosynthetically Active Radiation
    case growthRate = "Wachstumsrate"
    case waterStress = "Wasserstress"
    case pestPresence = "Schädlingsbefall"

    /// Einheit der Messung
    public var unit: String {
        switch self {
        case .ndvi: return ""                     // Index 0.0–1.0
        case .chlorophyllContent: return "µg/cm²"
        case .leafTemperature: return "°C"
        case .soilMoisture: return "%"
        case .soilPH: return ""
        case .soilNutrientN: return "mg/kg"
        case .soilNutrientP: return "mg/kg"
        case .soilNutrientK: return "mg/kg"
        case .lightPAR: return "µmol/m²/s"
        case .growthRate: return "mm/Tag"
        case .waterStress: return ""              // Index 0.0–1.0
        case .pestPresence: return ""             // Wahrscheinlichkeit 0.0–1.0
        }
    }

    /// Optimaler Bereich für gesundes Pflanzenwachstum
    public var optimalRange: ClosedRange<Double> {
        switch self {
        case .ndvi: return 0.6...0.9
        case .chlorophyllContent: return 30.0...80.0
        case .leafTemperature: return 18.0...28.0
        case .soilMoisture: return 40.0...70.0
        case .soilPH: return 6.0...7.0
        case .soilNutrientN: return 20.0...60.0
        case .soilNutrientP: return 10.0...40.0
        case .soilNutrientK: return 100.0...250.0
        case .lightPAR: return 200.0...800.0
        case .growthRate: return 1.0...10.0
        case .waterStress: return 0.0...0.3
        case .pestPresence: return 0.0...0.1
        }
    }

    /// Sensortyp für diesen Parameter
    public var sensorType: PlantSensorType {
        switch self {
        case .ndvi, .chlorophyllContent, .pestPresence:
            return .multispectralCamera
        case .leafTemperature:
            return .infraredThermometer
        case .soilMoisture, .soilPH, .soilNutrientN, .soilNutrientP, .soilNutrientK:
            return .soilProbe
        case .lightPAR:
            return .parSensor
        case .growthRate:
            return .computerVision
        case .waterStress:
            return .hyperspectralCamera
        }
    }
}

// MARK: - Sensor Types

/// Sensortypen für Pflanzen-Monitoring
public enum PlantSensorType: String, CaseIterable, Codable, Sendable {
    case multispectralCamera = "Multispektral-Kamera"
    case hyperspectralCamera = "Hyperspektral-Kamera"
    case infraredThermometer = "IR-Thermometer"
    case soilProbe = "Bodensonde"
    case parSensor = "PAR-Sensor"
    case computerVision = "Computer Vision"
    case dendrometer = "Dendrometer"
    case sapFlowSensor = "Saftfluss-Sensor"

    /// Typische Abtastrate in Hz
    public var sampleRate: Double {
        switch self {
        case .multispectralCamera: return 1.0       // 1 Bild/Sekunde
        case .hyperspectralCamera: return 0.5
        case .infraredThermometer: return 2.0
        case .soilProbe: return 0.017               // alle 60s
        case .parSensor: return 1.0
        case .computerVision: return 0.1             // alle 10s (ML-Inferenz)
        case .dendrometer: return 0.0003             // alle ~60min
        case .sapFlowSensor: return 0.017
        }
    }
}

// MARK: - Plant Species Categories

/// Pflanzenkategorien im Forschungsinstitut
public enum PlantCategory: String, CaseIterable, Codable, Sendable {
    case foodCrops = "Nahrungspflanzen"
    case medicinalHerbs = "Heilkräuter"
    case treeNursery = "Baumschule"
    case aquaponicPlants = "Aquaponik-Pflanzen"
    case urbanGreenery = "Stadtbegrünung"
    case experimentalVarieties = "Versuchssorten"
    case pollinatorGarden = "Bestäuber-Garten"

    /// Schlüsselparameter für diese Kategorie
    public var keyParameters: [PlantHealthParameter] {
        switch self {
        case .foodCrops:
            return [.ndvi, .soilNutrientN, .soilMoisture, .growthRate, .pestPresence]
        case .medicinalHerbs:
            return [.chlorophyllContent, .soilPH, .lightPAR, .waterStress]
        case .treeNursery:
            return [.ndvi, .growthRate, .soilMoisture, .leafTemperature]
        case .aquaponicPlants:
            return [.ndvi, .soilNutrientN, .soilNutrientP, .lightPAR, .growthRate]
        case .urbanGreenery:
            return [.ndvi, .waterStress, .leafTemperature, .pestPresence]
        case .experimentalVarieties:
            return PlantHealthParameter.allCases
        case .pollinatorGarden:
            return [.ndvi, .chlorophyllContent, .pestPresence, .growthRate]
        }
    }

    /// Bio-reaktive Klanglandschaft für diese Kategorie
    public var soundscape: PlantSoundscape {
        switch self {
        case .foodCrops: return .earthTones
        case .medicinalHerbs: return .crystalline
        case .treeNursery: return .deepForest
        case .aquaponicPlants: return .waterFlow
        case .urbanGreenery: return .windRustle
        case .experimentalVarieties: return .synthesis
        case .pollinatorGarden: return .beeHarmony
        }
    }
}

/// Bio-reaktive Klanglandschaften für Pflanzen
public enum PlantSoundscape: String, CaseIterable, Codable, Sendable {
    case earthTones = "Erdtöne"
    case crystalline = "Kristallin"
    case deepForest = "Tiefwald"
    case waterFlow = "Wasserfluss"
    case windRustle = "Windrauschen"
    case synthesis = "Synthese"
    case beeHarmony = "Bienenharmonie"

    /// Grundfrequenz in Hz
    public var baseFrequency: Double {
        switch self {
        case .earthTones: return 128.0      // C3 — Erdverbundenheit
        case .crystalline: return 528.0     // C5 — Klarheit
        case .deepForest: return 64.0       // C2 — Tiefe
        case .waterFlow: return 256.0       // C4 — Fluss
        case .windRustle: return 512.0      // C5 — Luft
        case .synthesis: return 440.0       // A4 — Standard
        case .beeHarmony: return 220.0      // A3 — Summen
        }
    }
}

// MARK: - Plant Reading

/// Einzelne Pflanzen-Messung
public struct PlantHealthReading: Sendable {
    public let timestamp: Date
    public let plantID: String
    public let category: PlantCategory
    public let parameter: PlantHealthParameter
    public let value: Double
    public let sensorID: String

    /// Ist der Messwert im optimalen Bereich?
    public var isOptimal: Bool {
        parameter.optimalRange.contains(value)
    }

    /// Abweichung vom Optimum (0 = perfekt)
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

// MARK: - Nutrition Profile

/// Nährstoff-Profil für Ernährungsforschung
public struct NutritionProfile: Sendable {
    public let plantID: String
    public let harvestDate: Date
    public let vitamins: [NutrientMeasurement]
    public let minerals: [NutrientMeasurement]
    public let antioxidants: Double         // ORAC-Wert (µmol TE/g)
    public let waterContent: Double         // Prozent
    public let organicCertified: Bool

    /// Gesamte Nährstoffdichte (0–1 normalisiert)
    public var nutrientDensity: Double {
        let vitaminScore = vitamins.isEmpty ? 0.0 :
            vitamins.reduce(0.0) { $0 + Swift.min(1.0, $1.value / $1.dailyRecommended) } / Double(vitamins.count)
        let mineralScore = minerals.isEmpty ? 0.0 :
            minerals.reduce(0.0) { $0 + Swift.min(1.0, $1.value / $1.dailyRecommended) } / Double(minerals.count)
        return (vitaminScore + mineralScore) / 2.0
    }
}

/// Einzelne Nährstoff-Messung
public struct NutrientMeasurement: Sendable {
    public let name: String               // z.B. "Vitamin C", "Eisen"
    public let value: Double              // mg pro 100g
    public let dailyRecommended: Double   // Empfohlene Tagesdosis in mg
    public let unit: String
}

// MARK: - Plant Bio-Reactive Engine

/// Zentrale Engine für Pflanzen-Monitoring und bio-reaktives Mapping
@MainActor
public class PlantBioReactiveEngine: ObservableObject {

    public static let shared = PlantBioReactiveEngine()

    // MARK: - Published State

    @Published public var isMonitoring: Bool = false
    @Published public var registeredPlants: [PlantRecord] = []
    @Published public var latestReadings: [String: [PlantHealthParameter: PlantHealthReading]] = [:]
    @Published public var overallGardenHealth: Double = 1.0  // 0.0–1.0
    @Published public var activeAlerts: [PlantAlert] = []

    // MARK: - Configuration

    @Published public var bioReactiveMappingEnabled: Bool = true
    @Published public var soundscapeEnabled: Bool = true
    @Published public var visualFeedbackEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Plant Registration

    /// Pflanze registrieren
    public func registerPlant(_ plant: PlantRecord) {
        guard !registeredPlants.contains(where: { $0.id == plant.id }) else { return }
        registeredPlants.append(plant)
    }

    /// Pflanze entfernen
    public func removePlant(id: String) {
        registeredPlants.removeAll { $0.id == id }
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

    /// Neue Messung verarbeiten
    public func processReading(_ reading: PlantHealthReading) {
        var plantReadings = latestReadings[reading.plantID] ?? [:]
        plantReadings[reading.parameter] = reading
        latestReadings[reading.plantID] = plantReadings

        updateGardenHealth()
        evaluateAlerts(for: reading)
    }

    // MARK: - Garden Health

    /// Gesamte Gartengesundheit berechnen
    private func updateGardenHealth() {
        var totalDeviation: Double = 0.0
        var readingCount: Int = 0

        for (_, paramReadings) in latestReadings {
            for (_, reading) in paramReadings {
                totalDeviation += reading.deviationFromOptimal
                readingCount += 1
            }
        }

        guard readingCount > 0 else {
            overallGardenHealth = 1.0
            return
        }

        let avgDeviation = totalDeviation / Double(readingCount)
        overallGardenHealth = Swift.max(0.0, 1.0 - avgDeviation)
    }

    // MARK: - Alert Evaluation

    private func evaluateAlerts(for reading: PlantHealthReading) {
        let deviation = reading.deviationFromOptimal
        guard deviation > 0.2 else { return }

        let severity: PlantAlertSeverity = deviation > 0.7 ? .critical : deviation > 0.4 ? .warning : .info

        let alert = PlantAlert(
            timestamp: reading.timestamp,
            plantID: reading.plantID,
            parameter: reading.parameter,
            severity: severity,
            value: reading.value,
            message: "\(reading.parameter.rawValue) bei Pflanze \(reading.plantID): \(reading.value) \(reading.parameter.unit)"
        )
        activeAlerts.append(alert)
    }

    // MARK: - Bio-Reactive Mapping

    /// Gartengesundheit → Kohärenz-Einfluss
    public var gardenCoherenceModifier: Double {
        guard bioReactiveMappingEnabled else { return 0.0 }
        return (overallGardenHealth - 0.5) * 0.15
    }

    /// Empfohlene Ambient-Farbe basierend auf Gartengesundheit
    public var ambientColor: (r: Float, g: Float, b: Float) {
        let health = Float(overallGardenHealth)
        // Gesund → Sattes Grün, Krank → Bräunlich
        return (
            r: 0.3 * (1 - health) + 0.1 * health,
            g: 0.2 * (1 - health) + 0.8 * health,
            b: 0.1 * (1 - health) + 0.3 * health
        )
    }
}

// MARK: - Supporting Types

/// Pflanzendatensatz
public struct PlantRecord: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let species: String
    public let category: PlantCategory
    public let plantedDate: Date
    public let location: SensorLocation
    public let notes: String

    public init(id: String, name: String, species: String, category: PlantCategory,
                plantedDate: Date, location: SensorLocation, notes: String = "") {
        self.id = id
        self.name = name
        self.species = species
        self.category = category
        self.plantedDate = plantedDate
        self.location = location
        self.notes = notes
    }
}

/// Pflanzen-Alarm
public struct PlantAlert: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date
    public let plantID: String
    public let parameter: PlantHealthParameter
    public let severity: PlantAlertSeverity
    public let value: Double
    public let message: String
}

/// Alarm-Schweregrad
public enum PlantAlertSeverity: String, CaseIterable, Codable, Sendable {
    case info = "Info"
    case warning = "Warnung"
    case critical = "Kritisch"
}
