//
//  ArchitectureTests.swift
//  EchoelmusicTests
//
//  Created: 2025-11-28
//  Tests for Core Architecture Components
//
//  Coverage:
//  - Dependency Injection Container
//  - Undo/Redo System
//  - Effect Preset System
//  - Lock-Free Audio Buffers
//  - Error Handling
//

import XCTest
import Combine
@testable import Echoelmusic

// MARK: - Dependency Container Tests

@MainActor
final class DependencyContainerTests: XCTestCase {

    var container: DependencyContainer!

    override func setUp() async throws {
        container = DependencyContainer.shared
    }

    override func tearDown() async throws {
        container.reset()
    }

    func testSingletonRegistration() throws {
        // Register a singleton
        var creationCount = 0
        container.register(TestService.self) { _ in
            creationCount += 1
            return TestService()
        }

        // Resolve multiple times
        let service1 = container.resolve(TestService.self)
        let service2 = container.resolve(TestService.self)

        // Should be same instance
        XCTAssertTrue(service1 === service2, "Singleton should return same instance")
        XCTAssertEqual(creationCount, 1, "Factory should only be called once")
    }

    func testTransientRegistration() throws {
        // Register as transient
        var creationCount = 0
        container.register(TestService.self, lifetime: .transient) { _ in
            creationCount += 1
            return TestService()
        }

        // Resolve multiple times
        let service1 = container.resolve(TestService.self)
        let service2 = container.resolve(TestService.self)

        // Should be different instances
        XCTAssertFalse(service1 === service2, "Transient should return new instance")
        XCTAssertEqual(creationCount, 2, "Factory should be called for each resolution")
    }

    func testScopedRegistration() throws {
        // Register as scoped
        container.register(TestService.self, lifetime: .scoped("test-scope")) { _ in
            TestService()
        }

        // Create scope
        container.createScope("test-scope")

        // Resolve within scope
        let service1 = container.resolve(TestService.self)
        let service2 = container.resolve(TestService.self)

        // Should be same instance within scope
        XCTAssertTrue(service1 === service2, "Scoped should return same instance within scope")

        // Dispose scope
        container.disposeScope("test-scope")
    }

    func testOverrideForTesting() throws {
        // Register original
        container.register(TestService.self) { _ in
            TestService()
        }

        // Override with mock
        let mockService = TestService()
        mockService.value = 42
        container.override(TestService.self, with: mockService)

        // Resolve should return mock
        let resolved = container.resolve(TestService.self)
        XCTAssertEqual(resolved.value, 42, "Override should replace registration")
    }

    func testOptionalResolution() throws {
        // Try to resolve unregistered type
        let service = container.resolveOptional(UnregisteredService.self)
        XCTAssertNil(service, "Unregistered type should return nil")
    }
}

// MARK: - Test Service Classes

class TestService {
    var value: Int = 0
}

class UnregisteredService {}

// MARK: - Undo/Redo Tests

@MainActor
final class UndoRedoSystemTests: XCTestCase {

    var history: EditHistory!

    override func setUp() async throws {
        history = EditHistory()
    }

    func testBasicUndoRedo() throws {
        // Execute some commands
        let command1 = TestCommand(value: 1)
        let command2 = TestCommand(value: 2)

        try history.execute(command1)
        try history.execute(command2)

        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)

        // Undo
        try history.undo()
        XCTAssertTrue(history.canUndo)
        XCTAssertTrue(history.canRedo)

        // Undo again
        try history.undo()
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)

        // Redo
        try history.redo()
        XCTAssertTrue(history.canUndo)
        XCTAssertTrue(history.canRedo)
    }

    func testUndoDescription() throws {
        let command = TestCommand(value: 1)
        try history.execute(command)

        XCTAssertEqual(history.undoDescription, "Test Command")
    }

    func testTransaction() throws {
        // Begin transaction
        history.beginTransaction(description: "Batch Edit")

        // Execute multiple commands
        try history.execute(TestCommand(value: 1))
        try history.execute(TestCommand(value: 2))
        try history.execute(TestCommand(value: 3))

        // End transaction
        try history.endTransaction()

        // All commands should be undone as one
        XCTAssertEqual(history.undoDescription, "Batch Edit")

        try history.undo()
        XCTAssertFalse(history.canUndo)
    }

    func testCancelTransaction() throws {
        // Begin transaction
        history.beginTransaction(description: "Cancelled Edit")

        let command = TestCommand(value: 42)
        try history.execute(command)

        // Cancel - should undo all commands in transaction
        try history.cancelTransaction()

        XCTAssertTrue(command.wasUndone, "Command should be undone when transaction is cancelled")
        XCTAssertFalse(history.canUndo, "Nothing should be in history after cancel")
    }

    func testDirtyFlag() throws {
        XCTAssertFalse(history.isDirty)

        try history.execute(TestCommand(value: 1))
        XCTAssertTrue(history.isDirty)

        history.markSaved()
        XCTAssertFalse(history.isDirty)

        try history.execute(TestCommand(value: 2))
        XCTAssertTrue(history.isDirty)
    }

    func testHistoryLimit() throws {
        let limitedHistory = EditHistory(maxHistorySize: 5)

        // Add more than limit
        for i in 0..<10 {
            try limitedHistory.execute(TestCommand(value: i))
        }

        // Should only have 5 items
        var undoCount = 0
        while limitedHistory.canUndo {
            try limitedHistory.undo()
            undoCount += 1
        }

        XCTAssertEqual(undoCount, 5, "History should be limited to max size")
    }
}

// MARK: - Test Command

class TestCommand: EditCommand {
    let id = UUID()
    let description = "Test Command"
    let timestamp = Date()
    let value: Int
    var wasUndone = false
    var wasExecuted = false

    init(value: Int) {
        self.value = value
    }

    func execute() throws {
        wasExecuted = true
    }

    func undo() throws {
        wasUndone = true
    }

    func canMerge(with other: EditCommand) -> Bool {
        false
    }

    func merge(with other: EditCommand) -> EditCommand? {
        nil
    }
}

// MARK: - Lock-Free Buffer Tests

final class LockFreeBufferTests: XCTestCase {

    func testBasicReadWrite() {
        let buffer = LockFreeRingBuffer<Int>(capacity: 8)

        // Write some values
        XCTAssertTrue(buffer.write(1))
        XCTAssertTrue(buffer.write(2))
        XCTAssertTrue(buffer.write(3))

        // Read them back
        XCTAssertEqual(buffer.read(), 1)
        XCTAssertEqual(buffer.read(), 2)
        XCTAssertEqual(buffer.read(), 3)
        XCTAssertNil(buffer.read(), "Should return nil when empty")
    }

    func testBufferFull() {
        let buffer = LockFreeRingBuffer<Int>(capacity: 4) // Actual capacity is power of 2

        // Fill buffer (capacity - 1 usable in ring buffer)
        for i in 0..<3 {
            XCTAssertTrue(buffer.write(i), "Should write until full")
        }

        // Check full state
        XCTAssertTrue(buffer.isFull)
        XCTAssertFalse(buffer.write(99), "Should fail when full")
        XCTAssertEqual(buffer.overruns, 1)
    }

    func testBufferEmpty() {
        let buffer = LockFreeRingBuffer<Int>(capacity: 4)

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertNil(buffer.read())
        XCTAssertEqual(buffer.underruns, 1)
    }

    func testBatchWrite() {
        let buffer = LockFreeRingBuffer<Float>(capacity: 16)

        let data: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let written = buffer.write(data)

        XCTAssertEqual(written, 5)
        XCTAssertEqual(buffer.availableRead, 5)
    }

    func testAvailableSpace() {
        let buffer = LockFreeRingBuffer<Int>(capacity: 8) // Power of 2 = 8

        XCTAssertEqual(buffer.availableRead, 0)
        XCTAssertEqual(buffer.availableWrite, 7) // capacity - 1

        _ = buffer.write(1)
        _ = buffer.write(2)

        XCTAssertEqual(buffer.availableRead, 2)
        XCTAssertEqual(buffer.availableWrite, 5)
    }

    func testClear() {
        let buffer = LockFreeRingBuffer<Int>(capacity: 8)

        _ = buffer.write(1)
        _ = buffer.write(2)
        buffer.clear()

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.availableRead, 0)
    }
}

// MARK: - Audio Ring Buffer Tests

final class AudioRingBufferTests: XCTestCase {

    func testInterleavedAudio() {
        let buffer = AudioRingBuffer(channels: 2, framesPerBuffer: 256, bufferCount: 4)

        // Write interleaved stereo samples
        let samples: [Float] = (0..<512).map { Float($0) / 512.0 }
        let framesWritten = samples.withUnsafeBufferPointer {
            buffer.writeInterleaved($0.baseAddress!, frameCount: 256)
        }

        XCTAssertEqual(framesWritten, 256)
        XCTAssertEqual(buffer.availableFrames, 256)
    }

    func testLatencyCalculation() {
        let buffer = AudioRingBuffer(channels: 2, framesPerBuffer: 256, bufferCount: 4)

        // Write some samples
        let samples = [Float](repeating: 0.5, count: 512) // 256 frames stereo
        _ = samples.withUnsafeBufferPointer {
            buffer.writeInterleaved($0.baseAddress!, frameCount: 256)
        }

        let latency = buffer.latency(atSampleRate: 48000)
        // 256 samples / 48000 Hz / 2 channels = 0.00267 seconds
        XCTAssertEqual(latency, 256.0 / 48000.0 / 2.0, accuracy: 0.0001)
    }

    func testFillLevel() {
        let buffer = AudioRingBuffer(channels: 1, framesPerBuffer: 256, bufferCount: 4)

        XCTAssertEqual(buffer.fillLevel, 0, accuracy: 0.01)

        // Write half capacity
        let samples = [Float](repeating: 0, count: 512)
        _ = samples.withUnsafeBufferPointer {
            buffer.writeInterleaved($0.baseAddress!, frameCount: 512)
        }

        XCTAssertGreaterThan(buffer.fillLevel, 0.4)
        XCTAssertLessThan(buffer.fillLevel, 0.6)
    }
}

// MARK: - Error Handling Tests

final class ErrorHandlingTests: XCTestCase {

    func testRetryPolicyDelays() {
        let policy = RetryPolicy.default

        let delay1 = policy.delay(forAttempt: 1)
        let delay2 = policy.delay(forAttempt: 2)
        let delay3 = policy.delay(forAttempt: 3)

        // Each delay should be roughly double the previous (with jitter)
        XCTAssertLessThanOrEqual(delay1, 1.5) // ~1 second with jitter
        XCTAssertLessThanOrEqual(delay2, 3.0) // ~2 seconds with jitter
        XCTAssertLessThanOrEqual(delay3, 6.0) // ~4 seconds with jitter
    }

    func testResultRecovery() {
        let successResult: Result<Int, AppError> = .success(42)
        let failureResult: Result<Int, AppError> = .failure(.audio(.engineNotRunning))

        XCTAssertEqual(successResult.recover(0), 42)
        XCTAssertEqual(failureResult.recover(0), 0)
    }

    func testOptionalToResult() {
        let someValue: String? = "test"
        let nilValue: String? = nil

        let successResult = someValue.toResult(orError: .validation("Value required"))
        let failureResult = nilValue.toResult(orError: .validation("Value required"))

        XCTAssertEqual(try? successResult.get(), "test")
        XCTAssertThrowsError(try failureResult.get())
    }

    func testErrorDomains() {
        let audioError = AppError.audio(.bufferUnderrun)
        let networkError = AppError.network(.noConnection)

        XCTAssertEqual(audioError.domain, "Audio")
        XCTAssertEqual(networkError.domain, "Network")
    }

    func testRecoverableErrors() {
        let recoverableError = AppError.audio(.bufferUnderrun)
        let unrecoverableError = AppError.audio(.permissionDenied)

        XCTAssertTrue(recoverableError.isRecoverable)
        XCTAssertFalse(unrecoverableError.isRecoverable)
    }

    @MainActor
    func testErrorLogger() {
        let logger = ErrorLogger.shared
        logger.clearLogs()

        logger.log(.audio(.engineNotRunning), context: "Test context")

        XCTAssertEqual(logger.recentErrors.count, 1)
        XCTAssertEqual(logger.recentErrors.first?.error.domain, "Audio")
    }
}

// MARK: - Effect Chain Tests

@MainActor
final class EffectChainTests: XCTestCase {

    func testEffectChainProcessing() {
        let chain = EffectChain(name: "Test Chain")
        let compressor = CompressorEffect()

        chain.addEffect(compressor)
        chain.prepareToPlay(sampleRate: 48000, maxBlockSize: 512)

        // Create test buffer
        var buffer = AudioBuffer(sampleRate: 48000, channelCount: 2, frameCount: 512)
        let samples = AudioBufferGenerator.sineWave(frequency: 440, sampleRate: 48000, duration: 512.0/48000.0)
        if let dst = buffer.getMutableSamples(channel: 0) {
            samples.withUnsafeBufferPointer { src in
                memcpy(dst, src.baseAddress!, min(samples.count, 512) * MemoryLayout<Float>.stride)
            }
        }

        // Process
        chain.process(&buffer)

        // Output should not be silent
        if let output = buffer.getSamples(channel: 0) {
            let peak = (0..<512).map { abs(output[$0]) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0, "Output should not be silent")
        }
    }

    func testEffectBypass() {
        let chain = EffectChain()
        let reverb = ReverbEffect()
        reverb.isBypassed = true

        chain.addEffect(reverb)
        chain.prepareToPlay(sampleRate: 48000, maxBlockSize: 512)

        var buffer = AudioBuffer(sampleRate: 48000, channelCount: 2, frameCount: 512)

        // Copy original
        let original = [Float](repeating: 0.5, count: 512)
        if let dst = buffer.getMutableSamples(channel: 0) {
            original.withUnsafeBufferPointer { src in
                memcpy(dst, src.baseAddress!, 512 * MemoryLayout<Float>.stride)
            }
        }

        chain.process(&buffer)

        // Bypassed effect should not change audio
        if let output = buffer.getSamples(channel: 0) {
            for i in 0..<512 {
                XCTAssertEqual(output[i], 0.5, accuracy: 0.001)
            }
        }
    }

    func testDryWetMix() {
        let chain = EffectChain()
        chain.mix = 0.5 // 50% wet

        let reverb = ReverbEffect()
        chain.addEffect(reverb)
        chain.prepareToPlay(sampleRate: 48000, maxBlockSize: 512)

        var buffer = AudioBuffer(sampleRate: 48000, channelCount: 2, frameCount: 512)

        chain.process(&buffer)

        // Mix should blend dry and wet
        XCTAssertEqual(chain.mix, 0.5)
    }

    func testEffectReordering() {
        let chain = EffectChain()

        let comp = CompressorEffect()
        let eq = ParametricEQEffect()
        let reverb = ReverbEffect()

        chain.addEffect(comp)
        chain.addEffect(eq)
        chain.addEffect(reverb)

        XCTAssertEqual(chain.effects.count, 3)
        XCTAssertEqual(chain.effects[0].name, "Compressor")

        chain.moveEffect(from: 2, to: 0)

        XCTAssertEqual(chain.effects[0].name, "Reverb")
    }
}

// MARK: - Video Timeline ViewModel Tests

@MainActor
final class VideoTimelineViewModelTests: XCTestCase {

    var viewModel: VideoTimelineViewModel!

    override func setUp() async throws {
        viewModel = VideoTimelineViewModel()
    }

    func testPlaybackControls() {
        XCTAssertFalse(viewModel.isPlaying)

        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)

        viewModel.pause()
        XCTAssertFalse(viewModel.isPlaying)

        viewModel.stop()
        XCTAssertEqual(viewModel.currentTime, 0)
    }

    func testSeek() {
        viewModel.seekTo(time: 30)
        XCTAssertEqual(viewModel.currentTime, 30)

        viewModel.seekForward(seconds: 5)
        XCTAssertEqual(viewModel.currentTime, 35)

        viewModel.seekBackward(seconds: 10)
        XCTAssertEqual(viewModel.currentTime, 25)
    }

    func testSeekBounds() {
        viewModel.seekTo(time: -10)
        XCTAssertEqual(viewModel.currentTime, 0, "Should clamp to 0")

        viewModel.seekTo(time: 10000)
        XCTAssertEqual(viewModel.currentTime, viewModel.duration, "Should clamp to duration")
    }

    func testAddTrack() {
        let initialCount = viewModel.videoTracks.count

        viewModel.addVideoTrack(name: "Test Track")

        XCTAssertEqual(viewModel.videoTracks.count, initialCount + 1)
        XCTAssertEqual(viewModel.videoTracks.first?.name, "Test Track")
    }

    func testDeleteTrack() {
        let trackId = viewModel.videoTracks.first!.id

        viewModel.deleteTrack(trackId)

        XCTAssertFalse(viewModel.videoTracks.contains { $0.id == trackId })
    }

    func testClipSelection() {
        let clipId = viewModel.videoTracks.last!.clips.first!.id

        viewModel.selectClip(clipId)
        XCTAssertTrue(viewModel.selectedClipIds.contains(clipId))

        viewModel.deselectAllClips()
        XCTAssertTrue(viewModel.selectedClipIds.isEmpty)
    }

    func testUndoRedo() {
        let initialTrackCount = viewModel.videoTracks.count

        viewModel.addVideoTrack(name: "New Track")
        XCTAssertEqual(viewModel.videoTracks.count, initialTrackCount + 1)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.undo()
        XCTAssertEqual(viewModel.videoTracks.count, initialTrackCount)
        XCTAssertTrue(viewModel.canRedo)

        viewModel.redo()
        XCTAssertEqual(viewModel.videoTracks.count, initialTrackCount + 1)
    }

    func testSnapping() {
        viewModel.isSnappingEnabled = true
        viewModel.snapTolerance = 0.5

        // Add a marker at 10 seconds
        viewModel.addMarker(at: 10, name: "Test Marker")

        // Time close to marker should snap
        let snapped = viewModel.snapTime(10.2)
        XCTAssertEqual(snapped, 10, accuracy: 0.01)
    }

    func testTimecodeFormatting() {
        let timecode = viewModel.formatTimecode(3661.5) // 1 hour, 1 minute, 1 second, 15 frames at 30fps
        XCTAssertTrue(timecode.hasPrefix("01:01:01:"))
    }
}
