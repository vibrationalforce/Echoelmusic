import EchoelCore
import XCTest
@testable import EchoelEngine

/// The Field of a video export: each frame's peak from the mix, the meter's hold and fall, the
/// song's tempo map, and the rule the export is built on — the same song gives the same film, and
/// no frame carries a body reading.
final class FieldExportTests: XCTestCase {
    /// Frame n of a 48 kHz mix is samples n·1600 ..< (n + 1)·1600, however the blocks fall.
    func testEachFramesPeakIsTheLoudestSampleOfItsStretch() {
        var left = [Float](repeating: 0, count: 1_600 * 3 + 400)
        var right = left
        left[100] = 0.5
        right[1_599] = -0.8      // frame 0's last sample
        left[1_600] = 0.25       // frame 1's first
        right[3_500] = .nan      // frame 2: a bad sample is silence
        left[3_501] = 0.1
        left[4_900] = 0.9        // frame 3, which the mix ends inside
        var peaks = FieldExport.Peaks(sampleRate: 48_000)
        var start = 0
        for size in [1_000, 777, 3_000, 2_000] where start < left.count {
            let count = Swift.min(size, left.count - start)
            left.withUnsafeBufferPointer { leftSamples in
                right.withUnsafeBufferPointer { rightSamples in
                    guard let leftBase = leftSamples.baseAddress, let rightBase = rightSamples.baseAddress else { return }
                    peaks.add(left: leftBase + start, right: rightBase + start, count: count)
                }
            }
            start += count
        }
        XCTAssertEqual(peaks.peaks, [0.8, 0.25, 0.1])
        XCTAssertEqual(peaks.finished, [0.8, 0.25, 0.1, 0.9], "the mix ends inside frame 3, and it counts")
        XCTAssertEqual(FieldExport.Peaks(sampleRate: 48_000).finished, [], "no mix, no frames")
    }

    /// The level falls 20 dB a second after a peak, as on the master meter, through the square root.
    func testTheLevelHoldsAndFallsLikeTheMeter() {
        var peaks = [Float](repeating: 0, count: 61)
        peaks[0] = 1
        let levels = FieldExport.levels(peaks: peaks)
        XCTAssertEqual(levels[0], 1, accuracy: 1e-12)
        XCTAssertEqual(levels[30], 0.1.squareRoot(), accuracy: 1e-9, "a tenth after one second")
        XCTAssertEqual(levels[60], 0.01.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(FieldExport.levels(peaks: [.nan, .infinity, -0.25]), [0, 0, 0.5],
                       "a sample that is no number is silence; a negative peak counts by its size")
    }

    /// At 120 BPM in 4/4 a beat is half a second and a bar two.
    func testTheFramesFollowTheSongsTempoMap() {
        let project = Project(tempo: 120, timeSignature: .common, context: MusicalContext(root: 9))
        let frames = FieldExport.frames(of: project, fromSeconds: 0, count: 61, levels: [0.5])
        XCTAssertEqual(frames.count, 61)
        XCTAssertEqual(frames[0].level, 0.5)
        XCTAssertEqual(frames[1].level, 0, "past the mix the level is silence")
        XCTAssertEqual(frames[7].beatPhase, 7.0 / 15, accuracy: 1e-9, "7/30 s is 0.47 of a beat")
        XCTAssertEqual(frames[22].beatPhase, 7.0 / 15, accuracy: 1e-9, "22/30 s: the second beat, as far in")
        XCTAssertEqual(frames[22].barPhase, 22.0 / 60, accuracy: 1e-9)
        XCTAssertEqual(frames[0].tonicHz, 440, accuracy: 1e-9, "A at the song's concert pitch")
        XCTAssertTrue(frames.allSatisfy(\.isPlaying))
        let later = FieldExport.frames(of: project, fromSeconds: 2.1, count: 2, levels: [])
        XCTAssertEqual(later[0].barPhase, 0.05, accuracy: 1e-9, "a short export starts where its bars start")
        XCTAssertEqual(later[0].beatPhase, 0.2, accuracy: 1e-9)
        XCTAssertTrue(FieldExport.frames(of: project, fromSeconds: .nan, count: -3, levels: []).isEmpty)
    }

    /// The rule the export is built on: its Field comes from the song and the mix alone. Two
    /// exports of one song are the same film, frame for frame, and no frame carries a body reading
    /// — a pulse measured while the musician exports changes nothing.
    func testTwoExportsOfOneSongAreTheSameFilm() {
        let project = Project(tempo: 97, tempoChanges: [TempoChange(tick: 7_680, bpm: 132)], timeSignature: .common)
        let peaks = (0..<900).map { (index: Int) -> Float in Float(index % 17) / 17 }
        let levels = FieldExport.levels(peaks: peaks)
        let frames = FieldExport.frames(of: project, fromSeconds: 1.5, count: 900, levels: levels)
        let first = FieldExport.motion(frames)
        let second = FieldExport.motion(FieldExport.frames(of: project, fromSeconds: 1.5, count: 900, levels: levels))
        XCTAssertEqual(first.count, 900)
        XCTAssertEqual(first, second)
        XCTAssertTrue(frames.allSatisfy { $0.pulse == nil && $0.hrv == nil && $0.coherence == nil && $0.breath == nil })
        XCTAssertTrue(first.allSatisfy { !$0.hasPulse && !$0.hasCoherence && $0.pulsePhase == 0 })
        XCTAssertGreaterThan(first.map(\.beatLight).max() ?? 0, 0.3, "full detail, never still: the beat ring shows")
        XCTAssertGreaterThan(Set(first.map(\.fieldPhase)).count, 100, "and the field drifts with the bars")
    }

    func testTheFrameAtATimeIsTheNearestOfTheFilm() {
        XCTAssertEqual(FieldExport.index(at: 0, count: 90), 0)
        XCTAssertEqual(FieldExport.index(at: 1.0 / 30, count: 90), 1)
        XCTAssertEqual(FieldExport.index(at: 2.999 / 30, count: 90), 3, "a time a hair early is still its frame")
        XCTAssertEqual(FieldExport.index(at: 1_000, count: 90), 89, "past the film: its last frame")
        XCTAssertEqual(FieldExport.index(at: .nan, count: 90), 0)
        XCTAssertEqual(FieldExport.index(at: -1, count: 90), 0)
        XCTAssertEqual(FieldExport.index(at: 5, count: 0), 0)
    }

    /// What the video window previews: the song as it plays, without the body.
    func testWithoutBodyKeepsTheSongAndDropsTheBody() {
        let live = FieldFrame(beatPhase: 0.25, barPhase: 0.5, tonicHz: 330, level: 0.4, pulse: 0.5, hrv: 0.3,
                              coherence: 0.7, breath: 0.6, isPlaying: true)
        let frozen = live.withoutBody
        XCTAssertNil(frozen.pulse)
        XCTAssertNil(frozen.hrv)
        XCTAssertNil(frozen.coherence)
        XCTAssertNil(frozen.breath)
        XCTAssertEqual(frozen.beatPhase, live.beatPhase)
        XCTAssertEqual(frozen.barPhase, live.barPhase)
        XCTAssertEqual(frozen.tonicHz, live.tonicHz)
        XCTAssertEqual(frozen.level, live.level)
        XCTAssertTrue(frozen.isPlaying)
    }
}
