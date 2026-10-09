// TheSlipKeepsThePartLevelTests.swift
// Echoel — GMMW AE-6 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir
// noch."). Slipping the file under an audio part moves the file, never the part, and never its level.
//
// WHAT THIS GUARDS. `AudioPartSlip` is the audio part editor's slip edit: hold the window's body
// and slide, or step one beat with the Earlier/Later buttons or a VoiceOver swipe. It writes
// ONE store call, `TimelineStore.setAudioRegionWindow`, which had no caller since CLIP-4 and
// defaulted its `gain` to 1 — so the first caller that left it out would have reset every part it
// slipped to unity. The default is gone and the one caller passes the part's own gain.
//
// THE CLAIMS.
//   1–3. END-TO-END BEHAVIOUR over the pure half, on shipped value types: the bounds (never before
//        the file's first second, never further past its end than the part already reaches), the
//        drag and the one-beat step in file seconds, and the change for an unwarped and a warped
//        part — the window is the canvas's own (`ArrangeCanvas.audioWindow`, #416). Expectations
//        are written from the algebra (#442): one bar at 120 BPM is 2 s; one beat is 0.5 s.
//   4.   END-TO-END BEHAVIOUR through the shipped write, on a real `TimelineStore` and
//        `TimelineRegionPlayer`: the slip changes the two offsets and NOTHING ELSE on the part
//        (start, length, gain, fades, warp, pitch — one struct comparison), one Undo step, the
//        gain written back is the one the store holds when it writes, and a slip that moves
//        nothing leaves no Undo step.
//   5.   SOURCE-TEXT SCAN of `TimelineStore.swift` and all of `Sources/`: `setAudioRegionWindow`
//        has no defaulted `gain` and exactly ONE production caller, which passes `live.gain` and
//        `live.lengthTicks`, read from the store before it writes.
//   6.   SOURCE-TEXT SCAN of the doors: the slide writes once, on release; the buttons step one
//        beat, are disabled where a step moves nothing, give way to a caption when neither
//        moves, and are full targets; the editor mounts the slide between the edge handles
//        (beneath them), gives the pane its VoiceOver step, and mounts the buttons OUTSIDE the
//        pane's one VoiceOver element so Voice Control, Switch Control and a keyboard reach them.
//
// ⛔ THE FIRST DRAFT REFUSED THE SLIP WHILE THE SONG PLAYED, and claims 5 and 6 pinned that
// refusal. The review (2026-10-09) measured the reason false: the player chases a structural
// edit on its next transport step (`refreshStructure` re-primes the audio lanes), so a slip is
// heard from there — exactly like the edge trims and Split beside it, neither of which refuses.
// The refusal made the slip the one edit in the pane that went dead on Play; it is gone, and so
// are its needles. The same review moved the buttons out of the ignored element (inside it they
// were in no accessibility tree at all).
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent and the worktree. This file
// names `AudioPartSlip`, which this same commit creates, so it does NOT compile against the
// parent's `Sources/` and no assertion has a verdict there. Claims 1–4 are FORWARD by
// construction. Claim 5's two scans would be red on the parent — the default and the missing
// caller are exactly what this commit changes — and claim 6 by anchor absence (one absence,
// #486); both graded by transcription only, and ten mutants each turn the claim they target red
// (a restored default, `gain: 1`, the buttons back inside the ignored element, a stale length, a
// write while sliding, no `.disabled`, the slide above the handles, no adjustable action, a second
// caller, a ceiling without `max`). Stripper `SourceText.codeOnly`: PROPHYLAKTISCH (0 verdicts flip — measured,
// every needle counts the same raw and code-only; the prose names the writer without its `(`).
//
// ⚠️ THE LIMIT. Nothing here renders the pane or moves a finger: whether the hold wins over the
// page's scroll, whether the frame follows the finger, and whether the slipped part sounds the
// stretch the frame showed is a DEVICE PROBE (founder device session, family "audio editor").
// That a slip WHILE PLAYING is heard from the next step is the player's chase, not this file's —
// `isPlaying` has a private setter, so no test here can start the transport without an engine.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSlipKeepsThePartLevelTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let slipPath = "Sources/Echoelmusic/Studio/AudioPartSlip.swift"
    private static let editorPath = "Sources/Echoelmusic/Studio/AudioPartEditorView.swift"

    /// One audio part at bar 4, one bar long, 1.5 s into an 8-s "loop.wav" at gain 0.5: at 120 BPM
    /// it plays 1.5 s … 3.5 s of the file.
    private func fixture(warped: Bool = false) -> (TimelineLane, TimelineRegion, Clip) {
        let lane = TimelineLane(name: "Take", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav", nativeDurationSeconds: 8, nativeBPM: 100)
        let part = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 3 * Self.bar, lengthTicks: Self.bar,
                                  contentOffsetSeconds: 1.5, contentOffsetTicks: 1440, gain: 0.5,
                                  warpEnabled: warped, fadeInTicks: 120, fadeOutTicks: 240, transposeSemitones: 3)
        return (lane, part, clip)
    }

    // MARK: 1 — the bounds

    func testTheSlipStaysInsideTheFile() throws {
        func offset(_ delta: Double, from: Double = 1.5, length: Double = 2, file: Double = 10) -> Double? {
            AudioPartSlip.offset(by: delta, from: from, lengthSeconds: length, fileSeconds: file)
        }
        XCTAssertEqual(offset(1), 2.5, "later by a second")
        XCTAssertEqual(offset(-1), 0.5, "earlier by a second")
        XCTAssertEqual(offset(-5), 0, "never before the file's first second")
        XCTAssertEqual(offset(20), 8, "never past the last offset where the whole part still fits")
        XCTAssertNil(offset(0), "a slip that moves nothing writes nothing")
        XCTAssertNil(offset(AudioPartSlip.minimumSeconds / 2), "below a millisecond is not a slip")
        XCTAssertNil(offset(1, from: 8), "at the end already: later moves nothing")
        XCTAssertEqual(offset(-1, from: 8), 7)

        // A part longer than what is left of its file slips back, never on.
        XCTAssertNil(offset(1, from: 9), "past the fitting end: later is refused")
        XCTAssertEqual(offset(-0.5, from: 9), 8.5, "…and earlier is allowed")
        // A negative offset from an older document counts as the file's first second.
        XCTAssertEqual(offset(1, from: -1), 1)

        let notNumbers: [Double] = [.nan, .infinity, -.infinity]
        for bad in notNumbers {
            XCTAssertNil(offset(bad), "a delta of \(bad) is not a slip")
            XCTAssertNil(offset(1, from: bad), "an offset of \(bad) is not a place")
            XCTAssertNil(offset(1, length: bad), "a length of \(bad) is not a window")
            XCTAssertNil(offset(1, file: bad), "a file of \(bad) s is not a file")
        }
        XCTAssertNil(offset(1, length: 0), "an empty window cannot slip")
        XCTAssertNil(offset(1, file: 0), "an empty file cannot be slipped through")
    }

    // MARK: 2 — the drag and the step in file seconds

    func testTheDragAndTheStepAreFileSeconds() throws {
        XCTAssertEqual(AudioPartSlip.seconds(dragPoints: 50, widthPoints: 200, fileSeconds: 8), 2,
                       "a quarter of the pane is a quarter of the file")
        XCTAssertEqual(AudioPartSlip.seconds(dragPoints: -50, widthPoints: 200, fileSeconds: 8), -2)
        XCTAssertNil(AudioPartSlip.seconds(dragPoints: 50, widthPoints: 0, fileSeconds: 8))
        XCTAssertNil(AudioPartSlip.seconds(dragPoints: .nan, widthPoints: 200, fileSeconds: 8))
        XCTAssertNil(AudioPartSlip.seconds(dragPoints: 50, widthPoints: 200, fileSeconds: 0))

        XCTAssertEqual(AudioPartSlip.stepSeconds(mediaBPM: 120), 0.5, "one beat at 120 BPM")
        XCTAssertEqual(AudioPartSlip.stepSeconds(mediaBPM: 60), 1, "one beat at 60 BPM")
        let notTempos: [Double] = [0, -1, .nan, .infinity]
        for bpm in notTempos {
            XCTAssertNil(AudioPartSlip.stepSeconds(mediaBPM: bpm), "\(bpm) is not a tempo")
        }
    }

    // MARK: 3 — the change, unwarped and warped

    func testTheChangeIsAskedOfTheCanvasWindow() throws {
        let (_, plain, clip) = fixture()
        let later = try XCTUnwrap(AudioPartSlip.change(by: 1, region: plain, clip: clip, fileSeconds: 8,
                                                       projectBPM: 120))
        XCTAssertEqual(later, AudioPartSlip.Change(offsetSeconds: 2.5, lengthSeconds: 2, mediaBPM: 120),
                       "one bar at 120 BPM is 2 s of the file; the media elapses at the song tempo")
        let window = try XCTUnwrap(ArrangeCanvas.audioWindow(for: plain, clip: clip, bpm: 120))
        XCTAssertEqual(later.lengthSeconds, window.lengthSeconds, "the canvas's own window (#416)")
        XCTAssertEqual(try XCTUnwrap(AudioPartSlip.change(by: 20, region: plain, clip: clip, fileSeconds: 8,
                                                          projectBPM: 120)).offsetSeconds, 6,
                       "8 s of file less the part's 2 s")

        // Warped: a 100-BPM file under a 120-BPM song elapses at its own tempo, 1.2× as much file.
        let (_, warped, _) = fixture(warped: true)
        let slipped = try XCTUnwrap(AudioPartSlip.change(by: 1, region: warped, clip: clip, fileSeconds: 8,
                                                         projectBPM: 120))
        XCTAssertEqual(slipped.offsetSeconds, 2.5, accuracy: 1e-9)
        XCTAssertEqual(slipped.lengthSeconds, 2.4, accuracy: 1e-9, "one bar at 120 BPM, stretched 1.2×")
        XCTAssertEqual(slipped.mediaBPM, 100, accuracy: 1e-9, "the tempo the trims convert offsets at")
        XCTAssertEqual(try XCTUnwrap(AudioPartSlip.change(by: 20, region: warped, clip: clip, fileSeconds: 8,
                                                          projectBPM: 120)).offsetSeconds, 5.6, accuracy: 1e-9)

        XCTAssertNil(AudioPartSlip.change(by: 1, region: plain, clip: Clip(name: "Keys", kind: .midi),
                                          fileSeconds: 8, projectBPM: 120), "not an audio part")
        XCTAssertNil(AudioPartSlip.change(by: 1, region: plain, clip: clip, fileSeconds: 8, projectBPM: .nan),
                     "not a tempo")
        XCTAssertNil(AudioPartSlip.change(by: 0, region: plain, clip: clip, fileSeconds: 8, projectBPM: 120),
                     "nothing to move")
    }

    // MARK: 4 — the write: the file moves, the part stays

    func testTheSlipMovesOnlyTheFileAndIsOneUndoStep() throws {
        try withStore { timeline, player, part, clip in
            AudioPartSlip.apply(by: 1, regionID: part.id, clip: clip, fileSeconds: 8,
                                timeline: timeline, player: player)
            var expected = part
            expected.contentOffsetSeconds = 2.5
            expected.contentOffsetTicks = TimelineTime.ticks(fromSeconds: 2.5, bpm: 120)
            XCTAssertEqual(expected.contentOffsetTicks, 2400, "2.5 s at 120 BPM — the tick twin follows")
            XCTAssertEqual(timeline.document.regions, [expected], """
                The slip changed something besides the file offset and its tick twin. Start, \
                length, gain, fades, warp and pitch belong to the part, not to the file under it.
                """)
            XCTAssertTrue(timeline.canUndo, "one undo step")
            timeline.undo()
            XCTAssertEqual(timeline.document.regions, [part], "Undo puts the file back")
            XCTAssertFalse(timeline.canUndo, "it was ONE step")
        }
    }

    func testTheStepIsOneBeatAndTheGainIsTheStoresOwn() throws {
        try withStore { timeline, player, part, clip in
            timeline.setRegionGain(id: part.id, 1.5)
            AudioPartSlip.applyStep(1, regionID: part.id, clip: clip, fileSeconds: 8,
                                    timeline: timeline, player: player)
            let live = try XCTUnwrap(timeline.document.regions.first)
            XCTAssertEqual(live.contentOffsetSeconds, 2, "one beat at 120 BPM later")
            XCTAssertEqual(live.gain, 1.5, "the gain the store holds when it writes, never unity")
            XCTAssertEqual(live.startTick, part.startTick, "who plays where never changes")

            AudioPartSlip.applyStep(-1, regionID: part.id, clip: clip, fileSeconds: 8,
                                    timeline: timeline, player: player)
            XCTAssertEqual(timeline.document.regions.first?.contentOffsetSeconds, 1.5, "and one beat back")
        }
    }

    func testASlipThatMovesNothingLeavesNoUndoStep() throws {
        try withStore { timeline, player, part, clip in
            AudioPartSlip.apply(by: 0, regionID: part.id, clip: clip, fileSeconds: 8,
                                timeline: timeline, player: player)
            AudioPartSlip.apply(by: 1, regionID: UUID(), clip: clip, fileSeconds: 8,
                                timeline: timeline, player: player)
            AudioPartSlip.applyStep(0, regionID: part.id, clip: clip, fileSeconds: 8,
                                    timeline: timeline, player: player)
            XCTAssertEqual(timeline.document.regions, [part])
            XCTAssertFalse(timeline.canUndo, "a refusal leaves no dead undo step")
        }
    }

    // MARK: 5 — SOURCE: no defaulted gain, exactly one caller, and it passes the part's own

    func testTheWindowWriterHasNoDefaultedGainAndOneCaller() throws {
        let store = try source(Self.storePath)
        guard let head = store.range(of: "public func setAudioRegionWindow("),
              let open = store[head.upperBound...].firstIndex(of: "{") else {
            return XCTFail("ANCHOR MISSING: `setAudioRegionWindow`'s declaration (#408)")
        }
        let signature = String(store[head.lowerBound..<open])
        XCTAssertTrue(signature.contains("gain: Float)"), "the writer still takes the part's gain")
        XCTAssertFalse(signature.contains("gain: Float ="), """
            `setAudioRegionWindow` defaults its `gain` again. It writes the gain every time, so a \
            caller that leaves it out resets the part to unity — and a defaulted argument no call \
            site writes appears in no diff (#431/#440). Keep it required.
            """)

        let callers = try filesCalling("setAudioRegionWindow(").filter { $0 != Self.storePath }
        XCTAssertEqual(callers, [Self.slipPath], """
            `setAudioRegionWindow` is called from \(callers). Its one caller is the slip, which \
            reads the part from the store as it writes. A second door must go through \
            `AudioPartSlip.apply` rather than write the window itself.
            """)

        let slip = try source(Self.slipPath)
        XCTAssertEqual(occurrences(of: "setAudioRegionWindow(", in: slip), 1, "one write in the slip")
        let apply = try member("static func apply(by deltaSeconds: Double", in: slip)
        for needle in ["gain: live.gain", "lengthTicks: live.lengthTicks", "projectBPM: player.preflightTempo"] {
            XCTAssertTrue(apply.contains(needle), "the slip's write lost `\(needle)`")
        }
        guard let read = apply.range(of: "timeline.document.regions.first(where: { $0.id == regionID })"),
              let write = apply.range(of: "timeline.setAudioRegionWindow(") else {
            return XCTFail("ANCHOR MISSING: the live read or the write in `apply` (#408)")
        }
        XCTAssertLessThan(read.lowerBound, write.lowerBound, "the part is read from the store as it writes")
    }

    // MARK: 6 — SOURCE: the three doors

    func testTheSlideTheButtonsAndVoiceOverAllGoThroughTheOneWrite() throws {
        let slip = try source(Self.slipPath)
        let area = try member("struct AudioPartSlipArea: View {", in: slip)
        XCTAssertEqual(occurrences(of: "AudioPartSlip.apply(", in: area), 1, "the slide writes once")
        let ended = try member(".onEnded { value in", in: area)
        XCTAssertTrue(ended.contains("AudioPartSlip.apply(by: seconds"), "…on release, never while the finger moves")
        XCTAssertTrue(area.contains("LongPressGesture(minimumDuration: 0.3)"),
                      "hold first, so a swipe on the wave still scrolls the page")

        let buttons = try member("struct AudioPartSlipButtons: View {", in: slip)
        XCTAssertEqual(occurrences(of: "AudioPartSlip.applyStep(", in: buttons), 1, "one step writer for both buttons")
        for needle in ["enabled: earlier)", "enabled: later)", "if earlier || later {", ".disabled(!enabled)",
                       "minWidth: CGFloat(AudioPartEditor.handleHitPoints)",
                       "minHeight: CGFloat(AudioPartEditor.handleHitPoints)", ".accessibilityLabel(label)"] {
            XCTAssertTrue(buttons.contains(needle), "the slip buttons lost `\(needle)`")
        }

        let editor = try source(Self.editorPath)
        let handles = try member("private struct AudioPartEdgeHandles: View {", in: editor)
        guard let mount = handles.range(of: "AudioPartSlipArea("),
              let firstHandle = handles.range(of: "handle(.start, frame: frames.start") else {
            return XCTFail("ANCHOR MISSING: the slide's mount or the start handle (#408)")
        }
        XCTAssertLessThan(mount.lowerBound, firstHandle.lowerBound,
                          "the slide sits beneath the handles, so an edge still trims")
        XCTAssertTrue(handles.contains("touch: frames.start.upperBound...frames.end.lowerBound"),
                      "the slide takes the touches between the two handles only")
        XCTAssertTrue(handles.contains("if frames.start.upperBound < frames.end.lowerBound"),
                      "no slide where the handles meet")

        let pane = try member("private struct AudioPartEditorPane: View {", in: editor)
        XCTAssertEqual(occurrences(of: "AudioPartSlipButtons(", in: pane), 1, "the buttons are on the pane")
        XCTAssertTrue(pane.contains(".accessibilityAdjustableAction"), "the pane is the slip's VoiceOver door")
        guard let ignored = pane.range(of: ".accessibilityElement(children: .ignore)"),
              let adjustable = pane.range(of: ".accessibilityAdjustableAction"),
              let buttonsMount = pane.range(of: "AudioPartSlipButtons(") else {
            return XCTFail("ANCHOR MISSING: the pane's element, its adjustable action or the buttons (#408)")
        }
        XCTAssertLessThan(ignored.lowerBound, buttonsMount.lowerBound, """
            The slip buttons are mounted INSIDE the view that `.accessibilityElement(children: .ignore)` \
            collapses — there they are in no accessibility tree, so Voice Control, Switch Control and a \
            keyboard cannot reach them. Mount them after the pane's element closes.
            """)
        XCTAssertLessThan(adjustable.lowerBound, buttonsMount.lowerBound,
                          "the buttons follow the element's last modifier, not its content")
        for step in ["AudioPartSlip.applyStep(1,", "AudioPartSlip.applyStep(-1,"] {
            XCTAssertEqual(occurrences(of: step, in: pane), 1, "VoiceOver steps through `\(step)`")
        }
    }

    // MARK: - Helpers

    private func withStore(_ body: (TimelineStore, TimelineRegionPlayer, TimelineRegion, Clip) throws -> Void) throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let player = TimelineRegionPlayer()
        player.preflightTempo = 120
        let (lane, part, clip) = fixture()
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [part]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        XCTAssertFalse(player.isPlaying, "fixture premise: the song is stopped")
        try body(timeline, player, part, clip)
    }

    private struct AnchorMissing: Error { let reason: String }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#408)")
            throw AnchorMissing(reason: head)
        }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` (#408)")
        throw AnchorMissing(reason: head)
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present: \(relativePath)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// Every Swift file under `Sources/` whose CODE (comments stripped) contains `needle`, as
    /// repo-relative paths, sorted.
    private func filesCalling(_ needle: String) throws -> [String] {
        let sources = try repoRoot().appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sources.path),
              let walker = FileManager.default.enumerator(atPath: sources.path) else {
            throw XCTSkip("cannot enumerate Sources/ — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8)
            if SourceText.codeOnly(text).contains(needle) {
                hits.append("Sources/" + relative)
            }
        }
        XCTAssertFalse(hits.isEmpty, "the scan selected nothing — a census of nothing is a finding (#454)")
        return hits.sorted()
    }
}
