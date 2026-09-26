// TheMediaAssetIsADurableIdentityTests.swift
// Echoel — MA4.1 (founder media decision 2026-09-26: "MediaAsset = durable media/source
// identity"; plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md` §MA4).
//
// WHAT IT PINS. `MediaAssetRecord` is the durable identity of one managed file: a stable id, a
// binding (the file name in its kind's home), provenance and measured evidence. This slice builds
// the value type and moves the one length rule into it (MA4.1); MA4.2–4.6 added the registry, the
// Clip link, the import write, library adoption and the relink move — claims 5–9 below.
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
// 7. SOURCE-TEXT SCAN (MA4.2/4.3/4.5): the landing transaction is the registry's one REGISTERING
//    writer and the song's relink step its one REBINDING writer, the app
//    constructs and injects it, the Workstation's import and the browser's Place hand it on, the
//    copy path mints a fresh record and the placement adopts, and no argument is defaulted.
// 8. END-TO-END (MA4.3, real stores): a library file placed as a new clip links the record bound
//    to its name; a record whose LENGTH contradicts the file is refuted and a new one adopted (the
//    old keeps its id); a record with no measurement cannot refute; a file without a record gets
//    exactly one; a reuse rewrites nothing; a FRESH COPY never adopts a same-name, same-length
//    record. `isContradicted` is driven directly, digest included.
// 9. END-TO-END (MA4.5, real stores): a relink of a linked clip checks the chosen file against
//    the RECORD (which can refuse where the clip alone could not — a clip that never learned its
//    length) and then MOVES the record's binding with its id; the clip keeps its link; ONE Undo
//    moves clip and record back, Redo forward. A link the registry does not hold is replaced by
//    the chosen file's own record. The writer refuses a move of another record. `recordRefusal`
//    refutes, never confirms.
// 10. END-TO-END (MA4.5 review, real stores): a record that has moved on to another file is not
//    pulled back (the link is released, MED-1); a file with its own record gives the clip THAT
//    record and nothing moves (MED-2) — even when the clip's record could legally move, which pins
//    the ORDER of the steps; a record its file's measurement refutes is not adopted; a file no
//    record describes takes the move.
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
                       "the landing transaction is the registry's one production writer")
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
        XCTAssertTrue(browser.contains("assets: mediaAssets) {"),
                      "the browser's Relink hands the registry to the relink (MA4.5)")
        let relink = try source("Sources/Echoelmusic/Sequencer/MediaRelink.swift")
        XCTAssertTrue(relink.contains("recordRefusal(linked, measurement: measurement, contentDigest: nil)"),
                      "the relink never hashes on the tap")
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
        func placed(_ assets: MediaAssetStore?) throws -> Clip {
            reset()
            let result = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
                                              measure: { _ in tenSeconds }, assets: assets)
            guard case .success(let placed) = result else {
                XCTFail("the orphan library file must land: \(result)")
                throw AnchorMissing(name: "placement")
            }
            XCTAssertFalse(placed.reusedClip, "fixture premise: no clip carried the file, so a new clip")
            return placed.clip
        }

        // The record bound to the file's name IS its identity: linked, nothing registered.
        let known = MediaAssetStore(store: nil)
        let existing = record(seconds: 10.02)
        XCTAssertTrue(known.register(existing))
        XCTAssertEqual(try placed(known).mediaAssetID, existing.id, "the library file links its own record")
        XCTAssertEqual(known.records, [existing], "no second record per placement")

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

        // A damaged record (nothing measured) cannot refute its own binding.
        let damaged = MediaAssetStore(store: nil)
        let blank = MediaAssetRecord(kind: .audio, fileName: "Loop.wav", originalName: "Loop.wav",
                                     importedAt: Date(timeIntervalSince1970: 0),
                                     evidence: .init(byteSize: 0, sampleRate: 0, frameCount: 0, channelCount: 0))
        XCTAssertTrue(damaged.register(blank))
        XCTAssertEqual(try placed(damaged).mediaAssetID, blank.id)
        XCTAssertEqual(damaged.record(id: blank.id)?.evidence.durationSeconds ?? 0, 10, accuracy: 1e-9,
                       "…and learns the file's measurement, so it can refute a later replacement")

        // A library file with no record gets exactly one, provenance = its own name.
        let empty = MediaAssetStore(store: nil)
        let adoptedID = try XCTUnwrap(try placed(empty).mediaAssetID)
        let adopted = try XCTUnwrap(empty.record(id: adoptedID))
        XCTAssertEqual(adopted.fileName, "Loop.wav")
        XCTAssertEqual(adopted.originalName, "Loop.wav",
                       "provenance of an adopted record is the file's own name (on Place the picked URL IS the file)")
        XCTAssertEqual(adopted.evidence.durationSeconds, 10, accuracy: 1e-9)

        // A second placement of the same file REUSES the clip and rewrites nothing.
        let reuse = MediaPlacement.place(asset, clipStore: clips, timeline: timeline, bpm: 120,
                                         measure: { _ in tenSeconds }, assets: empty)
        guard case .success(let again) = reuse else { return XCTFail("reuse failed: \(reuse)") }
        XCTAssertTrue(again.reusedClip)
        XCTAssertEqual(again.clip.mediaAssetID, adoptedID)
        XCTAssertEqual(empty.records.count, 1, "a reuse registers nothing")
        XCTAssertNil(try placed(nil).mediaAssetID, "counterweight: no registry, no link")

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

    // MARK: 9 — MA4.5: a relink moves the record with its id

    func testARelinkMovesTheRecordAndUndoMovesItBack() throws {
        let clips = ClipStore()
        let timeline = TimelineStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let assets = MediaAssetStore(store: nil)
        let source = MediaAssetRecord(kind: .audio, fileName: "Break.wav", originalName: "Break.wav",
                                      importedAt: Date(timeIntervalSince1970: 1), evidence: evidence(seconds: 8))
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
        func measured(_ seconds: Double) -> (URL) -> AudioImport.Measurement? {
            { _ in AudioImport.Measurement(sampleRate: 48_000, frameCount: Int64(seconds * 48_000),
                                           channelCount: 2) }
        }
        func relink(_ id: UUID, _ seconds: Double) -> Result<Double, MediaRelink.Refusal> {
            MediaRelink.relink(id, to: found, clipStore: clips, timeline: timeline, assets: assets,
                               fileExists: { _ in true }, measure: measured(seconds))
        }

        // The RECORD refutes a file the clip alone could not judge.
        XCTAssertEqual(relink(lengthless.id, 12), .failure(.differentLength(expected: 8, found: 12)),
                       "the record's length speaks for a clip that never learned its own")
        XCTAssertEqual(clips.clip(id: lengthless.id), lengthless, "the refusal wrote nothing")
        XCTAssertEqual(assets.records, [source], "…to the record either")
        XCTAssertFalse(timeline.canUndo)

        // The same source: the clip plays the new file, the record FOLLOWS it with its id.
        // 8.03125 s is exact in binary (and 385 500 frames), so the round trip is exact (#442).
        XCTAssertEqual(relink(gone.id, 8.03125), .success(8.03125))
        let after = try XCTUnwrap(clips.clip(id: gone.id))
        XCTAssertEqual(after.mediaRef, found.url.path)
        XCTAssertEqual(after.mediaAssetID, source.id, "the clip keeps its link — the record moved with it")
        XCTAssertEqual(after.id, gone.id)
        XCTAssertEqual(after.nativeBPM, 96)
        XCTAssertEqual(assets.records.count, 1, "no second record")
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break (1).wav", "the binding moved")
        XCTAssertEqual(assets.record(id: source.id)?.evidence, source.evidence, "the evidence is the source's, kept")
        XCTAssertEqual(assets.record(boundTo: found.key)?.id, source.id, "the new name answers the record")

        // ONE step moves both back, and Redo both forward.
        timeline.undo()
        XCTAssertEqual(clips.clip(id: gone.id), gone, "Undo restores the clip exactly")
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break.wav", "…and the record's binding")
        timeline.redo()
        XCTAssertEqual(clips.clip(id: gone.id)?.mediaAssetID, source.id)
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break (1).wav")

        // A link the registry does not hold is replaced by the chosen file's OWN record — after
        // the Redo that is the moved source, bound to "Break (1).wav" and measured at 8 s.
        XCTAssertEqual(relink(foreign.id, 8), .success(8))
        XCTAssertEqual(clips.clip(id: foreign.id)?.mediaAssetID, source.id,
                       "the clip links the record that describes the file it now plays")
        XCTAssertEqual(assets.record(id: source.id)?.fileName, "Break (1).wav", "adopting moves nothing")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: foreign.id), foreign, "Undo gives the unknown link back")

        // The writer refuses a rebinding of ANOTHER clip's record, writing nothing.
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
                     "no digest on the tap: the length decides, and 8 s is compatible")
        XCTAssertEqual(MediaRelink.Refusal.differentSource.userMessage.contains("same recording"), false)
    }

    // MARK: 10 — MA4.5 review: a relink never takes another file's identity

    func testARelinkNeverTakesAnotherFilesIdentity() throws {
        let clips = ClipStore()
        let timeline = TimelineStore()
        let originalSlots = clips.slots
        defer { clips.replaceSlots(originalSlots) }
        let assets = MediaAssetStore(store: nil)
        // The source two songs used. Another song already relinked it: it now names "Loop (1).wav",
        // a file that exists and that song plays.
        let shared = MediaAssetRecord(kind: .audio, fileName: "Loop (1).wav", originalName: "Loop.wav",
                                      importedAt: Date(timeIntervalSince1970: 1), evidence: evidence(seconds: 8))
        // A library file with its OWN identity, at a compatible length.
        let other = MediaAssetRecord(kind: .audio, fileName: "Other.wav", originalName: "Other.wav",
                                     importedAt: Date(timeIntervalSince1970: 2), evidence: evidence(seconds: 8))
        // A record whose name is taken by a file its measurement refutes.
        let stale = MediaAssetRecord(kind: .audio, fileName: "Short.wav", originalName: "Short.wav",
                                     importedAt: Date(timeIntervalSince1970: 3), evidence: evidence(seconds: 4))
        // A record that STILL names its clip's missing file — the one a move would be legal for.
        let current = MediaAssetRecord(kind: .audio, fileName: "Take.wav", originalName: "Take.wav",
                                       importedAt: Date(timeIntervalSince1970: 4), evidence: evidence(seconds: 8))
        for record in [shared, other, stale, current] {
            XCTAssertTrue(assets.register(record), "fixture premise")
        }
        // This song's clip still names the missing "Loop.wav" and links the shared record.
        let song = Clip(name: "Loop", kind: .audio, mediaRef: "/x/Media/Audio/Loop.wav",
                        mediaAssetID: shared.id, nativeDurationSeconds: 8, nativeBPM: 120)
        let take = Clip(name: "Take", kind: .audio, mediaRef: "/x/Media/Audio/Take.wav",
                        mediaAssetID: current.id, nativeDurationSeconds: 8)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = song
        grid[1] = take
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise")
        func relink(_ clipID: UUID? = nil, to name: String) -> Result<Double, MediaRelink.Refusal> {
            let asset = MediaAsset(kind: .audio, fileName: name,
                                   url: URL(fileURLWithPath: "/y/Media/Audio/\(name)"), byteSize: 1)
            // 384 000 frames at 48 kHz: exactly 8 s (#442).
            return MediaRelink.relink(clipID ?? song.id, to: asset, clipStore: clips, timeline: timeline,
                                      assets: assets,
                                      fileExists: { _ in true },
                                      measure: { _ in AudioImport.Measurement(sampleRate: 48_000,
                                                                              frameCount: 384_000,
                                                                              channelCount: 2) })
        }
        func bindings() -> [String] { assets.records.map(\.fileName) }
        let before = bindings()

        // MED-1: the record has moved on to a file another song plays — it is NOT pulled back.
        XCTAssertEqual(relink(to: "Loop (2).wav"), .success(8))
        XCTAssertNil(clips.clip(id: song.id)?.mediaAssetID,
                     "the clip lets go of a record that describes another file")
        XCTAssertEqual(assets.record(id: shared.id)?.fileName, "Loop (1).wav",
                       "the other song's file keeps its identity")
        XCTAssertEqual(bindings(), before, "no record moved")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: song.id), song, "Undo gives the link back")

        // MED-2: the chosen file has its own record — the clip ADOPTS it; a compatible length
        // never overwrites that file's identity with another's.
        XCTAssertEqual(relink(to: "Other.wav"), .success(8))
        XCTAssertEqual(clips.clip(id: song.id)?.mediaAssetID, other.id)
        XCTAssertEqual(assets.record(boundTo: MediaAsset.Key(kind: .audio, fileName: "Other.wav"))?.id, other.id,
                       "the file's name still answers its own record")
        XCTAssertEqual(bindings(), before, "adopting moves nothing")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: song.id), song)

        // Counterweight: a record its file's measurement refutes is not the file's identity.
        XCTAssertEqual(relink(to: "Short.wav"), .success(8))
        XCTAssertNil(clips.clip(id: song.id)?.mediaAssetID, "a refuted record is not adopted")
        XCTAssertEqual(bindings(), before)
        timeline.undo()
        XCTAssertEqual(clips.clip(id: song.id), song)

        // THE ORDER (review of `95cb1a16f`): this record still names its clip's missing file, so a
        // move WOULD be legal — and the chosen file's own identity still wins. Swapping steps 1
        // and 2 of `MediaRelink.identity` turns this red.
        XCTAssertEqual(relink(take.id, to: "Other.wav"), .success(8))
        XCTAssertEqual(clips.clip(id: take.id)?.mediaAssetID, other.id,
                       "the file's own record comes before moving the clip's")
        XCTAssertEqual(assets.record(id: current.id)?.fileName, "Take.wav", "the clip's record did not move")
        XCTAssertEqual(bindings(), before)
        timeline.undo()
        XCTAssertEqual(clips.clip(id: take.id), take)
        // Counterweight: the same clip to a file NO record describes — now the move is taken.
        XCTAssertEqual(relink(take.id, to: "Take (1).wav"), .success(8))
        XCTAssertEqual(clips.clip(id: take.id)?.mediaAssetID, current.id, "the link is kept")
        XCTAssertEqual(assets.record(id: current.id)?.fileName, "Take (1).wav", "…and the record moved")
        timeline.undo()
        XCTAssertEqual(clips.clip(id: take.id), take)
        XCTAssertEqual(assets.record(id: current.id)?.fileName, "Take.wav")
        XCTAssertFalse(timeline.canUndo, "five relinks, five steps, all undone")
    }

    // MARK: - Helpers

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
