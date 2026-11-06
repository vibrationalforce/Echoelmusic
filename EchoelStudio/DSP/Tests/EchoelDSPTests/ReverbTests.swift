import XCTest
@testable import EchoelDSP

final class ReverbTests: XCTestCase {
    private let rate = 48_000.0

    private func response(_ settings: Reverb.Settings, seconds: Double = 1.4) -> ([Float], [Float]) {
        let reverb = Reverb(sampleRate: rate, settings: settings)
        let count = Int(rate * seconds)
        var left = [Float](repeating: 0, count: count), right = left
        left[0] = 1
        right[0] = 1
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                // In blocks, as a host renders.
                var done = 0
                while done < count {
                    let n = Swift.min(256, count - done)
                    reverb.process(left: a + done, right: b + done, frames: n)
                    done += n
                }
            }
        }
        return (left, right)
    }

    private func rms(_ x: [Float], from: Double, to: Double) -> Double {
        let part = x[Int(from * rate)..<Int(to * rate)]
        return (part.reduce(0) { $0 + Double($1 * $1) } / Double(part.count)).squareRoot()
    }

    func testTheTailFallsBySixtyDecibelsInTheDecayTime() {
        let (left, _) = response(.init(size: 0.6, decay: 1, damping: 20_000, predelay: 0, mix: 1))
        let fall = 20 * log10(rms(left, from: 1.1, to: 1.2) / rms(left, from: 0.1, to: 0.2))
        XCTAssertEqual(fall, -60, accuracy: 9)
        let (long, _) = response(.init(size: 0.6, decay: 4, damping: 20_000, predelay: 0, mix: 1))
        XCTAssertGreaterThan(rms(long, from: 1.1, to: 1.2), 10 * rms(left, from: 1.1, to: 1.2), "a longer decay rings longer")
    }

    /// The peak of `seconds` of a 0.5 sine at `hertz` through `settings`, after the first second.
    private func sustainedPeak(_ settings: Reverb.Settings, hertz: Double, seconds: Double = 6) -> Float {
        let reverb = Reverb(sampleRate: rate, settings: settings)
        var left = [Float](repeating: 0, count: 512), right = left
        var peak: Float = 0
        var done = 0
        while done < Int(seconds * rate) {
            for i in 0..<512 {
                let phase: Double = 2 * Double.pi * hertz * Double(done + i) / rate
                left[i] = Float(sin(phase)) * 0.5
                right[i] = left[i]
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let a = l.baseAddress, let b = r.baseAddress else { return }
                    reverb.process(left: a, right: b, frames: 512)
                }
            }
            if done >= Int(rate) { peak = Swift.max(peak, left.map(abs).max() ?? 0, right.map(abs).max() ?? 0) }
            done += 512
        }
        return peak
    }

    /// A held tone on one of the network's modes rang up to 8.6 from a 0.5 sine — +24.7 dB — at
    /// Size 1, Decay 20 s, Damping 20 kHz, Mix 1, and to +16 dB at the default decay (audit
    /// 2026-11-04). The guard holds the wet within +6 dB of the input's peak, with a little room
    /// for its follower's ripple.
    func testAHeldToneNeverRingsFarAboveTheInput() {
        let extreme = Reverb.Settings(size: 1, decay: 20, damping: 20_000, predelay: 0.02, mix: 1)
        for hertz in [220.0, 1_107.5, 1_178.0] {
            let peak = sustainedPeak(extreme, hertz: hertz)
            XCTAssertLessThan(20 * log10(Double(peak) / 0.5), 8, "\(hertz) Hz rang to \(peak)")
        }
        let atDefault = sustainedPeak(.init(mix: 1), hertz: 280.3)
        XCTAssertLessThan(20 * log10(Double(atDefault) / 0.5), 8, "the default decay rang to \(atDefault)")
    }

    /// Hall is the reverb as it sounded before modes: settings built without a mode, and settings
    /// stored before modes existed, render the very samples an explicit Hall renders.
    func testHallIsTheSoundBeforeModesAndAStoredSettingWithoutAModeIsHall() throws {
        let old = Reverb.Settings(size: 0.6, decay: 2.2, damping: 7_000, predelay: 0.02, mix: 0.2)
        XCTAssertEqual(old.mode, .hall)
        XCTAssertEqual(Reverb.Settings().mode, .hall)
        XCTAssertEqual(response(old).0, response(.init(mode: .hall)).0)
        XCTAssertEqual(response(old).1, response(.init(mode: .hall)).1)

        let stored = Data(#"{"size":0.6,"decay":2.2,"damping":7000,"predelay":0.02,"mix":0.2}"#.utf8)
        let decoded = try JSONDecoder().decode(Reverb.Settings.self, from: stored)
        XCTAssertEqual(decoded, old)
        XCTAssertEqual(response(decoded).0, response(old).0)

        let plate = Reverb.Settings(decay: 3, mode: .plate)
        XCTAssertEqual(try JSONDecoder().decode(Reverb.Settings.self, from: try JSONEncoder().encode(plate)), plate)
        XCTAssertNotEqual(response(plate).0, response(.init(decay: 3)).0, "a plate is not the hall")
    }

    /// Seconds for the impulse's remaining energy to fall from −5 to −35 dB, doubled: the decay
    /// time a room measurement reports (Schroeder's backward integration).
    private func reverberationTime(_ x: [Float]) -> Double {
        var remaining = [Double](repeating: 0, count: x.count)
        var total = 0.0
        for index in stride(from: x.count - 1, through: 0, by: -1) {
            total += Double(x[index]) * Double(x[index])
            remaining[index] = total
        }
        guard total > 0 else { return 0 }
        let start = remaining.firstIndex { $0 < total * pow(10, -0.5) } ?? 0
        let end = remaining.firstIndex { $0 < total * pow(10, -3.5) } ?? x.count
        return 2 * Double(end - start) / rate
    }

    /// A room rings out in well under the hall's time at the same settings (0.88 s against 1.95 s
    /// in a double-precision model of this network, Decay 2.2 s).
    func testARoomRingsOutSoonerThanAHall() {
        let hall = reverberationTime(response(.init(predelay: 0, mix: 1), seconds: 3).0)
        let room = reverberationTime(response(.init(predelay: 0, mix: 1, mode: .room), seconds: 3).0)
        XCTAssertGreaterThan(hall, 1.2)
        XCTAssertLessThan(room, 0.7 * hall, "room \(room) s, hall \(hall) s")
        XCTAssertGreaterThan(room, 0.3)
    }

    /// How many of the samples between `from` and `to` stand above the window's own deviation, as a
    /// share of what noise would give (Abel and Huang's echo density): near 0 for a few separate
    /// echoes in silence, near 1 once the reflections have merged.
    private func echoDensity(_ x: [Float], from: Double, to: Double) -> Double {
        let part = Array(x[Int(from * rate)..<Int(to * rate)])
        let deviation = rms(x, from: from, to: to)
        let above = part.filter { Double(abs($0)) > deviation }.count
        return Double(above) / Double(part.count) / 0.3173
    }

    /// A plate fills its first 50 ms far denser than a hall (0.67 against 0.29 in the model), and
    /// its tail is brighter: more of its energy is in the sample-to-sample change.
    func testAPlateIsDenserEarlyAndBrighterThanAHall() {
        let hall = response(.init(predelay: 0, mix: 1), seconds: 0.6).0
        let plate = response(.init(predelay: 0, mix: 1, mode: .plate), seconds: 0.6).0
        let hallDensity = echoDensity(hall, from: 0, to: 0.05)
        let plateDensity = echoDensity(plate, from: 0, to: 0.05)
        XCTAssertGreaterThan(plateDensity, hallDensity + 0.2, "plate \(plateDensity), hall \(hallDensity)")

        func brightness(_ x: [Float]) -> Double {
            let tail = Array(x[Int(0.2 * rate)..<Int(0.5 * rate)])
            var energy = 0.0, change = 0.0
            for index in tail.indices {
                energy += Double(tail[index]) * Double(tail[index])
                if index > 0 {
                    let step = Double(tail[index] - tail[index - 1])
                    change += step * step
                }
            }
            return energy > 0 ? change / energy : 0
        }
        XCTAssertGreaterThan(brightness(plate), 1.3 * brightness(hall))
    }

    /// The guard holds in every mode: a held tone on the extreme settings, and at the defaults.
    func testEveryModeKeepsTheLevelGuard() {
        for mode in Reverb.Settings.Mode.allCases {
            let extreme = Reverb.Settings(size: 1, decay: 20, damping: 20_000, predelay: 0.02, mix: 1, mode: mode)
            for hertz in [220.0, 1_107.5, 1_178.0] {
                let peak = sustainedPeak(extreme, hertz: hertz)
                XCTAssertLessThan(20 * log10(Double(peak) / 0.5), 8, "\(mode) at \(hertz) Hz rang to \(peak)")
            }
            let atDefault = sustainedPeak(.init(mix: 1, mode: mode), hertz: 280.3)
            XCTAssertLessThan(20 * log10(Double(atDefault) / 0.5), 8, "\(mode) at the default decay rang to \(atDefault)")
        }
    }

    /// Switching the mode under a held tone moves the lines and the diffusers mid-tail; the output
    /// stays finite and inside the guard's bound the whole time.
    func testSwitchingTheModeWhilePlayingStaysFiniteAndUnderTheGuard() {
        let reverb = Reverb(sampleRate: rate, settings: .init(size: 1, decay: 20, damping: 20_000, predelay: 0.02, mix: 1))
        let order: [Reverb.Settings.Mode] = [.plate, .room, .hall, .room, .plate, .hall]
        var left = [Float](repeating: 0, count: 512), right = left
        var peak: Float = 0
        var finite = true
        for block in 0..<96 {
            if block % 8 == 0 { reverb.settings.mode = order[(block / 8) % order.count] }
            for i in 0..<512 {
                let phase: Double = 2 * Double.pi * 330 * Double(block * 512 + i) / rate
                left[i] = Float(sin(phase)) * 0.5
                right[i] = left[i]
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let a = l.baseAddress, let b = r.baseAddress else { return }
                    reverb.process(left: a, right: b, frames: 512)
                }
            }
            finite = finite && left.allSatisfy(\.isFinite) && right.allSatisfy(\.isFinite)
            if block * 512 >= Int(rate) { peak = Swift.max(peak, left.map(abs).max() ?? 0, right.map(abs).max() ?? 0) }
        }
        XCTAssertTrue(finite)
        XCTAssertLessThan(20 * log10(Double(peak) / 0.5), 8, "switching rang to \(peak)")
    }

    /// A choice's index picks the mode in the stored order; anything else plays Hall.
    func testAModeIsChosenByItsIndex() {
        XCTAssertEqual(Reverb.Settings.Mode.allCases.map(\.title), ["Hall", "Plate", "Room"])
        let indices: [Double] = [0, 1, 2, 1.2, 7, -1, .nan]
        let expected: [Reverb.Settings.Mode] = [.hall, .plate, .room, .plate, .hall, .hall, .hall]
        XCTAssertEqual(indices.map { (index: Double) -> Reverb.Settings.Mode in Reverb.Settings.Mode(index: index) }, expected)
    }

    func testThePredelayHoldsTheTailBackAndTheSidesDiffer() {
        let (left, right) = response(.init(predelay: 0.1, mix: 1), seconds: 0.5)
        let first = left.firstIndex { abs($0) > 1e-9 } ?? 0
        XCTAssertGreaterThanOrEqual(first, 4_800, "nothing before the predelay")
        XCTAssertNotEqual(left, right, "a stereo tail, not two copies")
        XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) < 1 })
    }

    func testDryPassesUntouchedAndABadSampleHeals() {
        let tone = (0..<4_800).map { Float(sin(Double($0) * 0.1)) }
        let dry = Reverb(sampleRate: rate, settings: .init(mix: 0))
        var a = tone, b = tone
        a.withUnsafeMutableBufferPointer { l in
            b.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                dry.process(left: x, right: y, frames: l.count)
            }
        }
        XCTAssertEqual(a, tone)

        let reverb = Reverb(sampleRate: rate, settings: .init(decay: 20, mix: 1))
        var bad = tone, other = tone
        bad[10] = .infinity
        bad.withUnsafeMutableBufferPointer { l in
            other.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                reverb.process(left: x, right: y, frames: l.count)
            }
        }
        XCTAssertTrue(bad.allSatisfy(\.isFinite))
        reverb.settings.decay = .nan
        XCTAssertEqual(reverb.settings.decay, 2.2, "non-finite takes the default")
    }
}
