//
//  AHostedUnitMustSpeakTheTrackBusShapeTests.swift
//  Night sweep 2026-10-14 (shell plan item 1): `AudioEngine.attachAudioUnit` connected a hosted
//  Audio Unit with whatever format its bus 0 reported. The track bus is built for the shape every
//  voice in this graph uses — mono or stereo, 32-bit float, one buffer per channel. A multi-out
//  instrument, or an integer or interleaved stream, now gets refused before `connect`, and
//  `finishLoad` marks the plugin failed, so the track keeps its built-in voice.
//
//  WHAT THIS PINS:
//  · claim 1 (BEHAVIOUR): `AudioEngine.trackBusTakes` accepts mono and stereo Float32
//    deinterleaved formats and refuses four channels, Int16 and interleaved Float32.
//  · claim 2 (SOURCE SCAN, comments stripped): inside `attachAudioUnit` the refusal branch comes
//    BEFORE the first `connect`, and it detaches the unit.
//  Nothing here forbids a wider bus later (#364). Widening it means changing this predicate and
//  this guard in the same commit.
//
//  GRADING (#433/#464): claim 1 does not compile on the parent (no `trackBusTakes`), and claim 2's
//  needle is absent there. Green on the worktree. Transcribed, not run.
//
//  `Tests/CISmoke` is the blocking bundle.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
@testable import Echoelmusic

final class AHostedUnitMustSpeakTheTrackBusShapeTests: XCTestCase {

    // MARK: 1 — the predicate

    func testOnlyMonoOrStereoFloatReachesATrackBus() throws {
        let stereo = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let mono = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        XCTAssertTrue(AudioEngine.trackBusTakes(stereo))
        XCTAssertTrue(AudioEngine.trackBusTakes(mono))

        let quad = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 4))
        XCTAssertFalse(AudioEngine.trackBusTakes(quad), "a multi-out bus 0 is refused")
        let int16 = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                                channels: 2, interleaved: false))
        XCTAssertFalse(AudioEngine.trackBusTakes(int16), "an integer stream is refused")
        let interleaved = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                                      channels: 2, interleaved: true))
        XCTAssertFalse(AudioEngine.trackBusTakes(interleaved), "an interleaved stream is refused")
    }

    // MARK: 2 — the attach asks it before it connects

    func testTheAttachRefusesBeforeItConnects() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/Echoelmusic/Audio/AudioEngine.swift")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Sources/ not on disk — this run has no source tree")
        }
        let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        guard let start = code.range(of: "func attachAudioUnit(_ unit: AVAudioUnit, slot: Int) -> Bool {"),
              let end = code[start.upperBound...].range(of: "\n    }\n") else {
            return XCTFail("ANCHOR MISSING: attachAudioUnit(_:slot:)")
        }
        let body = code[start.lowerBound..<end.upperBound]
        guard let refuse = body.range(of: "!Self.trackBusTakes(own)"),
              let connect = body.range(of: "masterEngine.connect(") else {
            return XCTFail("the attach no longer asks `trackBusTakes`, or no longer connects")
        }
        XCTAssertLessThan(refuse.lowerBound, connect.lowerBound, "refuse before any connect")
        XCTAssertTrue(body[refuse.upperBound..<connect.lowerBound].contains("masterEngine.detach(unit)"),
                      "a refused unit leaves the graph at once")
    }
}
#endif
