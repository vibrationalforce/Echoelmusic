import Foundation

/// Corner pin for a projector (keystone correction, wave REC-1): each corner of the picture moves
/// toward the middle until the projected image is a true rectangle on the wall. The earlier app
/// kept the same four corner offsets (`ProjectionWarp` in `EchoelStageEngine`, 2026-03) but drew
/// them as an average tilt, which moves no corner to where it was set; this ports the setting and
/// replaces the drawing with the real projective map, so every corner lands exactly on its point.
///
/// A device setting (the projector and the wall belong to the room, not to the song): it is never
/// written into a song file. Pure: the app turns `layerMatrix` into a `CATransform3D`.
public struct CornerPin: Equatable, Codable, Sendable {
    /// One corner's move toward the middle, as fractions of the picture's width and height.
    public struct Inset: Equatable, Codable, Sendable {
        public var horizontal: Double
        public var vertical: Double

        public init(horizontal: Double = 0, vertical: Double = 0) {
            self.horizontal = CornerPin.clamped(horizontal)
            self.vertical = CornerPin.clamped(vertical)
        }

        public static let zero = Inset()

        private enum Keys: String, CodingKey { case horizontal, vertical }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            self.init(horizontal: try container.decodeIfPresent(Double.self, forKey: .horizontal) ?? 0,
                      vertical: try container.decodeIfPresent(Double.self, forKey: .vertical) ?? 0)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            try container.encode(horizontal, forKey: .horizontal)
            try container.encode(vertical, forKey: .vertical)
        }
    }

    public enum Corner: String, CaseIterable, Sendable {
        case topLeft, topRight, bottomRight, bottomLeft

        public var title: String {
            switch self {
            case .topLeft: "Top Left"
            case .topRight: "Top Right"
            case .bottomRight: "Bottom Right"
            case .bottomLeft: "Bottom Left"
            }
        }
    }

    /// How far a corner may move: under half, so each corner stays in its own quarter of the
    /// picture and the four can never cross.
    public static let maximumInset = 0.3

    public var topLeft: Inset
    public var topRight: Inset
    public var bottomRight: Inset
    public var bottomLeft: Inset

    public init(topLeft: Inset = .zero, topRight: Inset = .zero, bottomRight: Inset = .zero,
                bottomLeft: Inset = .zero) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public static let none = CornerPin()

    public var isIdentity: Bool { self == .none }

    public subscript(corner: Corner) -> Inset {
        get {
            switch corner {
            case .topLeft: topLeft
            case .topRight: topRight
            case .bottomRight: bottomRight
            case .bottomLeft: bottomLeft
            }
        }
        set {
            switch corner {
            case .topLeft: topLeft = newValue
            case .topRight: topRight = newValue
            case .bottomRight: bottomRight = newValue
            case .bottomLeft: bottomLeft = newValue
            }
        }
    }

    /// A stored or typed fraction, made safe: not a number is no move, and a move past the
    /// maximum stops at it.
    static func clamped(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0 }
        return Swift.min(Swift.max(fraction, 0), maximumInset)
    }

    // A decoded setting passes the same clamp as a typed one: a hand-edited or damaged file
    // cannot fold the picture.
    private enum Keys: String, CodingKey { case topLeft, topRight, bottomRight, bottomLeft }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        topLeft = try container.decodeIfPresent(Inset.self, forKey: .topLeft) ?? .zero
        topRight = try container.decodeIfPresent(Inset.self, forKey: .topRight) ?? .zero
        bottomRight = try container.decodeIfPresent(Inset.self, forKey: .bottomRight) ?? .zero
        bottomLeft = try container.decodeIfPresent(Inset.self, forKey: .bottomLeft) ?? .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(topLeft, forKey: .topLeft)
        try container.encode(topRight, forKey: .topRight)
        try container.encode(bottomRight, forKey: .bottomRight)
        try container.encode(bottomLeft, forKey: .bottomLeft)
    }

    /// Where each corner of a `width` × `height` picture lands, in its own points (y down),
    /// in the order top left, top right, bottom right, bottom left.
    public func corners(width: Double, height: Double) -> [Point] {
        [Point(x: topLeft.horizontal * width, y: topLeft.vertical * height),
         Point(x: width - topRight.horizontal * width, y: topRight.vertical * height),
         Point(x: width - bottomRight.horizontal * width, y: height - bottomRight.vertical * height),
         Point(x: bottomLeft.horizontal * width, y: height - bottomLeft.vertical * height)]
    }

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// The projective map from the unit square to a quadrilateral:
    /// x' = (a u + b v + c) / (g u + h v + 1), y' = (d u + e v + f) / (g u + h v + 1).
    public struct Projection: Equatable, Sendable {
        public let a, b, c, d, e, f, g, h: Double

        public func map(u: Double, v: Double) -> Point? {
            let w = g * u + h * v + 1
            guard w.isFinite, Swift.abs(w) > 1e-12 else { return nil }
            return Point(x: (a * u + b * v + c) / w, y: (d * u + e * v + f) / w)
        }
    }

    /// The map that sends the unit square's corners (0,0), (1,0), (1,1), (0,1) to `quad`, in that
    /// order (Heckbert's square-to-quad). Nil for a quadrilateral that is not strictly convex or
    /// not finite: such a map would fold or tear the picture.
    public static func projection(toQuad quad: [Point]) -> Projection? {
        guard quad.count == 4, quad.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), isConvex(quad) else { return nil }
        let (x0, y0) = (quad[0].x, quad[0].y)
        let (x1, y1) = (quad[1].x, quad[1].y)
        let (x2, y2) = (quad[2].x, quad[2].y)
        let (x3, y3) = (quad[3].x, quad[3].y)
        let sx = x0 - x1 + x2 - x3
        let sy = y0 - y1 + y2 - y3
        var g = 0.0
        var h = 0.0
        if sx != 0 || sy != 0 {
            let dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2
            let determinant = dx1 * dy2 - dx2 * dy1
            guard determinant.isFinite, Swift.abs(determinant) > 1e-12 else { return nil }
            g = (sx * dy2 - dx2 * sy) / determinant
            h = (dx1 * sy - sx * dy1) / determinant
        }
        let projection = Projection(a: x1 - x0 + g * x1, b: x3 - x0 + h * x3, c: x0,
                                    d: y1 - y0 + g * y1, e: y3 - y0 + h * y3, f: y0, g: g, h: h)
        let numbers = [projection.a, projection.b, projection.c, projection.d, projection.e, projection.f,
                       projection.g, projection.h]
        return numbers.allSatisfy(\.isFinite) ? projection : nil
    }

    /// Whether the four points, in order, turn the same way at every corner.
    static func isConvex(_ quad: [Point]) -> Bool {
        guard quad.count == 4 else { return false }
        var sign = 0.0
        for index in 0..<4 {
            let p = quad[index], q = quad[(index + 1) % 4], r = quad[(index + 2) % 4]
            let cross = (q.x - p.x) * (r.y - q.y) - (q.y - p.y) * (r.x - q.x)
            guard cross.isFinite, Swift.abs(cross) > 1e-12 else { return false }
            if sign == 0 {
                sign = cross
            } else if (cross > 0) != (sign > 0) {
                return false
            }
        }
        return true
    }

    /// The pinned picture as a layer transform for a `width` × `height` layer whose anchor is its
    /// top-left corner: sixteen numbers in `CATransform3D` order (m11, m12, m13, m14, m21 …
    /// m44), where a point is the row vector (x, y, 0, 1) times the matrix. The identity when no
    /// corner moved, the size is not positive, or the corners would fold.
    public func layerMatrix(width: Double, height: Double) -> [Double] {
        let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        guard !isIdentity, width.isFinite, height.isFinite, width > 0, height > 0,
              let p = Self.projection(toQuad: corners(width: width, height: height)) else { return identity }
        // The unit square is the layer scaled down: u = x / width, v = y / height.
        return [p.a / width, p.d / width, 0, p.g / width,
                p.b / height, p.e / height, 0, p.h / height,
                0, 0, 1, 0,
                p.c, p.f, 0, 1]
    }

    /// Where the layer point (x, y) lands under `layerMatrix` — what the compositor will draw.
    public static func apply(_ matrix: [Double], x: Double, y: Double) -> Point? {
        guard matrix.count == 16 else { return nil }
        let w = x * matrix[3] + y * matrix[7] + matrix[15]
        guard w.isFinite, Swift.abs(w) > 1e-12 else { return nil }
        return Point(x: (x * matrix[0] + y * matrix[4] + matrix[12]) / w,
                     y: (x * matrix[1] + y * matrix[5] + matrix[13]) / w)
    }
}
