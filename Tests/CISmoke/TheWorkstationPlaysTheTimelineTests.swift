// TheWorkstationPlaysTheTimelineTests.swift
// Echoel — #1437, founder Phase 4: *"Activate existing Timeline playback from the
// Workstation."* The arrangement is PLAYABLE, it plays on the ONE clock, and exactly one
// path may start it.
//
// ⛔ AND #1438, PHASE 4b, WHICH THIS FILE'S OWN POSITIVE TEST MADE NECESSARY.
// The #1437 predicate took a document ALONE and asked only "does a region sit on a lane this
// player drives". A region is a POINTER: its `clipID` can resolve to nothing, to an empty
// clip, to a clip of the wrong kind, or to notes the region's window throws away — and every
// one of those enabled Play and started `PatternEngine` over silence. **The test written to
// prove the feature worked constructed the defect and asserted it**: a bare `UUID()`, no clip
// installed, `XCTAssertTrue`. It was green, it was honest about what it drove, and what it
// drove was wrong. The lesson is not "write more tests" — it is that a POSITIVE case must be
// built from the same materials the app builds from (an installed clip with real notes), or
// it pins the shape of the bug. Claims 4–7, 11 and 13 are the negatives that did not exist.
//
// ⛔ THIS FILE ALSO EXISTS BECAUSE A CLAIM HAD TO BE INVERTED, NOT ROUTED AROUND.
// `TheWorkstationHasADoorTests` claim H asserted "`TimelineRegionPlayer.play(…)` has no
// production caller", and its own failure message named this commit: *"If that is Phase 4
// landing, this claim has done its job — delete it deliberately, in the same commit that
// makes the arrangement playable."* The cheap move was to satisfy it — bind the player to a
// second name, call through a helper, and keep a green counterweight that no longer counters
// anything. What replaces it is STRICTER than what it replaced: not "zero callers" but
// "exactly one, and it is the Workstation's Play".
//
// ⚠️ WHICH HALF IS WHICH (§1).
//   · Claims 1–14 are END-TO-END BEHAVIOUR. `TimelineRegionPlayer.canPlay(_:clips:)` and the
//     two transport strings are pure, Foundation-only functions of value types, so the
//     question "will Play do anything, and does the control say so" is DRIVEN rather than
//     scanned. That is the #1436 design decision reused, and #1438 is why it matters: the
//     predicate deliberately does NOT live inside a `private` SwiftUI body, where it could
//     only ever have been a source scan — and a source scan cannot tell a resolving `clipID`
//     from a dangling one. Taking `[Clip]` instead of the `@MainActor` `ClipStore` is the
//     other half: the store's `init` reads the App Group, and a guard that has to construct
//     one is a guard that will be skipped on the day it matters.
//   · Claims A–J are SOURCE-TEXT SCANS. `WorkstationView` is `@Environment`-resolving
//     SwiftUI behind `#if canImport(SwiftUI)` and `EchoelStudioView` is a 12 000-line
//     `private` view; this bundle can construct neither.
//   · **That a note is HEARD when Play is tapped is a DEVICE PROBE and is OPEN.** A green
//     `Build for Testing` proves the bundle compiles. It proves nothing about sound.
//     Registered at `WorkstationView`'s header (`founder-verify.py` prints it).
//
// ⚠️ HONEST GRADING (#433/#464) — #1438, against the parent `a9bc667ff`:
//   · claims 1–13 name `TimelineRegionPlayer.canPlay(_:clips:)`, whose SIGNATURE this commit
//     changes, so the bundle does not compile on the parent and NO behaviour claim has a
//     verdict there (#488 said out loud). Transcribed by hand against both trees, per §0.
//   · claim 4 (dangling clip) and claim 5 (empty clip) are the BLOCKER, and their honest
//     grade is not "red on the parent" but "unexpressible there": the parent's predicate has
//     no clip argument to be wrong about. That is what §3 means by a signature that cannot
//     answer truthfully — the bug was not in a body anyone could have fixed.
//   · claim 8 is the COUNTERWEIGHT (#364) and it is the one that could not be faked: a
//     predicate returning `false` unconditionally greens twelve claims here and reds only
//     this one.
//   · claims A, B, C, E, F, G, H — GREEN on BOTH trees, unchanged by this repair. They are
//     the content (#343): the clock, the single player, the single caller, the global Stop.
//   · claim D changed its NEEDLES with the signature; D2, I and J are new (D2 = one
//     definition, §11 H; I and J = the two LOW review findings, §10).
//
// ⭐ `SourceText.codeOnly` IS LOAD-BEARING HERE SINCE #1438 — AND THE LINE IT REPLACES SAID
// THE OPPOSITE, TWICE, IN OPPOSITE DIRECTIONS. Measured each time rather than reasoned:
//   · #1437 first claimed the stripper was load-bearing because claim E counts `play(` call
//     sites while two headers name `play(` in prose. Driving it disproved that — the prose
//     writes `TimelineRegionPlayer.play(…)`, never the RECEIVER form `player.play(` the scan
//     matches — so the line was rewritten to PROPHYLAKTISCH with 0 of 8 verdicts flipping.
//   · #1438 re-drove all 27 scan verdicts raw vs. stripped: **1 flips, and it is claim J.**
//     `WorkstationView` names `currentTick` exactly once, inside the comment that explains
//     why the body does not read it. A raw scan reds a correct file for quoting its own law —
//     the #367 shape (a needle that cannot tell a claim from its denial), disarmed by the
//     stripper rather than by deleting the sentence.
// The DURABLE lesson is the measurement, not either verdict: this went from "load-bearing"
// (wrong) to "prophylaktisch" (right, then) to "load-bearing" (right, now) in two commits,
// and each step was one command. `Tests/CISmoke/CLAUDE.md` §2 is about exactly this — a
// stripper claimed either way without driving it is borrowed confidence.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWorkstationPlaysTheTimelineTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let summary = "Sources/Echoelmusic/Studio/WorkstationSummary.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: - Fixtures — the difference between a POINTER and CONTENT

    private static let bar = TimelineTime.ticksPerBar

    /// A MIDI clip that WOULD sound: one note inside the first bar.
    private static func midiClip(_ notes: [Note] = [Note(pitch: 60, startStep: 0)]) -> Clip {
        Clip(name: "Take", kind: .midi, melody: MelodyClip(notes: notes))
    }

    /// One bar-long part placing `clip` at the top of `lane`.
    private static func part(_ clip: Clip, on lane: TimelineLane) -> TimelineRegion {
        TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0, lengthTicks: bar)
    }

    // MARK: - 1. BEHAVIOUR — an untouched song offers no start

    func testAnEmptyDocumentCannotPlay() {
        XCTAssertFalse(TimelineRegionPlayer.canPlay(TimelineDocument(), clips: []), """
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
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [Self.midiClip()]), """
            `TimelineStore.migrate` seeds exactly this on a fresh install: two lanes, no \
            parts. It is the state MOST users see first, and it is not a song. A startable \
            Play here would be the first thing a new user taps and the first thing that does \
            nothing. The clip grid is deliberately NOT empty in this case — a clip that \
            exists but is placed nowhere is still not an arrangement.
            """)
    }

    // MARK: - 3. BEHAVIOUR — parts belonging to no lane are not a song

    func testOrphanedPartsAloneCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip()
        let doc = TimelineDocument(
            lanes: [midi],
            regions: [TimelineRegion(laneID: UUID(), clipID: clip.id,
                                     startTick: 0, lengthTicks: Self.bar)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            Every part here names a lane the song does not have — reachable today, because a \
            decoded document's LANE list is `try?`-tolerant while its REGION list is not. The \
            clip it points at is REAL and full of notes, so nothing but the missing lane can \
            make this false: the part has content and nowhere to play it.
            """)
    }

    // MARK: - 4. BEHAVIOUR — a part pointing at a clip that is gone (GUARD A)

    func testAPartWhoseClipIsMissingCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let doc = TimelineDocument(
            lanes: [midi],
            regions: [TimelineRegion(laneID: midi.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: Self.bar)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [Self.midiClip()]), """
            ⛔ THIS IS THE #1438 BLOCKER, AND THE #1437 POSITIVE TEST CONSTRUCTED EXACTLY THIS \
            SHAPE AND ASSERTED TRUE. A region is a POINTER; a bare `UUID()` points at nothing. \
            The grid here is not even empty — it holds a perfectly good clip with a different \
            id, which is what an arrangement outliving its clip grid actually looks like (the \
            two persist as separate files). Tapping Play on this started `PatternEngine` over \
            silence: a running clock that reads, from outside, as playback.
            """)
    }

    // MARK: - 5. BEHAVIOUR — a clip that resolves and carries nothing (GUARD B)

    func testAResolvedButEmptyMidiClipCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let empty = Clip(name: "Composed · MIDI 1", kind: .midi,
                         melody: MelodyClip(notes: []), composerOwned: true)
        let doc = TimelineDocument(lanes: [midi], regions: [Self.part(empty, on: midi)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [empty]), """
            *"The clip exists"* is NOT the question (§4). This is the EVERYDAY shape, not an \
            exotic one: `ensureComposerRegion` and `ensureUserMidiRegion` both place a region \
            over a clip built with `MelodyClip(notes: [])`, and the notes arrive later — for a \
            user clip, with the note editor deleted by #475 and the MIDI-record path doorless \
            (#204), never. A predicate that stopped at `clips.clip(id:) != nil` would light \
            Play up on a brand-new empty track.
            """)
    }

    // MARK: - 6. BEHAVIOUR — notes the region's own window throws away (GUARD B)

    func testNotesOutsideTheRegionWindowAreNotContent() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        // Bar 5 of the clip, placed in a ONE-bar region at offset 0 — `loadClip` windows to
        // [0, 1920) before the roll ever sees a note, so this clip contributes nothing.
        let clip = Self.midiClip([Note(pitch: 60, startStep: 64)])
        let doc = TimelineDocument(lanes: [midi], regions: [Self.part(clip, on: midi)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            The engine does not play a clip, it plays a clip THROUGH a region window \
            (`RegionNoteWindow.windowed`, the M1b repair). A predicate that asked \
            `melody?.notes.isEmpty == false` would be a THIRD definition of "has content" — \
            agreeing with the player most of the time and diverging exactly where a user \
            trimmed or split a part down to a silent stretch. `executableNotes` is the same \
            call the loader makes, so the two cannot drift.
            """)
    }

    // MARK: - 7. BEHAVIOUR — a drum grid is a bar clock, not a voice (GUARD B)

    func testADrumsOnlyClipIsNotExecutableContent() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let beat = Clip(name: "Beat", kind: .midi,
                        drums: DrumPattern(steps: [[true, false, true, false]],
                                           accents: [[false, false, false, false]]),
                        melody: MelodyClip(notes: []))
        let doc = TimelineDocument(lanes: [midi], regions: [Self.part(beat, on: midi)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [beat]), """
            `loadClip` really does hand this grid to `pattern.load(steps:accents:)`, so it \
            LOOKS like content — and it is the single most plausible thing a later session \
            adds to `isExecutable` to "fix a false negative". It is not content: \
            `PatternEngine.onStep` has had ZERO production assignments since #166/#167 \
            (`git grep -n "onStep" -- Sources | grep -v ': *//'` → the declaration, the call \
            site, and `BeatPlayer.detach`'s `= nil`). No drum voice exists to receive it. \
            Counting it re-opens Play over silence through a door closed twice already.
            """)
    }

    // MARK: - 8. BEHAVIOUR — a MIDI part with real notes IS a song (GUARD C)

    func testAMidiPartWithNotesMakesTheSongStartable() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip()
        let doc = TimelineDocument(lanes: [midi], regions: [Self.part(clip, on: midi)])
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            THE COUNTERWEIGHT (#364): every claim above this one is a refusal, and a \
            predicate that returned `false` unconditionally would make all of them green. \
            This is the live path — Generate places a composer region, then \
            `updateComposerMelody` fills its clip — and if it is false the Play button is \
            permanently dead and the phase shipped nothing.
            """)
    }

    // MARK: - 9. BEHAVIOUR — a SECONDARY MIDI lane counts too

    func testAPartOnASecondMidiLaneStillCounts() {
        let first = TimelineLane(name: "MIDI 1", kind: .midi)
        let second = TimelineLane(name: "MIDI 2", kind: .midi)
        let clip = Self.midiClip()
        let doc = TimelineDocument(lanes: [first, second],
                                   regions: [Self.part(clip, on: second)])
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            `rollLaneID` is only the FIRST non-bio MIDI lane; the rest sound through \
            `primeSecondaryLanes`/`MultiRollFanout`. A predicate written against `rollLaneID` \
            alone would refuse to play a song that plays perfectly — #364, forbidding correct \
            work — and this is exactly the shortcut the obvious implementation takes.
            """)
    }

    // MARK: - 10. BEHAVIOUR — a BIO lane is shown, never driven

    func testAPartOnlyOnABioLaneIsNotASong() {
        let bio = TimelineLane(name: "Breath", kind: .midi, isBio: true)
        let clip = Self.midiClip()
        let doc = TimelineDocument(lanes: [bio], regions: [Self.part(clip, on: bio)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            `midiLaneIDs` and `audioLaneIDs` both filter `!isBio`, and since #1438 the \
            predicate walks `document.lanes` itself (it needs each lane's KIND, which a list \
            of ids has thrown away) — so the `!isBio` filter is written in TWO places and \
            this is the claim that keeps them in step. A bio lane carries the body's own \
            trace for the eye; routing it into the roll would play the performer's breath \
            back at them as notes.
            """)
    }

    // MARK: - 11. BEHAVIOUR — a clip on the wrong KIND of lane (GUARD F)

    func testAClipOnTheWrongKindOfLaneCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let audioClip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav")
        let doc = TimelineDocument(lanes: [midi], regions: [Self.part(audioClip, on: midi)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [audioClip]), """
            The mismatch is reachable from a decoded document — a region's `clipID` is just a \
            UUID and nothing type-checks it at rest — and a predicate that asked "is the LANE \
            driven" and "does the CLIP exist" as two independent questions says true here.
            ⚠️ AND THE REASON IT IS FALSE IS CONTENT, NOT LABEL, which is the opposite of what \
            the obvious implementation does. A MIDI lane loads `clip.melody`, an audio clip \
            has none, so nothing sounds. `isExecutable` deliberately does NOT compare \
            `clip.kind` to the lane's: the engine never does either (`loadClip` and \
            `resolveURL` read their content slot whatever the clip calls itself), and a gate \
            the loader lacks is a SECOND definition — the very defect this repair removes. \
            The first draft had that gate; the mutation run showed dropping it flipped no \
            claim, i.e. it was inert here and wrong on a clip carrying both (#364).
            """)
    }

    // MARK: - 11b. COUNTERWEIGHT — the predicate stays as kind-blind as the loader

    func testThePredicateDoesNotOutlawWhatTheLoaderWouldPlay() throws {
        let engine = try code(at: Self.player)
        guard let head = engine.range(of: "onLaneOfKind laneKind: ClipKind,"),
              let close = engine.range(of: "\n    }\n", range: head.upperBound..<engine.endIndex)
        else { throw AnchorMissing(reason: "`isExecutable` could not be delimited — re-anchor.") }
        XCTAssertFalse(String(engine[head.upperBound..<close.lowerBound]).contains("clip.kind"), """
            `isExecutable` must not gate on `clip.kind`. Not a style rule — a CORRESPONDENCE \
            rule: `loadClip`, `windowedBars`, `MultiRollFanout.activeLoads` and \
            `AudioLanePlayer.resolveURL` contain no clip-kind test between them, so a clip \
            carrying a melody plays on a MIDI lane whatever its `kind` field says. A \
            predicate stricter than its engine dims Play over a song that would sound (#364).
            ⚠️ IF YOU ADDED A KIND GATE TO THE LOADER TOO, this claim is doing its job and \
            must move WITH it, in the same commit — do not satisfy it by renaming the read.
            """)
    }

    // MARK: - 12. BEHAVIOUR — a kind with no engine is not content (GUARD E)

    func testAPartOnlyOnAVideoLaneIsNotASong() {
        let video = TimelineLane(name: "Video 1", kind: .video)
        let clip = Clip(name: "Intro", kind: .video, mediaRef: "Media/Video/intro.mov")
        let doc = TimelineDocument(lanes: [video], regions: [Self.part(clip, on: video)])
        XCTAssertFalse(TimelineRegionPlayer.canPlay(doc, clips: [clip]), """
            Lane kind, clip kind and media reference all AGREE here — and it is still not \
            playable, because no video engine ships (`ClipKind.timelineEngineKinds`, and the \
            capture path was removed outright by #1304). The arrangement may SHOW such a \
            lane — `WorkstationSummary` marks it "no engine yet" — but offering Play over it \
            would promise a rendering that does not exist.
            """)
    }

    // MARK: - 13. BEHAVIOUR — the AUDIO verdict, decided from the engine (GUARD G)

    func testAnAudioPartWithMediaPlaysAndOneWithoutDoesNot() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let withMedia = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav")
        let withNone = Clip(name: "Empty", kind: .audio, mediaRef: "")
        let playable = TimelineDocument(lanes: [lane], regions: [Self.part(withMedia, on: lane)])
        let silent = TimelineDocument(lanes: [lane], regions: [Self.part(withNone, on: lane)])

        XCTAssertTrue(TimelineRegionPlayer.canPlay(playable, clips: [withMedia]), """
            §5 asked for the audio contradiction to be decided ONCE, from runtime truth. It \
            is decided in favour of audio, and this is where that verdict is pinned: \
            `TimelineAudioSink` ships, `EchoelmusicApp` injects it into `AudioLanePlayer` \
            (`makeSink:` + `resolveURL:` → `MediaLibrary.resolveRef`), and \
            `TimelineRegionPlayer` drives it on every prime, step and stop. A persisted audio \
            region SOUNDS. What is missing is a PRODUCER, not an engine (#204/#527) — and \
            refusing to play a document the engine would happily play is the #527 harm: \
            "silently mute" where "visibly absent" was the honest state.
            """)
        XCTAssertFalse(TimelineRegionPlayer.canPlay(silent, clips: [withNone]), """
            …and the audio branch must still ask for CONTENT. An audio clip with no media \
            reference resolves to no URL, `AudioLanePlayer` skips it, and the transport would \
            run over nothing — the same defect as the empty MIDI clip, one kind over.
            """)
    }

    // MARK: - 14. BEHAVIOUR — the control says WHY, and never promises editing

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

    // MARK: - D. COUNTERWEIGHT — ONE definition of "can this play" (GUARD D)

    func testTheEngineGuardAndTheControlAskTheSameQuestion() throws {
        let engine = try code(at: Self.player)
        XCTAssertTrue(
            engine.contains("guard Self.canPlay(document, clips: clips.filledClips) else { return }"),
            """
            `play(...)` must be gated by `canPlay` itself, not by a copy of its conditions, \
            and it must hand over the SAME clip values the control did. Two spellings of one \
            threshold is the defect whether or not they agree today (#416) — and here \
            disagreement has a specific shape: an enabled button whose tap silently does \
            nothing, or a dimmed button over a song that would have played.
            """)
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains("TimelineRegionPlayer.canPlay(timeline.document,"), """
            The control must ask the ENGINE, not a lookalike computed from the summary. The \
            summary answers "what does this song look like"; only the player answers "will I \
            do anything with it".
            """)
        XCTAssertTrue(src.contains("clips: clipStore.filledClips"), """
            ⛔ #1438: the control must pass the CLIPS. The #1437 form asked \
            `canPlay(timeline.document)` and the engine agreed with it exactly — both were \
            blind in the same way, which is the worst kind of agreement: one definition, \
            uniformly wrong, and no test comparing two spellings could see it.
            """)
        // The UI may not grow a SECOND opinion by reading clip internals itself.
        for ownWork in ["firstExecutableRegion", "isExecutable", "executableNotes",
                        ".melody", ".mediaRef", "timelineEngineKinds"] {
            XCTAssertFalse(src.contains(ownWork), """
                `WorkstationView` names `\(ownWork)`. The view's job is to ASK; the moment it \
                inspects clip content itself there are two answers to one question, and the \
                one on screen is the one nobody drives in a test (§2).
                """)
        }
    }

    // MARK: - D2. COUNTERWEIGHT — the predicate is declared once (GUARD H)

    func testExactlyOneDefinitionOfPlayabilityExists() throws {
        var declarations: [String] = []
        var askers: [String] = []
        for (path, source) in try Self.allSources() {
            if source.contains("func canPlay(") { declarations.append(path) }
            if source.contains("canPlay(") { askers.append(path) }
        }
        XCTAssertEqual(declarations.sorted(), ["Sequencer/TimelineRegionPlayer.swift"], """
            "Can this timeline currently execute at least one placed region?" must have ONE \
            answer, and it lives with the thing that would execute it. Found declarations in: \
            \(declarations.sorted()). A second one in the view, the summary or `ClipKind` is \
            exactly the shape §2 forbids.
            """)
        XCTAssertEqual(askers.sorted(),
                       ["Sequencer/TimelineRegionPlayer.swift", "Studio/WorkstationView.swift"], """
            Only the engine and its one control may ask. Found: \(askers.sorted()).
            """)
        let src = try code(at: Self.view)
        for construction in ["ClipStore(", "TimelineStore(", "PatternEngine(", "PianoRollModel("] {
            XCTAssertFalse(src.contains(construction), """
                `WorkstationView` constructs `\(construction)`. Every one of these is owned \
                elsewhere and injected; a surface-local copy compiles, looks identical, and is \
                wired to nothing the user can hear (§8).
                """)
        }
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

    // MARK: - I. COUNTERWEIGHT — Stop still stops the CLOCK, not just the follow-state

    func testStopStillDelegatesToTheSharedTransport() throws {
        let engine = try code(at: Self.player)
        guard let head = engine.range(of: "public func stop() {"),
              let close = engine.range(of: "\n    }\n", range: head.upperBound..<engine.endIndex)
        else {
            throw AnchorMissing(reason: """
                `TimelineRegionPlayer.stop()` could not be delimited — re-anchor rather than \
                letting the one claim about the stop cascade skip.
                """)
        }
        let body = String(engine[head.upperBound..<close.lowerBound])
        XCTAssertTrue(body.contains("pattern?.stop()"), """
            Review finding (low, §10): `stop()` must keep DELEGATING to the shared \
            `PatternEngine`. It is the asymmetry that makes the pair correct — `stop()` stops \
            the clock, `handleTransportStopped()` deliberately does not (it is called FROM \
            the stop cascade and would loop). Drop this line and the Workstation's Stop \
            clears its own follow-state while the transport keeps running: the surface looks \
            stopped and the song does not stop.
            """)
        let external = engine.range(of: "public func handleTransportStopped() {")
        XCTAssertNotNil(external)
        if let external,
           let end = engine.range(of: "\n    }\n", range: external.upperBound..<engine.endIndex) {
            XCTAssertFalse(String(engine[external.upperBound..<end.lowerBound])
                .contains("pattern?.stop()"), """
                …and the external entry point must NOT stop the pattern: it is invoked BY the
                transport's own stop, so calling back into it is a cascade loop.
                """)
        }
    }

    // MARK: - J. COUNTERWEIGHT — the control does not subscribe to the playhead

    func testTheControlDoesNotReadThePlayhead() throws {
        let src = try code(at: Self.view)
        XCTAssertFalse(src.contains("currentTick"), """
            Review finding (low, §10): `WorkstationView` must not read `player.currentTick`. \
            It is `@ObservationIgnored` precisely so a view CANNOT subscribe to the ~8 Hz \
            position — but that attribute protects the observation graph, not the reader: a \
            body that reads it would simply render a stale number forever, which is worse \
            than not showing one. The 10.76.50 law is the other half: a live positional read \
            in an ancestor of a `.menu` host tears the popover down on every tick.
            """)
        XCTAssertFalse(src.contains("player.relocate"), """
            …and `relocate` is the neighbouring temptation once a position is on screen. \
            Phase 4 authorised a transport, not a playhead.
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
