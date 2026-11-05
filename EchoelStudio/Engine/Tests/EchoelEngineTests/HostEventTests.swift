import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import Foundation
import XCTest

/// What a host's render events do to an instrument kernel (audit 2026-11-04): a two-byte MIDI
/// message used to be dropped, and a parameter ramp jumped to its end at once.
final class HostEventTests: XCTestCase {
    /// Records what reaches `receive`.
    private final class Spy: InstrumentKernel, @unchecked Sendable {
        static var parameters: [InstrumentKernelParameter] { [] }
        let sampleRate: Double
        var heard: [[UInt8]] = []
        init(sampleRate: Double, maximumFrames: Int) { self.sampleRate = sampleRate }
        func setParameter(_ address: Int, _ value: Float) {}
        func parameter(_ address: Int) -> Float { 0 }
        func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) { heard.append([status, data1, data2]) }
        func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain: Float) {}
    }

    func testTwoByteMessagesArriveAndShortOrSystemOnesDoNot() {
        let spy = Spy(sampleRate: 48_000, maximumFrames: 512)
        spy.receive(midi: 2, 0xD3, 100, 0x55)   // channel pressure: the third byte is not the message's
        spy.receive(midi: 2, 0xC0, 5, 0)        // program change
        spy.receive(midi: 3, 0x90, 60, 100)     // note on
        spy.receive(midi: 2, 0x90, 60, 100)     // a note on needs three bytes
        spy.receive(midi: 1, 0xD0, 0, 0)
        spy.receive(midi: 3, 0xF8, 0, 0)        // clock: not a channel message
        spy.receive(midi: 3, 0x40, 0, 0)        // a data byte is not a status
        XCTAssertEqual(spy.heard, [[0xD3, 100, 0], [0xC0, 5, 0], [0x90, 60, 100]])
    }

    /// The level ramped from 0 to 1 over 100 ms rises along the way; set at once, it is up
    /// within the voice's 5 ms glide.
    func testAParameterRampRunsOverItsFrames() {
        let level = SynthKernel.parameters.firstIndex { $0.identifier == "synth_level" } ?? -1
        let sustain = SynthKernel.parameters.firstIndex { $0.identifier == "synth_sustain" } ?? -1
        let filterAmount = SynthKernel.parameters.firstIndex { $0.identifier == "synth_filterAmount" } ?? -1
        func rms(ramped: Bool) -> [Float] {
            let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 512)
            kernel.setParameter(level, 0)
            kernel.setParameter(sustain, 1)   // flat envelopes: only the level moves
            kernel.setParameter(filterAmount, 0)
            kernel.receive(status: 0x90, 57, 100)
            let left = UnsafeMutablePointer<Float>.allocate(capacity: 480)
            let right = UnsafeMutablePointer<Float>.allocate(capacity: 480)
            defer {
                left.deallocate()
                right.deallocate()
            }
            kernel.render(frames: 480, left: left, right: right, gain: 1)
            if ramped { kernel.rampParameter(level, to: 1, frames: 4_800) } else { kernel.setParameter(level, 1) }
            var windows: [Float] = []
            for _ in 0..<12 {
                kernel.render(frames: 480, left: left, right: right, gain: 1)
                var sum: Float = 0
                for i in 0..<480 { sum += left[i] * left[i] }
                windows.append((sum / 480).squareRoot())
            }
            return windows
        }
        let ramped = rms(ramped: true), stepped = rms(ramped: false)
        let full = ramped[11]
        XCTAssertGreaterThan(full, 0.01)
        XCTAssertEqual(stepped[2], stepped[11], accuracy: stepped[11] * 0.05, "set at once: up within the 5 ms glide")
        XCTAssertLessThan(ramped[1], full * 0.3, "10 … 20 ms into a 100 ms ramp")
        XCTAssertEqual(ramped[4], full * 0.45, accuracy: full * 0.12, "halfway, about half")
        XCTAssertEqual(ramped[10], full, accuracy: full * 0.05, "and there by its end")
        for i in 1..<10 { XCTAssertGreaterThan(ramped[i], ramped[i - 1], "rising, window \(i)") }
    }

    /// A choice takes its value at once; a value set from the plugin's view ends a ramp.
    func testAChoiceDoesNotGlideAndAViewSettingEndsARamp() {
        let parameters = SynthKernel.parameters
        let engine = parameters.firstIndex { $0.identifier == "synth_engine" } ?? -1
        let cutoff = parameters.firstIndex { $0.identifier == "synth_cutoff" } ?? -1
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 512)
        kernel.rampParameter(engine, to: 3, frames: 48_000)
        XCTAssertEqual(kernel.parameter(engine), 3)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        kernel.rampParameter(cutoff, to: 18_000, frames: 48_000)
        kernel.render(frames: 512, left: left, right: right, gain: 1)
        XCTAssertLessThan(kernel.parameter(cutoff), 2_000, "on its way")
        kernel.setParameter(cutoff, 500)
        kernel.render(frames: 512, left: left, right: right, gain: 1)
        XCTAssertEqual(kernel.parameter(cutoff), 500, "the newer value stands")
    }

    /// The plugin's view sets exactly the value a ramp is passing through — the musician stops
    /// the knob where it shows. That is a newer set and ends the ramp; the ramp did not overwrite it.
    func testSettingTheValueARampPassesThroughEndsTheRamp() {
        let cutoff = SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" } ?? -1
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 512)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        kernel.rampParameter(cutoff, to: 18_000, frames: 48_000)
        kernel.render(frames: 512, left: left, right: right, gain: 1)
        let shown = kernel.parameter(cutoff)
        kernel.setParameter(cutoff, shown)
        for _ in 0..<4 { kernel.render(frames: 512, left: left, right: right, gain: 1) }
        XCTAssertEqual(kernel.parameter(cutoff), shown, "the set stands, the ramp is over")
    }

    /// A ramp holds its goal once it is there; it does not fall back to the value set before it.
    func testARampHoldsItsGoalAndASetLaterStillWins() {
        let cutoff = SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" } ?? -1
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 512)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        kernel.setParameter(cutoff, 1_000)
        kernel.rampParameter(cutoff, to: 4_000, frames: 1_024)
        for _ in 0..<4 { kernel.render(frames: 512, left: left, right: right, gain: 1) }
        XCTAssertEqual(kernel.parameter(cutoff), 4_000)
        kernel.render(frames: 512, left: left, right: right, gain: 1)
        XCTAssertEqual(kernel.parameter(cutoff), 4_000, "held")
        kernel.setParameter(cutoff, 1_000)
        XCTAssertEqual(kernel.parameter(cutoff), 1_000, "a set reads back at once")
        kernel.render(frames: 512, left: left, right: right, gain: 1)
        XCTAssertEqual(kernel.parameter(cutoff), 1_000)
    }

    /// Another thread sets a value while the render thread runs a ramp the host started before
    /// it. Whatever the interleaving, the set is the value once the render thread has run again.
    func testASetFromAnotherThreadIsNeverOverwrittenByARamp() {
        let cutoff = SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" } ?? -1
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 64)
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer {
            left.deallocate()
            right.deallocate()
        }
        let rounds = 200
        let go = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            for _ in 0..<rounds {
                go.wait()
                kernel.setParameter(cutoff, 500)
                done.signal()
            }
        }
        kernel.setParameter(cutoff, 500)
        for round in 0..<rounds {
            kernel.rampParameter(cutoff, to: 18_000, frames: 48_000)
            go.signal()
            while done.wait(timeout: .now()) != .success {
                kernel.render(frames: 64, left: left, right: right, gain: 1)
            }
            kernel.render(frames: 64, left: left, right: right, gain: 1)
            XCTAssertEqual(kernel.parameter(cutoff), 500, "round \(round)")
            if kernel.parameter(cutoff) != 500 { break }
        }
    }
}
