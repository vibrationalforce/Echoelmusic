// TheNormalizedPartReachesFullScaleTests.swift
// Echoel — Normalize on the part bar sets an audio part's level so its loudest sample in the
// stretch it plays reaches full scale (audio editor W9, founder 2026-10-08: "Die klassische DAW
// Audio Editing View fehlt mir noch.").
//
// WHY: W2 gave a part its own level, but finding the level that brings a quiet recording up to
// full scale was guesswork — drag, listen, drag again. Every DAW has the one-tap answer. W1 already
// reads each file's peaks for the canvas; W9 asks the same buckets for the loudest one.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `WaveformSketch.overlap`: the buckets a stretch overlaps; a stretch narrower
//    than a bucket takes its bucket; wholly before the file or past it, or degenerate, is none.
// 2. END-TO-END — `WaveformSketch.peak`: the loudest magnitude over exactly those buckets, a
//    negative extreme counting; NOT clamped (a float file above full scale reads above 1, which
//    the drawing clamps and the level must not); it agrees with a one-column `window` wherever the
//    drawing does not clamp — the one overlap rule (#416); outside the file and non-finite: none.
// 3. END-TO-END — `PartGain.normalizedGain`: target ÷ peak, held to the field's range (so a file
//    quieter than −6 dBFS comes up +6 dB, and one above full scale comes down); silence, a negative
//    or a non-finite peak: nothing; a peak whose reciprocal overflows: the ceiling. The real store
//    keeps exactly the level it computes.
// 4. END-TO-END — on a REAL two-second file: each half's peak, and the level each half gets.
// 5. SOURCE-TEXT SCAN — the leaf's `body` reads no store and no player (the work happens at the
//    tap); `normalize()` finds the canvas's own window, reads the file DETACHED, and writes once
//    through `setRegionGain`, in that order; the button is off while it reads.
// 6. SOURCE-TEXT SCAN — the overlap arithmetic exists ONCE in the sketch, and both `window` and
//    `peak` go through it.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `WaveformSketch.overlap`,
// `WaveformSketch.peak` and `PartGain.normalizedGain`, which this commit creates, so it does NOT
// COMPILE against the parent — no assertion has a verdict there. Hand-transcribed instead: claims
// 1–3 re-derived in Python on the same fixture (quarter-second buckets, so every boundary is exact);
// claim 4 by hand (48 kHz → 480 frames per bucket → buckets 0–99 are the first second). Claims 5–6
// are FORWARD guards (one absence on the parent, #486). How the level SOUNDS on a stretched part
// (warp or tape can move a peak a little once rendered) is a DEVICE PROBE and open.

import XCTest
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
@testable import Echoelmusic

@MainActor
final class TheNormalizedPartReachesFullScaleTests: XCTestCase {

    private static let bar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
    private static let sketch = "Sources/Echoelmusic/Sequencer/WaveformSketch.swift"

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
        try await super.tearDown()
    }

    /// Eight quarter-second buckets; b1 holds the first half's loudest sample as a NEGATIVE
    /// extreme, b4 is silence, b7 is a float file above full scale.
    private let eight = WaveformSketch.Overview(buckets: [
        WaveformBucket(min: -0.125, max: 0.25, rms: 0.125),
        WaveformBucket(min: -0.75, max: 0.5, rms: 0.25),
        WaveformBucket(min: 0, max: 0.375, rms: 0.25),
        WaveformBucket(min: -0.0625, max: 0.0625, rms: 0.03125),
        WaveformBucket(min: 0, max: 0, rms: 0),
        WaveformBucket(min: -0.25, max: 0.5, rms: 0.25),
        WaveformBucket(min: 0, max: 0.125, rms: 0.0625),
        WaveformBucket(min: -1.5, max: 1, rms: 0.5),
    ], secondsPerBucket: 0.25)

    // MARK: 1 — the one overlap rule

    func testAStretchOverlapsTheBucketsItTouches() {
        XCTAssertEqual(WaveformSketch.overlap(start: 0, end: 8, count: 8), 0..<8, "the whole file")
        XCTAssertEqual(WaveformSketch.overlap(start: 2, end: 6, count: 8), 2..<6, "a trimmed stretch")
        XCTAssertEqual(WaveformSketch.overlap(start: 2.5, end: 2.75, count: 8), 2..<3,
                       "a stretch narrower than a bucket takes the bucket it falls in")
        XCTAssertEqual(WaveformSketch.overlap(start: -1, end: 0.5, count: 8), 0..<1,
                       "a stretch that begins before the file reads the file it reaches")
        XCTAssertEqual(WaveformSketch.overlap(start: 7.5, end: 9, count: 8), 7..<8,
                       "a stretch that runs past the end reads the file it covers")
        XCTAssertNil(WaveformSketch.overlap(start: -2, end: 0, count: 8), "wholly before the file: none")
        XCTAssertNil(WaveformSketch.overlap(start: 8, end: 9, count: 8), "wholly past the end: none")
        XCTAssertNil(WaveformSketch.overlap(start: 0, end: 1, count: 0), "an empty overview: none")
        XCTAssertNil(WaveformSketch.overlap(start: .nan, end: 1, count: 8), "a position that is not a number: none")
        XCTAssertNil(WaveformSketch.overlap(start: 0, end: .infinity, count: 8), "an endless stretch: none")
    }

    // MARK: 2 — the peak of the part's stretch

    func testThePeakIsTheLoudestSampleOfTheStretch() {
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: 0, lengthSeconds: 1), 0.75,
                       "a negative extreme is as loud as a positive one")
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: 1, lengthSeconds: 0.5), 0.5, "a trimmed stretch")
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: 1, lengthSeconds: 0.25), 0, "a silent stretch peaks at 0")
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: 0.3, lengthSeconds: 0.1), 0.75, """
            a stretch inside one bucket reads that bucket's extreme — it can read high, never low, \
            so a level set from it errs quieter and never into a clip
            """)
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: -0.25, lengthSeconds: 0.5), 0.25,
                       "a part that begins before its file reads the file it reaches")
        XCTAssertEqual(WaveformSketch.peak(eight, fromSeconds: 0, lengthSeconds: 2), 1.5,
                       "the peak is NOT clamped: a float file above full scale reads above 1")

        // The one overlap rule: where the drawing does not clamp, a one-column window IS the peak.
        let stretches: [(Double, Double)] = [(0, 1), (1, 0.5), (0.3, 0.1), (-0.25, 0.5), (0.5, 0.75)]
        for (from, length) in stretches {
            let column = WaveformSketch.window(eight, fromSeconds: from, lengthSeconds: length, columns: 1, gain: 1)
            let drawn = column.first.map { Swift.max(abs($0.min), abs($0.max)) }
            XCTAssertEqual(drawn, WaveformSketch.peak(eight, fromSeconds: from, lengthSeconds: length),
                           "from \(from) s for \(length) s: the level and the wave disagree about the loudest sample")
        }
        let drawnWhole = WaveformSketch.window(eight, fromSeconds: 0, lengthSeconds: 2, columns: 1, gain: 1).first
        XCTAssertEqual(drawnWhole?.min, -1, "counterweight: the DRAWING clamps the over-full-scale bucket")

        XCTAssertNil(WaveformSketch.peak(eight, fromSeconds: 2, lengthSeconds: 1), "past the file's end: none")
        XCTAssertNil(WaveformSketch.peak(eight, fromSeconds: -1, lengthSeconds: 0.5), "before the file's start: none")
        XCTAssertNil(WaveformSketch.peak(eight, fromSeconds: 0, lengthSeconds: 0), "no length: none")
        XCTAssertNil(WaveformSketch.peak(eight, fromSeconds: .nan, lengthSeconds: 1), "no position: none")
        let flat = WaveformSketch.Overview(buckets: eight.buckets, secondsPerBucket: 0)
        XCTAssertNil(WaveformSketch.peak(flat, fromSeconds: 0, lengthSeconds: 1), "an overview without a timescale: none")
        let broken = WaveformSketch.Overview(buckets: [WaveformBucket(min: 0, max: .nan, rms: 0)], secondsPerBucket: 0.25)
        XCTAssertNil(WaveformSketch.peak(broken, fromSeconds: 0, lengthSeconds: 0.25),
                     "a non-finite bucket gives no peak — never a level computed from NaN")
    }

    // MARK: 3 — the level Normalize sets

    func testTheLevelBringsThePeakToTheTargetWithinTheFieldsRange() {
        let target = PartGain.normalizeTarget
        XCTAssertGreaterThan(target, 0)
        XCTAssertLessThanOrEqual(target, 1, "Normalize never aims past full scale — that would clip what it brings up")
        let top = Float(PartGain.range.upperBound)
        let bottom = Float(PartGain.range.lowerBound)

        XCTAssertEqual(PartGain.normalizedGain(forPeak: target), 1, "a part already at the target stays where it is")
        let peaks: [Float] = [0.25, 0.5, 0.75, 1, 1.5, 2, 4]
        for peak in peaks {
            let expected = Swift.min(top, Swift.max(bottom, target / peak))
            guard let level = PartGain.normalizedGain(forPeak: peak) else {
                XCTFail("a peak of \(peak) gets a level"); continue
            }
            XCTAssertEqual(level, expected, accuracy: 1e-6, "peak \(peak)")
            XCTAssertTrue(PartGain.range.contains(Double(level)), "peak \(peak): \(level) is outside the field's range")
        }
        XCTAssertEqual(PartGain.normalizedGain(forPeak: target / 8), top,
                       "a very quiet file comes up only as far as the field's ceiling (+6 dB)")
        XCTAssertEqual(PartGain.normalizedGain(forPeak: .leastNonzeroMagnitude), top,
                       "a peak whose reciprocal overflows gets the ceiling, not infinity")
        let nothing: [Float] = [0, -0.5, .nan, .infinity]
        for peak in nothing {
            XCTAssertNil(PartGain.normalizedGain(forPeak: peak), "peak \(peak): no level makes nothing loud")
        }

        // The real store keeps exactly what Normalize computes — its clamp is the field's range.
        let timeline = TimelineStore()
        let original = timeline.document
        restore.append { timeline.replaceDocument(original) }
        let audio = TimelineLane(name: "Loop", kind: .audio)
        let part = TimelineRegion(laneID: audio.id, clipID: UUID(), startTick: 0, lengthTicks: 1_920)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [part]))
        let quietPeaks: [Float] = [target / 8, target / 1.25, target * 2]
        for peak in quietPeaks {
            guard let level = PartGain.normalizedGain(forPeak: peak) else {
                XCTFail("a peak of \(peak) gets a level"); continue
            }
            timeline.setRegionGain(id: part.id, level)
            XCTAssertEqual(timeline.document.regions.first { $0.id == part.id }?.gain, level,
                           "peak \(peak): the store changed the level Normalize wrote")
        }
    }

    // MARK: 4 — a real file

    #if canImport(AVFoundation)

    private func writeWAV(frames: Int, fill: (Int) -> Float) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w9-normalize-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else {
            throw XCTSkip("no PCM buffer for the fixture")
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        for frame in 0..<frames { data[0][frame] = fill(frame) }
        try file.write(from: buffer)
        return url
    }

    func testARealFileNormalizesEachHalfByItsOwnPeak() throws {
        // Two seconds: ±0.25 alternating, then a steady 0.8.
        let url = try writeWAV(frames: 96_000) { frame in
            frame < 48_000 ? (frame % 2 == 0 ? 0.25 : -0.25) : 0.8
        }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let overview = WaveformSketch.overview(ofRef: url.path) else {
            return XCTFail("a readable WAV has an overview")
        }
        XCTAssertEqual(overview.buckets.count, 200, "96 000 frames at 480 per bucket")
        let quiet = WaveformSketch.peak(overview, fromSeconds: 0, lengthSeconds: 1)
        let loud = WaveformSketch.peak(overview, fromSeconds: 1, lengthSeconds: 1)
        XCTAssertEqual(quiet, 0.25, "the first second's loudest sample")
        XCTAssertEqual(loud, Float(0.8), "the second second's loudest sample")
        XCTAssertEqual(WaveformSketch.peak(overview, fromSeconds: 0, lengthSeconds: 2), Float(0.8))
        let top = Float(PartGain.range.upperBound)
        XCTAssertEqual(quiet.flatMap { PartGain.normalizedGain(forPeak: $0) },
                       Swift.min(top, PartGain.normalizeTarget / 0.25),
                       "the quiet half comes up — as far as the ceiling allows")
        guard let loudLevel = loud.flatMap({ PartGain.normalizedGain(forPeak: $0) }) else {
            return XCTFail("the loud half gets a level")
        }
        XCTAssertEqual(loudLevel, PartGain.normalizeTarget / Float(0.8), accuracy: 1e-6,
                       "the loud half comes up to the target, not to the ceiling")
    }

    #endif

    // MARK: 5 — the leaf does the work at the tap, off the main actor, and writes once

    func testNormalizeReadsDetachedAndWritesOnceThroughTheStore() throws {
        let code = try source(Self.bar)
        guard let leaf = code.range(of: "private struct PartGainField: View {"),
              let body = code.range(of: "var body: some View {", range: leaf.upperBound..<code.endIndex),
              let shown = code.range(of: "private var shownGain: Double {", range: body.upperBound..<code.endIndex),
              let action = code.range(of: "private func normalize() {", range: shown.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `PartGainField`'s body, `shownGain` or `normalize()` (#454)")
        }
        let rendered = String(code[body.upperBound..<shown.lowerBound])
        XCTAssertTrue(rendered.contains("Button { normalize() } label: {"), "the leaf no longer offers Normalize")
        XCTAssertTrue(rendered.contains("Text(\"Normalize\")"), "the button no longer says what it does")
        XCTAssertTrue(rendered.contains(".disabled(normalizing)"), "a second tap could start a second read of the file")
        XCTAssertEqual(code.components(separatedBy: "{ normalize() }").count - 1, 1, "one door to Normalize")
        for banned in ["clipStore", "player.", "timeline.document", "WaveformSketch."] {
            XCTAssertFalse(rendered.contains(banned), """
                `PartGainField.body` reads `\(banned)`. Normalize finds the part's file at the TAP; a \
                read in the body observes the store on every render of the part bar.
                """)
        }

        // To the leaf's column-0 close, not the end of the file (#408) — a later part-bar field
        // that wrote a part's gain would otherwise count as a second Normalize write.
        let afterAction = code[action.upperBound...]
        let work = String(afterAction[..<(afterAction.range(of: "\n}\n")?.lowerBound ?? afterAction.endIndex)])
        let steps = ["guard !normalizing,",
                     "ArrangeCanvas.audioWindow(for: region, clip: clipStore.clip(id: region.clipID),",
                     "bpm: player.preflightTempo)",
                     "normalizing = true",
                     "Task.detached(priority: .userInitiated) {",
                     "WaveformSketch.overview(ofRef: ref)",
                     "normalizing = false",
                     "WaveformSketch.peak(overview, fromSeconds: window.fromSeconds,",
                     "PartGain.normalizedGain(forPeak: peak)",
                     "timeline.setRegionGain(id: regionID, level)"]
        var cursor = work.startIndex
        for step in steps {
            guard let hit = work.range(of: step, range: cursor..<work.endIndex) else {
                return XCTFail("""
                    `normalize()` no longer does `\(step)` after the step before it. The order is the \
                    point: the canvas's own window, the file read DETACHED (it opens a whole file), the \
                    pure peak and level, then ONE write through the store's one region-gain writer.
                    """)
            }
            cursor = hit.upperBound
        }
        XCTAssertEqual(work.components(separatedBy: "setRegionGain(").count - 1, 1, "one write per Normalize")
    }

    // MARK: 6 — one overlap rule

    func testTheOverlapArithmeticExistsOnce() throws {
        let sketch = try source(Self.sketch)
        XCTAssertEqual(sketch.components(separatedBy: ".rounded(.down)").count - 1, 1, """
            the sketch rounds a bucket index down in more than one place — a second copy of the \
            overlap rule, and the level and the wave can disagree about which buckets a part covers
            """)
        guard let window = sketch.range(of: "nonisolated static func window("),
              let overlap = sketch.range(of: "nonisolated static func overlap(start: Double, end: Double, count: Int) -> Range<Int>? {"),
              let peak = sketch.range(of: "nonisolated static func peak(_ overview: Overview, fromSeconds: Double, lengthSeconds: Double) -> Float? {") else {
            return XCTFail("ANCHOR MISSING: `window`, `overlap` or `peak` in WaveformSketch (#454)")
        }
        XCTAssertLessThan(window.lowerBound, overlap.lowerBound)
        XCTAssertLessThan(overlap.lowerBound, peak.lowerBound)
        XCTAssertTrue(sketch[window.upperBound..<overlap.lowerBound].contains("overlap(start: start, end: end, count: count)"),
                      "`window` no longer finds its buckets through `overlap`")
        XCTAssertTrue(sketch[peak.upperBound...].contains("let span = overlap(start: fromSeconds / perBucket,"),
                      "`peak` no longer finds its buckets through `overlap`")
    }

    // MARK: helpers

    private static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: Self.root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }
}
