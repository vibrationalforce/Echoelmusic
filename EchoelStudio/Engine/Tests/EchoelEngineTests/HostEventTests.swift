import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest

/// What a host's render events do to an instrument kernel (audit 2026-11-04): a two-byte MIDI
/// message used to be dropped.
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
}
