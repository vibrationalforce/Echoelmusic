import XCTest
import AVFoundation
@testable import Echoelmusic

/// Tests for MixerDSPKernel — real audio buffer processing through the mixer signal chain.
///
/// Unlike ProMixEngineTests (which test the data model), these tests verify
/// actual audio signal flow: insert chain processing, volume/pan, sends,
/// bus summing, metering, and master output.
@MainActor
final class MixerDSPKernelTests: XCTestCase {

    var mixer: ProMixEngine!
    var format: AVAudioFormat!

    override func setUp() async throws {
        try await super.setUp()
        mixer = ProMixEngine(sampleRate: 48000, bufferSize: 256)
        format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }

    override func tearDown() async throws {
        mixer = nil
        format = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a stereo PCM buffer filled with a constant value on both channels.
    private func makeBuffer(value: Float, frameCount: Int = 256) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return buffer }
        for ch in 0..<Int(buffer.format.channelCount) {
            for i in 0..<frameCount {
                channelData[ch][i] = value
            }
        }
        return buffer
    }

    /// Creates a stereo buffer with a 440Hz sine wave.
    private func makeSineBuffer(frequency: Float = 440.0, amplitude: Float = 0.5, frameCount: Int = 256) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return buffer }
        let sampleRate = Float(48000)
        for i in 0..<frameCount {
            let sample = amplitude * sin(2.0 * Float.pi * frequency * Float(i) / sampleRate)
            channelData[0][i] = sample  // L
            channelData[1][i] = sample  // R
        }
        return buffer
    }

    /// Returns the peak absolute value of a buffer's first channel.
    private func peakLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var peak: Float = 0
        for i in 0..<count {
            peak = max(peak, abs(data[0][i]))
        }
        return peak
    }

    /// Returns the RMS level of a buffer's first channel.
    private func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sumSq: Float = 0
        for i in 0..<count {
            sumSq += data[0][i] * data[0][i]
        }
        return sqrt(sumSq / Float(count))
    }

    // MARK: - DSP Kernel Initialization

    func testKernelCreation() {
        let kernel = mixer.dspKernel
        XCTAssertEqual(kernel.sampleRate, 48000)
        XCTAssertEqual(kernel.bufferSize, 256)
    }

    func testAddChannelAllocatesDSP() {
        let channel = mixer.addChannel(name: "Test", type: .audio)
        XCTAssertNotNil(mixer.dspKernel.channelDSPs[channel.id], "DSP should be allocated for new channel")
    }

    func testRemoveChannelReleasesDSP() {
        let channel = mixer.addChannel(name: "Test", type: .audio)
        let id = channel.id
        XCTAssertNotNil(mixer.dspKernel.channelDSPs[id])
        mixer.removeChannel(id: id)
        XCTAssertNil(mixer.dspKernel.channelDSPs[id], "DSP should be released when channel is removed")
    }

    func testMasterChannelHasDSP() {
        // Access dspKernel to trigger lazy init, which adds master channel
        _ = mixer.dspKernel
        XCTAssertNotNil(mixer.dspKernel.channelDSPs[mixer.masterChannel.id],
                        "Master channel should have DSP allocation")
    }

    // MARK: - Audio Signal Flow

    func testSilenceInSilenceOut() {
        let channel = mixer.addChannel(name: "Silent", type: .audio)
        mixer.isPlaying = true
        mixer.dspKernel.prepare()

        let silentBuffer = makeBuffer(value: 0.0)
        let output = mixer.processAudioBlock(
            inputBuffers: [channel.id: silentBuffer],
            frameCount: 256
        )

        let peak = peakLevel(output)
        XCTAssertEqual(peak, 0.0, accuracy: 1e-6, "Silence in should produce silence out")
    }

    func testAudioPassesThrough() {
        let channel = mixer.addChannel(name: "Audio", type: .audio)
        mixer.isPlaying = true
        mixer.dspKernel.prepare()

        let input = makeSineBuffer(amplitude: 0.5)
        let output = mixer.processAudioBlock(
            inputBuffers: [channel.id: input],
            frameCount: 256
        )

        let peak = peakLevel(output)
        XCTAssertGreaterThan(peak, 0.0, "Audio should pass through the mixer")
    }

    func testVolumeAffectsOutput() {
        let channel = mixer.addChannel(name: "Vox", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeBuffer(value: 1.0)

        // Full volume
        if let idx = mixer.channelIndex(for: channel.id) {
            mixer.channels[idx].volume = 1.0
        }
        let outputFull = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)
        let peakFull = peakLevel(outputFull)

        // Half volume
        if let idx = mixer.channelIndex(for: channel.id) {
            mixer.channels[idx].volume = 0.5
        }
        let inputHalf = makeBuffer(value: 1.0)
        let outputHalf = mixer.processAudioBlock(inputBuffers: [channel.id: inputHalf], frameCount: 256)
        let peakHalf = peakLevel(outputHalf)

        XCTAssertGreaterThan(peakFull, peakHalf, "Higher volume should produce louder output")
    }

    func testMuteProducesSilence() {
        let channel = mixer.addChannel(name: "Muted", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        if let idx = mixer.channelIndex(for: channel.id) {
            mixer.channels[idx].mute = true
        }

        let input = makeSineBuffer(amplitude: 0.8)
        let output = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        let peak = peakLevel(output)
        XCTAssertEqual(peak, 0.0, accuracy: 1e-6, "Muted channel should produce silence")
    }

    func testSoloIsolatesChannel() {
        let ch1 = mixer.addChannel(name: "Soloed", type: .audio)
        let ch2 = mixer.addChannel(name: "NotSoloed", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Solo ch1
        mixer.soloExclusive(channelID: ch1.id)

        let input1 = makeSineBuffer(amplitude: 0.5)
        let input2 = makeSineBuffer(amplitude: 0.5)
        let output = mixer.processAudioBlock(
            inputBuffers: [ch1.id: input1, ch2.id: input2],
            frameCount: 256
        )

        // With solo, only ch1 should be heard
        let peak = peakLevel(output)
        XCTAssertGreaterThan(peak, 0.0, "Soloed channel should produce output")

        // Verify ch2 metering is zero (it was silenced by solo)
        let ch2State = mixer.channels.first { $0.id == ch2.id }
        XCTAssertEqual(ch2State?.metering.peak ?? 1.0, 0.0, accuracy: 1e-6,
                       "Non-soloed channel metering should be zero")
    }

    // MARK: - Pan Law

    func testEqualPowerPanCenter() {
        let kernel = mixer.dspKernel
        let (gainL, gainR) = kernel.equalPowerPan(pan: 0.0, volume: 1.0)

        // At center, both should be equal (~0.707)
        XCTAssertEqual(gainL, gainR, accuracy: 0.001, "Center pan should have equal L/R gains")
        XCTAssertEqual(gainL, cos(Float.pi / 4), accuracy: 0.001, "Center gain should be ~0.707")
    }

    func testEqualPowerPanHardLeft() {
        let kernel = mixer.dspKernel
        let (gainL, gainR) = kernel.equalPowerPan(pan: -1.0, volume: 1.0)

        XCTAssertEqual(gainL, 1.0, accuracy: 0.001, "Hard left should have L=1.0")
        XCTAssertEqual(gainR, 0.0, accuracy: 0.001, "Hard left should have R=0.0")
    }

    func testEqualPowerPanHardRight() {
        let kernel = mixer.dspKernel
        let (gainL, gainR) = kernel.equalPowerPan(pan: 1.0, volume: 1.0)

        XCTAssertEqual(gainL, 0.0, accuracy: 0.001, "Hard right should have L=0.0")
        XCTAssertEqual(gainR, 1.0, accuracy: 0.001, "Hard right should have R=1.0")
    }

    func testPanAffectsChannelBalance() {
        let channel = mixer.addChannel(name: "Panned", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Pan hard left
        if let idx = mixer.channelIndex(for: channel.id) {
            mixer.channels[idx].pan = -1.0
        }

        let input = makeBuffer(value: 0.5)
        let output = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        guard let data = output.floatChannelData, output.format.channelCount >= 2 else {
            XCTFail("Output should be stereo")
            return
        }

        // Left channel should have signal, right should be near zero
        var peakL: Float = 0
        var peakR: Float = 0
        for i in 0..<Int(output.frameLength) {
            peakL = max(peakL, abs(data[0][i]))
            peakR = max(peakR, abs(data[1][i]))
        }

        XCTAssertGreaterThan(peakL, 0.1, "Left channel should have signal when panned left")
        XCTAssertLessThan(peakR, 0.01, "Right channel should be near-silent when panned hard left")
    }

    // MARK: - Sends & Bus Routing

    func testSendRoutesToAuxBus() {
        let auxBus = mixer.createAuxBus(name: "Reverb")
        let channel = mixer.addChannel(name: "Vocals", type: .audio)

        // Add send from channel to aux bus
        mixer.addSend(from: channel.id, to: auxBus.id, level: 0.5)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeBuffer(value: 0.5)
        mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        // Aux bus should have received signal via send
        let auxMetering = mixer.channels.first { $0.id == auxBus.id }?.metering
        XCTAssertGreaterThan(auxMetering?.peak ?? 0, 0.0,
                             "Aux bus should receive signal via send")
    }

    func testBusGroupSumsChannels() {
        let ch1 = mixer.addChannel(name: "Kick", type: .audio)
        let ch2 = mixer.addChannel(name: "Snare", type: .audio)

        // Create bus group containing both channels
        let drumBus = mixer.createBusGroup(name: "Drums", channelIDs: [ch1.id, ch2.id])
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input1 = makeBuffer(value: 0.3)
        let input2 = makeBuffer(value: 0.3)
        mixer.processAudioBlock(
            inputBuffers: [ch1.id: input1, ch2.id: input2],
            frameCount: 256
        )

        // Drum bus should have signal from both channels
        let busMetering = mixer.channels.first { $0.id == drumBus.id }?.metering
        XCTAssertGreaterThan(busMetering?.peak ?? 0, 0.0,
                             "Bus group should sum input channels")
    }

    // MARK: - Metering

    func testMeteringReflectsActualAudio() {
        let channel = mixer.addChannel(name: "Metered", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeSineBuffer(amplitude: 0.7)
        mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        let metering = mixer.channels.first { $0.id == channel.id }?.metering
        XCTAssertNotNil(metering)
        XCTAssertGreaterThan(metering?.peak ?? 0, 0.0, "Peak should reflect actual audio level")
        XCTAssertGreaterThan(metering?.rms ?? 0, 0.0, "RMS should reflect actual audio level")
        XCTAssertLessThanOrEqual(metering?.peak ?? 2, 1.0, "Peak should not exceed 1.0 for 0.7 amplitude input")
    }

    func testMasterMeteringReflectsSum() {
        let ch1 = mixer.addChannel(name: "Ch1", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeSineBuffer(amplitude: 0.4)
        mixer.processAudioBlock(inputBuffers: [ch1.id: input], frameCount: 256)

        let masterMetering = mixer.masterChannel.metering
        XCTAssertGreaterThan(masterMetering.peak, 0.0, "Master should have signal")
    }

    func testClippingDetection() {
        let channel = mixer.addChannel(name: "Hot", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Volume > 1.0 would clip — send hot signal
        if let idx = mixer.channelIndex(for: channel.id) {
            mixer.channels[idx].volume = 1.0
        }
        let hotInput = makeBuffer(value: 1.0)
        mixer.processAudioBlock(inputBuffers: [channel.id: hotInput], frameCount: 256)

        // Master at full volume with a full-scale signal should be near clipping
        // The equal-power pan at center gives ~0.707 per channel, so peak ≈ 0.707
        // Not quite clipping, but metering should be non-zero
        let masterMetering = mixer.masterChannel.metering
        XCTAssertGreaterThan(masterMetering.peak, 0.5, "Full-scale signal should produce high metering")
    }

    // MARK: - Phase Invert

    func testPhaseInvert() {
        let ch1 = mixer.addChannel(name: "Normal", type: .audio)
        let ch2 = mixer.addChannel(name: "Inverted", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Invert phase on ch2
        if let idx = mixer.channelIndex(for: ch2.id) {
            mixer.channels[idx].phaseInvert = true
        }

        // Same signal on both channels — should cancel when summed
        let input1 = makeBuffer(value: 0.5)
        let input2 = makeBuffer(value: 0.5)

        // Set both to same volume and center pan
        if let idx1 = mixer.channelIndex(for: ch1.id) {
            mixer.channels[idx1].volume = 1.0
            mixer.channels[idx1].pan = 0.0
        }
        if let idx2 = mixer.channelIndex(for: ch2.id) {
            mixer.channels[idx2].volume = 1.0
            mixer.channels[idx2].pan = 0.0
        }

        let output = mixer.processAudioBlock(
            inputBuffers: [ch1.id: input1, ch2.id: input2],
            frameCount: 256
        )

        // Phase cancellation: identical signals with opposite polarity should sum to near-zero
        let peak = peakLevel(output)
        XCTAssertLessThan(peak, 0.01,
                          "Phase-inverted identical signals should cancel to near-silence (got \(peak))")
    }

    // MARK: - Insert Chain

    func testInsertChainSyncsNodes() {
        let channel = mixer.addChannel(name: "FX", type: .audio)
        mixer.addInsert(to: channel.id, effect: .compressor)
        mixer.addInsert(to: channel.id, effect: .parametricEQ)

        let dsp = mixer.dspKernel.channelDSPs[channel.id]
        XCTAssertNotNil(dsp)
        XCTAssertEqual(dsp?.insertNodes.count, 2, "Two insert nodes should be created")
        XCTAssertEqual(dsp?.insertOrder.count, 2, "Insert order should have two entries")
    }

    func testInsertProcessesAudio() {
        let channel = mixer.addChannel(name: "Compressed", type: .audio)
        mixer.addInsert(to: channel.id, effect: .compressor)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeSineBuffer(amplitude: 0.8)
        let output = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        // Compressor should produce output (may modify dynamics)
        let peak = peakLevel(output)
        XCTAssertGreaterThan(peak, 0.0, "Compressor insert should pass audio through")
    }

    // MARK: - Multi-Channel Summing

    func testMultipleChannelsSumToMaster() {
        let ch1 = mixer.addChannel(name: "A", type: .audio)
        let ch2 = mixer.addChannel(name: "B", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input1 = makeBuffer(value: 0.3)
        let input2 = makeBuffer(value: 0.3)

        // Process with both channels
        let outputBoth = mixer.processAudioBlock(
            inputBuffers: [ch1.id: input1, ch2.id: input2],
            frameCount: 256
        )
        let peakBoth = peakLevel(outputBoth)

        // Process with only one channel
        mixer.isPlaying = true // reset
        let inputSingle = makeBuffer(value: 0.3)
        if let idx = mixer.channelIndex(for: ch2.id) {
            mixer.channels[idx].mute = true
        }
        let outputSingle = mixer.processAudioBlock(
            inputBuffers: [ch1.id: inputSingle],
            frameCount: 256
        )
        let peakSingle = peakLevel(outputSingle)

        XCTAssertGreaterThan(peakBoth, peakSingle,
                             "Two channels summed should be louder than one")
    }

    // MARK: - Master Volume

    func testMasterVolumeScalesOutput() {
        let channel = mixer.addChannel(name: "Test", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Full master
        mixer.masterChannel.volume = 1.0
        let input1 = makeBuffer(value: 0.5)
        let outputFull = mixer.processAudioBlock(inputBuffers: [channel.id: input1], frameCount: 256)
        let peakFull = peakLevel(outputFull)

        // Half master
        mixer.masterChannel.volume = 0.5
        let input2 = makeBuffer(value: 0.5)
        let outputHalf = mixer.processAudioBlock(inputBuffers: [channel.id: input2], frameCount: 256)
        let peakHalf = peakLevel(outputHalf)

        XCTAssertGreaterThan(peakFull, peakHalf,
                             "Higher master volume should produce louder output")
    }

    func testMasterMuteProducesSilence() {
        let channel = mixer.addChannel(name: "Test", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true
        mixer.masterChannel.mute = true

        let input = makeSineBuffer(amplitude: 0.5)
        let output = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        let peak = peakLevel(output)
        XCTAssertEqual(peak, 0.0, accuracy: 1e-6, "Muted master should produce silence")
    }

    // MARK: - Lifecycle

    func testKernelPrepareAndStop() {
        mixer.addChannel(name: "Ch1", type: .audio)
        mixer.addInsert(to: mixer.channels.first!.id, effect: .compressor)

        mixer.dspKernel.prepare()
        XCTAssertTrue(mixer.dspKernel.isPrepared)

        mixer.dspKernel.stop()
        XCTAssertFalse(mixer.dspKernel.isPrepared)
    }

    func testKernelReset() {
        let channel = mixer.addChannel(name: "Reset", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Process some audio
        let input = makeSineBuffer()
        mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 256)

        // Reset
        mixer.dspKernel.reset()

        // Master buffer should be cleared
        let peak = peakLevel(mixer.dspKernel.masterBuffer)
        XCTAssertEqual(peak, 0.0, accuracy: 1e-6, "Reset should clear all buffers")
    }

    // MARK: - Default Session with DSP

    func testDefaultSessionHasDSPForAllChannels() {
        let session = ProMixEngine.defaultSession()

        // Every channel should have DSP allocated
        for channel in session.channels {
            XCTAssertNotNil(session.dspKernel.channelDSPs[channel.id],
                            "Channel '\(channel.name)' should have DSP allocation")
        }

        // Master should have DSP too
        XCTAssertNotNil(session.dspKernel.channelDSPs[session.masterChannel.id],
                        "Master channel should have DSP allocation")
    }

    func testDefaultSessionAuxBusesHaveInsertNodes() {
        let session = ProMixEngine.defaultSession()

        // Reverb bus should have a reverb insert node
        let reverbBus = session.channels.first { $0.name == "Reverb" }
        XCTAssertNotNil(reverbBus, "Default session should have a Reverb bus")
        if let reverbID = reverbBus?.id {
            let dsp = session.dspKernel.channelDSPs[reverbID]
            XCTAssertEqual(dsp?.insertNodes.count, 1, "Reverb bus should have 1 insert node")
        }

        // Delay bus should have a delay insert node
        let delayBus = session.channels.first { $0.name == "Delay" }
        XCTAssertNotNil(delayBus, "Default session should have a Delay bus")
        if let delayID = delayBus?.id {
            let dsp = session.dspKernel.channelDSPs[delayID]
            XCTAssertEqual(dsp?.insertNodes.count, 1, "Delay bus should have 1 insert node")
        }
    }

    // MARK: - Edge Cases

    func testZeroFrameCountDoesNotCrash() {
        let channel = mixer.addChannel(name: "Zero", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        let input = makeBuffer(value: 0.5, frameCount: 0)
        let output = mixer.processAudioBlock(inputBuffers: [channel.id: input], frameCount: 0)
        XCTAssertNotNil(output)
    }

    func testNoInputBuffersProducesSilence() {
        mixer.addChannel(name: "NoInput", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = true

        // Process with empty input buffers
        let output = mixer.processAudioBlock(inputBuffers: [:], frameCount: 256)
        let peak = peakLevel(output)
        XCTAssertEqual(peak, 0.0, accuracy: 1e-6, "No input should produce silence")
    }

    func testProcessBlockWithoutPlayingDoesNothing() {
        let channel = mixer.addChannel(name: "Stopped", type: .audio)
        mixer.dspKernel.prepare()
        mixer.isPlaying = false

        let input = makeSineBuffer(amplitude: 0.5)
        mixer.processBlock(frameCount: 256)

        // Should not advance time
        XCTAssertEqual(mixer.currentTime, 0.0, "Should not advance time when not playing")
    }
}
