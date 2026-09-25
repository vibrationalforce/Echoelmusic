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
// ⛔ AND #1439, PHASE 4c — THREE MORE WAYS THE SAME BUTTON COULD START A SILENT CLOCK, found
// by an outside adversarial review and all three real in the tree #1438 shipped. Each was a
// place where the predicate answered from something ADJACENT to the truth instead of the
// truth: an audio region from its `mediaRef` being a non-empty STRING rather than from the
// resolver that finds the file; a legacy seconds-trimmed MIDI region at offset 0 while the
// loader used the tempo-derived offset; and any region at all, including one lying entirely
// between two transport grid ticks, which the scheduler can never look at. Claims 13/13b,
// 15/16 and 17/18/19 are the six that did not exist, and K/L/M/N are their scans.
//
// ⚠️ WHICH HALF IS WHICH (§1).
//   · Claims 1–19 are END-TO-END BEHAVIOUR. `TimelineRegionPlayer.canPlay(_:clips:bpm:resolveAudio:)`,
//     `TimelineScheduling.isSampleable`, `MediaLibrary.resolveRef` and the two transport
//     strings are functions of value types, so "will Play do anything, and does the control
//     say so" is DRIVEN rather than scanned. That is the #1436 design decision reused, and
//     #1438/#1439 are why it matters: the predicate deliberately does NOT live inside a
//     `private` SwiftUI body, where it could only ever have been a source scan — and a source
//     scan cannot tell a resolving `clipID` from a dangling one, nor a reachable region from
//     an unreachable one. Taking `[Clip]` instead of the `@MainActor` `ClipStore` is the other
//     half: the store's `init` reads the App Group, and a guard that has to construct one is a
//     guard that will be skipped on the day it matters.
//   · Claims A–N are SOURCE-TEXT SCANS. `WorkstationView` is `@Environment`-resolving SwiftUI
//     behind `#if canImport(SwiftUI)` and `EchoelStudioView` is a 12 000-line `private` view;
//     this bundle can construct neither.
//   · **That a note is HEARD when Play is tapped is a DEVICE PROBE and is OPEN.** A green
//     `Build for Testing` proves the bundle compiles. It proves nothing about sound.
//     Registered at `WorkstationView`'s header (`founder-verify.py` prints it).
//
// ⚠️ HONEST GRADING (#433/#464) — #1439, against the parent `3ee39c5e3`:
//   · The bundle does NOT compile on the parent: this file names `canPlay(_:clips:bpm:resolveAudio:)`,
//     `TimelineScheduling.isSampleable`, `RegionNoteWindow.effectiveOffsetTicks`,
//     `AudioLanePlayer.resolvedURL(forClipID:)`, `TimelineRegionPlayer.preflightTempo` and
//     `.fallbackTempo` — six symbols this commit creates. **No behaviour claim has a verdict
//     there** (#488, said out loud rather than left to read as "green on its own tree").
//     Everything below was transcribed in Python against BOTH trees, per §0.
//   · BEHAVIOUR, driven: **22 of 22 cases pass** on the shipped chain. The three new blockers
//     (13b audio-resolver-nil, 15 legacy-offset, 17 unsampled sliver) are UNEXPRESSIBLE on the
//     parent — its predicate has no resolver and no bpm to be wrong about, and no schedulability
//     question at all. That is what §3 means by a signature that cannot answer truthfully.
//   · MUTATION, required by §11: **8 of 8 mutants killed** — `mediaref-is-enough`,
//     `ignore-resolver`, `ticks-only` (drop the legacy fallback), `no-step-align`,
//     `always-sampleable`, `inclusive-end`, `never-play`, and the counterweights hold.
//     ⚠️ `no-step-align` SURVIVED the first run: every fixture's offset happened to be a
//     multiple of the step, so the alignment half of `effectiveOffsetTicks` was untested.
//     Claim 16's second assertion (0.52 s → 499 ticks → snaps to 480) is what closed it. A
//     mutant that survives is the guard telling you which half of a helper you never drove.
//   · SCANS, driven: **40 of 40 green on the worktree, 18 red on the parent.** Of those 18,
//     exactly ONE is a regression in the #433 sense — **L2**, "`TimelineRegionPlayer` must not
//     read `mediaRef`", which is red there for precisely the reason its message gives. The
//     rest are FORWARD guards (B2, D1, D2c, L1, L3, L5) or three ABSENCES reported N times
//     (#486): K1–K4 = `effectiveOffsetTicks` does not exist, M1–M4 = `isSampleable` does not
//     exist, N1–N3 = `preflightTempo` does not exist. Counting those eleven as eleven findings
//     would be the flattering direction of the defect #433 names.
//   · COUNTERWEIGHTS, green on both trees and the point of the file (#343): A, C, E, F, G, H,
//     I, J, D2a, D2b, D3, L4 — the clock, the single player, the single caller, the global
//     Stop, the cold body.
//
// ⭐ `SourceText.codeOnly` IS LOAD-BEARING, MEASURED AGAIN — **4 of 40 scan verdicts flip raw
// vs. stripped** (D3, J1, L2, N4), up from 1 of 27 at #1438. Every one of the four is a needle
// whose text occurs in this tree ONLY inside a comment that explains why the code does not do
// the thing: `WorkstationView` names `currentTick` and `.tempo` in the sentences forbidding
// those reads, and `TimelineRegionPlayer` names `mediaRef` four times in the block recording
// why it stopped reading it. A raw scan reds a correct file for quoting its own law — the #367
// shape, disarmed by the stripper rather than by deleting the sentence.
// ⛔ AND THE FIRST TRANSCRIPTION OF THE STRIPPER WAS STRICTER THAN THE REAL ONE: it blanked
// string-literal CONTENTS, so three needles that live inside literals (`"Play timeline"`,
// `addStopSubscriber("timeline")`, `onTempoChange(id: "timeline.preflight")`) read as RED on a
// correct tree. `codeOnly` blanks COMMENTS and is merely string-literal AWARE. A transcription
// that models the tool WRONGLY is not a measurement of the guard, even when it errs toward
// alarm — which is the cheaper direction, and still not evidence.
// The DURABLE lesson is the measurement, not the verdict: this went "load-bearing" (wrong) →
// "prophylaktisch" (right, then) → "load-bearing" (right, now) across three commits, each step
// one command. `Tests/CISmoke/CLAUDE.md` §2 is about exactly this.

import Foundation
import XCTest
@testable import Echoelmusic

// ⚠️ `@MainActor` SINCE #1439, AND THE REASON IS THE POINT OF THE SLICE. `canPlay` stopped
// being `nonisolated` when it stopped guessing about audio: reaching
// `AudioLanePlayer.resolvedURL(forClipID:)` — the resolver the streaming path actually uses —
// means touching `@MainActor` state, and Swift 6 will not let a nonisolated function call a
// closure that does. The annotation is the price of the truthful dependency (§2). It costs
// this bundle nothing: no claim here constructs a store, an engine or an App-Group container.
@MainActor
final class TheWorkstationPlaysTheTimelineTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let summary = "Sources/Echoelmusic/Studio/WorkstationSummary.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let scheduling = "Sources/Echoelmusic/Sequencer/TimelineScheduling.swift"
    private static let window = "Sources/Echoelmusic/Sequencer/RegionNoteWindow.swift"
    private static let lanes = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: - Fixtures — the difference between a POINTER and CONTENT

    private static let bar = TimelineTime.ticksPerBar
    private static let step = TimelineTime.ticksPerTransportStep

    /// The predicate asked the way the DOCUMENT-ONLY claims mean it: at the default tempo,
    /// with NOTHING resolvable. A claim that is ABOUT the tempo or about media passes its own
    /// — spelled out at the call site, so a reader can see which input each one is testing.
    /// The default resolver says NO on purpose: a claim that accidentally depended on media
    /// would then go red rather than pass for a reason its name does not give (#367).
    private static func startable(_ doc: TimelineDocument, clips: [Clip],
                                  bpm: Double = TimelineRegionPlayer.fallbackTempo,
                                  resolveAudio: (UUID) -> URL? = { _ in nil }) -> Bool {
        TimelineRegionPlayer.canPlay(doc, clips: clips, bpm: bpm, resolveAudio: resolveAudio)
    }

    /// A stand-in for `AudioLanePlayer.resolvedURL(forClipID:)` that resolves exactly `ids`.
    /// It is a STUB of the dependency, not a second implementation: the guard's job is to
    /// prove the predicate ASKS and OBEYS, and whether `MediaLibrary` finds a particular file
    /// on a particular device is neither knowable here nor the thing under test.
    private static func resolving(_ ids: UUID...) -> (UUID) -> URL? {
        let yes = Set(ids)
        let url = URL(fileURLWithPath: "/echoel/test/loop.wav")
        return { yes.contains($0) ? url : nil }
    }

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
        XCTAssertFalse(Self.startable(TimelineDocument(), clips: []), """
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
        XCTAssertFalse(Self.startable(doc, clips: [Self.midiClip()]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [clip]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [Self.midiClip()]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [empty]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [clip]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [beat]), """
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
        XCTAssertTrue(Self.startable(doc, clips: [clip]), """
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
        XCTAssertTrue(Self.startable(doc, clips: [clip]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [clip]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [audioClip]), """
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
        XCTAssertFalse(Self.startable(doc, clips: [clip]), """
            Lane kind, clip kind and media reference all AGREE here — and it is still not \
            playable, because no video engine ships (`ClipKind.timelineEngineKinds`, and the \
            capture path was removed outright by #1304). The arrangement may SHOW such a \
            lane — `WorkstationSummary` marks it "no engine yet" — but offering Play over it \
            would promise a rendering that does not exist.
            """)
    }

    // MARK: - 13. BEHAVIOUR — the AUDIO verdict, decided by the RESOLVER (GUARD G)

    func testAnAudioPartPlaysOnlyWhenItsMediaActuallyResolves() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav")
        let doc = TimelineDocument(lanes: [lane], regions: [Self.part(clip, on: lane)])

        XCTAssertTrue(Self.startable(doc, clips: [clip], resolveAudio: Self.resolving(clip.id)), """
            §5 of #1438 asked for the audio contradiction to be decided ONCE, from runtime \
            truth. It is decided in favour of audio, and this is where that verdict is \
            pinned: `TimelineAudioSink` ships, `EchoelmusicApp` injects it into \
            `AudioLanePlayer` (`makeSink:` + `resolveURL:` → `MediaLibrary.resolveRef`), and \
            `TimelineRegionPlayer` drives it on every prime, step and stop. A persisted audio \
            region whose media resolves SOUNDS. What is missing is a PRODUCER, not an engine \
            (#204/#527) — and refusing to play a document the engine would happily play is \
            the #527 harm: "silently mute" where "visibly absent" was the honest state.
            """)

        XCTAssertFalse(Self.startable(doc, clips: [clip], resolveAudio: { _ in nil }), """
            ⛔ THE #1439 AUDIO BLOCKER, AND THE CLIP IS BYTE-FOR-BYTE THE ONE ABOVE. Only the \
            RESOLVER changed its answer — which is what happens when the recording is \
            deleted, moved off the device, or was written by another install. #1438 asked \
            `!(clip.mediaRef?.isEmpty ?? true)`, so a non-empty STRING enabled Play; \
            `AudioLanePlayer.prime`/`.apply` then `continue` past that lane at all three \
            `guard let url = self.resolveURL(...)` sites and the transport ran over nothing. \
            A media reference is not a file, and the only thing that knows the difference is \
            the resolver the player itself uses.
            """)
    }

    // MARK: - 13b. BEHAVIOUR — an EMPTY reference resolves to nothing, at the real resolver

    func testAnEmptyMediaReferenceResolvesToNothing() {
        XCTAssertNil(MediaLibrary.resolveRef(nil), """
            The predicate no longer inspects `mediaRef` at all — it asks the resolver — so \
            "an audio clip with no media cannot play" is only still true because the REAL \
            resolver refuses an absent reference. That link is what this claim pins; without \
            it, claim 13's stub would be the only evidence and the end-to-end statement would \
            rest on a fixture.
            """)
        XCTAssertNil(MediaLibrary.resolveRef(""), """
            …and the empty-string case, which is what `Clip(mediaRef: "")` decodes to. Both \
            return at `resolveRef`'s own first `guard`, before any filesystem work.
            ⚠️ THE THIRD CASE — a non-empty path that does not exist — IS DELIBERATELY NOT \
            DRIVEN HERE. It reaches `MediaLibrary.directory(_:)`, which CREATES `Media/Audio`, \
            `Media/Video` and `Media/Image` in the App Group container as a side effect. A \
            guard that writes to the container to prove a read is a guard that will be \
            skipped on the day it matters (§1). Claim 13's nil-resolver covers the behaviour; \
            this pair covers the two cases that cost nothing.
            """)
    }

    // MARK: - 15. BEHAVIOUR — a LEGACY seconds trim that removes everything

    func testALegacySecondsTrimThatWindowsEveryNoteAwayCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip([Note(pitch: 60, startStep: 0)])
        // Tick twin 0 + seconds set = EXACTLY what a project saved before the M1b twin
        // existed decodes to. At 120 bpm, 1 s is two beats = 960 ticks, so the loader's
        // window is [960, 2880) and the note at tick 0 is not in it.
        // ⚠️ DERIVED, NOT READ OFF A RUN (#442): the first draft wrote 2.0 s beside the
        // comment "= 960 ticks" and the transcription caught it — 2 s is 1920, a whole bar,
        // and claim 16's note would then have sat outside its own window too.
        let legacy = TimelineRegion(laneID: midi.id, clipID: clip.id,
                                    startTick: 0, lengthTicks: Self.bar,
                                    contentOffsetSeconds: 1.0)
        let doc = TimelineDocument(lanes: [midi], regions: [legacy])
        XCTAssertFalse(Self.startable(doc, clips: [clip], bpm: 120), """
            ⛔ THE #1439 LEGACY-OFFSET BLOCKER. `loadClip` derives this region's offset as \
            `contentOffsetTicks > 0 ? ticks : offsetTicks(seconds, bpm)`; #1438's predicate \
            derived it as `stepAligned(contentOffsetTicks)` and nothing else — so the \
            predicate judged the window at 0 and the loader judged it at 960. Predicate-yes / \
            loader-nothing is a silent transport start, which is the exact defect Phase 4b \
            existed to close, surviving in the one branch nothing WRITES today but every \
            pre-M1b document still DECODES into (#527). Both sides now call \
            `RegionNoteWindow.effectiveOffsetTicks` — one derivation, no residual to argue \
            about, and the `bpm` argument is what makes the question answerable at all.
            """)
    }

    // MARK: - 16. COUNTERWEIGHT — a legacy trim that leaves content still plays

    func testALegacySecondsTrimThatLeavesANoteStillPlays() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip([Note(pitch: 60, startStep: 8)])   // tick 960
        let legacy = TimelineRegion(laneID: midi.id, clipID: clip.id,
                                    startTick: 0, lengthTicks: Self.bar,
                                    contentOffsetSeconds: 1.0)
        let doc = TimelineDocument(lanes: [midi], regions: [legacy])
        XCTAssertTrue(Self.startable(doc, clips: [clip], bpm: 120), """
            THE COUNTERWEIGHT TO 15 (#364). The cheap way to "close the legacy hole" is to \
            refuse every region carrying a seconds trim, and it would green claim 15 while \
            dimming Play over a song that plays perfectly. Same region, same tempo, one note \
            moved to where the window lands: the predicate must follow the OFFSET, not the \
            presence of the field.
            """)

        // …and the OTHER half of the one derivation: the offset is STEP-ALIGNED. 0.52 s at
        // 120 bpm is 499.2 → 499 ticks, which snaps down to 480; a note at 480 is inside the
        // aligned window and outside the raw one. The roll is a step-grid instrument, so the
        // loader snaps (`RegionNoteWindow.stepAligned`) and a predicate that skipped the snap
        // would dim Play over content the loader does play. A mutation run found this gap:
        // dropping the snap left every other claim here green.
        let offGrid = TimelineRegion(laneID: midi.id, clipID: clip.id,
                                     startTick: 0, lengthTicks: Self.bar,
                                     contentOffsetSeconds: 0.52)
        let snapped = Self.midiClip([Note(pitch: 60, startStep: 4)])   // tick 480
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [midi], regions: [offGrid]),
                                     clips: [snapped], bpm: 120), """
            The predicate must snap the window onto the 16th grid exactly as `loadClip` does. \
            Both halves of `effectiveOffsetTicks` are load-bearing: the tick-twin-else-seconds \
            choice AND the alignment. Skipping either is a third spelling of the rule.
            """)
    }

    // MARK: - 17. BEHAVIOUR — a region the transport never samples

    func testARegionBetweenTwoSampleTicksCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip()
        // One tick long, starting one tick after a grid line: internally full of content
        // (`windowed` keeps the note at 0 for a [0, 1) window) and invisible to the player.
        let sliver = TimelineRegion(laneID: midi.id, clipID: clip.id,
                                    startTick: Self.step + 1, lengthTicks: 1)
        let doc = TimelineDocument(lanes: [midi], regions: [sliver])
        XCTAssertFalse(Self.startable(doc, clips: [clip]), """
            ⛔ THE #1439 SCHEDULABILITY BLOCKER, and the only one of the three that is about \
            the ENGINE rather than the content. `laneEvent` compares `activeRegion` at two \
            GRID ticks, `TimelinePlaybackCursor.advance` only ever produces multiples of \
            `ticksPerTransportStep`, and this span contains none — so the player can never \
            look at it, however many notes it holds. `TimelineScheduling`'s header has said \
            so since P2; until #1439 no caller could ASK, and a limit only the author knows \
            about is not a limit the UI can be honest about.
            """)
    }

    // MARK: - 18. COUNTERWEIGHT — a region ON a sample tick is playable

    func testAOneTickRegionExactlyOnASampleTickPlays() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let clip = Self.midiClip()
        let onGrid = TimelineRegion(laneID: midi.id, clipID: clip.id,
                                    startTick: Self.step, lengthTicks: 1)
        let doc = TimelineDocument(lanes: [midi], regions: [onGrid])
        XCTAssertTrue(Self.startable(doc, clips: [clip]), """
            THE COUNTERWEIGHT TO 17 (#364). "Shorter than one step" is NOT the rule — the rule \
            is "contains no grid tick", and this one-tick region contains exactly one. A \
            length-based approximation would refuse it, which is a dimmed Play over a region \
            the scheduler really does enter. Every ordinary region is bar-aligned and this \
            gate is inert for them; it must stay inert.
            """)
    }

    // MARK: - 19. BEHAVIOUR — the sampling rule's edges, driven directly

    func testTheSchedulabilityRuleRespectsItsExclusiveEnd() {
        let lane = UUID(), clip = UUID()
        func span(_ start: Int, _ length: Int) -> TimelineRegion {
            TimelineRegion(laneID: lane, clipID: clip, startTick: start, lengthTicks: length)
        }
        // tick 0 is a grid tick, so the very first region of every song qualifies.
        XCTAssertTrue(TimelineScheduling.isSampleable(span(0, 1)))
        XCTAssertTrue(TimelineScheduling.isSampleable(span(0, Self.bar)))
        // Exactly ON the next grid line.
        XCTAssertTrue(TimelineScheduling.isSampleable(span(Self.step, 1)))
        // Beginning one tick AFTER a sample: the next one is a whole step away.
        XCTAssertFalse(TimelineScheduling.isSampleable(span(1, Self.step - 1)))
        XCTAssertTrue(TimelineScheduling.isSampleable(span(1, Self.step)))
        // ENDING exactly on the next sample — the case a half-open rule gets wrong when it
        // is rewritten as `<=`. The region does NOT own that tick; the next one does.
        XCTAssertFalse(TimelineScheduling.isSampleable(span(Self.step - 1, 1)), """
            `activeRegion` is `tick >= startTick && tick < endTick`, and `isSampleable` reuses \
            that containment rather than restating it. A region ending exactly on a grid tick \
            must NOT count it: if it did, two abutting regions would both claim the boundary \
            and the predicate would disagree with the scheduler at every join in the song — \
            the one place a timeline has the most of them.
            """)
        // A whole step between two grid lines, entirely inside them.
        XCTAssertFalse(TimelineScheduling.isSampleable(span(Self.step + 1, Self.step - 1)))
    }

    // MARK: - 20. BEHAVIOUR — an executable region the scheduler never SELECTS (#1440)

    func testARegionFullyShadowedByItsOverlapCannotPlay() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let good = Self.midiClip()
        // Two one-tick parts at tick 0. `activeRegion` breaks the equal-start tie toward the
        // LATER array element, so the dangling one owns the only grid tick either of them has.
        let executable = TimelineRegion(laneID: midi.id, clipID: good.id,
                                        startTick: 0, lengthTicks: 1)
        let dangling = TimelineRegion(laneID: midi.id, clipID: UUID(),
                                      startTick: 0, lengthTicks: 1)
        let doc = TimelineDocument(lanes: [midi], regions: [executable, dangling])
        XCTAssertFalse(Self.startable(doc, clips: [good]), """
            ⛔ THE #1440 BLOCKER, and the last of the four silent-clock escapes. #1439 asked \
            each region TWO independent questions — "does the grid land in you" and "do you \
            hold content" — and approved the song when ONE region answered both. The player \
            never asks a region anything: `laneEvent` loads whatever `activeRegion` RETURNS, \
            and `activeRegion` gives the tick to the latest-starting containing region, \
            breaking an equal start toward the one placed LATER. Here that is the dangling \
            part, at the only grid tick in the song, so Play starts a transport over nothing \
            — while a region full of notes sits underneath it, never loaded. Dropping a part \
            on top of another at the same bar is the everyday shape of this, not an exotic \
            one.
            """)

        // The same shadow, one step LATER in the song rather than at an equal start — the
        // other half of the precedence rule (latest START wins, ties aside).
        let laterStart = TimelineRegion(laneID: midi.id, clipID: good.id,
                                        startTick: Self.step, lengthTicks: Self.step)
        let laterShadow = TimelineRegion(laneID: midi.id, clipID: UUID(),
                                         startTick: Self.step, lengthTicks: 1)
        XCTAssertFalse(Self.startable(TimelineDocument(lanes: [midi],
                                                       regions: [laterStart, laterShadow]),
                                      clips: [good]), """
            `laterStart` owns exactly one grid tick and `laterShadow` takes it. A predicate \
            that read only the earliest region, or only the first in the array, would answer \
            the opposite — which is why claim 21 exists beside this one.
            """)

        // AUDIO behaves identically: the resolver is asked about the WINNER, not about the
        // region that happens to resolve.
        let audioLane = TimelineLane(name: "Audio 1", kind: .audio)
        let present = Clip(name: "Loop", kind: .audio, mediaRef: "loop.wav")
        let missing = Clip(name: "Gone", kind: .audio, mediaRef: "gone.wav")
        let ok = TimelineRegion(laneID: audioLane.id, clipID: present.id,
                                startTick: 0, lengthTicks: 1)
        let gone = TimelineRegion(laneID: audioLane.id, clipID: missing.id,
                                  startTick: 0, lengthTicks: 1)
        XCTAssertFalse(Self.startable(TimelineDocument(lanes: [audioLane],
                                                       regions: [ok, gone]),
                                      clips: [present, missing],
                                      resolveAudio: Self.resolving(present.id)), """
            The #1439 resolver truth and the #1440 precedence truth compose, and this is the \
            case that proves they were not fixed in isolation: the file that EXISTS belongs \
            to the region the scheduler will not select. Asking the resolver about the wrong \
            region is as wrong as not asking it at all.
            """)
    }

    // MARK: - 21. COUNTERWEIGHT — overlaps the scheduler DOES select still play (#364)

    func testOverlapsTheSchedulerSelectsAreStillPlayable() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let good = Self.midiClip()

        // (a) The WINNER is the executable one — the mirror image of claim 20's first case.
        let dangling = TimelineRegion(laneID: midi.id, clipID: UUID(),
                                      startTick: 0, lengthTicks: 1)
        let executable = TimelineRegion(laneID: midi.id, clipID: good.id,
                                        startTick: 0, lengthTicks: 1)
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [midi],
                                                      regions: [dangling, executable]),
                                     clips: [good]), """
            Identical geometry to claim 20, array order swapped. If the repair had been \
            "any overlap is unplayable" — the cheap way to green claim 20 — this would be \
            red, and every song where a user replaced a part by dropping a new one on top \
            would refuse to start. The rule is the SELECTOR, not the presence of an overlap.
            """)

        // (b) A shadow that LIFTS: the executable region outlives its shadow and owns a
        // later grid tick. One reachable tick is a playable song.
        let long = TimelineRegion(laneID: midi.id, clipID: good.id,
                                  startTick: 0, lengthTicks: 3 * Self.step)
        let brief = TimelineRegion(laneID: midi.id, clipID: UUID(),
                                   startTick: 0, lengthTicks: Self.step)
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [midi],
                                                      regions: [long, brief]),
                                     clips: [good]), """
            `brief` wins tick 0 and ends before tick 120, so `long` owns the rest. A \
            predicate that judged only the FIRST candidate tick — the obvious \
            implementation, and one step short of correct — would refuse this. The question \
            is whether ANY sample tick selects executable content, not the first one.
            """)

        // (c) A later-STARTING executable region rescues an earlier dangling one.
        let earlierGone = TimelineRegion(laneID: midi.id, clipID: UUID(),
                                         startTick: 0, lengthTicks: 2 * Self.step)
        let laterGood = TimelineRegion(laneID: midi.id, clipID: good.id,
                                       startTick: Self.step, lengthTicks: Self.step)
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [midi],
                                                      regions: [earlierGone, laterGood]),
                                     clips: [good]), """
            Latest start wins, so the good part takes tick 120 from the dangling one that \
            spans it. This is the ordinary "punch a new part over the middle of an old one" \
            edit and it must stay startable.
            """)
    }

    // MARK: - 22. COUNTERWEIGHT — lanes are scheduled independently (§7)

    func testOverlapsOnDifferentLanesStayIndependent() {
        let one = TimelineLane(name: "MIDI 1", kind: .midi)
        let two = TimelineLane(name: "MIDI 2", kind: .midi)
        let good = Self.midiClip()

        // A dangling part on ANOTHER lane must not shadow an executable one.
        let executable = TimelineRegion(laneID: one.id, clipID: good.id,
                                        startTick: 0, lengthTicks: 1)
        let elsewhere = TimelineRegion(laneID: two.id, clipID: UUID(),
                                       startTick: 0, lengthTicks: 1)
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [one, two],
                                                      regions: [executable, elsewhere]),
                                     clips: [good]), """
            `TimelineScheduling.activeRegion` filters by `laneID` before it picks a winner, \
            so lanes cannot shadow each other at runtime and must not here. The tempting \
            implementation — one global winner per tick — is red on this claim, and it would \
            dim Play on any multi-lane song with a stale part anywhere in it.
            """)

        // …and a lane that is wholly shadowed does not poison a lane that plays.
        let shadowed = TimelineRegion(laneID: one.id, clipID: good.id,
                                      startTick: 0, lengthTicks: 1)
        let shadow = TimelineRegion(laneID: one.id, clipID: UUID(),
                                    startTick: 0, lengthTicks: 1)
        let plain = TimelineRegion(laneID: two.id, clipID: good.id,
                                   startTick: 0, lengthTicks: Self.bar)
        XCTAssertTrue(Self.startable(TimelineDocument(lanes: [one, two],
                                                      regions: [shadowed, shadow, plain]),
                                     clips: [good]), """
            Lane 1 is exactly claim 20 and contributes nothing; lane 2 plays. ONE executable \
            winning lane is a startable song — the predicate asks for an existence, not for \
            every lane to qualify.
            """)
    }

    // MARK: - 23. BEHAVIOUR — the candidate tick set is SOUND and COMPLETE (#1440)

    func testTheCandidateTicksAreSoundAndCompleteAgainstAFullGridScan() {
        let lane = UUID()
        func span(_ start: Int, _ length: Int) -> TimelineRegion {
            TimelineRegion(laneID: lane, clipID: UUID(), startTick: start, lengthTicks: length)
        }
        // SOUND: every emitted tick lies INSIDE a region on the lane. This is the one thing
        // `isSampleable` decides inside the enumeration that a caller can observe — drop it
        // and the sliver below contributes tick 240, which no region owns. `activeRegion`
        // re-checks containment, so no VERDICT would change; the set would just stop meaning
        // what its name says, and the next reader would build on a false description.
        let sliverAndBar = TimelineDocument(
            lanes: [], regions: [span(Self.step + 1, 1), span(4 * Self.step, 4 * Self.step)])
        for tick in TimelineScheduling.candidateSampleTicks(in: sliverAndBar, laneID: lane) {
            XCTAssertTrue(sliverAndBar.regions.contains { tick >= $0.startTick && tick < $0.endTick },
                          """
                          Candidate tick \(tick) lies in no region on this lane. Every \
                          emitted tick must be one some region actually owns — that is what \
                          `isSampleable` is doing inside `candidateSampleTicks`, and it is \
                          invisible in any verdict because `activeRegion` filters again.
                          """)
        }
        // A region ending exactly ON a grid tick owns none: the same exclusive end claim 19
        // drives directly, observed here through the enumeration.
        let endsOnGrid = TimelineDocument(lanes: [], regions: [span(Self.step - 1, 1)])
        XCTAssertEqual(TimelineScheduling.candidateSampleTicks(in: endsOnGrid, laneID: lane), [],
                       """
                       `[119, 120)` contains no grid tick — 120 belongs to whatever starts \
                       there. An inclusive end here would emit 120 and describe a tick this \
                       region does not own.
                       """)

        // COMPLETE: over a spread of overlapping geometries, the bounded candidate set finds
        // the same winners a FULL grid sweep finds. The set is O(regions); the sweep is O(song
        // length) and is here only as the oracle — it must never become the implementation
        // (§6: no per-tick brute force in the app).
        let geometries: [[TimelineRegion]] = [
            [span(0, Self.bar)],
            [span(0, 1), span(0, 1)],
            [span(0, 3 * Self.step), span(0, Self.step)],
            [span(0, 2 * Self.step), span(Self.step, Self.step)],
            [span(0, 4 * Self.step), span(0, Self.step), span(Self.step, Self.step)],
            [span(1, Self.step - 1), span(0, 2 * Self.step)],
            [span(Self.step + 1, 1), span(0, 4 * Self.step)],
            [span(Self.step - 1, 1), span(240, 240)],
            [span(0, Self.bar), span(60, 60), span(300, 1), span(480, 2 * Self.step)],
        ]
        for regions in geometries {
            let doc = TimelineDocument(lanes: [], regions: regions)
            let candidates = Set(TimelineScheduling.candidateSampleTicks(in: doc, laneID: lane))
            let horizon = (regions.map(\.endTick).max() ?? 0) + 2 * Self.step
            var sweptWinners = Set<UUID>()
            var tick = 0
            while tick <= horizon {
                if let r = TimelineScheduling.activeRegion(in: doc, laneID: lane, at: tick) {
                    sweptWinners.insert(r.id)
                }
                tick += Self.step
            }
            var candidateWinners = Set<UUID>()
            for t in candidates {
                if let r = TimelineScheduling.activeRegion(in: doc, laneID: lane, at: t) {
                    candidateWinners.insert(r.id)
                }
            }
            XCTAssertEqual(candidateWinners, sweptWinners, """
                The bounded candidate set must select the SAME regions a full grid sweep \
                selects. A missing boundary would hide a region that really does win a tick \
                — the predicate would then refuse a song that plays, which is #364 in the \
                direction nobody notices. Geometry: \
                \(regions.map { "[\($0.startTick),\($0.endTick))" }.joined(separator: " "))
                """)
        }
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
        XCTAssertEqual(reached, ["play", "stop", "isPlaying", "preflightTempo", "audioLanes",
                                 "laneVoiceCapacity"], """
            The surface reaches the player for \(reached.sorted()). Phase 4 authorised a \
            transport, not an editor: `relocate`, `launchRegion`, `loopEnabled` and the sinks \
            are all one tap away and all out of bounds here.
            ⚠️ #1439 ADDED TWO, AND BOTH ARE READ-ONLY AND `@ObservationIgnored` — that is why \
            they are allowed and why the pair is spelled out rather than the set loosened. \
            `preflightTempo` is the tempo the Play predicate judges a legacy region at; \
            `audioLanes` is reached ONLY to borrow its resolver. Neither is written here, and \
            neither subscribes this body to anything. A third addition needs the same two \
            properties argued, not this list widened by habit.
            ⚠️ WA4 path 6 ARGUED THE THIRD: `laneVoiceCapacity` is a read-only computed view of \
            `@ObservationIgnored private var multiRollCapacity`, set once at start. The track \
            header asks it — through `TrackMix.controls`, the inspector's own rule — so Mute \
            and Solo appear only on a track that has a voice to silence.
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
            engine.contains("guard Self.canPlay(document, clips: clips.filledClips, bpm: pattern.tempo,"),
            """
            `play(...)` must be gated by `canPlay` itself, not by a copy of its conditions, \
            and it must hand over the SAME inputs the control did — the clip values, the live \
            tempo, and a resolver. Two spellings of one threshold is the defect whether or not \
            they agree today (#416), and here disagreement has a specific shape: an enabled \
            button whose tap silently does nothing, or a dimmed button over a song that would \
            have played.
            """)
        let src = try code(at: Self.view)
        guard let ask = src.range(of: "TimelineRegionPlayer.canPlay(") else {
            throw AnchorMissing(reason: """
                `WorkstationView` no longer asks `TimelineRegionPlayer.canPlay(`. The control \
                must ask the ENGINE, not a lookalike computed from the summary — re-anchor if \
                it was renamed; if it is gone, say so loudly rather than skip.
                """)
        }
        let handed = String(src[ask.upperBound...].prefix(300))
        for argument in ["timeline.document", "clips: clipStore.filledClips",
                        "bpm: player.preflightTempo", "resolveAudio:"] {
            XCTAssertTrue(handed.contains(argument), """
                The control's `canPlay` call omits `\(argument)`. Every one of the four is a \
                PART OF THE QUESTION, learned the expensive way: #1437 asked with the document \
                alone and both sides were blind in the same way (the worst kind of agreement — \
                one definition, uniformly wrong); #1438 added the clips and still decided audio \
                from a string and legacy MIDI at the wrong offset. A missing argument here is a \
                predicate that cannot see what the engine will.
                """)
        }
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


    // MARK: - K. COUNTERWEIGHT — ONE derivation of a region's content offset (§4, §7)

    func testTheLoaderAndThePredicateDeriveOneOffset() throws {
        let engine = try code(at: Self.player)
        // Name-anchored rather than counted (#903/#408): a count pin goes stale the day a
        // legitimate fourth consumer appears, and says nothing about WHICH sites comply.
        for (anchor, who) in [("private func loadClip(", "the primary roll loader"),
                              ("private func windowedBars(", "the secondary-lane loader"),
                              ("static func executableNotes(", "the Play predicate")] {
            guard let head = engine.range(of: anchor),
                  let close = engine.range(of: "\n    }\n",
                                           range: head.upperBound..<engine.endIndex)
            else { throw AnchorMissing(reason: "`\(anchor)` could not be delimited — re-anchor.") }
            XCTAssertTrue(String(engine[head.upperBound..<close.lowerBound])
                .contains("RegionNoteWindow.effectiveOffsetTicks("), """
                \(who) derives a region's content offset without the ONE helper. All three \
                must call it: the rule was written three times before #1439 and the third \
                spelling was DIFFERENT, so a legacy seconds-trimmed region enabled Play and \
                then loaded silence. Two spellings of one decision is the defect whether or \
                not they agree today (#416).
                """)
        }
        for inlineSpelling in ["contentOffsetTicks > 0",
                               "contentOffsetSeconds: region.contentOffsetSeconds"] {
            XCTAssertFalse(engine.contains(inlineSpelling), """
                `TimelineRegionPlayer` spells the offset rule out inline \
                (`\(inlineSpelling)`). That rule lives in \
                `RegionNoteWindow.effectiveOffsetTicks` and nowhere else.
                """)
        }
        var declarations: [String] = []
        for (path, source) in try Self.allSources()
        where source.contains("func effectiveOffsetTicks(") { declarations.append(path) }
        XCTAssertEqual(declarations.sorted(), ["Sequencer/RegionNoteWindow.swift"], """
            The offset derivation must be declared once, in the pure windowing core that also \
            owns `windowed`, `stepAligned` and the seconds conversion it composes. Found: \
            \(declarations.sorted()).
            """)
    }

    // MARK: - L. COUNTERWEIGHT — audio is decided by the RESOLVER, not by a string (§2, §3)

    func testTheAudioBranchAsksTheRealResolver() throws {
        let engine = try code(at: Self.player)
        XCTAssertTrue(engine.contains("resolveAudio(region.clipID) != nil"), """
            The audio branch must ASK the injected resolver. `AudioLanePlayer` decides every \
            audio region with `guard let url = self.resolveURL(region.clipID)`; the predicate \
            asking anything else is a second definition (§2) and, as #1438 proved, a weaker \
            one — a non-empty `mediaRef` is a string, not a file.
            """)
        XCTAssertFalse(engine.contains("mediaRef"), """
            `TimelineRegionPlayer` must not read `mediaRef` at all. Reading it is how the \
            predicate came to believe a deleted recording was playable; the clip's media slot \
            is the RESOLVER's input, not the predicate's evidence.
            """)
        let lanes = try code(at: Self.lanes)
        XCTAssertTrue(lanes.contains("public func resolvedURL(forClipID id: UUID) -> URL? { resolveURL(id) }"), """
            The accessor must FORWARD the stored closure verbatim. The moment it does anything \
            else — a cache, a normalisation, a fallback — the preflight and the streaming path \
            have two answers again, and the one on screen is the one nobody drives (§7).
            """)
        XCTAssertTrue(lanes.contains("private let resolveURL: (UUID) -> URL?"), """
            …and the closure itself stays private: one accessor, one forwarder. A public \
            stored closure invites a second injection point.
            """)
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains("resolveAudio: { player.audioLanes?.resolvedURL(forClipID: $0) }"), """
            The control must hand over the PLAYER'S OWN resolver, so the question the button \
            asks is the question `prime`/`apply` will ask. A view-local `MediaLibrary` call \
            would compile, agree today, and be the thing that drifts.
            ⚠️ `audioLanes` is nil until the app wires it, and a nil resolver refusing every \
            audio region is correct: unwired means unplayable.
            """)
    }

    // MARK: - M. COUNTERWEIGHT — the scheduler's grid is asked, and its end stays exclusive

    func testThePredicateAsksWhetherTheSchedulerCanReachTheRegion() throws {
        let sched = try code(at: Self.scheduling)
        XCTAssertTrue(sched.contains("if isSampleable(region) {"), """
            The schedulability question must still be ASKED — a sliver between two grid ticks \
            must not contribute a candidate tick, or the set stops describing ticks any \
            region owns. ⚠️ THE CALLER MOVED IN #1440, THE QUESTION DID NOT: until then this \
            needle read `TimelineScheduling.isSampleable(region)` in the PLAYER, because \
            `firstExecutableRegion` filtered regions one by one. It now walks the scheduler \
            instead, so the gate lives inside `candidateSampleTicks` — one file further down, \
            same rule. A needle left on the old address would have gone red on a correct tree \
            (#1092), which is the failure this bundle has paid for four times.
            """)
        guard let head = sched.range(of: "static func isSampleable("),
              let close = sched.range(of: "\n    }\n", range: head.upperBound..<sched.endIndex)
        else { throw AnchorMissing(reason: "`isSampleable` could not be delimited — re-anchor.") }
        let body = String(sched[head.upperBound..<close.lowerBound])
        XCTAssertTrue(body.contains("t < region.endTick"), """
            The end must stay EXCLUSIVE, in the same spelling `activeRegion` uses. `<=` here \
            would let a region claim the grid tick that belongs to the one after it, and the \
            predicate would then disagree with the scheduler at every join in the song.
            """)
        XCTAssertTrue(body.contains("t >= region.startTick"), """
            …and the start stays INCLUSIVE. Dropping this half looks harmless because \
            `firstSampleTick` already rounds up — until someone changes the rounding, at \
            which point the containment test is the only thing left saying what a region owns.
            """)
        var declarations: [String] = []
        for (path, source) in try Self.allSources()
        where source.contains("func isSampleable(") { declarations.append(path) }
        XCTAssertEqual(declarations.sorted(), ["Sequencer/TimelineScheduling.swift"], """
            The schedulability rule belongs to the file that owns `activeRegion` and the \
            grid, and must exist once. Found: \(declarations.sorted()).
            """)
    }

    // MARK: - N. COUNTERWEIGHT — the preflight tempo has exactly one writer, and is cold

    func testThePreflightTempoIsPushedOnceAndReadFree() throws {
        var writers: [String] = []
        for (path, source) in try Self.allSources()
        where source.contains("preflightTempo = ") { writers.append(path) }
        XCTAssertEqual(writers.sorted(), ["EchoelmusicApp.swift"], """
            `preflightTempo` mirrors the one tempo authority and must have exactly ONE writer. \
            `Transport.setTempo` re-notifies only on a real MOVE — its own comment says a \
            drifted subscriber never self-heals — so a second writer would leave the Play \
            predicate judging legacy regions at a tempo nothing is playing at. Found: \
            \(writers.sorted()).
            """)
        let app = try code(at: Self.app)
        XCTAssertTrue(app.contains("transport.onTempoChange(id: \"timeline.preflight\")"), """
            The mirror must be fed from `Transport`'s tempo broadcast — the same channel the \
            click uses, which seeds itself with the current tempo on registration. Without \
            this line the predicate judges every legacy region at the default tempo forever.
            """)
        let engine = try code(at: Self.player)
        XCTAssertTrue(engine.contains("@ObservationIgnored public var preflightTempo"), """
            It must stay `@ObservationIgnored`. That attribute is the entire reason the \
            Workstation can read a live tempo in `body`: `PatternEngine.tempo` and \
            `Transport.tempo` are both observed, and this plate is evaluated inside the ROOT \
            body since #479 — so an observed read here rebuilds the whole Studio at glide \
            rate and tears down any open `.menu` Picker (10.76.41/50).
            """)
        let src = try code(at: Self.view)
        XCTAssertFalse(src.contains(".tempo"), """
            `WorkstationView` must not read a tempo property. The file's own header names \
            `beatPlayer.pattern` as the thing it must never touch in `body`; the preflight \
            mirror exists so it does not have to.
            """)
    }

    // MARK: - O. COUNTERWEIGHT — the preflight ASKS the selector, it does not re-derive it

    func testThePreflightAsksTheSchedulerWhoWins() throws {
        let engine = try code(at: Self.player)
        guard let head = engine.range(of: "static func firstExecutableRegion("),
              let close = engine.range(of: "\n    }\n", range: head.upperBound..<engine.endIndex)
        else { throw AnchorMissing(reason: "`firstExecutableRegion` could not be delimited — re-anchor.") }
        let body = String(engine[head.upperBound..<close.lowerBound])

        XCTAssertTrue(body.contains("TimelineScheduling.candidateSampleTicks(in: document, laneID: lane.id)"), """
            The preflight must walk the scheduler's own decision set. Judging regions one by \
            one — the #1439 shape — approves a song whose only executable part is shadowed by \
            an overlapping neighbour at every grid tick it owns (claim 20).
            """)
        XCTAssertTrue(body.contains("TimelineScheduling.activeRegion(in: document,"), """
            …and it must ask who WINS each of those ticks. `activeRegion` is the one place \
            overlap precedence is defined; a preflight that picks its own winner is a second \
            definition of the rule that decides what the user hears (§2, #416).
            """)
        XCTAssertTrue(body.contains("for lane in document.lanes where !lane.isBio"), """
            Lane by lane, because `activeRegion` filters by `laneID` before it picks. A \
            single global winner per tick would let a stale part on one lane dim Play for a \
            song that plays on another (claim 22).
            """)
        for vocabulary in ["startTick", "endTick", "max(by:", ".sorted"] {
            XCTAssertFalse(body.contains(vocabulary), """
                `firstExecutableRegion` must not contain the token `\(vocabulary)`. Ordering, \
                containment and the equal-start tie-break belong to `TimelineScheduling`; the \
                moment the predicate spells any of them itself, the two can disagree — and \
                the disagreement is invisible until a user drops one part on top of another.
                """)
        }

        let sched = try code(at: Self.scheduling)
        XCTAssertTrue(sched.contains("($0.element.startTick, $0.offset) < ($1.element.startTick, $1.offset)"), """
            THE PRECEDENCE RULE ITSELF, pinned where it lives: the lexicographic maximum over \
            `(startTick, position)` is what makes the LATEST-STARTING region win and breaks an \
            equal start toward the one placed LATER. Claims 20–22 are written against exactly \
            this rule; if it is ever changed deliberately, they change with it in the same \
            commit rather than going quietly wrong.
            """)
        var declarations: [String] = []
        for (path, source) in try Self.allSources()
        where source.contains("func candidateSampleTicks(") { declarations.append(path) }
        XCTAssertEqual(declarations.sorted(), ["Sequencer/TimelineScheduling.swift"], """
            The candidate-tick enumeration belongs to the file that owns `activeRegion` and \
            the grid, and must exist once. Found: \(declarations.sorted()).
            """)
        XCTAssertFalse(engine.contains("func candidateSampleTicks("), """
            …and the player must not grow its own copy. A second enumeration is a second \
            answer to "where can the winner change", which is the whole defect #1440 closed.
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
