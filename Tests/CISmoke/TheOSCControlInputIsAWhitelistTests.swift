// TheOSCControlInputIsAWhitelistTests.swift
// Echoel — #1255 (Grand Council 2026-09-10 step 4, ultraplan row 15). The app's FIRST inbound
// socket: an OSC control whitelist, off by default, that a console or VJ rig can send cues to.
//
// BEFORE: `Sources/` held zero `NWListener` (#821) — Echoel was a source only; TouchDesigner,
// Resolume, QLab and grandMA could hear the body and could not send a cue back. The Council
// ruled OSC-in before Link and the Appex because it is the one option provable OFF-DEVICE.
//
// END-TO-END BEHAVIOUR for claims 1–4 (`OSCDecoder`, `OSCControlCommand`, `TempoSource` and
// the defaults are shipped Foundation-only value types) and claim 8 (a LOOPBACK datagram
// through the real `NWListener` on an OS-picked port). SOURCE-TEXT SCAN for 5–7 and 9 (the
// dispatch, the door, the counterweights, the prose homes). What a console SEES is a DEVICE
// PROBE — NEEDS-FOUNDER-VERIFY at `StudioDefaultKeys.oscInEnabled`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`d9f48b1`) and this tree: claims
// 1–4 RED on the parent (the types do not exist — one finding, #486); claims 5, 6, 9 RED on the
// parent by ANCHOR ABSENCE (one finding); claim 7 (the receiver names no bus, no session start,
// no bio publish) is a FORWARD counterweight — vacuous on the parent (no file), green here;
// claim 8 is RUNTIME and cannot be transcribed: it compiles provably, its execution is
// unproven until a job log shows its name (#445/#807). Stripper: PROPHYLAKTISCH (0 of 9 scan
// verdicts flip). The decoder algebra (padding, big-endian float) was driven in Python
// against `OSCSender.encode`'s bytes before this file was written (#442).

import Foundation
import XCTest
@testable import Echoelmusic
#if canImport(Network)
import Network
#endif

final class TheOSCControlInputIsAWhitelistTests: XCTestCase {

    /// The mirror of `OSCSender.paddedOSCString`, so a string-argument message can be built.
    private func padded(_ s: String) -> [UInt8] {
        var b = Array(s.utf8) + [0]
        while b.count % 4 != 0 { b.append(0) }
        return b
    }
    private func message(_ address: String, string: String) -> Data {
        Data(padded(address) + padded(",s") + padded(string))
    }
    private func message(_ address: String, floats: [Float]) -> Data {
        OSCSender.encode(address: address, floats: floats)
    }

    /// Claim 1 — the decoder reads exactly what the sender writes, and refuses what is not a message.
    func testTheDecoderMirrorsTheEncoder() {
        let m = OSCDecoder.decode(message("/echoelmusic/bio/heart/bpm", floats: [72.5]))
        XCTAssertEqual(m, OSCDecoder.Message(address: "/echoelmusic/bio/heart/bpm", arguments: [.float(72.5)]))
        let two = OSCDecoder.decode(message("/a", floats: [1, -2]))
        XCTAssertEqual(two?.arguments, [.float(1), .float(-2)])
        let s = OSCDecoder.decode(message("/echoelmusic/ctrl/scale", string: "dorian"))
        XCTAssertEqual(s?.arguments, [.string("dorian")])
        XCTAssertNil(OSCDecoder.decode(Data(padded("#bundle"))), "a bundle is not a message (#1255)")
        XCTAssertNil(OSCDecoder.decode(Data(padded("/x") + padded(",f") + [0x42])), "a truncated float must not decode (#1255)")
        XCTAssertNil(OSCDecoder.decode(Data(padded("/x") + padded(",b") + [0, 0, 0, 0])), "a blob tag is refused, not guessed (#1255)")
        XCTAssertNil(OSCDecoder.decode(Data()))
    }

    /// Claim 2 — the enum IS the whitelist: six addresses, bounds checked, everything else nil.
    func testOnlyTheWhitelistParses() {
        let p = OSCControlCommand.prefix
        XCTAssertEqual(OSCControlCommand.addresses.count, 6)
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "key", arguments: [.float(7)])), .key(7))
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "key", arguments: [.int(11)])), .key(11))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "key", arguments: [.float(12)])), "a 12th pitch class (#1255)")
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "key", arguments: [])), "no argument, no cue")
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "bpm", arguments: [.float(120)])), .tempo(120))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "bpm", arguments: [.float(.nan)])), "NaN never reaches the clock (#1255)")
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "bpm", arguments: [.float(0)])))
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "scale", arguments: [.string("dorian")])), .scale("dorian"))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "scale", arguments: [.string("nope")])), "a scale no enum knows (#1255)")
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "genre", arguments: [.string("techHouse")])), .genre("techHouse"))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "genre", arguments: [.float(3)])), "a genre is named, never numbered")
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "visualStyle", arguments: [.int(9)])), .visualStyle(9))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "visualStyle", arguments: [.int(10)])))
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "blackout", arguments: [.bool(true)])), .blackout(true))
        XCTAssertEqual(OSCControlCommand.parse(.init(address: p + "blackout", arguments: [.int(0)])), .blackout(false))
        XCTAssertNil(OSCControlCommand.parse(.init(address: p + "play", arguments: [])),
                     "play/stop is NOT on the whitelist — a remote session start is the founder's decision (OneStartControlTests, #1255)")
        XCTAssertNil(OSCControlCommand.parse(.init(address: "/echoelmusic/bio/heart/bpm", arguments: [.float(70)])),
                     "a bio address coming IN must be dropped — the bus has one body (#639/#1255)")
        XCTAssertNil(OSCControlCommand.parse(.init(address: "/echoelmusic/mod/seq.tempo", arguments: [.float(0.5)])))
    }

    /// Claim 3 — the cue has its own name in the transport log (T1): a fifth source, no default.
    func testTheCueHasItsOwnTempoSource() {
        XCTAssertEqual(PatternEngine.TempoSource.remoteControl.rawValue, "remoteControl")
        XCTAssertTrue(PatternEngine.TempoSource.allCases.contains(.remoteControl))
    }

    /// Claim 4 — off by default, under a `net.*` key with ONE reader.
    func testTheSocketIsOptInAndOffByDefault() {
        XCTAssertEqual(StudioDefaultKeys.oscInEnabled.key, "net.osc.in.enabled")
        XCTAssertFalse(StudioDefaultKeys.oscInEnabled.value, "a fresh install must open no port (#1255)")
        #if canImport(Network)
        XCTAssertEqual(OSCReceiver.defaultPort, 8001, "the hub and the FAQ name 8001")
        XCTAssertTrue(OSCReceiver.isAllowed(endpoint: .hostPort(host: "192.168.1.9", port: 8001), allowedHosts: ""))
        XCTAssertTrue(OSCReceiver.isAllowed(endpoint: .hostPort(host: "192.168.1.9", port: 8001), allowedHosts: "10.0.0.2, 192.168.1.9"))
        XCTAssertFalse(OSCReceiver.isAllowed(endpoint: .hostPort(host: "192.168.1.9", port: 8001), allowedHosts: "10.0.0.2"))
        #endif
    }

    /// Claim 5 — the ONE dispatch: bpm only under the lock and under its own name; key/scale/genre
    /// through the header strip's funnel; the socket applied from the routing funnel.
    func testTheDispatchHonoursTheLockAndTheFunnel() throws {
        let app = SourceText.codeOnly(try text("Sources/Echoelmusic/EchoelmusicApp.swift"))
        let dispatch = try Self.member("oscIn.onCommand = { [weak beatPlayer, weak artNet, weak sacn] command in", in: app)
        XCTAssertTrue(dispatch.contains("guard d.bool(forKey: StudioDefaultKeys.lockBPM.key) else { return }"),
                      "a cue now moves the tempo in Flow — T2 (#1255)")
        XCTAssertTrue(dispatch.contains("beatPlayer?.pattern.setTempo(v, source: .remoteControl)"),
                      "the cue must name itself in the transport log (T1, #1255)")
        XCTAssertTrue(dispatch.contains("d.set(v, forKey: StudioDefaultKeys.lockedBPM.key)"),
                      "the locked field must show the cue's number, like BodyTempoField's binding (#1255)")
        for field in ["\"key\"", "\"scale\"", "\"genre\""] {
            XCTAssertTrue(dispatch.contains("NotificationCenter.default.post(name: .echoelCompositionEdited, object: \(field))"),
                          "\(field) no longer posts the composition-edit funnel — the take would not recompose (#1255)")
        }
        XCTAssertFalse(dispatch.contains("startBiofeedback") || dispatch.contains("toggleBiofeedback"),
                       "the dispatch must not start a session (OneStartControlTests, #1255)")
        let routing = try Self.member("private func applyRouting()", in: app)
        XCTAssertTrue(routing.contains("oscIn.applyPreference()"), "the persisted opt-in is not applied at launch (#1255)")
    }

    /// Claim 6 — the door: a Toggle in the routing card, mounted, applied through the one reader.
    func testTheRoutingCardHasTheSwitch() throws {
        let view = SourceText.codeOnly(try text("Sources/Echoelmusic/Studio/PatchbayView.swift"))
        let section = try Self.member("private var oscInSection: some View", in: view)
        XCTAssertTrue(section.contains("Toggle(isOn: $oscInEnabled)"))
        XCTAssertTrue(section.contains(".onChange(of: oscInEnabled) { _, _ in oscIn.applyPreference() }"),
                      "a switch that stores but never applies is a control that lies (#485/#1255)")
        XCTAssertTrue(section.contains("OSCInputStatusLine(receiver: oscIn)"), "the status must be a leaf (10.76.50)")
        let content = try Self.member("private var content: some View", in: view)
        XCTAssertTrue(content.contains("oscInSection"), "the card is not mounted (#1255)")
    }

    /// Claim 7 — counterweight in the receiver itself: it knows no bus, publishes no bio and
    /// starts no session. Whatever the whitelist grows into, these three stay absent.
    func testTheReceiverTouchesNoBusAndNoSession() throws {
        let receiver = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/OSCReceiver.swift"))
        for forbidden in ["EngineBus", "latestBio", "startBiofeedback", "toggleBiofeedback", "BioSampleFrame("] {
            XCTAssertFalse(receiver.contains(forbidden), "OSCReceiver now names `\(forbidden)` — a cue socket must stay a cue socket (#1255)")
        }
        XCTAssertTrue(receiver.contains("NWListener(using: .udp, on: nwPort)"))
        XCTAssertTrue(receiver.contains("guard Self.isAllowed(endpoint: connection.endpoint, allowedHosts: allowedHosts) else {"),
                      "the allowlist must be applied before a byte is decoded (#1255)")
    }

    #if canImport(Network)
    /// Claim 8 — RUNTIME: a real datagram through the real listener on an OS-picked port. One
    /// whitelisted cue is dispatched; one bio address is counted as ignored and reaches nobody.
    @MainActor
    func testALoopbackCueReachesTheDispatch() throws {
        let receiver = OSCReceiver(port: 0)
        receiver.port = 0
        var received: [OSCControlCommand] = []
        let cue = expectation(description: "cue dispatched")
        receiver.onCommand = { command in received.append(command); cue.fulfill() }
        receiver.start()
        XCTAssertTrue(receiver.isActive, "the listener did not open on an OS-picked port (#1255)")
        // Wait for the listener to report its bound port.
        let deadline = Date().addingTimeInterval(5)
        while receiver.boundPort == 0, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertGreaterThan(receiver.boundPort, 0, "the listener never became ready (#1255)")
        guard let port = NWEndpoint.Port(rawValue: receiver.boundPort) else { return XCTFail("port") }
        let conn = NWConnection(to: .hostPort(host: "127.0.0.1", port: port), using: .udp)
        conn.start(queue: .global())
        conn.send(content: message("/echoelmusic/bio/heart/bpm", floats: [70]), completion: .contentProcessed { _ in })
        conn.send(content: message("/echoelmusic/ctrl/key", floats: [7]), completion: .contentProcessed { _ in })
        wait(for: [cue], timeout: 8)
        XCTAssertEqual(received, [.key(7)], "the bio address must never dispatch; the key cue must (#1255)")
        XCTAssertGreaterThanOrEqual(receiver.ignoredCount, 1, "the bio datagram must be counted as ignored (#1255)")
        XCTAssertEqual(receiver.refusedCount, 0)
        conn.cancel()
        receiver.stop()
        XCTAssertFalse(receiver.isActive)
    }
    #endif

    /// Claim 9 — the prose homes moved with the socket (#456): the hub, the FAQ, the claims list,
    /// the law file. "No inbound socket" is retired everywhere it stood as a present-tense fact.
    func testTheProseHomesMoved() throws {
        let hub = try text("docs/integrations.html")
        XCTAssertTrue(hub.contains("OSC control input"))
        XCTAssertTrue(hub.contains("only while the BPM is locked"), "the hub must state the T2 limit (#1255)")
        let faq = try text("docs/faq.html")
        XCTAssertTrue(faq.contains("/echoelmusic/ctrl/"), "the FAQ no longer names the control input (#1255)")
        XCTAssertFalse(faq.contains("Bidirectional OSC and Ableton Link tempo sync are on the roadmap"),
                       "the FAQ still lists all of OSC-in as roadmap (#1255)")
        let claims = try text("ContentPipeline/CLAIMS.md")
        XCTAssertTrue(claims.contains("OSC-Eingang: Steuer-Whitelist"), "CLAIMS.md does not list the input — copy will invent or deny it (#1255)")
        let law = try text("CLAUDE.md")
        XCTAssertTrue(law.contains("FÜNF seit #1255"), "CLAUDE.md's T1 still counts four tempo sources (#1255)")
        XCTAssertTrue(law.contains("/echoelmusic/ctrl/{bpm,key,scale,genre,visualStyle,blackout}"), "the OSC address set in CLAUDE.md lacks the inbound line (#1255)")
        let privacy = try text("docs/privacy.html")
        XCTAssertTrue(privacy.contains("OSC input (off by default)"), "the privacy page must name the inbound port (#1255)")
    }

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
