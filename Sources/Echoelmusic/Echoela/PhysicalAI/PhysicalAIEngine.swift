// PhysicalAIEngine.swift
// Echoelmusic - Echoela Physical AI
//
// Main orchestrator for Physical AI capabilities:
// - High-frequency sensor fusion from watchOS
// - Objective-driven autonomous parameter control
// - Integration with WorldModel and ContextualHighlighter
//
// Latency Target: < 20ms for Aura reaction
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// MARK: - Sensor Data

/// High-frequency sensor reading from watchOS or local sensors
public struct SensorReading: Codable, Sendable {
    public let timestamp: Date
    public let source: Source
    public let heartRate: Float?
    public let rrIntervals: [Float]?      // For HRV calculation
    public let accelerometer: SIMD3<Float>?
    public let gyroscope: SIMD3<Float>?
    public let skinTemperature: Float?

    public enum Source: String, Codable, Sendable {
        case appleWatch = "Apple Watch"
        case iPhone = "iPhone"
        case external = "External Sensor"
        case simulated = "Simulated"
    }

    public init(
        timestamp: Date = Date(),
        source: Source,
        heartRate: Float? = nil,
        rrIntervals: [Float]? = nil,
        accelerometer: SIMD3<Float>? = nil,
        gyroscope: SIMD3<Float>? = nil,
        skinTemperature: Float? = nil
    ) {
        self.timestamp = timestamp
        self.source = source
        self.heartRate = heartRate
        self.rrIntervals = rrIntervals
        self.accelerometer = accelerometer
        self.gyroscope = gyroscope
        self.skinTemperature = skinTemperature
    }
}

// MARK: - Action Execution

/// Represents an autonomous action taken by Echoela
public struct AutonomousAction: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let parameter: String
    public let previousValue: Float
    public let newValue: Float
    public let reason: String
    public let objective: EchoelaObjective?
    public let confidence: Float
    public let pqcSignature: Data?    // Post-Quantum Cryptographic signature

    public init(
        parameter: String,
        previousValue: Float,
        newValue: Float,
        reason: String,
        objective: EchoelaObjective? = nil,
        confidence: Float,
        pqcSignature: Data? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.parameter = parameter
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
        self.objective = objective
        self.confidence = confidence
        self.pqcSignature = pqcSignature
    }
}

// MARK: - Physical AI Engine

/// Main Physical AI Engine - orchestrates sensor fusion, prediction, and autonomous control
@MainActor
public final class PhysicalAIEngine: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = PhysicalAIEngine()

    // MARK: - Published State

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var latestReading: SensorReading?
    @Published public private(set) var sensorLatency: TimeInterval = 0
    @Published public private(set) var actionHistory: [AutonomousAction] = []
    @Published public private(set) var autonomousMode: AutonomousMode = .suggest

    @Published public var targetLatency: TimeInterval = 0.020  // 20ms target

    // MARK: - Autonomous Mode

    public enum AutonomousMode: String, CaseIterable, Sendable {
        case disabled = "Disabled"
        case suggest = "Suggest Only"
        case confirmFirst = "Confirm First"
        case autonomous = "Fully Autonomous"
    }

    // MARK: - Configuration

    public struct Configuration {
        public var sensorUpdateRate: TimeInterval = 0.016    // 60Hz
        public var predictionUpdateRate: TimeInterval = 0.05  // 20Hz
        public var maxActionHistorySize: Int = 100
        public var enablePQCSignatures: Bool = true
        public var smoothingFactor: Float = 0.3

        public static let `default` = Configuration()
        public static let lowLatency = Configuration(
            sensorUpdateRate: 0.008,    // 125Hz
            predictionUpdateRate: 0.016  // 60Hz
        )
    }

    private var config: Configuration

    // MARK: - Internal State

    private let worldModel = WorldModel.shared
    private let highlighter = ContextualHighlighter.shared

    private var sensorBuffer: [SensorReading] = []
    private let bufferSize = 50

    #if canImport(CoreMotion)
    private var motionManager: CMMotionManager?
    #endif
    private var sensorTimer: Timer?
    private var predictionTimer: Timer?

    private var cancellables = Set<AnyCancellable>()

    #if canImport(WatchConnectivity)
    private var wcSession: WCSession?
    #endif

    // Running HRV calculation
    private var rrIntervalBuffer: [Float] = []
    private let hrvWindowSize = 30  // 30 RR intervals for RMSSD

    // Smoothed values
    private var smoothedHeartRate: Float = 72
    private var smoothedHRV: Float = 50
    private var smoothedCoherence: Float = 0.5

    // MARK: - Callbacks

    /// Called when an autonomous action is about to be executed (for confirmation mode)
    public var onActionProposed: ((AutonomousAction) async -> Bool)?

    /// Called when a parameter should be changed
    public var onParameterChange: ((String, Float) -> Void)?

    // MARK: - Initialization

    deinit {
        sensorTimer?.invalidate()
        predictionTimer?.invalidate()
    }

    private init(config: Configuration = .default) {
        self.config = config
        super.init()
        setupMotionManager()
        setupWatchConnectivity()
        setupWorldModelBinding()
    }

    // MARK: - Public API

    /// Start the Physical AI Engine
    public func start() {
        guard !isActive else { return }
        isActive = true

        // Start sensor collection
        startSensorCollection()

        // Start WorldModel
        worldModel.start()

        // Start prediction loop
        startPredictionLoop()

        log.info("PhysicalAIEngine started", category: .intelligence)
    }

    /// Stop the engine
    public func stop() {
        isActive = false

        sensorTimer?.invalidate()
        sensorTimer = nil

        predictionTimer?.invalidate()
        predictionTimer = nil

        motionManager?.stopAccelerometerUpdates()
        motionManager?.stopGyroUpdates()

        worldModel.stop()

        log.info("PhysicalAIEngine stopped", category: .intelligence)
    }

    /// Set autonomous mode
    public func setAutonomousMode(_ mode: AutonomousMode) {
        autonomousMode = mode
        log.info("Autonomous mode set to: \(mode.rawValue)", category: .intelligence)
    }

    /// Add an objective
    public func addObjective(_ objective: EchoelaObjective) {
        worldModel.addObjective(objective)
    }

    /// Process incoming sensor data (from watchOS or external)
    public func processSensorData(_ reading: SensorReading) {
        let latency = Date().timeIntervalSince(reading.timestamp)
        sensorLatency = latency

        // Buffer the reading
        sensorBuffer.append(reading)
        if sensorBuffer.count > bufferSize {
            sensorBuffer.removeFirst()
        }

        latestReading = reading

        // Process heart rate
        if let hr = reading.heartRate {
            smoothedHeartRate = smoothedHeartRate * (1 - config.smoothingFactor) + hr * config.smoothingFactor
        }

        // Process RR intervals for HRV
        if let rrIntervals = reading.rrIntervals {
            rrIntervalBuffer.append(contentsOf: rrIntervals)
            if rrIntervalBuffer.count > hrvWindowSize {
                rrIntervalBuffer.removeFirst(rrIntervalBuffer.count - hrvWindowSize)
            }
            updateHRVCalculation()
        }

        // Update WorldModel with biometrics
        let biometrics = WorldState.BiometricState(
            heartRate: smoothedHeartRate,
            hrv: smoothedHRV,
            coherence: smoothedCoherence,
            breathingRate: estimateBreathingRate(),
            motionIntensity: calculateMotionIntensity(reading),
            skinConductance: 0.5  // Default if not available
        )

        worldModel.updateBiometrics(biometrics)
    }

    /// Manually trigger action execution
    public func executeRecommendedActions() async {
        guard let prediction = worldModel.latestPrediction else { return }

        for action in prediction.recommendedActions {
            await executeAction(action)
        }
    }

    // MARK: - Private Setup

    private func setupMotionManager() {
        #if os(iOS) && canImport(CoreMotion)
        motionManager = SharedMotionManager.shared
        motionManager?.accelerometerUpdateInterval = config.sensorUpdateRate
        motionManager?.gyroUpdateInterval = config.sensorUpdateRate
        #endif
    }

    private func setupWatchConnectivity() {
        #if canImport(WatchConnectivity) && os(iOS)
        if WCSession.isSupported() {
            wcSession = WCSession.default
            // Note: Delegate would be set up here for receiving watch data
        }
        #endif
    }

    private func setupWorldModelBinding() {
        // React to WorldModel predictions
        worldModel.$latestPrediction
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prediction in
                self?.handlePrediction(prediction)
            }
            .store(in: &cancellables)
    }

    private func startSensorCollection() {
        #if os(iOS)
        // Start accelerometer
        if let mm = motionManager, mm.isAccelerometerAvailable {
            mm.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }

                let reading = SensorReading(
                    source: .iPhone,
                    accelerometer: SIMD3<Float>(
                        Float(data.acceleration.x),
                        Float(data.acceleration.y),
                        Float(data.acceleration.z)
                    )
                )

                Task { @MainActor in
                    self?.processSensorData(reading)
                }
            }
        }
        #endif

        // Sensor timer for simulated/external data
        sensorTimer = Timer.scheduledTimer(withTimeInterval: config.sensorUpdateRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sensorTick()
            }
        }
    }

    private func startPredictionLoop() {
        predictionTimer = Timer.scheduledTimer(withTimeInterval: config.predictionUpdateRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.predictionTick()
            }
        }
    }

    // MARK: - Processing

    private func sensorTick() {
        // If no real sensor data, use simulation for demo
        if latestReading.map({ Date().timeIntervalSince($0.timestamp) > 1.0 }) ?? true {
            let simulated = generateSimulatedReading()
            processSensorData(simulated)
        }
    }

    private func predictionTick() {
        worldModel.forceUpdate()
    }

    private func handlePrediction(_ prediction: WorldPrediction) {
        // Update highlighter based on emotional trajectory
        updateHighlighterFromPrediction(prediction)

        // Process actions based on autonomous mode
        if autonomousMode != .disabled {
            Task {
                await processRecommendedActions(prediction.recommendedActions)
            }
        }
    }

    private func updateHighlighterFromPrediction(_ prediction: WorldPrediction) {
        // Map prediction to aura configuration
        let auraConfig = AuraConfiguration.fromConfidence(
            prediction.confidence,
            variance: calculateVariance()
        )

        highlighter.auraConfig = auraConfig
    }

    private func processRecommendedActions(_ actions: [WorldPrediction.RecommendedAction]) async {
        for action in actions {
            let autonomousAction = AutonomousAction(
                parameter: action.parameter,
                previousValue: action.currentValue,
                newValue: action.targetValue,
                reason: action.rationale,
                confidence: worldModel.modelConfidence
            )

            switch autonomousMode {
            case .disabled:
                break

            case .suggest:
                // Just log the suggestion
                log.info("Suggested action: \(action.parameter) → \(action.targetValue)", category: .intelligence)

            case .confirmFirst:
                // Ask for confirmation
                if let callback = onActionProposed {
                    let approved = await callback(autonomousAction)
                    if approved {
                        await executeAction(action)
                    }
                }

            case .autonomous:
                // Execute immediately if high priority
                if action.priority >= .medium {
                    await executeAction(action)
                }
            }
        }
    }

    private func executeAction(_ action: WorldPrediction.RecommendedAction) async {
        // Sign with PQC if enabled
        let signature: Data? = config.enablePQCSignatures ? generatePQCSignature(for: action) : nil

        let autonomousAction = AutonomousAction(
            parameter: action.parameter,
            previousValue: action.currentValue,
            newValue: action.targetValue,
            reason: action.rationale,
            confidence: worldModel.modelConfidence,
            pqcSignature: signature
        )

        // Record in history
        actionHistory.append(autonomousAction)
        if actionHistory.count > config.maxActionHistorySize {
            actionHistory.removeFirst()
        }

        // Execute parameter change
        onParameterChange?(action.parameter, action.targetValue)

        log.info("Executed: \(action.parameter) = \(action.targetValue)", category: .intelligence)
    }

    // MARK: - HRV Calculation

    private func updateHRVCalculation() {
        guard rrIntervalBuffer.count >= 2 else { return }

        // Calculate RMSSD (Root Mean Square of Successive Differences)
        var sumSquaredDiffs: Float = 0
        for i in 1..<rrIntervalBuffer.count {
            let diff = rrIntervalBuffer[i] - rrIntervalBuffer[i-1]
            sumSquaredDiffs += diff * diff
        }

        let rmssd = sqrt(sumSquaredDiffs / Float(rrIntervalBuffer.count - 1))
        smoothedHRV = smoothedHRV * (1 - config.smoothingFactor) + rmssd * config.smoothingFactor

        // Calculate coherence (simplified: based on HRV regularity)
        let mean = rrIntervalBuffer.reduce(0, +) / Float(rrIntervalBuffer.count)
        var variance: Float = 0
        for rr in rrIntervalBuffer {
            variance += (rr - mean) * (rr - mean)
        }
        variance /= Float(rrIntervalBuffer.count)

        // Coherence: inverse of coefficient of variation, normalized
        let cv = sqrt(variance) / mean
        let coherence = max(0, min(1, 1 - cv * 2))
        smoothedCoherence = smoothedCoherence * (1 - config.smoothingFactor) + coherence * config.smoothingFactor
    }

    // MARK: - Helpers

    private func estimateBreathingRate() -> Float {
        // Estimate from HRV pattern (Respiratory Sinus Arrhythmia)
        guard rrIntervalBuffer.count >= 10 else { return 12 }

        // Simple peak detection in RR intervals
        var peaks = 0
        for i in 1..<(rrIntervalBuffer.count - 1) {
            if rrIntervalBuffer[i] > rrIntervalBuffer[i-1] &&
               rrIntervalBuffer[i] > rrIntervalBuffer[i+1] {
                peaks += 1
            }
        }

        // Convert to breaths per minute
        let duration = Float(rrIntervalBuffer.count) * (rrIntervalBuffer.reduce(0, +) / Float(rrIntervalBuffer.count)) / 1000
        let breathsPerMinute = Float(peaks) / duration * 60

        return max(4, min(30, breathsPerMinute))
    }

    private func calculateMotionIntensity(_ reading: SensorReading) -> Float {
        guard let acc = reading.accelerometer else { return 0 }

        // Magnitude minus gravity (1g)
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        let activity = abs(magnitude - 1.0)

        return min(1, activity * 2)
    }

    private func calculateVariance() -> Float {
        guard sensorBuffer.count >= 5 else { return 0.5 }

        let recentCoherence = sensorBuffer.suffix(5).compactMap { _ in smoothedCoherence }
        guard !recentCoherence.isEmpty else { return 0.5 }

        let mean = recentCoherence.reduce(0, +) / Float(recentCoherence.count)
        var variance: Float = 0
        for c in recentCoherence {
            variance += (c - mean) * (c - mean)
        }

        return sqrt(variance / Float(recentCoherence.count))
    }

    private func generateSimulatedReading() -> SensorReading {
        // Generate realistic simulated sensor data
        let baseHR: Float = 72
        let hrVariation = Float.random(in: -5...5)

        // Simulate RR intervals (ms)
        let baseRR: Float = 60000 / (baseHR + hrVariation)
        let rrIntervals = (0..<3).map { _ in baseRR + Float.random(in: -50...50) }

        return SensorReading(
            source: .simulated,
            heartRate: baseHR + hrVariation,
            rrIntervals: rrIntervals,
            accelerometer: SIMD3<Float>(
                Float.random(in: -0.1...0.1),
                Float.random(in: -0.1...0.1),
                Float.random(in: 0.9...1.1)
            )
        )
    }

    private func generatePQCSignature(for action: WorldPrediction.RecommendedAction) -> Data? {
        // Placeholder for Post-Quantum Cryptographic signature
        // In production, this would use CRYSTALS-Dilithium or similar
        let actionData = "\(action.parameter):\(action.targetValue):\(Date().timeIntervalSince1970)"
        return actionData.data(using: .utf8)?.base64EncodedData()
    }
}

// MARK: - WatchOS Data Receiver

#if canImport(WatchConnectivity) && os(iOS)
extension PhysicalAIEngine: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in
                log.info("WatchConnectivity activated", category: .intelligence)
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {}

    nonisolated public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Decode sensor reading from watch
        if let reading = try? JSONDecoder().decode(SensorReading.self, from: messageData) {
            Task { @MainActor in
                self.processSensorData(reading)
            }
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle dictionary-based messages from watch
        if let hrValue = message["heartRate"] as? Double,
           let rrData = message["rrIntervals"] as? [Double] {

            let reading = SensorReading(
                source: .appleWatch,
                heartRate: Float(hrValue),
                rrIntervals: rrData.map { Float($0) }
            )

            Task { @MainActor in
                self.processSensorData(reading)
            }
        }
    }
}
#endif
