// HardwareControlEngine.swift
// Echoelmusic - Hardware Controller Integration
// Created by Claude (Phase 4) - December 2025

import Foundation
import CoreMIDI
import Combine

// MARK: - Controller Types

/// Supported hardware controllers
public enum ControllerType: String, CaseIterable, Codable {
    // Ableton
    case abletonPush = "Ableton Push"
    case abletonPush2 = "Ableton Push 2"
    case abletonPush3 = "Ableton Push 3"

    // Novation
    case launchpadMini = "Launchpad Mini"
    case launchpadX = "Launchpad X"
    case launchpadPro = "Launchpad Pro"
    case launchkey = "Launchkey"
    case slMkIII = "SL MkIII"

    // Native Instruments
    case maschine = "Maschine"
    case maschineMikro = "Maschine Mikro"
    case maschineJam = "Maschine Jam"
    case komplete = "Komplete Kontrol"

    // Akai
    case apcMini = "APC Mini"
    case apc40 = "APC40"
    case mpd = "MPD"
    case mpc = "MPC"

    // Generic
    case genericMIDI = "Generic MIDI"
    case genericOSC = "Generic OSC"

    var gridSize: (rows: Int, cols: Int)? {
        switch self {
        case .abletonPush, .abletonPush2, .abletonPush3:
            return (8, 8)
        case .launchpadMini, .launchpadX, .launchpadPro:
            return (8, 8)
        case .maschine:
            return (4, 4)
        case .maschineMikro:
            return (4, 4)
        case .maschineJam:
            return (8, 8)
        case .apcMini, .apc40:
            return (8, 8)
        default:
            return nil
        }
    }

    var hasMotorizedFaders: Bool {
        switch self {
        case .abletonPush3, .slMkIII:
            return true
        default:
            return false
        }
    }

    var hasDisplay: Bool {
        switch self {
        case .abletonPush, .abletonPush2, .abletonPush3, .maschine, .slMkIII:
            return true
        default:
            return false
        }
    }
}

// MARK: - Control Surface Elements

/// Pad on a grid controller
public struct ControlPad: Identifiable {
    public let id: Int
    public let row: Int
    public let col: Int
    public var midiNote: UInt8
    public var color: PadColor
    public var isPressed: Bool
    public var velocity: UInt8
    public var pressure: UInt8  // Aftertouch

    public init(id: Int, row: Int, col: Int, midiNote: UInt8) {
        self.id = id
        self.row = row
        self.col = col
        self.midiNote = midiNote
        self.color = .off
        self.isPressed = false
        self.velocity = 0
        self.pressure = 0
    }
}

public enum PadColor: UInt8 {
    case off = 0
    case red = 5
    case orange = 9
    case yellow = 13
    case green = 21
    case cyan = 33
    case blue = 45
    case purple = 49
    case pink = 53
    case white = 3

    // Blinking modes
    case redBlink = 6
    case greenBlink = 22
    case blueBlink = 46
}

/// Encoder/knob on a controller
public struct ControlEncoder: Identifiable {
    public let id: Int
    public var cc: UInt8
    public var value: Float  // 0-1
    public var isEndless: Bool
    public var displayValue: String?
    public var label: String?

    public init(id: Int, cc: UInt8, isEndless: Bool = true) {
        self.id = id
        self.cc = cc
        self.value = 0
        self.isEndless = isEndless
    }
}

/// Fader on a controller
public struct ControlFader: Identifiable {
    public let id: Int
    public var cc: UInt8
    public var value: Float  // 0-1
    public var isMotorized: Bool
    public var isTouched: Bool
    public var label: String?

    public init(id: Int, cc: UInt8, isMotorized: Bool = false) {
        self.id = id
        self.cc = cc
        self.value = 0
        self.isMotorized = isMotorized
        self.isTouched = false
    }
}

/// Button on a controller
public struct ControlButton: Identifiable {
    public let id: Int
    public var cc: UInt8
    public var isPressed: Bool
    public var isLit: Bool
    public var color: PadColor
    public var label: String?

    public init(id: Int, cc: UInt8, label: String? = nil) {
        self.id = id
        self.cc = cc
        self.isPressed = false
        self.isLit = false
        self.color = .off
        self.label = label
    }
}

// MARK: - Controller Mapping

/// Maps controller elements to software functions
public struct ControlMapping: Codable, Identifiable {
    public let id: UUID
    public var controlType: ControlType
    public var controlId: Int
    public var action: MappedAction
    public var channel: Int
    public var parameter: String?
    public var range: ClosedRange<Float>

    public enum ControlType: String, Codable {
        case pad, encoder, fader, button
    }

    public enum MappedAction: String, Codable {
        // Transport
        case play, stop, record, loop
        case rewind, fastForward
        case metronome, tap

        // Mixer
        case volume, pan, mute, solo
        case send1, send2, send3, send4

        // Clips
        case launchClip, stopClip, recordClip
        case launchScene, stopScene

        // Instruments
        case noteOn, noteOff, pitchBend
        case modWheel, aftertouch

        // Navigation
        case trackLeft, trackRight
        case sceneUp, sceneDown
        case bankLeft, bankRight

        // Parameters
        case parameterControl
        case macroControl

        // Custom
        case custom
    }

    public init(controlType: ControlType, controlId: Int, action: MappedAction) {
        self.id = UUID()
        self.controlType = controlType
        self.controlId = controlId
        self.action = action
        self.channel = 0
        self.range = 0...1
    }
}

// MARK: - Controller State

/// Current state of a connected controller
public final class ControllerState: ObservableObject, @unchecked Sendable {
    public let type: ControllerType
    public let name: String

    @Published public var isConnected: Bool = false
    @Published public var pads: [ControlPad] = []
    @Published public var encoders: [ControlEncoder] = []
    @Published public var faders: [ControlFader] = []
    @Published public var buttons: [ControlButton] = []

    // Display
    @Published public var displayLines: [String] = []

    // Mode
    @Published public var currentMode: ControllerMode = .session

    public init(type: ControllerType, name: String) {
        self.type = type
        self.name = name
        setupElements()
    }

    private func setupElements() {
        // Setup pads based on controller type
        if let gridSize = type.gridSize {
            var padId = 0
            for row in 0..<gridSize.rows {
                for col in 0..<gridSize.cols {
                    let midiNote = UInt8(36 + row * 8 + col)  // Standard mapping
                    pads.append(ControlPad(id: padId, row: row, col: col, midiNote: midiNote))
                    padId += 1
                }
            }
        }

        // Setup encoders (8 is common)
        for i in 0..<8 {
            encoders.append(ControlEncoder(id: i, cc: UInt8(71 + i)))
        }

        // Setup faders
        let faderCount = type.hasMotorizedFaders ? 9 : 0
        for i in 0..<faderCount {
            faders.append(ControlFader(id: i, cc: UInt8(41 + i), isMotorized: true))
        }

        // Setup common buttons
        let commonButtons = ["Play", "Stop", "Record", "Loop", "Undo", "Redo", "Metronome", "Tap"]
        for (i, label) in commonButtons.enumerated() {
            buttons.append(ControlButton(id: i, cc: UInt8(85 + i), label: label))
        }
    }
}

public enum ControllerMode: String, CaseIterable {
    case session = "Session"
    case note = "Note"
    case drum = "Drum"
    case scale = "Scale"
    case user = "User"
    case mixer = "Mixer"
    case device = "Device"
}

// MARK: - MIDI Controller Manager

/// Manages MIDI communication with hardware controllers
public final class MIDIControllerManager: @unchecked Sendable {

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0

    private var connectedDevices: [String: MIDIEndpointRef] = [:]
    private let lock = NSLock()

    // Callbacks
    public var onNoteOn: ((UInt8, UInt8, UInt8) -> Void)?  // channel, note, velocity
    public var onNoteOff: ((UInt8, UInt8) -> Void)?       // channel, note
    public var onCC: ((UInt8, UInt8, UInt8) -> Void)?     // channel, cc, value
    public var onPitchBend: ((UInt8, Int16) -> Void)?     // channel, value
    public var onAftertouch: ((UInt8, UInt8) -> Void)?    // channel, pressure

    public init() throws {
        // Create MIDI client
        var status = MIDIClientCreate("Echoelmusic" as CFString, nil, nil, &midiClient)
        guard status == noErr else { throw MIDIError.clientCreationFailed }

        // Create input port
        status = MIDIInputPortCreate(midiClient, "Input" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
        guard status == noErr else { throw MIDIError.portCreationFailed }

        // Create output port
        status = MIDIOutputPortCreate(midiClient, "Output" as CFString, &outputPort)
        guard status == noErr else { throw MIDIError.portCreationFailed }
    }

    deinit {
        MIDIPortDispose(inputPort)
        MIDIPortDispose(outputPort)
        MIDIClientDispose(midiClient)
    }

    /// Scan for available MIDI devices
    public func scanDevices() -> [(name: String, id: String)] {
        var devices: [(name: String, id: String)] = []

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let name = getMIDIObjectName(source) {
                devices.append((name: name, id: "\(source)"))
            }
        }

        return devices
    }

    /// Connect to a MIDI device
    public func connect(deviceId: String) throws {
        guard let endpoint = MIDIEndpointRef(deviceId) else {
            throw MIDIError.deviceNotFound
        }

        let status = MIDIPortConnectSource(inputPort, endpoint, nil)
        guard status == noErr else { throw MIDIError.connectionFailed }

        if let name = getMIDIObjectName(endpoint) {
            lock.lock()
            connectedDevices[name] = endpoint
            lock.unlock()
        }
    }

    /// Disconnect from a device
    public func disconnect(deviceId: String) {
        guard let endpoint = MIDIEndpointRef(deviceId) else { return }
        MIDIPortDisconnectSource(inputPort, endpoint)

        lock.lock()
        connectedDevices = connectedDevices.filter { $0.value != endpoint }
        lock.unlock()
    }

    /// Send MIDI message
    public func send(to deviceName: String, message: [UInt8]) {
        lock.lock()
        let endpoint = connectedDevices[deviceName]
        lock.unlock()

        guard let dest = endpoint else { return }

        // Find corresponding destination
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let destEndpoint = MIDIGetDestination(i)
            if let name = getMIDIObjectName(destEndpoint), name == deviceName {
                sendMIDI(to: destEndpoint, message: message)
                return
            }
        }
    }

    private func sendMIDI(to dest: MIDIEndpointRef, message: [UInt8]) {
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = UInt16(message.count)

        withUnsafeMutableBytes(of: &packet.data) { ptr in
            for (i, byte) in message.enumerated() where i < 256 {
                ptr[i] = byte
            }
        }

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outputPort, dest, &packetList)
    }

    /// Send note on
    public func sendNoteOn(to device: String, channel: UInt8, note: UInt8, velocity: UInt8) {
        let status = 0x90 | (channel & 0x0F)
        send(to: device, message: [status, note, velocity])
    }

    /// Send note off
    public func sendNoteOff(to device: String, channel: UInt8, note: UInt8) {
        let status = 0x80 | (channel & 0x0F)
        send(to: device, message: [status, note, 0])
    }

    /// Send CC
    public func sendCC(to device: String, channel: UInt8, cc: UInt8, value: UInt8) {
        let status = 0xB0 | (channel & 0x0F)
        send(to: device, message: [status, cc, value])
    }

    /// Send SysEx (for controller-specific features)
    public func sendSysEx(to device: String, data: [UInt8]) {
        var message: [UInt8] = [0xF0]  // SysEx start
        message.append(contentsOf: data)
        message.append(0xF7)  // SysEx end
        send(to: device, message: message)
    }

    private func getMIDIObjectName(_ object: MIDIObjectRef) -> String? {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, kMIDIPropertyName, &name)
        guard status == noErr, let cfName = name?.takeRetainedValue() else { return nil }
        return cfName as String
    }

    // MIDI read callback
    private let midiReadProc: MIDIReadProc = { packetList, srcConnRefCon, _ in
        let manager = Unmanaged<MIDIControllerManager>.fromOpaque(srcConnRefCon!).takeUnretainedValue()

        let packets = packetList.pointee
        var packet = packets.packet

        for _ in 0..<packets.numPackets {
            let data = Mirror(reflecting: packet.data).children.map { $0.value as! UInt8 }
            let length = Int(packet.length)

            if length >= 1 {
                let status = data[0]
                let type = status & 0xF0
                let channel = status & 0x0F

                switch type {
                case 0x90:  // Note On
                    if length >= 3 && data[2] > 0 {
                        manager.onNoteOn?(channel, data[1], data[2])
                    } else if length >= 2 {
                        manager.onNoteOff?(channel, data[1])
                    }
                case 0x80:  // Note Off
                    if length >= 2 {
                        manager.onNoteOff?(channel, data[1])
                    }
                case 0xB0:  // CC
                    if length >= 3 {
                        manager.onCC?(channel, data[1], data[2])
                    }
                case 0xE0:  // Pitch Bend
                    if length >= 3 {
                        let value = Int16(data[1]) | (Int16(data[2]) << 7) - 8192
                        manager.onPitchBend?(channel, value)
                    }
                case 0xD0:  // Channel Aftertouch
                    if length >= 2 {
                        manager.onAftertouch?(channel, data[1])
                    }
                default:
                    break
                }
            }

            packet = MIDIPacketNext(&packet).pointee
        }
    }
}

// MARK: - Controller Profiles

/// Pre-configured mappings for specific controllers
public struct ControllerProfile: Codable {
    public var controllerType: ControllerType
    public var mappings: [ControlMapping]
    public var sysExInit: [[UInt8]]  // Initialization messages
    public var sysExMode: [ControllerMode: [UInt8]]  // Mode switch messages

    public static func pushProfile() -> ControllerProfile {
        var profile = ControllerProfile(
            controllerType: .abletonPush2,
            mappings: [],
            sysExInit: [],
            sysExMode: [:]
        )

        // Pad mappings (8x8 grid for clip launching)
        for row in 0..<8 {
            for col in 0..<8 {
                let padId = row * 8 + col
                var mapping = ControlMapping(controlType: .pad, controlId: padId, action: .launchClip)
                mapping.channel = col  // Track
                mapping.parameter = "\(row)"  // Scene
                profile.mappings.append(mapping)
            }
        }

        // Encoder mappings (8 encoders for device parameters)
        for i in 0..<8 {
            var mapping = ControlMapping(controlType: .encoder, controlId: i, action: .parameterControl)
            mapping.parameter = "param\(i)"
            profile.mappings.append(mapping)
        }

        // Transport buttons
        profile.mappings.append(ControlMapping(controlType: .button, controlId: 0, action: .play))
        profile.mappings.append(ControlMapping(controlType: .button, controlId: 1, action: .stop))
        profile.mappings.append(ControlMapping(controlType: .button, controlId: 2, action: .record))

        // Push 2 SysEx for user mode
        profile.sysExInit = [
            [0x00, 0x21, 0x1D, 0x01, 0x01, 0x0A, 0x01]  // Set to User mode
        ]

        return profile
    }

    public static func launchpadProfile() -> ControllerProfile {
        var profile = ControllerProfile(
            controllerType: .launchpadX,
            mappings: [],
            sysExInit: [],
            sysExMode: [:]
        )

        // Session mode pad mappings
        for row in 0..<8 {
            for col in 0..<8 {
                let padId = row * 8 + col
                var mapping = ControlMapping(controlType: .pad, controlId: padId, action: .launchClip)
                mapping.channel = col
                mapping.parameter = "\(row)"
                profile.mappings.append(mapping)
            }
        }

        // Launchpad X programmer mode
        profile.sysExInit = [
            [0x00, 0x20, 0x29, 0x02, 0x0C, 0x0E, 0x01]  // Programmer mode
        ]

        return profile
    }

    public static func maschineProfile() -> ControllerProfile {
        var profile = ControllerProfile(
            controllerType: .maschine,
            mappings: [],
            sysExInit: [],
            sysExMode: [:]
        )

        // 4x4 pad grid for drum sequencing
        for row in 0..<4 {
            for col in 0..<4 {
                let padId = row * 4 + col
                var mapping = ControlMapping(controlType: .pad, controlId: padId, action: .noteOn)
                mapping.parameter = "\(36 + padId)"  // MIDI note
                profile.mappings.append(mapping)
            }
        }

        // Encoders for sound parameters
        for i in 0..<8 {
            var mapping = ControlMapping(controlType: .encoder, controlId: i, action: .macroControl)
            mapping.parameter = "macro\(i)"
            profile.mappings.append(mapping)
        }

        return profile
    }
}

// MARK: - Hardware Control Engine

/// Main hardware control integration engine
public actor HardwareControlEngine {

    public static let shared = HardwareControlEngine()

    private var midiManager: MIDIControllerManager?
    private var controllers: [String: ControllerState] = [:]
    private var profiles: [ControllerType: ControllerProfile] = [:]
    private var activeProfile: ControllerProfile?

    // Callbacks
    public var onPadPressed: ((Int, UInt8) -> Void)?      // padId, velocity
    public var onPadReleased: ((Int) -> Void)?            // padId
    public var onEncoderTurned: ((Int, Float) -> Void)?   // encoderId, delta
    public var onFaderMoved: ((Int, Float) -> Void)?      // faderId, value
    public var onButtonPressed: ((Int) -> Void)?          // buttonId
    public var onTransport: ((ControlMapping.MappedAction) -> Void)?

    private init() {
        setupProfiles()
    }

    private func setupProfiles() {
        profiles[.abletonPush2] = ControllerProfile.pushProfile()
        profiles[.abletonPush3] = ControllerProfile.pushProfile()
        profiles[.launchpadX] = ControllerProfile.launchpadProfile()
        profiles[.launchpadPro] = ControllerProfile.launchpadProfile()
        profiles[.maschine] = ControllerProfile.maschineProfile()
    }

    // MARK: - Initialization

    public func initialize() async throws {
        midiManager = try MIDIControllerManager()
        setupMIDICallbacks()
    }

    private func setupMIDICallbacks() {
        midiManager?.onNoteOn = { [weak self] channel, note, velocity in
            Task { await self?.handleNoteOn(channel: channel, note: note, velocity: velocity) }
        }

        midiManager?.onNoteOff = { [weak self] channel, note in
            Task { await self?.handleNoteOff(channel: channel, note: note) }
        }

        midiManager?.onCC = { [weak self] channel, cc, value in
            Task { await self?.handleCC(channel: channel, cc: cc, value: value) }
        }
    }

    // MARK: - Device Management

    public func scanForControllers() -> [(name: String, id: String, type: ControllerType?)] {
        guard let manager = midiManager else { return [] }

        return manager.scanDevices().map { device in
            let type = detectControllerType(name: device.name)
            return (name: device.name, id: device.id, type: type)
        }
    }

    public func connect(deviceId: String, name: String) async throws {
        guard let manager = midiManager else { throw MIDIError.notInitialized }

        try manager.connect(deviceId: deviceId)

        let type = detectControllerType(name: name) ?? .genericMIDI
        let state = ControllerState(type: type, name: name)
        state.isConnected = true
        controllers[name] = state

        // Load profile and initialize
        if let profile = profiles[type] {
            activeProfile = profile

            // Send init SysEx
            for sysEx in profile.sysExInit {
                manager.sendSysEx(to: name, data: sysEx)
            }
        }

        // Initialize pad colors
        await setAllPadColors(device: name, color: .off)
    }

    public func disconnect(deviceName: String) async {
        guard let manager = midiManager, let controller = controllers[deviceName] else { return }

        // Turn off all LEDs
        await setAllPadColors(device: deviceName, color: .off)

        manager.disconnect(deviceId: deviceName)
        controller.isConnected = false
        controllers.removeValue(forKey: deviceName)
    }

    private func detectControllerType(name: String) -> ControllerType? {
        let lowercaseName = name.lowercased()

        if lowercaseName.contains("push 3") { return .abletonPush3 }
        if lowercaseName.contains("push 2") { return .abletonPush2 }
        if lowercaseName.contains("push") { return .abletonPush }
        if lowercaseName.contains("launchpad pro") { return .launchpadPro }
        if lowercaseName.contains("launchpad x") { return .launchpadX }
        if lowercaseName.contains("launchpad mini") { return .launchpadMini }
        if lowercaseName.contains("launchpad") { return .launchpadMini }
        if lowercaseName.contains("launchkey") { return .launchkey }
        if lowercaseName.contains("sl mkiii") { return .slMkIII }
        if lowercaseName.contains("maschine jam") { return .maschineJam }
        if lowercaseName.contains("maschine mikro") { return .maschineMikro }
        if lowercaseName.contains("maschine") { return .maschine }
        if lowercaseName.contains("komplete kontrol") { return .komplete }
        if lowercaseName.contains("apc mini") { return .apcMini }
        if lowercaseName.contains("apc40") { return .apc40 }
        if lowercaseName.contains("mpd") { return .mpd }
        if lowercaseName.contains("mpc") { return .mpc }

        return nil
    }

    // MARK: - MIDI Handling

    private func handleNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        // Find pad with this note
        for (_, controller) in controllers {
            if let padIndex = controller.pads.firstIndex(where: { $0.midiNote == note }) {
                controller.pads[padIndex].isPressed = true
                controller.pads[padIndex].velocity = velocity
                onPadPressed?(padIndex, velocity)

                // Check mapping
                if let mapping = findMapping(controlType: .pad, controlId: padIndex) {
                    executeMapping(mapping, value: Float(velocity) / 127.0)
                }
            }
        }
    }

    private func handleNoteOff(channel: UInt8, note: UInt8) {
        for (_, controller) in controllers {
            if let padIndex = controller.pads.firstIndex(where: { $0.midiNote == note }) {
                controller.pads[padIndex].isPressed = false
                controller.pads[padIndex].velocity = 0
                onPadReleased?(padIndex)
            }
        }
    }

    private func handleCC(channel: UInt8, cc: UInt8, value: UInt8) {
        for (_, controller) in controllers {
            // Check encoders
            if let encoderIndex = controller.encoders.firstIndex(where: { $0.cc == cc }) {
                let encoder = controller.encoders[encoderIndex]

                if encoder.isEndless {
                    // Relative mode: values 1-63 = increment, 65-127 = decrement
                    let delta: Float = value < 64 ? Float(value) / 127.0 : -Float(128 - Int(value)) / 127.0
                    controller.encoders[encoderIndex].value = max(0, min(1, encoder.value + delta))
                    onEncoderTurned?(encoderIndex, delta)
                } else {
                    // Absolute mode
                    controller.encoders[encoderIndex].value = Float(value) / 127.0
                    onEncoderTurned?(encoderIndex, Float(value) / 127.0)
                }

                if let mapping = findMapping(controlType: .encoder, controlId: encoderIndex) {
                    executeMapping(mapping, value: controller.encoders[encoderIndex].value)
                }
            }

            // Check faders
            if let faderIndex = controller.faders.firstIndex(where: { $0.cc == cc }) {
                controller.faders[faderIndex].value = Float(value) / 127.0
                onFaderMoved?(faderIndex, Float(value) / 127.0)

                if let mapping = findMapping(controlType: .fader, controlId: faderIndex) {
                    executeMapping(mapping, value: Float(value) / 127.0)
                }
            }

            // Check buttons
            if let buttonIndex = controller.buttons.firstIndex(where: { $0.cc == cc }) {
                let pressed = value > 0
                controller.buttons[buttonIndex].isPressed = pressed

                if pressed {
                    onButtonPressed?(buttonIndex)

                    if let mapping = findMapping(controlType: .button, controlId: buttonIndex) {
                        executeMapping(mapping, value: 1.0)
                    }
                }
            }
        }
    }

    private func findMapping(controlType: ControlMapping.ControlType, controlId: Int) -> ControlMapping? {
        activeProfile?.mappings.first { $0.controlType == controlType && $0.controlId == controlId }
    }

    private func executeMapping(_ mapping: ControlMapping, value: Float) {
        switch mapping.action {
        case .play, .stop, .record, .loop, .metronome:
            onTransport?(mapping.action)
        default:
            break
        }
    }

    // MARK: - Feedback (LEDs, Displays)

    public func setPadColor(device: String, padIndex: Int, color: PadColor) async {
        guard let manager = midiManager,
              let controller = controllers[device],
              padIndex < controller.pads.count else { return }

        let pad = controller.pads[padIndex]
        manager.sendNoteOn(to: device, channel: 0, note: pad.midiNote, velocity: color.rawValue)
        controllers[device]?.pads[padIndex].color = color
    }

    public func setAllPadColors(device: String, color: PadColor) async {
        guard let controller = controllers[device] else { return }

        for i in 0..<controller.pads.count {
            await setPadColor(device: device, padIndex: i, color: color)
        }
    }

    public func setPadGrid(device: String, colors: [[PadColor]]) async {
        guard let controller = controllers[device],
              let gridSize = controller.type.gridSize else { return }

        for row in 0..<min(colors.count, gridSize.rows) {
            for col in 0..<min(colors[row].count, gridSize.cols) {
                let padIndex = row * gridSize.cols + col
                await setPadColor(device: device, padIndex: padIndex, color: colors[row][col])
            }
        }
    }

    public func setEncoderRing(device: String, encoderIndex: Int, value: Float) async {
        guard let manager = midiManager,
              let controller = controllers[device],
              encoderIndex < controller.encoders.count else { return }

        // Encoder ring LEDs typically use CC messages
        // Value 0-127 represents LED position
        let encoder = controller.encoders[encoderIndex]
        let ledValue = UInt8(min(127, value * 127))
        manager.sendCC(to: device, channel: 0, cc: encoder.cc + 8, value: ledValue)  // Ring CC offset
    }

    public func setFaderPosition(device: String, faderIndex: Int, value: Float) async {
        guard let manager = midiManager,
              let controller = controllers[device],
              faderIndex < controller.faders.count,
              controller.faders[faderIndex].isMotorized else { return }

        let fader = controller.faders[faderIndex]
        let midiValue = UInt8(min(127, value * 127))
        manager.sendCC(to: device, channel: 0, cc: fader.cc, value: midiValue)
    }

    // MARK: - Mode Switching

    public func setMode(device: String, mode: ControllerMode) async {
        guard let manager = midiManager,
              let controller = controllers[device],
              let profile = profiles[controller.type],
              let sysEx = profile.sysExMode[mode] else { return }

        manager.sendSysEx(to: device, data: sysEx)
        controllers[device]?.currentMode = mode
    }

    // MARK: - Custom Mapping

    public func addMapping(_ mapping: ControlMapping) {
        activeProfile?.mappings.append(mapping)
    }

    public func removeMapping(id: UUID) {
        activeProfile?.mappings.removeAll { $0.id == id }
    }

    public func getMappings() -> [ControlMapping] {
        activeProfile?.mappings ?? []
    }

    // MARK: - State Access

    public func getController(name: String) -> ControllerState? {
        controllers[name]
    }

    public func getAllControllers() -> [ControllerState] {
        Array(controllers.values)
    }
}

// MARK: - Errors

public enum MIDIError: Error {
    case clientCreationFailed
    case portCreationFailed
    case deviceNotFound
    case connectionFailed
    case notInitialized
}
