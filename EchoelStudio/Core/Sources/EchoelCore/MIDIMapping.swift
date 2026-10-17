/// A knob, fader or button on a MIDI controller: one controller number on one channel.
public struct MIDIControl: Codable, Hashable, Sendable, CustomStringConvertible {
    /// 0…15 (shown as 1…16).
    public var channel: UInt8
    /// Controller number 0…127.
    public var number: UInt8

    public init(channel: UInt8, number: UInt8) {
        self.channel = channel
        self.number = number
    }

    public var isValid: Bool { channel < 16 && number < 128 }

    public var description: String { "CC \(number) · Ch \(Int(channel) + 1)" }
}

/// A controller that moves a parameter: its 0…127 travel spans the parameter's whole range on
/// the parameter's own taper, the way a fader on screen does.
public struct MIDIMapping: Codable, Equatable, Sendable {
    public var control: MIDIControl
    public var target: ParameterAddress

    public init(control: MIDIControl, target: ParameterAddress) {
        self.control = control
        self.target = target
    }
}

extension ParameterAddress {
    /// The track this parameter belongs to or depends on, if any.
    func involves(_ track: TrackID) -> Bool {
        if case .track(let id) = self.owner, id == track { return true }
        return key.sendTarget == track
    }
}
