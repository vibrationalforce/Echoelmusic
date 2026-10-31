import Foundation

/// The Sun, the Moon and the planets for any moment, by arithmetic alone (sky source, founder
/// 2026-10-31): nothing is downloaded, so the sky is complete offline and in the dark.
///
/// - Sun: Meeus, *Astronomical Algorithms* (2nd ed.), ch. 25, low accuracy (≈ 0.01°).
/// - Moon: Meeus ch. 47 with the 59 largest longitude, 30 latitude and 30 distance terms of the
///   ELP-2000/82 series Meeus tabulates (≈ 0.01°, ≈ 50 km), geocentric.
/// - Planets: Keplerian elements and their rates per century, J2000 ecliptic (E. M. Standish,
///   JPL, "Keplerian Elements for Approximate Positions of the Major Planets", table 1, valid
///   1800–2050), solved with Kepler's equation and light time, then precessed (Meeus ch. 21) —
///   a few hundredths of a degree for the inner planets, up to ≈ 0.2° for Jupiter and Saturn.
///   Magnitudes from distance and phase angle (Meeus ch. 41).
///
/// Good to well under a degree, which is what "which body is the phone pointing at" needs. Pure,
/// Foundation-only, tested against Meeus's worked examples (`SkyBodiesTests`).
public enum SkyBodies {
    public enum Body: String, CaseIterable, Sendable {
        case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune

        /// The English name, as the sky view shows it.
        public var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    }

    /// A body seen from the Earth's centre: right ascension and declination in degrees on the
    /// equator of the date, its visual magnitude, and its distance in astronomical units.
    public struct Position: Equatable, Sendable {
        public let rightAscension: Double
        public let declination: Double
        public let magnitude: Double
        public let distance: Double
    }

    /// The Earth's equatorial radius in astronomical units, for the Moon's parallax.
    public static let earthRadiusAU = 6_378.14 / 149_597_870.7

    /// Where `body` stands at `julianDay` (dynamical time; the 70 s to UT do not matter here).
    /// Nil for a non-finite day.
    public static func position(of body: Body, julianDay jd: Double) -> Position? {
        guard jd.isFinite else { return nil }
        switch body {
        case .sun: return sun(jd)
        case .moon: return moon(jd)
        case .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune: return planet(body, jd)
        }
    }

    /// A J2000 position (degrees) moved to the mean equator of `julianDay` (Meeus 21.2–21.4):
    /// about 0.36° over the 26 years since 2000, more than the width of the full Moon.
    public static func precessed(rightAscension: Double, declination: Double,
                                 toJulianDay jd: Double) -> (rightAscension: Double, declination: Double) {
        let t = (jd - 2_451_545) / 36_525
        let zeta = (2_306.2181 * t + 0.301_88 * t * t + 0.017_998 * t * t * t) / 3_600
        let z = (2_306.2181 * t + 1.094_68 * t * t + 0.018_203 * t * t * t) / 3_600
        let theta = (2_004.3109 * t - 0.426_65 * t * t - 0.041_833 * t * t * t) / 3_600
        let alpha = radians(rightAscension + zeta), delta = radians(declination), th = radians(theta)
        let a = cos(delta) * sin(alpha)
        let b = cos(th) * cos(delta) * cos(alpha) - sin(th) * sin(delta)
        let c = sin(th) * cos(delta) * cos(alpha) + cos(th) * sin(delta)
        let ra = Sky.normalized(degrees(atan2(a, b)) + z)
        let dec = degrees(asin(Swift.min(1, Swift.max(-1, c))))
        return (ra, dec)
    }

    /// The altitude a body at `distance` AU appears at from the ground, given its geocentric
    /// altitude: lower by the parallax (Meeus ch. 40, the altitude part). Up to ≈ 1° for the
    /// Moon, nothing anyone could see for the rest.
    public static func topocentricAltitude(_ altitude: Double, distance: Double) -> Double {
        guard distance > earthRadiusAU, altitude.isFinite else { return altitude }
        let parallax = degrees(asin(earthRadiusAU / distance))
        return altitude - parallax * cos(radians(altitude))
    }

    // MARK: - Sun

    private static func sun(_ jd: Double) -> Position {
        let t = (jd - 2_451_545) / 36_525
        let meanLongitude = 280.466_46 + 36_000.769_83 * t + 0.000_303_2 * t * t
        let anomaly = 357.529_11 + 35_999.050_29 * t - 0.000_153_7 * t * t
        let m = radians(anomaly)
        let centre = (1.914_602 - 0.004_817 * t - 0.000_014 * t * t) * sin(m)
            + (0.019_993 - 0.000_101 * t) * sin(2 * m) + 0.000_289 * sin(3 * m)
        let omega = radians(125.04 - 1_934.136 * t)
        let longitude = meanLongitude + centre - 0.005_69 - 0.004_78 * sin(omega)
        let obliquity = meanObliquity(t) + 0.002_56 * cos(omega)
        let eccentricity = 0.016_708_634 - 0.000_042_037 * t
        let trueAnomaly = radians(anomaly + centre)
        let distance = 1.000_001_018 * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(trueAnomaly))
        let equatorial = eclipticToEquatorial(longitude: longitude, latitude: 0, obliquity: obliquity)
        return Position(rightAscension: equatorial.ra, declination: equatorial.dec, magnitude: -26.74,
                        distance: distance)
    }

    // MARK: - Moon

    /// Meeus table 47.A/B as (D, M, M′, F, coefficient) rows, flat: longitude (10⁻⁶ °).
    private static let moonLongitudeTerms: [Double] = [
        0, 0, 1, 0, 6_288_774, 2, 0, -1, 0, 1_274_027, 2, 0, 0, 0, 658_314, 0, 0, 2, 0, 213_618,
        0, 1, 0, 0, -185_116, 0, 0, 0, 2, -114_332, 2, 0, -2, 0, 58_793, 2, -1, -1, 0, 57_066,
        2, 0, 1, 0, 53_322, 2, -1, 0, 0, 45_758, 0, 1, -1, 0, -40_923, 1, 0, 0, 0, -34_720,
        0, 1, 1, 0, -30_383, 2, 0, 0, -2, 15_327, 0, 0, 1, 2, -12_528, 0, 0, 1, -2, 10_980,
        4, 0, -1, 0, 10_675, 0, 0, 3, 0, 10_034, 4, 0, -2, 0, 8_548, 2, 1, -1, 0, -7_888,
        2, 1, 0, 0, -6_766, 1, 0, -1, 0, -5_163, 1, 1, 0, 0, 4_987, 2, -1, 1, 0, 4_036,
        2, 0, 2, 0, 3_994, 4, 0, 0, 0, 3_861, 2, 0, -3, 0, 3_665, 0, 1, -2, 0, -2_689,
        2, 0, -1, 2, -2_602, 2, -1, -2, 0, 2_390, 1, 0, 1, 0, -2_348, 2, -2, 0, 0, 2_236,
        0, 1, 2, 0, -2_120, 0, 2, 0, 0, -2_069, 2, -2, -1, 0, 2_048, 2, 0, 1, -2, -1_773,
        2, 0, 0, 2, -1_595, 4, -1, -1, 0, 1_215, 0, 0, 2, 2, -1_110, 3, 0, -1, 0, -892,
        2, 1, 1, 0, -810, 4, -1, -2, 0, 759, 0, 2, -1, 0, -713, 2, 2, -1, 0, -700,
        2, 1, -2, 0, 691, 2, -1, 0, -2, 596, 4, 0, 1, 0, 549, 0, 0, 4, 0, 537,
        4, -1, 0, 0, 520, 1, 0, -2, 0, -487, 2, 1, 0, -2, -399, 0, 0, 2, -2, -381,
        1, 1, 1, 0, 351, 3, 0, -2, 0, -340, 4, 0, -3, 0, 330, 2, -1, 2, 0, 327,
        0, 2, 1, 0, -323, 1, 1, -1, 0, 299, 2, 0, 3, 0, 294,
    ]

    /// Latitude (10⁻⁶ °), the 30 largest rows.
    private static let moonLatitudeTerms: [Double] = [
        0, 0, 0, 1, 5_128_122, 0, 0, 1, 1, 280_602, 0, 0, 1, -1, 277_693, 2, 0, 0, -1, 173_237,
        2, 0, -1, 1, 55_413, 2, 0, -1, -1, 46_271, 2, 0, 0, 1, 32_573, 0, 0, 2, 1, 17_198,
        2, 0, 1, -1, 9_266, 0, 0, 2, -1, 8_822, 2, -1, 0, -1, 8_216, 2, 0, -2, -1, 4_324,
        2, 0, 1, 1, 4_200, 2, 1, 0, -1, -3_359, 2, -1, -1, 1, 2_463, 2, -1, 0, 1, 2_211,
        2, -1, -1, -1, 2_065, 0, 1, -1, -1, -1_870, 4, 0, -1, -1, 1_828, 0, 1, 0, 1, -1_794,
        0, 0, 0, 3, -1_749, 0, 1, -1, 1, -1_565, 1, 0, 0, 1, -1_491, 0, 1, 1, 1, -1_475,
        0, 1, 1, -1, -1_410, 0, 1, 0, -1, -1_344, 1, 0, 0, -1, -1_335, 0, 0, 3, 1, 1_107,
        4, 0, 0, -1, 1_021, 4, 0, -1, 1, 833,
    ]

    /// Distance (metres, a cosine series), the 30 largest rows.
    private static let moonDistanceTerms: [Double] = [
        0, 0, 1, 0, -20_905_355, 2, 0, -1, 0, -3_699_111, 2, 0, 0, 0, -2_955_968, 0, 0, 2, 0, -569_925,
        0, 1, 0, 0, 48_888, 0, 0, 0, 2, -3_149, 2, 0, -2, 0, 246_158, 2, -1, -1, 0, -152_138,
        2, 0, 1, 0, -170_733, 2, -1, 0, 0, -204_586, 0, 1, -1, 0, -129_620, 1, 0, 0, 0, 108_743,
        0, 1, 1, 0, 104_755, 2, 0, 0, -2, 10_321, 0, 0, 1, -2, 79_661, 4, 0, -1, 0, -34_782,
        0, 0, 3, 0, -23_210, 4, 0, -2, 0, -21_636, 2, 1, -1, 0, 24_208, 2, 1, 0, 0, 30_824,
        1, 0, -1, 0, -8_379, 1, 1, 0, 0, -16_675, 2, -1, 1, 0, -12_831, 2, 0, 2, 0, -10_445,
        4, 0, 0, 0, -11_650, 2, 0, -3, 0, 14_403, 0, 1, -2, 0, -7_003, 2, -1, -2, 0, 10_056,
        1, 0, 1, 0, 6_322, 2, -2, 0, 0, -9_884,
    ]

    private struct LunarArguments {
        let d: Double
        let m: Double
        let mPrime: Double
        let f: Double
        let e: Double

        /// The term's argument in radians and its eccentricity factor.
        func argument(_ terms: [Double], at row: Int) -> (angle: Double, factor: Double) {
            let base = row * 5
            let angle = terms[base] * d + terms[base + 1] * m + terms[base + 2] * mPrime + terms[base + 3] * f
            let power = abs(terms[base + 1])
            let factor = power == 0 ? 1 : (power == 1 ? e : e * e)
            return (SkyBodies.radians(angle), factor)
        }
    }

    private static func series(_ terms: [Double], _ args: LunarArguments, cosine: Bool) -> Double {
        var sum = 0.0
        for row in 0..<(terms.count / 5) {
            let (angle, factor) = args.argument(terms, at: row)
            sum += terms[row * 5 + 4] * factor * (cosine ? cos(angle) : sin(angle))
        }
        return sum
    }

    private static func moon(_ jd: Double) -> Position {
        let t = (jd - 2_451_545) / 36_525
        let lPrime = Sky.normalized(218.316_447_7 + 481_267.881_234_21 * t - 0.001_578_6 * t * t)
        let args = LunarArguments(
            d: Sky.normalized(297.850_192_1 + 445_267.111_403_4 * t - 0.001_881_9 * t * t),
            m: Sky.normalized(357.529_109_2 + 35_999.050_290_9 * t - 0.000_153_6 * t * t),
            mPrime: Sky.normalized(134.963_396_4 + 477_198.867_505_5 * t + 0.008_741_4 * t * t),
            f: Sky.normalized(93.272_095_0 + 483_202.017_523_3 * t - 0.003_653_9 * t * t),
            e: 1 - 0.002_516 * t - 0.000_007_4 * t * t)
        let a1 = radians(119.75 + 131.849 * t)
        let a2 = radians(53.09 + 479_264.290 * t)
        let a3 = radians(313.45 + 481_266.484 * t)
        let lp = radians(lPrime), f = radians(args.f), mp = radians(args.mPrime)
        var sumL = series(moonLongitudeTerms, args, cosine: false)
        sumL += 3_958 * sin(a1) + 1_962 * sin(lp - f) + 318 * sin(a2)
        var sumB = series(moonLatitudeTerms, args, cosine: false)
        sumB += -2_235 * sin(lp) + 382 * sin(a3) + 175 * sin(a1 - f) + 175 * sin(a1 + f)
        sumB += 127 * sin(lp - mp) - 115 * sin(lp + mp)
        let sumR = series(moonDistanceTerms, args, cosine: true)
        // Nutation in longitude and obliquity, the two largest terms (Meeus ch. 22).
        let omega = radians(125.044_52 - 1_934.136_261 * t)
        let sunLongitude = radians(280.4665 + 36_000.7698 * t)
        let deltaPsi = (-17.20 * sin(omega) - 1.32 * sin(2 * sunLongitude)) / 3_600
        let deltaEpsilon = 9.20 * cos(omega) / 3_600
        let longitude = lPrime + sumL / 1_000_000 + deltaPsi
        let latitude = sumB / 1_000_000
        let kilometres = 385_000.56 + sumR / 1_000
        let equatorial = eclipticToEquatorial(longitude: longitude, latitude: latitude,
                                              obliquity: meanObliquity(t) + deltaEpsilon)
        let distance = kilometres / 149_597_870.7
        // Magnitude from the phase angle (elongation from the Sun, Meeus 48.2), Allen's fit.
        let solar = sun(jd)
        let elongation = Sky.separationEquatorial(solar.rightAscension, solar.declination,
                                                  equatorial.ra, equatorial.dec)
        let psi = radians(elongation)
        let phase = degrees(atan2(solar.distance * sin(psi), distance - solar.distance * cos(psi)))
        let magnitude = -12.73 + 0.026 * abs(phase) + 4e-9 * Foundation.pow(abs(phase), 4)
        return Position(rightAscension: equatorial.ra, declination: equatorial.dec, magnitude: magnitude,
                        distance: distance)
    }

    // MARK: - Planets

    /// Standish table 1: (value at J2000, rate per Julian century) for a [AU], e, I [°], L [°],
    /// longitude of perihelion ϖ [°], longitude of the ascending node Ω [°].
    private static func elements(_ body: Body) -> [Double] {
        switch body {
        case .mercury: return [0.387_099_27, 0.000_000_37, 0.205_635_93, 0.000_019_06, 7.004_979_02, -0.005_947_49,
                               252.250_323_50, 149_472.674_111_75, 77.457_796_28, 0.160_476_89, 48.330_765_93, -0.125_340_81]
        case .venus: return [0.723_335_66, 0.000_003_90, 0.006_776_72, -0.000_041_07, 3.394_676_05, -0.000_788_90,
                             181.979_099_50, 58_517.815_387_29, 131.602_467_18, 0.002_683_29, 76.679_842_55, -0.277_694_18]
        case .mars: return [1.523_710_34, 0.000_018_47, 0.093_394_10, 0.000_078_82, 1.849_691_42, -0.008_131_31,
                            -4.553_432_05, 19_140.302_684_99, -23.943_629_59, 0.444_410_88, 49.559_538_91, -0.292_573_43]
        case .jupiter: return [5.202_887_00, -0.000_116_07, 0.048_386_24, -0.000_132_53, 1.304_396_95, -0.001_837_14,
                               34.396_440_51, 3_034.746_127_75, 14.728_479_83, 0.212_526_68, 100.473_909_09, 0.204_691_06]
        case .saturn: return [9.536_675_94, -0.001_250_60, 0.053_861_79, -0.000_509_91, 2.485_991_87, 0.001_936_09,
                              49.954_244_23, 1_222.493_622_01, 92.598_878_31, -0.418_972_16, 113.662_424_48, -0.288_677_94]
        case .uranus: return [19.189_164_64, -0.001_961_76, 0.047_257_44, -0.000_043_97, 0.772_637_83, -0.002_429_39,
                              313.238_104_51, 428.482_027_85, 170.954_276_30, 0.408_052_81, 74.016_925_03, 0.042_405_89]
        case .neptune: return [30.069_922_76, 0.000_262_91, 0.008_590_48, 0.000_051_05, 1.770_043_47, 0.000_353_72,
                               -55.120_029_69, 218.459_453_25, 44.964_762_27, -0.322_414_64, 131.784_225_74, -0.005_086_64]
        case .sun, .moon: return earthElements
        }
    }

    /// The Earth–Moon barycentre.
    private static let earthElements: [Double] = [1.000_002_61, 0.000_005_62, 0.016_711_23, -0.000_043_92,
                                                  -0.000_015_31, -0.012_946_68, 100.464_571_66, 35_999.372_449_81,
                                                  102.937_681_93, 0.323_273_64, 0, 0]

    /// Heliocentric ecliptic J2000 coordinates (AU) from a set of elements at `t` centuries.
    private static func heliocentric(_ table: [Double], _ t: Double) -> (x: Double, y: Double, z: Double) {
        let a = table[0] + table[1] * t
        let e = table[2] + table[3] * t
        let inclination = radians(table[4] + table[5] * t)
        let meanLongitude = table[6] + table[7] * t
        let perihelion = table[8] + table[9] * t
        let node = table[10] + table[11] * t
        var anomaly = Sky.normalized(meanLongitude - perihelion)
        if anomaly > 180 { anomaly -= 360 }
        let m = radians(anomaly)
        var eccentric = m + e * sin(m)
        for _ in 0..<10 {
            eccentric -= (eccentric - e * sin(eccentric) - m) / (1 - e * cos(eccentric))
        }
        let xp = a * (cos(eccentric) - e)
        let yp = a * (1 - e * e).squareRoot() * sin(eccentric)
        let w = radians(perihelion - node), o = radians(node)
        let x = (cos(w) * cos(o) - sin(w) * sin(o) * cos(inclination)) * xp
            + (-sin(w) * cos(o) - cos(w) * sin(o) * cos(inclination)) * yp
        let y = (cos(w) * sin(o) + sin(w) * cos(o) * cos(inclination)) * xp
            + (-sin(w) * sin(o) + cos(w) * cos(o) * cos(inclination)) * yp
        let z = sin(w) * sin(inclination) * xp + cos(w) * sin(inclination) * yp
        return (x, y, z)
    }

    /// Meeus 41: magnitude from distances r (Sun) and Δ (Earth) and the phase angle i in degrees.
    private static func planetMagnitude(_ body: Body, r: Double, delta: Double, phase i: Double) -> Double {
        let distanceTerm = 5 * Foundation.log10(Swift.max(1e-9, r * delta))
        switch body {
        case .mercury: return -0.42 + distanceTerm + 0.038 * i - 0.000_273 * i * i + 0.000_002 * i * i * i
        case .venus: return -4.40 + distanceTerm + 0.000_9 * i + 0.000_239 * i * i - 0.000_000_65 * i * i * i
        case .mars: return -1.52 + distanceTerm + 0.016 * i
        case .jupiter: return -9.40 + distanceTerm + 0.005 * i
        case .saturn: return -8.88 + distanceTerm
        case .uranus: return -7.19 + distanceTerm
        case .neptune: return -6.87 + distanceTerm
        case .sun, .moon: return 0
        }
    }

    private static func planet(_ body: Body, _ jd: Double) -> Position {
        let t = (jd - 2_451_545) / 36_525
        let table = elements(body)
        let earth = heliocentric(earthElements, t)
        var helio = heliocentric(table, t)
        var gx = helio.x - earth.x, gy = helio.y - earth.y, gz = helio.z - earth.z
        // Light time: where the planet was when the light we see left it.
        let lightDays = (gx * gx + gy * gy + gz * gz).squareRoot() * 0.005_775_518_3
        helio = heliocentric(table, t - lightDays / 36_525)
        gx = helio.x - earth.x
        gy = helio.y - earth.y
        gz = helio.z - earth.z
        let delta = (gx * gx + gy * gy + gz * gz).squareRoot()
        let r = (helio.x * helio.x + helio.y * helio.y + helio.z * helio.z).squareRoot()
        let earthSun = (earth.x * earth.x + earth.y * earth.y + earth.z * earth.z).squareRoot()
        let longitude = Sky.normalized(degrees(atan2(gy, gx)))
        let latitude = degrees(atan2(gz, (gx * gx + gy * gy).squareRoot()))
        // J2000 ecliptic → J2000 equator → equator of the date.
        let j2000 = eclipticToEquatorial(longitude: longitude, latitude: latitude, obliquity: 23.439_28)
        let ofDate = precessed(rightAscension: j2000.ra, declination: j2000.dec, toJulianDay: jd)
        let cosPhase = (r * r + delta * delta - earthSun * earthSun) / (2 * r * delta)
        let phase = degrees(acos(Swift.min(1, Swift.max(-1, cosPhase))))
        return Position(rightAscension: ofDate.rightAscension, declination: ofDate.declination,
                        magnitude: planetMagnitude(body, r: r, delta: delta, phase: phase), distance: delta)
    }

    // MARK: - Shared

    private static func meanObliquity(_ t: Double) -> Double {
        23.439_291_111 - 0.013_004_166_7 * t - 0.000_000_163_9 * t * t + 0.000_000_503_6 * t * t * t
    }

    private static func eclipticToEquatorial(longitude: Double, latitude: Double,
                                             obliquity: Double) -> (ra: Double, dec: Double) {
        let l = radians(longitude), b = radians(latitude), e = radians(obliquity)
        let ra = atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
        let dec = asin(Swift.min(1, Swift.max(-1, sin(b) * cos(e) + cos(b) * sin(e) * sin(l))))
        return (Sky.normalized(degrees(ra)), degrees(dec))
    }

    fileprivate static func radians(_ d: Double) -> Double { d * .pi / 180 }
    fileprivate static func degrees(_ r: Double) -> Double { r * 180 / .pi }
}

extension Sky {
    /// The angle between two equatorial directions in degrees (0 … 180).
    static func separationEquatorial(_ ra1: Double, _ dec1: Double, _ ra2: Double, _ dec2: Double) -> Double {
        let d1 = dec1 * .pi / 180, d2 = dec2 * .pi / 180
        let cosine = sin(d1) * sin(d2) + cos(d1) * cos(d2) * cos((ra1 - ra2) * .pi / 180)
        return acos(Swift.min(1, Swift.max(-1, cosine))) * 180 / .pi
    }
}
