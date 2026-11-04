import Foundation
import XCTest
@testable import EchoelCore

/// The Field's light as its own transparency (PRO-W2 slice 3).
final class FieldAlphaKeyTests: XCTestCase {
    func testBlackIsTransparentAndTheBrightestChannelIsTheAlpha() {
        XCTAssertTrue(FieldAlphaKey.key(b: 0, g: 0, r: 0) == (0, 0, 0, 0))
        XCTAssertTrue(FieldAlphaKey.key(b: 255, g: 10, r: 0) == (255, 10, 0, 255))
        let half = FieldAlphaKey.key(b: 64, g: 128, r: 32)
        XCTAssertEqual(half.a, 128)
        XCTAssertEqual(half.g, 255, "the brightest channel lifts to full")
        XCTAssertEqual(half.b, 128)
        XCTAssertEqual(half.r, 64)
    }

    func testOverBlackGivesBackTheFieldAsDrawn() {
        // Every pixel, laid over black, is within one step of what Echoel drew.
        for value in stride(from: 0, through: 255, by: 5) {
            for other in [0, 1, 17, 100, 255] where other <= value {
                let b = UInt8(value), g = UInt8(other), r = UInt8(other / 2)
                let keyed = FieldAlphaKey.key(b: b, g: g, r: r)
                for (drawn, lifted) in [(b, keyed.b), (g, keyed.g), (r, keyed.r)] {
                    let back = FieldAlphaKey.over(lifted, alpha: keyed.a, under: 0)
                    XCTAssertLessThanOrEqual(abs(Int(back) - Int(drawn)), 1, "\(b) \(g) \(r)")
                }
            }
        }
    }

    func testAnImageIsKeyedRowByRowAndThePaddingIsLeft() {
        // Two rows of two pixels, each row padded to 12 bytes.
        var bytes: [UInt8] = [0, 0, 0, 9, 100, 50, 0, 9, 77, 77,
                              255, 0, 0, 255, 255, 0, 7, 7, 7, 7, 66, 66, 66, 66]
        bytes.withUnsafeMutableBytes { FieldAlphaKey.keyBGRA($0, width: 2, height: 2, bytesPerRow: 12) }
        XCTAssertEqual(Array(bytes[0..<8]), [0, 0, 0, 0, 255, 128, 0, 100])
        XCTAssertEqual(Array(bytes[8..<12]), [77, 77, 255, 0], "padding untouched")
        XCTAssertEqual(Array(bytes[12..<20]), [0, 255, 255, 255, 255, 255, 255, 7])
        XCTAssertEqual(Array(bytes[20..<24]), [66, 66, 66, 66])
        // A size the buffer cannot hold changes nothing past it.
        var short: [UInt8] = [10, 20, 30, 40]
        short.withUnsafeMutableBytes { FieldAlphaKey.keyBGRA($0, width: 2, height: 1, bytesPerRow: 8) }
        XCTAssertEqual(short, [10, 20, 30, 40])
    }
}
