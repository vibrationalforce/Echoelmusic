// TheSamplerRendersAtTheGraphRateTests.swift
// Echoel — #1213 (audit 2026-09-10 `audio-dsp-5`). The preview sampler no longer pays a
// sample-rate converter on every render block.
//
// THE COST. `SamplerVoice.sampleRate` was 44.1 kHz in a 48 kHz graph — the only source node
// pinned below `AudioConfiguration.preferredSampleRate` (PolySynthVoice, SubBassVoice,
// BioReactiveSynthVoice, MetronomeVoice, SessionEngine all sit at 48 kHz). `AVAudioEngine`
// connects a source whose format differs from the mixer's through an implicit converter, and
// `previewVoice` is attached for the life of the engine (`BeatPlayer.attach(to:)`), so the
// converter resampled SILENCE on every block, with one more per timeline lane.
//
// WHAT THIS PINS. (1) The sampler's rate IS the graph's — by value, against the one constant
// the graph is configured from, so a future rate change moves both or goes red. (2) The frame
// ceiling still means ~2 s at that rate (the documented contract of `maxSampleFrames`).
// (3) COUNTERWEIGHT — `loadSample` still resamples every file to `Self.sampleRate` at LOAD
// time and the source node is built from `Self.sampleRate`, so a 44.1 kHz WAV keeps its pitch
// and length; the converter moved from every render block to a one-off at load.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`8fc7ceb`) and this tree: claim 1
// RED on the parent (44_100 ≠ 48_000), GREEN here; claims 2 and 3 are green on BOTH trees —
// 88_200 WAS 2 s at the old rate, so claim 2 is a counterweight that goes red only if the
// ceiling and the rate drift apart, not a proof of this change. (The first draft of this
// header called claim 2 parent-red; the transcription said otherwise, and the transcription
// is the measurement.)
//
// ⚠️ THE LIMIT. A source scan cannot see the converter itself; that the converter is gone is
// `AVAudioEngine`'s documented behaviour for matching formats, not something XCTest observes.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSamplerRendersAtTheGraphRateTests: XCTestCase {

    /// Claim 1 — the sampler renders at the graph's own rate.
    func testTheSamplerRateIsTheGraphRate() {
        XCTAssertEqual(SamplerVoice.sampleRate, AudioConfiguration.preferredSampleRate,
                       "SamplerVoice renders below/above the graph rate again — AVAudioEngine " +
                       "inserts a converter on the always-attached previewVoice (#1213)")
    }

    /// Claim 2 — the frame ceiling is still ~2 s AT that rate.
    func testTheFrameCeilingIsTwoSecondsAtThatRate() {
        XCTAssertEqual(SamplerVoice.maxSampleFrames, Int(SamplerVoice.sampleRate * 2),
                       "maxSampleFrames no longer means ~2 s at SamplerVoice.sampleRate — the " +
                       "documented ceiling and the rate drifted apart (#1213)")
    }

    /// Claim 3 — counterweight: files are resampled to that rate at LOAD, and the node is
    /// built from the same constant.
    func testFilesAreResampledAtLoadAndTheNodeUsesTheSameRate() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Sequencer/SamplerVoice.swift"))
        XCTAssertTrue(src.contains("targetRate: Self.sampleRate"),
                      "loadSample no longer resamples to Self.sampleRate — a 44.1 kHz WAV would " +
                      "play at the wrong pitch now that the node sits at the graph rate (#1213)")
        XCTAssertTrue(src.contains("standardFormatWithSampleRate: Self.sampleRate"),
                      "the source node's format is no longer built from Self.sampleRate (#1213)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
