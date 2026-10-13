//
//  TheHostedInstrumentHasOneOwnerPerSlotTests.swift
//  Production level H2b, first half (founder 2026-10-13: „… auv3 Plugins für Effekte und MIDI
//  Instrumente …"). `HostedInstrumentHost` loads a rack track's chosen Audio Unit instrument,
//  hangs it into the master mix through `AudioEngine.attachAudioUnit` and plays the track's notes
//  on it as MIDI. H2b1 added the host and the engine API; H2b2 wired it (the region player names
//  each slot's plugin, the app's note sink routes an owned slot's notes to it).
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1) — all SOURCE-TEXT SCANS, because the host
//  needs a real `AVAudioUnit` from the system and the engine needs a device graph:
//  · Claim 1 — the load is safe against late answers: the completion handler is `@Sendable` and
//    hops to the main actor (builds 2613/2618 died of an inferred main-actor closure called off
//    main), and the stale check (the slot still wants this component, holds no unit) runs BEFORE
//    the graph is touched. A failed load gives the slot back to its built-in voice.
//  · Claim 2 — one owner per slot: `owns` is "the slot wants a unit", so a chosen plugin silences
//    the built-in voice of that track rather than doubling it; this app's own components are
//    never hosted inside the app.
//  · Claim 3 — leaving is clean: an unload sends all-notes-off on all 16 channels BEFORE it
//    detaches, and a media-services reset forgets every unit WITHOUT touching the old graph
//    (the engine's reset path has one owner, which this host never assigns).
//  · Claim 4 — the engine API is the `attachSourceNode` shape: rung first, pause, restart through
//    `restartOrDegrade` (the counts live in `TheFailedRestartHandsOverToDegradedTests`, raised to
//    7 and 6 in this commit; the rungs in `TheEngineLifecycleSpeaksInTheDiagLogTests`, #416).
//  · Claim 5 (H2b2) — the app builds exactly one host where the rack is wired; an owned slot's
//    notes return to the host before the rack's note-on, and the slot's plugin, gain and pan
//    reach it through the region player's sinks.
//  · DEVICE PROBE, OPEN — NEEDS-FOUNDER-VERIFY H2 at the host's header.
//
//  GRADING against the parent tree (#433/#464): the host file and both engine methods are created
//  by this commit, so every anchor is absent there (ONE absence, #486). Needles grepped against
//  the worktree; not run.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest

final class TheHostedInstrumentHasOneOwnerPerSlotTests: XCTestCase {

    private static let hostPath = "Sources/Echoelmusic/Audio/HostedInstrumentHost.swift"
    private static let enginePath = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    private func body(of head: String, in code: String, length: Int = 1200) -> String? {
        guard let r = code.range(of: head) else { return nil }
        return String(code[r.lowerBound...].prefix(length))
    }

    // MARK: 1 — a late answer never touches the graph

    func testTheLoadHopsAndChecksBeforeItAttaches() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        XCTAssertTrue(code.contains("AVAudioUnit.instantiate(with: description, options: []) { @Sendable [weak self] unit, error in"),
                      "the completion runs off main: it must be @Sendable and hop")
        XCTAssertTrue(code.contains("Task { @MainActor in\n                self?.finishLoad("))
        guard let finish = body(of: "private func finishLoad(", in: code) else {
            return XCTFail("ANCHOR MISSING: finishLoad")
        }
        guard let stale = finish.range(of: "guard wanted[slot] == component, hosted[slot] == nil else { return }"),
              let attach = finish.range(of: "engine.attachAudioUnit(unit)") else {
            return XCTFail("ANCHOR MISSING: the stale check or the attach in finishLoad")
        }
        XCTAssertLessThan(stale.lowerBound, attach.lowerBound, "the stale check comes before the graph")
        guard let failed = finish.range(of: "guard let unit else {") else {
            return XCTFail("ANCHOR MISSING: the failed-load branch")
        }
        XCTAssertTrue(finish[failed.upperBound...].prefix(300).contains("wanted[slot] = nil"),
                      "a unit that cannot load gives the slot back to its built-in voice")
    }

    // MARK: 2 — one owner per slot

    func testASlotWithAPluginIsOwnedByTheHost() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        XCTAssertTrue(code.contains("func owns(_ slot: Int) -> Bool { wanted[slot] != nil }"))
        XCTAssertTrue(code.contains("component.manufacturer != Self.ownManufacturer"),
                      "the Echoel AUv3 is never hosted inside the app that embeds it")
        XCTAssertTrue(code.contains("static let ownManufacturer: UInt32 = 0x4563_686F"), "'Echo'")
    }

    // MARK: 3 — leaving is clean

    func testUnloadSilencesFirstAndResetTouchesNoGraph() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        guard let unload = body(of: "private func unload(", in: code) else {
            return XCTFail("ANCHOR MISSING: unload")
        }
        guard let notesOff = unload.range(of: "[0xB0 | channel, 123, 0]"),
              let detach = unload.range(of: "engine.detachAudioUnit(held.unit)") else {
            return XCTFail("ANCHOR MISSING: all-notes-off or the detach in unload")
        }
        XCTAssertLessThan(notesOff.lowerBound, detach.lowerBound, "silence before the unit leaves the graph")
        XCTAssertTrue(unload.contains("for channel: UInt8 in 0..<16"))

        guard let reset = body(of: "private func forgetAfterMediaReset()", in: code, length: 400) else {
            return XCTFail("ANCHOR MISSING: the media-reset handler")
        }
        XCTAssertFalse(reset.contains("detach"), "after a reset the old graph is gone — never detach into it")
        XCTAssertTrue(reset.contains("wanted.removeAll()"), "the next prime names each plugin again")
        XCTAssertFalse(code.contains("onMediaServicesReset"), "the engine's reset path has one owner")
    }

    // MARK: 4 — the engine API

    func testTheEngineAttachIsTheSourceNodeShape() throws {
        let code = SourceText.codeOnly(try source(Self.enginePath))
        guard let attach = body(of: "func attachAudioUnit(_ unit: AVAudioUnit) -> Bool {", in: code) else {
            return XCTFail("ANCHOR MISSING: attachAudioUnit")
        }
        for needle in ["logEngineLifecycle(\"graph: attach audio unit",
                       "if wasRunning { masterEngine.pause() }",
                       "restartOrDegrade(after: \"audio unit attachment\")",
                       "masterEngine.detach(unit)"] {
            XCTAssertTrue(attach.contains(needle), needle)
        }
    }

    // MARK: 5 — one host, in the app, owning the slot's notes (H2b2)

    func testTheAppBuildsOneHostAndRoutesOwnedSlotsToIt() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not on disk — this run has no source tree")
        }
        var sites = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            sites += code.components(separatedBy: "HostedInstrumentHost(engine:").count - 1
        }
        XCTAssertEqual(sites, 1, "one host for the whole rack, built where the rack is wired")
        let app = SourceText.codeOnly(try source("Sources/Echoelmusic/EchoelmusicApp.swift"))
        guard let host = app.range(of: "let pluginHost = HostedInstrumentHost(engine: audioEngine)"),
              let owned = app.range(of: "if pluginHost.owns(slot) {\n                            pluginHost.send(events, toSlot: slot)\n                            return\n                        }"),
              let rack = app.range(of: "laneVoiceRack?.noteOn(slot: slot, pitch: event.pitch, velocity: event.velocity)") else {
            return XCTFail("ANCHOR MISSING: the host, the owned-slot branch or the rack's note-on in the note sink")
        }
        XCTAssertLessThan(host.lowerBound, owned.lowerBound)
        XCTAssertLessThan(owned.lowerBound, rack.lowerBound,
                          "an owned slot's notes return before the rack sees them — never both voices")
        XCTAssertTrue(app.contains("pluginHost.setInstrument(component, forSlot: slot)"))
        XCTAssertTrue(app.contains("pluginHost.setMix(slot: slot, gain: gain)"))
        XCTAssertTrue(app.contains("pluginHost.setMix(slot: slot, pan: pan)"))
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
