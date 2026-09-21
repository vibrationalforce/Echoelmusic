// TheWorkstationPlaysTheTimelineTests.swift
// Echoel — #1437, founder Phase 4: *"Activate existing Timeline playback from the
// Workstation."* The arrangement is PLAYABLE, it plays on the ONE clock, and exactly one
// path may start it.
//
// ⛔ THIS FILE EXISTS BECAUSE A CLAIM HAD TO BE INVERTED, NOT ROUTED AROUND.
// `TheWorkstationHasADoorTests` claim H asserted "`TimelineRegionPlayer.play(…)` has no
// production caller", and its own failure message named this commit: *"If that is Phase 4
// landing, this claim has done its job — delete it deliberately, in the same commit that
// makes the arrangement playable."* The cheap move was to satisfy it — bind the player to a
// second name, call through a helper, and keep a green counterweight that no longer counters
// anything. What replaces it is STRICTER than what it replaced: not "zero callers" but
// "exactly one, and it is the Workstation's Play".
//
// ⚠️ WHICH HALF IS WHICH (§1).
//   · Claims 1–7 are END-TO-END BEHAVIOUR. `TimelineRegionPlayer.canPlay(_:)` and the two
//     transport strings are pure, Foundation-only functions of a value type, so the question
//     "will Play do anything, and does the control say so" is DRIVEN rather than scanned.
//     That is the #1436 design decision reused: the predicate deliberately does NOT live
//     inside a `private` SwiftUI body, where it could only ever have been a source scan.
//   · Claims A–H are SOURCE-TEXT SCANS. `WorkstationView` is `@Environment`-resolving
//     SwiftUI behind `#if canImport(SwiftUI)` and `EchoelStudioView` is a 12 000-line
//     `private` view; this bundle can construct neither.
//   · **That a note is HEARD when Play is tapped is a DEVICE PROBE and is OPEN.** A green
//     `Build for Testing` proves the bundle compiles. It proves nothing about sound.
//     Registered at `WorkstationView`'s header (`founder-verify.py` prints it).
//
// ⚠️ HONEST GRADING (#433/#464), against the parent `228e48e54`:
//   · claims 1–7 name `TimelineRegionPlayer.canPlay` and `WorkstationSummary.transportHint`,
//     which this commit ADDS, so the bundle does not compile there and NO claim has a verdict
//     (#488 said out loud). Transcribed by hand instead, both trees, per §0.
//   · claims A, B, G — RED on the parent for their named reasons (the view had no player, no
//     `play(`, no `.disabled(`). ONE absence reported three times (#486), not three findings.
//   · claim E — the INVERSION. On the parent it would report 0 call sites and fail its new
//     "exactly one" assertion; that is the claim doing its job in reverse, and it is the
//     reason this file cannot simply be back-ported.
//   · claims C, D, F, H — GREEN on BOTH trees. They are the content (#343): the clock, the
//     one-definition guard, the single player, and the global Stop are the four things this
//     slice is most likely to have broken while looking correct.
//
// ⛔ `SourceText.codeOnly` IS PROPHYLAKTISCH HERE — 0 of 8 scan verdicts flip raw vs.
// stripped — AND THE FIRST DRAFT OF THIS LINE CLAIMED THE OPPOSITE. It said the stripper is
// LOAD-BEARING because claim E counts call sites while two file headers name `play(` in
// prose, so a raw scan "would count three callers where there is one". Driving it disproved
// that in one command: the prose says `TimelineRegionPlayer.play(…)` and `play()`, never the
// RECEIVER-plus-method form `player.play(` that the scan actually matches, so the raw and
// stripped verdicts are identical. The reasoning was plausible, it was written before the
// measurement, and `Tests/CISmoke/CLAUDE.md` §2 names exactly this: *a gate claimed
// load-bearing without measuring is the thing §2 keeps retracting.* It stays in use because
// the margin is one comment wide — the day a header writes `player.play(` the claim would
// go red on a correct tree — but PROPHYLAKTISCH is what it is today, and saying otherwise
// would be borrowing confidence from a check that is not doing the work.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWorkstationPlaysTheTimelineTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let summary = "Sources/Echoelmusic/Studio/WorkstationSummary.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: - 1. BEHAVIOUR — an untouched song offers no start

    func testAnEmptyDocumentCannotPlay() {
        XCTAssertFalse(TimelineRegionPlayer.canPlay(TimelineDocument()), """
            An empty document must not be startable. The control asks this exact question, so \
            a `true` here is a Play button that runs a clock over nothing — the "fake \
            playback" the phase brief forbids by name.
            """)
    }

    // MARK: - 2. BEHAVIOUR — the bootstrap shape is two lanes and NO song

    func testTheSeededLanesAloneCannotPlay() {
        let doc = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi),
                                           TimelineLane(name: "Audio 1", kind: .audio)],
                                   regions: [])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc), """
            `TimelineStore.migrate` seeds exactly this on a fresh install: two lanes, no \
            parts. It is the state MOST users see first, and it is not a song. A startable \
            Play here would be the first thing a new user taps and the first thing that does \
            nothing.
            """)
    }

    // MARK: - 3. BEHAVIOUR — parts belonging to no lane are not a song

    func testOrphanedPartsAloneCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let doc = TimelineDocument(
            lanes: [midi],
            regions: [TimelineRegion(laneID: UUID(), clipID: UUID(),
                                     startTick: 0, lengthTicks: TimelineTime.ticksPerBar)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc), """
            Every part here names a lane the song does not have — reachable today, because a \
            decoded document's LANE list is `try?`-tolerant while its REGION list is not. The \
            old guard asked only "a playable lane exists AND the region array is non-empty", \
            which this document satisfies, so it started the transport with nothing to chain: \
            a running clock over silence, which from outside is indistinguishable from \
            playback. This is the tightening #1437 made, and it is the one behaviour change \
            in the slice.
            """)
    }

    // MARK: - 4. BEHAVIOUR — a MIDI part on a MIDI lane is a song

    func testAMidiPartMakesTheSongStartable() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let doc = TimelineDocument(
            lanes: [midi],
            regions: [TimelineRegion(laneID: midi.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: TimelineTime.ticksPerBar)])
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc), """
            MIDI is the one kind with a shipped engine (`ClipKind.timelineEngineKinds`), so \
            this is the case Phase 4 exists to make audible. If this is false the Play button \
            is permanently dead and the phase shipped nothing.
            """)
    }

    // MARK: - 5. BEHAVIOUR — a SECONDARY MIDI lane counts too

    func testAPartOnASecondMidiLaneStillCounts() {
        let first = TimelineLane(name: "MIDI 1", kind: .midi)
        let second = TimelineLane(name: "MIDI 2", kind: .midi)
        let doc = TimelineDocument(
            lanes: [first, second],
            regions: [TimelineRegion(laneID: second.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: TimelineTime.ticksPerBar)])
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc), """
            `rollLaneID` is only the FIRST non-bio MIDI lane; the rest sound through \
            `primeSecondaryLanes`/`MultiRollFanout`. A predicate written against `rollLaneID` \
            alone would refuse to play a song that plays perfectly — #364, forbidding correct \
            work — and this is exactly the shortcut the obvious implementation takes.
            """)
    }

    // MARK: - 6. BEHAVIOUR — a kind with no engine is not content

    func testAPartOnlyOnAVideoLaneIsNotASong() {
        let video = TimelineLane(name: "Video 1", kind: .video)
        let doc = TimelineDocument(
            lanes: [video],
            regions: [TimelineRegion(laneID: video.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: TimelineTime.ticksPerBar)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc), """
            No video engine ships (`ClipKind.timelineEngineKinds` is `[.midi]`, and the video \
            capture path was removed outright by #1304). The arrangement may SHOW such a \
            lane — `WorkstationSummary` marks it "no engine yet" — but offering Play over it \
            would promise a rendering that does not exist.
            """)
    }

    // MARK: - 7. BEHAVIOUR — the control says WHY, and never promises editing

    func testTheTransportWordsAreTruthful() {
        let blocked = WorkstationSummary.transportHint(playing: false, startable: false)
        XCTAssertTrue(blocked.contains("no parts on a track that plays"), """
            An unavailable control must say what is missing. "Play timeline, dimmed" is what \
            VoiceOver reads without this, and it gives a blind user nothing to act on — the \
            accessibility half of the phase brief, which asks that a control not be announced \
            as available when playback cannot start. Read: \(blocked)
            """)
        let ready = WorkstationSummary.transportHint(playing: false, startable: true)
        let running = WorkstationSummary.transportHint(playing: true, startable: true)
        XCTAssertNotEqual(ready, running, """
            Play and Stop must not read the same to a listener. The glyph carries the \
            difference for a sighted user; the hint is the ONLY carrier for anyone else.
            """)
        XCTAssertTrue(running.lowercased().contains("stop"))

        // ⚠️ THE SCAN IS FOR PROMISES, NOT FOR WORDS, and the first draft got that wrong in a
        // way worth recording: it banned the substring "edit " and would have reddened the
        // caption "…this view still does not edit them", i.e. the one sentence that STATES
        // the boundary. A needle that cannot distinguish a claim from its denial is not a
        // needle (#367). What is forbidden is an OFFER — an imperative or a capability.
        let captions = [WorkstationSummary.transportCaption(playing: false, startable: true),
                        WorkstationSummary.transportCaption(playing: true, startable: true),
                        WorkstationSummary.transportCaption(playing: false, startable: false)]
        for words in captions + [ready, running, blocked] {
            for offer in ["tap to ", "you can ", "drag ", "record ", "import ", "trim "] {
                XCTAssertFalse(words.lowercased().contains(offer), """
                    The transport copy offers "\(offer.trimmingCharacters(in: .whitespaces))" \
                    — "\(words)". Phase 4 added the power to START the song, never to CHANGE \
                    it, and copy is where a hard-won boundary leaks first: a sentence is \
                    cheaper to write than the feature it promises.
                    """)
            }
        }
        XCTAssertTrue(captions[0].lowercased().contains("does not edit"), """
            The ready caption must still SAY the boundary out loud. Adding a transport is \
            exactly the moment a read-only surface starts reading as an editor, and the one \
            sentence beside the button is where that is cheapest to prevent. Read: \
            \(captions[0])
            """)
    }

    // MARK: - A. SCAN — Play reaches the existing execution path, with owned arguments

    func testThePlayControlReachesTheExistingPlayer() throws {
        let src = try code(at: Self.view)
        guard let call = src.range(of: "player.play(") else {
            throw AnchorMissing(reason: """
                `WorkstationView` no longer calls `player.play(`. That is the whole of Phase 4 \
                — if the binding was renamed, re-anchor; if the call is gone, the arrangement \
                is unplayable again and this file must say so loudly rather than skip.
                """)
        }
        let args = String(src[call.upperBound...].prefix(400))
        for handed in ["document:", "clips:", "pattern:", "pianoRoll:"] {
            XCTAssertTrue(args.contains(handed), """
                The call omits `\(handed)`. All four are ALREADY-OWNED instances — the \
                document from `TimelineStore`, the clock from `PatternEngine`, the notes from \
                `PianoRollModel`, the clips from `ClipStore`. A missing one means the view \
                started minting its own, which is the Ω21 fork.
                """)
        }
        XCTAssertTrue(args.contains("timeline.document"), """
            The document handed over must be the store's, not a copy. Anything else is a \
            second truth that diverges from what is persisted the moment the user edits.
            """)
    }

    // MARK: - B. SCAN — Stop is the player's own stop, and nothing else is reached

    func testStopIsTheExistingStopAndTheSurfaceReachesNothingElse() throws {
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains("player.stop()"), """
            Stop must be `TimelineRegionPlayer.stop()` — the path that also stops the shared \
            pattern, releases every sounding note and clears the launch state. A Workstation \
            that flipped a local flag instead would leave notes ringing and the transport \
            running, which is the lifecycle bug this claim exists to prevent.
            """)
        // Structural, not a blacklist: the player has ~30 public members (sinks, relocate,
        // launchRegion, enableMultiRoll…). A read-only-plus-transport surface may reach
        // exactly three of them, and anything else is scope this phase did not authorise.
        let reached = Set(Self.messages(to: "player", in: src))
        XCTAssertEqual(reached, ["play", "stop", "isPlaying"], """
            The surface reaches the player for \(reached.sorted()). Phase 4 authorised a \
            transport, not an editor: `relocate`, `launchRegion`, `loopEnabled` and the sinks \
            are all one tap away and all out of bounds here.
            """)
    }

    // MARK: - C. COUNTERWEIGHT — no second clock is introduced

    func testTheSurfaceOwnsNoClock() throws {
        for path in [Self.view, Self.summary] {
            let src = try code(at: path)
            for forbidden in ["Timer", "DispatchSourceTimer", "CADisplayLink", "AsyncTimerSequence",
                             "asyncAfter", "Task.sleep", "TimelineClock", "WorkstationClock"] {
                XCTAssertFalse(src.contains(forbidden), """
                    \(path) names `\(forbidden)`. `PatternEngine` is the musical authority and \
                    the Workstation JOINS it; a surface-local tick would be a second tempo \
                    truth over one audio graph, which is the Ω-level mistake this phase was \
                    most at risk of making.
                    """)
            }
        }
        let engine = try code(at: Self.player)
        XCTAssertTrue(engine.contains("pattern.play(cause: .timelineRegion)"), """
            `play(...)` must hand the start to the shared `PatternEngine` and name itself \
            while doing it. Without that line the timeline would need its own clock, and the \
            `.timelineRegion` breadcrumb — the only thing that tells a device log WHO started \
            the transport — would be absent exactly when it is needed.
            """)
    }

    // MARK: - D. COUNTERWEIGHT — one definition of "can this play"

    func testTheEngineGuardAndTheControlAskTheSameQuestion() throws {
        let engine = try code(at: Self.player)
        XCTAssertTrue(engine.contains("guard Self.canPlay(document) else { return }"), """
            `play(...)` must be gated by `canPlay` itself, not by a copy of its conditions. \
            Two spellings of one threshold is the defect whether or not they agree today \
            (#416) — and here disagreement has a specific shape: an enabled button whose tap \
            silently does nothing.
            """)
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains("TimelineRegionPlayer.canPlay(timeline.document)"), """
            The control must ask the ENGINE, not a lookalike computed from the summary. The \
            summary answers "what does this song look like"; only the player answers "will I \
            do anything with it".
            """)
    }

    // MARK: - E. THE REPLACEMENT FOR CLAIM H — exactly one production caller

    func testTheTimelinePlayerHasExactlyTheOneAuthorisedCaller() throws {
        let declaration = try code(at: Self.player)
        guard declaration.contains("public func play(") else {
            throw AnchorMissing(reason: """
                `TimelineRegionPlayer` no longer declares `play(`; this scan is anchored on it. \
                Re-anchor rather than reporting "one caller" for a method that is gone.
                """)
        }
        var callers: [String] = []
        for (path, source) in try Self.allSources() {
            for name in Self.playerNames(in: source) where source.contains("\(name).play(") {
                callers.append(path)
            }
        }
        XCTAssertEqual(callers.sorted(), ["Studio/WorkstationView.swift"], """
            The authorised production caller of `TimelineRegionPlayer.play(…)` is the \
            Workstation's Play and nothing else. Found: \(callers.sorted()).
            · EMPTY means Phase 4 was undone — the arrangement is unplayable and the door \
              leads to a read-only plate again.
            · MORE THAN ONE means a second surface can start the song. That is not a style \
              point: two starters over one follow-state is how a transport ends up believing \
              it is playing twice, and the second one is always the one nobody tests.
            """)
    }

    // MARK: - F. COUNTERWEIGHT — still exactly one player, constructed once, by the app

    func testTheAppStillConstructsTheOnlyPlayer() throws {
        var sites: [String] = []
        for (path, source) in try Self.allSources() where source.contains("TimelineRegionPlayer(") {
            sites.append(path)
        }
        XCTAssertEqual(sites.sorted(), ["EchoelmusicApp.swift"], """
            `TimelineRegionPlayer` must be constructed exactly once, by the app, so that every \
            surface shares one follow-state and the app's sinks, `audioLanes` and the \
            `addStopSubscriber("timeline")` wiring apply to the player people actually hear. \
            Found: \(sites.sorted()). A view-local `@State` player would look identical on \
            screen, compile, and be wired to nothing.
            """)
        let app = try code(at: Self.app)
        XCTAssertTrue(app.contains(".environment(timelinePlayer)"), """
            The one player must reach the Workstation through the environment. Without this \
            line the view's `@Environment(TimelineRegionPlayer.self)` traps at runtime — a \
            crash on opening the plate, which no compile gate can see.
            """)
    }

    // MARK: - G. SCAN — the control is unavailable when the engine would refuse

    func testThePlayControlDisablesItselfRatherThanLying() throws {
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains(".disabled(!playing && !startable)"), """
            A control that can be tapped and does nothing is a lying control, and this repo \
            has paid for that shape before. The disable must be exactly "not running AND not \
            startable": disabling it while PLAYING would strand the user with a running \
            transport and no way to stop it from the surface that started it.
            """)
        XCTAssertTrue(src.contains("minHeight: 44"), """
            The transport is a primary control and must carry the 44 pt HIG tap target the \
            chip strip already does (#113/#353b).
            """)
        XCTAssertTrue(src.contains("accessibilityLabel(playing ? \"Stop timeline\" : \"Play timeline\")"), """
            The button is icon-plus-word on screen and a LABEL to VoiceOver. It must name the \
            thing it acts on — "Play" alone, on a plate that also holds the instrument's own \
            transport, does not say WHICH.
            """)
    }

    // MARK: - H. COUNTERWEIGHT — the global Stop still reaches the timeline

    func testTheOneTransportStillStopsTheArrangement() throws {
        let app = try code(at: Self.app)
        XCTAssertTrue(app.contains("addStopSubscriber(\"timeline\")"), """
            Any Stop — the instrument's own ■, a route loss, the background cascade — must \
            reset the timeline's follow-state. Without this subscriber the arrangement would \
            keep believing it is playing after the transport died, and the next Play would \
            find `isPlaying` already true and do nothing: the "second Play does not work" \
            bug, arriving one step removed from where it was caused.
            """)
        let engine = try code(at: Self.player)
        XCTAssertTrue(engine.contains("public func handleTransportStopped()"), """
            The external-stop entry point must exist for the subscriber above to call. It is \
            deliberately NOT `stop()`: that one stops the pattern in turn, which from inside \
            a stop cascade is a loop.
            """)
        XCTAssertTrue(engine.contains("guard isPlaying else { return }"), """
            Both stop paths must be no-ops when already stopped. Stop-while-stopped is \
            ordinary (the global ■ fires the subscriber every time) and must stay safe.
            """)
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    /// Every member reached on `receiver`. Blunt on purpose: it over-collects rather than
    /// under-collects, because a member this missed would be the one that slipped through.
    private static func messages(to receiver: String, in source: String) -> [String] {
        var found: [String] = []
        var cursor = source.startIndex
        let needle = receiver + "."
        while let hit = source.range(of: needle, range: cursor..<source.endIndex) {
            cursor = hit.upperBound
            if hit.lowerBound > source.startIndex {
                let before = source[source.index(before: hit.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" || before == "." { continue }
            }
            var member = ""
            var index = hit.upperBound
            while index < source.endIndex, source[index].isLetter || source[index].isNumber
                    || source[index] == "_" {
                member.append(source[index])
                index = source.index(after: index)
            }
            if !member.isEmpty { found.append(member) }
        }
        return found
    }

    /// Identifiers that hold the player in ONE file: bound by construction
    /// (`= TimelineRegionPlayer()`), resolved from the environment
    /// (`@Environment(TimelineRegionPlayer.self) private var player`), or aliased ONE hop
    /// from either (`let p = player`).
    ///
    /// ⚠️ THE LIMIT IS STATED RATHER THAN PAPERED OVER (§"do not fake completeness"). One
    /// alias hop is what this resolves — the same depth `needle-reachability.py` chose, for
    /// the same reason: two hops needs a type checker, and a scanner that guesses at type
    /// flow fails in the reassuring direction. A determined second caller CAN hide behind two
    /// assignments or a closure parameter. What makes that acceptable is that it cannot
    /// happen by ACCIDENT, and accident is what a guard is for; the deliberate case is
    /// covered by §0's repo-wide search at review time, not by this scan pretending to.
    private static func playerNames(in source: String) -> Set<String> {
        var names: Set<String> = []
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            if let head = line.range(of: "= TimelineRegionPlayer(") {
                if let name = line[line.startIndex..<head.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: { $0 == " " || $0 == ":" }).last {
                    names.insert(String(name))
                }
            }
            if line.contains("@Environment(TimelineRegionPlayer.self)"),
               let varWord = line.range(of: "var ") {
                let rest = line[varWord.upperBound...].trimmingCharacters(in: .whitespaces)
                if let name = rest.split(whereSeparator: { $0 == " " || $0 == ":" }).first {
                    names.insert(String(name))
                }
            }
        }
        // ONE alias hop: `let p = player` where `player` is already known. The snapshot is
        // not style: inserting into the set being iterated is the kind of thing that works
        // by COW accident and stops working when someone changes the collection type.
        let direct = names
        for line in lines {
            for known in direct {
                guard let head = line.range(of: "= \(known)") else { continue }
                let after = line[head.upperBound...].trimmingCharacters(in: .whitespaces)
                guard after.isEmpty || after.hasPrefix("/") else { continue }   // not `= player.foo`
                if let name = line[line.startIndex..<head.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: { $0 == " " || $0 == ":" }).last {
                    names.insert(String(name))
                }
            }
        }
        return names
    }

    private static func allSources() throws -> [(String, String)] {
        let root = try treeRootStatic().appendingPathComponent("Sources")
        var out: [(String, String)] = []
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        while let rel = enumerator?.nextObject() as? String {
            guard rel.hasSuffix(".swift") else { continue }
            let text = (try? String(contentsOf: root.appendingPathComponent(rel),
                                    encoding: .utf8)) ?? ""
            out.append((rel.replacingOccurrences(of: "Echoelmusic/", with: ""),
                        SourceText.codeOnly(text)))
        }
        return out
    }

    private func code(at relativePath: String) throws -> String {
        let path = try Self.treeRootStatic().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Directory-gated, never per-file (#475): a `fileExists` bracket around each read turns
    /// the very catastrophe this file guards against into a green SKIP.
    private static func treeRootStatic() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }
}
