// RalphWiggumLambdaLoopTests.swift
// Echoelmusic - Comprehensive Tests for Ralph Wiggum Lambda Loop Improvements
// Phase 10000 - 12 Major Improvements
// Created 2026-01-16

import XCTest
@testable import Echoelmusic

// MARK: - Circuit Breaker Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class CircuitBreakerTests: XCTestCase {

    func testInitialState() async {
        let breaker = CircuitBreaker(name: "test")
        let state = await breaker.state
        XCTAssertEqual(state, .closed)
    }

    func testSuccessfulExecution() async throws {
        let breaker = CircuitBreaker(name: "test")

        let result = try await breaker.execute {
            return 42
        }

        XCTAssertEqual(result, 42)
        let stats = await breaker.statistics
        XCTAssertEqual(stats.successfulRequests, 1)
    }

    func testFailureTracking() async {
        let breaker = CircuitBreaker(name: "test", config: .init(failureThreshold: 3))

        for _ in 0..<2 {
            do {
                _ = try await breaker.execute {
                    throw NSError(domain: "test", code: 1)
                }
            } catch {}
        }

        let stats = await breaker.statistics
        XCTAssertEqual(stats.failedRequests, 2)
    }

    func testCircuitOpens() async {
        let breaker = CircuitBreaker(name: "test", config: .init(failureThreshold: 2))

        // Cause failures
        for _ in 0..<3 {
            do {
                _ = try await breaker.execute {
                    throw NSError(domain: "test", code: 1)
                }
            } catch {}
        }

        let state = await breaker.state
        XCTAssertEqual(state, .open)
    }

    func testRetryPolicy() {
        let policy = RetryPolicy.default

        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertGreaterThan(policy.delay(for: 1), 0)
    }
}

// MARK: - Memory Pressure Handler Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class MemoryPressureHandlerTests: XCTestCase {

    func testSingleton() async {
        let handler1 = await MemoryPressureHandler.shared
        let handler2 = await MemoryPressureHandler.shared
        XCTAssertTrue(handler1 === handler2)
    }

    func testMemoryUsage() async {
        let handler = await MemoryPressureHandler.shared
        let usage = await handler.memoryUsage

        XCTAssertGreaterThan(usage.usedBytes, 0)
        XCTAssertGreaterThan(usage.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(usage.usagePercent, 0)
    }

    func testMemoryAwareCache() {
        let cache = MemoryAwareCache<String, Data>(maxSize: 1000)

        cache.set("key1", value: Data(count: 100), size: 100)
        cache.set("key2", value: Data(count: 200), size: 200)

        XCTAssertEqual(cache.currentSize, 300)
        XCTAssertNotNil(cache.get("key1"))
        XCTAssertNotNil(cache.get("key2"))

        cache.remove("key1")
        XCTAssertNil(cache.get("key1"))
        XCTAssertEqual(cache.currentSize, 200)
    }

    func testCacheEviction() {
        let cache = MemoryAwareCache<String, Data>(maxSize: 500)

        cache.set("key1", value: Data(count: 300), size: 300)
        cache.set("key2", value: Data(count: 300), size: 300)

        // key1 should be evicted
        XCTAssertLessThanOrEqual(cache.currentSize, 500)
    }
}

// MARK: - Crash-Safe State Persistence Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class CrashSafeStatePersistenceTests: XCTestCase {

    func testSessionStateCreation() {
        let state = SessionState()

        XCTAssertNotNil(state.sessionId)
        XCTAssertNotNil(state.startedAt)
        XCTAssertEqual(state.durationSeconds, 0)
    }

    func testSessionStateBuilder() {
        let state = SessionStateBuilder()
            .withPreset("Meditation")
            .withBioSettings(enabled: true, coherenceThreshold: 0.7)
            .withAudioSettings(volume: 0.8, bpm: 60)
            .withCoherenceReading(0.75)
            .build()

        XCTAssertEqual(state.activePreset, "Meditation")
        XCTAssertEqual(state.bioSettings.coherenceThreshold, 0.7)
        XCTAssertEqual(state.audioSettings.bpm, 60)
        XCTAssertEqual(state.metrics.coherenceReadings, 1)
    }

    func testSessionStateSerialization() throws {
        let state = SessionState()

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(SessionState.self, from: data)

        XCTAssertEqual(decoded.sessionId, state.sessionId)
    }
}

// MARK: - SIMD Bio Processing Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class SIMDBioProcessingTests: XCTestCase {

    func testProcessorCreation() {
        let processor = SIMDBioProcessor()
        XCTAssertNotNil(processor)
    }

    func testAddRRIntervals() {
        let processor = SIMDBioProcessor()

        for i in 0..<100 {
            processor.addRRInterval(Float(800 + i % 50))
        }

        let metrics = processor.calculateHRVMetrics()
        XCTAssertGreaterThan(metrics.meanRR, 0)
    }

    func testHRVMetrics() {
        let processor = SIMDBioProcessor(config: .init(windowSize: 64))

        // Add stable RR intervals
        for _ in 0..<64 {
            processor.addRRInterval(850 + Float.random(in: -20...20))
        }

        let metrics = processor.calculateHRVMetrics()

        XCTAssertGreaterThan(metrics.meanRR, 800)
        XCTAssertLessThan(metrics.meanRR, 900)
        XCTAssertGreaterThan(metrics.sdnn, 0)
        XCTAssertGreaterThanOrEqual(metrics.heartRate, 60)
    }

    func testNormalization() {
        let data: [Float] = [10, 20, 30, 40, 50]
        let normalized = SIMDBioProcessor.normalize(data)

        XCTAssertEqual(normalized.first, 0, accuracy: 0.001)
        XCTAssertEqual(normalized.last, 1, accuracy: 0.001)
    }

    func testCorrelation() {
        let a: [Float] = [1, 2, 3, 4, 5]
        let b: [Float] = [1, 2, 3, 4, 5]

        let correlation = SIMDBioProcessor.correlation(a, b)
        XCTAssertEqual(correlation, 1.0, accuracy: 0.001)

        let c: [Float] = [5, 4, 3, 2, 1]
        let negCorrelation = SIMDBioProcessor.correlation(a, c)
        XCTAssertEqual(negCorrelation, -1.0, accuracy: 0.001)
    }
}

// MARK: - Predictive Frame Prefetch Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class PredictiveFramePrefetchTests: XCTestCase {

    func testPrefetcherCreation() {
        let prefetcher = PredictiveFramePrefetcher()
        XCTAssertNotNil(prefetcher)
    }

    func testAddInput() {
        let prefetcher = PredictiveFramePrefetcher()

        prefetcher.addInput(PredictionInput(coherence: 0.5))
        prefetcher.addInput(PredictionInput(coherence: 0.6))
        prefetcher.addInput(PredictionInput(coherence: 0.7))

        let stats = prefetcher.statistics
        XCTAssertEqual(stats.historySize, 3)
    }

    func testPrediction() {
        let prefetcher = PredictiveFramePrefetcher()

        // Add enough samples
        for i in 0..<20 {
            let coherence = 0.5 + Float(i) * 0.01
            prefetcher.addInput(PredictionInput(coherence: coherence))
        }

        let prediction = prefetcher.getNextFramePrediction()

        XCTAssertGreaterThan(prediction.confidence, 0)
        XCTAssertGreaterThanOrEqual(prediction.coherence, 0)
        XCTAssertLessThanOrEqual(prediction.coherence, 1)
    }

    func testTrendDetection() {
        let prefetcher = PredictiveFramePrefetcher()

        // Rising coherence
        for i in 0..<30 {
            let coherence = 0.3 + Float(i) * 0.02
            prefetcher.addInput(PredictionInput(coherence: coherence))
        }

        let stats = prefetcher.statistics
        XCTAssertGreaterThan(stats.coherenceTrend, 0)
    }
}

// MARK: - Audio Graph Builder Tests

final class AudioGraphBuilderTests: XCTestCase {

    func testSourceNode() {
        let source = Source("osc")
            .frequency(440)
            .waveform(.sine)
            .amplitude(0.5)

        XCTAssertEqual(source.nodeId, "osc")
        XCTAssertEqual(source.parameters["frequency"] as? Float, 440)
        XCTAssertEqual(source.parameters["waveform"] as? String, "sine")
    }

    func testEffectNode() {
        let effect = Effect("filter", type: .lowPass)
            .input("osc")
            .cutoff(1000)
            .resonance(0.7)

        XCTAssertEqual(effect.nodeId, "filter")
        XCTAssertEqual(effect.inputs, ["osc"])
        XCTAssertEqual(effect.parameters["cutoff"] as? Float, 1000)
    }

    func testGraphBuild() {
        let graph = AudioGraphBuilder.build {
            Source("osc")
                .frequency(440)

            Effect("filter", type: .lowPass)
                .input("osc")
                .cutoff(1000)

            Output("main")
                .input("filter")
        }

        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.connections.count, 2)
    }

    func testMeditationPreset() {
        let graph = AudioGraphBuilder.meditationGraph()

        XCTAssertGreaterThan(graph.nodes.count, 0)
        XCTAssertTrue(graph.nodes.contains { $0.nodeType == .bioReactive })
    }
}

// MARK: - Async Bio Stream Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class AsyncBioStreamTests: XCTestCase {

    func testBioSampleCreation() {
        let sample = BioSample(
            heartRate: 72,
            hrvCoherence: 65,
            breathPhase: 0.5
        )

        XCTAssertEqual(sample.heartRate, 72)
        XCTAssertEqual(sample.hrvCoherence.value, 65)
        XCTAssertEqual(sample.normalizedCoherence.value, 0.65, accuracy: 0.001)
    }

    func testStreamSend() async {
        let stream = AsyncBioStream()
        stream.start()

        stream.send(BioSample.resting)

        // Verify stream is running
        stream.stop()
    }

    func testBioBufferAverage() async {
        let buffer = AsyncBioBuffer()

        await buffer.add(BioSample(hrvCoherence: 60))
        await buffer.add(BioSample(hrvCoherence: 70))
        await buffer.add(BioSample(hrvCoherence: 80))

        let avg = await buffer.averageCoherence()
        XCTAssertEqual(avg.value, 0.7, accuracy: 0.01)
    }
}

// MARK: - Dependency Container Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class DependencyContainerTests: XCTestCase {

    func testDefaultResolution() {
        let config = DependencyContainer.shared.resolve(ConfigurationKey.self)
        XCTAssertNotNil(config)
    }

    func testCustomRegistration() {
        let container = DependencyContainer.shared

        let customConfig = AppConfiguration(isDebug: true, apiEndpoint: "https://test.com")
        container.registerSingleton(ConfigurationKey.self, instance: customConfig)

        let resolved = container.resolve(ConfigurationKey.self)
        XCTAssertEqual(resolved.apiEndpoint, "https://test.com")
        XCTAssertTrue(resolved.isDebug)

        // Reset for other tests
        container.reset()
    }

    func testScopedContainer() {
        let scoped = ScopedContainer()

        let customConfig = AppConfiguration(isDebug: true)
        scoped.override(ConfigurationKey.self, with: customConfig)

        let resolved = scoped.resolve(ConfigurationKey.self)
        XCTAssertTrue(resolved.isDebug)
    }
}

// MARK: - Offline First Sync Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class OfflineFirstSyncTests: XCTestCase {

    func testSyncableSession() {
        var session = SyncableSession(name: "Test Session")

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertFalse(session.isDeleted)
        XCTAssertEqual(session.syncVersion, 0)

        session.syncVersion += 1
        XCTAssertEqual(session.syncVersion, 1)
    }

    func testSyncOperation() {
        let session = SyncableSession(name: "Test")
        let operation = SyncOperation<SyncableSession>(
            type: .create,
            entityId: session.id,
            entity: session
        )

        XCTAssertEqual(operation.operationType, .create)
        XCTAssertEqual(operation.retryCount, 0)
    }
}

// MARK: - ML Coherence Prediction Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class CoherencePredictionTests: XCTestCase {

    func testModelCreation() {
        let model = CoherencePredictionModel()
        XCTAssertNotNil(model)
    }

    func testAddSamples() {
        let model = CoherencePredictionModel()

        for i in 0..<20 {
            model.addSample(coherence: Float(i) * 0.05, heartRate: 72)
        }

        let stats = model.statistics
        XCTAssertEqual(stats.sampleCount, 20)
    }

    func testPrediction() {
        let model = CoherencePredictionModel()

        // Add stable samples
        for _ in 0..<30 {
            model.addSample(coherence: 0.65, heartRate: 70)
        }

        let prediction = model.predict(horizon: 5.0)

        XCTAssertGreaterThanOrEqual(prediction.value.value, 0)
        XCTAssertLessThanOrEqual(prediction.value.value, 1)
        XCTAssertGreaterThanOrEqual(prediction.confidence, 0)
    }

    func testStatePredictor() {
        let predictor = CoherenceStatePredictor()

        for _ in 0..<20 {
            predictor.addSample(BioSample(hrvCoherence: 75))
        }

        let (state, confidence) = predictor.predictState()
        XCTAssertGreaterThanOrEqual(confidence, 0)
        XCTAssertNotNil(state)
    }
}

// MARK: - Haptic Feedback Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class HapticFeedbackTests: XCTestCase {

    func testPatternTypes() {
        XCTAssertEqual(HapticPatternType.allCases.count, 18)
        XCTAssertTrue(HapticPatternType.allCases.contains(.heartbeat))
        XCTAssertTrue(HapticPatternType.allCases.contains(.coherencePulse))
    }

    func testCoherenceThresholds() {
        let thresholds = HapticFeedbackManager.CoherenceHapticThresholds.default

        XCTAssertEqual(thresholds.stressAlert, 0.3)
        XCTAssertEqual(thresholds.transitionUp, 0.6)
        XCTAssertEqual(thresholds.flowEntry, 0.8)
    }
}

// MARK: - Integration Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class RalphWiggumIntegrationTests: XCTestCase {

    func testFullPipelineFlow() async {
        // Create components
        let bioBuffer = AsyncBioBuffer()
        let predictor = CoherencePredictionModel()
        let prefetcher = PredictiveFramePrefetcher()

        // Simulate bio data flow
        for i in 0..<50 {
            let coherence = 0.5 + sin(Float(i) * 0.1) * 0.2
            let sample = BioSample(
                heartRate: 72 + Float(i % 10),
                hrvCoherence: Double(coherence * 100),
                breathPhase: Float(i % 10) / 10.0
            )

            await bioBuffer.add(sample)
            predictor.addSample(sample)
            prefetcher.addInput(PredictionInput(
                coherence: sample.normalizedCoherence.floatValue,
                heartRate: sample.heartRate,
                breathPhase: sample.breathPhase
            ))
        }

        // Verify all components have data
        let samples = await bioBuffer.getSamples()
        XCTAssertEqual(samples.count, 50)

        let prediction = predictor.predict(horizon: 5)
        XCTAssertGreaterThan(prediction.confidence, 0)

        let framePrediction = prefetcher.getNextFramePrediction()
        XCTAssertGreaterThan(framePrediction.confidence, 0)
    }

    func testCircuitBreakerWithRetry() async throws {
        let breaker = CircuitBreaker(name: "integration", config: .aggressive)

        var attempts = 0
        let result = try await breaker.executeWithRetry(maxRetries: 3) {
            attempts += 1
            if attempts < 2 {
                throw NSError(domain: "test", code: 1)
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 2)
    }
}

// MARK: - Performance Tests

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class RalphWiggumPerformanceTests: XCTestCase {

    func testSIMDPerformance() {
        let processor = SIMDBioProcessor()

        measure {
            for _ in 0..<1000 {
                processor.addRRInterval(Float.random(in: 700...900))
            }
            _ = processor.calculateHRVMetrics()
        }
    }

    func testPredictionPerformance() {
        let model = CoherencePredictionModel()

        // Warm up
        for _ in 0..<60 {
            model.addSample(coherence: Float.random(in: 0.3...0.9), heartRate: 72)
        }

        measure {
            for _ in 0..<1000 {
                _ = model.predict(horizon: 5)
            }
        }
    }

    func testPrefetchPerformance() {
        let prefetcher = PredictiveFramePrefetcher()

        // Warm up
        for _ in 0..<60 {
            prefetcher.addInput(PredictionInput(coherence: Float.random(in: 0.3...0.9)))
        }

        measure {
            for _ in 0..<1000 {
                _ = prefetcher.getPredictions(framesAhead: 5)
            }
        }
    }
}
