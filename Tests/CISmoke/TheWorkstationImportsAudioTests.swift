// TheWorkstationImportsAudioTests.swift
// Echoel — Audio Import V1 (founder 2026-09-22). The first REACHABLE producer of an
// audio-bearing region, and the guard over what it is allowed to be.
//
// WHAT CHANGED. `AudioLanePlayer` has been constructed by `EchoelmusicApp` and driven by
// `TimelineRegionPlayer` on every prime/apply/stop since v191; `TimelineAudioSink` is
// injected into it; `#1438` corrected `ClipKind.timelineEngineKinds` to `[.midi, .audio]`
// because the ENGINE was shipped. What was missing for four months was a PRODUCER — the one
// type that mints an audio-bearing clip, `AudioClipFactory`, had exactly one caller
// (`TakeRecorder`), reached only from `RecordController.arm()`, which has zero callers
// (#204/#527). `Sequencer/AudioImport.swift` is the second caller and the first with a door.
//
// ⚠️ THE LIMIT, FIRST (§1). Most of this file is END-TO-END BEHAVIOUR: `AudioImport.plan`,
// `validate`, `firstImportableAudioLane`, `successNote`, `AudioClipFactory.coveringBars`,
// `MediaLibrary.resolveRef` and `TimelineRegionPlayer.canPlay` are all shipped, `public` or
// `@testable`-reachable, Foundation-only value code, driven here on real values. The claims
// that are SOURCE-TEXT SCANS say so in their own doc — named rather than counted a second
// time (#416/#818): `testTheImportIntroducesNoPersistenceRoot`,
// `testNoMediaAssetIdentityWasIntroduced`, `testTheImportPathCarriesNoInputOrRecordingCode`,
// `testTheWorkstationIsTheOnlyImportDoor`, `testNoFileImporterSitsAboveTheImportDoor` (#W1)
// and `testTheClipIsCommittedBeforeTheRegionAndOnlyOnSuccess`. NOTHING here is a DEVICE PROBE: no file picker
// runs, no security-scoped URL is acquired, no audio decodes, no sound is made. That the
// door is tappable and that an imported file is AUDIBLE are both open and registered.
//
// ⚠️ WHY THE STORES ARE BARELY TOUCHED, and it is not squeamishness. `ClipStore` and
// `TimelineStore` persist into the App Group on EVERY write, so a test that drove the
// SUCCESS path through `commit` would leave a clip and a region in the running app's own
// saved song. Every guard in `TheWorkstationPlaysTheTimelineTests` drives pure statics over
// `TimelineDocument`/`[Clip]` values for exactly that reason, and this file follows it:
// `AudioImport.plan` is the seam where every decision lives, and it is a pure function of
// values. The ONE claim that constructs the real stores drives a failure that `plan` reaches
// BEFORE either store is consulted (an unreadable measurement is rejected first), so no
// write is possible on a correct tree — and it snapshots both stores either side to say so.
//
// ⚠️ HONEST GRADING (#433/#464/#486). This file names `AudioImport`, a type this same commit
// creates, so it DOES NOT COMPILE against the parent tree: **no assertion has a verdict
// there**, and none of them may be booked as a regression. They were graded instead by
// transcription (§0) — a Python rebuild of `plan`/`validate`/`coveringBars`/`nextStartTick`
// and of `SourceText.codeOnly`, driven against the worktree. The five scan claims would have
// a verdict on the parent and are red there by ANCHOR ABSENCE — one absence (the importer
// file), reported several times, which is ONE finding (#486). The counterweights below (the recorder
// chain, the bio-lane exclusion, the missing-media survival) are green on both trees where
// they can run at all, and they are the content (#343).
//
// ⚠️ AND WHAT THIS FILE MUST NOT BECOME. It does not forbid a second import door, a lane
// creator, or a media-asset identity (#364) — all three are wanted work. What it forbids is
// landing any of them while the prose still counts one door and zero asset types. When a
// claim here goes red for that reason, the repair is to move the register line in CLAUDE.md
// and the ⛔ block in `AudioLanePlayer.swift` in the SAME commit, never to relax the claim.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheWorkstationImportsAudioTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let importer = "Sources/Echoelmusic/Sequencer/AudioImport.swift"
    private static let door = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    /// 120 bpm — the transport default, so a bar is exactly 2 s and every span below is
    /// arithmetic a reader can check without running anything (#442).
    private static let bpm = 120.0

    // MARK: - Fixtures

    /// A song shaped like the one the founder's decision 4 describes: a MIDI lane, a BIO
    /// audio lane that must be skipped, then the real audio lane, then a second one.
    private func song() -> (document: TimelineDocument,
                            midi: TimelineLane, bio: TimelineLane,
                            audio: TimelineLane, second: TimelineLane) {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let bio = TimelineLane(name: "Bio", kind: .audio, isBio: true)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let second = TimelineLane(name: "Audio 2", kind: .audio)
        return (TimelineDocument(lanes: [midi, bio, audio, second]), midi, bio, audio, second)
    }

    /// A measurement of something schedulable: 5 s of 44.1 kHz stereo. 5 s at 120 bpm is
    /// 2,5 bars, which is the interesting case — see `testTheSpanCoversTheMediaRatherThanRoundingIntoIt`.
    private func fiveSeconds() -> AudioImport.Measurement {
        AudioImport.Measurement(sampleRate: 44_100, frameCount: 220_500, channelCount: 2)
    }

    /// A real file in the temp directory, so `MediaLibrary.resolveRef` has something to
    /// resolve and something to fail to resolve once it is removed. NOTHING is written into
    /// the App Group or into `Media/Audio`: these claims are about the RESOLVER's answer to
    /// a path, not about the copy step, which is injected everywhere it appears.
    private func temporaryMedia(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-import-guard-\(UUID().uuidString)-\(name)")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url)
        return url
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 1…5 What a successful import produces

    /// CLAIM 1 + 2 + 4 + 5 — readable managed audio yields ONE clip and ONE region, the clip
    /// is `.audio`, its native duration is finite and positive, and its `nativeBPM` is 0.
    ///
    /// The four are asserted together because they are four properties of ONE landing, and
    /// splitting them would re-run the same call four times to read four fields of the same
    /// value. Each carries its own message.
    func testAReadableImportProducesOneAudioClipAndOneRegion() throws {
        let media = try temporaryMedia("landing.wav")
        defer { remove(media) }
        let world = song()

        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: world.document, freeSlotIndex: 0, bpm: Self.bpm)))

        XCTAssertEqual(landing.clip.kind, .audio, """
            The import produced a clip of kind \(landing.clip.kind) rather than `.audio`. \
            `AudioLanePlayer` is LANE-driven, so a mislabelled clip would still resolve — \
            but `TimelineRegionPlayer.isExecutable` and every surface that reads `kind` \
            would disagree with the engine about what this is.
            """)

        let duration = try XCTUnwrap(landing.clip.nativeDurationSeconds, """
            The clip carries no `nativeDurationSeconds`. It is the ONLY record of how long \
            the media is once the file itself is out of reach, and the region's span was \
            derived from it — dropping it makes the span unexplainable.
            """)
        XCTAssertTrue(duration.isFinite && duration > 0, """
            `nativeDurationSeconds` is \(duration) — not a finite positive length. \
            220 500 frames at 44 100 Hz is exactly 5 s; a NaN or a zero here means the \
            measurement reached the clip without passing `AudioImport.validate`.
            """)
        XCTAssertEqual(duration, 5.0, accuracy: 1e-9, """
            The measured duration is \(duration), not 5 s. `Measurement.durationSeconds` is \
            COMPUTED from frames ÷ rate (#416) precisely so it cannot drift from its inputs; \
            a different answer means a third, stored number has been introduced.
            """)

        XCTAssertEqual(landing.clip.nativeBPM, 0, """
            `nativeBPM` is \(landing.clip.nativeBPM), not 0 AT THE LANDING. The tempo is \
            estimated — founder 2026-09-23 lifted decision 7 — but NOT here: `plan` is pure \
            and the transaction is synchronous and `@MainActor`, while the estimate is seconds \
            of work. It runs afterwards from the door, off the main actor, and a KNOWN result \
            is adopted through `ClipStore.adoptDetectedNativeBPM` (#B2, pinned by \
            `TheDetectedTempoIsHonestTests`). A tempo appearing HERE would be a guess made \
            without the audio — `AudioClipFactory.nativeBPM` derives one from the file's \
            length alone. `AudioClipFactory.clip` must keep NOT passing `nativeBPM:`.
            """)

        XCTAssertEqual(landing.region.clipID, landing.clip.id, """
            The region points at \(landing.region.clipID) while the clip is \
            \(landing.clip.id). Playback resolves `TimelineRegion.clipID` THROUGH \
            `ClipStore`; a mismatch is a dangling pointer the moment it persists.
            """)
        XCTAssertEqual(landing.region.laneID, world.audio.id, """
            The region landed on \(landing.region.laneID) rather than the first non-bio \
            audio lane — see `testThePlacementSkipsTheBioLaneAndTakesTheFirstAudioOne`.
            """)
    }

    /// CLAIM 3 — the clip's `mediaRef` is the MANAGED copy, and `MediaLibrary.resolveRef`
    /// (the ONE resolver every playback surface uses) finds it.
    ///
    /// END-TO-END: it asks the shipped resolver rather than comparing two strings, because
    /// "the ref equals the path we passed" would stay green if the resolver's conventions
    /// ever changed underneath it.
    func testTheClipRefersToTheManagedCopyAndTheResolverFindsIt() throws {
        let media = try temporaryMedia("managed.wav")
        defer { remove(media) }
        let world = song()

        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: world.document, freeSlotIndex: 3, bpm: Self.bpm)))

        XCTAssertEqual(landing.clip.mediaRef, media.path, """
            `mediaRef` is \(landing.clip.mediaRef ?? "nil") rather than the managed copy's \
            absolute path. `AudioClipFactory.clip`'s own doc states the convention and why: \
            the resolver is `URL(fileURLWithPath:)` + `fileExists`, so a relative or \
            last-component ref would resolve only by accident.
            """)

        let resolved = MediaLibrary.resolveRef(landing.clip.mediaRef)
        XCTAssertEqual(resolved?.path, media.path, """
            `MediaLibrary.resolveRef` returned \(resolved?.path ?? "nil") for the ref this \
            import just wrote. That resolver is what `AudioLanePlayer`'s injected \
            `resolveURL` calls at all three prime/step/stop sites — if it cannot answer for \
            a freshly imported clip, the region persists and never plays.
            """)

        XCTAssertEqual(landing.slotIndex, 3, """
            The landing reports slot \(landing.slotIndex) rather than the free slot it was \
            handed. The slot is not chosen here: `ClipStore.firstEmptySlotIndex` chooses it \
            and `plan` carries it, so that `commit` writes where the store said it could.
            """)
    }

    // MARK: - 6…7 Where it lands

    /// CLAIM 6 — placement targets the FIRST existing audio lane, and a BIO audio lane is
    /// not one of them.
    ///
    /// ⚠️ THE `!isBio` HALF IS NOT AN ADDITION TO THE FOUNDER'S DECISION, IT IS WHAT MAKES IT
    /// TRUE (#416). `TimelineDocument.audioLaneIDs` — what `AudioLanePlayer.prime`/`apply`
    /// actually walk — is `kind == .audio && !isBio`. A region placed on a bio audio lane
    /// would persist somewhere the transport refuses to look: a control that lies.
    func testThePlacementSkipsTheBioLaneAndTakesTheFirstAudioOne() throws {
        let media = try temporaryMedia("lane.wav")
        defer { remove(media) }
        let world = song()

        let chosen = try XCTUnwrap(AudioImport.firstImportableAudioLane(in: world.document), """
            No importable audio lane found in a document that has two. The predicate must \
            stay `audioLaneIDs`' own.
            """)
        XCTAssertEqual(chosen.id, world.audio.id, """
            The import chose lane "\(chosen.name)". The bio lane is `.audio` by kind and is \
            still not a landing site; the second audio lane is a landing site and is not the \
            FIRST one.
            """)
        XCTAssertTrue(world.document.audioLaneIDs.contains(chosen.id), """
            The chosen lane is not in `audioLaneIDs`, so the transport would never walk it. \
            The two predicates have drifted apart — there must be exactly one.
            """)

        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: world.document, freeSlotIndex: 0, bpm: Self.bpm)))
        XCTAssertEqual(landing.region.laneID, world.audio.id, """
            `plan` placed the region on a different lane than \
            `firstImportableAudioLane` names. Those two answers must be the same answer.
            """)

        // COUNTERWEIGHT (#343): a song whose ONLY audio lane is a bio lane has nowhere to
        // land, and must say so rather than using it.
        let bioOnly = TimelineDocument(lanes: [world.midi, world.bio])
        XCTAssertNil(AudioImport.firstImportableAudioLane(in: bioOnly), """
            A document whose only `.audio` lane is the BIO lane offered it as an import \
            target. That region would be persisted onto a lane `audioLaneIDs` excludes.
            """)
    }

    /// CLAIM 7 + 11 — placement uses `TimelineDocument.nextStartTick(inLane:)`, so a second
    /// import appends after the first instead of stacking on top of it.
    ///
    /// Driven as the user would reach it: plan once, fold the region into the document, plan
    /// again. That is the ONLY way to test "repeated imports append" without a second clock.
    func testRepeatedImportsAppendThroughTheExistingPlacementRule() throws {
        let first = try temporaryMedia("first.wav")
        let second = try temporaryMedia("second.wav")
        defer { remove(first); remove(second) }
        var world = song().document
        let lane = try XCTUnwrap(AudioImport.firstImportableAudioLane(in: world))

        let one = try XCTUnwrap(try success(
            AudioImport.plan(managed: first, measurement: fiveSeconds(),
                             document: world, freeSlotIndex: 0, bpm: Self.bpm)))
        XCTAssertEqual(one.region.startTick, 0, """
            The first import on an empty lane started at tick \(one.region.startTick) \
            rather than 0. `nextStartTick` is `max(endTick) ?? 0` — a non-zero answer on an \
            empty lane means the placement is no longer asking it.
            """)

        world.regions.append(one.region)
        let two = try XCTUnwrap(try success(
            AudioImport.plan(managed: second, measurement: fiveSeconds(),
                             document: world, freeSlotIndex: 1, bpm: Self.bpm)))

        XCTAssertEqual(two.region.startTick, world.nextStartTick(inLane: lane.id), """
            The second import started at \(two.region.startTick) while \
            `nextStartTick(inLane:)` says \(world.nextStartTick(inLane: lane.id)). The \
            placement must ASK that function, not re-derive an answer beside it (#416).
            """)
        XCTAssertEqual(two.region.startTick, one.region.endTick, """
            The second region starts at \(two.region.startTick) and the first ends at \
            \(one.region.endTick). Overlapping them is not merely untidy: \
            `TimelineScheduling.activeRegion` gives every shared tick to the LATER region, \
            so an import dropped on top of an earlier one silences it (#1440).
            """)
        XCTAssertNotEqual(one.clip.id, two.clip.id, """
            Two imports produced the same clip id. `ClipStore` is positional and its slots \
            are not uniqued, so a duplicate id makes `clip(id:)` answer for the wrong file.
            """)
    }

    /// COUNTERWEIGHT — the span COVERS the media rather than rounding into it.
    ///
    /// This is the reason `AudioClipFactory.unwarpedRegion` exists beside `region(…)`: the
    /// older one derives bars from a KNOWN `nativeBPM` and rounds to the NEAREST bar, which
    /// is right for a well-cut loop and wrong for an unwarped import, where rounding down
    /// truncates the tail. 5 s at 120 bpm is 2,5 bars; nearest gives 2 and loses a second.
    func testTheSpanCoversTheMediaRatherThanRoundingIntoIt() throws {
        XCTAssertEqual(AudioClipFactory.coveringBars(forDurationSeconds: 5, bpm: Self.bpm), 3, """
            5 s at 120 bpm is 2,5 bars and the covering span is \
            \(AudioClipFactory.coveringBars(forDurationSeconds: 5, bpm: Self.bpm)) bars, not \
            3. Rounding DOWN drops audio the user imported; rounding UP costs trailing \
            silence, which is inaudible. Only one of those two is a bug.
            """)
        XCTAssertEqual(AudioClipFactory.coveringBars(forDurationSeconds: 4, bpm: Self.bpm), 2, """
            An exact two-bar file must stay two bars — a covering rule that adds a bar to \
            material that already fits would make every well-cut loop gappy.
            """)
        XCTAssertEqual(AudioClipFactory.coveringBars(forDurationSeconds: 0.01, bpm: Self.bpm), 1, """
            A very short file must still occupy one whole bar. A zero-bar region is a region \
            the grid never lands in, which `TimelineRegionPlayer.canPlay` correctly refuses \
            (#1439) — it would import successfully and be unplayable.
            """)
        XCTAssertEqual(AudioClipFactory.coveringBars(forDurationSeconds: 5, bpm: 0), 1, """
            A degenerate tempo returned \
            \(AudioClipFactory.coveringBars(forDurationSeconds: 5, bpm: 0)) bars. It must \
            fall back to 1 and must NOT substitute a default tempo: quietly choosing a BPM \
            inside a placement helper is an invisible musical decision, and it is the \
            estimation founder decision 7 forbids.
            """)

        let media = try temporaryMedia("span.wav")
        defer { remove(media) }
        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: song().document, freeSlotIndex: 0, bpm: Self.bpm)))
        XCTAssertEqual(landing.region.lengthTicks, 3 * TimelineTime.ticksPerBar, """
            The placed region spans \(landing.region.lengthTicks) ticks rather than three \
            whole bars. `plan` must route through `unwarpedRegion`, not through the \
            nearest-bar `region(forDurationSeconds:…)`, which would need a `nativeBPM` this \
            slice is forbidden to invent.
            """)
        XCTAssertFalse(landing.region.warpEnabled, """
            The imported region arrived with warping ENABLED. Unwarped means \
            `StretchPlan.resolve` returns rate 1.0 and the media plays at its recorded \
            speed; warping a clip whose `nativeBPM` is 0 has nothing to warp TO.
            """)
    }

    // MARK: - 8…10 Every way it refuses

    /// CLAIM 8 + 9 — no audio lane and a full clip grid are both refusals that decide
    /// BEFORE anything is written, and each says something different.
    func testAMissingLaneAndAFullGridBothRefuseBeforeAnyWrite() throws {
        let media = try temporaryMedia("refuse.wav")
        defer { remove(media) }
        let world = song()

        let noLane = TimelineDocument(lanes: [world.midi, world.bio])
        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: fiveSeconds(),
                                                    document: noLane, freeSlotIndex: 0,
                                                    bpm: Self.bpm)),
                       AudioImport.Failure.noAudioLane, """
            A song with no importable audio lane did not refuse with `.noAudioLane`. \
            Founder decision 4 is explicit: fail honestly, do NOT create a lane. Auto-\
            creating one here would make the import path a track producer, which is a \
            different slice with a different owner (`TimelineStore.addLane`).
            """)

        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: fiveSeconds(),
                                                    document: world.document,
                                                    freeSlotIndex: nil, bpm: Self.bpm)),
                       AudioImport.Failure.clipGridFull, """
            A full `ClipStore` did not refuse with `.clipGridFull`. Founder decision 8: \
            respect the eight-slot capacity, never overwrite another clip. `plan` learns \
            about capacity ONLY through the `freeSlotIndex` it is handed, so it cannot \
            invent a slot even if it wanted to.
            """)

        // COUNTERWEIGHT (#343) — the same document and the same media succeed the moment a
        // slot exists, so neither refusal above is passing for an unrelated reason.
        XCTAssertNotNil(try success(AudioImport.plan(managed: media, measurement: fiveSeconds(),
                                                     document: world.document,
                                                     freeSlotIndex: 7, bpm: Self.bpm)), """
            With a lane and slot 7 free, the very same inputs still did not land. One of \
            the two refusals above is firing for a reason other than the one it names.
            """)
    }

    /// CLAIM 10 — an unreadable or ill-formed file is refused, and the three refusals are
    /// DISTINCT because they send the user to three different repairs.
    func testAnUnplayableFileIsRefusedWithTheReasonThatNamesIt() throws {
        let media = try temporaryMedia("bad.wav")
        defer { remove(media) }
        let world = song().document

        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: nil,
                                                    document: world, freeSlotIndex: 0,
                                                    bpm: Self.bpm)),
                       AudioImport.Failure.unreadableAudio, """
            A file the decoder could not open at all was not refused with \
            `.unreadableAudio`. nil is the ONLY thing `measureWithAVFoundation` returns for \
            a file `AVAudioFile(forReading:)` rejects.
            """)

        let noRate = AudioImport.Measurement(sampleRate: 0, frameCount: 220_500, channelCount: 2)
        let noChannels = AudioImport.Measurement(sampleRate: 44_100, frameCount: 220_500,
                                                 channelCount: 0)
        let noFrames = AudioImport.Measurement(sampleRate: 44_100, frameCount: 0, channelCount: 2)
        let nanRate = AudioImport.Measurement(sampleRate: .nan, frameCount: 220_500,
                                              channelCount: 2)

        XCTAssertEqual(AudioImport.validate(noRate), AudioImport.Failure.invalidFormat, """
            A zero sample rate passed validation or was called a duration problem. It is a \
            FORMAT problem: `Measurement.durationSeconds` divides by the rate, so letting \
            this through is a division by zero one line later.
            """)
        XCTAssertEqual(AudioImport.validate(nanRate), AudioImport.Failure.invalidFormat, """
            A NaN sample rate passed validation. `isFinite` is checked FIRST on purpose — \
            `NaN > 0` is false, so the ordering happens to save this one, but a later edit \
            that reorders the guards must not be able to let a NaN reach `Double(frames)/rate`.
            """)
        XCTAssertEqual(AudioImport.validate(noChannels), AudioImport.Failure.invalidFormat, """
            A zero-channel file passed validation. There is nothing for the sink to schedule.
            """)
        XCTAssertEqual(AudioImport.validate(noFrames), AudioImport.Failure.invalidDuration, """
            An empty file was called a FORMAT problem. Its rate and channel count are \
            perfectly good — what it has no useful amount of is LENGTH, and "check the file \
            length" and "check the file format" are different instructions to a user.
            """)
        XCTAssertNil(AudioImport.validate(fiveSeconds()), """
            A 5-second 44,1 kHz stereo measurement was rejected, so the four rejections \
            above are not discriminating anything (#343).
            """)

        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: noFrames,
                                                    document: world, freeSlotIndex: 0,
                                                    bpm: Self.bpm)),
                       AudioImport.Failure.invalidDuration, """
            `plan` did not surface `validate`'s verdict unchanged. It must not re-decide \
            what "valid" means; there is one definition and `validate` owns it (#416).
            """)
    }

    /// COUNTERWEIGHT — THE ORDER OF THE REJECTIONS, pinned because it is OBSERVABLE and
    /// because a mutation run showed nothing else catches it.
    ///
    /// A file that is unreadable AND destined for a song with no audio lane reports
    /// UNREADABLE, because that is the one the user can act on with the file still in their
    /// hand. Hoisting the cheap lane check above the measurement looks like an optimisation
    /// (it would skip a pointless copy) and silently changes what every such user is told.
    ///
    /// ⚠️ IT ALSO PROTECTS THE ONE STORE-TOUCHING CLAIM IN THIS FILE.
    /// `testARefusedImportDeletesItsCopyAndWritesToNeitherStore` constructs the real
    /// `ClipStore`/`TimelineStore` and is safe because a nil measurement is rejected BEFORE
    /// either is consulted, whatever the ambient song looks like. Reorder these guards and
    /// that safety argument is gone — so this claim is load-bearing twice over.
    func testTheRefusalsAreOrderedSoTheFileItselfAnswersFirst() throws {
        let media = try temporaryMedia("order.wav")
        defer { remove(media) }
        let world = song()
        let laneless = TimelineDocument(lanes: [world.midi, world.bio])

        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: nil,
                                                    document: laneless, freeSlotIndex: nil,
                                                    bpm: Self.bpm)),
                       AudioImport.Failure.unreadableAudio, """
            A file that is unreadable, on a song with no audio lane, in a full grid, \
            reported something other than `.unreadableAudio`. The measurement is decided \
            FIRST — that is the founder's sequence (copy, validate the COPY, then verify \
            lane and capacity) and it is the only order under which the cleanup contract \
            ("delete the newly copied file if import/validation/lane/capacity fails") means \
            anything.
            """)

        XCTAssertEqual(try failure(AudioImport.plan(managed: media, measurement: fiveSeconds(),
                                                    document: laneless, freeSlotIndex: nil,
                                                    bpm: Self.bpm)),
                       AudioImport.Failure.noAudioLane, """
            A readable file, on a song with no audio lane, in a full grid, did not report \
            `.noAudioLane`. The lane is decided before the slot because "add an audio track" \
            is an instruction the user can follow and "the grid is full" is only meaningful \
            once there is somewhere for the clip to go.
            """)
    }

    /// CLAIM 10 (the transactional half) + THE CLEANUP CONTRACT — a refused import deletes
    /// the file it just copied, and writes to neither store.
    ///
    /// ⚠️ THE ONE CLAIM THAT CONSTRUCTS THE REAL STORES, and it is safe by ORDERING rather
    /// than by luck: `plan` rejects a nil measurement BEFORE it consults the document or the
    /// slot, so on a correct tree neither store can be reached whatever the ambient song
    /// looks like. The snapshots either side are what turns that argument into an assertion.
    func testARefusedImportDeletesItsCopyAndWritesToNeitherStore() throws {
        let picked = try temporaryMedia("picked.wav")
        let managed = try temporaryMedia("managed-copy.wav")
        defer { remove(picked); remove(managed) }

        let clipStore = ClipStore()
        let timeline = TimelineStore()
        let slotsBefore = clipStore.slots
        let regionsBefore = timeline.document.regions
        let lanesBefore = timeline.document.lanes

        var deleted: [URL] = []
        let result = AudioImport.commit(
            pickedURL: picked, clipStore: clipStore, timeline: timeline, bpm: Self.bpm,
            importFile: { _ in managed },
            measure: { _ in nil },
            deleteManagedCopy: { deleted.append($0) })

        XCTAssertEqual(try failure(result), AudioImport.Failure.unreadableAudio, """
            A managed copy the decoder could not read did not produce `.unreadableAudio`.
            """)
        XCTAssertEqual(deleted, [managed], """
            The cleanup deleted \(deleted.map(\.lastPathComponent)) rather than exactly the \
            one file this operation created. It must delete ONLY the URL `importFile` just \
            returned — that file is provably owned by this failed operation because \
            `MediaLibrary.importAudio` picks a collision-free name. A generic sweep over \
            `Media/Audio` would delete media belonging to clips a persisted document still \
            points at, which is the #527 hazard exactly.
            """)
        XCTAssertEqual(clipStore.slots, slotsBefore, """
            A REFUSED import changed the clip grid. Nothing may be written before the \
            transaction has an answer.
            """)
        XCTAssertEqual(timeline.document.regions, regionsBefore, """
            A REFUSED import changed the timeline's regions.
            """)
        XCTAssertEqual(timeline.document.lanes, lanesBefore, """
            A REFUSED import changed the timeline's LANES — which would mean something on \
            this path creates a track. Founder decision 4 forbids exactly that.
            """)

        // COUNTERWEIGHT — a copy that never happened must not be deleted.
        var deletedAfterCopyFailure: [URL] = []
        struct CopyRefused: Error {}
        let copyFailure = AudioImport.commit(
            pickedURL: picked, clipStore: clipStore, timeline: timeline, bpm: Self.bpm,
            importFile: { _ in throw CopyRefused() },
            measure: { _ in nil },
            deleteManagedCopy: { deletedAfterCopyFailure.append($0) })
        XCTAssertEqual(try failure(copyFailure), AudioImport.Failure.copyFailed, """
            A copy that threw did not surface as `.copyFailed`.
            """)
        XCTAssertTrue(deletedAfterCopyFailure.isEmpty, """
            The cleanup ran after the COPY itself failed, deleting \
            \(deletedAfterCopyFailure.map(\.lastPathComponent)). There is no managed file to \
            delete in that case, and a delete built from anything other than `importFile`'s \
            own return value is a delete aimed at a path this operation does not own.
            """)
    }

    // MARK: - 12 Missing media

    /// CLAIM 12 — media that disappears after the import does NOT invalidate the clip or the
    /// region. It blocks only the affected playback.
    ///
    /// END-TO-END: it deletes a real file and asks the shipped resolver and the shipped
    /// play predicate, so this is the actual behaviour a user's song gets.
    func testMediaThatDisappearsLeavesTheClipAndTheRegionAlone() throws {
        let media = try temporaryMedia("vanishing.wav")
        var world = song().document

        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: world, freeSlotIndex: 0, bpm: Self.bpm)))
        world.regions.append(landing.region)

        let resolver: (UUID) -> URL? = { id in
            guard id == landing.clip.id else { return nil }
            return MediaLibrary.resolveRef(landing.clip.mediaRef)
        }

        XCTAssertTrue(TimelineRegionPlayer.canPlay(world, clips: [landing.clip],
                                                   bpm: Self.bpm, resolveAudio: resolver), """
            A freshly imported audio region is not executable. This is the payoff of the \
            whole slice: `ClipKind.timelineEngineKinds` contains `.audio`, the lane is a \
            non-bio audio lane, the clip matches it, the grid lands inside the region, and \
            the resolver answers — if Play still refuses, the import produced something the \
            engine will not schedule and the door is a control that lies.
            """)

        remove(media)

        XCTAssertNil(MediaLibrary.resolveRef(landing.clip.mediaRef), """
            The resolver still answers for a file that no longer exists anywhere it looks. \
            (If this ever goes red because the H6 re-root found a same-named file in \
            `Media/Audio`, the fixture name must become more unique — it is not a finding \
            about the import.)
            """)
        XCTAssertFalse(TimelineRegionPlayer.canPlay(world, clips: [landing.clip],
                                                    bpm: Self.bpm, resolveAudio: resolver), """
            Play is still offered for a song whose only audio has vanished. `isExecutable` \
            asks the SAME resolver the player uses precisely so the button and the transport \
            cannot disagree (#1439).
            """)

        XCTAssertEqual(world.regions.count, 1, """
            The region disappeared along with its media. Founder decision 5 is explicit: \
            missing media must NOT invalidate or delete the clip or the region — it blocks \
            only the affected playback. Deleting the user's arrangement because a file moved \
            is unrecoverable; refusing to play it is not.
            """)
        XCTAssertEqual(world.regions.first?.clipID, landing.clip.id, """
            The surviving region no longer points at its clip.
            """)
        XCTAssertEqual(landing.clip.mediaRef, media.path, """
            The clip's `mediaRef` was cleared when the file went missing. It is the only \
            record of WHERE the media was, and a future relink surface — not this slice — \
            needs it to have survived.
            """)
    }

    // MARK: - 13…16 What this slice did NOT add

    /// CLAIM 13 — no new persistence root. SOURCE-TEXT SCAN.
    ///
    /// The import writes through `ClipStore` and `TimelineStore` and copies through
    /// `MediaLibrary`, all of which already existed. A fifth root (Ω49) is the thing a media
    /// import most naturally grows, and it grows by one innocent `AppGroupStore(subdirectory:)`.
    ///
    /// ⚠️ SCOPED TO `AudioImport.swift` ON PURPOSE (#416/#486). The same question about
    /// `WorkstationView` is already owned by
    /// `TheWorkstationHasADoorTests.testTheSurfaceIntroducesNoPersistenceRoot`, whose needle
    /// set is wider (it also bans `@AppStorage`/`@SceneStorage`, which only a View can have).
    /// Asserting it twice would report one absence as two findings the day it breaks.
    func testTheImportIntroducesNoPersistenceRoot() throws {
        let importer = SourceText.codeOnly(try rawText(Self.importer))
        for forbidden in ["AppGroupStore(", "UserDefaults", "JSONEncoder(", "JSONDecoder(",
                          "NSKeyedArchiver", "FileManager.default.createDirectory"] {
            XCTAssertFalse(importer.contains(forbidden), """
                `AudioImport.swift` now contains `\(forbidden)`. The import path owns NO \
                storage: the clip persists through `ClipStore`, the region through \
                `TimelineStore`, and the file itself through `MediaLibrary`, which already \
                exists and already owns the `Media/Audio` directory. A new persistence root \
                here is a fifth place a project can half-exist.
                """)
        }

        // COUNTERWEIGHT (#343) — it DOES name the two stores it writes through, so the
        // absences above are not passing because the file writes nothing at all.
        for expected in ["clipStore.setClip(", "timeline.addRegion(", "MediaLibrary.importAudio"] {
            XCTAssertTrue(importer.contains(expected), """
                `AudioImport.swift` no longer contains `\(expected)`. The whole point of the \
                scan above is that this file persists THROUGH the existing owners; if it has \
                stopped calling them, the clean absence report means nothing.
                """)
        }
    }

    /// CLAIM 14 — no media-asset identity type or store was introduced. SOURCE-TEXT SCAN
    /// over the whole of `Sources/`, because the point is that it exists NOWHERE.
    ///
    /// ⚠️ THIS FORBIDS NOTHING PERMANENTLY (#364). Founder decision 2 says "not yet", not
    /// "never": `Clip.id` remains the creative identity and `mediaRef` remains the
    /// file-location bridge FOR THIS SLICE. When a canonical media identity does land, this
    /// claim goes red on the day it does, and its job is to make that a decision rather than
    /// a drift.
    func testNoMediaAssetIdentityWasIntroduced() throws {
        for name in ["MediaAsset", "AudioAsset", "MediaAssetStore", "AudioAssetStore"] {
            for keyword in ["struct", "class", "enum", "actor", "protocol"] {
                let declarations = try filesUnderSources(containing: "\(keyword) \(name)")
                XCTAssertTrue(declarations.isEmpty, """
                    `\(keyword) \(name)` is declared in \
                    \(declarations.joined(separator: ", ")). Founder decision 2 for Audio \
                    Import V1 is explicit that canonical source-media identity is NOT part \
                    of this slice — `Clip.id` is the creative identity and `mediaRef` is the \
                    location bridge. If media identity is genuinely landing, this file's \
                    doc and CLAUDE.md's register line move in the same commit.
                    """)
            }
        }
    }

    /// CLAIM 15 — no audio input, recording, sample instrument or grain code entered the two
    /// files this slice writes. SOURCE-TEXT SCAN.
    ///
    /// The founder's STOP list closes this task, and each of these is a plausible next step
    /// that would have arrived here disguised as a helper.
    func testTheImportPathCarriesNoInputOrRecordingCode() throws {
        let importer = SourceText.codeOnly(try rawText(Self.importer))
        let door = SourceText.codeOnly(try rawText(Self.door))
        for (label, code) in [("AudioImport.swift", importer), ("WorkstationView.swift", door)] {
            for forbidden in ["inputNode", "AVAudioRecorder", "AVAudioEngine",
                              "RecordController", "TakeRecorder", "SampleInstrument",
                              "GrainEngine", "MicrophoneManager", "AudioInputManager",
                              "requestRecordPermission"] {
                XCTAssertFalse(code.contains(forbidden), """
                    `\(label)` now contains `\(forbidden)`. Audio Import V1 reads a file the \
                    user already has; it does not capture one. The microphone was removed \
                    from this app entirely (#1302) and `RecordRouteOwner` is an EMPTY enum \
                    so the session can never be raised to `.playAndRecord` — anything here \
                    that reaches for an input would either not compile or quietly re-open a \
                    permission this repo deliberately retired.
                    """)
            }
        }
    }

    /// CLAIM 16 — the Workstation is the ONE production caller of the import transaction.
    /// SOURCE-TEXT SCAN.
    ///
    /// ⚠️ IT PINS THE CALL, NOT THE BUTTON. A second surface calling `AudioImport.perform`
    /// is a second import door, and that is exactly what makes "the Workstation is the door"
    /// checkable — a label or an SF Symbol is not.
    func testTheWorkstationIsTheOnlyImportDoor() throws {
        let callers = try filesUnderSources(containing: "AudioImport.perform(")
        XCTAssertEqual(callers, ["Studio/WorkstationView.swift"], """
            `AudioImport.perform` is called from \
            \(callers.isEmpty ? "nothing" : callers.joined(separator: ", ")). Exactly one \
            production caller was the founder's instruction ("exactly one user-facing \
            action"), and it must be the Workstation plate. If it is called from NOTHING the \
            door has been lost and the audio lanes are back to having no producer; if it is \
            called from two places, say where the second door is and update CLAUDE.md's \
            register in the same commit.
            """)

        let door = SourceText.codeOnly(try rawText(Self.door))
        XCTAssertTrue(door.contains(".fileImporter(isPresented: $importPresented"), """
            The Workstation no longer mounts the system file importer on its own body. The \
            founder's instruction was to use SwiftUI's existing mechanism rather than build \
            a media browser, and to keep the presentation state LOCAL to this leaf.
            """)
        XCTAssertTrue(door.contains("Text(\"Import Audio\")"), """
            The "Import Audio" action is no longer labelled. This is the only user-facing \
            name the feature has.
            """)
        for forbidden in ["TimelineRegion(", "Clip(", "AudioClipFactory.", "MediaLibrary."] {
            XCTAssertFalse(door.contains(forbidden), """
                `WorkstationView` now contains `\(forbidden)`. The view hands its two stores \
                over to `AudioImport` and reads back a result; it constructs no model and \
                touches no file. That is why it still sends `timeline` exactly one message \
                (`document`) and why `TheWorkstationHasADoorTests` claim F stays green.
                """)
        }
    }

    /// COUNTERWEIGHT — the two persistent writes happen in the SUCCESS branch only, and in
    /// the order the resolver requires. SOURCE-TEXT SCAN, brace-matched (#408).
    ///
    /// ⚠️ THE ORDER IS LOAD-BEARING AND THE PAIR IS NOT ATOMIC. Playback resolves
    /// `TimelineRegion.clipID` THROUGH `ClipStore`, so a region written before its clip is a
    /// dangling pointer for as long as the gap lasts; a clip written before its region is an
    /// unreferenced slot, which is the harmless direction. Neither store exposes a
    /// transaction — this claim pins the ordering, it does not pretend the pair is atomic.
    /// #W1 — NO FILE IMPORTER MAY SIT ABOVE THE DOOR. SOURCE-TEXT SCAN (§1).
    ///
    /// Founder device report on build 2599 (2026-09-23): tapping "Import Audio" did NOTHING —
    /// no picker, not even on a second tap — and Play stayed grey because nothing could land.
    /// The door's own `.fileImporter` was correctly bound. Directly above it, on
    /// `EchoelStudioView`'s body chain, sat a SECOND `.fileImporter` whose flag
    /// (`midiImportPresented`) had had no writer of `true` since `f371d27` — dead, but an
    /// ANCESTOR of the plate, and SwiftUI resolves a file importer through the hierarchy, where
    /// one declared higher up can shadow a nested one. #W1 deleted it.
    ///
    /// ⚠️ WHAT THIS PROVES AND WHAT IT CANNOT. It proves where the text sits: the four files
    /// on the plate's ancestor path (app → `WorkspaceView` → `SurfaceHost` →
    /// `EchoelStudioView`) carry no `.fileImporter(` except the ONE nested inside
    /// `openSheet`, which is a sheet's CONTENT and so not an ancestor of the plate. That the
    /// picker now OPENS is a DEVICE PROBE and stays open (item (7) of the founder checks in
    /// `WorkstationView`'s header); the shadowing mechanism is SwiftUI behaviour no test here can run.
    ///
    /// Grading (#433): REGRESSION on the parent tree — `EchoelStudioView` carried two
    /// `.fileImporter(` occurrences there, one of them `$midiImportPresented`; green after.
    /// ⚠️ It does not forbid a future MIDI or project import (#364): it forbids mounting one
    /// on the plate's ANCESTOR path. Put it on its own leaf, or inside a sheet's content, the
    /// way `openSheet` does.
    func testNoFileImporterSitsAboveTheImportDoor() throws {
        let ancestors = [
            "Sources/Echoelmusic/EchoelmusicApp.swift",
            "Sources/Echoelmusic/Studio/WorkspaceView.swift",
            "Sources/Echoelmusic/Studio/SurfaceSwitcher.swift",
        ]
        for path in ancestors {
            let code = SourceText.codeOnly(try rawText(path))
            XCTAssertEqual(occurrences(of: ".fileImporter(", in: code), 0, """
                \(path) now mounts a `.fileImporter`. It is an ancestor of the Workstation \
                plate, and an importer declared above the plate's own can shadow it — the #W1 \
                device defect: "Import Audio" opened nothing. Mount the new importer on its own \
                leaf or inside a sheet's content instead.
                """)
        }

        let studio = SourceText.codeOnly(try rawText("Sources/Echoelmusic/Studio/EchoelStudioView.swift"))
        let importers = studio.components(separatedBy: "\n").filter { $0.contains(".fileImporter(") }
        XCTAssertEqual(importers.count, 1, """
            `EchoelStudioView` now has \(importers.count) `.fileImporter(` sites. Exactly one \
            is legal — the project importer nested inside `openSheet`, which is a sheet's \
            content and therefore NOT an ancestor of the Workstation plate. Any other one sits \
            above the plate and can shadow its "Import Audio" picker (#W1). Found: \
            \(importers.map { $0.trimmingCharacters(in: .whitespaces) })
            """)
        XCTAssertTrue(importers.allSatisfy { $0.contains("$projectImportPresented") }, """
            The one `.fileImporter` left in `EchoelStudioView` is no longer the project \
            importer inside `openSheet`: \(importers.map { $0.trimmingCharacters(in: .whitespaces) }). \
            A body-chain importer is an ancestor of the Workstation plate (#W1).
            """)
        XCTAssertFalse(studio.contains("midiImportPresented"), """
            `midiImportPresented` is back in code. Its importer was an ancestor of the \
            Workstation plate and silenced "Import Audio" on the device (#W1); a MIDI import \
            door, if it returns, must not ride the root body chain.
            """)
    }

    func testTheClipIsCommittedBeforeTheRegionAndOnlyOnSuccess() throws {
        let code = SourceText.codeOnly(try rawText(Self.importer))
        let body = try body(of: "commit", in: code)

        let clipWrite = try XCTUnwrap(body.range(of: "clipStore.setClip("), """
            `AudioImport.commit` no longer writes the clip. Without it the region points at \
            a clip `ClipStore.clip(id:)` cannot find, and the import silently produces \
            nothing playable.
            """)
        let regionWrite = try XCTUnwrap(body.range(of: "timeline.addRegion("), """
            `AudioImport.commit` no longer writes the region. The clip would sit in the grid \
            and never appear on the timeline.
            """)
        XCTAssertTrue(clipWrite.lowerBound < regionWrite.lowerBound, """
            `timeline.addRegion` now runs BEFORE `clipStore.setClip`. Between the two writes \
            the document holds a region whose clip does not exist yet — and both stores \
            `persist()` on every write, so that state reaches disk. Reversed, the worst case \
            is a clip in a slot that nothing references.
            """)

        let successBranch = try XCTUnwrap(body.range(of: "case .success(let landing):"), """
            `commit` no longer switches on the plan's result. Both writes must sit inside the \
            success branch; a write reachable from a failure is a half-import.
            """)
        XCTAssertTrue(successBranch.lowerBound < clipWrite.lowerBound, """
            `clipStore.setClip` is reachable before the success branch, i.e. a refused import \
            can write.
            """)
        XCTAssertEqual(occurrences(of: "clipStore.setClip(", in: body), 1, """
            `commit` writes the clip in more than one place. One write, one branch.
            """)
        XCTAssertEqual(occurrences(of: "timeline.addRegion(", in: body), 1, """
            `commit` writes the region in more than one place.
            """)
    }

    /// COUNTERWEIGHT — every failure says something, and no two failures say the same thing.
    /// A distinct message per reason is what "no silent failure" means once the alert is on
    /// screen rather than in an enum.
    func testEveryRefusalHasItsOwnSentence() {
        let all: [AudioImport.Failure] = [.pickerFailed, .copyFailed, .unreadableAudio,
                                          .invalidFormat, .invalidDuration, .noAudioLane,
                                          .clipGridFull]
        var seen: Set<String> = []
        for failure in all {
            let message = failure.userMessage
            XCTAssertFalse(message.isEmpty, """
                `\(failure)` has an empty user message — that is a silent failure with extra \
                steps.
                """)
            XCTAssertTrue(seen.insert(message).inserted, """
                `\(failure)` repeats a message another failure already uses: "\(message)". \
                Two causes with one sentence send the user to the wrong repair.
                """)
        }
        XCTAssertTrue(AudioImport.Failure.noAudioLane.userMessage.contains("audio track"), """
            The no-lane message no longer names the missing thing. Whatever it says, it has to \
            name what is absent, or the user cannot tell this refusal from the other six.
            """)
    }

    /// Claim 18 (SOURCE-TEXT SCAN) — the no-lane refusal may INSTRUCT only for as long as some
    /// production path can carry the instruction out.
    ///
    /// ⛔ THE FOUNDER'S OWN SENTENCE WAS "Add an audio track first.", and on 2026-09-22 that
    /// was an instruction no production path could perform: `bootstrapIfNeeded`, `addLane` and
    /// `addInstrumentTrack` each had ZERO callers outside `Core/TimelineStore.swift`, and a
    /// fresh `TimelineStore.init()` with no stored document builds `TimelineDocument()` —
    /// `lanes: []`. The sentence sent a new user hunting for a control that did not exist, in
    /// the one refusal a fresh install is guaranteed to hit, so it was demoted to a report.
    ///
    /// ⭐ AND ON 2026-09-23 THE FOUNDER BUILT THE MISSING CONTROL, so this claim flipped —
    /// which is the whole reason it was written as a BICONDITIONAL (#364) rather than as a ban
    /// on instructing. It never forbade a lane door; it required the two halves to agree.
    /// `AudioImport.addAudioTrack` is now `addLane`'s one production caller and
    /// `WorkstationView`'s "Add Audio Track" row is its door, so `doored` is non-empty and the
    /// message instructs again. It still goes red in exactly the two INCONSISTENT states: an
    /// instruction with no way to obey it, or a door that exists while the message only
    /// diagnoses. ⚠️ Read that as a ratchet in neither direction — DELETING the door is
    /// legitimate work and this claim permits it, as long as the sentence is demoted in the
    /// same commit.
    ///
    /// ⚠️ ITS REACH IS THE THREE NAMES IT KNOWS. A lane creator added under a fourth name is
    /// invisible to it, so this under-claims rather than over-claims — say so rather than
    /// reading a green here as "no lane can be created".
    func testTheNoLaneRefusalOnlyInstructsWhatAProductionPathCanDo() throws {
        let creators: [String] = ["bootstrapIfNeeded(", "addLane(", "addInstrumentTrack("]
        var doored: [String] = []
        for creator in creators {
            let callers = try filesUnderSources(containing: creator)
                .filter { $0 != "Core/TimelineStore.swift" }
            if !callers.isEmpty {
                doored.append("\(creator) called from \(callers.joined(separator: ", "))")
            }
        }
        let message: String = AudioImport.Failure.noAudioLane.userMessage
        let instructs: Bool = message.lowercased().contains("add an audio track")
        // Hoisted out of the interpolation on purpose: a ternary over two String-producing
        // branches inside a `\( … )` is the shape that cost a TEST BUILD on 2026-09-22 (#E2,
        // `Tests/CISmoke/CLAUDE.md` §4). Nothing here needs the type checker to work for it.
        let creatorList: String = doored.isEmpty ? "none" : doored.joined(separator: " | ")
        XCTAssertEqual(instructs, !doored.isEmpty, """
            The no-lane refusal and the app's actual ability to create a lane disagree.
            message: "\(message)"  (instructs: \(instructs))
            production lane creators with a caller: \(creatorList)
            Either the message tells the user to add an audio track while nothing outside \
            `Core/TimelineStore.swift` can add one — the state this claim was written for — or \
            a lane creator has gained a door and the message still only diagnoses, which \
            withholds the repair from a user who now has it. Fix whichever side is stale; this \
            claim does not prefer one.
            """)
    }

    // MARK: - 19…21 The lane door (founder 2026-09-23)

    /// Claim 19 (END-TO-END BEHAVIOUR) — one tap appends exactly one importable audio lane.
    ///
    /// ⚠️ EVERY ASSERTION IS A DELTA, NOT AN ABSOLUTE, AND THAT IS NOT TIMIDITY. `TimelineStore`
    /// has one initialiser and it LOADS from the app-group container, so what a fresh
    /// `TimelineStore()` holds in a test host depends on what an earlier run persisted —
    /// `addLane` calls `persist()`, so this claim's own previous run is one of those. An
    /// absolute (`lanes.count == 1`) would pass once and then fail forever for a reason that
    /// has nothing to do with the code under test. The delta is the real invariant anyway: the
    /// founder asked for a creator, and a creator is defined by what it ADDS.
    ///
    /// ⭐ THE LAST ASSERTION IS THE ONE THAT MATTERS — it closes the founder's own chain.
    /// "Add Audio Track → Import Audio" only works if the lane this mints is the lane the
    /// import SELECTS, and those are two different predicates written in two places. Asking
    /// `firstImportableAudioLane` rather than re-checking `kind`/`isBio` by hand is the #416
    /// discipline: a creator that drifted (`isBio: true`, a `.midi` kind) would still satisfy
    /// a hand-written copy of the rule while the import silently refused its own track.
    func testTheLaneDoorAppendsOneImportableAudioLane() {
        let timeline = TimelineStore()
        let before = timeline.document.lanes

        AudioImport.addAudioTrack(timeline: timeline)

        let after = timeline.document.lanes
        XCTAssertEqual(after.count, before.count + 1, """
            `addAudioTrack` changed the lane count by \(after.count - before.count) rather \
            than by exactly one. The founder's instruction was "create exactly a \
            TimelineLane(kind: .audio)" — no more, and not nothing.
            """)
        guard let added = after.last else { return }   // unreachable once the delta above holds
        XCTAssertEqual(added.kind, .audio, """
            `addAudioTrack` appended a lane of kind `.\(added.kind)`. An audio track is the \
            only thing this door was approved to create.
            """)
        XCTAssertFalse(added.isBio, """
            `addAudioTrack` appended a lane marked `isBio`. The bio lane renders an \
            automation curve instead of media regions, and `TimelineDocument.audioLaneIDs` — \
            what the transport actually walks — excludes it. A track the user added and the \
            transport refuses to look at is a control that lies.
            """)
        XCTAssertNotNil(AudioImport.firstImportableAudioLane(in: timeline.document), """
            After adding a track, the import still finds no lane to land on. That breaks the \
            founder's whole chain (Add Audio Track → Import Audio → playback): the creator \
            and the selector disagree about what an importable audio lane is.
            """)
    }

    /// Claim 20 (SOURCE-TEXT SCAN) — the creator has a door, and it is the Workstation plate.
    ///
    /// ⚠️ THE LABEL IS SCANNED SEPARATELY FROM THE CALL because they fail apart. A button
    /// wired to nothing and a call with no button are both "the door exists" to a careless
    /// reading, and only one of them is reachable by a person holding the phone.
    func testTheLaneCreatorHasADoorOnTheWorkstationPlate() throws {
        let door = SourceText.codeOnly(try rawText(Self.door))
        XCTAssertTrue(door.contains("AudioImport.addAudioTrack(timeline: timeline)"), """
            `WorkstationView` no longer calls `AudioImport.addAudioTrack`. It is the only \
            production caller, so losing it takes `addLane` back to zero callers and makes \
            the import door unreachable on a fresh install — the exact state the founder \
            unblocked on 2026-09-23. If the removal is deliberate, demote \
            `AudioImport.Failure.noAudioLane.userMessage` in the same commit; claim 18 is a \
            biconditional and will say so.
            """)
        XCTAssertTrue(door.contains("Text(\"Add Audio Track\")"), """
            The "Add Audio Track" action is no longer labelled. This is the only user-facing \
            name the founder's creator has.
            """)
    }

    /// #W2 (SOURCE-TEXT SCAN) — the empty plate instructs only what the plate offers.
    ///
    /// On build 2599 the empty Workstation said "Takes you record or generate appear here as
    /// parts on a track." beside a greyed Play. Neither producer could run on a fresh
    /// document: nothing records (#1302), and a generated take reaches the timeline only
    /// through `ensureComposerRegion`, which needs a MIDI lane nothing in the build creates.
    /// The founder read it as buttons that do not work. The sentence now names the two
    /// buttons that DO fill the plate, and this claim pins that each name it uses is a label
    /// this same file renders.
    ///
    /// Grading (#433): REGRESSION on the parent for the second assertion (the old sentence
    /// says "record" and "generate"); the first is FORWARD (the labels are new in the empty
    /// state). ⚠️ It forbids no future producer (#364): when a production path DOES record or
    /// generate onto a track, the sentence may say so again, and this claim moves with it.
    func testTheEmptyPlateNamesOnlyActionsItOffers() throws {
        let door = SourceText.codeOnly(try rawText(Self.door))
        guard let start = door.range(of: "private var emptyState: some View {"),
              let end = door.range(of: "private func songLine(", range: start.upperBound..<door.endIndex)
        else {
            return XCTFail("`emptyState` or the `songLine` that follows it moved in \(Self.door) — re-anchor this claim")
        }
        let empty = String(door[start.upperBound..<end.lowerBound])

        for label in ["Add Audio Track", "Import Audio"] {
            XCTAssertTrue(empty.contains(label) && door.contains("Text(\"\(label)\")"), """
                The empty Workstation no longer names "\(label)", or no button on the plate is \
                labelled that any more. The empty state is the one sentence a new user reads \
                beside a greyed Play; it must point at a button that exists (#W2).
                """)
        }
        for promise in ["record", "generate"] {
            XCTAssertFalse(empty.lowercased().contains(promise), """
                The empty Workstation says "\(promise)" again. On a fresh document nothing \
                \(promise)s onto a track (#1302 took recording; a generated take needs a MIDI \
                lane nothing creates), so the plate would promise a producer that cannot run — \
                the #W2 device report. If such a producer now exists, update this claim with it.
                """)
        }
    }

    /// Claim 21 (SOURCE-TEXT SCAN) — `addLane` has exactly one production caller, and it is
    /// the helper, not the view.
    ///
    /// ⭐ THIS IS WHY `TheWorkstationHasADoorTests` CLAIM F IS STILL GREEN, and the two must be
    /// read together. Claim F asserts `WorkstationView` sends `timeline` nothing but
    /// `document`; the founder's instruction was that the mutation go through the existing
    /// `TimelineStore` owner. Both hold because the view HANDS THE STORE OVER to
    /// `AudioImport.addAudioTrack`, the same seam `perform` uses — which is the repair claim
    /// F's own note prescribes, not a way around it. A future slice that calls
    /// `timeline.addLane(` from a `body` reddens claim F; one that calls it from a third file
    /// reddens this.
    ///
    /// ⚠️ IT FORBIDS NO SECOND CREATOR (#364) — it prices one. An "Add MIDI Track" row, a
    /// project importer, a template are all legitimate; each must arrive with this line, with
    /// claim 18's two halves re-checked, and with CLAUDE.md's register moved in the same
    /// commit. A pinned SET rather than a count, so the failure names WHO appeared.
    func testTheLaneCreatorIsTheOnlyProductionCallerOfAddLane() throws {
        let callers = try filesUnderSources(containing: "addLane(")
            .filter { $0 != "Core/TimelineStore.swift" }
        // Hoisted, not inlined: a ternary over two String-producing branches inside a
        // `\( … )` is the shape that cost a TEST BUILD on 2026-09-22 (#E2). Claim 18 above
        // carries the same note for the same reason — the type checker is not needed here.
        let callerList: String = callers.isEmpty ? "nothing outside its own file"
                                                 : callers.joined(separator: ", ")
        XCTAssertEqual(callers, ["Sequencer/AudioImport.swift"], """
            `TimelineStore.addLane` is called from \(callerList). \
            Exactly one production caller was the founder's shape: the creator lives beside \
            `firstImportableAudioLane` so it cannot drift from the predicate that decides \
            which lane an import lands on, and the view stays read-only toward the store.
            """)
    }

    /// COUNTERWEIGHT — the success note names the file, the span and the track.
    func testTheSuccessNoteNamesWhatLanded() throws {
        let media = try temporaryMedia("note.wav")
        defer { remove(media) }
        let landing = try XCTUnwrap(try success(
            AudioImport.plan(managed: media, measurement: fiveSeconds(),
                             document: song().document, freeSlotIndex: 0, bpm: Self.bpm)))
        let note = AudioImport.successNote(landing, laneName: "Audio 1")
        XCTAssertTrue(note.contains(landing.clip.name), """
            The success note does not name the file that landed: "\(note)".
            """)
        XCTAssertTrue(note.contains("Audio 1"), """
            The success note does not name the track it landed on: "\(note)". With no \
            waveform in this slice, the sentence IS the feedback.
            """)
        XCTAssertTrue(note.contains("3 bars"), """
            The success note reports the wrong span: "\(note)". A 5-second file at 120 bpm \
            covers three bars.
            """)
    }

    // MARK: - Helpers

    private func success(_ result: Result<AudioImport.Landing, AudioImport.Failure>) throws
        -> AudioImport.Landing? {
        switch result {
        case .success(let landing): return landing
        case .failure(let failure):
            XCTFail("expected a landing, got `.\(failure)` — \(failure.userMessage)")
            return nil
        }
    }

    private func failure(_ result: Result<AudioImport.Landing, AudioImport.Failure>) throws
        -> AudioImport.Failure? {
        switch result {
        case .success(let landing):
            XCTFail("expected a refusal, got a landing on lane \(landing.laneID)")
            return nil
        case .failure(let failure): return failure
        }
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var index = text.startIndex
        while let found = text.range(of: needle, range: index..<text.endIndex) {
            count += 1
            index = found.upperBound
        }
        return count
    }

    /// #1240 — thrown after `XCTFail` when an anchor is missing, so the calling claim stops
    /// (it has nothing to scan) AND the run is red (it asserted the anchor and lost).
    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body of `name` inside `code`, so a needle cannot be satisfied by a
    /// neighbouring declaration. This repo writes 30–40-line comment blocks and
    /// `SourceText.codeOnly` preserves line count, so any fixed line window is unsound by
    /// construction (§2, #408).
    private func body(of name: String, in code: String) throws -> String {
        guard let start = code.range(of: "func \(name)"),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex)
        else {
            XCTFail("`func \(name)` is not in \(Self.importer) — the anchor moved; re-anchor this guard (#1240: XCTFail for a missed anchor, XCTSkip only for a missing tree)")
            throw AnchorMissing(name: name)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        throw XCTSkip("unbalanced braces after `func \(name)` — refusing to guess its body")
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("""
                \(relativePath) is not present — this guard inspects source text, so it SKIPS \
                rather than reporting a green it did not earn (#454)
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
