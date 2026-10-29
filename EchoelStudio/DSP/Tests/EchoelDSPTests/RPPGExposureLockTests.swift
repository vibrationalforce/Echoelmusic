import XCTest
@testable import EchoelDSP

/// The exposure-lock policy, stepped tick by tick: it locks only on a dark, steady fingertip,
/// lets go of a washed-out or finger-less lock, re-settles a bright lock that never shows a pulse
/// (twice at most), and makes a phantom lock earn more time before the next one.
final class RPPGExposureLockTests: XCTestCase {

    private func input(finger: Bool = true, brightness: Float = 0.2, red: Float = 0.35,
                       acf: Float = 0.7, confidence: Float = 0.8, windowFull: Bool = true,
                       settled: Bool = true) -> RPPGExposureLock.Input {
        RPPGExposureLock.Input(fingerDetected: finger, brightness: brightness, red: red, autoStrength: acf,
                               confidence: confidence, windowFull: windowFull, settled: settled)
    }

    /// Ticks `input` until an action other than `.none` or `count` ticks pass; returns the
    /// action and the tick it came on (1-based).
    @discardableResult
    private func tick(_ lock: inout RPPGExposureLock, _ input: RPPGExposureLock.Input, upTo count: Int)
        -> (action: RPPGExposureLock.Action, at: Int) {
        for index in 1...count {
            let action = lock.tick(input)
            if action != .none { return (action, index) }
        }
        return (.none, count)
    }

    func testADarkSteadyFingerLocksAfterTwelveTicks() {
        var lock = RPPGExposureLock()
        let result = tick(&lock, input(), upTo: 50)
        XCTAssertEqual(result.action, .lock)
        XCTAssertEqual(result.at, RPPGExposureLock.lockAfterTicks)
        XCTAssertTrue(lock.isLocked)
    }

    func testNoFingerNeverLocks() {
        var lock = RPPGExposureLock()
        XCTAssertEqual(tick(&lock, input(finger: false), upTo: 200).action, .none)
        XCTAssertFalse(lock.isLocked)
    }

    /// 0.4 is under the permissive ceiling but over the strict one: no lock during the first ~6 s
    /// of finger presence, a lock as soon as the strict window has passed.
    func testTheFirstSecondsDemandADarkScene() {
        var lock = RPPGExposureLock()
        let bright = input(brightness: 0.4)
        let result = tick(&lock, bright, upTo: 200)
        XCTAssertEqual(result.action, .lock)
        // The strict window ends on the 60th tick of finger presence, which is the first tick
        // that counts toward the lock; eleven more make twelve.
        XCTAssertEqual(result.at, RPPGExposureLock.strictLockWindowTicks + RPPGExposureLock.lockAfterTicks - 1)
        var flooded = RPPGExposureLock()
        XCTAssertEqual(tick(&flooded, input(brightness: 0.65), upTo: 300).action, .none, "over the permissive ceiling nothing locks")
    }

    func testAWashedOutLockIsHandedBackKeepingTheEstimate() {
        var lock = RPPGExposureLock()
        tick(&lock, input(), upTo: 50)
        let result = tick(&lock, input(brightness: 0.8), upTo: 100)
        XCTAssertEqual(result.action, .unlock(flush: .keepEstimate))
        XCTAssertEqual(result.at, RPPGExposureLock.resettleAfterTicks)
        XCTAssertFalse(lock.isLocked)

        var short = RPPGExposureLock()
        tick(&short, input(), upTo: 50)
        XCTAssertEqual(tick(&short, input(red: 0.95, windowFull: false), upTo: 100).action, .unlock(flush: .none),
                       "a short window is not worth flushing")
    }

    func testALostFingerDropsTheLockAfterThreeSeconds() {
        var lock = RPPGExposureLock()
        tick(&lock, input(), upTo: 50)
        // Hold the lock well past the phantom window first, so this is a real placement.
        tick(&lock, input(), upTo: RPPGExposureLock.quickFailWindowTicks + 10)
        let result = tick(&lock, input(finger: false), upTo: 100)
        XCTAssertEqual(result.action, .unlock(flush: .dropEstimate))
        XCTAssertEqual(result.at, RPPGExposureLock.relockOnLossTicks)
        // A real placement that ended: the next lock needs only the base time again.
        XCTAssertEqual(tick(&lock, input(), upTo: 50).at, RPPGExposureLock.lockAfterTicks)
    }

    /// A lock whose finger vanishes within ~6 s was ambient flicker: the next lock must earn
    /// twice the stable time, the one after that three times.
    func testAPhantomLockStretchesTheNextOne() {
        var lock = RPPGExposureLock()
        XCTAssertEqual(tick(&lock, input(), upTo: 50).at, RPPGExposureLock.lockAfterTicks)
        tick(&lock, input(finger: false), upTo: 100)   // quick fail 1
        XCTAssertEqual(tick(&lock, input(), upTo: 100).at, 2 * RPPGExposureLock.lockAfterTicks)
        tick(&lock, input(finger: false), upTo: 100)   // quick fail 2
        XCTAssertEqual(tick(&lock, input(), upTo: 100).at, 3 * RPPGExposureLock.lockAfterTicks)
        XCTAssertEqual(RPPGExposureLock.requiredStableTicks(base: 12, quickFails: 50), 72, "capped at six times")
    }

    /// A bright lock that fills its window with no pulse evidence is re-settled after ~12 s,
    /// at most twice per placement; after that the window is flushed every ~30 s instead.
    func testAWeakLockIsResettledTwiceThenFlushed() {
        var lock = RPPGExposureLock()
        tick(&lock, input(), upTo: 50)
        let weak = input(acf: 0.05, confidence: 0.1, settled: false)
        var result = tick(&lock, weak, upTo: 500)
        XCTAssertEqual(result.action, .unlock(flush: .dropEstimate))
        XCTAssertEqual(result.at, RPPGExposureLock.weakRelockAfterTicks)
        tick(&lock, input(), upTo: 100)   // re-lock (the strict window restarted, so this takes longer)
        XCTAssertTrue(lock.isLocked)
        result = tick(&lock, weak, upTo: 500)
        XCTAssertEqual(result.action, .unlock(flush: .dropEstimate), "the second re-settle")
        tick(&lock, input(), upTo: 100)
        result = tick(&lock, weak, upTo: 1_000)
        XCTAssertEqual(result.action, .flushWindow, "budget spent: flush, never a third re-settle")
        XCTAssertEqual(result.at, RPPGExposureLock.deadWindowFlushAfterTicks)
        XCTAssertTrue(lock.isLocked, "the exposure stays as it is")
    }

    func testATrustedPulseIsNeverDisturbedAndAFillingWindowIsNotDiagnostic() {
        var lock = RPPGExposureLock()
        tick(&lock, input(), upTo: 50)
        XCTAssertEqual(tick(&lock, input(acf: 0.05, confidence: 0.1, settled: true), upTo: 1_000).action, .none)
        XCTAssertEqual(tick(&lock, input(acf: 0.05, confidence: 0.1, windowFull: false, settled: false), upTo: 1_000).action, .none)
    }

    func testTheResetsForgetEverything() {
        var lock = RPPGExposureLock()
        tick(&lock, input(), upTo: 50)
        lock.sessionReset()
        XCTAssertEqual(lock, RPPGExposureLock())
        tick(&lock, input(), upTo: 50)
        lock.reset()
        XCTAssertEqual(lock, RPPGExposureLock())
    }

    func testThePurePredicates() {
        XCTAssertTrue(RPPGExposureLock.isWashedOut(brightness: 0.73, red: 0.5))
        XCTAssertTrue(RPPGExposureLock.isWashedOut(brightness: 0.3, red: 0.93))
        XCTAssertFalse(RPPGExposureLock.isWashedOut(brightness: 0.72, red: 0.92))
        XCTAssertTrue(RPPGExposureLock.canLockNow(fingerDetected: true, brightness: 0.59))
        XCTAssertFalse(RPPGExposureLock.canLockNow(fingerDetected: true, brightness: 0.6))
        XCTAssertEqual(RPPGExposureLock.lockBrightnessCeiling(fingerPresentTicks: 59), RPPGExposureLock.strictLockBrightness)
        XCTAssertEqual(RPPGExposureLock.lockBrightnessCeiling(fingerPresentTicks: 60), RPPGExposureLock.maxLockBrightness)
        XCTAssertEqual(RPPGExposureLock.weakTicksStep(current: 5, windowFull: true, acf: 0.1, confidence: 0.1, settled: false), 6)
        XCTAssertEqual(RPPGExposureLock.weakTicksStep(current: 5, windowFull: true, acf: 0.5, confidence: 0.1, settled: false), 3)
        XCTAssertEqual(RPPGExposureLock.weakTicksStep(current: 5, windowFull: true, acf: 0.3, confidence: 0.4, settled: false), 5)
        XCTAssertEqual(RPPGExposureLock.weakTicksStep(current: 5, windowFull: false, acf: 0.1, confidence: 0.1, settled: false), 0)
        XCTAssertFalse(RPPGExposureLock.deadWindowNeedsFlush(weakTicks: 400, relocksUsed: 1))
        XCTAssertTrue(RPPGExposureLock.deadWindowNeedsFlush(weakTicks: 300, relocksUsed: 2))
    }
}
