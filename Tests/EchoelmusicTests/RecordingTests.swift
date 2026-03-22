#if canImport(AVFoundation)
// RecordingTests.swift
// Echoelmusic — Phase 4 Test Coverage: Recording & Session
//
// Tests for Track, TrackSend, TrackAutomationLane, TrackAutomationPoint,
// Session, RecordingTimeSignature, BioDataPoint, SessionMetadata,
// and associated enums (TrackType, TrackColor, AutomatedParameter, etc.)

import XCTest
@testable import Echoelmusic

// MARK: - TrackType Tests

final class TrackTypeTests: XCTestCase {

    func testCoreTypes() {
        XCTAssertEqual(TrackType.audio.rawValue, "audio")
        XCTAssertEqual(TrackType.voice.rawValue, "voice")
        XCTAssertEqual(TrackType.master.rawValue, "master")
        XCTAssertEqual(TrackType.instrument.rawValue, "instrument")
        XCTAssertEqual(TrackType.midi.rawValue, "midi")
    }

    func testRoutingTypes() {
        XCTAssertEqual(TrackType.aux.rawValue, "aux")
        XCTAssertEqual(TrackType.bus.rawValue, "bus")
        XCTAssertEqual(TrackType.send.rawValue, "send")
    }

    func testCodable() throws {
        let original = TrackType.audio
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackType.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - TrackInputSource Tests

final class TrackInputSourceTests: XCTestCase {

    func testAllCases() {
        let cases = TrackInputSource.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.none))
        XCTAssertTrue(cases.contains(.mic))
        XCTAssertTrue(cases.contains(.lineIn))
        XCTAssertTrue(cases.contains(.midi))
    }

    func testCodable() throws {
        let original = TrackInputSource.mic
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackInputSource.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - TrackColor Tests

final class TrackColorTests: XCTestCase {

    func testAllCases() {
        let cases = TrackColor.allCases
        XCTAssertGreaterThanOrEqual(cases.count, 10)
    }

    func testCodable() throws {
        let original = TrackColor.cyan
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrackColor.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - AutomatedParameter Tests

final class AutomatedParameterTests: XCTestCase {

    func testAllCases() {
        let cases = AutomatedParameter.allCases
        XCTAssertGreaterThan(cases.count, 20)
    }

    func testDefaultValues() {
        XCTAssertEqual(AutomatedParameter.volume.defaultValue, 0.8, accuracy: 0.01)
        XCTAssertEqual(AutomatedParameter.pan.defaultValue, 0.0, accuracy: 0.01)
    }

    func testDisplayNames() {
        for param in AutomatedParameter.allCases {
            XCTAssertFalse(param.displayName.isEmpty, "\(param) missing displayName")
        }
    }

    func testCodable() throws {
        let original = AutomatedParameter.filterCutoff
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AutomatedParameter.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - RecordingMonitorMode Tests

final class RecordingMonitorModeTests: XCTestCase {

    func testAllCases() {
        let cases = RecordingMonitorMode.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.auto))
        XCTAssertTrue(cases.contains(.alwaysOn))
        XCTAssertTrue(cases.contains(.off))
    }
}

// MARK: - TrackSend Tests

final class TrackSendTests: XCTestCase {

    func testInit() {
        let destID = UUID()
        let send = TrackSend(destinationID: destID, level: 0.5, isPreFader: true)
        XCTAssertEqual(send.destinationID, destID)
        XCTAssertEqual(send.level, 0.5, accuracy: 0.01)
        XCTAssertTrue(send.isPreFader)
        XCTAssertTrue(send.isEnabled)
    }

    func testCodable() throws {
        let send = TrackSend(destinationID: UUID(), level: 0.7, isPreFader: false)
        let data = try JSONEncoder().encode(send)
        let decoded = try JSONDecoder().decode(TrackSend.self, from: data)
        XCTAssertEqual(send.destinationID, decoded.destinationID)
        XCTAssertEqual(send.level, decoded.level, accuracy: 0.001)
        XCTAssertEqual(send.isPreFader, decoded.isPreFader)
    }
}

// MARK: - TrackAutomationPoint Tests

final class TrackAutomationPointTests: XCTestCase {

    func testInit() {
        let point = TrackAutomationPoint(time: 1.5, value: 0.8, curveType: .linear)
        XCTAssertEqual(point.time, 1.5, accuracy: 0.001)
        XCTAssertEqual(point.value, 0.8, accuracy: 0.001)
        XCTAssertEqual(point.curveType, .linear)
    }

    func testCurveTypes() {
        let types = TrackAutomationPoint.CurveType.allCases
        XCTAssertEqual(types.count, 5)
        XCTAssertTrue(types.contains(.linear))
        XCTAssertTrue(types.contains(.exponential))
        XCTAssertTrue(types.contains(.logarithmic))
        XCTAssertTrue(types.contains(.sCurve))
        XCTAssertTrue(types.contains(.hold))
    }

    func testCodable() throws {
        let point = TrackAutomationPoint(time: 2.0, value: 0.5, curveType: .sCurve)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(TrackAutomationPoint.self, from: data)
        XCTAssertEqual(point.time, decoded.time, accuracy: 0.001)
        XCTAssertEqual(point.value, decoded.value, accuracy: 0.001)
        XCTAssertEqual(point.curveType, decoded.curveType)
    }
}

// MARK: - TrackAutomationLane Tests

final class TrackAutomationLaneTests: XCTestCase {

    func testInit() {
        let lane = TrackAutomationLane(parameter: .volume)
        XCTAssertEqual(lane.parameter, .volume)
        XCTAssertTrue(lane.points.isEmpty)
        XCTAssertTrue(lane.isVisible)
        XCTAssertTrue(lane.isEnabled)
        XCTAssertFalse(lane.isRecording)
    }

    func testValueAtWithNoPoints() {
        let lane = TrackAutomationLane(parameter: .volume)
        let value = lane.valueAt(time: 1.0)
        // Should return parameter default
        XCTAssertEqual(value, AutomatedParameter.volume.defaultValue, accuracy: 0.01)
    }

    func testValueAtWithSinglePoint() {
        var lane = TrackAutomationLane(parameter: .pan)
        lane.points = [TrackAutomationPoint(time: 1.0, value: 0.7, curveType: .linear)]
        let before = lane.valueAt(time: 0.5)
        let at = lane.valueAt(time: 1.0)
        let after = lane.valueAt(time: 2.0)
        XCTAssertEqual(at, 0.7, accuracy: 0.01)
        // Before first point should return first point value
        XCTAssertEqual(before, 0.7, accuracy: 0.01)
        // After last point should return last point value
        XCTAssertEqual(after, 0.7, accuracy: 0.01)
    }

    func testLinearInterpolation() {
        var lane = TrackAutomationLane(parameter: .volume)
        lane.points = [
            TrackAutomationPoint(time: 0.0, value: 0.0, curveType: .linear),
            TrackAutomationPoint(time: 1.0, value: 1.0, curveType: .linear)
        ]
        let mid = lane.valueAt(time: 0.5)
        XCTAssertEqual(mid, 0.5, accuracy: 0.05)
    }

    func testHoldInterpolation() {
        var lane = TrackAutomationLane(parameter: .volume)
        lane.points = [
            TrackAutomationPoint(time: 0.0, value: 0.3, curveType: .hold),
            TrackAutomationPoint(time: 1.0, value: 0.9, curveType: .hold)
        ]
        // Hold should keep the first value until the next point
        let mid = lane.valueAt(time: 0.5)
        XCTAssertEqual(mid, 0.3, accuracy: 0.05)
    }

    func testCodable() throws {
        var lane = TrackAutomationLane(parameter: .filterCutoff)
        lane.points = [TrackAutomationPoint(time: 0.0, value: 0.5, curveType: .linear)]
        let data = try JSONEncoder().encode(lane)
        let decoded = try JSONDecoder().decode(TrackAutomationLane.self, from: data)
        XCTAssertEqual(lane.parameter, decoded.parameter)
        XCTAssertEqual(lane.points.count, decoded.points.count)
    }
}

// MARK: - Track Tests

final class TrackTests: XCTestCase {

    func testDefaultInit() {
        let track = Track(name: "Test Track")
        XCTAssertEqual(track.name, "Test Track")
        XCTAssertEqual(track.type, .audio)
        XCTAssertEqual(track.volume, 0.8, accuracy: 0.01)
        XCTAssertEqual(track.pan, 0.0, accuracy: 0.01)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSoloed)
        XCTAssertFalse(track.isArmed)
        XCTAssertFalse(track.isFrozen)
        XCTAssertFalse(track.isPhaseInverted)
    }

    func testCustomInit() {
        let track = Track(name: "Bass", type: .instrument, volume: 0.6, pan: -0.3)
        XCTAssertEqual(track.name, "Bass")
        XCTAssertEqual(track.type, .instrument)
        XCTAssertEqual(track.volume, 0.6, accuracy: 0.01)
        XCTAssertEqual(track.pan, -0.3, accuracy: 0.01)
    }

    func testAddEffect() {
        var track = Track(name: "FX")
        track.addEffect("reverb_1")
        XCTAssertEqual(track.effects.count, 1)
        XCTAssertEqual(track.effects.first, "reverb_1")
    }

    func testRemoveEffect() {
        var track = Track(name: "FX")
        track.addEffect("reverb_1")
        track.addEffect("delay_1")
        track.removeEffect("reverb_1")
        XCTAssertEqual(track.effects.count, 1)
        XCTAssertEqual(track.effects.first, "delay_1")
    }

    func testAddSend() {
        var track = Track(name: "Send Test")
        let destID = UUID()
        track.addSend(to: destID, level: 0.5, preFader: true)
        XCTAssertEqual(track.sends.count, 1)
        XCTAssertEqual(track.sends.first?.destinationID, destID)
        XCTAssertEqual(track.sends.first?.level ?? 0, 0.5, accuracy: 0.01)
    }

    func testRemoveSend() throws {
        var track = Track(name: "Send Test")
        let destID = UUID()
        track.addSend(to: destID, level: 0.5, preFader: false)
        let sendID = try XCTUnwrap(track.sends.first?.id)
        track.removeSend(id: sendID)
        XCTAssertTrue(track.sends.isEmpty)
    }

    func testAddAutomationLane() {
        var track = Track(name: "Auto")
        track.addAutomationLane(for: .volume)
        XCTAssertEqual(track.automationLanes.count, 1)
        XCTAssertEqual(track.automationLanes.first?.parameter, .volume)
    }

    func testVoiceTrackPreset() {
        let track = Track.voiceTrack()
        XCTAssertEqual(track.type, .voice)
        XCTAssertFalse(track.name.isEmpty)
    }

    func testMasterTrackPreset() {
        let track = Track.masterTrack()
        XCTAssertEqual(track.type, .master)
    }

    func testInstrumentTrackPreset() {
        let track = Track.instrumentTrack(name: "Piano")
        XCTAssertEqual(track.type, .instrument)
        XCTAssertEqual(track.name, "Piano")
    }

    func testAuxTrackPreset() {
        let track = Track.auxTrack(name: "FX Bus")
        XCTAssertEqual(track.type, .aux)
    }

    func testBusTrackPreset() {
        let track = Track.busTrack(name: "Drum Bus")
        XCTAssertEqual(track.type, .bus)
    }

    func testMidiTrackPreset() {
        let track = Track.midiTrack(name: "Synth Lead")
        XCTAssertEqual(track.type, .midi)
    }

    func testCodable() throws {
        let track = Track(name: "Codable Test", type: .audio, volume: 0.7, pan: 0.2)
        let data = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(Track.self, from: data)
        XCTAssertEqual(track.id, decoded.id)
        XCTAssertEqual(track.name, decoded.name)
        XCTAssertEqual(track.type, decoded.type)
        XCTAssertEqual(track.volume, decoded.volume, accuracy: 0.001)
    }

    func testProMusicSession() {
        let tracks = Track.proMusicSession()
        XCTAssertGreaterThan(tracks.count, 3)
    }

    func testDjSession() {
        let tracks = Track.djSession()
        XCTAssertGreaterThan(tracks.count, 1)
    }

    func testLivePerformanceSession() {
        let tracks = Track.livePerformanceSession()
        XCTAssertGreaterThan(tracks.count, 1)
    }
}

// MARK: - RecordingTimeSignature Tests

final class RecordingTimeSignatureTests: XCTestCase {

    func testDefaultInit() {
        let sig = RecordingTimeSignature(beats: 4, noteValue: 4)
        XCTAssertEqual(sig.beats, 4)
        XCTAssertEqual(sig.noteValue, 4)
    }

    func testDescription() {
        let sig = RecordingTimeSignature(beats: 3, noteValue: 4)
        XCTAssertEqual(sig.description, "3/4")
    }

    func testAlternateInit() {
        let sig = RecordingTimeSignature(numerator: 6, denominator: 8)
        XCTAssertEqual(sig.numerator, 6)
        XCTAssertEqual(sig.denominator, 8)
    }

    func testCodable() throws {
        let sig = RecordingTimeSignature(beats: 7, noteValue: 8)
        let data = try JSONEncoder().encode(sig)
        let decoded = try JSONDecoder().decode(RecordingTimeSignature.self, from: data)
        XCTAssertEqual(sig.beats, decoded.beats)
        XCTAssertEqual(sig.noteValue, decoded.noteValue)
    }
}

// MARK: - BioDataPoint Tests

final class BioDataPointTests: XCTestCase {

    func testInit() {
        let point = BioDataPoint(
            timestamp: 1.0,
            hrv: 65.0,
            heartRate: 72.0,
            coherence: 0.7,
            audioLevel: 0.5,
            frequency: 440.0
        )
        XCTAssertEqual(point.timestamp, 1.0, accuracy: 0.001)
        XCTAssertEqual(point.hrv, 65.0, accuracy: 0.01)
        XCTAssertEqual(point.heartRate, 72.0, accuracy: 0.01)
        XCTAssertEqual(point.coherence, 0.7, accuracy: 0.01)
    }

    func testCodable() throws {
        let point = BioDataPoint(
            timestamp: 2.0, hrv: 50.0, heartRate: 80.0,
            coherence: 0.5, audioLevel: 0.3, frequency: 220.0
        )
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(BioDataPoint.self, from: data)
        XCTAssertEqual(point.hrv, decoded.hrv, accuracy: 0.001)
        XCTAssertEqual(point.heartRate, decoded.heartRate, accuracy: 0.001)
    }
}

// MARK: - SessionMetadata Tests

final class SessionMetadataTests: XCTestCase {

    func testDefaultInit() {
        let meta = SessionMetadata(tags: ["test"], genre: "ambient", mood: "calm", notes: "session note")
        XCTAssertEqual(meta.tags, ["test"])
        XCTAssertEqual(meta.genre, "ambient")
        XCTAssertEqual(meta.mood, "calm")
        XCTAssertEqual(meta.notes, "session note")
    }

    func testCodable() throws {
        let meta = SessionMetadata(tags: ["a", "b"], genre: "electronic", mood: nil, notes: nil)
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(SessionMetadata.self, from: data)
        XCTAssertEqual(meta.tags, decoded.tags)
        XCTAssertEqual(meta.genre, decoded.genre)
    }
}

// MARK: - Session Tests

final class SessionTests: XCTestCase {

    func testDefaultInit() {
        let session = Session(name: "Test Session")
        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.tempo, 120.0, accuracy: 0.01)
        XCTAssertTrue(session.tracks.isEmpty)
        XCTAssertTrue(session.bioData.isEmpty)
    }

    func testAddTrack() {
        var session = Session(name: "Test")
        let track = Track(name: "Audio 1")
        session.addTrack(track)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertEqual(session.tracks.first?.name, "Audio 1")
    }

    func testRemoveTrack() {
        var session = Session(name: "Test")
        let track = Track(name: "Audio 1")
        session.addTrack(track)
        session.removeTrack(id: track.id)
        XCTAssertTrue(session.tracks.isEmpty)
    }

    func testUpdateTrack() {
        var session = Session(name: "Test")
        var track = Track(name: "Audio 1")
        session.addTrack(track)
        track.volume = 0.5
        session.updateTrack(track)
        XCTAssertEqual(session.tracks.first?.volume ?? 0, 0.5, accuracy: 0.01)
    }

    func testAddBioDataPoint() {
        var session = Session(name: "Bio")
        let point = BioDataPoint(
            timestamp: 1.0, hrv: 50.0, heartRate: 70.0,
            coherence: 0.6, audioLevel: 0.3, frequency: 440.0
        )
        session.addBioDataPoint(point)
        XCTAssertEqual(session.bioData.count, 1)
    }

    func testClearBioData() {
        var session = Session(name: "Bio")
        session.addBioDataPoint(BioDataPoint(
            timestamp: 0, hrv: 50, heartRate: 70,
            coherence: 0.5, audioLevel: 0.3, frequency: 440
        ))
        session.clearBioData()
        XCTAssertTrue(session.bioData.isEmpty)
    }

    func testAverageHRV() {
        var session = Session(name: "Stats")
        session.addBioDataPoint(BioDataPoint(
            timestamp: 0, hrv: 40, heartRate: 70,
            coherence: 0.5, audioLevel: 0.3, frequency: 440
        ))
        session.addBioDataPoint(BioDataPoint(
            timestamp: 1, hrv: 60, heartRate: 80,
            coherence: 0.7, audioLevel: 0.3, frequency: 440
        ))
        XCTAssertEqual(session.averageHRV, 50, accuracy: 0.01)
        XCTAssertEqual(session.averageHeartRate, 75, accuracy: 0.01)
        XCTAssertEqual(session.averageCoherence, 0.6, accuracy: 0.01)
    }

    func testCodable() throws {
        var session = Session(name: "Codable")
        session.addTrack(Track(name: "Track 1"))
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(session.id, decoded.id)
        XCTAssertEqual(session.name, decoded.name)
        XCTAssertEqual(session.tracks.count, decoded.tracks.count)
    }

    func testMeditationTemplate() {
        let session = Session.meditationTemplate()
        XCTAssertFalse(session.name.isEmpty)
        XCTAssertGreaterThan(session.tracks.count, 0)
    }

    func testRecoveryTemplate() {
        let session = Session.recoveryTemplate()
        XCTAssertFalse(session.name.isEmpty)
    }

    func testCreativeTemplate() {
        let session = Session.creativeTemplate()
        XCTAssertFalse(session.name.isEmpty)
    }
}

// MARK: - Recording Crash Hardening Tests

final class RecordingCrashHardeningTests: XCTestCase {

    func testAutomationLane_InterpolateEmptyPoints() {
        let param = AutomationParameter(name: "Volume", range: 0...1, defaultValue: 0.8)
        let lane = AutomationLane(parameter: param)
        // Empty points should return default, not crash
        XCTAssertEqual(lane.valueAt(time: 0.0), 0.8, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: 1.0), 0.8, accuracy: 0.01)
        XCTAssertEqual(lane.valueAt(time: -1.0), 0.8, accuracy: 0.01)
    }

    func testAutomationLane_NegativeTime() {
        let param = AutomationParameter(name: "Pan", range: -1...1, defaultValue: 0.0)
        var lane = AutomationLane(parameter: param)
        lane.addPoint(value: 0.5, at: 0.0)
        lane.addPoint(value: 1.0, at: 5.0)
        // Negative time should not crash
        let value = lane.valueAt(time: -10.0)
        XCTAssertFalse(value.isNaN, "Negative time should not produce NaN")
    }

    func testTrack_EmptyAutomation() {
        var track = Track(name: "Test", type: .audio)
        // Accessing automation on track with no lanes should not crash
        XCTAssertEqual(track.automationLanes.count, 0)
        track.volume = 0.5
        XCTAssertEqual(track.volume, 0.5, accuracy: 0.01)
    }

    func testSession_EmptyTracks() {
        let session = Session(name: "Empty", tracks: [])
        XCTAssertEqual(session.tracks.count, 0)
        XCTAssertFalse(session.name.isEmpty)
    }

    func testCircularBuffer_EmptyRead() {
        let buffer = CircularBuffer<Float>(capacity: 16)
        // Reading from empty buffer should return nil
        let sample = buffer.dequeue()
        XCTAssertNil(sample, "Empty circular buffer dequeue should return nil")
    }

    func testCircularBuffer_OverflowWrite() {
        let buffer = CircularBuffer<Float>(capacity: 4)
        // Writing more than capacity should wrap, not crash
        for i in 0..<100 {
            buffer.enqueue(Float(i))
        }
        // Should still be readable
        let sample = buffer.dequeue()
        XCTAssertNotNil(sample, "Overflowed buffer should still have data")
    }
}
#endif
