// TheMediaAssetIsADurableIdentityTests.swift
// Echoel — MA4.1 (founder media decision 2026-09-26: "MediaAsset = durable media/source
// identity"; plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md` §MA4).
//
// WHAT IT PINS. `MediaAssetRecord` is the durable identity of one managed file: a stable id, a
// binding (the file name in its kind's home), provenance and measured evidence. This slice builds
// the value type and moves the one length rule into it; nothing in the app constructs a record
// yet (registry, Clip link, import write and digest are the next slices).
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
//    grid, and `assets: nil` is the pre-MA4.2 transaction. The clip codec keeps the link, an old
//    clip has none, a damaged link costs only the link.
// 7. SOURCE-TEXT SCAN (MA4.2): the import is the registry's one writer, the app constructs and
//    injects it, the Workstation hands it to the transaction, and the argument is not defaulted.
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
                                         deleteManagedCopy: { _ in }, assets: assets)
        guard case .failure = refused else { return XCTFail("an unreadable copy must be refused") }
        XCTAssertTrue(assets.records.isEmpty, "a refused import registers nothing")

        let result = AudioImport.commit(pickedURL: picked, clipStore: clips, timeline: timeline,
                                        bpm: 120, importFile: { _ in copy }, measure: { _ in measured },
                                        deleteManagedCopy: { _ in }, assets: assets)
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
                                        deleteManagedCopy: { _ in }, assets: nil)
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
        XCTAssertEqual(try filesUnderSources(containing: "assets.register("), ["Sequencer/AudioImport.swift"],
                       "the import is the registry's one production writer in MA4.2")
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("@State private var mediaAssetStore = MediaAssetStore()"))
        XCTAssertTrue(app.contains(".environment(mediaAssetStore)"))
        let door = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertTrue(door.contains("@Environment(MediaAssetStore.self) private var mediaAssets"))
        XCTAssertTrue(door.contains("assets: mediaAssets,"),
                      "the Workstation's import hands the registry to the transaction")
        let importer = try source("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        XCTAssertTrue(importer.contains("assets: assets)"), "perform forwards the registry to commit")
        XCTAssertFalse(importer.contains("assets: MediaAssetStore? ="),
                       "the registry argument is required, never defaulted (#431)")
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
