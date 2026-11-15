import XCTest
@testable import EchoelCore

/// Which place the sky is drawn from: a chosen place stays when a fix arrives later; "Here" goes
/// back to the newest fix; a remembered place gives way to a fix.
final class SkyPlaceTests: XCTestCase {
    func testAChosenPlaceStaysWhenALocationFixArrivesLater() {
        var place = SkyPlace()
        XCTAssertTrue(place.choose("Tokyo", latitude: 35.68, longitude: 139.69))
        XCTAssertFalse(place.located(latitude: 53.6, longitude: 10.0), "the fix does not take the chosen sky away")
        XCTAssertEqual(place.source, .chosen("Tokyo"))
        XCTAssertEqual(place.latitude, 35.68)
        XCTAssertEqual(place.longitude, 139.69)
        XCTAssertEqual(place.chosenName, "Tokyo")
    }

    func testHereGoesBackToTheNewestFix() {
        var place = SkyPlace()
        place.choose("Tokyo", latitude: 35.68, longitude: 139.69)
        XCTAssertFalse(place.located(latitude: 53.6, longitude: 10.0))
        XCTAssertFalse(place.located(latitude: 48.9, longitude: 2.4))
        place.choose("Sydney", latitude: -33.87, longitude: 151.21)
        place.useHere()
        XCTAssertEqual(place.source, .located)
        XCTAssertEqual(place.latitude, 48.9, "the newest fix, not the first")
        XCTAssertEqual(place.longitude, 2.4)
        XCTAssertNil(place.chosenName)
    }

    func testHereWithoutAFixFallsBackToTheRememberedPlace() {
        var place = SkyPlace()
        place.remember(latitude: 53.6, longitude: 10.0)
        place.choose("Tokyo", latitude: 35.68, longitude: 139.69)
        XCTAssertTrue(place.hasRememberedPlace)
        place.useHere()
        XCTAssertEqual(place.source, .remembered, "the sky stays drawn")
        XCTAssertEqual(place.latitude, 53.6)
        XCTAssertEqual(place.longitude, 10.0)
        var remembered = SkyPlace()
        remembered.remember(latitude: 53.6, longitude: 10.0)
        remembered.useHere()
        XCTAssertEqual(remembered.source, .remembered)
        XCTAssertEqual(remembered.latitude, 53.6)
    }

    func testHereWithNothingKnownWaitsForTheNextFix() {
        var place = SkyPlace()
        place.choose("Berlin", latitude: 52.52, longitude: 13.40)
        XCTAssertFalse(place.hasRememberedPlace)
        place.useHere()
        XCTAssertEqual(place.source, .none, "nothing to show until a fix arrives")
        XCTAssertNil(place.latitude)
        XCTAssertTrue(place.located(latitude: 48.9, longitude: 2.4))
        XCTAssertEqual(place.source, .located)
    }

    func testARememberedPlaceGivesWayToAFixButNotTheOtherWayRound() {
        var place = SkyPlace()
        XCTAssertTrue(place.remember(latitude: 53.6, longitude: 10.0))
        XCTAssertEqual(place.source, .remembered)
        XCTAssertTrue(place.located(latitude: 48.9, longitude: 2.4))
        XCTAssertEqual(place.source, .located)
        XCTAssertFalse(place.remember(latitude: 1, longitude: 1), "an old place never replaces a fix")
        XCTAssertEqual(place.latitude, 48.9)
        var chosen = SkyPlace()
        chosen.choose("London", latitude: 51.51, longitude: -0.13)
        XCTAssertFalse(chosen.remember(latitude: 53.6, longitude: 10.0), "nor a chosen place")
    }

    func testCoordinatesOffTheGlobeAndAnEmptyNameAreRefused() {
        var place = SkyPlace()
        XCTAssertFalse(place.choose("", latitude: 0, longitude: 0))
        XCTAssertFalse(place.choose("Nowhere", latitude: 91, longitude: 0))
        XCTAssertFalse(place.located(latitude: .nan, longitude: 0))
        XCTAssertFalse(place.remember(latitude: 0, longitude: 181))
        XCTAssertEqual(place, SkyPlace(), "nothing changed")
    }

    func testHereNamesTheSkyItWillLandOn() {
        var place = SkyPlace()
        XCTAssertEqual(place.hereSource, .none)
        place.remember(latitude: 53.6, longitude: 10.0)
        XCTAssertEqual(place.hereSource, .remembered)
        place.choose("Tokyo", latitude: 35.68, longitude: 139.69)
        place.located(latitude: 48.9, longitude: 2.4)
        XCTAssertEqual(place.hereSource, .located, "this time's fix comes before the remembered place")
        let landing = place.hereSource
        place.useHere()
        XCTAssertEqual(place.source, landing, "the way back lands where its name said")
        var remembered = SkyPlace()
        remembered.remember(latitude: 53.6, longitude: 10.0)
        remembered.choose("Tokyo", latitude: 35.68, longitude: 139.69)
        let back = remembered.hereSource
        remembered.useHere()
        XCTAssertEqual(remembered.source, back)
        XCTAssertEqual(back, .remembered)
    }

    func testTheGlobesEdgesAreOnItAndInfinityIsNot() {
        var place = SkyPlace()
        XCTAssertTrue(place.located(latitude: 90, longitude: 180))
        XCTAssertTrue(place.located(latitude: -90, longitude: -180))
        XCTAssertFalse(place.remember(latitude: .infinity, longitude: 0))
        XCTAssertFalse(place.choose("X", latitude: 0, longitude: -.infinity))
    }
}
