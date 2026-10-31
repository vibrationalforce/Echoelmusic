import XCTest
@testable import EchoelCore

/// The camera layer's rules: when the exposure goes long, how strongly the layer shows, how the
/// stack weighs a new frame, how a turn of the phone shifts it, and the field of view that lines
/// the drawn stars up with the camera's picture.
final class SkyNightCameraTests: XCTestCase {
    func testTheExposureGoesLongInTheDarkAndComesBackWithHysteresis() {
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .automatic, luma: 0.5), .automatic)
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .automatic, luma: 0.03), .longest)
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .longest, luma: 0.2), .longest, "no flapping in between")
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .longest, luma: 0.6), .automatic)
        XCTAssertEqual(SkyNightCamera.nextExposure(current: .longest, luma: .nan), .longest)
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
