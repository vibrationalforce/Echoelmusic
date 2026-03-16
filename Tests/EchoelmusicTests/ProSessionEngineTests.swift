#if canImport(AVFoundation)
// ProSessionEngineTests.swift
// Echoelmusic — Test Coverage: ProSessionEngine Types
//
// Tests for MIDINoteEvent, PatternStep, WarpMarker, ClipType, ClipState,
// ClipColor, LaunchMode, LaunchQuantize, FollowActionType, FollowAction,
// WarpMode, and SessionClip.

import XCTest
@testable import Echoelmusic

// MARK: - MIDINoteEvent Tests

final class MIDINoteEventTests: XCTestCase {

    func testMIDINoteEvent_InitWithDefaults_SetsCorrectValues() {
        let event = MIDINoteEvent(note: 60, startBeat: 0.0)
        XCTAssertEqual(event.note, 60)
        XCTAssertEqual(event.velocity, 100, "Default velocity should be 100")
        XCTAssertEqual(event.startBeat, 0.0)
        XCTAssertEqual(event.duration, 0.25, "Default duration should be 0.25 beats")
        XCTAssertEqual(event.channel, 0, "Default channel should be 0")
    }

    func testMIDINoteEvent_InitWithAllParameters_SetsCorrectValues() {
        let event = MIDINoteEvent(
            note: 127,
            velocity: 64,
            startBeat: 2.5,
            duration: 1.0,
            channel: 15
        )
        XCTAssertEqual(event.note, 127)
        XCTAssertEqual(event.velocity, 64)
        XCTAssertEqual(event.startBeat, 2.5)
        XCTAssertEqual(event.duration, 1.0)
        XCTAssertEqual(event.channel, 15)
    }

    func testMIDINoteEvent_Identifiable_HasUniqueID() {
        let event1 = MIDINoteEvent(note: 60, startBeat: 0.0)
        let event2 = MIDINoteEvent(note: 60, startBeat: 0.0)
        XCTAssertNotEqual(event1.id, event2.id, "Each event should have a unique ID")
    }

    func testMIDINoteEvent_Equatable_SameFieldsButDifferentID() {
        let id = UUID()
        let event1 = MIDINoteEvent(id: id, note: 60, velocity: 100, startBeat: 0.0, duration: 0.25, channel: 0)
        let event2 = MIDINoteEvent(id: id, note: 60, velocity: 100, startBeat: 0.0, duration: 0.25, channel: 0)
        XCTAssertEqual(event1, event2)
    }

    func testMIDINoteEvent_Equatable_DifferentNotes() {
        let id = UUID()
        let event1 = MIDINoteEvent(id: id, note: 60, startBeat: 0.0)
        let event2 = MIDINoteEvent(id: id, note: 72, startBeat: 0.0)
        XCTAssertNotEqual(event1, event2)
    }

    func testMIDINoteEvent_Equatable_DifferentVelocity() {
        let id = UUID()
        let event1 = MIDINoteEvent(id: id, note: 60, velocity: 100, startBeat: 0.0)
        let event2 = MIDINoteEvent(id: id, note: 60, velocity: 50, startBeat: 0.0)
        XCTAssertNotEqual(event1, event2)
    }

    func testMIDINoteEvent_Equatable_DifferentStartBeat() {
        let id = UUID()
        let event1 = MIDINoteEvent(id: id, note: 60, startBeat: 0.0)
        let event2 = MIDINoteEvent(id: id, note: 60, startBeat: 1.0)
        XCTAssertNotEqual(event1, event2)
    }

    func testMIDINoteEvent_CodableRoundTrip_PreservesAllFields() throws {
        let original = MIDINoteEvent(
            note: 64,
            velocity: 80,
            startBeat: 1.5,
            duration: 0.5,
            channel: 9
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MIDINoteEvent.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testMIDINoteEvent_CodableRoundTrip_PreservesID() throws {
        let original = MIDINoteEvent(note: 48, startBeat: 0.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MIDINoteEvent.self, from: encoded)
        XCTAssertEqual(original.id, decoded.id)
    }

    func testMIDINoteEvent_BoundaryNoteValues() {
        let low = MIDINoteEvent(note: 0, startBeat: 0.0)
        XCTAssertEqual(low.note, 0)
        let high = MIDINoteEvent(note: 127, startBeat: 0.0)
        XCTAssertEqual(high.note, 127)
    }

    func testMIDINoteEvent_BoundaryVelocityValues() {
        let silent = MIDINoteEvent(note: 60, velocity: 0, startBeat: 0.0)
        XCTAssertEqual(silent.velocity, 0)
        let max = MIDINoteEvent(note: 60, velocity: 127, startBeat: 0.0)
        XCTAssertEqual(max.velocity, 127)
    }

    func testMIDINoteEvent_BoundaryChannelValues() {
        let ch0 = MIDINoteEvent(note: 60, startBeat: 0.0, channel: 0)
        XCTAssertEqual(ch0.channel, 0)
        let ch15 = MIDINoteEvent(note: 60, startBeat: 0.0, channel: 15)
        XCTAssertEqual(ch15.channel, 15)
    }

    func testMIDINoteEvent_NegativeStartBeat_Accepted() {
        let event = MIDINoteEvent(note: 60, startBeat: -1.0)
        XCTAssertEqual(event.startBeat, -1.0)
    }

    func testMIDINoteEvent_ZeroDuration_Accepted() {
        let event = MIDINoteEvent(note: 60, startBeat: 0.0, duration: 0.0)
        XCTAssertEqual(event.duration, 0.0)
    }
}

// MARK: - PatternStep Tests

final class PatternStepTests: XCTestCase {

    func testPatternStep_InitWithDefaults_SetsCorrectValues() {
        let step = PatternStep(stepIndex: 0)
        XCTAssertEqual(step.stepIndex, 0)
        XCTAssertFalse(step.isActive, "Default isActive should be false")
        XCTAssertEqual(step.velocity, 0.8, accuracy: 0.001, "Default velocity should be 0.8")
        XCTAssertEqual(step.pan, 0.0, accuracy: 0.001, "Default pan should be 0.0")
        XCTAssertEqual(step.pitch, 0.0, accuracy: 0.001, "Default pitch should be 0.0")
        XCTAssertEqual(step.gate, 0.75, accuracy: 0.001, "Default gate should be 0.75")
        XCTAssertEqual(step.probability, 1.0, accuracy: 0.001, "Default probability should be 1.0")
        XCTAssertFalse(step.slide, "Default slide should be false")
    }

    func testPatternStep_InitWithAllParameters_SetsCorrectValues() {
        let step = PatternStep(
            stepIndex: 7,
            isActive: true,
            velocity: 0.5,
            pan: -0.5,
            pitch: 12.0,
            gate: 0.5,
            probability: 0.75,
            slide: true
        )
        XCTAssertEqual(step.stepIndex, 7)
        XCTAssertTrue(step.isActive)
        XCTAssertEqual(step.velocity, 0.5, accuracy: 0.001)
        XCTAssertEqual(step.pan, -0.5, accuracy: 0.001)
        XCTAssertEqual(step.pitch, 12.0, accuracy: 0.001)
        XCTAssertEqual(step.gate, 0.5, accuracy: 0.001)
        XCTAssertEqual(step.probability, 0.75, accuracy: 0.001)
        XCTAssertTrue(step.slide)
    }

    func testPatternStep_VelocityClamping_ClipsToRange() {
        let tooHigh = PatternStep(stepIndex: 0, velocity: 2.0)
        XCTAssertEqual(tooHigh.velocity, 1.0, accuracy: 0.001, "Velocity above 1.0 should be clamped to 1.0")

        let tooLow = PatternStep(stepIndex: 0, velocity: -0.5)
        XCTAssertEqual(tooLow.velocity, 0.0, accuracy: 0.001, "Velocity below 0.0 should be clamped to 0.0")
    }

    func testPatternStep_VelocityClamping_BoundaryValues() {
        let atMin = PatternStep(stepIndex: 0, velocity: 0.0)
        XCTAssertEqual(atMin.velocity, 0.0, accuracy: 0.001)

        let atMax = PatternStep(stepIndex: 0, velocity: 1.0)
        XCTAssertEqual(atMax.velocity, 1.0, accuracy: 0.001)
    }

    func testPatternStep_PanClamping_ClipsToRange() {
        let tooRight = PatternStep(stepIndex: 0, pan: 5.0)
        XCTAssertEqual(tooRight.pan, 1.0, accuracy: 0.001, "Pan above 1.0 should be clamped to 1.0")

        let tooLeft = PatternStep(stepIndex: 0, pan: -5.0)
        XCTAssertEqual(tooLeft.pan, -1.0, accuracy: 0.001, "Pan below -1.0 should be clamped to -1.0")
    }

    func testPatternStep_PanClamping_BoundaryValues() {
        let left = PatternStep(stepIndex: 0, pan: -1.0)
        XCTAssertEqual(left.pan, -1.0, accuracy: 0.001)

        let center = PatternStep(stepIndex: 0, pan: 0.0)
        XCTAssertEqual(center.pan, 0.0, accuracy: 0.001)

        let right = PatternStep(stepIndex: 0, pan: 1.0)
        XCTAssertEqual(right.pan, 1.0, accuracy: 0.001)
    }

    func testPatternStep_PitchClamping_ClipsToRange() {
        let tooHigh = PatternStep(stepIndex: 0, pitch: 48.0)
        XCTAssertEqual(tooHigh.pitch, 24.0, accuracy: 0.001, "Pitch above 24 should be clamped to 24")

        let tooLow = PatternStep(stepIndex: 0, pitch: -48.0)
        XCTAssertEqual(tooLow.pitch, -24.0, accuracy: 0.001, "Pitch below -24 should be clamped to -24")
    }

    func testPatternStep_PitchClamping_BoundaryValues() {
        let minPitch = PatternStep(stepIndex: 0, pitch: -24.0)
        XCTAssertEqual(minPitch.pitch, -24.0, accuracy: 0.001)

        let maxPitch = PatternStep(stepIndex: 0, pitch: 24.0)
        XCTAssertEqual(maxPitch.pitch, 24.0, accuracy: 0.001)
    }

    func testPatternStep_GateClamping_ClipsToRange() {
        let tooHigh = PatternStep(stepIndex: 0, gate: 1.5)
        XCTAssertEqual(tooHigh.gate, 1.0, accuracy: 0.001, "Gate above 1.0 should be clamped to 1.0")

        let tooLow = PatternStep(stepIndex: 0, gate: -0.5)
        XCTAssertEqual(tooLow.gate, 0.0, accuracy: 0.001, "Gate below 0.0 should be clamped to 0.0")
    }

    func testPatternStep_ProbabilityClamping_ClipsToRange() {
        let tooHigh = PatternStep(stepIndex: 0, probability: 2.0)
        XCTAssertEqual(tooHigh.probability, 1.0, accuracy: 0.001, "Probability above 1.0 should be clamped to 1.0")

        let tooLow = PatternStep(stepIndex: 0, probability: -1.0)
        XCTAssertEqual(tooLow.probability, 0.0, accuracy: 0.001, "Probability below 0.0 should be clamped to 0.0")
    }

    func testPatternStep_ProbabilityClamping_BoundaryValues() {
        let zero = PatternStep(stepIndex: 0, probability: 0.0)
        XCTAssertEqual(zero.probability, 0.0, accuracy: 0.001)

        let one = PatternStep(stepIndex: 0, probability: 1.0)
        XCTAssertEqual(one.probability, 1.0, accuracy: 0.001)
    }

    func testPatternStep_Identifiable_HasUniqueID() {
        let step1 = PatternStep(stepIndex: 0)
        let step2 = PatternStep(stepIndex: 0)
        XCTAssertNotEqual(step1.id, step2.id)
    }

    func testPatternStep_Equatable_SameFieldsSameID() {
        let id = UUID()
        let step1 = PatternStep(id: id, stepIndex: 3, isActive: true, velocity: 0.5, pan: 0.0, pitch: 0.0, gate: 0.75, probability: 1.0, slide: false)
        let step2 = PatternStep(id: id, stepIndex: 3, isActive: true, velocity: 0.5, pan: 0.0, pitch: 0.0, gate: 0.75, probability: 1.0, slide: false)
        XCTAssertEqual(step1, step2)
    }

    func testPatternStep_CodableRoundTrip_PreservesAllFields() throws {
        let original = PatternStep(
            stepIndex: 5,
            isActive: true,
            velocity: 0.6,
            pan: -0.3,
            pitch: 7.0,
            gate: 0.5,
            probability: 0.9,
            slide: true
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PatternStep.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testPatternStep_CodableRoundTrip_PreservesID() throws {
        let original = PatternStep(stepIndex: 0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PatternStep.self, from: encoded)
        XCTAssertEqual(original.id, decoded.id)
    }

    func testPatternStep_CodableRoundTrip_ClampedValues() throws {
        let original = PatternStep(stepIndex: 0, velocity: 0.8, pan: 0.0, pitch: 0.0, gate: 0.75, probability: 1.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PatternStep.self, from: encoded)
        XCTAssertEqual(decoded.velocity, 0.8, accuracy: 0.001)
        XCTAssertEqual(decoded.gate, 0.75, accuracy: 0.001)
    }

    func testPatternStep_MultipleClampedFields_AllClamped() {
        let step = PatternStep(
            stepIndex: 0,
            velocity: 999.0,
            pan: 999.0,
            pitch: 999.0,
            gate: 999.0,
            probability: 999.0
        )
        XCTAssertEqual(step.velocity, 1.0, accuracy: 0.001)
        XCTAssertEqual(step.pan, 1.0, accuracy: 0.001)
        XCTAssertEqual(step.pitch, 24.0, accuracy: 0.001)
        XCTAssertEqual(step.gate, 1.0, accuracy: 0.001)
        XCTAssertEqual(step.probability, 1.0, accuracy: 0.001)
    }

    func testPatternStep_AllNegativeClampedFields_AllClamped() {
        let step = PatternStep(
            stepIndex: 0,
            velocity: -999.0,
            pan: -999.0,
            pitch: -999.0,
            gate: -999.0,
            probability: -999.0
        )
        XCTAssertEqual(step.velocity, 0.0, accuracy: 0.001)
        XCTAssertEqual(step.pan, -1.0, accuracy: 0.001)
        XCTAssertEqual(step.pitch, -24.0, accuracy: 0.001)
        XCTAssertEqual(step.gate, 0.0, accuracy: 0.001)
        XCTAssertEqual(step.probability, 0.0, accuracy: 0.001)
    }

    func testPatternStep_HighStepIndex_Accepted() {
        let step = PatternStep(stepIndex: 63)
        XCTAssertEqual(step.stepIndex, 63)
    }
}

// MARK: - WarpMarker Tests

final class WarpMarkerTests: XCTestCase {

    func testWarpMarker_Init_SetsCorrectValues() {
        let marker = WarpMarker(samplePosition: 1.5, beatPosition: 4.0)
        XCTAssertEqual(marker.samplePosition, 1.5)
        XCTAssertEqual(marker.beatPosition, 4.0)
    }

    func testWarpMarker_Identifiable_HasUniqueID() {
        let marker1 = WarpMarker(samplePosition: 0.0, beatPosition: 0.0)
        let marker2 = WarpMarker(samplePosition: 0.0, beatPosition: 0.0)
        XCTAssertNotEqual(marker1.id, marker2.id)
    }

    func testWarpMarker_Equatable_SameFieldsSameID() {
        let id = UUID()
        let marker1 = WarpMarker(id: id, samplePosition: 2.0, beatPosition: 8.0)
        let marker2 = WarpMarker(id: id, samplePosition: 2.0, beatPosition: 8.0)
        XCTAssertEqual(marker1, marker2)
    }

    func testWarpMarker_Equatable_DifferentSamplePosition() {
        let id = UUID()
        let marker1 = WarpMarker(id: id, samplePosition: 1.0, beatPosition: 4.0)
        let marker2 = WarpMarker(id: id, samplePosition: 2.0, beatPosition: 4.0)
        XCTAssertNotEqual(marker1, marker2)
    }

    func testWarpMarker_Equatable_DifferentBeatPosition() {
        let id = UUID()
        let marker1 = WarpMarker(id: id, samplePosition: 1.0, beatPosition: 4.0)
        let marker2 = WarpMarker(id: id, samplePosition: 1.0, beatPosition: 8.0)
        XCTAssertNotEqual(marker1, marker2)
    }

    func testWarpMarker_CodableRoundTrip_PreservesAllFields() throws {
        let original = WarpMarker(samplePosition: 3.75, beatPosition: 16.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WarpMarker.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testWarpMarker_CodableRoundTrip_PreservesID() throws {
        let original = WarpMarker(samplePosition: 0.0, beatPosition: 0.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WarpMarker.self, from: encoded)
        XCTAssertEqual(original.id, decoded.id)
    }

    func testWarpMarker_ZeroValues_Accepted() {
        let marker = WarpMarker(samplePosition: 0.0, beatPosition: 0.0)
        XCTAssertEqual(marker.samplePosition, 0.0)
        XCTAssertEqual(marker.beatPosition, 0.0)
    }

    func testWarpMarker_LargeValues_Accepted() {
        let marker = WarpMarker(samplePosition: 3600.0, beatPosition: 7200.0)
        XCTAssertEqual(marker.samplePosition, 3600.0)
        XCTAssertEqual(marker.beatPosition, 7200.0)
    }
}

// MARK: - ClipType Tests

final class ClipTypeTests: XCTestCase {

    func testClipType_AllCasesCount_IsFive() {
        XCTAssertEqual(ClipType.allCases.count, 5)
    }

    func testClipType_RawValues_MatchExpected() {
        XCTAssertEqual(ClipType.audio.rawValue, "audio")
        XCTAssertEqual(ClipType.midi.rawValue, "midi")
        XCTAssertEqual(ClipType.pattern.rawValue, "pattern")
        XCTAssertEqual(ClipType.automation.rawValue, "automation")
        XCTAssertEqual(ClipType.video.rawValue, "video")
    }

    func testClipType_CodableRoundTrip_AllCases() throws {
        for clipType in ClipType.allCases {
            let encoded = try JSONEncoder().encode(clipType)
            let decoded = try JSONDecoder().decode(ClipType.self, from: encoded)
            XCTAssertEqual(clipType, decoded, "Codable round-trip failed for \(clipType)")
        }
    }

    func testClipType_DecodableFromString() throws {
        let json = Data("\"midi\"".utf8)
        let decoded = try JSONDecoder().decode(ClipType.self, from: json)
        XCTAssertEqual(decoded, .midi)
    }

    func testClipType_ContainsExpectedCases() {
        let allCases = ClipType.allCases
        XCTAssertTrue(allCases.contains(.audio))
        XCTAssertTrue(allCases.contains(.midi))
        XCTAssertTrue(allCases.contains(.pattern))
        XCTAssertTrue(allCases.contains(.automation))
        XCTAssertTrue(allCases.contains(.video))
    }
}

// MARK: - ClipState Tests

final class ClipStateTests: XCTestCase {

    func testClipState_AllCasesCount_IsFive() {
        XCTAssertEqual(ClipState.allCases.count, 5)
    }

    func testClipState_RawValues_MatchExpected() {
        XCTAssertEqual(ClipState.empty.rawValue, "empty")
        XCTAssertEqual(ClipState.stopped.rawValue, "stopped")
        XCTAssertEqual(ClipState.queued.rawValue, "queued")
        XCTAssertEqual(ClipState.playing.rawValue, "playing")
        XCTAssertEqual(ClipState.recording.rawValue, "recording")
    }

    func testClipState_CodableRoundTrip_AllCases() throws {
        for state in ClipState.allCases {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ClipState.self, from: encoded)
            XCTAssertEqual(state, decoded, "Codable round-trip failed for \(state)")
        }
    }

    func testClipState_DecodableFromString() throws {
        let json = Data("\"playing\"".utf8)
        let decoded = try JSONDecoder().decode(ClipState.self, from: json)
        XCTAssertEqual(decoded, .playing)
    }

    func testClipState_ContainsExpectedCases() {
        let allCases = ClipState.allCases
        XCTAssertTrue(allCases.contains(.empty))
        XCTAssertTrue(allCases.contains(.stopped))
        XCTAssertTrue(allCases.contains(.queued))
        XCTAssertTrue(allCases.contains(.playing))
        XCTAssertTrue(allCases.contains(.recording))
    }
}

// MARK: - ClipColor Tests

final class ClipColorTests: XCTestCase {

    func testClipColor_AllCasesCount_IsSixteen() {
        XCTAssertEqual(ClipColor.allCases.count, 16)
    }

    func testClipColor_RawValues_MatchExpected() {
        XCTAssertEqual(ClipColor.rose.rawValue, 0)
        XCTAssertEqual(ClipColor.red.rawValue, 1)
        XCTAssertEqual(ClipColor.orange.rawValue, 2)
        XCTAssertEqual(ClipColor.amber.rawValue, 3)
        XCTAssertEqual(ClipColor.yellow.rawValue, 4)
        XCTAssertEqual(ClipColor.lime.rawValue, 5)
        XCTAssertEqual(ClipColor.green.rawValue, 6)
        XCTAssertEqual(ClipColor.mint.rawValue, 7)
        XCTAssertEqual(ClipColor.cyan.rawValue, 8)
        XCTAssertEqual(ClipColor.sky.rawValue, 9)
        XCTAssertEqual(ClipColor.blue.rawValue, 10)
        XCTAssertEqual(ClipColor.indigo.rawValue, 11)
        XCTAssertEqual(ClipColor.purple.rawValue, 12)
        XCTAssertEqual(ClipColor.magenta.rawValue, 13)
        XCTAssertEqual(ClipColor.pink.rawValue, 14)
        XCTAssertEqual(ClipColor.sand.rawValue, 15)
    }

    func testClipColor_CodableRoundTrip_AllCases() throws {
        for color in ClipColor.allCases {
            let encoded = try JSONEncoder().encode(color)
            let decoded = try JSONDecoder().decode(ClipColor.self, from: encoded)
            XCTAssertEqual(color, decoded, "Codable round-trip failed for \(color)")
        }
    }

    func testClipColor_FirstAndLast_AreCorrect() {
        XCTAssertEqual(ClipColor.allCases.first, .rose)
        XCTAssertEqual(ClipColor.allCases.last, .sand)
    }

    func testClipColor_InitFromRawValue_ValidValues() {
        for rawValue in 0...15 {
            let color = ClipColor(rawValue: rawValue)
            XCTAssertNotNil(color, "ClipColor should exist for raw value \(rawValue)")
        }
    }

    func testClipColor_InitFromRawValue_InvalidValue() {
        XCTAssertNil(ClipColor(rawValue: 16))
        XCTAssertNil(ClipColor(rawValue: -1))
        XCTAssertNil(ClipColor(rawValue: 100))
    }

    func testClipColor_ContiguousRawValues() {
        let rawValues = ClipColor.allCases.map(\.rawValue)
        for i in 0..<rawValues.count {
            XCTAssertEqual(rawValues[i], i, "ClipColor raw values should be contiguous from 0")
        }
    }
}

// MARK: - LaunchMode Tests

final class LaunchModeTests: XCTestCase {

    func testLaunchMode_AllCasesCount_IsFour() {
        XCTAssertEqual(LaunchMode.allCases.count, 4)
    }

    func testLaunchMode_RawValues_MatchExpected() {
        XCTAssertEqual(LaunchMode.trigger.rawValue, "trigger")
        XCTAssertEqual(LaunchMode.gate.rawValue, "gate")
        XCTAssertEqual(LaunchMode.toggle.rawValue, "toggle")
        XCTAssertEqual(LaunchMode.repeating.rawValue, "repeating")
    }

    func testLaunchMode_CodableRoundTrip_AllCases() throws {
        for mode in LaunchMode.allCases {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(LaunchMode.self, from: encoded)
            XCTAssertEqual(mode, decoded, "Codable round-trip failed for \(mode)")
        }
    }

    func testLaunchMode_ContainsExpectedCases() {
        let allCases = LaunchMode.allCases
        XCTAssertTrue(allCases.contains(.trigger))
        XCTAssertTrue(allCases.contains(.gate))
        XCTAssertTrue(allCases.contains(.toggle))
        XCTAssertTrue(allCases.contains(.repeating))
    }

    func testLaunchMode_DecodableFromString() throws {
        let json = Data("\"gate\"".utf8)
        let decoded = try JSONDecoder().decode(LaunchMode.self, from: json)
        XCTAssertEqual(decoded, .gate)
    }
}

// MARK: - LaunchQuantize Tests

final class LaunchQuantizeTests: XCTestCase {

    func testLaunchQuantize_AllCasesCount_IsSix() {
        XCTAssertEqual(LaunchQuantize.allCases.count, 6)
    }

    func testLaunchQuantize_RawValues_MatchExpected() {
        XCTAssertEqual(LaunchQuantize.none.rawValue, "none")
        XCTAssertEqual(LaunchQuantize.nextBeat.rawValue, "nextBeat")
        XCTAssertEqual(LaunchQuantize.nextBar.rawValue, "nextBar")
        XCTAssertEqual(LaunchQuantize.next2Bars.rawValue, "next2Bars")
        XCTAssertEqual(LaunchQuantize.next4Bars.rawValue, "next4Bars")
        XCTAssertEqual(LaunchQuantize.next8Bars.rawValue, "next8Bars")
    }

    func testLaunchQuantize_BeatCount_None_IsZero() {
        XCTAssertEqual(LaunchQuantize.none.beatCount, 0)
    }

    func testLaunchQuantize_BeatCount_NextBeat_IsOne() {
        XCTAssertEqual(LaunchQuantize.nextBeat.beatCount, 1)
    }

    func testLaunchQuantize_BeatCount_NextBar_IsFour() {
        XCTAssertEqual(LaunchQuantize.nextBar.beatCount, 4)
    }

    func testLaunchQuantize_BeatCount_Next2Bars_IsEight() {
        XCTAssertEqual(LaunchQuantize.next2Bars.beatCount, 8)
    }

    func testLaunchQuantize_BeatCount_Next4Bars_IsSixteen() {
        XCTAssertEqual(LaunchQuantize.next4Bars.beatCount, 16)
    }

    func testLaunchQuantize_BeatCount_Next8Bars_IsThirtyTwo() {
        XCTAssertEqual(LaunchQuantize.next8Bars.beatCount, 32)
    }

    func testLaunchQuantize_BeatCounts_AreMonotonicallyIncreasing() {
        let beatCounts = LaunchQuantize.allCases.map(\.beatCount)
        for i in 1..<beatCounts.count {
            XCTAssertGreaterThan(beatCounts[i], beatCounts[i - 1],
                                 "Beat counts should increase: \(beatCounts[i]) should be > \(beatCounts[i - 1])")
        }
    }

    func testLaunchQuantize_BeatCounts_AllNonNegative() {
        for quantize in LaunchQuantize.allCases {
            XCTAssertGreaterThanOrEqual(quantize.beatCount, 0,
                                        "\(quantize) beat count should be non-negative")
        }
    }

    func testLaunchQuantize_CodableRoundTrip_AllCases() throws {
        for quantize in LaunchQuantize.allCases {
            let encoded = try JSONEncoder().encode(quantize)
            let decoded = try JSONDecoder().decode(LaunchQuantize.self, from: encoded)
            XCTAssertEqual(quantize, decoded, "Codable round-trip failed for \(quantize)")
        }
    }

    func testLaunchQuantize_DecodableFromString() throws {
        let json = Data("\"next4Bars\"".utf8)
        let decoded = try JSONDecoder().decode(LaunchQuantize.self, from: json)
        XCTAssertEqual(decoded, .next4Bars)
    }
}

// MARK: - FollowActionType Tests

final class FollowActionTypeTests: XCTestCase {

    func testFollowActionType_AllCasesCount_IsEight() {
        XCTAssertEqual(FollowActionType.allCases.count, 8)
    }

    func testFollowActionType_RawValues_MatchExpected() {
        XCTAssertEqual(FollowActionType.stop.rawValue, "stop")
        XCTAssertEqual(FollowActionType.playAgain.rawValue, "playAgain")
        XCTAssertEqual(FollowActionType.playPrevious.rawValue, "playPrevious")
        XCTAssertEqual(FollowActionType.playNext.rawValue, "playNext")
        XCTAssertEqual(FollowActionType.playFirst.rawValue, "playFirst")
        XCTAssertEqual(FollowActionType.playLast.rawValue, "playLast")
        XCTAssertEqual(FollowActionType.playRandom.rawValue, "playRandom")
        XCTAssertEqual(FollowActionType.playAny.rawValue, "playAny")
    }

    func testFollowActionType_CodableRoundTrip_AllCases() throws {
        for action in FollowActionType.allCases {
            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(FollowActionType.self, from: encoded)
            XCTAssertEqual(action, decoded, "Codable round-trip failed for \(action)")
        }
    }

    func testFollowActionType_ContainsExpectedCases() {
        let allCases = FollowActionType.allCases
        XCTAssertTrue(allCases.contains(.stop))
        XCTAssertTrue(allCases.contains(.playAgain))
        XCTAssertTrue(allCases.contains(.playPrevious))
        XCTAssertTrue(allCases.contains(.playNext))
        XCTAssertTrue(allCases.contains(.playFirst))
        XCTAssertTrue(allCases.contains(.playLast))
        XCTAssertTrue(allCases.contains(.playRandom))
        XCTAssertTrue(allCases.contains(.playAny))
    }

    func testFollowActionType_DecodableFromString() throws {
        let json = Data("\"playRandom\"".utf8)
        let decoded = try JSONDecoder().decode(FollowActionType.self, from: json)
        XCTAssertEqual(decoded, .playRandom)
    }
}

// MARK: - FollowAction Tests

final class FollowActionTests: XCTestCase {

    func testFollowAction_InitWithDefaults_SetsCorrectValues() {
        let action = FollowAction()
        XCTAssertEqual(action.action, .playNext, "Default action should be playNext")
        XCTAssertEqual(action.chance, 1.0, accuracy: 0.001, "Default chance should be 1.0")
        XCTAssertNil(action.linkedAction, "Default linkedAction should be nil")
        XCTAssertEqual(action.linkedChance, 0.0, accuracy: 0.001, "Default linkedChance should be 0.0")
    }

    func testFollowAction_InitWithAllParameters_SetsCorrectValues() {
        let action = FollowAction(
            action: .stop,
            chance: 0.7,
            linkedAction: .playAgain,
            linkedChance: 0.3
        )
        XCTAssertEqual(action.action, .stop)
        XCTAssertEqual(action.chance, 0.7, accuracy: 0.001)
        XCTAssertEqual(action.linkedAction, .playAgain)
        XCTAssertEqual(action.linkedChance, 0.3, accuracy: 0.001)
    }

    func testFollowAction_ChanceClamping_ClipsToRange() {
        let tooHigh = FollowAction(chance: 5.0)
        XCTAssertEqual(tooHigh.chance, 1.0, accuracy: 0.001)

        let tooLow = FollowAction(chance: -1.0)
        XCTAssertEqual(tooLow.chance, 0.0, accuracy: 0.001)
    }

    func testFollowAction_LinkedChanceClamping_ClipsToRange() {
        let tooHigh = FollowAction(linkedChance: 5.0)
        XCTAssertEqual(tooHigh.linkedChance, 1.0, accuracy: 0.001)

        let tooLow = FollowAction(linkedChance: -1.0)
        XCTAssertEqual(tooLow.linkedChance, 0.0, accuracy: 0.001)
    }

    func testFollowAction_Equatable_SameValues() {
        let action1 = FollowAction(action: .playNext, chance: 0.8, linkedAction: .stop, linkedChance: 0.2)
        let action2 = FollowAction(action: .playNext, chance: 0.8, linkedAction: .stop, linkedChance: 0.2)
        XCTAssertEqual(action1, action2)
    }

    func testFollowAction_Equatable_DifferentAction() {
        let action1 = FollowAction(action: .playNext)
        let action2 = FollowAction(action: .stop)
        XCTAssertNotEqual(action1, action2)
    }

    func testFollowAction_CodableRoundTrip_WithLinkedAction() throws {
        let original = FollowAction(
            action: .playFirst,
            chance: 0.6,
            linkedAction: .playLast,
            linkedChance: 0.4
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FollowAction.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testFollowAction_CodableRoundTrip_WithoutLinkedAction() throws {
        let original = FollowAction(action: .stop, chance: 1.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FollowAction.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testFollowAction_Resolve_ReturnsActionWhenNoLinked() {
        let action = FollowAction(action: .stop, chance: 1.0)
        let result = action.resolve()
        XCTAssertEqual(result, .stop, "Should always return primary action when no linked action and full chance")
    }

    func testFollowAction_Resolve_ReturnsActionWhenZeroTotalWeight() {
        let action = FollowAction(action: .playNext, chance: 0.0, linkedAction: .stop, linkedChance: 0.0)
        let result = action.resolve()
        XCTAssertEqual(result, .playNext, "Should return primary action when total weight is zero")
    }

    func testFollowAction_Resolve_FallsBackToPrimaryWhenLinkedIsNil() {
        let action = FollowAction(action: .playAgain, chance: 0.0, linkedChance: 1.0)
        // linkedAction is nil, so even when roll falls in linked range, should return primary
        let result = action.resolve()
        XCTAssertEqual(result, .playAgain, "Should fallback to primary action when linkedAction is nil")
    }
}

// MARK: - WarpMode Tests

final class WarpModeTests: XCTestCase {

    func testWarpMode_AllCasesCount_IsSeven() {
        XCTAssertEqual(WarpMode.allCases.count, 7)
    }

    func testWarpMode_RawValues_MatchExpected() {
        XCTAssertEqual(WarpMode.off.rawValue, "off")
        XCTAssertEqual(WarpMode.beats.rawValue, "beats")
        XCTAssertEqual(WarpMode.tones.rawValue, "tones")
        XCTAssertEqual(WarpMode.texture.rawValue, "texture")
        XCTAssertEqual(WarpMode.rePitch.rawValue, "rePitch")
        XCTAssertEqual(WarpMode.complex.rawValue, "complex")
        XCTAssertEqual(WarpMode.complexPro.rawValue, "complexPro")
    }

    func testWarpMode_CodableRoundTrip_AllCases() throws {
        for mode in WarpMode.allCases {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(WarpMode.self, from: encoded)
            XCTAssertEqual(mode, decoded, "Codable round-trip failed for \(mode)")
        }
    }

    func testWarpMode_ContainsExpectedCases() {
        let allCases = WarpMode.allCases
        XCTAssertTrue(allCases.contains(.off))
        XCTAssertTrue(allCases.contains(.beats))
        XCTAssertTrue(allCases.contains(.tones))
        XCTAssertTrue(allCases.contains(.texture))
        XCTAssertTrue(allCases.contains(.rePitch))
        XCTAssertTrue(allCases.contains(.complex))
        XCTAssertTrue(allCases.contains(.complexPro))
    }
}

// MARK: - SessionClip Tests

final class SessionClipTests: XCTestCase {

    func testSessionClip_InitWithDefaults_SetsCorrectValues() {
        let clip = SessionClip()
        XCTAssertEqual(clip.name, "Clip")
        XCTAssertEqual(clip.type, .midi)
        XCTAssertEqual(clip.state, .stopped)
        XCTAssertEqual(clip.color, .blue)
        XCTAssertEqual(clip.length, 4.0, accuracy: 0.001)
        XCTAssertTrue(clip.loopEnabled)
        XCTAssertEqual(clip.launchMode, .trigger)
        XCTAssertEqual(clip.quantization, .nextBar)
        XCTAssertNil(clip.followAction)
        XCTAssertEqual(clip.followActionTime, 4.0, accuracy: 0.001)
        XCTAssertEqual(clip.warpMode, .off)
        XCTAssertTrue(clip.warpMarkers.isEmpty)
        XCTAssertEqual(clip.playbackSpeed, 1.0, accuracy: 0.001)
        XCTAssertEqual(clip.startOffset, 0.0, accuracy: 0.001)
        XCTAssertEqual(clip.endOffset, 0.0, accuracy: 0.001)
        XCTAssertNil(clip.audioURL)
        XCTAssertEqual(clip.gain, 0.0, accuracy: 0.001)
        XCTAssertTrue(clip.midiNotes.isEmpty)
        XCTAssertTrue(clip.patternSteps.isEmpty)
    }

    func testSessionClip_InitWithCustomValues_SetsCorrectValues() {
        let followAction = FollowAction(action: .playNext, chance: 0.8)
        let clip = SessionClip(
            name: "Drums",
            type: .pattern,
            state: .playing,
            color: .orange,
            length: 8.0,
            loopEnabled: false,
            launchMode: .toggle,
            quantization: .next2Bars,
            followAction: followAction,
            followActionTime: 8.0,
            warpMode: .beats,
            playbackSpeed: 1.5,
            gain: -6.0
        )
        XCTAssertEqual(clip.name, "Drums")
        XCTAssertEqual(clip.type, .pattern)
        XCTAssertEqual(clip.state, .playing)
        XCTAssertEqual(clip.color, .orange)
        XCTAssertEqual(clip.length, 8.0, accuracy: 0.001)
        XCTAssertFalse(clip.loopEnabled)
        XCTAssertEqual(clip.launchMode, .toggle)
        XCTAssertEqual(clip.quantization, .next2Bars)
        XCTAssertNotNil(clip.followAction)
        XCTAssertEqual(clip.followActionTime, 8.0, accuracy: 0.001)
        XCTAssertEqual(clip.warpMode, .beats)
        XCTAssertEqual(clip.playbackSpeed, 1.5, accuracy: 0.001)
        XCTAssertEqual(clip.gain, -6.0, accuracy: 0.001)
    }

    func testSessionClip_Identifiable_HasUniqueID() {
        let clip1 = SessionClip()
        let clip2 = SessionClip()
        XCTAssertNotEqual(clip1.id, clip2.id)
    }

    func testSessionClip_WithMIDINotes_StoresCorrectly() {
        let notes = [
            MIDINoteEvent(note: 60, startBeat: 0.0),
            MIDINoteEvent(note: 64, startBeat: 1.0),
            MIDINoteEvent(note: 67, startBeat: 2.0)
        ]
        let clip = SessionClip(type: .midi, midiNotes: notes)
        XCTAssertEqual(clip.midiNotes.count, 3)
        XCTAssertEqual(clip.midiNotes[0].note, 60)
        XCTAssertEqual(clip.midiNotes[1].note, 64)
        XCTAssertEqual(clip.midiNotes[2].note, 67)
    }

    func testSessionClip_WithPatternSteps_StoresCorrectly() {
        let steps = (0..<16).map { PatternStep(stepIndex: $0, isActive: $0 % 4 == 0) }
        let clip = SessionClip(type: .pattern, patternSteps: steps)
        XCTAssertEqual(clip.patternSteps.count, 16)
        XCTAssertTrue(clip.patternSteps[0].isActive)
        XCTAssertFalse(clip.patternSteps[1].isActive)
        XCTAssertFalse(clip.patternSteps[2].isActive)
        XCTAssertFalse(clip.patternSteps[3].isActive)
        XCTAssertTrue(clip.patternSteps[4].isActive)
    }

    func testSessionClip_WithWarpMarkers_StoresCorrectly() {
        let markers = [
            WarpMarker(samplePosition: 0.0, beatPosition: 0.0),
            WarpMarker(samplePosition: 2.0, beatPosition: 4.0),
            WarpMarker(samplePosition: 4.0, beatPosition: 8.0)
        ]
        let clip = SessionClip(type: .audio, warpMode: .beats, warpMarkers: markers)
        XCTAssertEqual(clip.warpMarkers.count, 3)
        XCTAssertEqual(clip.warpMarkers[1].samplePosition, 2.0)
        XCTAssertEqual(clip.warpMarkers[1].beatPosition, 4.0)
    }

    func testSessionClip_Equatable_SameIDSameFields() {
        let id = UUID()
        let clip1 = SessionClip(id: id, name: "Test", type: .midi, state: .stopped, color: .blue)
        let clip2 = SessionClip(id: id, name: "Test", type: .midi, state: .stopped, color: .blue)
        XCTAssertEqual(clip1, clip2)
    }

    func testSessionClip_Equatable_DifferentState() {
        let id = UUID()
        let clip1 = SessionClip(id: id, state: .stopped)
        let clip2 = SessionClip(id: id, state: .playing)
        XCTAssertNotEqual(clip1, clip2)
    }

    func testSessionClip_MutableState_CanChangeState() {
        var clip = SessionClip(state: .stopped)
        XCTAssertEqual(clip.state, .stopped)
        clip.state = .queued
        XCTAssertEqual(clip.state, .queued)
        clip.state = .playing
        XCTAssertEqual(clip.state, .playing)
    }

    func testSessionClip_MutableGain_CanChangeGain() {
        var clip = SessionClip(gain: 0.0)
        XCTAssertEqual(clip.gain, 0.0, accuracy: 0.001)
        clip.gain = -12.0
        XCTAssertEqual(clip.gain, -12.0, accuracy: 0.001)
    }
}

#endif
