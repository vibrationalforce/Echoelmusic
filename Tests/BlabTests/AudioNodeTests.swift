import XCTest
import AVFoundation
@testable import Blab

/// Tests for audio processing nodes
@MainActor
final class AudioNodeTests: XCTestCase {

    // MARK: - FilterNode Tests

    func testFilterNodeInitialization() {
        let filter = FilterNode()

        XCTAssertEqual(filter.name, "Bio-Reactive Filter")
        XCTAssertEqual(filter.type, .effect)
        XCTAssertFalse(filter.isBypassed)
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.parameters.count, 2)  // cutoff + resonance
    }

    func testFilterNodeParameters() {
        let filter = FilterNode()

        // Test setting cutoff frequency
        filter.setParameter(name: "cutoffFrequency", value: 2000.0)
        XCTAssertEqual(filter.getParameter(name: "cutoffFrequency"), 2000.0, accuracy: 0.1)

        // Test parameter clamping
        filter.setParameter(name: "cutoffFrequency", value: 10000.0)  // Above max
        XCTAssertLessThanOrEqual(filter.getParameter(name: "cutoffFrequency") ?? 0, 8000.0)

        // Test resonance
        filter.setParameter(name: "resonance", value: 2.0)
        XCTAssertEqual(filter.getParameter(name: "resonance"), 2.0, accuracy: 0.1)
    }

    func testFilterNodeProcessing() {
        let filter = FilterNode()

        // Create test buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512) else {
            XCTFail("Failed to create buffer")
            return
        }

        buffer.frameLength = 512

        // Fill with test signal (1kHz sine wave)
        if let channelData = buffer.floatChannelData {
            for frame in 0..<512 {
                let sample = sin(2.0 * Float.pi * 1000.0 * Float(frame) / 44100.0)
                channelData[0][frame] = sample
                channelData[1][frame] = sample
            }
        }

        // Prepare and start filter
        filter.prepare(sampleRate: 44100, maxFrames: 512)
        filter.start()

        // Process buffer
        let time = AVAudioTime(hostTime: mach_absolute_time())
        let processed = filter.process(buffer, time: time)

        XCTAssertEqual(processed.frameLength, 512)
        XCTAssertNotNil(processed.floatChannelData)
    }

    func testFilterNodeBioReactivity() {
        let filter = FilterNode()

        // Create bio signal with high heart rate
        let bioSignal = BioSignal(
            hrv: 50,
            heartRate: 100,  // High HR -> brighter sound
            coherence: 80,
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        filter.react(to: bioSignal)

        // Cutoff should be higher for high heart rate
        let cutoff = filter.getParameter(name: "cutoffFrequency") ?? 0
        XCTAssertGreaterThan(cutoff, 2000.0)  // Should be in bright range

        // Resonance should increase with coherence
        let resonance = filter.getParameter(name: "resonance") ?? 0
        XCTAssertGreaterThan(resonance, 0.707)  // Default Q
    }

    // MARK: - DelayNode Tests

    func testDelayNodeInitialization() {
        let delay = DelayNode()

        XCTAssertEqual(delay.name, "Bio-Reactive Delay")
        XCTAssertEqual(delay.type, .effect)
        XCTAssertEqual(delay.parameters.count, 4)  // time, feedback, wet/dry, cutoff
    }

    func testDelayNodeTempoSync() {
        let delay = DelayNode()

        // Test tempo-synced delay (120 BPM)
        delay.setTempoSyncedDelay(bpm: 120.0, subdivision: .quarter)

        let delayTime = delay.getParameter(name: "delayTime") ?? 0
        XCTAssertEqual(delayTime, 0.5, accuracy: 0.01)  // Quarter note at 120 BPM

        // Test eighth note
        delay.setTempoSyncedDelay(bpm: 120.0, subdivision: .eighth)
        let eighthTime = delay.getParameter(name: "delayTime") ?? 0
        XCTAssertEqual(eighthTime, 0.25, accuracy: 0.01)
    }

    func testDelayNodeBioReactivity() {
        let delay = DelayNode()
        delay.prepare(sampleRate: 44100, maxFrames: 512)

        // Bio signal with 60 BPM heart rate
        let bioSignal = BioSignal(
            hrv: 60,
            heartRate: 60,  // 60 BPM
            coherence: 70,
            audioLevel: 0.8,
            voicePitch: 440.0
        )

        delay.react(to: bioSignal)

        // Delay time should sync to heart rate (quarter note = 1 second at 60 BPM)
        let delayTime = delay.getParameter(name: "delayTime") ?? 0
        XCTAssertEqual(delayTime, 0.5, accuracy: 0.1)  // Eighth note

        // Feedback should increase with coherence
        let feedback = delay.getParameter(name: "feedback") ?? 0
        XCTAssertGreaterThan(feedback, 50.0)  // >50% for high coherence
    }

    // MARK: - ReverbNode Tests

    func testReverbNodeInitialization() {
        let reverb = ReverbNode()

        XCTAssertEqual(reverb.name, "Bio-Reactive Reverb")
        XCTAssertEqual(reverb.type, .effect)
        XCTAssertGreaterThan(reverb.parameters.count, 0)
    }

    func testReverbNodeBioReactivity() {
        let reverb = ReverbNode()

        // Low coherence (stressed) -> less reverb
        let stressedSignal = BioSignal(
            hrv: 30,
            heartRate: 80,
            coherence: 20,  // Low coherence
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        reverb.react(to: stressedSignal)
        let dryWetness = reverb.getParameter(name: "wetDry") ?? 0
        XCTAssertLessThan(dryWetness, 30.0)  // Should be relatively dry

        // High coherence (flow) -> more reverb
        let flowSignal = BioSignal(
            hrv: 80,
            heartRate: 65,
            coherence: 80,  // High coherence
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        reverb.react(to: flowSignal)
        let wetWetness = reverb.getParameter(name: "wetDry") ?? 0
        XCTAssertGreaterThan(wetWetness, 50.0)  // Should be wetter
    }

    // MARK: - CompressorNode Tests

    func testCompressorNodeInitialization() {
        let compressor = CompressorNode()

        XCTAssertEqual(compressor.name, "Bio-Reactive Compressor")
        XCTAssertEqual(compressor.type, .effect)
        XCTAssertEqual(compressor.parameters.count, 5)  // threshold, ratio, attack, release, makeup
    }

    func testCompressorNodeBioReactivity() {
        let compressor = CompressorNode()

        // Fast breathing -> more compression
        let fastBreathingSignal = BioSignal(
            hrv: 40,
            heartRate: 85,
            coherence: 40,
            respiratoryRate: 25.0,  // Fast breathing
            audioLevel: 0.7,
            voicePitch: 440.0
        )

        compressor.react(to: fastBreathingSignal)
        let threshold = compressor.getParameter(name: "threshold") ?? 0
        XCTAssertLessThan(threshold, -20.0)  // Lower threshold = more compression

        // High coherence -> slower attack/release
        let coherentSignal = BioSignal(
            hrv: 80,
            heartRate: 65,
            coherence: 80,
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        compressor.react(to: coherentSignal)
        let attack = compressor.getParameter(name: "attack") ?? 0
        XCTAssertGreaterThan(attack, 10.0)  // Slower attack
    }

    // MARK: - NodeGraph Tests

    func testNodeGraphCreation() {
        let graph = NodeGraph.createBiofeedbackChain()

        XCTAssertGreaterThan(graph.nodes.count, 0)
        XCTAssertGreaterThan(graph.connections.count, 0)
    }

    func testNodeGraphProcessing() async {
        let graph = NodeGraph.createBiofeedbackChain()

        // Start graph
        graph.start(sampleRate: 44100, maxFrames: 512)
        XCTAssertTrue(graph.isProcessing)

        // Create test buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512) else {
            XCTFail("Failed to create buffer")
            return
        }

        buffer.frameLength = 512

        // Process through graph
        let time = AVAudioTime(hostTime: mach_absolute_time())
        let processed = graph.process(buffer, time: time)

        XCTAssertEqual(processed.frameLength, 512)

        // Stop graph
        graph.stop()
        XCTAssertFalse(graph.isProcessing)
    }

    func testNodeGraphBioSignalUpdate() async {
        let graph = NodeGraph.createBiofeedbackChain()

        let bioSignal = BioSignal(
            hrv: 70,
            heartRate: 65,
            coherence: 75,
            audioLevel: 0.6,
            voicePitch: 440.0
        )

        graph.updateBioSignal(bioSignal)

        // Verify nodes received signal
        // (Nodes should update their parameters based on bio signal)
    }

    // MARK: - Integration Tests

    func testAudioEngineNodeGraphIntegration() {
        let micManager = MicrophoneManager()
        let audioEngine = AudioEngine(microphoneManager: micManager)

        // Verify node graph is created
        XCTAssertNotNil(audioEngine.effectsChain)

        // Verify node graph has nodes
        XCTAssertGreaterThan(audioEngine.effectsChain?.nodes.count ?? 0, 0)
    }
}
