// Production H6-3 — every rack slot sounds through its OWN bus.
//
// WHY: an effect plugin on a track has to sit AFTER the track's sound and BEFORE the master,
// and the track's level and pan live on the source's AVAudioMixing — so re-wiring
// source → effect directly would take level and pan with it. The seam is a per-slot mixer:
// sources → track bus → masterMixer. This slice builds that seam and moves nothing else.
//
// KIND: SOURCE-TEXT SCAN. It proves where the build sits and what it refuses; it does NOT
// prove the graph renders, that sound is unchanged, or that pan still acts on the bus input.
// That is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY: launch, identical sound, track pan/mute).
//
// GRADING against the parent tree: every claim names `attachTrackBus` or `trackBusCount`,
// which this commit creates, so all six are FORWARD guards — red there only by ANCHOR
// ABSENCE, one absence (#486). Claims 2, 3 and 6 are the counterweights the point rests on:
// no pause/restart (the count pins in TheFailedRestartHandsOverToDegradedTests stay put),
// format before graph, and the rack stays free of AVFoundation types.

import Foundation
import XCTest

final class TheRackSlotsSoundThroughTheirOwnBusTests: XCTestCase {

    private static let enginePath = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let rackPath = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"
    private static let head = "func attachTrackBus(slot: Int, feeding sources: [AVAudioNode]) -> AVAudioMixerNode? {"

    private func busBody() throws -> String {
        let code = SourceText.codeOnly(try source(Self.enginePath))
        guard let a = code.range(of: Self.head),
              let end = code[a.upperBound...].range(of: "\n    }\n") else {
            throw XCTSkip("ANCHOR MISSING: attachTrackBus — re-anchor (§4)")
        }
        return String(code[a.lowerBound..<end.upperBound])
    }

    /// 1 — on a running engine it touches nothing: the refusal comes before the graph.
    func testTheBusIsBuiltOnlyBeforeTheEngineStarts() throws {
        let body = try busBody()
        guard let refuse = body.range(of: "guard !masterEngine.isRunning else {"),
              let attach = body.range(of: "masterEngine.attach(bus)") else {
            return XCTFail("ANCHOR MISSING: the running-engine refusal or the attach")
        }
        XCTAssertLessThan(refuse.lowerBound, attach.lowerBound,
                          "the running-engine refusal must come before the graph is touched")
        XCTAssertTrue(body[refuse.upperBound...].prefix(200).contains("return nil"),
                      "a running engine leaves the slot on its direct path")
    }

    /// 2 — no pause and no restart: built before start, so there is nothing to recover from.
    func testTheBusNeverPausesOrRestartsTheEngine() throws {
        let body = try busBody()
        XCTAssertFalse(body.contains("masterEngine.pause()"), "the track bus must not pause the engine")
        XCTAssertFalse(body.contains("restartOrDegrade("), "the track bus must not restart the engine")
    }

    /// 3 — the format is validated before the bus is attached.
    func testTheFormatIsCheckedBeforeTheGraph() throws {
        let body = try busBody()
        guard let check = body.range(of: "guard busFormat.sampleRate > 0, busFormat.channelCount > 0 else {"),
              let attach = body.range(of: "masterEngine.attach(bus)") else {
            return XCTFail("ANCHOR MISSING: the format check or the attach")
        }
        XCTAssertLessThan(check.lowerBound, attach.lowerBound)
    }

    /// 4 — only a source this engine owns is moved, and it moves to the bus.
    func testOnlyOwnSourcesMoveOntoTheBus() throws {
        let body = try busBody()
        XCTAssertTrue(body.contains("for source in sources where source.engine === masterEngine {"))
        XCTAssertTrue(body.contains("masterEngine.connect(source, to: bus, format: format)"))
        XCTAssertTrue(body.contains("masterEngine.connect(bus, to: masterMixer, format: busFormat)"),
                      "the bus itself feeds the master")
        XCTAssertTrue(body.contains("trackBuses[slot] = bus"), "the bus is kept under its slot")
    }

    /// 5 — the rack gives every slot a bus, voice plus sampler, inside attachAll, before `attached`.
    func testTheRackBuildsOneBusPerSlotAtAttach() throws {
        let code = SourceText.codeOnly(try source(Self.rackPath))
        guard let a = code.range(of: "public func attachAll(to audioEngine: AudioEngine) {"),
              let call = code[a.upperBound...].range(of: "audioEngine.attachTrackBus(slot: slot, feeding: sources)"),
              let done = code[a.upperBound...].range(of: "attached = true") else {
            return XCTFail("ANCHOR MISSING: attachAll, the bus call or `attached = true`")
        }
        XCTAssertLessThan(call.lowerBound, done.lowerBound, "buses are built before the rack reports attached")
        let around = String(code[a.upperBound..<call.lowerBound].suffix(400))
        XCTAssertTrue(around.contains("for slot in voices.indices {"), "every slot, not only the first")
        XCTAssertTrue(around.contains("[voices[slot].sourceNode, samplers[slot].sourceNode]"),
                      "a slot's sampler shares its bus")
    }

    /// 6 — the rack stays free of AVFoundation; the buses are owned by the engine.
    func testTheRackStaysFreeOfAVFoundationTypes() throws {
        let code = SourceText.codeOnly(try source(Self.rackPath))
        XCTAssertFalse(code.contains("import AVFoundation"))
        XCTAssertFalse(code.contains("AVAudioMixerNode"))
        let engine = SourceText.codeOnly(try source(Self.enginePath))
        XCTAssertTrue(engine.contains("func trackBus(slot: Int) -> AVAudioMixerNode? { trackBuses[slot] }"))
    }

    /// 7 — H6-4: a hosted plugin instrument sounds through its slot's bus, falling back to the master.
    func testAHostedInstrumentSoundsThroughItsSlotsBus() throws {
        let code = SourceText.codeOnly(try source(Self.enginePath))
        guard let a = code.range(of: "func attachAudioUnit(_ unit: AVAudioUnit, slot: Int) -> Bool {"),
              let end = code[a.upperBound...].range(of: "\n    }\n") else {
            return XCTFail("ANCHOR MISSING: attachAudioUnit(_:slot:)")
        }
        let body = String(code[a.lowerBound..<end.upperBound])
        XCTAssertTrue(body.contains("let destination = trackBuses[slot] ?? masterMixer"))
        XCTAssertFalse(body.contains("to: masterMixer, format:"),
                       "every connect goes to the destination, never straight to the master")
        let host = SourceText.codeOnly(try source("Sources/Echoelmusic/Audio/HostedInstrumentHost.swift"))
        XCTAssertTrue(host.contains("engine.attachAudioUnit(unit, slot: slot)"), "the host passes its rack slot")
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
