// TheMediaLibraryIsBrowsedAndPlacedTests.swift
// Echoel — Phase 3 / MA1: "MediaAsset + lazy Browser" (founder order 2026-09-25; plan
// `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`).
//
// WHAT IT PINS. Before this slice, an imported file could be used a second time only by picking
// it from Files again — a second copy and a second of the eight clip slots for the same sound.
// The Workstation now lists the library ("Media Library") and "Place" puts a file on the song,
// reusing the clip that already plays it.
//
// 1. PURE (`MediaAsset`, END-TO-END BEHAVIOUR on shipped value types): the identity of a file is
//    (home, file name), read from the TAIL of a stored path — a path written under an older
//    container is the same asset (H6). Anything that is not an asset home is no asset.
// 2. PURE: usage joins the clip grid and the song — only AUDIO clips count, parts are counted
//    per clip that carries the asset; the browser order reads like a person reads.
// 3. PURE (`MediaPlacement.plan`): no audio track refuses first; a carried asset becomes a region
//    on THAT clip at the import's lane and end-of-lane tick, spanning bars at the song tempo;
//    an orphan asks for a new clip; an unknown length is measured, and an unreadable one refused.
// 4. END-TO-END over a REAL `TimelineStore` and `ClipStore`: a reuse spends no slot and is ONE
//    undo step that leaves the clip; an orphan makes one clip pointing at the file where it is.
// 5. END-TO-END on a REAL FILE: a refused orphan placement (full grid) leaves the library file on
//    disk — the transaction's cleanup must never reach a user's asset.
// 6. SOURCE-TEXT SCAN: the listing runs detached and only there; the browser is a mounted leaf
//    with no modal, no persistence and no model construction; one production caller each.
// 7. B1 (MA3 revised order, 2026-09-26): a NAME FILTER — PURE `MediaAsset.matching` (case- and
//    diacritic-insensitive, spaces trimmed, the shown name only, order kept) and a SCAN that the
//    rows are that projection of the listing in memory, the query is leaf state outside the
//    listing's key (typing never re-lists), and closing empties it. On the parent (`049e0b765`)
//    this file does NOT compile — `matching` and `noMatchText` are new: one absence (#486); claim
//    7 is a FORWARD guard, its counterweights are the empty query and the single listing call.
// 8. B2 (same order): a MISSING FILE IS NAMED — PURE `MediaAsset.missing` lists the audio clips
//    whose ref the resolver cannot find, with the expected file name and their parts on playable
//    audio lanes; a SCAN that the answer comes from the player's own resolver in the open list's
//    task, and the body only draws it. On the parent (`1013dab43`) this file does NOT compile —
//    `missing`, `Missing` and `missingText` are new: one absence (#486); claim 8 is a FORWARD
//    guard, its counterweights are the all-resolve and no-ref cases.
// 9. B2b: RELINK — END-TO-END over a REAL `ClipStore`: four refusals (file gone, another length,
//    unreadable, MIDI) write nothing; a file of the same length keeps id, name, tempo and slot count and
//    only changes `mediaRef` (+ length); the writer refuses bad input itself. SCAN: no file
//    operation, the file checked before the write, one writer and one door. On `6bf47f8b9` this file
//    does NOT compile — `MediaRelink` and `relinkAudio` are new: one absence (#486), FORWARD guard.
//    Review repair (`aa7089d90`, M3/L3): Relink is refused while the song plays
//    (`relinkRefusal`, asked before the write) and the file is checked before it is MEASURED;
//    REGRESSIONS on `90270c345` (the refusal and the order scan did not exist), counterweight
//    the stopped-song case. The rule checks LENGTH only — it cannot tell two equal-length
//    recordings apart, and no assertion here claims it can.
//    Founder 2026-09-26: a relink is ONE undo step in the current session
//    (`TimelineStore.relinkClipSource`, history kind `.clipSource`): Undo restores the old file
//    and length exactly — including an unknown length — and Redo the new ones; refusals record no
//    step. REGRESSIONS on `7006ace55` (the relink wrote around the history).
//    MA4.2 review (`eeaee9daf`): the relink RELEASES the clip's `mediaAssetID` (it named the old
//    file's record) and Undo gives it back — 2 REGRESSIONS there (the link survived the relink,
//    and Redo kept it); the rest of the claim is unchanged. This commit also adds the required
//    `mediaAssetID:` to the three writer calls below, so the file does not compile on that parent.
// 10. B3: PREVIEW — PURE `MediaBrowserView.previewRefusal` refuses while the song, the instrument's
//    loop plays, or the engine is stopped (the sink's first use attaches a node, which pauses the
//    engine); a SCAN that the preview plays through `BeatPlayer`'s attached audition path, only
//    after the refusal, from the browser alone, and ends with the list, the view, a start of the
//    song or loop, and after `previewSeconds`. On `a68bf05fa` this file does NOT compile —
//    `previewRefusal` and `previewSeconds` are new: one absence (#486), FORWARD guard; the
//    all-stopped case is its counterweight.
//
// HONEST GRADING (§3), against the parent tree (`a57d03f5c`): the file does NOT compile there —
// `MediaAsset`, `MediaPlacement`, `MediaLibrary.listAudio` and `MediaBrowserView` are all new —
// so no assertion has a verdict on the parent. Every claim is a FORWARD guard for symbols this
// commit creates; one absence (#486), not twenty. Counterweights (#343): claim 4 asserts the
// clip is untouched and the grid count unchanged; claim 6 asserts the positive mount and the
// positive detached hop beside every absence. Graded by Python transcription of the key rule,
// the usage join, the plan and the scan anchors against the worktree.
//
// NOT HERE — DEVICE PROBE, open: that the list scrolls smoothly with a long library, that
// "Place" is reachable and readable at large Dynamic Type, that a placed part SOUNDS.
// NEEDS-FOUNDER-VERIFY: Import Audio twice with two files → Media Library → both listed with
// "in 1 part" → Place the first → a second part appears at the end of the audio track and plays
// the same sound → the grid did not grow (Import a third file still works) → Undo removes only
// the new part. Then type part of a name into "Filter by name" → only matching files stay, the
// "N of M files" line counts them → clear it → all return → close and reopen → the field is empty.
// Then open a project saved on another device (the app's media folder is not visible in the
// Files app, so there is no in-app way to lose a file) → Media Library → "Missing on this device"
// names the clip, the file it expects and its parts → the parts are still in the song → with the
// song stopped, Relink → pick the same recording → the row disappears and the old parts sound
// again; a file of another length is refused; with the song playing, Relink says to stop it.
// ⚠️ A different recording of the SAME length is accepted, and a relink cannot be undone
// (review M1/M2 of `aa7089d90`) — do not test with a file you want to keep the clip away from.
// Then, with the song stopped, tap Preview on a row → its first seconds sound, the button reads
// Stop → Stop silences it → Preview again, then press the song's Play → the preview stops → with
// the song playing, Preview says to stop the song first and nothing sounds.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMediaLibraryIsBrowsedAndPlacedTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let browserPath = "Sources/Echoelmusic/Studio/MediaBrowserView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let placementPath = "Sources/Echoelmusic/Sequencer/MediaPlacement.swift"
    private static let relinkPath = "Sources/Echoelmusic/Sequencer/MediaRelink.swift"

    private let today = "/private/var/mobile/Containers/Shared/AppGroup/NEW-UUID/Media/Audio/Loop.wav"
    private let beforeUpdate = "/private/var/mobile/Containers/Shared/AppGroup/OLD-UUID/Media/Audio/Loop.wav"

    // MARK: 1 — identity

    func testTheIdentityIsTheHomeAndTheFileName() {
        let key = MediaAsset.Key(kind: .audio, fileName: "Loop.wav")
        XCTAssertEqual(MediaAsset.key(forRef: today), key)
        XCTAssertEqual(MediaAsset.key(forRef: beforeUpdate), key,
                       "a path from an older container is the SAME asset — the H6 re-rooting rule")
        XCTAssertEqual(MediaAsset.key(forRef: "Media/Audio/Loop.wav"), key)

        XCTAssertNil(MediaAsset.key(forRef: nil))
        XCTAssertNil(MediaAsset.key(forRef: ""))
        XCTAssertNil(MediaAsset.key(forRef: "Loop.wav"), "a bare name carries no home")
        XCTAssertNil(MediaAsset.key(forRef: "/x/Media/Audio/"), "a directory is no asset")
        XCTAssertNil(MediaAsset.key(forRef: "/x/Documents/Videos/Take.mov"),
                     "the legacy video folder is not an asset home")
        XCTAssertNil(MediaAsset.key(forRef: "/x/Media/Video/Take.mov"),
                     "nothing plays video since #1304, so its home lists nothing")
        XCTAssertNil(MediaAsset.key(forRef: "/x/Audio/Loop.wav"), "the home is TWO directories")

        let asset = MediaAsset(kind: .audio, fileName: "Take 2.m4a",
                               url: URL(fileURLWithPath: "/x/Media/Audio/Take 2.m4a"), byteSize: -5)
        XCTAssertEqual(asset.displayName, "Take 2")
        XCTAssertEqual(asset.byteSize, 0, "a negative size is not a size")
    }

    // MARK: 2 — usage and order

    func testUsageJoinsTheClipGridAndTheSong() {
        let first = Clip(name: "Loop", kind: .audio, mediaRef: today)
        let second = Clip(name: "Loop again", kind: .audio, mediaRef: beforeUpdate)
        let midi = Clip(name: "Keys", kind: .midi, mediaRef: today)
        let other = Clip(name: "Pad", kind: .audio, mediaRef: "/x/Media/Audio/Pad.wav")
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let regions = [
            TimelineRegion(laneID: audio.id, clipID: first.id, startTick: 0, lengthTicks: 1920),
            TimelineRegion(laneID: audio.id, clipID: first.id, startTick: 1920, lengthTicks: 1920),
            TimelineRegion(laneID: audio.id, clipID: second.id, startTick: 3840, lengthTicks: 1920),
            TimelineRegion(laneID: keys.id, clipID: midi.id, startTick: 0, lengthTicks: 1920),
            // Not uses: a part on a bio lane and a part whose lane is gone (review of ae3faa1c5).
            TimelineRegion(laneID: body.id, clipID: first.id, startTick: 0, lengthTicks: 1920),
            TimelineRegion(laneID: UUID(), clipID: first.id, startTick: 0, lengthTicks: 1920),
        ]
        let doc = TimelineDocument(lanes: [audio, body, keys], regions: regions)
        let usage = MediaAsset.usage(clips: [first, midi, second, other], document: doc)

        let loop = MediaAsset.Key(kind: .audio, fileName: "Loop.wav")
        XCTAssertEqual(usage[loop]?.clipIDs, [first.id, second.id],
                       "both audio clips carry the file, in slot order; the MIDI clip does not")
        XCTAssertEqual(usage[loop]?.partCount, 3,
                       "three parts on the playable audio lane; the MIDI, bio and lane-less parts are not uses")
        XCTAssertEqual(usage[MediaAsset.Key(kind: .audio, fileName: "Pad.wav")],
                       MediaAsset.Usage(clipIDs: [other.id], partCount: 0))
        XCTAssertNil(usage[MediaAsset.Key(kind: .audio, fileName: "Unused.wav")])

        XCTAssertEqual(MediaBrowserView.usageText(.unused), "not in the song")
        XCTAssertEqual(MediaBrowserView.usageText(MediaAsset.Usage(clipIDs: [other.id], partCount: 0)),
                       "in a clip, no part yet")
        XCTAssertEqual(MediaBrowserView.usageText(MediaAsset.Usage(clipIDs: [first.id], partCount: 1)),
                       "in 1 part")
        XCTAssertEqual(MediaBrowserView.usageText(MediaAsset.Usage(clipIDs: [first.id], partCount: 3)),
                       "in 3 parts")
    }

    func testTheOrderReadsLikeAPersonReads() {
        func asset(_ name: String) -> MediaAsset {
            MediaAsset(kind: .audio, fileName: name, url: URL(fileURLWithPath: "/x/" + name), byteSize: 1)
        }
        let sorted = MediaAsset.sorted([asset("Take 10.wav"), asset("take 2.wav"), asset("Alpha.wav")])
        XCTAssertEqual(sorted.map(\.key.fileName), ["Alpha.wav", "take 2.wav", "Take 10.wav"])
    }

    // MARK: 3 — the plan

    func testThePlanReusesTheClipThatCarriesTheFile() {
        let bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: beforeUpdate, nativeDurationSeconds: 5)
        let existing = TimelineRegion(laneID: audio.id, clipID: clip.id, startTick: 0, lengthTicks: 3840)
        let doc = TimelineDocument(lanes: [bio, audio], regions: [existing])
        let key = MediaAsset.Key(kind: .audio, fileName: "Loop.wav")

        guard case .reuse(let region) = MediaPlacement.plan(key, clips: [clip], document: doc,
                                                             bpm: 120, measuredSeconds: nil) else {
            return XCTFail("a carried asset must be placed on its own clip")
        }
        XCTAssertEqual(region.clipID, clip.id, "no new clip — the part plays the one that exists")
        XCTAssertEqual(region.laneID, audio.id, "the import's lane: the first audio lane that is not bio")
        XCTAssertEqual(region.startTick, doc.nextStartTick(inLane: audio.id), "after the lane's last part")
        XCTAssertEqual(region.startTick, 3840)
        let bars = AudioClipFactory.coveringBars(forDurationSeconds: 5, bpm: 120)
        XCTAssertEqual(region.lengthTicks, bars * TimelineTime.ticksPerBar)
        XCTAssertEqual(bars, 3, "5 s at 120 BPM is 2.5 bars, covered by 3")
        XCTAssertFalse(region.warpEnabled, "placed unwarped, as the import places")

        // The clip's own length wins over a measurement.
        guard case .reuse(let same) = MediaPlacement.plan(key, clips: [clip], document: doc,
                                                           bpm: 120, measuredSeconds: 60) else {
            return XCTFail("a known length needs no measurement")
        }
        XCTAssertEqual(same.lengthTicks, region.lengthTicks)
    }

    func testAReuseOnAWarpedTrackLandsWarped() {
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: today,
                        nativeDurationSeconds: 8, nativeBPM: 90)
        let key = MediaAsset.Key(kind: .audio, fileName: "Loop.wav")
        let first = TimelineRegion(laneID: audio.id, clipID: clip.id, startTick: 0, lengthTicks: 3840)

        var warped = first
        warped.warpEnabled = true
        let onTrack = TimelineDocument(lanes: [audio], regions: [warped])
        XCTAssertEqual(AudioWarp.state(laneID: audio.id, in: onTrack, clips: [clip]), .on,
                       "fixture premise: the track's switch reads on")
        guard case .reuse(let region) = MediaPlacement.plan(key, clips: [clip], document: onTrack,
                                                             bpm: 120, measuredSeconds: nil) else {
            return XCTFail("the reuse must land")
        }
        XCTAssertTrue(region.warpEnabled, "a new part of a warped track must not flip it to Mixed")
        XCTAssertEqual(region.lengthTicks,
                       AudioWarp.spanTicks(for: region, clip: clip, warped: true, bpm: 120),
                       "the span the switch itself gives a warped part (#416)")
        var after = onTrack
        after.regions.append(region)
        XCTAssertEqual(AudioWarp.state(laneID: audio.id, in: after, clips: [clip]), .on)

        let offTrack = TimelineDocument(lanes: [audio], regions: [first])
        guard case .reuse(let plain) = MediaPlacement.plan(key, clips: [clip], document: offTrack,
                                                            bpm: 120, measuredSeconds: nil) else {
            return XCTFail("the reuse must land")
        }
        XCTAssertFalse(plain.warpEnabled, "an unwarped track gets an unwarped part, as Import gives")
        XCTAssertEqual(plain.lengthTicks,
                       AudioClipFactory.coveringBars(forDurationSeconds: 8, bpm: 120) * TimelineTime.ticksPerBar)
    }

    func testThePlanRefusesWhatItCannotPlace() {
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let doc = TimelineDocument(lanes: [audio], regions: [])
        let key = MediaAsset.Key(kind: .audio, fileName: "Loop.wav")
        let lengthless = Clip(name: "Old", kind: .audio, mediaRef: today)

        XCTAssertEqual(MediaPlacement.plan(key, clips: [], document: doc, bpm: 120, measuredSeconds: nil),
                       .newClip, "an orphan file needs a clip, made by the import transaction")
        XCTAssertEqual(MediaPlacement.plan(key, clips: [lengthless], document: doc, bpm: 120,
                                           measuredSeconds: nil),
                       .failure(.unreadableAudio), "no stored length and no readable file")
        XCTAssertEqual(MediaPlacement.plan(key, clips: [lengthless], document: doc, bpm: 120,
                                           measuredSeconds: 0),
                       .failure(.invalidDuration))
        XCTAssertEqual(MediaPlacement.plan(key, clips: [lengthless], document: doc, bpm: 120,
                                           measuredSeconds: .nan),
                       .failure(.invalidDuration), "a NaN length is no length")
        guard case .reuse = MediaPlacement.plan(key, clips: [lengthless], document: doc, bpm: 120,
                                                measuredSeconds: 3) else {
            return XCTFail("a measured length places an old clip")
        }

        let noAudio = TimelineDocument(lanes: [TimelineLane(name: "Keys", kind: .midi),
                                               TimelineLane(name: "Body", kind: .audio, isBio: true)],
                                       regions: [])
        XCTAssertEqual(MediaPlacement.plan(key, clips: [], document: noAudio, bpm: 120, measuredSeconds: nil),
                       .failure(.noAudioLane), "the lane is refused FIRST, even for an orphan")
    }

    // MARK: 4 — the real stores

    func testAReuseSpendsNoSlotAndIsOneUndoStep() {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: beforeUpdate, nativeDurationSeconds: 4)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: one audio clip")
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [
            TimelineRegion(laneID: audio.id, clipID: clip.id, startTick: 0, lengthTicks: 1920),
        ]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")

        let asset = MediaAsset(kind: .audio, fileName: "Loop.wav",
                               url: URL(fileURLWithPath: today), byteSize: 1)
        var measured = 0
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120, assets: nil,
                                          measure: { _ in measured += 1; return nil })
        guard case .success(let placed) = result else { return XCTFail("the reuse must land") }
        XCTAssertTrue(placed.reusedClip)
        XCTAssertEqual(placed.clipName, "Loop")
        XCTAssertEqual(measured, 0, "a clip that knows its length is not measured")
        XCTAssertEqual(timeline.document.regions.count, 2)
        XCTAssertEqual(timeline.document.regions.last?.clipID, clip.id)
        XCTAssertEqual(clips.filledClips.count, 1, "no slot spent")
        XCTAssertEqual(clips.clip(id: clip.id), clip, "the clip itself is untouched")

        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(timeline.document.regions.count, 1, "ONE Undo takes the new part back")
        XCTAssertFalse(timeline.canUndo, "and it was one step")
        XCTAssertEqual(clips.filledClips.count, 1, "the clip other parts play is left alone")
    }

    func testAnOrphanBecomesOneClipAtTheFileWhereItIs() {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio)],
                                                  regions: []))
        let url = URL(fileURLWithPath: today)
        let asset = MediaAsset(kind: .audio, fileName: "Loop.wav", url: url, byteSize: 1)
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120, assets: nil,
                                          measure: { _ in
            AudioImport.Measurement(sampleRate: 48_000, frameCount: 96_000, channelCount: 2)
        })
        guard case .success(let placed) = result else { return XCTFail("the orphan must land") }
        XCTAssertFalse(placed.reusedClip)
        XCTAssertEqual(clips.filledClips.count, 1, "one clip for the orphan")
        let made = clips.filledClips.first
        XCTAssertEqual(made?.mediaRef, url.path, "the clip points at the library file itself — no copy")
        XCTAssertEqual(MediaAsset.key(forRef: made?.mediaRef), asset.key)
        XCTAssertEqual(timeline.document.regions.map(\.clipID), made.map { [$0.id] } ?? [])
    }

    // MARK: 5 — a real file survives a refusal

    func testARefusedPlacementNeverDeletesTheLibraryFile() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        let probe = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaPlacementProbe-\(UUID().uuidString)")
        let home = probe.appendingPathComponent("Media/Audio", isDirectory: true)
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
            try? FileManager.default.removeItem(at: probe)
        }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let file = home.appendingPathComponent("Keep.wav")
        try Data([0, 1, 2, 3]).write(to: file)

        // A full grid of OTHER clips: the plan says `.newClip`, the transaction refuses.
        let full: [Clip?] = (0..<ClipStore.slotCount).map { i in
            Clip(name: "Other \(i)", kind: .audio, mediaRef: "/x/Media/Audio/Other\(i).wav")
        }
        XCTAssertTrue(clips.replaceSlots(full))
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio)],
                                                  regions: []))
        let asset = MediaAsset(kind: .audio, fileName: "Keep.wav", url: file, byteSize: 4)
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120, assets: nil,
                                          measure: { _ in
            AudioImport.Measurement(sampleRate: 44_100, frameCount: 44_100, channelCount: 1)
        })
        guard case .failure(let failure) = result else { return XCTFail("a full grid must refuse") }
        XCTAssertEqual(failure, .clipGridFull)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path),
                      "the import's cleanup deletes 'the copy it made' — here there is none, and the user's file must stay")
        XCTAssertTrue(timeline.document.regions.isEmpty, "nothing was placed")
    }

    // MARK: 6 — source

    func testTheListingIsDetachedAndTheBrowserIsAQuietLeaf() throws {
        let browser = try source(Self.browserPath)
        XCTAssertEqual(occurrences(of: "MediaLibrary.listAudio()", in: browser), 1,
                       "the browser lists the library at exactly one place")
        let task = try body(of: "sorted()))", in: browser)   // the `.task(id: ListingKey(…))` line's end
        let hop = try XCTUnwrap(task.range(of: "Task.detached("),
                                "the listing must hop off the main actor")
        let list = try XCTUnwrap(task.range(of: "MediaLibrary.listAudio()"))
        XCTAssertLessThan(hop.lowerBound, list.lowerBound, "…and list INSIDE the hop, not before it")
        let cancelled = try XCTUnwrap(task.range(of: "guard !Task.isCancelled"),
                                      "a superseded listing must not overwrite a newer one")
        let write = try XCTUnwrap(task.range(of: "listing = "))
        XCTAssertLessThan(cancelled.lowerBound, write.lowerBound, "the check comes BEFORE the write")
        XCTAssertTrue(browser.contains("LazyVStack"), "a long library builds only the rows on screen")
        XCTAssertTrue(browser.contains("MediaPlacement.perform("), "Place writes through the one writer")
        XCTAssertTrue(browser.contains("selection.selectRegion(placed.region.id, in: timeline.document)"),
                      "the placed part is selected, as the other creators select theirs")
        for forbidden in [".sheet(", ".fullScreenCover(", ".popover(", "@AppStorage", "UserDefaults",
                          "FileManager", "Clip(", "TimelineRegion(", "timeline.addRegion(",
                          "clipStore.setClip("] {
            XCTAssertFalse(browser.contains(forbidden), "the browser leaf must not contain `\(forbidden)`")
        }

        let workstation = try source(Self.workstationPath)
        XCTAssertEqual(occurrences(of: "MediaBrowserView()", in: workstation), 1,
                       "the Media Library is mounted on the Workstation plate, once")
        XCTAssertFalse(workstation.contains("MediaLibrary."),
                       "the root still touches no file (TheWorkstationImportsAudioTests claim 16)")

        XCTAssertEqual(try filesUnderSources(containing: "MediaLibrary.listAudio("),
                       ["Studio/MediaBrowserView.swift"],
                       "the one QUALIFIED caller, detached (MA2's `existingAudio` reaches it inside MediaLibrary, on the import path)")
        XCTAssertEqual(try filesUnderSources(containing: "MediaPlacement.perform("),
                       ["Studio/MediaBrowserView.swift"], "one door for placing a library file")
    }

    func testTheOrphanPathCannotDeleteAndReuseIsOneRegion() throws {
        let placement = try source(Self.placementPath)
        let place = try body(of: "public static func place(", in: placement)
        XCTAssertTrue(place.contains("importFile: { $0 }"), "an orphan is not copied again")
        XCTAssertTrue(place.contains("deleteManagedCopy: { _ in }"),
                      "the transaction's cleanup must be a no-op on a library file")
        XCTAssertFalse(place.contains("removeItem"), "nothing in the placement deletes")
        XCTAssertEqual(occurrences(of: "timeline.addRegion(", in: place), 1,
                       "a reuse is exactly one region write — one undo step")
        XCTAssertFalse(place.contains("clipStore.setClip("),
                       "a reuse never writes a clip; a new clip is `AudioImport.commit`'s to write")
        XCTAssertTrue(placement.contains("AudioImport.firstImportableAudioLane(in: document)"),
                      "the lane is the import's own predicate (#416)")
        let perform = try body(of: "public static func perform(", in: placement)
        let exists = try XCTUnwrap(perform.range(of: "fileExists(atPath: asset.url.path)"),
                                   "a vanished file must be refused, not placed as a silent part")
        let call = try XCTUnwrap(perform.range(of: "place(asset"))
        XCTAssertLessThan(exists.lowerBound, call.lowerBound, "checked before anything is written")
    }

    // MARK: 7 — B1: the name filter

    func testTheFilterMatchesTheShownNameAndKeepsTheOrder() {
        func asset(_ name: String) -> MediaAsset {
            MediaAsset(kind: .audio, fileName: name, url: URL(fileURLWithPath: "/x/Media/Audio/\(name)"),
                       byteSize: 1)
        }
        let library = MediaAsset.sorted([asset("Kick Loop.wav"), asset("Käse Pad.aif"),
                                         asset("take 2.wav"), asset("Take 10.wav")])
        XCTAssertEqual(MediaAsset.matching(library, query: "").map(\.key.fileName),
                       library.map(\.key.fileName), "counterweight: no query keeps every file, in order")
        XCTAssertEqual(MediaAsset.matching(library, query: "   ").count, library.count,
                       "a query of only spaces filters nothing")
        XCTAssertEqual(MediaAsset.matching(library, query: " LOOP ").map(\.key.fileName), ["Kick Loop.wav"],
                       "case-insensitive, and the spaces a keyboard leaves are not part of the name")
        XCTAssertEqual(MediaAsset.matching(library, query: "kase").map(\.key.fileName), ["Käse Pad.aif"],
                       "diacritic-insensitive, as the Files app searches")
        XCTAssertEqual(MediaAsset.matching(library, query: "take").map(\.key.fileName),
                       ["take 2.wav", "Take 10.wav"], "the browser's order survives the filter")
        XCTAssertTrue(MediaAsset.matching(library, query: "wav").isEmpty,
                      "the extension is not in the name the row shows, so it is not matched")
        XCTAssertEqual(MediaBrowserView.noMatchText(" snare "), "No file name contains \u{201C}snare\u{201D}.")
    }

    func testTheFilterIsAProjectionInTheLeafNotAListing() throws {
        let browser = try source(Self.browserPath)
        XCTAssertTrue(browser.contains("let shown = MediaAsset.matching(assets, query: query)"),
                      "the rows are the filtered projection of the listing in memory")
        XCTAssertTrue(browser.contains("ForEach(shown)"), "the list draws the filtered rows")
        XCTAssertFalse(browser.contains("ForEach(assets)"), "no second, unfiltered list")
        XCTAssertTrue(browser.contains("@State private var query = \"\""),
                      "the query is the leaf's own state — typing never rebuilds the Workstation")
        let key = try body(of: "private struct ListingKey: Equatable", in: browser)
        XCTAssertFalse(key.contains("query"),
                       "typing must not re-list the directory: the query is not part of the listing's key")
        let toggle = try body(of: "private var toggleRow: some View", in: browser)
        XCTAssertTrue(toggle.contains("query = \"\""), "closing the list empties the filter")
        XCTAssertEqual(occurrences(of: "MediaLibrary.listAudio()", in: browser), 1,
                       "counterweight: still one listing call")
    }

    // MARK: 8 — B2: a file this device cannot find is named, not silent

    func testAMissingFileIsNamedWithTheClipAndItsParts() {
        let gone = Clip(name: "Break", kind: .audio, mediaRef: "/x/Media/Audio/Break.wav")
        let here = Clip(name: "Pad", kind: .audio, mediaRef: "/x/Media/Audio/Pad.wav")
        let noRef = Clip(name: "Empty", kind: .audio, mediaRef: nil)
        let keys = Clip(name: "Keys", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let doc = TimelineDocument(lanes: [audio, midi], regions: [
            TimelineRegion(laneID: audio.id, clipID: gone.id, startTick: 0, lengthTicks: bar),
            TimelineRegion(laneID: audio.id, clipID: gone.id, startTick: bar, lengthTicks: bar),
            TimelineRegion(laneID: midi.id, clipID: gone.id, startTick: 0, lengthTicks: bar),
            TimelineRegion(laneID: audio.id, clipID: here.id, startTick: 2 * bar, lengthTicks: bar),
        ])
        let clips = [gone, here, noRef, keys]

        let missing = MediaAsset.missing(clips: clips, document: doc, resolves: { $0 != gone.id })
        XCTAssertEqual(missing.map(\.clipID), [gone.id],
                       "only the clip whose file the resolver cannot find — not the one it finds, not a clip with no ref, not MIDI")
        XCTAssertEqual(missing.first?.fileName, "Break.wav", "the file the clip expects, by name")
        XCTAssertEqual(missing.first?.clipName, "Break")
        XCTAssertEqual(missing.first?.partCount, 2,
                       "parts on playable audio lanes only — the region on a MIDI lane plays nothing of this file")
        XCTAssertTrue(MediaAsset.missing(clips: clips, document: doc, resolves: { _ in true }).isEmpty,
                      "counterweight: when everything resolves, nothing is called missing")
        XCTAssertEqual(MediaAsset.missing(clips: [noRef], document: doc, resolves: { _ in false }), [],
                       "a clip that names no file is not a missing file")
        XCTAssertEqual(missing.first.map(MediaBrowserView.missingText), "Break — expects Break.wav · 2 parts")
    }

    func testMissingIsAskedOfThePlayersResolverWhileTheListIsOpen() throws {
        let browser = try source(Self.browserPath)
        let task = try body(of: "sorted()))", in: browser)
        XCTAssertTrue(task.contains("resolves: { lanes.resolvedURL(forClipID: $0) != nil }"),
                      "the question goes to the PLAYING path's resolver (#1439), inside the open list's task")
        XCTAssertTrue(task.contains("if let lanes = player.audioLanes {"),
                      "no player, no answer — nothing is called missing on a guess")
        XCTAssertEqual(occurrences(of: "resolvedURL(forClipID:", in: browser), 1,
                       "asked once, in the task — never in `body`, where typing a filter would re-ask it")
        XCTAssertFalse(browser.contains("MediaLibrary.resolveRef("), "no second resolver beside the player's")
        XCTAssertTrue(browser.contains("resolves: { !missingIDs.contains($0) }"),
                      "the body draws the task's answer; part counts stay fresh from the live song")
        let toggle = try body(of: "private var toggleRow: some View", in: browser)
        XCTAssertTrue(toggle.contains("missingIDs = []"), "closing forgets the answer; reopening asks again")
    }

    // MARK: 9 — B2b: relink a missing clip to a library file of the same length

    func testARelinkKeepsTheClipAndItsPartsAndRefusesAnotherRecording() {
        XCTAssertTrue(MediaRelink.sameLength(8.0, 8.04), "a re-export moves the end by milliseconds")
        XCTAssertTrue(MediaRelink.sameLength(60.0, 60.5), "1 % of a long file")
        XCTAssertFalse(MediaRelink.sameLength(8.0, 8.2), "a different take is another recording")
        XCTAssertFalse(MediaRelink.sameLength(.nan, 8.0))

        let clips = ClipStore()
        let timeline = TimelineStore()
        let original = clips.slots
        defer { clips.replaceSlots(original) }
        // MA4.2 review: the clip carries a link to the durable record of its OLD file.
        let gone = Clip(name: "Break", kind: .audio, mediaRef: "/x/Media/Audio/Break.wav",
                        mediaAssetID: UUID(), nativeDurationSeconds: 8.0, nativeBPM: 96)
        let midi = Clip(name: "Keys", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = gone
        grid[1] = midi
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise")
        let found = MediaAsset(kind: .audio, fileName: "Break (1).wav",
                               url: URL(fileURLWithPath: "/y/Media/Audio/Break (1).wav"), byteSize: 1)
        func measured(_ seconds: Double) -> (URL) -> AudioImport.Measurement? {
            { _ in AudioImport.Measurement(sampleRate: 48_000, frameCount: Int64(seconds * 48_000),
                                           channelCount: 2) }
        }

        // Refusals write nothing.
        XCTAssertEqual(MediaRelink.relink(gone.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in false },
                                          measure: measured(8.0)), .failure(.fileGone))
        XCTAssertEqual(MediaRelink.relink(gone.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in true },
                                          measure: measured(12.0)),
                       .failure(.differentLength(expected: 8.0, found: 12.0)))
        XCTAssertEqual(MediaRelink.relink(gone.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in true },
                                          measure: { _ in nil }), .failure(.unreadable))
        XCTAssertEqual(MediaRelink.relink(midi.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in true },
                                          measure: measured(8.0)), .failure(.noAudioClip))
        XCTAssertEqual(clips.clip(id: gone.id), gone, "every refusal left the clip exactly as it was")
        XCTAssertFalse(timeline.canUndo, "…and recorded no undo step")

        // The same recording: only the source changes.
        XCTAssertEqual(MediaRelink.relink(gone.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in true },
                                          measure: measured(8.0)), .success(8.0))
        let after = clips.clip(id: gone.id)
        XCTAssertEqual(after?.mediaRef, found.url.path, "the clip now names the library file")
        XCTAssertEqual(after?.id, gone.id, "the id every part points at is kept")
        XCTAssertEqual(after?.name, "Break")
        XCTAssertEqual(after?.nativeBPM, 96, "its tempo is kept — the file has the same length")
        XCTAssertNil(after?.mediaAssetID,
                     "the link to the old file's record is released — it would name a file the clip no longer plays")
        XCTAssertEqual(clips.filledClips.count, 2, "no new clip, no slot spent")
        XCTAssertEqual(clips.clip(id: midi.id), midi, "counterweight: the other clip is untouched")

        // ONE undo step in the session (founder 2026-09-26): Undo restores the old binding, Redo
        // the new one; the clip id and everything else are the same object throughout.
        XCTAssertTrue(timeline.canUndo, "a relink is an undo step")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: gone.id), gone, "Undo restores the old file, length and link exactly")
        XCTAssertTrue(timeline.canRedo)
        timeline.redo()
        XCTAssertEqual(clips.clip(id: gone.id)?.mediaRef, found.url.path, "Redo re-applies the relink")
        XCTAssertEqual(clips.clip(id: gone.id)?.nativeDurationSeconds, 8.0)
        XCTAssertNil(clips.clip(id: gone.id)?.mediaAssetID, "Redo releases the link again")

        // A clip that never learned its length takes the file's.
        let unmeasured = Clip(name: "Old", kind: .audio, mediaRef: "/x/Media/Audio/Old.wav")
        grid[2] = unmeasured
        XCTAssertTrue(clips.replaceSlots(grid))
        XCTAssertEqual(MediaRelink.relink(unmeasured.id, to: found, clipStore: clips, timeline: timeline, assets: nil, fileExists: { _ in true },
                                          measure: measured(3.0)), .success(3.0))
        XCTAssertEqual(clips.clip(id: unmeasured.id)?.nativeDurationSeconds, 3.0)
        timeline.undo()
        XCTAssertEqual(clips.clip(id: unmeasured.id), unmeasured,
                       "Undo gives an unmeasured clip back its unknown length, not the file's")
        XCTAssertFalse(clips.relinkAudio(id: midi.id, mediaRef: "/y/x.wav", nativeDurationSeconds: 1,
                                         mediaAssetID: nil),
                       "the writer itself refuses a MIDI clip")
        XCTAssertFalse(clips.relinkAudio(id: gone.id, mediaRef: "", nativeDurationSeconds: 1, mediaAssetID: nil))
        XCTAssertFalse(clips.relinkAudio(id: gone.id, mediaRef: "/y/x.wav", nativeDurationSeconds: Double.nan,
                                         mediaAssetID: nil))
    }

    func testRelinkIsOneWriterAndTheBrowsersOnlyDoor() throws {
        let relink = try source(Self.relinkPath)
        XCTAssertFalse(relink.contains("removeItem") || relink.contains("copyItem") || relink.contains("moveItem"),
                       "a relink never touches a file")
        let relinkBody = try body(of: "public static func relink(", in: relink)
        let exists = try XCTUnwrap(relinkBody.range(of: "guard fileExists(asset.url.path)"))
        let write = try XCTUnwrap(relinkBody.range(of: "timeline.relinkClipSource("))
        XCTAssertLessThan(exists.lowerBound, write.lowerBound, "the file is checked before anything is written")
        let measure = try XCTUnwrap(relinkBody.range(of: "measure(asset.url)"))
        XCTAssertLessThan(exists.lowerBound, measure.lowerBound, "…and before it is measured")
        XCTAssertEqual(MediaBrowserView.relinkRefusal(songPlaying: true), "Stop the song to relink a file.",
                       "no relink under a playing song — its lane's first attach would pause the engine")
        XCTAssertNil(MediaBrowserView.relinkRefusal(songPlaying: false), "counterweight: a stopped song relinks")
        let relinkTap = try body(of: "private func relink(_ item: MediaAsset.Missing", in: try source(Self.browserPath))
        let refused = try XCTUnwrap(relinkTap.range(of: "Self.relinkRefusal(songPlaying: player.isPlaying)"))
        let performed = try XCTUnwrap(relinkTap.range(of: "MediaRelink.perform("))
        XCTAssertLessThan(refused.lowerBound, performed.lowerBound, "the refusal is asked before the write")
        XCTAssertFalse(relinkBody.contains("Region"), "no part is written — the parts stay where they are")
        XCTAssertEqual(try filesUnderSources(containing: "relinkAudio("),
                       ["Core/ClipStore.swift", "Core/TimelineStore.swift"],
                       "one clip writer, called only by the song's undoable writer and its Undo/Redo")
        XCTAssertEqual(try filesUnderSources(containing: "relinkClipSource("),
                       ["Core/TimelineStore.swift", "Sequencer/MediaRelink.swift"],
                       "one undoable writer, one caller")
        XCTAssertEqual(try filesUnderSources(containing: "MediaRelink.perform("),
                       ["Studio/MediaBrowserView.swift"], "the browser's Relink is the one door")
        let browser = try source(Self.browserPath)
        XCTAssertTrue(browser.contains("candidates = MediaAsset.matching(all, query: query)"),
                      "the files offered are the rows the filter shows")
    }

    // MARK: 10 — B3 preview

    func testAPreviewIsRefusedWhileAnythingPlays() {
        XCTAssertNil(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: false, engineRunning: true),
                     "counterweight: with everything stopped a preview may play")
        XCTAssertEqual(MediaBrowserView.previewRefusal(songPlaying: true, loopPlaying: false, engineRunning: true),
                       "Stop the song to preview a file.")
        XCTAssertEqual(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: true, engineRunning: true),
                       "Stop the instrument's loop to preview a file.")
        XCTAssertEqual(MediaBrowserView.previewRefusal(songPlaying: true, loopPlaying: true, engineRunning: true),
                       "Stop the song to preview a file.", "the song is named first")
        XCTAssertNotNil(MediaBrowserView.previewRefusal(songPlaying: false, loopPlaying: false, engineRunning: false),
                        "a stopped engine would light the button and play nothing")
        XCTAssertTrue(MediaBrowserView.previewSeconds.isFinite && MediaBrowserView.previewSeconds > 0,
                      "a preview ends itself")
    }

    func testThePreviewPlaysThroughTheAttachedAuditionAndEndsItself() throws {
        let browser = try source(Self.browserPath)
        let start = try body(of: "private func preview(_ asset: MediaAsset)", in: browser)
        let refusal = try XCTUnwrap(start.range(of: "Self.previewRefusal("))
        let play = try XCTUnwrap(start.range(of: "beatPlayer.audition(url: asset.url, fromSeconds: 0, lengthSeconds: Self.previewSeconds)"))
        XCTAssertLessThan(refusal.lowerBound, play.lowerBound, "the refusal is asked before anything sounds")
        XCTAssertEqual(try filesUnderSources(containing: ".audition(url:"), ["Studio/MediaBrowserView.swift"],
                       "the browser's Preview is the audition path's one caller")
        XCTAssertEqual(try filesUnderSources(containing: ".stopAudition()"), ["Studio/MediaBrowserView.swift"])
        let toggle = try body(of: "private var toggleRow: some View", in: browser)
        XCTAssertTrue(toggle.contains("stopPreview()"), "closing the list ends a preview")
        XCTAssertTrue(browser.contains(".onDisappear { stopPreview() }"), "leaving the Workstation ends it")
        XCTAssertTrue(browser.contains(".onChange(of: player.isPlaying || beatPlayer.pattern.isPlaying)"),
                      "the song or the loop starting ends it — never two sources over each other")
        XCTAssertTrue(browser.contains("try? await Task.sleep(for: .seconds(Self.previewSeconds))"),
                      "a forgotten preview ends itself")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing(name: anchor)
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// `Sources/Echoelmusic`-relative paths of every Swift file whose CODE contains `needle`.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }
}
