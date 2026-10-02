// B1a (Workstation redesign, 2026-10-01, PLAN_WORKSTATION_REDESIGN_2026-10-01.md item B1): the part
// grid holds more than eight clips, the eight-cell grid every earlier build wrote — on disk AND inside
// a saved piece — opens in it with every clip in the cell it was saved in, and a grid of eight or
// fewer clips is still WRITTEN as the eight-cell file an earlier build reads (rollback keeps it).
//
// WHY THIS IS A MIGRATION AND NOT A NUMBER: `ClipStore.init` threw away any file whose cell count was
// not `slotCount`, and `SessionSaveOpen` refused any piece whose grid was not `slotCount`. Raising the
// constant alone would have emptied every user's grid on first launch and refused every saved piece.
// `ClipStore.migratedGrid` is the ONE migration (#416): pad at the END, refuse a LARGER grid.
// `replaceSlots` stays strict on purpose — `TheSessionReplacesTheSongWholeTests` pins that. The full-
// grid sentence lives in `AudioImport` (glossary-scanned), never in the pure-data store.
//
// KIND OF EVIDENCE (§1), per claim:
//   1–4, 6  END-TO-END BEHAVIOUR on the shipped stores, the shipped migration and the written file.
//   5       SOURCE-TEXT SCAN (which readers ask the migration, where the sentence lives) plus a
//           runtime comparison of both import messages, plus the string catalog.
// No directory walk (#454): every file is read by path, and each read asserts its anchor.
//
// HONEST GRADING against the parent (aea9096f6, §3): this file does NOT COMPILE there — it names
// `ClipStore.migratedGrid`, `ClipStore.legacySlotCount` and `AudioImport.gridFullSentence`, which this
// commit creates. ONE absence (#486); every claim is FORWARD. Counterweights (green on any correct
// tree): `replaceSlots` stays exact, the store's file name and subdirectory, `restoreSong` installs
// through `replaceSlots`, the store speaks no chrome. NOT driven by Python transcription — hand-traced
// only. Mutants to drive before pushing, each with the claim that must go red: init keeps
// `saved.count == Self.slotCount` → 2 · migration truncates instead of refusing → 3, 4 · migration pads
// at the FRONT → 4 · `slotCount` left at 8 → 1 · a literal "8" in either import message → 5 · the
// sentence moved back into ClipStore → 5 · `persist` writes the full grid → 6 · `storedGrid` trims a
// filled cell → 6.
//
// NEEDS-FOUNDER-VERIFY: install this build OVER one that has parts; every part still plays; add more
// than eight parts and imports; Save, then Open that piece; then open a piece saved before this build.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheOldPartGridOpensInTheLargerOneTests: XCTestCase {

    /// The size every pre-B1 build wrote. A LITERAL on purpose: it is a fact about files already on
    /// devices, not a decision this build owns — asking `slotCount` would ask the thing under test.
    private static let legacySlotCount = 8

    private static let take = Project(
        name: "B1 grid", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 96,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "",
        patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
        drumSteps: [], drumAccents: [])

    /// Eight held MIDI clips with notes — never "empty", so no reuse path may take them.
    /// A factory, so each claim gets its own ids (#1419).
    private static func heldClips() -> [Clip] {
        (0..<legacySlotCount).map { i in
            Clip(name: "Held \(i)", colorIndex: i, kind: .midi,
                 melody: MelodyClip(notes: [Note(pitch: 60 + i, startStep: i)]))
        }
    }

    // MARK: 1 — the ninth part lands

    func testANinthPartLandsWhereEightWasTheCeiling() throws {
        XCTAssertGreaterThan(ClipStore.slotCount, Self.legacySlotCount, "B1 premise: the grid grew")
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let held = Self.heldClips()
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        for (i, clip) in held.enumerated() { grid[i] = clip }
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the store takes a full-size grid")
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Keys", kind: .midi)], regions: []))

        guard case .success(let landing) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline,
                                                                selectedTrack: nil, voiceCapacity: 0) else {
            return XCTFail("""
                With eight cells taken, a ninth part was refused — that is the pre-B1 ceiling \
                (`slotCount == 8`). B1 lifts it; founder WA2: the eight slots are compatibility only.
                """)
        }
        XCTAssertEqual(landing.slotIndex, Self.legacySlotCount, "the new clip takes the first free cell — the ninth")
        XCTAssertEqual(Array(clips.slots.prefix(Self.legacySlotCount)), held.map { Optional($0) },
                       "no held clip was overwritten or moved")
        XCTAssertEqual(landing.region.clipID, landing.clip.id, "the new part plays the new clip")
        XCTAssertEqual(clips.clip(id: landing.region.clipID)?.id, landing.clip.id, "and it resolves in the grid")
        XCTAssertEqual(ClipStore().slots, clips.slots, "the grid written to disk reads back as it is")
    }

    // MARK: 2 — an eight-cell file on disk

    func testAnEightCellGridOnDiskLoadsInPlace() throws {
        XCTAssertEqual(ClipStore.legacySlotCount, Self.legacySlotCount, "the store names the size files on devices have")
        let original = ClipStore().slots
        defer { ClipStore().replaceSlots(original) }
        let held = Self.heldClips()
        let legacy: [Clip?] = held.map { Optional($0) }
        XCTAssertEqual(legacy.count, Self.legacySlotCount, "fixture premise: the old size")
        XCTAssertTrue(AppGroupStore(subdirectory: "Clips").save(legacy, name: "clips"),
                      "fixture premise: an eight-cell file is on disk where the store reads it")

        let store = ClipStore()
        XCTAssertEqual(store.slots.count, ClipStore.slotCount, """
            An eight-cell file did not open in the larger grid. Before B1 `init` threw away any file \
            whose count was not `slotCount` — raising the constant without the migration would empty \
            every user's grid on first launch.
            """)
        XCTAssertEqual(Array(store.slots.prefix(Self.legacySlotCount)), legacy,
                       "every held clip in the cell it was saved in")
        XCTAssertTrue(store.slots.dropFirst(Self.legacySlotCount).allSatisfy { $0 == nil }, "the new cells are empty")
        for clip in held {
            XCTAssertEqual(store.clip(id: clip.id), clip, "a part's clip id still resolves")
        }
        XCTAssertEqual(store.firstEmptySlotIndex, Self.legacySlotCount, "and the ninth cell is the first free one")
    }

    // MARK: 3 — a piece saved with eight cells opens; a larger one is refused whole

    func testAPieceSavedWithEightCellsOpensAndALargerOneIsRefused() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let held = Self.heldClips()
        let bar = TimelineTime.ticksPerBar
        let part = TimelineRegion(laneID: lane.id, clipID: held[3].id, startTick: 0, lengthTicks: 4 * bar)
        let song = TimelineDocument(lanes: [lane], regions: [part])
        var legacyGrid = [Clip?](repeating: nil, count: Self.legacySlotCount)
        for (i, clip) in held.enumerated() { legacyGrid[i] = clip }

        let oldRow = SessionSaveOpen.capturing(Self.take, timeline: song, clipSlots: legacyGrid,
                                               songForm: Arrangement(), playerAutomation: [],
                                               sampleRate: 48_000)
        guard case .restorable(let oldSession) = oldRow.readSession() else {
            return XCTFail("fixture premise: the capture wrote a readable Session")
        }
        XCTAssertEqual(oldSession.content.clipSlots.count, Self.legacySlotCount, "fixture premise: an eight-cell envelope")
        XCTAssertNil(SessionSaveOpen.refusal(for: oldRow), "a piece saved before B1 is not refused for its grid size")
        XCTAssertTrue(SessionSaveOpen.restoreSong(of: oldRow, timeline: timeline, clips: clips,
                                                  player: TimelineRegionPlayer()))
        XCTAssertEqual(clips.slots.count, ClipStore.slotCount, "the restored grid is this build's size")
        XCTAssertEqual(Array(clips.slots.prefix(Self.legacySlotCount)), legacyGrid, "every clip in its saved cell")
        let restored = try XCTUnwrap(timeline.document.regions.first, "the part came back")
        XCTAssertEqual(clips.clip(id: restored.clipID), held[3], "and it still finds its clip")

        let before = (timeline.document, clips.slots)
        var newerGrid = [Clip?](repeating: nil, count: ClipStore.slotCount + 1)
        newerGrid[0] = held[0]
        let newerRow = SessionSaveOpen.capturing(Self.take, timeline: song, clipSlots: newerGrid,
                                                 songForm: Arrangement(), playerAutomation: [],
                                                 sampleRate: 48_000)
        let refusal = try XCTUnwrap(SessionSaveOpen.refusal(for: newerRow),
                                    "a grid this build cannot hold is refused, never truncated")
        XCTAssertTrue(refusal.contains("\(ClipStore.slotCount + 1)"), "the refusal names the saved size")
        XCTAssertTrue(refusal.contains("\(ClipStore.slotCount)"), "and this build's size")
        XCTAssertFalse(SessionSaveOpen.restoreSong(of: newerRow, timeline: timeline, clips: clips,
                                                   player: TimelineRegionPlayer()))
        XCTAssertEqual(timeline.document, before.0, "a refused Open changes nothing — the timeline")
        XCTAssertEqual(clips.slots, before.1, "nor the grid")
    }

    // MARK: 4 — the migration itself

    func testTheMigrationPadsAndNeverMovesOrDrops() throws {
        let held = Self.heldClips()
        var exact = [Clip?](repeating: nil, count: ClipStore.slotCount)
        exact[0] = held[0]
        exact[ClipStore.slotCount - 1] = held[1]
        XCTAssertEqual(ClipStore.migratedGrid(exact), exact, "a grid of this build's size comes back unchanged")

        let short: [Clip?] = [nil, held[2], nil, held[3]]
        let padded = try XCTUnwrap(ClipStore.migratedGrid(short), "a shorter grid is migrated, not refused")
        XCTAssertEqual(padded.count, ClipStore.slotCount)
        XCTAssertEqual(Array(padded.prefix(short.count)), short,
                       "padding goes at the END — every cell keeps its index, holes included")
        XCTAssertTrue(padded.dropFirst(short.count).allSatisfy { $0 == nil }, "the added cells are empty")
        XCTAssertEqual(ClipStore.migratedGrid(padded), padded, "migrating twice is migrating once")
        XCTAssertEqual(ClipStore.migratedGrid([]), [Clip?](repeating: nil, count: ClipStore.slotCount))
        XCTAssertNil(ClipStore.migratedGrid([Clip?](repeating: nil, count: ClipStore.slotCount + 1)),
                     "a larger grid is refused, never truncated")
    }

    // MARK: 5 — the three readers ask the one migration; the doors say the real size

    func testTheThreeReadersAskTheOneMigrationAndTheImportsSayTheSize() throws {
        let store = try code("Sources/Echoelmusic/Core/ClipStore.swift")
        let initBody = try member("public init() {", in: store)
        XCTAssertTrue(initBody.contains("Self.migratedGrid(saved)"), "ClipStore.init no longer asks the migration")
        XCTAssertFalse(initBody.contains("saved.count == Self.slotCount"),
                       "ClipStore.init is back to the exact-count check that empties an older grid")
        let replace = try member("public func replaceSlots(_ replacement: [Clip?]) -> Bool {", in: store)
        XCTAssertTrue(replace.contains("guard replacement.count == Self.slotCount else { return false }"),
                      "counterweight: replaceSlots stays exact — padding lives in the migration only")
        let persist = try member("private func persist() {", in: store)
        XCTAssertTrue(persist.contains("Self.storedGrid(slots)"), "persist writes the full grid again — claim 6's premise")
        XCTAssertTrue(store.contains("AppGroupStore(subdirectory: \"Clips\")"), "claims 2/6 fixture premise: the subdirectory")
        XCTAssertTrue(store.contains("fileName = \"clips\""), "claims 2/6 fixture premise: the file name")
        XCTAssertFalse(store.contains("String(localized:"), """
            ClipStore speaks chrome again. The store is pure data, and it is outside the glossary scan \
            (its persisted "clips" name would be a hit) — the full-grid sentence lives in AudioImport.
            """)

        let session = try code("Sources/Echoelmusic/Core/SessionSaveOpen.swift")
        XCTAssertEqual(occurrences(of: "ClipStore.migratedGrid(session.content.clipSlots)", in: session), 2,
                       "refusal AND restoreSong must both ask the migration — one asking alone opens what the other refuses")
        XCTAssertFalse(session.contains("session.content.clipSlots.count == ClipStore.slotCount"),
                       "an exact-count Session check is back")
        XCTAssertTrue(session.contains("guard clips.replaceSlots(song.slots) else { return false }"),
                      "counterweight: the Open still installs through replaceSlots")

        let audio = try code("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        XCTAssertTrue(audio.contains("String(localized: \"The part grid is full — all \") + \"\\(ClipStore.slotCount)\" + String(localized: \" slots are in use.\")"),
                      "the one full-grid sentence is defined in AudioImport, with the store's number")
        for path in ["Sources/Echoelmusic/Sequencer/AudioImport.swift", "Sources/Echoelmusic/Sequencer/MIDIImport.swift"] {
            let text = try code(path)
            XCTAssertEqual(occurrences(of: "return AudioImport.gridFullSentence", in: text), 1,
                           "\(path): the full-grid failure must say the one sentence (#416)")
            XCTAssertFalse(text.contains("all 8"), "\(path): a literal slot count is back")
        }
        XCTAssertEqual(AudioImport.Failure.clipGridFull.userMessage, AudioImport.gridFullSentence)
        XCTAssertEqual(MIDIImport.Failure.clipGridFull.userMessage, AudioImport.gridFullSentence)
        XCTAssertTrue(AudioImport.gridFullSentence.contains("\(ClipStore.slotCount)"), "the sentence states the store's number")

        let catalog = try catalogStrings()
        for key in ["The part grid is full — all ", " slots are in use."] {
            let entry = try XCTUnwrap(catalog[key] as? [String: Any], "ANCHOR MISSING: catalog key `\(key)`")
            let localizations = entry["localizations"] as? [String: Any]
            let english = (localizations?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(english?["state"] as? String, "translated", "`\(key)` has no translated English unit")
            XCTAssertEqual(english?["value"] as? String, key, "`\(key)`: the English unit is the key")
            XCTAssertEqual(Set((localizations ?? [:]).keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
        }
        for retired in ["The part grid is full — all 8 slots are in use.", "The part slots are full — all 8 are in use."] {
            XCTAssertNil(catalog[retired], "the retired key `\(retired)` is still in the catalog")
        }
    }

    // MARK: 6 — eight or fewer clips are written as the file an earlier build reads

    func testAGridOfEightOrFewerClipsIsWrittenAsTheOldFile() throws {
        let clips = ClipStore()
        let original = clips.slots
        defer { clips.replaceSlots(original) }
        let held = Self.heldClips()
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        for (i, clip) in held.enumerated() { grid[i] = clip }
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the store takes a full-size grid")

        let disk = AppGroupStore(subdirectory: "Clips")
        let written = try XCTUnwrap(disk.loadLossyArray(Clip?.self, name: "clips"),
                                    "ANCHOR MISSING: the store wrote no readable file").map { $0 ?? nil }
        XCTAssertEqual(written.count, Self.legacySlotCount, """
            Eight clips were written as \(written.count) cells. Every earlier build throws away a file \
            whose count is not eight, and its next clip write replaces it — a rollback would wipe them.
            """)
        XCTAssertEqual(written, Array(grid.prefix(Self.legacySlotCount)), "each clip in its cell")

        let ninth = Clip(name: "Ninth", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 72, startStep: 0)]))
        clips.setClip(at: Self.legacySlotCount, ninth)
        let grown = try XCTUnwrap(disk.loadLossyArray(Clip?.self, name: "clips"),
                                  "ANCHOR MISSING: the store wrote no readable file").map { $0 ?? nil }
        XCTAssertEqual(grown.count, Self.legacySlotCount + 1, "a ninth clip is written — trimming never drops a filled cell")
        XCTAssertEqual(grown.last.flatMap { $0 }?.id, ninth.id)
        XCTAssertEqual(ClipStore().slots, clips.slots, "and the trimmed file reads back as the whole grid")
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func code(_ path: String) throws -> String {
        let text = try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: \(path) read empty")
        return SourceText.codeOnly(text)
    }

    /// Brace-matched body of the member whose declaration line is `anchor` (which must end in `{`).
    private func member(_ anchor: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: anchor), "ANCHOR MISSING: `\(anchor)`")
        XCTAssertEqual(code.components(separatedBy: anchor).count, 2, "ANCHOR NOT UNIQUE: `\(anchor)` (#408)")
        var depth = 0
        var index = code.index(before: start.upperBound)
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR UNBALANCED: `\(anchor)`")
        return ""
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = repoRoot().appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
                                 "ANCHOR MISSING: the string catalog is not a JSON object")
        return try XCTUnwrap(root["strings"] as? [String: Any], "ANCHOR MISSING: the catalog has no `strings`")
    }
}
