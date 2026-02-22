// AsyncBioStream.swift
// Echoelmusic - Modern Swift Concurrency for Bio Data Streaming
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Provides AsyncSequence-based API for streaming biometric data.
// Enables modern async/await patterns for bio-reactive components.
//
// Supported Platforms: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+
// Created 2026-01-16

import Foundation

// MARK: - Bio Sample

/// A single biometric data sample
public struct BioSample: Sendable {
    public let timestamp: Date
    public let heartRate: Float
    public let hrvCoherence: HeartMathCoherence
    public let breathPhase: Float
    public let breathRate: Float
    public let gsr: Float
    public let spO2: Float

    /// Normalized coherence for audio/visual use
    public var normalizedCoherence: NormalizedCoherence {
        hrvCoherence.normalized
    }

    public init(
        timestamp: Date = Date(),
        heartRate: Float = 72,
        hrvCoherence: Double = 50,
        breathPhase: Float = 0,
        breathRate: Float = 6,
        gsr: Float = 0.5,
        spO2: Float = 98
    ) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrvCoherence = HeartMathCoherence(hrvCoherence)
        self.breathPhase = breathPhase
        self.breathRate = breathRate
        self.gsr = gsr
        self.spO2 = spO2
    }

    /// Default resting sample
    public static let resting = BioSample()

    /// Convert to TypeSafeBioData
    public var typeSafe: TypeSafeBioData {
        TypeSafeBioData(
            heartRate: heartRate,
            coherence: hrvCoherence,
            breathPhase: breathPhase,
            gsr: gsr,
            spO2: spO2
        )
    }
}

// MARK: - Async Bio Stream

/// AsyncSequence for streaming biometric data
///
/// Usage:
/// ```swift
/// let bioStream = AsyncBioStream()
///
/// // Start producing data
/// bioStream.start()
///
/// // Consume data asynchronously
/// for await sample in bioStream {
///     updateVisuals(with: sample)
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class AsyncBioStream: AsyncSequence {
    public typealias Element = BioSample

    // MARK: - Properties

    private let continuation: AsyncStream<BioSample>.Continuation
    private let stream: AsyncStream<BioSample>
    private var isRunning = false
    /// Retains Combine subscription when created via `from(_:)`
    private var bridgeCancellable: Any?

    /// Sample rate in Hz
    public var sampleRate: Double = 60.0

    /// Buffer size (samples)
    public var bufferSize: Int = 10

    // MARK: - Initialization

    public init(bufferingPolicy: AsyncStream<BioSample>.Continuation.BufferingPolicy = .bufferingNewest(10)) {
        var capturedContinuation: AsyncStream<BioSample>.Continuation?
        self.stream = AsyncStream(bufferingPolicy: bufferingPolicy) { cont in
            capturedContinuation = cont
        }
        // The closure is always called synchronously by AsyncStream.init,
        // so capturedContinuation is guaranteed to be set.
        self.continuation = capturedContinuation!
    }

    // MARK: - AsyncSequence

    public func makeAsyncIterator() -> AsyncStream<BioSample>.AsyncIterator {
        stream.makeAsyncIterator()
    }

    // MARK: - Control

    /// Start the bio stream
    public func start() {
        isRunning = true
    }

    /// Stop the bio stream
    public func stop() {
        isRunning = false
    }

    /// Finish the stream (no more data)
    public func finish() {
        continuation.finish()
    }

    // MARK: - Data Injection

    /// Inject a new bio sample into the stream
    public func send(_ sample: BioSample) {
        guard isRunning else { return }
        continuation.yield(sample)
    }

    /// Inject raw values
    public func send(
        heartRate: Float,
        coherence: Double,
        breathPhase: Float,
        breathRate: Float = 6,
        gsr: Float = 0.5,
        spO2: Float = 98
    ) {
        send(BioSample(
            heartRate: heartRate,
            hrvCoherence: coherence,
            breathPhase: breathPhase,
            breathRate: breathRate,
            gsr: gsr,
            spO2: spO2
        ))
    }
}

// MARK: - Transformed Bio Streams

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension AsyncBioStream {

    /// Map to coherence-only stream
    func coherenceStream() -> AsyncMapSequence<AsyncBioStream, NormalizedCoherence> {
        self.map { $0.normalizedCoherence }
    }

    /// Map to heart rate stream
    func heartRateStream() -> AsyncMapSequence<AsyncBioStream, Float> {
        self.map { $0.heartRate }
    }

    /// Filter to high coherence samples only
    func highCoherenceStream() -> AsyncFilterSequence<AsyncBioStream> {
        self.filter { $0.hrvCoherence.isHigh }
    }

    /// Smooth coherence values
    func smoothedCoherence(factor: Double = 0.3) -> AsyncSmoothingSequence<AsyncBioStream, Double> {
        AsyncSmoothingSequence(base: self, factor: factor) { $0.normalizedCoherence.value }
    }
}

// MARK: - Smoothing Sequence

/// AsyncSequence that applies exponential moving average smoothing
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct AsyncSmoothingSequence<Base: AsyncSequence, Value: BinaryFloatingPoint>: AsyncSequence {
    public typealias Element = Value

    private let base: Base
    private let factor: Double
    private let transform: (Base.Element) -> Value

    public init(base: Base, factor: Double, transform: @escaping (Base.Element) -> Value) {
        self.base = base
        self.factor = factor
        self.transform = transform
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), factor: factor, transform: transform)
    }

    public struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let factor: Double
        let transform: (Base.Element) -> Value
        var lastValue: Value?

        init(base: Base.AsyncIterator, factor: Double, transform: @escaping (Base.Element) -> Value) {
            self.baseIterator = base
            self.factor = factor
            self.transform = transform
        }

        public mutating func next() async -> Value? {
            guard let element = try? await baseIterator.next() else {
                return nil
            }

            let newValue = transform(element)

            if let last = lastValue {
                let smoothed = Value(factor) * newValue + Value(1 - factor) * last
                lastValue = smoothed
                return smoothed
            } else {
                lastValue = newValue
                return newValue
            }
        }
    }
}

// MARK: - Bio Stream Provider

/// Protocol for bio data sources
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public protocol BioStreamProvider {
    /// Get an async stream of bio samples
    func bioStream() -> AsyncBioStream
}

// MARK: - Bio Stream Hub

/// Central hub for bio data distribution
///
/// Manages multiple consumers of bio data with efficient fan-out.
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@MainActor
public final class BioStreamHub {

    // MARK: - Singleton

    public static let shared = BioStreamHub()

    // MARK: - Streams

    private var streams: [UUID: AsyncBioStream] = [:]
    private var latestSample: BioSample = .resting

    // MARK: - Initialization

    private init() {}

    // MARK: - Stream Management

    /// Create a new consumer stream
    public func createStream() -> (id: UUID, stream: AsyncBioStream) {
        let id = UUID()
        let stream = AsyncBioStream()
        stream.start()
        streams[id] = stream
        return (id, stream)
    }

    /// Remove a consumer stream
    public func removeStream(id: UUID) {
        streams[id]?.finish()
        streams.removeValue(forKey: id)
    }

    /// Broadcast a sample to all consumers
    public func broadcast(_ sample: BioSample) {
        latestSample = sample
        for stream in streams.values {
            stream.send(sample)
        }
    }

    /// Get latest sample synchronously
    public var latest: BioSample { latestSample }

    /// Number of active streams
    public var streamCount: Int { streams.count }
}

// MARK: - Async Bio Buffer

/// Buffered bio data for batch processing
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public actor AsyncBioBuffer {

    private var samples: [BioSample] = []
    private let maxSize: Int
    private var continuation: AsyncStream<[BioSample]>.Continuation?

    public init(maxSize: Int = 256) {
        self.maxSize = maxSize
    }

    /// Add a sample to the buffer
    public func add(_ sample: BioSample) {
        samples.append(sample)

        // Trim if needed
        if samples.count > maxSize {
            samples.removeFirst(samples.count - maxSize)
        }
    }

    /// Get all samples
    public func getSamples() -> [BioSample] {
        samples
    }

    /// Get samples in time range
    public func getSamples(from startTime: Date, to endTime: Date) -> [BioSample] {
        samples.filter { $0.timestamp >= startTime && $0.timestamp <= endTime }
    }

    /// Get last N samples
    public func getLastSamples(_ count: Int) -> [BioSample] {
        Array(samples.suffix(count))
    }

    /// Calculate average coherence
    public func averageCoherence() -> NormalizedCoherence {
        guard !samples.isEmpty else { return .medium }
        let sum = samples.reduce(0.0) { $0 + $1.normalizedCoherence.value }
        return NormalizedCoherence(sum / Double(samples.count))
    }

    /// Calculate average heart rate
    public func averageHeartRate() -> Float {
        guard !samples.isEmpty else { return 72 }
        let sum = samples.reduce(Float(0)) { $0 + $1.heartRate }
        return sum / Float(samples.count)
    }

    /// Clear buffer
    public func clear() {
        samples.removeAll()
    }

    /// Stream of windowed samples
    public func windowedStream(windowSize: Int, slideBy: Int = 1) -> AsyncStream<[BioSample]> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                var lastIndex = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_666_667) // ~60Hz
                    guard !Task.isCancelled else { break }

                    guard let self = self else { break }
                    let currentSamples = await self.getSamples()
                    if currentSamples.count >= windowSize && currentSamples.count > lastIndex + slideBy {
                        let window = Array(currentSamples.suffix(windowSize))
                        continuation.yield(window)
                        lastIndex = currentSamples.count
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Combine Bridge

#if canImport(Combine)
import Combine

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension AsyncBioStream {

    /// Create from Combine publisher
    static func from<P: Publisher>(_ publisher: P) -> AsyncBioStream where P.Output == BioSample, P.Failure == Never {
        let stream = AsyncBioStream()
        stream.start()

        // Store cancellable on stream instance to tie subscription lifetime to stream lifetime
        stream.bridgeCancellable = publisher.sink { sample in
            stream.send(sample)
        }

        return stream
    }

    /// Convert to Combine publisher
    func toPublisher() -> AnyPublisher<BioSample, Never> {
        let subject = PassthroughSubject<BioSample, Never>()

        let task = Task { [weak self] in
            guard let self = self else { return }
            for await sample in self {
                guard !Task.isCancelled else { break }
                subject.send(sample)
            }
            subject.send(completion: .finished)
        }

        // Cancel task when last subscriber disconnects
        return subject
            .handleEvents(receiveCancel: { task.cancel() })
            .eraseToAnyPublisher()
    }
}
#endif
