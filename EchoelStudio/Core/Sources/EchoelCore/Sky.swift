import Foundation

/// Where a star stands in the sky of one place at one moment (sky source S1, founder 2026-10-28):
/// the arithmetic that turns a catalogue position (right ascension, declination) into altitude
/// and azimuth from the observer's latitude, longitude and the time. Pure and Foundation-only;
/// the formulas are Meeus, *Astronomical Algorithms* (2nd ed.), ch. 12 and 13. No refraction,
/// precession or nutation: for "which star is the phone pointing at" a few arcminutes do not
/// matter, and the result says nothing beyond where the star is.
public enum Sky {
    /// Julian day of a moment (Meeus 7; the Unix epoch is JD 2440587.5).
    public static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    /// Greenwich mean sidereal time in degrees, 0 ..< 360 (Meeus 12.4).
    public static func greenwichSiderealDegrees(julianDay jd: Double) -> Double {
        let t = (jd - 2_451_545) / 36_525
        let theta = 280.460_618_37 + 360.985_647_366_29 * (jd - 2_451_545)
            + 0.000_387_933 * t * t - t * t * t / 38_710_000
        return normalized(theta)
    }

    /// A position seen from the ground: altitude above the horizon (−90 … 90) and azimuth from
    /// north through east (0 ..< 360), both in degrees.
    public struct Horizontal: Equatable, Sendable {
        public let altitude: Double
        public let azimuth: Double
    }

    /// Where a body at `rightAscension`/`declination` (degrees, equator of date) stands for an
    /// observer at `latitude`/`longitude` (degrees, east positive) at `julianDay` (Meeus 13.5/13.6).
    /// Nil for a non-finite input or a latitude or declination outside ±90.
    public static func horizontal(rightAscension: Double, declination: Double, latitude: Double,
                                  longitude: Double, julianDay: Double) -> Horizontal? {
        guard [rightAscension, declination, latitude, longitude, julianDay].allSatisfy(\.isFinite),
              abs(latitude) <= 90, abs(declination) <= 90 else { return nil }
        let local = greenwichSiderealDegrees(julianDay: julianDay) + longitude
        let hourAngle = radians(normalized(local - rightAscension))
        let phi = radians(latitude), delta = radians(declination)
        let sinAltitude = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(hourAngle)
        let altitude = asin(Swift.min(1, Swift.max(-1, sinAltitude)))
        // From north through east; Meeus measures from south, so the sign of x and y flips.
        let y = -cos(delta) * sin(hourAngle)
        let x = sin(delta) * cos(phi) - cos(delta) * cos(hourAngle) * sin(phi)
        let azimuth = (x == 0 && y == 0) ? 0 : normalized(degrees(atan2(y, x)))
        return Horizontal(altitude: degrees(altitude), azimuth: azimuth)
    }

    /// The angle between two directions on the sky, in degrees (0 … 180).
    public static func separation(_ a: Horizontal, _ b: Horizontal) -> Double {
        let a1 = radians(a.altitude), a2 = radians(b.altitude)
        let cosine = sin(a1) * sin(a2) + cos(a1) * cos(a2) * cos(radians(a.azimuth - b.azimuth))
        return degrees(acos(Swift.min(1, Swift.max(-1, cosine))))
    }

    static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    private static func radians(_ d: Double) -> Double { d * .pi / 180 }
    private static func degrees(_ r: Double) -> Double { r * 180 / .pi }
}
