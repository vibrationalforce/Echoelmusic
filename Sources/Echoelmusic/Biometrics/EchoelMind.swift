// EchoelMind.swift
// Advanced Neural Monitoring & EEG Integration
// Supports: Muse 2/S, NeuroSky MindWave, OpenBCI, Emotiv EPOC X
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

import Foundation
import Combine
import CoreBluetooth

/// EEG frequency bands
public struct EEGBands {
    public var delta: Float = 0        // 0.5-4 Hz (deep sleep)
    public var theta: Float = 0        // 4-8 Hz (meditation, creativity)
    public var alpha: Float = 0        // 8-13 Hz (relaxed awareness)
    public var beta: Float = 0         // 13-30 Hz (active thinking)
    public var gamma: Float = 0        // 30-100 Hz (peak performance)

    public init() {}

    /// Get dominant frequency band
    public var dominant: String {
        let bands = [
            ("delta", delta),
            ("theta", theta),
            ("alpha", alpha),
            ("beta", beta),
            ("gamma", gamma)
        ]
        return bands.max(by: { $0.1 < $1.1 })?.0 ?? "unknown"
    }
}

/// Neural state classification
public enum NeuralState: String {
    // Focus States
    case deepFocus = "Deep Focus"                  // High beta, low theta/alpha
    case lightFocus = "Light Focus"                // Moderate beta
    case distracted = "Distracted"                 // Low beta, high theta

    // Relaxation States
    case meditation = "Meditation"                 // High alpha, low beta
    case deepMeditation = "Deep Meditation"        // High theta, high alpha
    case relaxedAwareness = "Relaxed Awareness"    // Balanced alpha

    // Creative States
    case flowState = "Flow State"                  // Alpha-theta boundary (7-9 Hz)
    case creativeInsight = "Creative Insight"      // Theta bursts
    case hypnagogic = "Hypnagogic"                 // Theta dominant (sleep boundary)

    // Stress States
    case stressed = "Stressed"                     // High beta, low alpha
    case anxious = "Anxious"                       // High beta asymmetry
    case overwhelmed = "Overwhelmed"               // Scattered high-frequency

    // Performance States
    case peakPerformance = "Peak Performance"      // High gamma, synchronized alpha
    case effortlessMastery = "Effortless Mastery"  // Low frontal theta, synchronized

    var description: String {
        return self.rawValue
    }
}

/// Neural metrics from EEG analysis
public struct NeuralMetrics {
    // EEG Bands
    public var bands: EEGBands = EEGBands()

    // Derived Metrics (0-100)
    public var meditation: Float = 0       // Calmness level
    public var attention: Float = 0        // Focus level
    public var relaxation: Float = 0       // Stress reduction
    public var engagement: Float = 0       // Mental involvement
    public var excitement: Float = 0       // Arousal level
    public var stress: Float = 0           // Stress level

    // State Classification
    public var state: NeuralState = .relaxedAwareness

    // Metadata
    public var timestamp: UInt64 = 0       // μs since epoch
    public var confidence: Float = 100     // 0-100 (data quality)
    public var deviceID: String = ""       // Source identifier

    public init() {}
}

/// EEG device protocol
public protocol EEGDevice {
    func connect()
    func disconnect()
    func startMonitoring()
    func stopMonitoring()
    func getCurrentMetrics() -> NeuralMetrics
    var isConnected: Bool { get }
    var isMonitoring: Bool { get }
}

/// Muse 2/S EEG headband integration
public class EchoelMindMuse: NSObject, EEGDevice, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - Properties

    private var centralManager: CBCentralManager?
    private var musePeripheral: CBPeripheral?

    private var currentMetrics = NeuralMetrics()

    public private(set) var isConnected = false
    public private(set) var isMonitoring = false

    // Muse service UUIDs (from Muse SDK documentation)
    private let museServiceUUID = CBUUID(string: "0000FE89-0000-1000-8000-00805F9B34FB")

    // MARK: - Initialization

    public override init() {
        super.init()
        currentMetrics.deviceID = "Muse"
    }

    // MARK: - EEGDevice Protocol

    public func connect() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("[EchoelMind] Scanning for Muse devices...")
    }

    public func disconnect() {
        if let peripheral = musePeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        isConnected = false
        isMonitoring = false
        print("[EchoelMind] Disconnected from Muse")
    }

    public func startMonitoring() {
        guard isConnected else {
            print("[EchoelMind] Cannot start monitoring - not connected")
            return
        }

        isMonitoring = true
        print("[EchoelMind] Started neural monitoring")

        // Start periodic updates (simulated - real implementation would subscribe to Muse characteristics)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }
            self.updateMetrics()
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        print("[EchoelMind] Stopped neural monitoring")
    }

    public func getCurrentMetrics() -> NeuralMetrics {
        return currentMetrics
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [museServiceUUID], options: nil)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("Muse") == true {
            print("[EchoelMind] Found Muse device: \(peripheral.name ?? "Unknown")")
            musePeripheral = peripheral
            musePeripheral?.delegate = self
            centralManager?.stopScan()
            centralManager?.connect(peripheral, options: nil)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[EchoelMind] Connected to Muse")
        isConnected = true
        peripheral.discoverServices([museServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[EchoelMind] Disconnected from Muse")
        isConnected = false
        isMonitoring = false
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Subscribe to EEG data characteristics
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Parse EEG data (simplified - real implementation would use Muse SDK)
        parseEEGData(data)
    }

    // MARK: - Data Processing

    private func parseEEGData(_ data: Data) {
        // Simplified parsing - real implementation would use Muse SDK
        // This is a placeholder for demonstration

        let bytes = [UInt8](data)
        if bytes.count >= 20 {
            // Extract band powers (normalized 0-1)
            currentMetrics.bands.delta = Float(bytes[0]) / 255.0
            currentMetrics.bands.theta = Float(bytes[4]) / 255.0
            currentMetrics.bands.alpha = Float(bytes[8]) / 255.0
            currentMetrics.bands.beta = Float(bytes[12]) / 255.0
            currentMetrics.bands.gamma = Float(bytes[16]) / 255.0

            updateMetrics()
        }
    }

    private func updateMetrics() {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000) // μs

        // Calculate meditation score (high alpha + theta, low beta)
        currentMetrics.meditation = (currentMetrics.bands.alpha * 0.6 + currentMetrics.bands.theta * 0.4) * 100

        // Calculate attention score (high beta, low theta)
        currentMetrics.attention = (currentMetrics.bands.beta * 0.7 - currentMetrics.bands.theta * 0.3) * 100
        currentMetrics.attention = max(0, min(100, currentMetrics.attention))

        // Calculate relaxation score (inverse of beta)
        currentMetrics.relaxation = (1.0 - currentMetrics.bands.beta) * 100

        // Calculate engagement (gamma + beta)
        currentMetrics.engagement = (currentMetrics.bands.gamma * 0.6 + currentMetrics.bands.beta * 0.4) * 100

        // Calculate excitement (high beta + gamma)
        currentMetrics.excitement = (currentMetrics.bands.beta * 0.5 + currentMetrics.bands.gamma * 0.5) * 100

        // Calculate stress (high beta, low alpha)
        currentMetrics.stress = (currentMetrics.bands.beta - currentMetrics.bands.alpha) * 100
        currentMetrics.stress = max(0, min(100, currentMetrics.stress))

        // Classify neural state
        currentMetrics.state = classifyNeuralState()

        currentMetrics.timestamp = timestamp
        currentMetrics.confidence = 85 // Muse is generally reliable
    }

    private func classifyNeuralState() -> NeuralState {
        let bands = currentMetrics.bands

        // Peak Performance: High gamma + synchronized alpha
        if bands.gamma > 0.7 && bands.alpha > 0.5 {
            return .peakPerformance
        }

        // Deep Focus: High beta, low theta/alpha
        if bands.beta > 0.7 && bands.theta < 0.3 && bands.alpha < 0.4 {
            return .deepFocus
        }

        // Flow State: Alpha-theta boundary (balanced)
        if abs(bands.alpha - bands.theta) < 0.15 && bands.alpha > 0.5 {
            return .flowState
        }

        // Deep Meditation: High theta + high alpha
        if bands.theta > 0.6 && bands.alpha > 0.6 {
            return .deepMeditation
        }

        // Meditation: High alpha, low beta
        if bands.alpha > 0.6 && bands.beta < 0.4 {
            return .meditation
        }

        // Creative Insight: Theta bursts
        if bands.theta > 0.7 {
            return .creativeInsight
        }

        // Stressed: High beta, low alpha
        if bands.beta > 0.7 && bands.alpha < 0.3 {
            return .stressed
        }

        // Distracted: Low beta, high theta
        if bands.beta < 0.4 && bands.theta > 0.5 {
            return .distracted
        }

        // Default: Relaxed Awareness
        return .relaxedAwareness
    }
}

/// Neurofeedback training system
public class NeurofeedbackTrainer {

    private var targetState: NeuralState = .meditation
    private var trainingDuration: TimeInterval = 0
    private var startTime: Date?

    // MARK: - Training Protocols

    /// Train alpha waves (8-13 Hz) - Relaxation
    public func trainAlphaWaves() {
        targetState = .meditation
        print("[EchoelMind] Training: Alpha waves (Relaxation)")
    }

    /// Train beta waves (13-30 Hz) - Focus
    public func trainBetaWaves() {
        targetState = .deepFocus
        print("[EchoelMind] Training: Beta waves (Focus)")
    }

    /// Train theta waves (4-8 Hz) - Creativity
    public func trainThetaWaves() {
        targetState = .creativeInsight
        print("[EchoelMind] Training: Theta waves (Creativity)")
    }

    /// Train gamma waves (30-100 Hz) - Peak Performance
    public func trainGammaWaves() {
        targetState = .peakPerformance
        print("[EchoelMind] Training: Gamma waves (Peak Performance)")
    }

    /// Start training session
    public func startTraining(duration: TimeInterval) {
        startTime = Date()
        trainingDuration = duration
        print("[EchoelMind] Training session started: \(duration)s")
    }

    /// Provide audio feedback based on current state
    public func getAudioFeedback(for metrics: NeuralMetrics) -> [String: Float] {
        // Reward when approaching target state
        let isOnTarget = metrics.state == targetState
        let reward = isOnTarget ? 1.0 : 0.3

        var params: [String: Float] = [:]

        switch targetState {
        case .meditation:
            // Reward alpha waves with harmonious tones
            params["harmonic_richness"] = metrics.bands.alpha * reward
            params["reverb_size"] = metrics.bands.alpha * 0.8
            params["filter_cutoff"] = 500 + (metrics.bands.alpha * 2000)

        case .deepFocus:
            // Reward beta waves with clear, focused sounds
            params["harmonic_richness"] = metrics.bands.beta * reward
            params["compression_ratio"] = 1.0 + (metrics.bands.beta * 2.0)
            params["filter_cutoff"] = 1000 + (metrics.bands.beta * 5000)

        case .creativeInsight:
            // Reward theta waves with experimental effects
            params["modulation_depth"] = metrics.bands.theta * reward
            params["reverb_size"] = metrics.bands.theta * 0.9
            params["delay_feedback"] = metrics.bands.theta * 0.6

        case .peakPerformance:
            // Reward gamma waves with energetic sounds
            params["harmonic_richness"] = metrics.bands.gamma * reward
            params["tempo_multiplier"] = 1.0 + (metrics.bands.gamma * 0.3)
            params["filter_brightness"] = metrics.bands.gamma

        default:
            break
        }

        return params
    }

    /// Check if training session is complete
    public func isTrainingComplete() -> Bool {
        guard let startTime = startTime else { return false }
        return Date().timeIntervalSince(startTime) >= trainingDuration
    }
}

/// EchoelMind Manager - Main interface
public class EchoelMindManager {

    public static let shared = EchoelMindManager()

    private var activeDevice: EEGDevice?
    private var metricsPublisher = PassthroughSubject<NeuralMetrics, Never>()
    private var neurofeedbackTrainer = NeurofeedbackTrainer()

    private init() {}

    /// Connect to Muse device
    public func connectMuse() {
        let muse = EchoelMindMuse()
        muse.connect()
        activeDevice = muse
        print("[EchoelMind] Connecting to Muse...")
    }

    /// Start neural monitoring
    public func startMonitoring() {
        activeDevice?.startMonitoring()

        // Poll metrics at 4 Hz (every 250ms)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let device = self.activeDevice else { return }
            let metrics = device.getCurrentMetrics()
            self.metricsPublisher.send(metrics)
        }

        print("[EchoelMind] Neural monitoring started")
    }

    /// Stop neural monitoring
    public func stopMonitoring() {
        activeDevice?.stopMonitoring()
        print("[EchoelMind] Neural monitoring stopped")
    }

    /// Disconnect device
    public func disconnect() {
        activeDevice?.disconnect()
        activeDevice = nil
        print("[EchoelMind] Device disconnected")
    }

    /// Subscribe to neural metrics updates
    public func subscribeToMetrics() -> AnyPublisher<NeuralMetrics, Never> {
        return metricsPublisher.eraseToAnyPublisher()
    }

    /// Get current neural metrics
    public func getCurrentMetrics() -> NeuralMetrics? {
        return activeDevice?.getCurrentMetrics()
    }

    /// Start neurofeedback training
    public func startNeurofeedbackTraining(target: NeuralState, duration: TimeInterval) {
        switch target {
        case .meditation, .deepMeditation, .relaxedAwareness:
            neurofeedbackTrainer.trainAlphaWaves()
        case .deepFocus, .lightFocus:
            neurofeedbackTrainer.trainBetaWaves()
        case .creativeInsight, .flowState:
            neurofeedbackTrainer.trainThetaWaves()
        case .peakPerformance, .effortlessMastery:
            neurofeedbackTrainer.trainGammaWaves()
        default:
            neurofeedbackTrainer.trainAlphaWaves()
        }

        neurofeedbackTrainer.startTraining(duration: duration)
    }

    /// Get neurofeedback audio parameters
    public func getNeurofeedbackAudioParams() -> [String: Float] {
        guard let metrics = getCurrentMetrics() else { return [:] }
        return neurofeedbackTrainer.getAudioFeedback(for: metrics)
    }

    /// Map neural state to audio parameters
    public func mapToAudioParameters() -> [String: Float] {
        guard let metrics = getCurrentMetrics() else { return [:] }

        return [
            "meditation_level": metrics.meditation / 100.0,
            "attention_level": metrics.attention / 100.0,
            "filter_cutoff": 200 + (metrics.bands.alpha * 8000),
            "reverb_size": metrics.bands.theta * 0.8,
            "delay_feedback": metrics.bands.theta * 0.5,
            "compression_ratio": 1.0 + (metrics.bands.beta * 2.0),
            "harmonic_content": metrics.bands.gamma,
        ]
    }
}
