import EchoelCore
import XCTest
@testable import EchoelEngine

final class RecordingTests: XCTestCase {
    private func write(_ ring: AudioRing, _ values: [Float]) -> Int {
        values.withUnsafeBufferPointer { b in b.baseAddress.map { ring.write($0, count: b.count) } ?? 0 }
    }

    private func read(_ ring: AudioRing, _ count: Int) -> [Float] {
        var out = [Float](repeating: -1, count: count)
        let n = out.withUnsafeMutableBufferPointer { b in b.baseAddress.map { ring.read(into: $0, count: count) } ?? 0 }
        return Array(out.prefix(n))
    }

    func testTheRingKeepsOrderAcrossTheWrap() {
        let ring = AudioRing(capacity: 5)
        XCTAssertEqual(write(ring, [1, 2, 3]), 3)
        XCTAssertEqual(read(ring, 2), [1, 2])
        XCTAssertEqual(write(ring, [4, 5, 6, 7]), 4)
        XCTAssertEqual(ring.available, 5)
        XCTAssertEqual(read(ring, 10), [3, 4, 5, 6, 7])
        XCTAssertEqual(read(ring, 1), [])
    }

    func testAFullRingDropsAndCountsInsteadOfWaiting() {
        let ring = AudioRing(capacity: 4)
        XCTAssertEqual(write(ring, [1, 2, 3, 4, 5, 6]), 4)
        XCTAssertEqual(ring.dropped, 2)
        XCTAssertEqual(read(ring, 4), [1, 2, 3, 4])
    }

    func testDiscardingDropsWhatAnEarlierTakeLeft() {
        let ring = AudioRing(capacity: 8)
        _ = write(ring, [1, 2, 3])
        ring.discardAvailable()
        XCTAssertEqual(ring.available, 0)
        _ = write(ring, [4])
        XCTAssertEqual(read(ring, 4), [4])
    }

    func testATakeLinesUpWithTheBeatItWasPlayedTo() {
        // 120 BPM at 48 kHz: one tick is 25 samples, one beat 24,000.
        let time = TimeConversion(bpm: 120, sampleRate: 48_000)
        let exact = RecordingPlacement.place(startSample: 24_000, latency: 0, time: time)
        XCTAssertEqual(exact.start, 960)
        XCTAssertEqual(exact.offset, 0)

        // 480 samples of round-trip latency: the true start is 23,520, between ticks 940 and 941.
        let late = RecordingPlacement.place(startSample: 24_000, latency: 480, time: time)
        XCTAssertEqual(late.start, 941)
        XCTAssertEqual(late.offset, 5)
        XCTAssertEqual(time.sample(at: late.start) - Int64(late.offset), 23_520)

        // Recording from the very start: the latency is skipped from the take itself.
        let early = RecordingPlacement.place(startSample: 100, latency: 480, time: time)
        XCTAssertEqual(early.start, 0)
        XCTAssertEqual(early.offset, 380)
    }

    /// A take is placed with the tempo map in force when its first frame was stamped — the one the
    /// app's engine keeps with the take (`RecordedTake.tempoMap`) — never the map at the stop: a
    /// followed clock drifts, and the engine keeps the song's musical position across each change,
    /// so the same output sample names a later tick under the later map (review 2026-10-28, 2.2).
    func testATakeIsPlacedWithTheMapItBeganUnder() {
        let began = TimeConversion(bpm: 120, sampleRate: 48_000)
        // Bar 33 of 4/4 at 120 BPM: 128 beats, 64 s, 3 072 000 samples.
        let bar33 = 32 * MusicalTime.ticksPerBar(.common)
        let stamped = began.sample(at: bar33)
        let placed = RecordingPlacement.place(startSample: stamped, latency: 0, time: began)
        XCTAssertEqual(placed.start, bar33)
        XCTAssertEqual(placed.offset, 0)

        // The clock drifted half a BPM by the stop; with that map the take lands a beat late.
        let stopped = TimeConversion(bpm: 120.5, sampleRate: 48_000)
        let late = RecordingPlacement.place(startSample: stamped, latency: 0, time: stopped)
        XCTAssertGreaterThan(late.start - bar33, MusicalTime.ticksPerQuarter / 2)
    }
}
