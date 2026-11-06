import Foundation
import XCTest
@testable import EchoelCore

/// A universe's frames are numbered on, never over, within one run (Q2): a receiver drops frames
/// whose number runs backwards.
final class WireSequencesTests: XCTestCase {
    func testSACNCountsOnAndWrapsThroughZero() {
        var sequences = WireSequences()
        var numbers: [UInt8] = []
        for _ in 0..<300 { numbers.append(sequences.next(.sacn, universe: 1)) }
        XCTAssertEqual(numbers.first, 1)
        XCTAssertEqual(numbers[254], 255)
        XCTAssertEqual(numbers[255], 0, "sACN wraps 255 to 0")
        XCTAssertEqual(numbers[256], 1)
        for index in 1..<numbers.count {
            XCTAssertEqual(numbers[index], numbers[index - 1] &+ 1, "frame \(index) steps on by one")
        }
    }

    func testArtNetNeverSaysZero() {
        var sequences = WireSequences()
        var numbers: [UInt8] = []
        for _ in 0..<600 { numbers.append(sequences.next(.artNet, universe: 0)) }
        XCTAssertFalse(numbers.contains(0), "0 would tell the node the sender does not sequence")
        XCTAssertEqual(numbers[254], 255)
        XCTAssertEqual(numbers[255], 1)
    }

    func testEachUniverseAndProtocolCountsOnItsOwn() {
        var sequences = WireSequences()
        XCTAssertEqual(sequences.next(.sacn, universe: 1), 1)
        XCTAssertEqual(sequences.next(.sacn, universe: 1), 2)
        XCTAssertEqual(sequences.next(.sacn, universe: 2), 1, "another universe has its own count")
        XCTAssertEqual(sequences.next(.artNet, universe: 1), 1, "another protocol has its own count")
        XCTAssertEqual(sequences.next(.sacn, universe: 1), 3, "the first universe went on where it stood")
    }

    func testAPauseInTheStreamIsNotARestart() {
        // Switched off after 254 frames, the dark frames and three goodbyes, then on again later:
        // the same counter goes on, across the wrap.
        var sequences = WireSequences()
        var last: UInt8 = 0
        for _ in 0..<254 { last = sequences.next(.sacn, universe: 7) }
        for _ in 0..<4 { _ = sequences.next(.sacn, universe: 3) }
        let afterPause = sequences.next(.sacn, universe: 7)
        XCTAssertEqual(afterPause, last &+ 1)
        XCTAssertEqual(sequences.next(.sacn, universe: 7), 0)
    }
}
