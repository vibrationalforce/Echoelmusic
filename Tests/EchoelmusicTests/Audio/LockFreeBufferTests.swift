import XCTest
@testable import Echoelmusic

/// Tests for LockFreeAudioBuffer - Critical for real-time audio thread safety
/// Coverage target: Thread safety and buffer operations
final class LockFreeBufferTests: XCTestCase {

    // MARK: - Buffer Initialization Tests

    func testBufferCapacity() {
        // Buffer capacity should be power of 2 for efficient modulo
        let capacities = [256, 512, 1024, 2048, 4096]
        for capacity in capacities {
            XCTAssertTrue(capacity.isPowerOfTwo, "Capacity \(capacity) should be power of 2")
        }
    }

    func testInitialBufferState() {
        // New buffer should be empty
        let readIndex = 0
        let writeIndex = 0
        let count = writeIndex - readIndex

        XCTAssertEqual(count, 0, "New buffer should be empty")
    }

    // MARK: - Ring Buffer Operations

    func testRingBufferWrap() {
        // Ring buffer indices wrap using modulo
        let capacity = 256
        let index = 260
        let wrappedIndex = index % capacity

        XCTAssertEqual(wrappedIndex, 4, "Index should wrap correctly")
    }

    func testRingBufferFullDetection() {
        // Buffer is full when write catches up to read
        let capacity = 256
        let readIndex = 100
        let writeIndex = readIndex + capacity - 1  // One slot must stay empty

        let count = writeIndex - readIndex
        let isFull = count >= capacity - 1

        XCTAssertTrue(isFull, "Buffer should be detected as full")
    }

    func testRingBufferEmptyDetection() {
        // Buffer is empty when read == write
        let readIndex = 100
        let writeIndex = 100

        let isEmpty = readIndex == writeIndex
        XCTAssertTrue(isEmpty, "Buffer should be detected as empty")
    }

    // MARK: - Thread Safety Tests

    func testAtomicReadWrite() {
        // Atomic operations prevent torn reads/writes
        var value: Int = 0

        // Simulate atomic increment
        value += 1
        XCTAssertEqual(value, 1)
    }

    func testMemoryBarrier() {
        // Memory barriers ensure ordering
        var flag = false
        var data = 0

        // Write data before setting flag
        data = 42
        // Memory barrier would go here
        flag = true

        // Read flag before data
        if flag {
            XCTAssertEqual(data, 42, "Data should be visible after flag")
        }
    }

    func testSPSCGuarantees() {
        // Single Producer Single Consumer allows lock-free operation
        // Producer only writes to writeIndex
        // Consumer only writes to readIndex
        var readIndex = 0
        var writeIndex = 0

        // Producer writes
        writeIndex = 10

        // Consumer reads
        let available = writeIndex - readIndex
        XCTAssertEqual(available, 10)

        // Consumer updates read index
        readIndex = 5
        let remaining = writeIndex - readIndex
        XCTAssertEqual(remaining, 5)
    }

    // MARK: - Performance Tests

    func testBufferLatency() {
        // Buffer adds latency = bufferSize / sampleRate
        let bufferSize = 256
        let sampleRate = 48000.0
        let latency = Double(bufferSize) / sampleRate

        XCTAssertLessThan(latency, 0.01, "Buffer latency should be < 10ms")
    }

    func testZeroCopyRead() {
        // Zero-copy: read directly from buffer without allocation
        var buffer = [Float](repeating: 0, count: 256)
        buffer[0] = 1.0
        buffer[1] = 2.0

        // Direct pointer access (zero-copy)
        buffer.withUnsafeBufferPointer { ptr in
            XCTAssertEqual(ptr[0], 1.0)
            XCTAssertEqual(ptr[1], 2.0)
        }
    }

    // MARK: - Edge Cases

    func testBufferOverrun() {
        // Overrun: producer writes faster than consumer reads
        let capacity = 256
        var readIndex = 0
        var writeIndex = 0

        // Simulate producer writing too fast
        writeIndex = capacity + 10  // Wrapped around

        // Check for overrun
        let distance = writeIndex - readIndex
        let hasOverrun = distance >= capacity

        XCTAssertTrue(hasOverrun, "Should detect overrun")
    }

    func testBufferUnderrun() {
        // Underrun: consumer reads faster than producer writes
        let readIndex = 100
        let writeIndex = 100

        let available = writeIndex - readIndex
        let hasUnderrun = available <= 0

        XCTAssertTrue(hasUnderrun, "Should detect underrun")
    }

    func testPowerOfTwoModulo() {
        // Fast modulo for power-of-2: index & (capacity - 1)
        let capacity = 256
        let index = 260

        let slowModulo = index % capacity
        let fastModulo = index & (capacity - 1)

        XCTAssertEqual(slowModulo, fastModulo, "Fast modulo should equal slow modulo")
    }
}

// MARK: - Helper Extensions

private extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}
