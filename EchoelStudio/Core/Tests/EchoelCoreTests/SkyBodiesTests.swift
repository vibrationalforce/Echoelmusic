import XCTest
@testable import EchoelCore

/// The Sun, the Moon, Venus and precession against Meeus's worked examples, and the geometry
/// every year shows (the Sun's declination at the solstices).
final class SkyBodiesTests: XCTestCase {
    /// Meeus example 25.a: 1992 October 13.0 TD — α 13h13m31.4s, δ −7°47'06", R 0.99766 AU.
    func testTheSunMatchesMeeusExample() throws {
        let sun = try XCTUnwrap(SkyBodies.position(of: .sun, julianDay: 2_448_908.5))
        XCTAssertEqual(sun.rightAscension, 198.380_83, accuracy: 0.002)
        XCTAssertEqual(sun.declination, -7.785_07, accuracy: 0.002)
        XCTAssertEqual(sun.distance, 0.997_66, accuracy: 0.000_1)
        XCTAssertLessThan(sun.magnitude, -26)
    }

    /// Meeus example 47.a: 1992 April 12.0 TD — α 134.688470°, δ 13.768368°, Δ 368 409.7 km.
    func testTheMoonMatchesMeeusExample() throws {
        let moon = try XCTUnwrap(SkyBodies.position(of: .moon, julianDay: 2_448_724.5))
        XCTAssertEqual(moon.rightAscension, 134.688_470, accuracy: 0.005)
        XCTAssertEqual(moon.declination, 13.768_368, accuracy: 0.005)
        let kilometres: Double = moon.distance * 149_597_870.7
        XCTAssertEqual(kilometres, 368_409.7, accuracy: 60)
        XCTAssertLessThan(moon.magnitude, -6, "the Moon outshines every star at any phase")
    }

    /// Meeus example 33.a: Venus, 1992 December 20.0 TD — α 21h04m41.454s, δ −18°53'16.84".
    /// Elements, not the full theory: a few hundredths of a degree is what they promise.
    func testVenusMatchesMeeusExample() throws {
        let venus = try XCTUnwrap(SkyBodies.position(of: .venus, julianDay: 2_448_976.5))
        XCTAssertEqual(venus.rightAscension, 316.172_73, accuracy: 0.03)
        XCTAssertEqual(venus.declination, -18.888_01, accuracy: 0.03)
        XCTAssertGreaterThan(venus.magnitude, -4.7)
        XCTAssertLessThan(venus.magnitude, -3.7)
    }

    /// Meeus example 21.b: θ Persei, J2000 (with its proper motion to the date applied) to
    /// 2028 November 13.19 TD — α 2h46m11.331s, δ +49°20'54.54".
    func testPrecessionMatchesMeeusExample() {
        let moved = SkyBodies.precessed(rightAscension: 41.054_063, declination: 49.227_750, toJulianDay: 2_462_088.69)
        XCTAssertEqual(moved.rightAscension, 41.547_214, accuracy: 0.000_2)
        XCTAssertEqual(moved.declination, 49.348_483, accuracy: 0.000_2)
    }

    func testTheSunStandsAtTheTropicsAtTheSolstices() throws {
        // 2026 June 21.36 and December 21.86, the solstices (UT, near enough to TD here).
        let june = try XCTUnwrap(SkyBodies.position(of: .sun, julianDay: 2_461_212.86))
        let december = try XCTUnwrap(SkyBodies.position(of: .sun, julianDay: 2_461_396.36))
        XCTAssertEqual(june.declination, 23.436, accuracy: 0.01)
        XCTAssertEqual(december.declination, -23.436, accuracy: 0.01)
    }

    func testEveryBodyHasAPositionAndPlanetsAreFartherThanTheMoon() throws {
        let jd = 2_461_345.5
        let moon = try XCTUnwrap(SkyBodies.position(of: .moon, julianDay: jd))
        for body in SkyBodies.Body.allCases {
            let position = try XCTUnwrap(SkyBodies.position(of: body, julianDay: jd), body.rawValue)
            XCTAssertTrue((0..<360).contains(position.rightAscension), body.rawValue)
            XCTAssertLessThanOrEqual(abs(position.declination), 90, body.rawValue)
            XCTAssertTrue(position.magnitude.isFinite, body.rawValue)
            if body != .moon { XCTAssertGreaterThan(position.distance, moon.distance, body.rawValue) }
        }
        XCTAssertNil(SkyBodies.position(of: .mars, julianDay: .nan))
        XCTAssertEqual(SkyBodies.Body.jupiter.name, "Jupiter")
    }

    /// Seen from the ground the Moon stands up to about a degree lower than from the centre.
    func testTheMoonSitsLowerSeenFromTheGround() {
        let moonDistance: Double = 384_400 / 149_597_870.7
        let horizon = SkyBodies.topocentricAltitude(0, distance: moonDistance)
        XCTAssertEqual(horizon, -0.95, accuracy: 0.02)
        XCTAssertEqual(SkyBodies.topocentricAltitude(90, distance: moonDistance), 90, accuracy: 1e-9)
        XCTAssertEqual(SkyBodies.topocentricAltitude(30, distance: 5), 30, accuracy: 1e-4, "a planet does not move")
    }
}
