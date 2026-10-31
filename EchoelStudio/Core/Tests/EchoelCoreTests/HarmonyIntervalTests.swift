import XCTest
@testable import EchoelCore

final class HarmonyIntervalTests: XCTestCase {
    /// Every choice is a harmony: no second, seventh or tritone, every one named in words.
    func testEveryChoiceIsANamedHarmony() {
        let offered = HarmonyInterval.allCases.compactMap(\.semitones).map { abs($0) % 12 }
        for dissonant in [1, 2, 6, 10, 11] { XCTAssertFalse(offered.contains(dissonant), "\(dissonant)") }
        XCTAssertEqual(Set(HarmonyInterval.allCases.map(\.title)).count, HarmonyInterval.allCases.count)
        for interval in HarmonyInterval.allCases {
            XCTAssertFalse(interval.title.contains(where: \.isNumber), interval.title)
        }
        XCTAssertNil(HarmonyInterval.off.semitones)
        XCTAssertEqual(HarmonyInterval.fifthUp.semitones, 7)
    }

    func testAStoredIndexReadsBackAndAnUnknownOneIsOff() {
        for interval in HarmonyInterval.allCases {
            XCTAssertEqual(HarmonyInterval(index: Float(interval.rawValue)), interval)
        }
        XCTAssertEqual(HarmonyInterval(index: 12.2), .fifthUp)
        for bad: Float in [-1, 99, .nan, .infinity] { XCTAssertEqual(HarmonyInterval(index: bad), .off) }
    }
}
