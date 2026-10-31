import XCTest
@testable import EchoelCore

/// The bundled star table against what the catalogue says of well-known stars, and the plain
/// numbers (brightness, colour) a route or a renderer reads from a star.
final class StarCatalogTests: XCTestCase {
    func testTheTableHoldsTheNakedEyeSky() {
        let stars = StarCatalog.stars
        XCTAssertGreaterThan(stars.count, 2_800, "every star to magnitude 5.5")
        XCTAssertLessThan(stars.count, 3_000)
        XCTAssertTrue(stars.allSatisfy { $0.magnitude <= StarCatalog.faintestMagnitude })
        XCTAssertTrue(stars.allSatisfy { (0..<360).contains($0.rightAscension) && abs($0.declination) <= 90 })
        XCTAssertEqual(Set(stars.map(\.id)).count, stars.count, "one row per catalogue number")
    }

    func testWellKnownStarsStandWhereTheCatalogueSays() throws {
        let sirius = try XCTUnwrap(StarCatalog.stars.first { $0.name == "Sirius" })
        XCTAssertEqual(sirius.id, 2_491)
        XCTAssertEqual(sirius.rightAscension, 101.2871, accuracy: 0.001)   // 6h45m08.9s
        XCTAssertEqual(sirius.declination, -16.7161, accuracy: 0.001)      // −16°42'58"
        XCTAssertEqual(sirius.magnitude, -1.46, accuracy: 1e-9)
        let polaris = try XCTUnwrap(StarCatalog.stars.first { $0.id == 424 })
        XCTAssertEqual(polaris.name, "Polaris")
        XCTAssertEqual(polaris.declination, 89.2642, accuracy: 0.001)
        let betelgeuse = try XCTUnwrap(StarCatalog.stars.first { $0.name == "Betelgeuse" })
        XCTAssertEqual(try XCTUnwrap(betelgeuse.colorIndex), 1.85, accuracy: 1e-9)
    }

    func testTheBrightestStarInTheTableIsSirius() throws {
        let brightest = try XCTUnwrap(StarCatalog.stars.min { $0.magnitude < $1.magnitude })
        XCTAssertEqual(brightest.name, "Sirius")
    }

    func testANameNamesOneStar() {
        let names = StarCatalog.stars.compactMap(\.name)
        XCTAssertGreaterThan(names.count, 100)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testALineThatIsNotAStarIsSkipped() {
        let parsed = StarCatalog.parse("1 10.5 20.25 3.10 0.50 Testa\nnot a star\n2 400 0 1 0\n3 1 2 4.00 -")
        XCTAssertEqual(parsed.map(\.id), [1, 3])
        XCTAssertEqual(parsed.first?.name, "Testa")
        XCTAssertNil(parsed.last?.colorIndex, "a missing index is absent, not zero")
        XCTAssertNil(parsed.last?.name)
    }

    func testBrightnessRunsFromTheBrightestStarToTheTablesLimit() {
        XCTAssertEqual(StarCatalog.brightness(magnitude: -1.5), 1)
        XCTAssertEqual(StarCatalog.brightness(magnitude: -4.4), 1, "Venus is brighter than the scale")
        XCTAssertEqual(StarCatalog.brightness(magnitude: 5.5), 0)
        XCTAssertEqual(StarCatalog.brightness(magnitude: 7), 0)
        XCTAssertEqual(StarCatalog.brightness(magnitude: 2), 0.5)
        XCTAssertNil(StarCatalog.brightness(magnitude: .nan))
    }

    func testColourPositionRunsFromBlueToRed() {
        XCTAssertEqual(StarCatalog.colorPosition(colorIndex: -0.4), 0)
        XCTAssertEqual(StarCatalog.colorPosition(colorIndex: 2.0), 1)
        XCTAssertEqual(StarCatalog.colorPosition(colorIndex: 0.8) ?? -1, 0.5, accuracy: 1e-12)
        XCTAssertNil(StarCatalog.colorPosition(colorIndex: .infinity))
    }

    /// Ballesteros 2012: B−V 0 is about 10 000 K, the Sun's 0.65 about 5 800 K; redder is cooler.
    func testTheColourIndexStandsForATemperature() throws {
        XCTAssertEqual(try XCTUnwrap(StarCatalog.temperature(colorIndex: 0)), 10_125, accuracy: 10)
        XCTAssertEqual(try XCTUnwrap(StarCatalog.temperature(colorIndex: 0.65)), 5_800, accuracy: 120)
        let hot = try XCTUnwrap(StarCatalog.temperature(colorIndex: -0.2))
        let cool = try XCTUnwrap(StarCatalog.temperature(colorIndex: 1.5))
        XCTAssertGreaterThan(hot, cool)
        XCTAssertNil(StarCatalog.temperature(colorIndex: 3))
    }

    func testAHotStarIsDrawnBluerThanACoolOne() {
        let hot = StarCatalog.color(colorIndex: -0.2)
        let cool = StarCatalog.color(colorIndex: 1.6)
        XCTAssertGreaterThan(hot.blue - hot.red, cool.blue - cool.red)
        XCTAssertEqual(StarCatalog.color(colorIndex: nil), StarCatalog.Color(red: 1, green: 1, blue: 1))
        for index in stride(from: -0.4, through: 2.0, by: 0.1) {
            let color = StarCatalog.color(colorIndex: index)
            for channel in [color.red, color.green, color.blue] {
                XCTAssertTrue((0...1).contains(channel), "\(index)")
            }
        }
    }
}
