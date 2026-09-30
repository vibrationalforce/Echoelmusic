// TheCodecNoteNamesNoInputTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten"), first step:
// "Mikrofon-Satz aus dem Codec-Hinweis streichen".
//
// WHAT IT GUARDS. `AudioConfiguration.RouteCodec.note` is the one sentence the latency numbers
// cannot carry: Bluetooth in call mode (HFP) is mono and band-limited, and the music is too.
// Until 2026-09-30 both sentences ended with advice about an INPUT — "the iPhone mic as input",
// "check which input is selected". #1302 deleted the audio input on 2026-09-12; the advice
// outlived it by eighteen days because the property has no reader: `LatencyReadout.codec` is
// constructed in `latencySnapshot()` and read by no view (measured on this tree:
// `git grep -n "\.codec\b" -- Sources` → the declaration and the constructor, nothing else).
// A sentence nobody renders can still ship — Zug 3 mounts it in the master panel — so the
// decision is pinned where it is written, not where it will be shown.
//
// §1 LIMIT: claims 1–4 are END-TO-END BEHAVIOUR on a pure value type (an enum with no state,
// `@testable`-reachable); claim 5 is a SOURCE-TEXT SCAN and says so. Nothing here proves the
// sentence reaches a screen — today it provably does not, and the header above says so rather
// than letting a green read as "shown".
//
// §3 HONEST GRADING, transcribed in Python against the parent (2b3d08405) and this tree:
// claim 1 is the DECISION — on the parent both notes carry "mic"/"input", so its 2 word
// assertions are RED there (one decision, reported once, #486). Claims 2, 3 and 5 are
// COUNTERWEIGHTS, green on both trees. Claim 4 RESTORES a pin that
// TheBluetoothCodecReachesTheScreenTests carried until #1302 deleted that file; it is green on
// both trees and was unpinned in between — the comment on `hfpPortType` cited the deleted guard
// the whole time (#474). ZERO regressions claimed.

#if canImport(AVFoundation)
import AVFoundation
#endif
import Foundation
import XCTest
@testable import Echoelmusic

final class TheCodecNoteNamesNoInputTests: XCTestCase {

    private typealias Codec = AudioConfiguration.RouteCodec

    /// Whole words the note may not contain: the app has had no audio input since #1302, so
    /// any of these is advice about a control that does not exist.
    private static let inputWords: Set<String> = ["mic", "microphone", "input", "inputs"]

    private func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter }.map(String.init))
    }

    // MARK: - claim 1 — the DECISION: neither call-mode sentence names an input

    func testTheCallModeSentencesNameNoInput() throws {
        for codec in [Codec.telephony, Codec.telephonySuspected] {
            let note = try XCTUnwrap(codec.note, "\(codec) has something to say — a nil here is a regression, not a pass")
            let hit = words(note).intersection(Self.inputWords)
            XCTAssertTrue(hit.isEmpty, """
                `RouteCodec.\(codec).note` names an input again (\(hit.sorted())): "\(note)". \
                Echoel has had no audio input since #1302 — the phone's own microphone is not a \
                selectable route, so "use the mic as input" or "check which input is selected" \
                is advice about a control the player cannot find. Say what IS true: Echoel only \
                plays out, another app holds the call, a cable keeps full bandwidth. If an input \
                ever returns, rewrite this claim WITH it in the same commit (#456).
                """)
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT, #343) — nothing to say renders no row

    func testWidebandHasNothingToSay() {
        XCTAssertNil(Codec.wideband.note, """
            `RouteCodec.wideband.note` grew a sentence. The whole point of `nil` is that a caller \
            renders NO row rather than a reassuring "all good" line nobody asked for.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT, #654) — named and inferred never print the same sentence

    func testTheNamedAndTheInferredCaseDiffer() throws {
        let named = try XCTUnwrap(Codec.telephony.note)
        let inferred = try XCTUnwrap(Codec.telephonySuspected.note)
        XCTAssertNotEqual(named, inferred, """
            `.telephony` (iOS NAMED an HFP port) and `.telephonySuspected` (we INFERRED from a \
            low rate) print the same sentence. #654 exists because this file once rendered \
            "could not measure" and "measured zero" identically; "is" and "looks like" must stay \
            two sentences.
            """)
        XCTAssertTrue(inferred.lowercased().contains("looks like"),
                      "the inferred case must hedge — it is corroborating evidence, never a verdict")
        XCTAssertFalse(named.lowercased().contains("looks like"),
                       "the named case must NOT hedge — iOS named the port, nothing is guessed")
    }

    // MARK: - claim 4 — the port-type literal still equals the AVFoundation constant

    /// `hfpPortType` is a STRING literal so `routeCodec` stays a pure function a test can drive
    /// without a live session. The literal is only safe while it equals the framework's raw
    /// value; this assertion is what makes an iOS rename a red guard instead of a silent
    /// `wideband` verdict on a call-mode route. (Restored: the pin went with #1302's file.)
    func testTheHFPPortLiteralMatchesAVFoundation() throws {
        #if canImport(AVFoundation)
        XCTAssertEqual(AudioConfiguration.hfpPortType, AVAudioSession.Port.bluetoothHFP.rawValue, """
            `AudioConfiguration.hfpPortType` no longer equals `AVAudioSession.Port.bluetoothHFP`. \
            `routeCodec` compares the route's port types against this literal; a mismatch means a \
            phone call's HFP route reads as `wideband` and the call-mode sentence never appears.
            """)
        #else
        throw XCTSkip("AVFoundation is not importable on this platform — claim 4 needs the framework constant")
        #endif
    }

    // MARK: - claim 5 (COUNTERWEIGHT, SOURCE-TEXT SCAN) — the note still has its carrier

    /// `LatencyReadout.codec` is where a future master-panel row will read the note (Zug 3).
    /// If the field goes, the sentence above has no way to the screen at all — delete the
    /// claims above together with it rather than leaving a guard over unreachable copy.
    func testTheReadoutStillCarriesTheCodec() throws {
        let code = try source("Sources/Echoelmusic/Audio/AudioConfiguration.swift")
        XCTAssertTrue(code.contains("let codec: RouteCodec"), """
            `LatencyReadout` lost its `codec` field — the note's only carrier. Either the \
            audio-route row moved somewhere else (move this scan with it) or the sentence is \
            now unreachable by construction (then retire this file, do not leave it green).
            """)
    }

    // MARK: - source access

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped source (#453 — one stripper for the whole bundle). A SKIP without a
    /// checkout, a FAILURE when a named file moved (#454: a skip passes CI).
    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
