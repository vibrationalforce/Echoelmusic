// BahrenfeldResearchHub.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Zentraler Orchestrator für das Forschungsinstitut Brache Bahrenfeld
// Verbindet alle Forschungsbereiche:
//   - Bewegung (FreiraumEnvironmentEngine)
//   - Freiraum (Umgebungssensorik, Luftqualität)
//   - Wasser (WaterQualityEngine, Aquaponik)
//   - Pflanzen & Ernährung (PlantBioReactiveEngine)
//
// Übergreifende Kohärenz-Berechnung, Datenaggregation und
// bio-reaktives Mapping für alle Forschungsdomänen.
//
// Vision: Ein Ort, an dem Mensch, Natur, Wasser und Bewegung
// zusammenwirken — messbar, erlebbar, transformativ.
//
// HINWEIS: Forschungsplattform. Kein medizinisches Gerät.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Research Domains

/// Die vier Forschungssäulen des Instituts
public enum ResearchDomain: String, CaseIterable, Codable, Sendable {
    case movement = "Bewegung"
    case openSpace = "Freiraum"
    case water = "Wasser"
    case plantsNutrition = "Pflanzen & Ernährung"

    /// Beschreibung der Forschungssäule
    public var description: String {
        switch self {
        case .movement:
            return "Bewegungsforschung: Outdoor-Fitness, Yoga, Tai Chi, Laufen, Radfahren — Einfluss auf HRV-Kohärenz und Wohlbefinden"
        case .openSpace:
            return "Freiraumforschung: Luftqualität, Stadtklima, Lärm, Licht — Wirkung des Außenraums auf Gesundheit und Kreativität"
        case .water:
            return "Wasserforschung: Trinkwasserqualität, Aquaponik, Regenwasser, Gewässerschutz — Wasser als Lebensgrundlage"
        case .plantsNutrition:
            return "Pflanzen- und Ernährungsforschung: NDVI, Bodengesundheit, Nährstoffdichte, Heilkräuter — vom Boden auf den Teller"
        }
    }

    /// Zugeordnete Engine
    public var engineType: String {
        switch self {
        case .movement: return "FreiraumEnvironmentEngine (Bewegung)"
        case .openSpace: return "FreiraumEnvironmentEngine (Umgebung)"
        case .water: return "WaterQualityEngine"
        case .plantsNutrition: return "PlantBioReactiveEngine"
        }
    }

    /// Farbe für Dashboard-Visualisierung (R, G, B)
    public var domainColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .movement: return (0.95, 0.5, 0.2)     // Energetisches Orange
        case .openSpace: return (0.3, 0.7, 0.95)    // Himmelsblau
        case .water: return (0.1, 0.5, 0.9)         // Tiefes Blau
        case .plantsNutrition: return (0.2, 0.8, 0.3) // Lebendiges Grün
        }
    }
}

// MARK: - Institute Status

/// Betriebszustand des Forschungsinstituts
public enum InstituteOperationalStatus: String, CaseIterable, Codable, Sendable {
    case active = "Aktiv"
    case maintenance = "Wartung"
    case research = "Forschungsbetrieb"
    case publicOpen = "Öffentlich zugänglich"
    case event = "Veranstaltung"
    case closed = "Geschlossen"
}

// MARK: - Integrated Health Score

/// Übergreifender Gesundheitsscore aller Domänen
public struct IntegratedHealthScore: Sendable {
    public let timestamp: Date
    public let movementScore: Double       // 0–1
    public let environmentScore: Double    // 0–1
    public let waterScore: Double          // 0–1
    public let plantScore: Double          // 0–1

    /// Gewichteter Gesamtscore
    public var overallScore: Double {
        let weights = (movement: 0.25, environment: 0.25, water: 0.25, plant: 0.25)
        return movementScore * weights.movement
             + environmentScore * weights.environment
             + waterScore * weights.water
             + plantScore * weights.plant
    }

    /// Schwächste Domäne (für Handlungsempfehlung)
    public var weakestDomain: ResearchDomain {
        let scores: [(ResearchDomain, Double)] = [
            (.movement, movementScore),
            (.openSpace, environmentScore),
            (.water, waterScore),
            (.plantsNutrition, plantScore)
        ]
        return scores.min(by: { $0.1 < $1.1 })?.0 ?? .water
    }

    /// Kohärenz-Einfluss aller Domänen kombiniert
    public var combinedCoherenceModifier: Double {
        (overallScore - 0.5) * 0.3  // ±0.15 Kohärenz-Einfluss
    }
}

// MARK: - Research Data Point

/// Einzelner Forschungsdatenpunkt (domänenübergreifend)
public struct ResearchDataPoint: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date
    public let domain: ResearchDomain
    public let metric: String
    public let value: Double
    public let unit: String
    public let metadata: [String: String]
}

// MARK: - Bahrenfeld Research Hub

/// Zentraler Hub für das Forschungsinstitut Brache Bahrenfeld
/// Orchestriert alle vier Forschungsdomänen und erzeugt
/// übergreifende bio-reaktive Audio/Visual-Erlebnisse
@MainActor
public class BahrenfeldResearchHub: ObservableObject {

    public static let shared = BahrenfeldResearchHub()

    // MARK: - Sub-Engines (Domain-Specific)

    public let waterEngine = WaterQualityEngine.shared
    public let plantEngine = PlantBioReactiveEngine.shared
    public let freiraumEngine = FreiraumEnvironmentEngine.shared

    // MARK: - Universal Engine (Lambda Loop Integration)

    public let universalEngine = UniversalEnvironmentEngine.shared
    public let loopProcessor = EnvironmentLoopProcessor.shared

    // MARK: - Published State

    @Published public var isActive: Bool = false
    @Published public var operationalStatus: InstituteOperationalStatus = .closed
    @Published public var integratedScore: IntegratedHealthScore
    @Published public var activeDomains: Set<ResearchDomain> = []
    @Published public var researchLog: [ResearchDataPoint] = []

    // MARK: - Configuration

    @Published public var bioReactiveFeedbackEnabled: Bool = true
    @Published public var dataLoggingEnabled: Bool = true
    @Published public var publicDashboardEnabled: Bool = false

    /// GPS-Koordinaten Brache Bahrenfeld (ungefähr)
    public let location = SensorLocation(
        latitude: 53.5631,
        longitude: 9.8896,
        altitude: 12,
        description: "Forschungsinstitut Brache Bahrenfeld, Hamburg"
    )

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.integratedScore = IntegratedHealthScore(
            timestamp: Date(),
            movementScore: 1.0,
            environmentScore: 1.0,
            waterScore: 1.0,
            plantScore: 1.0
        )
        setupSubscriptions()
    }

    // MARK: - Lifecycle

    /// Forschungsinstitut aktivieren — startet alle Engines inkl. Universal Lambda Loop
    public func activate() {
        guard !isActive else { return }
        isActive = true
        operationalStatus = .research
        activeDomains = Set(ResearchDomain.allCases)

        // Domain-spezifische Engines
        waterEngine.startMonitoring()
        plantEngine.startMonitoring()
        freiraumEngine.startMonitoring()

        // Universal Environment auf Bahrenfeld setzen & Lambda Loop starten
        universalEngine.setEnvironment(.greenhouse)
        universalEngine.startMonitoring()
        loopProcessor.setLambdaChain(.bahrenfeldResearch)
        loopProcessor.start()
    }

    /// Forschungsinstitut deaktivieren
    public func deactivate() {
        isActive = false
        operationalStatus = .closed

        waterEngine.stopMonitoring()
        plantEngine.stopMonitoring()
        freiraumEngine.stopMonitoring()

        loopProcessor.stop()
        universalEngine.stopMonitoring()
    }

    /// Einzelne Domäne aktivieren/deaktivieren
    public func setDomain(_ domain: ResearchDomain, active: Bool) {
        if active {
            activeDomains.insert(domain)
        } else {
            activeDomains.remove(domain)
        }
    }

    // MARK: - Combine Subscriptions

    private func setupSubscriptions() {
        // Wasserqualität beobachten
        waterEngine.$overallQualityScore
            .combineLatest(
                plantEngine.$overallGardenHealth,
                freiraumEngine.$overallEnvironmentScore
            )
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] waterScore, plantScore, envScore in
                self?.updateIntegratedScore(water: waterScore, plant: plantScore, environment: envScore)
            }
            .store(in: &cancellables)
    }

    // MARK: - Score Integration

    private func updateIntegratedScore(water: Double, plant: Double, environment: Double) {
        // Bewegungsscore basiert auf aktiven Sessions und Umgebung
        let movementScore = calculateMovementScore()

        integratedScore = IntegratedHealthScore(
            timestamp: Date(),
            movementScore: movementScore,
            environmentScore: environment,
            waterScore: water,
            plantScore: plant
        )
    }

    private func calculateMovementScore() -> Double {
        let activeSessions = freiraumEngine.activeMovementSessions.count
        guard activeSessions > 0 else { return 0.5 } // Neutral wenn keine Session

        // Mehr Bewegungssessions + gute Umgebung = höherer Score
        let sessionBonus = Swift.min(1.0, Double(activeSessions) * 0.2)
        let envFactor = freiraumEngine.overallEnvironmentScore
        return Swift.min(1.0, 0.3 + sessionBonus * envFactor)
    }

    // MARK: - Bio-Reactive Output

    /// Kombinierter Kohärenz-Modifier aller Domänen
    public var combinedCoherenceModifier: Double {
        guard bioReactiveFeedbackEnabled else { return 0.0 }
        return integratedScore.combinedCoherenceModifier
    }

    /// Empfohlene Audio-Frequenz basierend auf Gesamtzustand
    public var recommendedFrequency: Double {
        let score = integratedScore.overallScore
        // Niedriger Score → beruhigende Theta-Frequenzen
        // Hoher Score → energetische Alpha/Beta-Frequenzen
        return 4.0 + score * 16.0  // 4–20 Hz Bereich
    }

    /// Kombinierte Ambient-Farbe aller Domänen
    public var ambientColor: (r: Float, g: Float, b: Float) {
        let water = waterEngine.ambientColor
        let plant = plantEngine.ambientColor
        let env = freiraumEngine.ambientColor

        // Gleichgewichtete Mischung
        return (
            r: (water.r + plant.r + env.r) / 3.0,
            g: (water.g + plant.g + env.g) / 3.0,
            b: (water.b + plant.b + env.b) / 3.0
        )
    }

    // MARK: - Research Data Logging

    /// Forschungsdatenpunkt protokollieren
    public func logDataPoint(domain: ResearchDomain, metric: String, value: Double,
                              unit: String, metadata: [String: String] = [:]) {
        guard dataLoggingEnabled else { return }

        let dataPoint = ResearchDataPoint(
            timestamp: Date(),
            domain: domain,
            metric: metric,
            value: value,
            unit: unit,
            metadata: metadata
        )
        researchLog.append(dataPoint)
    }

    // MARK: - Dashboard Summary

    /// Zusammenfassung für öffentliches Dashboard
    public var dashboardSummary: DashboardSummary {
        DashboardSummary(
            timestamp: Date(),
            overallScore: integratedScore.overallScore,
            waterQuality: waterEngine.overallQualityScore,
            gardenHealth: plantEngine.overallGardenHealth,
            airQuality: freiraumEngine.overallEnvironmentScore,
            activeMovementSessions: freiraumEngine.activeMovementSessions.count,
            connectedSensors: waterEngine.connectedSensors.count,
            registeredPlants: plantEngine.registeredPlants.count,
            activeZones: freiraumEngine.activeZones.count,
            operationalStatus: operationalStatus
        )
    }
}

// MARK: - Dashboard Summary

/// Zusammenfassung für öffentliches/internes Dashboard
public struct DashboardSummary: Sendable {
    public let timestamp: Date
    public let overallScore: Double
    public let waterQuality: Double
    public let gardenHealth: Double
    public let airQuality: Double
    public let activeMovementSessions: Int
    public let connectedSensors: Int
    public let registeredPlants: Int
    public let activeZones: Int
    public let operationalStatus: InstituteOperationalStatus
}
