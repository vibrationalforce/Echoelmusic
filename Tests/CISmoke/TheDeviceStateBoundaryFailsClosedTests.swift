// TheDeviceStateBoundaryFailsClosedTests.swift
// Echoel — 2026-09-24 (overnight P3): `EchoelDeviceState` has one read boundary and one write
// boundary, and both fail closed. Blocking bundle.
//
// THE DEFECT (measured before the repair). The WA3.2 value type had `sanitized(against:)` and a
// lossy decoder, and nothing that joined them:
//   · a decoded state was never sanitized unless a caller remembered to — and it had to pick
//     the right descriptor set itself; nothing resolved `deviceType` to one;
//   · an unknown `deviceType` decoded fine; its values could not be checked against anything;
//   · `schemaVersion` fell back to the CURRENT version when it was unreadable, so a corrupted
//     or foreign document read as a well-formed one of this build, and a document from a NEWER
//     build was accepted without a word;
//   · there was no write path, so a caller encoding a state with a NaN value would meet
//     `JSONEncoder`'s own error, and one with a bio key would write it.
//
// THE REPAIR (value layer only — no caller, no Session writer, no persistence root, no Track,
// no multi-instance runtime; nothing here needs `project.yml` or #95). `validated()` = migrate
// (the ONE migration entry point) → resolve the type to its descriptors
// (`creativeDescriptors(forDeviceType:)`) → sanitize values and fold the patch into its bounds.
// `restored(from:into:)` = decode + the state must be FOR the device it is loaded into + validate;
// `encodedForStorage()` = validate + encode. Refusals are `EchoelDeviceStateError`: unknown type,
// wrong type, future schema, invalid schema.
//
// WHAT KIND OF GREEN (§1): every claim is END-TO-END BEHAVIOUR on the shipped, public value type
// — JSON in, state or error out. There is no device or host half: nothing calls this yet.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the schema at 1. A v2 adds its
// step to `migrated(_:)`; claim 4 reads `currentSchemaVersion` rather than a literal, so it moves
// with it.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `05968e1b5`: `validated`,
// `restored`, `encodedForStorage`, `migrated`, `creativeDescriptors(forDeviceType:)` and
// `EchoelDeviceStateError` do not exist, so the file does not COMPILE there — no assertion has a
// verdict on the parent. All claims are FORWARD guards; the counterweights in claims 2 and 5
// (a bare `JSONEncoder` rejects NaN; the descriptors name no bio input) would be green there.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDeviceStateBoundaryFailsClosedTests: XCTestCase {

    private typealias ID = EchoelBodyVibeDevice.BaseID
    private let type = EchoelBodyVibeDevice.typeID

    // MARK: - claim 1 (READ)

    func testARestoredStateKeepsOnlyFiniteInRangeCreativeValues() throws {
        let json = #"""
        {"schemaVersion":1,"deviceType":"echoel.bodyvibe","parameterValues":{
          "bodyvibe.osc.baseFrequency":330,
          "bodyvibe.out.masterGain":9999,
          "coherence":0.9,"hrv":0.9,"heartRate":0.9,"breathPhase":0.9,
          "bodyvibe.bio.heartRate":0.9,
          "bodyvibe.ghost":0.5}}
        """#
        let state = try EchoelDeviceState.restored(from: Data(json.utf8), into: type)
        XCTAssertEqual(Set(state.parameterValues.keys), [ID.baseFrequency, ID.masterGain], """
            A restored state kept a key that no creative descriptor names. Bio inputs, live \
            controls and unknown IDs must never become active device state.
            """)
        XCTAssertEqual(state.parameterValues[ID.baseFrequency], 330)
        XCTAssertEqual(state.parameterValues[ID.masterGain], 1, "an out-of-range value was not clamped")

        var inMemory = EchoelDeviceState(deviceType: type, parameterValues: [
            ID.textureAmount: .nan, ID.reverbMix: .infinity, ID.masterGain: -.infinity,
        ])
        inMemory.schemaVersion = EchoelDeviceState.currentSchemaVersion
        XCTAssertTrue(try inMemory.validated().parameterValues.isEmpty,
                      "a non-finite value survived validation")
    }

    // MARK: - claim 2 (WRITE)

    func testWritingGoesThroughTheSameGate() throws {
        let dirty = EchoelDeviceState(deviceType: type, parameterValues: [
            ID.reverbMix: 0.4, ID.textureAmount: .nan, LegacyLiveControl.heartRate.rawValue: 0.8,
        ])
        // COUNTERWEIGHT — the bare encoder cannot write this at all, so the boundary is the
        // thing that makes a write possible, not decoration.
        XCTAssertThrowsError(try JSONEncoder().encode(dirty),
                             "JSONEncoder now accepts NaN — this claim no longer shows the gate is load-bearing")

        let data = try dirty.encodedForStorage()
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let values = try XCTUnwrap(raw["parameterValues"] as? [String: Any])
        XCTAssertEqual(Set(values.keys), [ID.reverbMix], """
            The write boundary stored a key that is not a finite creative value: \(values.keys.sorted()).
            """)
        XCTAssertEqual(try EchoelDeviceState.restored(from: data, into: type),
                       try dirty.validated(), "write then read is not the identity on a validated state")
    }

    // MARK: - claim 3

    func testAnUnknownDeviceTypeFailsClosedBothWays() {
        let json = #"{"schemaVersion":1,"deviceType":"echoel.ghost","parameterValues":{"x":1}}"#
        XCTAssertThrowsError(try EchoelDeviceState.restored(from: Data(json.utf8), into: "echoel.ghost")) {
            XCTAssertEqual($0 as? EchoelDeviceStateError, .unknownDeviceType("echoel.ghost"))
        }
        XCTAssertThrowsError(try EchoelDeviceState.restored(from: Data(json.utf8), into: type)) {
            XCTAssertEqual($0 as? EchoelDeviceStateError,
                           .wrongDeviceType(expected: EchoelBodyVibeDevice.typeID, found: "echoel.ghost"),
                           "a state written for another device was loaded into BodyVibe — reject, never coerce")
        }
        XCTAssertThrowsError(try EchoelDeviceState(deviceType: "echoel.ghost").encodedForStorage()) {
            XCTAssertEqual($0 as? EchoelDeviceStateError, .unknownDeviceType("echoel.ghost"))
        }
        XCTAssertNil(EchoelDeviceState.creativeDescriptors(forDeviceType: "echoel.ghost"))
        XCTAssertNotNil(EchoelDeviceState.creativeDescriptors(forDeviceType: type),
                        "the one known type no longer resolves — every state would be refused")
    }

    // MARK: - claim 4 (SCHEMA POLICY)

    func testTheSchemaPolicyRefusesTheFutureAndTheInvalid() throws {
        let current = EchoelDeviceState.currentSchemaVersion
        func restore(_ schemaField: String) throws -> EchoelDeviceState {
            let json = "{" + schemaField + #""deviceType":"echoel.bodyvibe"}"#
            return try EchoelDeviceState.restored(from: Data(json.utf8),
                                                  into: EchoelBodyVibeDevice.typeID)
        }

        XCTAssertThrowsError(try restore(#""schemaVersion":\#(current + 1),"#)) {
            XCTAssertEqual($0 as? EchoelDeviceStateError, .futureSchema(current + 1), """
                A document from a newer build was accepted. Its unknown fields would be dropped \
                and the next write would erase them.
                """)
        }
        for bad in [0, -3] {
            XCTAssertThrowsError(try restore(#""schemaVersion":\#(bad),"#)) {
                XCTAssertEqual($0 as? EchoelDeviceStateError, .invalidSchema(bad))
            }
        }
        XCTAssertThrowsError(try restore(#""schemaVersion":"x","#)) {
            XCTAssertEqual($0 as? EchoelDeviceStateError,
                           .invalidSchema(EchoelDeviceState.unreadableSchemaVersion), """
                An unreadable schema version was read as a valid one. It used to become the \
                CURRENT version.
                """)
        }
        XCTAssertEqual(try restore("").schemaVersion, current,
                       "a document without the key must read as the first version and migrate up")
        let now = EchoelDeviceState(deviceType: type)
        XCTAssertEqual(try EchoelDeviceState.migrated(now), now, "migrating a current state changed it")
    }

    // MARK: - claim 5

    func testThePatchIsFoldedIntoItsBoundsAndNoBioNameIsCreative() throws {
        var patch = try XCTUnwrap(SynthPatch.factory.first, "no factory patch to carry")
        patch.filterCutoff = 1e9
        patch.reverbMix = -4
        let state = try EchoelDeviceState(deviceType: type, patch: patch).validated()
        let kept = try XCTUnwrap(state.patch, "validation dropped a readable patch")
        XCTAssertLessThanOrEqual(kept.filterCutoff, SynthPatch.Bounds.filterCutoff.upperBound)
        XCTAssertGreaterThanOrEqual(kept.reverbMix, SynthPatch.Bounds.reverbMix.lowerBound)

        // COUNTERWEIGHT — the read gate drops bio names because no descriptor names one. If a
        // descriptor ever did, claim 1 would pass a bio value straight through.
        let names = Set((EchoelDeviceState.creativeDescriptors(forDeviceType: type) ?? []).map(\.keyPath))
        for control in LegacyLiveControl.allCases {
            XCTAssertFalse(names.contains(control.rawValue), "\(control.rawValue) became a creative descriptor")
        }
        XCTAssertFalse(names.contains { $0.contains(".bio.") }, "a creative descriptor is named as a bio input")
    }
}
