import XCTest
@testable import EchoelEngine

final class AudioRecoveryPolicyTests: XCTestCase {
    func testAFailedStartIsTriedAgainAFewTimesEachWaitLonger() {
        var policy = AudioRecoveryPolicy()
        var waits: [Duration] = []
        while let wait = policy.failed() { waits.append(wait) }
        XCTAssertEqual(waits.count, AudioRecoveryPolicy.retryLimit)
        XCTAssertEqual(waits.first, AudioRecoveryPolicy.settle)
        XCTAssertEqual(waits, waits.sorted(), "each wait at least as long as the one before")
        XCTAssertGreaterThan(waits.last ?? .zero, waits.first ?? .zero)
        XCTAssertNil(policy.failed(), "used up, it stays used up until something changes")
    }

    func testAnEventThatCanChangeTheOutcomeStartsTheCountAgain() {
        var policy = AudioRecoveryPolicy()
        while policy.failed() != nil {}
        policy.reset()
        XCTAssertEqual(policy.failures, 0)
        XCTAssertEqual(policy.failed(), AudioRecoveryPolicy.settle)
    }
}
