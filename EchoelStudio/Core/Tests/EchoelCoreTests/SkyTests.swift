import XCTest
@testable import EchoelCore

/// The sky arithmetic against Meeus's worked example and against geometry that holds for any
/// place: the pole stands at the observer's latitude, a star on the meridian at 90° minus the
/// distance between its declination and the latitude.
final class SkyTests: XCTestCase {
    /// Meeus example 12.a: 1987 April 10, 0h UT is JD 2446895.5 and 13h10m46.3668s sidereal.
    func testSiderealTimeMatchesMeeusExample() {
        let hours: Double = 13
        let minutes: Double = 10
        let seconds: Double = 46.3668
        let expected: Double = (hours + minutes / 60 + seconds / 3600) * 15
        XCTAssertEqual(Sky.greenwichSiderealDegrees(julianDay: 2_446_895.5), expected, accuracy: 1e-4)
    }

    func testTheUnixEpochIsItsJulianDay() {
        XCTAssertEqual(Sky.julianDay(Date(timeIntervalSince1970: 0)), 2_440_587.5, accuracy: 1e-9)
    }

    func testThePoleStandsAtTheObserversLatitude() throws {
        for latitude in [53.55, 0, -33.9, 89] {
            for jd in [2_451_545.0, 2_460_000.25] {
                let pole = try XCTUnwrap(Sky.horizontal(rightAscension: 37, declination: 90, latitude: latitude,
                                                        longitude: 9.99, julianDay: jd))
                XCTAssertEqual(pole.altitude, latitude, accuracy: 1e-9)
            }
        }
    }

    /// A star whose right ascension is the local sidereal time is on the meridian: due south of an
    /// observer north of it, at 90° minus the difference of latitude and declination.
    func testAStarOnTheMeridianStandsSouthAtTheExpectedHeight() throws {
        let jd = 2_460_612.5, longitude = 9.99, latitude = 53.55
        let ra = Sky.normalized(Sky.greenwichSiderealDegrees(julianDay: jd) + longitude)
        let star = try XCTUnwrap(Sky.horizontal(rightAscension: ra, declination: 20, latitude: latitude,
                                                longitude: longitude, julianDay: jd))
        let expectedAltitude: Double = 90 - (latitude - 20)
        XCTAssertEqual(star.altitude, expectedAltitude, accuracy: 1e-9)
        XCTAssertEqual(star.azimuth, 180, accuracy: 1e-9)
        let north = try XCTUnwrap(Sky.horizontal(rightAscension: ra, declination: 80, latitude: latitude,
                                                 longitude: longitude, julianDay: jd))
        XCTAssertEqual(north.azimuth, 0, accuracy: 1e-9, "north of the zenith it stands due north")
    }

    /// Six sidereal hours later the same star has moved west: its azimuth is past 180°.
    func testTheSkyTurnsWestward() throws {
        let jd = 2_460_612.5, longitude = 0.0, latitude = 45.0
        let ra = Sky.greenwichSiderealDegrees(julianDay: jd)
        let later = try XCTUnwrap(Sky.horizontal(rightAscension: ra, declination: 0, latitude: latitude,
                                                 longitude: longitude, julianDay: jd + 0.1))
        XCTAssertGreaterThan(later.azimuth, 180)
        XCTAssertLessThan(later.azimuth, 360)
    }

    func testBadInputGivesNoPosition() {
        XCTAssertNil(Sky.horizontal(rightAscension: .nan, declination: 0, latitude: 0, longitude: 0, julianDay: 2_451_545))
        XCTAssertNil(Sky.horizontal(rightAscension: 0, declination: 0, latitude: 91, longitude: 0, julianDay: 2_451_545))
    }

    func testSeparationIsTheAngleBetweenTwoDirections() {
        let zenith = Sky.Horizontal(altitude: 90, azimuth: 0), horizonEast = Sky.Horizontal(altitude: 0, azimuth: 90)
        XCTAssertEqual(Sky.separation(zenith, horizonEast), 90, accuracy: 1e-9)
        XCTAssertEqual(Sky.separation(horizonEast, Sky.Horizontal(altitude: 0, azimuth: 270)), 180, accuracy: 1e-9)
    }
}
