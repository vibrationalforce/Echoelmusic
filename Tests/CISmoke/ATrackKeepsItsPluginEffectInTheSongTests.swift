//
//  ATrackKeepsItsPluginEffectInTheSongTests.swift
//  Production level H6-1 — a third-party Audio Unit EFFECT on a track is one insert of the track's
//  chain (`Core/PluginEffectInsert.swift`). Nothing sounds from it yet; the writer, host and graph
//  insert follow (`scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md`).
//
//  KIND: END-TO-END BEHAVIOUR — `DeviceChain`/`DeviceInsert` are shipped Foundation-only value
//  types, driven directly.
//
//  GRADING against the parent tree (#433/#464): `pluginEffect`, `pluginEffectComponent`,
//  `settingPluginEffect` and `soundingPluginEffect` do not exist there — the file does not compile
//  on the parent, so no assertion has a verdict there (ONE absence, #486). Claims 1–5 are forward
//  guards, transcribed by reading the setter. COUNTERWEIGHTS (#343): claim 2 (other inserts and the
//  instrument untouched) and claim 6 (the two readers never answer for each other).
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class ATrackKeepsItsPluginEffectInTheSongTests: XCTestCase {

    private static let delay = DeviceInsert.PluginComponent(type: 0x6175_6678, subtype: 3, manufacturer: 5,
                                                            name: "Delay", manufacturerName: "Acme")
    private static let reverb = DeviceInsert.PluginComponent(type: 0x6175_6678, subtype: 4, manufacturer: 5,
                                                             name: "Reverb", manufacturerName: "Acme")
    private static let synth = DeviceInsert.PluginComponent(type: 0x6175_6D75, subtype: 7, manufacturer: 9,
                                                            name: "Synth", manufacturerName: "Acme")

    // MARK: 1 — round trip

    func testAnEffectRoundTripsThroughTheChain() throws {
        let chain = try XCTUnwrap(DeviceChain(inserts: []).settingPluginEffect(Self.delay))
        XCTAssertEqual(chain.soundingPluginEffect, Self.delay)
        XCTAssertEqual(chain.pluginEffectInsert?.typeID, DeviceInsert.pluginEffectTypeID)
        let decoded = try JSONDecoder().decode(DeviceChain.self, from: JSONEncoder().encode(chain))
        XCTAssertEqual(decoded.soundingPluginEffect, Self.delay, "the song keeps the effect")
    }

    // MARK: 2 — counterweight: other inserts and the instrument stay

    func testOtherInsertsAndTheInstrumentStayInPlace() throws {
        let unknown = DeviceInsert(typeID: "com.example.later", typeVersion: 3, isEnabled: true, stateBlob: Data([7]))
        var start = DeviceChain(inserts: [DeviceInsert.grain(GrainSettings()), unknown])
        start.instrument = DeviceInsert.pluginInstrument(Self.synth)
        let chain = try XCTUnwrap(start.settingPluginEffect(Self.delay))
        XCTAssertEqual(Array(chain.inserts.prefix(2)), start.inserts, "existing inserts keep their place and bytes")
        XCTAssertEqual(chain.instrument, start.instrument, "the instrument is never touched")
        let removed = try XCTUnwrap(chain.settingPluginEffect(nil))
        XCTAssertEqual(removed, start, "removing the effect gives the chain back as it was")
    }

    // MARK: 3 — at most one effect; the same pick keeps its insert

    func testAtMostOneEffectAndTheSamePickKeepsItsInsert() throws {
        let first = try XCTUnwrap(DeviceChain(inserts: []).settingPluginEffect(Self.delay))
        let again = try XCTUnwrap(first.settingPluginEffect(Self.delay))
        XCTAssertEqual(again, first, "picking the same effect changes nothing")
        let other = try XCTUnwrap(first.settingPluginEffect(Self.reverb))
        XCTAssertEqual(other.inserts.count, 1)
        XCTAssertEqual(other.soundingPluginEffect, Self.reverb)
        XCTAssertEqual(other.pluginEffectInsert?.id, first.pluginEffectInsert?.id, "the slot keeps its identity")
        var twice = first
        twice.inserts.append(DeviceInsert.pluginEffect(Self.reverb))
        let cleaned = try XCTUnwrap(twice.settingPluginEffect(Self.delay))
        XCTAssertEqual(cleaned.inserts.filter { $0.typeID == DeviceInsert.pluginEffectTypeID }.count, 1)
    }

    // MARK: 4 — nil removes it; an empty chain is none

    func testNilRemovesTheEffectAndAnEmptyChainIsNone() throws {
        let chain = try XCTUnwrap(DeviceChain(inserts: []).settingPluginEffect(Self.delay))
        XCTAssertNil(chain.settingPluginEffect(nil), "nothing left → the lane stores no chain")
    }

    // MARK: 5 — a later format fails closed

    func testALaterFormatFailsClosed() {
        var later = DeviceInsert.pluginEffect(Self.delay)
        later.typeVersion = DeviceInsert.pluginEffectTypeVersion + 1
        XCTAssertNil(later.pluginEffectComponent, "a later build's effect is never loaded with v1 meaning")
        XCTAssertNil(DeviceChain(inserts: [later]).soundingPluginEffect)
        var disabled = DeviceInsert.pluginEffect(Self.delay)
        disabled.isEnabled = false
        XCTAssertNil(DeviceChain(inserts: [disabled]).soundingPluginEffect, "a disabled effect does not sound")
    }

    // MARK: 6 — counterweight: the two readers never answer for each other

    func testAnEffectIsNeverReadAsAnInstrument() {
        XCTAssertNil(DeviceInsert.pluginEffect(Self.delay).pluginComponent,
                     "an effect insert must never load as an instrument")
        XCTAssertNil(DeviceInsert.pluginInstrument(Self.synth).pluginEffectComponent,
                     "an instrument insert must never load as an effect")
    }
}
