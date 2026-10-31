import XCTest
@testable import EchoelCore

/// The Field over a video, at pixel values: the three blends, the opacity, Off, and what a bad
/// number becomes at the boundary.
final class FieldLayerTests: XCTestCase {
    private let grid: [Double] = [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1]

    func testScreenLightensThePictureAndNeverDarkensIt() {
        let full = FieldLayer(blend: .screen, opacity: 1)
        XCTAssertEqual(full.mix(video: 0.5, field: 0.5), 0.75, accuracy: 1e-12)
        XCTAssertEqual(full.mix(video: 0, field: 0.4), 0.4, accuracy: 1e-12, "over black the Field shows as it is")
        XCTAssertEqual(full.mix(video: 1, field: 1), 1, "full light stays full, never more")
        let layer = FieldLayer(blend: .screen, opacity: 0.6)
        XCTAssertEqual(layer.mix(video: 0, field: 0.4), 0.24, accuracy: 1e-12)
        XCTAssertEqual(layer.mix(video: 0.5, field: 1), 0.8, accuracy: 1e-12, "0.5 + 0.6 × 1 × 0.5")
        for video in grid {
            for field in grid {
                let out = layer.mix(video: video, field: field)
                XCTAssertGreaterThanOrEqual(out, video - 1e-12, "screen never darkens: v \(video), f \(field)")
                XCTAssertLessThanOrEqual(out, 1)
            }
        }
    }

    func testAddBurnsOutAtFullLight() {
        let full = FieldLayer(blend: .add, opacity: 1)
        XCTAssertEqual(full.mix(video: 0.6, field: 0.6), 1, "clipped at full light")
        XCTAssertEqual(FieldLayer(blend: .add, opacity: 0.6).mix(video: 0.2, field: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(full.mix(video: 0.3, field: 0), 0.3, accuracy: 1e-12, "no Field, no change")
    }

    func testNormalLaysTheFieldOverThePicture() {
        XCTAssertEqual(FieldLayer(blend: .normal, opacity: 0.5).mix(video: 0.2, field: 0.8), 0.5, accuracy: 1e-12)
        XCTAssertEqual(FieldLayer(blend: .normal, opacity: 1).mix(video: 0.9, field: 0.1), 0.1, accuracy: 1e-12,
                       "at full opacity only the Field shows")
        XCTAssertEqual(FieldLayer(blend: .normal, opacity: 0.25).mix(video: 1, field: 0), 0.75, accuracy: 1e-12,
                       "a dark Field darkens the picture by its opacity")
    }

    /// Off, or an opacity of 0, leaves every pixel exactly as it was.
    func testOffAndNoOpacityLeaveThePictureAlone() {
        let layers = [FieldLayer(blend: .off, opacity: 1), FieldLayer(blend: .off)]
            + FieldLayer.Blend.allCases.map { FieldLayer(blend: $0, opacity: 0) }
        for layer in layers {
            XCTAssertFalse(layer.isVisible, "\(layer.blend)")
            for video in grid {
                for field in grid {
                    XCTAssertEqual(layer.mix(video: video, field: field), video, "\(layer.blend) v \(video) f \(field)")
                }
            }
        }
        XCTAssertTrue(FieldLayer(blend: .screen, opacity: 0.01).isVisible)
    }

    /// The numbers the GPU pass receives: the shader evaluates `v·video + f·field + v·f·product`.
    func testTheShaderFormTakesTheBlendsCoefficients() {
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: 0.6).coefficients,
                       FieldLayer.Coefficients(video: 1, field: 0.6, product: -0.6))
        XCTAssertEqual(FieldLayer(blend: .add, opacity: 0.6).coefficients,
                       FieldLayer.Coefficients(video: 1, field: 0.6, product: 0))
        XCTAssertEqual(FieldLayer(blend: .normal, opacity: 0.25).coefficients,
                       FieldLayer.Coefficients(video: 0.75, field: 0.25, product: 0))
        XCTAssertEqual(FieldLayer(blend: .off, opacity: 0.6).coefficients,
                       FieldLayer.Coefficients(video: 1, field: 0, product: 0))
    }

    /// What storage or a slip hands the layer is cleaned at the boundary, never passed on.
    func testABadNumberBecomesNoLightAtTheBoundary() {
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: .nan).opacity, 0)
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: .infinity).opacity, 0)
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: 7).opacity, 1)
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: -1).opacity, 0)
        XCTAssertFalse(FieldLayer(blend: .add, opacity: .nan).isVisible)
        let layer = FieldLayer(blend: .screen, opacity: 1)
        XCTAssertEqual(layer.mix(video: .nan, field: 0.5), 0.5, accuracy: 1e-12, "an unreadable picture is black")
        XCTAssertEqual(layer.mix(video: 0.5, field: .infinity), 0.5, accuracy: 1e-12, "an unreadable Field is dark")
        XCTAssertEqual(layer.mix(video: 3, field: -2), 1, "light outside 0 … 1 is clamped first")
        for value in [Double.nan, .infinity, -.infinity, 2, -1] {
            let out = FieldLayer(blend: .normal, opacity: 0.5).mix(video: value, field: value)
            XCTAssertTrue(out.isFinite && (0...1).contains(out), "\(value) gave \(out)")
        }
    }

    func testTheOpacityReadsAsAWholePercent() {
        XCTAssertEqual(FieldLayer(blend: .screen).opacityPercent, 60, "the standard opacity")
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: 0.333).opacityPercent, 33)
        XCTAssertEqual(FieldLayer(blend: .screen, opacity: .nan).opacityPercent, 0)
        XCTAssertEqual(FieldLayer.Blend.allCases.map(\.title), ["Off", "Screen", "Add", "Normal"])
    }
}
