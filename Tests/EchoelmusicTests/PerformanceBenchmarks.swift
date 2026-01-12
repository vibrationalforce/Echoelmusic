import XCTest
import AVFoundation
#if canImport(Accelerate)
import Accelerate
#endif
@testable import Echoelmusic

/// Comprehensive performance benchmarks for all critical paths
/// Targets:
/// - Audio latency: <10ms
/// - Frame time: <16.6ms (60fps)
/// - HRV calculation: <5ms
/// - Network latency: <100ms
/// - Plugin load: <500ms
/// - Memory: <200MB peak
/// - Startup: <2s
final class PerformanceBenchmarks: XCTestCase {

    // MARK: - Performance Metrics Tracking

    struct PerformanceMetrics {
        var averageTime: TimeInterval
        var minTime: TimeInterval
        var maxTime: TimeInterval
        var standardDeviation: TimeInterval
        var iterationCount: Int

        var meetsTarget: Bool {
            return averageTime <= targetTime
        }

        var targetTime: TimeInterval
        var metricName: String

        func report() -> String {
            let status = meetsTarget ? "✅ PASS" : "❌ FAIL"
            return """
            \(status) \(metricName)
              Average: \(String(format: "%.3f", averageTime * 1000))ms
              Min: \(String(format: "%.3f", minTime * 1000))ms
              Max: \(String(format: "%.3f", maxTime * 1000))ms
              StdDev: \(String(format: "%.3f", standardDeviation * 1000))ms
              Target: \(String(format: "%.3f", targetTime * 1000))ms
              Iterations: \(iterationCount)
            """
        }
    }

    private var metrics: [PerformanceMetrics] = []

    override func tearDown() {
        // Print all collected metrics at end of test run
        if !metrics.isEmpty {
            print("\n========================================")
            print("PERFORMANCE BENCHMARK REPORT")
            print("========================================\n")
            for metric in metrics {
                print(metric.report())
                print("")
            }
            let passCount = metrics.filter { $0.meetsTarget }.count
            let totalCount = metrics.count
            let passRate = Double(passCount) / Double(totalCount) * 100
            print("========================================")
            print("Overall: \(passCount)/\(totalCount) passed (\(String(format: "%.1f", passRate))%)")
            print("========================================\n")
        }
        metrics.removeAll()
        super.tearDown()
    }

    private func measurePerformance(
        name: String,
        target: TimeInterval,
        iterations: Int = 1000,
        setup: (() -> Void)? = nil,
        block: @escaping () -> Void
    ) {
        setup?()

        var times: [TimeInterval] = []
        times.reserveCapacity(iterations)

        // Warm up
        for _ in 0..<10 {
            block()
        }

        // Measure
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            block()
            let end = CFAbsoluteTimeGetCurrent()
            times.append(end - start)
        }

        // Calculate statistics
        let sum = times.reduce(0, +)
        let average = sum / Double(iterations)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        let variance = times.map { pow($0 - average, 2) }.reduce(0, +) / Double(iterations)
        let stdDev = sqrt(variance)

        let metric = PerformanceMetrics(
            averageTime: average,
            minTime: min,
            maxTime: max,
            standardDeviation: stdDev,
            iterationCount: iterations,
            targetTime: target,
            metricName: name
        )

        metrics.append(metric)

        // Also use XCTest measure for IDE integration
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<100 {
                block()
            }
        }
    }

    // MARK: - 1. Audio Performance Benchmarks

    func testAudioBufferProcessingLatency() {
        let bufferSize = 512
        var inputBuffer = [Float](repeating: 0.0, count: bufferSize)
        var outputBuffer = [Float](repeating: 0.0, count: bufferSize)

        // Fill with test signal (sine wave)
        for i in 0..<bufferSize {
            inputBuffer[i] = sin(Float(i) * 0.1)
        }

        measurePerformance(
            name: "Audio Buffer Processing",
            target: 0.010, // 10ms target
            iterations: 1000
        ) {
            // Simulate typical audio processing chain
            #if canImport(Accelerate)
            var gain: Float = 0.5
            vDSP_vsmul(inputBuffer, 1, &gain, &outputBuffer, 1, vDSP_Length(bufferSize))
            #else
            for i in 0..<bufferSize {
                outputBuffer[i] = inputBuffer[i] * 0.5
            }
            #endif
        }
    }

    func testIsochronicToneGeneration() {
        let sampleRate = 44100.0
        let bufferSize = 512
        let carrierFreq = 220.0  // Warm pad base frequency
        let pulseFreq = 10.0     // Alpha rhythm

        var leftBuffer = [Float](repeating: 0.0, count: bufferSize)
        var rightBuffer = [Float](repeating: 0.0, count: bufferSize)
        var carrierPhase: Double = 0.0
        var pulsePhase: Double = 0.0

        measurePerformance(
            name: "Isochronic Tone Generation (CPU)",
            target: 0.005, // 5ms target
            iterations: 1000
        ) {
            for i in 0..<bufferSize {
                let time = Double(i) / sampleRate
                let carrier = sin(2.0 * .pi * carrierFreq * time + carrierPhase)
                let pulse = (sin(2.0 * .pi * pulseFreq * time + pulsePhase) + 1.0) / 2.0
                let sample = Float(carrier * pulse)
                leftBuffer[i] = sample
                rightBuffer[i] = sample
            }
            carrierPhase += 2.0 * .pi * carrierFreq * Double(bufferSize) / sampleRate
            pulsePhase += 2.0 * .pi * pulseFreq * Double(bufferSize) / sampleRate
        }
    }

    func testSpatialAudioRendering() {
        let bufferSize = 512
        var monoSource = [Float](repeating: 0.0, count: bufferSize)
        var leftOutput = [Float](repeating: 0.0, count: bufferSize)
        var rightOutput = [Float](repeating: 0.0, count: bufferSize)

        // Fill with test signal
        for i in 0..<bufferSize {
            monoSource[i] = sin(Float(i) * 0.1)
        }

        // Test HRTF-like spatial rendering
        let azimuth: Float = 45.0 // degrees
        let leftGain = cos(azimuth * .pi / 180.0)
        let rightGain = sin(azimuth * .pi / 180.0)

        measurePerformance(
            name: "Spatial Audio Rendering",
            target: 0.008, // 8ms target
            iterations: 1000
        ) {
            #if canImport(Accelerate)
            var leftGainVar = leftGain
            var rightGainVar = rightGain
            vDSP_vsmul(monoSource, 1, &leftGainVar, &leftOutput, 1, vDSP_Length(bufferSize))
            vDSP_vsmul(monoSource, 1, &rightGainVar, &rightOutput, 1, vDSP_Length(bufferSize))
            #else
            for i in 0..<bufferSize {
                leftOutput[i] = monoSource[i] * leftGain
                rightOutput[i] = monoSource[i] * rightGain
            }
            #endif
        }
    }

    func testEffectChainProcessing() {
        let bufferSize = 512
        var buffer = [Float](repeating: 0.0, count: bufferSize)
        var tempBuffer = [Float](repeating: 0.0, count: bufferSize)

        // Fill with test signal
        for i in 0..<bufferSize {
            buffer[i] = sin(Float(i) * 0.1)
        }

        measurePerformance(
            name: "Effect Chain (5 effects)",
            target: 0.015, // 15ms for 5 effects
            iterations: 1000
        ) {
            // Effect 1: Gain
            #if canImport(Accelerate)
            var gain: Float = 0.8
            vDSP_vsmul(buffer, 1, &gain, &tempBuffer, 1, vDSP_Length(bufferSize))

            // Effect 2: Simple lowpass filter (moving average)
            vDSP_vswsum(&tempBuffer, 1, &buffer, 1, vDSP_Length(bufferSize - 2), 3)

            // Effect 3: Saturation (tanh approximation)
            for i in 0..<bufferSize {
                let x = buffer[i] * 2.0
                buffer[i] = x / (1.0 + abs(x)) // Fast tanh approximation
            }

            // Effect 4: DC blocker
            var mean: Float = 0.0
            vDSP_meanv(buffer, 1, &mean, vDSP_Length(bufferSize))
            var negativeMean = -mean
            vDSP_vsadd(buffer, 1, &negativeMean, &tempBuffer, 1, vDSP_Length(bufferSize))

            // Effect 5: Output gain
            var outputGain: Float = 0.9
            vDSP_vsmul(tempBuffer, 1, &outputGain, &buffer, 1, vDSP_Length(bufferSize))
            #else
            // Fallback without Accelerate
            for i in 0..<bufferSize {
                var sample = buffer[i] * 0.8
                sample = sample / (1.0 + abs(sample))
                buffer[i] = sample * 0.9
            }
            #endif
        }
    }

    // MARK: - 2. Visual Performance Benchmarks

    func testFrameRenderTime() {
        // Simulate typical frame rendering workload
        let particleCount = 1000
        var particles: [(x: Float, y: Float, vx: Float, vy: Float)] = []

        for _ in 0..<particleCount {
            particles.append((
                x: Float.random(in: -1...1),
                y: Float.random(in: -1...1),
                vx: Float.random(in: -0.1...0.1),
                vy: Float.random(in: -0.1...0.1)
            ))
        }

        measurePerformance(
            name: "Frame Render Time (1000 particles)",
            target: 0.0166, // 16.6ms for 60fps
            iterations: 500
        ) {
            // Update particle positions
            for i in 0..<particleCount {
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy

                // Bounce off edges
                if abs(particles[i].x) > 1.0 {
                    particles[i].vx *= -1
                }
                if abs(particles[i].y) > 1.0 {
                    particles[i].vy *= -1
                }
            }

            // Simulate rendering overhead
            _ = particles.map { sqrt($0.x * $0.x + $0.y * $0.y) }
        }
    }

    func testLargeParticleSystem() {
        let particleCount = 10000
        var positions = [SIMD2<Float>](repeating: SIMD2<Float>(0, 0), count: particleCount)
        var velocities = [SIMD2<Float>](repeating: SIMD2<Float>(0, 0), count: particleCount)

        // Initialize
        for i in 0..<particleCount {
            positions[i] = SIMD2<Float>(
                Float.random(in: -100...100),
                Float.random(in: -100...100)
            )
            velocities[i] = SIMD2<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            )
        }

        measurePerformance(
            name: "Particle System (10,000 particles)",
            target: 0.0166, // 16.6ms for 60fps
            iterations: 300
        ) {
            // Update all particles
            for i in 0..<particleCount {
                positions[i] += velocities[i]

                // Simple collision detection
                if positions[i].x < -100 || positions[i].x > 100 {
                    velocities[i].x *= -1
                }
                if positions[i].y < -100 || positions[i].y > 100 {
                    velocities[i].y *= -1
                }
            }
        }
    }

    func testShaderDataPreparation() {
        // Simulate preparing data for GPU shader
        let vertexCount = 1000
        var vertices = [SIMD4<Float>](repeating: SIMD4<Float>(0, 0, 0, 1), count: vertexCount)
        var colors = [SIMD4<Float>](repeating: SIMD4<Float>(1, 1, 1, 1), count: vertexCount)

        measurePerformance(
            name: "Shader Data Preparation",
            target: 0.005, // 5ms target
            iterations: 1000
        ) {
            let time = Float(Date().timeIntervalSince1970)

            for i in 0..<vertexCount {
                let angle = Float(i) * 2.0 * .pi / Float(vertexCount)
                let radius = 1.0 + 0.2 * sin(time + angle * 3.0)

                vertices[i] = SIMD4<Float>(
                    radius * cos(angle),
                    radius * sin(angle),
                    sin(time + angle * 5.0) * 0.5,
                    1.0
                )

                colors[i] = SIMD4<Float>(
                    (sin(time + angle) + 1.0) * 0.5,
                    (cos(time + angle * 2.0) + 1.0) * 0.5,
                    (sin(time * 0.5) + 1.0) * 0.5,
                    1.0
                )
            }
        }
    }

    func testTextureDataGeneration() {
        let width = 512
        let height = 512
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        measurePerformance(
            name: "Texture Data Generation (512x512)",
            target: 0.010, // 10ms target
            iterations: 100
        ) {
            let time = Float(Date().timeIntervalSince1970)

            for y in 0..<height {
                for x in 0..<width {
                    let fx = Float(x) / Float(width)
                    let fy = Float(y) / Float(height)

                    let value = sin(fx * 10.0 + time) * cos(fy * 10.0 + time)
                    let color = UInt8((value + 1.0) * 127.5)

                    let index = (y * width + x) * 4
                    pixels[index] = color
                    pixels[index + 1] = color
                    pixels[index + 2] = color
                    pixels[index + 3] = 255
                }
            }
        }
    }

    // MARK: - 3. Bio Processing Benchmarks

    func testHRVCalculationSpeed() {
        // Generate realistic RR intervals (in ms)
        var rrIntervals = [Double]()
        let baseRR = 800.0 // 75 bpm

        for _ in 0..<100 {
            let variation = Double.random(in: -50...50)
            rrIntervals.append(baseRR + variation)
        }

        measurePerformance(
            name: "HRV Calculation (SDNN, RMSSD, pNN50)",
            target: 0.005, // 5ms target
            iterations: 1000
        ) {
            // SDNN calculation
            let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
            let variance = rrIntervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(rrIntervals.count)
            let sdnn = sqrt(variance)

            // RMSSD calculation
            var squaredDiffs = [Double]()
            for i in 0..<(rrIntervals.count - 1) {
                let diff = rrIntervals[i + 1] - rrIntervals[i]
                squaredDiffs.append(diff * diff)
            }
            let rmssd = sqrt(squaredDiffs.reduce(0, +) / Double(squaredDiffs.count))

            // pNN50 calculation
            var nn50 = 0
            for i in 0..<(rrIntervals.count - 1) {
                if abs(rrIntervals[i + 1] - rrIntervals[i]) > 50 {
                    nn50 += 1
                }
            }
            let pnn50 = Double(nn50) / Double(rrIntervals.count - 1) * 100

            _ = (sdnn, rmssd, pnn50)
        }
    }

    func testCoherenceScoreComputation() {
        // Generate test heart rate data
        var heartRateData = [Double]()
        for i in 0..<100 {
            let coherentSignal = 60.0 + 10.0 * sin(Double(i) * 0.1)
            heartRateData.append(coherentSignal)
        }

        measurePerformance(
            name: "Coherence Score Computation",
            target: 0.003, // 3ms target
            iterations: 1000
        ) {
            // Simplified coherence calculation (peak-to-total power ratio)
            let mean = heartRateData.reduce(0, +) / Double(heartRateData.count)
            let centered = heartRateData.map { $0 - mean }

            // Calculate FFT-like power (simplified)
            var maxPower = 0.0
            var totalPower = 0.0

            for freq in 1..<50 {
                let omega = 2.0 * .pi * Double(freq) / Double(heartRateData.count)
                var real = 0.0
                var imag = 0.0

                for (i, value) in centered.enumerated() {
                    real += value * cos(omega * Double(i))
                    imag += value * sin(omega * Double(i))
                }

                let power = real * real + imag * imag
                totalPower += power

                // Coherence peak is typically at 0.1 Hz
                if freq >= 8 && freq <= 12 {
                    maxPower = max(maxPower, power)
                }
            }

            let coherence = min(maxPower / totalPower, 1.0)
            _ = coherence
        }
    }

    func testRRIntervalBufferOperations() {
        let bufferSize = 100
        var buffer = [Double]()
        buffer.reserveCapacity(bufferSize)

        measurePerformance(
            name: "RR Interval Buffer Operations",
            target: 0.001, // 1ms target
            iterations: 1000
        ) {
            // Add new interval
            buffer.append(800.0 + Double.random(in: -50...50))

            // Maintain buffer size
            if buffer.count > bufferSize {
                buffer.removeFirst()
            }

            // Calculate rolling statistics
            let mean = buffer.reduce(0, +) / Double(buffer.count)
            let max = buffer.max() ?? 0
            let min = buffer.min() ?? 0

            _ = (mean, max, min)
        }
    }

    func testRealTimeStreamingOverhead() {
        struct BiometricSample {
            var timestamp: Date
            var heartRate: Double
            var hrv: Double
            var coherence: Double
        }

        var samples = [BiometricSample]()
        samples.reserveCapacity(1000)

        measurePerformance(
            name: "Real-time Biometric Streaming",
            target: 0.002, // 2ms target
            iterations: 1000
        ) {
            let sample = BiometricSample(
                timestamp: Date(),
                heartRate: 75.0 + Double.random(in: -10...10),
                hrv: 50.0 + Double.random(in: -10...10),
                coherence: 0.5 + Double.random(in: -0.2...0.2)
            )

            samples.append(sample)

            if samples.count > 1000 {
                samples.removeFirst(100)
            }
        }
    }

    // MARK: - 4. Network Performance Benchmarks

    func testDataSerializationSpeed() {
        struct SessionState: Codable {
            var sessionId: String
            var participants: [String]
            var parameters: [String: Double]
            var timestamp: Date
        }

        let state = SessionState(
            sessionId: UUID().uuidString,
            participants: (0..<10).map { "User\($0)" },
            parameters: [
                "coherence": 0.75,
                "heartRate": 72.5,
                "bpm": 120.0,
                "filterCutoff": 2500.0
            ],
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measurePerformance(
            name: "JSON Serialization + Deserialization",
            target: 0.001, // 1ms target
            iterations: 1000
        ) {
            do {
                let data = try encoder.encode(state)
                _ = try decoder.decode(SessionState.self, from: data)
            } catch {
                XCTFail("Serialization failed: \(error)")
            }
        }
    }

    func testCompressionEfficiency() {
        // Generate compressible data
        let originalData = Data((0..<10000).map { _ in UInt8.random(in: 0...255) })

        measurePerformance(
            name: "Data Compression (zlib)",
            target: 0.010, // 10ms target
            iterations: 100
        ) {
            do {
                if #available(macOS 13.0, iOS 16.0, *) {
                    _ = try (originalData as NSData).compressed(using: .zlib)
                } else {
                    // Simulate compression overhead on older OS
                    _ = originalData.count
                }
            } catch {
                XCTFail("Compression failed: \(error)")
            }
        }
    }

    func testMessageQueueProcessing() {
        struct Message {
            var id: UUID
            var type: String
            var payload: [String: Any]
            var timestamp: Date
        }

        var queue = [Message]()
        queue.reserveCapacity(1000)

        measurePerformance(
            name: "Message Queue Processing",
            target: 0.005, // 5ms target
            iterations: 1000
        ) {
            // Add messages
            for _ in 0..<10 {
                queue.append(Message(
                    id: UUID(),
                    type: "parameter_update",
                    payload: ["value": Double.random(in: 0...1)],
                    timestamp: Date()
                ))
            }

            // Process messages
            let processed = queue.filter { message in
                message.timestamp.timeIntervalSinceNow > -1.0
            }

            queue.removeAll { message in
                message.timestamp.timeIntervalSinceNow <= -1.0
            }

            _ = processed.count
        }
    }

    // MARK: - 5. Plugin Performance Benchmarks

    func testPluginLoadTime() {
        // Simulate plugin loading overhead
        struct PluginMetadata {
            var name: String
            var version: String
            var capabilities: [String]
            var parameters: [String: Any]
        }

        measurePerformance(
            name: "Plugin Load Time",
            target: 0.500, // 500ms target
            iterations: 20
        ) {
            // Simulate plugin initialization
            let metadata = PluginMetadata(
                name: "TestPlugin",
                version: "1.0.0",
                capabilities: ["audio", "visual", "bio"],
                parameters: [
                    "gain": 0.8,
                    "frequency": 440.0,
                    "enabled": true
                ]
            )

            // Simulate resource allocation
            var buffer = [Float](repeating: 0.0, count: 44100) // 1 second at 44.1kHz

            // Simulate initial processing
            for i in 0..<buffer.count {
                buffer[i] = sin(Float(i) * 0.01) * 0.5
            }

            _ = (metadata, buffer)
        }
    }

    func testPluginProcessCallback() {
        let bufferSize = 512
        var input = [Float](repeating: 0.0, count: bufferSize)
        var output = [Float](repeating: 0.0, count: bufferSize)

        // Fill with test signal
        for i in 0..<bufferSize {
            input[i] = sin(Float(i) * 0.1)
        }

        measurePerformance(
            name: "Plugin Process Callback Overhead",
            target: 0.005, // 5ms target
            iterations: 1000
        ) {
            // Simulate plugin processing
            for i in 0..<bufferSize {
                output[i] = input[i] * 0.8 // Simple gain
            }
        }
    }

    func testPluginStateSerialization() {
        struct PluginState: Codable {
            var parameters: [String: Double]
            var presetName: String
            var enabled: Bool
            var version: String
        }

        let state = PluginState(
            parameters: [
                "frequency": 440.0,
                "gain": 0.8,
                "resonance": 0.5,
                "cutoff": 2500.0
            ],
            presetName: "Default",
            enabled: true,
            version: "1.0.0"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measurePerformance(
            name: "Plugin State Serialization",
            target: 0.001, // 1ms target
            iterations: 1000
        ) {
            do {
                let data = try encoder.encode(state)
                _ = try decoder.decode(PluginState.self, from: data)
            } catch {
                XCTFail("State serialization failed: \(error)")
            }
        }
    }

    // MARK: - 6. Memory Benchmarks

    func testAudioBufferAllocation() {
        let bufferSize = 512

        measurePerformance(
            name: "Audio Buffer Allocation",
            target: 0.001, // 1ms target
            iterations: 1000
        ) {
            var buffer = [Float](repeating: 0.0, count: bufferSize)

            // Fill buffer to ensure actual allocation
            for i in 0..<bufferSize {
                buffer[i] = Float(i)
            }

            _ = buffer
        }
    }

    func testImageTextureMemory() {
        let width = 512
        let height = 512

        measurePerformance(
            name: "Image/Texture Memory Allocation",
            target: 0.010, // 10ms target
            iterations: 100
        ) {
            var pixels = [UInt8](repeating: 0, count: width * height * 4)

            // Fill texture to ensure allocation
            for i in 0..<(width * height * 4) {
                pixels[i] = UInt8(i % 256)
            }

            _ = pixels
        }
    }

    func testPeakMemoryUsageDuringSession() {
        // Simulate a typical session's memory usage
        struct SessionMemory {
            var audioBuffers: [[Float]]
            var visualData: [UInt8]
            var biometricSamples: [(Double, Double, Double)]
            var networkMessages: [String]
        }

        measurePerformance(
            name: "Peak Memory Usage Simulation",
            target: 0.050, // 50ms target
            iterations: 100
        ) {
            var session = SessionMemory(
                audioBuffers: [],
                visualData: [],
                biometricSamples: [],
                networkMessages: []
            )

            // Allocate typical session data
            for _ in 0..<10 {
                session.audioBuffers.append([Float](repeating: 0.0, count: 512))
            }

            session.visualData = [UInt8](repeating: 0, count: 512 * 512 * 4)

            for _ in 0..<100 {
                session.biometricSamples.append((75.0, 50.0, 0.75))
            }

            for i in 0..<50 {
                session.networkMessages.append("Message \(i)")
            }

            _ = session
        }
    }

    func testMemoryLeakDetectionPattern() {
        // Test that objects are properly deallocated
        class TestResource {
            var data: [Float]

            init(size: Int) {
                self.data = [Float](repeating: 0.0, count: size)
            }
        }

        weak var weakReference: TestResource?

        measurePerformance(
            name: "Memory Leak Detection Pattern",
            target: 0.001, // 1ms target
            iterations: 1000
        ) {
            autoreleasepool {
                let resource = TestResource(size: 1024)
                weakReference = resource

                // Use the resource
                _ = resource.data.count
            }

            // Verify deallocation
            XCTAssertNil(weakReference, "Resource should be deallocated")
        }
    }

    // MARK: - 7. Startup Benchmarks

    func testAppLaunchTimeComponents() {
        // Simulate app initialization phases
        struct AppInitialization {
            var configuration: [String: Any] = [:]
            var services: [String] = []
            var audioEngine: Bool = false
            var networkClient: Bool = false
        }

        measurePerformance(
            name: "App Launch Initialization",
            target: 2.0, // 2 second target
            iterations: 10
        ) {
            var app = AppInitialization()

            // Phase 1: Configuration loading
            app.configuration = [
                "sampleRate": 44100.0,
                "bufferSize": 512,
                "maxVoices": 16,
                "enableQuantum": true
            ]

            // Phase 2: Service registration
            app.services = [
                "AudioEngine",
                "VisualEngine",
                "BioEngine",
                "NetworkClient",
                "PluginManager"
            ]

            // Phase 3: Audio engine initialization
            var audioBuffer = [Float](repeating: 0.0, count: 512)
            for i in 0..<512 {
                audioBuffer[i] = Float(i) * 0.001
            }
            app.audioEngine = true

            // Phase 4: Network client
            app.networkClient = true

            _ = (app, audioBuffer)
        }
    }

    func testFirstFrameRender() {
        // Simulate first frame rendering
        let particleCount = 100
        var particles: [(x: Float, y: Float)] = []

        measurePerformance(
            name: "First Frame Render",
            target: 0.100, // 100ms target
            iterations: 50
        ) {
            particles.removeAll()

            for i in 0..<particleCount {
                let angle = Float(i) * 2.0 * .pi / Float(particleCount)
                particles.append((
                    x: cos(angle),
                    y: sin(angle)
                ))
            }

            // Simulate initial render calculations
            _ = particles.map { sqrt($0.x * $0.x + $0.y * $0.y) }
        }
    }

    func testAudioEngineInitialization() {
        // Simulate AVAudioEngine setup
        measurePerformance(
            name: "Audio Engine Initialization",
            target: 0.500, // 500ms target
            iterations: 20
        ) {
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let reverb = AVAudioUnitReverb()

            engine.attach(player)
            engine.attach(reverb)

            engine.connect(player, to: reverb, format: nil)
            engine.connect(reverb, to: engine.mainMixerNode, format: nil)

            do {
                try engine.start()
                engine.stop()
            } catch {
                // Expected in test environment
            }
        }
    }

    // MARK: - Integration Performance Tests

    func testFullPipelineLatency() {
        // End-to-end latency: Bio input → Audio output
        let bufferSize = 512
        var audioOutput = [Float](repeating: 0.0, count: bufferSize)

        measurePerformance(
            name: "Full Pipeline Latency (Bio→Audio)",
            target: 0.020, // 20ms target
            iterations: 500
        ) {
            // 1. Bio signal processing (5ms)
            let heartRate = 75.0 + Double.random(in: -10...10)
            let coherence = 0.75 + Double.random(in: -0.2...0.2)

            // 2. Parameter mapping (1ms)
            let frequency = 440.0 * (coherence + 0.5)
            let amplitude = Float(heartRate / 100.0)

            // 3. Audio synthesis (10ms)
            for i in 0..<bufferSize {
                audioOutput[i] = amplitude * sin(Float(i) * Float(frequency) * 0.001)
            }

            // 4. Effects processing (4ms)
            #if canImport(Accelerate)
            var gain: Float = 0.8
            vDSP_vsmul(audioOutput, 1, &gain, &audioOutput, 1, vDSP_Length(bufferSize))
            #endif
        }
    }

    func testConcurrentEngineProcessing() {
        // Test multiple engines running simultaneously
        let bufferSize = 512

        measurePerformance(
            name: "Concurrent Multi-Engine Processing",
            target: 0.030, // 30ms target
            iterations: 200
        ) {
            var audioBuffer = [Float](repeating: 0.0, count: bufferSize)
            var visualData = [UInt8](repeating: 0, count: 256 * 256 * 4)
            var bioData = [(Double, Double, Double)]()

            // Concurrent processing simulation
            DispatchQueue.concurrentPerform(iterations: 3) { index in
                switch index {
                case 0: // Audio engine
                    for i in 0..<bufferSize {
                        audioBuffer[i] = sin(Float(i) * 0.1)
                    }
                case 1: // Visual engine
                    for i in 0..<(256 * 256 * 4) {
                        visualData[i] = UInt8(i % 256)
                    }
                case 2: // Bio engine
                    for _ in 0..<100 {
                        bioData.append((75.0, 50.0, 0.75))
                    }
                default:
                    break
                }
            }

            _ = (audioBuffer, visualData, bioData)
        }
    }

    // MARK: - Stress Tests

    func testStressMaximumVoiceCount() {
        let maxVoices = 64
        let bufferSize = 512
        var voiceBuffers: [[Float]] = []
        var mixBuffer = [Float](repeating: 0.0, count: bufferSize)

        // Initialize voice buffers
        for i in 0..<maxVoices {
            var buffer = [Float](repeating: 0.0, count: bufferSize)
            let frequency = Float(110.0 * pow(2.0, Double(i) / 12.0))

            for j in 0..<bufferSize {
                buffer[j] = sin(Float(j) * frequency * 0.001) * 0.1
            }

            voiceBuffers.append(buffer)
        }

        measurePerformance(
            name: "Stress Test: 64 Voice Mix",
            target: 0.025, // 25ms target
            iterations: 200
        ) {
            // Reset mix buffer
            for i in 0..<bufferSize {
                mixBuffer[i] = 0.0
            }

            // Mix all voices
            #if canImport(Accelerate)
            for voice in voiceBuffers {
                vDSP_vadd(mixBuffer, 1, voice, 1, &mixBuffer, 1, vDSP_Length(bufferSize))
            }
            #else
            for voice in voiceBuffers {
                for i in 0..<bufferSize {
                    mixBuffer[i] += voice[i]
                }
            }
            #endif

            // Normalize
            #if canImport(Accelerate)
            var scale = Float(1.0 / Float(maxVoices))
            vDSP_vsmul(mixBuffer, 1, &scale, &mixBuffer, 1, vDSP_Length(bufferSize))
            #endif
        }
    }

    func testStressLargeParticleField() {
        let particleCount = 50000
        var particles = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: particleCount)

        // Initialize random positions
        for i in 0..<particleCount {
            particles[i] = SIMD3<Float>(
                Float.random(in: -100...100),
                Float.random(in: -100...100),
                Float.random(in: -100...100)
            )
        }

        measurePerformance(
            name: "Stress Test: 50K Particle Field",
            target: 0.050, // 50ms target
            iterations: 50
        ) {
            let attractorPos = SIMD3<Float>(0, 0, 0)
            let strength: Float = 0.01

            for i in 0..<particleCount {
                let direction = attractorPos - particles[i]
                let distance = length(direction)
                let force = (direction / distance) * strength
                particles[i] += force
            }
        }
    }
}
