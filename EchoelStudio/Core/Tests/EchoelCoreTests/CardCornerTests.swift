import XCTest
@testable import EchoelCore

/// The corner a floating card rests in: a real drag crosses to the other side, a slip stays, each
/// axis on its own, and going round visits every corner once.
final class CardCornerTests: XCTestCase {
    private let far = CardCorner.crossingDistance
    private let near = CardCorner.crossingDistance - 1

    func testADragAcrossMovesTheCardToTheOtherSide() {
        let start = CardCorner.bottomTrailing
        XCTAssertEqual(start.moved(towardTrailing: -far, down: 0), .bottomLeading)
        XCTAssertEqual(start.moved(towardTrailing: 0, down: -far), .topTrailing)
        XCTAssertEqual(start.moved(towardTrailing: -far, down: -far), .topLeading, "both axes at once")
        XCTAssertEqual(CardCorner.topLeading.moved(towardTrailing: far, down: far), .bottomTrailing)
    }

    func testAShortDragLeavesTheCardWhereItWas() {
        for corner in CardCorner.allCases {
            XCTAssertEqual(corner.moved(towardTrailing: near, down: near), corner, corner.rawValue)
            XCTAssertEqual(corner.moved(towardTrailing: -near, down: -near), corner, corner.rawValue)
            XCTAssertEqual(corner.moved(towardTrailing: 0, down: 0), corner, corner.rawValue)
        }
    }

    func testADragFurtherIntoItsOwnCornerStays() {
        XCTAssertEqual(CardCorner.bottomTrailing.moved(towardTrailing: 500, down: 500), .bottomTrailing)
        XCTAssertEqual(CardCorner.topLeading.moved(towardTrailing: -500, down: -500), .topLeading)
    }

    func testADistanceThatIsNoNumberMovesNothing() {
        for corner in CardCorner.allCases {
            XCTAssertEqual(corner.moved(towardTrailing: Double.nan, down: Double.nan), corner, corner.rawValue)
            XCTAssertEqual(corner.moved(towardTrailing: Double.infinity, down: -Double.infinity), corner, corner.rawValue)
        }
    }

    func testGoingRoundVisitsEveryCornerOnce() {
        var seen: [CardCorner] = []
        var corner = CardCorner.bottomTrailing
        for _ in CardCorner.allCases {
            seen.append(corner)
            corner = corner.next
        }
        XCTAssertEqual(Set(seen).count, CardCorner.allCases.count)
        XCTAssertEqual(corner, .bottomTrailing, "and comes back to where it began")
    }

    func testACardStepsAsideFromATakenCorner() {
        XCTAssertEqual(CardCorner.bottomLeading.avoiding(.bottomLeading), .bottomTrailing)
        XCTAssertEqual(CardCorner.topTrailing.avoiding(.topTrailing), .topLeading)
        XCTAssertEqual(CardCorner.bottomTrailing.avoiding(.bottomLeading), .bottomTrailing, "another corner is taken: it stays")
        XCTAssertEqual(CardCorner.bottomLeading.avoiding(nil), .bottomLeading)
    }

    /// The corner is kept on the device by its name: the names stay as they are.
    func testTheCornersKeepTheirStoredNames() {
        XCTAssertEqual(CardCorner.allCases.map(\.rawValue), ["topLeading", "topTrailing", "bottomLeading", "bottomTrailing"])
        XCTAssertEqual(CardCorner(rawValue: "bottomTrailing"), .bottomTrailing)
        XCTAssertNil(CardCorner(rawValue: "middle"))
    }
}
