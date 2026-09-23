// TheImportedTempoCanBeCorrectedTests.swift
// Echoel — S1 (founder 2026-09-23, "Great all tasks"): an imported file's OWN tempo can be
// corrected — ×2, ÷2, or typed by hand when the detector said "Tempo unclear".
//
// WHAT KIND OF GUARD THIS IS (§1). Claims 1–7 are END-TO-END BEHAVIOUR over shipped, public,
// Foundation-only value types: `AudioTempoCorrection`, `Clip`, `TimelineDocument`, `AudioWarp`
// and `StretchPlan`, driven with hand-built values. No store is constructed — `ClipStore` and
// `TimelineStore` persist into the shared App Group. Claims 8–12 are SOURCE-TEXT SCANS of the
// authored writer, the writer census, the seam and the surface. Whether the row reads well,
// whether ×2 lands where a musician expects, and whether a hand-typed tempo makes a loop sit in
// time are DEVICE questions, registered as NEEDS-FOUNDER-VERIFY (28)–(35) in
// `Studio/WorkstationView.swift`.
//
// HONEST GRADING (§3). `AudioTempoCorrection` and `ClipStore.setAuthoredNativeBPM` are created
// by this commit, so the file does not compile against the parent and NO assertion has a
// verdict there — every behavioural claim is a FORWARD guard. It was graded by TRANSCRIPTION:
// `octave`, `accepted` and `startingValue` re-driven in Python, and claim 6's spans from the
// `AudioWarp.spanTicks` arithmetic (9.6 s at native 100 → rate 1.2 → 8 s → 4 bars at 120;
// native 200 → rate 0.6 → 16 s → 8 bars). The scans were driven with a Python port of
// `SourceText.codeOnly` against the worktree (all green) and the parent (the writer, the seam
// file and the row are absent — ONE absence, #486; the census would read 1 in `ClipStore`).
//
// COUNTERWEIGHTS (#343): claim 5 (an unwarped part's sound and length do not depend on the
// tempo — the premise that lets the row stay usable while the song plays), the census floor in
// claim 9, and claim 12 (the Warp switch keeps its own `.disabled(playing)`).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheImportedTempoCanBeCorrectedTests: XCTestCase {

    // The TheWarpSwitchIsHonestTests fixture: a 4-bar loop at 100 BPM lasts 9.6 s, placed
    // unwarped at 120 it covers FIVE whole bars.
    private static let seconds = 9.6
    private static let song = 120.0
    private static let bar = TimelineTime.ticksPerBar

    private struct Fixture {
        var document: TimelineDocument
        var clips: [Clip]
        let laneID: UUID
    }

    private func fixture(nativeBPM: Double, warped: Bool = false) -> Fixture {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let clip = Clip(name: "loop", kind: .audio, mediaRef: "/tmp/loop.wav",
                        nativeDurationSeconds: Self.seconds, nativeBPM: nativeBPM)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: 5 * Self.bar, warpEnabled: warped)
        return Fixture(document: TimelineDocument(lanes: [lane], regions: [region]),
                       clips: [clip], laneID: lane.id)
    }

    /// 1. ×2 and ÷2 are exact octaves, and are OFFERED only when the result stays in range —
    /// a clamped "×2" is not ×2.
    func testTheOctaveButtonsAreExactAndNeverClamp() throws {
        XCTAssertEqual(AudioTempoCorrection.doubled(87), 174)
        XCTAssertEqual(AudioTempoCorrection.halved(174), 87)
        XCTAssertEqual(AudioTempoCorrection.doubled(200), 400)
        XCTAssertEqual(AudioTempoCorrection.halved(40), 20)
        XCTAssertNil(AudioTempoCorrection.doubled(250), "500 is outside the range — no ×2 button")
        XCTAssertNil(AudioTempoCorrection.halved(30), "15 is outside the range — no ÷2 button")
        for bad in [0.0, -1.0, Double.nan, Double.infinity] {
            XCTAssertNil(AudioTempoCorrection.doubled(bad), "×2 of \(bad)")
            XCTAssertNil(AudioTempoCorrection.halved(bad), "÷2 of \(bad)")
        }
        for x in [60.0, 87.0, 120.0, 150.0] {
            let up = try XCTUnwrap(AudioTempoCorrection.doubled(x))
            XCTAssertEqual(AudioTempoCorrection.halved(up), x, "÷2 undoes ×2 at \(x)")
        }
    }

    /// 2. `accepted` is the ONE clamp `Clip` already owns, over the ONE range (#416).
    func testAnAcceptedTempoIsTheClipsOwnClamp() {
        XCTAssertEqual(AudioTempoCorrection.bounds, AudioClipRegion.nativeBPMRange)
        for bad in [0.0, -5.0, Double.nan, Double.infinity] {
            XCTAssertNil(AudioTempoCorrection.accepted(bad), "\(bad) is not a tempo this path writes")
        }
        XCTAssertEqual(AudioTempoCorrection.accepted(1000), AudioTempoCorrection.bounds.upperBound)
        XCTAssertEqual(AudioTempoCorrection.accepted(5), AudioTempoCorrection.bounds.lowerBound)
        XCTAssertEqual(AudioTempoCorrection.accepted(128.4), 128.4)
        for x in [1.0, 19.9, 20.0, 99.5, 400.0, 401.0, 9999.0] {
            XCTAssertEqual(AudioTempoCorrection.accepted(x), Clip.clampedNativeBPM(x),
                           "a second spelling of the clamp at \(x)")
        }
    }

    /// 3. The warp lock is per CLIP, anywhere in the song — and needs a known tempo.
    func testTheWarpLockBelongsToTheClip() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let other = TimelineLane(name: "Audio 2", kind: .audio)
        let a = Clip(name: "a", kind: .audio, mediaRef: "/tmp/a.wav",
                     nativeDurationSeconds: Self.seconds, nativeBPM: 100)
        let b = Clip(name: "b", kind: .audio, mediaRef: "/tmp/b.wav",
                     nativeDurationSeconds: Self.seconds, nativeBPM: 100)
        let aPlain = TimelineRegion(laneID: lane.id, clipID: a.id, startTick: 0,
                                    lengthTicks: 5 * Self.bar)
        let aWarpedElsewhere = TimelineRegion(laneID: other.id, clipID: a.id, startTick: 0,
                                              lengthTicks: 4 * Self.bar, warpEnabled: true)
        let bWarped = TimelineRegion(laneID: lane.id, clipID: b.id, startTick: 8 * Self.bar,
                                     lengthTicks: 4 * Self.bar, warpEnabled: true)

        let unlocked = TimelineDocument(lanes: [lane], regions: [aPlain])
        XCTAssertFalse(AudioTempoCorrection.isLockedByWarp(clip: a, in: unlocked))
        let lockedOnAnotherTrack = TimelineDocument(lanes: [lane, other],
                                                    regions: [aPlain, aWarpedElsewhere])
        XCTAssertTrue(AudioTempoCorrection.isLockedByWarp(clip: a, in: lockedOnAnotherTrack),
                      "a warped placement ANYWHERE sized its span from this tempo")
        let neighbourWarped = TimelineDocument(lanes: [lane], regions: [aPlain, bWarped])
        XCTAssertFalse(AudioTempoCorrection.isLockedByWarp(clip: a, in: neighbourWarped),
                       "another clip's warp does not lock this one")

        // An older build could leave a warped part on a clip with no tempo: it plays at rate 1
        // and shows no Warp switch, so a lock would name a control the user cannot find.
        let noTempo = Clip(name: "legacy", kind: .audio, mediaRef: "/tmp/l.wav",
                           nativeDurationSeconds: Self.seconds, nativeBPM: 0)
        let legacy = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: noTempo.id, startTick: 0,
                           lengthTicks: 5 * Self.bar, warpEnabled: true)])
        XCTAssertFalse(AudioTempoCorrection.isLockedByWarp(clip: noTempo, in: legacy))
    }

    /// 4. One row per FILE on the track, in placement order.
    func testTheRowsAreTheDistinctAudioFilesOnTheTrack() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let other = TimelineLane(name: "Audio 2", kind: .audio)
        let first = Clip(name: "first", kind: .audio, mediaRef: "/tmp/1.wav")
        let second = Clip(name: "second", kind: .audio, mediaRef: "/tmp/2.wav")
        let midi = Clip(name: "notes", kind: .midi)
        let elsewhere = Clip(name: "elsewhere", kind: .audio, mediaRef: "/tmp/3.wav")
        func place(_ clipID: UUID, on laneID: UUID, bar index: Int) -> TimelineRegion {
            TimelineRegion(laneID: laneID, clipID: clipID, startTick: index * 4 * Self.bar,
                           lengthTicks: 4 * Self.bar)
        }
        let document = TimelineDocument(lanes: [lane, other], regions: [
            place(second.id, on: lane.id, bar: 0),
            place(first.id, on: lane.id, bar: 1),
            place(second.id, on: lane.id, bar: 2),
            place(midi.id, on: lane.id, bar: 3),
            place(UUID(), on: lane.id, bar: 4),
            place(elsewhere.id, on: other.id, bar: 0),
        ])
        let rows = AudioTempoCorrection.audioClips(onLane: lane.id, in: document,
                                                   clips: [first, second, midi, elsewhere])
        XCTAssertEqual(rows.map(\.id), [second.id, first.id],
                       "twice-placed once, MIDI out, unknown id skipped, other tracks out")
    }

    /// 5. COUNTERWEIGHT — the premise of "correctable even while playing": unwarped, the tempo
    /// is inaudible. Same rate, same span, nothing to change, for 100 and for 200.
    func testAnUnwarpedPartDoesNotDependOnItsTempo() throws {
        var spans: [Int] = []
        for native in [100.0, 200.0] {
            let plan = StretchPlan.resolve(mode: .clean, warpEnabled: false, nativeBPM: native,
                                           projectBPM: Self.song,
                                           capabilities: StretchMode.timelineCapabilities)
            XCTAssertEqual(plan.rate, 1.0, "an unwarped part plays at recorded speed")
            let f = fixture(nativeBPM: native)
            let region = try XCTUnwrap(f.document.regions.first)
            spans.append(AudioWarp.spanTicks(for: region, clip: f.clips[0], warped: false,
                                             bpm: Self.song))
            XCTAssertTrue(AudioWarp.changes(warp: false, laneID: f.laneID, in: f.document,
                                            clips: f.clips, bpm: Self.song).isEmpty)
        }
        XCTAssertEqual(spans, [5 * Self.bar, 5 * Self.bar])
    }

    /// 6. A hand-entered tempo is what makes Warp possible — through the EXISTING path, with
    /// no second length writer: the span follows the corrected tempo when Warp is turned on.
    func testAnEnteredTempoOpensWarpAndTheSpanFollowsIt() throws {
        var f = fixture(nativeBPM: 0)
        XCTAssertEqual(AudioWarp.state(laneID: f.laneID, in: f.document, clips: f.clips),
                       .unavailable, "premise: an unclear tempo offers no Warp switch")

        f.clips[0].nativeBPM = try XCTUnwrap(AudioTempoCorrection.accepted(100))
        XCTAssertEqual(AudioWarp.state(laneID: f.laneID, in: f.document, clips: f.clips), .off)
        let atHundred = try XCTUnwrap(AudioWarp.changes(warp: true, laneID: f.laneID,
                                                        in: f.document, clips: f.clips,
                                                        bpm: Self.song).first)
        XCTAssertEqual(atHundred.lengthTicks, 4 * Self.bar)

        f.clips[0].nativeBPM = try XCTUnwrap(AudioTempoCorrection.doubled(100))
        let atTwoHundred = try XCTUnwrap(AudioWarp.changes(warp: true, laneID: f.laneID,
                                                           in: f.document, clips: f.clips,
                                                           bpm: Self.song).first)
        XCTAssertEqual(atTwoHundred.lengthTicks, 8 * Self.bar,
                       "after ×2 the loop plays slower and spans twice the bars")
    }

    /// 7. What the field shows before anything is set — displayed only.
    func testTheStartingValueIsShownNotWritten() {
        XCTAssertEqual(AudioTempoCorrection.startingValue(nativeBPM: 93, songBPM: 128), 93)
        XCTAssertEqual(AudioTempoCorrection.startingValue(nativeBPM: 0, songBPM: 128), 128)
        XCTAssertEqual(AudioTempoCorrection.startingValue(nativeBPM: 0, songBPM: 1000),
                       AudioTempoCorrection.bounds.upperBound)
        XCTAssertEqual(AudioTempoCorrection.startingValue(nativeBPM: 0, songBPM: .nan),
                       AudioTempoCorrection.bounds.lowerBound)
        XCTAssertEqual(AudioTempoCorrection.startingValue(nativeBPM: .nan, songBPM: 128), 128)
    }

    /// 8. SOURCE-TEXT SCAN — the authored writer overrides, but only through the one clamp,
    /// only for audio, and it persists. The detection writer keeps never-clobber.
    func testTheAuthoredWriterIsNotTheDetectionWriter() throws {
        let store = try code("Sources/Echoelmusic/Core/ClipStore.swift")
        let authored = try XCTUnwrap(body(of: "public func setAuthoredNativeBPM(", in: store),
                                     "ANCHOR MISSING: ClipStore.setAuthoredNativeBPM")
        for needle in ["AudioTempoCorrection.accepted(", "clip.kind == .audio", "persist()"] {
            XCTAssertTrue(authored.contains(needle), "the authored writer lost `\(needle)`")
        }
        XCTAssertFalse(authored.contains("adoptableNativeBPM"),
                       "the authored path must OVERRIDE — never-clobber belongs to detection")
        let detected = try XCTUnwrap(body(of: "public func adoptDetectedNativeBPM(", in: store),
                                     "ANCHOR MISSING: ClipStore.adoptDetectedNativeBPM")
        XCTAssertTrue(detected.contains("AudioTempoAnalysis.adoptableNativeBPM("),
                      "counterweight: detection still asks the never-clobber policy")
    }

    /// 9. SOURCE-TEXT SCAN — the writer census. `\b` is load-bearing: `octaveAlternativeBPM =`
    /// ends in "…nativeBPM =" only without it. ⚠️ It sees ASSIGNMENTS only — a `Clip(…,
    /// nativeBPM:)` construction or a `+=` is out of scope and named here so nobody reads the
    /// census as complete.
    func testTheNativeTempoHasExactlyTheKnownWriters() throws {
        let assign = try NSRegularExpression(pattern: #"\bnativeBPM\s*=[^=]"#)
        var hits: [String: Int] = [:]
        var read = 0
        for (name, text) in try sourceFiles() {
            read += 1
            let n = assign.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            if n > 0 { hits[name, default: 0] += n }
        }
        XCTAssertGreaterThan(read, 250, "only \(read) Swift files read — the walk failed (#454)")
        XCTAssertEqual(Set(hits.keys), ["Clip.swift", "AudioClipRegion.swift", "ClipStore.swift"],
                       "a new assignment to `nativeBPM` — found \(hits). Route it through ClipStore")
        XCTAssertEqual(hits["ClipStore.swift"], 2, "exactly the detection and the authored writer")
    }

    /// 10. SOURCE-TEXT SCAN — the seam decides, the store writes, and nothing else calls it.
    func testTheSeamChecksTheLockBeforeTheWrite() throws {
        var callers: [String] = []
        for (name, text) in try sourceFiles() where name != "ClipStore.swift"
            && text.contains("setAuthoredNativeBPM(") {
            callers.append(name)
        }
        XCTAssertEqual(callers, ["AudioTempoCorrection.swift"],
                       "`setAuthoredNativeBPM` must be reached only through the seam — found \(callers)")

        let seam = try code("Sources/Echoelmusic/Sequencer/AudioTempoCorrection.swift")
        let setter = try XCTUnwrap(body(of: "public static func setNativeBPM(", in: seam),
                                "ANCHOR MISSING: AudioTempoCorrection.setNativeBPM")
        let lock = try XCTUnwrap(setter.range(of: "isLockedByWarp("), "the seam lost its lock")
        let write = try XCTUnwrap(setter.range(of: "clipStore.setAuthoredNativeBPM("),
                                  "the seam lost its write")
        XCTAssertLessThan(lock.lowerBound, write.lowerBound, "the lock must be asked BEFORE the write")
        for forbidden in ["setTempo", "SessionContext", "setRegionWarp", "warpEnabled =",
                          "lengthTicks =", "adoptDetectedNativeBPM", "import SwiftUI"] {
            XCTAssertFalse(seam.contains(forbidden), "the seam must not reach `\(forbidden)`")
        }
        XCTAssertEqual(seam.components(separatedBy: "AudioClipRegion.nativeBPMRange").count - 1, 1,
                       "the range is forwarded once, never restated (#416)")
    }

    /// 11. SOURCE-TEXT SCAN — the surface: one call to the seam, the one numeric control, the
    /// scrub draft in the leaf, the row outside the combined facts (#621).
    func testTheSurfaceUsesTheOneFieldAndTheSeam() throws {
        let view = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "AudioTempoCorrection.setNativeBPM(").count - 1, 1)
        for forbidden in ["Slider(", "Stepper(", "nativeBPM ==", ".mediaRef"] {
            XCTAssertFalse(view.contains(forbidden), "WorkstationView must not contain `\(forbidden)`")
        }
        let row = try XCTUnwrap(slice(view, from: "private struct PartTempoRow",
                                      to: "private struct AnalysisRequest"),
                                "ANCHOR MISSING: PartTempoRow")
        for needle in ["EchoelValueField(", "range: AudioTempoCorrection.bounds", "unit: \"BPM\"",
                       "decimals: 1,", ".disabled(lockedByWarp", "@State private var draft",
                       ".onChange(of: clip.nativeBPM)"] {
            XCTAssertTrue(row.contains(needle), "PartTempoRow lost `\(needle)`")
        }
        let facts = try XCTUnwrap(slice(view, from: "private func laneFacts(",
                                        to: "private func warpSwitch("),
                                  "ANCHOR MISSING: laneFacts / warpSwitch")
        XCTAssertFalse(facts.contains("PartTempoRow("),
                       "the tempo row must sit OUTSIDE the combined facts, or VoiceOver loses it (#621)")
    }

    /// 12. COUNTERWEIGHT — the two rules are DIFFERENT on purpose. The Warp switch changes a
    /// part's span and is disabled while playing; the tempo row is locked by WARP, not by
    /// playback, because an unwarped tempo is inaudible (claim 5). Do not "harmonise" them.
    func testTheTempoRowIsGatedOnWarpNotOnPlayback() throws {
        let view = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(view.contains(".disabled(playing)"), "the Warp switch lost its playback gate")
        let row = try XCTUnwrap(slice(view, from: "private struct PartTempoRow",
                                      to: "private struct AnalysisRequest"),
                                "ANCHOR MISSING: PartTempoRow")
        let rows = try XCTUnwrap(body(of: "private func partTempoRows(", in: view),
                                 "ANCHOR MISSING: partTempoRows")
        XCTAssertFalse(row.contains("playing"), "the tempo row is gated on Warp, not on playback")
        XCTAssertFalse(rows.contains("playing"), "the tempo rows are gated on Warp, not on playback")
    }

    // MARK: - Source helpers

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("\(relative) not readable — source scan skipped")
        }
        return SourceText.codeOnly(text)
    }

    /// Every Swift file under `Sources/`, comment-stripped, keyed by file name.
    private func sourceFiles() throws -> [(String, String)] {
        let root = try repoRoot().appendingPathComponent("Sources")
        var out: [(String, String)] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            out.append((url.lastPathComponent, SourceText.codeOnly(text)))
        }
        return out
    }

    /// The text from `from` up to (not including) `to`, or nil if either anchor is missing.
    private func slice(_ text: String, from: String, to: String) -> String? {
        guard let start = text.range(of: from),
              let end = text.range(of: to, range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.lowerBound..<end.lowerBound])
    }

    /// The brace-matched body of the first declaration starting with `signature`.
    private func body(of signature: String, in text: String) -> String? {
        guard let start = text.range(of: signature),
              let open = text[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[open...index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
