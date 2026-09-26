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
// the new part.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMediaLibraryIsBrowsedAndPlacedTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let browserPath = "Sources/Echoelmusic/Studio/MediaBrowserView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let placementPath = "Sources/Echoelmusic/Sequencer/MediaPlacement.swift"

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
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
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
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
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
        let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
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
