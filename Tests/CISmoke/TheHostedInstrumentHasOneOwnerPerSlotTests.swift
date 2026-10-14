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
//    the graph is touched. A failed load gives the slot back to its built-in voice. Since the deep
//    audit of 2026-10-14 (Lieferung 1.2) each load carries a request number and only the NEWEST
//    request's answer counts — after A → B → A the component check alone let the first A's late
//    success attach, or its late failure mark A failed.
//  · Claim 2 — one owner per NOTE (P0-2, 2026-10-14): `route(_:forSlot:)` gives an attack to the
//    LOADED unit, and to the built-in voice while the unit is still loading (⛔ until P0-2 a slot
//    that merely WANTED a unit owned its notes and dropped them, so a fresh pick opened with
//    silence); a release follows its attack, so nothing doubles and nothing is stranded. This
//    app's own components are never hosted inside the app.
//  · Claim 3 — leaving is clean: an unload sends all-notes-off on all 16 channels BEFORE it
//    detaches, and a media-services reset DETACHES every unit (no MIDI to a dead unit) before it
//    forgets it — the engine is one instance that outlives the reset (corrected H2d; H2b1 pinned
//    the opposite). The engine's reset path has one owner, which this host never assigns.
//  · Claim 3b (H2d) — a component that failed to load is remembered per slot and not retried at
//    every region onset; the track's Transpose reaches the unit, and a release uses the number its
//    attack was sent with.
//  · Claim 4 — the engine API is the `attachSourceNode` shape: rung first, pause, restart through
//    `restartOrDegrade` (the counts live in `TheFailedRestartHandsOverToDegradedTests`, raised to
//    7 and 6 in this commit; the rungs in `TheEngineLifecycleSpeaksInTheDiagLogTests`, #416).
//  · Claim 5 (H2b2) — the app builds exactly one host where the rack is wired; every slot's
//    notes pass through the host's `route` before the rack's note-on (P0-2), and the slot's plugin, gain and pan
//    reach it through the region player's sinks.
//  · Claim 6 (H5) — a plugin whose extension process died (invalidation notification) is
//    detached, its slot goes back to the built-in voice, and it is marked failed so it is not
//    reloaded at every onset; a breadcrumb names it in the diag log.
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
              let attach = finish.range(of: "engine.attachAudioUnit(unit, slot: slot)") else {
            return XCTFail("ANCHOR MISSING: the stale check or the attach in finishLoad")
        }
        XCTAssertLessThan(stale.lowerBound, attach.lowerBound, "the stale check comes before the graph")
        guard let newest = finish.range(of: "guard loadRequest[slot] == request else { return }") else {
            return XCTFail("ANCHOR MISSING: the newest-request check in finishLoad")
        }
        XCTAssertLessThan(newest.lowerBound, stale.lowerBound,
                          "an older request's answer is dropped before it can attach OR mark the component failed")
        guard let numbered = code.range(of: "let request = (loadRequest[slot] ?? 0) &+ 1\n        loadRequest[slot] = request\n        AVAudioUnit.instantiate(") else {
            return XCTFail("ANCHOR MISSING: the request number taken right before the load")
        }
        XCTAssertTrue(code[numbered.upperBound...].prefix(400).contains("component: component, request: request)"),
                      "the answer carries the number of the request it answers")
        guard let failed = finish.range(of: "guard let unit else {") else {
            return XCTFail("ANCHOR MISSING: the failed-load branch")
        }
        XCTAssertTrue(finish[failed.upperBound...].prefix(300).contains("wanted[slot] = nil"),
                      "a unit that cannot load gives the slot back to its built-in voice")
        guard let attachFail = finish.range(of: "guard engine.attachAudioUnit(unit, slot: slot) else {") else {
            return XCTFail("ANCHOR MISSING: the attach-failure branch")
        }
        XCTAssertTrue(finish[attachFail.upperBound...].prefix(400).contains("failed[slot] = component"),
                      "a unit the engine cannot attach is remembered as failed, or every onset retries it")
    }

    // MARK: 2 — one owner per slot

    func testANoteBelongsToTheVoiceThatPlaysItsAttack() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        XCTAssertFalse(code.contains("func owns("),
                       "P0-2: wanting a unit no longer owns its notes — that dropped them while it loaded")
        guard let route = body(of: "func route(_ events: [LaneNotePump.Event], forSlot slot: Int) -> [LaneNotePump.Event] {",
                               in: code, length: 1100) else {
            return XCTFail("ANCHOR MISSING: route(_:forSlot:)")
        }
        guard let loaded = route.range(of: "if hosted[slot] != nil {\n                    unit.append(event)\n                } else {\n                    builtIn.append(event)\n                    builtInHeld[slot, default: []].insert(event.pitch)"),
              let release = route.range(of: "} else if builtInHeld[slot]?.remove(event.pitch) != nil {\n                builtIn.append(event)") else {
            return XCTFail("ANCHOR MISSING: the attack split or the release that follows its attack")
        }
        XCTAssertLessThan(loaded.lowerBound, release.lowerBound)
        XCTAssertTrue(route.contains("guard wanted[slot] != nil else {\n            builtInHeld[slot] = nil\n            return events"),
                      "a slot with no unit plays everything on its built-in voice")
        XCTAssertTrue(route.contains("if !unit.isEmpty { send(unit, toSlot: slot) }"))
        XCTAssertTrue(route.contains("return builtIn"))
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
        // ⛔ H2b1 asserted the OPPOSITE ("never detach into it") and pinned a defect: the app has
        // ONE `AVAudioEngine` for its life and the reset restarts it, so a dead unit stayed wired
        // into the mixer (review of H2b, 2026-10-13). Detach first; send it no MIDI.
        guard let detach = reset.range(of: "for held in hosted.values { engine.detachAudioUnit(held.unit) }"),
              let forget = reset.range(of: "hosted.removeAll()") else {
            return XCTFail("ANCHOR MISSING: the reset's detach or its forget")
        }
        XCTAssertLessThan(detach.lowerBound, forget.lowerBound, "detach every unit before forgetting it")
        XCTAssertFalse(reset.contains("scheduleMIDIEventBlock"), "a dead unit gets no MIDI")
        XCTAssertTrue(reset.contains("wanted.removeAll()"), "the next prime names each plugin again")
        XCTAssertTrue(reset.contains("failed.removeAll()"), "after a reset a failed unit may load again")
        XCTAssertFalse(code.contains("onMediaServicesReset"), "the engine's reset path has one owner")
    }

    // MARK: 3b — a missing plugin is not retried, and Transpose reaches the unit (H2d)

    func testAFailedUnitKeepsTheBuiltInVoiceAndNotesKeepTheirSentNumber() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        guard let set = body(of: "func setInstrument(", in: code, length: 600),
              let skip = set.range(of: "if let component, failed[slot] == component { return }"),
              let unload = set.range(of: "unload(slot)") else {
            return XCTFail("ANCHOR MISSING: the failed-component check or the unload in setInstrument")
        }
        XCTAssertLessThan(skip.lowerBound, unload.lowerBound,
                          "a component that failed here is not loaded again at every region onset")
        guard let finish = body(of: "private func finishLoad(", in: code) else {
            return XCTFail("ANCHOR MISSING: finishLoad")
        }
        XCTAssertTrue(finish.contains("failed[slot] = component"), "a failed load is remembered")
        guard let send = body(of: "func send(_ events:", in: code, length: 1400) else {
            return XCTFail("ANCHOR MISSING: send")
        }
        XCTAssertTrue(send.contains("event.pitch + (transpose[slot] ?? 0)"), "the track's Transpose shifts the note")
        XCTAssertTrue(send.contains("sounding[slot]?.removeValue(forKey: event.pitch)"),
                      "a release uses the number its attack was sent with — no stranded note")
        let app = SourceText.codeOnly(try source("Sources/Echoelmusic/EchoelmusicApp.swift"))
        XCTAssertTrue(app.contains("pluginHost.setTranspose(slot: slot, semitones: semitones)"))
    }

    // MARK: 3c — a pick during playback is taken now (H2d)

    func testAPickDuringPlaybackReleasesThenRenames() throws {
        let player = SourceText.codeOnly(try source("Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"))
        guard let merge = body(of: "private func refreshMixer()", in: player, length: 2400) else {
            return XCTFail("ANCHOR MISSING: refreshMixer")
        }
        guard let change = merge.range(of: "if plugin != namedPlugin[slot] {"),
              let release = merge.range(of: "sink(slot, pump.releaseSounding())", range: change.upperBound..<merge.endIndex),
              let rename = merge.range(of: "nameSlotPlugin(slot, plugin)", range: change.upperBound..<merge.endIndex) else {
            return XCTFail("ANCHOR MISSING: the change test, the release or the rename in refreshMixer")
        }
        XCTAssertLessThan(release.lowerBound, rename.lowerBound,
                          "held notes leave through the OLD owner before the slot is named again")
        // Night sweep 2026-10-14 (B1): `reset()` here also dropped the bars, so a pick during
        // playback silenced the track until its next part started. The pick releases what
        // sounds and keeps the part.
        XCTAssertFalse(merge[change.upperBound..<rename.lowerBound].contains("pump.reset()"),
                       "a pick mid-play keeps the part — release the sounding notes, do not empty the pump")
        let pump = SourceText.codeOnly(try source("Sources/Echoelmusic/Sequencer/LaneNotePump.swift"))
        guard let keep = body(of: "public mutating func releaseSounding() -> [Event] {", in: pump, length: 400) else {
            return XCTFail("ANCHOR MISSING: LaneNotePump.releaseSounding")
        }
        XCTAssertTrue(keep.contains("active.removeAll()"), "every sounding note gets its release")
        XCTAssertFalse(keep.contains("bars.removeAll()") || keep.contains("notes.removeAll()"),
                       "the part's content stays, so the next step still plays it")
        XCTAssertEqual(player.components(separatedBy: "slotPluginSink?(").count - 1, 1,
                       "every naming goes through nameSlotPlugin, which remembers what it said")
    }

    // MARK: 4 — the engine API

    func testTheEngineAttachIsTheSourceNodeShape() throws {
        let code = SourceText.codeOnly(try source(Self.enginePath))
        guard let attach = body(of: "func attachAudioUnit(_ unit: AVAudioUnit, slot: Int) -> Bool {", in: code, length: 2400) else {
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
              let owned = app.range(of: "let builtIn = pluginHost.route(events, forSlot: slot)"),
              let rack = app.range(of: "laneVoiceRack?.noteOn(slot: slot, pitch: event.pitch, velocity: event.velocity)") else {
            return XCTFail("ANCHOR MISSING: the host, the routing line or the rack's note-on in the note sink")
        }
        XCTAssertLessThan(host.lowerBound, owned.lowerBound)
        XCTAssertLessThan(owned.lowerBound, rack.lowerBound,
                          "the host routes a slot's notes before the rack sees them — never both voices")
        XCTAssertTrue(app.contains("pluginHost.setInstrument(component, state: state, forSlot: slot)"))
        XCTAssertTrue(app.contains("pluginHost.setMix(slot: slot, gain: gain)"))
        XCTAssertTrue(app.contains("pluginHost.setMix(slot: slot, pan: pan)"))
    }

    // MARK: 6 — a plugin whose process died gives its slot back

    func testACrashedPluginGivesItsSlotBack() throws {
        let code = SourceText.codeOnly(try source(Self.hostPath))
        XCTAssertTrue(code.contains("forName: Notification.Name(kAudioComponentInstanceInvalidationNotification as String),"),
                      "the host listens for a dead plugin instance")
        XCTAssertTrue(code.contains("Task { @MainActor in self?.forgetInvalidated(dead) }"),
                      "the notification hops to the main actor before touching the host")
        guard let forget = body(of: "private func forgetInvalidated(", in: code, length: 900),
              let detach = forget.range(of: "engine.detachAudioUnit(held.unit)"),
              let failed = forget.range(of: "failed[slot] = held.component") else {
            return XCTFail("ANCHOR MISSING: the invalidation handler, its detach or its failed mark")
        }
        XCTAssertLessThan(detach.lowerBound, failed.lowerBound)
        XCTAssertTrue(forget.contains("wanted[slot] = nil"), "the built-in voice owns the slot again")
        XCTAssertTrue(forget.contains("EchoelCrashLog.breadcrumb(\"plugin: '"), "the diag log names the plugin")
        XCTAssertFalse(forget.contains("scheduleMIDIEventBlock"), "a dead unit gets no MIDI")
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
