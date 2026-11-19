import Foundation

/// The white balance a video take is filmed at (Michael 2025-11-11: „5600 K und andere
/// Weißabgleich Sachen“): Auto, or one colour temperature held for the whole take, so a cut
/// between two takes under the same light does not shift in colour. The choices are the lamps a
/// set is lit with — tungsten 3200 K, warm white 4000 K, daylight 5600 K, overcast 6500 K, shade
/// 7500 K. The camera turns a temperature into its own channel gains; `clampedGains` keeps what
/// it hands over inside what the lens accepts.
public enum TakeWhiteBalance {
    /// The temperatures offered, coolest light last.
    public static let kelvins: [Int] = [3200, 4000, 5600, 6500, 7500]

    /// "Auto" for nil, else "5600 K".
    public static func label(_ kelvin: Int?) -> String {
        guard let kelvin else { return "Auto" }
        return "\(kelvin) K"
    }

    /// The three channel gains a camera is locked to.
    public struct Gains: Equatable, Sendable {
        public var red: Float
        public var green: Float
        public var blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// Each gain inside 1 … `maximum`, which a lens requires of locked gains; a gain that is not a
    /// number becomes 1 (no change on that channel), and a maximum below 1 or not a number is 1.
    public static func clampedGains(_ gains: Gains, maximum: Float) -> Gains {
        let top = maximum.isFinite && maximum > 1 ? maximum : 1
        func clamp(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 1), top) : 1 }
        return Gains(red: clamp(gains.red), green: clamp(gains.green), blue: clamp(gains.blue))
    }
}
