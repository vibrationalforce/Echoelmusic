// TheAudioPartHasAnEditorTests.swift
// Echoel — GMMW AE-2 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir
// noch."). The selected audio part opens its whole file on the Part page, its window marked.
//
// WHAT THIS GUARDS. `AudioPartEditorView` mounts on the selected track's Part page, above the
// part list, and draws the selected AUDIO part's whole file: the stretch the part plays bright,
// the rest dimmed, the song's position as a line. It was read-only in AE-2; AE-4b's edge handles
// are pinned in `ThePartEdgeMovesOnTheGridItCanPlayTests`.
//
// THE CLAIMS.
//   1–5. END-TO-END BEHAVIOUR over the pure half (`AudioPartEditor`), on shipped value types:
//        which part is the editor's (only the selected one, only on this track), that its window
//        IS the canvas's (`ArrangeCanvas.audioWindow`, #416), the file length it draws against,
//        where the part and the song sit on the file, and what the header says when the file is
//        missing. Expectations are written from the algebra (#442): one bar at 120 BPM is 2 s.
//   6.   SOURCE-TEXT SCAN of `AudioPartEditorView.swift`: no modal of any kind; no `AVAudioFile(`;
//        the song position (`currentTick`, `isPlaying`) read only inside the playhead leaf; the
//        file read detached, through the player's resolver and `WaveformSketch`'s reader, its
//        cancellation forwarded and checked before it lands.
//   7.   SOURCE-TEXT SCAN of `TrackInspectorView.swift`: the editor is mounted on the Part page,
//        above the part list.
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent and the worktree. This file
// names `AudioPartEditor`, which this same commit creates, so it does NOT compile against the
// parent's `Sources/` and no assertion has a verdict there. Claims 1–6 are FORWARD by
// construction. Claim 7's text scan would be red on the parent (the mount is new) — a
// regression in kind, graded by transcription only. Stripper `SourceText.codeOnly`: TRAGEND for
// claim 6 — the editor's file header names `currentTick` in prose, so a raw read counts 2 where
// the leaf holds 1 and the claim would go red on a correct tree (1 verdict flips); PROPHYLAKTISCH
// for the rest of claims 6 and 7 (0 flips).
//
// ⚠️ THE LIMIT. Nothing here renders the pane, reads a real file, or watches the line move:
// whether the wave reads well at a phone's width, and whether the playhead lands on the hit the
// ear hears, is a DEVICE PROBE (founder device session, family "audio editor").

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAudioPartHasAnEditorTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let editorPath = "Sources/Echoelmusic/Studio/AudioPartEditorView.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    /// One audio part at bar 4, one bar long, 1.5 s into "loop.wav": at 120 BPM it plays
    /// 1.5 s … 3.5 s of the file.
    private func fixture(fileSeconds: Double? = 4) -> (TimelineDocument, TimelineRegion, Clip, UUID) {
        let lane = TimelineLane(name: "Take", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav", nativeDurationSeconds: fileSeconds)
        let part = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 3 * Self.bar, lengthTicks: Self.bar,
                                  contentOffsetSeconds: 1.5, gain: 0.5)
        return (TimelineDocument(lanes: [lane], regions: [part]), part, clip, lane.id)
    }

    // MARK: 1 — only the selected part, only on this track

    func testTheEditorShowsTheSelectedPartOfThisTrackOnly() {
        let (document, part, _, laneID) = fixture()
        XCTAssertEqual(AudioPartEditor.selectedPart(part.id, track: laneID, in: document), part)
        XCTAssertNil(AudioPartEditor.selectedPart(nil, track: laneID, in: document), "no selection, no editor")
        XCTAssertNil(AudioPartEditor.selectedPart(part.id, track: UUID(), in: document),
                     "a part selected on another track is not this track's to edit")
        XCTAssertNil(AudioPartEditor.selectedPart(UUID(), track: laneID, in: document), "an unknown part opens nothing")
    }

    // MARK: 2 — the window is the canvas's

    func testTheEditorsWindowIsTheStretchThePartPlays() throws {
        let (_, part, clip, _) = fixture()
        let subject = try XCTUnwrap(AudioPartEditor.subject(for: part, clip: clip, bpm: 120))
        XCTAssertEqual(subject.window, ArrangeCanvas.audioWindow(for: part, clip: clip, bpm: 120),
                       "the editor draws the canvas's own window — the player's position and stretch (#416)")
        XCTAssertEqual(subject.window.fromSeconds, 1.5, accuracy: 1e-12)
        XCTAssertEqual(subject.window.lengthSeconds, 2, accuracy: 1e-12, "one bar at 120 BPM is 2 s")
        XCTAssertEqual(subject.name, "Loop")
        XCTAssertEqual(subject.fileSeconds, 4)
        XCTAssertEqual(subject.regionID, part.id)

        // Not an audio part, or not a tempo: no editor (the canvas's own gate).
        XCTAssertNil(AudioPartEditor.subject(for: part, clip: Clip(name: "Keys", kind: .midi), bpm: 120))
        XCTAssertNil(AudioPartEditor.subject(for: part, clip: Clip(name: "Gone", kind: .audio), bpm: 120))
        XCTAssertNil(AudioPartEditor.subject(for: part, clip: nil, bpm: 120))
        let notTempos: [Double] = [0, -1, .nan, .infinity]
        for bpm in notTempos {
            XCTAssertNil(AudioPartEditor.subject(for: part, clip: clip, bpm: bpm), "\(bpm) is not a tempo")
        }
        // A length that is not a length counts as unmeasured.
        let unmeasured: [Double] = [0, -2, .nan, .infinity]
        for bad in unmeasured {
            let (_, p, c, _) = fixture(fileSeconds: bad)
            XCTAssertNil(AudioPartEditor.subject(for: p, clip: c, bpm: 120)?.fileSeconds, "\(bad) s is not a file length")
        }
    }

    // MARK: 3 — the file length it draws against

    func testTheFileLengthIsTheMeasuredOneElseTheOverviews() throws {
        let (_, part, clip, _) = fixture(fileSeconds: nil)
        let subject = try XCTUnwrap(AudioPartEditor.subject(for: part, clip: clip, bpm: 120))
        XCTAssertNil(AudioPartEditor.fileSeconds(subject, load: .reading), "nothing measured and nothing read yet")
        let overview = WaveformSketch.Overview(buckets: Array(repeating: WaveformBucket(min: -0.5, max: 0.5, rms: 0.25),
                                                              count: 6),
                                               secondsPerBucket: 0.5)
        XCTAssertEqual(try XCTUnwrap(AudioPartEditor.fileSeconds(subject, load: .ready(overview))), 3, accuracy: 1e-12,
                       "an older clip without a measured length takes the overview's: 6 buckets × 0.5 s")
        let (_, measuredPart, measuredClip, _) = fixture(fileSeconds: 4)
        let measured = try XCTUnwrap(AudioPartEditor.subject(for: measuredPart, clip: measuredClip, bpm: 120))
        XCTAssertEqual(AudioPartEditor.fileSeconds(measured, load: .ready(overview)), 4,
                       "the length measured at import wins over the overview's bucket-rounded one")
    }

    // MARK: 4 — where the part and the song sit on the file

    func testThePartAndTheSongSitWhereTheyPlayOnTheFile() throws {
        let (_, part, clip, _) = fixture()
        let window = try XCTUnwrap(AudioPartEditor.subject(for: part, clip: clip, bpm: 120)).window

        // 1.5 s … 3.5 s of a 4 s file.
        let span = try XCTUnwrap(AudioPartEditor.span(of: window, fileSeconds: 4))
        XCTAssertEqual(span.lowerBound, 1.5 / 4, accuracy: 1e-12)
        XCTAssertEqual(span.upperBound, 3.5 / 4, accuracy: 1e-12)
        // A part running past a 3 s file is cut at the file's end (it plays silence there).
        XCTAssertEqual(try XCTUnwrap(AudioPartEditor.span(of: window, fileSeconds: 3)).upperBound, 1, accuracy: 1e-12)
        // Wholly past the end, or a length that is not one: nothing.
        XCTAssertNil(AudioPartEditor.span(of: window, fileSeconds: 1))
        let badFiles: [Double] = [0, -1, .nan, .infinity]
        for bad in badFiles {
            XCTAssertNil(AudioPartEditor.span(of: window, fileSeconds: bad), "\(bad) s is not a file")
        }

        func at(_ tick: Int, file: Double = 4) -> Double? {
            AudioPartEditor.playheadFraction(tick: tick, partStartTick: part.startTick, lengthTicks: part.lengthTicks,
                                             window: window, fileSeconds: file)
        }
        XCTAssertEqual(try XCTUnwrap(at(part.startTick)), 1.5 / 4, accuracy: 1e-12, "the part's first tick is 1.5 s in")
        XCTAssertEqual(try XCTUnwrap(at(part.startTick + Self.bar / 2)), 2.5 / 4, accuracy: 1e-12,
                       "half a bar in is 1 s further: 2.5 s")
        XCTAssertNil(at(part.startTick - 1), "before the part, the song is not in its file")
        XCTAssertNil(at(part.startTick + Self.bar), "at the part's end it has stopped playing")
        XCTAssertEqual(try XCTUnwrap(at(part.startTick + Self.bar * 3 / 4, file: 3)), 1, accuracy: 1e-12,
                       "3/4 bar in is 3.0 s — exactly the end of a 3 s file")
        XCTAssertNil(at(part.startTick + Self.bar * 7 / 8, file: 3), "3.25 s is past a 3 s file: no line")
    }

    // MARK: 5 — the header says what the part plays, or why there is no wave

    func testTheHeaderSaysWhatThePartPlaysOrWhyThereIsNoWave() throws {
        let (_, part, clip, _) = fixture()
        let subject = try XCTUnwrap(AudioPartEditor.subject(for: part, clip: clip, bpm: 120))
        let reading = AudioPartEditor.summary(subject, load: .reading)
        XCTAssertTrue(reading.contains(AudioPartEditor.seconds(1.5)) && reading.contains(AudioPartEditor.seconds(3.5)),
                      "the header names the stretch the part plays: \(reading)")
        XCTAssertTrue(reading.contains(AudioPartEditor.seconds(4)), "and the file's measured length: \(reading)")
        let missing = AudioPartEditor.summary(subject, load: .missing)
        XCTAssertTrue(missing.contains("not found"), """
            A part whose file the player's resolver cannot find plays silence (#1439); the header \
            must say the file is not found, not show seconds of a wave that is not there: \(missing)
            """)
        XCTAssertNotEqual(AudioPartEditor.summary(subject, load: .unreadable), reading)
        XCTAssertEqual(AudioPartEditor.seconds(.nan), "–", "a non-finite time never prints as a number")
    }

    // MARK: 6 — SOURCE: no modal, no file read on the main actor, the position in its leaf

    func testTheEditorIsInlineReadsDetachedAndKeepsThePositionInItsLeaf() throws {
        let code = try source(Self.editorPath)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(code.contains(modal), """
                `AudioPartEditorView.swift` presents `\(modal)`. The editor is inline on a page that \
                already exists — a modal adds to the presentation chain the black-screen law caps.
                """)
        }
        XCTAssertFalse(code.contains("AVAudioFile("), """
            The editor opens a file itself. The one reader is `WaveformSketch.overview(ofRef:)`, \
            run detached (#416, and never on the main actor).
            """)

        guard let leaf = Self.bracedBody(after: "struct AudioPartPlayheadView: View {", in: code) else {
            return XCTFail("ANCHOR MISSING: `AudioPartPlayheadView` (#408)")
        }
        for hot in ["currentTick", "isPlaying"] {
            let everywhere = Self.occurrences(of: hot, in: code)
            XCTAssertGreaterThan(everywhere, 0, "`\(hot)` is not read at all — the scan selects nothing (#454)")
            XCTAssertEqual(Self.occurrences(of: hot, in: leaf), everywhere, """
                `\(hot)` is read outside `AudioPartPlayheadView`. A song-position read in the pane's \
                body rebuilds the Part page 15 times a second and tears down its open controls \
                (10.76.41/50). Keep it in the leaf.
                """)
        }
        XCTAssertTrue(leaf.contains("TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing))"),
                      "the playhead leaf self-drives at 15 Hz and pauses while the song is stopped")

        guard let read = Self.bracedBody(after: ".task(id: subject.window.mediaRef) {", in: code) else {
            return XCTFail("ANCHOR MISSING: the file read keyed to the file (#408)")
        }
        for needle in ["Task.detached(priority: .utility)", "MediaLibrary.resolveRef(ref)",
                       "WaveformSketch.overview(ofRef: ref)", "reader.cancel()"] {
            XCTAssertTrue(read.contains(needle), "the file read lost `\(needle)`")
        }
        guard let check = read.range(of: "guard !Task.isCancelled else { return }"),
              let land = read.range(of: "self.load = read") else {
            return XCTFail("the read no longer checks cancellation before it lands")
        }
        XCTAssertLessThan(check.lowerBound, land.lowerBound,
                          "a read for a file the part no longer plays must not land over the newer one")
    }

    // MARK: 7 — SOURCE: mounted on the Part page, above the part list

    func testTheEditorIsMountedOnThePartPageAboveThePartList() throws {
        let code = try source(Self.inspectorPath)
        guard let page = code.range(of: "if page == .part {"),
              let notes = code.range(of: "if page == .notes {", range: page.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the Part page or the Notes page after it (#408)")
        }
        let part = code[page.upperBound..<notes.lowerBound]
        guard let editor = part.range(of: "AudioPartEditorView(laneID: laneID)"),
              let list = part.range(of: "TrackPartsView(laneID: laneID)") else {
            return XCTFail("""
                The Part page no longer mounts `AudioPartEditorView(laneID: laneID)` and the part \
                list. The audio editor is the founder's ask (2026-10-08) and lives there (AE-2).
                """)
        }
        XCTAssertLessThan(editor.lowerBound, list.lowerBound, "the editor sits above the part list")
    }

    // MARK: - Helpers

    static func bracedBody(after head: String, in code: String) -> String? {
        guard let start = code.range(of: head) else { return nil }
        var depth = 0
        var i = code.index(before: start.upperBound)   // the opening brace
        while i < code.endIndex {
            if code[i] == "{" {
                depth += 1
            } else if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<i]) }
            }
            i = code.index(after: i)
        }
        return nil
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present under \(dir.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
