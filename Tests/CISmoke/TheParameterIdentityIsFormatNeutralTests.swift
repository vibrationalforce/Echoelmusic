// TheParameterIdentityIsFormatNeutralTests.swift
// Echoel — WA3.2 (2026-09-24): canonical parameter identity, the AUv3 adapter mapping and the
// minimal device state. Blocking bundle.
//
// THE LAW. A parameter's canonical identity is a stable STRING in a `ParameterDescriptor`. Host
// numbers (AU address, VST3 ParamID, CLAP param_id) live in adapter tables and never become
// Session identity; a host address is never derived from array order. The AUv3's public
// contract — addresses 0…7, identifiers, names, ranges, defaults, units, order — is frozen.
// The four bio parameters at 0…3 are LEGACY LIVE CONTROLS: host-visible for compatibility,
// never creative device state, presets or saved plugin state.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–12 are END-TO-END BEHAVIOUR on the shared, public, Foundation-only types in
//   `DSP/ParameterDescriptor.swift` and `DSP/EchoelBodyVibeDevice.swift` — the same types and
//   the same table the AUv3 extension builds its tree from. Claim 7 drives the REAL engines
//   (`EchoelDDSP`, `EchoelCellular`) through the shared binding.
// · claims 13–14 are SOURCE-TEXT SCANS of the extension (this bundle's host is the app; it
//   cannot instantiate the extension's `AUAudioUnit`): the tree is built from the mapping, and
//   the preset path writes no bio parameter except the one isolated legacy seed.
// · A HOST PROBE (AUM / Logic / GarageBand: tree, automation, preset recall, save/reload) is
//   impossible here and stays owed (`FOUNDER_DEVICE_SESSION.md`).
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the creative parameter SET:
// a new parameter is a new descriptor plus a new adapter entry with a NEW literal address.
// It freezes the eight that hosts already reference. It does not forbid removing the preset
// coherence seed — that is the founder's call (claim 11 says so in its message).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `87d829f42`: every shared
// symbol here (`EchoelBodyVibeDevice`, `EchoelBodyVibeAUv3Mapping`, `EchoelDeviceState`) is
// created by this commit, so claims 1–12 do not COMPILE against the parent — FORWARD guards, no
// verdict there. Claim 13 is a REGRESSION (the parent hand-wrote its tree); claim 14 is a
// REGRESSION too (the parent's presets wrote `coherenceParam` inline, four times). Driven in
// Python against this tree: all green.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheParameterIdentityIsFormatNeutralTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private typealias ID = EchoelBodyVibeDevice.BaseID

    // MARK: - claims 1–12 (END-TO-END)

    /// 1 (A) — canonical creative IDs are unique, dotted, and none is a host identifier.
    func testCanonicalCreativeIDsAreUniqueAndFormatNeutral() {
        let ids = EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate canonical ID in \(ids)")
        for id in ids {
            XCTAssertTrue(id.hasPrefix("bodyvibe."), "`\(id)` is not in the device's namespace")
            XCTAssertFalse(EchoelBodyVibeAUv3Mapping.entries.map(\.identifier).contains(id), """
                `\(id)` is spelled like an AU identifier. Canonical identity must not borrow the \
                adapter's names, or the next adapter inherits the AU's.
                """)
        }
    }

    /// 2 (B) — every creative AU parameter maps to exactly one canonical descriptor.
    func testEveryCreativeAUParameterMapsToExactlyOneDescriptor() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        let creative = resolved.compactMap { r -> String? in
            if case .creative(let id) = r.target { return id }
            return nil
        }
        XCTAssertEqual(creative.count, Set(creative).count)
        XCTAssertEqual(Set(creative), Set(EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath)))
    }

    /// 3 (C, D) — the host contract: addresses 0…7 with their identifiers, exactly.
    func testTheHostAddressesAreTheShippedOnes() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        let expected: [(UInt64, String)] = [
            (0, "coherence"), (1, "hrv"), (2, "heartRate"), (3, "breathPhase"),
            (4, "baseFrequency"), (5, "textureAmount"), (6, "reverbMix"), (7, "masterGain"),
        ]
        XCTAssertEqual(resolved.map(\.address), expected.map { $0.0 }, """
            A host-visible AU address moved. Host projects and automation lanes reference these \
            numbers; renumbering retargets every existing lane.
            """)
        XCTAssertEqual(resolved.map(\.identifier), expected.map { $0.1 })
        for r in resolved where r.address <= 3 {
            guard case .legacyLiveControl = r.target else {
                return XCTFail("address \(r.address) is no longer a legacy live control")
            }
        }
    }

    /// 4 (E) — addresses come from the adapter's literals, never from descriptor order.
    func testNoAddressIsInferredFromDescriptorOrder() throws {
        let forward = try EchoelBodyVibeAUv3Mapping.resolve()
        let reversed = try EchoelBodyVibeAUv3Mapping.resolve(
            descriptors: Array(EchoelBodyVibeDevice.creativeDescriptors.reversed()))
        XCTAssertEqual(forward, reversed, "reordering the descriptors changed the host tree")
        // And reordering the ENTRIES moves the tree order but never an address.
        let shuffled = try EchoelBodyVibeAUv3Mapping.resolve(
            entries: Array(EchoelBodyVibeAUv3Mapping.entries.reversed()))
        var addressOf: [String: UInt64] = [:]
        for r in forward { addressOf[r.identifier] = r.address }
        for r in shuffled {
            XCTAssertEqual(r.address, addressOf[r.identifier],
                           "`\(r.identifier)` changed address when the table order changed")
        }
    }

    /// 5 (F) — names, ranges, defaults, units and groups are the values the AUv3 always shipped.
    func testTheCreativeRangesAndDefaultsAreUnchanged() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        typealias Row = (String, String, Float, Float, Float, AUv3ParameterEntry.Unit,
                         AUv3ParameterEntry.Group)
        let expected: [Row] = [
            ("coherence", "Coherence", 0, 1, 0.5, .generic, .bio),
            ("hrv", "HRV", 0, 1, 0.5, .generic, .bio),
            ("heartRate", "Heart Rate", 0, 1, 0.5, .generic, .bio),
            ("breathPhase", "Breath Phase", 0, 1, 0.5, .generic, .bio),
            ("baseFrequency", "Base Frequency", 40, 440, 220, .hertz, .sound),
            ("textureAmount", "Texture", 0, 1, 0.3, .generic, .sound),
            ("reverbMix", "Reverb", 0, 1, 0.3, .generic, .sound),
            ("masterGain", "Master Gain", 0, 1, 0.7, .linearGain, .sound),
        ]
        XCTAssertEqual(resolved.count, expected.count)
        for (r, e) in zip(resolved, expected) {
            XCTAssertEqual(r.identifier, e.0)
            XCTAssertEqual(r.name, e.1, "`\(r.identifier)` host-visible name changed")
            XCTAssertEqual(r.min, e.2, "`\(r.identifier)` minimum changed")
            XCTAssertEqual(r.max, e.3, "`\(r.identifier)` maximum changed")
            XCTAssertEqual(r.defaultValue, e.4, "`\(r.identifier)` default changed")
            XCTAssertEqual(r.unit, e.5, "`\(r.identifier)` unit changed")
            XCTAssertEqual(r.group, e.6, "`\(r.identifier)` moved group")
        }
    }

    /// 6 — P2 law: nothing in the app binds these, so no Session capability is granted.
    func testTheCreativeDescriptorsGrantNoSessionCapability() {
        for d in EchoelBodyVibeDevice.creativeDescriptors {
            XCTAssertFalse(d.automationEligible, "`\(d.keyPath)` is automation-eligible but unbound")
            XCTAssertFalse(d.modulationEligible, "`\(d.keyPath)` is modulation-eligible but unbound")
        }
        let appCatalog = Set(DDSPParameterCatalog.descriptors.map(\.keyPath))
        XCTAssertTrue(appCatalog.isDisjoint(with: EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath)),
                      "a BodyVibe ID leaked into the app's DDSP catalog")
    }

    /// 7 (G) — every creative ID has a binding, and the binding reaches the intended engine field.
    func testTheCreativeParametersBindToTheirEngineFields() {
        for d in EchoelBodyVibeDevice.creativeDescriptors {
            XCTAssertNotNil(EchoelBodyVibeDevice.binding(for: d.keyPath),
                            "`\(d.keyPath)` is registered but UNBOUND")
        }
        XCTAssertNil(EchoelBodyVibeDevice.binding(for: "coherence"),
                     "a live control resolved to a creative binding")
        XCTAssertNil(EchoelBodyVibeDevice.binding(for: "bodyvibe.unknown"))

        let synth = EchoelDDSP(sampleRate: 48000)
        let texture = EchoelCellular(cellCount: 128, sampleRate: 48000)
        EchoelBodyVibeDevice.apply(.pitch, value: 330, synth: synth, texture: texture)
        XCTAssertEqual(synth.frequency, 330)
        XCTAssertEqual(texture.frequency, 165)
        EchoelBodyVibeDevice.apply(.textureGain, value: 0.4, synth: synth, texture: texture)
        XCTAssertEqual(texture.gain, 0.4)
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: 0.6, synth: synth, texture: texture)
        XCTAssertEqual(synth.reverbMix, 0.6)
        // The output gain belongs to the adapter's own stage: it must touch no engine field.
        let before = (synth.frequency, synth.reverbMix, texture.gain, texture.frequency)
        EchoelBodyVibeDevice.apply(.outputGain, value: 0.1, synth: synth, texture: texture)
        XCTAssertEqual(synth.frequency, before.0)
        XCTAssertEqual(synth.reverbMix, before.1)
        XCTAssertEqual(texture.gain, before.2)
        XCTAssertEqual(texture.frequency, before.3)
    }

    /// 8 (H) — bio control parameters can never be creative device state.
    func testTheDeviceStateHoldsNoBodyReading() throws {
        let creativeIDs = Set(EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath))
        for control in LegacyLiveControl.allCases {
            XCTAssertFalse(creativeIDs.contains(control.rawValue))
        }
        var values: [String: Float] = [ID.baseFrequency: 55, ID.masterGain: 5]
        for control in LegacyLiveControl.allCases { values[control.rawValue] = 0.9 }
        values["bodyvibe.bio.heartRate"] = 0.9
        values[ID.textureAmount] = .nan
        let state = EchoelDeviceState(deviceType: EchoelBodyVibeDevice.typeID,
                                      parameterValues: values)
            .sanitized(against: EchoelBodyVibeDevice.creativeDescriptors)
        XCTAssertEqual(Set(state.parameterValues.keys), [ID.baseFrequency, ID.masterGain], """
            Sanitized state kept a key that is not a creative descriptor. Heart rate, HRV, \
            coherence and breath phase must never survive into device state.
            """)
        XCTAssertEqual(state.parameterValues[ID.baseFrequency], 55)
        XCTAssertEqual(state.parameterValues[ID.masterGain], 1, "an out-of-range value must clamp")
    }

    /// 9 — the minimal state round-trips, carries SynthPatch as a COMPONENT, and decodes lossily.
    func testTheDeviceStateRoundTripsAndDecodesLossily() throws {
        let patch = try XCTUnwrap(SynthPatch.factory.first, "no factory patch to carry")
        let state = EchoelDeviceState(deviceType: EchoelBodyVibeDevice.typeID, patch: patch,
                                      parameterValues: [ID.reverbMix: 0.4])
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(EchoelDeviceState.self, from: data)
        XCTAssertEqual(back, state)
        XCTAssertEqual(back.schemaVersion, EchoelDeviceState.currentSchemaVersion)

        let broken = Data(#"{"deviceType":"echoel.bodyvibe","patch":42,"parameterValues":"x"}"#.utf8)
        let lossy = try JSONDecoder().decode(EchoelDeviceState.self, from: broken)
        XCTAssertNil(lossy.patch, "an unreadable patch must cost only the patch")
        XCTAssertTrue(lossy.parameterValues.isEmpty)
        XCTAssertEqual(lossy.schemaVersion, EchoelDeviceState.currentSchemaVersion)
    }

    /// 10 (K, L) — a broken table fails loudly; nothing is silently retargeted.
    func testABrokenMappingFailsInsteadOfRetargeting() {
        let descriptors = EchoelBodyVibeDevice.creativeDescriptors
        let entries = EchoelBodyVibeAUv3Mapping.entries
        guard let first = descriptors.first, let lastEntry = entries.last else {
            return XCTFail("the catalog or the mapping is empty")
        }

        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolve(descriptors: descriptors + [first])) {
            XCTAssertEqual($0 as? AUv3MappingError, .duplicateCanonicalID(first.keyPath))
        }
        let unknown = AUv3ParameterEntry(address: 8, identifier: "ghost",
                                         target: .creative("bodyvibe.ghost"),
                                         unit: .generic, group: .sound)
        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolve(entries: entries + [unknown])) {
            XCTAssertEqual($0 as? AUv3MappingError, .unknownCanonicalID("bodyvibe.ghost"))
        }
        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolve(entries: Array(entries.dropLast()))) {
            guard case .unmappedCreativeDescriptor? = $0 as? AUv3MappingError else {
                return XCTFail("a descriptor without an AU entry was not reported: \($0)")
            }
        }
        let clash = AUv3ParameterEntry(address: lastEntry.address, identifier: "clash",
                                       target: .legacyLiveControl(.hrv),
                                       unit: .generic, group: .bio)
        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolve(entries: entries + [clash])) {
            XCTAssertEqual($0 as? AUv3MappingError, .duplicateAddress(lastEntry.address))
        }
        let twin = AUv3ParameterEntry(address: 9, identifier: lastEntry.identifier,
                                      target: .legacyLiveControl(.hrv),
                                      unit: .generic, group: .bio)
        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolve(entries: entries + [twin])) {
            XCTAssertEqual($0 as? AUv3MappingError, .duplicateIdentifier(lastEntry.identifier))
        }
    }

    /// 11 (I) — factory presets are creative state; the coherence seed is isolated, not creative.
    func testFactoryPresetsCarryNoBodyReadingAsCreativeState() {
        let creativeIDs = Set(EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath))
        let presets = EchoelBodyVibeDevice.factoryPresets
        XCTAssertEqual(presets.map(\.number), [0, 1, 2], "a preset number moved")
        XCTAssertEqual(presets.map(\.name), ["Ambient Calm", "Deep Sleep", "Active Focus"])
        for preset in presets {
            XCTAssertTrue(Set(preset.creativeValues.keys).isSubset(of: creativeIDs), """
                `\(preset.name)` names a key that is not a creative descriptor: \
                \(preset.creativeValues.keys.sorted()).
                """)
            for control in LegacyLiveControl.allCases {
                XCTAssertNil(preset.creativeValues[control.rawValue])
            }
        }
        // ⛔ HOLD-FOR-FOUNDER: the seed is the one remaining bio write. Removing it is legitimate
        // (it changes two presets' sound — see `Preset.legacyCoherenceSeed`) and then this
        // assertion is simply updated; what it forbids is the seed quietly spreading to
        // another live control or back into `creativeValues`.
        XCTAssertEqual(presets.map(\.legacyCoherenceSeed), [0.7, 0.8, 0.5])
    }

    /// 12 (J) — WA3.1 still holds: what the AUv3 saves is exactly the mapping's creative set.
    func testWA31StillSavesOnlyTheCreativeSet() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        var values: [String: Float] = [:]
        var creativeIDs: Set<String> = []
        var live: Set<String> = []
        for r in resolved {
            switch r.target {
            case .creative:
                creativeIDs.insert(r.identifier)
                values[r.identifier] = r.defaultValue
            case .legacyLiveControl:
                live.insert(r.identifier)
                values[r.identifier] = 0.9
            }
        }
        let saved = AUv3StateContract.savedState(base: ["name": "Untitled"],
                                                 persistedValues: values)
        for identifier in live {
            XCTAssertNil(saved[identifier], "`\(identifier)` reached saved state again")
        }
        XCTAssertEqual(Set(AUv3StateContract.persistedParameterIdentifiers), creativeIDs)
        for identifier in creativeIDs {
            XCTAssertNotNil(saved[identifier], "`\(identifier)` is creative and was not saved")
        }
    }

    // MARK: - claims 13–14 (SOURCE-TEXT SCANS of the extension)

    /// 13 — the extension builds its tree from the mapping; no parameter is hand-spelled there.
    func testTheAudioUnitBuildsItsTreeFromTheMapping() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        guard let body = Self.body(startingWith: "private func setupParameterTree() throws", in: code) else {
            return XCTFail("`setupParameterTree() throws` is gone from \(Self.audioUnit) — re-anchor")
        }
        XCTAssertTrue(body.contains("EchoelBodyVibeAUv3Mapping.resolve()"),
                      "the AUv3 tree is no longer built from the adapter mapping")
        for identifier in EchoelBodyVibeAUv3Mapping.entries.map(\.identifier) {
            XCTAssertFalse(body.contains("withIdentifier: \"\(identifier)\""), """
                `\(identifier)` is hand-spelled in the tree again — a second list beside the \
                mapping, which is how a host address drifts from the canonical table.
                """)
        }
        XCTAssertTrue(code.contains("try setupParameterTree()"),
                      "a mapping failure no longer propagates out of init")
    }

    /// 14 (I) — the preset path writes creative values through the mapping and touches exactly
    /// one live control, through the isolated seed.
    func testThePresetPathWritesNoBodyReadingExceptTheSeed() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        guard let body = Self.body(startingWith: "public override var currentPreset", in: code) else {
            return XCTFail("`currentPreset` is gone from \(Self.audioUnit) — re-anchor")
        }
        XCTAssertTrue(body.contains("EchoelBodyVibeDevice.factoryPresets"),
                      "the presets are hand-written in the extension again")
        for param in ["hrvParam", "heartRateParam", "breathPhaseParam"] {
            XCTAssertFalse(body.contains(param), "a preset now writes `\(param)`")
        }
        XCTAssertEqual(body.components(separatedBy: "coherenceParam.value").count - 1, 1, """
            The preset path writes `coherenceParam` other than through the one legacy seed.
            """)
        XCTAssertTrue(body.contains("preset.legacyCoherenceSeed"))
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
