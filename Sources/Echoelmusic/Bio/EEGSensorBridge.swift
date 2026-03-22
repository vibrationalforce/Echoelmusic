#if canImport(CoreBluetooth)
//
//  EEGSensorBridge.swift
//  Echoelmusic — EEG Sensor Integration
//
//  CoreBluetooth bridge for consumer EEG headbands:
//  - Muse 2 / Muse S (Interaxon)
//  - NeuroSky MindWave
//  - OpenBCI Ganglion/Cyton (BLE variant)
//
//  Extracts spectral band powers via vDSP FFT:
//  Delta (0.5-4Hz), Theta (4-8Hz), Alpha (8-13Hz),
//  Beta (13-30Hz), Gamma (30-100Hz)
//
//  IMPORTANT: Not a medical device. Data for self-observation only.
//

import Foundation
import CoreBluetooth
import Accelerate
#if canImport(Observation)
import Observation
#endif

// MARK: - EEG Data Types

/// Spectral band power values extracted from raw EEG via FFT
public struct EEGBandPowers: Sendable, Equatable {
    /// Delta (0.5-4 Hz) — deep sleep, unconscious processing
    public var delta: Float = 0.0
    /// Theta (4-8 Hz) — drowsiness, meditation, memory
    public var theta: Float = 0.0
    /// Alpha (8-13 Hz) — relaxed awareness, eyes closed
    public var alpha: Float = 0.0
    /// Beta (13-30 Hz) — active thinking, focus, anxiety
    public var beta: Float = 0.0
    /// Gamma (30-100 Hz) — higher cognitive functions, perception
    public var gamma: Float = 0.0

    /// Total power across all bands
    public var totalPower: Float {
        delta + theta + alpha + beta + gamma
    }

    /// Relative band powers normalized to [0-1]
    public var relativeAlpha: Float {
        guard totalPower > 0 else { return 0 }
        return alpha / totalPower
    }

    public var relativeBeta: Float {
        guard totalPower > 0 else { return 0 }
        return beta / totalPower
    }

    public var relativeTheta: Float {
        guard totalPower > 0 else { return 0 }
        return theta / totalPower
    }
}

/// Current EEG state snapshot
public struct EEGSnapshot: Sendable {
    /// Spectral band powers from FFT
    public var bandPowers: EEGBandPowers = EEGBandPowers()
    /// Attention score [0-1] derived from beta/theta ratio
    public var attentionScore: Float = 0.0
    /// Meditation score [0-1] derived from alpha dominance
    public var meditationScore: Float = 0.0
    /// Raw signal quality [0-1] (1 = excellent contact)
    public var rawSignalQuality: Float = 0.0
    /// Number of active channels
    public var activeChannels: Int = 0
    /// Sample rate of connected device
    public var sampleRate: Double = 256.0
    /// Timestamp of last update
    public var timestamp: Date = Date()
}

/// Known EEG device types
public enum EEGDeviceType: String, Sendable, CaseIterable {
    case muse2 = "Muse 2"
    case museS = "Muse S"
    case neurosky = "NeuroSky MindWave"
    case openBCI = "OpenBCI Ganglion"
    case unknown = "Unknown EEG"
}

/// Connection state for EEG device
public enum EEGConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case connecting = "Connecting"
    case connected = "Connected"
    case streaming = "Streaming"
}

// MARK: - Known BLE Service/Characteristic UUIDs

private enum EEGServiceUUIDs {
    /// Muse 2 / Muse S primary service
    nonisolated(unsafe) static let museControl = CBUUID(string: "0000FE8D-0000-1000-8000-00805F9B34FB")
    /// NeuroSky TGAM module
    nonisolated(unsafe) static let neuroskyData = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    /// OpenBCI Ganglion BLE service
    nonisolated(unsafe) static let openBCIGanglion = CBUUID(string: "FE84")

    nonisolated(unsafe) static let allServices: [CBUUID] = [museControl, neuroskyData, openBCIGanglion]
}

private enum EEGCharacteristicUUIDs {
    /// Muse data stream characteristic
    nonisolated(unsafe) static let museEEGData = CBUUID(string: "273E0003-4C4D-454D-96BE-F03BAC821358")
    /// Muse control characteristic (start/stop streaming)
    nonisolated(unsafe) static let museControl = CBUUID(string: "273E0001-4C4D-454D-96BE-F03BAC821358")
    /// NeuroSky raw data
    nonisolated(unsafe) static let neuroskyRawData = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    /// OpenBCI Ganglion data
    nonisolated(unsafe) static let openBCIData = CBUUID(string: "2D30C082-F39F-4CE6-923F-3484EA480596")
}

// MARK: - Thread-Safe Circular Buffer

/// Lock-free circular buffer for raw EEG samples (single-producer, single-consumer)
private final class EEGCircularBuffer: @unchecked Sendable {
    private let capacity: Int
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var fillCount: Int = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0.0, count: capacity)
    }

    /// Write a single sample
    func write(_ sample: Float) {
        buffer[writeIndex % capacity] = sample
        writeIndex += 1
        if fillCount < capacity {
            fillCount += 1
        }
    }

    /// Write multiple samples
    func write(_ samples: [Float]) {
        for sample in samples {
            write(sample)
        }
    }

    /// Read the most recent `count` samples in order
    func readRecent(_ count: Int) -> [Float] {
        let available = min(count, fillCount)
        guard available > 0 else { return [] }
        var result = [Float](repeating: 0.0, count: available)
        let startIdx = writeIndex - available
        for i in 0..<available {
            let idx = ((startIdx + i) % capacity + capacity) % capacity
            result[i] = buffer[idx]
        }
        return result
    }

    /// Number of samples available
    var count: Int { fillCount }

    /// Reset buffer
    func reset() {
        writeIndex = 0
        fillCount = 0
        buffer = [Float](repeating: 0.0, count: capacity)
    }
}

// MARK: - EEGSensorBridge

/// CoreBluetooth bridge for consumer EEG headbands with real-time spectral analysis
@preconcurrency @MainActor
@Observable
public final class EEGSensorBridge: NSObject {

    // MARK: - Singleton

    @MainActor public static let shared = EEGSensorBridge()

    // MARK: - Observable State

    public var snapshot: EEGSnapshot = EEGSnapshot()
    public var connectionState: EEGConnectionState = .disconnected
    public var deviceType: EEGDeviceType = .unknown
    public var deviceName: String = ""
    public var isStreaming: Bool = false

    /// Discovered EEG peripherals during scan
    public var discoveredDevices: [(name: String, peripheral: CBPeripheral)] = []

    // MARK: - FFT Configuration

    /// FFT length — must be power of 2. 256 samples at 256Hz = 1 second window
    private let fftLength: Int = 256
    /// Overlap for sliding window (75%)
    private let fftOverlap: Int = 192
    /// Hann window for spectral leakage reduction
    private var hannWindow: [Float] = []

    // MARK: - vDSP FFT

    private var fftSetup: vDSP_DFT_Setup?
    private var fftInputReal: [Float] = []
    private var fftInputImag: [Float] = []
    private var fftOutputReal: [Float] = []
    private var fftOutputImag: [Float] = []

    // MARK: - Raw Data Buffer

    /// Circular buffer: 256Hz * 10s = 2560 samples
    private let rawBuffer = EEGCircularBuffer(capacity: 2560)
    private var lastFFTSampleCount: Int = 0

    // MARK: - CoreBluetooth

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?

    // MARK: - Smoothing

    private let smoothingAlpha: Float = 0.2

    // MARK: - Init

    private override init() {
        super.init()
        setupFFT()
        setupHannWindow()
    }

    // MARK: - FFT Setup

    private func setupFFT() {
        let halfN = fftLength / 2
        fftInputReal = [Float](repeating: 0.0, count: halfN)
        fftInputImag = [Float](repeating: 0.0, count: halfN)
        fftOutputReal = [Float](repeating: 0.0, count: halfN)
        fftOutputImag = [Float](repeating: 0.0, count: halfN)

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(halfN),
            .FORWARD
        )

        if fftSetup == nil {
            log.log(.error, category: .biofeedback, "EEG: Failed to create vDSP DFT setup")
        }
    }

    private func setupHannWindow() {
        hannWindow = [Float](repeating: 0.0, count: fftLength)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Scanning

    /// Start scanning for EEG devices
    public func startScanning() {
        guard connectionState == .disconnected else { return }
        discoveredDevices.removeAll()
        connectionState = .scanning

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            beginScan()
        }

        log.log(.info, category: .biofeedback, "EEG: Starting BLE scan for EEG devices")
    }

    /// Stop scanning
    public func stopScanning() {
        centralManager?.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
        log.log(.info, category: .biofeedback, "EEG: Stopped BLE scan")
    }

    private func beginScan() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: EEGServiceUUIDs.allServices,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    // MARK: - Connection

    /// Connect to a discovered EEG peripheral
    public func connect(to peripheral: CBPeripheral) {
        guard connectionState == .scanning || connectionState == .disconnected else { return }
        centralManager?.stopScan()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
        log.log(.info, category: .biofeedback, "EEG: Connecting to \(peripheral.name ?? "unknown")")
    }

    /// Disconnect from current device
    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        cleanup()
        log.log(.info, category: .biofeedback, "EEG: Disconnected")
    }

    private func cleanup() {
        connectedPeripheral = nil
        dataCharacteristic = nil
        controlCharacteristic = nil
        connectionState = .disconnected
        isStreaming = false
        deviceType = .unknown
        deviceName = ""
        rawBuffer.reset()
        lastFFTSampleCount = 0
    }

    // MARK: - Streaming Control

    /// Start EEG data streaming from connected device
    public func startStreaming() {
        guard connectionState == .connected, let peripheral = connectedPeripheral else {
            log.log(.warning, category: .biofeedback, "EEG: Cannot start streaming — not connected")
            return
        }

        // Enable notifications on data characteristic
        if let dataChar = dataCharacteristic {
            peripheral.setNotifyValue(true, for: dataChar)
        }

        // Send start command for Muse devices
        if deviceType == .muse2 || deviceType == .museS, let controlChar = controlCharacteristic {
            // Muse start streaming command: "p21" + newline
            if let command = "p21\n".data(using: .utf8) {
                peripheral.writeValue(command, for: controlChar, type: .withResponse)
            }
        }

        connectionState = .streaming
        isStreaming = true
        log.log(.info, category: .biofeedback, "EEG: Streaming started — \(deviceType.rawValue)")
    }

    /// Stop EEG data streaming
    public func stopStreaming() {
        guard isStreaming, let peripheral = connectedPeripheral else { return }

        if let dataChar = dataCharacteristic {
            peripheral.setNotifyValue(false, for: dataChar)
        }

        // Send stop command for Muse devices
        if deviceType == .muse2 || deviceType == .museS, let controlChar = controlCharacteristic {
            if let command = "h\n".data(using: .utf8) {
                peripheral.writeValue(command, for: controlChar, type: .withResponse)
            }
        }

        connectionState = .connected
        isStreaming = false
        log.log(.info, category: .biofeedback, "EEG: Streaming stopped")
    }

    // MARK: - Data Processing

    /// Process raw EEG samples from BLE characteristic update
    private func processRawSamples(_ data: Data) {
        let samples = parseEEGData(data)
        guard !samples.isEmpty else { return }

        rawBuffer.write(samples)

        // Run FFT when we have enough new samples (stride = fftLength - overlap)
        let stride = fftLength - fftOverlap
        if rawBuffer.count - lastFFTSampleCount >= stride {
            lastFFTSampleCount = rawBuffer.count
            performSpectralAnalysis()
        }
    }

    /// Parse raw BLE data into float samples based on device type
    private func parseEEGData(_ data: Data) -> [Float] {
        switch deviceType {
        case .muse2, .museS:
            return parseMuseEEGPacket(data)
        case .neurosky:
            return parseNeuroskyPacket(data)
        case .openBCI:
            return parseOpenBCIPacket(data)
        case .unknown:
            return []
        }
    }

    /// Parse Muse EEG packet (12-bit samples, 4 channels interleaved)
    private func parseMuseEEGPacket(_ data: Data) -> [Float] {
        guard data.count >= 2 else { return [] }
        var samples: [Float] = []
        let bytes = [UInt8](data)

        // Muse sends compressed 12-bit samples; extract channel 0 (TP9)
        // Packet format: 2-byte header + 12-bit packed samples
        var byteIndex = 2 // skip header
        while byteIndex + 1 < bytes.count {
            let high = UInt16(bytes[byteIndex]) << 4
            let low = UInt16(bytes[byteIndex + 1]) >> 4
            let rawValue = Int16(bitPattern: high | low)
            // Normalize 12-bit signed to [-1, 1]
            let normalized = Float(rawValue) / 2048.0
            samples.append(normalized)
            byteIndex += 2
        }

        return samples
    }

    /// Parse NeuroSky TGAM packet
    private func parseNeuroskyPacket(_ data: Data) -> [Float] {
        guard data.count >= 4 else { return [] }
        let bytes = [UInt8](data)
        var samples: [Float] = []

        // NeuroSky raw value: 2 bytes big-endian signed
        var i = 0
        while i + 1 < bytes.count {
            let rawValue = Int16(bytes[i]) << 8 | Int16(bytes[i + 1])
            let normalized = Float(rawValue) / 32768.0
            samples.append(normalized)
            i += 2
        }

        // Extract signal quality if present in packet header
        if bytes.count > 2 {
            let quality = Float(255 - bytes[0]) / 255.0
            snapshot.rawSignalQuality = quality
        }

        return samples
    }

    /// Parse OpenBCI Ganglion packet (18-bit samples)
    private func parseOpenBCIPacket(_ data: Data) -> [Float] {
        guard data.count >= 3 else { return [] }
        let bytes = [UInt8](data)
        var samples: [Float] = []

        // OpenBCI Ganglion: 4 channels, 18-bit resolution
        // First byte is sample number, remaining are packed 18-bit values
        var bitOffset = 8 // skip sample number byte
        while bitOffset + 18 <= bytes.count * 8 {
            let byteIdx = bitOffset / 8
            let bitIdx = bitOffset % 8
            guard byteIdx + 2 < bytes.count else { break }

            var rawValue: Int32 = 0
            rawValue |= Int32(bytes[byteIdx]) << (10 + bitIdx)
            rawValue |= Int32(bytes[byteIdx + 1]) << (2 + bitIdx)
            if byteIdx + 2 < bytes.count {
                rawValue |= Int32(bytes[byteIdx + 2]) >> (6 - bitIdx)
            }
            rawValue = (rawValue >> 14) & 0x3FFFF

            // Sign extend 18-bit to 32-bit
            if rawValue & 0x20000 != 0 {
                rawValue |= ~0x3FFFF
            }

            let normalized = Float(rawValue) / 131072.0
            samples.append(normalized)
            bitOffset += 18
        }

        return samples
    }

    // MARK: - Spectral Analysis (vDSP FFT)

    /// Perform FFT on recent samples and extract band powers
    private func performSpectralAnalysis() {
        let samples = rawBuffer.readRecent(fftLength)
        guard samples.count == fftLength else { return }

        // Apply Hann window
        var windowedSamples = [Float](repeating: 0.0, count: fftLength)
        vDSP_vmul(samples, 1, hannWindow, 1, &windowedSamples, 1, vDSP_Length(fftLength))

        // Pack into split complex format for real FFT
        let halfN = fftLength / 2
        // Copy to avoid overlapping access issues with vDSP
        var inputReal = [Float](repeating: 0.0, count: halfN)
        var inputImag = [Float](repeating: 0.0, count: halfN)

        for i in 0..<halfN {
            inputReal[i] = windowedSamples[2 * i]
            inputImag[i] = windowedSamples[2 * i + 1]
        }

        var outputReal = [Float](repeating: 0.0, count: halfN)
        var outputImag = [Float](repeating: 0.0, count: halfN)

        guard let setup = fftSetup else { return }

        vDSP_DFT_Execute(
            setup,
            inputReal, inputImag,
            &outputReal, &outputImag
        )

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: halfN)
        var splitComplex = DSPSplitComplex(
            realp: &outputReal,
            imagp: &outputImag
        )
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))

        // Scale magnitudes
        var scale = Float(2.0) / Float(fftLength)
        var scaledMagnitudes = [Float](repeating: 0.0, count: halfN)
        vDSP_vsmul(magnitudes, 1, &scale, &scaledMagnitudes, 1, vDSP_Length(halfN))

        // Extract band powers
        let sampleRate = snapshot.sampleRate
        let bandPowers = extractBandPowers(from: scaledMagnitudes, sampleRate: sampleRate)

        // Smooth and update snapshot
        updateSnapshot(with: bandPowers)
    }

    /// Extract power in each frequency band from magnitude spectrum
    private func extractBandPowers(from magnitudes: [Float], sampleRate: Double) -> EEGBandPowers {
        let binResolution = sampleRate / Double(fftLength) // Hz per bin
        let halfN = magnitudes.count

        guard binResolution > 0 else { return EEGBandPowers() }

        // Frequency band boundaries in Hz
        let deltaBins = binRange(low: 0.5, high: 4.0, resolution: binResolution, maxBin: halfN)
        let thetaBins = binRange(low: 4.0, high: 8.0, resolution: binResolution, maxBin: halfN)
        let alphaBins = binRange(low: 8.0, high: 13.0, resolution: binResolution, maxBin: halfN)
        let betaBins = binRange(low: 13.0, high: 30.0, resolution: binResolution, maxBin: halfN)
        let gammaBins = binRange(low: 30.0, high: 100.0, resolution: binResolution, maxBin: halfN)

        return EEGBandPowers(
            delta: sumPower(magnitudes, range: deltaBins),
            theta: sumPower(magnitudes, range: thetaBins),
            alpha: sumPower(magnitudes, range: alphaBins),
            beta: sumPower(magnitudes, range: betaBins),
            gamma: sumPower(magnitudes, range: gammaBins)
        )
    }

    /// Calculate bin index range for a frequency band
    private func binRange(low: Double, high: Double, resolution: Double, maxBin: Int) -> ClosedRange<Int> {
        let lowBin = max(0, Int((low / resolution).rounded(.up)))
        let highBin = min(maxBin - 1, Int((high / resolution).rounded(.down)))
        guard lowBin <= highBin else { return 0...0 }
        return lowBin...highBin
    }

    /// Sum power (squared magnitudes) in a bin range
    private func sumPower(_ magnitudes: [Float], range: ClosedRange<Int>) -> Float {
        guard range.lowerBound < magnitudes.count else { return 0 }
        let upper = min(range.upperBound, magnitudes.count - 1)
        var power: Float = 0
        for i in range.lowerBound...upper {
            power += magnitudes[i] * magnitudes[i]
        }
        return power
    }

    /// Update snapshot with smoothed band powers and derived scores
    private func updateSnapshot(with bandPowers: EEGBandPowers) {
        // Exponential moving average smoothing
        snapshot.bandPowers.delta = snapshot.bandPowers.delta * (1 - smoothingAlpha) + bandPowers.delta * smoothingAlpha
        snapshot.bandPowers.theta = snapshot.bandPowers.theta * (1 - smoothingAlpha) + bandPowers.theta * smoothingAlpha
        snapshot.bandPowers.alpha = snapshot.bandPowers.alpha * (1 - smoothingAlpha) + bandPowers.alpha * smoothingAlpha
        snapshot.bandPowers.beta  = snapshot.bandPowers.beta  * (1 - smoothingAlpha) + bandPowers.beta  * smoothingAlpha
        snapshot.bandPowers.gamma = snapshot.bandPowers.gamma * (1 - smoothingAlpha) + bandPowers.gamma * smoothingAlpha

        // Attention score: beta / (theta + alpha) — higher beta relative to slow waves = more focused
        let slowWaves = snapshot.bandPowers.theta + snapshot.bandPowers.alpha
        if slowWaves > 0 {
            let rawAttention = snapshot.bandPowers.beta / slowWaves
            // Normalize: typical ratio range [0.5, 3.0] -> [0, 1]
            snapshot.attentionScore = min(1.0, max(0.0, (rawAttention - 0.5) / 2.5))
        }

        // Meditation score: alpha / (beta + gamma) — higher alpha relative to fast waves = more relaxed
        let fastWaves = snapshot.bandPowers.beta + snapshot.bandPowers.gamma
        if fastWaves > 0 {
            let rawMeditation = snapshot.bandPowers.alpha / fastWaves
            // Normalize: typical ratio range [0.3, 2.0] -> [0, 1]
            snapshot.meditationScore = min(1.0, max(0.0, (rawMeditation - 0.3) / 1.7))
        }

        snapshot.timestamp = Date()
    }

    // MARK: - Device Type Detection

    private func identifyDevice(from services: [CBService]) -> EEGDeviceType {
        for service in services {
            switch service.uuid {
            case EEGServiceUUIDs.museControl:
                return .muse2 // Muse S uses same service; differentiate by name if needed
            case EEGServiceUUIDs.neuroskyData:
                return .neurosky
            case EEGServiceUUIDs.openBCIGanglion:
                return .openBCI
            default:
                continue
            }
        }
        return .unknown
    }
}

// MARK: - CBCentralManagerDelegate

extension EEGSensorBridge: @preconcurrency CBCentralManagerDelegate {
    public nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                log.log(.info, category: .biofeedback, "EEG: Bluetooth powered on")
                if connectionState == .scanning {
                    beginScan()
                }
            case .poweredOff:
                log.log(.warning, category: .biofeedback, "EEG: Bluetooth powered off")
                cleanup()
            case .unauthorized:
                log.log(.warning, category: .biofeedback, "EEG: Bluetooth unauthorized")
                cleanup()
            case .unsupported:
                log.log(.error, category: .biofeedback, "EEG: Bluetooth unsupported on this device")
            default:
                break
            }
        }
    }

    public nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown EEG"
        let peripheralID = peripheral.identifier
        nonisolated(unsafe) let capturedPeripheral = peripheral
        Task { @MainActor in
            // Avoid duplicates
            guard !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheralID }) else { return }
            discoveredDevices.append((name: name, peripheral: capturedPeripheral))
            log.log(.info, category: .biofeedback, "EEG: Discovered \(name) (RSSI: \(RSSI))")
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let pName = peripheral.name ?? "EEG Device"
        nonisolated(unsafe) let capturedPeripheral = peripheral
        Task { @MainActor in
            connectionState = .connected
            deviceName = pName
            capturedPeripheral.discoverServices(EEGServiceUUIDs.allServices)
            log.log(.info, category: .biofeedback, "EEG: Connected to \(deviceName)")
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            log.log(.error, category: .biofeedback, "EEG: Connection failed — \(error?.localizedDescription ?? "unknown")")
            cleanup()
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            log.log(.info, category: .biofeedback, "EEG: Peripheral disconnected")
            cleanup()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension EEGSensorBridge: @preconcurrency CBPeripheralDelegate {
    public nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        nonisolated(unsafe) let capturedPeripheral = peripheral
        nonisolated(unsafe) let services = peripheral.services
        let err = error
        Task { @MainActor in
            guard let services, err == nil else {
                log.log(.error, category: .biofeedback, "EEG: Service discovery failed — \(error?.localizedDescription ?? "unknown")")
                return
            }

            deviceType = identifyDevice(from: services)

            if deviceName.lowercased().contains("muse-s") || deviceName.lowercased().contains("muse s") {
                deviceType = .museS
            }

            // Set sample rate based on device
            switch deviceType {
            case .muse2, .museS: snapshot.sampleRate = 256.0; snapshot.activeChannels = 4
            case .neurosky: snapshot.sampleRate = 512.0; snapshot.activeChannels = 1
            case .openBCI: snapshot.sampleRate = 200.0; snapshot.activeChannels = 4
            case .unknown: snapshot.sampleRate = 256.0; snapshot.activeChannels = 0
            }

            log.log(.info, category: .biofeedback, "EEG: Identified \(deviceType.rawValue) — \(snapshot.sampleRate)Hz, \(snapshot.activeChannels) channels")

            for service in services {
                capturedPeripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    public nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        nonisolated(unsafe) let characteristics = service.characteristics
        let err = error
        Task { @MainActor in
            guard let characteristics, err == nil else { return }

            for characteristic in characteristics {
                switch characteristic.uuid {
                case EEGCharacteristicUUIDs.museEEGData,
                     EEGCharacteristicUUIDs.neuroskyRawData,
                     EEGCharacteristicUUIDs.openBCIData:
                    dataCharacteristic = characteristic
                    log.log(.info, category: .biofeedback, "EEG: Found data characteristic")

                case EEGCharacteristicUUIDs.museControl:
                    controlCharacteristic = characteristic
                    log.log(.info, category: .biofeedback, "EEG: Found control characteristic")

                default:
                    break
                }
            }
        }
    }

    public nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, error == nil else { return }
        Task { @MainActor in
            processRawSamples(data)
        }
    }
}

#else
// Non-CoreBluetooth platforms (Linux, etc.)
import Foundation
#if canImport(Observation)
import Observation
#endif

public struct EEGBandPowers: Sendable, Equatable {
    public var delta: Float = 0.0
    public var theta: Float = 0.0
    public var alpha: Float = 0.0
    public var beta: Float = 0.0
    public var gamma: Float = 0.0
    public var totalPower: Float { delta + theta + alpha + beta + gamma }
    public var relativeAlpha: Float { guard totalPower > 0 else { return 0 }; return alpha / totalPower }
    public var relativeBeta: Float { guard totalPower > 0 else { return 0 }; return beta / totalPower }
    public var relativeTheta: Float { guard totalPower > 0 else { return 0 }; return theta / totalPower }
}

public struct EEGSnapshot: Sendable {
    public var bandPowers: EEGBandPowers = EEGBandPowers()
    public var attentionScore: Float = 0.0
    public var meditationScore: Float = 0.0
    public var rawSignalQuality: Float = 0.0
    public var activeChannels: Int = 0
    public var sampleRate: Double = 256.0
    public var timestamp: Date = Date()
}

public enum EEGDeviceType: String, Sendable, CaseIterable {
    case muse2 = "Muse 2"
    case museS = "Muse S"
    case neurosky = "NeuroSky MindWave"
    case openBCI = "OpenBCI Ganglion"
    case unknown = "Unknown EEG"
}

public enum EEGConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case connecting = "Connecting"
    case connected = "Connected"
    case streaming = "Streaming"
}

@preconcurrency @MainActor
@Observable
public final class EEGSensorBridge {
    @MainActor public static let shared = EEGSensorBridge()
    public var snapshot: EEGSnapshot = EEGSnapshot()
    public var connectionState: EEGConnectionState = .disconnected
    public var deviceType: EEGDeviceType = .unknown
    public var deviceName: String = ""
    public var isStreaming: Bool = false
    private init() {}
    public func startScanning() {}
    public func stopScanning() {}
    public func disconnect() {}
    public func startStreaming() {}
    public func stopStreaming() {}
}
#endif
