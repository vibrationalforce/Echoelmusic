import XCTest
@testable import EchoelDSP

/// The one bar a camera pulse clears before it is shown or moves anything.
final class PulseTrustTests: XCTestCase {
    func testConfidentAndCorroboratedIsTrusted() {
        XCTAssertTrue(PulseTrust.isTrustworthy(confidence: 0.6, autoStrength: 0.4))
        XCTAssertTrue(PulseTrust.isTrustworthy(confidence: 0.9, autoStrength: 0.5))
    }

    /// The peak counter agreeing with itself on a badly placed finger: high confidence, no
    /// periodicity. The device case that showed a wrong 79 bpm against a true 54.
    func testConfidentWithoutPeriodicityIsJunk() {
        XCTAssertFalse(PulseTrust.isTrustworthy(confidence: 0.9, autoStrength: 0.14))
        XCTAssertFalse(PulseTrust.isTrustworthy(confidence: 0.9, autoStrength: 0.39))
    }

    /// Strong periodicity proves the pulse on its own, however low the confidence sits.
    func testStrongPeriodicityStandsAlone() {
        XCTAssertTrue(PulseTrust.isTrustworthy(confidence: 0.01, autoStrength: 0.6))
        XCTAssertFalse(PulseTrust.isTrustworthy(confidence: 0.01, autoStrength: 0.59))
    }

    func testBothLowIsNothing() {
        XCTAssertFalse(PulseTrust.isTrustworthy(confidence: 0.3, autoStrength: 0.3))
        XCTAssertFalse(PulseTrust.isTrustworthy(confidence: .nan, autoStrength: 0.9))
    }

    func testPublishingNeedsARate() {
        XCTAssertFalse(PulseTrust.shouldPublish(bpm: 0, confidence: 0.9, autoStrength: 0.9))
        XCTAssertFalse(PulseTrust.shouldPublish(bpm: .nan, confidence: 0.9, autoStrength: 0.9))
        XCTAssertTrue(PulseTrust.shouldPublish(bpm: 62, confidence: 0.9, autoStrength: 0.9))
    }

    /// The channel quality is the stronger witness, so a strongly periodic reading at low
    /// confidence still clears a 0.6 floor; an untrusted reading has none.
    func testQualityIsTheStrongerWitnessOrNothing() {
        XCTAssertEqual(PulseTrust.quality(confidence: 0.01, autoStrength: 0.7), 0.7)
        XCTAssertEqual(PulseTrust.quality(confidence: 0.8, autoStrength: 0.45), 0.8)
        XCTAssertEqual(PulseTrust.quality(confidence: 0.9, autoStrength: 0.1), 0)
    }
}
