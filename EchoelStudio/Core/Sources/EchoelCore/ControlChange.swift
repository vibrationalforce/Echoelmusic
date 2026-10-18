/// A pitch bend or a controller value inside a MIDI clip: what a keyboard's wheel, pedal and
/// knobs played, kept next to the notes and played back on the clip's track.
///
/// A change holds its value until the next one of the same kind. Where a placement ends, the
/// plan returns the wheel to centre and lifts the sustain pedal if the clip moved them, so a
/// bent or held clip never leaves the next one bent or held.
public struct ControlChange: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: Codable, Hashable, Sendable {
        /// 14-bit, 0…16383, centre 8192.
        case pitchBend
        /// A controller 0…119, value 0…127. 120…127 are channel-mode messages, not controllers.
        case controller(number: Int)
    }

    public var id: ControlID
    public var kind: Kind
    /// Ticks from the clip start.
    public var start: Tick
    public var value: Int

    public init(id: ControlID = ControlID(), kind: Kind, start: Tick, value: Int) {
        self.id = id
        self.kind = kind
        self.start = start
        self.value = value
    }

    public static let bendRange: ClosedRange<Int> = 0...16383
    public static let bendCentre = 8192
    public static let controllerNumbers: ClosedRange<Int> = 0...119
    public static let controllerValues: ClosedRange<Int> = 0...127
    public static let sustainPedal = 64

    /// Whether the kind and value are ones a MIDI channel can carry.
    public var isValid: Bool {
        switch kind {
        case .pitchBend: Self.bendRange.contains(value)
        case .controller(let number): Self.controllerNumbers.contains(number) && Self.controllerValues.contains(value)
        }
    }

    /// The value a placement's end returns this kind to, or nil when a controller has no rest:
    /// a volume or a filter knob stays where the music left it.
    var rest: Int? {
        switch kind {
        case .pitchBend: Self.bendCentre
        case .controller(let number): number == Self.sustainPedal ? 0 : nil
        }
    }
}
