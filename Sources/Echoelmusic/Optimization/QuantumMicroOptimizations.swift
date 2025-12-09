import Foundation
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM MICRO-OPTIMIZATIONS - CYCLE-LEVEL PERFORMANCE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Compiler optimization enablers:
// • @frozen structs for fixed layout
// • @inlinable functions for cross-module optimization
// • final classes for static dispatch
// • ContiguousArray for cache-friendly storage
// • Pre-computed reciprocals for division elimination
//
// Memory optimizations:
// • Cache-line aligned structures (64 bytes)
// • Struct field reordering for minimal padding
// • Bitwise operations for power-of-2 modulo
// • SIMD-width aligned buffers
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Frozen Performance Structs

/// GPU uniform buffer - frozen for optimal memory layout
@frozen
public struct OptimizedUniforms {
    // 8-byte aligned fields first (avoid internal padding)
    public var modelViewProjection: simd_float4x4  // 64 bytes
    public var time: Float                          // 4 bytes
    public var audioLevel: Float                    // 4 bytes
    public var frequency: Float                     // 4 bytes
    public var hrvCoherence: Float                  // 4 bytes
    public var heartRate: Float                     // 4 bytes
    public var breathingRate: Float                 // 4 bytes
    public var resolution: SIMD2<Float>             // 8 bytes
    public var waveSpeed: Float                     // 4 bytes
    public var waveAmplitude: Float                 // 4 bytes
    // Total: 104 bytes (cache-line friendly)

    @inlinable
    public init() {
        modelViewProjection = matrix_identity_float4x4
        time = 0
        audioLevel = 0
        frequency = 440
        hrvCoherence = 0.5
        heartRate = 60
        breathingRate = 12
        resolution = SIMD2(1920, 1080)
        waveSpeed = 1
        waveAmplitude = 1
    }
}

/// Compact HRV data point - minimal memory footprint
@frozen
public struct CompactHRVSample {
    public var rr: UInt16           // RR interval in ms (max 65535ms)
    public var coherence: UInt8     // 0-255 scaled to 0-1
    public var timestamp: UInt32    // Seconds since epoch (good until 2106)
    // Total: 7 bytes + 1 padding = 8 bytes

    @inlinable
    public init(rr: Float, coherence: Float, timestamp: TimeInterval) {
        self.rr = UInt16(min(max(rr, 0), 65535))
        self.coherence = UInt8(min(max(coherence * 255, 0), 255))
        self.timestamp = UInt32(timestamp.truncatingRemainder(dividingBy: Double(UInt32.max)))
    }

    @inlinable
    public var rrInterval: Float { Float(rr) }

    @inlinable
    public var coherenceValue: Float { Float(coherence) / 255.0 }
}

/// Audio frame metadata - cache-line aligned
@frozen
public struct AudioFrameMetadata {
    public var timestamp: UInt64        // 8 bytes - mach_absolute_time
    public var sampleRate: Float        // 4 bytes
    public var frameCount: UInt32       // 4 bytes
    public var peakLevel: Float         // 4 bytes
    public var rmsLevel: Float          // 4 bytes
    public var dominantFreq: Float      // 4 bytes
    public var flags: UInt32            // 4 bytes
    // Total: 32 bytes (half cache line)

    public struct Flags: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let hasClipping = Flags(rawValue: 1 << 0)
        public static let isSilence = Flags(rawValue: 1 << 1)
        public static let hasBeat = Flags(rawValue: 1 << 2)
        public static let hasOnset = Flags(rawValue: 1 << 3)
    }

    @inlinable
    public init() {
        timestamp = 0
        sampleRate = 44100
        frameCount = 0
        peakLevel = 0
        rmsLevel = 0
        dominantFreq = 0
        flags = 0
    }
}

// MARK: - Optimized Enum-Indexed Array

/// Fast enum-indexed storage (replaces Dictionary<Enum, T>)
@frozen
public struct EnumIndexedArray<Key: RawRepresentable, Value> where Key.RawValue == Int {

    @usableFromInline
    var storage: ContiguousArray<Value?>

    @inlinable
    public init(count: Int, defaultValue: Value? = nil) {
        storage = ContiguousArray(repeating: defaultValue, count: count)
    }

    @inlinable
    public subscript(key: Key) -> Value? {
        get { storage[key.rawValue] }
        set { storage[key.rawValue] = newValue }
    }

    @inlinable
    public mutating func set(_ value: Value, for key: Key) {
        storage[key.rawValue] = value
    }

    @inlinable
    public func get(_ key: Key) -> Value? {
        return storage[key.rawValue]
    }
}

// MARK: - Pre-Computed Reciprocals

/// Division elimination through pre-computed reciprocals
@frozen
public struct FastReciprocals {

    // Common audio reciprocals
    public static let inv44100: Float = 1.0 / 44100.0
    public static let inv48000: Float = 1.0 / 48000.0
    public static let inv96000: Float = 1.0 / 96000.0

    // Common buffer size reciprocals
    public static let inv256: Float = 1.0 / 256.0
    public static let inv512: Float = 1.0 / 512.0
    public static let inv1024: Float = 1.0 / 1024.0
    public static let inv2048: Float = 1.0 / 2048.0
    public static let inv4096: Float = 1.0 / 4096.0

    // Video reciprocals
    public static let inv60: Float = 1.0 / 60.0
    public static let inv120: Float = 1.0 / 120.0

    // Bio reciprocals
    public static let inv60000: Float = 1.0 / 60000.0  // For RR interval calc

    /// Get reciprocal for sample rate
    @inlinable @inline(__always)
    public static func sampleRateReciprocal(_ rate: Float) -> Float {
        switch Int(rate) {
        case 44100: return inv44100
        case 48000: return inv48000
        case 96000: return inv96000
        default: return 1.0 / rate
        }
    }

    /// Get reciprocal for buffer size
    @inlinable @inline(__always)
    public static func bufferSizeReciprocal(_ size: Int) -> Float {
        switch size {
        case 256: return inv256
        case 512: return inv512
        case 1024: return inv1024
        case 2048: return inv2048
        case 4096: return inv4096
        default: return 1.0 / Float(size)
        }
    }
}

// MARK: - Bitwise Fast Math

/// Bitwise operations for power-of-2 arithmetic
@frozen
public struct BitwiseMath {

    /// Fast modulo for power-of-2 (x % n where n is power of 2)
    @inlinable @inline(__always)
    public static func mod(_ x: Int, powerOf2 n: Int) -> Int {
        return x & (n - 1)
    }

    /// Fast division by power of 2
    @inlinable @inline(__always)
    public static func div(_ x: Int, powerOf2 n: Int) -> Int {
        return x >> n.trailingZeroBitCount
    }

    /// Fast multiply by power of 2
    @inlinable @inline(__always)
    public static func mul(_ x: Int, powerOf2 n: Int) -> Int {
        return x << n.trailingZeroBitCount
    }

    /// Check if power of 2
    @inlinable @inline(__always)
    public static func isPowerOf2(_ n: Int) -> Bool {
        return n > 0 && (n & (n - 1)) == 0
    }

    /// Next power of 2
    @inlinable @inline(__always)
    public static func nextPowerOf2(_ n: Int) -> Int {
        guard n > 0 else { return 1 }
        return 1 << (Int.bitWidth - (n - 1).leadingZeroBitCount)
    }

    /// Unchecked addition (no overflow trap)
    @inlinable @inline(__always)
    public static func addUnchecked(_ a: Int, _ b: Int) -> Int {
        return a &+ b
    }

    /// Unchecked multiplication
    @inlinable @inline(__always)
    public static func mulUnchecked(_ a: Int, _ b: Int) -> Int {
        return a &* b
    }
}

// MARK: - SIMD Batch Operations

/// Vectorized batch operations
public struct SIMDBatch {

    /// Batch multiply-add: result = a * b + c
    @inlinable
    public static func multiplyAdd(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        _ c: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_vma(a, 1, b, 1, c, 1, result, 1, vDSP_Length(count))
    }

    /// Batch linear interpolation: result = a + t * (b - a)
    @inlinable
    public static func lerp(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        t: Float,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var t1 = 1.0 - t
        var t2 = t
        vDSP_vsmsma(a, 1, &t1, b, 1, &t2, result, 1, vDSP_Length(count))
    }

    /// Batch clamp: result = clamp(input, min, max)
    @inlinable
    public static func clamp(
        _ input: UnsafePointer<Float>,
        min: Float,
        max: Float,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var minVal = min
        var maxVal = max
        vDSP_vclip(input, 1, &minVal, &maxVal, result, 1, vDSP_Length(count))
    }

    /// Batch absolute value
    @inlinable
    public static func abs(
        _ input: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_vabs(input, 1, result, 1, vDSP_Length(count))
    }

    /// Batch square root
    @inlinable
    public static func sqrt(
        _ input: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var n = Int32(count)
        vvsqrtf(result, input, &n)
    }

    /// Batch exponential
    @inlinable
    public static func exp(
        _ input: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var n = Int32(count)
        vvexpf(result, input, &n)
    }

    /// Batch natural log
    @inlinable
    public static func log(
        _ input: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var n = Int32(count)
        vvlogf(result, input, &n)
    }

    /// Batch power: result = base^exp
    @inlinable
    public static func pow(
        base: UnsafePointer<Float>,
        exp: UnsafePointer<Float>,
        result: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var n = Int32(count)
        vvpowf(result, exp, base, &n)
    }

    /// RMS (Root Mean Square)
    @inlinable
    public static func rms(
        _ input: UnsafePointer<Float>,
        count: Int
    ) -> Float {
        var result: Float = 0
        vDSP_rmsqv(input, 1, &result, vDSP_Length(count))
        return result
    }

    /// Peak value
    @inlinable
    public static func peak(
        _ input: UnsafePointer<Float>,
        count: Int
    ) -> Float {
        var result: Float = 0
        vDSP_maxmgv(input, 1, &result, vDSP_Length(count))
        return result
    }

    /// Mean value
    @inlinable
    public static func mean(
        _ input: UnsafePointer<Float>,
        count: Int
    ) -> Float {
        var result: Float = 0
        vDSP_meanv(input, 1, &result, vDSP_Length(count))
        return result
    }
}

// MARK: - Cache-Optimized Containers

/// Fixed-size array with no heap allocation
@frozen
public struct FixedArray8<T> {
    public var e0, e1, e2, e3, e4, e5, e6, e7: T

    @inlinable
    public init(repeating value: T) {
        e0 = value; e1 = value; e2 = value; e3 = value
        e4 = value; e5 = value; e6 = value; e7 = value
    }

    @inlinable
    public subscript(index: Int) -> T {
        get {
            switch index {
            case 0: return e0; case 1: return e1
            case 2: return e2; case 3: return e3
            case 4: return e4; case 5: return e5
            case 6: return e6; case 7: return e7
            default: fatalError("Index out of bounds")
            }
        }
        set {
            switch index {
            case 0: e0 = newValue; case 1: e1 = newValue
            case 2: e2 = newValue; case 3: e3 = newValue
            case 4: e4 = newValue; case 5: e5 = newValue
            case 6: e6 = newValue; case 7: e7 = newValue
            default: fatalError("Index out of bounds")
            }
        }
    }
}

/// Fixed-size array for frequency bands (7 bands standard)
@frozen
public struct FrequencyBands {
    public var subBass: Float      // 20-60 Hz
    public var bass: Float         // 60-250 Hz
    public var lowMid: Float       // 250-500 Hz
    public var mid: Float          // 500-2000 Hz
    public var upperMid: Float     // 2000-4000 Hz
    public var presence: Float     // 4000-6000 Hz
    public var brilliance: Float   // 6000-20000 Hz

    @inlinable
    public init() {
        subBass = 0; bass = 0; lowMid = 0; mid = 0
        upperMid = 0; presence = 0; brilliance = 0
    }

    @inlinable
    public subscript(index: Int) -> Float {
        get {
            switch index {
            case 0: return subBass
            case 1: return bass
            case 2: return lowMid
            case 3: return mid
            case 4: return upperMid
            case 5: return presence
            case 6: return brilliance
            default: return 0
            }
        }
        set {
            switch index {
            case 0: subBass = newValue
            case 1: bass = newValue
            case 2: lowMid = newValue
            case 3: mid = newValue
            case 4: upperMid = newValue
            case 5: presence = newValue
            case 6: brilliance = newValue
            default: break
            }
        }
    }

    /// Overall energy
    @inlinable
    public var total: Float {
        return subBass + bass + lowMid + mid + upperMid + presence + brilliance
    }

    /// Weighted average (perception-based)
    @inlinable
    public var weightedAverage: Float {
        // A-weighting approximation
        let weights: [Float] = [0.5, 0.7, 0.9, 1.0, 1.0, 0.9, 0.7]
        var sum: Float = 0
        var weightSum: Float = 0
        for i in 0..<7 {
            sum += self[i] * weights[i]
            weightSum += weights[i]
        }
        return sum / weightSum
    }
}

// MARK: - Loop Optimization Helpers

/// Stride iterator for loop unrolling hints
@frozen
public struct OptimizedStride {

    /// Process in chunks of 4 for SIMD
    @inlinable
    public static func forEach4(
        count: Int,
        body: (Int) -> Void
    ) {
        let chunks = count >> 2  // count / 4
        let remainder = count & 3  // count % 4

        for i in 0..<chunks {
            let base = i << 2
            body(base)
            body(base + 1)
            body(base + 2)
            body(base + 3)
        }

        let base = chunks << 2
        for i in 0..<remainder {
            body(base + i)
        }
    }

    /// Process in chunks of 8 for wider SIMD
    @inlinable
    public static func forEach8(
        count: Int,
        body: (Int) -> Void
    ) {
        let chunks = count >> 3  // count / 8
        let remainder = count & 7  // count % 8

        for i in 0..<chunks {
            let base = i << 3
            body(base); body(base + 1); body(base + 2); body(base + 3)
            body(base + 4); body(base + 5); body(base + 6); body(base + 7)
        }

        let base = chunks << 3
        for i in 0..<remainder {
            body(base + i)
        }
    }
}

// MARK: - Lazy Filter/Map Helpers

/// Optimized filter with single pass
public extension Sequence {

    /// Filter and collect in single allocation
    @inlinable
    func filteredArray(
        reservingCapacity: Int? = nil,
        where predicate: (Element) -> Bool
    ) -> [Element] {
        var result = [Element]()
        if let capacity = reservingCapacity {
            result.reserveCapacity(capacity)
        }
        for element in self {
            if predicate(element) {
                result.append(element)
            }
        }
        return result
    }

    /// Combined filter and map in single pass
    @inlinable
    func compactTransform<T>(
        reservingCapacity: Int? = nil,
        _ transform: (Element) -> T?
    ) -> [T] {
        var result = [T]()
        if let capacity = reservingCapacity {
            result.reserveCapacity(capacity)
        }
        for element in self {
            if let transformed = transform(element) {
                result.append(transformed)
            }
        }
        return result
    }
}

// MARK: - Inline String Optimization

/// Pre-allocated string buffer for logging
public final class StringBuffer {

    private var buffer: [UInt8]
    private var position: Int = 0
    private let capacity: Int

    public init(capacity: Int = 1024) {
        self.capacity = capacity
        self.buffer = [UInt8](repeating: 0, count: capacity)
    }

    /// Append without allocation (returns false if full)
    @inlinable
    public func append(_ string: StaticString) -> Bool {
        let length = string.utf8CodeUnitCount
        guard position + length < capacity else { return false }

        string.withUTF8Buffer { utf8 in
            for i in 0..<length {
                buffer[position + i] = utf8[i]
            }
        }
        position += length
        return true
    }

    /// Append integer
    @inlinable
    public func append(_ value: Int) -> Bool {
        var temp = [UInt8](repeating: 0, count: 20)
        var n = abs(value)
        var i = 19

        repeat {
            temp[i] = UInt8(48 + n % 10)
            n /= 10
            i -= 1
        } while n > 0

        if value < 0 {
            temp[i] = 45  // '-'
            i -= 1
        }

        let start = i + 1
        let length = 20 - start

        guard position + length < capacity else { return false }

        for j in start..<20 {
            buffer[position] = temp[j]
            position += 1
        }

        return true
    }

    /// Get string (creates allocation)
    public var string: String {
        return String(bytes: buffer[0..<position], encoding: .utf8) ?? ""
    }

    /// Reset buffer
    @inlinable
    public func reset() {
        position = 0
    }
}

// MARK: - Memory Alignment Helpers

/// Cache-line aligned allocation
public func allocateCacheAligned<T>(
    count: Int,
    alignment: Int = 64
) -> UnsafeMutablePointer<T> {
    let size = count * MemoryLayout<T>.stride
    let alignedSize = (size + alignment - 1) & ~(alignment - 1)

    guard let ptr = UnsafeMutableRawPointer.allocate(
        byteCount: alignedSize,
        alignment: alignment
    ).bindMemory(to: T.self, capacity: count) else {
        fatalError("Failed to allocate aligned memory")
    }

    return ptr
}

/// SIMD-aligned buffer wrapper
@frozen
public struct AlignedBuffer<T> {

    public let pointer: UnsafeMutablePointer<T>
    public let count: Int
    public let alignment: Int

    public init(count: Int, alignment: Int = 16) {
        self.count = count
        self.alignment = alignment

        let size = count * MemoryLayout<T>.stride
        let alignedPtr = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: alignment
        )
        self.pointer = alignedPtr.bindMemory(to: T.self, capacity: count)
    }

    public func deallocate() {
        pointer.deallocate()
    }

    @inlinable
    public subscript(index: Int) -> T {
        get { pointer[index] }
        nonmutating set { pointer[index] = newValue }
    }
}

// MARK: - Compiler Hints

/// Force inline for critical hot paths
@_transparent
@inlinable
public func forceInline<T>(_ body: () -> T) -> T {
    return body()
}

/// Likely branch hint
@_transparent
@inlinable
public func likely(_ condition: Bool) -> Bool {
    return condition
}

/// Unlikely branch hint
@_transparent
@inlinable
public func unlikely(_ condition: Bool) -> Bool {
    return condition
}
