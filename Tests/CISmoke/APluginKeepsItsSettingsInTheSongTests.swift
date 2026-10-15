//
//  APluginKeepsItsSettingsInTheSongTests.swift
//  Production level H4a — a hosted Audio Unit's own settings (`fullStateForDocument`) ride in the
//  track's instrument insert, so a song can bring the sound back after a relaunch.
//
//  KIND: END-TO-END BEHAVIOUR (claims 1–3) — `DeviceInsert` is a shipped Foundation-only value
//  type, driven directly. SOURCE-TEXT SCAN (claim 4) for the store's one writer, (claim 5, H4b)
//  for the capture when the plugin window closes, (claim 6, H4c) for the restore when the unit
//  loads. The device sound is a DEVICE PROBE, open.
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

    // MARK: 5b — oversize settings are SAID, and a plugin's level stays in range (Grok, 2026-10-15)

    func testOversizeSettingsAreSaidAndThePluginLevelIsBounded() throws {
        func code(_ rel: String) throws -> String {
            var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                dir = dir.deletingLastPathComponent()
            }
            let url = dir.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw XCTSkip("\(rel) not on disk — this run has no source tree")
            }
            return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        }
        XCTAssertEqual(DeviceInsert.pluginStateLimit, 1 << 20,
                       "the oversize sentence says 1 MB — move it with the limit")
        let row = try code("Sources/Echoelmusic/Studio/TrackPluginRow.swift")
        XCTAssertTrue(row.contains("guard state.count <= DeviceInsert.pluginStateLimit else {"),
                      "settings over the limit are refused by the store — the row says so instead of dropping them in silence")
        XCTAssertTrue(row.contains("so the piece cannot keep them"))
        let host = try code("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        XCTAssertTrue(host.contains("current.gain = gain.isFinite ? min(1, max(0, gain)) : 0"),
                      "a mixer input's volume is 0…1 — the hosted unit's level is clamped to it")
    }

    // MARK: 6 — H4c: a unit that loads gets the song's settings back

    func testALoadingUnitGetsTheSongsSettingsBack() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ rel: String) throws -> String {
            let url = root.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw XCTSkip("\(rel) not on disk — this run has no source tree")
            }
            return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        }
        let app = try code("Sources/Echoelmusic/EchoelmusicApp.swift")
        let host = try code("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        let fanout = try code("Sources/Echoelmusic/Sequencer/MultiRollFanout.swift")
        XCTAssertTrue(fanout.contains("?.deviceChain?.instrument?.pluginFullState"),
                      "the slot's settings come from the insert's own reader")
        XCTAssertTrue(app.contains("MultiRollFanout.hostedInstrumentState(forSlot: slot, in: store.document,"))
        XCTAssertTrue(app.contains("pluginHost.setInstrument(component, state: state, forSlot: slot)"))
        guard let finish = host.range(of: "private func finishLoad("),
              let restore = host.range(of: "if let data = pendingState.removeValue(forKey: slot) {\n            restore(data, to: unit, name: component.name)"),
              let held = host.range(of: "hosted[slot] = Hosted(component: component, unit: unit)") else {
            return XCTFail("ANCHOR MISSING: the restore in finishLoad")
        }
        XCTAssertLessThan(finish.lowerBound, restore.lowerBound)
        XCTAssertLessThan(restore.lowerBound, held.lowerBound, "settings are back before the slot plays notes")
        XCTAssertTrue(host.contains("unit.auAudioUnit.fullStateForDocument = state"))
        guard let unload = host.range(of: "private func unload(_ slot: Int) {") else {
            return XCTFail("ANCHOR MISSING: unload")
        }
        XCTAssertTrue(host[unload.upperBound...].prefix(200).contains("pendingState[slot] = nil"),
                      "unloading a slot forgets settings it never applied")
        XCTAssertTrue(host.contains("pendingState.removeAll()"), "a media reset forgets them too; the next prime names them again")
    }

    // MARK: 7 — H4d: the same plugin with OTHER song settings gets them; the same bytes change nothing

    /// Review finding G (read-only review of 1657030d6…8b1203e93): `setInstrument` returned on the
    /// same component, so a unit still loaded from project A kept A's sound in project B, and closing
    /// its window wrote A's settings into B. SOURCE-TEXT SCAN — the host is an `AVAudioUnit` owner no
    /// test can load; the sound is a DEVICE PROBE.
    func testTheSamePluginWithOtherSettingsGetsThem() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("no source tree") }
        let host = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        guard let same = host.range(of: "if wanted[slot] == component {"),
              let load = host.range(of: "unload(slot)\n        failed[slot] = nil") else {
            return XCTFail("ANCHOR MISSING: the same-component branch of setInstrument")
        }
        let branch = String(host[same.upperBound..<load.lowerBound])
        XCTAssertTrue(branch.contains("guard appliedState[slot] != state, let unit = hosted[slot]?.unit else { return }"),
                      "the same bytes must change nothing — a capture comes back from the song on every onset")
        XCTAssertTrue(branch.contains("restore(state, to: unit, name: component.name)"), "other settings reach the loaded unit")
        XCTAssertTrue(branch.contains("pendingState[slot] = state\n                return"),
                      "a unit still loading takes the newest settings — nil too, so it never inherits another song's")
        XCTAssertFalse(branch.contains("unload("), "COUNTERWEIGHT: new settings never reload the unit (that pauses the engine)")
        XCTAssertTrue(host.contains("if data.count <= DeviceInsert.pluginStateLimit { appliedState[slot] = data }"),
                      "a capture records what the song will hand back — only bytes the song can keep")
        XCTAssertEqual(host.components(separatedBy: "appliedState[slot] = nil").count - 1, 2, "unload and a dead unit forget it")
        XCTAssertTrue(host.contains("appliedState.removeAll()"), "a media reset forgets it")
    }

    // MARK: 8 — H4e: a song that keeps NO settings for the unit gets a fresh one

    /// Deep audit 2026-10-14 (Lieferung 1.1): `nil` settings for the same component returned at once,
    /// so project B — or another track that lands on the same rack slot — played project A's sound.
    /// A unit cannot be reset in place; it loads afresh, but ONLY when it carries settings the song
    /// gave or captured (`appliedState`), so a fresh pick with its window open is never reset by an
    /// onset. SOURCE-TEXT SCAN; the sound is a DEVICE PROBE (A → B → A, same plugin).
    func testASongWithoutSettingsGetsAFreshUnit() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("no source tree") }
        let host = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        guard let same = host.range(of: "if wanted[slot] == component {"),
              let given = host.range(of: "if let state {", range: same.upperBound..<host.endIndex),
              let fresh = host.range(of: "guard appliedState[slot] != nil else { return }", range: given.upperBound..<host.endIndex),
              let unload = host.range(of: "unload(slot)\n        failed[slot] = nil", range: fresh.upperBound..<host.endIndex) else {
            return XCTFail("ANCHOR MISSING: the settings branch, the fresh-unit test or the reload that follows it")
        }
        let between = String(host[fresh.upperBound..<unload.lowerBound])
        XCTAssertFalse(between.contains("return\n"),
                       "a unit carrying settings the song does not keep falls through to the reload")
        XCTAssertTrue(String(host[given.upperBound..<fresh.lowerBound]).contains("return"),
                      "COUNTERWEIGHT: settings the song DOES keep are applied in place, never by reloading")
    }

    // MARK: 7 — H4f: a Save and a trip to the background keep every loaded plugin's settings

    func testSaveAndBackgroundKeepEveryLoadedPluginsSettings() throws {
        func code(_ rel: String) throws -> String {
            var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                dir = dir.deletingLastPathComponent()
            }
            let url = dir.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw XCTSkip("\(rel) not on disk — this run has no source tree")
            }
            return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        }
        let host = try code("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift")
        guard let start = host.range(of: "func keepAllStates(in timeline: TimelineStore) -> Int {"),
              let end = host.range(of: "return kept", range: start.upperBound..<host.endIndex) else {
            return XCTFail("ANCHOR MISSING: HostedInstrumentHost.keepAllStates")
        }
        let body = String(host[start.upperBound..<end.lowerBound])
        XCTAssertTrue(body.contains("MultiRollFanout.laneID(forSlot: slot, in: document, rollLane: document.rollLaneID)"),
                      "each slot goes back to its track through the player's own inverse (#416)")
        XCTAssertTrue(body.contains("captureState(forSlot: slot, expecting: component)"),
                      "only the component the track still names — never one plugin's settings under another's name")
        XCTAssertTrue(body.contains("state.count <= DeviceInsert.pluginStateLimit"),
                      "settings the song cannot keep are skipped, not written")
        XCTAssertTrue(body.contains("timeline.setLanePluginState(laneID, state)"), "through the one writer")

        let app = try code("Sources/Echoelmusic/EchoelmusicApp.swift")
        guard let keep = app.range(of: "HostedInstrumentHost.live?.keepAllStates(in: timelineStore)"),
              let flush = app.range(of: "timelineStore.flushPendingSave()", range: keep.upperBound..<app.endIndex) else {
            return XCTFail("ANCHOR MISSING: the background branch keeps the plugins' settings before the flush")
        }
        XCTAssertLessThan(app.distance(from: keep.upperBound, to: flush.lowerBound), 200,
                          "the settings go into the song right before the background flush writes it")

        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        guard let session = studio.range(of: "private func withSession(_ take: Project) -> Project {"),
              let capture = studio.range(of: "SessionSaveOpen.capturing(", range: session.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: withSession, the one Save funnel")
        }
        XCTAssertTrue(String(studio[session.upperBound..<capture.lowerBound]).contains("HostedInstrumentHost.live?.keepAllStates(in: timelineStore)"),
                      "a Save captures the plugins' settings before the song is copied into the project")
    }
}
