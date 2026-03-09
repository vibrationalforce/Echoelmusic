#if canImport(AVFoundation)
// VideoExtendedTests.swift
// Echoelmusic — Extended Video & Export Module Tests
//
// Tests for BPMGridEditEngine types, ProColorGrading types,
// and VideoEditingEngine types.

import XCTest
import Foundation
@testable import Echoelmusic

// MARK: - TimeSignature Tests

final class ExtendedTimeSignatureTests: XCTestCase {

    func testDefaultInit() {
        let ts = TimeSignature()
        XCTAssertEqual(ts.numerator, 4)
        XCTAssertEqual(ts.denominator, 4)
    }

    func testCustomInit() {
        let ts = TimeSignature(numerator: 3, denominator: 8)
        XCTAssertEqual(ts.numerator, 3)
        XCTAssertEqual(ts.denominator, 8)
    }

    func testFourFourStatic() {
        let ts = TimeSignature.fourFour
        XCTAssertEqual(ts.numerator, 4)
        XCTAssertEqual(ts.denominator, 4)
    }

    func testThreeFourStatic() {
        let ts = TimeSignature.threeFour
        XCTAssertEqual(ts.numerator, 3)
        XCTAssertEqual(ts.denominator, 4)
    }

    func testSixEightStatic() {
        let ts = TimeSignature.sixEight
        XCTAssertEqual(ts.numerator, 6)
        XCTAssertEqual(ts.denominator, 8)
    }

    func testTwoFourStatic() {
        XCTAssertEqual(TimeSignature.twoFour.numerator, 2)
        XCTAssertEqual(TimeSignature.twoFour.denominator, 4)
    }

    func testFiveFourStatic() {
        XCTAssertEqual(TimeSignature.fiveFour.numerator, 5)
    }

    func testSevenEightStatic() {
        XCTAssertEqual(TimeSignature.sevenEight.numerator, 7)
        XCTAssertEqual(TimeSignature.sevenEight.denominator, 8)
    }

    func testTwelveEightStatic() {
        XCTAssertEqual(TimeSignature.twelveEight.numerator, 12)
        XCTAssertEqual(TimeSignature.twelveEight.denominator, 8)
    }

    func testCommonCount() {
        XCTAssertEqual(TimeSignature.common.count, 7)
    }

    func testDisplayString() {
        XCTAssertEqual(TimeSignature.fourFour.displayString, "4/4")
        XCTAssertEqual(TimeSignature.sixEight.displayString, "6/8")
        XCTAssertEqual(TimeSignature.threeFour.displayString, "3/4")
    }

    func testBeatsPerBarSimpleMeter() {
        XCTAssertEqual(TimeSignature.fourFour.beatsPerBar, 4)
        XCTAssertEqual(TimeSignature.threeFour.beatsPerBar, 3)
        XCTAssertEqual(TimeSignature.twoFour.beatsPerBar, 2)
    }

    func testBeatsPerBarCompoundMeter() {
        XCTAssertEqual(TimeSignature.sixEight.beatsPerBar, 2)
        XCTAssertEqual(TimeSignature.twelveEight.beatsPerBar, 4)
    }

    func testSubdivisionsPerBeatSimple() {
        XCTAssertEqual(TimeSignature.fourFour.subdivisionsPerBeat, 1)
    }

    func testSubdivisionsPerBeatCompound() {
        XCTAssertEqual(TimeSignature.sixEight.subdivisionsPerBeat, 3)
        XCTAssertEqual(TimeSignature.twelveEight.subdivisionsPerBeat, 3)
    }

    func testEquatable() {
        XCTAssertEqual(TimeSignature.fourFour, TimeSignature(numerator: 4, denominator: 4))
        XCTAssertNotEqual(TimeSignature.fourFour, TimeSignature.threeFour)
    }

    func testCodableRoundTrip() throws {
        let original = TimeSignature.sixEight
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimeSignature.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testHashable() {
        var set = Set<TimeSignature>()
        set.insert(.fourFour)
        set.insert(.fourFour)
        XCTAssertEqual(set.count, 1)
    }

    func testFiveFourBeatsPerBar() {
        XCTAssertEqual(TimeSignature.fiveFour.beatsPerBar, 5)
    }

    func testSevenEightBeatsPerBar() {
        // 7/8 is NOT compound (7 % 3 != 0), so beatsPerBar == numerator
        XCTAssertEqual(TimeSignature.sevenEight.beatsPerBar, 7)
    }
}

// MARK: - SnapMode Tests

final class ExtendedSnapModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(SnapMode.allCases.count, 9)
    }

    func testRawValues() {
        XCTAssertEqual(SnapMode.off.rawValue, "Off")
        XCTAssertEqual(SnapMode.bar.rawValue, "Bar")
        XCTAssertEqual(SnapMode.beat.rawValue, "Beat")
        XCTAssertEqual(SnapMode.halfBeat.rawValue, "1/2 Beat")
        XCTAssertEqual(SnapMode.quarterBeat.rawValue, "1/4 Beat")
        XCTAssertEqual(SnapMode.eighthBeat.rawValue, "1/8 Beat")
        XCTAssertEqual(SnapMode.triplet.rawValue, "Triplet")
        XCTAssertEqual(SnapMode.sixteenth.rawValue, "1/16")
        XCTAssertEqual(SnapMode.thirtySecond.rawValue, "1/32")
    }

    func testSubdivisionsPerBeat() {
        XCTAssertEqual(SnapMode.off.subdivisionsPerBeat, 0)
        XCTAssertEqual(SnapMode.bar.subdivisionsPerBeat, 0)
        XCTAssertEqual(SnapMode.beat.subdivisionsPerBeat, 1)
        XCTAssertEqual(SnapMode.halfBeat.subdivisionsPerBeat, 2)
        XCTAssertEqual(SnapMode.quarterBeat.subdivisionsPerBeat, 4)
        XCTAssertEqual(SnapMode.eighthBeat.subdivisionsPerBeat, 8)
        XCTAssertEqual(SnapMode.triplet.subdivisionsPerBeat, 3)
        XCTAssertEqual(SnapMode.sixteenth.subdivisionsPerBeat, 16)
        XCTAssertEqual(SnapMode.thirtySecond.subdivisionsPerBeat, 32)
    }

    func testIconsAreNonEmpty() {
        for mode in SnapMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode.rawValue) should have an icon")
        }
    }

    func testCodableRoundTrip() throws {
        for mode in SnapMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SnapMode.self, from: data)
            XCTAssertEqual(mode, decoded)
        }
    }
}

// MARK: - BeatPosition Tests

final class ExtendedBeatPositionTests: XCTestCase {

    func testDefaultInit() {
        let pos = BeatPosition()
        XCTAssertEqual(pos.bar, 1)
        XCTAssertEqual(pos.beat, 1)
        XCTAssertEqual(pos.tick, 0)
    }

    func testCustomInit() {
        let pos = BeatPosition(bar: 2, beat: 3, tick: 480)
        XCTAssertEqual(pos.bar, 2)
        XCTAssertEqual(pos.beat, 3)
        XCTAssertEqual(pos.tick, 480)
    }

    func testDisplayString() {
        let pos = BeatPosition(bar: 1, beat: 2, tick: 480)
        XCTAssertEqual(pos.displayString, "1.2.480")
    }

    func testShortDisplayString() {
        let pos = BeatPosition(bar: 3, beat: 4, tick: 0)
        XCTAssertEqual(pos.shortDisplayString, "3.4")
    }

    func testFromSeconds() {
        let pos = BeatPosition.from(seconds: 0, bpm: 120)
        XCTAssertEqual(pos.bar, 1)
        XCTAssertEqual(pos.beat, 1)
    }

    func testFromSecondsOneBeat() {
        // At 120 BPM, 1 beat = 0.5 seconds
        let pos = BeatPosition.from(seconds: 0.5, bpm: 120)
        XCTAssertEqual(pos.bar, 1)
        XCTAssertEqual(pos.beat, 2)
    }

    func testFromSecondsOneBar() {
        // At 120 BPM, 4/4, 1 bar = 2 seconds
        let pos = BeatPosition.from(seconds: 2.0, bpm: 120, timeSignature: .fourFour)
        XCTAssertEqual(pos.bar, 2)
        XCTAssertEqual(pos.beat, 1)
    }

    func testToSeconds() {
        let pos = BeatPosition(bar: 1, beat: 1, tick: 0)
        let seconds = pos.toSeconds(bpm: 120)
        XCTAssertEqual(seconds, 0, accuracy: 0.001)
    }

    func testToSecondsSecondBeat() {
        let pos = BeatPosition(bar: 1, beat: 2, tick: 0)
        let seconds = pos.toSeconds(bpm: 120)
        XCTAssertEqual(seconds, 0.5, accuracy: 0.001)
    }

    func testRoundTripConversion() {
        let originalSeconds = 3.5
        let pos = BeatPosition.from(seconds: originalSeconds, bpm: 120)
        let recoveredSeconds = pos.toSeconds(bpm: 120)
        XCTAssertEqual(recoveredSeconds, originalSeconds, accuracy: 0.01)
    }

    func testComparableLessThan() {
        let a = BeatPosition(bar: 1, beat: 1, tick: 0)
        let b = BeatPosition(bar: 1, beat: 2, tick: 0)
        XCTAssertTrue(a < b)
    }

    func testComparableBarDifference() {
        let a = BeatPosition(bar: 1, beat: 4, tick: 0)
        let b = BeatPosition(bar: 2, beat: 1, tick: 0)
        XCTAssertTrue(a < b)
    }

    func testComparableTickDifference() {
        let a = BeatPosition(bar: 1, beat: 1, tick: 100)
        let b = BeatPosition(bar: 1, beat: 1, tick: 200)
        XCTAssertTrue(a < b)
    }

    func testEquatable() {
        let a = BeatPosition(bar: 1, beat: 1, tick: 0)
        let b = BeatPosition(bar: 1, beat: 1, tick: 0)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = BeatPosition(bar: 5, beat: 3, tick: 240)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatPosition.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testFromSecondsClampsBPM() {
        // BPM below 20 should be clamped to 20
        let pos = BeatPosition.from(seconds: 3.0, bpm: 0)
        XCTAssertEqual(pos.bar, 1) // Should not crash
    }
}

// MARK: - BeatMarker Tests

final class ExtendedBeatMarkerTests: XCTestCase {

    func testMarkerTypeAllCasesCount() {
        XCTAssertEqual(BeatMarker.MarkerType.allCases.count, 10)
    }

    func testMarkerTypeRawValues() {
        XCTAssertEqual(BeatMarker.MarkerType.downbeat.rawValue, "Downbeat")
        XCTAssertEqual(BeatMarker.MarkerType.beat.rawValue, "Beat")
        XCTAssertEqual(BeatMarker.MarkerType.accent.rawValue, "Accent")
        XCTAssertEqual(BeatMarker.MarkerType.cue.rawValue, "Cue")
        XCTAssertEqual(BeatMarker.MarkerType.drop.rawValue, "Drop")
        XCTAssertEqual(BeatMarker.MarkerType.breakdown.rawValue, "Breakdown")
        XCTAssertEqual(BeatMarker.MarkerType.buildup.rawValue, "Buildup")
        XCTAssertEqual(BeatMarker.MarkerType.transition.rawValue, "Transition")
        XCTAssertEqual(BeatMarker.MarkerType.cut.rawValue, "Cut")
        XCTAssertEqual(BeatMarker.MarkerType.custom.rawValue, "Custom")
    }

    func testDefaultInit() {
        let marker = BeatMarker()
        XCTAssertEqual(marker.type, .beat)
        XCTAssertEqual(marker.label, "")
        XCTAssertEqual(marker.color, "#FF0000")
    }

    func testCustomInit() {
        let marker = BeatMarker(type: .drop, label: "Main Drop", color: "#00FF00")
        XCTAssertEqual(marker.type, .drop)
        XCTAssertEqual(marker.label, "Main Drop")
        XCTAssertEqual(marker.color, "#00FF00")
    }

    func testIconsAreNonEmpty() {
        for markerType in BeatMarker.MarkerType.allCases {
            let marker = BeatMarker(type: markerType)
            XCTAssertFalse(marker.icon.isEmpty, "\(markerType.rawValue) should have an icon")
        }
    }

    func testIdentifiable() {
        let a = BeatMarker()
        let b = BeatMarker()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCodableRoundTrip() throws {
        let original = BeatMarker(type: .cue, label: "Test", color: "#AABB00")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatMarker.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.color, original.color)
    }
}

// MARK: - TempoChange Tests

final class ExtendedTempoChangeTests: XCTestCase {

    func testTempoChangeCurveAllCasesCount() {
        XCTAssertEqual(TempoChange.TempoChangeCurve.allCases.count, 4)
    }

    func testTempoChangeCurveRawValues() {
        XCTAssertEqual(TempoChange.TempoChangeCurve.instant.rawValue, "Instant")
        XCTAssertEqual(TempoChange.TempoChangeCurve.linear.rawValue, "Linear")
        XCTAssertEqual(TempoChange.TempoChangeCurve.exponential.rawValue, "Exponential")
        XCTAssertEqual(TempoChange.TempoChangeCurve.sCurve.rawValue, "S-Curve")
    }

    func testDefaultInit() {
        let tc = TempoChange()
        XCTAssertEqual(tc.bpm, 120)
        XCTAssertEqual(tc.curve, .instant)
    }

    func testCustomInit() {
        let tc = TempoChange(bpm: 140, curve: .linear)
        XCTAssertEqual(tc.bpm, 140)
        XCTAssertEqual(tc.curve, .linear)
    }

    func testIdentifiable() {
        let a = TempoChange()
        let b = TempoChange()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCodableRoundTrip() throws {
        let original = TempoChange(bpm: 175, curve: .sCurve)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TempoChange.self, from: data)
        XCTAssertEqual(decoded.bpm, original.bpm)
        XCTAssertEqual(decoded.curve, original.curve)
    }
}

// MARK: - BeatSyncedTransition Tests

final class ExtendedBeatSyncedTransitionTests: XCTestCase {

    func testTransitionTypeAllCasesCount() {
        XCTAssertEqual(BeatSyncedTransition.TransitionType.allCases.count, 14)
    }

    func testTransitionTypeRawValues() {
        XCTAssertEqual(BeatSyncedTransition.TransitionType.cut.rawValue, "Cut")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.crossfade.rawValue, "Crossfade")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.fadeToBlack.rawValue, "Fade to Black")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.glitch.rawValue, "Glitch")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.beatFlash.rawValue, "Beat Flash")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.rhythmCut.rawValue, "Rhythm Cut")
        XCTAssertEqual(BeatSyncedTransition.TransitionType.strobeTransition.rawValue, "Strobe")
    }

    func testDefaultInit() {
        let t = BeatSyncedTransition()
        XCTAssertEqual(t.type, .cut)
        XCTAssertEqual(t.durationBeats, 1)
        XCTAssertTrue(t.startOnBeat)
        XCTAssertTrue(t.endOnBeat)
        XCTAssertFalse(t.syncToDownbeat)
        XCTAssertEqual(t.intensity, 1.0)
    }

    func testCustomInit() {
        let t = BeatSyncedTransition(type: .flash, durationBeats: 0.5, syncToDownbeat: true, intensity: 0.8)
        XCTAssertEqual(t.type, .flash)
        XCTAssertEqual(t.durationBeats, 0.5)
        XCTAssertTrue(t.syncToDownbeat)
        XCTAssertEqual(t.intensity, 0.8)
    }

    func testIconsAreNonEmpty() {
        for transType in BeatSyncedTransition.TransitionType.allCases {
            let t = BeatSyncedTransition(type: transType)
            XCTAssertFalse(t.icon.isEmpty, "\(transType.rawValue) should have an icon")
        }
    }

    func testIdentifiable() {
        let a = BeatSyncedTransition()
        let b = BeatSyncedTransition()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCodableRoundTrip() throws {
        let original = BeatSyncedTransition(type: .zoom, durationBeats: 2, intensity: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatSyncedTransition.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.durationBeats, original.durationBeats)
        XCTAssertEqual(decoded.intensity, original.intensity)
    }
}

// MARK: - BeatSyncedEffect Tests

final class ExtendedBeatSyncedEffectTests: XCTestCase {

    func testEffectTypeAllCasesCount() {
        XCTAssertEqual(BeatSyncedEffect.EffectType.allCases.count, 22)
    }

    func testTriggerModeAllCasesCount() {
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.allCases.count, 9)
    }

    func testTriggerModeRawValues() {
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.everyBeat.rawValue, "Every Beat")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.everyDownbeat.rawValue, "Every Downbeat")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.everyOtherBeat.rawValue, "Every Other Beat")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.everyBar.rawValue, "Every Bar")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.every2Bars.rawValue, "Every 2 Bars")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.every4Bars.rawValue, "Every 4 Bars")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.onCue.rawValue, "On Cue")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.continuous.rawValue, "Continuous (Synced)")
        XCTAssertEqual(BeatSyncedEffect.TriggerMode.random.rawValue, "Random (Synced)")
    }

    func testDefaultInit() {
        let e = BeatSyncedEffect()
        XCTAssertEqual(e.type, .pulse)
        XCTAssertEqual(e.triggerOn, .everyBeat)
        XCTAssertEqual(e.intensity, 1.0)
        XCTAssertEqual(e.decay, 0.5)
        XCTAssertEqual(e.phase, 0)
    }

    func testCustomInit() {
        let e = BeatSyncedEffect(type: .glitch, triggerOn: .everyBar, intensity: 0.7, decay: 0.3, phase: 0.25)
        XCTAssertEqual(e.type, .glitch)
        XCTAssertEqual(e.triggerOn, .everyBar)
        XCTAssertEqual(e.intensity, 0.7)
        XCTAssertEqual(e.decay, 0.3)
        XCTAssertEqual(e.phase, 0.25)
    }

    func testIconsAreNonEmpty() {
        for effectType in BeatSyncedEffect.EffectType.allCases {
            let e = BeatSyncedEffect(type: effectType)
            XCTAssertFalse(e.icon.isEmpty, "\(effectType.rawValue) should have an icon")
        }
    }

    func testIdentifiable() {
        let a = BeatSyncedEffect()
        let b = BeatSyncedEffect()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCodableRoundTrip() throws {
        let original = BeatSyncedEffect(type: .heartbeatPulse, triggerOn: .every2Bars, intensity: 0.9)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatSyncedEffect.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.triggerOn, original.triggerOn)
        XCTAssertEqual(decoded.intensity, original.intensity)
    }
}

// MARK: - BeatDetectionResult Tests

final class ExtendedBeatDetectionResultTests: XCTestCase {

    func testDefaultInit() {
        let r = BeatDetectionResult()
        XCTAssertEqual(r.bpm, 120)
        XCTAssertEqual(r.confidence, 0)
        XCTAssertTrue(r.beats.isEmpty)
        XCTAssertTrue(r.downbeats.isEmpty)
        XCTAssertEqual(r.timeSignature, .fourFour)
        XCTAssertEqual(r.offset, 0)
    }

    func testCustomInit() {
        let r = BeatDetectionResult(bpm: 140, confidence: 0.9, beats: [0.0, 0.43], downbeats: [0.0], offset: 0.01)
        XCTAssertEqual(r.bpm, 140)
        XCTAssertEqual(r.confidence, 0.9)
        XCTAssertEqual(r.beats.count, 2)
        XCTAssertEqual(r.downbeats.count, 1)
        XCTAssertEqual(r.offset, 0.01)
    }

    func testCodableRoundTrip() throws {
        let original = BeatDetectionResult(bpm: 128, confidence: 0.85)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeatDetectionResult.self, from: data)
        XCTAssertEqual(decoded.bpm, original.bpm)
        XCTAssertEqual(decoded.confidence, original.confidence)
    }
}

// MARK: - BPMGrid Tests

final class ExtendedBPMGridTests: XCTestCase {

    func testDefaultInit() {
        let g = BPMGrid()
        XCTAssertEqual(g.bpm, 120)
        XCTAssertEqual(g.timeSignature, .fourFour)
        XCTAssertEqual(g.offset, 0)
        XCTAssertTrue(g.tempoChanges.isEmpty)
    }

    func testSecondsPerBeat() {
        let g = BPMGrid(bpm: 120)
        XCTAssertEqual(g.secondsPerBeat(), 0.5, accuracy: 0.001)
    }

    func testSecondsPerBeatAt60BPM() {
        let g = BPMGrid(bpm: 60)
        XCTAssertEqual(g.secondsPerBeat(), 1.0, accuracy: 0.001)
    }

    func testSecondsPerBar() {
        let g = BPMGrid(bpm: 120, timeSignature: .fourFour)
        XCTAssertEqual(g.secondsPerBar(), 2.0, accuracy: 0.001)
    }

    func testSecondsPerBarThreeFour() {
        let g = BPMGrid(bpm: 120, timeSignature: .threeFour)
        XCTAssertEqual(g.secondsPerBar(), 1.5, accuracy: 0.001)
    }

    func testBpmAtNoTempoChanges() {
        let g = BPMGrid(bpm: 120)
        XCTAssertEqual(g.bpmAt(seconds: 5.0), 120)
    }

    func testSnapToGridOff() {
        let g = BPMGrid(bpm: 120)
        let time = 1.23
        XCTAssertEqual(g.snapToGrid(seconds: time, snapMode: .off), time)
    }

    func testSnapToGridBeat() {
        let g = BPMGrid(bpm: 120)
        // At 120 BPM, beats at 0, 0.5, 1.0, 1.5, ...
        let snapped = g.snapToGrid(seconds: 0.6, snapMode: .beat)
        XCTAssertEqual(snapped, 0.5, accuracy: 0.001)
    }

    func testSnapToGridBar() {
        let g = BPMGrid(bpm: 120, timeSignature: .fourFour)
        // Bars at 0, 2, 4, ...
        let snapped = g.snapToGrid(seconds: 1.8, snapMode: .bar)
        XCTAssertEqual(snapped, 2.0, accuracy: 0.001)
    }

    func testGridLinesOff() {
        let g = BPMGrid(bpm: 120)
        let lines = g.gridLines(from: 0, to: 4, snapMode: .off)
        XCTAssertTrue(lines.isEmpty)
    }

    func testGridLinesBeat() {
        let g = BPMGrid(bpm: 120)
        let lines = g.gridLines(from: 0, to: 2, snapMode: .beat)
        // Beats at 0.0, 0.5, 1.0, 1.5, 2.0
        XCTAssertEqual(lines.count, 5)
    }

    func testIsOnBeat() {
        let g = BPMGrid(bpm: 120)
        XCTAssertTrue(g.isOnBeat(0.5))
        XCTAssertTrue(g.isOnBeat(1.0))
    }

    func testIsNotOnBeat() {
        let g = BPMGrid(bpm: 120)
        XCTAssertFalse(g.isOnBeat(0.3))
    }

    func testIsOnDownbeat() {
        let g = BPMGrid(bpm: 120, timeSignature: .fourFour)
        XCTAssertTrue(g.isOnDownbeat(0.0))
        XCTAssertTrue(g.isOnDownbeat(2.0))
    }

    func testIsNotOnDownbeat() {
        let g = BPMGrid(bpm: 120, timeSignature: .fourFour)
        XCTAssertFalse(g.isOnDownbeat(0.5))
    }

    func testNearestBeat() {
        let g = BPMGrid(bpm: 120)
        XCTAssertEqual(g.nearestBeat(to: 0.6), 0.5, accuracy: 0.001)
    }

    func testNearestBar() {
        let g = BPMGrid(bpm: 120, timeSignature: .fourFour)
        XCTAssertEqual(g.nearestBar(to: 1.1), 0.0, accuracy: 0.5)
    }

    func testNextBeat() {
        let g = BPMGrid(bpm: 120)
        let next = g.nextBeat(after: 0.3)
        XCTAssertEqual(next, 0.5, accuracy: 0.001)
    }

    func testPreviousBeat() {
        let g = BPMGrid(bpm: 120)
        let prev = g.previousBeat(before: 0.7)
        XCTAssertEqual(prev, 0.5, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = BPMGrid(bpm: 140, timeSignature: .threeFour, offset: 0.1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BPMGrid.self, from: data)
        XCTAssertEqual(decoded.bpm, original.bpm)
        XCTAssertEqual(decoded.timeSignature, original.timeSignature)
        XCTAssertEqual(decoded.offset, original.offset)
    }
}

// MARK: - CurvePoint Tests

final class ExtendedCurvePointTests: XCTestCase {

    func testInit() {
        let p = CurvePoint(input: 0.5, output: 0.7)
        XCTAssertEqual(p.input, 0.5)
        XCTAssertEqual(p.output, 0.7)
    }

    func testClampingAboveOne() {
        let p = CurvePoint(input: 1.5, output: 2.0)
        XCTAssertEqual(p.input, 1.0)
        XCTAssertEqual(p.output, 1.0)
    }

    func testClampingBelowZero() {
        let p = CurvePoint(input: -0.5, output: -1.0)
        XCTAssertEqual(p.input, 0.0)
        XCTAssertEqual(p.output, 0.0)
    }

    func testEquatable() {
        let a = CurvePoint(input: 0.5, output: 0.5)
        let b = CurvePoint(input: 0.5, output: 0.5)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = CurvePoint(input: 0.3, output: 0.8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurvePoint.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ColorRange Tests

final class ExtendedColorRangeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ColorRange.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(ColorRange.red.rawValue, "red")
        XCTAssertEqual(ColorRange.orange.rawValue, "orange")
        XCTAssertEqual(ColorRange.yellow.rawValue, "yellow")
        XCTAssertEqual(ColorRange.green.rawValue, "green")
        XCTAssertEqual(ColorRange.cyan.rawValue, "cyan")
        XCTAssertEqual(ColorRange.blue.rawValue, "blue")
        XCTAssertEqual(ColorRange.purple.rawValue, "purple")
        XCTAssertEqual(ColorRange.magenta.rawValue, "magenta")
    }

    func testCenterHueValues() {
        XCTAssertEqual(ColorRange.red.centerHue, 0)
        XCTAssertEqual(ColorRange.orange.centerHue, 30)
        XCTAssertEqual(ColorRange.yellow.centerHue, 60)
        XCTAssertEqual(ColorRange.green.centerHue, 120)
        XCTAssertEqual(ColorRange.cyan.centerHue, 180)
        XCTAssertEqual(ColorRange.blue.centerHue, 240)
        XCTAssertEqual(ColorRange.purple.centerHue, 270)
        XCTAssertEqual(ColorRange.magenta.centerHue, 300)
    }

    func testHueWidth() {
        for range in ColorRange.allCases {
            XCTAssertEqual(range.hueWidth, 22.5)
        }
    }

    func testCodableRoundTrip() throws {
        for range in ColorRange.allCases {
            let data = try JSONEncoder().encode(range)
            let decoded = try JSONDecoder().decode(ColorRange.self, from: data)
            XCTAssertEqual(range, decoded)
        }
    }

    func testCenterHueIncreases() {
        let ordered: [ColorRange] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .magenta]
        for i in 1..<ordered.count {
            XCTAssertGreaterThan(ordered[i].centerHue, ordered[i - 1].centerHue)
        }
    }
}

// MARK: - HSLValues Tests

final class ExtendedHSLValuesTests: XCTestCase {

    func testDefaultInit() {
        let v = HSLValues()
        XCTAssertEqual(v.hueShift, 0)
        XCTAssertEqual(v.saturation, 0)
        XCTAssertEqual(v.luminance, 0)
    }

    func testIsNeutralDefault() {
        XCTAssertTrue(HSLValues().isNeutral)
    }

    func testIsNotNeutral() {
        let v = HSLValues(hueShift: 10)
        XCTAssertFalse(v.isNeutral)
    }

    func testClampingHueShift() {
        let v = HSLValues(hueShift: 200)
        XCTAssertEqual(v.hueShift, 180)
    }

    func testClampingSaturation() {
        let v = HSLValues(saturation: -5)
        XCTAssertEqual(v.saturation, -1)
    }

    func testClampingLuminance() {
        let v = HSLValues(luminance: 3)
        XCTAssertEqual(v.luminance, 1)
    }

    func testEquatable() {
        let a = HSLValues(hueShift: 10, saturation: 0.5, luminance: -0.3)
        let b = HSLValues(hueShift: 10, saturation: 0.5, luminance: -0.3)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = HSLValues(hueShift: 45, saturation: 0.3, luminance: -0.2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HSLValues.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - WipeDirection Tests

final class ExtendedWipeDirectionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(WipeDirection.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(WipeDirection.left.rawValue, "left")
        XCTAssertEqual(WipeDirection.right.rawValue, "right")
        XCTAssertEqual(WipeDirection.up.rawValue, "up")
        XCTAssertEqual(WipeDirection.down.rawValue, "down")
        XCTAssertEqual(WipeDirection.diagonal.rawValue, "diagonal")
    }

    func testCodableRoundTrip() throws {
        for dir in WipeDirection.allCases {
            let data = try JSONEncoder().encode(dir)
            let decoded = try JSONDecoder().decode(WipeDirection.self, from: data)
            XCTAssertEqual(dir, decoded)
        }
    }
}

// MARK: - TransitionEasing Tests

final class ExtendedTransitionEasingTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TransitionEasing.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TransitionEasing.linear.rawValue, "linear")
        XCTAssertEqual(TransitionEasing.easeIn.rawValue, "easeIn")
        XCTAssertEqual(TransitionEasing.easeOut.rawValue, "easeOut")
        XCTAssertEqual(TransitionEasing.easeInOut.rawValue, "easeInOut")
        XCTAssertEqual(TransitionEasing.bounce.rawValue, "bounce")
    }

    func testLinearEvaluateEndpoints() {
        XCTAssertEqual(TransitionEasing.linear.evaluate(0), 0, accuracy: 0.001)
        XCTAssertEqual(TransitionEasing.linear.evaluate(1), 1, accuracy: 0.001)
    }

    func testLinearEvaluateMidpoint() {
        XCTAssertEqual(TransitionEasing.linear.evaluate(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseInStartsSlow() {
        let val = TransitionEasing.easeIn.evaluate(0.5)
        XCTAssertLessThan(val, 0.5)
    }

    func testEaseOutStartsFast() {
        let val = TransitionEasing.easeOut.evaluate(0.5)
        XCTAssertGreaterThan(val, 0.5)
    }

    func testEaseInOutEndpoints() {
        XCTAssertEqual(TransitionEasing.easeInOut.evaluate(0), 0, accuracy: 0.001)
        XCTAssertEqual(TransitionEasing.easeInOut.evaluate(1), 1, accuracy: 0.001)
    }

    func testBounceEndpoints() {
        XCTAssertEqual(TransitionEasing.bounce.evaluate(0), 0, accuracy: 0.01)
        XCTAssertEqual(TransitionEasing.bounce.evaluate(1), 1, accuracy: 0.01)
    }

    func testEvaluateClamps() {
        // Values outside 0-1 should be clamped
        let val = TransitionEasing.linear.evaluate(-0.5)
        XCTAssertEqual(val, 0, accuracy: 0.001)
        let val2 = TransitionEasing.linear.evaluate(1.5)
        XCTAssertEqual(val2, 1, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        for easing in TransitionEasing.allCases {
            let data = try JSONEncoder().encode(easing)
            let decoded = try JSONDecoder().decode(TransitionEasing.self, from: data)
            XCTAssertEqual(easing, decoded)
        }
    }
}

// MARK: - GradeTransitionType Tests

final class ExtendedGradeTransitionTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(GradeTransitionType.allCases.count, 21)
    }

    func testDisplayNamesAreNonEmpty() {
        for t in GradeTransitionType.allCases {
            XCTAssertFalse(t.displayName.isEmpty, "\(t.rawValue) should have a display name")
        }
    }

    func testSpecificDisplayNames() {
        XCTAssertEqual(GradeTransitionType.cut.displayName, "Cut")
        XCTAssertEqual(GradeTransitionType.crossDissolve.displayName, "Cross Dissolve")
        XCTAssertEqual(GradeTransitionType.dipToBlack.displayName, "Dip to Black")
        XCTAssertEqual(GradeTransitionType.beatSync.displayName, "Beat Sync")
    }

    func testCutDoesNotRequireTwoSources() {
        XCTAssertFalse(GradeTransitionType.cut.requiresTwoSources)
    }

    func testNonCutRequiresTwoSources() {
        for t in GradeTransitionType.allCases where t != .cut {
            XCTAssertTrue(t.requiresTwoSources, "\(t.rawValue) should require two sources")
        }
    }

    func testCutDefaultDurationIsZero() {
        XCTAssertEqual(GradeTransitionType.cut.defaultDuration, 0)
    }

    func testDefaultDurationsAreNonNegative() {
        for t in GradeTransitionType.allCases {
            XCTAssertGreaterThanOrEqual(t.defaultDuration, 0)
        }
    }

    func testCodableRoundTrip() throws {
        for t in GradeTransitionType.allCases {
            let data = try JSONEncoder().encode(t)
            let decoded = try JSONDecoder().decode(GradeTransitionType.self, from: data)
            XCTAssertEqual(t, decoded)
        }
    }
}

// MARK: - ProTransition Tests

final class ExtendedProTransitionTests: XCTestCase {

    func testDefaultInit() {
        let t = ProTransition()
        XCTAssertEqual(t.type, .crossDissolve)
        XCTAssertEqual(t.easing, .easeInOut)
        XCTAssertTrue(t.parameters.isEmpty)
    }

    func testDefaultDurationUsesType() {
        let t = ProTransition(type: .cut)
        XCTAssertEqual(t.duration, 0)
    }

    func testCustomDuration() {
        let t = ProTransition(type: .crossDissolve, duration: 2.5)
        XCTAssertEqual(t.duration, 2.5)
    }

    func testMixAtZero() {
        let t = ProTransition(easing: .linear)
        XCTAssertEqual(t.mix(at: 0), 0, accuracy: 0.001)
    }

    func testMixAtOne() {
        let t = ProTransition(easing: .linear)
        XCTAssertEqual(t.mix(at: 1), 1, accuracy: 0.001)
    }

    func testMixUsesEasing() {
        let t = ProTransition(easing: .easeIn)
        let mid = t.mix(at: 0.5)
        XCTAssertLessThan(mid, 0.5) // easeIn starts slow
    }

    func testEquatable() {
        let a = ProTransition(type: .flash, duration: 0.15, easing: .linear)
        let b = ProTransition(type: .flash, duration: 0.15, easing: .linear)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = ProTransition(type: .glitch, duration: 0.3, easing: .bounce, parameters: ["amount": 0.5])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProTransition.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ScopeType Tests

final class ExtendedScopeTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ScopeType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(ScopeType.histogram.rawValue, "histogram")
        XCTAssertEqual(ScopeType.waveform.rawValue, "waveform")
        XCTAssertEqual(ScopeType.vectorscope.rawValue, "vectorscope")
        XCTAssertEqual(ScopeType.rgbParade.rawValue, "rgbParade")
        XCTAssertEqual(ScopeType.falseColor.rawValue, "falseColor")
    }

    func testDisplayNames() {
        XCTAssertEqual(ScopeType.histogram.displayName, "Histogram")
        XCTAssertEqual(ScopeType.waveform.displayName, "Waveform")
        XCTAssertEqual(ScopeType.vectorscope.displayName, "Vectorscope")
        XCTAssertEqual(ScopeType.rgbParade.displayName, "RGB Parade")
        XCTAssertEqual(ScopeType.falseColor.displayName, "False Color")
    }

    func testCodableRoundTrip() throws {
        for scope in ScopeType.allCases {
            let data = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(ScopeType.self, from: data)
            XCTAssertEqual(scope, decoded)
        }
    }
}

// MARK: - ColorWheels Tests

final class ExtendedColorWheelsTests: XCTestCase {

    func testNeutralInit() {
        let cw = ColorWheels()
        XCTAssertTrue(cw.isNeutral)
    }

    func testNeutralStatic() {
        let cw = ColorWheels.neutral
        XCTAssertTrue(cw.isNeutral)
    }

    func testNotNeutralWithExposure() {
        let cw = ColorWheels(exposure: 1.0)
        XCTAssertFalse(cw.isNeutral)
    }

    func testNotNeutralWithSaturation() {
        let cw = ColorWheels(saturation: 1.5)
        XCTAssertFalse(cw.isNeutral)
    }

    func testNotNeutralWithTemperature() {
        let cw = ColorWheels(temperature: 50)
        XCTAssertFalse(cw.isNeutral)
    }

    func testExposureClamping() {
        let cw = ColorWheels(exposure: 10)
        XCTAssertEqual(cw.exposure, 5)
    }

    func testContrastClamping() {
        let cw = ColorWheels(contrast: -200)
        XCTAssertEqual(cw.contrast, -100)
    }

    func testSaturationClamping() {
        let cw = ColorWheels(saturation: 5)
        XCTAssertEqual(cw.saturation, 2)
    }

    func testDefaultSaturationIsOne() {
        let cw = ColorWheels()
        XCTAssertEqual(cw.saturation, 1)
    }

    func testEquatable() {
        let a = ColorWheels(exposure: 1.0, contrast: 20)
        let b = ColorWheels(exposure: 1.0, contrast: 20)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = ColorWheels(temperature: 30, tint: -10, saturation: 1.2, exposure: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorWheels.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CurvesEditor Tests

final class ExtendedCurvesEditorTests: XCTestCase {

    func testIdentityCurve() {
        let identity = CurvesEditor.identityCurve
        XCTAssertEqual(identity.count, 2)
        XCTAssertEqual(identity[0].input, 0)
        XCTAssertEqual(identity[0].output, 0)
        XCTAssertEqual(identity[1].input, 1)
        XCTAssertEqual(identity[1].output, 1)
    }

    func testDefaultIsNeutral() {
        let c = CurvesEditor()
        XCTAssertTrue(c.isNeutral)
    }

    func testNeutralStatic() {
        XCTAssertTrue(CurvesEditor.neutral.isNeutral)
    }

    func testNotNeutralWithCustomCurve() {
        let c = CurvesEditor(masterCurve: [
            CurvePoint(input: 0, output: 0),
            CurvePoint(input: 0.5, output: 0.8),
            CurvePoint(input: 1, output: 1)
        ])
        XCTAssertFalse(c.isNeutral)
    }

    func testEvaluateIdentityAtMidpoint() {
        let c = CurvesEditor()
        let result = c.evaluate(curve: CurvesEditor.identityCurve, at: 0.5)
        XCTAssertEqual(result, 0.5, accuracy: 0.05)
    }

    func testEvaluateAtEndpoints() {
        let c = CurvesEditor()
        XCTAssertEqual(c.evaluate(curve: CurvesEditor.identityCurve, at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(c.evaluate(curve: CurvesEditor.identityCurve, at: 1), 1, accuracy: 0.001)
    }

    func testEvaluateClamps() {
        let c = CurvesEditor()
        let result = c.evaluate(curve: CurvesEditor.identityCurve, at: -0.5)
        XCTAssertEqual(result, 0, accuracy: 0.001)
    }

    func testEquatable() {
        let a = CurvesEditor()
        let b = CurvesEditor()
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = CurvesEditor()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurvesEditor.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - HSLAdjustment Tests

final class HSLAdjustmentTests: XCTestCase {

    func testDefaultInit() {
        let adj = HSLAdjustment()
        XCTAssertEqual(adj.adjustments.count, ColorRange.allCases.count)
    }

    func testDefaultIsNeutral() {
        XCTAssertTrue(HSLAdjustment().isNeutral)
    }

    func testNeutralStatic() {
        XCTAssertTrue(HSLAdjustment.neutral.isNeutral)
    }

    func testNotNeutralAfterModification() {
        var adj = HSLAdjustment()
        adj.setValues(HSLValues(hueShift: 10), for: .red)
        XCTAssertFalse(adj.isNeutral)
    }

    func testValuesForRange() {
        let adj = HSLAdjustment()
        let vals = adj.values(for: .green)
        XCTAssertTrue(vals.isNeutral)
    }

    func testSetValuesForRange() {
        var adj = HSLAdjustment()
        let custom = HSLValues(hueShift: 30, saturation: 0.5, luminance: -0.2)
        adj.setValues(custom, for: .blue)
        XCTAssertEqual(adj.values(for: .blue), custom)
    }

    func testCodableRoundTrip() throws {
        var original = HSLAdjustment()
        original.setValues(HSLValues(hueShift: 15), for: .orange)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HSLAdjustment.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - LUT3D Tests

final class LUT3DTests: XCTestCase {

    func testInitAndSize() {
        let size = 2
        let data = (0..<(size * size * size)).map { i in
            SIMD3<Float>(Float(i) / 7.0, Float(i) / 7.0, Float(i) / 7.0)
        }
        let lut = LUT3D(size: size, data: data)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.data.count, 8)
    }

    func testLookupIdentity() {
        // Identity LUT: output == input
        let size = 2
        var data = [SIMD3<Float>]()
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    data.append(SIMD3<Float>(Float(r), Float(g), Float(b)))
                }
            }
        }
        let lut = LUT3D(size: size, data: data)
        let result = lut.lookup(SIMD3<Float>(0.5, 0.5, 0.5))
        XCTAssertEqual(result.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(result.y, 0.5, accuracy: 0.01)
        XCTAssertEqual(result.z, 0.5, accuracy: 0.01)
    }

    func testLookupClamps() {
        let size = 2
        var data = [SIMD3<Float>]()
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    data.append(SIMD3<Float>(Float(r), Float(g), Float(b)))
                }
            }
        }
        let lut = LUT3D(size: size, data: data)
        // Should not crash with values outside 0-1
        let result = lut.lookup(SIMD3<Float>(-0.5, 1.5, 0.5))
        XCTAssertGreaterThanOrEqual(result.x, 0)
    }
}

// MARK: - LUTParseError Tests

final class LUTParseErrorTests: XCTestCase {

    func testFileNotFoundDescription() {
        let error = LUTParseError.fileNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue((error.errorDescription ?? "").contains("not found"))
    }

    func testInvalidFormatDescription() {
        let error = LUTParseError.invalidFormat("bad header")
        XCTAssertTrue((error.errorDescription ?? "").contains("bad header"))
    }

    func testSizeMismatchDescription() {
        let error = LUTParseError.sizeMismatch(expected: 17, actual: 100)
        XCTAssertTrue((error.errorDescription ?? "").contains("17"))
        XCTAssertTrue((error.errorDescription ?? "").contains("100"))
    }

    func testInvalidValueDescription() {
        let error = LUTParseError.invalidValue(line: 42)
        XCTAssertTrue((error.errorDescription ?? "").contains("42"))
    }
}

// MARK: - LUTManager Tests

final class LUTManagerTests: XCTestCase {

    func testBuiltInLUTsNonEmpty() {
        let manager = LUTManager()
        XCTAssertFalse(manager.builtInLUTs.isEmpty)
    }

    func testBuiltInLUTNamesExist() {
        let manager = LUTManager()
        XCTAssertNotNil(manager.builtInLUTs["Film Print"])
        XCTAssertNotNil(manager.builtInLUTs["Bleach Bypass"])
        XCTAssertNotNil(manager.builtInLUTs["Cross Process"])
        XCTAssertNotNil(manager.builtInLUTs["Teal & Orange"])
    }

    func testBuiltInLUTSize() {
        let manager = LUTManager()
        if let filmPrint = manager.builtInLUTs["Film Print"] {
            XCTAssertEqual(filmPrint.size, 17)
            XCTAssertEqual(filmPrint.data.count, 17 * 17 * 17)
        }
    }

    func testLoadCubeValidFormat() throws {
        let manager = LUTManager()
        let cubeContent = """
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """
        let lut = try manager.loadCube(from: cubeContent)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.data.count, 8)
    }

    func testLoadCubeMissingSize() {
        let manager = LUTManager()
        let cubeContent = "0.0 0.0 0.0"
        XCTAssertThrowsError(try manager.loadCube(from: cubeContent))
    }

    func testLoadCubeSizeMismatch() {
        let manager = LUTManager()
        let cubeContent = """
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 0.0 0.0
        """
        XCTAssertThrowsError(try manager.loadCube(from: cubeContent))
    }
}

// MARK: - ScopeData Tests

final class ScopeDataTests: XCTestCase {

    func testDefaultInit() {
        let sd = ScopeData()
        XCTAssertEqual(sd.histogram.count, 256)
        XCTAssertEqual(sd.vectorscope.count, 256)
    }

    func testHistogramDefaultIsZero() {
        let sd = ScopeData()
        XCTAssertTrue(sd.histogram.allSatisfy { $0 == 0 })
    }
}

// MARK: - VideoScopes Tests

final class VideoScopesTests: XCTestCase {

    func testDefaultInit() {
        let vs = VideoScopes()
        XCTAssertFalse(vs.showScopes)
        XCTAssertTrue(vs.activeScopes.contains(.histogram))
        XCTAssertTrue(vs.activeScopes.contains(.waveform))
    }

    func testCustomInit() {
        let vs = VideoScopes(showScopes: true, activeScopes: [.vectorscope])
        XCTAssertTrue(vs.showScopes)
        XCTAssertTrue(vs.activeScopes.contains(.vectorscope))
        XCTAssertFalse(vs.activeScopes.contains(.histogram))
    }
}

// MARK: - ColorGrade Tests

final class ColorGradeTests: XCTestCase {

    func testDefaultInit() {
        let g = ColorGrade()
        XCTAssertEqual(g.name, "Untitled Grade")
        XCTAssertTrue(g.isEnabled)
        XCTAssertNil(g.lutName)
        XCTAssertEqual(g.lutIntensity, 1.0)
    }

    func testDefaultIsNeutral() {
        XCTAssertTrue(ColorGrade().isNeutral)
    }

    func testNotNeutralWithLUT() {
        let g = ColorGrade(lutName: "Film Print")
        XCTAssertFalse(g.isNeutral)
    }

    func testNotNeutralWithModifiedWheels() {
        let g = ColorGrade(colorWheels: ColorWheels(exposure: 1.0))
        XCTAssertFalse(g.isNeutral)
    }

    func testIdentifiable() {
        let a = ColorGrade()
        let b = ColorGrade()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testEquatable() {
        let id = UUID()
        let date = Date()
        let a = ColorGrade(id: id, name: "Test", date: date)
        let b = ColorGrade(id: id, name: "Test", date: date)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let original = ColorGrade(name: "Cinema Look", lutName: "Teal & Orange", lutIntensity: 0.8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorGrade.self, from: data)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.lutName, decoded.lutName)
        XCTAssertEqual(original.lutIntensity, decoded.lutIntensity)
    }
}

// MARK: - KeyframeProperty Tests

final class ExtendedKeyframePropertyTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(KeyframeProperty.opacity.rawValue, "Opacity")
        XCTAssertEqual(KeyframeProperty.scale.rawValue, "Scale")
        XCTAssertEqual(KeyframeProperty.rotation.rawValue, "Rotation")
        XCTAssertEqual(KeyframeProperty.positionX.rawValue, "Position X")
        XCTAssertEqual(KeyframeProperty.positionY.rawValue, "Position Y")
        XCTAssertEqual(KeyframeProperty.volume.rawValue, "Volume")
    }
}

// MARK: - MarkerColor Tests

final class ExtendedMarkerColorTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(MarkerColor.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(MarkerColor.red.rawValue, "Red")
        XCTAssertEqual(MarkerColor.orange.rawValue, "Orange")
        XCTAssertEqual(MarkerColor.yellow.rawValue, "Yellow")
        XCTAssertEqual(MarkerColor.green.rawValue, "Green")
        XCTAssertEqual(MarkerColor.blue.rawValue, "Blue")
        XCTAssertEqual(MarkerColor.purple.rawValue, "Purple")
    }
}

// MARK: - TextPreset Tests

final class ExtendedTextPresetTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TextPreset.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(TextPreset.title.rawValue, "Title")
        XCTAssertEqual(TextPreset.subtitle.rawValue, "Subtitle")
        XCTAssertEqual(TextPreset.lowerThird.rawValue, "Lower Third")
        XCTAssertEqual(TextPreset.caption.rawValue, "Caption")
        XCTAssertEqual(TextPreset.endCredits.rawValue, "End Credits")
        XCTAssertEqual(TextPreset.callout.rawValue, "Callout")
        XCTAssertEqual(TextPreset.watermark.rawValue, "Watermark")
    }

    func testTitlePresetCreatesOverlay() {
        let overlay = TextPreset.title.createOverlay(
            text: "Hello",
            at: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        XCTAssertEqual(overlay.text, "Hello")
        XCTAssertNotNil(overlay.animation)
    }

    func testSubtitlePresetCreatesOverlay() {
        let overlay = TextPreset.subtitle.createOverlay(
            text: "Sub",
            at: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        XCTAssertEqual(overlay.text, "Sub")
    }

    func testLowerThirdPresetPosition() {
        let overlay = TextPreset.lowerThird.createOverlay(
            text: "Name",
            at: .zero,
            duration: CMTime(seconds: 4, preferredTimescale: 600)
        )
        XCTAssertEqual(overlay.position.y, 0.85, accuracy: 0.01)
    }

    func testCaptionHasNoAnimation() {
        let overlay = TextPreset.caption.createOverlay(
            text: "Caption",
            at: .zero,
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )
        XCTAssertNil(overlay.animation)
    }

    func testWatermarkDurationIsLong() {
        let overlay = TextPreset.watermark.createOverlay(
            text: "Logo",
            at: .zero,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )
        // Watermark overrides duration to all-day
        XCTAssertGreaterThan(overlay.duration.seconds, 3600)
    }

    func testAllPresetsCreateValidOverlays() {
        let duration = CMTime(seconds: 5, preferredTimescale: 600)
        for preset in TextPreset.allCases {
            let overlay = preset.createOverlay(text: "Test", at: .zero, duration: duration)
            XCTAssertEqual(overlay.text, "Test")
        }
    }
}

// MARK: - VideoEditingError Tests

final class ExtendedVideoEditingErrorTests: XCTestCase {

    func testCompositionCreationFailedDescription() {
        let error = VideoEditingError.compositionCreationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue((error.errorDescription ?? "").contains("composition"))
    }

    func testClipNotFoundDescription() {
        let error = VideoEditingError.clipNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue((error.errorDescription ?? "").contains("not found"))
    }

    func testInvalidTimeRangeDescription() {
        let error = VideoEditingError.invalidTimeRange
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue((error.errorDescription ?? "").contains("time range"))
    }
}

#endif
