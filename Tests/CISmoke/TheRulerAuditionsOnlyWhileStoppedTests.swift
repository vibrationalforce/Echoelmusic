// TheRulerAuditionsOnlyWhileStoppedTests.swift
// Echoel — GMMW AE-8 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.
// Orientiere dich an den Bigplayern"). Hold the ruler, then slide: while the piece is stopped, the
// audio under the finger sounds, one transport step at a time — the scrub every DAW has.
//
// WHAT THIS GUARDS. The scrub is an AUDITION, never a locate, and it never touches the render
// thread: each grain is one segment on the audition sink the Media Library previews with. The pure
// half (`RulerScrub`) decides which grain a finger names, and it owns none of the decisions it
// combines — the part is `TimelineScheduling.activeRegion`'s (#1440), the stretch of the file is
// the canvas's `ArrangeCanvas.audioWindow` (#416), whether a track is heard is
// `MultiRollFanout.audible`, the file is the player's resolver's (#1439). The gesture half
// (`RulerScrubGesture`) asks the Media Library's refusal before every grain.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR: a finger names a transport step on the ruler's scale — clamped at
//      both ends, never past the piece, nothing for degenerate geometry or a piece shorter than
//      one step.
//   2. END-TO-END BEHAVIOUR: the grain is one step of the FILE under the part that sounds there —
//      its file position from the canvas's window, cut at the part's end — on the first HEARD audio
//      track, top to bottom. Mute, a foreign solo, level 0 and a part at level 0 pass to the next
//      track; so does a winning part whose file is gone — never the part it shadows on its own
//      track — and a step past the end of a file the part outlasts (review NIT-7). MIDI and bio
//      tracks are not scrubbed; a tempo that cannot map sounds nothing.
//   3. SOURCE-TEXT SCAN of the gesture: the player, the loop, the engine and the store are read
//      ONLY inside the action `sound(_:)` — not in `body(content:)` and not in any computed member
//      the body evaluates (review SHOULD-3; 10.76.41/50); the refusal and the pace rule are asked
//      before the one audition; a lift or a refusal stops only a grain this scrub started (review
//      NIT-5); the only `@State` is the pace reference; nothing locates, plays or stops the piece.
//   7. END-TO-END BEHAVIOUR: the pace rule — a grain plays at least `minimumGrainSeconds` before
//      the next may cut it (review SHOULD-1: at 60–120 changes a second a slide was a click train).
//   4. SOURCE-TEXT SCAN of the mount: the ruler row applies the gesture once, after its tap, and
//      keeps AE-7's law — no drag and no gesture state in the row itself, still exactly two
//      `locate` calls (the tap and the VoiceOver step).
//   5. SOURCE-TEXT SCAN of the pure half: it asks the four owners and never walks the regions.
//   6. COUNTERWEIGHT (behaviour): the refusal it borrows still refuses while the piece or the loop
//      plays and while the engine is off.
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent and the worktree. Claims 1, 2,
// 3–5 and 7 name `RulerScrub` / `RulerScrubGesture`, which this same commit creates, so this file
// does NOT compile against the parent's `Sources/` and no assertion has a verdict there: they are
// FORWARD, one absence reported once (#486). Claim 6 is a COUNTERWEIGHT, green on both trees, and
// so is claim 4's AE-7 half (the row's two `locate` calls, no drag in the row). Mutants, each red on
// the claim it targets: the step snapped to the bar, no clamp past the end, the bottom track first,
// mute ignored, a part at level 0 scrubbed, a missing file falling to the shadowed part, no end cut,
// the refusal dropped, the refusal asked after the audition, `isPlaying` read in the body, a locate
// from the scrub, the drag moved into the row, a second walk of the regions — and, after the review,
// a hot read in a computed member, an unconditional stop, the pace rule dropped or asked after the
// audition, the past-file pass-through dropped, a pace below one grain.
//
// ⚠️ THE LIMIT. Nothing here sounds. Whether the grains read as a scrub (one step each, ~0.125 s at
// 120 BPM, at most one per `minimumGrainSeconds`), whether hold-then-slide wins over the scroll view,
// whether a held tap still locates, and whether the sink's first attach is inaudible while stopped
// are DEVICE PROBES — registered as NEEDS-FOUNDER-VERIFY at the ruler. The grain is the FILE, not
// the part as Play renders it (no transpose, stretch speed, fades or part level): named at the
// ruler, not guarded, because it is a limit and not a rule.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheRulerAuditionsOnlyWhileStoppedTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerQuarter
    private static let step = TimelineTime.ticksPerTransportStep
    private static let rulerPath = "Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift"

    // MARK: 1 — a finger names a step

    func testAFingerNamesATransportStep() {
        let song = 4 * Self.bar                       // 7680 ticks over 768 points: 10 ticks a point
        func tick(_ x: CGFloat, width: CGFloat = 768, song: Int = 4 * TimelineTime.ticksPerBar) -> Int? {
            RulerScrub.stepTick(atX: x, laneWidth: width, songTicks: song)
        }
        XCTAssertEqual(tick(0), 0)
        XCTAssertEqual(tick(12), Self.step, "12 points are 120 ticks — exactly one step")
        XCTAssertEqual(tick(11.9), 0, "a finger short of the next step still names this one")
        XCTAssertEqual(tick(48), Self.beat, "a step, not a bar: a scrub is finer than a tap")
        XCTAssertEqual(tick(-5), 0, "left of the lane is the first step")
        XCTAssertEqual(tick(768), song - Self.step, "the lane's end is the last step, never past the piece")
        XCTAssertEqual(tick(5000), song - Self.step)
        for x in stride(from: CGFloat(0), through: 768, by: 7.3) {
            guard let t = tick(x) else { return XCTFail("x \(x) named nothing") }
            XCTAssertEqual(t % Self.step, 0, "x \(x): on the step grid")
            XCTAssertLessThan(t, song)
        }
        XCTAssertNil(tick(.nan))
        XCTAssertNil(tick(10, width: 0))
        XCTAssertNil(tick(10, width: .infinity))
        XCTAssertNil(tick(10, song: Self.step - 1), "a piece shorter than one step names nothing")
    }

    // MARK: 2 — the grain is the part that sounds there

    private struct Library {
        var clips: [UUID: Clip] = [:]
        var files: [UUID: URL] = [:]
        mutating func add(_ clip: Clip, resolvable: Bool = true) {
            clips[clip.id] = clip
            if resolvable { files[clip.id] = URL(fileURLWithPath: "/media/\(clip.name).wav") }
        }
        func grain(_ doc: TimelineDocument, _ tick: Int, bpm: Double = 120) -> RulerScrub.Grain? {
            RulerScrub.grain(in: doc, atTick: tick, bpm: bpm, clip: { clips[$0] }, resolveURL: { files[$0] })
        }
    }

    private static func audio(_ name: String) -> Clip {
        Clip(name: name, kind: .audio, mediaRef: "\(name).wav", nativeDurationSeconds: 100)
    }

    func testTheGrainIsOneStepOfThePartThatSounds() throws {
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let top = TimelineLane(name: "Top", kind: .audio)
        let bottom = TimelineLane(name: "Bottom", kind: .audio)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        var library = Library()
        let a = Self.audio("a"), b = Self.audio("b"), gone = Self.audio("gone"), keys = Self.audio("keys")
        [a, b, keys].forEach { library.add($0) }
        library.add(gone, resolvable: false)
        // Top: part A, bar 2…4 (3900 ticks, so its end falls between two steps), file from 1.5 s.
        // Bottom: part B, bar 1…5, file from 0. One second of file is 960 ticks at 120 BPM.
        let partA = TimelineRegion(laneID: top.id, clipID: a.id, startTick: Self.bar, lengthTicks: 3900,
                                   contentOffsetSeconds: 1.5)
        let partB = TimelineRegion(laneID: bottom.id, clipID: b.id, startTick: 0, lengthTicks: 4 * Self.bar)
        let decoys = [TimelineRegion(laneID: midi.id, clipID: keys.id, startTick: 0, lengthTicks: 4 * Self.bar),
                      TimelineRegion(laneID: body.id, clipID: keys.id, startTick: 0, lengthTicks: 4 * Self.bar)]
        func doc(_ topLane: TimelineLane, _ part: TimelineRegion, extra: [TimelineRegion] = [],
                 bottom bottomLane: TimelineLane? = nil) -> TimelineDocument {
            TimelineDocument(lanes: [midi, topLane, bottomLane ?? bottom, body], regions: decoys + [part, partB] + extra)
        }

        let inA = Self.bar + Self.beat
        let grain = try XCTUnwrap(library.grain(doc(top, partA), inA), "a part sounds one beat into it")
        XCTAssertEqual(grain.regionID, partA.id, "the TOP heard track wins — MIDI and bio tracks are not scrubbed")
        XCTAssertEqual(grain.url, URL(fileURLWithPath: "/media/a.wav"), "the grain carries the resolved file")
        XCTAssertEqual(grain.fromSeconds, 2.0, accuracy: 1e-12, "the file offset plus one beat (0.5 s)")
        XCTAssertEqual(grain.lengthSeconds, 0.125, accuracy: 1e-12, "one transport step of file — a sixteenth at 120 BPM")

        let window = try XCTUnwrap(ArrangeCanvas.audioWindow(for: partA, clip: a, bpm: 120))
        XCTAssertEqual(grain.fromSeconds,
                       window.fromSeconds + Double(Self.beat) * window.lengthSeconds / Double(partA.lengthTicks),
                       accuracy: 1e-12, "the position is read off the stretch the canvas draws (#416)")

        let atTail = Self.bar + 3840                  // 60 ticks before A's end
        let tail = try XCTUnwrap(library.grain(doc(top, partA), atTail))
        XCTAssertEqual(tail.regionID, partA.id)
        XCTAssertEqual(tail.lengthSeconds, 0.0625, accuracy: 1e-12, "the last grain is cut at the part's end")

        let before = try XCTUnwrap(library.grain(doc(top, partA), Self.bar / 2), "before A, the bottom track sounds")
        XCTAssertEqual(before.regionID, partB.id)
        XCTAssertEqual(before.fromSeconds, 1.0, accuracy: 1e-12, "half a bar in, one second of B's file")

        var muted = top; muted.isMuted = true
        XCTAssertEqual(library.grain(doc(muted, partA), inA)?.regionID, partB.id, "a muted track passes to the next")
        var soloed = bottom; soloed.isSoloed = true
        XCTAssertEqual(library.grain(doc(top, partA, bottom: soloed), inA)?.regionID, partB.id,
                       "a foreign solo silences the top track")
        var silent = top; silent.level = 0
        XCTAssertEqual(library.grain(doc(silent, partA), inA)?.regionID, partB.id, "level 0 is not heard")
        var quietPart = partA; quietPart.gain = 0
        XCTAssertEqual(library.grain(doc(top, quietPart), inA)?.regionID, partB.id, "a part at level 0 is not heard")

        // Two parts on one start on the top track: the one placed later wins (#1440) …
        let later = TimelineRegion(laneID: top.id, clipID: b.id, startTick: Self.bar, lengthTicks: Self.bar)
        XCTAssertEqual(library.grain(doc(top, partA, extra: [later]), inA)?.regionID, later.id,
                       "overlapping parts on one track: the scheduler's choice")
        // … and when the winner's file is gone, the track is silent there — the scrub passes to the
        // next TRACK, never to the part the winner shadows.
        let lost = TimelineRegion(laneID: top.id, clipID: gone.id, startTick: Self.bar, lengthTicks: Self.bar)
        XCTAssertEqual(library.grain(doc(top, partA, extra: [lost]), inA)?.regionID, partB.id,
                       "a winner whose file is gone hands the scrub to the next track (#1439)")

        // A part that outlasts its file: past the file's end the sink would play nothing, so the
        // scrub passes to the next track (review NIT-7) — and before that end, it still sounds.
        let short = Clip(name: "short", kind: .audio, mediaRef: "short.wav", nativeDurationSeconds: 2.0)
        library.add(short)
        let outlasting = TimelineRegion(laneID: top.id, clipID: short.id, startTick: Self.bar, lengthTicks: 3900,
                                        contentOffsetSeconds: 1.5)
        XCTAssertEqual(library.grain(doc(top, outlasting), inA)?.regionID, partB.id,
                       "file second 2.0 of a 2.0 s file: nothing left to hear, the next track sounds")
        XCTAssertEqual(library.grain(doc(top, outlasting), Self.bar)?.regionID, outlasting.id,
                       "COUNTERWEIGHT: at file second 1.5 the same part still sounds")

        XCTAssertNil(library.grain(doc(top, partA), 4 * Self.bar), "after every part, nothing sounds")
        XCTAssertNil(library.grain(doc(top, partA), inA, bpm: 0), "a tempo that cannot map sounds nothing")
        XCTAssertNil(library.grain(doc(top, partA), inA, bpm: .nan))
    }

    // MARK: 3 — the gesture reads the player in its action

    func testTheScrubAsksTheRefusalBeforeItSounds() throws {
        let code = try source(Self.rulerPath)
        let gesture = try member("private struct RulerScrubGesture: ViewModifier {", in: code)
        let body = try member("func body(content: Content) -> some View {", in: gesture)
        for hot in ["player.", "isPlaying", "currentTick", "audioEngine", "clipStore", "preflightTempo"] {
            XCTAssertFalse(body.contains(hot), """
                `\(hot)` in the scrub's `body(content:)` — the player is read when a grain would sound, \
                never in a body (10.76.41/50).
                """)
        }
        XCTAssertTrue(body.contains(".gesture(scrub)"), "the modifier carries the gesture")
        XCTAssertTrue(body.contains(".onChange(of: tick) { _, next in sound(next) }"),
                      "a grain per step the finger enters — and the lift (nil) is what silences it")

        let sound = try member("private func sound(_ tick: Int?) {", in: gesture)
        // Outside `sound(_:)` the owners are only declared, never read — a computed member the body
        // evaluates is the same hot read as one in the body itself (review SHOULD-3).
        let outsideTheAction = gesture.replacingOccurrences(of: sound, with: "")
        XCTAssertNotEqual(outsideTheAction, gesture, "precondition: the action was cut out of the modifier")
        for owner in ["player.", "beatPlayer.", "audioEngine.", "clipStore."] {
            XCTAssertFalse(outsideTheAction.contains(owner), """
                `\(owner)` is read outside `sound(_:)` in the scrub. A read in `body(content:)` or in a \
                computed member it evaluates registers the modifier as an observer of that owner \
                (10.76.41/50); the owners are asked when a grain would sound, nowhere else.
                """)
        }
        guard let refusal = sound.range(of: "MediaBrowserView.previewRefusal(songPlaying: player.isPlaying,"),
              let pace = sound.range(of: "RulerScrub.mayStartGrain(secondsSinceLast: elapsed)"),
              let play = sound.range(of: "beatPlayer.audition(url: grain.url, fromSeconds: grain.fromSeconds, lengthSeconds: grain.lengthSeconds)") else {
            return XCTFail("ANCHOR MISSING: the refusal, the pace rule or the audition in `sound(_:)` (#408)")
        }
        XCTAssertLessThan(refusal.lowerBound, play.lowerBound, "the refusal is asked before anything sounds")
        XCTAssertLessThan(pace.lowerBound, play.lowerBound, "the pace rule is asked before a grain may cut the last one")
        XCTAssertTrue(sound.contains("guard let tick, !locked,"), "a lift and a locked row both stop the scrub")
        XCTAssertTrue(sound.contains("if pace.sounding { beatPlayer.stopAudition() }"), """
            a lift or a refusal silences a grain THIS scrub started, and only that: the sink is the \
            Media Library's too, and a step into a gap must not cut a preview (review NIT-5)
            """)
        XCTAssertEqual(occurrences(of: "beatPlayer.stopAudition()", in: sound), 1, "one stop, behind the flag")
        XCTAssertTrue(sound.contains("bpm: player.preflightTempo"), "the tempo the player itself will use")
        XCTAssertTrue(sound.contains("player.audioLanes?.resolvedURL(forClipID: $0)"),
                      "the player's own resolver decides whether a file is there (#1439)")
        XCTAssertEqual(occurrences(of: ".audition(", in: code), 1, "one audition call")

        for never in ["locate(", "cueTick", "player.play(", "player.stop(", "setCycle("] {
            XCTAssertFalse(gesture.contains(never), "`\(never)` in the scrub — it is an audition, never a locate")
        }
        XCTAssertTrue(gesture.contains("LongPressGesture(minimumDuration: 0.3)")
                      && gesture.contains(".sequenced(before: DragGesture("),
                      "hold first, then slide — a swipe still scrolls the piece")
        XCTAssertTrue(gesture.contains("@GestureState private var fingerX: CGFloat? = nil"),
                      "the finger is gesture state — it resets itself when the finger lifts or the gesture is cancelled")
        // The one `@State` is the pace REFERENCE: its fields change per grain and nothing shows them,
        // so they are kept off the observation path (the `ArrangeTimeZoom` viewport pattern, #364:
        // the finger itself stays gesture state).
        XCTAssertEqual(occurrences(of: "@State", in: gesture), 1, "one `@State`, the pace reference")
        XCTAssertTrue(gesture.contains("@State private var pace = Pace()") && gesture.contains("private final class Pace {"),
                      "the pace is a reference held once, never a value that redraws the ruler per grain")
    }

    // MARK: 4 — the row mounts it and keeps its own law

    func testTheRowMountsTheScrubAndStillNeverLocatesOnADrag() throws {
        let code = try source(Self.rulerPath)
        XCTAssertEqual(occurrences(of: ".modifier(RulerScrubGesture(", in: code), 1, "mounted once")
        let row = try member("struct ArrangeRulerLocator: View {", in: code)
        guard let tap = row.range(of: ".onTapGesture(coordinateSpace: .local)"),
              let scrub = row.range(of: ".modifier(RulerScrubGesture(document: document, songTicks: songTicks, laneWidth: width,") else {
            return XCTFail("ANCHOR MISSING: the row's tap or the scrub mount (#408)")
        }
        XCTAssertLessThan(tap.lowerBound, scrub.lowerBound, "on the same view, after the tap — the part blocks' order")
        XCTAssertTrue(row.contains("locked: locked))"), "the scrub honours the row's lock")
        for banned in ["DragGesture", "@GestureState", "@State"] {
            XCTAssertFalse(row.contains(banned), "COUNTERWEIGHT (AE-7): `\(banned)` in the row itself — the drag lives in the modifier")
        }
        XCTAssertEqual(occurrences(of: "player.locate(toTick: tick)", in: code), 2,
                       "COUNTERWEIGHT (AE-7): still the tap and the VoiceOver step — the scrub adds no locate")
    }

    // MARK: 5 — the pure half asks its owners

    func testTheGrainAsksItsOwners() throws {
        let code = try source(Self.rulerPath)
        let scrub = try member("enum RulerScrub {", in: code)
        for owner in ["TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick)",
                      "ArrangeCanvas.audioWindow(for: region, clip: media, bpm: bpm)",
                      "let media = clip(region.clipID)",
                      "MultiRollFanout.audible(document, laneID: laneID)",
                      "document.audioLaneIDs",
                      "resolveURL(region.clipID)"] {
            XCTAssertTrue(scrub.contains(owner), "the scrub asks `\(owner)` instead of deciding it again")
        }
        XCTAssertFalse(scrub.contains(".regions"),
                       "the scrub never walks the regions — which part sounds is defined once, in `activeRegion` (#1440)")
        XCTAssertTrue(scrub.contains("TimelineTime.ticksPerTransportStep"), "one step is the transport's own step")
    }

    // MARK: 7 — a grain plays before the next may cut it

    func testAGrainPlaysBeforeTheNextMayCutIt() {
        let floor = RulerScrub.minimumGrainSeconds
        XCTAssertGreaterThan(floor, 0, "a pace of zero is no pace")
        XCTAssertLessThanOrEqual(floor, 0.125, """
            the floor stays under one transport step at 120 BPM (0.125 s) — longer, and a slow slide \
            would skip steps a grain could have sounded
            """)
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: nil), "the first grain of a hold always sounds")
        XCTAssertFalse(RulerScrub.mayStartGrain(secondsSinceLast: 0), "a second grain in the same instant waits")
        XCTAssertFalse(RulerScrub.mayStartGrain(secondsSinceLast: floor / 2), "too soon: the last grain plays on")
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: floor), "at the floor the next grain may start")
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: 1), "a slow slide sounds every step it enters")
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: .nan), "an unreadable span never silences the scrub")
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: -1))
        XCTAssertTrue(RulerScrub.mayStartGrain(secondsSinceLast: .infinity))
    }

    // MARK: 6 — the borrowed refusal still refuses

    func testTheBorrowedRefusalStillRefuses() {
        XCTAssertNil(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: false, engineRunning: true),
                     "premise: with everything stopped a grain may sound")
        XCTAssertNotNil(MediaBrowserView.previewRefusal(songPlaying: true, loopPlaying: false, engineRunning: true),
                        "the piece playing refuses — the lane sink is already sounding it")
        XCTAssertNotNil(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: true, engineRunning: true))
        XCTAssertNotNil(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: false, engineRunning: false))
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    /// The text between the brace that opens after `head` and its matching close (#408).
    private func member(_ head: String, in text: String) throws -> String {
        guard head.hasSuffix("{"), let start = text.range(of: head) else {
            XCTFail("ANCHOR MISSING: `\(head)` (#408)")
            throw AnchorMissing(reason: head)
        }
        let from = text.index(before: start.upperBound)   // the anchor's own opening brace
        var depth = 0
        var index = from
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: from)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED after `\(head)`")
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
            // The tree is here, so a missing file is a move, not a missing checkout (#454).
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
