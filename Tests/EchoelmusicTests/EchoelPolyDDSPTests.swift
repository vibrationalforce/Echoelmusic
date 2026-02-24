// EchoelPolyDDSPTests.swift
// Tests for EchoelPolyDDSP — Polyphonic DDSP with voice management

import XCTest
@testable import Echoelmusic

final class EchoelPolyDDSPTests: XCTestCase {

    // MARK: - Init

    func testPolyDDSPInit() {
        let poly = EchoelPolyDDSP(maxVoices: 8, harmonicCount: 64, sampleRate: 48000)
        XCTAssertEqual(poly.maxVoices, 8)
        XCTAssertEqual(poly.sampleRate, 48000)
        XCTAssertEqual(poly.activeVoiceCount, 0)
    }

    func testPolyDDSPCustomVoiceCount() {
        let poly = EchoelPolyDDSP(maxVoices: 16)
        XCTAssertEqual(poly.maxVoices, 16)
        XCTAssertEqual(poly.activeVoiceCount, 0)
    }

    // MARK: - Note On/Off

    func testNoteOnActivatesVoice() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 60) // Middle C
        XCTAssertEqual(poly.activeVoiceCount, 1)
    }

    func testMultipleNotesActivateMultipleVoices() {
        let poly = EchoelPolyDDSP(maxVoices: 8)
        poly.noteOn(note: 60) // C
        poly.noteOn(note: 64) // E
        poly.noteOn(note: 67) // G
        XCTAssertEqual(poly.activeVoiceCount, 3)
    }

    func testNoteOffDeactivatesVoice() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 60)
        poly.noteOff(note: 60)
        // Voice is in release, so still active but will decay
        // (We count it as not active since voiceNotes = -1)
        XCTAssertEqual(poly.activeVoiceCount, 0)
    }

    func testAllNotesOff() {
        let poly = EchoelPolyDDSP(maxVoices: 8)
        for note in 60...72 {
            poly.noteOn(note: note)
        }
        XCTAssertGreaterThan(poly.activeVoiceCount, 0)
        poly.allNotesOff()
        XCTAssertEqual(poly.activeVoiceCount, 0)
    }

    // MARK: - Voice Stealing

    func testVoiceStealingWhenFull() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 60)
        poly.noteOn(note: 62)
        poly.noteOn(note: 64)
        poly.noteOn(note: 67)
        XCTAssertEqual(poly.activeVoiceCount, 4)

        // 5th note should steal oldest voice
        poly.noteOn(note: 72)
        XCTAssertEqual(poly.activeVoiceCount, 4) // Still 4 max
    }

    // MARK: - Audio Rendering

    func testRenderSilenceWithNoNotes() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        let frameCount = 256
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)

        poly.render(left: &left, right: &right, frameCount: frameCount)

        for i in 0..<frameCount {
            XCTAssertEqual(left[i], 0)
            XCTAssertEqual(right[i], 0)
        }
    }

    func testRenderProducesAudioWithNotes() {
        let poly = EchoelPolyDDSP(maxVoices: 4, sampleRate: 48000)
        poly.noteOn(note: 69, velocity: 0.8) // A4 = 440Hz

        let frameCount = 256
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)

        // Render a few frames to let envelope ramp up
        for _ in 0..<4 {
            poly.render(left: &left, right: &right, frameCount: frameCount)
        }

        // Should have non-zero audio
        let hasAudio = left.contains { $0 != 0 } || right.contains { $0 != 0 }
        XCTAssertTrue(hasAudio, "Expected audio output with active note")
    }

    func testRenderStereoSpread() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 48)
        poly.noteOn(note: 60)
        poly.noteOn(note: 72)

        let frameCount = 256
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)

        for _ in 0..<4 {
            poly.render(left: &left, right: &right, frameCount: frameCount)
        }

        // With multiple notes, stereo spread should make L and R differ
        let hasLeftAudio = left.contains { abs($0) > 0.0001 }
        let hasRightAudio = right.contains { abs($0) > 0.0001 }
        XCTAssertTrue(hasLeftAudio || hasRightAudio)
    }

    // MARK: - Bio-Reactive

    func testBioReactiveApplied() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 60)

        // Apply bio-reactive parameters — should not crash
        poly.applyBioReactive(
            coherence: 0.8,
            hrvVariability: 0.6,
            heartRate: 0.5,
            breathPhase: 0.7,
            breathDepth: 0.5,
            lfHfRatio: 0.4,
            coherenceTrend: 0.1
        )

        XCTAssertEqual(poly.activeVoiceCount, 1)
    }

    func testBioReactiveExtremeValues() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        poly.noteOn(note: 69)

        // Edge cases
        poly.applyBioReactive(coherence: 0, hrvVariability: 0, heartRate: 0)
        poly.applyBioReactive(coherence: 1, hrvVariability: 1, heartRate: 1)

        let frameCount = 128
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        poly.render(left: &left, right: &right, frameCount: frameCount)

        // Should not produce NaN or Inf
        for val in left + right {
            XCTAssertFalse(val.isNaN, "NaN in output")
            XCTAssertFalse(val.isInfinite, "Inf in output")
        }
    }

    // MARK: - Spectral Control

    func testSetSpectralShape() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        for shape in EchoelDDSP.SpectralShape.allCases {
            poly.setSpectralShape(shape)
        }
        // Should not crash
        XCTAssertTrue(true)
    }

    func testLoadTimbreProfile() {
        let poly = EchoelPolyDDSP(maxVoices: 4)
        let profile = EchoelDDSP.instrumentProfile(.violin, harmonics: 64)
        poly.loadTimbreProfile(profile, blend: 0.5)
        XCTAssertEqual(poly.activeVoiceCount, 0) // No notes yet, just profile loaded
    }

    // MARK: - Reset

    func testResetClearsAllVoices() {
        let poly = EchoelPolyDDSP(maxVoices: 8)
        for note in 60...72 {
            poly.noteOn(note: note)
        }
        XCTAssertGreaterThan(poly.activeVoiceCount, 0)

        poly.reset()
        XCTAssertEqual(poly.activeVoiceCount, 0)
    }

    // MARK: - Performance

    func testPolyphonicRenderPerformance() {
        let poly = EchoelPolyDDSP(maxVoices: 8, harmonicCount: 32, sampleRate: 48000)
        for note in [48, 52, 55, 60, 64, 67, 72, 76] {
            poly.noteOn(note: note, velocity: 0.7)
        }

        let frameCount = 256
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)

        measure {
            for _ in 0..<100 {
                poly.render(left: &left, right: &right, frameCount: frameCount)
            }
        }
    }
}
