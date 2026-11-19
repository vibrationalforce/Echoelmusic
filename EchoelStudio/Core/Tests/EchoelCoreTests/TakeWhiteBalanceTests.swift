import Foundation
import XCTest
@testable import EchoelCore

final class TakeWhiteBalanceTests: XCTestCase {
    func testTheChoicesRunFromTungstenToShade() {
        XCTAssertEqual(TakeWhiteBalance.kelvins, [3200, 4000, 5600, 6500, 7500])
        XCTAssertEqual(TakeWhiteBalance.label(nil), "Auto")
        XCTAssertEqual(TakeWhiteBalance.label(5600), "5600 K")
    }

    func testGainsStayInsideWhatTheLensAccepts() {
        let gains = TakeWhiteBalance.Gains(red: 0.4, green: 1.7, blue: 9)
        XCTAssertEqual(TakeWhiteBalance.clampedGains(gains, maximum: 4), TakeWhiteBalance.Gains(red: 1, green: 1.7, blue: 4))
    }

    func testANumberThatIsNoNumberChangesNothing() {
        let gains = TakeWhiteBalance.Gains(red: .nan, green: .infinity, blue: 2)
        XCTAssertEqual(TakeWhiteBalance.clampedGains(gains, maximum: 4), TakeWhiteBalance.Gains(red: 1, green: 1, blue: 2))
        XCTAssertEqual(TakeWhiteBalance.clampedGains(gains, maximum: .nan), TakeWhiteBalance.Gains(red: 1, green: 1, blue: 1))
        XCTAssertEqual(TakeWhiteBalance.clampedGains(gains, maximum: 0.5), TakeWhiteBalance.Gains(red: 1, green: 1, blue: 1))
    }
}
