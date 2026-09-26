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
//    never identity; nothing measurable is `unmeasured`; a malformed digest is not comparable.
// 2. END-TO-END + SOURCE-TEXT SCAN: the length rule has ONE definition. `MediaRelink.sameLength`
//    agrees with `MediaAssetRecord.compatibleDuration` over a grid, and the tolerance literal
//    occurs once in `Sources/`, in the record's file (#416).
// 3. END-TO-END: Codable — a round trip is lossless; a record missing its evidence, provenance or
//    kind keeps its id and binding; a record without an id does not decode; an unknown kind
//    decodes with no key (no listing can show it).
// 4. SOURCE-TEXT SCAN (counterweight): the record touches no file and stores no availability,
//    placement or tempo, and its file imports Foundation only.
//
// GRADING against the parent (`bb5a1a534`): this file does NOT compile there —
// `MediaAssetRecord` is new, so no assertion has a verdict (one absence, #486). Claims 1, 3 and
// 4 are FORWARD guards. Claim 2's scan would be green-by-count on the parent (the literal sat once,
// in `MediaRelink`) and is red there only by its FILE assertion — a regression guard for the move,
// not for behaviour. Graded by transcription (§0); device probes: none apply.

import Foundation
import XCTest
@testable import Echoelmusic

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
