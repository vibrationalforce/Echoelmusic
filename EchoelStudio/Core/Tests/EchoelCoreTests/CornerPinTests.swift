import Foundation
import XCTest
@testable import EchoelCore

/// The projector's corner pin (REC-1): every corner lands exactly where it was set, the picture
/// never folds, and a damaged setting cannot do more than the musician can.
final class CornerPinTests: XCTestCase {
    private let width = 1_920.0
    private let height = 1_080.0

    private func assertClose(_ point: CornerPin.Point?, _ x: Double, _ y: Double,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let point else { return XCTFail("no point", file: file, line: line) }
        XCTAssertEqual(point.x, x, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(point.y, y, accuracy: 1e-6, file: file, line: line)
    }

    func testNoMoveIsTheIdentity() {
        let matrix = CornerPin.none.layerMatrix(width: width, height: height)
        XCTAssertEqual(matrix, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
        assertClose(CornerPin.apply(matrix, x: 300, y: 200), 300, 200)
    }

    func testEveryCornerLandsWhereItWasSet() {
        let pin = CornerPin(topLeft: .init(horizontal: 0.1, vertical: 0.05),
                            topRight: .init(horizontal: 0, vertical: 0.2),
                            bottomRight: .init(horizontal: 0.3, vertical: 0),
                            bottomLeft: .init(horizontal: 0.05, vertical: 0.1))
        let matrix = pin.layerMatrix(width: width, height: height)
        let targets = pin.corners(width: width, height: height)
        let sources: [(Double, Double)] = [(0, 0), (width, 0), (width, height), (0, height)]
        for (source, target) in zip(sources, targets) {
            assertClose(CornerPin.apply(matrix, x: source.0, y: source.1), target.x, target.y)
        }
        assertClose(targets.first, 192, 54)
        assertClose(targets.last, 96, 972)
    }

    func testAnEvenInsetShrinksAboutTheMiddle() {
        let inset = CornerPin.Inset(horizontal: 0.1, vertical: 0.1)
        let pin = CornerPin(topLeft: inset, topRight: inset, bottomRight: inset, bottomLeft: inset)
        let matrix = pin.layerMatrix(width: width, height: height)
        assertClose(CornerPin.apply(matrix, x: width / 2, y: height / 2), width / 2, height / 2)
        assertClose(CornerPin.apply(matrix, x: 0, y: 0), 192, 108)
        // A pure scale: no perspective term.
        XCTAssertEqual(matrix[3], 0, accuracy: 1e-12)
        XCTAssertEqual(matrix[7], 0, accuracy: 1e-12)
    }

    func testAKeystoneKeepsStraightLinesStraight() {
        // The classic projector tilt: the top is wider on the wall, so the top corners move in.
        let pin = CornerPin(topLeft: .init(horizontal: 0.15), topRight: .init(horizontal: 0.15))
        let matrix = pin.layerMatrix(width: width, height: height)
        // The picture's left edge stays a straight line from its top corner to its bottom one.
        guard let top = CornerPin.apply(matrix, x: 0, y: 0), let bottom = CornerPin.apply(matrix, x: 0, y: height),
              let middle = CornerPin.apply(matrix, x: 0, y: height / 2) else { return XCTFail("no points") }
        let cross = (bottom.x - top.x) * (middle.y - top.y) - (bottom.y - top.y) * (middle.x - top.x)
        XCTAssertEqual(cross, 0, accuracy: 1e-6)
        // And the middle of the picture moves up toward the narrower edge, as perspective does.
        XCTAssertLessThan(CornerPin.apply(matrix, x: width / 2, y: height / 2)?.y ?? .infinity, height / 2)
    }

    func testAMoveStopsAtTheMaximumAndNotANumberIsNoMove() {
        let inset = CornerPin.Inset(horizontal: 0.9, vertical: .nan)
        XCTAssertEqual(inset.horizontal, CornerPin.maximumInset)
        XCTAssertEqual(inset.vertical, 0)
        XCTAssertEqual(CornerPin.Inset(horizontal: -0.2, vertical: .infinity).horizontal, 0)
        XCTAssertEqual(CornerPin.Inset(horizontal: -0.2, vertical: .infinity).vertical, 0)
    }

    func testTheLargestMovesNeverFoldThePicture() {
        // Every corner at either end of its range: 256 settings, each must give a convex picture.
        let ends = [0.0, CornerPin.maximumInset]
        var count = 0
        for mask in 0..<256 {
            func end(_ bit: Int) -> Double { ends[(mask >> bit) & 1] }
            let pin = CornerPin(topLeft: .init(horizontal: end(0), vertical: end(1)),
                                topRight: .init(horizontal: end(2), vertical: end(3)),
                                bottomRight: .init(horizontal: end(4), vertical: end(5)),
                                bottomLeft: .init(horizontal: end(6), vertical: end(7)))
            XCTAssertNotNil(CornerPin.projection(toQuad: pin.corners(width: width, height: height)), "mask \(mask)")
            count += 1
        }
        XCTAssertEqual(count, 256)
    }

    func testAFoldedOrBrokenQuadHasNoProjection() {
        let crossed = [CornerPin.Point(x: 0, y: 0), CornerPin.Point(x: 100, y: 100),
                       CornerPin.Point(x: 100, y: 0), CornerPin.Point(x: 0, y: 100)]
        XCTAssertNil(CornerPin.projection(toQuad: crossed))
        let flat = [CornerPin.Point(x: 0, y: 0), CornerPin.Point(x: 50, y: 0),
                    CornerPin.Point(x: 100, y: 0), CornerPin.Point(x: 0, y: 100)]
        XCTAssertNil(CornerPin.projection(toQuad: flat))
        let broken = [CornerPin.Point(x: .nan, y: 0), CornerPin.Point(x: 100, y: 0),
                      CornerPin.Point(x: 100, y: 100), CornerPin.Point(x: 0, y: 100)]
        XCTAssertNil(CornerPin.projection(toQuad: broken))
        XCTAssertNil(CornerPin.projection(toQuad: Array(broken.prefix(3))))
    }

    func testAnEmptyOrBrokenSizeGivesTheIdentity() {
        let pin = CornerPin(topLeft: .init(horizontal: 0.1, vertical: 0.1))
        let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        XCTAssertEqual(pin.layerMatrix(width: 0, height: height), identity)
        XCTAssertEqual(pin.layerMatrix(width: width, height: .nan), identity)
        XCTAssertEqual(pin.layerMatrix(width: -1, height: -1), identity)
    }

    func testAStoredSettingComesBackAndADamagedOneIsClamped() throws {
        var pin = CornerPin.none
        pin[.bottomRight] = .init(horizontal: 0.12, vertical: 0.04)
        let data = try JSONEncoder().encode(pin)
        XCTAssertEqual(try JSONDecoder().decode(CornerPin.self, from: data), pin)
        let damaged = Data(#"{"topLeft":{"horizontal":7,"vertical":-3}}"#.utf8)
        let decoded = try JSONDecoder().decode(CornerPin.self, from: damaged)
        XCTAssertEqual(decoded.topLeft, CornerPin.Inset(horizontal: CornerPin.maximumInset, vertical: 0))
        XCTAssertEqual(decoded.topRight, .zero)
    }

    func testTheSubscriptReachesEachCorner() {
        var pin = CornerPin.none
        for (index, corner) in CornerPin.Corner.allCases.enumerated() {
            pin[corner] = .init(horizontal: Double(index + 1) / 100, vertical: 0)
        }
        XCTAssertEqual(pin.topLeft.horizontal, 0.01, accuracy: 1e-12)
        XCTAssertEqual(pin.topRight.horizontal, 0.02, accuracy: 1e-12)
        XCTAssertEqual(pin.bottomRight.horizontal, 0.03, accuracy: 1e-12)
        XCTAssertEqual(pin.bottomLeft.horizontal, 0.04, accuracy: 1e-12)
        XCTAssertFalse(pin.isIdentity)
    }
}
