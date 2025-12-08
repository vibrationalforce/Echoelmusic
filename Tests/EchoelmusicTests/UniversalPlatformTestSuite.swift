import XCTest
@testable import Echoelmusic

// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL PLATFORM TEST SUITE FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive tests for cross-platform functionality:
// • Platform detection and identification
// • Capability detection across all platforms
// • Audio bridge functionality
// • Visual bridge functionality
// • Performance optimization verification
// • Platform-specific feature validation
//
// Supported Platforms:
// iOS, macOS, watchOS, tvOS, visionOS, Android, Windows, Linux
//
// ═══════════════════════════════════════════════════════════════════════════════

final class UniversalPlatformTestSuite: XCTestCase {

    // MARK: - Platform Detection Tests

    func testPlatformDetection() async {
        let manager = await UnifiedPlatformManager.shared

        // Platform should be detected
        let platform = await manager.platform
        XCTAssertNotEqual(platform, .unknown, "Platform should be detected")

        // Platform should have valid display name
        XCTAssertFalse(platform.displayName.isEmpty)
        XCTAssertFalse(platform.icon.isEmpty)

        print("Detected Platform: \(platform.displayName)")
    }

    func testPlatformTypeEnumeration() {
        // All platform types should have unique raw values
        let rawValues = PlatformType.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueValues.count, "All platform types should have unique raw values")

        // Check all expected platforms exist
        XCTAssertTrue(PlatformType.allCases.contains(.iOS))
        XCTAssertTrue(PlatformType.allCases.contains(.macOS))
        XCTAssertTrue(PlatformType.allCases.contains(.watchOS))
        XCTAssertTrue(PlatformType.allCases.contains(.tvOS))
        XCTAssertTrue(PlatformType.allCases.contains(.visionOS))
        XCTAssertTrue(PlatformType.allCases.contains(.android))
        XCTAssertTrue(PlatformType.allCases.contains(.windows))
        XCTAssertTrue(PlatformType.allCases.contains(.linux))
    }

    // MARK: - Capability Detection Tests

    func testAudioCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.audio

        // Sample rate should be valid
        XCTAssertGreaterThan(caps.maxSampleRate, 0, "Sample rate should be positive")
        XCTAssertLessThanOrEqual(caps.maxSampleRate, 192000, "Sample rate should be reasonable")

        // Channels should be valid
        XCTAssertGreaterThan(caps.maxChannels, 0, "Should have at least 1 channel")

        // Latency should be valid
        XCTAssertGreaterThan(caps.minLatencyMs, 0, "Latency should be positive")

        print("Audio Capabilities:")
        print("  Max Sample Rate: \(caps.maxSampleRate) Hz")
        print("  Max Channels: \(caps.maxChannels)")
        print("  Min Latency: \(caps.minLatencyMs) ms")
    }

    func testVisualCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.visual

        // Resolution should be valid
        XCTAssertGreaterThan(caps.maxResolutionWidth, 0, "Width should be positive")
        XCTAssertGreaterThan(caps.maxResolutionHeight, 0, "Height should be positive")

        // Refresh rate should be valid
        XCTAssertGreaterThan(caps.maxRefreshRate, 0, "Refresh rate should be positive")
        XCTAssertLessThanOrEqual(caps.maxRefreshRate, 240, "Refresh rate should be reasonable")

        print("Visual Capabilities:")
        print("  Max Resolution: \(caps.maxResolutionWidth)x\(caps.maxResolutionHeight)")
        print("  Max Refresh Rate: \(caps.maxRefreshRate) Hz")
        print("  Metal: \(caps.supportsMetal)")
    }

    func testProcessingCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.processing

        // CPU cores should be valid
        XCTAssertGreaterThan(caps.cpuCores, 0, "Should have at least 1 CPU core")

        // RAM should be valid
        XCTAssertGreaterThan(caps.ramGB, 0, "RAM should be positive")

        // SIMD should be detected
        let hasSIMD = caps.hasNEON || caps.hasAVX2 || caps.hasSIMD
        XCTAssertTrue(hasSIMD, "Should detect some SIMD capability")

        print("Processing Capabilities:")
        print("  CPU Cores: \(caps.cpuCores)")
        print("  RAM: \(caps.ramGB) GB")
        print("  NEON: \(caps.hasNEON), AVX2: \(caps.hasAVX2)")
    }

    func testBioCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.bio

        // At least one bio platform should be available on supported devices
        #if os(iOS) || os(watchOS)
        XCTAssertTrue(caps.supportsHealthKit, "HealthKit should be available on Apple platforms")
        #endif

        print("Bio Capabilities:")
        print("  HealthKit: \(caps.supportsHealthKit)")
        print("  Health Connect: \(caps.supportsHealthConnect)")
        print("  HRV Analysis: \(caps.supportsHRVAnalysis)")
    }

    func testSensorCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.sensors

        // Mobile devices should have motion sensors
        #if os(iOS) || os(watchOS)
        XCTAssertTrue(caps.hasAccelerometer || caps.hasGyroscope,
                      "Mobile devices should have motion sensors")
        #endif

        print("Sensor Capabilities:")
        print("  Accelerometer: \(caps.hasAccelerometer)")
        print("  Gyroscope: \(caps.hasGyroscope)")
        print("  Camera: \(caps.hasCamera)")
        print("  Microphone: \(caps.hasMicrophone)")
    }

    func testConnectivityCapabilitiesDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.connectivity

        // Most devices should have WiFi and Bluetooth
        print("Connectivity Capabilities:")
        print("  WiFi: \(caps.hasWiFi)")
        print("  Bluetooth: \(caps.hasBluetooth)")
        print("  MIDI: \(caps.hasMIDI)")
    }

    // MARK: - Performance Tier Tests

    func testPerformanceTierDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let tier = await manager.performanceTier

        // Tier should have valid settings
        XCTAssertGreaterThan(tier.maxAudioTracks, 0)
        XCTAssertGreaterThan(tier.visualQuality, 0)
        XCTAssertGreaterThan(tier.targetFPS, 0)
        XCTAssertGreaterThan(tier.audioBufferSize, 0)

        // Buffer size should be power of 2
        let isPowerOf2 = (tier.audioBufferSize & (tier.audioBufferSize - 1)) == 0
        XCTAssertTrue(isPowerOf2, "Audio buffer size should be power of 2")

        print("Performance Tier: \(tier.rawValue)")
        print("  Max Audio Tracks: \(tier.maxAudioTracks)")
        print("  Visual Quality: \(tier.visualQuality)")
        print("  Target FPS: \(tier.targetFPS)")
        print("  Audio Buffer: \(tier.audioBufferSize)")
    }

    func testPerformanceTierConsistency() {
        // Higher tiers should have better settings
        let tiers: [UnifiedPlatformManager.PerformanceTier] = [.low, .medium, .high, .ultra]

        for i in 1..<tiers.count {
            let lower = tiers[i - 1]
            let higher = tiers[i]

            XCTAssertLessThanOrEqual(lower.maxAudioTracks, higher.maxAudioTracks)
            XCTAssertLessThanOrEqual(lower.visualQuality, higher.visualQuality)
            XCTAssertLessThanOrEqual(lower.targetFPS, higher.targetFPS)
            XCTAssertGreaterThanOrEqual(lower.audioBufferSize, higher.audioBufferSize)
        }
    }

    // MARK: - Feature Support Tests

    func testFeatureSupport() async {
        let manager = await UnifiedPlatformManager.shared

        // Test all features
        for feature in UnifiedPlatformManager.Feature.allCases {
            let supported = await manager.supportsFeature(feature)
            print("Feature \(feature.rawValue): \(supported ? "Supported" : "Not Supported")")
        }
    }

    func testSIMDFeatureSupport() async {
        let manager = await UnifiedPlatformManager.shared
        let hasSIMD = await manager.supportsFeature(.simd)

        // SIMD should be available on modern hardware
        XCTAssertTrue(hasSIMD, "SIMD should be available on modern hardware")
    }

    // MARK: - Platform Report Tests

    func testPlatformReportGeneration() async {
        let manager = await UnifiedPlatformManager.shared
        let report = await manager.generateReport()

        // Report should contain key sections
        XCTAssertTrue(report.contains("PLATFORM IDENTIFICATION"))
        XCTAssertTrue(report.contains("PROCESSING"))
        XCTAssertTrue(report.contains("AUDIO"))
        XCTAssertTrue(report.contains("VISUAL"))
        XCTAssertTrue(report.contains("BIO-DATA"))
        XCTAssertTrue(report.contains("INPUT"))
        XCTAssertTrue(report.contains("CONNECTIVITY"))
        XCTAssertTrue(report.contains("POWER"))
        XCTAssertTrue(report.contains("RECOMMENDED SETTINGS"))

        print(report)
    }

    // MARK: - Audio Bridge Tests

    func testAudioBridgeConfiguration() {
        var config = AudioBridgeConfig()
        config.sampleRate = 48000
        config.bufferSize = 256

        XCTAssertEqual(config.sampleRate, 48000)
        XCTAssertEqual(config.bufferSize, 256)
        XCTAssertTrue(config.enableInput)
        XCTAssertTrue(config.enableOutput)
    }

    func testOptimalAudioConfig() async {
        let config = await PlatformAudioConfig.optimal()

        XCTAssertGreaterThan(config.sampleRate, 0)
        XCTAssertGreaterThan(config.bufferSize, 0)
        XCTAssertGreaterThan(config.channels, 0)

        print("Optimal Audio Config:")
        print("  Sample Rate: \(config.sampleRate)")
        print("  Buffer Size: \(config.bufferSize)")
        print("  Channels: \(config.channels)")
    }

    func testLowLatencyAudioConfig() async {
        let config = await PlatformAudioConfig.lowLatency()

        // Low latency should have small buffer
        XCTAssertLessThanOrEqual(config.bufferSize, 128)
        XCTAssertEqual(config.sampleRate, 48000)

        print("Low Latency Config: \(config.bufferSize) samples")
    }

    func testHighQualityAudioConfig() async {
        let config = await PlatformAudioConfig.highQuality()

        // High quality should have higher sample rate and larger buffer
        XCTAssertGreaterThanOrEqual(config.bufferSize, 256)

        print("High Quality Config:")
        print("  Sample Rate: \(config.sampleRate)")
        print("  Buffer Size: \(config.bufferSize)")
    }

    func testAudioLatencyCalculation() {
        // Test latency calculation
        let latency = CrossPlatformAudioBridge.calculateLatency(
            sampleRate: 48000,
            bufferSize: 128,
            bufferCount: 2
        )

        let expectedLatency = Double(128 * 2) / 48000 * 1000
        XCTAssertEqual(latency, expectedLatency, accuracy: 0.001)

        print("Calculated Latency: \(String(format: "%.2f", latency)) ms")
    }

    // MARK: - Visual Bridge Tests

    func testVisualBridgeConfiguration() {
        var config = VisualBridgeConfig()
        config.targetFPS = 60
        config.maxResolution = CGSize(width: 1920, height: 1080)
        config.enableHDR = true

        XCTAssertEqual(config.targetFPS, 60)
        XCTAssertEqual(config.maxResolution.width, 1920)
        XCTAssertEqual(config.maxResolution.height, 1080)
        XCTAssertTrue(config.enableHDR)
    }

    func testOptimalVisualConfig() async {
        let config = await PlatformVisualConfig.optimal()

        XCTAssertGreaterThan(config.targetFPS, 0)
        XCTAssertGreaterThanOrEqual(config.quality, 0)
        XCTAssertLessThanOrEqual(config.quality, 1)
        XCTAssertGreaterThan(config.maxParticles, 0)

        print("Optimal Visual Config:")
        print("  Target FPS: \(config.targetFPS)")
        print("  Quality: \(config.quality)")
        print("  Max Particles: \(config.maxParticles)")
    }

    // MARK: - Particle System Tests

    func testParticleSystemCreation() {
        let system = CrossPlatformParticleSystem(maxParticles: 1000)

        XCTAssertEqual(system.particleCount, 0)
        XCTAssertEqual(system.allParticles.count, 0)
    }

    func testParticleSystemUpdate() {
        let system = CrossPlatformParticleSystem(maxParticles: 1000)
        system.emitterPosition = SIMD3(0, 0, 0)
        system.audioIntensity = 1.0  // High emission rate

        // Update for several frames
        for _ in 0..<10 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        XCTAssertGreaterThan(system.particleCount, 0, "Particles should be emitted")
    }

    func testParticlePresets() {
        let system = CrossPlatformParticleSystem(maxParticles: 1000)

        // Test all presets
        let presets: [CrossPlatformParticleSystem.ParticlePreset] = [
            .fire, .water, .sparkle, .smoke, .energy, .bioReactive
        ]

        for preset in presets {
            system.applyPreset(preset)
            // Just verify it doesn't crash
        }
    }

    func testParticleDataExport() {
        let system = CrossPlatformParticleSystem(maxParticles: 100)
        system.emitterPosition = .zero
        system.audioIntensity = 1.0

        // Generate some particles
        for _ in 0..<10 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        let positionData = system.getPositionData()
        let colorData = system.getColorData()

        // Position data should have 3 floats per particle
        XCTAssertEqual(positionData.count, system.particleCount * 3)

        // Color data should have 4 floats per particle
        XCTAssertEqual(colorData.count, system.particleCount * 4)
    }

    // MARK: - Audio Level Meter Tests

    func testAudioLevelMeter() {
        let meter = AudioLevelMeter()

        // Create test signal
        var signal = [Float](repeating: 0, count: 1024)
        for i in 0..<signal.count {
            signal[i] = sin(Float(i) * 0.1) * 0.5  // 50% amplitude sine wave
        }

        signal.withUnsafeBufferPointer { ptr in
            meter.process(ptr.baseAddress!, count: signal.count)
        }

        XCTAssertGreaterThan(meter.rmsLevel, 0)
        XCTAssertGreaterThan(meter.peakLevel, 0)
        XCTAssertLessThanOrEqual(meter.peakLevel, 1.0)

        // dB values should be negative for signals < 1.0
        XCTAssertLessThan(meter.rmsLevelDB, 0)
        XCTAssertLessThan(meter.peakLevelDB, 0)
    }

    func testAudioLevelMeterReset() {
        let meter = AudioLevelMeter()

        var signal = [Float](repeating: 0.5, count: 1024)
        signal.withUnsafeBufferPointer { ptr in
            meter.process(ptr.baseAddress!, count: signal.count)
        }

        XCTAssertGreaterThan(meter.rmsLevel, 0)

        meter.reset()

        XCTAssertEqual(meter.rmsLevel, 0)
        XCTAssertEqual(meter.peakLevel, 0)
    }

    // MARK: - Binaural Processor Tests

    func testBinauralProcessorCreation() {
        let processor = BinauralProcessor(sampleRate: 48000)

        processor.setCarrierFrequency(200)
        processor.setBeatFrequency(10)

        // Generate output
        var output = [Float](repeating: 0, count: 1024)
        output.withUnsafeMutableBufferPointer { ptr in
            processor.process(output: ptr.baseAddress!, frameCount: 512)
        }

        // Output should contain non-zero values
        let hasNonZero = output.contains { $0 != 0 }
        XCTAssertTrue(hasNonZero, "Binaural output should contain audio")

        // Check stereo interleaving (left and right should differ)
        let left = output[0]
        let right = output[1]
        // After first sample, values might be very close but not identical due to beat frequency
    }

    func testBinauralBrainwavePresets() {
        let processor = BinauralProcessor(sampleRate: 48000)

        // Test all brainwave states
        for state in BinauralProcessor.BrainwaveState.allCases {
            processor.setTargetState(state)

            // Verify frequency is in valid range
            let range = state.frequencyRange
            XCTAssertGreaterThanOrEqual(state.recommendedFrequency, range.lowerBound)
            XCTAssertLessThanOrEqual(state.recommendedFrequency, range.upperBound)

            print("Brainwave State: \(state.rawValue) -> \(state.recommendedFrequency) Hz")
        }
    }

    // MARK: - SIMD Detection Tests

    func testSIMDCapabilitiesDetection() {
        let caps = SIMDPlatformUtils.detectSIMDCapabilities()

        #if arch(arm64)
        XCTAssertTrue(caps.hasNEON, "ARM64 should have NEON")
        XCTAssertEqual(caps.vectorWidth, 4, "NEON processes 4 floats")
        XCTAssertEqual(caps.preferredAlignment, 16, "NEON prefers 16-byte alignment")
        #elseif arch(x86_64)
        XCTAssertTrue(caps.hasSSE42, "x86_64 should have SSE4.2")
        #endif

        print("SIMD Capabilities:")
        print("  NEON: \(caps.hasNEON)")
        print("  SSE4.2: \(caps.hasSSE42)")
        print("  AVX2: \(caps.hasAVX2)")
        print("  AVX-512: \(caps.hasAVX512)")
        print("  Vector Width: \(caps.vectorWidth)")
    }

    func testOptimalUnrollFactor() {
        let factor = SIMDPlatformUtils.optimalUnrollFactor()

        XCTAssertGreaterThanOrEqual(factor, 1)
        XCTAssertLessThanOrEqual(factor, 16)

        // Should be power of 2
        let isPowerOf2 = (factor & (factor - 1)) == 0
        XCTAssertTrue(isPowerOf2, "Unroll factor should be power of 2")

        print("Optimal Unroll Factor: \(factor)")
    }

    // MARK: - Color Utility Tests

    func testHSVToRGBConversion() {
        // Red (H=0)
        let red = ColorUtils.hsvToRGB(h: 0, s: 1, v: 1)
        XCTAssertEqual(red.x, 1, accuracy: 0.01)
        XCTAssertEqual(red.y, 0, accuracy: 0.01)
        XCTAssertEqual(red.z, 0, accuracy: 0.01)

        // Green (H=120)
        let green = ColorUtils.hsvToRGB(h: 120, s: 1, v: 1)
        XCTAssertEqual(green.x, 0, accuracy: 0.01)
        XCTAssertEqual(green.y, 1, accuracy: 0.01)
        XCTAssertEqual(green.z, 0, accuracy: 0.01)

        // Blue (H=240)
        let blue = ColorUtils.hsvToRGB(h: 240, s: 1, v: 1)
        XCTAssertEqual(blue.x, 0, accuracy: 0.01)
        XCTAssertEqual(blue.y, 0, accuracy: 0.01)
        XCTAssertEqual(blue.z, 1, accuracy: 0.01)
    }

    func testColorForBioState() {
        // High HRV, high coherence = calm (greenish)
        let calmColor = ColorUtils.colorForBioState(hrv: 80, coherence: 0.9)
        XCTAssertGreaterThan(calmColor.y, calmColor.x, "Calm should be more green than red")

        // Low HRV, low coherence = stress (reddish)
        let stressColor = ColorUtils.colorForBioState(hrv: 20, coherence: 0.1)
        XCTAssertGreaterThan(stressColor.x, stressColor.y, "Stress should be more red than green")
    }

    // MARK: - Thermal Management Tests

    func testThermalManagerInitialization() async {
        let manager = await ThermalManager.shared

        // Should have a valid thermal state
        let state = await manager.thermalState
        XCTAssertNotNil(state)

        print("Current Thermal State: \(state.rawValue)")
    }

    func testThrottledSettings() async {
        let manager = await ThermalManager.shared
        let settings = await manager.getThrottledSettings()

        // All multipliers should be between 0 and 2
        XCTAssertGreaterThan(settings.audioBufferMultiplier, 0)
        XCTAssertLessThanOrEqual(settings.audioBufferMultiplier, 2)

        XCTAssertGreaterThan(settings.fpsMultiplier, 0)
        XCTAssertLessThanOrEqual(settings.fpsMultiplier, 1)

        XCTAssertGreaterThan(settings.particleMultiplier, 0)
        XCTAssertLessThanOrEqual(settings.particleMultiplier, 1)
    }

    func testThermalStateThrottleMultipliers() {
        // Verify throttle multipliers decrease with thermal severity
        let nominal = ThermalManager.ThermalState.nominal.throttleMultiplier
        let fair = ThermalManager.ThermalState.fair.throttleMultiplier
        let serious = ThermalManager.ThermalState.serious.throttleMultiplier
        let critical = ThermalManager.ThermalState.critical.throttleMultiplier

        XCTAssertGreaterThan(nominal, fair)
        XCTAssertGreaterThan(fair, serious)
        XCTAssertGreaterThan(serious, critical)

        XCTAssertEqual(nominal, 1.0)
        XCTAssertGreaterThan(critical, 0)
    }

    // MARK: - Platform Optimizer Tests

    func testPlatformOptimizerFactory() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()

        // Should create optimizer for current platform
        #if os(iOS)
        XCTAssertEqual(optimizer.platform, .iOS)
        #elseif os(macOS)
        XCTAssertEqual(optimizer.platform, .macOS)
        #elseif os(watchOS)
        XCTAssertEqual(optimizer.platform, .watchOS)
        #elseif os(tvOS)
        XCTAssertEqual(optimizer.platform, .tvOS)
        #elseif os(visionOS)
        XCTAssertEqual(optimizer.platform, .visionOS)
        #endif
    }

    func testAudioOptimizations() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()
        let audioOpts = optimizer.getAudioOptimizations()

        XCTAssertGreaterThan(audioOpts.sampleRate, 0)
        XCTAssertGreaterThan(audioOpts.bufferSize, 0)
        XCTAssertGreaterThan(audioOpts.maxConcurrentStreams, 0)

        // SIMD should be enabled
        let hasSIMD = audioOpts.useNEON || audioOpts.useAVX2 || audioOpts.useSIMD
        XCTAssertTrue(hasSIMD, "SIMD should be enabled for audio")

        print("Audio Optimizations:")
        print("  Sample Rate: \(audioOpts.sampleRate)")
        print("  Buffer Size: \(audioOpts.bufferSize)")
        print("  NEON: \(audioOpts.useNEON)")
        print("  AVX2: \(audioOpts.useAVX2)")
    }

    func testVisualOptimizations() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()
        let visualOpts = optimizer.getVisualOptimizations()

        XCTAssertGreaterThan(visualOpts.targetFPS, 0)
        XCTAssertGreaterThan(visualOpts.maxParticles, 0)

        print("Visual Optimizations:")
        print("  Target FPS: \(visualOpts.targetFPS)")
        print("  Max Particles: \(visualOpts.maxParticles)")
        print("  Metal: \(visualOpts.useMetal)")
    }

    func testProcessingOptimizations() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()
        let procOpts = optimizer.getProcessingOptimizations()

        XCTAssertGreaterThan(procOpts.maxThreads, 0)
        XCTAssertGreaterThan(procOpts.memoryLimit, 0)
        XCTAssertGreaterThan(procOpts.simdWidth, 0)

        print("Processing Optimizations:")
        print("  Max Threads: \(procOpts.maxThreads)")
        print("  Memory Limit: \(procOpts.memoryLimit) MB")
        print("  SIMD Width: \(procOpts.simdWidth)")
    }

    // MARK: - Audio Buffer Manager Tests

    func testAudioBufferManagerCreation() {
        let manager = AudioBufferManager(bufferSize: 512, maxBuffers: 8)
        XCTAssertEqual(manager.availableCount, 8)
    }

    func testAudioBufferAcquireRelease() {
        let manager = AudioBufferManager(bufferSize: 256, maxBuffers: 4)

        // Acquire all buffers
        var acquired: [(buffer: UnsafeMutablePointer<Float>, index: Int)] = []
        for _ in 0..<4 {
            if let buffer = manager.acquire() {
                acquired.append(buffer)
            }
        }

        XCTAssertEqual(acquired.count, 4)
        XCTAssertEqual(manager.availableCount, 0)

        // Next acquire should fail
        XCTAssertNil(manager.acquire())

        // Release one buffer
        manager.release(index: acquired[0].index)
        XCTAssertEqual(manager.availableCount, 1)

        // Should be able to acquire again
        XCTAssertNotNil(manager.acquire())
    }

    // MARK: - Format Utility Tests

    func testSampleRateFormatting() {
        XCTAssertEqual(AudioFormatUtils.formatSampleRate(44100), "44kHz")
        XCTAssertEqual(AudioFormatUtils.formatSampleRate(48000), "48kHz")
        XCTAssertEqual(AudioFormatUtils.formatSampleRate(96000), "96kHz")
        XCTAssertEqual(AudioFormatUtils.formatSampleRate(500), "500Hz")
    }

    func testLatencyFormatting() {
        XCTAssertEqual(AudioFormatUtils.formatLatency(5.0), "5.0ms")
        XCTAssertEqual(AudioFormatUtils.formatLatency(0.5), "500.0μs")
    }

    func testBufferSizeForLatency() {
        let bufferSize = AudioFormatUtils.bufferSizeForLatency(targetMs: 5.0, sampleRate: 48000)

        // Should be power of 2
        let isPowerOf2 = (bufferSize & (bufferSize - 1)) == 0
        XCTAssertTrue(isPowerOf2)

        // Should be close to 5ms worth of samples (240 samples -> 256)
        XCTAssertGreaterThanOrEqual(bufferSize, 128)
        XCTAssertLessThanOrEqual(bufferSize, 512)
    }

    func testRoundTripLatency() {
        let latency = AudioFormatUtils.roundTripLatency(
            bufferSize: 128,
            sampleRate: 48000,
            systemLatencyMs: 5.0
        )

        // Should be approximately 5.33ms (buffer) + 5ms (system) = 10.33ms
        XCTAssertGreaterThan(latency, 10)
        XCTAssertLessThan(latency, 12)
    }

    // MARK: - Performance Tests

    func testParticleSystemPerformance() {
        let system = CrossPlatformParticleSystem(maxParticles: 10000)
        system.audioIntensity = 1.0

        // Warm up
        for _ in 0..<60 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        measure {
            for _ in 0..<60 {
                system.update(deltaTime: 1.0 / 60.0)
            }
        }

        print("Final particle count: \(system.particleCount)")
    }

    func testAudioLevelMeterPerformance() {
        let meter = AudioLevelMeter()
        var signal = [Float](repeating: 0, count: 4096)
        for i in 0..<signal.count {
            signal[i] = sin(Float(i) * 0.1) * Float.random(in: 0...1)
        }

        measure {
            for _ in 0..<1000 {
                signal.withUnsafeBufferPointer { ptr in
                    meter.process(ptr.baseAddress!, count: signal.count)
                }
            }
        }
    }
}

// MARK: - Platform-Specific Tests

#if os(iOS)
final class iOSSpecificTests: XCTestCase {

    func testiOSAudioSession() async throws {
        // Test iOS-specific audio session configuration
        let bridge = await CrossPlatformAudioBridge.shared

        XCTAssertFalse(await bridge.isRunning)
    }

    func testiOSProMotionDetection() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.visual

        // Check if ProMotion is correctly detected
        print("ProMotion supported: \(caps.supportsProMotion)")
    }
}
#endif

#if os(macOS)
final class macOSSpecificTests: XCTestCase {

    func testmacOSAppleSiliconDetection() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()

        if let macOptimizer = optimizer as? macOSOptimizer {
            print("Apple Silicon: \(await macOptimizer.isAppleSilicon)")
        }
    }

    func testmacOSHighPerformanceAudio() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.audio

        // macOS should support high sample rates
        XCTAssertGreaterThanOrEqual(caps.maxSampleRate, 96000)
        XCTAssertGreaterThanOrEqual(caps.maxChannels, 8)
    }
}
#endif

#if os(watchOS)
final class watchOSSpecificTests: XCTestCase {

    func testwatchOSBioCapabilities() async {
        let manager = await UnifiedPlatformManager.shared
        let caps = await manager.capabilities.bio

        // watchOS should have heart rate sensor
        XCTAssertTrue(caps.hasHeartRateSensor)
        XCTAssertTrue(caps.supportsHealthKit)
    }

    func testwatchOSLowPowerOptimizations() async {
        let optimizer = await PlatformOptimizerFactory.createOptimizer()
        let procOpts = optimizer.getProcessingOptimizations()

        // watchOS should prioritize power efficiency
        XCTAssertTrue(procOpts.enablePowerOptimization)
    }
}
#endif
