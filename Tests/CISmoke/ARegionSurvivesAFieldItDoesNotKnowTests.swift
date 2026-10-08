// ARegionSurvivesAFieldItDoesNotKnowTests.swift
// Echoel — GMMW AE-0 (2026-10-08). Every field of a part is saved, and a part read back
// from an older or newer build still opens.
//
// WHAT THIS GUARDS. `TimelineRegion` has a hand-written `init(from:)` and a SYNTHESIZED
// `encode(to:)`, and both read one `CodingKeys` enum. Audio editor W4a added two stored fields
// (`fadeInTicks`, `fadeOutTicks`) with no guard over that pairing. A stored field missing from
// `CodingKeys` still compiles: the synthesized encoder simply never writes it and the custom
// decoder assigns it a constant. The part then loses that field on every save, silently, and
// the song only looks right until the next launch. `ALaneSurvivesAFieldItDoesNotKnowTests`
// guards the LANE's decoder; nothing guarded the part's.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR — a part with every field away from its default survives an
//      encode → decode round trip unchanged (`TimelineRegion` is `Equatable` over all stored
//      fields). This is the strong claim, and it catches a missing key for every field that
//      exists TODAY.
//   2. SOURCE-TEXT SCAN — every stored property of the struct is a case of `CodingKeys`. This
//      is the claim that catches field N+1, which claim 1 cannot construct with a non-default
//      value. A fixture with a field missing from the keys proves the scan can fail for its
//      named reason (#367).
//   3. SOURCE-TEXT SCAN — every key is decoded with a fallback (`??`) in `init(from:)`, and every
//      non-primitive type with `try?` (the lane rule, #543: `decodeIfPresent` absorbs a MISSING
//      key, never an unknown enum case).
//   4. END-TO-END BEHAVIOUR — a part written before the late fields existed opens with their
//      defaults; an unknown stretch mode opens as Clean; an unknown extra key is ignored; a
//      negative fade opens as a hard edge.
//
// ⚠️ HONEST GRADING (#433), transcribed against the parent `6481aa7` and the worktree: this is a
// GUARD-ONLY slice — `Sources/` does not change. Every assertion is a COUNTERWEIGHT, green on
// both trees, except the fixture in claim 2, which is red on its fixture by construction (that
// is the point of it). Nothing here was red before; the slice closes a hole, it does not repair
// a defect. Stripper `SourceText.codeOnly`: PROPHYLAKTISCH — the struct's doc comments name no
// stored property in `public var` form, measured 0 flips over claims 2–3 on both trees.
//
// ⚠️ THE LIMIT. Claim 1 proves the fields that exist today and claim 2 the shape of tomorrow's;
// neither proves that a real document from a user's device opens. That is a device probe.

import Foundation
import XCTest
@testable import Echoelmusic

final class ARegionSurvivesAFieldItDoesNotKnowTests: XCTestCase {

    private static let timeline = "Sources/Echoelmusic/Sequencer/Timeline.swift"
    private static let structHead = "public struct TimelineRegion: Codable, Sendable, Equatable, Identifiable {"
    private static let decoderHead = "public init(from decoder: Decoder) throws {"

    /// The types a `decodeIfPresent` may read without `try?`: a value of these can be missing,
    /// but it cannot be an unknown case. The same set as the lane's rule (#543).
    private static let primitives: Set<String> = ["UUID", "Int", "Double", "Float", "Bool", "String"]

    // MARK: 1 — END-TO-END: every field survives a round trip

    func testEveryFieldSurvivesASaveAndAnOpen() throws {
        let other = try XCTUnwrap(StretchMode.allCases.first { $0 != .clean },
                                  "StretchMode has only Clean — this round trip needs a second mode")
        let part = TimelineRegion(laneID: UUID(), clipID: UUID(),
                                  startTick: 960, lengthTicks: 1_920,
                                  contentOffsetSeconds: 1.25, contentOffsetTicks: 480,
                                  gain: 0.5, warpEnabled: true, stretchMode: other,
                                  fadeInTicks: 120, fadeOutTicks: 240)
        let data = try JSONEncoder().encode(part)
        let back = try JSONDecoder().decode(TimelineRegion.self, from: data)
        XCTAssertEqual(back, part, """
            A part does not come back as it was saved. Some stored field is missing from \
            `TimelineRegion.CodingKeys` (the synthesized encoder never writes it) or the custom \
            decoder does not read it — either way the field is lost on every save.
            """)
    }

    // MARK: 2 — SOURCE: every stored property is a coding key

    func testEveryStoredPropertyIsACodingKey() throws {
        let code = try source(Self.timeline)
        let missing = try XCTUnwrap(Self.fieldsMissingFromCodingKeys(in: code),
                                    "ANCHOR MISSING: `TimelineRegion`, its `init(` or its `CodingKeys` moved (#408)")
        XCTAssertEqual(missing, [], """
            `TimelineRegion` stores \(missing) but `CodingKeys` does not name it. The synthesized \
            encoder never writes such a field, so it is lost on every save. Add the key and a \
            decode with a default in `init(from:)` (AE-0).
            """)

        // The scan must be able to fail for its named reason (#367): a fixture region with a
        // field the keys do not name.
        let fixture = """
            public struct TimelineRegion: Codable, Sendable, Equatable, Identifiable {
                public var id: UUID
                public var fadeInTicks: Int
                public var endTick: Int { 0 }
                public init(id: UUID) {
                    self.id = id
                    self.fadeInTicks = 0
                }
                private enum CodingKeys: String, CodingKey {
                    case id
                }
            }
            """
        XCTAssertEqual(Self.fieldsMissingFromCodingKeys(in: fixture), ["fadeInTicks"],
                       "the scan no longer reports a stored field the keys leave out")
    }

    // MARK: 3 — SOURCE: every key decodes with a fallback, every non-primitive with `try?`

    func testEveryKeyDecodesWithAFallback() throws {
        let code = try source(Self.timeline)
        guard let head = code.range(of: Self.structHead),
              let keys = Self.codingKeys(in: code, after: head.upperBound),
              let decoder = code.range(of: Self.decoderHead, range: head.upperBound..<code.endIndex),
              let end = code.range(of: "\n    }\n", range: decoder.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `TimelineRegion.init(from:)` or its `CodingKeys` moved (#408)")
        }
        let body = String(code[decoder.upperBound..<end.lowerBound])
        let statements = body.components(separatedBy: "\n")
        XCTAssertFalse(keys.isEmpty, "no coding keys were read — a scan that saw nothing is not a pass (#454)")
        for key in keys {
            let lines = statements.filter { $0.contains("forKey: .\(key))") }
            XCTAssertEqual(lines.count, 1, "`\(key)` is decoded \(lines.count) times in `init(from:)`, not once")
            guard let line = lines.first else { continue }
            XCTAssertTrue(line.contains("??"), """
                `\(key)` is decoded without a fallback: `\(line.trimmingCharacters(in: .whitespaces))`. \
                A part saved before the field existed then throws, the region array throws, and \
                the whole song is lost (the decodeIfPresent LAW in `init(from:)`'s own comment).
                """)
            guard let type = Self.decodedType(in: line) else {
                XCTFail("cannot read the decoded type of `\(key)` from `\(line)`")
                continue
            }
            if !Self.primitives.contains(type) {
                XCTAssertTrue(line.contains("try? c.decode(\(type).self"), """
                    `\(key)` decodes the non-primitive `\(type)` without `try?`. `decodeIfPresent` \
                    absorbs a MISSING key, never an unknown case — a part written by a newer \
                    build with a case this build lacks would throw and take the song with it (#543).
                    """)
            }
        }
    }

    // MARK: 4 — END-TO-END: an old part, an unknown mode, an unknown key, a negative fade

    func testAnOldOrForeignPartStillOpens() throws {
        let lane = UUID(), clip = UUID(), id = UUID()
        let old = """
            {"id":"\(id.uuidString)","laneID":"\(lane.uuidString)","clipID":"\(clip.uuidString)",\
            "startTick":480,"lengthTicks":960}
            """
        let part = try JSONDecoder().decode(TimelineRegion.self, from: Data(old.utf8))
        XCTAssertEqual(part, TimelineRegion(id: id, laneID: lane, clipID: clip, startTick: 480, lengthTicks: 960),
                       "a part saved before the late fields existed must open with their defaults")

        let foreign = """
            {"id":"\(id.uuidString)","laneID":"\(lane.uuidString)","clipID":"\(clip.uuidString)",\
            "startTick":0,"lengthTicks":960,"stretchMode":"a-mode-from-a-newer-build",\
            "aFieldFromANewerBuild":42,"fadeInTicks":-5,"fadeOutTicks":-1}
            """
        let opened = try JSONDecoder().decode(TimelineRegion.self, from: Data(foreign.utf8))
        XCTAssertEqual(opened.stretchMode, .clean, "an unknown stretch mode opens as Clean, not as a lost song")
        XCTAssertEqual(opened.fadeInTicks, 0, "a negative fade opens as a hard edge")
        XCTAssertEqual(opened.fadeOutTicks, 0, "a negative fade opens as a hard edge")
        XCTAssertEqual(opened.lengthTicks, 960, "the known fields of a foreign part still open")
    }

    // MARK: - Pure scan helpers (driven on the real file and on the fixture)

    /// The stored properties of `TimelineRegion` that `CodingKeys` does not name, or nil when an
    /// anchor is missing. A stored property is a `public var name: Type` at the struct's own
    /// indentation, between the struct head and its first `init(`, without a `{` (a computed
    /// property carries one).
    static func fieldsMissingFromCodingKeys(in code: String) -> [String]? {
        guard let head = code.range(of: structHead),
              let firstInit = code.range(of: "\n    public init(", range: head.upperBound..<code.endIndex),
              let keys = codingKeys(in: code, after: head.upperBound) else { return nil }
        var stored: [String] = []
        for line in code[head.upperBound..<firstInit.lowerBound].components(separatedBy: "\n") {
            guard line.hasPrefix("    public var "), !line.contains("{") else { continue }
            let rest = line.dropFirst("    public var ".count)
            guard let colon = rest.firstIndex(of: ":") else { continue }
            stored.append(String(rest[rest.startIndex..<colon]).trimmingCharacters(in: .whitespaces))
        }
        guard !stored.isEmpty else { return nil }
        return stored.filter { !keys.contains($0) }
    }

    /// The case names of the first `enum CodingKeys` after `start`, or nil when there is none.
    static func codingKeys(in code: String, after start: String.Index) -> Set<String>? {
        guard let open = code.range(of: "enum CodingKeys: String, CodingKey {", range: start..<code.endIndex),
              let close = code.range(of: "}", range: open.upperBound..<code.endIndex) else { return nil }
        var keys: Set<String> = []
        for line in code[open.upperBound..<close.lowerBound].components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("case ") else { continue }
            for name in trimmed.dropFirst("case ".count).components(separatedBy: ",") {
                let key = name.trimmingCharacters(in: .whitespaces)
                if !key.isEmpty { keys.insert(key) }
            }
        }
        return keys.isEmpty ? nil : keys
    }

    /// `X` in a line holding `decode(X.self` or `decodeIfPresent(X.self`.
    static func decodedType(in line: String) -> String? {
        for call in ["decode(", "decodeIfPresent("] {
            guard let at = line.range(of: call),
                  let dot = line.range(of: ".self", range: at.upperBound..<line.endIndex) else { continue }
            return String(line[at.upperBound..<dot.lowerBound])
        }
        return nil
    }

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present under \(dir.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
