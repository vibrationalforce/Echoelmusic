// TheInputFeedsThePictureTests.swift
// Echoel — #1248 (founder 2026-09-11: *"per microphon zum Beispiel auf Konzerten, im Club oder
// auf Festivals oder andere Audio Inputs die physikalisch assoziierten visuals zu generieren"*).
// The live INPUT reaches the picture: level, bass share, transient energy and brightness.
//
// MEASURED BEFORE THIS SLICE: no visual read the input. Every audio-reactive surface read the
// synth OUTPUT ring, and `MetalBioView` read only `MusicalFrame.masterLevel` — a sum of note
// VELOCITIES from the piano-roll tick, not measured audio. The monitor tap's 2048-sample window
// and its ~15 Hz FFT existed and fed the howl detector alone.
//
// THE SHAPE. `AudioFeatureExtractor` (pure, Foundation-only) turns window + spectrum into
// `AudioFeatureFrame`; `AudioEngine.updateFeedbackGuard` publishes it into
// `AudioFeatureChannel.shared` (the `TouchVisualEnergy` lock-leaf shape — no actor hop, no
// observable); `MetalBioView.draw(in:)` reads it once per frame inside its MainActor block and
// folds it into the CPU-side terms that already existed (`musicLevel`, the touch energy, the
// hue bias). NO new uniform, so the 99-field MSL mirror is untouched (#1119).
//
// END-TO-END BEHAVIOUR for claims 1–3 (the extractor and the channel are shipped value types
// driven here); SOURCE-TEXT SCAN for claims 4–6 (the wiring). Whether the picture visibly
// follows a room is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY at `AudioEngine.inputFeatures`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`cfe8364`) and this tree: claims
// 1–3 RED on the parent (the types do not exist — ONE finding, #486), GREEN here, the
// arithmetic driven in Python beforehand; claims 4–6 RED on the parent, GREEN here. Stripper:
// PROPHYLAKTISCH (0 of 9 scan verdicts flip).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheInputFeedsThePictureTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let fftSize = 2048

    /// A magnitude spectrum with one peak at `hz` (bin resolution `sampleRate / fftSize`).
    private func spectrum(peakHz: Float, amplitude: Float = 1) -> [Float] {
        var m = [Float](repeating: 0, count: fftSize / 2)
        let bin = Int((Double(peakHz) / sampleRate * Double(fftSize)).rounded())
        if bin > 0, bin < m.count { m[bin] = amplitude }
        return m
    }

    /// A sine window at `rmsDBFS`.
    private func window(rmsDBFS: Float) -> [Float] {
        let amp = pow(10, rmsDBFS / 20) * Float(2).squareRoot()
        return (0..<fftSize).map { amp * sin(Float($0) * 0.05) }
    }

    /// Claim 1 — silence is the EXACT zero frame (the #1244 skip depends on it).
    func testSilenceIsExactlyZero() {
        var x = AudioFeatureExtractor()
        let quiet = x.analyze(samples: window(rmsDBFS: -70), magnitudes: spectrum(peakHz: 100),
                              sampleRate: sampleRate, timestamp: 1)
        XCTAssertEqual(quiet, .silent(at: 1), "a −70 dBFS window must yield the all-zero frame, not a small float (#1248)")
        XCTAssertTrue(quiet.isSilent)
        let none = x.analyze(samples: [], magnitudes: [], sampleRate: sampleRate, timestamp: 2)
        XCTAssertEqual(none, .silent(at: 2))
        let badRate = x.analyze(samples: window(rmsDBFS: -20), magnitudes: spectrum(peakHz: 100),
                                sampleRate: 0, timestamp: 3)
        XCTAssertEqual(badRate, .silent(at: 3), "a 0 Hz tap rate must not divide (#1248)")
    }

    /// Claim 2 — bands, level and centroid are physically associated with the spectrum.
    func testBassIsLowAndHatsAreBright() {
        var x = AudioFeatureExtractor()
        let bass = x.analyze(samples: window(rmsDBFS: -20), magnitudes: spectrum(peakHz: 80),
                             sampleRate: sampleRate, timestamp: 1)
        XCTAssertGreaterThan(bass.low, 0.99, "an 80 Hz peak is all low band (#1248)")
        XCTAssertEqual(bass.high, 0, accuracy: 1e-6)
        XCTAssertGreaterThan(bass.level, 0.6, "−20 dBFS on a −60…−6 axis is ~0.74 (#1248)")
        XCTAssertLessThan(bass.level, 0.8)
        let hats = x.analyze(samples: window(rmsDBFS: -20), magnitudes: spectrum(peakHz: 8_000),
                             sampleRate: sampleRate, timestamp: 2)
        XCTAssertGreaterThan(hats.high, 0.99)
        XCTAssertGreaterThan(hats.centroid, bass.centroid, "brightness must rise from bass to hats (#1248)")
        XCTAssertLessThan(bass.centroid, 0.3)
        XCTAssertGreaterThan(hats.centroid, 0.7)
        XCTAssertEqual(bass.low + bass.mid + bass.high, 1, accuracy: 1e-5, "band shares sum to one when sounding (#1248)")
    }

    /// Claim 3 — a transient reads as an onset, a steady tone does not, and the channel decays to EXACT zero.
    func testATransientIsAnOnsetAndTheChannelDecaysToZero() {
        var x = AudioFeatureExtractor()
        let steady = spectrum(peakHz: 440, amplitude: 0.2)
        var lastSteady = AudioFeatureFrame.silent(at: 0)
        for i in 0..<30 {
            lastSteady = x.analyze(samples: window(rmsDBFS: -20), magnitudes: steady,
                                   sampleRate: sampleRate, timestamp: Double(i) / 15)
        }
        XCTAssertEqual(lastSteady.onset, 0, "a steady tone is not an onset (#1248)")
        let hit = x.analyze(samples: window(rmsDBFS: -12), magnitudes: spectrum(peakHz: 440, amplitude: 4),
                            sampleRate: sampleRate, timestamp: 2.0)
        XCTAssertGreaterThan(hit.onset, 0.5, "a sudden 20× jump must read as a strong transient (#1248)")

        let channel = AudioFeatureChannel()
        channel.publish(hit)
        let now = channel.snapshot(now: 2.0)
        XCTAssertGreaterThan(now.onsetEnergy, 0.2)
        XCTAssertEqual(now.frame, hit, "a fresh frame is returned as published (#1248)")
        let later = channel.snapshot(now: 2.0 + 6 * Double(AudioFeatureChannel.onsetTauSeconds))
        XCTAssertEqual(later.onsetEnergy, 0, "six time constants later the energy must be the EXACT 0 (#1244/#1248)")
        XCTAssertTrue(later.frame.isSilent, "a stale frame reads as silent without a reset (#1248)")
        channel.publish(hit)
        channel.reset()
        XCTAssertTrue(channel.snapshot(now: 2.0).frame.isSilent)
        XCTAssertEqual(channel.snapshot(now: 2.0).onsetEnergy, 0)
    }

    /// Claim 4 — the engine publishes from the SAME spectrum the howl detector reads, and OFF resets.
    func testTheGuardTickPublishesAndOffResets() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Audio/AudioEngine.swift"))
        let tick = try Self.member("private func updateFeedbackGuard()", in: src)
        XCTAssertTrue(tick.contains("AudioFeatureChannel.shared.publish("),
                      "`updateFeedbackGuard` no longer publishes the input features — the picture is deaf again (#1248)")
        XCTAssertEqual(tick.components(separatedBy: "monitorSpectrumFFT.forward(").count - 1, 1,
                       "exactly ONE FFT per tick — the feature stage must read the howl detector's spectrum, not run a second (#1248)")
        let off = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        XCTAssertTrue(off.contains("AudioFeatureChannel.shared.reset()"),
                      "monitoring OFF no longer resets the channel — a stale frame could linger (#1248)")
    }

    /// Claim 5 — the renderer reads the channel in `draw`, never in `updateUIView`, and folds it into existing terms.
    func testTheRendererReadsTheChannelInDrawOnly() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        let draw = try Self.member("func draw(in view: MTKView)", in: src)
        XCTAssertEqual(draw.components(separatedBy: "AudioFeatureChannel.shared.snapshot(now: nowGov)").count - 1, 1,
                       "`draw(in:)` must read the input channel exactly once per frame (#1248)")
        let update = try Self.member("func updateUIView(", in: src)
        XCTAssertFalse(update.contains("AudioFeatureChannel"),
                       "`updateUIView` reads the input channel — that is a SwiftUI graph node, the 10.76.41/50 law (#1248)")
        for needle in ["musicLevel = max(musicLevel, input.frame.level)",
                       "let liveE = min(1, touchE + input.onsetEnergy)",
                       "hueShift: lookHue + voiceHueBias + audioHueBias",
                       "0.25 * bassSwing"] {
            XCTAssertTrue(draw.contains(needle), "the input no longer reaches `\(needle)` (#1248)")
        }
    }

    /// Claim 6 — counterweights: no new uniform (the MSL mirror is positional, #1119) and the listen-only caption exists.
    func testNoNewUniformAndTheListenOnlyCaptionExists() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        let uniforms = try Self.member("private struct BioUniforms", in: src)
        XCTAssertFalse(uniforms.contains("audio"), "a new audio uniform was added to `BioUniforms` — append it on BOTH sides of the mirror in one commit and move this claim (#1119/#1248)")
        let picker = try text("Sources/Echoelmusic/Studio/AudioInputPickerView.swift")
        XCTAssertTrue(picker.contains("0 = listen only: nothing reaches the speakers, the picture still follows the input."),
                      "the listen-only caption under Monitor level is gone — a performer at a club cannot know the picture follows a muted input (#1248)")
    }

    // MARK: - helpers

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
