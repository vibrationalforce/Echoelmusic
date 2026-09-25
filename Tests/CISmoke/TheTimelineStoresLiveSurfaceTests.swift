// TheTimelineStoresLiveSurfaceTests.swift
// Echoel — #870. `TimelineStore` declares 58 methods and 42 of them have no caller.
//
// WHY THAT IS NOT A BUG REPORT. The 42 are one coherent set — add/remove/move/resize/split/
// merge region, mute/solo/arm, the per-lane dials, the whole automation API — i.e. the API of
// the arrangement surface that #121 Slice 4 deliberately deleted. The store's DOCUMENT, its
// migration and its save path stayed live; the editing API outlived its UI. That is a
// recorded state, not rot, and the full reasoning (including why the #527 "a persisted
// document can still reach it" argument does NOT apply to mutators) is in the header of
// `Core/TimelineStore.swift`.
//
// ⭐ WHAT THIS FILE ACTUALLY GUARDS, and it is the opposite of what its subject suggests: not
// the dead 42, but the LIVE few. A store method losing its last caller is the invisible
// regression here — the capability does not break loudly, it just stops being reachable and
// joins the pile, and the next census reads "43 caller-less" as if that were always true.
//
// ⛔ AND THIS FILE WAS GREEN FOR THE WRONG REASON FROM #870 UNTIL #1441 — SIX OF ITS TEN
// NAMES, in the BLOCKING bundle. `callsFunction(named:in:)` is deliberately dot-independent
// (see its own note: an extension of the same type is a legitimate caller), so it cannot tell
// WHICH type owns the name it finds. Six of the ten names are declared on a SECOND type, and
// every hit for them was that other type's member:
//   · `persist` — TEN other files declare `private func persist()` (ArrangementStore,
//        AutomationPlayer, ClipStore, FXPresetStore, MixerStore, MoodPresetStore, PatchStore,
//        ProjectStore, TrackFXStore, OSCReceiver). All ten hits were those stores calling
//        their OWN private method. The header here said "called from nine files"; the real
//        count outside this store is ZERO, and it CANNOT be anything else —
//   · ⛔ `persist` and `snapshotForUndo` are `private` ON THE STORE. A `private` member is
//        not visible outside its own file, so "still has a caller outside its own file" was
//        asserting what the LANGUAGE FORBIDS. That is the #367 mirror case at its purest: an
//        assertion that cannot fail for its named reason, passing for a reason other than the
//        one its message states. `testTheSavePathIsCalledFromSeveralPlaces` pinned that same
//        impossibility at a FLOOR of two.
//   · `undo` · `redo` · `snapshotForUndo` — `PianoRollModel` declares all three
//        (`Studio/PianoRollView.swift`).
//   · `healRollSlotAudibility` · `unsilenceRollSlot` — `TimelineDocument` declares both
//        (`Sequencer/Timeline.swift`), and the store's own methods DELEGATE to them, so the
//        hit was the document's member seen from a third file.
//   (`healRollSlotNamingCause` is also declared twice, so it is unprovable by the same rule
//   even though a real external caller happens to exist.)
//
// ⭐ THE REPAIR IS NOT RECEIVER ATTRIBUTION. #666 measured that road: matching call arguments
// against declared labels gave 59 false positives on a correct tree, and adding receiver-type
// attribution cut it to 7 while LOSING all three real positives. Instead the needle's
// SOUNDNESS PRECONDITION is now an asserted claim (claim 1): a name may sit in `liveSurface`
// only while exactly ONE file in `Sources/` declares it. Ambiguity is a RED now, not a silent
// green — which is the thing that would have caught this on the day it was written.
//
// ⛔ NO ASSERTION HERE FORBIDS WORK (#364). Dooring a lane dial is exactly what the founder's
// "mehrere" ask points at, and building it is welcome; the counterweight below goes red on
// that day ON PURPOSE, and its message names the prose that must move with it. Deleting the
// 42 is also a legitimate call — it belongs to the founder, not to a cleanup pass. Claim 4 is
// the same shape: it reds when a name BECOMES provable, and says to move it back.
//
// ⚠️ WHAT THIS FILE CANNOT DO. It reads source text. A caller inside a `#if` that never
// compiles still counts as a caller here, and a call reached only from dead code counts too.
// It proves a NAME is referenced, never that the path runs.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTimelineStoresLiveSurfaceTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"

    /// The methods for which "has a caller outside this store" is PROVABLE by a source scan:
    /// each is declared exactly once in all of `Sources/`, so a hit can only be this store's.
    /// Claim 1 keeps that precondition true; do not add a name without re-checking it.
    private static let liveSurface = [
        "addRegion", "ensureComposerRegion", "flushPendingSave",
        // #C1: the Workstation's warp switch, reached through `AudioWarp.setWarp`.
        "setRegionWarp",
        // #165: the Workstation's Pitch field, reached through `AudioTranspose.setPitch`.
        "setLaneTranspose",
        // WA4.1: the Workstation's track inspector, reached through `TrackMix`
        // (`Studio/TrackInspectorView.swift`). The counterweight below moved from `setLanePan`
        // to `setLaneOctave` in the same commit, exactly as its own message asked.
        "setLaneLevel", "setLanePan", "toggleMute", "toggleSolo", "renameLane",
        // WA4.3: the track's parts under the inspector, reached through `TrackParts`
        // (`Studio/TrackPartsView.swift`). `undo`/`redo` got their first production caller
        // in the same file, but stay in `unprovable`: `PianoRollModel` declares both names too.
        "moveRegion", "duplicateRegion", "removeRegion",
    ]

    /// The six this file used to assert and could not prove (#1441). Kept BY NAME rather than
    /// deleted, because a silent shrink from ten to three reads like six capabilities died —
    /// they did not; the EVIDENCE died. Claim 4 pins that each is still unprovable, so the day
    /// one becomes unambiguous the bundle says so instead of leaving it unmeasured forever.
    private static let unprovable = [
        "persist", "snapshotForUndo", "undo", "redo",
        "healRollSlotAudibility", "unsilenceRollSlot", "healRollSlotNamingCause",
    ]

    // MARK: - The live surface

    /// Claim 1 — THE PRECONDITION, and the assertion whose absence made this file lie for
    /// months. `callsFunction` cannot attribute a hit to a type; it is only sound where the
    /// name is unique in `Sources/`. Assert that uniqueness rather than assuming it.
    func testEveryPinnedNameIsUniqueInTheSources() throws {
        for name in Self.liveSurface {
            let declarers = try filesDeclaring(name)
            XCTAssertEqual(declarers.count, 1, """
                `\(name)` is declared in \(declarers.count) file(s) (\
                \(declarers.joined(separator: ", "))). `liveSurface` needs exactly one, \
                because `callsFunction` is dot-independent and cannot tell whose method it \
                found. With a second declaration, claim 3 below can be satisfied by the OTHER \
                type's member — which is exactly how six names sat here green and unproven \
                from #870 to #1441. Move `\(name)` into `unprovable` in THIS commit, or \
                prove the caller another way; do not relax this count.
                """)
            XCTAssertEqual(declarers.first, Self.storePath, """
                `\(name)` is declared in \(declarers.first ?? "nowhere"), not in the store. \
                A name that moved out of `TimelineStore` is not this file's subject any more.
                """)
        }
    }

    /// Claim 2 — THE LANGUAGE RULE. A `private` member cannot be called from another file, so
    /// demanding an external caller for one is demanding the impossible. `persist` and
    /// `snapshotForUndo` sat in the pinned list for months in exactly that state.
    func testNoPinnedNameIsPrivateOnTheStore() throws {
        let store = SourceText.codeOnly(try rawText(Self.storePath))
        for name in Self.liveSurface {
            XCTAssertFalse(store.contains("private func \(name)("), """
                `TimelineStore.\(name)` is declared `private`, so Swift forbids a caller \
                outside this file — claim 3 below could then only ever pass by matching some \
                OTHER type's same-named member. If the method was deliberately made private, \
                move it out of `liveSurface` in this commit (its callers are now internal, and \
                claim 5's shape is how an internal path gets pinned).
                """)
        }
    }

    /// Claim 3 — the original subject, now standing on claims 1 and 2. Every provable name
    /// still has a caller OUTSIDE the store's own file. Losing one is a capability going
    /// doorless without breaking a build.
    func testEveryLiveStoreMethodStillHasAnExternalCaller() throws {
        XCTAssertFalse(Self.liveSurface.isEmpty,
                       "`liveSurface` is empty — every assertion below would then pass "
                       + "vacuously. An empty list is a finding, never a pass (#454).")
        for name in Self.liveSurface {
            let callers = try filesCalling(name)
            XCTAssertFalse(callers.isEmpty, """
                `TimelineStore.\(name)` no longer has a caller outside its own file. It had \
                one on 2026-08-29, so a capability just went doorless without breaking a \
                build. Either restore the call, or move it into the header's caller-less \
                list in `Core/TimelineStore.swift` IN THIS COMMIT and drop it from \
                `liveSurface` here — an undocumented move is how 42 of them got there.
                """)
        }
    }

    /// Claim 4 — COUNTERWEIGHT (#343) to the shrink. Each retired name is still genuinely
    /// unprovable: either `private` on the store, or declared on a second type. A red here is
    /// GOOD NEWS and a checklist — the name just became measurable, so move it back up into
    /// `liveSurface` and let claim 3 start protecting it.
    func testTheRetiredNamesAreStillUnprovable() throws {
        let store = SourceText.codeOnly(try rawText(Self.storePath))
        for name in Self.unprovable {
            let isPrivate = store.contains("private func \(name)(")
            let declarers = try filesDeclaring(name)
            XCTAssertTrue(isPrivate || declarers.count > 1, """
                `\(name)` is no longer ambiguous: it is not private on the store and exactly \
                one file declares it (\(declarers.joined(separator: ", "))). That means a \
                source scan CAN now prove its caller. Move it from `unprovable` into \
                `liveSurface` above in this commit — leaving it here keeps a live capability \
                unguarded, which is the whole defect #1441 repaired.
                """)
        }
    }

    /// Claim 5 — THE SAVE PATH, pinned where its callers actually are. `persist` is `private`,
    /// so its protection was never an external-caller count; it is the 40-odd call sites
    /// INSIDE the store, one per mutator. A collapse there means most edits stop reaching the
    /// disk — the timeline looks right in memory and is gone after relaunch, which nothing
    /// else in this bundle would notice. A FLOOR, not the measured number: a count is a date.
    func testTheSavePathIsCalledFromEveryMutator() throws {
        let store = SourceText.codeOnly(try rawText(Self.storePath))
        let total = occurrences(of: "persist(", in: store)
        let declaration = occurrences(of: "private func persist(", in: store)
        let calls = total - declaration
        XCTAssertGreaterThanOrEqual(calls, 20, """
            `TimelineStore.persist` is called from \(calls) site(s) inside the store. It was \
            46, one per mutating path. A collapse to a handful means most edits no longer \
            reach the disk. ⚠️ Do NOT repair a red here by pinning an EXTERNAL caller count \
            instead — `persist` is private, that number is structurally zero, and pretending \
            otherwise is what this file did until #1441.
            """)
        XCTAssertEqual(declaration, 1, """
            `private func persist(` appears \(declaration) time(s) in the store — the call \
            count above subtracts exactly one declaration, so any other number makes it wrong.
            """)
    }

    // MARK: - Counterweight (#343) — the dead half must still be dead, or the header is stale

    /// ONE representative of the caller-less set, not all of them (#486: one absence is one
    /// finding, and forty assertions of the same absence is noise that hides the one that
    /// matters). ⭐ This was `setLanePan` until WA4.1 doored the lane mixer — the red this
    /// method promised arrived "for a GOOD reason", and pan joined `liveSurface`. The
    /// representative is now `setLaneOctave`: still a per-lane dial, still caller-less, the
    /// next one a track surface would door. ⚠️ It is unique in `Sources/`, which is what makes
    /// the scan sound; claim 6 pins that.
    func testTheLaneDialsAreStillUnreachable() throws {
        let callers = try filesCalling("setLaneOctave")
        XCTAssertTrue(callers.isEmpty, """
            `TimelineStore.setLaneOctave` now has a caller: \(callers.joined(separator: ", ")). \
            If a lane surface was built, this red is CORRECT and welcome — it is not an \
            objection. It is a checklist: the header of `Core/TimelineStore.swift` says 42 \
            methods have no caller and names the per-lane dials among them, so that block \
            moves in this same commit, and this method joins `liveSurface` above.
            """)
    }

    /// Claim 6 — the counterweight's OWN precondition. An absence claim over an ambiguous name
    /// is the mirror of the defect above: `XCTAssertTrue(callers.isEmpty)` would go red for a
    /// foreign type's caller and read as "the lane dial got a door". Same rule, other polarity.
    func testTheCounterweightNameIsUniqueToo() throws {
        let declarers = try filesDeclaring("setLaneOctave")
        XCTAssertEqual(declarers, [Self.storePath], """
            `setLaneOctave` is declared in \(declarers.joined(separator: ", ")) — the absence \
            claim above needs it unique to `TimelineStore`, or a same-named member elsewhere \
            turns that assertion red without any lane surface existing.
            """)
    }

    /// The header's claim rests on the declarations actually existing. If the file were
    /// gutted, every assertion above would pass vacuously on an empty set (#343).
    func testTheStoreStillDeclaresAWholeEditingAPI() throws {
        let text = SourceText.codeOnly(try rawText(Self.storePath))
        let declarations = text.components(separatedBy: "func ").count - 1
        XCTAssertGreaterThan(declarations, 40, """
            `TimelineStore` now declares only \(declarations) methods. The header records 59 \
            declarations under 58 names (`moveRegion` is overloaded), 42 of them caller-less; \
            a large drop means someone took the deletion decision that the header says \
            belongs to the founder. If that was deliberate, rewrite the header block — do not \
            lower this threshold to match.
            """)
    }

    // MARK: - Reading the source

    /// Files under `Sources/` OTHER than the store itself that name `name(` in CODE.
    /// Dot-independent on purpose: a caller could be an extension of the same type.
    /// ⚠️ That choice is why claim 1 exists — it also means the scan cannot tell WHOSE method
    /// it found, so it is only sound for a name that is unique in `Sources/`.
    private func filesCalling(_ name: String) throws -> [String] {
        try scanSources(skippingStore: true) { Self.callsFunction(named: name, in: $0) }
    }

    /// Files under `Sources/` — INCLUDING the store — that DECLARE `func name(`. This is what
    /// makes the caller scan sound: one declarer, and every hit above is necessarily its.
    private func filesDeclaring(_ name: String) throws -> [String] {
        try scanSources(skippingStore: false) { $0.contains("func \(name)(") }
    }

    private func scanSources(skippingStore: Bool,
                             _ matches: (String) -> Bool) throws -> [String] {
        let root = try repoRoot()
        let sources = root.appendingPathComponent(Self.sourcesRoot)
        guard FileManager.default.fileExists(atPath: sources.path), let walker = FileManager.default.enumerator(atPath: sources.path) else {
            throw XCTSkip("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let isStore = relative.hasSuffix("Core/TimelineStore.swift")
            if skippingStore, isStore { continue }
            guard let text = try? String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if matches(SourceText.codeOnly(text)) {
                hits.append(isStore ? Self.storePath : relative)
            }
        }
        return hits.sorted()
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var start = text.startIndex
        while let found = text.range(of: needle, range: start..<text.endIndex) {
            count += 1
            start = found.upperBound
        }
        return count
    }

    /// `code.contains("undo(")` is TRUE for `canUndo(` — a substring needle would have
    /// reported a caller that does not exist, and for the counterweight below the same class
    /// of error reports a door that was never built. So the character before the name must
    /// not be an identifier character. (#679/#738: an invented needle that cannot match its
    /// target is the same defect as one that matches too much.)
    private static func callsFunction(named name: String, in code: String) -> Bool {
        var searchStart = code.startIndex
        while let found = code.range(of: "\(name)(", range: searchStart..<code.endIndex) {
            if found.lowerBound == code.startIndex { return true }
            let before = code[code.index(before: found.lowerBound)]
            if !(before.isLetter || before.isNumber || before == "_") { return true }
            searchStart = found.upperBound
        }
        return false
    }

    private func rawText(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("\(relativePath) not readable at \(url.path) — source scan skipped")
        }
        return text
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
