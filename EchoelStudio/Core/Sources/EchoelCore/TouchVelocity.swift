import Foundation

/// How hard a key on the screen plays, from where on the key the finger lands: near the far end
/// softly, near the foot hard — the way a longer lever gives more force. Glass feels no pressure,
/// so the place of the touch is the one thing a phone knows about how a note was meant.
///
/// Pure, so the range is tested here. The middle of a key plays exactly the loudness every screen
/// key had before (100), so a tap in the middle sounds as it always did — a synth patch's Accent,
/// which starts at 100, included. The upper half plays softer, down to 60; the lower half harder,
/// up to 127.
public enum TouchVelocity {
    /// The softest a touch plays, at the key's far end: clearly quieter, never silent.
    public static let softest: UInt8 = 60
    /// What the middle of a key plays: the loudness every screen key had before.
    public static let middle: UInt8 = 100
    /// The hardest a touch plays, at the key's foot: MIDI's full velocity.
    public static let hardest: UInt8 = 127
    /// What a touch plays when its place is not known (VoiceOver's activate, a key with no
    /// length): the middle's loudness.
    public static let unplaced: UInt8 = middle

    /// The velocity of a touch at `position` along the key: 0 at its far end, 1 at its foot, in a
    /// straight line from `softest` to `middle` over the upper half and from `middle` to `hardest`
    /// over the lower one. A place outside the key, an infinite one too, counts as its nearer end;
    /// a place that is not a number is `unplaced`.
    public static func velocity(at position: Double) -> UInt8 {
        guard !position.isNaN else { return unplaced }
        let along = Swift.min(1, Swift.max(0, position))
        let value: Double
        if along <= 0.5 {
            value = Double(softest) + (Double(middle) - Double(softest)) * along * 2
        } else {
            value = Double(middle) + (Double(hardest) - Double(middle)) * (along - 0.5) * 2
        }
        let rounded = value.rounded()
        return UInt8(Swift.min(Double(hardest), Swift.max(Double(softest), rounded)))
    }

    /// The velocity of a touch `offset` points down a key `length` points long. A key without a
    /// finite length above zero gives no place; an offset above the key's top counts as its top.
    public static func velocity(offset: Double, length: Double) -> UInt8 {
        guard !offset.isNaN, length.isFinite, length > 0 else { return unplaced }
        return velocity(at: offset / length)
    }
}
