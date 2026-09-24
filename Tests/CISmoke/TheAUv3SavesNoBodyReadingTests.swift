// TheAUv3SavesNoBodyReadingTests.swift
// Echoel — WA3.1 (2026-09-24), AUv3 bio state privacy repair. Blocking bundle.
//
// THE DEFECT. `EchoelmusicAudioUnit.fullState` wrote all eight parameter-tree values into the
// dictionary a host saves in ITS project file — the four bio inputs (`coherence`, `hrv`,
// `heartRate`, `breathPhase`) included. Those are the parameters the App-Group vitals bridge
// writes from a live body. Echoel cannot erase a third-party host document. Measured today the
// bridge is DEAD in the shipped extension (`EchoelmusicAUv3.entitlements` carries no App Group,
// removed 2026-07-19 over -3000), so the values that reached a document were host automation,
// the plug-in UI or a factory preset — the defect was latent, not leaking. The repair makes the
// rule structural: runtime bio input is not saved plugin state.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–6 are END-TO-END BEHAVIOUR on `AUv3StateContract`, the Foundation-only type in
//   `Core/BioFeedbackManager.swift` that BOTH the app and the extension compile. The dictionaries
//   are real, and claim 5 sends them through `PropertyListSerialization`, the format a host
//   document holds. ⚠️ This bundle's host is the APP; it cannot instantiate the extension's
//   `AUAudioUnit` subclass, so the base class's own `super.fullState` is SIMULATED here with the
//   `kAUPresetDataKey` blob key the contract strips — what Apple's base getter actually emits is
//   NOT observed by this file (HOST VERIFY OWED).
// · claims 7–9 are SOURCE-TEXT SCANS of the extension: that its getter and setter route through
//   the contract, that the contract's two lists cover exactly the tree's eight identifiers, and
//   that host-visible addresses 0…7 did not move.
// · DEVICE / HOST PROBE — a real AUM/Logic/GarageBand save → reload — is impossible here.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not forbid persisting a future bio ROUTE
// (user-authored, creative); it forbids persisting a bio READING. It does not freeze the
// creative parameter set: adding a parameter means adding its identifier to ONE of the two
// lists in the same commit, which claim 8 demands by name.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `59a243958`: the contract type
// does not exist there, so claims 1–6 and 8 do not COMPILE against it — no verdict, FORWARD
// guards (they drive a symbol this commit creates). Claim 7 is a REGRESSION: on the parent the
// getter wrote every identifier and named no contract — red for its named reason. Claim 9 is a
// COUNTERWEIGHT, green on both trees. Driven in Python against this tree: all nine green.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAUv3SavesNoBodyReadingTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    /// The tree's ranges, as `setupParameterTree` declares them.
    private static let ranges: [String: ClosedRange<Float>] = [
        "coherence": 0...1, "hrv": 0...1, "heartRate": 0...1, "breathPhase": 0...1,
        "baseFrequency": 40...440, "textureAmount": 0...1, "reverbMix": 0...1, "masterGain": 0...1,
    ]

    private static let creative: [String: Float] = [
        "baseFrequency": 330, "textureAmount": 0.4, "reverbMix": 0.2, "masterGain": 0.7,
    ]

    /// What a pre-WA3.1 build wrote: the base class's keys, its parameter blob, and all eight
    /// explicit values — four of them body readings.
    private static func legacyDocument() -> [String: Any] {
        [
            "type": 1635085685, "subtype": 1701013612, "manufacturer": 1164142703,
            "version": 0, "name": "Untitled",
            AUv3StateContract.baseParameterSnapshotKey: Data([0x01, 0x02, 0x03]),
            "coherence": Float(0.81), "hrv": Float(0.42), "heartRate": Float(0.37),
            "breathPhase": Float(0.66),
            "baseFrequency": Float(55), "textureAmount": Float(0.1),
            "reverbMix": Float(0.6), "masterGain": Float(0.9),
        ]
    }

    // MARK: - claims 1–6 (END-TO-END on the contract)

    /// 1 (A) — a new save carries the creative sound state, and the base's identity keys survive.
    func testANewSaveCarriesTheCreativeSoundState() {
        let saved = AUv3StateContract.savedState(base: ["name": "Untitled"],
                                                 persistedValues: Self.creative)
        for (identifier, value) in Self.creative {
            XCTAssertEqual(saved[identifier] as? Float, value, """
                `\(identifier)` is missing from the saved state. It is a CREATIVE parameter — \
                a host reload would lose the sound the person made.
                """)
        }
        XCTAssertEqual(saved["name"] as? String, "Untitled",
                       "a non-parameter base key was dropped; only the parameter blob may go")
    }

    /// 2 (B–E) — a new save carries no heart rate, HRV, coherence or breath phase, even when the
    /// base dictionary and the caller both hand them in, and not the base's parameter blob either.
    func testANewSaveCarriesNoBodyReading() {
        var polluted = Self.creative
        for identifier in AUv3StateContract.transientParameterIdentifiers {
            polluted[identifier] = 0.5
        }
        let saved = AUv3StateContract.savedState(base: Self.legacyDocument(),
                                                 persistedValues: polluted)
        for identifier in ["heartRate", "hrv", "coherence", "breathPhase"] {
            XCTAssertNil(saved[identifier], """
                `\(identifier)` reached the saved state. A host stores this dictionary in ITS \
                project file, which Echoel cannot erase — a body reading must never go there.
                """)
        }
        XCTAssertNil(saved[AUv3StateContract.baseParameterSnapshotKey], """
            The base class's parameter snapshot survived. It holds EVERY tree value, the bio \
            ones included, so stripping only the explicit keys leaves the readings in the blob.
            """)
    }

    /// 3 (F, I) — a legacy document restores its creative values, clamped, without failure.
    func testALegacyDocumentStillRestoresItsSound() {
        let restored = AUv3StateContract.restorableValues(from: Self.legacyDocument(),
                                                          ranges: Self.ranges)
        XCTAssertEqual(restored["baseFrequency"], 55)
        XCTAssertEqual(restored["textureAmount"], 0.1)
        XCTAssertEqual(restored["reverbMix"], 0.6)
        XCTAssertEqual(restored["masterGain"], 0.9)

        // I — the pre-WA3.1 hardening is unchanged: out-of-range clamps, non-finite drops.
        let hostile: [String: Any] = ["baseFrequency": Float(10_000),
                                      "masterGain": Float.nan,
                                      "reverbMix": "loud"]
        let clamped = AUv3StateContract.restorableValues(from: hostile, ranges: Self.ranges)
        XCTAssertEqual(clamped["baseFrequency"], 440, "an out-of-range value must clamp")
        XCTAssertNil(clamped["masterGain"], "a NaN from a third-party document must be dropped")
        XCTAssertNil(clamped["reverbMix"], "a non-numeric entry must be dropped, not coerced")
        XCTAssertTrue(AUv3StateContract.restorableValues(from: nil, ranges: Self.ranges).isEmpty)
    }

    /// 4 (G) — legacy bio values never come back out as values to apply, and the base restore
    /// never sees them as explicit keys.
    func testLegacyBodyReadingsAreNotRestoredAsTruth() {
        let restored = AUv3StateContract.restorableValues(from: Self.legacyDocument(),
                                                          ranges: Self.ranges)
        for identifier in AUv3StateContract.transientParameterIdentifiers {
            XCTAssertNil(restored[identifier], """
                The legacy `\(identifier)` value came back as state to apply. It is accepted \
                for compatibility only; it must not become the plug-in's value.
                """)
        }
        let forBase = AUv3StateContract.stateForBaseRestore(Self.legacyDocument()) ?? [:]
        for identifier in AUv3StateContract.transientParameterIdentifiers {
            XCTAssertNil(forBase[identifier], "the base restore was handed `\(identifier)`")
        }
        XCTAssertNotNil(forBase[AUv3StateContract.baseParameterSnapshotKey], """
            The base snapshot was stripped on RESTORE. An older document may need it for its \
            creative values; the AUv3 undoes any bio value it replays instead.
            """)
    }

    /// 5 (F, H) — the real round trip: a legacy document through a property list (what a host
    /// file holds), restored, re-saved — and the re-save omits every body reading.
    func testReSavingALegacyDocumentOmitsTheBody() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: Self.legacyDocument(),
                                                      format: .binary, options: 0)
        let reloaded = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            "a legacy document no longer decodes as a dictionary")
        let restored = AUv3StateContract.restorableValues(from: reloaded, ranges: Self.ranges)
        XCTAssertEqual(restored.count, AUv3StateContract.persistedParameterIdentifiers.count, """
            After a property-list round trip the numbers come back as NSNumber/Double; the \
            contract must still read every creative value.
            """)
        let resaved = AUv3StateContract.savedState(base: reloaded, persistedValues: restored)
        for identifier in AUv3StateContract.transientParameterIdentifiers {
            XCTAssertNil(resaved[identifier], "re-saving a legacy document kept `\(identifier)`")
        }
        XCTAssertNil(resaved[AUv3StateContract.baseParameterSnapshotKey])
        XCTAssertEqual(resaved["baseFrequency"] as? Float, 55)
        XCTAssertNoThrow(try PropertyListSerialization.data(fromPropertyList: resaved,
                                                            format: .binary, options: 0),
                         "the re-saved state is no longer a valid property list")
    }

    /// 6 — the two lists are disjoint: a parameter cannot be both kept and dropped.
    func testNoParameterIsBothPersistedAndTransient() {
        let both = Set(AUv3StateContract.persistedParameterIdentifiers)
            .intersection(AUv3StateContract.transientParameterIdentifiers)
        XCTAssertTrue(both.isEmpty, "classified twice: \(both.sorted())")
    }

    // MARK: - claims 7–9 (SOURCE-TEXT SCANS of the extension)

    /// 7 — the extension's getter and setter route through the contract. REGRESSION on the parent.
    func testTheAudioUnitSavesThroughTheContract() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        guard let body = Self.body(startingWith: "public override var fullState", in: code) else {
            return XCTFail("`public override var fullState` is gone from \(Self.audioUnit) — re-anchor")
        }
        XCTAssertTrue(body.contains("AUv3StateContract.savedState(base: super.fullState"), """
            The AUv3 getter no longer builds its dictionary through `AUv3StateContract.savedState`. \
            Writing parameter values directly is how the four bio readings reached host documents.
            """)
        XCTAssertTrue(body.contains("AUv3StateContract.stateForBaseRestore(newValue)"),
                      "the setter hands the raw document to the base class again")
        XCTAssertTrue(body.contains("AUv3StateContract.restorableValues(from: newValue"),
                      "the setter no longer restores through the contract")
        XCTAssertFalse(body.contains("s[p.identifier] = p.value"),
                       "the pre-WA3.1 write-every-parameter loop is back")
    }

    /// 8 — the contract's two lists are EXACTLY the tree's identifiers. A new parameter must be
    /// classified in the same commit; an unclassified one would silently fail closed (not saved).
    func testEveryTreeParameterIsClassified() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        var declared: Set<String> = []
        var rest = Substring(code)
        let needle = "withIdentifier: \""
        while let hit = rest.range(of: needle) {
            let after = rest[hit.upperBound...]
            guard let close = after.firstIndex(of: "\"") else { break }
            declared.insert(String(after[..<close]))
            rest = after[close...]
        }
        declared.subtract(["bio", "sound"])   // the two GROUP identifiers, not parameters
        guard !declared.isEmpty else {
            return XCTFail("no `withIdentifier:` found in \(Self.audioUnit) — the parser matched nothing")
        }
        let classified = Set(AUv3StateContract.persistedParameterIdentifiers)
            .union(AUv3StateContract.transientParameterIdentifiers)
        XCTAssertEqual(declared, classified, """
            The AUv3 tree and `AUv3StateContract` disagree. Add a new parameter's identifier to \
            persistedParameterIdentifiers (creative) OR transientParameterIdentifiers (a live \
            reading) in the same commit.
            """)
    }

    /// 9 — COUNTERWEIGHT. Host compatibility: the addresses a host automates did not move.
    func testTheHostVisibleAddressesAreUnchanged() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let expected = ["case coherence = 0", "case hrv = 1", "case heartRate = 2",
                        "case breathPhase = 3", "case baseFrequency = 4", "case textureAmount = 5",
                        "case reverbMix = 6", "case masterGain = 7"]
        for line in expected {
            XCTAssertTrue(code.contains(line), """
                `\(line)` is gone from `ParameterAddress`. A host saved automation against these \
                numbers; moving one retargets every existing automation lane.
                """)
        }
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
