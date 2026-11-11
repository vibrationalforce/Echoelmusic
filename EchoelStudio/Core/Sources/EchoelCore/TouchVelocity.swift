import Foundation

/// How hard a key on the screen plays, from where on the key the finger lands: near the far end
/// softly, near the foot hard — the way a longer lever gives more force. Glass feels no pressure,
/// so the place of the touch is the one thing a phone knows about how a note was meant.
///
/// Pure, so the range is tested here. The middle of a key plays close to the fixed loudness every
/// screen key had before (100), so a musician who never thinks about it hears what they heard.
public enum TouchVelocity {
    /// The softest a touch plays: clearly quieter than the middle, never silent.
    public static let softest: UInt8 = 60
    /// The hardest a touch plays: MIDI's full velocity.
    public static let hardest: UInt8 = 127
    /// What a touch plays when its place is not known (VoiceOver's activate, a key with no height):
    /// the loudness every screen key had before.
    public static let unplaced: UInt8 = 100

    /// The velocity of a touch at `position` along the key: 0 at its far end, 1 at its foot.
    /// A place outside the key counts as its nearer end; a place that is no number is `unplaced`.
    public static func velocity(at position: Double) -> UInt8 {
        guard position.isFinite else { return unplaced }
        let along = Swift.min(1, Swift.max(0, position))
        let span = Double(hardest) - Double(softest)
        let value = (Double(softest) + span * along).rounded()
        return UInt8(Swift.min(Double(hardest), Swift.max(Double(softest), value)))
    }

    /// The velocity of a touch `offset` points down a key `length` points long. A key without a
    /// length gives no place.
    public static func velocity(offset: Double, length: Double) -> UInt8 {
        guard offset.isFinite, length.isFinite, length > 0 else { return unplaced }
        return velocity(at: offset / length)
    }
}
