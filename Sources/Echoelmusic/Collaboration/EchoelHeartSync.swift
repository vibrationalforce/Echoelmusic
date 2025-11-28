//
//  EchoelHeartSync.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  ECHOELHEARSYNC - Collective Heart Coherence Training
//
//  Train heart coherence together with collaborators worldwide.
//  See each other's coherence in real-time and create music
//  that responds to collective biofeedback data.
//
//  Based on HeartMath Institute research:
//  - Heart coherence synchronization between people
//  - Collective coherence amplification
//  - Heart-brain synchronization
//
//  Features:
//  - Real-time HRV sharing between collaborators
//  - Collective coherence score
//  - Synchronized breathing pacers
//  - Music generation from collective heart data
//  - Coherence competition/gamification
//

import Foundation
import Combine
import HealthKit

// MARK: - EchoelHeartSync Manager

@MainActor
public class EchoelHeartSync: ObservableObject {

    // Singleton
    public static let shared = EchoelHeartSync()

    // MARK: - Published State

    // Local user
    @Published public var localHeartRate: Double = 0
    @Published public var localHRV: Double = 0  // RMSSD in ms
    @Published public var localCoherence: CoherenceLevel = .low
    @Published public var localCoherenceScore: Double = 0  // 0-100
    @Published public var localBreathingRate: Double = 6.0  // breaths per minute

    // Collective
    @Published public var participants: [HeartSyncParticipant] = []
    @Published public var collectiveCoherence: Double = 0  // 0-100
    @Published public var collectiveCoherenceLevel: CoherenceLevel = .low
    @Published public var isSynchronized: Bool = false  // Are hearts in sync?
    @Published public var synchronizationScore: Double = 0  // 0-100

    // Session
    @Published public var isSessionActive: Bool = false
    @Published public var sessionDuration: TimeInterval = 0
    @Published public var sessionMode: SessionMode = .freeform

    // MARK: - Types

    public enum CoherenceLevel: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        public var color: String {
            switch self {
            case .low: return "red"
            case .medium: return "yellow"
            case .high: return "green"
            }
        }

        public var threshold: Double {
            switch self {
            case .low: return 0
            case .medium: return 40
            case .high: return 70
            }
        }

        public static func from(score: Double) -> CoherenceLevel {
            if score >= 70 { return .high }
            if score >= 40 { return .medium }
            return .low
        }
    }

    public enum SessionMode: String, CaseIterable {
        case freeform = "Freeform"
        case guidedBreathing = "Guided Breathing"
        case synchronization = "Synchronization Challenge"
        case musicGeneration = "Music Generation"
        case competition = "Coherence Competition"
    }

    // MARK: - Participant

    public struct HeartSyncParticipant: Identifiable {
        public let id: UUID
        public let peerId: String
        public let username: String
        public let location: String

        // Heart data
        public var heartRate: Double = 0
        public var hrv: Double = 0  // RMSSD ms
        public var coherenceScore: Double = 0
        public var coherenceLevel: CoherenceLevel = .low
        public var breathingRate: Double = 6.0

        // Real-time graph data
        public var heartRateHistory: [Double] = []
        public var coherenceHistory: [Double] = []

        // Sync
        public var lastUpdate: Date = Date()
        public var latency: Double = 0

        public var isOnline: Bool {
            return Date().timeIntervalSince(lastUpdate) < 5.0
        }
    }

    // MARK: - Heart Data Message

    struct HeartDataMessage: Codable {
        let timestamp: UInt64
        let heartRate: Double
        let hrv: Double
        let coherenceScore: Double
        let breathingRate: Double
        let rrIntervals: [Double]?  // Optional detailed data
    }

    // MARK: - Dependencies

    private let worldwideSync = WorldwideSyncBridge.shared
    private let healthKit = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var broadcastTimer: Timer?
    private var sessionTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupHealthKitObserver()
    }

    private func setupHealthKitObserver() {
        // Listen for heart rate updates from Apple Watch
        // This would connect to HealthKitManager
    }

    // MARK: - Session Management

    /// Start a HeartSync session
    public func startSession(mode: SessionMode = .freeform) {
        sessionMode = mode
        isSessionActive = true
        sessionDuration = 0

        // Start broadcasting local heart data
        startHeartDataBroadcast()

        // Start session timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionDuration += 1
                self?.updateCollectiveCoherence()
            }
        }

        // Notify other participants
        broadcastSessionStart()

        print("💚 HeartSync session started: \(mode.rawValue)")
    }

    /// End the current session
    public func endSession() {
        isSessionActive = false

        stopHeartDataBroadcast()
        sessionTimer?.invalidate()
        sessionTimer = nil

        broadcastSessionEnd()

        print("💔 HeartSync session ended. Duration: \(Int(sessionDuration))s")
    }

    // MARK: - Heart Data Broadcasting

    private func startHeartDataBroadcast() {
        // Broadcast at 10Hz (every 100ms) for smooth visualization
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.broadcastHeartData()
            }
        }
    }

    private func stopHeartDataBroadcast() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
    }

    private func broadcastHeartData() {
        let message = HeartDataMessage(
            timestamp: UInt64(Date().timeIntervalSince1970 * 1_000_000),
            heartRate: localHeartRate,
            hrv: localHRV,
            coherenceScore: localCoherenceScore,
            breathingRate: localBreathingRate,
            rrIntervals: nil
        )

        // Send via WorldwideSyncBridge
        if let data = try? JSONEncoder().encode(message) {
            // worldwideSync.webRTC.sendData(data, type: .custom)
        }
    }

    private func broadcastSessionStart() {
        // Notify all connected peers about session
    }

    private func broadcastSessionEnd() {
        // Notify all connected peers session ended
    }

    // MARK: - Receiving Heart Data

    public func handleReceivedHeartData(_ data: Data, from peerId: String) {
        guard let message = try? JSONDecoder().decode(HeartDataMessage.self, from: data) else {
            return
        }

        // Update participant data
        if let index = participants.firstIndex(where: { $0.peerId == peerId }) {
            participants[index].heartRate = message.heartRate
            participants[index].hrv = message.hrv
            participants[index].coherenceScore = message.coherenceScore
            participants[index].coherenceLevel = CoherenceLevel.from(score: message.coherenceScore)
            participants[index].breathingRate = message.breathingRate
            participants[index].lastUpdate = Date()

            // Add to history (keep last 60 seconds at 10Hz = 600 samples)
            participants[index].heartRateHistory.append(message.heartRate)
            if participants[index].heartRateHistory.count > 600 {
                participants[index].heartRateHistory.removeFirst()
            }

            participants[index].coherenceHistory.append(message.coherenceScore)
            if participants[index].coherenceHistory.count > 600 {
                participants[index].coherenceHistory.removeFirst()
            }
        }
    }

    // MARK: - Collective Coherence Calculation

    private func updateCollectiveCoherence() {
        let allScores = [localCoherenceScore] + participants.filter { $0.isOnline }.map { $0.coherenceScore }

        guard !allScores.isEmpty else {
            collectiveCoherence = 0
            return
        }

        // Average coherence
        collectiveCoherence = allScores.reduce(0, +) / Double(allScores.count)
        collectiveCoherenceLevel = CoherenceLevel.from(score: collectiveCoherence)

        // Calculate synchronization
        updateSynchronizationScore()
    }

    private func updateSynchronizationScore() {
        // Compare heart rate variability patterns between participants
        // High synchronization = similar HRV patterns

        let onlineParticipants = participants.filter { $0.isOnline }
        guard !onlineParticipants.isEmpty else {
            synchronizationScore = 0
            isSynchronized = false
            return
        }

        // Calculate variance in coherence scores
        let allScores = [localCoherenceScore] + onlineParticipants.map { $0.coherenceScore }
        let mean = allScores.reduce(0, +) / Double(allScores.count)
        let variance = allScores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(allScores.count)
        let stdDev = sqrt(variance)

        // Low variance = high synchronization
        // Max score when std dev < 5
        synchronizationScore = max(0, min(100, 100 - (stdDev * 5)))
        isSynchronized = synchronizationScore > 70
    }

    // MARK: - Music Generation from Heart Data

    /// Generate musical parameters from collective heart data
    public func getMusicalParameters() -> HeartMusicParameters {
        return HeartMusicParameters(
            tempo: mapHeartRateToTempo(),
            key: mapCoherenceToKey(),
            intensity: mapCollectiveEnergyToIntensity(),
            harmony: mapSynchronizationToHarmony(),
            rhythm: mapBreathingToRhythm()
        )
    }

    public struct HeartMusicParameters {
        public let tempo: Double  // BPM
        public let key: String  // Musical key (C, D, etc.)
        public let intensity: Double  // 0-1
        public let harmony: Double  // 0-1 (dissonant to consonant)
        public let rhythm: String  // Pattern suggestion
    }

    private func mapHeartRateToTempo() -> Double {
        // Map average heart rate to musical tempo
        // Resting HR ~60-80 → Slow tempo 70-90 BPM
        // Elevated HR ~100+ → Faster tempo 120+ BPM

        let allHeartRates = [localHeartRate] + participants.map { $0.heartRate }
        let avgHR = allHeartRates.filter { $0 > 0 }.reduce(0, +) / Double(max(1, allHeartRates.count))

        // Map 60-120 HR to 70-140 BPM
        return max(70, min(140, avgHR + 10))
    }

    private func mapCoherenceToKey() -> String {
        // High coherence = major keys (happy)
        // Low coherence = minor keys (tense)

        let keys = ["Am", "Dm", "Em", "C", "F", "G", "D", "A", "E"]

        switch collectiveCoherenceLevel {
        case .high:
            return ["C", "G", "D", "A"].randomElement() ?? "C"  // Major keys
        case .medium:
            return ["F", "E", "Am"].randomElement() ?? "F"  // Mixed
        case .low:
            return ["Am", "Dm", "Em"].randomElement() ?? "Am"  // Minor keys
        }
    }

    private func mapCollectiveEnergyToIntensity() -> Double {
        // Combine heart rates and coherence for overall energy
        let allHR = [localHeartRate] + participants.map { $0.heartRate }
        let avgHR = allHR.filter { $0 > 0 }.reduce(0, +) / Double(max(1, allHR.count))

        // Normalize: 60 HR = 0.3, 100 HR = 0.7, 120 HR = 1.0
        let hrIntensity = max(0, min(1, (avgHR - 50) / 70))
        let coherenceBoost = collectiveCoherence / 200  // 0-0.5 boost

        return min(1.0, hrIntensity + coherenceBoost)
    }

    private func mapSynchronizationToHarmony() -> Double {
        // High sync = more consonant harmonies
        // Low sync = more dissonant/complex harmonies
        return synchronizationScore / 100
    }

    private func mapBreathingToRhythm() -> String {
        // Map average breathing rate to rhythm pattern
        let avgBreathing = ([localBreathingRate] + participants.map { $0.breathingRate }).reduce(0, +) / Double(participants.count + 1)

        if avgBreathing < 5 {
            return "slow-ambient"  // Very slow breathing = ambient
        } else if avgBreathing < 8 {
            return "4/4-relaxed"  // Normal relaxed = 4/4 at medium tempo
        } else if avgBreathing < 12 {
            return "4/4-driving"  // Faster = more driving rhythm
        } else {
            return "4/4-energetic"  // Fast breathing = energetic
        }
    }

    // MARK: - Guided Breathing Sync

    /// Get current breathing phase for synchronized breathing
    public func getSynchronizedBreathingPhase() -> (phase: BreathingPhase, progress: Double) {
        let breathCycleDuration = 60.0 / localBreathingRate  // seconds per breath
        let inhaleDuration = breathCycleDuration * 0.45
        let exhaleDuration = breathCycleDuration * 0.55

        let cyclePosition = sessionDuration.truncatingRemainder(dividingBy: breathCycleDuration)

        if cyclePosition < inhaleDuration {
            return (.inhale, cyclePosition / inhaleDuration)
        } else {
            return (.exhale, (cyclePosition - inhaleDuration) / exhaleDuration)
        }
    }

    public enum BreathingPhase {
        case inhale
        case exhale
    }

    // MARK: - Simulation (for testing)

    #if DEBUG
    public func simulateHeartData() {
        // Simulate local heart data
        localHeartRate = Double.random(in: 65...75)
        localHRV = Double.random(in: 40...80)
        localCoherenceScore = Double.random(in: 50...90)
        localCoherence = CoherenceLevel.from(score: localCoherenceScore)

        // Simulate remote participants
        let participant1 = HeartSyncParticipant(
            id: UUID(),
            peerId: "peer-1",
            username: "YogaMaster_Berlin",
            location: "Berlin, Germany",
            heartRate: Double.random(in: 62...70),
            hrv: Double.random(in: 50...90),
            coherenceScore: Double.random(in: 60...95),
            coherenceLevel: .high,
            breathingRate: 5.5,
            heartRateHistory: (0..<100).map { _ in Double.random(in: 62...70) },
            coherenceHistory: (0..<100).map { _ in Double.random(in: 60...95) },
            lastUpdate: Date(),
            latency: 45
        )

        let participant2 = HeartSyncParticipant(
            id: UUID(),
            peerId: "peer-2",
            username: "ZenMaster_Tokyo",
            location: "Tokyo, Japan",
            heartRate: Double.random(in: 58...65),
            hrv: Double.random(in: 60...100),
            coherenceScore: Double.random(in: 70...98),
            coherenceLevel: .high,
            breathingRate: 5.0,
            heartRateHistory: (0..<100).map { _ in Double.random(in: 58...65) },
            coherenceHistory: (0..<100).map { _ in Double.random(in: 70...98) },
            lastUpdate: Date(),
            latency: 180
        )

        participants = [participant1, participant2]
        updateCollectiveCoherence()

        print("💚 Simulated HeartSync data:")
        print("   Local: HR=\(Int(localHeartRate)), Coherence=\(Int(localCoherenceScore))%")
        print("   Collective: \(Int(collectiveCoherence))%, Sync: \(Int(synchronizationScore))%")
    }
    #endif
}

// MARK: - HealthKit Manager Extension

extension HealthKitManager {
    // This would be extended to provide real HRV data
    // using HKHealthStore.startHeartRateQuery() etc.
}
