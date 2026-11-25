import AudioToolbox
import AVFoundation
import Synchronization
import XCTest
@testable import EchoelHost

/// The deadline on a unit's start (`UnitInstantiation`): the first of the answer and the deadline
/// is the answer, and whatever comes second changes nothing.
final class UnitInstantiationTests: XCTestCase {
    func testAnAnswerBeforeTheDeadlineIsTheAnswer() async {
        let value = await UnitInstantiation.answer(within: .seconds(5), timedOut: -1) { reply in
            DispatchQueue.global().async { reply(7) }
        }
        XCTAssertEqual(value, 7)
    }

    func testARequestThatNeverAnswersEndsAtTheDeadline() async {
        let clock = ContinuousClock()
        let start = clock.now
        let value = await UnitInstantiation.answer(within: .milliseconds(100), timedOut: -1) { _ in }
        XCTAssertEqual(value, -1)
        XCTAssertGreaterThanOrEqual(start.duration(to: clock.now), .milliseconds(100))
    }

    func testAnAnswerAfterTheDeadlineIsIgnored() async throws {
        let late = expectation(description: "the late answer was sent")
        let value = await UnitInstantiation.answer(within: .milliseconds(50), timedOut: -1) { reply in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                reply(7)
                late.fulfill()
            }
        }
        XCTAssertEqual(value, -1)
        // The late answer must not resume the continuation a second time (that would trap).
        await fulfillment(of: [late], timeout: 5)
    }

    func testOnlyTheFirstOfTwoAnswersCounts() async {
        let value = await UnitInstantiation.answer(within: .seconds(5), timedOut: -1) { reply in
            reply(1)
            reply(2)
        }
        XCTAssertEqual(value, 1)
    }

    /// Apple's Low Pass through the system's asynchronous instantiation, as the host loads every
    /// unit: it starts well inside the deadline.
    func testAnAppleUnitStartsInsideTheDeadline() async throws {
        final class Box: @unchecked Sendable {
            let unit: AUAudioUnit?
            init(_ unit: AUAudioUnit?) { self.unit = unit }
        }
        let description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_LowPassFilter,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        let box = await UnitInstantiation.answer(within: UnitInstantiation.deadline, timedOut: Box(nil)) { reply in
            AUAudioUnit.instantiate(with: description, options: []) { @Sendable unit, _ in reply(Box(unit)) }
        }
        XCTAssertNotNil(box.unit)
    }
}
