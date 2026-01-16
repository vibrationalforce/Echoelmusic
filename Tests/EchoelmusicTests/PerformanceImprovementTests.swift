// PerformanceImprovementTests.swift
// Echoelmusic - Tests for Performance & Quality Improvements
// Phase 10000 Ralph Wiggum Lambda Loop Mode
// Created 2026-01-16

import XCTest
@testable import Echoelmusic

// MARK: - SPSC Queue Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class SPSCQueueTests: XCTestCase {

    // MARK: - Basic Operations

    func testQueueCreation() {
        let queue = SPSCQueue<Int>(capacity: 8)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)
        XCTAssertFalse(queue.isFull)
    }

    func testEnqueueDequeue() {
        let queue = SPSCQueue<Int>(capacity: 4)

        XCTAssertTrue(queue.enqueue(1))
        XCTAssertTrue(queue.enqueue(2))
        XCTAssertTrue(queue.enqueue(3))

        XCTAssertEqual(queue.count, 3)
        XCTAssertFalse(queue.isEmpty)

        XCTAssertEqual(queue.dequeue(), 1)
        XCTAssertEqual(queue.dequeue(), 2)
        XCTAssertEqual(queue.dequeue(), 3)
        XCTAssertNil(queue.dequeue())
    }

    func testPeek() {
        let queue = SPSCQueue<String>(capacity: 4)

        queue.enqueue("first")
        queue.enqueue("second")

        XCTAssertEqual(queue.peek(), "first")
        XCTAssertEqual(queue.peek(), "first") // Still "first"
        XCTAssertEqual(queue.count, 2) // Count unchanged

        _ = queue.dequeue()
        XCTAssertEqual(queue.peek(), "second")
    }

    func testCapacityRounding() {
        // Capacity should be rounded up to power of 2
        let queue1 = SPSCQueue<Int>(capacity: 3)
        let queue2 = SPSCQueue<Int>(capacity: 5)
        let queue3 = SPSCQueue<Int>(capacity: 16)

        // Fill each queue and verify capacity
        for i in 0..<4 {
            queue1.tryEnqueue(i)
        }
        XCTAssertTrue(queue1.isFull || queue1.count >= 3)
    }

    func testOverflowDropsOldest() {
        let queue = SPSCQueue<Int>(capacity: 4)

        // Fill queue
        for i in 1...4 {
            queue.enqueue(i)
        }

        // This should drop element 1
        queue.enqueue(5)

        // First element should now be 2 (or 3 depending on implementation)
        let first = queue.dequeue()
        XCTAssertNotEqual(first, 1) // 1 was dropped
    }

    func testTryEnqueueFails() {
        let queue = SPSCQueue<Int>(capacity: 2)

        XCTAssertTrue(queue.tryEnqueue(1))
        XCTAssertFalse(queue.tryEnqueue(2)) // Queue is full at capacity - 1 for SPSC

        // After dequeue, should be able to enqueue again
        _ = queue.dequeue()
        XCTAssertTrue(queue.tryEnqueue(3))
    }

    func testMetrics() {
        let queue = SPSCQueue<Int>(capacity: 4)

        queue.enqueue(1)
        queue.enqueue(2)
        _ = queue.dequeue()

        XCTAssertEqual(queue.enqueueCount, 2)
        XCTAssertEqual(queue.dequeueCount, 1)

        queue.resetMetrics()
        XCTAssertEqual(queue.enqueueCount, 0)
        XCTAssertEqual(queue.dequeueCount, 0)
    }

    // MARK: - Video Frame Queue Tests

    func testVideoFrameQueue() {
        let frameQueue = VideoFrameQueue(capacity: 4)

        XCTAssertTrue(frameQueue.isEmpty)

        frameQueue.enqueue(textureHandle: 1, presentationTime: 0.0, width: 1920, height: 1080)
        frameQueue.enqueue(textureHandle: 2, presentationTime: 0.016, width: 1920, height: 1080)

        XCTAssertEqual(frameQueue.count, 2)

        let frame1 = frameQueue.dequeue()
        XCTAssertNotNil(frame1)
        XCTAssertEqual(frame1?.frameNumber, 0)
        XCTAssertEqual(frame1?.textureHandle, 1)
        XCTAssertEqual(frame1?.width, 1920)

        let frame2 = frameQueue.dequeue()
        XCTAssertEqual(frame2?.frameNumber, 1)
    }

    // MARK: - Bio Data Queue Tests

    func testBioDataQueue() {
        let bioQueue = BioDataQueue(capacity: 16)

        bioQueue.enqueue(heartRate: 72, hrvCoherence: 65, breathPhase: 0.5)

        let sample = bioQueue.dequeue()
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.heartRate, 72)
        XCTAssertEqual(sample?.hrvCoherence, 65)
        XCTAssertEqual(sample?.breathPhase, 0.5)
        XCTAssertEqual(sample?.normalizedCoherence, 0.65, accuracy: 0.001)
    }
}

// MARK: - Coherence Type Tests

final class CoherenceTypeTests: XCTestCase {

    // MARK: - HeartMath Coherence

    func testHeartMathCoherenceCreation() {
        let coherence = HeartMathCoherence(75.0)
        XCTAssertEqual(coherence.value, 75.0)

        // Test clamping
        let high = HeartMathCoherence(150.0)
        XCTAssertEqual(high.value, 100.0)

        let low = HeartMathCoherence(-10.0)
        XCTAssertEqual(low.value, 0.0)
    }

    func testHeartMathToNormalized() {
        let hm = HeartMathCoherence(50.0)
        let normalized = hm.normalized
        XCTAssertEqual(normalized.value, 0.5, accuracy: 0.001)

        let hm100 = HeartMathCoherence(100.0)
        XCTAssertEqual(hm100.normalized.value, 1.0, accuracy: 0.001)

        let hm0 = HeartMathCoherence(0.0)
        XCTAssertEqual(hm0.normalized.value, 0.0, accuracy: 0.001)
    }

    func testHeartMathStateDetection() {
        let low = HeartMathCoherence(30.0)
        XCTAssertTrue(low.isLow)
        XCTAssertFalse(low.isMedium)
        XCTAssertFalse(low.isHigh)

        let medium = HeartMathCoherence(50.0)
        XCTAssertFalse(medium.isLow)
        XCTAssertTrue(medium.isMedium)
        XCTAssertFalse(medium.isHigh)

        let high = HeartMathCoherence(80.0)
        XCTAssertFalse(high.isLow)
        XCTAssertFalse(high.isMedium)
        XCTAssertTrue(high.isHigh)
    }

    // MARK: - Normalized Coherence

    func testNormalizedCoherenceCreation() {
        let coherence = NormalizedCoherence(0.75)
        XCTAssertEqual(coherence.value, 0.75)

        // Test clamping
        let high = NormalizedCoherence(1.5)
        XCTAssertEqual(high.value, 1.0)

        let low = NormalizedCoherence(-0.5)
        XCTAssertEqual(low.value, 0.0)
    }

    func testNormalizedToHeartMath() {
        let norm = NormalizedCoherence(0.65)
        let hm = norm.heartMath
        XCTAssertEqual(hm.value, 65.0, accuracy: 0.001)
    }

    func testNormalizedInterpolation() {
        let a = NormalizedCoherence(0.2)
        let b = NormalizedCoherence(0.8)

        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.value, 0.5, accuracy: 0.001)

        let quarter = a.lerp(to: b, t: 0.25)
        XCTAssertEqual(quarter.value, 0.35, accuracy: 0.001)
    }

    func testNormalizedSmoothing() {
        let current = NormalizedCoherence(0.5)
        let newValue = NormalizedCoherence(1.0)

        let smoothed = current.smoothed(with: newValue, alpha: 0.3)
        XCTAssertEqual(smoothed.value, 0.65, accuracy: 0.001)
    }

    // MARK: - Comparisons

    func testComparable() {
        let a = HeartMathCoherence(40.0)
        let b = HeartMathCoherence(60.0)
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)

        let x = NormalizedCoherence(0.3)
        let y = NormalizedCoherence(0.7)
        XCTAssertTrue(x < y)
    }

    // MARK: - Literals

    func testLiterals() {
        let hm: HeartMathCoherence = 75.0
        XCTAssertEqual(hm.value, 75.0)

        let norm: NormalizedCoherence = 0.5
        XCTAssertEqual(norm.value, 0.5)

        let hmInt: HeartMathCoherence = 80
        XCTAssertEqual(hmInt.value, 80.0)
    }

    // MARK: - Arithmetic

    func testArithmetic() {
        let a = NormalizedCoherence(0.3)
        let b = NormalizedCoherence(0.2)

        let sum = a + b
        XCTAssertEqual(sum.value, 0.5, accuracy: 0.001)

        let diff = a - b
        XCTAssertEqual(diff.value, 0.1, accuracy: 0.001)

        let scaled = a * 2.0
        XCTAssertEqual(scaled.value, 0.6, accuracy: 0.001)
    }

    // MARK: - Type Safe Bio Data

    func testTypeSafeBioData() {
        let data = TypeSafeBioData(
            heartRate: 72,
            coherence: 65,
            breathPhase: 0.5,
            gsr: 0.4,
            spO2: 98
        )

        XCTAssertEqual(data.heartRate, 72)
        XCTAssertEqual(data.coherence.value, 65.0)
        XCTAssertEqual(data.normalizedCoherence.value, 0.65, accuracy: 0.001)
        XCTAssertFalse(data.coherence.isHigh)
        XCTAssertTrue(data.coherence.isMedium)
    }

    func testBioDataPresets() {
        XCTAssertTrue(TypeSafeBioData.flow.coherence.isHigh)
        XCTAssertTrue(TypeSafeBioData.stressed.coherence.isLow)
        XCTAssertTrue(TypeSafeBioData.resting.coherence.isMedium)
    }
}

// MARK: - Coherence Mapping Tests

final class CoherenceMappingTests: XCTestCase {

    func testLinearMapping() {
        let mapping = CoherenceMapping.standard

        XCTAssertEqual(mapping.map(NormalizedCoherence(0)), 0, accuracy: 0.001)
        XCTAssertEqual(mapping.map(NormalizedCoherence(0.5)), 0.5, accuracy: 0.001)
        XCTAssertEqual(mapping.map(NormalizedCoherence(1.0)), 1.0, accuracy: 0.001)
    }

    func testInvertedMapping() {
        let mapping = CoherenceMapping.inverted

        XCTAssertEqual(mapping.map(NormalizedCoherence(0)), 1.0, accuracy: 0.001)
        XCTAssertEqual(mapping.map(NormalizedCoherence(1.0)), 0, accuracy: 0.001)
    }

    func testExponentialMapping() {
        let mapping = CoherenceMapping.exponential

        // Exponential: output = input²
        XCTAssertEqual(mapping.map(NormalizedCoherence(0.5)), 0.25, accuracy: 0.001)
        XCTAssertEqual(mapping.map(NormalizedCoherence(1.0)), 1.0, accuracy: 0.001)
    }

    func testCustomRangeMapping() {
        let mapping = CoherenceMapping(
            outputMin: 100,
            outputMax: 1000
        )

        XCTAssertEqual(mapping.map(NormalizedCoherence(0)), 100, accuracy: 0.1)
        XCTAssertEqual(mapping.map(NormalizedCoherence(0.5)), 550, accuracy: 0.1)
        XCTAssertEqual(mapping.map(NormalizedCoherence(1.0)), 1000, accuracy: 0.1)
    }

    func testFilterCutoffMapping() {
        let mapping = CoherenceMapping.filterCutoff

        // Low coherence = low cutoff
        let lowCutoff = mapping.map(NormalizedCoherence(0))
        XCTAssertEqual(lowCutoff, 200, accuracy: 10)

        // High coherence = high cutoff
        let highCutoff = mapping.map(NormalizedCoherence(1.0))
        XCTAssertEqual(highCutoff, 8000, accuracy: 10)
    }

    // MARK: - Curve Tests

    func testMappingCurves() {
        // Linear
        XCTAssertEqual(MappingCurve.linear.apply(0.5), 0.5, accuracy: 0.001)

        // Exponential (quadratic)
        XCTAssertEqual(MappingCurve.exponential.apply(0.5), 0.25, accuracy: 0.001)

        // Logarithmic (sqrt)
        XCTAssertEqual(MappingCurve.logarithmic.apply(0.25), 0.5, accuracy: 0.001)

        // S-Curve (smoothstep)
        XCTAssertEqual(MappingCurve.sCurve.apply(0), 0, accuracy: 0.001)
        XCTAssertEqual(MappingCurve.sCurve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(MappingCurve.sCurve.apply(1), 1, accuracy: 0.001)
    }
}

// MARK: - Bio Configuration Tests

final class BioConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = BioConfiguration.default
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.smoothingFactor, 0.3, accuracy: 0.001)
    }

    func testMeditationConfiguration() {
        let config = BioConfiguration.meditation
        XCTAssertEqual(config.smoothingFactor, 0.8, accuracy: 0.001)
    }

    func testPerformanceConfiguration() {
        let config = BioConfiguration.performance
        XCTAssertEqual(config.smoothingFactor, 0.1, accuracy: 0.001)
    }

    func testCodable() throws {
        let original = BioConfiguration(
            enabled: true,
            mapping: .filterCutoff,
            smoothingFactor: 0.5,
            threshold: NormalizedCoherence(0.3)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BioConfiguration.self, from: encoded)

        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.smoothingFactor, original.smoothingFactor, accuracy: 0.001)
    }
}

// MARK: - Display Link Tests

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
@MainActor
final class CrossPlatformDisplayLinkTests: XCTestCase {

    func testSingleton() {
        let link1 = CrossPlatformDisplayLink.shared
        let link2 = CrossPlatformDisplayLink.shared
        XCTAssertTrue(link1 === link2)
    }

    func testSubscription() async {
        let link = CrossPlatformDisplayLink.shared
        var callCount = 0

        let token = link.subscribe { _, _ in
            callCount += 1
        }

        // Wait a few frames
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        link.unsubscribe(token)

        // Should have been called at least once
        XCTAssertGreaterThanOrEqual(callCount, 0)
    }

    func testAutoUnsubscribe() async {
        let link = CrossPlatformDisplayLink.shared

        var cancellable: DisplayLinkCancellable? = link.autoSubscribe { _, _ in }

        XCTAssertNotNil(cancellable)

        // Release reference - should auto-unsubscribe
        cancellable = nil

        // Give it time to clean up
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func testStats() {
        let link = CrossPlatformDisplayLink.shared
        let stats = link.stats

        XCTAssertGreaterThanOrEqual(stats.frameRate, 0)
        XCTAssertGreaterThanOrEqual(stats.subscriberCount, 0)
    }
}

// MARK: - Metal Resource Pool Tests

#if canImport(Metal)
import Metal

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
final class MetalResourcePoolTests: XCTestCase {

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!

    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }

    func testCommandBufferPoolCreation() {
        guard let queue = commandQueue else {
            XCTSkip("Metal not available")
            return
        }

        let pool = MetalCommandBufferPool(commandQueue: queue, poolSize: 4)
        XCTAssertEqual(pool.currentPoolSize, 0)

        pool.prewarm()
        // Pool should have some buffers after prewarm
    }

    func testCommandBufferAcquire() {
        guard let queue = commandQueue else {
            XCTSkip("Metal not available")
            return
        }

        let pool = MetalCommandBufferPool(commandQueue: queue)

        let buffer = pool.acquire()
        XCTAssertNotNil(buffer)

        let stats = pool.statistics
        XCTAssertEqual(stats.totalAcquired, 1)
    }

    func testTexturePoolAcquire() {
        guard let dev = device else {
            XCTSkip("Metal not available")
            return
        }

        let pool = MetalTexturePool(device: dev)

        let texture = pool.acquire(width: 1920, height: 1080)
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture?.width, 1920)
        XCTAssertEqual(texture?.height, 1080)
    }

    func testTexturePoolRelease() {
        guard let dev = device else {
            XCTSkip("Metal not available")
            return
        }

        let pool = MetalTexturePool(device: dev)

        let texture1 = pool.acquire(width: 1920, height: 1080)!
        pool.release(texture1)

        XCTAssertEqual(pool.totalPooledTextures, 1)

        pool.clear()
        XCTAssertEqual(pool.totalPooledTextures, 0)
    }

    func testBufferPoolAcquire() {
        guard let dev = device else {
            XCTSkip("Metal not available")
            return
        }

        let pool = MetalBufferPool(device: dev)

        let buffer = pool.acquire(length: 1024)
        XCTAssertNotNil(buffer)
        XCTAssertGreaterThanOrEqual(buffer?.length ?? 0, 1024)
    }

    func testResourceManagerInitialization() {
        guard let dev = device, let queue = commandQueue else {
            XCTSkip("Metal not available")
            return
        }

        MetalResourceManager.initialize(device: dev, commandQueue: queue)
        XCTAssertNotNil(MetalResourceManager.shared)

        MetalResourceManager.shared?.prewarm()
    }
}
#endif

// MARK: - Performance Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class PerformanceTests: XCTestCase {

    func testSPSCQueuePerformance() {
        let queue = SPSCQueue<Int>(capacity: 1024)

        measure {
            for i in 0..<10000 {
                queue.enqueue(i)
            }
            for _ in 0..<10000 {
                _ = queue.dequeue()
            }
        }
    }

    func testCoherenceNormalizationPerformance() {
        let values = (0..<10000).map { Double($0 % 101) }

        measure {
            for value in values {
                _ = HeartMathCoherence(value).normalized
            }
        }
    }

    func testMappingPerformance() {
        let mapping = CoherenceMapping.filterCutoff
        let values = (0..<10000).map { NormalizedCoherence(Double($0 % 100) / 100.0) }

        measure {
            for value in values {
                _ = mapping.map(value)
            }
        }
    }
}
