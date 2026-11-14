import Foundation
import XCTest
@testable import EchoelCore

/// The camera layer's rules: how the exposure follows the dark fluidly, where focus waits, how strongly the layer shows, how the
/// stack weighs a new frame, how a turn of the phone shifts it, and the field of view that lines
/// the drawn stars up with the camera's picture.
final class SkyNightCameraTests: XCTestCase {
    private let limits = SkyNightCamera.Limits(minDuration: 1.0 / 8000, maxDuration: 1, minISO: 50, maxISO: 3200)
    /// Automatic exposure at night: its frame time at half the highest gain, near its limit.
    private let nightReading = (1.0 / 30, 1600.0)

    private func next(_ current: SkyNightCamera.Exposure, luma: Double, reading: (Double, Double)? = nil,
                      after seconds: Double = 1, frames: Int = 3, clipped: Int = 0) -> SkyNightCamera.Exposure {
        let read = reading ?? nightReading
        return SkyNightCamera.nextExposure(current: current, luma: luma, reading: (duration: read.0, iso: read.1),
                                           limits: limits, secondsSinceLastStep: seconds, framesSinceLastStep: frames,
                                           clippedFramesInARow: clipped)
    }

    private func value(_ exposure: SkyNightCamera.Exposure) -> Double? {
        if case let .manual(duration, iso) = exposure { return duration * iso }
        return nil
    }

    private func duration(_ exposure: SkyNightCamera.Exposure) -> Double? {
        if case let .manual(duration, _) = exposure { return duration }
        return nil
    }

    func testInTheDarkTheExposureTakesOverNearAutomaticsLimitAndRisesByAtMostOneAndAHalf() throws {
        XCTAssertEqual(next(.automatic, luma: 0.5), .automatic, "a bright scene stays automatic")
        XCTAssertEqual(next(.automatic, luma: 0.02, reading: (1.0 / 100, 100)), .automatic,
                       "automatic exposure still has room: a dark start-up frame is no reason to take over")
        let first = next(.automatic, luma: 0.02)
        let taken = try XCTUnwrap(value(first), "the dark hands the exposure to the hand-set mode")
        let automatic = nightReading.0 * nightReading.1
        XCTAssertGreaterThan(taken, automatic, "it starts brighter than automatic exposure")
        XCTAssertLessThanOrEqual(taken, automatic * SkyNightCamera.maximumStep * (1 + 1e-9),
                                 "never more than one and a half times the light of automatic exposure")
        let second = next(first, luma: 0.02)
        let more = try XCTUnwrap(value(second))
        XCTAssertGreaterThan(more, taken)
        XCTAssertLessThanOrEqual(more, taken * SkyNightCamera.maximumStep * (1 + 1e-9))
    }

    func testTheFrameTimeNeverJumpsAcrossTheTakeoverOrAStep() throws {
        var exposure = SkyNightCamera.Exposure.automatic
        var time = nightReading.0
        for _ in 0..<16 {
            exposure = next(exposure, luma: 0.01)
            let now = try XCTUnwrap(duration(exposure))
            XCTAssertLessThanOrEqual(abs(Foundation.log(now / time)), Foundation.log(SkyNightCamera.maximumStep) + 1e-9,
                                     "the frame rate changes by at most one step")
            time = now
        }
        XCTAssertEqual(time, limits.maxDuration, accuracy: 1e-12, "a long night ends at the longest time")
    }

    func testTheExposureTimeIsPreferredToGainAndTheGainFallsFirst() {
        var exposure = SkyNightCamera.Exposure.manual(duration: 0.1, iso: 50)
        for _ in 0..<12 { exposure = next(exposure, luma: 0.01) }
        guard case let .manual(longDuration, highISO) = exposure else { return XCTFail("still hand-set") }
        XCTAssertEqual(longDuration, limits.maxDuration, accuracy: 1e-12)
        XCTAssertGreaterThan(highISO, limits.minISO)
        // Brighter than the still band: the gain goes down while the time stays at its longest.
        let back = next(exposure, luma: 0.4)
        guard case let .manual(sameDuration, lowerISO) = back else { return XCTFail("still hand-set") }
        XCTAssertEqual(sameDuration, limits.maxDuration, accuracy: 1e-12)
        XCTAssertLessThan(lowerISO, highISO)
        XCTAssertEqual(limits.split(0.13, from: nil).iso, limits.minISO, "a short exposure needs no gain")
    }

    func testNearItsTargetTheExposureHoldsStillAndBetweenStepsItWaits() {
        let set = SkyNightCamera.Exposure.manual(duration: 0.25, iso: 400)
        let low = SkyNightCamera.targetLuma / SkyNightCamera.stillBand
        let high = SkyNightCamera.targetLuma * SkyNightCamera.stillBand
        XCTAssertEqual(next(set, luma: low), set, "the band's edge is inside")
        XCTAssertEqual(next(set, luma: high), set, "the band's edge is inside")
        XCTAssertNotEqual(next(set, luma: low.nextDown), set)
        XCTAssertNotEqual(next(set, luma: high.nextUp), set)
        XCTAssertEqual(next(set, luma: 0.02, after: SkyNightCamera.stepSeconds / 2), set, "too soon for another step")
        XCTAssertEqual(next(set, luma: 0.02, frames: SkyNightCamera.stepFrames - 1), set,
                       "the last step has not shown in enough frames yet")
        XCTAssertEqual(next(.automatic, luma: 0.02, after: 0), .automatic, "too soon after the start")
    }

    func testTheExposureHandsBackOnceAutomaticCanCarryThePictureEasily() {
        XCTAssertEqual(next(.manual(duration: 1.0 / 30, iso: 50), luma: 0.4), .automatic, "morning")
        XCTAssertEqual(next(.manual(duration: 1.0 / 37, iso: 50), luma: 0.25), .automatic,
                       "a dim room inside the still band hands back too")
        // A lit room after a long exposure: the time comes down a step at a time, then automatic.
        var exposure = SkyNightCamera.Exposure.manual(duration: 0.4, iso: 50)
        var steps = 0
        while exposure != .automatic, steps < 10 {
            exposure = next(exposure, luma: 0.3)
            steps += 1
        }
        XCTAssertEqual(exposure, .automatic)
        XCTAssertLessThanOrEqual(steps, 6)
        XCTAssertNotEqual(next(.manual(duration: 0.5, iso: 400), luma: 0.4), .automatic,
                          "a long exposure with gain is shortened, not handed back")
        let taken = next(.automatic, luma: 0.02)
        XCTAssertNotEqual(next(taken, luma: 0.4), .automatic, "what was just taken over is not handed back")
    }

    func testALightSwitchedOnHandsBackButOnePassingLightDoesNot() {
        let night = SkyNightCamera.Exposure.manual(duration: 1, iso: 3200)
        XCTAssertEqual(next(night, luma: 1, after: 0, frames: 0, clipped: SkyNightCamera.clippedFrames), .automatic,
                       "two clipped frames in a row: back to automatic at once")
        XCTAssertNotEqual(next(night, luma: 1, clipped: 1), .automatic, "one clipped frame is a passing light")
        XCTAssertNotEqual(next(night, luma: 0.5, clipped: 0), .automatic)
    }

    func testNonFiniteInputsAndInvalidLimitsChangeNothing() {
        let set = SkyNightCamera.Exposure.manual(duration: 0.25, iso: 400)
        XCTAssertEqual(next(set, luma: .nan), set)
        XCTAssertEqual(next(set, luma: -1), set)
        XCTAssertEqual(next(set, luma: 0.02, after: .nan), set)
        XCTAssertEqual(next(.automatic, luma: .infinity), .automatic)
        XCTAssertEqual(next(.automatic, luma: 0.02, reading: (.nan, 800)), .automatic)
        XCTAssertEqual(next(.manual(duration: 0, iso: 400), luma: 0.02), .automatic, "a broken hand setting goes back")
        let broken = SkyNightCamera.Limits(minDuration: 1, maxDuration: 0.5, minISO: 50, maxISO: 3200)
        XCTAssertFalse(broken.isValid)
        XCTAssertEqual(SkyNightCamera.nextExposure(current: set, luma: 0.02, reading: (duration: 0.25, iso: 400),
                                                   limits: broken, secondsSinceLastStep: 1, framesSinceLastStep: 3,
                                                   clippedFramesInARow: 0), set)
        let fixed = SkyNightCamera.Limits(minDuration: 1.0 / 30, maxDuration: 1.0 / 30, minISO: 800, maxISO: 800)
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .automatic, luma: 0.02, reading: (duration: 1.0 / 30, iso: 800),
                                                   limits: fixed, secondsSinceLastStep: 1, framesSinceLastStep: 3,
                                                   clippedFramesInARow: 0),
                       .manual(duration: 1.0 / 30, iso: 800), "a format without room stays inside it")
    }

    func testFocusHoldsStillOnlyWhileTheExposureIsSetByHand() {
        XCTAssertFalse(SkyNightCamera.holdsFocus(.automatic))
        XCTAssertTrue(SkyNightCamera.holdsFocus(.manual(duration: 0.5, iso: 800)))
    }

    func testThePicturesLiftStartsAtZeroAtTheTakeoverAndGrowsWithoutAJump() {
        XCTAssertEqual(SkyNightCamera.nightLift(.automatic, limits: limits), 0)
        XCTAssertEqual(SkyNightCamera.nightLift(next(.automatic, luma: 0.02), limits: limits), 0,
                       "nothing changes at the takeover")
        let atLimit = next(.automatic, luma: 0.02, reading: (1.0 / 30, 3200))
        XCTAssertEqual(SkyNightCamera.nightLift(atLimit, limits: limits), 0, accuracy: 1e-9,
                       "nor when automatic exposure was at its very limit")
        var exposure = atLimit
        var previous = 0.0
        for _ in 0..<12 {
            exposure = next(exposure, luma: 0.01)
            let lift = SkyNightCamera.nightLift(exposure, limits: limits)
            XCTAssertGreaterThanOrEqual(lift, previous)
            XCTAssertLessThanOrEqual(lift - previous, 0.2, "no step of the exposure jumps the picture")
            previous = lift
        }
        XCTAssertEqual(SkyNightCamera.nightLift(.manual(duration: 1, iso: 3200), limits: limits),
                       Foundation.log(20) / Foundation.log(30), accuracy: 1e-9)
    }

    func testTheStackedLumaBlendsLikeTheStack() throws {
        XCTAssertEqual(SkyNightCamera.stackedLuma(previous: nil, frame: 0.2, weight: 0.5), 0.2)
        let blended = try XCTUnwrap(SkyNightCamera.stackedLuma(previous: 0.2, frame: 0.02, weight: 0.125))
        XCTAssertEqual(blended, 0.2 * 0.875 + 0.02 * 0.125, accuracy: 1e-12,
                       "one dark frame barely moves a bright stack")
        XCTAssertEqual(SkyNightCamera.stackedLuma(previous: 0.2, frame: .nan, weight: 0.5), 0.2)
        XCTAssertEqual(SkyNightCamera.stackedLuma(previous: .nan, frame: 0.1, weight: 0.5), 0.1)
        XCTAssertEqual(SkyNightCamera.stackedLuma(previous: 0.2, frame: 0.1, weight: 2), 0.1)
        XCTAssertEqual(SkyNightCamera.stackedLuma(previous: 0.2, frame: 0.1, weight: -1), 0.2)
    }

    func testTheLayerStaysAwayInNoiseAndFadesInWithSignal() {
        XCTAssertEqual(SkyNightCamera.layerOpacity(luma: 0), 0)
        XCTAssertEqual(SkyNightCamera.layerOpacity(luma: SkyNightCamera.noiseFloorLuma), 0)
        XCTAssertEqual(SkyNightCamera.layerOpacity(luma: 0.5), SkyNightCamera.maximumOpacity)
        let middle = SkyNightCamera.layerOpacity(luma: (SkyNightCamera.noiseFloorLuma + SkyNightCamera.fullLuma) / 2)
        XCTAssertEqual(middle, SkyNightCamera.maximumOpacity / 2, accuracy: 1e-9)
        XCTAssertEqual(SkyNightCamera.layerOpacity(luma: .infinity), 0)
    }

    func testANewFrameWeighsLessAsTheStackGrowsDownToAFloor() {
        XCTAssertEqual(SkyNightCamera.newFrameWeight(stacked: 0), 1)
        XCTAssertEqual(SkyNightCamera.newFrameWeight(stacked: 1), 0.5)
        XCTAssertEqual(SkyNightCamera.newFrameWeight(stacked: 3), 0.25)
        XCTAssertEqual(SkyNightCamera.newFrameWeight(stacked: 100), 0.125)
        XCTAssertEqual(SkyNightCamera.newFrameWeight(stacked: -4), 1)
    }

    func testASmallTurnIsMeasuredAlongTheOldFramesAxes() throws {
        let up = SkyVector(x: 0, y: 0, z: 1)
        let north = SkyVector(Sky.Horizontal(altitude: 0, azimuth: 0))
        let right = SkyVector(Sky.Horizontal(altitude: 0, azimuth: 1))
        let turned = try XCTUnwrap(SkyNightCamera.turn(fromForward: north, up: up, toForward: right, up: up))
        XCTAssertEqual(turned.right, 1, accuracy: 1e-9)
        XCTAssertEqual(turned.up, 0, accuracy: 1e-9)
        let raised = try XCTUnwrap(SkyNightCamera.turn(fromForward: north, up: up,
                                                       toForward: SkyVector(Sky.Horizontal(altitude: 2, azimuth: 0)),
                                                       up: SkyVector(Sky.Horizontal(altitude: 92, azimuth: 0))))
        XCTAssertEqual(raised.up, 2, accuracy: 1e-9)
        XCTAssertEqual(raised.right, 0, accuracy: 1e-9)
    }

    func testALargeTurnOrARollStartsTheStackOver() {
        let up = SkyVector(x: 0, y: 0, z: 1)
        let north = SkyVector(Sky.Horizontal(altitude: 0, azimuth: 0))
        XCTAssertNil(SkyNightCamera.turn(fromForward: north, up: up,
                                         toForward: SkyVector(Sky.Horizontal(altitude: 0, azimuth: 10)), up: up))
        let rolled = SkyVector(x: sin(10 * .pi / 180), y: 0, z: cos(10 * .pi / 180))
        XCTAssertNil(SkyNightCamera.turn(fromForward: north, up: up, toForward: north, up: rolled))
        XCTAssertNil(SkyNightCamera.turn(fromForward: north, up: north, toForward: north, up: up), "degenerate")
    }

    func testTheDrawnSkyMatchesAnAspectFilledCameraPicture() throws {
        // A 16:9 picture with 64° along its long side on a taller 19.5:9 screen: the long sides
        // match, so the short side sees tan(32°)/(19.5/9).
        let tall = try XCTUnwrap(SkyNightCamera.matchingFieldOfView(cameraLongSideDegrees: 64, imageAspect: 16.0 / 9,
                                                                    screenAspect: 19.5 / 9))
        let expected: Double = 2 * atan(tan(32 * Double.pi / 180) * 9 / 19.5) * 180 / .pi
        XCTAssertEqual(tall, expected, accuracy: 1e-9)
        // On a squarer screen the short sides match: the picture's own short field.
        let square = try XCTUnwrap(SkyNightCamera.matchingFieldOfView(cameraLongSideDegrees: 64, imageAspect: 16.0 / 9,
                                                                      screenAspect: 4.0 / 3))
        let shortField: Double = 2 * atan(tan(32 * Double.pi / 180) * 9 / 16) * 180 / .pi
        XCTAssertEqual(square, shortField, accuracy: 1e-9)
        XCTAssertNil(SkyNightCamera.matchingFieldOfView(cameraLongSideDegrees: .nan, imageAspect: 1, screenAspect: 1))
    }
}
