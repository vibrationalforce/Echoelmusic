//
//  APluginKeepsItsSettingsInTheSongTests.swift
//  Production level H4a — a hosted Audio Unit's own settings (`fullStateForDocument`) ride in the
//  track's instrument insert, so a song can bring the sound back after a relaunch.
//
//  KIND: END-TO-END BEHAVIOUR (claims 1–3) — `DeviceInsert` is a shipped Foundation-only value
//  type, driven directly. SOURCE-TEXT SCAN (claim 4) for the store's one writer, (claim 5, H4b)
//  for the capture when the plugin window closes. Restore on load is H4c; the device sound is a
//  DEVICE PROBE, open.
//
//  GRADING against the parent tree (#433/#464): `pluginFullState`, `settingPluginFullState`,
//  `pluginStateLimit` and `setLanePluginState` do not exist there — the file does not compile on
//  the parent, so no assertion has a verdict there (ONE absence, #486). Claims 1–3 are forward
//  guards; transcribed by reading the encoder (sorted keys, optional omitted when nil).
//  COUNTERWEIGHTS (#343): the component is unchanged by a settings write, a non-plugin insert is
//  refused, and nil settings give the bytes of a fresh insert.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class APluginKeepsItsSettingsInTheSongTests: XCTestCase {

    private static let synth = DeviceInsert.PluginComponent(type: 0x6175_6D75, subtype: 7, manufacturer: 9,
                                                            name: "Synth", manufacturerName: "Acme")

    // MARK: 1 — settings round-trip and never change the component

    func testTheSettingsRoundTripAndTheComponentStays() throws {
        let fresh = DeviceInsert.pluginInstrument(Self.synth)
        XCTAssertNil(fresh.pluginFullState, "a fresh pick carries no settings")
        let state = Data([0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x00, 0xFF])
        let saved = try XCTUnwrap(fresh.settingPluginFullState(state))
        XCTAssertEqual(saved.pluginFullState, state)
        XCTAssertEqual(saved.pluginComponent, Self.synth,
                       "a settings write is never a different component — the host must not reload")
        XCTAssertEqual(saved.typeID, fresh.typeID)
        XCTAssertEqual(saved.typeVersion, fresh.typeVersion, "an added optional key does not move the format")
    }

    // MARK: 2 — clearing gives back the fresh bytes

    func testClearingTheSettingsGivesTheFreshInsertBytes() throws {
        let fresh = DeviceInsert.pluginInstrument(Self.synth)
        let saved = try XCTUnwrap(fresh.settingPluginFullState(Data([1, 2, 3])))
        let cleared = try XCTUnwrap(saved.settingPluginFullState(nil))
        XCTAssertEqual(cleared.stateBlob, fresh.stateBlob, "one state, one byte form")
        XCTAssertNil(cleared.pluginFullState)
    }

    // MARK: 3 — refusals

    func testOversizeAndForeignInsertsAreRefused() {
        let fresh = DeviceInsert.pluginInstrument(Self.synth)
        XCTAssertNil(fresh.settingPluginFullState(Data(count: DeviceInsert.pluginStateLimit + 1)),
                     "a state over the limit is refused, never stored")
        XCTAssertNotNil(fresh.settingPluginFullState(Data(count: DeviceInsert.pluginStateLimit)),
                        "exactly the limit still fits")
        let foreign = DeviceInsert(typeID: "com.example.other", typeVersion: 1, isEnabled: true, stateBlob: Data())
        XCTAssertNil(foreign.settingPluginFullState(Data([1])), "only a plugin instrument carries plugin settings")
        XCTAssertNil(foreign.pluginFullState)
    }

    // MARK: 4 — the store has one writer, and it is not an Undo step

    func testTheStoreWritesSettingsThroughOneWriter() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/Echoelmusic/Core/TimelineStore.swift")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("TimelineStore.swift not on disk — this run has no source tree")
        }
        let store = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(store.components(separatedBy: "settingPluginFullState(").count - 1, 1,
                       "the settings are written in exactly one place in the store")
        guard let start = store.range(of: "public func setLanePluginState(_ laneID: UUID, _ state: Data?) {"),
              let end = store.range(of: "public func editLanePlugin(", range: start.upperBound..<store.endIndex) else {
            return XCTFail("`setLanePluginState` is gone or moved — re-anchor")
        }
        let body = String(store[start.upperBound..<end.lowerBound])
        XCTAssertFalse(body.contains("pushUndo("), "moving a plugin's own control is not an Undo step")
        XCTAssertTrue(body.contains("persist()"), "the settings are saved with the song")
    }

    // MARK: 5 — H4b: closing the plugin window hands its settings to that writer

    func testClosingThePluginWindowKeepsItsSettings() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ rel: String) throws -> String {
            let url = root.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw XCTSkip("\(rel) not on disk — this run has no source tree")
            }
            return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        }
        let host = try code("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        let row = try code("Sources/Echoelmusic/Studio/TrackPluginRow.swift")
        XCTAssertTrue(host.contains("unit.auAudioUnit.fullStateForDocument"),
                      "the document state, not `fullState` — the one a host saves with a song")
        XCTAssertTrue(host.contains("PropertyListSerialization.data(fromPropertyList: state, format: .binary"))
        XCTAssertTrue(row.contains(".sheet(item: $window, onDismiss: keepSettings)"),
                      "closing the window is the moment the settings are kept")
        XCTAssertTrue(row.contains("timeline.setLanePluginState(laneID, state)"))
        XCTAssertEqual(row.components(separatedBy: "setLanePluginState(").count - 1, 1)
    }
}
