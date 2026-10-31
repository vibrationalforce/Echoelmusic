import Foundation

/// One moment of the sky over one place, ready to draw and to ask "what is in the middle"
/// (sky source, founder 2026-10-31). Built from the star table, the Sun, Moon and planets, the
/// place and the time — never from a sensor, so it is complete in darkness and behind clouds.
/// Pure and cheap enough to rebuild every few seconds; the sky turns 0.25° a minute.
public struct SkyScene: Sendable {
    public struct Object: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable {
            case star(Int)
            case body(SkyBodies.Body)
        }

        /// "star.<HR>" or "body.<name>", stable across scenes.
        public let id: String
        public let kind: Kind
        public let name: String?
        /// Where it stands from the ground (the Moon corrected for parallax).
        public let position: Sky.Horizontal
        public let magnitude: Double
        /// B−V for a star; the Sun's 0.65 for the Sun, nil for the Moon and planets.
        public let colorIndex: Double?
        /// The same direction as a unit vector, east · north · up.
        public let vector: SkyVector
    }

    /// Objects lower than this are left out: below the horizon nothing can be pointed at, and a
    /// little margin keeps a rising star from popping in.
    public static let lowestAltitude = -5.0

    public let latitude: Double
    public let longitude: Double
    public let julianDay: Double
    /// Every star and body above `lowestAltitude`, stars first in catalogue order, then bodies.
    public let objects: [Object]

    /// Nil for a non-finite input or a latitude outside ±90.
    public init?(latitude: Double, longitude: Double, date: Date) {
        let jd = Sky.julianDay(date)
        guard latitude.isFinite, longitude.isFinite, jd.isFinite, abs(latitude) <= 90 else { return nil }
        self.latitude = latitude
        self.longitude = longitude
        julianDay = jd
        var found: [Object] = []
        found.reserveCapacity(StarCatalog.stars.count / 2 + SkyBodies.Body.allCases.count)
        for star in StarCatalog.stars {
            let ofDate = SkyBodies.precessed(rightAscension: star.rightAscension, declination: star.declination,
                                             toJulianDay: jd)
            guard let place = Sky.horizontal(rightAscension: ofDate.rightAscension, declination: ofDate.declination,
                                             latitude: latitude, longitude: longitude, julianDay: jd),
                  place.altitude >= Self.lowestAltitude else { continue }
            found.append(Object(id: "star.\(star.id)", kind: .star(star.id), name: star.name, position: place,
                                magnitude: star.magnitude, colorIndex: star.colorIndex, vector: SkyVector(place)))
        }
        for body in SkyBodies.Body.allCases {
            guard let ephemeris = SkyBodies.position(of: body, julianDay: jd),
                  let geocentric = Sky.horizontal(rightAscension: ephemeris.rightAscension, declination: ephemeris.declination,
                                                  latitude: latitude, longitude: longitude, julianDay: jd) else { continue }
            let altitude = SkyBodies.topocentricAltitude(geocentric.altitude, distance: ephemeris.distance)
            guard altitude >= Self.lowestAltitude else { continue }
            let place = Sky.Horizontal(altitude: altitude, azimuth: geocentric.azimuth)
            found.append(Object(id: "body.\(body.rawValue)", kind: .body(body), name: body.name, position: place,
                                magnitude: ephemeris.magnitude, colorIndex: body == .sun ? 0.65 : nil,
                                vector: SkyVector(place)))
        }
        objects = found
    }

    /// The object the view is centred on: of everything within `radius` degrees of `direction`,
    /// the one the eye would pick — each degree off-centre counts as `degreeCost` magnitudes, so
    /// a bright star a little aside wins over a faint one dead centre. Nil when nothing is near.
    public func centred(on direction: Sky.Horizontal, radius: Double = 4,
                        degreeCost: Double = 0.6) -> Object? {
        guard direction.altitude.isFinite, direction.azimuth.isFinite, radius > 0 else { return nil }
        let axis = SkyVector(direction)
        let minimumCosine = cos(radius * .pi / 180)
        var best: Object?
        var bestScore = Double.infinity
        for object in objects {
            let cosine = axis.dot(object.vector)
            guard cosine >= minimumCosine else { continue }
            let separation = acos(Swift.min(1, cosine)) * 180 / .pi
            let score = object.magnitude + separation * degreeCost
            if score < bestScore {
                bestScore = score
                best = object
            }
        }
        return best
    }
}

/// A direction in the sky as a unit vector: x east, y north, z up.
public struct SkyVector: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ place: Sky.Horizontal) {
        let altitude = place.altitude * .pi / 180, azimuth = place.azimuth * .pi / 180
        x = cos(altitude) * sin(azimuth)
        y = cos(altitude) * cos(azimuth)
        z = sin(altitude)
    }

    public func dot(_ other: SkyVector) -> Double { x * other.x + y * other.y + z * other.z }

    public func cross(_ other: SkyVector) -> SkyVector {
        SkyVector(x: y * other.z - z * other.y, y: z * other.x - x * other.z, z: x * other.y - y * other.x)
    }

    public var length: Double { (x * x + y * y + z * z).squareRoot() }

    /// The vector scaled to length 1, or nil for a zero or non-finite one.
    public var normalized: SkyVector? {
        let l = length
        guard l.isFinite, l > 1e-12 else { return nil }
        return SkyVector(x: x / l, y: y / l, z: z / l)
    }

    /// Altitude and azimuth of this direction.
    public var horizontal: Sky.Horizontal {
        let unit = normalized ?? SkyVector(x: 0, y: 1, z: 0)
        let altitude = asin(Swift.min(1, Swift.max(-1, unit.z))) * 180 / .pi
        let flat = (unit.x * unit.x + unit.y * unit.y).squareRoot()
        let azimuth = flat < 1e-9 ? 0 : Sky.normalized(atan2(unit.x, unit.y) * 180 / .pi)
        return Sky.Horizontal(altitude: altitude, azimuth: azimuth)
    }

    /// A step of `fraction` (0 … 1) from `self` towards `target`, back on the unit sphere: the
    /// glide that takes the sensor's tremor out of the picture without lagging a real turn.
    public func gliding(towards target: SkyVector, fraction: Double) -> SkyVector {
        let f = fraction.isFinite ? Swift.min(1, Swift.max(0, fraction)) : 1
        let mixed = SkyVector(x: x + (target.x - x) * f, y: y + (target.y - y) * f, z: z + (target.z - z) * f)
        return mixed.normalized ?? target
    }
}

/// How the sky lands on the screen: a stereographic projection around the view's forward
/// direction with the given up, so circles stay circles and the middle is undistorted.
/// Coordinates are −1 … 1 across the shorter side of the screen; x right, y up.
public struct SkyProjection: Equatable, Sendable {
    public let forward: SkyVector
    public let right: SkyVector
    public let up: SkyVector
    /// Degrees from one edge of the shorter side to the other.
    public let fieldOfView: Double

    /// Nil when `forward` and `up` are not two different directions.
    public init?(forward: SkyVector, up: SkyVector, fieldOfView: Double) {
        guard fieldOfView.isFinite, fieldOfView > 1, fieldOfView < 179,
              let f = forward.normalized,
              let r = f.cross(up).normalized else { return nil }
        self.forward = f
        right = r
        self.up = r.cross(f)
        self.fieldOfView = fieldOfView
    }

    /// Looking at `centre` with the horizon level — for a finger-turned view without sensors.
    public init?(centre: Sky.Horizontal, fieldOfView: Double) {
        let forward = SkyVector(centre)
        // Up is the zenith tilted back: straight up unless looking at the zenith itself.
        let azimuth = centre.azimuth * .pi / 180
        let level = SkyVector(x: sin(azimuth), y: cos(azimuth), z: 0)
        let up = abs(forward.z) > 0.999 ? SkyVector(x: -level.x * forward.z, y: -level.y * forward.z, z: 0)
            : SkyVector(x: 0, y: 0, z: 1)
        self.init(forward: forward, up: up, fieldOfView: fieldOfView)
    }

    /// Screen coordinates of `vector`, or nil when it is behind the viewer.
    public func project(_ vector: SkyVector) -> (x: Double, y: Double)? {
        let depth = vector.dot(forward)
        guard depth > -0.2 else { return nil }
        let scale = 2 / (1 + depth)
        // A point half the field off-centre lands on the edge: stereographic radius 2·tan(θ/2).
        let edge = 2 * tan(fieldOfView * .pi / 720)
        return (scale * vector.dot(right) / edge, scale * vector.dot(up) / edge)
    }
}
