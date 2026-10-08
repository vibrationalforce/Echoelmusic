// AnUnreadableStoreKeepsItsBytesTests.swift
// Echoel — GMMW SH-4 (founder 2026-10-08, "vermeide … abstürze"). A read that cannot use a
// present file used to return nil — or an array with holes — and nothing else. Every caller
// then falls back to an empty or shorter document, and its NEXT save writes that back over
// the file: the one copy of bytes that might still be repaired is gone, and the only trace is
// a log line nobody exports. `AppGroupStore` now copies those bytes beside the file BEFORE the
// read returns (`<name>.json.unreadable-<ms>`, newest three, never the same bytes twice) and
// writes one `store:` line into the diag log.
//
// ⚠️ THE LIMITS FIRST.
// · Nothing RESTORES a copy yet. This guard proves the bytes survive the overwrite; a recovery
//   door is a later slice, and until it exists a kept copy is reachable through a support
//   session, not through the app.
// · The diag-log line is a SOURCE-TEXT SCAN (claim 7): the crash log's file descriptor is
//   private and is not open in every test host, so the line itself cannot be observed here.
// · Claims 1–6 are END-TO-END BEHAVIOUR on the shipped store in a throwaway subdirectory —
//   the same pattern as `AFailedSaveLeavesATraceTests`. Whether the copy is written under
//   real on-device file protection while the phone is locked is a DEVICE PROBE, open.
//
// ⚠️ HONEST GRADING (#433/#464/#486). This file names `unreadableCopies(of:)` and
// `unreadableCopiesKept`, which this commit adds — it does NOT compile against the parent, so
// no assertion has a verdict there. Hand-transcribed instead: a Python model of the store's
// read paths (directory as a dict, the same prefix/stamp/dedupe/prune rules) driven by the
// claims below, against the parent's behaviour and the worktree's.
// · Parent behaviour: claims 1, 2, 3, 5 and 6 are REGRESSIONS — no copy is ever written, so
//   each fails for the reason it names — but they are ONE finding (#486): the store kept
//   nothing. Claim 7 is red there by ANCHOR ABSENCE (`keepUnreadable` does not exist): one
//   absence, not three.
// · Claim 4 is the COUNTERWEIGHT and is green on both: a read that loses nothing keeps
//   nothing, an explicit `null` in an optional grid is not a hole, an absent file is silent.
//   Without it a store that copied on EVERY read would pass claims 1–3.
// · Mutants, each red for its named reason in the model: no copy on decode failure (1), none
//   on holes (2), none on a non-array (3), a copy on every read or a null counted as a hole
//   (4), no dedupe or no prune or oldest-first pruning (5), a `.json` copy name or a listing
//   that leaks another name's copies (6), the call after `return nil`, one keeping call fewer, a
//   silent exit, a crash-marker word, or the copy written without file protection (7).
//
// · `SourceText.codeOnly` is PROPHYLACTIC here, measured: raw and stripped text give the same
//   claim-7 verdict on both trees (0 of 3 findings flip).
//
// Guard of `Sources/Echoelmusic/Core/AppGroupStore.swift`.

import XCTest
@testable import Echoelmusic

private struct KeptStoreAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

/// A minimal strict `Codable`: a missing field really fails, which every broken file below
/// depends on.
private struct Tiny: Codable, Equatable {
    var label: String
    var value: Double
}

final class AnUnreadableStoreKeepsItsBytesTests: XCTestCase {

    private let name = "kept-probe"

    /// One throwaway container per test (the UUID: a simulator container is reused between
    /// local runs, `AutosaveSlotTests`).
    private func throwawayStore(_ tag: String = #function) -> AppGroupStore {
        AppGroupStore(subdirectory: "EchoelTests-kept-\(tag)-\(UUID().uuidString)")
    }

    private func erase(_ store: AppGroupStore, _ names: [String]) {
        for name in names {
            for copy in store.unreadableCopies(of: name) {
                try? FileManager.default.removeItem(at: copy)
            }
            store.delete(name: name)
        }
    }

    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    private func kept(_ store: AppGroupStore, _ name: String) -> [Data?] {
        store.unreadableCopies(of: name).map { try? Data(contentsOf: $0) }
    }

    // MARK: - 1. A document that does not decode survives the save that follows

    func testAFileThatDoesNotDecodeIsKeptBeforeTheNextSaveOverwritesIt() throws {
        let store = throwawayStore()
        defer { erase(store, [name]) }
        let broken = bytes("{\"label\":\"half a song\",\"value\":")
        XCTAssertTrue(store.saveRawForTests(broken, name: name), "precondition: the raw write")

        XCTAssertNil(store.load(Tiny.self, name: name), "the read still gives up — that contract is unchanged")
        XCTAssertEqual(kept(store, name), [broken], """
            the bytes the read could not use must be kept BEFORE it returns — the caller's next \
            save is about to write its fallback over the file
            """)

        // What every caller does next: save the fallback. The kept copy must outlive it.
        let fallback = Tiny(label: "fallback", value: 0)
        XCTAssertTrue(store.save(fallback, name: name))
        XCTAssertEqual(store.load(Tiny.self, name: name), fallback,
                       "precondition: the document really was overwritten")
        XCTAssertEqual(kept(store, name), [broken], "the overwrite must not touch the kept copy")
    }

    // MARK: - 2. A library that drops elements keeps them first

    func testALibraryThatDropsElementsKeepsThemBeforeTheCompactingSave() throws {
        let store = throwawayStore()
        defer { erase(store, [name]) }
        let partly = bytes("[{\"label\":\"a\",\"value\":1},42,{\"label\":\"c\"}]")
        XCTAssertTrue(store.saveRawForTests(partly, name: name))

        let values = try XCTUnwrap(store.loadLossyArray(Tiny.self, name: name))
        XCTAssertEqual(values.count, 3, "precondition: every slot accounted for, holes included")
        let survivors = values.compactMap { $0 }
        XCTAssertEqual(survivors, [Tiny(label: "a", value: 1)], "precondition: two elements are holes")
        XCTAssertEqual(kept(store, name), [partly], """
            two elements did not decode, and the next save writes the array back WITHOUT them — \
            the bounded loss is only bounded if the bytes are kept now
            """)

        XCTAssertTrue(store.save(survivors, name: name))
        XCTAssertEqual(kept(store, name), [partly], "the compacting save must not touch the kept copy")
    }

    // MARK: - 3. A library that is not an array at all is kept too

    func testALibraryThatIsNotAnArrayIsKept() {
        let store = throwawayStore()
        defer { erase(store, [name]) }
        let object = bytes("{\"label\":\"a\",\"value\":1}")
        XCTAssertTrue(store.saveRawForTests(object, name: name))

        XCTAssertNil(store.loadLossyArray(Tiny.self, name: name), "precondition: unreadable as a library")
        XCTAssertEqual(kept(store, name), [object], "the whole file is about to become an empty library")
    }

    // MARK: - 4. COUNTERWEIGHT — a read that loses nothing keeps nothing

    func testAReadThatLosesNothingKeepsNothing() throws {
        let store = throwawayStore()
        defer { erase(store, [name, "grid", "library", "absent"]) }

        XCTAssertNil(store.load(Tiny.self, name: "absent"))
        XCTAssertNil(store.loadLossyArray(Tiny.self, name: "absent"))
        XCTAssertTrue(store.unreadableCopies(of: "absent").isEmpty, "an absent file is 'nothing saved yet', not a loss")

        XCTAssertTrue(store.save(Tiny(label: "ok", value: 1), name: name))
        XCTAssertEqual(store.load(Tiny.self, name: name), Tiny(label: "ok", value: 1))
        XCTAssertTrue(store.unreadableCopies(of: name).isEmpty, "a clean read must not copy")

        XCTAssertTrue(store.save([Tiny(label: "a", value: 1), Tiny(label: "b", value: 2)], name: "library"))
        XCTAssertEqual(try XCTUnwrap(store.loadLossyArray(Tiny.self, name: "library")).count, 2)
        XCTAssertTrue(store.unreadableCopies(of: "library").isEmpty, "a clean library must not copy")

        // `ClipStore`'s grid: an explicit null is an EMPTY SLOT, decoded as a value — not a hole.
        XCTAssertTrue(store.saveRawForTests(bytes("[{\"label\":\"a\",\"value\":1},null,null]"), name: "grid"))
        let slots = try XCTUnwrap(store.loadLossyArray(Tiny?.self, name: "grid")).map { $0 ?? nil }
        XCTAssertEqual(slots, [Tiny(label: "a", value: 1), nil, nil], "precondition: the grid reads whole")
        XCTAssertTrue(store.unreadableCopies(of: "grid").isEmpty, """
            empty grid slots are not lost elements — copying here would fill the container on \
            every launch of an ordinary project
            """)
    }

    // MARK: - 5. The same bytes are kept once; only the newest few stay

    func testTheSameBytesAreKeptOnceAndOnlyTheNewestStay() throws {
        let store = throwawayStore()
        defer { erase(store, [name]) }
        let cap = AppGroupStore.unreadableCopiesKept
        XCTAssertGreaterThan(cap, 0, "a cap of zero keeps nothing — that is this slice undone")

        let first = bytes("{\"label\":\"broken\",\"value\":")
        XCTAssertTrue(store.saveRawForTests(first, name: name))
        for _ in 0..<3 { XCTAssertNil(store.load(Tiny.self, name: name)) }
        XCTAssertEqual(kept(store, name), [first], """
            every launch meets the same broken file again — one copy, not one per launch
            """)

        let later: [Data] = (1...(cap + 1)).map { bytes("{\"label\":\"broken \($0)\",\"value\":") }
        for broken in later {
            XCTAssertTrue(store.saveRawForTests(broken, name: name))
            XCTAssertNil(store.load(Tiny.self, name: name))
        }
        let newestFirst: [Data?] = ([first] + later).reversed().prefix(cap).map { Optional($0) }
        XCTAssertEqual(kept(store, name), newestFirst, """
            the container must hold the NEWEST \(cap) copies, newest first — no copy is unbounded, \
            and the one a person most likely wants is never the one pruned
            """)

        // A byte string that is already among the kept ones adds nothing and moves nothing.
        let alreadyKept = try XCTUnwrap(later.last)
        XCTAssertTrue(store.saveRawForTests(alreadyKept, name: name))
        XCTAssertNil(store.load(Tiny.self, name: name))
        XCTAssertEqual(kept(store, name), newestFirst)
    }

    // MARK: - 6. A kept copy sits beside its file and cannot pass for a live document

    func testAKeptCopyCannotPassForALiveDocument() throws {
        let store = throwawayStore()
        let neighbour = "\(name)-2"
        defer { erase(store, [name, neighbour]) }
        XCTAssertTrue(store.saveRawForTests(bytes("not json"), name: name))
        XCTAssertNil(store.load(Tiny.self, name: name))
        XCTAssertTrue(store.saveRawForTests(bytes("also not json"), name: neighbour))
        XCTAssertNil(store.load(Tiny.self, name: neighbour))

        let copy = try XCTUnwrap(store.unreadableCopies(of: name).first, "precondition: a copy exists")
        XCTAssertEqual(store.unreadableCopies(of: name).count, 1, """
            another document's copies must not be listed as this one's — a recovery door would \
            offer the wrong song
            """)
        XCTAssertTrue(copy.lastPathComponent.hasPrefix("\(name).json"), "the copy is named after its file")
        XCTAssertFalse(copy.lastPathComponent.hasSuffix(".json"), """
            a copy ending in `.json` is a file any listing of the store's documents reads as a \
            live one — the unreadable bytes would come back as a document
            """)
        let beside = copy.deletingLastPathComponent().appendingPathComponent("\(name).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: beside.path), "the copy sits beside the file it keeps")
    }

    // MARK: - 7. SOURCE-TEXT SCAN — the bytes are kept before the read returns, and it is logged

    func testEveryReadThatGivesUpKeepsTheBytesFirst() throws {
        let load = try declarationBody(of: "public func load<T: Decodable>(_ type: T.Type, name: String) -> T? {")
        let caught = try XCTUnwrap(load.range(of: "} catch {"), "load's catch branch")
        let afterCatch = load[caught.upperBound...]
        let keepInLoad = try XCTUnwrap(afterCatch.range(of: "keepUnreadable(data, name: name"),
                                       "the decode failure must keep the bytes")
        let giveUp = try XCTUnwrap(afterCatch.range(of: "return nil"))
        XCTAssertLessThan(keepInLoad.lowerBound, giveUp.lowerBound, "kept BEFORE the read returns, or never")

        let lossy = try declarationBody(
            of: "public func loadLossyArray<T: Decodable>(_ type: T.Type, name: String) -> [T?]? {")
        XCTAssertEqual(lossy.components(separatedBy: "keepUnreadable(data, name: name").count - 1, 2,
                       "the library read gives up two ways — not an array, and holes — and both keep")

        // Every way out of the keeper reaches the diag log — the log is the only place a support
        // session learns that a document fell back to empty. The URL guard is the one silent exit
        // (`fileURL` is never nil today, the store's own header says why).
        let keep = try declarationBody(of: "private func keepUnreadable(_ data: Data, name: String, reason: String) {")
        let urlGuard = try XCTUnwrap(keep.range(of: "else { return }"), "the URL guard")
        var cursor = urlGuard.upperBound
        var exits = 0
        while let exit = keep.range(of: "return", range: cursor..<keep.endIndex) {
            exits += 1
            let opened = try XCTUnwrap(keep[..<exit.lowerBound].range(of: "{", options: .backwards))
            XCTAssertTrue(keep[opened.upperBound..<exit.lowerBound].contains("EchoelCrashLog.breadcrumb("),
                          "early exit \(exits) of the keeper leaves no line in the diag log")
            cursor = exit.upperBound
        }
        XCTAssertGreaterThanOrEqual(exits, 2, "precondition: the already-kept and the failed-copy exits were found")
        let prune = try XCTUnwrap(keep.range(of: "dropFirst(Self.unreadableCopiesKept)"), "the prune")
        XCTAssertTrue(keep[prune.upperBound...].contains("EchoelCrashLog.breadcrumb("),
                      "a copy that WAS kept must say where — the line after the prune")
        XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(keep), """
            a store line must not read as a crash marker — the next launch would offer a crash \
            report for a run that only met a broken file
            """)
        XCTAssertTrue(keep.contains(".completeFileProtection"), """
            a kept copy of a song is the song — it is encrypted at rest exactly like the file it \
            keeps, or the copy is the weak point
            """)
    }

    // MARK: - Source access (house template)

    private func declarationBody(of key: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent("Sources/Echoelmusic/Core/AppGroupStore.swift")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw KeptStoreAnchorMissing(reason: """
                AppGroupStore.swift is missing while the tree is present — re-anchor this scan, \
                do not let it skip (#454).
                """)
        }
        let text = SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
        guard let start = text.range(of: key) else {
            throw KeptStoreAnchorMissing(reason: "AppGroupStore no longer declares `\(key)` — re-anchor.")
        }
        var depth = 0
        var body = ""
        for ch in text[text.index(before: start.upperBound)...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return body
    }
}
