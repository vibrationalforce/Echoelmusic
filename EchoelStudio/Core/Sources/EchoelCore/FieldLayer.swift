import Foundation

/// The Field as a layer over a video (wave W15): how its light mixes with the picture under it and
/// how much of it shows. One formula for every place that draws the layer — the video export's
/// compositor and the video window's preview hand `coefficients` to the same GPU pass, which
/// evaluates exactly `mix(video:field:)` — so the window shows what the file will hold.
///
/// Each channel is light, 0 (none) … 1 (full). With the picture `v`, the Field `f` and the
/// opacity `a`:
/// - Screen: `v + a·f·(1 − v)` — the Field lightens the picture and never darkens it.
/// - Add: `v + a·f`, clipped at full light — brighter, burning out where both are bright.
/// - Normal: `v·(1 − a) + a·f` — the Field over the picture, which shows through by `1 − a`.
///
/// All three are one bilinear form, `v·video + f·field + v·f·product` clipped to 0 … 1 — the form
/// the shader evaluates, so it holds no blend of its own. Off, or an opacity of 0, leaves the
/// picture exactly as it is. Pure and deterministic: the same pixels give the same pixel.
///
/// A device setting, never stored in the song (no format field): an export option the video window
/// shows too. Whatever reaches it is checked here, at the boundary — an opacity that is not a
/// finite number is 0, one outside 0 … 1 is clamped; a channel that is not a finite number is no
/// light.
public struct FieldLayer: Hashable, Sendable {
    public enum Blend: String, CaseIterable, Sendable {
        case off, screen, add, normal

        public var title: String {
            switch self {
            case .off: "Off"
            case .screen: "Screen"
            case .add: "Add"
            case .normal: "Normal"
            }
        }
    }

    /// The factors of the one formula: `v·video + f·field + v·f·product`, clipped to 0 … 1.
    public struct Coefficients: Hashable, Sendable {
        public let video: Double
        public let field: Double
        public let product: Double

        public init(video: Double, field: Double, product: Double) {
            self.video = video
            self.field = field
            self.product = product
        }
    }

    public let blend: Blend
    /// How much of the Field shows, 0 … 1.
    public let opacity: Double

    /// Where a new layer starts: enough to read the Field, not enough to hide the performer.
    public static let standardOpacity = 0.6

    public init(blend: Blend = .off, opacity: Double = FieldLayer.standardOpacity) {
        self.blend = blend
        self.opacity = opacity.isFinite ? Swift.min(1, Swift.max(0, opacity)) : 0
    }

    /// The opacity as a whole percent, 0 … 100, the way the export sheet shows it.
    public var opacityPercent: Int { Int((opacity * 100).rounded()) }

    /// Whether the layer draws anything at all.
    public var isVisible: Bool { blend != .off && opacity > 0 }

    public var coefficients: Coefficients {
        let a = isVisible ? opacity : 0
        switch blend {
        case .off: return Coefficients(video: 1, field: 0, product: 0)
        case .screen: return Coefficients(video: 1, field: a, product: -a)
        case .add: return Coefficients(video: 1, field: a, product: 0)
        case .normal: return Coefficients(video: 1 - a, field: a, product: 0)
        }
    }

    /// One channel of the Field over the same channel of the picture.
    public func mix(video: Double, field: Double) -> Double {
        let v = Self.light(video)
        let f = Self.light(field)
        let k = coefficients
        return Swift.min(1, Swift.max(0, v * k.video + f * k.field + v * f * k.product))
    }

    private static func light(_ value: Double) -> Double {
        value.isFinite ? Swift.min(1, Swift.max(0, value)) : 0
    }
}
