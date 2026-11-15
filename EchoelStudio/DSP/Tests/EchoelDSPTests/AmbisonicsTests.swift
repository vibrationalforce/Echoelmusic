import Foundation
import XCTest
@testable import EchoelDSP

/// AmbiX (ACN order, SN3D normalisation) up to third order, the conversions to and from FuMa and
/// N3D, a tetrahedral microphone's A-format as first-order B-format, and the first-order rotation
/// a head tracker turns. The microphone here is a mock: four ideal cardioid capsules, so the
/// matrices are tested without hardware.
final class AmbisonicsTests: XCTestCase {
    private func gains(_ azimuth: Float, _ elevation: Float, order: Int = 3) -> [Float] {
        Ambisonics.gains(azimuthDegrees: azimuth, elevationDegrees: elevation, order: order)
    }

    private func radians(_ degrees: Float) -> Float { degrees * .pi / 180 }

    /// The four capsule signals of a mock tetrahedral microphone hit by a plane wave of amplitude 1:
    /// ideal cardioids `0.5 + 0.5 cos θ` pointing front-left-up, front-right-down, back-left-down
    /// and back-right-up (x ahead, y left, z up), written out here and not taken from the code.
    private func capsules(_ azimuth: Float, _ elevation: Float) -> (flu: Float, frd: Float, bld: Float, bru: Float) {
        let a = radians(azimuth), e = radians(elevation)
        let x = cos(e) * cos(a), y = cos(e) * sin(a), z = sin(e)
        let k = 1 / Float(3).squareRoot()
        func cardioid(_ dx: Float, _ dy: Float, _ dz: Float) -> Float { 0.5 + 0.5 * k * (dx * x + dy * y + dz * z) }
        return (cardioid(1, 1, 1), cardioid(1, -1, -1), cardioid(-1, 1, -1), cardioid(-1, -1, 1))
    }

    /// The SN3D real spherical harmonics from their definition, independently of the code's
    /// closed forms: Nₗᵐ · Pₗ^|m|(sin elevation) · (cos mφ for m ≥ 0, sin |m|φ for m < 0), with the
    /// associated Legendre functions by their recurrence (no Condon–Shortley phase) and
    /// Nₗᵐ = √((2 − δₘ₀) (l − |m|)! / (l + |m|)!).
    private func reference(_ azimuth: Float, _ elevation: Float) -> [Double] {
        let phi = Double(azimuth) * .pi / 180
        let x = sin(Double(elevation) * .pi / 180)
        let s = (Swift.max(0, 1 - x * x)).squareRoot()
        func factorial(_ n: Int) -> Double { n < 2 ? 1 : (2...n).reduce(1.0) { $0 * Double($1) } }
        var out = [Double](repeating: 0, count: 16)
        for degree in 0...3 {
            for index in -degree...degree {
                let order = abs(index)
                var pmm = 1.0
                if order > 0 { for k in 1...order { pmm *= Double(2 * k - 1) * s } }
                var legendre = pmm
                if degree > order {
                    var below = pmm, current = x * Double(2 * order + 1) * pmm
                    if degree > order + 1 {
                        for step in (order + 2)...degree {
                            let next = (Double(2 * step - 1) * x * current - Double(step + order - 1) * below)
                                / Double(step - order)
                            below = current
                            current = next
                        }
                    }
                    legendre = current
                }
                let norm = ((order == 0 ? 1.0 : 2.0) * factorial(degree - order) / factorial(degree + order)).squareRoot()
                let angular = index >= 0 ? cos(Double(order) * phi) : sin(Double(order) * phi)
                out[degree * degree + degree + index] = norm * legendre * angular
            }
        }
        return out
    }

    private let directions: [(Float, Float)] = [(0, 0), (90, 0), (-90, 0), (180, 0), (0, 90), (0, -90),
                                                (30, 20), (-135, -40), (75, 60), (-10, -80), (160, 5)]

    func testAnOrderHoldsItsSquareOfChannelsAndEveryChannelKnowsItsDegreeAndIndex() {
        XCTAssertEqual((0...3).map(Ambisonics.channelCount(order:)), [1, 4, 9, 16])
        XCTAssertEqual(Ambisonics.channelCount(order: 7), 16, "orders above three are held at three")
        XCTAssertEqual(Ambisonics.channelCount(order: -1), 1)
        var acn = 0
        for degree in 0...3 {
            for index in -degree...degree {
                XCTAssertEqual(Ambisonics.acn(degree: degree, index: index), acn)
                let back = Ambisonics.degreeAndIndex(acn: acn)
                XCTAssertEqual(back.degree, degree)
                XCTAssertEqual(back.index, index)
                acn += 1
            }
        }
    }

    func testTheFirstOrderIsOneAndTheDirectionCosinesInTheOrderWYZX() {
        for (azimuth, elevation) in directions {
            let g = gains(azimuth, elevation, order: 1)
            XCTAssertEqual(g.count, 4)
            let a = radians(azimuth), e = radians(elevation)
            XCTAssertEqual(g[0], 1, accuracy: 1e-6)
            XCTAssertEqual(g[1], cos(e) * sin(a), accuracy: 1e-5, "Y: left is positive")
            XCTAssertEqual(g[2], sin(e), accuracy: 1e-5, "Z: up is positive")
            XCTAssertEqual(g[3], cos(e) * cos(a), accuracy: 1e-5, "X: ahead is positive")
        }
    }

    func testEveryChannelMatchesTheSN3DDefinitionAtEveryDirection() {
        for (azimuth, elevation) in directions {
            let g = gains(azimuth, elevation)
            let expected = reference(azimuth, elevation)
            for channel in 0..<16 {
                XCTAssertEqual(Double(g[channel]), expected[channel], accuracy: 1e-5,
                               "ACN \(channel) at \(azimuth)°, \(elevation)°")
            }
        }
        // The same at one direction, as numbers (python3, the definition above): a sign or a sin/cos
        // swap in any of these channels shows here.
        let g = gains(30, 20)
        XCTAssertEqual(g[5], 0.278335, accuracy: 1e-5)
        XCTAssertEqual(g[7], 0.482091, accuracy: 1e-5)
        XCTAssertEqual(g[9], 0.655990, accuracy: 1e-5)
        XCTAssertEqual(g[10], 0.506488, accuracy: 1e-5)
        XCTAssertEqual(g[11], -0.119436, accuracy: 1e-5)
        XCTAssertEqual(g[14], 0.292421, accuracy: 1e-5)
    }

    func testHigherOrdersHaveTheirSN3DValuesAtKnownDirections() {
        let up = gains(0, 90)
        XCTAssertEqual(up[6], 1, accuracy: 1e-5, "ACN 6 is (3 sin² − 1)/2")
        XCTAssertEqual(up[12], 1, accuracy: 1e-5, "ACN 12 is (5 sin³ − 3 sin)/2")
        XCTAssertEqual(up[8], 0, accuracy: 1e-5)
        let left45 = gains(45, 0)
        XCTAssertEqual(left45[4], Float(3).squareRoot() / 2, accuracy: 1e-5, "ACN 4 is √3/2 cos² sin 2φ")
        XCTAssertEqual(left45[8], 0, accuracy: 1e-5)
        let ahead = gains(0, 0)
        XCTAssertEqual(ahead[15], (Float(5) / 8).squareRoot(), accuracy: 1e-5, "ACN 15 is √(5/8) cos³ cos 3φ")
        XCTAssertEqual(ahead[6], -0.5, accuracy: 1e-5)
        XCTAssertEqual(ahead[13], -(Float(3) / 8).squareRoot(), accuracy: 1e-5)
    }

    func testEveryChannelsSquareIntegratesToFourPiOverTwoLPlusOneAndTheChannelsAreOrthogonal() {
        // SN3D: ∫ Yᵢ Yⱼ dΩ = 4π / (2l + 1) when i = j, else 0. Midpoint rule over sin(elevation)
        // and azimuth, which weighs every patch by its solid angle; 64 azimuths hold every product up
        // to 6φ exactly, 400 rows keep the error near 2e-4.
        let rows = 400, columns = 64
        var sums = [Double](repeating: 0, count: 16 * 16)
        for row in 0..<rows {
            let mu = -1 + (Double(row) + 0.5) * 2 / Double(rows)
            let elevation = Float(asin(mu) * 180 / .pi)
            for column in 0..<columns {
                let azimuth = Float((Double(column) + 0.5) * 360 / Double(columns) - 180)
                let g = gains(azimuth, elevation).map(Double.init)
                let weight = (2 / Double(rows)) * (2 * .pi / Double(columns))
                for i in 0..<16 { for j in 0..<16 { sums[i * 16 + j] += g[i] * g[j] * weight } }
            }
        }
        for i in 0..<16 {
            for j in 0..<16 {
                let degree = Ambisonics.degreeAndIndex(acn: i).degree
                let expected = i == j ? 4 * Double.pi / Double(2 * degree + 1) : 0
                XCTAssertEqual(sums[i * 16 + j], expected, accuracy: 1e-3, "ACN \(i) × ACN \(j)")
            }
        }
    }

    func testN3DIsSN3DTimesTheRootOfTwoLPlusOne() {
        XCTAssertEqual((0...3).map(Ambisonics.n3dGain(degree:)), [1, Float(3).squareRoot(), Float(5).squareRoot(),
                                                                  Float(7).squareRoot()])
        XCTAssertEqual((0...3).map(Ambisonics.sn3dGain(degree:)), [1, 1 / Float(3).squareRoot(), 1 / Float(5).squareRoot(),
                                                                   1 / Float(7).squareRoot()])
        // N3D's definition: each squared channel integrates to 4π — SN3D's 4π / (2l + 1) times the gain².
        for degree in 0...3 {
            let gain = Double(Ambisonics.n3dGain(degree: degree))
            XCTAssertEqual(gain * gain * 4 * .pi / Double(2 * degree + 1), 4 * .pi, accuracy: 1e-5, "degree \(degree)")
        }
    }

    func testFuMaAndAmbiXTurnIntoEachOtherAtFirstOrder() {
        // FuMa carries W at −3 dB and the order W X Y Z; AmbiX W at 0 dB and W Y Z X.
        let g = gains(-60, 25, order: 1)
        let fuMa = Ambisonics.fuMa(ambiXW: g[0], y: g[1], z: g[2], x: g[3])
        XCTAssertEqual(fuMa.w, 1 / Float(2).squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(fuMa.x, g[3], accuracy: 1e-6)
        XCTAssertEqual(fuMa.y, g[1], accuracy: 1e-6)
        XCTAssertEqual(fuMa.z, g[2], accuracy: 1e-6)
        let back = Ambisonics.ambiX(fuMaW: fuMa.w, x: fuMa.x, y: fuMa.y, z: fuMa.z)
        XCTAssertEqual(back.w, g[0], accuracy: 1e-6)
        XCTAssertEqual(back.y, g[1], accuracy: 1e-6)
        XCTAssertEqual(back.z, g[2], accuracy: 1e-6)
        XCTAssertEqual(back.x, g[3], accuracy: 1e-6)
    }

    func testAMockTetrahedralMicrophoneOfIdealCardioidsGivesTheFirstOrderField() {
        for (azimuth, elevation) in directions {
            let c = capsules(azimuth, elevation)
            let b = TetrahedralMicrophone.bFormat(flu: c.flu, frd: c.frd, bld: c.bld, bru: c.bru)
            let g = gains(azimuth, elevation, order: 1)
            XCTAssertEqual(b.w, g[0], accuracy: 1e-5, "W at \(azimuth)°, \(elevation)°")
            XCTAssertEqual(b.y, g[1], accuracy: 1e-5, "Y at \(azimuth)°, \(elevation)°")
            XCTAssertEqual(b.z, g[2], accuracy: 1e-5, "Z at \(azimuth)°, \(elevation)°")
            XCTAssertEqual(b.x, g[3], accuracy: 1e-5, "X at \(azimuth)°, \(elevation)°")
        }
    }

    func testTheBlockConversionMatchesFrameByFrameWorksInPlaceAndReadsNoNonFiniteSample() {
        let frames = 64
        var flu = [Float](repeating: 0, count: frames), frd = flu, bld = flu, bru = flu
        for i in 0..<frames {
            let c = capsules(Float(i) * 5.6 - 180, Float(i % 17) * 10 - 80)
            let level = sin(Float(i) * 0.3)
            flu[i] = c.flu * level; frd[i] = c.frd * level; bld[i] = c.bld * level; bru[i] = c.bru * level
        }
        flu[10] = .nan
        bru[20] = .infinity
        let expected = (0..<frames).map { (i: Int) -> (w: Float, y: Float, z: Float, x: Float) in
            TetrahedralMicrophone.bFormat(flu: flu[i], frd: frd[i], bld: bld[i], bru: bru[i])
        }
        // In place: the four outputs are the four inputs.
        flu.withUnsafeMutableBufferPointer { a in
            frd.withUnsafeMutableBufferPointer { b in
                bld.withUnsafeMutableBufferPointer { c in
                    bru.withUnsafeMutableBufferPointer { d in
                        guard let pa = a.baseAddress, let pb = b.baseAddress, let pc = c.baseAddress, let pd = d.baseAddress else {
                            return XCTFail("no buffers")
                        }
                        TetrahedralMicrophone.convert(flu: pa, frd: pb, bld: pc, bru: pd, w: pa, y: pb, z: pc, x: pd, frames: frames)
                    }
                }
            }
        }
        for i in 0..<frames {
            XCTAssertEqual(flu[i], expected[i].w, accuracy: 1e-6)
            XCTAssertEqual(frd[i], expected[i].y, accuracy: 1e-6)
            XCTAssertEqual(bld[i], expected[i].z, accuracy: 1e-6)
            XCTAssertEqual(bru[i], expected[i].x, accuracy: 1e-6)
            XCTAssertTrue(flu[i].isFinite && frd[i].isFinite && bld[i].isFinite && bru[i].isFinite, "frame \(i)")
        }
    }

    func testAYawTurnsASourceAlongTheAzimuthAndPitchAndRollTiltItUp() {
        let yaw = FirstOrderRotation(yawDegrees: 40, pitchDegrees: 0, rollDegrees: 0)
        let source = gains(30, 10, order: 1)
        let turned = yaw.rotate(y: source[1], z: source[2], x: source[3])
        let target = gains(70, 10, order: 1)
        XCTAssertEqual(turned.y, target[1], accuracy: 1e-5)
        XCTAssertEqual(turned.z, target[2], accuracy: 1e-5)
        XCTAssertEqual(turned.x, target[3], accuracy: 1e-5)

        let pitch = FirstOrderRotation(yawDegrees: 0, pitchDegrees: 90, rollDegrees: 0)
        let raised = pitch.rotate(y: 0, z: 0, x: 1)
        XCTAssertEqual(raised.z, 1, accuracy: 1e-5, "pitching up lifts the source ahead overhead")
        XCTAssertEqual(raised.x, 0, accuracy: 1e-5)

        let roll = FirstOrderRotation(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 90)
        let tilted = roll.rotate(y: 1, z: 0, x: 0)
        XCTAssertEqual(tilted.z, 1, accuracy: 1e-5, "rolling lifts the source on the left")
        XCTAssertEqual(tilted.y, 0, accuracy: 1e-5)
    }

    func testRollComesFirstThenPitchThenYaw() {
        // Pitch first, then yaw: the source ahead goes overhead and stays there (yaw first would put it
        // on the left before lifting it).
        let pitchThenYaw = FirstOrderRotation(yawDegrees: 90, pitchDegrees: 90, rollDegrees: 0).rotate(y: 0, z: 0, x: 1)
        XCTAssertEqual(pitchThenYaw.z, 1, accuracy: 1e-5)
        XCTAssertEqual(pitchThenYaw.y, 0, accuracy: 1e-5)
        // Roll first, then pitch: the source on the left goes overhead, then pitching tips it behind
        // (pitch first would leave it on the left and roll it overhead).
        let rollThenPitch = FirstOrderRotation(yawDegrees: 0, pitchDegrees: 90, rollDegrees: 90).rotate(y: 1, z: 0, x: 0)
        XCTAssertEqual(rollThenPitch.x, -1, accuracy: 1e-5)
        XCTAssertEqual(rollThenPitch.z, 0, accuracy: 1e-5)
    }

    func testARotationKeepsTheFieldsStrengthAndItsInverseUndoesIt() {
        let turn = FirstOrderRotation(yawDegrees: -73, pitchDegrees: 21, rollDegrees: 140)
        for (azimuth, elevation) in directions {
            let g = gains(azimuth, elevation, order: 1)
            let r = turn.rotate(y: g[1], z: g[2], x: g[3])
            XCTAssertEqual(r.x * r.x + r.y * r.y + r.z * r.z, 1, accuracy: 1e-5, "a unit direction stays a unit direction")
            let back = turn.inverse.rotate(y: r.y, z: r.z, x: r.x)
            XCTAssertEqual(back.y, g[1], accuracy: 1e-5)
            XCTAssertEqual(back.z, g[2], accuracy: 1e-5)
            XCTAssertEqual(back.x, g[3], accuracy: 1e-5)
        }
        XCTAssertEqual(FirstOrderRotation.identity.rotate(y: 0.2, z: -0.3, x: 0.9).x, 0.9, accuracy: 1e-7)
    }

    func testADirectionThatIsNotANumberEncodesAsStraightAheadAndAHugeOneStaysFinite() {
        XCTAssertEqual(gains(.nan, .infinity), gains(0, 0))
        let none = FirstOrderRotation(yawDegrees: .nan, pitchDegrees: 0, rollDegrees: .infinity)
        XCTAssertEqual(none, FirstOrderRotation.identity)
        XCTAssertTrue(gains(.greatestFiniteMagnitude, -.greatestFiniteMagnitude).allSatisfy(\.isFinite))
        let huge = FirstOrderRotation(yawDegrees: .greatestFiniteMagnitude, pitchDegrees: 3e38, rollDegrees: -3e38)
        let turned = huge.rotate(y: 0.3, z: -0.4, x: 0.5)
        XCTAssertTrue(turned.x.isFinite && turned.y.isFinite && turned.z.isFinite)
        // 370° is 10°.
        XCTAssertEqual(gains(370, 0, order: 1)[1], gains(10, 0, order: 1)[1], accuracy: 1e-6)
    }
}
