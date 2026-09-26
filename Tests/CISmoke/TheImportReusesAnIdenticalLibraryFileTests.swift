// TheImportReusesAnIdenticalLibraryFileTests.swift
// Echoel — Phase 3 / MA2: import de-duplication (plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`).
//
// WHAT IT PINS. Before this slice, importing a file whose bytes were already in the library made
// a second copy in `Media/Audio` and spent a second of the eight clip slots on the same sound.
// Now `AudioImport.perform` asks the library first: the same bytes are the same sound, and they
// land through `MediaPlacement.place` — the decision "Place" already makes — with no copy.
//
// 1. END-TO-END on REAL FILES (`MediaLibrary.sameBytes` / `identicalAudio`): equal bytes match,
//    one differing byte does not, a shorter file does not, a file that cannot be opened never
//    matches; the size filter runs FIRST, so a same-content file recorded at another size is not
//    even read; an empty source matches nothing. The multi-chunk path is driven with a 3-byte
//    chunk so the loop runs more than once.
// 2. PURE (`AudioImport.preferredExisting`): of several identical files, the one a clip already
//    plays wins — a pre-MA2 library can hold the same sound twice.
// 3. END-TO-END over a REAL `ClipStore` and `TimelineStore` and a REAL temp home
//    (`AudioImport.landExisting`): a carried file lands as ONE region with no slot spent and no
//    new file on disk; an orphan becomes ONE clip AT the existing file; a refusal (no audio track,
//    a full grid) leaves the library file where it was. The landing says it reused the file, and
//    the note says so to the person.
// 4. SOURCE-TEXT SCAN: `perform` asks the library BEFORE the copy transaction and inside the
//    security scope; the de-dup branch contains no delete and no copy; one production caller of
//    the library question.
//
// HONEST GRADING (§3), against the parent tree (`45484ee85`): the file does NOT compile there —
// `MediaLibrary.sameBytes`, `identicalAudio`, `existingAudio`, `AudioImport.preferredExisting`,
// `landExisting` and `Landing.reusedLibraryFile` are all new — so no assertion has a verdict on
// the parent. Every claim is a FORWARD guard; one absence (#486), not twenty. Counterweights
// (#343): claim 1 asserts the positive match beside every refusal; claim 3 asserts the file
// still exists and the clip is untouched beside the region count; claim 4 asserts the copy path
// is still there AFTER the library question. Graded by Python transcription of the compare,
// the size filter, the preference and every scan anchor against the worktree.
//
// NOT HERE — DEVICE PROBE, open: a real Files pick (security scope, an iCloud file not yet
// downloaded has no size and simply copies), and how long the compare takes on a long file.
// NEEDS-FOUNDER-VERIFY: Import Audio → pick a file → Import Audio → pick THE SAME file again →
// the note says "already in the library … no second copy", a second part appears at the end of
// the audio track, and Media Library lists the file ONCE with "in 2 parts".

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheImportReusesAnIdenticalLibraryFileTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let importPath = "Sources/Echoelmusic/Sequencer/AudioImport.swift"

    // MARK: fixtures

    /// A fresh `…/Media/Audio` under the temp directory, so `MediaAsset.key(forRef:)` reads the
    /// files as assets. Removed by the caller's `defer`, registered before any write.
    private func makeHome() -> (probe: URL, home: URL) {
        let probe = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaDedupProbe-\(UUID().uuidString)")
        return (probe, probe.appendingPathComponent("Media/Audio", isDirectory: true))
    }

    private func write(_ bytes: [UInt8], _ name: String, in dir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    private func asset(_ url: URL, size: Int64) -> MediaAsset {
        MediaAsset(kind: .audio, fileName: url.lastPathComponent, url: url, byteSize: size)
    }

    private func fileCount(_ dir: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: dir.path).count) ?? -1
    }

    // MARK: 1 — the same bytes

    func testTheSameBytesAreTheSameFile() throws {
        let (probe, home) = makeHome()
        defer { try? FileManager.default.removeItem(at: probe) }
        let ten: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        let a = try write(ten, "a.wav", in: home)
        let b = try write(ten, "b.wav", in: home)
        var oneOff = ten
        oneOff[9] = 42
        let c = try write(oneOff, "c.wav", in: home)
        let d = try write(Array(ten.prefix(7)), "d.wav", in: home)

        for chunk in [3, 1 << 20] {
            XCTAssertTrue(MediaLibrary.sameBytes(a, b, chunkSize: chunk),
                          "equal bytes are the same file (chunk \(chunk))")
            XCTAssertFalse(MediaLibrary.sameBytes(a, c, chunkSize: chunk),
                           "one differing byte in the LAST chunk is a different file (chunk \(chunk))")
            XCTAssertFalse(MediaLibrary.sameBytes(a, d, chunkSize: chunk),
                           "a shorter file is a different file (chunk \(chunk))")
            XCTAssertFalse(MediaLibrary.sameBytes(d, a, chunkSize: chunk), "…in either order")
        }
        let missing = home.appendingPathComponent("gone.wav")
        XCTAssertFalse(MediaLibrary.sameBytes(a, missing), "a file that cannot be opened never matches")
        XCTAssertFalse(MediaLibrary.sameBytes(a, b, chunkSize: 0), "a non-positive chunk refuses, it does not spin")
    }

    func testOnlyAnIdenticalFileOfTheSameSizeMatches() throws {
        let (probe, home) = makeHome()
        defer { try? FileManager.default.removeItem(at: probe) }
        let bytes: [UInt8] = [9, 8, 7, 6, 5, 4]
        let picked = try write(bytes, "picked.wav", in: probe)
        let same = try write(bytes, "Same.wav", in: home)
        let sameSizeOther = try write([9, 8, 7, 6, 5, 0], "Other.wav", in: home)
        let longer = try write(bytes + [1], "Longer.wav", in: home)

        let found = MediaLibrary.identicalAudio(
            to: picked,
            among: [asset(same, size: 6), asset(sameSizeOther, size: 6), asset(longer, size: 7)],
            chunkSize: 4)
        XCTAssertEqual(found.map(\.key.fileName), ["Same.wav"],
                       "only the file with the same bytes is the same sound")

        // The size gate runs FIRST: an identical file RECORDED at another size is never read.
        XCTAssertTrue(MediaLibrary.identicalAudio(to: picked, among: [asset(same, size: 5)]).isEmpty,
                      "the compare runs only on files that survive the size filter")

        let empty = try write([], "empty.wav", in: probe)
        XCTAssertTrue(MediaLibrary.identicalAudio(to: empty, among: [asset(same, size: 0)]).isEmpty,
                      "an empty file is no audio and matches nothing — the import refuses it as before")
    }

    // MARK: 2 — which copy

    func testAnImportPrefersTheCopyAClipAlreadyPlays() {
        let first = MediaAsset(kind: .audio, fileName: "Loop.wav",
                               url: URL(fileURLWithPath: "/c/Media/Audio/Loop.wav"), byteSize: 6)
        let second = MediaAsset(kind: .audio, fileName: "Loop 2.wav",
                                url: URL(fileURLWithPath: "/c/Media/Audio/Loop 2.wav"), byteSize: 6)
        let carrier = Clip(name: "Loop 2", kind: .audio, mediaRef: "/old/Media/Audio/Loop 2.wav")
        XCTAssertEqual(AudioImport.preferredExisting([first, second], clips: [carrier]), second,
                       "the copy a clip plays wins, so the new part spends no slot")
        XCTAssertEqual(AudioImport.preferredExisting([first, second], clips: []), first,
                       "with no carrier, the browser's order decides")
        XCTAssertNil(AudioImport.preferredExisting([], clips: [carrier]), "no match, no reuse")
    }

    // MARK: 3 — the real stores and a real home

    func testAnIdenticalImportSpendsNoSlotAndMakesNoCopy() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        let (probe, home) = makeHome()
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
            try? FileManager.default.removeItem(at: probe)
        }
        let file = try write([1, 2, 3, 4], "Keep.wav", in: home)
        let clip = Clip(name: "Keep", kind: .audio, mediaRef: file.path, nativeDurationSeconds: 4)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[2] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: one audio clip, in slot 2")
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        timeline.replaceDocument(TimelineDocument(lanes: [audio], regions: [
            TimelineRegion(laneID: audio.id, clipID: clip.id, startTick: 0, lengthTicks: 1920),
        ]))
        let filesBefore = fileCount(home)

        let result = AudioImport.landExisting(asset(file, size: 4), clipStore: clips,
                                              timeline: timeline, bpm: 120,
                                              measure: { _ in XCTFail("a known length is not measured"); return nil })
        guard case .success(let landing) = result else { return XCTFail("an identical import must land") }
        XCTAssertTrue(landing.reusedLibraryFile)
        XCTAssertEqual(landing.clip, clip, "the landing reports the clip that already plays the file")
        XCTAssertEqual(landing.slotIndex, 2)
        XCTAssertEqual(landing.managedURL, file, "the analysis reads the existing file, not a copy")
        XCTAssertEqual(landing.laneID, audio.id)
        XCTAssertEqual(clips.filledClips.count, 1, "no slot spent")
        XCTAssertEqual(timeline.document.regions.count, 2, "one new part")
        XCTAssertEqual(fileCount(home), filesBefore, "no second copy on disk")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let note = AudioImport.successNote(landing, laneName: "Audio 1")
        XCTAssertTrue(note.contains("already in the library"), "the note says why nothing was copied: \(note)")
        XCTAssertTrue(note.contains("no second copy"), note)
        XCTAssertTrue(note.contains("Audio 1"), note)
    }

    func testAnIdenticalOrphanBecomesOneClipAtTheExistingFile() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        let (probe, home) = makeHome()
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
            try? FileManager.default.removeItem(at: probe)
        }
        let file = try write([5, 6, 7, 8], "Orphan.wav", in: home)
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio)],
                                                  regions: []))
        let filesBefore = fileCount(home)

        let result = AudioImport.landExisting(asset(file, size: 4), clipStore: clips,
                                              timeline: timeline, bpm: 120, measure: { _ in
            AudioImport.Measurement(sampleRate: 44_100, frameCount: 88_200, channelCount: 1)
        })
        guard case .success(let landing) = result else { return XCTFail("an identical orphan must land") }
        XCTAssertTrue(landing.reusedLibraryFile)
        XCTAssertEqual(clips.filledClips.count, 1, "one clip for the orphan")
        XCTAssertEqual(landing.clip.mediaRef, file.path, "the clip points at the EXISTING file")
        XCTAssertEqual(clips.clip(id: landing.clip.id), landing.clip, "the landing is what the grid holds")
        XCTAssertEqual(timeline.document.regions.map(\.clipID), [landing.clip.id])
        XCTAssertEqual(fileCount(home), filesBefore, "no copy made")
    }

    func testARefusedIdenticalImportLeavesTheLibraryFile() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        let (probe, home) = makeHome()
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
            try? FileManager.default.removeItem(at: probe)
        }
        let file = try write([1, 1, 2, 3, 5], "Keep.wav", in: home)
        let two: (URL) -> AudioImport.Measurement? = { _ in
            AudioImport.Measurement(sampleRate: 44_100, frameCount: 88_200, channelCount: 1)
        }

        // No audio track: refused before anything else — and nothing to clean up.
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        timeline.replaceDocument(TimelineDocument(lanes: [], regions: []))
        guard case .failure(let noLane) = AudioImport.landExisting(
            asset(file, size: 5), clipStore: clips, timeline: timeline, bpm: 120, measure: two) else {
            return XCTFail("a song with no audio track must refuse")
        }
        XCTAssertEqual(noLane, .noAudioLane)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "the refusal leaves the library file")

        // A full grid of OTHER clips: the orphan needs a slot and the transaction refuses.
        let full: [Clip?] = (0..<ClipStore.slotCount).map { i in
            Clip(name: "Other \(i)", kind: .audio, mediaRef: "/x/Media/Audio/Other\(i).wav")
        }
        XCTAssertTrue(clips.replaceSlots(full))
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio)],
                                                  regions: []))
        guard case .failure(let gridFull) = AudioImport.landExisting(
            asset(file, size: 5), clipStore: clips, timeline: timeline, bpm: 120, measure: two) else {
            return XCTFail("a full grid must refuse")
        }
        XCTAssertEqual(gridFull, .clipGridFull)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path),
                      "the transaction deletes 'the copy it made' — here there is none, and the user's file stays")
        XCTAssertTrue(timeline.document.regions.isEmpty, "nothing was placed")
    }

    /// COUNTERWEIGHT — the ordinary import still says "Imported", and a fresh copy is not
    /// reported as a reuse.
    func testAFreshCopyIsNotReportedAsAReuse() throws {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let managed = URL(fileURLWithPath: "/c/Media/Audio/Fresh.wav")
        let planned = AudioImport.plan(
            managed: managed,
            measurement: AudioImport.Measurement(sampleRate: 48_000, frameCount: 240_000, channelCount: 2),
            document: TimelineDocument(lanes: [lane], regions: []),
            freeSlotIndex: 0, bpm: 120)
        guard case .success(let landing) = planned else { return XCTFail("the fixture must plan") }
        XCTAssertFalse(landing.reusedLibraryFile)
        XCTAssertTrue(AudioImport.successNote(landing, laneName: "Audio 1").hasPrefix("Imported "))
    }

    // MARK: 4 — source

    func testTheImportAsksTheLibraryBeforeItCopies() throws {
        let code = try source(Self.importPath)
        let perform = try body(of: "public static func perform(pickedURL:", in: code)
        let scope = try XCTUnwrap(perform.range(of: "startAccessingSecurityScopedResource()"))
        let ask = try XCTUnwrap(perform.range(of: "MediaLibrary.existingAudio(matching: pickedURL)"),
                                "the import must ask the library whether these bytes are already there")
        let reuse = try XCTUnwrap(perform.range(of: "return landExisting("))
        let copy = try XCTUnwrap(perform.range(of: "return commit(pickedURL: pickedURL"),
                                 "COUNTERWEIGHT: a new file still takes the copy transaction")
        XCTAssertLessThan(scope.lowerBound, ask.lowerBound, "the compare reads the picked file — inside the scope")
        XCTAssertLessThan(ask.lowerBound, reuse.lowerBound)
        XCTAssertLessThan(reuse.lowerBound, copy.lowerBound, "the library is asked BEFORE anything is copied")
        XCTAssertTrue(perform.contains("MediaLibrary.importAudio"), "the copy path is unchanged")

        let land = try body(of: "public static func landExisting(", in: code)
        XCTAssertTrue(land.contains("MediaPlacement.place("), "the same decision Place makes (#416)")
        for forbidden in ["removeItem", "importAudio", "clipStore.setClip(", "timeline.addRegion("] {
            XCTAssertFalse(land.contains(forbidden), "the de-dup branch must not contain `\(forbidden)`")
        }

        XCTAssertEqual(try filesUnderSources(containing: "MediaLibrary.existingAudio("),
                       ["Sequencer/AudioImport.swift"], "one production caller of the library question")
        XCTAssertEqual(try filesUnderSources(containing: "landExisting("),
                       ["Sequencer/AudioImport.swift"], "the de-dup branch has one door, the import")

        let library = try source("Sources/Echoelmusic/Core/MediaLibrary.swift")
        let same = try body(of: "static func sameBytes(", in: library)
        XCTAssertTrue(same.contains("read(upToCount: chunkSize)"), "a long file is read in bounded chunks, never whole")
        XCTAssertFalse(same.contains("Data(contentsOf:"), "…and never loaded whole")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

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
