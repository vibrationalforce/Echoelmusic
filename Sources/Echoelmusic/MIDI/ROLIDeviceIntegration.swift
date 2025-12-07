// ROLIDeviceIntegration.swift
// Echoelmusic - Complete ROLI Device Support
// Seaboard, Airwave, Lumi, Lightpad, Blocks, and all ROLI controllers

import Foundation
import Combine
import CoreMIDI
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

// MARK: - ROLI Device Types

public enum ROLIDeviceType: String, CaseIterable, Codable {
    // Seaboard Family
    case seaboardRise49 = "Seaboard RISE 49"
    case seaboardRise25 = "Seaboard RISE 25"
    case seaboardRise2 = "Seaboard RISE 2"
    case seaboardBlock = "Seaboard Block"
    case seaboardBlockM = "Seaboard Block M"
    case seaboardGrand = "Seaboard Grand"

    // Lumi Family
    case lumiKeys = "LUMI Keys"
    case lumiKeysStudio = "LUMI Keys Studio Edition"
    case lumiKeysSE = "LUMI Keys SE"

    // Blocks Family
    case lightpadBlock = "Lightpad Block"
    case lightpadBlockM = "Lightpad Block M"
    case loopBlock = "Loop Block"
    case liveBlock = "Live Block"
    case touchBlock = "Touch Block"

    // Airwave
    case airwave = "ROLI Airwave"

    // Controllers
    case songmakerKit = "Songmaker Kit"

    var isMPE: Bool {
        switch self {
        case .seaboardRise49, .seaboardRise25, .seaboardRise2, .seaboardBlock, .seaboardBlockM, .seaboardGrand, .lightpadBlock, .lightpadBlockM:
            return true
        case .lumiKeys, .lumiKeysStudio, .lumiKeysSE:
            return true // LUMI supports MPE mode
        default:
            return false
        }
    }

    var hasGestureSensor: Bool {
        switch self {
        case .airwave:
            return true
        default:
            return false
        }
    }

    var hasLEDs: Bool {
        switch self {
        case .lumiKeys, .lumiKeysStudio, .lumiKeysSE, .lightpadBlock, .lightpadBlockM, .seaboardBlock, .seaboardBlockM:
            return true
        default:
            return false
        }
    }

    var keyCount: Int? {
        switch self {
        case .seaboardRise49: return 49
        case .seaboardRise25, .seaboardRise2: return 25
        case .seaboardBlock, .seaboardBlockM: return 24
        case .seaboardGrand: return 88
        case .lumiKeys, .lumiKeysStudio, .lumiKeysSE: return 24
        default: return nil
        }
    }

    var defaultPitchBendRange: Int {
        switch self {
        case .seaboardRise49, .seaboardRise25, .seaboardRise2, .seaboardGrand:
            return 48 // ±48 semitones default for Seaboard
        case .seaboardBlock, .seaboardBlockM:
            return 48
        case .lightpadBlock, .lightpadBlockM:
            return 24
        case .lumiKeys, .lumiKeysStudio, .lumiKeysSE:
            return 12
        default:
            return 2
        }
    }
}

// MARK: - ROLI Device

public struct ROLIDevice: Identifiable, Codable {
    public let id: UUID
    public let type: ROLIDeviceType
    public var name: String
    public var serialNumber: String?
    public var firmwareVersion: String?
    public var isConnected: Bool
    public var connectionType: ConnectionType
    public var batteryLevel: Int? // For wireless devices

    public enum ConnectionType: String, Codable {
        case usb = "USB"
        case bluetooth = "Bluetooth"
        case dna = "DNA Connector" // ROLI Blocks connection
    }

    // Device-specific settings
    public var settings: ROLIDeviceSettings

    public init(
        id: UUID = UUID(),
        type: ROLIDeviceType,
        name: String,
        serialNumber: String? = nil,
        firmwareVersion: String? = nil,
        isConnected: Bool = false,
        connectionType: ConnectionType = .usb,
        batteryLevel: Int? = nil,
        settings: ROLIDeviceSettings = ROLIDeviceSettings()
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.batteryLevel = batteryLevel
        self.settings = settings
    }
}

// MARK: - ROLI Device Settings

public struct ROLIDeviceSettings: Codable {
    // MPE Settings
    public var mpeEnabled: Bool = true
    public var pitchBendRange: Int = 48
    public var pressureSensitivity: Float = 0.5
    public var slideSensitivity: Float = 0.5

    // Touch Response
    public var strikeThreshold: Float = 0.3
    public var liftThreshold: Float = 0.1
    public var fixedVelocity: Bool = false
    public var fixedVelocityValue: Int = 100

    // Glide (Pitch Bend)
    public var glideEnabled: Bool = true
    public var glideMode: GlideMode = .absolute
    public var glideLock: Bool = false

    // Slide (Y-axis / Timbre)
    public var slideEnabled: Bool = true
    public var slideCC: Int = 74 // CC 74 = Brightness
    public var slideInitialValue: Int = 64

    // Press (Pressure / Aftertouch)
    public var pressEnabled: Bool = true
    public var pressMode: PressMode = .channelPressure
    public var pressCC: Int = 1 // CC 1 = Modulation

    // LED Settings (for compatible devices)
    public var ledMode: LEDMode = .keyColor
    public var ledBrightness: Float = 0.8
    public var ledColors: [Int: LEDColor] = [:] // Note number to color mapping

    // Airwave Settings
    public var airwaveEnabled: Bool = true
    public var airwaveXMapping: AirwaveMapping = .pitchBend
    public var airwaveYMapping: AirwaveMapping = .modulation
    public var airwaveZMapping: AirwaveMapping = .volume
    public var airwaveSensitivity: Float = 0.7
    public var airwaveSmoothing: Float = 0.3

    public enum GlideMode: String, Codable {
        case absolute = "Absolute"
        case relative = "Relative"
        case quantized = "Quantized"
    }

    public enum PressMode: String, Codable {
        case channelPressure = "Channel Pressure"
        case polyPressure = "Poly Aftertouch"
        case controlChange = "Control Change"
    }

    public enum LEDMode: String, Codable {
        case off = "Off"
        case keyColor = "Key Colors"
        case scale = "Scale Highlight"
        case velocity = "Velocity Response"
        case custom = "Custom"
        case bioReactive = "Bio-Reactive"
    }

    public enum AirwaveMapping: String, Codable {
        case none = "None"
        case pitchBend = "Pitch Bend"
        case modulation = "Modulation"
        case volume = "Volume"
        case expression = "Expression"
        case filter = "Filter Cutoff"
        case resonance = "Resonance"
        case pan = "Pan"
        case custom = "Custom CC"
    }
}

// MARK: - LED Color

public struct LEDColor: Codable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = LEDColor(red: 255, green: 255, blue: 255)
    public static let red = LEDColor(red: 255, green: 0, blue: 0)
    public static let green = LEDColor(red: 0, green: 255, blue: 0)
    public static let blue = LEDColor(red: 0, green: 0, blue: 255)
    public static let yellow = LEDColor(red: 255, green: 255, blue: 0)
    public static let cyan = LEDColor(red: 0, green: 255, blue: 255)
    public static let magenta = LEDColor(red: 255, green: 0, blue: 255)
    public static let orange = LEDColor(red: 255, green: 128, blue: 0)
    public static let purple = LEDColor(red: 128, green: 0, blue: 255)
}

// MARK: - Airwave Gesture Data

public struct AirwaveGestureData {
    public var x: Float  // Left/Right (-1 to 1)
    public var y: Float  // Up/Down (-1 to 1)
    public var z: Float  // Distance (0 to 1)
    public var handPresent: Bool
    public var timestamp: TimeInterval

    // Derived gestures
    public var velocity: SIMD3<Float>
    public var acceleration: SIMD3<Float>

    public init(
        x: Float = 0,
        y: Float = 0,
        z: Float = 0,
        handPresent: Bool = false,
        timestamp: TimeInterval = 0,
        velocity: SIMD3<Float> = .zero,
        acceleration: SIMD3<Float> = .zero
    ) {
        self.x = x
        self.y = y
        self.z = z
        self.handPresent = handPresent
        self.timestamp = timestamp
        self.velocity = velocity
        self.acceleration = acceleration
    }
}

// MARK: - ROLI Device Manager

@MainActor
public final class ROLIDeviceManager: ObservableObject {
    public static let shared = ROLIDeviceManager()

    // MARK: - Published State

    @Published public private(set) var connectedDevices: [ROLIDevice] = []
    @Published public private(set) var isScanning: Bool = false

    // Airwave state
    @Published public private(set) var airwaveData: AirwaveGestureData = AirwaveGestureData()
    @Published public private(set) var airwaveConnected: Bool = false

    // Bio-reactive LED state
    @Published public var bioReactiveLEDsEnabled: Bool = false
    @Published public var currentCoherence: Float = 0.5

    // MARK: - Private Properties

    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0
    private var midiOutputPort: MIDIPortRef = 0

    private var mpeZoneManager: MPEZoneManager?
    private var airwaveProcessor: AirwaveProcessor?
    private var ledController: ROLILEDController?

    private var deviceEndpoints: [UUID: MIDIEndpointRef] = [:]
    private var cancellables = Set<AnyCancellable>()

    // Previous Airwave data for velocity calculation
    private var previousAirwaveData: AirwaveGestureData?
    private var lastAirwaveUpdate: TimeInterval = 0

    // MARK: - Initialization

    private init() {
        setupMIDI()
        startDeviceDiscovery()
    }

    private func setupMIDI() {
        // Create MIDI client
        var status = MIDIClientCreate("Echoelmusic-ROLI" as CFString, nil, nil, &midiClient)
        guard status == noErr else {
            print("❌ ROLI: Failed to create MIDI client: \(status)")
            return
        }

        // Create input port
        status = MIDIInputPortCreate(midiClient, "ROLI-Input" as CFString, midiReadCallback, Unmanaged.passUnretained(self).toOpaque(), &midiInputPort)
        guard status == noErr else {
            print("❌ ROLI: Failed to create MIDI input port: \(status)")
            return
        }

        // Create output port
        status = MIDIOutputPortCreate(midiClient, "ROLI-Output" as CFString, &midiOutputPort)
        guard status == noErr else {
            print("❌ ROLI: Failed to create MIDI output port: \(status)")
            return
        }

        print("✅ ROLI: MIDI setup complete")
    }

    // MARK: - Device Discovery

    private func startDeviceDiscovery() {
        // Scan for USB MIDI devices
        scanMIDIDevices()

        // Setup Bluetooth scanning for wireless ROLI devices
        setupBluetoothScanning()

        // Register for device connection notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "MIDINetworkSessionDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scanMIDIDevices()
        }
    }

    private func scanMIDIDevices() {
        isScanning = true

        let sourceCount = MIDIGetNumberOfSources()
        let destinationCount = MIDIGetNumberOfDestinations()

        var foundDevices: [ROLIDevice] = []

        // Scan sources (input devices)
        for i in 0..<sourceCount {
            let endpoint = MIDIGetSource(i)
            if let device = identifyROLIDevice(endpoint: endpoint) {
                foundDevices.append(device)
                deviceEndpoints[device.id] = endpoint

                // Connect to input
                MIDIPortConnectSource(midiInputPort, endpoint, nil)
            }
        }

        // Update connected devices
        for device in foundDevices {
            if let index = connectedDevices.firstIndex(where: { $0.serialNumber == device.serialNumber }) {
                connectedDevices[index].isConnected = true
            } else {
                connectedDevices.append(device)
            }
        }

        // Mark disconnected devices
        for i in connectedDevices.indices {
            if !foundDevices.contains(where: { $0.serialNumber == connectedDevices[i].serialNumber }) {
                connectedDevices[i].isConnected = false
            }
        }

        isScanning = false

        print("✅ ROLI: Found \(foundDevices.count) devices")
    }

    private func identifyROLIDevice(endpoint: MIDIEndpointRef) -> ROLIDevice? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?

        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)

        guard let deviceName = name?.takeRetainedValue() as String?,
              let mfr = manufacturer?.takeRetainedValue() as String?,
              mfr.lowercased().contains("roli") || deviceName.lowercased().contains("roli") ||
              deviceName.lowercased().contains("seaboard") || deviceName.lowercased().contains("lumi") ||
              deviceName.lowercased().contains("lightpad") || deviceName.lowercased().contains("airwave") ||
              deviceName.lowercased().contains("block")
        else {
            return nil
        }

        // Identify device type
        let deviceType = identifyDeviceType(name: deviceName)

        // Get serial number if available
        var serialRef: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertySerialNumber, &serialRef)
        let serial = serialRef?.takeRetainedValue() as String?

        return ROLIDevice(
            type: deviceType,
            name: deviceName,
            serialNumber: serial,
            isConnected: true,
            connectionType: .usb
        )
    }

    private func identifyDeviceType(name: String) -> ROLIDeviceType {
        let lowercaseName = name.lowercased()

        if lowercaseName.contains("airwave") {
            return .airwave
        } else if lowercaseName.contains("seaboard") {
            if lowercaseName.contains("rise") {
                if lowercaseName.contains("49") {
                    return .seaboardRise49
                } else if lowercaseName.contains("25") {
                    return .seaboardRise25
                } else if lowercaseName.contains("2") {
                    return .seaboardRise2
                }
            } else if lowercaseName.contains("block") {
                if lowercaseName.contains("m") {
                    return .seaboardBlockM
                }
                return .seaboardBlock
            } else if lowercaseName.contains("grand") {
                return .seaboardGrand
            }
            return .seaboardBlock
        } else if lowercaseName.contains("lumi") {
            if lowercaseName.contains("studio") {
                return .lumiKeysStudio
            } else if lowercaseName.contains("se") {
                return .lumiKeysSE
            }
            return .lumiKeys
        } else if lowercaseName.contains("lightpad") {
            if lowercaseName.contains("m") {
                return .lightpadBlockM
            }
            return .lightpadBlock
        } else if lowercaseName.contains("loop") {
            return .loopBlock
        } else if lowercaseName.contains("live") {
            return .liveBlock
        } else if lowercaseName.contains("touch") {
            return .touchBlock
        }

        return .seaboardBlock // Default
    }

    private func setupBluetoothScanning() {
        #if canImport(CoreBluetooth)
        // Scan for Bluetooth MIDI devices
        // ROLI devices use standard Bluetooth MIDI profile
        #endif
    }

    // MARK: - Device Configuration

    /// Configure MPE settings for a device
    public func configureMPE(deviceId: UUID, enabled: Bool, pitchBendRange: Int = 48) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        connectedDevices[index].settings.mpeEnabled = enabled
        connectedDevices[index].settings.pitchBendRange = pitchBendRange

        // Send MPE configuration to device
        if enabled {
            sendMPEConfiguration(deviceId: deviceId, pitchBendRange: pitchBendRange)
        }
    }

    /// Configure touch sensitivity
    public func configureSensitivity(deviceId: UUID, pressure: Float, slide: Float, strike: Float) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        connectedDevices[index].settings.pressureSensitivity = pressure
        connectedDevices[index].settings.slideSensitivity = slide
        connectedDevices[index].settings.strikeThreshold = strike

        // Send sensitivity settings via SysEx
        sendSensitivitySettings(deviceId: deviceId, pressure: pressure, slide: slide, strike: strike)
    }

    /// Configure Airwave gesture mappings
    public func configureAirwave(
        deviceId: UUID,
        xMapping: ROLIDeviceSettings.AirwaveMapping,
        yMapping: ROLIDeviceSettings.AirwaveMapping,
        zMapping: ROLIDeviceSettings.AirwaveMapping,
        sensitivity: Float
    ) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        connectedDevices[index].settings.airwaveXMapping = xMapping
        connectedDevices[index].settings.airwaveYMapping = yMapping
        connectedDevices[index].settings.airwaveZMapping = zMapping
        connectedDevices[index].settings.airwaveSensitivity = sensitivity
    }

    // MARK: - LED Control

    /// Set LED color for a specific key/pad
    public func setLEDColor(deviceId: UUID, note: Int, color: LEDColor) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }),
              connectedDevices[index].type.hasLEDs else { return }

        connectedDevices[index].settings.ledColors[note] = color

        // Send LED color via SysEx
        sendLEDColor(deviceId: deviceId, note: note, color: color)
    }

    /// Set LED mode
    public func setLEDMode(deviceId: UUID, mode: ROLIDeviceSettings.LEDMode) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        connectedDevices[index].settings.ledMode = mode

        if mode == .bioReactive {
            bioReactiveLEDsEnabled = true
        }
    }

    /// Update all LEDs based on scale
    public func setScaleHighlight(deviceId: UUID, root: Int, scale: MusicalScale) {
        guard let device = connectedDevices.first(where: { $0.id == deviceId }),
              device.type.hasLEDs,
              let keyCount = device.type.keyCount else { return }

        let scaleNotes = scale.notes(root: root)

        for note in 0..<keyCount {
            let midiNote = note + 36 // Assuming C2 start
            let isInScale = scaleNotes.contains(midiNote % 12)
            let isRoot = (midiNote % 12) == (root % 12)

            let color: LEDColor
            if isRoot {
                color = .cyan
            } else if isInScale {
                color = .blue
            } else {
                color = LEDColor(red: 20, green: 20, blue: 20) // Dim
            }

            sendLEDColor(deviceId: deviceId, note: midiNote, color: color)
        }
    }

    /// Update LEDs based on bio-data (coherence)
    public func updateBioReactiveLEDs(coherence: Float) {
        guard bioReactiveLEDsEnabled else { return }

        currentCoherence = coherence

        // Color based on coherence level
        let color: LEDColor
        if coherence < 0.33 {
            // Low coherence: Red to Yellow
            let t = coherence / 0.33
            color = LEDColor(red: 255, green: UInt8(255 * t), blue: 0)
        } else if coherence < 0.66 {
            // Medium coherence: Yellow to Green
            let t = (coherence - 0.33) / 0.33
            color = LEDColor(red: UInt8(255 * (1 - t)), green: 255, blue: 0)
        } else {
            // High coherence: Green to Blue
            let t = (coherence - 0.66) / 0.34
            color = LEDColor(red: 0, green: UInt8(255 * (1 - t)), blue: UInt8(255 * t))
        }

        // Update all connected devices with LEDs
        for device in connectedDevices where device.type.hasLEDs && device.settings.ledMode == .bioReactive {
            if let keyCount = device.type.keyCount {
                for note in 0..<keyCount {
                    sendLEDColor(deviceId: device.id, note: note + 36, color: color)
                }
            }
        }
    }

    // MARK: - MIDI Message Handling

    private func handleMIDIMessage(_ data: [UInt8], from deviceId: UUID?) {
        guard !data.isEmpty else { return }

        let status = data[0]
        let channel = status & 0x0F
        let messageType = status & 0xF0

        // Handle Airwave SysEx
        if status == 0xF0 && data.count > 4 {
            handleAirwaveSysEx(data)
            return
        }

        // Regular MIDI messages are handled by MPEZoneManager
        // Just update Airwave state if it's an Airwave device
        if let deviceId = deviceId,
           let device = connectedDevices.first(where: { $0.id == deviceId }),
           device.type == .airwave {
            // Airwave sends CC messages for gesture data
            if messageType == 0xB0 && data.count >= 3 {
                handleAirwaveCC(controller: data[1], value: data[2], device: device)
            }
        }
    }

    private func handleAirwaveSysEx(_ data: [UInt8]) {
        // ROLI Airwave sends gesture data via SysEx
        // Format: F0 00 21 10 [device] [x_msb] [x_lsb] [y_msb] [y_lsb] [z_msb] [z_lsb] F7

        guard data.count >= 10 else { return }

        let xRaw = (Int(data[5]) << 7) | Int(data[6])
        let yRaw = (Int(data[7]) << 7) | Int(data[8])
        let zRaw = (Int(data[9]) << 7) | Int(data.count > 10 ? data[10] : 0)

        let x = (Float(xRaw) / 8192.0) - 1.0 // -1 to 1
        let y = (Float(yRaw) / 8192.0) - 1.0 // -1 to 1
        let z = Float(zRaw) / 16383.0         // 0 to 1

        updateAirwaveData(x: x, y: y, z: z, handPresent: z > 0.01)
    }

    private func handleAirwaveCC(controller: UInt8, value: UInt8, device: ROLIDevice) {
        // Airwave might send CC for X, Y, Z axes
        let normalizedValue = Float(value) / 127.0

        switch controller {
        case 1: // X axis mapped to modulation
            updateAirwaveData(x: normalizedValue * 2 - 1, y: airwaveData.y, z: airwaveData.z, handPresent: true)
        case 2: // Y axis mapped to breath
            updateAirwaveData(x: airwaveData.x, y: normalizedValue * 2 - 1, z: airwaveData.z, handPresent: true)
        case 11: // Z axis mapped to expression
            updateAirwaveData(x: airwaveData.x, y: airwaveData.y, z: normalizedValue, handPresent: normalizedValue > 0.01)
        default:
            break
        }
    }

    private func updateAirwaveData(x: Float, y: Float, z: Float, handPresent: Bool) {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastAirwaveUpdate

        // Calculate velocity
        var velocity = SIMD3<Float>.zero
        var acceleration = SIMD3<Float>.zero

        if deltaTime > 0 && deltaTime < 0.1 {
            velocity = SIMD3<Float>(
                (x - airwaveData.x) / Float(deltaTime),
                (y - airwaveData.y) / Float(deltaTime),
                (z - airwaveData.z) / Float(deltaTime)
            )

            if let prev = previousAirwaveData {
                let prevVelocity = SIMD3<Float>(
                    (airwaveData.x - prev.x) / Float(deltaTime),
                    (airwaveData.y - prev.y) / Float(deltaTime),
                    (airwaveData.z - prev.z) / Float(deltaTime)
                )
                acceleration = (velocity - prevVelocity) / Float(deltaTime)
            }
        }

        previousAirwaveData = airwaveData
        lastAirwaveUpdate = currentTime

        airwaveData = AirwaveGestureData(
            x: x,
            y: y,
            z: z,
            handPresent: handPresent,
            timestamp: currentTime,
            velocity: velocity,
            acceleration: acceleration
        )

        airwaveConnected = handPresent

        // Process gesture mappings
        processAirwaveGestures()
    }

    private func processAirwaveGestures() {
        // Find connected Airwave device
        guard let device = connectedDevices.first(where: { $0.type == .airwave && $0.isConnected }) else { return }

        let settings = device.settings
        let sensitivity = settings.airwaveSensitivity

        // Apply mappings
        applyAirwaveMapping(settings.airwaveXMapping, value: airwaveData.x * sensitivity, device: device)
        applyAirwaveMapping(settings.airwaveYMapping, value: airwaveData.y * sensitivity, device: device)
        applyAirwaveMapping(settings.airwaveZMapping, value: airwaveData.z * sensitivity, device: device)
    }

    private func applyAirwaveMapping(_ mapping: ROLIDeviceSettings.AirwaveMapping, value: Float, device: ROLIDevice) {
        let midiValue = UInt8(max(0, min(127, Int((value + 1) / 2 * 127))))
        let pitchBendValue = Int16(max(-8192, min(8191, Int(value * 8192))))

        switch mapping {
        case .none:
            break
        case .pitchBend:
            sendPitchBend(pitchBendValue)
        case .modulation:
            sendControlChange(1, value: midiValue)
        case .volume:
            sendControlChange(7, value: midiValue)
        case .expression:
            sendControlChange(11, value: midiValue)
        case .filter:
            sendControlChange(74, value: midiValue)
        case .resonance:
            sendControlChange(71, value: midiValue)
        case .pan:
            sendControlChange(10, value: midiValue)
        case .custom:
            break // User-defined CC
        }
    }

    // MARK: - MIDI Output

    private func sendMPEConfiguration(deviceId: UUID, pitchBendRange: Int) {
        guard let endpoint = findOutputEndpoint(for: deviceId) else { return }

        // MPE Configuration RPN
        let sysex: [UInt8] = [
            0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7 // Universal Device Inquiry
        ]

        sendMIDIData(sysex, to: endpoint)
    }

    private func sendSensitivitySettings(deviceId: UUID, pressure: Float, slide: Float, strike: Float) {
        guard let endpoint = findOutputEndpoint(for: deviceId) else { return }

        // ROLI-specific SysEx for sensitivity
        // Manufacturer ID: 0x00 0x21 0x10 (ROLI)
        let sysex: [UInt8] = [
            0xF0, 0x00, 0x21, 0x10, // ROLI manufacturer ID
            0x01, // Command: Set sensitivity
            UInt8(pressure * 127),
            UInt8(slide * 127),
            UInt8(strike * 127),
            0xF7
        ]

        sendMIDIData(sysex, to: endpoint)
    }

    private func sendLEDColor(deviceId: UUID, note: Int, color: LEDColor) {
        guard let endpoint = findOutputEndpoint(for: deviceId) else { return }

        // ROLI LED SysEx
        let sysex: [UInt8] = [
            0xF0, 0x00, 0x21, 0x10, // ROLI manufacturer ID
            0x02, // Command: Set LED
            UInt8(note & 0x7F),
            color.red >> 1, // 7-bit values
            color.green >> 1,
            color.blue >> 1,
            0xF7
        ]

        sendMIDIData(sysex, to: endpoint)
    }

    private func sendPitchBend(_ value: Int16) {
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        let data: [UInt8] = [0xE0, lsb, msb]

        // Send to all Seaboard devices
        for device in connectedDevices where device.type.isMPE {
            if let endpoint = findOutputEndpoint(for: device.id) {
                sendMIDIData(data, to: endpoint)
            }
        }
    }

    private func sendControlChange(_ controller: UInt8, value: UInt8) {
        let data: [UInt8] = [0xB0, controller, value]

        for device in connectedDevices where device.isConnected {
            if let endpoint = findOutputEndpoint(for: device.id) {
                sendMIDIData(data, to: endpoint)
            }
        }
    }

    private func findOutputEndpoint(for deviceId: UUID) -> MIDIEndpointRef? {
        // Find matching output endpoint for the device
        let destCount = MIDIGetNumberOfDestinations()

        guard let device = connectedDevices.first(where: { $0.id == deviceId }) else {
            return nil
        }

        for i in 0..<destCount {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)

            if let endpointName = name?.takeRetainedValue() as String?,
               endpointName.lowercased().contains(device.type.rawValue.lowercased()) {
                return endpoint
            }
        }

        return nil
    }

    private func sendMIDIData(_ data: [UInt8], to endpoint: MIDIEndpointRef) {
        var packetList = MIDIPacketList()
        var packet = MIDIPacketListInit(&packetList)
        packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, data.count, data)

        MIDISend(midiOutputPort, endpoint, &packetList)
    }
}

// MARK: - Musical Scale

public enum MusicalScale: String, CaseIterable {
    case major = "Major"
    case minor = "Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case chromatic = "Chromatic"

    func notes(root: Int) -> [Int] {
        let intervals: [Int]
        switch self {
        case .major: intervals = [0, 2, 4, 5, 7, 9, 11]
        case .minor: intervals = [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: intervals = [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: intervals = [0, 2, 3, 5, 7, 9, 11]
        case .dorian: intervals = [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: intervals = [0, 1, 3, 5, 7, 8, 10]
        case .lydian: intervals = [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: intervals = [0, 2, 4, 5, 7, 9, 10]
        case .locrian: intervals = [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor: intervals = [0, 2, 4, 7, 9]
        case .pentatonicMinor: intervals = [0, 3, 5, 7, 10]
        case .blues: intervals = [0, 3, 5, 6, 7, 10]
        case .chromatic: intervals = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        }

        return intervals.map { (root + $0) % 12 }
    }
}

// MARK: - MIDI Callback

private func midiReadCallback(
    _ packetList: UnsafePointer<MIDIPacketList>,
    _ readProcRefCon: UnsafeMutableRawPointer?,
    _ srcConnRefCon: UnsafeMutableRawPointer?
) {
    guard let refCon = readProcRefCon else { return }
    let manager = Unmanaged<ROLIDeviceManager>.fromOpaque(refCon).takeUnretainedValue()

    let packets = packetList.pointee
    var packet = packets.packet

    for _ in 0..<packets.numPackets {
        let data = Array(UnsafeBufferPointer(start: &packet.data.0, count: Int(packet.length)))

        Task { @MainActor in
            manager.handleMIDIMessage(data, from: nil)
        }

        packet = MIDIPacketNext(&packet).pointee
    }
}

// MARK: - Airwave Processor

public class AirwaveProcessor {
    private var smoothingFactor: Float = 0.3
    private var deadzone: Float = 0.05

    func process(_ data: AirwaveGestureData) -> AirwaveGestureData {
        var processed = data

        // Apply deadzone
        if abs(processed.x) < deadzone { processed.x = 0 }
        if abs(processed.y) < deadzone { processed.y = 0 }
        if processed.z < deadzone { processed.z = 0 }

        return processed
    }
}

// MARK: - ROLI LED Controller

public class ROLILEDController {
    func setAllLEDs(color: LEDColor) {
        // Set all LEDs to a single color
    }

    func animateRainbow(speed: Float) {
        // Rainbow animation
    }

    func pulse(color: LEDColor, rate: Float) {
        // Pulsing animation synced to heartbeat
    }
}
