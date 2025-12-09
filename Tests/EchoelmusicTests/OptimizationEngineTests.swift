import XCTest
import Accelerate
import simd
@testable import Echoelmusic

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION ENGINE TEST SUITE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive tests for all optimization systems:
// • UltraMath SIMD operations
// • Memory pools and buffers
// • DSP optimizations (convolution, biquad, envelope)
// • Streaming optimizations (ring buffer, layer cache)
// • Performance benchmarks
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class OptimizationEngineTests: XCTestCase {

    // MARK: - UltraMath SIMD Tests

    func testUltraMathSinCos() {
        var input = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            input[i] = Float(i) * 0.01
        }

        var sinResult = input
        var cosResult = input

        UltraMath.sin(&sinResult)
        UltraMath.cos(&cosResult)

        // Verify against standard library
        for i in 0..<1024 {
            XCTAssertEqual(sinResult[i], Foundation.sin(input[i]), accuracy: 0.0001,
                          "SIMD sin should match Foundation.sin at index \(i)")
            XCTAssertEqual(cosResult[i], Foundation.cos(input[i]), accuracy: 0.0001,
                          "SIMD cos should match Foundation.cos at index \(i)")
        }
    }

    func testUltraMathExpLog() {
        var input: [Float] = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0]

        var expResult = input
        UltraMath.exp(&expResult)

        for (i, val) in input.enumerated() {
            XCTAssertEqual(expResult[i], Foundation.exp(val), accuracy: 0.001,
                          "SIMD exp should match Foundation.exp")
        }

        var logInput: [Float] = [1.0, 2.0, 10.0, 100.0]
        var logResult = logInput
        UltraMath.log(&logResult)

        for (i, val) in logInput.enumerated() {
            XCTAssertEqual(logResult[i], Foundation.log(val), accuracy: 0.001,
                          "SIMD log should match Foundation.log")
        }
    }

    func testUltraMathSqrt() {
        var input: [Float] = [1, 4, 9, 16, 25, 100, 144]
        var result = input

        UltraMath.sqrt(&result)

        let expected: [Float] = [1, 2, 3, 4, 5, 10, 12]
        for i in 0..<input.count {
            XCTAssertEqual(result[i], expected[i], accuracy: 0.0001,
                          "SIMD sqrt should be accurate")
        }
    }

    func testUltraMathTanh() {
        var input: [Float] = [-2, -1, -0.5, 0, 0.5, 1, 2]
        var result = input

        UltraMath.tanh(&result)

        for (i, val) in input.enumerated() {
            XCTAssertEqual(result[i], Foundation.tanh(val), accuracy: 0.0001,
                          "SIMD tanh should match Foundation.tanh")
        }
    }

    func testUltraMathVariance() {
        let data: [Float] = [2, 4, 4, 4, 5, 5, 7, 9]
        let variance = data.withUnsafeBufferPointer { buffer in
            UltraMath.variance(buffer.baseAddress!, count: buffer.count)
        }

        // Expected variance: 4.0 (population variance)
        XCTAssertGreaterThan(variance, 0, "Variance should be positive")
    }

    func testUltraMathHRVRMSSD() {
        // Sample RR intervals in ms
        let rrIntervals: [Float] = [800, 810, 795, 820, 805, 815, 790, 825, 800, 810]

        let rmssd = UltraMath.hrvRMSSD(rrIntervals)

        XCTAssertGreaterThan(rmssd, 0, "RMSSD should be positive")
        XCTAssertLessThan(rmssd, 100, "RMSSD should be reasonable for normal HR")
    }

    func testUltraMathCoherenceScore() {
        // Generate synthetic HRV data with coherent pattern
        var hrvData = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            // Simulate coherent 0.1 Hz oscillation
            hrvData[i] = 50 + 20 * sin(Float(i) * 0.1 * 2 * .pi / 256)
        }

        let coherence = UltraMath.coherenceScore(hrvData, sampleRate: 4.0)

        XCTAssertGreaterThanOrEqual(coherence, 0, "Coherence should be >= 0")
        XCTAssertLessThanOrEqual(coherence, 1, "Coherence should be <= 1")
    }

    // MARK: - ZeroAllocAudioBuffer Tests

    func testZeroAllocAudioBuffer() {
        let buffer = ZeroAllocAudioBuffer(capacity: 1024)

        XCTAssertEqual(buffer.count, 1024, "Buffer capacity should match")

        // Test fill
        buffer.fill(0.5)
        XCTAssertEqual(buffer.pointer[0], 0.5, "Fill should work")
        XCTAssertEqual(buffer.pointer[1023], 0.5, "Fill should fill entire buffer")

        // Test clear
        buffer.clear()
        XCTAssertEqual(buffer.pointer[0], 0, "Clear should zero buffer")

        // Test gain
        buffer.fill(1.0)
        buffer.applyGain(0.5)
        XCTAssertEqual(buffer.pointer[0], 0.5, accuracy: 0.0001, "Gain should be applied")
    }

    func testZeroAllocAudioBufferCopy() {
        let source: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let buffer = ZeroAllocAudioBuffer(capacity: 10)

        source.withUnsafeBufferPointer { srcPtr in
            buffer.copy(from: srcPtr.baseAddress!, count: source.count)
        }

        XCTAssertEqual(buffer.pointer[0], 1.0, "Copy should work")
        XCTAssertEqual(buffer.pointer[4], 5.0, "Copy should copy all elements")
    }

    // MARK: - OptimizedRingBuffer Tests

    func testOptimizedRingBuffer() {
        let ringBuffer = OptimizedRingBuffer(capacityPowerOf2: 4) // 16 elements

        XCTAssertEqual(ringBuffer.availableRead, 0, "New buffer should be empty")
        XCTAssertEqual(ringBuffer.availableWrite, 16, "New buffer should have full capacity")

        // Write samples
        let samples: [Float] = [1, 2, 3, 4, 5]
        let written = samples.withUnsafeBufferPointer { buffer in
            ringBuffer.write(buffer.baseAddress!, count: buffer.count)
        }

        XCTAssertEqual(written, 5, "Should write all samples")
        XCTAssertEqual(ringBuffer.availableRead, 5, "Should have 5 samples to read")

        // Read samples
        var output = [Float](repeating: 0, count: 3)
        let read = output.withUnsafeMutableBufferPointer { buffer in
            ringBuffer.read(buffer.baseAddress!, count: 3)
        }

        XCTAssertEqual(read, 3, "Should read 3 samples")
        XCTAssertEqual(output[0], 1, "First sample should be correct")
        XCTAssertEqual(output[2], 3, "Third sample should be correct")
        XCTAssertEqual(ringBuffer.availableRead, 2, "Should have 2 samples remaining")
    }

    // MARK: - SIMDColor Tests

    func testSIMDColorHSVtoRGB() {
        // Test red (H=0)
        let red = SIMDColor.hsvToRgb(SIMD4<Float>(0, 1, 1, 1))
        XCTAssertEqual(red.x, 1.0, accuracy: 0.01, "Red channel for H=0")
        XCTAssertEqual(red.y, 0.0, accuracy: 0.01, "Green channel for H=0")
        XCTAssertEqual(red.z, 0.0, accuracy: 0.01, "Blue channel for H=0")

        // Test green (H=0.333)
        let green = SIMDColor.hsvToRgb(SIMD4<Float>(0.333, 1, 1, 1))
        XCTAssertEqual(green.y, 1.0, accuracy: 0.1, "Green should be dominant for H=0.333")

        // Test blue (H=0.666)
        let blue = SIMDColor.hsvToRgb(SIMD4<Float>(0.666, 1, 1, 1))
        XCTAssertEqual(blue.z, 1.0, accuracy: 0.1, "Blue should be dominant for H=0.666")
    }

    func testSIMDColorBlend() {
        let white = SIMD4<Float>(1, 1, 1, 1)
        let black = SIMD4<Float>(0, 0, 0, 1)

        let gray = SIMDColor.blend(white, black, t: 0.5)

        XCTAssertEqual(gray.x, 0.5, accuracy: 0.01, "Blend should produce gray")
        XCTAssertEqual(gray.y, 0.5, accuracy: 0.01, "Blend should produce gray")
        XCTAssertEqual(gray.z, 0.5, accuracy: 0.01, "Blend should produce gray")
    }

    // MARK: - BatchOptimizer Tests

    func testBatchOptimizerParallelProcess() {
        let input = Array(0..<10000)

        let result = BatchOptimizer.parallelProcess(input, chunkSize: 1000) { $0 * 2 }

        XCTAssertEqual(result.count, input.count, "Output count should match input")
        XCTAssertEqual(result[0], 0, "First element should be 0")
        XCTAssertEqual(result[100], 200, "Element 100 should be 200")
        XCTAssertEqual(result[9999], 19998, "Last element should be correct")
    }

    func testBatchOptimizerParallelReduce() {
        let input = Array(1...1000)

        let sum = BatchOptimizer.parallelReduce(input, initial: 0, combine: +)

        XCTAssertEqual(sum, 500500, "Sum of 1...1000 should be 500500")
    }

    // MARK: - OptimizedMatrix Tests

    func testOptimizedMatrixMultiply() {
        // 2x3 * 3x2 = 2x2
        var a = OptimizedMatrix(rows: 2, cols: 3)
        a[0, 0] = 1; a[0, 1] = 2; a[0, 2] = 3
        a[1, 0] = 4; a[1, 1] = 5; a[1, 2] = 6

        var b = OptimizedMatrix(rows: 3, cols: 2)
        b[0, 0] = 7; b[0, 1] = 8
        b[1, 0] = 9; b[1, 1] = 10
        b[2, 0] = 11; b[2, 1] = 12

        let c = a.multiply(by: b)

        XCTAssertEqual(c.rows, 2, "Result should have 2 rows")
        XCTAssertEqual(c.cols, 2, "Result should have 2 cols")
        XCTAssertEqual(c[0, 0], 58, accuracy: 0.001, "c[0,0] = 1*7 + 2*9 + 3*11 = 58")
        XCTAssertEqual(c[0, 1], 64, accuracy: 0.001, "c[0,1] = 1*8 + 2*10 + 3*12 = 64")
        XCTAssertEqual(c[1, 0], 139, accuracy: 0.001, "c[1,0] = 4*7 + 5*9 + 6*11 = 139")
        XCTAssertEqual(c[1, 1], 154, accuracy: 0.001, "c[1,1] = 4*8 + 5*10 + 6*12 = 154")
    }

    func testOptimizedMatrixTranspose() {
        var m = OptimizedMatrix(rows: 2, cols: 3)
        m[0, 0] = 1; m[0, 1] = 2; m[0, 2] = 3
        m[1, 0] = 4; m[1, 1] = 5; m[1, 2] = 6

        let t = m.transposed()

        XCTAssertEqual(t.rows, 3, "Transposed should have 3 rows")
        XCTAssertEqual(t.cols, 2, "Transposed should have 2 cols")
        XCTAssertEqual(t[0, 0], 1, accuracy: 0.001)
        XCTAssertEqual(t[1, 0], 2, accuracy: 0.001)
        XCTAssertEqual(t[2, 1], 6, accuracy: 0.001)
    }
}

// MARK: - Streaming Optimization Tests

final class StreamingOptimizationTests: XCTestCase {

    func testFrameRingBuffer() {
        let buffer = FrameRingBuffer<Int>(capacityPowerOf2: 3) // 8 elements

        XCTAssertTrue(buffer.isEmpty, "New buffer should be empty")
        XCTAssertFalse(buffer.isFull, "New buffer should not be full")

        // Fill buffer
        for i in 0..<7 {
            XCTAssertTrue(buffer.enqueue(i), "Should enqueue \(i)")
        }

        XCTAssertEqual(buffer.count, 7, "Should have 7 items")
        XCTAssertFalse(buffer.isFull, "Buffer with 7/8 should not be full")

        // Add one more
        XCTAssertTrue(buffer.enqueue(7), "Should enqueue 7")
        XCTAssertTrue(buffer.isFull, "Buffer should be full now")

        // Try to add when full
        XCTAssertFalse(buffer.enqueue(8), "Should not enqueue when full")

        // Dequeue
        XCTAssertEqual(buffer.dequeue(), 0, "First dequeue should be 0")
        XCTAssertEqual(buffer.dequeue(), 1, "Second dequeue should be 1")
        XCTAssertEqual(buffer.count, 6, "Should have 6 items after dequeue")

        // Clear
        buffer.clear()
        XCTAssertTrue(buffer.isEmpty, "Buffer should be empty after clear")
    }

    func testEncodedFrameBuffer() {
        let buffer = EncodedFrameBuffer(capacity: 4)

        // Add frames
        let frame1 = Data([0x00, 0x01, 0x02])
        let frame2 = Data([0x10, 0x11, 0x12])

        XCTAssertTrue(buffer.add(data: frame1, timestamp: .zero, isKeyframe: true))
        XCTAssertTrue(buffer.add(data: frame2, timestamp: CMTime(value: 1, timescale: 30), isKeyframe: false))

        XCTAssertEqual(buffer.count, 2, "Should have 2 frames")

        // Get frames
        let retrieved1 = buffer.getNext()
        XCTAssertNotNil(retrieved1, "Should retrieve frame")
        XCTAssertEqual(retrieved1?.data, frame1, "Data should match")
        XCTAssertTrue(retrieved1?.isKeyframe ?? false, "Should be keyframe")

        let retrieved2 = buffer.getNext()
        XCTAssertNotNil(retrieved2, "Should retrieve second frame")
        XCTAssertFalse(retrieved2?.isKeyframe ?? true, "Should not be keyframe")

        XCTAssertTrue(buffer.isEmpty, "Buffer should be empty after retrieving all")
    }

    func testSceneLayerCache() {
        let cache = SceneLayerCache()

        // Add layers
        let layer1 = SceneLayerCache.CachedLayer(
            id: UUID(),
            zIndex: 2,
            isVisible: true,
            transform: matrix_identity_float4x4,
            opacity: 1.0,
            blendMode: .normal
        )
        let layer2 = SceneLayerCache.CachedLayer(
            id: UUID(),
            zIndex: 1,
            isVisible: true,
            transform: matrix_identity_float4x4,
            opacity: 0.5,
            blendMode: .screen
        )
        let layer3 = SceneLayerCache.CachedLayer(
            id: UUID(),
            zIndex: 3,
            isVisible: false,
            transform: matrix_identity_float4x4,
            opacity: 1.0,
            blendMode: .normal
        )

        cache.setLayer(layer1)
        cache.setLayer(layer2)
        cache.setLayer(layer3)

        // Get sorted visible layers
        let sorted = cache.getSortedVisibleLayers()

        XCTAssertEqual(sorted.count, 2, "Should have 2 visible layers")
        XCTAssertEqual(sorted[0].zIndex, 1, "First should have zIndex 1")
        XCTAssertEqual(sorted[1].zIndex, 2, "Second should have zIndex 2")
    }

    func testVisualEngineBuffers() {
        let buffers = VisualEngineBuffers.shared

        // Test spectrum update
        let spectrum: [Float] = Array(repeating: 0.5, count: 64)
        spectrum.withUnsafeBufferPointer { ptr in
            buffers.updateSpectrum(from: ptr.baseAddress!, count: ptr.count)
        }

        XCTAssertEqual(buffers.spectrumBuffer[0], 0.5, "Spectrum should be updated")
        XCTAssertEqual(buffers.spectrumBuffer[63], 0.5, "All spectrum values should be updated")

        // Test waveform update
        let waveform: [Float] = (0..<256).map { sin(Float($0) * 0.1) }
        waveform.withUnsafeBufferPointer { ptr in
            buffers.updateWaveform(from: ptr.baseAddress!, count: ptr.count)
        }

        XCTAssertNotEqual(buffers.waveformBuffer[0], 0, "Waveform should be updated")

        // Test clear
        buffers.clear()
        XCTAssertEqual(buffers.spectrumBuffer[0], 0, "Clear should zero spectrum")
        XCTAssertEqual(buffers.waveformBuffer[0], 0, "Clear should zero waveform")
    }

    func testStreamingMetricsAggregator() {
        let metrics = StreamingMetricsAggregator(historySize: 64)

        metrics.startSession()

        // Record frames
        for i in 0..<100 {
            metrics.recordFrame(timing: 0.016, bytes: 50000, dropped: i % 20 == 0)
        }

        XCTAssertGreaterThan(metrics.actualFPS, 0, "FPS should be calculated")
        XCTAssertGreaterThan(metrics.currentBitrate, 0, "Bitrate should be calculated")
        XCTAssertEqual(metrics.dropRate, 0.05, accuracy: 0.01, "Drop rate should be ~5%")
    }
}

// MARK: - DSP Optimization Tests

final class DSPOptimizationTests: XCTestCase {

    func testWindowCache() {
        let cache = WindowCache.shared

        // Test Hann window
        let hann1 = cache.getWindow(type: .hann, size: 1024)
        let hann2 = cache.getWindow(type: .hann, size: 1024)

        XCTAssertEqual(hann1.count, 1024, "Window size should match")
        XCTAssertEqual(hann1[0], 0, accuracy: 0.001, "Hann window should start at 0")
        XCTAssertEqual(hann1[512], 1, accuracy: 0.001, "Hann window should peak at center")

        // Verify caching (same reference)
        XCTAssertEqual(hann1, hann2, "Cached windows should be identical")

        // Test Gaussian window
        let gaussian = cache.getWindow(type: .gaussian, size: 256, parameter: 0.5)
        XCTAssertEqual(gaussian.count, 256, "Gaussian window size should match")
        XCTAssertEqual(gaussian[128], 1, accuracy: 0.01, "Gaussian should peak at center")
    }

    func testLayerSortCache() {
        struct TestLayer: Identifiable {
            let id: UUID
            let zIndex: Int
        }

        let cache = LayerSortCache<TestLayer>()

        let layers = [
            TestLayer(id: UUID(), zIndex: 3),
            TestLayer(id: UUID(), zIndex: 1),
            TestLayer(id: UUID(), zIndex: 2)
        ]

        // First sort
        let sorted1 = cache.getSorted(items: layers, version: 1) { $0.zIndex < $1.zIndex }

        XCTAssertEqual(sorted1[0].zIndex, 1, "Should be sorted by zIndex")
        XCTAssertEqual(sorted1[1].zIndex, 2)
        XCTAssertEqual(sorted1[2].zIndex, 3)

        // Same version should use cache
        let sorted2 = cache.getSorted(items: layers, version: 1) { $0.zIndex < $1.zIndex }
        XCTAssertTrue(cache.isValid, "Cache should be valid")

        // Different version should re-sort
        cache.invalidate()
        XCTAssertFalse(cache.isValid, "Cache should be invalid after invalidate")
    }

    func testOptimizedPatternMatcher() {
        let matcher = OptimizedPatternMatcher()

        // Add exact match patterns
        matcher.addPattern("hello", category: "greeting", weight: 1.0, isRegex: false)
        matcher.addPattern("world", category: "noun", weight: 0.8, isRegex: false)

        // Add regex pattern
        matcher.addPattern(#"\d{3}-\d{4}"#, category: "phone", weight: 0.9, isRegex: true)

        matcher.buildFailureLinks()

        // Test matching
        let text = "hello world, call me at 555-1234"
        let matches = matcher.match(text)

        XCTAssertGreaterThanOrEqual(matches.count, 3, "Should find at least 3 matches")

        let categories = Set(matches.map { $0.category })
        XCTAssertTrue(categories.contains("greeting"), "Should find greeting")
        XCTAssertTrue(categories.contains("noun"), "Should find noun")
        XCTAssertTrue(categories.contains("phone"), "Should find phone")
    }

    func testSIMDEnvelopeFollower() {
        let follower = SIMDEnvelopeFollower(attackMs: 10, releaseMs: 100, sampleRate: 48000)

        // Create test signal with attack and release
        var input = [Float](repeating: 0, count: 4800) // 100ms
        for i in 0..<2400 {
            input[i] = 0.8 // First 50ms at 0.8
        }
        // Last 50ms at 0

        var output = [Float](repeating: 0, count: 4800)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                follower.process(inPtr.baseAddress!, count: inPtr.count, output: outPtr.baseAddress!)
            }
        }

        // Envelope should rise during attack
        XCTAssertLessThan(output[0], output[480], "Envelope should rise during attack")

        // Envelope should fall during release
        XCTAssertGreaterThan(output[2400], output[4799], "Envelope should fall during release")
    }
}

// MARK: - Memory Optimization Tests

final class MemoryOptimizationTests: XCTestCase {

    func testFloatBufferPool() {
        let pool = FloatBufferPool.shared

        // Acquire buffers
        var buffer1 = pool.acquire(minimumSize: 100)
        var buffer2 = pool.acquire(minimumSize: 500)

        XCTAssertGreaterThanOrEqual(buffer1.count, 100, "Buffer should be at least requested size")
        XCTAssertGreaterThanOrEqual(buffer2.count, 500, "Buffer should be at least requested size")

        // Standard sizes should be used
        XCTAssertTrue([64, 128, 256, 512, 1024, 2048, 4096, 8192].contains(buffer1.count),
                     "Should use standard size")

        // Release buffers
        pool.release(&buffer1)
        pool.release(&buffer2)

        // Stats should show available buffers
        let stats = pool.stats
        XCTAssertGreaterThan(stats.values.reduce(0, +), 0, "Pool should have available buffers")
    }

    func testScratchBuffer() {
        let buffer1 = ScratchBuffer.get(minimumSize: 1000)
        XCTAssertGreaterThanOrEqual(buffer1.count, 1000, "Scratch buffer should be at least requested size")

        // Same thread should get same buffer
        let buffer2 = ScratchBuffer.get(minimumSize: 500)
        XCTAssertEqual(buffer1.baseAddress, buffer2.baseAddress, "Same thread should reuse scratch buffer")

        // Larger request should allocate new buffer
        let buffer3 = ScratchBuffer.get(minimumSize: 10000)
        XCTAssertGreaterThanOrEqual(buffer3.count, 10000, "Should allocate larger buffer when needed")
    }

    func testLockFreeQueue() {
        let queue = LockFreeQueue<Int>(capacityPowerOf2: 4) // 16 elements

        XCTAssertTrue(queue.isEmpty, "New queue should be empty")

        // Enqueue items
        for i in 0..<15 {
            XCTAssertTrue(queue.enqueue(i), "Should enqueue \(i)")
        }

        XCTAssertEqual(queue.count, 15, "Queue should have 15 items")

        // Dequeue items
        for i in 0..<10 {
            XCTAssertEqual(queue.dequeue(), i, "Should dequeue in order")
        }

        XCTAssertEqual(queue.count, 5, "Queue should have 5 items remaining")

        // Dequeue rest
        while let _ = queue.dequeue() {}
        XCTAssertTrue(queue.isEmpty, "Queue should be empty after dequeuing all")
    }

    func testPreallocatedArray() {
        var array = PreallocatedArray<Int>(capacity: 10, defaultValue: 0)

        XCTAssertEqual(array.count, 0, "New array should have count 0")
        XCTAssertEqual(array.capacity, 10, "Capacity should match")

        // Append items
        for i in 0..<5 {
            array.append(i * 10)
        }

        XCTAssertEqual(array.count, 5, "Count should be 5 after appending")
        XCTAssertEqual(array[0], 0, "First element should be 0")
        XCTAssertEqual(array[4], 40, "Fifth element should be 40")

        // Reset
        array.reset()
        XCTAssertEqual(array.count, 0, "Count should be 0 after reset")
        XCTAssertEqual(array.capacity, 10, "Capacity should remain")
    }

    func testCompactHRVPoint() {
        let point = CompactHRVPoint(rrInterval: 850.5, timestampOffset: 1234.5)

        XCTAssertEqual(point.rrInterval, 850, "RR interval should be truncated to UInt16")
        XCTAssertEqual(point.timestamp, 1234, "Timestamp should be truncated to UInt16")
        XCTAssertEqual(point.rrIntervalFloat, 850, "Float conversion should work")

        // Test size
        XCTAssertEqual(MemoryLayout<CompactHRVPoint>.size, 4, "CompactHRVPoint should be 4 bytes")
    }

    func testCompactStereoSample() {
        let sample = CompactStereoSample(left: 0.5, right: -0.5)

        XCTAssertEqual(sample.leftFloat, 0.5, accuracy: 0.001, "Left channel conversion")
        XCTAssertEqual(sample.rightFloat, -0.5, accuracy: 0.001, "Right channel conversion")

        // Test size
        XCTAssertEqual(MemoryLayout<CompactStereoSample>.size, 4, "CompactStereoSample should be 4 bytes")
    }
}
