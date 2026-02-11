// EEGSensorBridge.swift
// Echoelmusic - EEG Sensor Integration Bridge
//
// Supports external EEG devices:
// - Muse 2 / Muse S (Interaxon)
// - NeuroSky MindWave
// - OpenBCI (via Bluetooth/WiFi)
// - Neurosity Crown
//
// "My knob tastes funny." - Ralph Wiggum, Neuroscientist
//
// Created 2026-02-04
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import CoreBluetooth

// MARK: - EEG Data Types

/// EEG frequency bands with power values
public struct EEGBands: Codable, Sendable, Equatable {
    /// Delta waves (0.5-4 Hz) - Deep sleep, unconscious
    public var delta: Double

    /// Theta waves (4-8 Hz) - Drowsiness, creativity, meditation
    public var theta: Double

    /// Alpha waves (8-12 Hz) - Relaxed awareness, calm focus
    public var alpha: Double

    /// Beta waves (12-30 Hz) - Active thinking, alertness
    public var beta: Double

    /// Gamma waves (30-100 Hz) - Peak awareness, cognition
    public var gamma: Double

    /// Timestamp of this reading
    public var timestamp: Date

    public init(
        delta: Double = 0,
        theta: Double = 0,
        alpha: Double = 0,
        beta: Double = 0,
        gamma: Double = 0,
        timestamp: Date = Date()
    ) {
        self.delta = delta
        self.theta = theta
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.timestamp = timestamp
    }

    /// Total power across all bands
    public var totalPower: Double {
        delta + theta + alpha + beta + gamma
    }

    /// Relative band powers (normalized to 0-1)
    public var relativePowers: (delta: Double, theta: Double, alpha: Double, beta: Double, gamma: Double) {
        let total = max(totalPower, 0.001)
        return (
            delta / total,
            theta / total,
            alpha / total,
            beta / total,
            gamma / total
        )
    }

    /// Dominant frequency band
    public var dominantBand: String {
        let bands = [
            ("Delta", delta),
            ("Theta", theta),
            ("Alpha", alpha),
            ("Beta", beta),
            ("Gamma", gamma)
        ]
        return bands.max(by: { $0.1 < $1.1 })?.0 ?? "Unknown"
    }

    /// Meditation score (theta/beta ratio) - higher = more meditative
    public var meditationScore: Double {
        guard beta > 0 else { return 0 }
        return min(theta / beta, 2.0) / 2.0  // Normalize to 0-1
    }

    /// Focus score (beta/(alpha+theta) ratio) - higher = more focused
    public var focusScore: Double {
        let relaxation = alpha + theta
        guard relaxation > 0 else { return 0 }
        return min(beta / relaxation, 2.0) / 2.0  // Normalize to 0-1
    }

    /// Flow state indicator (alpha + low beta balance)
    public var flowScore: Double {
        let relative = relativePowers
        // Flow = high alpha, moderate beta, low delta
        let alphaContribution = relative.alpha * 0.5
        let betaContribution = min(relative.beta, 0.3) * 0.3
        let thetaContribution = min(relative.theta, 0.2) * 0.2
        return alphaContribution + betaContribution + thetaContribution
    }
}

/// Raw EEG electrode data
public struct EEGRawData: Sendable {
    /// Electrode positions (standard 10-20 system)
    public enum Electrode: String, CaseIterable, Sendable {
        case fp1 = "FP1"  // Left forehead
        case fp2 = "FP2"  // Right forehead
        case tp9 = "TP9"  // Left ear (Muse)
        case tp10 = "TP10" // Right ear (Muse)
        case af7 = "AF7"  // Left front (Muse)
        case af8 = "AF8"  // Right front (Muse)
        case o1 = "O1"    // Left occipital
        case o2 = "O2"    // Right occipital
    }

    public var electrode: Electrode
    public var values: [Double]  // Raw microvolt samples
    public var sampleRate: Int   // Hz (typically 256)
    public var timestamp: Date

    public init(electrode: Electrode, values: [Double], sampleRate: Int = 256, timestamp: Date = Date()) {
        self.electrode = electrode
        self.values = values
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }
}

/// EEG device connection state
public enum EEGConnectionState: String, Sendable {
    case disconnected
    case scanning
    case connecting
    case connected
    case streaming
    case error
}

/// Supported EEG device types
public enum EEGDeviceType: String, CaseIterable, Sendable {
    case muse2 = "Muse 2"
    case museS = "Muse S"
    case neurosky = "NeuroSky MindWave"
    case openBCI = "OpenBCI"
    case neurosity = "Neurosity Crown"
    case simulator = "Simulator"

    public var electrodeCount: Int {
        switch self {
        case .muse2, .museS: return 4
        case .neurosky: return 1
        case .openBCI: return 8
        case .neurosity: return 8
        case .simulator: return 4
        }
    }

    public var sampleRate: Int {
        switch self {
        case .muse2, .museS: return 256
        case .neurosky: return 512
        case .openBCI: return 250
        case .neurosity: return 256
        case .simulator: return 256
        }
    }

    public var bluetoothServiceUUID: String? {
        switch self {
        case .muse2, .museS: return "0000FE8D-0000-1000-8000-00805F9B34FB"
        case .neurosky: return "0000FFE0-0000-1000-8000-00805F9B34FB"
        default: return nil
        }
    }
}

// MARK: - EEG Delegate Protocol

/// Protocol for receiving EEG data updates
public protocol EEGSensorDelegate: AnyObject {
    func eegSensor(_ sensor: EEGSensorBridge, didUpdateBands bands: EEGBands)
    func eegSensor(_ sensor: EEGSensorBridge, didUpdateRawData data: EEGRawData)
    func eegSensor(_ sensor: EEGSensorBridge, didChangeState state: EEGConnectionState)
    func eegSensor(_ sensor: EEGSensorBridge, didDetectArtifact type: String)
}

// Default implementations
public extension EEGSensorDelegate {
    func eegSensor(_ sensor: EEGSensorBridge, didUpdateBands bands: EEGBands) {}
    func eegSensor(_ sensor: EEGSensorBridge, didUpdateRawData data: EEGRawData) {}
    func eegSensor(_ sensor: EEGSensorBridge, didChangeState state: EEGConnectionState) {}
    func eegSensor(_ sensor: EEGSensorBridge, didDetectArtifact type: String) {}
}

// MARK: - EEG Sensor Bridge

/// Bridge for connecting to external EEG devices
@MainActor
public final class EEGSensorBridge: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = EEGSensorBridge()

    // MARK: - Published State

    @Published public private(set) var connectionState: EEGConnectionState = .disconnected
    @Published public private(set) var connectedDevice: EEGDeviceType?
    @Published public private(set) var currentBands: EEGBands = EEGBands()
    @Published public private(set) var signalQuality: Double = 0.0  // 0-1
    @Published public private(set) var isArtifactPresent: Bool = false
    @Published public private(set) var errorMessage: String?

    // Derived metrics
    @Published public private(set) var meditationScore: Double = 0.0
    @Published public private(set) var focusScore: Double = 0.0
    @Published public private(set) var flowScore: Double = 0.0

    // MARK: - Delegate

    public weak var delegate: EEGSensorDelegate?

    // MARK: - Callbacks

    public var onBandsUpdate: ((EEGBands) -> Void)?
    public var onStateChange: ((EEGConnectionState) -> Void)?

    // MARK: - Private Properties

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var simulationTimer: Timer?

    // Band history for smoothing
    private var bandHistory: [EEGBands] = []
    private let historySize = 10

    // MARK: - Health Disclaimer

    public static let disclaimer = """
    ============================================================================
    IMPORTANT: NOT A MEDICAL DEVICE
    ============================================================================

    EEG data in Echoelmusic is for CREATIVE and INFORMATIONAL purposes only.

    - EEG readings from consumer devices may NOT be accurate
    - "Meditation" and "Focus" scores are creative interpretations
    - NOT intended for diagnosis or treatment of any condition
    - NOT a substitute for medical EEG or professional care

    If you have neurological concerns, consult a healthcare provider.

    ============================================================================
    """

    // MARK: - Initialization

    private override init() {
        super.init()
        log.biofeedback("EEGSensorBridge initialized")
    }

    // MARK: - Device Discovery

    /// Start scanning for EEG devices
    public func startScanning() {
        connectionState = .scanning

        // Initialize Bluetooth
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        // If already powered on, start scan
        if centralManager?.state == .poweredOn {
            startBluetoothScan()
        }

        log.biofeedback("Started EEG device scanning")
    }

    /// Stop scanning
    public func stopScanning() {
        centralManager?.stopScan()
        connectionState = .disconnected
    }

    private func startBluetoothScan() {
        // Scan for known EEG device services
        let serviceUUIDs = EEGDeviceType.allCases.compactMap { type -> CBUUID? in
            guard let uuidString = type.bluetoothServiceUUID else { return nil }
            return CBUUID(string: uuidString)
        }

        centralManager?.scanForPeripherals(
            withServices: serviceUUIDs.isEmpty ? nil : serviceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    // MARK: - Connection

    /// Connect to a discovered device
    public func connect(to peripheral: CBPeripheral, type: EEGDeviceType) {
        connectionState = .connecting
        connectedDevice = type

        centralManager?.connect(peripheral, options: nil)
        connectedPeripheral = peripheral

        log.biofeedback("Connecting to \(type.rawValue)")
    }

    /// Disconnect from current device
    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }

        stopSimulation()
        connectedPeripheral = nil
        connectedDevice = nil
        connectionState = .disconnected

        log.biofeedback("Disconnected from EEG device")
    }

    // MARK: - Simulation Mode

    /// Start simulated EEG data (for testing/demo)
    public func startSimulation() {
        connectedDevice = .simulator
        connectionState = .streaming

        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.generateSimulatedData()
            }
        }

        log.biofeedback("Started EEG simulation")
        log.biofeedback(Self.disclaimer)
    }

    /// Stop simulation
    public func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil

        if connectedDevice == .simulator {
            connectedDevice = nil
            connectionState = .disconnected
        }
    }

    private func generateSimulatedData() {
        let time = Date().timeIntervalSinceReferenceDate

        // Generate realistic-ish EEG band powers
        // Based on typical awake, relaxed state
        let bands = EEGBands(
            delta: 10 + sin(time * 0.1) * 3 + Double.random(in: -2...2),
            theta: 15 + sin(time * 0.2) * 5 + Double.random(in: -3...3),
            alpha: 25 + sin(time * 0.15) * 8 + Double.random(in: -4...4),
            beta: 20 + sin(time * 0.3) * 6 + Double.random(in: -3...3),
            gamma: 5 + sin(time * 0.5) * 2 + Double.random(in: -1...1),
            timestamp: Date()
        )

        processNewBands(bands)

        // Occasionally simulate artifacts (eye blinks, muscle tension)
        if Double.random(in: 0...1) < 0.05 {
            isArtifactPresent = true
            delegate?.eegSensor(self, didDetectArtifact: "Eye Blink")
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    self.isArtifactPresent = false
                }
            }
        }
    }

    // MARK: - Data Processing

    private func processNewBands(_ bands: EEGBands) {
        // Add to history for smoothing
        bandHistory.append(bands)
        if bandHistory.count > historySize {
            bandHistory.removeFirst()
        }

        // Smooth bands using moving average
        let smoothedBands = smoothBands()
        currentBands = smoothedBands

        // Update derived metrics
        meditationScore = smoothedBands.meditationScore
        focusScore = smoothedBands.focusScore
        flowScore = smoothedBands.flowScore

        // Signal quality estimation (based on variance)
        signalQuality = estimateSignalQuality()

        // Notify
        delegate?.eegSensor(self, didUpdateBands: smoothedBands)
        onBandsUpdate?(smoothedBands)
    }

    private func smoothBands() -> EEGBands {
        guard !bandHistory.isEmpty else { return EEGBands() }

        let count = Double(bandHistory.count)
        return EEGBands(
            delta: bandHistory.map(\.delta).reduce(0, +) / count,
            theta: bandHistory.map(\.theta).reduce(0, +) / count,
            alpha: bandHistory.map(\.alpha).reduce(0, +) / count,
            beta: bandHistory.map(\.beta).reduce(0, +) / count,
            gamma: bandHistory.map(\.gamma).reduce(0, +) / count,
            timestamp: Date()
        )
    }

    private func estimateSignalQuality() -> Double {
        guard bandHistory.count >= 3 else { return 0.5 }

        // Calculate variance in recent readings
        let recentAlpha = bandHistory.suffix(3).map(\.alpha)
        let mean = recentAlpha.reduce(0, +) / Double(recentAlpha.count)
        let variance = recentAlpha.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentAlpha.count)

        // Lower variance = better signal (less noise)
        // Normalize: variance < 10 = good, > 50 = poor
        let normalizedVariance = min(variance / 50.0, 1.0)
        return 1.0 - normalizedVariance
    }

    // MARK: - State Updates

    private func updateState(_ state: EEGConnectionState) {
        connectionState = state
        delegate?.eegSensor(self, didChangeState: state)
        onStateChange?(state)
    }
}

// MARK: - CBCentralManagerDelegate

extension EEGSensorBridge: CBCentralManagerDelegate {

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if connectionState == .scanning {
                    startBluetoothScan()
                }
            case .poweredOff:
                errorMessage = "Bluetooth is turned off"
                updateState(.error)
            case .unauthorized:
                errorMessage = "Bluetooth permission denied"
                updateState(.error)
            case .unsupported:
                errorMessage = "Bluetooth not supported on this device"
                updateState(.error)
            default:
                break
            }
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Identify device type from advertisement
        let name = peripheral.name ?? ""
        var deviceType: EEGDeviceType?

        if name.contains("Muse") {
            deviceType = name.contains("S") ? .museS : .muse2
        } else if name.contains("MindWave") || name.contains("NeuroSky") {
            deviceType = .neurosky
        } else if name.contains("OpenBCI") {
            deviceType = .openBCI
        } else if name.contains("Crown") || name.contains("Neurosity") {
            deviceType = .neurosity
        }

        if let type = deviceType {
            Task { @MainActor in
                log.biofeedback("Discovered EEG device: \(name) (\(type.rawValue))")
                // In production: Add to discovered devices list for user selection
                // For now: Auto-connect to first found device
                self.connect(to: peripheral, type: type)
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            updateState(.connected)
            peripheral.delegate = self
            peripheral.discoverServices(nil)
            log.biofeedback("Connected to EEG device")
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            errorMessage = error?.localizedDescription ?? "Connection failed"
            updateState(.error)
            log.biofeedback("EEG connection failed: \(errorMessage ?? "unknown")")
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            updateState(.disconnected)
            connectedPeripheral = nil
            connectedDevice = nil
            log.biofeedback("EEG device disconnected")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension EEGSensorBridge: CBPeripheralDelegate {

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Subscribe to notify characteristics for streaming data
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        Task { @MainActor in
            updateState(.streaming)
        }
    }

    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }

        // Parse EEG data based on device type
        // This is device-specific and would need actual protocol parsing
        // For now, this is a placeholder that would be implemented per device

        Task { @MainActor in
            if let type = connectedDevice {
                parseEEGData(data, for: type)
            }
        }
    }

    @MainActor
    private func parseEEGData(_ data: Data, for deviceType: EEGDeviceType) {
        // Device-specific parsing would go here
        // Each device has its own data format

        switch deviceType {
        case .muse2, .museS:
            // Muse uses a specific protocol with multiple data types
            // Reference: https://mind-monitor.com/FAQ.php
            parseMuseData(data)

        case .neurosky:
            // NeuroSky uses ThinkGear protocol
            parseNeuroSkyData(data)

        default:
            // Generic parsing or simulation fallback
            break
        }
    }

    @MainActor
    private func parseMuseData(_ data: Data) {
        // Muse data format (simplified):
        // Packet types include: EEG, accelerometer, gyroscope, PPG
        // EEG packets contain 12-bit samples from 4 channels

        // This would need the full Muse SDK or reverse-engineered protocol
        // For now, generate simulated data when connected

        // Placeholder: Use simulation when connected to real device
        // In production: Implement actual Muse protocol parsing
        generateSimulatedData()
    }

    @MainActor
    private func parseNeuroSkyData(_ data: Data) {
        // NeuroSky ThinkGear protocol parsing
        // Reference: http://developer.neurosky.com/docs/doku.php

        // Placeholder for actual parsing
        generateSimulatedData()
    }
}

// MARK: - SwiftUI View

/// EEG visualization view
@MainActor
public struct EEGVisualizationView: View {
    @ObservedObject var bridge: EEGSensorBridge

    public init(bridge: EEGSensorBridge = .shared) {
        self.bridge = bridge
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Connection status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(bridge.connectionState.rawValue.capitalized)
                    .font(.caption)

                Spacer()

                if let device = bridge.connectedDevice {
                    Text(device.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Band powers visualization
            VStack(spacing: 8) {
                bandRow(label: "Delta", value: bridge.currentBands.delta, color: .purple)
                bandRow(label: "Theta", value: bridge.currentBands.theta, color: .blue)
                bandRow(label: "Alpha", value: bridge.currentBands.alpha, color: .green)
                bandRow(label: "Beta", value: bridge.currentBands.beta, color: .yellow)
                bandRow(label: "Gamma", value: bridge.currentBands.gamma, color: .orange)
            }

            Divider()

            // Derived scores
            HStack(spacing: 20) {
                scoreView(label: "Meditation", value: bridge.meditationScore, color: .purple)
                scoreView(label: "Focus", value: bridge.focusScore, color: .blue)
                scoreView(label: "Flow", value: bridge.flowScore, color: .green)
            }

            // Signal quality
            HStack {
                Text("Signal Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                signalQualityIndicator
            }

            // Controls
            HStack {
                if bridge.connectionState == .disconnected {
                    Button("Start Simulation") {
                        bridge.startSimulation()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Scan Devices") {
                        bridge.startScanning()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Disconnect") {
                        bridge.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            // Disclaimer
            Text("For creative/informational purposes only. Not a medical device.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func bandRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / 50.0, 1.0))
                }
            }
            .frame(height: 16)

            Text("\(Int(value))")
                .font(.caption.monospacedDigit())
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func scoreView(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value * 100))")
                    .font(.caption.bold())
            }
            .frame(width: 50, height: 50)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var signalQualityIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bridge.signalQuality > Double(i) / 5.0 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 12 + CGFloat(i * 3))
            }
        }
    }

    private var statusColor: Color {
        switch bridge.connectionState {
        case .disconnected: return .gray
        case .scanning: return .yellow
        case .connecting: return .orange
        case .connected, .streaming: return .green
        case .error: return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("EEG Visualization") {
    EEGVisualizationView()
}
#endif
