// TheMIDI2SourceIsSwitchableTests.swift
// Echoel — #1253 (ultraplan row 12). A SECOND virtual MIDI source in the MIDI 2.0 protocol,
// behind a routing switch that defaults OFF.
//
// BEFORE: `MIDIOutput` created one source, `MIDISourceCreateWithProtocol(… ._1_0 …)`, and
// `UMPEncoder`'s two-word MIDI 2.0 builders had no production caller (#1229, audit
// `output-sync-6`) — every "MIDI 2.0" claim in copy had to say "INPUT only". Now the switch
// "MIDI 2.0 source" (`StudioDefaultKeys.midiOutUMP2`) builds "Echoelmusic (MIDI 2.0)" and
// `sendMIDI2Mirror` widens every 1.0 channel-voice message through those builders.
//
// END-TO-END BEHAVIOUR for claims 1 and 5 (the persisted default; the scaling algebra the
// mirror relies on — driven in Python first, #442). SOURCE-TEXT SCAN for 2–4 and 6–8 (the
// members are `private` on a `@MainActor` class; nothing here can open a CoreMIDI client).
// Whether a host SEES the second source and records widened notes is a DEVICE PROBE —
// NEEDS-FOUNDER-VERIFY at `StudioDefaultKeys.midiOutUMP2`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`9c926a8`) and this tree: claim 1
// RED on the parent (the key does not exist — one finding, #486); claims 2, 3, 4, 6, 7 RED on
// the parent by ANCHOR ABSENCE (the members do not exist — one finding); claim 5 GREEN on both
// (the algebra predates the slice); claim 8 (counterweights: the 1.0 source, the MPE gate)
// GREEN on both. Stripper: TRAGEND (2 of 16 verdicts flip — claim 8's `if mpeEnabled,
// expressionEnabled` count reads 2 raw on BOTH trees, because the ready-line comment quotes
// the gate; stripped it is 1, as MIDIOutQualitySwitchesTests claim 2 pins).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMIDI2SourceIsSwitchableTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/MIDIOutput.swift"
    private static let surface = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    /// Claim 1 — the persisted contract: a named key, OFF by default. On would put a second
    /// device into every host's list on a fresh install and record every note twice.
    func testTheSwitchDefaultsOff() {
        XCTAssertEqual(StudioDefaultKeys.midiOutUMP2.key, "midi.out.ump2",
                       "the key moved — a stored preference silently resets for everyone who set it (#1253)")
        XCTAssertFalse(StudioDefaultKeys.midiOutUMP2.value,
                       "the MIDI 2.0 source now defaults ON: every fresh install offers two sources (#1253)")
    }

    /// Claim 2 — the switch OWNS the lifecycle: on creates, off disposes, and only while the
    /// port is open (port-open builds it from the persisted flag).
    func testTheSwitchCreatesAndDisposesTheSource() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let didSet = try Self.member("public var ump2Enabled = false", in: src)
        XCTAssertTrue(didSet.contains("guard ump2Enabled != oldValue, isReady else { return }"),
                      "the switch must be an EDGE and must wait for an open port (#1253)")
        XCTAssertTrue(didSet.contains("if ump2Enabled { createUMP2Source() } else { disposeUMP2Source() }"))
        let start = try Self.member("private func startIfNeeded()", in: src)
        XCTAssertTrue(start.contains("if ump2Enabled { createUMP2Source() }"),
                      "a port opened with the flag already ON must build the 2.0 source (#1253)")
        let prefs = try Self.member("public func applyOutputPreferences()", in: src)
        XCTAssertTrue(prefs.contains("StudioDefaultKeys.midiOutUMP2.key"),
                      "the ONE reader of the key is applyOutputPreferences — the view only stores it (#713/#1253)")
        XCTAssertTrue(prefs.contains("if ump2Enabled != ump2 { ump2Enabled = ump2 }"))
        let dispose = try Self.member("private func disposeHalfBuiltLifecycle()", in: src)
        XCTAssertTrue(dispose.contains("virtualSource2 = 0"),
                      "a torn-down client must forget the 2.0 endpoint, or the next port-open skips creating it (#1253)")
        let create = try Self.member("private func createUMP2Source()", in: src)
        XCTAssertTrue(create.contains("guard client != 0, virtualSource2 == 0 else { return }"),
                      "creating twice leaks an endpoint (#1253)")
    }

    /// Claim 3 — the source is created in the 2.0 protocol, and NO `._1_0` list is ever pushed
    /// into it: a list must carry its source's protocol.
    func testTheSourceSpeaksMIDI2Only() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let create = try Self.member("private func createUMP2Source()", in: src)
        XCTAssertTrue(create.contains("MIDISourceCreateWithProtocol(client, \"Echoelmusic (MIDI 2.0)\" as CFString, ._2_0, &newSource)"),
                      "the second source must be built with the 2.0 protocol (#1253)")
        XCTAssertFalse(create.contains("._1_0"))
        let mirror = try Self.member("private func sendMIDI2Mirror(_ bytes: [UInt8])", in: src)
        XCTAssertTrue(mirror.contains("MIDIEventListInit(&list2, ._2_0)"))
        XCTAssertTrue(mirror.contains("MIDIReceivedEventList(virtualSource2, &list2)"))
        XCTAssertFalse(mirror.contains("._1_0"), "a 1.0 list into the 2.0 source (#1253)")
        XCTAssertFalse(mirror.contains("MIDISendEventList("),
                       "the mirror goes to the VIRTUAL source only — hardware has one protocol and already got the 1.0 words (#1253)")
        let realtime = try Self.member("private func sendRealTime(_ message: UMPEncoder.RealTime)", in: src)
        XCTAssertTrue(realtime.contains("MIDIEventListInit(&list2, ._2_0)"),
                      "clock/start/stop must reach the 2.0 source in a 2.0 list too (#1253)")
    }

    /// Claim 4 — every 1.0 channel-voice send is mirrored, and the mirror maps each status it
    /// forwards to the matching 2.0 builder; a note-on with velocity 0 is a note-OFF.
    func testEverySendIsMirroredAndMapped() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let send = try Self.member("private func send(_ bytes: [UInt8])", in: src)
        XCTAssertTrue(send.contains("sendMIDI2Mirror(bytes)"), "the 1.0 send path no longer mirrors (#1253)")
        let mirror = try Self.member("private func sendMIDI2Mirror(_ bytes: [UInt8])", in: src)
        XCTAssertTrue(mirror.contains("guard virtualSource2 != 0, bytes.count >= 2 else { return }"),
                      "the mirror must be a no-op while the switch is off (#1253)")
        XCTAssertTrue(mirror.contains("case 0x90 where d2 > 0:"))
        XCTAssertTrue(mirror.contains("case 0x90, 0x80:"), "velocity-0 note-on must fall into the note-off arm (#1253)")
        for builder in ["UMPEncoder.note2On(", "UMPEncoder.note2Off(", "UMPEncoder.controlChange2(",
                        "UMPEncoder.channelPressure2(", "UMPEncoder.pitchBend2("] {
            XCTAssertTrue(mirror.contains(builder), "\(builder) is no longer used by the mirror (#1253)")
        }
        XCTAssertTrue(mirror.contains("UMPEncoder.bend14to32(value14)"))
        XCTAssertFalse(mirror.contains("perNotePitchBend2("),
                       "per-note bend is the 2.0-native MPE nobody has built — the mirror must not pretend (#1253)")
    }

    /// Claim 5 — END-TO-END: the widening the mirror relies on keeps the three MMA anchors
    /// (0 → 0, centre → centre, max → max), so a 2.0 host hears the 1.0 dynamics unchanged.
    func testTheWideningKeepsTheAnchors() {
        XCTAssertEqual(UMPEncoder.velocity7to16(0), 0)
        XCTAssertEqual(UMPEncoder.velocity7to16(64), 0x8000, "centre must map to centre (#1253)")
        XCTAssertEqual(UMPEncoder.velocity7to16(127), 0xFFFF, "max must map to max (#1253)")
        XCTAssertEqual(UMPEncoder.cc7to32(0), 0)
        XCTAssertEqual(UMPEncoder.cc7to32(64), 0x8000_0000)
        XCTAssertEqual(UMPEncoder.cc7to32(127), 0xFFFF_FFFF)
        XCTAssertEqual(UMPEncoder.bend14to32(8192), 0x8000_0000, "bend centre (#1253)")
        XCTAssertEqual(UMPEncoder.bend14to32(0x3FFF), 0xFFFF_FFFF)
        let on = UMPEncoder.note2On(channel: 3, note: 60, velocity16: 0xFFFF)
        XCTAssertEqual(on.0 >> 28, 0x4, "message type 4 = MIDI 2.0 channel voice (#1253)")
        XCTAssertEqual((on.0 >> 20) & 0xF, 0x9)
        XCTAssertEqual((on.0 >> 16) & 0xF, 3)
        XCTAssertEqual((on.0 >> 8) & 0x7F, 60)
        XCTAssertEqual(on.1 >> 16, 0xFFFF)
        XCTAssertEqual((UMPEncoder.note2Off(channel: 0, note: 1, velocity16: 0).0 >> 20) & 0xF, 0x8)
    }

    /// Claim 6 — the door: a Toggle in the routing surface, persisted through the key, applied
    /// through the same funnel as the other two switches.
    func testTheRoutingSurfaceHasTheToggle() throws {
        let view = SourceText.codeOnly(try text(Self.surface))
        XCTAssertTrue(view.contains("@AppStorage(StudioDefaultKeys.midiOutUMP2.key)"),
                      "the toggle must persist through the ONE key definition (#416/#1253)")
        let section = try Self.member("private var midiOutSection: some View", in: view)
        XCTAssertTrue(section.contains("Toggle(isOn: $midiOutUMP2)"), "the MIDI 2.0 toggle left the routing surface (#1253)")
        XCTAssertTrue(section.contains("Text(\"MIDI 2.0 source\")"))
        XCTAssertTrue(section.contains(".onChange(of: midiOutUMP2) { _, _ in midiOut.applyOutputPreferences() }"),
                      "a toggle that stores but never applies is a control that lies (#485/#1253)")
    }

    /// Claim 7 — the prose homes moved with the code (#456): the encoder's status line, the
    /// claims list, the website. A "TEST-ONLY" note over a wired builder is the #1229 defect
    /// inverted.
    func testTheProseHomesMoved() throws {
        let header = try text("Sources/Echoelmusic/Sync/UMPEncoder.swift")
        XCTAssertFalse(header.contains("TEST-ONLY until that source exists"),
                       "UMPEncoder's header still calls the 2.0 builders test-only (#1253)")
        XCTAssertTrue(header.contains("THAT SOURCE EXISTS SINCE #1253"))
        let claims = try text("ContentPipeline/CLAIMS.md")
        XCTAssertTrue(claims.contains("Zweite Quelle im MIDI-2.0-Protokoll"),
                      "CLAIMS.md does not list the MIDI 2.0 source — copy will either invent or deny it (#1253)")
        XCTAssertTrue(claims.contains("NIE als „natives MIDI-2.0-MPE"),
                      "the row must carry its own ceiling — per-note expression stays test-only (#1253)")
        let faq = try text("docs/faq.html")
        XCTAssertTrue(faq.contains("&ldquo;Echoelmusic (MIDI&nbsp;2.0)&rdquo;"),
                      "the FAQ no longer names the second source (#1253)")
        XCTAssertFalse(faq.contains("native MIDI&nbsp;2.0 out, inter-app"),
                       "the FAQ still lists MIDI 2.0 out as roadmap (#1253)")
        let index = try text("docs/index.html")
        XCTAssertTrue(index.contains("2.0 source out (switch)"))
    }

    /// Claim 8 — counterweights: the 1.0 source and the MPE gate are as they were; the 2.0
    /// source is ADDED beside them, not swapped in.
    func testTheFirstSourceAndTheMPEGateAreUntouched() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        XCTAssertEqual(src.components(separatedBy: "MIDISourceCreateWithProtocol(client, \"Echoelmusic\" as CFString, ._1_0, &newSource)").count - 1, 1,
                       "the MIDI 1.0 source every DAW records from must stay exactly as it was (#1253)")
        XCTAssertEqual(src.components(separatedBy: "if mpeEnabled, expressionEnabled").count - 1, 1,
                       "the MPE expression gate moved — MIDIOutQualitySwitchesTests claim 2 is the owner (#713)")
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
