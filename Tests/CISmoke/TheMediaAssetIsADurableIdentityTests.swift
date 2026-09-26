// TheMediaAssetIsADurableIdentityTests.swift
// Echoel — MA4.1 (founder media decision 2026-09-26: "MediaAsset = durable media/source
// identity"; plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md` §MA4).
//
// WHAT IT PINS. `MediaAssetRecord` is the durable identity of one managed file: a stable id, a
// binding (the file name in its kind's home), provenance and measured evidence. This slice builds
// the value type and moves the one length rule into it (MA4.1); MA4.2–4.6 added the registry, the
// Clip link, the import write, library adoption and the relink move — claims 5–10 below; MA4.4
// the SHA-256 content evidence — claim 11.
//
// 1. END-TO-END BEHAVIOUR (shipped, pure value type): the DIGEST decides identity when both sides
//    have one — equal is `sameContent`, different is `differentContent` EVEN AT THE SAME LENGTH;
//    without a comparable digest the verdict is only `compatibleDuration` / `differentDuration`,
//    never identity; nothing measurable is `unmeasured`; a malformed digest is not comparable;
//    digests of two DIFFERENT algorithms fall back to the length, and the hex is case-blind.
// 2. END-TO-END + SOURCE-TEXT SCAN: the length rule has ONE definition. `MediaRelink.sameLength`
//    agrees with `MediaAssetRecord.compatibleDuration` over a grid, and the tolerance literal
//    occurs once in `Sources/`, in the record's file (#416).
// 3. END-TO-END: Codable — a round trip is lossless; a record missing its evidence, provenance or
//    kind keeps its id and binding; a record without an id does not decode; an unknown kind
//    decodes with no key (no listing can show it).
// 4. SOURCE-TEXT SCAN (counterweight): the record touches no file and stores no availability,
//    placement or tempo, and its file imports Foundation only.
// 5. END-TO-END (MA4.2, `MediaAssetStore`): one record per id, a name answers the newest, an empty
//    binding is refused; one damaged element on disk is dropped and the rest survive; a
//    registration persists.
// 6. END-TO-END (MA4.2): `AudioImport.assetRecord` binds the managed copy's name and keeps the
//    picked name as provenance, with no digest; over REAL `ClipStore`/`TimelineStore` a refused
//    import registers nothing, a landed one registers ONE record whose id the clip carries in the
//    grid, and `assets: .unlinked` is the pre-MA4.2 transaction. The clip codec keeps the link, an old
//    clip has none, a damaged link costs only the link.
// 7. SOURCE-TEXT SCAN (MA4.2/4.3/4.5/4.4): the landing transaction and the relink's step D are the
//    registry's two REGISTERING writers and the song's relink step its one REBINDING writer, the app
//    constructs and injects it, the Workstation's import and the browser's Place hand it on, the
//    copy path mints a fresh record and the placement adopts, and no argument is defaulted.
// 8. END-TO-END (MA4.3, real stores): a library file placed as a new clip links the record bound
//    to its name; a record whose LENGTH contradicts the file is refuted and a new one adopted (the
//    old keeps its id); a record with no measurement cannot refute; a file without a record gets
//    exactly one; a reuse rewrites nothing; a FRESH COPY never adopts a same-name, same-length
//    record. `isContradicted` is driven directly, digest included.
// 9. END-TO-END (MA4.5 + MA4.4, real stores): a relink of a linked clip checks the chosen file
//    against the RECORD (which can refuse where the clip alone could not — a clip that never
//    learned its length). A shared record MOVES only on proven content (A: equal SHA-256) — with
//    its id, the clip keeps its link, ONE Undo moves both back, Redo forward. Another digest is
//    refused (B). No digest (D) moves nothing: the chosen file gets its own record. A link the
//    registry does not hold adopts the file's own record (C). The writer refuses a move of
//    another record; `recordRefusal` refutes, never confirms.
// 10. END-TO-END (founder §7, real stores): Projects A and B share record X, B relinks — matching
//    digest repairs X's binding with X's evidence unchanged; a different digest is refused; a
//    target that owns a record keeps it and X does not move (both with and without a digest,
//    pinning the step ORDER); a legacy Y without a digest never moves on duration, with or
//    without a candidate digest; a refuted own record is not adopted. Project A's clip and X's
//    evidence are asserted after every case.
// 11. END-TO-END + SOURCE-TEXT SCAN (MA4.4): the persisted digest is `"sha256:" + 64 hex` (the
//    standard vectors, chunked = whole, a >2 MiB file streamed = one-shot); cancellation stops
//    before the next chunk; the registry only ADDS a digest, never overwrites; `learn` hashes a
//    record once, drops failures and malformed results; the relink hashes only when the record
//    has a digest, never on a wrong length or under a playing song (asked again after the hash),
//    and a failed hash is `.unreadable`. Scans: learning only in the Workstation's own digest
//    task (records the landing MINTED only — MA4.4c; never inside the cancellable analysis task), file hashing only there and in the relink, nothing at launch, chunked reads, a
//    detached utility task, CryptoKit behind its guard.
//
// MA4.4 GRADING against `c6d39b7c3`: does not compile there (`MediaContentDigest`,
// `learnDigest`, `relink(…candidateDigest:)`, `relinkProvingContent`, `.songPlaying` are new) —
// one absence (#486). Claim 11 is FORWARD. Claims 9 and 10 changed MEANING: on that tree the
// digestless relinks moved the shared record on a name match and a compatible length — the
// founder's 2026-09-26 law makes those REGRESSIONS now (they are cases D and "legacy" here).
// Claim 7's needles follow the async browser door. Device probes: a relink of a large file shows
// no hitch; an import's digest appears in `MediaAssets/assets.json` after the import settles.
//
// MA4.5 REVIEW GRADING against `9bed36874`: does not compile there (`RelinkIdentity`,
// `relinkClipSource(…identity:)`) — one absence (#486). Claim 10 is FORWARD; on that tree's
// logic its MED-1 and MED-2 cases would be REGRESSIONS (the record moved in both). Claim 9's
// foreign-link case changed meaning (released → adopts the file's record); claim 7's two new
// needles are FORWARD. Claim 8's L2/L4 additions (`31aa7f3a7`: picked-name provenance, a blank
// record learns the measurement) were FORWARD there; the learn step now also keeps a digest.
//
// MA4.5 GRADING against `7a38af018`: does not compile there (`Rebinding`, `rebind`,
// `recordRefusal`, `relink(…assets:)` are new) — one absence (#486); claim 9 is FORWARD.
//
// MA4.3 GRADING against `bcaeea552`: the file does not compile there (`AssetIdentity`,
// `isContradicted`, `place(…assets:)` are new) — one absence (#486). Claim 8 is a FORWARD guard;
// claim 7's new needles are FORWARD; claims 1–6 are unchanged apart from the argument spelling.
//
// MA4.2 GRADING against `965f5cb8e`: this file does not compile there (`MediaAssetStore`,
// `assetRecord`, `mediaAssetID` and `commit(…assets:)` are new) — one absence (#486); claims 5–7
// are FORWARD guards. Device probes (not coverable here): an import on a device writes
// `MediaAssets/assets.json` and relaunch keeps the link.
//
// GRADING against the parent (`bb5a1a534`): this file does NOT compile there —
// `MediaAssetRecord` is new, so no assertion has a verdict (one absence, #486). Claims 1, 3 and
// 4 are FORWARD guards. Claim 2's scan would be green-by-count on the parent (the literal sat once,
// in `MediaRelink`) and is red there only by its FILE assertion — a regression guard for the move,
// not for behaviour. Graded by transcription (§0); device probes: none apply.

import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import Echoelmusic

@MainActor
final class TheMediaAssetIsADurableIdentityTests: XCTestCase {

    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let recordFile = "Sources/Echoelmusic/Core/MediaAssetRecord.swift"

    private func evidence(seconds: Double, digest: String? = nil) -> MediaAssetRecord.Evidence {
        MediaAssetRecord.Evidence(byteSize: 1_000, sampleRate: 48_000,
                                  frameCount: Int64((seconds * 48_000).rounded()),
                                  channelCount: 2, contentDigest: digest)
    }

    private func record(seconds: Double, digest: String? = nil) -> MediaAssetRecord {
        MediaAssetRecord(kind: .audio, fileName: "loop.wav", originalName: "Loop.wav",
                         importedAt: Date(timeIntervalSince1970: 1_000),
                         evidence: evidence(seconds: seconds, digest: digest))
    }

    // MARK: 1 — identity is the digest, compatibility is the length

    func testTheDigestDecidesIdentityAndTheLengthOnlyCompatibility() {
        let known = record(seconds: 8, digest: "sha256:aa")

        XCTAssertEqual(known.match(evidence(seconds: 8, digest: "sha256:aa")), .sameContent)
        XCTAssertEqual(known.match(evidence(seconds: 8, digest: "sha256:bb")), .differentContent,
                       "two recordings of the same length are two sources once both are hashed")

        // No comparable digest on one side: only a compatibility verdict, never identity.
        XCTAssertEqual(known.match(evidence(seconds: 8.04)), .compatibleDuration)
        XCTAssertEqual(record(seconds: 8).match(evidence(seconds: 8.04, digest: "sha256:aa")),
                       .compatibleDuration)
        XCTAssertEqual(known.match(evidence(seconds: 8.2)), .differentDuration)

        // Malformed digests are not comparable, so they fall back to the length.
        XCTAssertEqual(record(seconds: 8, digest: "sha256:").match(evidence(seconds: 8, digest: "sha256:")),
                       .compatibleDuration)
        XCTAssertEqual(record(seconds: 8, digest: "aa").match(evidence(seconds: 8, digest: "aa")),
                       .compatibleDuration)

        // Review of ec2ad04a9 (MED): the algorithm is part of the digest. Two algorithms say
        // nothing about each other, a case difference in the hex is the same bytes, and an
        // empty algorithm is no digest.
        XCTAssertEqual(known.match(evidence(seconds: 8, digest: "blake3:aa")), .compatibleDuration,
                       "a digest of another algorithm must not read as another file")
        XCTAssertEqual(known.match(evidence(seconds: 8, digest: "SHA256:AA")), .sameContent)
        XCTAssertEqual(record(seconds: 8, digest: ":aa").match(evidence(seconds: 8, digest: ":bb")),
                       .compatibleDuration)

        // Nothing measurable and nothing to compare.
        XCTAssertEqual(record(seconds: 0).match(evidence(seconds: 8)), .unmeasured)
        XCTAssertEqual(record(seconds: 8).match(evidence(seconds: 0)), .unmeasured)
        let nanRate = MediaAssetRecord.Evidence(byteSize: 1, sampleRate: .nan, frameCount: 10,
                                                channelCount: 1)
        XCTAssertEqual(nanRate.durationSeconds, 0, "a non-finite rate is no length, never NaN")
    }

    // MARK: 2 — one length rule

    func testTheLengthRuleHasOneDefinition() throws {
        let lengths: [Double] = [0, 0.04, 1, 4.99, 5, 8, 8.04, 8.2, 60, 60.5, 61, .nan, .infinity]
        for a in lengths {
            for b in lengths {
                XCTAssertEqual(MediaRelink.sameLength(a, b),
                               MediaAssetRecord.compatibleDuration(a, b),
                               "relink and record disagree on \(a) vs \(b)")
            }
        }
        XCTAssertTrue(MediaAssetRecord.compatibleDuration(8.0, 8.04))
        XCTAssertTrue(MediaAssetRecord.compatibleDuration(60.0, 60.5))
        XCTAssertFalse(MediaAssetRecord.compatibleDuration(8.0, 8.2))
        XCTAssertFalse(MediaAssetRecord.compatibleDuration(.nan, 8.0))

        let files = try filesUnderSources(containing: "Swift.max(0.05, 0.01")
        XCTAssertEqual(files, ["Core/MediaAssetRecord.swift"],
                       "the relink tolerance must have one home, the durable record (#416)")
    }

    // MARK: 3 — Codable keeps the identity

    func testTheIdentitySurvivesADamagedRecord() throws {
        let original = record(seconds: 8, digest: "sha256:aa")
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(MediaAssetRecord.self, from: data), original)

        let id = UUID()
        let damaged = """
        {"id":"\(id.uuidString)","fileName":"loop.wav","evidence":"not an object"}
        """
        let kept = try JSONDecoder().decode(MediaAssetRecord.self, from: Data(damaged.utf8))
        XCTAssertEqual(kept.id, id)
        XCTAssertEqual(kept.fileName, "loop.wav")
        XCTAssertEqual(kept.originalName, "loop.wav", "provenance falls back to the binding")
        XCTAssertEqual(kept.kind, .audio)
        XCTAssertEqual(kept.evidence.durationSeconds, 0)
        XCTAssertNil(kept.evidence.contentDigest)

        let anonymous = #"{"fileName":"loop.wav"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(MediaAssetRecord.self, from: Data(anonymous.utf8)),
                             "a record without an id is nothing")
        let unbound = "{\"id\":\"\(id.uuidString)\"}"
        XCTAssertThrowsError(try JSONDecoder().decode(MediaAssetRecord.self, from: Data(unbound.utf8)),
                             "a record without a binding is nothing")

        let future = "{\"id\":\"\(id.uuidString)\",\"fileName\":\"clip.mov\",\"kindRaw\":\"video\"}"
        let foreign = try JSONDecoder().decode(MediaAssetRecord.self, from: Data(future.utf8))
        XCTAssertNil(foreign.kind)
        XCTAssertNil(foreign.key, "a kind this build cannot use gets no listing key")
        XCTAssertEqual(original.key, MediaAsset.Key(kind: .audio, fileName: "loop.wav"))
    }

    // MARK: 4 — a record describes the source, never a use of it

    func testTheRecordTouchesNoFileAndHoldsNoUse() throws {
        let code = try source(Self.recordFile)
        for forbidden in ["FileManager", "fileExists", "contentsOf", "isAvailable",
                          "laneID", "Tick", "nativeBPM", "automation", "Region"] {
            XCTAssertFalse(code.contains(forbidden),
                           "MediaAssetRecord must not touch files or hold placement/tempo: \(forbidden)")
        }
        let imports = code.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"])
        XCTAssertTrue(code.contains("public var evidence: Evidence"),
                      "anchor: the stored evidence the verdicts read")
    }

    // MARK: 5 — MA4.2: the registry

    func testTheRegistryKeepsOneRecordPerIdAndAnswersTheNewestForAName() {
        let assets = MediaAssetStore(store: nil)
        XCTAssertTrue(assets.records.isEmpty)

        let first = record(seconds: 8)
        XCTAssertTrue(assets.register(first))
        XCTAssertEqual(assets.record(id: first.id), first)
        XCTAssertEqual(assets.record(boundTo: MediaAsset.Key(kind: .audio, fileName: "loop.wav")), first)

        // Same id: replaced in place, never duplicated.
        var hashed = first
        hashed.evidence.contentDigest = "sha256:aa"
        XCTAssertTrue(assets.register(hashed))
        XCTAssertEqual(assets.records.count, 1)
        XCTAssertEqual(assets.record(id: first.id)?.evidence.contentDigest, "sha256:aa")

        // Same name, new id: both kept (a clip linked to the old id is not rewritten), and the
        // name answers the newest.
        let newer = record(seconds: 12)
        XCTAssertTrue(assets.register(newer))
        XCTAssertEqual(assets.records.count, 2)
        XCTAssertEqual(assets.record(boundTo: MediaAsset.Key(kind: .audio, fileName: "loop.wav"))?.id,
                       newer.id)
        XCTAssertEqual(assets.record(id: first.id)?.id, first.id)

        // No binding, no record.
        let unbound = MediaAssetRecord(kind: .audio, fileName: "", originalName: "x",
                                       importedAt: Date(timeIntervalSince1970: 0),
                                       evidence: evidence(seconds: 1))
        XCTAssertFalse(assets.register(unbound))
        XCTAssertNil(assets.record(id: unbound.id))
    }

    func testTheRegistryDropsOneDamagedRecordAndKeepsTheRest() throws {
        let disk = AppGroupStore(subdirectory: "MediaAssetsGuard-\(UUID().uuidString)")
        defer { disk.delete(name: "assets") }
        let good = record(seconds: 8, digest: "sha256:aa")
        let goodJSON = try XCTUnwrap(String(data: try JSONEncoder().encode(good), encoding: .utf8))
        XCTAssertTrue(disk.saveRawForTests(Data("[\(goodJSON), 42, {\"fileName\":\"x.wav\"}]".utf8),
                                           name: "assets"))

        let reloaded = MediaAssetStore(store: disk)
        XCTAssertEqual(reloaded.records, [good], "one damaged element must not take the others down")

        XCTAssertTrue(reloaded.register(record(seconds: 4)))
        XCTAssertEqual(MediaAssetStore(store: disk).records.count, 2, "a registration persists")
    }

    // MARK: 6 — MA4.2: the import establishes identity

    func testTheImportRegistersTheCopyAndTheClipCarriesItsID() throws {
        let measured = AudioImport.Measurement(sampleRate: 44_100, frameCount: 441_000, channelCount: 2)
        let managed = URL(fileURLWithPath: "/tmp/Media/Audio/Loop 2.wav")
        let built = AudioImport.assetRecord(managed: managed, originalName: "Loop.wav",
                                            measurement: measured, byteSize: 1_764_044,
                                            importedAt: Date(timeIntervalSince1970: 5))
        XCTAssertEqual(built.fileName, "Loop 2.wav", "the binding is the managed copy's name")
        XCTAssertEqual(built.originalName, "Loop.wav", "provenance is the picked name")
        XCTAssertEqual(built.kind, .audio)
        XCTAssertEqual(built.evidence.durationSeconds, 10, accuracy: 1e-9)
        XCTAssertEqual(built.evidence.channelCount, 2)
        XCTAssertEqual(built.evidence.byteSize, 1_764_044)
        XCTAssertNil(built.evidence.contentDigest, "hashing is never part of the import transaction")
        XCTAssertEqual(AudioImport.assetRecord(managed: managed, originalName: "", measurement: measured,
                                               byteSize: 0, importedAt: Date()).originalName,
                       "Loop 2.wav", "an empty picked name falls back to the binding")

        // END-TO-END over the real stores, the way the journey guard drives them.
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }
        timeline.replaceDocument(TimelineDocument(lanes: [], regions: []))
        AudioImport.addAudioTrack(timeline: timeline)
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        let assets = MediaAssetStore(store: nil)
        let picked = URL(fileURLWithPath: "/tmp/picked/Loop.wav")
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("ma42-\(UUID().uuidString).wav")

        let refused = AudioImport.commit(pickedURL: picked, clipStore: clips, timeline: timeline,
                                         bpm: 120, importFile: { _ in copy }, measure: { _ in nil },
                                         deleteManagedCopy: { _ in }, assets: .freshCopy(assets))
        guard case .failure = refused else { return XCTFail("an unreadable copy must be refused") }
        XCTAssertTrue(assets.records.isEmpty, "a refused import registers nothing")

        let result = AudioImport.commit(pickedURL: picked, clipStore: clips, timeline: timeline,
                                        bpm: 120, importFile: { _ in copy }, measure: { _ in measured },
                                        deleteManagedCopy: { _ in }, assets: .freshCopy(assets))
        guard case .success(let landing) = result else { return XCTFail("import failed: \(result)") }
        let id = try XCTUnwrap(landing.clip.mediaAssetID, "the landed clip carries its asset id")
        let registered = try XCTUnwrap(assets.record(id: id), "the id names a registered record")
        XCTAssertEqual(registered.fileName, copy.lastPathComponent)
        XCTAssertEqual(registered.originalName, "Loop.wav")
        XCTAssertEqual(registered.evidence.durationSeconds, 10, accuracy: 1e-9)
        XCTAssertEqual(clips.clip(id: landing.clip.id)?.mediaAssetID, id, "the grid holds the link")
        XCTAssertEqual(assets.records.count, 1)

        // Without a registry the import is exactly the pre-MA4.2 transaction.
        let legacy = AudioImport.commit(pickedURL: picked, clipStore: clips, timeline: timeline,
                                        bpm: 120, importFile: { _ in copy }, measure: { _ in measured },
                                        deleteManagedCopy: { _ in }, assets: .unlinked)
        guard case .success(let plain) = legacy else { return XCTFail("legacy import failed") }
        XCTAssertNil(plain.clip.mediaAssetID)
    }

    func testTheLinkSurvivesTheClipCodecAndAnOldClipHasNone() throws {
        let linked = Clip(name: "Loop", kind: .audio, mediaRef: "/x/Loop.wav", mediaAssetID: UUID(),
                          nativeDurationSeconds: 8)
        let decoded = try JSONDecoder().decode(Clip.self, from: try JSONEncoder().encode(linked))
        XCTAssertEqual(decoded.mediaAssetID, linked.mediaAssetID)

        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Loop","kind":"audio","mediaRef":"/x/Loop.wav"}"#
        XCTAssertNil(try JSONDecoder().decode(Clip.self, from: Data(old.utf8)).mediaAssetID,
                     "a clip written before MA4.2 decodes without a link and plays by mediaRef")
        let damaged = #"{"name":"Loop","kind":"audio","mediaRef":"/x/Loop.wav","mediaAssetID":7}"#
        let survived = try JSONDecoder().decode(Clip.self, from: Data(damaged.utf8))
        XCTAssertNil(survived.mediaAssetID)
        XCTAssertEqual(survived.mediaRef, "/x/Loop.wav", "a damaged link costs the link, not the clip")
    }

    // MARK: 7 — MA4.2: one writer, wired at the one door

    func testTheImportDoorHandsTheRegistryToTheOneWriter() throws {
        XCTAssertEqual(try filesUnderSources(containing: "registry.register("), ["Sequencer/AudioImport.swift"],
                       "the landing transaction registers through its `registry`")
        // MA4.4 review L2: the registry has TWO registering writers since step D — measured by the
        // store's own method name, not by one caller's variable name (#867: a needle on
        // `registry.` could never see `assets.register(`).
        XCTAssertEqual(try filesUnderSources(containing: ".register(created)"), ["Sequencer/MediaRelink.swift"],
                       "the relink registers the chosen file's own record (step D), nowhere else")
        XCTAssertEqual(try filesUnderSources(containing: "assets.register("), ["Sequencer/MediaRelink.swift"],
                       "no other caller spells a registration through an `assets` store")
        XCTAssertEqual(try filesUnderSources(containing: ".register(candidate)"), ["Sequencer/AudioImport.swift"],
                       "…through `establishIdentity`, and nowhere else")
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("@State private var mediaAssetStore = MediaAssetStore()"))
        XCTAssertTrue(app.contains(".environment(mediaAssetStore)"))
        let door = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(door.contains("@Environment(MediaAssetStore.self) private var mediaAssets"))
        XCTAssertTrue(door.contains("assets: mediaAssets,"),
                      "the Workstation's import hands the registry to the transaction")
        let importer = try source("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        XCTAssertTrue(importer.contains("assets: .freshCopy(assets))"),
                      "perform's copy path registers a NEW record for the new bytes")
        XCTAssertTrue(importer.contains("measure: measureWithAVFoundation, assets: assets)"),
                      "perform's de-dup branch hands the registry to the placement (MA4.3)")
        for defaulted in ["assets: MediaAssetStore? =", "assets: MediaAssetStore =", "assets: AssetIdentity ="] {
            XCTAssertFalse(importer.contains(defaulted), "`\(defaulted)`: the argument is required (#431)")
        }
        let placement = try source("Sources/Echoelmusic/Sequencer/MediaPlacement.swift")
        XCTAssertTrue(placement.contains("assets.map { .libraryFile($0) } ?? .unlinked"),
                      "a new clip for a library file adopts that file's record (MA4.3)")
        XCTAssertTrue(placement.contains("assets: identity)"))
        XCTAssertFalse(placement.contains(".freshCopy("),
                       "a placement never mints a fresh-copy record for a file that is already in the library")
        XCTAssertFalse(placement.contains("assets: MediaAssetStore? ="), "required (#431)")
        let browser = try source("Sources/Echoelmusic/Studio/MediaBrowserView.swift")
        XCTAssertTrue(browser.contains("@Environment(MediaAssetStore.self) private var mediaAssets"))
        XCTAssertTrue(browser.contains("assets: mediaAssets, bpm: player.preflightTempo)"),
                      "the browser's Place hands the registry to the placement")
        XCTAssertTrue(browser.contains("assets: mediaAssets,\n"),
                      "the browser's Relink hands the registry to the relink (MA4.5)")
        XCTAssertTrue(browser.contains("isSongPlaying: { player.isPlaying })"),
                      "…and asks, after any hash, whether the song started (M3)")
        let relink = try source("Sources/Echoelmusic/Sequencer/MediaRelink.swift")
        XCTAssertTrue(relink.contains("recordRefusal(linked, measurement: measurement, contentDigest: candidateDigest)"),
                      "the record refutes the chosen file by digest when one was computed (MA4.4)")
        XCTAssertTrue(relink.contains("identity: identity,"),
                      "what the clip links is decided once and handed to the song's one relink step")
        XCTAssertTrue(relink.contains("return .adopt(own.id)"),
                      "the chosen file's own record comes first (MA4.5 review MED-2)")
        XCTAssertEqual(try filesUnderSources(containing: ".rebind(id:"), ["Core/TimelineStore.swift"],
                       "the record's binding moves only inside the undoable relink step")
    }

    // MARK: 8 — MA4.3: a library file has ONE identity

    func testALibraryFileAdoptsItsRecordAndAFreshCopyNeverDoes() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }
        func reset() {
            timeline.replaceDocument(TimelineDocument(lanes: [], regions: []))
            AudioImport.addAudioTrack(timeline: timeline)
            XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        }
        let tenSeconds = AudioImport.Measurement(sampleRate: 44_100, frameCount: 441_000, channelCount: 2)
        let library = URL(fileURLWithPath: "/tmp/ma43/Media/Audio/Loop.wav")
        let asset = MediaAsset(kind: .audio, fileName: "Loop.wav", url: library, byteSize: 0)
        func record(seconds: Double, name: String = "Loop.wav") -> MediaAssetRecord {
            MediaAssetRecord(kind: .audio, fileName: name, originalName: "Loop (picked).wav",
                             importedAt: Date(timeIntervalSince1970: 1), evidence: evidence(seconds: seconds))
        }
        // MA4.4c: whether the last placement MINTED its record — the fact the import door hashes on.
        var lastMinted: Bool?
        func placed(_ assets: MediaAssetStore?) throws -> Clip {
            reset()
            lastMinted = nil
            let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
                                              measure: { _ in tenSeconds }, assets: assets)
            guard case .success(let placed) = result else {
                XCTFail("the orphan library file must land: \(result)")
                throw AnchorMissing(name: "placement")
            }
            XCTAssertFalse(placed.reusedClip, "fixture premise: no clip carried the file, so a new clip")
            lastMinted = placed.mintedAssetRecord
            return placed.clip
        }

        // The record bound to the file's name IS its identity: linked, nothing registered.
        let known = MediaAssetStore(store: nil)
        let existing = record(seconds: 10.02)
        XCTAssertTrue(known.register(existing))
        XCTAssertEqual(try placed(known).mediaAssetID, existing.id, "the library file links its own record")
        XCTAssertEqual(known.records, [existing], "no second record per placement")
        XCTAssertEqual(lastMinted, false, "an ADOPTED record is not minted, so the door never hashes it (L1)")

        // A record whose length contradicts the file describes a file that was replaced: a new
        // record is adopted for what is there now, and the old one keeps its id.
        let replaced = MediaAssetStore(store: nil)
        let stale = record(seconds: 4)
        XCTAssertTrue(replaced.register(stale))
        let relinked = try XCTUnwrap(try placed(replaced).mediaAssetID)
        XCTAssertNotEqual(relinked, stale.id, "an incompatible length refutes the binding")
        XCTAssertEqual(replaced.records.count, 2)
        XCTAssertEqual(replaced.record(boundTo: asset.key)?.id, relinked, "the name answers the newest")
        XCTAssertEqual(replaced.record(id: stale.id), stale, "the refuted record is kept, not rewritten")
        XCTAssertEqual(lastMinted, true, "a record registered for what is there now is minted")

        // A damaged record (nothing measured) cannot refute its own binding.
        let damaged = MediaAssetStore(store: nil)
        let blank = MediaAssetRecord(kind: .audio, fileName: "Loop.wav", originalName: "Loop.wav",
                                     importedAt: Date(timeIntervalSince1970: 0),
                                     evidence: .init(byteSize: 0, sampleRate: 0, frameCount: 0, channelCount: 0))
        XCTAssertTrue(damaged.register(blank))
        XCTAssertEqual(try placed(damaged).mediaAssetID, blank.id)
        XCTAssertEqual(damaged.record(id: blank.id)?.evidence.durationSeconds ?? 0, 10, accuracy: 1e-9,
                       "…and learns the file's measurement, so it can refute a later replacement")
        XCTAssertEqual(lastMinted, false, "learning a measurement is not minting a record")

        // A library file with no record gets exactly one, provenance = its own name.
        let empty = MediaAssetStore(store: nil)
        let adoptedID = try XCTUnwrap(try placed(empty).mediaAssetID)
        let adopted = try XCTUnwrap(empty.record(id: adoptedID))
        XCTAssertEqual(adopted.fileName, "Loop.wav")
        XCTAssertEqual(adopted.originalName, "Loop.wav",
                       "provenance of an adopted record is the file's own name (on Place the picked URL IS the file)")
        XCTAssertEqual(adopted.evidence.durationSeconds, 10, accuracy: 1e-9)
        XCTAssertEqual(lastMinted, true,
                       "an orphan's new record is minted by THIS landing — the re-review gap of 292d2d4c8")

        // A second placement of the same file REUSES the clip and rewrites nothing.
        let reuse = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
                                         measure: { _ in tenSeconds }, assets: empty)
        guard case .success(let again) = reuse else { return XCTFail("reuse failed: \(reuse)") }
        XCTAssertTrue(again.reusedClip)
        XCTAssertEqual(again.clip.mediaAssetID, adoptedID)
        XCTAssertEqual(empty.records.count, 1, "a reuse registers nothing")
        XCTAssertFalse(again.mintedAssetRecord, "…and mints nothing")
        XCTAssertNil(try placed(nil).mediaAssetID, "counterweight: no registry, no link")
        XCTAssertEqual(lastMinted, false, "…and nothing minted")

        // A FRESH COPY never adopts, even a record bound to the very same name at the same length:
        // new bytes are a new source, and a compatible length is not identity.
        reset()
        let fresh = MediaAssetStore(store: nil)
        let lookalike = record(seconds: 10)
        XCTAssertTrue(fresh.register(lookalike))
        let copied = AudioImport.commit(pickedURL: URL(fileURLWithPath: "/tmp/picked/Original Take.wav"),
                                        clipStore: clips, timeline: timeline, bpm: 120,
                                        importFile: { _ in library }, measure: { _ in tenSeconds },
                                        deleteManagedCopy: { _ in }, assets: .freshCopy(fresh))
        guard case .success(let copy) = copied else { return XCTFail("copy failed: \(copied)") }
        let freshID = try XCTUnwrap(copy.clip.mediaAssetID)
        XCTAssertNotEqual(freshID, lookalike.id, "a fresh copy is a new record")
        XCTAssertTrue(copy.mintedAssetRecord, "…minted by this landing")
        XCTAssertEqual(fresh.records.count, 2)
        XCTAssertEqual(fresh.record(id: freshID)?.originalName, "Original Take.wav",
                       "a fresh copy's provenance is the PICKED name, not the managed one")
        XCTAssertEqual(fresh.record(id: freshID)?.fileName, "Loop.wav", "…and its binding the managed one")

        // The refutation rule itself, on the record.
        XCTAssertFalse(existing.isContradicted(by: evidence(seconds: 10)), "compatible does not refute")
        XCTAssertTrue(existing.isContradicted(by: evidence(seconds: 12)))
        XCTAssertFalse(existing.isContradicted(by: evidence(seconds: 0)), "unmeasured does not refute")
        let hashed = MediaAssetRecord(kind: .audio, fileName: "Loop.wav", originalName: "Loop.wav",
                                      importedAt: Date(), evidence: evidence(seconds: 10, digest: "sha256:aa"))
        XCTAssertTrue(hashed.isContradicted(by: evidence(seconds: 10, digest: "sha256:bb")),
                      "another digest refutes, whatever the length")
        XCTAssertFalse(hashed.isContradicted(by: evidence(seconds: 10, digest: "sha256:AA")))
    }

    // MARK: 9 — MA4.5 + MA4.4: a relink moves a record only on proven content

    func testARelinkMovesTheRecordOnlyOnProvenContent() throws {
        let clips = ClipStore()
        let timeline = TimelineStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let assets = MediaAssetStore(store: nil)
        let source = MediaAssetRecord(kind: .audio, fileName: "Break.wav", originalName: "Break.wav",
                                      importedAt: Date(timeIntervalSince1970: 1),
                                      evidence: evidence(seconds: 8, digest: sha("a")))
        XCTAssertTrue(assets.register(source))
        let gone = Clip(name: "Break", kind: .audio, mediaRef: "/x/Media/Audio/Break.wav",
                        mediaAssetID: source.id, nativeDurationSeconds: 8, nativeBPM: 96)
        // A clip that never learned its length but whose RECORD knows it.
        let lengthless = Clip(name: "Old", kind: .audio, mediaRef: "/x/Media/Audio/Break.wav",
                              mediaAssetID: source.id)
        // A link this registry does not hold — a project from another device.
        let foreign = Clip(name: "Away", kind: .audio, mediaRef: "/x/Media/Audio/Away.wav",
                           mediaAssetID: UUID(), nativeDurationSeconds: 8)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = gone
        grid[1] = lengthless
        grid[2] = foreign
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise")
        let found = MediaAsset(kind: .audio, fileName: "Break (1).wav",
                               url: URL(fileURLWithPath: "/y/Media/Audio/Break (1).wav"), byteSize: 1)
        func relink(_ id: UUID, _ seconds: Double, digest: String?) -> Result<Double, MediaRelink.Refusal> {
            MediaRelink.relink(id, to: found, clipStore: clips, timeline: timeline, assets: assets,
                               candidateDigest: digest, fileExists: { _ in true },
                               measure: { _ in AudioImport.Measurement(sampleRate: 48_000,
                                                                       frameCount: Int64(seconds * 48_000),
                                                                       channelCount: 2) })
        }

        // The record's LENGTH refutes a file the clip alone could not judge.
        XCTAssertEqual(relink(lengthless.id, 12, digest: nil), .failure(.differentLength(expected: 8, found: 12)),
                       "the record's length speaks for a clip that never learned its own")
        XCTAssertEqual(clips.clip(id: lengthless.id), lengthless, "the refusal wrote nothing")
        XCTAssertEqual(assets.records, [source], "…to the record either")
        XCTAssertFalse(timeline.canUndo)

        // B — another digest is another source, at a compatible length: refused, nothing moves.
        XCTAssertEqual(relink(gone.id, 8, digest: sha("b")), .failure(.differentSource))
        XCTAssertEqual(clips.clip(id: gone.id), gone)
        XCTAssertEqual(assets.records, [source])
        XCTAssertFalse(timeline.canUndo)

        // A — the SAME digest proves the same bytes: the record follows the file with its id.
        // 8.03125 s is exact in binary (and 385 500 frames), so the round trip is exact (#442).
        XCTAssertEqual(relink(gone.id, 8.03125, digest: sha("a")), .success(8.03125))
        let after = try XCTUnwrap(clips.clip(id: gone.id))
        XCTAssertEqual(after.mediaRef, found.url.path)
        XCTAssertEqual(after.mediaAssetID, source.id, "the clip keeps its link — the record moved with it")
        XCTAssertEqual(after.id, gone.id)
        XCTAssertEqual(after.nativeBPM, 96)
        XCTAssertEqual(assets.records.count, 1, "no second record")
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break (1).wav", "the binding moved")
        XCTAssertEqual(assets.record(id: source.id)?.evidence, source.evidence, "the evidence is kept")
        XCTAssertEqual(assets.record(boundTo: found.key)?.id, source.id, "the new name answers the record")
        // ONE step moves both back, and Redo both forward.
        timeline.undo()
        XCTAssertEqual(clips.clip(id: gone.id), gone, "Undo restores the clip exactly")
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break.wav", "…and the record's binding")
        timeline.redo()
        XCTAssertEqual(clips.clip(id: gone.id)?.mediaAssetID, source.id)
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break (1).wav")
        timeline.undo()
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break.wav")

        // D — no digest for the chosen file: a compatible length proves nothing, so the shared
        // record does NOT move; the chosen file gets its own identity and the clip links it.
        XCTAssertEqual(relink(gone.id, 8.03125, digest: nil), .success(8.03125))
        let weak = try XCTUnwrap(clips.clip(id: gone.id))
        XCTAssertEqual(weak.mediaRef, found.url.path)
        XCTAssertNotEqual(weak.mediaAssetID, source.id, "an unproven file is not the source's identity")
        let own = try XCTUnwrap(weak.mediaAssetID.flatMap { assets.record(id: $0) })
        XCTAssertEqual(own.fileName, "Break (1).wav")
        XCTAssertNil(own.evidence.contentDigest, "nothing was hashed, so nothing is claimed")
        XCTAssertEqual(assets.record(id: source.id), source, "the source record is untouched")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: gone.id), gone, "Undo gives the source link back")
        XCTAssertEqual(assets.record(id: own.id), own, "the file's record stays — it describes that file")

        // C — a link the registry does not hold adopts the chosen file's OWN record.
        XCTAssertEqual(relink(foreign.id, 8, digest: nil), .success(8))
        XCTAssertEqual(clips.clip(id: foreign.id)?.mediaAssetID, own.id,
                       "the clip links the record that describes the file it now plays")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: foreign.id), foreign, "Undo gives the unknown link back")

        // The writer refuses a move of ANOTHER clip's record, writing nothing.
        let stranger = MediaAssetStore.Rebinding(store: assets, recordID: UUID(), fileName: "x.wav")
        XCTAssertFalse(timeline.relinkClipSource(clipID: foreign.id, mediaRef: "/y/Media/Audio/x.wav",
                                                 nativeDurationSeconds: 8, identity: .move(stranger),
                                                 clips: clips))
        XCTAssertEqual(clips.clip(id: foreign.id), foreign)

        // The refusal rule itself: the record refutes, never confirms.
        let hashed = MediaAssetRecord(kind: .audio, fileName: "Break.wav", originalName: "Break.wav",
                                      importedAt: Date(), evidence: evidence(seconds: 8, digest: "sha256:aa"))
        let eight = AudioImport.Measurement(sampleRate: 48_000, frameCount: 384_000, channelCount: 2)
        XCTAssertEqual(MediaRelink.recordRefusal(hashed, measurement: eight, contentDigest: "sha256:bb"),
                       .differentSource, "another digest is another source, at the same length")
        XCTAssertNil(MediaRelink.recordRefusal(hashed, measurement: eight, contentDigest: nil),
                     "no digest: the length decides, and 8 s is compatible")
        XCTAssertEqual(MediaRelink.Refusal.differentSource.userMessage.contains("same recording"), false)
    }

    // MARK: 10 — founder §7: one project's relink cannot corrupt another project's asset

    func testARelinkInOneProjectLeavesAnotherProjectsAssetTrue() throws {
        let clips = ClipStore()
        let timeline = TimelineStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let assets = MediaAssetStore(store: nil)
        // Asset X, with a digest, used by Project A (still playing it) and Project B (missing).
        let x = MediaAssetRecord(kind: .audio, fileName: "Loop.wav", originalName: "Loop.wav",
                                 importedAt: Date(timeIntervalSince1970: 1),
                                 evidence: evidence(seconds: 8, digest: sha("a")))
        // A legacy asset Y without a digest, used by both projects the same way.
        let y = MediaAssetRecord(kind: .audio, fileName: "Legacy.wav", originalName: "Legacy.wav",
                                 importedAt: Date(timeIntervalSince1970: 2), evidence: evidence(seconds: 8))
        // A library file with its OWN identity.
        let other = MediaAssetRecord(kind: .audio, fileName: "Other.wav", originalName: "Other.wav",
                                     importedAt: Date(timeIntervalSince1970: 3), evidence: evidence(seconds: 8))
        for record in [x, y, other] { XCTAssertTrue(assets.register(record), "fixture premise") }
        // ONE registry is app-wide, so two projects are two clips linking the same record.
        let projectA = Clip(name: "A", kind: .audio, mediaRef: "/x/Media/Audio/Loop.wav",
                            mediaAssetID: x.id, nativeDurationSeconds: 8)
        let projectB = Clip(name: "B", kind: .audio, mediaRef: "/x/Media/Audio/Loop.wav",
                            mediaAssetID: x.id, nativeDurationSeconds: 8)
        let legacyA = Clip(name: "LA", kind: .audio, mediaRef: "/x/Media/Audio/Legacy.wav",
                           mediaAssetID: y.id, nativeDurationSeconds: 8)
        let legacyB = Clip(name: "LB", kind: .audio, mediaRef: "/x/Media/Audio/Legacy.wav",
                           mediaAssetID: y.id, nativeDurationSeconds: 8)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = projectA
        grid[1] = projectB
        grid[2] = legacyA
        grid[3] = legacyB
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise")
        func relink(_ id: UUID, to name: String, digest: String?) -> Result<Double, MediaRelink.Refusal> {
            let asset = MediaAsset(kind: .audio, fileName: name,
                                   url: URL(fileURLWithPath: "/y/Media/Audio/\(name)"), byteSize: 1)
            // 384 000 frames at 48 kHz: exactly 8 s (#442).
            return MediaRelink.relink(id, to: asset, clipStore: clips, timeline: timeline, assets: assets,
                                      candidateDigest: digest, fileExists: { _ in true },
                                      measure: { _ in AudioImport.Measurement(sampleRate: 48_000,
                                                                              frameCount: 384_000,
                                                                              channelCount: 2) })
        }
        func projectAStillTrue(_ line: UInt = #line) {
            XCTAssertEqual(clips.clip(id: projectA.id), projectA, "Project A's clip is untouched", line: line)
            XCTAssertEqual(assets.record(id: x.id)?.evidence, x.evidence,
                           "X's evidence still describes Project A's content", line: line)
        }

        // MATCHING DIGEST — proven same bytes: X may be repaired with its id; its evidence is
        // unchanged, so it still describes exactly what Project A plays.
        XCTAssertEqual(relink(projectB.id, to: "Loop (1).wav", digest: sha("a")), .success(8))
        XCTAssertEqual(clips.clip(id: projectB.id)?.mediaAssetID, x.id)
        XCTAssertEqual(assets.record(id: x.id)?.fileName, "Loop (1).wav", "the binding is repaired")
        projectAStillTrue()
        timeline.undo()
        XCTAssertEqual(clips.clip(id: projectB.id), projectB)
        XCTAssertEqual(assets.record(id: x.id), x)

        // DIFFERENT DIGEST — refused; neither the identity nor the binding changes.
        XCTAssertEqual(relink(projectB.id, to: "Loop (1).wav", digest: sha("b")), .failure(.differentSource))
        XCTAssertEqual(clips.clip(id: projectB.id), projectB)
        XCTAssertEqual(assets.record(id: x.id), x)
        projectAStillTrue()

        // TARGET OWNS ANOTHER RECORD — adopted, never hidden or stolen: even with X PROVEN (the
        // step order), the file's own identity wins, and X stays where Project A needs it.
        for digest in [sha("a"), nil] {
            XCTAssertEqual(relink(projectB.id, to: "Other.wav", digest: digest), .success(8))
            XCTAssertEqual(clips.clip(id: projectB.id)?.mediaAssetID, other.id)
            XCTAssertEqual(assets.record(boundTo: MediaAsset.Key(kind: .audio, fileName: "Other.wav"))?.id,
                           other.id, "the file's name still answers its own record")
            XCTAssertEqual(assets.record(id: x.id), x, "X did not move")
            projectAStillTrue()
            timeline.undo()
            XCTAssertEqual(clips.clip(id: projectB.id), projectB)
        }
        XCTAssertEqual(assets.record(id: other.id)?.evidence.contentDigest, sha("a"),
                       "the digest the relink computed was written to the file's own record — the one backfill")

        // LEGACY SOURCE WITHOUT A DIGEST — duration alone moves nothing global: Y keeps its
        // binding and evidence for Project A; Project B's clip links the chosen file's OWN new
        // identity (D). A second relink to that file adopts that identity (C), and a digest the
        // relink computed lands there — Y still cannot be proven, so it still does not move.
        let before = assets.records.count
        XCTAssertEqual(relink(legacyB.id, to: "Legacy (1).wav", digest: nil), .success(8))
        let fresh = try XCTUnwrap(clips.clip(id: legacyB.id)?.mediaAssetID)
        XCTAssertNotEqual(fresh, y.id, "an unproven file never takes the shared identity")
        XCTAssertEqual(assets.records.count, before + 1, "one new identity for the chosen file")
        XCTAssertNil(assets.record(id: fresh)?.evidence.contentDigest)
        XCTAssertEqual(assets.record(id: y.id), y, "Y is untouched")
        XCTAssertEqual(clips.clip(id: legacyA.id), legacyA, "Project A still plays Y")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: legacyB.id), legacyB)
        XCTAssertEqual(relink(legacyB.id, to: "Legacy (1).wav", digest: sha("c")), .success(8))
        XCTAssertEqual(clips.clip(id: legacyB.id)?.mediaAssetID, fresh, "the file's own identity, again")
        XCTAssertEqual(assets.record(id: fresh)?.evidence.contentDigest, sha("c"),
                       "the file's own record gained the digest of the file it describes")
        XCTAssertEqual(assets.records.count, before + 1, "no third identity")
        XCTAssertEqual(assets.record(id: y.id), y, "a digest on one side proves nothing about Y")
        XCTAssertEqual(clips.clip(id: legacyA.id), legacyA)
        timeline.undo()

        // A file whose own record its measurement REFUTES is not adopted: that record describes
        // other bytes, so the clip gets a fresh identity and the refuted record is left alone.
        let short = MediaAssetRecord(kind: .audio, fileName: "Short.wav", originalName: "Short.wav",
                                     importedAt: Date(timeIntervalSince1970: 4), evidence: evidence(seconds: 4))
        XCTAssertTrue(assets.register(short))
        XCTAssertEqual(relink(legacyB.id, to: "Short.wav", digest: nil), .success(8))
        XCTAssertNotEqual(clips.clip(id: legacyB.id)?.mediaAssetID, short.id)
        XCTAssertNotEqual(clips.clip(id: legacyB.id)?.mediaAssetID, y.id)
        XCTAssertEqual(assets.record(id: short.id), short, "the refuted record is not rewritten")
        timeline.undo()
    }

    // MARK: 11 — MA4.4: the digest is portable SHA-256, streamed, and taken only where needed

    func testTheDigestIsPortableSHA256ReadInChunks() throws {
        XCTAssertEqual(MediaContentDigest.algorithm, "sha256")
        XCTAssertEqual(MediaContentDigest.evidence(digestBytes: [UInt8](repeating: 0xAB, count: 32)),
                       "sha256:" + String(repeating: "ab", count: 32), "text: algorithm, colon, 64 hex digits")
        XCTAssertNil(MediaContentDigest.evidence(digestBytes: [UInt8](repeating: 0, count: 31)))
        XCTAssertTrue(MediaContentDigest.isEvidence(sha("a")))
        XCTAssertTrue(MediaContentDigest.isEvidence("SHA256:" + String(repeating: "AB", count: 32)))
        XCTAssertFalse(MediaContentDigest.isEvidence("md5:" + String(repeating: "a", count: 64)))
        XCTAssertFalse(MediaContentDigest.isEvidence("sha256:" + String(repeating: "a", count: 63)))
        XCTAssertFalse(MediaContentDigest.isEvidence("sha256:" + String(repeating: "g", count: 64)))
        XCTAssertFalse(MediaContentDigest.isEvidence(String(repeating: "a", count: 64)))
        #if canImport(CryptoKit)
        // The standard SHA-256 vectors — any platform's implementation must print these.
        func hash(_ chunks: [String]) throws -> String {
            var queue = chunks.map { Data($0.utf8) }
            return try MediaContentDigest.sha256(readChunk: { queue.isEmpty ? nil : queue.removeFirst() },
                                                 isCancelled: { false })
        }
        let abc = "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertEqual(try hash(["abc"]), abc)
        XCTAssertEqual(try hash(["a", "b", "c"]), abc, "chunked equals whole")
        XCTAssertEqual(try hash([]), "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        let reads = HashCalls()
        XCTAssertThrowsError(try MediaContentDigest.sha256(readChunk: { reads.count(); return Data([1]) },
                                                           isCancelled: { reads.value >= 2 }),
                             "cancellation is checked before every chunk")
        XCTAssertEqual(reads.value, 2)
        // A real file across chunk boundaries: 2.5 MiB + 7 bytes, read 1 MiB at a time.
        let bytes = Data((0..<(5 * (1 << 19) + 7)).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ma44-\(UUID().uuidString).bin")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try MediaContentDigest.sha256(fileAt: url),
                       MediaContentDigest.evidence(digestBytes: Array(SHA256.hash(data: bytes))),
                       "the streamed file digest equals the one-shot digest of the same bytes")
        #endif
    }

    func testTheRegistryOnlyEverAddsDigestEvidence() {
        let assets = MediaAssetStore(store: nil)
        let blank = record(seconds: 8)
        XCTAssertTrue(assets.register(blank))
        XCTAssertFalse(assets.learnDigest(id: blank.id, digest: "sha256:zz"), "a malformed digest is refused")
        XCTAssertFalse(assets.learnDigest(id: UUID(), digest: sha("a")), "an unknown id is refused")
        XCTAssertNil(assets.record(id: blank.id)?.evidence.contentDigest)
        XCTAssertTrue(assets.learnDigest(id: blank.id, digest: "SHA256:" + String(repeating: "A", count: 64)))
        XCTAssertEqual(assets.record(id: blank.id)?.evidence.contentDigest, sha("a"), "stored lower-cased")
        XCTAssertTrue(assets.learnDigest(id: blank.id, digest: sha("a")), "the same digest again is no change")
        XCTAssertFalse(assets.learnDigest(id: blank.id, digest: sha("b")), "a digest is never overwritten")
        XCTAssertEqual(assets.record(id: blank.id)?.evidence.contentDigest, sha("a"))
    }

    func testTheImportLearnsItsDigestOnce() async {
        let assets = MediaAssetStore(store: nil)
        let blank = record(seconds: 8)
        XCTAssertTrue(assets.register(blank))
        let url = URL(fileURLWithPath: "/y/Media/Audio/loop.wav")
        let calls = HashCalls()
        let digest = sha("a")
        let failed = await MediaContentDigest.learn(recordID: blank.id, from: url, into: assets,
                                                    hash: { _ in calls.count(); throw CocoaError(.fileReadNoSuchFile) })
        XCTAssertFalse(failed, "an unreadable file teaches nothing")
        XCTAssertNil(assets.record(id: blank.id)?.evidence.contentDigest)
        let malformed = await MediaContentDigest.learn(recordID: blank.id, from: url, into: assets,
                                                       hash: { _ in calls.count(); return "sha256:12" })
        XCTAssertFalse(malformed, "a hash that is not SHA-256 evidence is dropped")
        let learned = await MediaContentDigest.learn(recordID: blank.id, from: url, into: assets,
                                                     hash: { _ in calls.count(); return digest })
        XCTAssertTrue(learned)
        XCTAssertEqual(assets.record(id: blank.id)?.evidence.contentDigest, digest)
        let again = await MediaContentDigest.learn(recordID: blank.id, from: url, into: assets,
                                                   hash: { _ in calls.count(); return digest })
        XCTAssertFalse(again, "a record with a digest is not hashed again")
        XCTAssertEqual(calls.value, 3, "the fourth call never hashed")
        let unknown = await MediaContentDigest.learn(recordID: UUID(), from: url, into: assets,
                                                     hash: { _ in calls.count(); return digest })
        XCTAssertFalse(unknown)
        XCTAssertEqual(calls.value, 3)
    }

    func testTheRelinkHashesOnlyWhenItMustAndNeverUnderAPlayingSong() async throws {
        let clips = ClipStore()
        let timeline = TimelineStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let assets = MediaAssetStore(store: nil)
        let hashed = MediaAssetRecord(kind: .audio, fileName: "Take.wav", originalName: "Take.wav",
                                      importedAt: Date(timeIntervalSince1970: 1),
                                      evidence: evidence(seconds: 8, digest: sha("a")))
        let legacy = MediaAssetRecord(kind: .audio, fileName: "Old.wav", originalName: "Old.wav",
                                      importedAt: Date(timeIntervalSince1970: 2), evidence: evidence(seconds: 8))
        XCTAssertTrue(assets.register(hashed))
        XCTAssertTrue(assets.register(legacy))
        let take = Clip(name: "Take", kind: .audio, mediaRef: "/x/Media/Audio/Take.wav",
                        mediaAssetID: hashed.id, nativeDurationSeconds: 8)
        let old = Clip(name: "Old", kind: .audio, mediaRef: "/x/Media/Audio/Old.wav",
                       mediaAssetID: legacy.id, nativeDurationSeconds: 8)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = take
        grid[1] = old
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise")
        XCTAssertTrue(MediaRelink.needsContentProof(take, assets: assets))
        XCTAssertFalse(MediaRelink.needsContentProof(old, assets: assets), "nothing to compare, nothing hashed")
        XCTAssertFalse(MediaRelink.needsContentProof(take, assets: nil))
        let target = MediaAsset(kind: .audio, fileName: "Take (1).wav",
                                url: URL(fileURLWithPath: "/y/Media/Audio/Take (1).wav"), byteSize: 1)
        let calls = HashCalls()
        func run(_ clipID: UUID, seconds: Double = 8, playing: @escaping (Int) -> Bool = { _ in false },
                 hash: @escaping @Sendable (URL) throws -> String) async -> Result<Double, MediaRelink.Refusal> {
            var asked = 0
            return await MediaRelink.relinkProvingContent(
                clipID, to: target, clipStore: clips, timeline: timeline, assets: assets,
                isSongPlaying: { asked += 1; return playing(asked) },
                fileExists: { _ in true },
                measure: { _ in AudioImport.Measurement(sampleRate: 48_000,
                                                        frameCount: Int64(seconds * 48_000),
                                                        channelCount: 2) },
                hash: hash)
        }
        let digest = sha("a")
        // A file of the wrong length is never hashed.
        let short = await run(take.id, seconds: 12, hash: { _ in calls.count(); return digest })
        XCTAssertEqual(short, .failure(.differentLength(expected: 8, found: 12)))
        XCTAssertEqual(calls.value, 0)
        // Never under a playing song — before the hash, and again after it.
        let before = await run(take.id, playing: { _ in true }, hash: { _ in calls.count(); return digest })
        XCTAssertEqual(before, .failure(.songPlaying))
        XCTAssertEqual(calls.value, 0)
        let during = await run(take.id, playing: { $0 > 1 }, hash: { _ in calls.count(); return digest })
        XCTAssertEqual(during, .failure(.songPlaying), "the song started while the file was hashed")
        XCTAssertEqual(calls.value, 1)
        XCTAssertEqual(clips.clip(id: take.id), take, "nothing written")
        XCTAssertEqual(MediaBrowserView.relinkRefusal(songPlaying: true),
                       MediaRelink.Refusal.songPlaying.userMessage, "one sentence for one refusal (#416)")
        // A hash that fails proves nothing: refused as unreadable, nothing written.
        let broken = await run(take.id, hash: { _ in calls.count(); throw CocoaError(.fileReadCorruptFile) })
        XCTAssertEqual(broken, .failure(.unreadable))
        XCTAssertEqual(calls.value, 2)
        XCTAssertEqual(assets.record(id: hashed.id), hashed)
        // Proven: the record moves with its id.
        let proven = await run(take.id, hash: { _ in calls.count(); return digest })
        XCTAssertEqual(proven, .success(8))
        XCTAssertEqual(calls.value, 3)
        XCTAssertEqual(assets.record(id: hashed.id)?.fileName, "Take (1).wav")
        XCTAssertEqual(clips.clip(id: take.id)?.mediaAssetID, hashed.id)
        // A legacy record has nothing to compare: no hash at all, and nothing global moves.
        let unproven = await run(old.id, hash: { _ in calls.count(); return digest })
        XCTAssertEqual(unproven, .success(8))
        XCTAssertEqual(calls.value, 3, "no digest to compare, no hash")
        XCTAssertEqual(assets.record(id: legacy.id), legacy, "the unprovable legacy record does not move")
        // Step C (review L3): "Take (1).wav" now carries the proven Take record, which this
        // length does not refute — the clip adopts the chosen file's own identity.
        XCTAssertEqual(clips.clip(id: old.id)?.mediaAssetID, hashed.id,
                       "the clip links the record of the file it now plays (C), not the legacy one")
    }

    func testNothingHashesAtLaunchOrAsAScan() throws {
        XCTAssertEqual(try filesUnderSources(containing: "MediaContentDigest.learn("), ["Studio/WorkstationView.swift"],
                       "a new import's digest is learned by the Workstation's import door, nowhere else")
        XCTAssertEqual(try filesUnderSources(containing: "MediaContentDigest.sha256(fileAt:"),
                       ["Sequencer/MediaRelink.swift", "Studio/WorkstationView.swift"],
                       "the file is hashed by the import door and the relink, and by nothing else")
        XCTAssertFalse(try source("Sources/Echoelmusic/EchoelmusicApp.swift").contains("MediaContentDigest"),
                       "no launch-time hashing")
        XCTAssertFalse(try source("Sources/Echoelmusic/Core/MediaAssetStore.swift").contains("sha256(fileAt:"),
                       "the registry never hashes")
        let digest = try source("Sources/Echoelmusic/Core/MediaContentDigest.swift")
        XCTAssertTrue(digest.contains("handle.read(upToCount: chunkSize)"), "the file is read in bounded chunks")
        XCTAssertFalse(digest.contains("Data(contentsOf") || digest.contains("readToEnd"),
                       "a media file is never read whole to hash it")
        XCTAssertTrue(digest.contains("Task.detached(priority: .utility)"), "off the main actor")
        XCTAssertTrue(digest.contains("#if canImport(CryptoKit)\nimport CryptoKit"),
                      "CryptoKit is the implementation, imported behind its guard")
        // Review of 66d37a8c5 (M1): the hash runs in ITS OWN task — inside the analysis task the
        // next import tap cancelled it and the record never got a digest.
        let door = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        let helper = try XCTUnwrap(door.range(of: "private func learnContentDigest(of landing: AudioImport.Landing)"))
        let learn = try XCTUnwrap(door.range(of: "MediaContentDigest.learn("))
        XCTAssertLessThan(helper.lowerBound, learn.lowerBound, "the learn call lives in the helper")
        let helperText = door[helper.lowerBound..<learn.lowerBound]
        // MA4.4c: the door hashes what the landing MINTED — a fresh copy AND an orphan's new
        // record — and never an adopted one (review L1). The copy question was the wrong proxy.
        XCTAssertTrue(helperText.contains("guard landing.mintedAssetRecord"),
                      "the door asks the transaction whether it minted the record")
        XCTAssertFalse(helperText.contains("reusedLibraryFile"),
                       "…and does not infer it from whether bytes were copied (re-review of 292d2d4c8)")
        XCTAssertTrue(helperText.contains("Task {"), "its own task, not the cancellable analysis task")
        XCTAssertEqual(door.components(separatedBy: "learnContentDigest(of: landing)").count - 1, 1,
                       "called once, from the import's success branch")
        let analysis = try XCTUnwrap(door.range(of: ".task(id: tuningPending)"))
        let afterAnalysis = door[analysis.lowerBound...]
        let analysisEnd = try XCTUnwrap(afterAnalysis.range(of: "\n        }\n"))
        XCTAssertFalse(afterAnalysis[..<analysisEnd.lowerBound].contains("MediaContentDigest"),
                       "the analysis task does not hash")
    }

    // MARK: - Helpers

    /// A well-formed persisted digest made of one repeated hex digit.
    private func sha(_ digit: Character) -> String {
        "sha256:" + String(repeating: String(digit), count: 64)
    }

    private struct AnchorMissing: Error { let name: String }

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

/// Counts calls — hash calls from the detached task `MediaContentDigest.compute` runs them in,
/// and chunk reads in the cancellation claim.
private final class HashCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    func count() { lock.lock(); calls += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return calls }
}
