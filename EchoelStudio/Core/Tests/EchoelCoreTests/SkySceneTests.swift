import XCTest
@testable import EchoelCore

/// The sky over Hamburg at known moments, what counts as "in the middle", and the projection
/// that puts it on the screen.
final class SkySceneTests: XCTestCase {
    private let latitude = 53.55
    private let longitude = 9.99

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        return try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                                hour: hour, minute: minute)))
    }

    func testPolarisStandsNorthAtTheLatitude() throws {
        let scene = try XCTUnwrap(SkyScene(latitude: latitude, longitude: longitude, date: date(2026, 10, 31, 22, 0)))
        let polaris = try XCTUnwrap(scene.objects.first { $0.name == "Polaris" })
        XCTAssertEqual(polaris.position.altitude, 54.11, accuracy: 0.05)
        XCTAssertEqual(polaris.position.azimuth, 0.48, accuracy: 0.1)
        XCTAssertEqual(scene.centred(on: polaris.position)?.id, polaris.id)
    }

    func testTheSunIsHighAtMiddayAndGoneAtMidnightInJune() throws {
        let noon = try XCTUnwrap(SkyScene(latitude: latitude, longitude: longitude, date: date(2026, 6, 21, 11, 20)))
        let sun = try XCTUnwrap(noon.objects.first { $0.kind == .body(.sun) })
        XCTAssertEqual(sun.position.altitude, 59.89, accuracy: 0.05)
        XCTAssertEqual(sun.position.azimuth, 179.1, accuracy: 0.2)
        let midnight = try XCTUnwrap(SkyScene(latitude: latitude, longitude: longitude, date: date(2026, 6, 21, 0, 0)))
        XCTAssertNil(midnight.objects.first { $0.kind == .body(.sun) }, "12.6° below the horizon")
    }

    func testOnlyWhatIsAboveTheHorizonIsInTheScene() throws {
        let scene = try XCTUnwrap(SkyScene(latitude: latitude, longitude: longitude, date: date(2026, 10, 31, 22, 0)))
        XCTAssertTrue(scene.objects.allSatisfy { $0.position.altitude >= SkyScene.lowestAltitude })
        XCTAssertGreaterThan(scene.objects.count, 1_000)
        XCTAssertLessThan(scene.objects.count, StarCatalog.stars.count)
        XCTAssertNil(SkyScene(latitude: 91, longitude: 0, date: Date()))
        XCTAssertNil(SkyScene(latitude: .nan, longitude: 0, date: Date()))
    }

    func testABrightStarAsideWinsOverAFaintOneInTheMiddle() throws {
        let scene = try XCTUnwrap(SkyScene(latitude: latitude, longitude: longitude, date: date(2026, 10, 31, 22, 0)))
        let vega = try XCTUnwrap(scene.objects.first { $0.name == "Vega" })
        let aside = Sky.Horizontal(altitude: vega.position.altitude + 1.5, azimuth: vega.position.azimuth)
        XCTAssertEqual(scene.centred(on: aside)?.id, vega.id)
        let empty = Sky.Horizontal(altitude: -60, azimuth: 0)
        XCTAssertNil(scene.centred(on: empty), "nothing below the horizon")
    }

    func testTheCentreProjectsToTheMiddleAndTheSkyKeepsItsSides() throws {
        let view = try XCTUnwrap(SkyProjection(centre: Sky.Horizontal(altitude: 0, azimuth: 0), fieldOfView: 60))
        let middle = try XCTUnwrap(view.project(SkyVector(Sky.Horizontal(altitude: 0, azimuth: 0))))
        XCTAssertEqual(middle.x, 0, accuracy: 1e-12)
        XCTAssertEqual(middle.y, 0, accuracy: 1e-12)
        let higher = try XCTUnwrap(view.project(SkyVector(Sky.Horizontal(altitude: 10, azimuth: 0))))
        XCTAssertGreaterThan(higher.y, 0)
        XCTAssertEqual(higher.x, 0, accuracy: 1e-12)
        let east = try XCTUnwrap(view.project(SkyVector(Sky.Horizontal(altitude: 0, azimuth: 30))))
        XCTAssertEqual(east.x, 1, accuracy: 1e-9, "half the field to the right lands on the right edge")
        XCTAssertNil(view.project(SkyVector(Sky.Horizontal(altitude: 0, azimuth: 180))), "behind the viewer")
    }

    func testLookingAtTheZenithStillHasAnUp() throws {
        let view = try XCTUnwrap(SkyProjection(centre: Sky.Horizontal(altitude: 90, azimuth: 0), fieldOfView: 90))
        XCTAssertEqual(view.forward.z, 1, accuracy: 1e-9)
        XCTAssertEqual(view.up.dot(view.forward), 0, accuracy: 1e-9)
        XCTAssertNil(SkyProjection(forward: SkyVector(x: 0, y: 0, z: 1), up: SkyVector(x: 0, y: 0, z: 2), fieldOfView: 60))
    }

    func testAVectorKnowsItsDirectionAndGlidesOnTheSphere() {
        let place = Sky.Horizontal(altitude: 35, azimuth: 250)
        let back = SkyVector(place).horizontal
        XCTAssertEqual(back.altitude, 35, accuracy: 1e-9)
        XCTAssertEqual(back.azimuth, 250, accuracy: 1e-9)
        let a = SkyVector(Sky.Horizontal(altitude: 0, azimuth: 0)), b = SkyVector(Sky.Horizontal(altitude: 0, azimuth: 90))
        XCTAssertEqual(a.gliding(towards: b, fraction: 0), a)
        XCTAssertEqual(a.gliding(towards: b, fraction: 1).x, 1, accuracy: 1e-12)
        let half = a.gliding(towards: b, fraction: 0.5)
        XCTAssertEqual(half.length, 1, accuracy: 1e-12)
        XCTAssertEqual(half.horizontal.azimuth, 45, accuracy: 1e-9)
    }
}
