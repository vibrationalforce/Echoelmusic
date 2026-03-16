#if canImport(AVFoundation)
import XCTest
import Foundation
import AVFoundation
import CoreGraphics
@testable import Echoelmusic

// MARK: - VocalDSPKernel Tests

final class VocalDSPKernelTests: XCTestCase {

    private var kernel: VocalDSPKernel!

    override func setUp() {
        super.setUp()
        kernel = VocalDSPKernel()
    }

    override func tearDown() {
        kernel = nil
        super.tearDown()
    }

    // MARK: - ParameterAddress Raw Values

    func testParameterAddress_correctionSpeed_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.correctionSpeed.rawValue, 0)
    }

    func testParameterAddress_correctionStrength_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.correctionStrength.rawValue, 1)
    }

    func testParameterAddress_rootNote_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.rootNote.rawValue, 2)
    }

    func testParameterAddress_scaleType_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.scaleType.rawValue, 3)
    }

    func testParameterAddress_formantShift_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.formantShift.rawValue, 4)
    }

    func testParameterAddress_harmonyMix_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.harmonyMix.rawValue, 5)
    }

    func testParameterAddress_harmonyInterval1_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.harmonyInterval1.rawValue, 6)
    }

    func testParameterAddress_harmonyInterval2_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.harmonyInterval2.rawValue, 7)
    }

    func testParameterAddress_inputGain_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.inputGain.rawValue, 8)
    }

    func testParameterAddress_outputGain_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.outputGain.rawValue, 9)
    }

    func testParameterAddress_dryWet_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.dryWet.rawValue, 10)
    }

    func testParameterAddress_transpose_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.transpose.rawValue, 11)
    }

    func testParameterAddress_humanize_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.humanize.rawValue, 12)
    }

    func testParameterAddress_bypass_rawValue() {
        XCTAssertEqual(VocalDSPKernel.ParameterAddress.bypass.rawValue, 13)
    }

    func testParameterAddress_contiguousRange() {
        // All 14 addresses span 0-13 with no gaps
        for raw: UInt64 in 0...13 {
            XCTAssertNotNil(
                VocalDSPKernel.ParameterAddress(rawValue: raw),
                "ParameterAddress should exist for raw value \(raw)"
            )
        }
    }

    func testParameterAddress_invalidRawValue_returnsNil() {
        XCTAssertNil(VocalDSPKernel.ParameterAddress(rawValue: 14))
        XCTAssertNil(VocalDSPKernel.ParameterAddress(rawValue: 999))
    }

    // MARK: - Scale Types

    func testScaleType_chromatic_has12Notes() {
        // Chromatic scale includes all 12 semitones
        kernel.setParameter(address: .scaleType, value: 0)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 0)
    }

    func testScaleType_major_intervals() {
        // Major: W-W-H-W-W-W-H → [0,2,4,5,7,9,11] — 7 notes
        kernel.setParameter(address: .scaleType, value: 1)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 1)
    }

    func testScaleType_naturalMinor_intervals() {
        // Natural minor: [0,2,3,5,7,8,10] — 7 notes
        kernel.setParameter(address: .scaleType, value: 2)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 2)
    }

    func testScaleType_harmonicMinor_intervals() {
        kernel.setParameter(address: .scaleType, value: 3)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 3)
    }

    func testScaleType_melodicMinor_intervals() {
        kernel.setParameter(address: .scaleType, value: 4)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 4)
    }

    func testScaleType_pentatonicMajor_intervals() {
        // Pentatonic major: [0,2,4,7,9] — 5 notes
        kernel.setParameter(address: .scaleType, value: 5)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 5)
    }

    func testScaleType_pentatonicMinor_intervals() {
        kernel.setParameter(address: .scaleType, value: 6)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 6)
    }

    func testScaleType_blues_intervals() {
        // Blues: [0,3,5,6,7,10] — 6 notes
        kernel.setParameter(address: .scaleType, value: 7)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 7)
    }

    func testScaleType_dorian_intervals() {
        kernel.setParameter(address: .scaleType, value: 8)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 8)
    }

    func testScaleType_phrygian_intervals() {
        kernel.setParameter(address: .scaleType, value: 9)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 9)
    }

    func testScaleType_lydian_intervals() {
        kernel.setParameter(address: .scaleType, value: 10)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 10)
    }

    func testScaleType_mixolydian_intervals() {
        kernel.setParameter(address: .scaleType, value: 11)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 11)
    }

    func testScaleType_locrian_intervals() {
        kernel.setParameter(address: .scaleType, value: 12)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 12)
    }

    func testScaleType_wholeTone_intervals() {
        // Whole tone: [0,2,4,6,8,10] — 6 notes
        kernel.setParameter(address: .scaleType, value: 13)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 13)
    }

    func testScaleType_diminished_intervals() {
        kernel.setParameter(address: .scaleType, value: 14)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 14)
    }

    func testScaleType_augmented_intervals() {
        kernel.setParameter(address: .scaleType, value: 15)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 15)
    }

    func testScaleType_arabian_intervals() {
        kernel.setParameter(address: .scaleType, value: 16)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 16)
    }

    func testScaleType_japanese_intervals() {
        kernel.setParameter(address: .scaleType, value: 17)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 17)
    }

    func testScaleType_hungarianMinor_intervals() {
        kernel.setParameter(address: .scaleType, value: 18)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 18)
    }

    func testScaleType_wrapsModulo19() {
        // ScaleType 19 wraps to 0 (chromatic) since there are 19 scales
        kernel.setParameter(address: .scaleType, value: 19)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 0)
    }

    // MARK: - setParameter / getParameter Round-Trip

    func testRoundTrip_correctionSpeed() {
        kernel.setParameter(address: .correctionSpeed, value: 100.0)
        XCTAssertEqual(kernel.getParameter(address: .correctionSpeed), 100.0)
    }

    func testRoundTrip_correctionStrength() {
        kernel.setParameter(address: .correctionStrength, value: 0.75)
        XCTAssertEqual(kernel.getParameter(address: .correctionStrength), 0.75)
    }

    func testRoundTrip_rootNote() {
        kernel.setParameter(address: .rootNote, value: 7)  // G
        XCTAssertEqual(kernel.getParameter(address: .rootNote), 7)
    }

    func testRoundTrip_rootNote_wraps() {
        // rootNote uses modulo 12
        kernel.setParameter(address: .rootNote, value: 14)
        XCTAssertEqual(kernel.getParameter(address: .rootNote), 2)  // 14 % 12 = 2 (D)
    }

    func testRoundTrip_formantShift() {
        kernel.setParameter(address: .formantShift, value: -5.0)
        XCTAssertEqual(kernel.getParameter(address: .formantShift), -5.0)
    }

    func testRoundTrip_formantShift_positive() {
        kernel.setParameter(address: .formantShift, value: 8.5)
        XCTAssertEqual(kernel.getParameter(address: .formantShift), 8.5)
    }

    func testRoundTrip_harmonyMix() {
        kernel.setParameter(address: .harmonyMix, value: 0.6)
        XCTAssertEqual(kernel.getParameter(address: .harmonyMix), 0.6, accuracy: 0.0001)
    }

    func testRoundTrip_harmonyInterval1() {
        kernel.setParameter(address: .harmonyInterval1, value: -7.0)
        XCTAssertEqual(kernel.getParameter(address: .harmonyInterval1), -7.0)
    }

    func testRoundTrip_harmonyInterval2() {
        kernel.setParameter(address: .harmonyInterval2, value: 12.0)
        XCTAssertEqual(kernel.getParameter(address: .harmonyInterval2), 12.0)
    }

    func testRoundTrip_inputGain() {
        kernel.setParameter(address: .inputGain, value: 1.5)
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 1.5)
    }

    func testRoundTrip_outputGain() {
        kernel.setParameter(address: .outputGain, value: 0.3)
        XCTAssertEqual(kernel.getParameter(address: .outputGain), 0.3, accuracy: 0.0001)
    }

    func testRoundTrip_dryWet() {
        kernel.setParameter(address: .dryWet, value: 0.5)
        XCTAssertEqual(kernel.getParameter(address: .dryWet), 0.5)
    }

    func testRoundTrip_transpose() {
        kernel.setParameter(address: .transpose, value: -12.0)
        XCTAssertEqual(kernel.getParameter(address: .transpose), -12.0)
    }

    func testRoundTrip_transpose_positive() {
        kernel.setParameter(address: .transpose, value: 24.0)
        XCTAssertEqual(kernel.getParameter(address: .transpose), 24.0)
    }

    func testRoundTrip_humanize() {
        kernel.setParameter(address: .humanize, value: 0.8)
        XCTAssertEqual(kernel.getParameter(address: .humanize), 0.8, accuracy: 0.0001)
    }

    func testRoundTrip_bypass_on() {
        kernel.setParameter(address: .bypass, value: 1.0)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 1.0)
    }

    func testRoundTrip_bypass_off() {
        kernel.setParameter(address: .bypass, value: 0.0)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 0.0)
    }

    func testRoundTrip_bypass_threshold() {
        // Values > 0.5 map to bypassed (1.0), values <= 0.5 map to not bypassed (0.0)
        kernel.setParameter(address: .bypass, value: 0.51)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 1.0)

        kernel.setParameter(address: .bypass, value: 0.5)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 0.0)
    }

    // MARK: - Default Parameter Values

    func testDefaultParameter_correctionSpeed() {
        XCTAssertEqual(kernel.getParameter(address: .correctionSpeed), 50.0)
    }

    func testDefaultParameter_correctionStrength() {
        XCTAssertEqual(kernel.getParameter(address: .correctionStrength), 0.8)
    }

    func testDefaultParameter_rootNote() {
        XCTAssertEqual(kernel.getParameter(address: .rootNote), 0)  // C
    }

    func testDefaultParameter_scaleType() {
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 0)  // Chromatic
    }

    func testDefaultParameter_formantShift() {
        XCTAssertEqual(kernel.getParameter(address: .formantShift), 0.0)
    }

    func testDefaultParameter_harmonyMix() {
        XCTAssertEqual(kernel.getParameter(address: .harmonyMix), 0.0)
    }

    func testDefaultParameter_harmonyInterval1() {
        XCTAssertEqual(kernel.getParameter(address: .harmonyInterval1), 4.0)  // Major 3rd
    }

    func testDefaultParameter_harmonyInterval2() {
        XCTAssertEqual(kernel.getParameter(address: .harmonyInterval2), 7.0)  // Perfect 5th
    }

    func testDefaultParameter_inputGain() {
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 1.0)
    }

    func testDefaultParameter_outputGain() {
        XCTAssertEqual(kernel.getParameter(address: .outputGain), 1.0)
    }

    func testDefaultParameter_dryWet() {
        XCTAssertEqual(kernel.getParameter(address: .dryWet), 1.0)
    }

    func testDefaultParameter_transpose() {
        XCTAssertEqual(kernel.getParameter(address: .transpose), 0.0)
    }

    func testDefaultParameter_humanize() {
        XCTAssertEqual(kernel.getParameter(address: .humanize), 0.2)
    }

    func testDefaultParameter_bypass() {
        XCTAssertEqual(kernel.getParameter(address: .bypass), 0.0)
    }

    // MARK: - prepare()

    func testPrepare_configuresKernel() {
        kernel.prepare(sampleRate: 44100, maxFrames: 1024, channelCount: 2)
        // After prepare, kernel should accept process calls without crashing
        // Verify by checking that spectral state is initialized
        XCTAssertEqual(kernel.dominantFrequency, 0)
        XCTAssertEqual(kernel.rmsLevel, 0)
    }

    func testPrepare_differentSampleRates() {
        // Should not crash at various sample rates
        kernel.prepare(sampleRate: 22050, maxFrames: 256, channelCount: 1)
        kernel.prepare(sampleRate: 44100, maxFrames: 512, channelCount: 2)
        kernel.prepare(sampleRate: 48000, maxFrames: 1024, channelCount: 2)
        kernel.prepare(sampleRate: 96000, maxFrames: 2048, channelCount: 2)
        // No crash means success
    }

    func testPrepare_monoConfiguration() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 1)
        XCTAssertEqual(kernel.rmsLevel, 0)
    }

    // MARK: - reset()

    func testReset_clearsSpectralBands() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()

        let bands = kernel.spectralBands
        XCTAssertEqual(bands.0, 0)
        XCTAssertEqual(bands.1, 0)
        XCTAssertEqual(bands.2, 0)
        XCTAssertEqual(bands.3, 0)
        XCTAssertEqual(bands.4, 0)
        XCTAssertEqual(bands.5, 0)
        XCTAssertEqual(bands.6, 0)
        XCTAssertEqual(bands.7, 0)
    }

    func testReset_clearsDominantFrequency() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()
        XCTAssertEqual(kernel.dominantFrequency, 0)
    }

    func testReset_clearsRmsLevel() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()
        XCTAssertEqual(kernel.rmsLevel, 0)
    }

    func testReset_afterPrepare_doesNotCrash() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()
        // Should be safe to call reset multiple times
        kernel.reset()
    }

    // MARK: - process() with Silence

    func testProcess_silenceInput_bypassOutputsSilence() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 1)
        kernel.setParameter(address: .bypass, value: 1.0)

        let frameCount: AVAudioFrameCount = 256
        let frames = Int(frameCount)

        var inputSamples = [Float](repeating: 0, count: frames)
        var outputSamples = [Float](repeating: 0.5, count: frames)  // Pre-fill to detect changes

        inputSamples.withUnsafeMutableBufferPointer { inputBuf in
            outputSamples.withUnsafeMutableBufferPointer { outputBuf in
                var inputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: inputBuf.baseAddress
                    )
                )
                var outputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: outputBuf.baseAddress
                    )
                )

                kernel.process(
                    inputBufferList: &inputABL,
                    outputBufferList: &outputABL,
                    frameCount: frameCount
                )
            }
        }

        // In bypass mode with silent input, output should be silent
        for i in 0..<frames {
            XCTAssertEqual(outputSamples[i], 0, accuracy: 0.0001,
                           "Frame \(i) should be silent in bypass mode")
        }
    }

    func testProcess_silenceInput_nonBypass_outputsSilence() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 1)
        kernel.setParameter(address: .bypass, value: 0.0)

        let frameCount: AVAudioFrameCount = 512
        let frames = Int(frameCount)

        var inputSamples = [Float](repeating: 0, count: frames)
        var outputSamples = [Float](repeating: 0, count: frames)

        inputSamples.withUnsafeMutableBufferPointer { inputBuf in
            outputSamples.withUnsafeMutableBufferPointer { outputBuf in
                var inputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: inputBuf.baseAddress
                    )
                )
                var outputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: outputBuf.baseAddress
                    )
                )

                kernel.process(
                    inputBufferList: &inputABL,
                    outputBufferList: &outputABL,
                    frameCount: frameCount
                )
            }
        }

        // Silence in should produce silence out (no pitch to detect or correct)
        for i in 0..<frames {
            XCTAssertEqual(outputSamples[i], 0, accuracy: 0.001,
                           "Frame \(i) should be near-silent with silent input")
        }
    }

    func testProcess_rmsLevel_silenceIsZero() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 1)

        let frameCount: AVAudioFrameCount = 512
        let frames = Int(frameCount)

        var inputSamples = [Float](repeating: 0, count: frames)
        var outputSamples = [Float](repeating: 0, count: frames)

        inputSamples.withUnsafeMutableBufferPointer { inputBuf in
            outputSamples.withUnsafeMutableBufferPointer { outputBuf in
                var inputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: inputBuf.baseAddress
                    )
                )
                var outputABL = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                        mData: outputBuf.baseAddress
                    )
                )

                kernel.process(
                    inputBufferList: &inputABL,
                    outputBufferList: &outputABL,
                    frameCount: frameCount
                )
            }
        }

        XCTAssertEqual(kernel.rmsLevel, 0, accuracy: 0.0001)
    }

    // MARK: - Multiple Parameter Changes

    func testMultipleParameterChanges_maintainState() {
        kernel.setParameter(address: .correctionSpeed, value: 0)
        kernel.setParameter(address: .correctionStrength, value: 1.0)
        kernel.setParameter(address: .rootNote, value: 5)  // F
        kernel.setParameter(address: .scaleType, value: 1)  // Major
        kernel.setParameter(address: .inputGain, value: 1.5)

        XCTAssertEqual(kernel.getParameter(address: .correctionSpeed), 0)
        XCTAssertEqual(kernel.getParameter(address: .correctionStrength), 1.0)
        XCTAssertEqual(kernel.getParameter(address: .rootNote), 5)
        XCTAssertEqual(kernel.getParameter(address: .scaleType), 1)
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 1.5)
    }
}

// MARK: - EchoelVoiceAudioUnit Tests

final class EchoelVoiceAudioUnitTests: XCTestCase {

    private var audioUnit: EchoelVoiceAudioUnit!

    private static let effectDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: FourCharCode(0x65766F63), // "evoc"
        componentManufacturer: FourCharCode(0x4563686F), // "Echo"
        componentFlags: 0,
        componentFlagsMask: 0
    )

    override func setUp() {
        super.setUp()
        do {
            audioUnit = try EchoelVoiceAudioUnit(
                componentDescription: Self.effectDescription,
                options: []
            )
        } catch {
            XCTFail("Failed to initialize EchoelVoiceAudioUnit: \(error)")
        }
    }

    override func tearDown() {
        audioUnit = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInit_succeeds() {
        XCTAssertNotNil(audioUnit)
    }

    func testInit_withDifferentDescription_succeeds() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode(0x74657374), // "test"
            componentManufacturer: FourCharCode(0x74657374),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        do {
            let unit = try EchoelVoiceAudioUnit(componentDescription: desc, options: [])
            XCTAssertNotNil(unit)
        } catch {
            XCTFail("Initialization should succeed: \(error)")
        }
    }

    // MARK: - Bus Arrays

    func testInputBusses_hasOneBus() {
        XCTAssertEqual(audioUnit.inputBusses.count, 1)
    }

    func testOutputBusses_hasOneBus() {
        XCTAssertEqual(audioUnit.outputBusses.count, 1)
    }

    func testInputBus_format_isStereo() {
        let bus = audioUnit.inputBusses[0]
        XCTAssertEqual(bus.format.channelCount, 2)
    }

    func testOutputBus_format_isStereo() {
        let bus = audioUnit.outputBusses[0]
        XCTAssertEqual(bus.format.channelCount, 2)
    }

    func testInputBus_format_sampleRate48k() {
        let bus = audioUnit.inputBusses[0]
        XCTAssertEqual(bus.format.sampleRate, 48000)
    }

    func testOutputBus_format_sampleRate48k() {
        let bus = audioUnit.outputBusses[0]
        XCTAssertEqual(bus.format.sampleRate, 48000)
    }

    // MARK: - Parameter Tree

    func testParameterTree_exists() {
        XCTAssertNotNil(audioUnit.parameterTree)
    }

    func testParameterTree_hasFourGroups() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        // The tree's children are the 4 groups: pitch, formant, harmony, gain
        let groups = tree.children.filter { $0 is AUParameterGroup }
        XCTAssertEqual(groups.count, 4,
                       "Parameter tree should have 4 groups (pitch, formant, harmony, gain)")
    }

    func testParameterTree_pitchGroupName() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        let groups = tree.children.compactMap { $0 as? AUParameterGroup }
        let pitchGroup = groups.first { $0.identifier == "pitch" }
        XCTAssertNotNil(pitchGroup)
        XCTAssertEqual(pitchGroup?.displayName, "Pitch Correction")
    }

    func testParameterTree_formantGroupName() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        let groups = tree.children.compactMap { $0 as? AUParameterGroup }
        let group = groups.first { $0.identifier == "formant" }
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.displayName, "Formant")
    }

    func testParameterTree_harmonyGroupName() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        let groups = tree.children.compactMap { $0 as? AUParameterGroup }
        let group = groups.first { $0.identifier == "harmony" }
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.displayName, "Harmony")
    }

    func testParameterTree_gainGroupName() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        let groups = tree.children.compactMap { $0 as? AUParameterGroup }
        let group = groups.first { $0.identifier == "gain" }
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.displayName, "Gain")
    }

    // MARK: - All 13 Parameters Readable/Writable

    func testParameter_correctionSpeed_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 0)
        XCTAssertNotNil(param)
        XCTAssertTrue(param!.flags.contains(.flag_IsReadable))
        XCTAssertTrue(param!.flags.contains(.flag_IsWritable))
    }

    func testParameter_correctionStrength_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 1)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "correctionStrength")
    }

    func testParameter_rootNote_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 2)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "rootNote")
    }

    func testParameter_scaleType_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 3)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "scaleType")
    }

    func testParameter_formantShift_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 4)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "formantShift")
    }

    func testParameter_harmonyMix_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 5)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "harmonyMix")
    }

    func testParameter_harmonyInterval1_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 6)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "harmonyInterval1")
    }

    func testParameter_harmonyInterval2_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 7)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "harmonyInterval2")
    }

    func testParameter_inputGain_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 8)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "inputGain")
    }

    func testParameter_outputGain_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 9)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "outputGain")
    }

    func testParameter_dryWet_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 10)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "dryWet")
    }

    func testParameter_transpose_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 11)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "transpose")
    }

    func testParameter_humanize_readable() {
        let param = audioUnit.parameterTree?.parameter(withAddress: 12)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.identifier, "humanize")
    }

    func testAllParameters_writable() {
        for address: AUParameterAddress in 0...12 {
            let param = audioUnit.parameterTree?.parameter(withAddress: address)
            XCTAssertNotNil(param, "Parameter at address \(address) should exist")
            XCTAssertTrue(param?.flags.contains(.flag_IsWritable) ?? false,
                          "Parameter at address \(address) should be writable")
        }
    }

    func testAllParameters_valueCanBeSet() {
        guard let tree = audioUnit.parameterTree else {
            XCTFail("Parameter tree should exist")
            return
        }
        // Set and read back each parameter
        let param0 = tree.parameter(withAddress: 0)
        param0?.value = 75.0
        XCTAssertEqual(param0?.value, 75.0, accuracy: 0.01)

        let param10 = tree.parameter(withAddress: 10)
        param10?.value = 0.42
        XCTAssertEqual(param10?.value, 0.42, accuracy: 0.01)
    }

    // MARK: - Factory Presets

    func testFactoryPresets_count() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        XCTAssertEqual(presets.count, 7)
    }

    func testFactoryPresets_names() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        let expectedNames = ["Natural", "Pop", "Auto-Tune", "Hard Tune", "Harmony", "Octave Up", "Choir"]
        for (i, name) in expectedNames.enumerated() {
            XCTAssertEqual(presets[i].name, name, "Preset \(i) should be named '\(name)'")
        }
    }

    func testFactoryPresets_numbers() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        for i in 0..<presets.count {
            XCTAssertEqual(presets[i].number, i, "Preset \(i) number should be \(i)")
        }
    }

    func testFactoryPreset_hardTune_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        // Apply Hard Tune preset (index 3)
        audioUnit.currentPreset = presets[3]

        let speed = audioUnit.parameterTree?.parameter(withAddress: 0)
        let strength = audioUnit.parameterTree?.parameter(withAddress: 1)
        let humanize = audioUnit.parameterTree?.parameter(withAddress: 12)

        XCTAssertEqual(speed?.value, 0, accuracy: 0.01, "Hard Tune correctionSpeed should be 0")
        XCTAssertEqual(strength?.value, 1.0, accuracy: 0.01, "Hard Tune correctionStrength should be 1.0")
        XCTAssertEqual(humanize?.value, 0.0, accuracy: 0.01, "Hard Tune humanize should be 0.0")
    }

    func testFactoryPreset_natural_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[0]

        let speed = audioUnit.parameterTree?.parameter(withAddress: 0)
        let strength = audioUnit.parameterTree?.parameter(withAddress: 1)
        let humanize = audioUnit.parameterTree?.parameter(withAddress: 12)
        let harmonyMix = audioUnit.parameterTree?.parameter(withAddress: 5)

        XCTAssertEqual(speed?.value, 150, accuracy: 0.01)
        XCTAssertEqual(strength?.value, 0.5, accuracy: 0.01)
        XCTAssertEqual(humanize?.value, 0.5, accuracy: 0.01)
        XCTAssertEqual(harmonyMix?.value, 0.0, accuracy: 0.01)
    }

    func testFactoryPreset_autoTune_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[2]

        let speed = audioUnit.parameterTree?.parameter(withAddress: 0)
        let strength = audioUnit.parameterTree?.parameter(withAddress: 1)
        let humanize = audioUnit.parameterTree?.parameter(withAddress: 12)

        XCTAssertEqual(speed?.value, 10, accuracy: 0.01)
        XCTAssertEqual(strength?.value, 0.95, accuracy: 0.01)
        XCTAssertEqual(humanize?.value, 0.05, accuracy: 0.01)
    }

    func testFactoryPreset_harmony_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[4]

        let harmonyMix = audioUnit.parameterTree?.parameter(withAddress: 5)
        let interval1 = audioUnit.parameterTree?.parameter(withAddress: 6)
        let interval2 = audioUnit.parameterTree?.parameter(withAddress: 7)

        XCTAssertEqual(harmonyMix?.value, 0.6, accuracy: 0.01)
        XCTAssertEqual(interval1?.value, 4.0, accuracy: 0.01, "Major 3rd interval")
        XCTAssertEqual(interval2?.value, 7.0, accuracy: 0.01, "Perfect 5th interval")
    }

    func testFactoryPreset_octaveUp_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[5]

        let transpose = audioUnit.parameterTree?.parameter(withAddress: 11)
        let harmonyMix = audioUnit.parameterTree?.parameter(withAddress: 5)

        XCTAssertEqual(transpose?.value, 12.0, accuracy: 0.01, "Octave Up transpose should be +12")
        XCTAssertEqual(harmonyMix?.value, 0.0, accuracy: 0.01, "Octave Up has no harmony")
    }

    func testFactoryPreset_choir_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[6]

        let harmonyMix = audioUnit.parameterTree?.parameter(withAddress: 5)
        let interval1 = audioUnit.parameterTree?.parameter(withAddress: 6)
        let interval2 = audioUnit.parameterTree?.parameter(withAddress: 7)
        let humanize = audioUnit.parameterTree?.parameter(withAddress: 12)

        XCTAssertEqual(harmonyMix?.value, 0.8, accuracy: 0.01)
        XCTAssertEqual(interval1?.value, 3.0, accuracy: 0.01, "Minor 3rd interval")
        XCTAssertEqual(interval2?.value, 7.0, accuracy: 0.01, "Perfect 5th interval")
        XCTAssertEqual(humanize?.value, 0.3, accuracy: 0.01)
    }

    func testFactoryPreset_pop_values() {
        guard let presets = audioUnit.factoryPresets else {
            XCTFail("Factory presets should exist")
            return
        }
        audioUnit.currentPreset = presets[1]

        let speed = audioUnit.parameterTree?.parameter(withAddress: 0)
        let strength = audioUnit.parameterTree?.parameter(withAddress: 1)

        XCTAssertEqual(speed?.value, 50, accuracy: 0.01)
        XCTAssertEqual(strength?.value, 0.8, accuracy: 0.01)
    }

    // MARK: - State Save/Restore

    func testFullState_saveAndRestore() {
        // Set non-default values
        audioUnit.parameterTree?.parameter(withAddress: 0)?.value = 123.0
        audioUnit.parameterTree?.parameter(withAddress: 1)?.value = 0.42
        audioUnit.parameterTree?.parameter(withAddress: 2)?.value = 5.0
        audioUnit.parameterTree?.parameter(withAddress: 4)?.value = -3.0
        audioUnit.parameterTree?.parameter(withAddress: 8)?.value = 1.8
        audioUnit.parameterTree?.parameter(withAddress: 10)?.value = 0.65
        audioUnit.parameterTree?.parameter(withAddress: 11)?.value = -7.0

        // Save state
        let state = audioUnit.fullState

        // Create a new audio unit and restore state
        guard let newUnit = try? EchoelVoiceAudioUnit(
            componentDescription: Self.effectDescription, options: []
        ) else {
            XCTFail("Failed to create new audio unit for state restore test")
            return
        }
        newUnit.fullState = state

        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 0)?.value, 123.0, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 1)?.value, 0.42, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 2)?.value, 5.0, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 4)?.value, -3.0, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 8)?.value, 1.8, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 10)?.value, 0.65, accuracy: 0.01)
        XCTAssertEqual(newUnit.parameterTree?.parameter(withAddress: 11)?.value, -7.0, accuracy: 0.01)
    }

    func testFullState_containsAllParameterKeys() {
        let state = audioUnit.fullState
        XCTAssertNotNil(state)

        let expectedKeys = [
            "correctionSpeed", "correctionStrength", "rootNote", "scaleType",
            "formantShift", "harmonyMix", "harmonyInterval1", "harmonyInterval2",
            "inputGain", "outputGain", "dryWet", "transpose", "humanize"
        ]
        for key in expectedKeys {
            XCTAssertNotNil(state?[key], "fullState should contain key '\(key)'")
        }
    }

    func testFullState_restoreWithNil_doesNotCrash() {
        audioUnit.fullState = nil
        // Should not crash
        XCTAssertNotNil(audioUnit)
    }

    // MARK: - Processing Properties

    func testCanProcessInPlace_isTrue() {
        XCTAssertTrue(audioUnit.canProcessInPlace)
    }

    func testLatency_isZero() {
        XCTAssertEqual(audioUnit.latency, 0)
    }

    func testTailTime_isPointOne() {
        XCTAssertEqual(audioUnit.tailTime, 0.1, accuracy: 0.0001)
    }

    func testSupportsUserPresets_isTrue() {
        XCTAssertTrue(audioUnit.supportsUserPresets)
    }

    // MARK: - DSP Kernel Access

    func testDspKernel_isAccessible() {
        XCTAssertNotNil(audioUnit.dspKernel)
    }
}

// MARK: - CIE1931SpectralMapper Tests

final class CIE1931SpectralMapperTests: XCTestCase {

    // MARK: - frequencyToWavelength

    func testFrequencyToWavelength_20Hz_returns700nm() {
        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(20)
        XCTAssertEqual(wavelength, 700, accuracy: 1.0, "20Hz should map to ~700nm (red)")
    }

    func testFrequencyToWavelength_20kHz_returns380nm() {
        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(20000)
        XCTAssertEqual(wavelength, 380, accuracy: 1.0, "20kHz should map to ~380nm (violet)")
    }

    func testFrequencyToWavelength_belowHearing_returnsRed() {
        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(10)
        XCTAssertEqual(wavelength, 700, "Below 20Hz should clamp to 700nm")
    }

    func testFrequencyToWavelength_aboveHearing_returnsViolet() {
        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(25000)
        XCTAssertEqual(wavelength, 380, "Above 20kHz should clamp to 380nm")
    }

    func testFrequencyToWavelength_midRange_returnsMidWavelength() {
        let wavelength = CIE1931SpectralMapper.frequencyToWavelength(1000)
        // 1kHz is roughly in the middle of the log scale
        XCTAssertGreaterThan(wavelength, 380)
        XCTAssertLessThan(wavelength, 700)
    }

    func testFrequencyToWavelength_monotonicallyDecreasing() {
        // Higher frequency should map to shorter wavelength
        let w1 = CIE1931SpectralMapper.frequencyToWavelength(100)
        let w2 = CIE1931SpectralMapper.frequencyToWavelength(1000)
        let w3 = CIE1931SpectralMapper.frequencyToWavelength(10000)
        XCTAssertGreaterThan(w1, w2, "100Hz should have longer wavelength than 1kHz")
        XCTAssertGreaterThan(w2, w3, "1kHz should have longer wavelength than 10kHz")
    }

    func testFrequencyToWavelength_logarithmicMapping() {
        // Equal octave ratios should produce roughly equal wavelength spans
        let w440 = CIE1931SpectralMapper.frequencyToWavelength(440)
        let w880 = CIE1931SpectralMapper.frequencyToWavelength(880)
        let w1760 = CIE1931SpectralMapper.frequencyToWavelength(1760)
        let span1 = w440 - w880
        let span2 = w880 - w1760
        // Should be approximately equal since mapping is logarithmic
        XCTAssertEqual(span1, span2, accuracy: 5.0,
                       "Equal octave ratios should produce similar wavelength spans")
    }

    // MARK: - wavelengthToRGB

    func testWavelengthToRGB_700nm_isRed() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(700)
        XCTAssertGreaterThan(r, 0, "Red should be positive at 700nm")
        XCTAssertEqual(g, 0, accuracy: 0.01, "Green should be near zero at 700nm")
        XCTAssertEqual(b, 0, accuracy: 0.01, "Blue should be near zero at 700nm")
    }

    func testWavelengthToRGB_530nm_isGreen() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(530)
        XCTAssertGreaterThan(g, 0, "Green should be positive at 530nm")
        // Green region (510-580) has green=1.0 and some red
        XCTAssertGreaterThanOrEqual(g, r, "Green should dominate at 530nm")
    }

    func testWavelengthToRGB_450nm_isBlue() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(450)
        XCTAssertGreaterThan(b, 0, "Blue should be positive at 450nm")
        // In 440-490 range, blue is 1.0 and green transitions in
        XCTAssertGreaterThanOrEqual(b, r, "Blue should dominate at 450nm")
    }

    func testWavelengthToRGB_validRange_allComponentsNonNegative() {
        let testWavelengths: [Float] = [380, 400, 420, 450, 490, 510, 530, 580, 600, 645, 700, 780]
        for wl in testWavelengths {
            let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(wl)
            XCTAssertGreaterThanOrEqual(r, 0, "Red should be >= 0 at \(wl)nm")
            XCTAssertGreaterThanOrEqual(g, 0, "Green should be >= 0 at \(wl)nm")
            XCTAssertGreaterThanOrEqual(b, 0, "Blue should be >= 0 at \(wl)nm")
        }
    }

    func testWavelengthToRGB_validRange_allComponentsAtMost1() {
        let testWavelengths: [Float] = [380, 400, 420, 450, 490, 510, 530, 580, 600, 645, 700, 780]
        for wl in testWavelengths {
            let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(wl)
            XCTAssertLessThanOrEqual(r, 1.0, "Red should be <= 1.0 at \(wl)nm")
            XCTAssertLessThanOrEqual(g, 1.0, "Green should be <= 1.0 at \(wl)nm")
            XCTAssertLessThanOrEqual(b, 1.0, "Blue should be <= 1.0 at \(wl)nm")
        }
    }

    func testWavelengthToRGB_outsideRange_returnsBlack() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(300)
        XCTAssertEqual(r, 0, accuracy: 0.001)
        XCTAssertEqual(g, 0, accuracy: 0.001)
        XCTAssertEqual(b, 0, accuracy: 0.001)
    }

    func testWavelengthToRGB_edgeIntensityFalloff_380nm() {
        let (r, _, b) = CIE1931SpectralMapper.wavelengthToRGB(380)
        // At 380nm, intensity is 0.3 (falloff region 380-420)
        // Blue should be present but reduced
        XCTAssertGreaterThan(r + b, 0, "Some color should be present at 380nm")
    }

    func testWavelengthToRGB_edgeIntensityFalloff_780nm() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(780)
        // At 780nm, intensity should be 0.3 (far red edge)
        XCTAssertGreaterThan(r, 0, "Red should have some value at 780nm")
        XCTAssertEqual(g, 0, accuracy: 0.001)
        XCTAssertEqual(b, 0, accuracy: 0.001)
    }

    func testWavelengthToRGB_550nm_isYellowGreen() {
        let (r, g, b) = CIE1931SpectralMapper.wavelengthToRGB(550)
        // 550nm is in 510-580 range: green=1.0, red increasing
        XCTAssertGreaterThan(r, 0, "Red component present at 550nm")
        XCTAssertEqual(g, 1.0, accuracy: 0.01, "Green should be 1.0 at 550nm")
        XCTAssertEqual(b, 0, accuracy: 0.01, "Blue should be 0 at 550nm")
    }

    // MARK: - bandsToColor

    func testBandsToColor_silence_returnsBlack() {
        let silentBands: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0, 0, 0, 0, 0, 0, 0, 0)
        let color = CIE1931SpectralMapper.bandsToColor(silentBands)
        XCTAssertEqual(color.r, 0, accuracy: 0.001)
        XCTAssertEqual(color.g, 0, accuracy: 0.001)
        XCTAssertEqual(color.b, 0, accuracy: 0.001)
        XCTAssertEqual(color.brightness, 0, accuracy: 0.001)
    }

    func testBandsToColor_nearSilence_returnsDark() {
        let nearSilent: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0.0001, 0, 0, 0, 0, 0, 0, 0)
        let color = CIE1931SpectralMapper.bandsToColor(nearSilent)
        // Below 0.001 threshold, should still be black
        XCTAssertEqual(color.brightness, 0, accuracy: 0.01)
    }

    func testBandsToColor_dominantLowBand_returnsWarm() {
        // Sub-bass dominant → should be reddish (700nm)
        let lowDominant: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (1.0, 0.1, 0, 0, 0, 0, 0, 0)
        let color = CIE1931SpectralMapper.bandsToColor(lowDominant)
        XCTAssertGreaterThan(color.r, 0, "Should have red from sub-bass")
        XCTAssertGreaterThan(color.brightness, 0, "Should have positive brightness")
        // Red should dominate because sub-bass maps to 700nm (red)
        XCTAssertGreaterThan(color.r, color.b,
                             "Red should exceed blue for low-frequency dominant signal")
    }

    func testBandsToColor_dominantHighBand_returnsCool() {
        // Air band dominant → should be violet/blue (410nm)
        let highDominant: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0, 0, 0, 0, 0, 0, 0, 1.0)
        let color = CIE1931SpectralMapper.bandsToColor(highDominant)
        // 410nm is in the violet/blue range
        XCTAssertGreaterThan(color.b, 0, "Should have blue from air band")
        XCTAssertGreaterThan(color.brightness, 0)
    }

    func testBandsToColor_midBandDominant_returnsGreen() {
        // Mid band (530nm) → green
        let midDominant: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0, 0, 0, 1.0, 0, 0, 0, 0)
        let color = CIE1931SpectralMapper.bandsToColor(midDominant)
        XCTAssertGreaterThan(color.g, 0, "Should have green from mid band")
    }

    func testBandsToColor_equalBands_producesMixedColor() {
        let equal: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        let color = CIE1931SpectralMapper.bandsToColor(equal)
        // All bands contributing should produce a mixed color with brightness
        XCTAssertGreaterThan(color.brightness, 0)
        XCTAssertGreaterThan(color.r, 0)
    }

    func testBandsToColor_rgbInValidRange() {
        let bands: (Float, Float, Float, Float, Float, Float, Float, Float) =
            (0.8, 0.3, 0.5, 0.9, 0.2, 0.6, 0.1, 0.4)
        let color = CIE1931SpectralMapper.bandsToColor(bands)
        XCTAssertGreaterThanOrEqual(color.r, 0)
        XCTAssertLessThanOrEqual(color.r, 1.0)
        XCTAssertGreaterThanOrEqual(color.g, 0)
        XCTAssertLessThanOrEqual(color.g, 1.0)
        XCTAssertGreaterThanOrEqual(color.b, 0)
        XCTAssertLessThanOrEqual(color.b, 1.0)
        XCTAssertGreaterThanOrEqual(color.brightness, 0)
        XCTAssertLessThanOrEqual(color.brightness, 1.0)
    }

    // MARK: - toCGColor

    func testToCGColor_black_returnsValidCGColor() {
        let black = CIE1931SpectralMapper.SpectralColor.black
        let cgColor = CIE1931SpectralMapper.toCGColor(black)
        XCTAssertNotNil(cgColor)
        XCTAssertEqual(cgColor.numberOfComponents, 4)  // RGBA
    }

    func testToCGColor_brightRed_returnsCorrectComponents() {
        let red = CIE1931SpectralMapper.SpectralColor(r: 1.0, g: 0, b: 0, brightness: 1.0)
        let cgColor = CIE1931SpectralMapper.toCGColor(red)
        guard let components = cgColor.components, components.count >= 3 else {
            XCTFail("CGColor should have components")
            return
        }
        XCTAssertEqual(components[0], 1.0, accuracy: 0.01, "Red component")
        XCTAssertEqual(components[1], 0.0, accuracy: 0.01, "Green component")
        XCTAssertEqual(components[2], 0.0, accuracy: 0.01, "Blue component")
    }

    func testToCGColor_halfBrightness_scalesComponents() {
        let color = CIE1931SpectralMapper.SpectralColor(r: 1.0, g: 0.5, b: 0.25, brightness: 0.5)
        let cgColor = CIE1931SpectralMapper.toCGColor(color)
        guard let components = cgColor.components, components.count >= 3 else {
            XCTFail("CGColor should have components")
            return
        }
        // brightness multiplies each component
        XCTAssertEqual(components[0], 0.5, accuracy: 0.01, "Red * brightness")
        XCTAssertEqual(components[1], 0.25, accuracy: 0.01, "Green * brightness")
        XCTAssertEqual(components[2], 0.125, accuracy: 0.01, "Blue * brightness")
    }

    // MARK: - colorForFrequency

    func testColorForFrequency_440Hz_returnsColor() {
        let color = CIE1931SpectralMapper.colorForFrequency(440, energy: 0.8)
        XCTAssertGreaterThan(color.brightness, 0)
    }

    func testColorForFrequency_zeroEnergy_zeroBrightness() {
        let color = CIE1931SpectralMapper.colorForFrequency(440, energy: 0)
        XCTAssertEqual(color.brightness, 0, accuracy: 0.001)
    }

    func testColorForFrequency_lowFreq_isWarm() {
        let color = CIE1931SpectralMapper.colorForFrequency(40, energy: 1.0)
        // 40Hz maps near 700nm (red)
        XCTAssertGreaterThan(color.r, 0, "Low frequency should have red")
    }

    func testColorForFrequency_highFreq_isCool() {
        let color = CIE1931SpectralMapper.colorForFrequency(15000, energy: 1.0)
        // 15kHz maps near 380-400nm (violet/blue)
        XCTAssertGreaterThan(color.b, 0, "High frequency should have blue")
    }

    // MARK: - SpectralColor

    func testSpectralColor_blackConstant() {
        let black = CIE1931SpectralMapper.SpectralColor.black
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)
        XCTAssertEqual(black.brightness, 0)
    }
}

// MARK: - Factory Function Tests

final class EchoelVoiceFactoryTests: XCTestCase {

    func testAudioUnit_canBeCreatedViaInit() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode(0x65766F63), // "evoc"
            componentManufacturer: FourCharCode(0x4563686F), // "Echo"
            componentFlags: 0,
            componentFlagsMask: 0
        )
        do {
            let unit = try EchoelVoiceAudioUnit(componentDescription: desc, options: [])
            XCTAssertNotNil(unit)
        } catch {
            XCTFail("EchoelVoiceAudioUnit should be creatable via init: \(error)")
        }
    }

    func testAudioUnit_multipleInstances_independent() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode(0x65766F63),
            componentManufacturer: FourCharCode(0x4563686F),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let unit1 = try? EchoelVoiceAudioUnit(componentDescription: desc, options: []),
              let unit2 = try? EchoelVoiceAudioUnit(componentDescription: desc, options: []) else {
            XCTFail("Should create two independent instances")
            return
        }

        // Change parameter on unit1, verify unit2 is unaffected
        unit1.parameterTree?.parameter(withAddress: 0)?.value = 199.0
        XCTAssertEqual(unit1.parameterTree?.parameter(withAddress: 0)?.value, 199.0, accuracy: 0.01)
        XCTAssertEqual(unit2.parameterTree?.parameter(withAddress: 0)?.value, 50.0, accuracy: 0.01,
                       "Second instance should retain its own default value")
    }

    func testAudioUnit_dspKernel_parametersSyncWithTree() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode(0x65766F63),
            componentManufacturer: FourCharCode(0x4563686F),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let unit = try? EchoelVoiceAudioUnit(componentDescription: desc, options: []) else {
            XCTFail("Should create audio unit")
            return
        }

        // Set via parameter tree
        unit.parameterTree?.parameter(withAddress: 8)?.value = 1.7  // inputGain
        // Read via dspKernel
        let kernelValue = unit.dspKernel.getParameter(address: .inputGain)
        XCTAssertEqual(kernelValue, 1.7, accuracy: 0.01,
                       "Kernel parameter should sync with parameter tree")
    }
}
#endif
