import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest

/// The click hunt through the standard effects (AUD, 2026-11-01): each one plays a held tone, and
/// each of its number parameters is thrown from one end of its range to the other at once — as an
/// automation step, a MIDI knob or a route moves it — while the tone plays through.
final class EffectClickHuntTests: XCTestCase {
    private let rate = 48_000.0

    /// A tone with some harmonics, as an instrument plays into an insert: 220 Hz at 0.3, a third
    /// of that at 660 Hz.
    private func tone(_ count: Int) -> [Float] {
        (0..<count).map { (i: Int) -> Float in
            let t = Double(i) / 48_000
            let fundamental: Double = sin(2 * Double.pi * 220 * t)
            let third: Double = sin(2 * Double.pi * 660 * t)
            return Float(0.3 * fundamental + 0.1 * third)
        }
    }

    /// `frames` of the tone through `kernel` in 256-frame blocks, `change` applied before block
    /// `at`.
    private func play(_ kernel: EffectKernel, frames: Int, changeAt at: Int, _ change: () -> Void) -> (left: [Float], right: [Float]) {
        let input = tone(frames)
        var left = input, right = input
        var start = 0, block = 0
        while start < frames {
            let n = Swift.min(256, frames - start)
            if block == at { change() }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    kernel.process(left: lp + start, right: rp + start, frames: n)
                }
            }
            start += n
            block += 1
        }
        return (left, right)
    }

    /// Every (effect, parameter, direction) whose throw clicks, as text — empty when none does.
    private func sweep(_ effects: [StandardEffect]) -> [String] {
        var found: [String] = []
        for effect in effects {
            for parameter in EffectKernel.parameters(for: effect) where parameter.unit != .choice && parameter.unit != .boolean {
                for (from, to) in [(parameter.range.lowerBound, parameter.range.upperBound),
                                   (parameter.range.upperBound, parameter.range.lowerBound)] {
                    let kernel = EffectKernel(effect: effect, sampleRate: rate)
                    kernel.setParameter(parameter.address, from)
                    let out = play(kernel, frames: 48_000, changeAt: 94) { kernel.setParameter(parameter.address, to) }
                    // Only around the throw: the second half of the block before it to 0.2 s after.
                    let window = (94 * 256 - 128)..<(94 * 256 + 9_600)
                    let clicks = ClickDetector().clicks(in: Array(out.left)).filter { window.contains($0.index) }
                    if let first = clicks.first {
                        found.append("\(effect.rawValue).\(parameter.identifier) \(from)→\(to): \(first)")
                    }
                }
            }
        }
        return found
    }

    func testThrowingAParameterOfAnEffectDoesNotClick() {
        let found = sweep(StandardEffect.allCases.filter { $0 != .bitcrusher })
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    /// The harmonizer's styles (VOX): each one sung over a held voice, and a style changed while
    /// the voice sounds — a named choice changes at once, so its voices must enter without a click.
    func testEveryHarmonyStyleAndAChangeOfStyleSingWithoutAClick() throws {
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        let style = try XCTUnwrap(kernel.parameters.first { $0.identifier == "style" })
        let level = try XCTUnwrap(kernel.parameters.first { $0.identifier == "level" })
        var found: [String] = []
        for index in 0..<style.choices.count {
            let held = EffectKernel(effect: .harmonizer, sampleRate: rate)
            held.setParameter(level.address, 1)
            held.setParameter(style.address, Float(index))
            let next = (index + 1) % style.choices.count
            let out = play(held, frames: 48_000, changeAt: 94) { held.setParameter(style.address, Float(next)) }
            let clicks = ClickDetector().clicks(in: out.left).filter { $0.index > 4_800 }
            if let first = clicks.first {
                found.append("\(style.choices[index]) → \(style.choices[next]): \(clicks.count) — \(first)")
            }
        }
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    /// Each effect at its defaults plays the tone through without a click of its own.
    func testEveryEffectPlaysAToneThroughWithoutAClick() {
        var found: [String] = []
        for effect in StandardEffect.allCases where effect != .bitcrusher {
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            let out = play(kernel, frames: 96_000, changeAt: -1) {}
            let clicks = ClickDetector().clicks(in: out.left).filter { $0.index > 4_800 }
            if let first = clicks.first { found.append("\(effect.rawValue): \(clicks.count) — \(first)") }
        }
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }
}
