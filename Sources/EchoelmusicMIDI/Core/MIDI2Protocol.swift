import Foundation

/// MIDI 2.0 protocol definition
/// Skeleton for MIDI 2.0 Universal MIDI Packet (UMP) support
public protocol MIDI2Protocol {

    /// Send MIDI 2.0 message
    /// - Parameter message: MIDI 2.0 message
    func send(_ message: MIDI2Message) throws

    /// Register handler for incoming MIDI messages
    /// - Parameter handler: Closure to handle messages
    func onReceive(handler: @escaping (MIDI2Message) -> Void)
}

/// MIDI 2.0 message types
public enum MIDI2Message: Sendable {

    /// Note on with 32-bit velocity
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt32, attributeType: UInt8, attributeData: UInt16)

    /// Note off
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt32, attributeType: UInt8, attributeData: UInt16)

    /// Per-note pitch bend
    case perNotePitchBend(channel: UInt8, note: UInt8, data: UInt32)

    /// Per-note controller
    case perNoteController(channel: UInt8, note: UInt8, controller: UInt8, data: UInt32)

    /// Control change
    case controlChange(channel: UInt8, controller: UInt8, value: UInt32)
}

/// MIDI 2.0 capabilities
public struct MIDI2Capabilities: Sendable {

    /// Supports MIDI 2.0 protocol
    public let supportsMIDI2: Bool

    /// Maximum simultaneous voices
    public let maxVoices: Int

    /// Supports per-note controllers
    public let supportsPerNoteControllers: Bool

    /// Supports MPE
    public let supportsMPE: Bool

    public init(
        supportsMIDI2: Bool = true,
        maxVoices: Int = 16,
        supportsPerNoteControllers: Bool = true,
        supportsMPE: Bool = true
    ) {
        self.supportsMIDI2 = supportsMIDI2
        self.maxVoices = maxVoices
        self.supportsPerNoteControllers = supportsPerNoteControllers
        self.supportsMPE = supportsMPE
    }
}
