// QuantumHealthBiofeedbackEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Quantum-Inspired Health & Biofeedback Integration
// Real-Time Unlimited Collaboration & Broadcasting
//
// Quantum Computing Konzepte:
// - Superposition (multiple states simultaneously)
// - Entanglement (correlated participants)
// - Coherence (maintaining quantum state)
// - Wave Function Collapse (measurement -> action)
//
// HINWEIS: "Quantum" bezieht sich auf quantum-inspirierte Algorithmen,
// nicht auf tatsächliche Quantencomputer-Hardware.

import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Quantum Health State

/// Quantum-inspirierter Gesundheitszustand
public struct QuantumHealthState: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date

    // Biometric Observables (Messungen)
    public var heartRate: Double = 70
    public var hrvSDNN: Double = 50
    public var hrvRMSSD: Double = 40
    public var hrvLF: Double = 0.5      // Low Frequency Power
    public var hrvHF: Double = 0.5      // High Frequency Power
    public var coherenceRatio: Double = 0.5
    public var breathingRate: Double = 12
    public var gsrConductance: Double = 0  // Galvanic Skin Response
    public var skinTemperature: Double = 33
    public var bloodOxygenation: Double = 98

    // Quantum-Inspired Metrics
    public var coherenceAmplitude: Double = 0.5    // |ψ|²
    public var phaseAlignment: Double = 0.5         // Phase coherence
    public var entropyLevel: Double = 0.5           // System disorder
    public var entanglementScore: Double = 0        // Group correlation
    public var superpositionPotential: Double = 0.5 // Possibility space

    // Integrated Health Score (0-100)
    public var quantumHealthScore: Double {
        let biometricScore = (
            (hrvSDNN / 100.0) * 0.3 +
            coherenceRatio * 0.3 +
            (1.0 - abs(breathingRate - 6) / 6) * 0.2 +  // Optimal bei 6/min
            (bloodOxygenation / 100.0) * 0.2
        ) * 100

        let quantumBonus = (coherenceAmplitude + phaseAlignment + (1 - entropyLevel)) / 3 * 10

        return min(100, biometricScore + quantumBonus)
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
    }
}

// MARK: - Quantum Entanglement Session

/// Gruppensession mit Quantum-Entanglement Metapher
public struct QuantumEntanglementSession: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public var participants: [EntangledParticipant]
    public var sessionType: SessionType
    public var maxParticipants: Int
    public var isActive: Bool

    // Group Quantum State
    public var groupCoherence: Double = 0
    public var groupEntanglement: Double = 0
    public var synchronyScore: Double = 0

    // Broadcast Settings
    public var broadcastEnabled: Bool = false
    public var broadcastURL: String?
    public var viewerCount: Int = 0

    public enum SessionType: String, CaseIterable, Codable {
        case meditation = "meditation"
        case coherenceTraining = "coherence_training"
        case creativeSynthesis = "creative_synthesis"
        case wellnessCircle = "wellness_circle"  // Changed from "healing" - no medical claims
        case researchStudy = "research_study"
        case performance = "performance"
        case workshop = "workshop"
        case unlimited = "unlimited"  // No participant limit
    }

    public init(
        id: UUID = UUID(),
        name: String,
        sessionType: SessionType,
        maxParticipants: Int = .max
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.participants = []
        self.sessionType = sessionType
        self.maxParticipants = maxParticipants
        self.isActive = true
    }
}

public struct EntangledParticipant: Identifiable, Codable {
    public let id: UUID
    public let displayName: String
    public let joinedAt: Date
    public var currentState: QuantumHealthState
    public var connectionQuality: Double = 1.0
    public var isLeader: Bool = false

    // Entanglement with others
    public var entanglementPartners: [UUID] = []
    public var avgEntanglementStrength: Double = 0

    public init(
        id: UUID = UUID(),
        displayName: String,
        currentState: QuantumHealthState = QuantumHealthState()
    ) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = Date()
        self.currentState = currentState
    }
}

// MARK: - Broadcast Configuration

/// Streaming/Broadcasting Konfiguration
public struct BroadcastConfiguration: Codable {
    public var enabled: Bool = false
    public var platforms: [BroadcastPlatform] = []
    public var quality: StreamQuality = .hd1080
    public var biometricOverlay: Bool = true
    public var visualizationOverlay: Bool = true
    public var showParticipantCount: Bool = true
    public var privacyMode: PrivacyMode = .aggregated

    public enum BroadcastPlatform: String, CaseIterable, Codable {
        case youtube = "youtube"
        case twitch = "twitch"
        case facebook = "facebook"
        case instagram = "instagram"
        case tiktok = "tiktok"
        case custom = "custom_rtmp"
        case webrtc = "webrtc"
        case ndi = "ndi"
    }

    public enum StreamQuality: String, CaseIterable, Codable {
        case mobile480 = "480p"
        case hd720 = "720p"
        case hd1080 = "1080p"
        case uhd4k = "4k"
        case uhd8k = "8k"
    }

    public enum PrivacyMode: String, CaseIterable, Codable {
        case full = "full"           // Alle individuellen Daten
        case aggregated = "aggregated"  // Nur Gruppendurchschnitt
        case anonymous = "anonymous"    // Keine biometrischen Daten
    }
}

// MARK: - Quantum Health Biofeedback Engine

@MainActor
public final class QuantumHealthBiofeedbackEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentState: QuantumHealthState = QuantumHealthState()
    @Published public private(set) var activeSession: QuantumEntanglementSession?
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isBroadcasting: Bool = false

    // Group Metrics
    @Published public private(set) var totalParticipants: Int = 0
    @Published public private(set) var groupCoherence: Double = 0
    @Published public private(set) var groupEntanglement: Double = 0
    @Published public private(set) var coherenceSynchronyWave: [Double] = []

    // Broadcast Metrics
    @Published public private(set) var viewerCount: Int = 0
    @Published public private(set) var broadcastDuration: TimeInterval = 0

    // Historical Data
    @Published public private(set) var healthHistory: [QuantumHealthState] = []
    @Published public private(set) var peakCoherenceMoments: [QuantumHealthState] = []

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var broadcastStartTime: Date?
    private var broadcastConfig: BroadcastConfiguration = BroadcastConfiguration()

    // MARK: - Constants

    /// Maximale Teilnehmer für "Unlimited" Mode
    public static let unlimitedParticipants = Int.max

    /// Kohärenz-Schwelle für "Quantum Entanglement Event"
    public static let entanglementThreshold: Double = 0.9

    /// Optimale Atemfrequenz (6/min = 0.1Hz = Baroreflex)
    public static let optimalBreathingRate: Double = 6.0

    // MARK: - Singleton

    public static let shared = QuantumHealthBiofeedbackEngine()

    // MARK: - Initialization

    public init() {}

    // MARK: - Session Management

    /// Erstellt eine neue Quantum Session
    public func createSession(
        name: String,
        type: QuantumEntanglementSession.SessionType,
        maxParticipants: Int = .max
    ) -> QuantumEntanglementSession {
        let session = QuantumEntanglementSession(
            name: name,
            sessionType: type,
            maxParticipants: maxParticipants
        )
        activeSession = session
        startSessionUpdates()
        return session
    }

    /// Tritt einer bestehenden Session bei
    public func joinSession(
        sessionId: UUID,
        displayName: String
    ) -> EntangledParticipant? {
        guard var session = activeSession, session.id == sessionId else {
            return nil
        }

        let participant = EntangledParticipant(
            displayName: displayName,
            currentState: currentState
        )

        session.participants.append(participant)
        activeSession = session
        totalParticipants = session.participants.count

        return participant
    }

    /// Verlässt die aktuelle Session
    public func leaveSession(participantId: UUID) {
        guard var session = activeSession else { return }

        session.participants.removeAll { $0.id == participantId }
        activeSession = session
        totalParticipants = session.participants.count

        if session.participants.isEmpty {
            stopSession()
        }
    }

    /// Beendet die Session
    public func stopSession() {
        updateTimer?.invalidate()
        updateTimer = nil
        activeSession?.isActive = false
        activeSession = nil
        stopBroadcast()
    }

    // MARK: - Biofeedback Updates

    /// Aktualisiert Biometrie-Daten
    public func updateBiometrics(
        heartRate: Double,
        hrvSDNN: Double,
        hrvRMSSD: Double,
        coherence: Double,
        breathingRate: Double,
        gsr: Double = 0,
        temperature: Double = 33,
        spo2: Double = 98
    ) {
        currentState.heartRate = heartRate
        currentState.hrvSDNN = hrvSDNN
        currentState.hrvRMSSD = hrvRMSSD
        currentState.coherenceRatio = coherence
        currentState.breathingRate = breathingRate
        currentState.gsrConductance = gsr
        currentState.skinTemperature = temperature
        currentState.bloodOxygenation = spo2

        calculateQuantumMetrics()
        saveToHistory()

        // Update participant in session
        updateParticipantState()
    }

    /// Berechnet Quantum-inspirierte Metriken
    private func calculateQuantumMetrics() {
        // Coherence Amplitude (wie stark der kohärente Zustand)
        currentState.coherenceAmplitude = currentState.coherenceRatio *
            (currentState.hrvSDNN / 100.0)

        // Phase Alignment (wie synchron Herz und Atmung)
        let heartBreathRatio = currentState.heartRate / (currentState.breathingRate * 4)
        currentState.phaseAlignment = 1.0 - min(1.0, abs(heartBreathRatio - 1.0))

        // Entropy (inverse of coherence, lower is better)
        currentState.entropyLevel = 1.0 - currentState.coherenceRatio

        // Superposition Potential (Möglichkeitsraum für Veränderung)
        currentState.superpositionPotential = (1.0 - currentState.entropyLevel) *
            currentState.coherenceAmplitude
    }

    // MARK: - Group Coherence

    /// Berechnet Gruppen-Kohärenz (optimized single-pass)
    public func calculateGroupCoherence() {
        guard let session = activeSession else { return }

        let participants = session.participants
        guard participants.count > 1 else {
            groupCoherence = currentState.coherenceRatio
            return
        }

        // Single-pass mean and variance (Welford's algorithm)
        let count = Double(participants.count)
        var sum: Double = 0
        var sumSquares: Double = 0
        for participant in participants {
            let c = participant.currentState.coherenceRatio
            sum += c
            sumSquares += c * c
        }

        let avgCoherence = sum / count
        let variance = sumSquares / count - avgCoherence * avgCoherence
        let stdDev = sqrt(max(0, variance))

        // Synchrony Score (1 - normalized std dev)
        let synchrony = 1.0 - min(1.0, stdDev * 2)

        groupCoherence = avgCoherence
        activeSession?.synchronyScore = synchrony

        // Entanglement Score (Korrelation der HRV-Muster)
        calculateGroupEntanglement()

        // Update Coherence Wave
        coherenceSynchronyWave.append(synchrony)
        if coherenceSynchronyWave.count > 300 {  // 5 Minuten bei 1Hz
            coherenceSynchronyWave.removeFirst()
        }

        // Detect Quantum Entanglement Events
        if synchrony > Self.entanglementThreshold {
            triggerEntanglementEvent()
        }
    }

    /// Berechnet Entanglement-Score using vectorized operations
    private func calculateGroupEntanglement() {
        guard let session = activeSession, session.participants.count > 1 else {
            groupEntanglement = 0
            return
        }

        let participants = session.participants
        let count = participants.count

        // Extract values
        let hrvValues = participants.map { $0.currentState.hrvSDNN }
        let coherenceValues = participants.map { $0.currentState.coherenceRatio }

        // Compute means
        let hrvMean = hrvValues.reduce(0, +) / Double(count)
        let cohMean = coherenceValues.reduce(0, +) / Double(count)

        // Compute deviations and correlation in single pass
        var numerator: Double = 0
        var denomHRV: Double = 0
        var denomCoh: Double = 0

        for i in 0..<count {
            let hrvDiff = hrvValues[i] - hrvMean
            let cohDiff = coherenceValues[i] - cohMean
            numerator += hrvDiff * cohDiff
            denomHRV += hrvDiff * hrvDiff
            denomCoh += cohDiff * cohDiff
        }

        let denomProduct = denomHRV * denomCoh
        groupEntanglement = denomProduct > 0 ? abs(numerator / sqrt(denomProduct)) : 0
        activeSession?.groupEntanglement = groupEntanglement
    }

    /// Löst ein Quantum Entanglement Event aus
    private func triggerEntanglementEvent() {
        // Peak Experience für alle Teilnehmer
        if let session = activeSession {
            for participant in session.participants {
                peakCoherenceMoments.append(participant.currentState)
            }
        }

        // Notification oder Haptic Feedback
        // (Implementation would go here)
    }

    // MARK: - Broadcasting

    /// Startet Broadcasting
    public func startBroadcast(config: BroadcastConfiguration) {
        broadcastConfig = config
        isBroadcasting = true
        broadcastStartTime = Date()
        activeSession?.broadcastEnabled = true
    }

    /// Stoppt Broadcasting
    public func stopBroadcast() {
        isBroadcasting = false
        broadcastStartTime = nil
        activeSession?.broadcastEnabled = false
        viewerCount = 0
    }

    /// Aktualisiert Viewer-Statistiken
    public func updateViewerCount(_ count: Int) {
        viewerCount = count
        activeSession?.viewerCount = count
    }

    // MARK: - Private Methods

    private func startSessionUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionTick()
            }
        }
    }

    private func sessionTick() {
        calculateGroupCoherence()
        totalParticipants = activeSession?.participants.count ?? 0

        if isBroadcasting, let start = broadcastStartTime {
            broadcastDuration = Date().timeIntervalSince(start)
        }
    }

    private func updateParticipantState() {
        guard var session = activeSession else { return }

        // Find and update current user's state
        if let index = session.participants.firstIndex(where: { $0.isLeader }) {
            session.participants[index].currentState = currentState
            activeSession = session
        }
    }

    private func saveToHistory() {
        healthHistory.append(currentState)

        // Keep last hour at 1Hz
        if healthHistory.count > 3600 {
            healthHistory.removeFirst()
        }

        // Save peak moments
        if currentState.coherenceRatio > 0.9 {
            peakCoherenceMoments.append(currentState)
        }
    }

    // MARK: - Analytics

    /// Berechnet Session-Statistiken
    public func getSessionAnalytics() -> SessionAnalytics {
        SessionAnalytics(
            duration: broadcastDuration,
            avgCoherence: groupCoherence,
            peakCoherence: peakCoherenceMoments.map { $0.coherenceRatio }.max() ?? 0,
            totalParticipants: totalParticipants,
            peakParticipants: totalParticipants,  // Would need tracking
            entanglementEvents: peakCoherenceMoments.count,
            avgHealthScore: currentState.quantumHealthScore
        )
    }
}

// MARK: - Analytics

public struct SessionAnalytics: Codable {
    public let duration: TimeInterval
    public let avgCoherence: Double
    public let peakCoherence: Double
    public let totalParticipants: Int
    public let peakParticipants: Int
    public let entanglementEvents: Int
    public let avgHealthScore: Double
}

// MARK: - Quantum Disclaimer

public struct QuantumHealthDisclaimer {
    public static let text = """
    HINWEIS ZU "QUANTUM" TERMINOLOGIE
    ==================================

    Der Begriff "Quantum" in dieser App bezieht sich auf:

    ✓ Quantum-INSPIRIERTE Algorithmen und Metaphern
    ✓ Konzepte wie Kohärenz, Superposition, Entanglement
    ✓ Mathematische Modelle aus der Quantenmechanik

    Es handelt sich NICHT um:
    ✗ Tatsächliche Quantencomputer-Berechnungen
    ✗ Quantenphysikalische Effekte im Körper
    ✗ Pseudowissenschaftliche "Quanten-Heilung"

    Die Verwendung dient der:
    - Veranschaulichung komplexer Gruppendynamiken
    - Kreativen Exploration von Bewusstseinszuständen
    - Wissenschaftlich fundierter Biofeedback-Analyse

    Alle Gesundheitsfunktionen basieren auf etablierter
    Wissenschaft (HRV, Herzkohärenz, Biofeedback).

    Diese App ist KEIN medizinisches Gerät.
    """
}
