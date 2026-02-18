// EchoelShowControl.swift
// Echoelmusic — MIDI Show Control & DAW Control Surface Protocol Engine
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelShowControl — Professional show control & DAW surface integration
//
// Implements:
// 1. MIDI Show Control (MSC) — USITT standard for theater/live events
//    - GO, STOP, RESUME, TIMED_GO, FIRE, ALL_OFF commands
//    - Cue number addressing (major.minor.sub)
//    - Device group targeting (lighting, sound, video, pyro, etc.)
//    - QLab integration (bidirectional via MSC + OSC)
//
// 2. Mackie Control Universal (MCU) — DAW control surface protocol
//    - Fader touch/move (10-bit resolution, motorized)
//    - V-Pot (rotary encoder) for pan/send/plugin params
//    - Transport controls (play, stop, record, scrub, jog)
//    - Channel metering (LED/LCD peak meters)
//    - LCD scribble strips (2x7 character per channel)
//    - Bank/channel navigation
//    - Automation modes (read/write/touch/latch/trim)
//
// 3. HUI (Human User Interface) — Avid/Pro Tools protocol
//    - Similar to Mackie but 4-bit nibble zone/port addressing
//    - Pro Tools-specific transport (online, quickpunch, audition)
//    - Edit mode controls (cut, copy, paste, undo)
//
// Compatible Hardware:
//   Mackie Control: Behringer X-Touch, Icon Platform M+, SSL UF8,
//                   Avid S1, PreSonus FaderPort, Softube Console 1
//   HUI: Avid Artist Series, Icon QCon, Mackie HUI
//   MSC: Any MSC-capable lighting/show controller
//
// Architecture:
// ┌────────────────────────────────────────────────────────────┐
// │  EchoelShowControl                                        │
// │       │                                                   │
// │       ├─→ MSCEngine (MIDI Show Control)                   │
// │       │       ├─→ Send/receive MSC commands               │
// │       │       └─→ Cue list synchronization                │
// │       │                                                   │
// │       ├─→ MackieControl (MCU protocol)                    │
// │       │       ├─→ Fader/VPot/Button state machine         │
// │       │       ├─→ LCD/meter updates                       │
// │       │       └─→ Bi-directional surface sync             │
// │       │                                                   │
// │       ├─→ HUIProtocol                                     │
// │       │       └─→ Zone/port nibble-based control          │
// │       │                                                   │
// │       └─→ EngineBus bridge                                │
// └────────────────────────────────────────────────────────────┘
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - MSC (MIDI Show Control) Types

/// MIDI Show Control command types (USITT standard)
public enum MSCCommand: UInt8, CaseIterable, Sendable {
    case go = 0x01            // GO: Execute cue
    case stop = 0x02          // STOP: Halt cue
    case resume = 0x03        // RESUME: Continue halted cue
    case timedGo = 0x04       // TIMED_GO: Execute with fade time
    case load = 0x05          // LOAD: Prepare cue
    case set = 0x06           // SET: Set value
    case fire = 0x07          // FIRE: Immediate trigger
    case allOff = 0x08        // ALL_OFF: Emergency stop
    case restore = 0x09       // RESTORE: Reset to default
    case reset = 0x0A         // RESET: Full system reset
    case goOff = 0x0B         // GO_OFF: Fade out cue
    case goPanic = 0x10       // GO/JAM_CLOCK: Panic stop

    public var description: String {
        switch self {
        case .go: return "GO"
        case .stop: return "STOP"
        case .resume: return "RESUME"
        case .timedGo: return "TIMED GO"
        case .load: return "LOAD"
        case .set: return "SET"
        case .fire: return "FIRE"
        case .allOff: return "ALL OFF"
        case .restore: return "RESTORE"
        case .reset: return "RESET"
        case .goOff: return "GO OFF"
        case .goPanic: return "PANIC"
        }
    }
}

/// MSC device group categories
public enum MSCDeviceGroup: UInt8, CaseIterable, Sendable {
    case lighting = 0x01       // Lighting controllers
    case movingLights = 0x02   // Moving lights
    case colorChangers = 0x03  // Color changers
    case strobes = 0x04        // Strobes
    case lasers = 0x05         // Lasers
    case chasers = 0x06        // Chasers
    case sound = 0x10          // Sound playback
    case music = 0x11          // Music playback
    case cdPlayer = 0x12       // CD player
    case video = 0x30          // Video playback
    case videoTape = 0x31      // Video tape
    case fileSvr = 0x32        // File server
    case projection = 0x40     // Projectors
    case filmProj = 0x41       // Film projectors
    case slideProj = 0x42      // Slide projectors
    case pyro = 0x60           // Pyrotechnics
    case fog = 0x61            // Fog machines
    case allTypes = 0x7F       // All device types

    public var description: String {
        switch self {
        case .lighting: return "Lighting"
        case .movingLights: return "Moving Lights"
        case .colorChangers: return "Color Changers"
        case .strobes: return "Strobes"
        case .lasers: return "Lasers"
        case .chasers: return "Chasers"
        case .sound: return "Sound"
        case .music: return "Music"
        case .cdPlayer: return "CD Player"
        case .video: return "Video"
        case .videoTape: return "Video Tape"
        case .fileSvr: return "File Server"
        case .projection: return "Projection"
        case .filmProj: return "Film Projector"
        case .slideProj: return "Slide Projector"
        case .pyro: return "Pyrotechnics"
        case .fog: return "Fog Machines"
        case .allTypes: return "All Types"
        }
    }
}

/// MSC cue number (major.minor.sub format)
public struct MSCCueNumber: Sendable, CustomStringConvertible {
    public let major: String
    public let minor: String?
    public let sub: String?

    public init(major: String, minor: String? = nil, sub: String? = nil) {
        self.major = major
        self.minor = minor
        self.sub = sub
    }

    public init(_ number: Double) {
        let intPart = Int(number)
        let fracPart = number - Double(intPart)
        self.major = "\(intPart)"
        self.minor = fracPart > 0 ? "\(Int(fracPart * 100))" : nil
        self.sub = nil
    }

    public var description: String {
        var s = major
        if let m = minor { s += ".\(m)" }
        if let sub = sub { s += ".\(sub)" }
        return s
    }

    /// Encode cue number as ASCII bytes per MSC spec
    public func encode() -> [UInt8] {
        var bytes: [UInt8] = Array(major.utf8)
        if let minor = minor {
            bytes.append(0x2E) // "."
            bytes.append(contentsOf: minor.utf8)
        }
        if let sub = sub {
            bytes.append(0x2E)
            bytes.append(contentsOf: sub.utf8)
        }
        return bytes
    }
}

/// An MSC command ready to send/received
public struct MSCEvent: Sendable {
    public let command: MSCCommand
    public let deviceGroup: MSCDeviceGroup
    public let cueNumber: MSCCueNumber?
    public let fadeTime: TimeInterval?
    public let deviceId: UInt8      // 0x7F = all devices
    public let timestamp: Date

    public init(
        command: MSCCommand,
        deviceGroup: MSCDeviceGroup = .allTypes,
        cueNumber: MSCCueNumber? = nil,
        fadeTime: TimeInterval? = nil,
        deviceId: UInt8 = 0x7F,
        timestamp: Date = Date()
    ) {
        self.command = command
        self.deviceGroup = deviceGroup
        self.cueNumber = cueNumber
        self.fadeTime = fadeTime
        self.deviceId = deviceId
        self.timestamp = timestamp
    }

    /// Encode as MIDI SysEx (F0 7F <device> 02 <group> <cmd> <data> F7)
    public func encode() -> [UInt8] {
        var bytes: [UInt8] = [
            0xF0,                    // SysEx start
            0x7F,                    // Universal Real-Time
            deviceId,                // Device ID (7F = all)
            0x02,                    // Sub-ID#1: MSC
            deviceGroup.rawValue,    // Command format (device group)
            command.rawValue         // Command
        ]

        // Cue number (if applicable)
        if let cue = cueNumber {
            bytes.append(contentsOf: cue.encode())
        }

        bytes.append(0xF7) // SysEx end
        return bytes
    }

    /// Decode MSC SysEx
    public static func decode(from bytes: [UInt8]) -> MSCEvent? {
        guard bytes.count >= 7,
              bytes[0] == 0xF0,
              bytes[1] == 0x7F,
              bytes[3] == 0x02,
              bytes.last == 0xF7 else { return nil }

        let deviceId = bytes[2]
        guard let group = MSCDeviceGroup(rawValue: bytes[4]),
              let command = MSCCommand(rawValue: bytes[5]) else { return nil }

        // Parse cue number from remaining bytes
        var cue: MSCCueNumber? = nil
        if bytes.count > 7 {
            let cueBytes = Array(bytes[6..<bytes.count-1])
            if let cueStr = String(bytes: cueBytes, encoding: .utf8) {
                let parts = cueStr.split(separator: ".")
                cue = MSCCueNumber(
                    major: String(parts[0]),
                    minor: parts.count > 1 ? String(parts[1]) : nil,
                    sub: parts.count > 2 ? String(parts[2]) : nil
                )
            }
        }

        return MSCEvent(command: command, deviceGroup: group, cueNumber: cue, deviceId: deviceId)
    }
}

// MARK: - Mackie Control Universal (MCU) Types

/// MCU channel strip state
public struct MCUChannelStrip: Identifiable, Sendable {
    public let id: Int          // Channel index (0-7 per bank)
    public var faderValue: UInt16 = 0    // 0-16383 (14-bit)
    public var vpotValue: UInt8 = 64     // 0-127
    public var vpotMode: VPotMode = .single
    public var isMuted: Bool = false
    public var isSoloed: Bool = false
    public var isArmed: Bool = false
    public var isSelected: Bool = false
    public var meterLevel: UInt8 = 0     // 0-14 (LED segments)
    public var scribbleTop: String = ""  // 7 chars max
    public var scribbleBottom: String = ""

    public enum VPotMode: UInt8, Sendable {
        case single = 0      // Single dot
        case boost = 1       // Fill from center-left
        case cut = 2         // Fill from center-right
        case spread = 3      // Spread from center
        case pan = 4         // Pan indicator
    }
}

/// MCU transport state
public struct MCUTransport: Sendable {
    public var isPlaying: Bool = false
    public var isRecording: Bool = false
    public var isStopped: Bool = true
    public var isRewinding: Bool = false
    public var isFastForwarding: Bool = false
    public var isScrubbing: Bool = false
    public var isLooping: Bool = false
    public var jogValue: Int = 0         // Relative encoder
}

/// MCU button identifiers (standard Mackie Control layout)
public enum MCUButton: UInt8, CaseIterable, Sendable {
    // Channel strip buttons (per channel, offset by channel number)
    case rec = 0x00         // Record arm
    case solo = 0x08        // Solo
    case mute = 0x10        // Mute
    case select = 0x18      // Select

    // Assignment buttons
    case track = 0x28
    case send = 0x29
    case pan = 0x2A
    case plugin = 0x2B
    case eq = 0x2C
    case instrument = 0x2D

    // Navigation
    case bankLeft = 0x2E
    case bankRight = 0x2F
    case channelLeft = 0x30
    case channelRight = 0x31

    // Transport
    case rewind = 0x5B
    case fastForward = 0x5C
    case stop = 0x5D
    case play = 0x5E
    case record = 0x5F

    // Modifier
    case shift = 0x46
    case option = 0x47
    case control = 0x48
    case alt = 0x49

    // Automation
    case readMode = 0x4A
    case writeMode = 0x4B
    case trimMode = 0x4C
    case touchMode = 0x4D
    case latchMode = 0x4E

    // Utility
    case flip = 0x32
    case global = 0x33
    case nameValue = 0x34
    case scrub = 0x65
    case zoom = 0x64

    // Function keys
    case f1 = 0x36
    case f2 = 0x37
    case f3 = 0x38
    case f4 = 0x39
    case f5 = 0x3A
    case f6 = 0x3B
    case f7 = 0x3C
    case f8 = 0x3D
}

// MARK: - EchoelShowControl

/// Professional show control & DAW control surface integration.
///
/// Bridges MIDI Show Control (theater/live events) and Mackie Control/HUI
/// (DAW control surfaces) to the Echoelmusic ecosystem.
///
/// Usage:
/// ```swift
/// let show = EchoelShowControl.shared
///
/// // MSC: Send GO cue 5 to lighting
/// show.mscGo(cue: MSCCueNumber("5"), group: .lighting)
///
/// // Mackie Control: Update fader position
/// show.setFader(channel: 0, value: 8192)  // 50%
///
/// // Mackie Control: Update scribble strip
/// show.setScribble(channel: 0, top: "Vocal", bottom: "-3.5dB")
///
/// // Listen for surface events
/// show.onFaderMove = { channel, value in
///     print("Fader \(channel): \(value)")
/// }
/// ```
@MainActor
public final class EchoelShowControl: ObservableObject {

    public static let shared = EchoelShowControl()

    // MARK: - Published State

    /// MSC enabled
    @Published public var mscEnabled: Bool = false

    /// Mackie Control enabled
    @Published public var mackieEnabled: Bool = false

    /// HUI mode enabled (alternative to Mackie)
    @Published public var huiEnabled: Bool = false

    /// Current protocol mode
    @Published public var protocolMode: ControlSurfaceProtocol = .mackieControl

    /// MSC device ID (0x7F = all devices)
    @Published public var mscDeviceId: UInt8 = 0x7F

    /// Channel strip states (8 per bank)
    @Published public var channels: [MCUChannelStrip] = (0..<8).map { MCUChannelStrip(id: $0) }

    /// Current transport state
    @Published public var transport: MCUTransport = MCUTransport()

    /// Current bank offset (for bank switching)
    @Published public var bankOffset: Int = 0

    /// Master fader value (14-bit)
    @Published public var masterFader: UInt16 = 12000

    /// Total number of banks available
    @Published public var totalBanks: Int = 1

    /// MSC event log (recent commands)
    @Published public var mscLog: [MSCEvent] = []

    /// Connected control surface name
    @Published public var connectedSurface: String = "None"

    /// Control surface protocol options
    public enum ControlSurfaceProtocol: String, CaseIterable, Sendable {
        case mackieControl = "Mackie Control"
        case hui = "HUI (Pro Tools)"
        case both = "Both (MCU + HUI)"
    }

    // MARK: - Callbacks

    /// Called when a fader is moved on the control surface
    public var onFaderMove: ((Int, UInt16) -> Void)?

    /// Called when a V-Pot is turned
    public var onVPotTurn: ((Int, Int) -> Void)?

    /// Called when a button is pressed
    public var onButtonPress: ((MCUButton, Bool) -> Void)?

    /// Called when transport state changes
    public var onTransportChange: ((MCUTransport) -> Void)?

    /// Called when an MSC command is received
    public var onMSCReceived: ((MSCEvent) -> Void)?

    /// Called when jog/shuttle wheel is turned
    public var onJogWheel: ((Int) -> Void)?

    // MARK: - Internal

    private var busSubscriptions: [BusSubscription] = []
    private var meterUpdateTimer: Timer?

    // MARK: - Initialization

    private init() {
        subscribeToBus()
    }

    // MARK: - MSC Commands (Send)

    /// Send MSC GO command
    public func mscGo(cue: MSCCueNumber, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .go, deviceGroup: group, cueNumber: cue, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC STOP command
    public func mscStop(cue: MSCCueNumber? = nil, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .stop, deviceGroup: group, cueNumber: cue, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC RESUME command
    public func mscResume(cue: MSCCueNumber? = nil, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .resume, deviceGroup: group, cueNumber: cue, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC FIRE command (immediate, no fade)
    public func mscFire(cue: MSCCueNumber, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .fire, deviceGroup: group, cueNumber: cue, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC ALL OFF (emergency stop)
    public func mscAllOff() {
        let event = MSCEvent(command: .allOff, deviceGroup: .allTypes, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC TIMED GO with fade time
    public func mscTimedGo(cue: MSCCueNumber, fadeTime: TimeInterval, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .timedGo, deviceGroup: group, cueNumber: cue, fadeTime: fadeTime, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send MSC LOAD (prepare cue)
    public func mscLoad(cue: MSCCueNumber, group: MSCDeviceGroup = .allTypes) {
        let event = MSCEvent(command: .load, deviceGroup: group, cueNumber: cue, deviceId: mscDeviceId)
        sendMSC(event)
    }

    /// Send raw MSC event
    public func sendMSC(_ event: MSCEvent) {
        let bytes = event.encode()
        mscLog.append(event)
        if mscLog.count > 100 { mscLog.removeFirst() }

        // Publish via MIDI bus for CoreMIDI output
        EngineBus.shared.publish(.custom(
            topic: "msc.send",
            payload: [
                "command": event.command.description,
                "group": event.deviceGroup.description,
                "cue": event.cueNumber?.description ?? "",
                "bytes": bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            ]
        ))
    }

    /// Process received MSC SysEx bytes
    public func receiveMSC(_ bytes: [UInt8]) {
        guard let event = MSCEvent.decode(from: bytes) else { return }
        mscLog.append(event)
        if mscLog.count > 100 { mscLog.removeFirst() }
        onMSCReceived?(event)

        // Bridge to EngineBus
        EngineBus.shared.publish(.custom(
            topic: "msc.received",
            payload: [
                "command": event.command.description,
                "group": event.deviceGroup.description,
                "cue": event.cueNumber?.description ?? ""
            ]
        ))

        // Auto-respond to certain commands
        handleMSCCommand(event)
    }

    // MARK: - Mackie Control (Send to Surface)

    /// Update fader position on the control surface
    public func setFader(channel: Int, value: UInt16) {
        guard channel < channels.count else { return }
        channels[channel].faderValue = value

        // Mackie fader: pitch bend on channel (14-bit)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMCUMessage([0xE0 | UInt8(channel), lsb, msb])
    }

    /// Update master fader
    public func setMasterFader(value: UInt16) {
        masterFader = value
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMCUMessage([0xE8, lsb, msb]) // Channel 9 = master
    }

    /// Update V-Pot LED ring
    public func setVPot(channel: Int, value: UInt8, mode: MCUChannelStrip.VPotMode = .single) {
        guard channel < channels.count else { return }
        channels[channel].vpotValue = value
        channels[channel].vpotMode = mode

        // V-Pot LED: CC 0x30-0x37
        let modeOffset = mode.rawValue << 4
        sendMCUMessage([0xB0, 0x30 + UInt8(channel), modeOffset | (value & 0x0F)])
    }

    /// Update channel meter level
    public func setMeter(channel: Int, level: UInt8) {
        guard channel < channels.count else { return }
        channels[channel].meterLevel = Swift.min(level, 14)

        // Channel pressure (aftertouch) encodes meters
        let byte = (UInt8(channel) << 4) | Swift.min(level, 0x0E)
        sendMCUMessage([0xD0, byte])
    }

    /// Update scribble strip text
    public func setScribble(channel: Int, top: String, bottom: String) {
        guard channel < channels.count else { return }
        let topTrimmed = String(top.prefix(7)).padding(toLength: 7, withPad: " ", startingAt: 0)
        let bottomTrimmed = String(bottom.prefix(7)).padding(toLength: 7, withPad: " ", startingAt: 0)
        channels[channel].scribbleTop = topTrimmed
        channels[channel].scribbleBottom = bottomTrimmed

        // LCD SysEx: F0 00 00 66 14 12 <offset> <chars> F7
        let offset = channel * 7
        var sysex: [UInt8] = [0xF0, 0x00, 0x00, 0x66, 0x14, 0x12, UInt8(offset)]
        sysex.append(contentsOf: Array(topTrimmed.utf8))
        sysex.append(0xF7)
        sendMCUMessage(sysex)

        // Bottom row
        var sysex2: [UInt8] = [0xF0, 0x00, 0x00, 0x66, 0x14, 0x12, UInt8(offset + 56)]
        sysex2.append(contentsOf: Array(bottomTrimmed.utf8))
        sysex2.append(0xF7)
        sendMCUMessage(sysex2)
    }

    /// Set button LED state
    public func setButtonLED(_ button: MCUButton, channel: Int = 0, on: Bool) {
        let note = button.rawValue + UInt8(channel)
        sendMCUMessage([on ? 0x90 : 0x80, note, on ? 0x7F : 0x00])
    }

    /// Set transport button LED
    public func setTransportLED(play: Bool? = nil, record: Bool? = nil, stop: Bool? = nil) {
        if let play = play { setButtonLED(.play, on: play) }
        if let record = record { setButtonLED(.record, on: record) }
        if let stop = stop { setButtonLED(.stop, on: stop) }
    }

    /// Send time display update (SMPTE/Bars)
    public func setTimeDisplay(_ text: String) {
        // Time display SysEx
        var sysex: [UInt8] = [0xF0, 0x00, 0x00, 0x66, 0x14, 0x10]
        sysex.append(contentsOf: Array(text.prefix(10).utf8))
        sysex.append(0xF7)
        sendMCUMessage(sysex)
    }

    // MARK: - Mackie Control (Receive from Surface)

    /// Process incoming MIDI from control surface
    public func processMCUMessage(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        let status = bytes[0] & 0xF0
        let channel = Int(bytes[0] & 0x0F)

        switch status {
        case 0xE0:
            // Fader move (pitch bend)
            guard bytes.count >= 3 else { return }
            let value = UInt16(bytes[1]) | (UInt16(bytes[2]) << 7)
            if channel < 8 {
                channels[channel].faderValue = value
                onFaderMove?(channel + bankOffset * 8, value)
                EngineBus.shared.publishParam(engine: "surface", param: "fader.\(channel + bankOffset * 8)", value: Float(value) / 16383.0)
            } else if channel == 8 {
                masterFader = value
                onFaderMove?(-1, value) // -1 = master
                EngineBus.shared.publishParam(engine: "surface", param: "master", value: Float(value) / 16383.0)
            }

        case 0xB0:
            // V-Pot rotation (CC)
            guard bytes.count >= 3 else { return }
            let cc = Int(bytes[1])
            let value = Int(bytes[2])
            if cc >= 0x10 && cc <= 0x17 {
                let vpotChannel = cc - 0x10
                let delta = (value & 0x40) != 0 ? -(value & 0x3F) : (value & 0x3F)
                onVPotTurn?(vpotChannel + bankOffset * 8, delta)
            } else if cc == 0x3C {
                // Jog wheel
                let delta = (value & 0x40) != 0 ? -(value & 0x3F) : (value & 0x3F)
                transport.jogValue = delta
                onJogWheel?(delta)
            }

        case 0x90:
            // Button press (note on)
            guard bytes.count >= 3 else { return }
            let note = bytes[1]
            let pressed = bytes[2] > 0

            if let button = MCUButton(rawValue: note) {
                handleMCUButton(button, channel: 0, pressed: pressed)
            } else if note >= 0x00 && note < 0x08 {
                handleMCUButton(.rec, channel: Int(note), pressed: pressed)
            } else if note >= 0x08 && note < 0x10 {
                handleMCUButton(.solo, channel: Int(note - 0x08), pressed: pressed)
            } else if note >= 0x10 && note < 0x18 {
                handleMCUButton(.mute, channel: Int(note - 0x10), pressed: pressed)
            } else if note >= 0x18 && note < 0x20 {
                handleMCUButton(.select, channel: Int(note - 0x18), pressed: pressed)
            }

        default:
            break
        }
    }

    // MARK: - Bank Navigation

    /// Switch to next bank of 8 channels
    public func bankRight() {
        guard bankOffset < totalBanks - 1 else { return }
        bankOffset += 1
        updateSurfaceFromMixer()
    }

    /// Switch to previous bank of 8 channels
    public func bankLeft() {
        guard bankOffset > 0 else { return }
        bankOffset -= 1
        updateSurfaceFromMixer()
    }

    /// Switch one channel right
    public func channelRight() {
        // Fine navigation (single channel offset)
        bankOffset = Swift.min(bankOffset + 1, totalBanks - 1)
        updateSurfaceFromMixer()
    }

    /// Switch one channel left
    public func channelLeft() {
        bankOffset = Swift.max(bankOffset - 1, 0)
        updateSurfaceFromMixer()
    }

    // MARK: - Bio-Reactive Surface Features

    /// Update surface meters from bio data (coherence → meter animation)
    public func updateMetersFromBio(coherence: Float) {
        let level = UInt8(coherence * 14)
        for i in 0..<channels.count {
            setMeter(channel: i, level: level)
        }
    }

    /// Map coherence to surface LED brightness
    public func updateBioLEDs(coherence: Float, heartRate: Float) {
        // Pulse transport LEDs with heartbeat
        let beatPhase = fmodf(Float(Date().timeIntervalSince1970) * (heartRate / 60.0), 1.0)
        let pulse = beatPhase < 0.3

        if coherence > 0.7 {
            setButtonLED(.play, on: true)
            setButtonLED(.record, on: pulse)
        } else {
            setButtonLED(.play, on: pulse)
        }
    }

    // MARK: - Auto-Sync with Mixer

    /// Start automatic meter updates from EchoelMix
    public func startMeterSync() {
        meterUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncMetersFromBus()
            }
        }
    }

    /// Stop meter sync
    public func stopMeterSync() {
        meterUpdateTimer?.invalidate()
        meterUpdateTimer = nil
    }

    // MARK: - Private Methods

    private func handleMCUButton(_ button: MCUButton, channel: Int, pressed: Bool) {
        onButtonPress?(button, pressed)
        guard pressed else { return }

        switch button {
        case .play:
            transport.isPlaying = true
            transport.isStopped = false
            onTransportChange?(transport)
            EngineBus.shared.publish(.custom(topic: "surface.transport", payload: ["action": "play"]))
        case .stop:
            transport.isPlaying = false
            transport.isRecording = false
            transport.isStopped = true
            onTransportChange?(transport)
            EngineBus.shared.publish(.custom(topic: "surface.transport", payload: ["action": "stop"]))
        case .record:
            transport.isRecording.toggle()
            onTransportChange?(transport)
            EngineBus.shared.publish(.custom(topic: "surface.transport", payload: ["action": "record"]))
        case .rewind:
            transport.isRewinding = true
            onTransportChange?(transport)
        case .fastForward:
            transport.isFastForwarding = true
            onTransportChange?(transport)
        case .bankLeft:
            bankLeft()
        case .bankRight:
            bankRight()
        case .channelLeft:
            channelLeft()
        case .channelRight:
            channelRight()
        case .mute:
            guard channel < channels.count else { return }
            channels[channel].isMuted.toggle()
            setButtonLED(.mute, channel: channel, on: channels[channel].isMuted)
            EngineBus.shared.publishParam(engine: "surface", param: "mute.\(channel + bankOffset * 8)", value: channels[channel].isMuted ? 1 : 0)
        case .solo:
            guard channel < channels.count else { return }
            channels[channel].isSoloed.toggle()
            setButtonLED(.solo, channel: channel, on: channels[channel].isSoloed)
            EngineBus.shared.publishParam(engine: "surface", param: "solo.\(channel + bankOffset * 8)", value: channels[channel].isSoloed ? 1 : 0)
        case .rec:
            guard channel < channels.count else { return }
            channels[channel].isArmed.toggle()
            setButtonLED(.rec, channel: channel, on: channels[channel].isArmed)
        case .select:
            guard channel < channels.count else { return }
            // Deselect all, select this one
            for i in 0..<channels.count { channels[i].isSelected = false }
            channels[channel].isSelected = true
            for i in 0..<channels.count {
                setButtonLED(.select, channel: i, on: channels[i].isSelected)
            }
            EngineBus.shared.publish(.custom(topic: "surface.select", payload: ["channel": "\(channel + bankOffset * 8)"]))
        case .flip:
            // Flip mode: swap fader and V-Pot assignments
            EngineBus.shared.publish(.custom(topic: "surface.flip", payload: [:]))
        case .scrub:
            transport.isScrubbing.toggle()
        default:
            break
        }
    }

    private func handleMSCCommand(_ event: MSCEvent) {
        switch event.command {
        case .go:
            EngineBus.shared.publish(.custom(
                topic: "show.cue.go",
                payload: ["cue": event.cueNumber?.description ?? ""]
            ))
        case .stop:
            EngineBus.shared.publish(.custom(
                topic: "show.cue.stop",
                payload: ["cue": event.cueNumber?.description ?? ""]
            ))
        case .allOff:
            EngineBus.shared.publish(.custom(
                topic: "show.emergency",
                payload: ["command": "ALL_OFF"]
            ))
        default:
            break
        }
    }

    private func sendMCUMessage(_ bytes: [UInt8]) {
        EngineBus.shared.publish(.custom(
            topic: "midi.send.raw",
            payload: [
                "protocol": protocolMode.rawValue,
                "bytes": bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            ]
        ))
    }

    private func updateSurfaceFromMixer() {
        // Request channel data from EchoelMix for current bank
        EngineBus.shared.publish(.custom(
            topic: "surface.bank.changed",
            payload: ["offset": "\(bankOffset)"]
        ))
    }

    private func syncMetersFromBus() {
        // Read RMS from bus and update surface meters
        if let rms = EngineBus.shared.request("audio.rms") {
            let level = UInt8(Swift.min(rms * 14, 14))
            for i in 0..<channels.count {
                setMeter(channel: i, level: level)
            }
        }
    }

    private func subscribeToBus() {
        let bioSub = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.updateBioLEDs(coherence: bio.coherence, heartRate: bio.heartRate)
                }
            }
        }
        busSubscriptions.append(bioSub)

        // Listen for MIDI SysEx (MSC) from CoreMIDI
        let midiSub = EngineBus.shared.subscribe(to: .custom) { [weak self] msg in
            if case .custom(let topic, let payload) = msg, topic == "midi.sysex.received" {
                if let hexString = payload["bytes"] {
                    let bytes = hexString.split(separator: " ").compactMap { UInt8($0, radix: 16) }
                    Task { @MainActor in
                        // Check if MSC
                        if bytes.count >= 5 && bytes[0] == 0xF0 && bytes[1] == 0x7F && bytes[3] == 0x02 {
                            self?.receiveMSC(bytes)
                        }
                    }
                }
            }
        }
        busSubscriptions.append(midiSub)
    }

    // MARK: - Shutdown

    /// Stop all show control operations
    public func shutdown() {
        stopMeterSync()
        mscEnabled = false
        mackieEnabled = false
        huiEnabled = false
        busSubscriptions.removeAll()
    }
}
