// QuantumPlatformTests.swift
// Echoelmusic - Quantum Platform Tests
// SPDX-License-Identifier: MIT

import XCTest
@testable import Echoelmusic

final class QuantumPlatformTests: XCTestCase {

    // MARK: - Platform Detection Tests

    func testPlatformDetection() {
        let platform = Platform.current
        XCTAssertNotEqual(platform, .unknown, "Platform should be detected")
    }

    func testPlatformCapabilities() {
        let platform = Platform.current
        XCTAssertGreaterThan(platform.maxAudioChannels, 0, "Should support at least 1 audio channel")
    }

    // MARK: - Safe Unwrap Tests

    func testSafeUnwrapWithDefault() {
        let optional: String? = nil
        let result = SafeUnwrap.unwrap(optional, default: "default")
        XCTAssertEqual(result, "default")

        let optionalWithValue: String? = "value"
        let resultWithValue = SafeUnwrap.unwrap(optionalWithValue, default: "default")
        XCTAssertEqual(resultWithValue, "value")
    }

    func testSafeUnwrapWithError() {
        let optional: String? = nil
        XCTAssertThrowsError(try SafeUnwrap.unwrap(optional, or: EchoelError.validation("nil")))

        let optionalWithValue: String? = "value"
        XCTAssertNoThrow(try SafeUnwrap.unwrap(optionalWithValue, or: EchoelError.validation("nil")))
    }

    func testSafeElementAccess() {
        let array = [1, 2, 3, 4, 5]
        XCTAssertEqual(SafeUnwrap.element(at: 2, in: array, default: 0), 3)
        XCTAssertEqual(SafeUnwrap.element(at: 10, in: array, default: 0), 0)
        XCTAssertEqual(SafeUnwrap.element(at: -1, in: array, default: 0), 0)
    }

    func testSafeDictionaryAccess() {
        let dict = ["a": 1, "b": 2]
        XCTAssertEqual(SafeUnwrap.value(for: "a", in: dict, default: 0), 1)
        XCTAssertEqual(SafeUnwrap.value(for: "c", in: dict, default: 0), 0)
    }

    // MARK: - Optional Extension Tests

    func testOptionalSafely() {
        let optional: Int? = nil
        XCTAssertEqual(optional.safely(42), 42)

        let optionalWithValue: Int? = 10
        XCTAssertEqual(optionalWithValue.safely(42), 10)
    }

    func testOptionalSafelyThrow() {
        let optional: Int? = nil
        XCTAssertThrowsError(try optional.safelyThrow(EchoelError.validation("nil")))

        let optionalWithValue: Int? = 10
        XCTAssertEqual(try optionalWithValue.safelyThrow(EchoelError.validation("nil")), 10)
    }

    func testOptionalMapOr() {
        let optional: Int? = nil
        XCTAssertEqual(optional.mapOr({ $0 * 2 }, default: 0), 0)

        let optionalWithValue: Int? = 5
        XCTAssertEqual(optionalWithValue.mapOr({ $0 * 2 }, default: 0), 10)
    }

    // MARK: - Collection Extension Tests

    func testSafeSubscript() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 1], 2)
        XCTAssertNil(array[safe: 10])
        XCTAssertNil(array[safe: -1])
    }

    func testSafeSubscriptWithDefault() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 1, default: 0], 2)
        XCTAssertEqual(array[safe: 10, default: 0], 0)
    }

    func testFirstSafe() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.firstSafe(default: 0), 1)

        let emptyArray: [Int] = []
        XCTAssertEqual(emptyArray.firstSafe(default: 0), 0)
    }

    func testLastSafe() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.lastSafe(default: 0), 3)

        let emptyArray: [Int] = []
        XCTAssertEqual(emptyArray.lastSafe(default: 0), 0)
    }

    func testSafeRemove() {
        var array = [1, 2, 3]
        XCTAssertEqual(array.safeRemove(at: 1), 2)
        XCTAssertEqual(array, [1, 3])
        XCTAssertNil(array.safeRemove(at: 10))
    }

    // MARK: - Quantum Color Tests

    func testQuantumColorInitialization() {
        let color = QuantumColor(red: 0.5, green: 0.3, blue: 0.8)
        XCTAssertEqual(color.red, 0.5)
        XCTAssertEqual(color.green, 0.3)
        XCTAssertEqual(color.blue, 0.8)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testQuantumColorClamping() {
        let color = QuantumColor(red: 1.5, green: -0.5, blue: 0.5)
        XCTAssertEqual(color.red, 1.0) // Clamped to 1
        XCTAssertEqual(color.green, 0.0) // Clamped to 0
        XCTAssertEqual(color.blue, 0.5)
    }

    func testQuantumColorFromHex() {
        let color = QuantumColor(hex: "#FF0000")
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 0.0, accuracy: 0.01)
    }

    // MARK: - Quantum Point Tests

    func testQuantumPointDistance() {
        let p1 = QuantumPoint(x: 0, y: 0)
        let p2 = QuantumPoint(x: 3, y: 4)
        XCTAssertEqual(p1.distance(to: p2), 5.0, accuracy: 0.0001)
    }

    func testQuantumPoint3DMagnitude() {
        let point = QuantumPoint3D(x: 1, y: 2, z: 2)
        XCTAssertEqual(point.magnitude, 3.0, accuracy: 0.0001)
    }

    func testQuantumPoint3DNormalized() {
        let point = QuantumPoint3D(x: 0, y: 3, z: 4)
        let normalized = point.normalized
        XCTAssertEqual(normalized.magnitude, 1.0, accuracy: 0.0001)
    }

    // MARK: - Numeric Clamping Tests

    func testClamped() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
        XCTAssertEqual(15.clamped(to: 0...10), 10)
        XCTAssertEqual((-5).clamped(to: 0...10), 0)
    }

    func testNormalized() {
        XCTAssertEqual(0.5.normalized, 0.5)
        XCTAssertEqual(1.5.normalized, 1.0)
        XCTAssertEqual((-0.5).normalized, 0.0)
    }

    func testLerp() {
        XCTAssertEqual(0.0.lerp(to: 10.0, t: 0.5), 5.0, accuracy: 0.0001)
        XCTAssertEqual(0.0.lerp(to: 10.0, t: 0.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(0.0.lerp(to: 10.0, t: 1.0), 10.0, accuracy: 0.0001)
    }

    // MARK: - Safe Cast Tests

    func testSafeNumericCast() {
        let int32: Int32 = 100
        let int64: Int64? = SafeCast.numeric(int32)
        XCTAssertEqual(int64, 100)

        let largeInt64: Int64 = Int64.max
        let int8: Int8? = SafeCast.numeric(largeInt64)
        XCTAssertNil(int8) // Overflow returns nil
    }

    func testSafeCastWithDefault() {
        let value: Any = "hello"
        let result = SafeCast.cast(value, to: String.self, default: "default")
        XCTAssertEqual(result, "hello")

        let wrongType: Any = 42
        let resultWrong = SafeCast.cast(wrongType, to: String.self, default: "default")
        XCTAssertEqual(resultWrong, "default")
    }
}

// MARK: - Thread-Safe Actor Tests

final class ThreadSafeActorTests: XCTestCase {

    // MARK: - Quantum State Tests

    func testQuantumStateGetSet() async {
        let state = QuantumState<Int>(0)
        await state.set(42)
        let value = await state.get()
        XCTAssertEqual(value, 42)
    }

    func testQuantumStateUpdate() async {
        let state = QuantumState<Int>(10)
        await state.update { $0 += 5 }
        let value = await state.get()
        XCTAssertEqual(value, 15)
    }

    func testQuantumStateCompareAndSwap() async {
        let state = QuantumState<Int>(10)

        let success = await state.compareAndSwap(expected: 10, new: 20)
        XCTAssertTrue(success)
        XCTAssertEqual(await state.get(), 20)

        let failure = await state.compareAndSwap(expected: 10, new: 30)
        XCTAssertFalse(failure)
        XCTAssertEqual(await state.get(), 20)
    }

    // MARK: - Audio Engine Actor Tests

    func testAudioEngineActorDefaults() async {
        let actor = AudioEngineActor()
        let state = await actor.getState()

        XCTAssertFalse(state.isRunning)
        XCTAssertEqual(state.sampleRate, 44100)
        XCTAssertEqual(state.bufferSize, 512)
    }

    func testAudioEngineActorSetSampleRate() async {
        let actor = AudioEngineActor()
        await actor.setSampleRate(48000)
        XCTAssertEqual(await actor.getSampleRate(), 48000)

        // Invalid sample rate should be ignored
        await actor.setSampleRate(12345)
        XCTAssertEqual(await actor.getSampleRate(), 48000)
    }

    func testAudioEngineActorSetBufferSize() async {
        let actor = AudioEngineActor()
        await actor.setBufferSize(1024)
        XCTAssertEqual(await actor.getBufferSize(), 1024)

        // Invalid buffer size should be ignored
        await actor.setBufferSize(999)
        XCTAssertEqual(await actor.getBufferSize(), 1024)
    }

    // MARK: - MIDI Engine Actor Tests

    func testMIDIEngineActorNotes() async {
        let actor = MIDIEngineActor()

        await actor.noteOn(60, velocity: 100)
        var notes = await actor.getActiveNotes()
        XCTAssertTrue(notes.contains(60))

        await actor.noteOff(60)
        notes = await actor.getActiveNotes()
        XCTAssertFalse(notes.contains(60))
    }

    func testMIDIEngineActorControlChange() async {
        let actor = MIDIEngineActor()

        await actor.controlChange(1, value: 64) // Modulation wheel
        XCTAssertEqual(await actor.getControlValue(1), 64)

        await actor.controlChange(7, value: 100) // Volume
        XCTAssertEqual(await actor.getControlValue(7), 100)
    }

    func testMIDIEngineActorPitchBend() async {
        let actor = MIDIEngineActor()

        await actor.pitchBend(12000)
        XCTAssertEqual(await actor.getPitchBend(), 12000)

        // Test clamping
        await actor.pitchBend(20000)
        XCTAssertEqual(await actor.getPitchBend(), 16383)
    }

    // MARK: - Session Actor Tests

    func testSessionActorTransportControls() async {
        let actor = SessionActor()

        await actor.startRecording()
        XCTAssertTrue(await actor.isRecording())

        await actor.stopRecording()
        XCTAssertFalse(await actor.isRecording())

        await actor.startPlayback()
        XCTAssertTrue(await actor.isPlaying())

        await actor.stopPlayback()
        XCTAssertFalse(await actor.isPlaying())
    }

    func testSessionActorTempo() async {
        let actor = SessionActor()

        await actor.setTempo(140)
        XCTAssertEqual(await actor.getTempo(), 140)

        // Invalid tempo should be ignored
        await actor.setTempo(500)
        XCTAssertEqual(await actor.getTempo(), 140)
    }

    func testSessionActorUndo() async {
        let actor = SessionActor()

        await actor.setTempo(120)
        await actor.setTempo(140)

        let undone = await actor.undo()
        XCTAssertTrue(undone)
        XCTAssertEqual(await actor.getTempo(), 120)
    }
}

// MARK: - Quantum Validation Tests

final class QuantumValidationTests: XCTestCase {

    var validator: QuantumValidator!

    override func setUp() {
        super.setUp()
        validator = QuantumValidator()
    }

    func testMIDIValidation() async {
        let validResult = await validator.validateMIDI(64)
        XCTAssertTrue(validResult.isValid)

        let invalidLow = await validator.validateMIDI(-1)
        XCTAssertFalse(invalidLow.isValid)

        let invalidHigh = await validator.validateMIDI(200)
        XCTAssertFalse(invalidHigh.isValid)
    }

    func testAudioLevelValidation() async {
        let validResult = await validator.validateAudioLevel(0.5)
        XCTAssertTrue(validResult.isValid)

        let invalidNegative = await validator.validateAudioLevel(-0.1)
        XCTAssertFalse(invalidNegative.isValid)

        let invalidHigh = await validator.validateAudioLevel(1.5)
        XCTAssertFalse(invalidHigh.isValid)
    }

    func testFrequencyValidation() async {
        let validResult = await validator.validateFrequency(440)
        XCTAssertTrue(validResult.isValid)

        let invalidLow = await validator.validateFrequency(10) // Below audible
        XCTAssertFalse(invalidLow.isValid)

        let extendedValid = await validator.validateFrequency(10, extended: true)
        XCTAssertTrue(extendedValid.isValid)
    }

    func testSpatialPositionValidation() async {
        let validResult = await validator.validateSpatialPosition(
            QuantumPoint3D(x: 0.5, y: -0.5, z: 0.0)
        )
        XCTAssertTrue(validResult.isValid)

        let invalidResult = await validator.validateSpatialPosition(
            QuantumPoint3D(x: 2.0, y: 0.0, z: 0.0)
        )
        XCTAssertFalse(invalidResult.isValid)
    }

    func testBPMValidation() async {
        let validResult = await validator.validateBPM(120)
        XCTAssertTrue(validResult.isValid)

        let invalidLow = await validator.validateBPM(10)
        XCTAssertFalse(invalidLow.isValid)

        let invalidHigh = await validator.validateBPM(500)
        XCTAssertFalse(invalidHigh.isValid)
    }
}

// MARK: - Helper Error for Testing

enum EchoelError: Error {
    case validation(String)
}
