// AnAudioPartShowsItsWaveformTests.swift
// Echoel — an audio part on the Arrange canvas draws the stretch of its file it plays (audio
// editor W1, founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.").
//
// WHY: an audio part was a plain tinted bar. Nothing said where the hits are, where the file goes
// quiet, or which stretch of the file a trimmed part plays — and the editing slices after this
// one (gain, trim, fades) need the audio to be SEEN before they can be judged by eye.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `framesPerBucket`: ~100 buckets per second, never more than `maxBuckets`,
//    and a refusal (0) for an empty file, a rate that is not a rate, or an absurd length.
// 2. END-TO-END — `window`: a column is the `WaveformReducer.downsample` join of the buckets it
//    overlaps; a trimmed window shows only its stretch; past the file's end is silence; a
//    column narrower than a bucket takes its bucket; the part's gain scales the picture and is
//    clamped to ±1; a non-finite value draws as silence; degenerate input draws nothing; the
//    column count is capped. `columns(forWidthPoints:)` rides along.
// 3. END-TO-END — `ArrangeCanvas.audioWindow`: the window is the PLAYER's — the part's own media
//    offset (not its place in the song), its length at the song tempo, times the warp rate; a
//    warped part's window is the same at every song tempo; a MIDI part, a missing clip or file,
//    and a tempo that is not a tempo get none.
// 4. END-TO-END — `overview(ofRef:)` on REAL files written here: a half-silent mono file reads
//    as silence then level, a stereo file folds to its louder channel, an unreadable or missing
//    file reads as nothing, and a CANCELLED read returns nothing.
// 5. SOURCE-TEXT SCAN — the leaf reads off the main actor, forwards cancellation, and drops a
//    read that lands after it was cancelled; it takes no touches, reads no hot state and adds
//    no presentation modifier. The read has exactly TWO callers — this leaf and, since W9, the
//    part bar's Normalize (`TheNormalizedPartReachesFullScaleTests` pins that one detached).
// 6. SOURCE-TEXT SCAN — the canvas hands each block its window from the same one read of the
//    clip grid; the block draws it between the note sketch and the name tag; the Workstation
//    hands the tempo in COLD.
// 7. COUNTERWEIGHTS (#343) — the premises: the reduction is `WaveformReducer`'s three functions
//    (#416); the player still windows a region by the same two calls; the app's injected
//    resolver is still `MediaLibrary.resolveRef` (#1439); `preflightTempo` is still
//    `@ObservationIgnored`.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `WaveformSketch`,
// `ArrangeCanvas.audioWindow` and `AudioPartWaveform`, which this commit creates, so it does NOT
// COMPILE against the parent — no assertion has a verdict there. Hand-transcribed instead:
// claims 1–2 re-derived in Python against the same algebra (power-of-two bucket widths, so every
// column boundary is exact; identity, trim, join, past-end, zoom-in, gain, non-finite,
// degenerate, cap — all as asserted); claim 3 by hand (one bar at 120 = 2 s; warped at native
// 60 = 4 s at 120 and at 90); claim 4 by hand (48 kHz → 480 frames per bucket → 100 buckets for
// one second). Claims 5–6 are FORWARD guards (one absence on the parent, #486); claim 7's four
// premises are COUNTERWEIGHTS, green on both trees. What the wave LOOKS like on a phone — legible
// on every track hue, smooth while pinching, quick to appear on a long file — is a DEVICE PROBE
// and open.

import XCTest
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
@testable import Echoelmusic

final class AnAudioPartShowsItsWaveformTests: XCTestCase {

    private static let leaf = "Sources/Echoelmusic/Studio/AudioPartWaveform.swift"
    private static let sketch = "Sources/Echoelmusic/Sequencer/WaveformSketch.swift"
    private static let partBar = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let lanePlayer = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"
    private static let regionPlayer = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: 1 — the overview's resolution

    func testTheOverviewHasAHundredBucketsASecondAndACap() {
        XCTAssertEqual(WaveformSketch.framesPerBucket(totalFrames: 48_000 * 60, sampleRate: 48_000), 480,
                       "a minute at 48 kHz: 100 buckets per second")
        XCTAssertEqual(WaveformSketch.framesPerBucket(totalFrames: 44_100 * 60, sampleRate: 44_100), 441)
        XCTAssertEqual(WaveformSketch.framesPerBucket(totalFrames: 10, sampleRate: 48_000), 480,
                       "a file shorter than a bucket still gets one")
        // Ten minutes would be 60 000 buckets at 100/s: the cap makes them coarser instead.
        let long = WaveformSketch.framesPerBucket(totalFrames: 48_000 * 600, sampleRate: 48_000)
        XCTAssertEqual(long, 1_758, "ceil(28 800 000 / 16 384) frames per bucket")
        XCTAssertLessThanOrEqual((48_000 * 600 + long - 1) / long, WaveformSketch.maxBuckets)
        let refused: [(Int64, Double)] = [(0, 48_000), (100, .nan), (100, 0), (100, -1), (.max, 48_000)]
        for (frames, rate) in refused {
            XCTAssertEqual(WaveformSketch.framesPerBucket(totalFrames: frames, sampleRate: rate), 0,
                           "\(frames) frames at \(rate) Hz is refused, never half-read")
        }
    }

    // MARK: 2 — a column is the reducer's join of what it overlaps

    /// Eight buckets of a quarter second each — a power of two, so every boundary is exact.
    private static let eight: WaveformSketch.Overview = {
        let buckets: [WaveformBucket] = (0..<8).map {
            WaveformBucket(min: -Float($0) / 10, max: Float($0) / 10, rms: Float($0) / 20)
        }
        return WaveformSketch.Overview(buckets: buckets, secondsPerBucket: 0.25)
    }()

    func testAColumnIsTheJoinOfTheBucketsItOverlaps() {
        let all = Self.eight.buckets
        XCTAssertEqual(WaveformSketch.window(Self.eight, fromSeconds: 0, lengthSeconds: 2, columns: 8, gain: 1),
                       all, "one column per bucket draws every bucket as it is")
        XCTAssertEqual(WaveformSketch.window(Self.eight, fromSeconds: 0.5, lengthSeconds: 1, columns: 4, gain: 1),
                       Array(all[2..<6]), "a trimmed part shows only its own stretch of the file")
        let joined = WaveformSketch.window(Self.eight, fromSeconds: 0, lengthSeconds: 2, columns: 4, gain: 1)
        XCTAssertEqual(joined.count, 4)
        for (index, column) in joined.enumerated() {
            let pair = Array(all[(2 * index)..<(2 * index + 2)])
            XCTAssertEqual(column, WaveformReducer.downsample(pair, factor: 2).first,
                           "column \(index) is the reducer's own join of its two buckets (#416)")
        }
        let tail = WaveformSketch.window(Self.eight, fromSeconds: 1.5, lengthSeconds: 1, columns: 4, gain: 1)
        XCTAssertEqual(tail, [all[6], all[7], WaveformSketch.silent, WaveformSketch.silent],
                       "past the file's end the part plays silence, and draws it")
        XCTAssertEqual(WaveformSketch.window(Self.eight, fromSeconds: 0.25, lengthSeconds: 0.25, columns: 4, gain: 1),
                       Array(repeating: all[1], count: 4),
                       "zoomed in past the overview, each column takes the bucket it falls in")
        XCTAssertEqual(WaveformSketch.window(Self.eight, fromSeconds: 0, lengthSeconds: 2, columns: 5_000, gain: 1).count,
                       WaveformSketch.maxColumns, "a part never draws more than the column cap")
    }

    func testThePartsGainScalesThePictureAndNothingNonFiniteIsDrawn() {
        let loud = WaveformSketch.Overview(buckets: [WaveformBucket(min: -0.7, max: 0.7, rms: 0.35)],
                                           secondsPerBucket: 1)
        XCTAssertEqual(WaveformSketch.window(loud, fromSeconds: 0, lengthSeconds: 1, columns: 1, gain: 2),
                       [WaveformBucket(min: -1, max: 1, rms: Float(0.35) * 2)],
                       "a part at +6 dB draws its peaks clipped to the block, its body doubled")
        XCTAssertEqual(WaveformSketch.window(loud, fromSeconds: 0, lengthSeconds: 1, columns: 1, gain: 0.5),
                       [WaveformBucket(min: Float(-0.7) * 0.5, max: Float(0.7) * 0.5, rms: Float(0.35) * 0.5)],
                       "a quieter part draws a smaller wave")
        let broken = WaveformSketch.Overview(buckets: [WaveformBucket(min: .nan, max: .infinity, rms: 0.5)],
                                             secondsPerBucket: 1)
        XCTAssertEqual(WaveformSketch.window(broken, fromSeconds: 0, lengthSeconds: 1, columns: 1, gain: 1),
                       [WaveformBucket(min: 0, max: 0, rms: 0.5)],
                       "a non-finite sample from a damaged file draws as silence, never as a NaN rect")
        let empty = WaveformSketch.Overview(buckets: [], secondsPerBucket: 0.25)
        let degenerate: [(WaveformSketch.Overview, Double, Double, Int)] = [
            (Self.eight, 0, 0, 8), (Self.eight, 0, .nan, 8), (Self.eight, .infinity, 1, 8),
            (Self.eight, 0, 1, 0), (empty, 0, 1, 8),
        ]
        for (overview, from, length, columns) in degenerate {
            XCTAssertEqual(WaveformSketch.window(overview, fromSeconds: from, lengthSeconds: length,
                                                 columns: columns, gain: 1), [],
                           "from \(from), length \(length), \(columns) columns draws nothing")
        }
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: 100), 50, "one column per two points")
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: 3), 2)
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: 0.5), 1)
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: 1e9), WaveformSketch.maxColumns)
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: 0), 0)
        XCTAssertEqual(WaveformSketch.columns(forWidthPoints: .nan), 0)
    }

    // MARK: 3 — the window is the player's

    func testTheWindowIsTheStretchOfTheFileThePartPlays() {
        let bar = TimelineTime.ticksPerBar
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav")
        let part = TimelineRegion(laneID: UUID(), clipID: clip.id, startTick: 3 * bar, lengthTicks: bar,
                                  contentOffsetSeconds: 1.5, gain: 0.5)
        XCTAssertEqual(ArrangeCanvas.audioWindow(for: part, clip: clip, bpm: 120),
                       ArrangeCanvas.AudioWindow(mediaRef: "loop.wav", fromSeconds: 1.5, lengthSeconds: 2, gain: 0.5,
                                                 fadeIn: 0, fadeOut: 0),
                       "a part at bar 4 starts at ITS OWN offset into the file and runs one bar at 120 — 2 s")

        let warpedClip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav", nativeBPM: 60)
        let warped = TimelineRegion(laneID: UUID(), clipID: warpedClip.id, startTick: 0, lengthTicks: bar,
                                    contentOffsetSeconds: 1.5, warpEnabled: true)
        for songBPM in [120.0, 90.0] {
            guard let window = ArrangeCanvas.audioWindow(for: warped, clip: warpedClip, bpm: songBPM) else {
                return XCTFail("a warped audio part at \(songBPM) has a window")
            }
            XCTAssertEqual(window.fromSeconds, 1.5, accuracy: 1e-12)
            XCTAssertEqual(window.lengthSeconds, TimelineTime.seconds(fromTicks: bar, bpm: 60), accuracy: 1e-9,
                           "a warped part plays one bar of the file at ITS tempo, whatever the song's is")
        }

        let midi = Clip(name: "Keys", kind: .midi, mediaRef: "loop.wav")
        let silent = Clip(name: "Gone", kind: .audio)
        let blank = Clip(name: "Blank", kind: .audio, mediaRef: "")
        XCTAssertNil(ArrangeCanvas.audioWindow(for: part, clip: midi, bpm: 120), "a MIDI part keeps its note sketch")
        XCTAssertNil(ArrangeCanvas.audioWindow(for: part, clip: nil, bpm: 120), "a part whose clip is gone stays plain")
        XCTAssertNil(ArrangeCanvas.audioWindow(for: part, clip: silent, bpm: 120), "no file, no wave")
        XCTAssertNil(ArrangeCanvas.audioWindow(for: part, clip: blank, bpm: 120), "an empty ref is no file")
        let notTempos: [Double] = [0, -120, .nan, .infinity]
        for bpm in notTempos {
            XCTAssertNil(ArrangeCanvas.audioWindow(for: part, clip: clip, bpm: bpm), "\(bpm) is not a tempo")
        }
    }

    // MARK: 4 — the overview of a real file

    #if canImport(AVFoundation)

    /// A float WAV at 48 kHz, written here, whose channels are `fill(channel, frame)`.
    private func writeWAV(channels: Int, frames: Int, fill: (Int, Int) -> Float) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w1-waveform-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: channels,
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
        for channel in 0..<channels {
            for frame in 0..<frames { data[channel][frame] = fill(channel, frame) }
        }
        try file.write(from: buffer)
        return url
    }

    func testARealFileReadsAsItsOverview() throws {
        // One second: silence, then a level of 0.5 from the half-second on.
        let mono = try writeWAV(channels: 1, frames: 48_000) { _, frame in frame < 24_000 ? 0 : 0.5 }
        defer { try? FileManager.default.removeItem(at: mono) }
        guard let overview = WaveformSketch.overview(ofRef: mono.path) else {
            return XCTFail("a readable WAV has an overview")
        }
        XCTAssertEqual(overview.buckets.count, 100, "48 000 frames at 480 per bucket")
        XCTAssertEqual(overview.secondsPerBucket, 0.01, accuracy: 1e-12)
        XCTAssertEqual(overview.buckets[49], WaveformSketch.silent, "the last bucket of the silent half")
        XCTAssertEqual(overview.buckets[50], WaveformBucket(min: 0.5, max: 0.5, rms: 0.5),
                       "the first bucket of the level")
        XCTAssertEqual(WaveformSketch.window(overview, fromSeconds: 0.5, lengthSeconds: 0.5, columns: 1, gain: 1),
                       [WaveformBucket(min: 0.5, max: 0.5, rms: 0.5)],
                       "a part trimmed to the second half shows only the level")

        // Stereo: the louder channel wins each sample (`WaveformReducer.foldStereo`).
        let stereo = try writeWAV(channels: 2, frames: 24_000) { channel, _ in channel == 0 ? 0.25 : -0.75 }
        defer { try? FileManager.default.removeItem(at: stereo) }
        guard let folded = WaveformSketch.overview(ofRef: stereo.path) else {
            return XCTFail("a readable stereo WAV has an overview")
        }
        XCTAssertEqual(folded.buckets.count, 50)
        XCTAssertEqual(folded.buckets.first, WaveformBucket(min: -0.75, max: -0.75, rms: 0.75),
                       "a hard-panned hit stays visible: the louder channel is drawn")

        let text = FileManager.default.temporaryDirectory
            .appendingPathComponent("w1-not-audio-\(UUID().uuidString).wav")
        try Data("not audio".utf8).write(to: text)
        defer { try? FileManager.default.removeItem(at: text) }
        XCTAssertNil(WaveformSketch.overview(ofRef: text.path), "a file that is not audio reads as nothing")
        XCTAssertNil(WaveformSketch.overview(ofRef: "/nonexistent/w1-\(UUID().uuidString).wav"),
                     "a file that does not resolve reads as nothing")
    }

    func testACancelledReadReturnsNothing() async throws {
        let url = try writeWAV(channels: 1, frames: 48_000) { _, _ in 0.5 }
        defer { try? FileManager.default.removeItem(at: url) }
        let path = url.path
        let cancelled = Task.detached { () -> WaveformSketch.Overview? in
            withUnsafeCurrentTask { task in
                if let task { task.cancel() }
            }
            return WaveformSketch.overview(ofRef: path)
        }
        let result = await cancelled.value
        XCTAssertNil(result, "a read whose part went away stops at the first chunk and lands nothing")
    }

    #endif

    // MARK: 5 — the leaf reads off the main actor, once, and is cold

    func testTheLeafReadsOffTheMainActorAndDropsAStaleRead() throws {
        let leaf = try code(Self.leaf)
        XCTAssertTrue(leaf.contains("@State private var overview: WaveformSketch.Overview?"))
        XCTAssertEqual(leaf.components(separatedBy: "@State").count - 1, 1, "one piece of state: the overview")
        guard let task = leaf.range(of: ".task(id: window.mediaRef) {"),
              let hop = leaf.range(of: "Task.detached(priority: .utility) {", range: task.upperBound..<leaf.endIndex),
              let read = leaf.range(of: "WaveformSketch.overview(ofRef: ref)", range: hop.upperBound..<leaf.endIndex),
              let handler = leaf.range(of: "withTaskCancellationHandler {", range: read.upperBound..<leaf.endIndex),
              let forward = leaf.range(of: "reader.cancel()", range: handler.upperBound..<leaf.endIndex),
              let stale = leaf.range(of: "guard !Task.isCancelled else { return }", range: forward.upperBound..<leaf.endIndex),
              let land = leaf.range(of: "self.overview = read", range: stale.upperBound..<leaf.endIndex) else {
            return XCTFail("""
                `AudioPartWaveform` no longer reads in this order: a `.task` keyed on the file, a \
                detached read, the cancellation forwarded into it, a stale read dropped, then the \
                landing. Each step is a reason the read is off the main actor and never lands late.
                """)
        }
        XCTAssertLessThan(task.lowerBound, land.lowerBound)
        XCTAssertTrue(leaf.contains(".allowsHitTesting(false)"), "a tap or a hold on the wave reaches the block")
        XCTAssertTrue(leaf.contains(".accessibilityHidden(true)"), "the block speaks for the part")
        for banned in ["currentTick", "player", "TimelineView(", "Timer", "@Environment", "UserDefaults",
                       ".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(leaf.contains(banned), """
                `AudioPartWaveform` contains `\(banned)`. It draws a file it read once: no position, \
                no clock, no store, and no presentation modifier (the black-screen ceiling).
                """)
        }
        let readers = try sourceFiles { $0.contains("WaveformSketch.overview(") }
        XCTAssertEqual(readers, [Self.leaf, Self.partBar], """
            `WaveformSketch.overview(` is called from \(readers). It opens and reads a whole file; \
            its two callers — this leaf and the part bar's Normalize (W9) — each run it inside \
            `Task.detached`. A caller on the main actor would stall the canvas for the length of \
            the file: pin a new one detached, in its own guard, before adding it here.
            """)
        let sketch = try code(Self.sketch)
        XCTAssertTrue(sketch.contains("nonisolated static func overview(ofRef ref: String) -> Overview? {"))
        guard let loop = sketch.range(of: "while file.framePosition < file.length {"),
              let check = sketch.range(of: "if Task.isCancelled { return nil }", range: loop.upperBound..<sketch.endIndex),
              let chunk = sketch.range(of: "try file.read(into: buffer", range: check.upperBound..<sketch.endIndex) else {
            return XCTFail("the read no longer checks for cancellation before each chunk")
        }
        XCTAssertLessThan(check.lowerBound, chunk.lowerBound)
        XCTAssertTrue(sketch.contains("guard let url = MediaLibrary.resolveRef(ref),"),
                      "the file is found by the player's own resolver (#1439)")
    }

    // MARK: 6 — the canvas hands the window over; the block draws it

    func testTheCanvasHandsEachAudioPartItsWindowCold() throws {
        let file = try code(Self.canvas)
        guard let lane = file.range(of: "private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {"),
              let laneEnd = file.range(of: "private func drop(", range: lane.upperBound..<file.endIndex),
              let blockStart = file.range(of: "struct ArrangePartBlock: View {"),
              let pure = file.range(of: "nonisolated static func audioWindow(for region: TimelineRegion, clip: Clip?,"),
              let pureEnd = file.range(of: "struct ArrangeCanvasView: View {"),
              pure.upperBound < pureEnd.lowerBound else {
            return XCTFail("ANCHOR MISSING: `laneRow`, `drop`, `ArrangePartBlock` or `audioWindow` (#454)")
        }
        let laneBody = String(file[lane.upperBound..<laneEnd.lowerBound])
        XCTAssertTrue(laneBody.contains("let waves = clips.compactMapValues { ArrangeCanvas.audioWindow(for: $0.0, clip: $0.1, bpm: bpm) }"),
                      "each audio part's window comes from the same one read of the clip grid")
        XCTAssertTrue(laneBody.contains("audio: waves[block.id],"), "and each block gets its own")

        let block = String(file[blockStart.upperBound...])
        XCTAssertTrue(block.contains("let audio: ArrangeCanvas.AudioWindow?"))
        XCTAssertTrue(block.contains("AudioPartWaveform(window: audio, tint: tint)"))
        guard let notes = block.range(of: ".overlay { noteSketch }"),
              let wave = block.range(of: ".overlay { audioSketch }"),
              let tag = block.range(of: ".overlay(alignment: .topLeading) { nameTag }") else {
            return XCTFail("ANCHOR MISSING: the block's note, wave and name overlays (#454)")
        }
        XCTAssertLessThan(notes.lowerBound, wave.lowerBound)
        XCTAssertLessThan(wave.lowerBound, tag.lowerBound,
                          "the wave sits under the name tag and the selection ring, like the note sketch")

        let window = String(file[pure.upperBound..<pureEnd.lowerBound])
        for needle in ["StretchPlan.resolve(mode: region.stretchMode, warpEnabled: region.warpEnabled,",
                       "capabilities: StretchMode.timelineCapabilities)",
                       "AudioRegionPlayback.filePositionSeconds(for: region, atTick: region.startTick,",
                       "TimelineTime.seconds(fromTicks: region.lengthTicks, bpm: bpm) * plan.rate"] {
            XCTAssertTrue(window.contains(needle), "`audioWindow` lost `\(needle)` — the player's own window (#416)")
        }

        let workstation = try code(Self.workstation)
        guard let door = workstation.range(of: "ArrangeCanvasView(rows: arrangeRows, document: timeline.document,") else {
            return XCTFail("ANCHOR MISSING: the canvas door in the Workstation (#454)")
        }
        XCTAssertTrue(workstation[door.upperBound...].prefix(160).contains("bpm: player.preflightTempo,"),
                      "the tempo arrives cold — `preflightTempo` is not observed")
    }

    // MARK: 7 — counterweights: the premises the picture stands on

    func testThePremisesStillHold() throws {
        let sketch = try code(Self.sketch)
        for needle in ["WaveformReducer.foldStereo(", "WaveformReducer.reduce(folded, bucketSize: perBucket)",
                       "WaveformReducer.downsample("] {
            XCTAssertTrue(sketch.contains(needle), "the reduction is the reducer's (#416): `\(needle)` is gone")
        }
        let lanes = try code(Self.lanePlayer)
        XCTAssertTrue(lanes.contains("AudioRegionPlayback.filePositionSeconds(for: region, atTick: tick,"),
                      "the player still finds the media position by this function — the canvas asks the same one")
        XCTAssertTrue(lanes.contains("TimelineTime.seconds(fromTicks: region.endTick - tick, bpm: bpm)"),
                      "the player still measures the remaining length in song time, then times the rate")
        let app = try code(Self.app)
        XCTAssertTrue(app.contains("return MediaLibrary.resolveRef(clip.mediaRef)"),
                      "the player's injected resolver is still `MediaLibrary.resolveRef` — the one the read asks")
        let player = try code(Self.regionPlayer)
        XCTAssertTrue(player.contains("@ObservationIgnored public var preflightTempo"),
                      "the tempo the canvas is handed is not observed, so a glide never re-renders it")
    }

    // MARK: helpers

    private static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func code(_ relativePath: String) throws -> String {
        let text = try String(contentsOf: Self.root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }

    /// The `Sources/` files whose code (comments stripped) satisfies `matches`, repo-relative, sorted.
    private func sourceFiles(_ matches: (String) -> Bool) throws -> [String] {
        let base = Self.root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate Sources/ — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8) else {
                continue
            }
            if matches(SourceText.codeOnly(text)) { hits.append("Sources/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
