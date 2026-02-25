// WaterQualityEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Wasserqualitäts-Monitoring für Forschungsinstitut Brache Bahrenfeld
// IoT-Sensorintegration für Trinkwasser, Brauchwasser und Umgebungsgewässer
//
// Unterstützt: pH, Temperatur, Leitfähigkeit, Trübung, Sauerstoffgehalt,
// Chlor, Nitrat, TDS, Durchfluss, ORP, Schwermetalle
//
// HINWEIS: Kein medizinisches Gerät. Alle Messwerte dienen der
// Forschung und dem allgemeinen Wellness-Monitoring.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Water Quality Parameter Types

/// Messbare Wasserqualitäts-Parameter
public enum WaterQualityParameter: String, CaseIterable, Codable, Sendable {
    case pH = "pH"
    case temperature = "Temperatur"
    case conductivity = "Leitfähigkeit"
    case turbidity = "Trübung"
    case dissolvedOxygen = "Gelöster Sauerstoff"
    case chlorine = "Chlor"
    case nitrate = "Nitrat"
    case totalDissolvedSolids = "TDS"
    case flowRate = "Durchfluss"
    case oxidationReductionPotential = "ORP"
    case heavyMetals = "Schwermetalle"

    /// Einheit der Messung
    public var unit: String {
        switch self {
        case .pH: return ""
        case .temperature: return "°C"
        case .conductivity: return "µS/cm"
        case .turbidity: return "NTU"
        case .dissolvedOxygen: return "mg/L"
        case .chlorine: return "mg/L"
        case .nitrate: return "mg/L"
        case .totalDissolvedSolids: return "ppm"
        case .flowRate: return "L/min"
        case .oxidationReductionPotential: return "mV"
        case .heavyMetals: return "µg/L"
        }
    }

    /// Optimaler Bereich für Trinkwasser (WHO-Richtlinien)
    public var optimalRange: ClosedRange<Double> {
        switch self {
        case .pH: return 6.5...8.5
        case .temperature: return 8.0...25.0
        case .conductivity: return 200.0...800.0
        case .turbidity: return 0.0...4.0
        case .dissolvedOxygen: return 6.0...14.0
        case .chlorine: return 0.2...0.5
        case .nitrate: return 0.0...50.0
        case .totalDissolvedSolids: return 50.0...500.0
        case .flowRate: return 0.5...50.0
        case .oxidationReductionPotential: return 200.0...600.0
        case .heavyMetals: return 0.0...10.0
        }
    }

    /// Abtastrate des IoT-Sensors in Hz
    public var sensorSampleRate: Double {
        switch self {
        case .pH: return 0.1                   // alle 10s
        case .temperature: return 0.2          // alle 5s
        case .conductivity: return 0.1
        case .turbidity: return 0.5            // alle 2s (optisch)
        case .dissolvedOxygen: return 0.05     // alle 20s (elektrochemisch)
        case .chlorine: return 0.05
        case .nitrate: return 0.02             // alle 50s (spektrophotometrisch)
        case .totalDissolvedSolids: return 0.1
        case .flowRate: return 1.0             // jede Sekunde
        case .oxidationReductionPotential: return 0.1
        case .heavyMetals: return 0.01         // alle 100s (aufwändig)
        }
    }
}

// MARK: - Water Source Types

/// Wasserquelle im Forschungsinstitut
public enum WaterSourceType: String, CaseIterable, Codable, Sendable {
    case drinkingWater = "Trinkwasser"
    case greyWater = "Brauchwasser"
    case rainwater = "Regenwasser"
    case groundwater = "Grundwasser"
    case surfaceWater = "Oberflächengewässer"
    case irrigationWater = "Bewässerungswasser"
    case aquaponics = "Aquaponik-Kreislauf"

    /// Prioritäts-Parameter für diese Quelle
    public var priorityParameters: [WaterQualityParameter] {
        switch self {
        case .drinkingWater:
            return [.pH, .chlorine, .turbidity, .heavyMetals, .nitrate]
        case .greyWater:
            return [.pH, .turbidity, .conductivity, .totalDissolvedSolids]
        case .rainwater:
            return [.pH, .conductivity, .heavyMetals, .turbidity]
        case .groundwater:
            return [.pH, .nitrate, .heavyMetals, .conductivity, .dissolvedOxygen]
        case .surfaceWater:
            return [.dissolvedOxygen, .pH, .turbidity, .temperature, .nitrate]
        case .irrigationWater:
            return [.pH, .conductivity, .totalDissolvedSolids, .temperature]
        case .aquaponics:
            return [.pH, .dissolvedOxygen, .temperature, .nitrate, .conductivity]
        }
    }
}

// MARK: - Water Quality Reading

/// Einzelne Wasserqualitäts-Messung
public struct WaterQualityReading: Sendable {
    public let timestamp: Date
    public let source: WaterSourceType
    public let parameter: WaterQualityParameter
    public let value: Double
    public let sensorID: String

    /// Ist der Messwert im optimalen Bereich?
    public var isOptimal: Bool {
        parameter.optimalRange.contains(value)
    }

    /// Abweichung vom optimalen Bereich (0 = perfekt, >1 = außerhalb)
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

// MARK: - Water Quality Alert

/// Alarm bei Grenzwertüberschreitung
public enum WaterQualityAlertLevel: String, CaseIterable, Codable, Sendable {
    case normal = "Normal"
    case caution = "Vorsicht"
    case warning = "Warnung"
    case critical = "Kritisch"

    /// Farbe für bio-reaktive Visualisierung (R, G, B)
    public var visualColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .normal: return (0.0, 0.85, 0.4)     // Grün
        case .caution: return (1.0, 0.85, 0.0)    // Gelb
        case .warning: return (1.0, 0.5, 0.0)     // Orange
        case .critical: return (1.0, 0.1, 0.1)    // Rot
        }
    }

    /// Audio-Feedback Frequenz für Sonifikation
    public var sonificationFrequency: Double {
        switch self {
        case .normal: return 432.0     // Harmonisch
        case .caution: return 528.0    // Aufmerksamkeit
        case .warning: return 639.0    // Warnung
        case .critical: return 741.0   // Alarm
        }
    }
}

// MARK: - IoT Sensor Protocol

/// IoT-Kommunikationsprotokoll für Wassersensoren
public enum WaterSensorProtocol: String, CaseIterable, Codable, Sendable {
    case mqtt = "MQTT"
    case coap = "CoAP"
    case httpREST = "HTTP/REST"
    case modbusRTU = "Modbus RTU"
    case modbusTCP = "Modbus TCP"
    case bleGATT = "BLE GATT"
    case loraWAN = "LoRaWAN"

    /// Typische Latenz in Millisekunden
    public var typicalLatencyMs: Int {
        switch self {
        case .mqtt: return 50
        case .coap: return 30
        case .httpREST: return 100
        case .modbusRTU: return 10
        case .modbusTCP: return 20
        case .bleGATT: return 25
        case .loraWAN: return 2000
        }
    }
}

// MARK: - Water Quality Engine

/// Zentrale Engine für Wasserqualitäts-Monitoring
/// Verbindet IoT-Sensoren mit bio-reaktivem Audio/Visual-Feedback
@MainActor
public class WaterQualityEngine: ObservableObject {

    public static let shared = WaterQualityEngine()

    // MARK: - Published State

    @Published public var isMonitoring: Bool = false
    @Published public var connectedSensors: [WaterSensorNode] = []
    @Published public var latestReadings: [WaterSourceType: [WaterQualityParameter: WaterQualityReading]] = [:]
    @Published public var overallQualityScore: Double = 1.0  // 0.0 (schlecht) – 1.0 (optimal)
    @Published public var currentAlertLevel: WaterQualityAlertLevel = .normal
    @Published public var alertHistory: [WaterQualityAlert] = []

    // MARK: - Configuration

    @Published public var monitoringSources: Set<WaterSourceType> = [.drinkingWater]
    @Published public var alertThreshold: WaterQualityAlertLevel = .caution
    @Published public var sonificationEnabled: Bool = true
    @Published public var bioReactiveMappingEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Sensor Management

    /// IoT-Sensor registrieren
    public func registerSensor(_ sensor: WaterSensorNode) {
        guard !connectedSensors.contains(where: { $0.id == sensor.id }) else { return }
        connectedSensors.append(sensor)
    }

    /// Sensor entfernen
    public func removeSensor(id: String) {
        connectedSensors.removeAll { $0.id == id }
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
    public func processReading(_ reading: WaterQualityReading) {
        // Speichere letzte Messung
        var sourceReadings = latestReadings[reading.source] ?? [:]
        sourceReadings[reading.parameter] = reading
        latestReadings[reading.source] = sourceReadings

        // Qualitätsscore aktualisieren
        updateOverallQualityScore()

        // Alert prüfen
        evaluateAlerts(for: reading)
    }

    // MARK: - Quality Score Calculation

    /// Gesamtqualitätsscore berechnen
    private func updateOverallQualityScore() {
        var totalDeviation: Double = 0.0
        var readingCount: Int = 0

        for (_, paramReadings) in latestReadings {
            for (_, reading) in paramReadings {
                totalDeviation += reading.deviationFromOptimal
                readingCount += 1
            }
        }

        guard readingCount > 0 else {
            overallQualityScore = 1.0
            return
        }

        let avgDeviation = totalDeviation / Double(readingCount)
        overallQualityScore = Swift.max(0.0, 1.0 - avgDeviation)
    }

    // MARK: - Alert Evaluation

    /// Alert-Level für einzelne Messung bewerten
    private func evaluateAlerts(for reading: WaterQualityReading) {
        let deviation = reading.deviationFromOptimal

        let level: WaterQualityAlertLevel
        if deviation == 0 {
            level = .normal
        } else if deviation < 0.3 {
            level = .caution
        } else if deviation < 0.7 {
            level = .warning
        } else {
            level = .critical
        }

        if level != .normal {
            let alert = WaterQualityAlert(
                timestamp: reading.timestamp,
                source: reading.source,
                parameter: reading.parameter,
                level: level,
                value: reading.value,
                message: "\(reading.parameter.rawValue) bei \(reading.source.rawValue): \(reading.value) \(reading.parameter.unit) — \(level.rawValue)"
            )
            alertHistory.append(alert)
        }

        // Höchstes aktives Alert-Level setzen
        currentAlertLevel = level
    }

    // MARK: - Bio-Reactive Mapping

    /// Wasserqualität → Kohärenz-Einfluss für bio-reaktive Audio/Visuals
    public var waterCoherenceModifier: Double {
        guard bioReactiveMappingEnabled else { return 0.0 }
        // Hohe Wasserqualität → positive Kohärenz-Modulation
        return (overallQualityScore - 0.5) * 0.2  // ±0.1 Kohärenz-Einfluss
    }

    /// Empfohlene Umgebungsfarbe basierend auf Wasserqualität
    public var ambientColor: (r: Float, g: Float, b: Float) {
        let c = currentAlertLevel.visualColor
        let blend = Float(overallQualityScore)
        // Blend zwischen Alert-Farbe und beruhigendem Aqua-Blau
        return (
            r: c.r * (1 - blend) + 0.0 * blend,
            g: c.g * (1 - blend) + 0.7 * blend,
            b: c.b * (1 - blend) + 0.9 * blend
        )
    }
}

// MARK: - Supporting Types

/// IoT Sensor-Knoten im Netzwerk
public struct WaterSensorNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let source: WaterSourceType
    public let parameters: [WaterQualityParameter]
    public let protocolType: WaterSensorProtocol
    public let location: SensorLocation
    public let firmwareVersion: String
    public let calibrationDate: Date

    public init(id: String, name: String, source: WaterSourceType,
                parameters: [WaterQualityParameter], protocolType: WaterSensorProtocol,
                location: SensorLocation, firmwareVersion: String = "1.0.0",
                calibrationDate: Date = Date()) {
        self.id = id
        self.name = name
        self.source = source
        self.parameters = parameters
        self.protocolType = protocolType
        self.location = location
        self.firmwareVersion = firmwareVersion
        self.calibrationDate = calibrationDate
    }
}

/// Sensorposition im Forschungsgelände
public struct SensorLocation: Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let description: String  // z.B. "Aquaponik-Halle Nord", "Regenwasser-Zisterne"

    public init(latitude: Double, longitude: Double, altitude: Double = 0, description: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.description = description
    }
}

/// Wasserqualitäts-Alarm
public struct WaterQualityAlert: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date
    public let source: WaterSourceType
    public let parameter: WaterQualityParameter
    public let level: WaterQualityAlertLevel
    public let value: Double
    public let message: String
}
