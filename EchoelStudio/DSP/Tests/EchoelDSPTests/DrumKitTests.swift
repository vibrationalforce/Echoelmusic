import XCTest
@testable import EchoelDSP

final class DrumKitTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(_ kit: inout DrumKit, seconds: Float) -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(seconds * rate))
        var start = 0
        while start < buffer.count {
            let end = Swift.min(start + 256, buffer.count)
            buffer[start..<end].withUnsafeMutableBufferPointer { kit.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func peak(_ samples: [Float]) -> Float { samples.reduce(0) { Swift.max($0, Swift.abs($1)) } }

    func testEveryPieceSoundsStaysBoundedAndEndsInSilence() {
        let pitches: [UInt8] = [36, 38, 39, 45, 50, 42, 46, 49]
        for pitch in pitches {
            var kit = DrumKit(sampleRate: rate)
            kit.noteOn(pitch: pitch, velocity: 127)
            let hit = render(&kit, seconds: 0.1)
            XCTAssertGreaterThan(peak(hit), 0.05, "pitch \(pitch)")
            XCTAssertLessThan(peak(hit), 2, "pitch \(pitch)")
            XCTAssertTrue(hit.allSatisfy(\.isFinite), "pitch \(pitch)")
            _ = render(&kit, seconds: 8)
            XCTAssertEqual(kit.activeVoiceCount, 0, "pitch \(pitch) never stopped")
        }
    }

    func testANoteOutsideTheKitIsSilent() {
        var kit = DrumKit(sampleRate: rate)
        kit.noteOn(pitch: 60, velocity: 127)
        kit.noteOn(pitch: 36, velocity: 0)
        XCTAssertEqual(peak(render(&kit, seconds: 0.05)), 0)
        XCTAssertEqual(kit.activeVoiceCount, 0)
    }

    func testVelocitySetsTheLevel() {
        var soft = DrumKit(sampleRate: rate), hard = DrumKit(sampleRate: rate)
        soft.noteOn(pitch: 36, velocity: 40)
        hard.noteOn(pitch: 36, velocity: 127)
        XCTAssertLessThan(peak(render(&soft, seconds: 0.1)), peak(render(&hard, seconds: 0.1)) * 0.5)
    }

    func testAClosedHatChokesTheOpenHat() {
        var kit = DrumKit(sampleRate: rate)
        kit.noteOn(pitch: 46, velocity: 127)
        _ = render(&kit, seconds: 0.02)
        kit.noteOn(pitch: 42, velocity: 127)
        _ = render(&kit, seconds: 0.4)
        XCTAssertEqual(kit.activeVoiceCount, 0, "both hats are done well before the open hat's own 2-second tail")
    }

    func testTheKitIsDeterministicAndNoteOffDoesNotCutAHit() {
        var a = DrumKit(sampleRate: rate), b = DrumKit(sampleRate: rate)
        a.noteOn(pitch: 38, velocity: 110)
        b.noteOn(pitch: 38, velocity: 110)
        b.noteOff(pitch: 38)
        b.allNotesOff()
        XCTAssertEqual(render(&a, seconds: 0.2), render(&b, seconds: 0.2))
    }

    /// A tom hit again while it still rings starts the new hit without a step in the waveform —
    /// a roll does not click on every hit — whatever point of its cycle the old hit stood at
    /// (audit 2026-10-23).
    func testAReHitOfARingingTomDoesNotClick() {
        for pitch: UInt8 in [45, 50] {
            var largest: Float = 0
            for gap in 100...150 {
                var kit = DrumKit(sampleRate: rate)
                kit.noteOn(pitch: pitch, velocity: 127)
                let before = render(&kit, seconds: Float(gap) / 1_000)
                kit.noteOn(pitch: pitch, velocity: 127)
                let after = render(&kit, seconds: 0.01)
                guard let last = before.last, let first = after.first else {
                    XCTFail("nothing rendered")
                    continue
                }
                largest = Swift.max(largest, Swift.abs(first - last))
            }
            XCTAssertLessThan(largest, 0.05, "pitch \(pitch)")
        }
    }

    func testABadSampleRateFallsBack() {
        var kit = DrumKit(sampleRate: .nan)
        kit.noteOn(pitch: 36, velocity: 100)
        XCTAssertTrue(render(&kit, seconds: 0.05).allSatisfy(\.isFinite))
    }
}
