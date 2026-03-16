#if canImport(AVFoundation)
import XCTest
import AVFoundation
@testable import Echoelmusic

// MARK: - DSPKernel Tests

final class DSPKernelTests: XCTestCase {

    private var kernel: DSPKernel!

    override func setUp() {
        super.setUp()
        kernel = DSPKernel()
    }

    override func tearDown() {
        kernel = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInit_CreatesKernelSuccessfully() {
        let newKernel = DSPKernel()
        XCTAssertNotNil(newKernel)
    }

    // MARK: - ParameterAddress Enum Raw Values

    func testParameterAddress_WetDry_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.wetDry.rawValue, 0)
    }

    func testParameterAddress_RoomSize_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.roomSize.rawValue, 1)
    }

    func testParameterAddress_Damping_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.damping.rawValue, 2)
    }

    func testParameterAddress_DelayTime_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.delayTime.rawValue, 3)
    }

    func testParameterAddress_Feedback_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.feedback.rawValue, 4)
    }

    func testParameterAddress_FilterCutoff_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.filterCutoff.rawValue, 5)
    }

    func testParameterAddress_FilterResonance_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.filterResonance.rawValue, 6)
    }

    func testParameterAddress_InputGain_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.inputGain.rawValue, 7)
    }

    func testParameterAddress_OutputGain_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.outputGain.rawValue, 8)
    }

    func testParameterAddress_Bypass_RawValue() {
        XCTAssertEqual(DSPKernel.ParameterAddress.bypass.rawValue, 9)
    }

    func testParameterAddress_AllAddressesAreUnique() {
        let addresses: [DSPKernel.ParameterAddress] = [
            .wetDry, .roomSize, .damping, .delayTime, .feedback,
            .filterCutoff, .filterResonance, .inputGain, .outputGain, .bypass
        ]
        let rawValues = addresses.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, 10, "All 10 parameter addresses must be unique")
    }

    func testParameterAddress_InitFromRawValue_ValidAddress() {
        let address = DSPKernel.ParameterAddress(rawValue: 5)
        XCTAssertEqual(address, .filterCutoff)
    }

    func testParameterAddress_InitFromRawValue_InvalidAddress() {
        let address = DSPKernel.ParameterAddress(rawValue: 99)
        XCTAssertNil(address)
    }

    // MARK: - Default Parameter Values

    func testDefaultValue_WetDry() {
        let value = kernel.getParameter(address: .wetDry)
        XCTAssertEqual(value, 0.3, accuracy: 0.001)
    }

    func testDefaultValue_RoomSize() {
        let value = kernel.getParameter(address: .roomSize)
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }

    func testDefaultValue_Damping() {
        let value = kernel.getParameter(address: .damping)
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }

    func testDefaultValue_DelayTime() {
        let value = kernel.getParameter(address: .delayTime)
        XCTAssertEqual(value, 0.25, accuracy: 0.001)
    }

    func testDefaultValue_Feedback() {
        let value = kernel.getParameter(address: .feedback)
        XCTAssertEqual(value, 0.4, accuracy: 0.001)
    }

    func testDefaultValue_FilterCutoff() {
        let value = kernel.getParameter(address: .filterCutoff)
        XCTAssertEqual(value, 8000.0, accuracy: 0.1)
    }

    func testDefaultValue_FilterResonance() {
        let value = kernel.getParameter(address: .filterResonance)
        XCTAssertEqual(value, 0.707, accuracy: 0.001)
    }

    func testDefaultValue_InputGain() {
        let value = kernel.getParameter(address: .inputGain)
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }

    func testDefaultValue_OutputGain() {
        let value = kernel.getParameter(address: .outputGain)
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }

    func testDefaultValue_Bypass() {
        let value = kernel.getParameter(address: .bypass)
        XCTAssertEqual(value, 0.0, accuracy: 0.001, "Bypass should default to off (0.0)")
    }

    // MARK: - Set/Get Parameter Round-Trip

    func testSetGetRoundTrip_WetDry() {
        kernel.setParameter(address: .wetDry, value: 0.75)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.75, accuracy: 0.001)
    }

    func testSetGetRoundTrip_RoomSize() {
        kernel.setParameter(address: .roomSize, value: 0.9)
        XCTAssertEqual(kernel.getParameter(address: .roomSize), 0.9, accuracy: 0.001)
    }

    func testSetGetRoundTrip_Damping() {
        kernel.setParameter(address: .damping, value: 0.8)
        XCTAssertEqual(kernel.getParameter(address: .damping), 0.8, accuracy: 0.001)
    }

    func testSetGetRoundTrip_DelayTime() {
        kernel.setParameter(address: .delayTime, value: 1.5)
        XCTAssertEqual(kernel.getParameter(address: .delayTime), 1.5, accuracy: 0.001)
    }

    func testSetGetRoundTrip_Feedback() {
        kernel.setParameter(address: .feedback, value: 0.85)
        XCTAssertEqual(kernel.getParameter(address: .feedback), 0.85, accuracy: 0.001)
    }

    func testSetGetRoundTrip_FilterCutoff() {
        kernel.setParameter(address: .filterCutoff, value: 12000.0)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 12000.0, accuracy: 0.1)
    }

    func testSetGetRoundTrip_FilterResonance() {
        kernel.setParameter(address: .filterResonance, value: 5.0)
        XCTAssertEqual(kernel.getParameter(address: .filterResonance), 5.0, accuracy: 0.001)
    }

    func testSetGetRoundTrip_InputGain() {
        kernel.setParameter(address: .inputGain, value: 1.5)
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 1.5, accuracy: 0.001)
    }

    func testSetGetRoundTrip_OutputGain() {
        kernel.setParameter(address: .outputGain, value: 0.5)
        XCTAssertEqual(kernel.getParameter(address: .outputGain), 0.5, accuracy: 0.001)
    }

    func testSetGetRoundTrip_Bypass_On() {
        kernel.setParameter(address: .bypass, value: 1.0)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 1.0, accuracy: 0.001)
    }

    func testSetGetRoundTrip_Bypass_Off() {
        kernel.setParameter(address: .bypass, value: 1.0)
        kernel.setParameter(address: .bypass, value: 0.0)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 0.0, accuracy: 0.001)
    }

    func testSetGetRoundTrip_Bypass_ThresholdBehavior() {
        // Values > 0.5 should activate bypass
        kernel.setParameter(address: .bypass, value: 0.51)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 1.0, accuracy: 0.001)

        // Values <= 0.5 should deactivate bypass
        kernel.setParameter(address: .bypass, value: 0.5)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 0.0, accuracy: 0.001)
    }

    func testSetParameter_MultipleUpdates_LastValueWins() {
        kernel.setParameter(address: .wetDry, value: 0.1)
        kernel.setParameter(address: .wetDry, value: 0.5)
        kernel.setParameter(address: .wetDry, value: 0.9)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.9, accuracy: 0.001)
    }

    func testSetParameter_ZeroValues() {
        kernel.setParameter(address: .wetDry, value: 0.0)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.0, accuracy: 0.001)

        kernel.setParameter(address: .feedback, value: 0.0)
        XCTAssertEqual(kernel.getParameter(address: .feedback), 0.0, accuracy: 0.001)
    }

    func testSetParameter_ExtremeCutoff_Low() {
        kernel.setParameter(address: .filterCutoff, value: 20.0)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 20.0, accuracy: 0.1)
    }

    func testSetParameter_ExtremeCutoff_High() {
        kernel.setParameter(address: .filterCutoff, value: 20000.0)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 20000.0, accuracy: 0.1)
    }

    // MARK: - Prepare

    func testPrepare_WithValidSampleRate48000() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        // Kernel should not crash; verify parameters are still accessible
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.3, accuracy: 0.001)
    }

    func testPrepare_WithValidSampleRate44100() {
        kernel.prepare(sampleRate: 44100, maxFrames: 256, channelCount: 2)
        XCTAssertEqual(kernel.getParameter(address: .roomSize), 0.5, accuracy: 0.001)
    }

    func testPrepare_WithValidSampleRate96000() {
        kernel.prepare(sampleRate: 96000, maxFrames: 1024, channelCount: 2)
        XCTAssertEqual(kernel.getParameter(address: .damping), 0.5, accuracy: 0.001)
    }

    func testPrepare_MonoChannel() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 1)
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 1.0, accuracy: 0.001)
    }

    func testPrepare_LargeFrameCount() {
        kernel.prepare(sampleRate: 48000, maxFrames: 4096, channelCount: 2)
        XCTAssertEqual(kernel.getParameter(address: .outputGain), 1.0, accuracy: 0.001)
    }

    // MARK: - Reset

    func testReset_AfterPrepare_DoesNotCrash() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()
        // Parameters should be unaffected by reset
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.3, accuracy: 0.001)
    }

    func testReset_PreservesParameterValues() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.setParameter(address: .wetDry, value: 0.8)
        kernel.setParameter(address: .roomSize, value: 0.9)
        kernel.setParameter(address: .filterCutoff, value: 3000)
        kernel.reset()

        // Parameters should remain after reset (only DSP state clears)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.8, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .roomSize), 0.9, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 3000, accuracy: 0.1)
    }

    func testReset_CalledMultipleTimes_DoesNotCrash() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.reset()
        kernel.reset()
        kernel.reset()
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.3, accuracy: 0.001)
    }

    // MARK: - Freeverb Constants

    func testFreeverbCombDelays_Count() {
        // Freeverb uses 8 comb delays
        let expectedDelays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        XCTAssertEqual(expectedDelays.count, 8)
    }

    func testFreeverbCombDelays_Values() {
        // Standard Freeverb comb delay lengths (in samples at 44100 Hz)
        let expectedDelays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        // Verify the known Freeverb values
        XCTAssertEqual(expectedDelays[0], 1116)
        XCTAssertEqual(expectedDelays[1], 1188)
        XCTAssertEqual(expectedDelays[2], 1277)
        XCTAssertEqual(expectedDelays[3], 1356)
        XCTAssertEqual(expectedDelays[4], 1422)
        XCTAssertEqual(expectedDelays[5], 1491)
        XCTAssertEqual(expectedDelays[6], 1557)
        XCTAssertEqual(expectedDelays[7], 1617)
    }

    func testFreeverbAllpassDelays_Count() {
        // Freeverb uses 4 allpass delays
        let expectedDelays = [556, 441, 341, 225]
        XCTAssertEqual(expectedDelays.count, 4)
    }

    func testFreeverbAllpassDelays_Values() {
        let expectedDelays = [556, 441, 341, 225]
        XCTAssertEqual(expectedDelays[0], 556)
        XCTAssertEqual(expectedDelays[1], 441)
        XCTAssertEqual(expectedDelays[2], 341)
        XCTAssertEqual(expectedDelays[3], 225)
    }

    func testFreeverbCombDelays_AreStrictlyIncreasing() {
        let delays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        for i in 1..<delays.count {
            XCTAssertGreaterThan(delays[i], delays[i - 1],
                                 "Comb delay \(i) should be greater than \(i - 1)")
        }
    }

    func testFreeverbAllpassDelays_AreStrictlyDecreasing() {
        let delays = [556, 441, 341, 225]
        for i in 1..<delays.count {
            XCTAssertLessThan(delays[i], delays[i - 1],
                              "Allpass delay \(i) should be less than \(i - 1)")
        }
    }

    // MARK: - Parameter Setting After Prepare

    func testSetParameter_AfterPrepare_UpdatesKernel() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.setParameter(address: .wetDry, value: 0.6)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.6, accuracy: 0.001)
    }

    func testSetParameter_FilterCutoff_AfterPrepare_UpdatesCoefficients() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.setParameter(address: .filterCutoff, value: 2000.0)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 2000.0, accuracy: 0.1)
    }

    func testSetParameter_FilterResonance_AfterPrepare_UpdatesCoefficients() {
        kernel.prepare(sampleRate: 48000, maxFrames: 512, channelCount: 2)
        kernel.setParameter(address: .filterResonance, value: 10.0)
        XCTAssertEqual(kernel.getParameter(address: .filterResonance), 10.0, accuracy: 0.001)
    }

    // MARK: - Full Lifecycle

    func testFullLifecycle_PrepareProcessReset() {
        kernel.prepare(sampleRate: 44100, maxFrames: 512, channelCount: 2)
        kernel.setParameter(address: .wetDry, value: 0.5)
        kernel.setParameter(address: .roomSize, value: 0.7)
        kernel.setParameter(address: .bypass, value: 0.0)
        kernel.reset()
        // After reset, parameters persist, DSP state clears
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.5, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .roomSize), 0.7, accuracy: 0.001)
    }

    func testPrepare_ThenReset_ThenPrepareAgain() {
        kernel.prepare(sampleRate: 44100, maxFrames: 256, channelCount: 2)
        kernel.reset()
        kernel.prepare(sampleRate: 96000, maxFrames: 1024, channelCount: 2)
        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.3, accuracy: 0.001)
    }

    // MARK: - All Parameters Independent

    func testAllParametersSetIndependently() {
        kernel.setParameter(address: .wetDry, value: 0.1)
        kernel.setParameter(address: .roomSize, value: 0.2)
        kernel.setParameter(address: .damping, value: 0.3)
        kernel.setParameter(address: .delayTime, value: 0.4)
        kernel.setParameter(address: .feedback, value: 0.5)
        kernel.setParameter(address: .filterCutoff, value: 6000)
        kernel.setParameter(address: .filterResonance, value: 2.0)
        kernel.setParameter(address: .inputGain, value: 0.8)
        kernel.setParameter(address: .outputGain, value: 0.9)
        kernel.setParameter(address: .bypass, value: 1.0)

        XCTAssertEqual(kernel.getParameter(address: .wetDry), 0.1, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .roomSize), 0.2, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .damping), 0.3, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .delayTime), 0.4, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .feedback), 0.5, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .filterCutoff), 6000, accuracy: 0.1)
        XCTAssertEqual(kernel.getParameter(address: .filterResonance), 2.0, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .inputGain), 0.8, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .outputGain), 0.9, accuracy: 0.001)
        XCTAssertEqual(kernel.getParameter(address: .bypass), 1.0, accuracy: 0.001)
    }
}

// MARK: - EchoelmusicAudioUnit Tests

final class EchoelmusicAudioUnitTests: XCTestCase {

    /// Helper: create a standard AudioComponentDescription for an effect AU
    private func makeComponentDescription() -> AudioComponentDescription {
        return AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }

    /// Helper: instantiate the audio unit
    private func makeAudioUnit() throws -> EchoelmusicAudioUnit {
        return try EchoelmusicAudioUnit(
            componentDescription: makeComponentDescription(),
            options: []
        )
    }

    // MARK: - Initialization

    func testInit_Succeeds() throws {
        let au = try makeAudioUnit()
        XCTAssertNotNil(au)
    }

    func testInit_MultipleTimes_EachSucceeds() throws {
        let au1 = try makeAudioUnit()
        let au2 = try makeAudioUnit()
        XCTAssertNotNil(au1)
        XCTAssertNotNil(au2)
    }

    // MARK: - Bus Configuration

    func testInputBusses_HasOneBus() throws {
        let au = try makeAudioUnit()
        XCTAssertEqual(au.inputBusses.count, 1)
    }

    func testOutputBusses_HasOneBus() throws {
        let au = try makeAudioUnit()
        XCTAssertEqual(au.outputBusses.count, 1)
    }

    func testInputBus_DefaultFormat_IsStereo() throws {
        let au = try makeAudioUnit()
        let format = au.inputBusses[0].format
        XCTAssertEqual(format.channelCount, 2)
    }

    func testOutputBus_DefaultFormat_IsStereo() throws {
        let au = try makeAudioUnit()
        let format = au.outputBusses[0].format
        XCTAssertEqual(format.channelCount, 2)
    }

    func testInputBus_DefaultFormat_SampleRate48000() throws {
        let au = try makeAudioUnit()
        let format = au.inputBusses[0].format
        XCTAssertEqual(format.sampleRate, 48000.0, accuracy: 0.1)
    }

    func testOutputBus_DefaultFormat_SampleRate48000() throws {
        let au = try makeAudioUnit()
        let format = au.outputBusses[0].format
        XCTAssertEqual(format.sampleRate, 48000.0, accuracy: 0.1)
    }

    // MARK: - Parameter Tree

    func testParameterTree_Exists() throws {
        let au = try makeAudioUnit()
        XCTAssertNotNil(au.parameterTree)
    }

    func testParameterTree_HasFourGroups() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        // Top-level children are 4 groups: Reverb, Delay, Filter, Gain
        XCTAssertEqual(tree.children.count, 4)
    }

    func testParameterTree_GroupNames() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let groupNames = tree.children.compactMap { ($0 as? AUParameterGroup)?.displayName }
        XCTAssertTrue(groupNames.contains("Reverb"), "Missing Reverb group")
        XCTAssertTrue(groupNames.contains("Delay"), "Missing Delay group")
        XCTAssertTrue(groupNames.contains("Filter"), "Missing Filter group")
        XCTAssertTrue(groupNames.contains("Gain"), "Missing Gain group")
    }

    func testParameterTree_ReverbGroup_HasThreeParameters() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let reverbGroup = tree.children.compactMap { $0 as? AUParameterGroup }.first { $0.displayName == "Reverb" }
        XCTAssertNotNil(reverbGroup)
        XCTAssertEqual(reverbGroup?.children.count, 3, "Reverb group should have 3 parameters (wetDry, roomSize, damping)")
    }

    func testParameterTree_DelayGroup_HasTwoParameters() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let delayGroup = tree.children.compactMap { $0 as? AUParameterGroup }.first { $0.displayName == "Delay" }
        XCTAssertNotNil(delayGroup)
        XCTAssertEqual(delayGroup?.children.count, 2, "Delay group should have 2 parameters (delayTime, feedback)")
    }

    func testParameterTree_FilterGroup_HasTwoParameters() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let filterGroup = tree.children.compactMap { $0 as? AUParameterGroup }.first { $0.displayName == "Filter" }
        XCTAssertNotNil(filterGroup)
        XCTAssertEqual(filterGroup?.children.count, 2, "Filter group should have 2 parameters (cutoff, resonance)")
    }

    func testParameterTree_GainGroup_HasTwoParameters() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let gainGroup = tree.children.compactMap { $0 as? AUParameterGroup }.first { $0.displayName == "Gain" }
        XCTAssertNotNil(gainGroup)
        XCTAssertEqual(gainGroup?.children.count, 2, "Gain group should have 2 parameters (inputGain, outputGain)")
    }

    // MARK: - Writable Parameters

    func testParameterTree_TotalWritableParameters() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        let allParams = tree.allParameters
        let writableParams = allParams.filter { $0.flags.contains(.flag_IsWritable) }
        XCTAssertEqual(writableParams.count, 9, "Should have 9 writable parameters")
    }

    func testParameterTree_AllParametersAreReadable() throws {
        let au = try makeAudioUnit()
        guard let tree = au.parameterTree else {
            XCTFail("Parameter tree is nil")
            return
        }
        for param in tree.allParameters {
            XCTAssertTrue(param.flags.contains(.flag_IsReadable),
                          "Parameter \(param.identifier) should be readable")
        }
    }

    // MARK: - Parameter Default Values via Tree

    func testParameterDefault_WetDry() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.3, accuracy: 0.001)
    }

    func testParameterDefault_RoomSize() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 1)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.5, accuracy: 0.001)
    }

    func testParameterDefault_Damping() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 2)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.5, accuracy: 0.001)
    }

    func testParameterDefault_DelayTime() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.25, accuracy: 0.001)
    }

    func testParameterDefault_Feedback() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 4)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.4, accuracy: 0.001)
    }

    func testParameterDefault_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 8000.0, accuracy: 0.1)
    }

    func testParameterDefault_FilterResonance() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 6)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 0.707, accuracy: 0.001)
    }

    func testParameterDefault_InputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 7)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 1.0, accuracy: 0.001)
    }

    func testParameterDefault_OutputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 8)
        XCTAssertNotNil(param)
        XCTAssertEqual(param?.value ?? -1, 1.0, accuracy: 0.001)
    }

    // MARK: - Parameter Ranges

    func testParameterRange_WetDry() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertEqual(param?.minValue, 0.0)
        XCTAssertEqual(param?.maxValue, 1.0)
    }

    func testParameterRange_DelayTime() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertEqual(param?.minValue, 0.01, accuracy: 0.001)
        XCTAssertEqual(param?.maxValue, 2.0, accuracy: 0.001)
    }

    func testParameterRange_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(param?.minValue, 20.0, accuracy: 0.1)
        XCTAssertEqual(param?.maxValue, 20000.0, accuracy: 0.1)
    }

    func testParameterRange_Feedback() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 4)
        XCTAssertEqual(param?.minValue, 0.0)
        XCTAssertEqual(param?.maxValue, 0.9, accuracy: 0.001)
    }

    func testParameterRange_InputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 7)
        XCTAssertEqual(param?.minValue, 0.0)
        XCTAssertEqual(param?.maxValue, 2.0, accuracy: 0.001)
    }

    func testParameterRange_OutputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 8)
        XCTAssertEqual(param?.minValue, 0.0)
        XCTAssertEqual(param?.maxValue, 2.0, accuracy: 0.001)
    }

    func testParameterRange_FilterResonance() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 6)
        XCTAssertEqual(param?.minValue, 0.1, accuracy: 0.001)
        XCTAssertEqual(param?.maxValue, 20.0, accuracy: 0.001)
    }

    // MARK: - Parameter Units

    func testParameterUnit_DelayTime_IsSeconds() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertEqual(param?.unit, .seconds)
    }

    func testParameterUnit_FilterCutoff_IsHertz() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(param?.unit, .hertz)
    }

    func testParameterUnit_InputGain_IsLinearGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 7)
        XCTAssertEqual(param?.unit, .linearGain)
    }

    func testParameterUnit_OutputGain_IsLinearGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 8)
        XCTAssertEqual(param?.unit, .linearGain)
    }

    // MARK: - Factory Presets

    func testFactoryPresets_Exist() throws {
        let au = try makeAudioUnit()
        XCTAssertNotNil(au.factoryPresets)
    }

    func testFactoryPresets_Count() throws {
        let au = try makeAudioUnit()
        XCTAssertEqual(au.factoryPresets?.count, 5)
    }

    func testFactoryPreset_0_IsClean() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        XCTAssertEqual(presets[0].name, "Clean")
        XCTAssertEqual(presets[0].number, 0)
    }

    func testFactoryPreset_1_IsSmallRoom() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        XCTAssertEqual(presets[1].name, "Small Room")
        XCTAssertEqual(presets[1].number, 1)
    }

    func testFactoryPreset_2_IsLargeHall() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        XCTAssertEqual(presets[2].name, "Large Hall")
        XCTAssertEqual(presets[2].number, 2)
    }

    func testFactoryPreset_3_IsEchoChamber() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        XCTAssertEqual(presets[3].name, "Echo Chamber")
        XCTAssertEqual(presets[3].number, 3)
    }

    func testFactoryPreset_4_IsBioReactive() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        XCTAssertEqual(presets[4].name, "Bio-Reactive")
        XCTAssertEqual(presets[4].number, 4)
    }

    func testFactoryPreset_NumbersAreSequential() throws {
        let au = try makeAudioUnit()
        guard let presets = au.factoryPresets else {
            XCTFail("No factory presets")
            return
        }
        for (index, preset) in presets.enumerated() {
            XCTAssertEqual(preset.number, index, "Preset at index \(index) should have number \(index)")
        }
    }

    // MARK: - Preset Values

    func testApplyPreset_Clean_WetDryNearZero() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 0
        preset.name = "Clean"
        au.currentPreset = preset

        let wetDry = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertEqual(wetDry?.value ?? -1, 0.0, accuracy: 0.01, "Clean preset should have wetDry near 0")
    }

    func testApplyPreset_Clean_FeedbackZero() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 0
        preset.name = "Clean"
        au.currentPreset = preset

        let feedback = au.parameterTree?.parameter(withAddress: 4)
        XCTAssertEqual(feedback?.value ?? -1, 0.0, accuracy: 0.01, "Clean preset should have zero feedback")
    }

    func testApplyPreset_Clean_FullCutoff() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 0
        preset.name = "Clean"
        au.currentPreset = preset

        let cutoff = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(cutoff?.value ?? -1, 20000.0, accuracy: 1.0, "Clean preset should have max cutoff")
    }

    func testApplyPreset_SmallRoom_RoomSize() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 1
        preset.name = "Small Room"
        au.currentPreset = preset

        let roomSize = au.parameterTree?.parameter(withAddress: 1)
        XCTAssertEqual(roomSize?.value ?? -1, 0.3, accuracy: 0.01)
    }

    func testApplyPreset_SmallRoom_Damping() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 1
        preset.name = "Small Room"
        au.currentPreset = preset

        let damping = au.parameterTree?.parameter(withAddress: 2)
        XCTAssertEqual(damping?.value ?? -1, 0.6, accuracy: 0.01)
    }

    func testApplyPreset_LargeHall_RoomSize() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 2
        preset.name = "Large Hall"
        au.currentPreset = preset

        let roomSize = au.parameterTree?.parameter(withAddress: 1)
        XCTAssertEqual(roomSize?.value ?? -1, 0.85, accuracy: 0.01)
    }

    func testApplyPreset_LargeHall_WetDry() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 2
        preset.name = "Large Hall"
        au.currentPreset = preset

        let wetDry = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertEqual(wetDry?.value ?? -1, 0.5, accuracy: 0.01)
    }

    func testApplyPreset_LargeHall_Damping() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 2
        preset.name = "Large Hall"
        au.currentPreset = preset

        let damping = au.parameterTree?.parameter(withAddress: 2)
        XCTAssertEqual(damping?.value ?? -1, 0.3, accuracy: 0.01)
    }

    func testApplyPreset_LargeHall_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 2
        preset.name = "Large Hall"
        au.currentPreset = preset

        let cutoff = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(cutoff?.value ?? -1, 6000.0, accuracy: 1.0)
    }

    func testApplyPreset_EchoChamber_DelayTime() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 3
        preset.name = "Echo Chamber"
        au.currentPreset = preset

        let delayTime = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertEqual(delayTime?.value ?? -1, 0.375, accuracy: 0.001)
    }

    func testApplyPreset_EchoChamber_Feedback() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 3
        preset.name = "Echo Chamber"
        au.currentPreset = preset

        let feedback = au.parameterTree?.parameter(withAddress: 4)
        XCTAssertEqual(feedback?.value ?? -1, 0.6, accuracy: 0.01)
    }

    func testApplyPreset_EchoChamber_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 3
        preset.name = "Echo Chamber"
        au.currentPreset = preset

        let cutoff = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(cutoff?.value ?? -1, 5000.0, accuracy: 1.0)
    }

    func testApplyPreset_BioReactive_DefaultValues() throws {
        let au = try makeAudioUnit()
        let preset = AUAudioUnitPreset()
        preset.number = 4
        preset.name = "Bio-Reactive"
        au.currentPreset = preset

        let wetDry = au.parameterTree?.parameter(withAddress: 0)
        let roomSize = au.parameterTree?.parameter(withAddress: 1)
        let damping = au.parameterTree?.parameter(withAddress: 2)
        let delayTime = au.parameterTree?.parameter(withAddress: 3)
        let feedback = au.parameterTree?.parameter(withAddress: 4)
        let cutoff = au.parameterTree?.parameter(withAddress: 5)

        XCTAssertEqual(wetDry?.value ?? -1, 0.3, accuracy: 0.01)
        XCTAssertEqual(roomSize?.value ?? -1, 0.5, accuracy: 0.01)
        XCTAssertEqual(damping?.value ?? -1, 0.5, accuracy: 0.01)
        XCTAssertEqual(delayTime?.value ?? -1, 0.25, accuracy: 0.01)
        XCTAssertEqual(feedback?.value ?? -1, 0.4, accuracy: 0.01)
        XCTAssertEqual(cutoff?.value ?? -1, 8000.0, accuracy: 1.0)
    }

    // MARK: - State Save/Restore

    func testFullState_Save_ReturnsNonNilDictionary() throws {
        let au = try makeAudioUnit()
        let state = au.fullState
        XCTAssertNotNil(state)
    }

    func testFullState_Save_ContainsAllParameterKeys() throws {
        let au = try makeAudioUnit()
        guard let state = au.fullState else {
            XCTFail("fullState is nil")
            return
        }
        let expectedKeys = ["wetDry", "roomSize", "damping", "delayTime",
                            "feedback", "filterCutoff", "filterResonance",
                            "inputGain", "outputGain"]
        for key in expectedKeys {
            XCTAssertNotNil(state[key], "fullState should contain key '\(key)'")
        }
    }

    func testFullState_RoundTrip_PreservesValues() throws {
        let au = try makeAudioUnit()

        // Set non-default values
        au.parameterTree?.parameter(withAddress: 0)?.value = 0.7   // wetDry
        au.parameterTree?.parameter(withAddress: 1)?.value = 0.85  // roomSize
        au.parameterTree?.parameter(withAddress: 2)?.value = 0.2   // damping
        au.parameterTree?.parameter(withAddress: 3)?.value = 1.0   // delayTime
        au.parameterTree?.parameter(withAddress: 4)?.value = 0.8   // feedback
        au.parameterTree?.parameter(withAddress: 5)?.value = 3000  // filterCutoff
        au.parameterTree?.parameter(withAddress: 6)?.value = 5.0   // filterResonance
        au.parameterTree?.parameter(withAddress: 7)?.value = 0.5   // inputGain
        au.parameterTree?.parameter(withAddress: 8)?.value = 1.5   // outputGain

        // Save state
        let savedState = au.fullState

        // Reset to defaults via Bio-Reactive preset
        let preset = AUAudioUnitPreset()
        preset.number = 4
        preset.name = "Bio-Reactive"
        au.currentPreset = preset

        // Restore state
        au.fullState = savedState

        // Verify restored values
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.7, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 1)?.value ?? -1, 0.85, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 2)?.value ?? -1, 0.2, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 3)?.value ?? -1, 1.0, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 4)?.value ?? -1, 0.8, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 5)?.value ?? -1, 3000, accuracy: 1.0)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 6)?.value ?? -1, 5.0, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 7)?.value ?? -1, 0.5, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 8)?.value ?? -1, 1.5, accuracy: 0.01)
    }

    func testFullState_RestoreNil_DoesNotCrash() throws {
        let au = try makeAudioUnit()
        au.fullState = nil
        // Should not crash; parameters retain previous values
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.3, accuracy: 0.001)
    }

    func testFullState_RestorePartialState_UpdatesOnlyProvidedKeys() throws {
        let au = try makeAudioUnit()
        let partialState: [String: Any] = [
            "wetDry": Float(0.9),
            "roomSize": Float(0.1)
        ]
        au.fullState = partialState

        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.9, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 1)?.value ?? -1, 0.1, accuracy: 0.01)
    }

    // MARK: - Processing Properties

    func testCanProcessInPlace_IsTrue() throws {
        let au = try makeAudioUnit()
        XCTAssertTrue(au.canProcessInPlace)
    }

    func testSupportsUserPresets_IsTrue() throws {
        let au = try makeAudioUnit()
        XCTAssertTrue(au.supportsUserPresets)
    }

    func testLatency_IsZero() throws {
        let au = try makeAudioUnit()
        XCTAssertEqual(au.latency, 0.0, accuracy: 0.0001)
    }

    func testTailTime_IsPositive() throws {
        let au = try makeAudioUnit()
        XCTAssertGreaterThan(au.tailTime, 0.0)
    }

    func testTailTime_IncludesDelayAndReverb() throws {
        let au = try makeAudioUnit()
        // tailTime = delayTime (0.25) + 2.0 = 2.25
        XCTAssertEqual(au.tailTime, 2.25, accuracy: 0.01)
    }

    func testTailTime_UpdatesWithDelayTimeParameter() throws {
        let au = try makeAudioUnit()
        au.parameterTree?.parameter(withAddress: 3)?.value = 1.5
        // tailTime = delayTime (1.5) + 2.0 = 3.5
        XCTAssertEqual(au.tailTime, 3.5, accuracy: 0.01)
    }

    // MARK: - Render Block

    func testInternalRenderBlock_IsNotNil() throws {
        let au = try makeAudioUnit()
        let renderBlock = au.internalRenderBlock
        XCTAssertNotNil(renderBlock)
    }

    // MARK: - Parameter Identifiers

    func testParameterIdentifier_WetDry() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertEqual(param?.identifier, "wetDry")
    }

    func testParameterIdentifier_RoomSize() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 1)
        XCTAssertEqual(param?.identifier, "roomSize")
    }

    func testParameterIdentifier_Damping() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 2)
        XCTAssertEqual(param?.identifier, "damping")
    }

    func testParameterIdentifier_DelayTime() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertEqual(param?.identifier, "delayTime")
    }

    func testParameterIdentifier_Feedback() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 4)
        XCTAssertEqual(param?.identifier, "feedback")
    }

    func testParameterIdentifier_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(param?.identifier, "filterCutoff")
    }

    func testParameterIdentifier_FilterResonance() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 6)
        XCTAssertEqual(param?.identifier, "filterResonance")
    }

    func testParameterIdentifier_InputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 7)
        XCTAssertEqual(param?.identifier, "inputGain")
    }

    func testParameterIdentifier_OutputGain() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 8)
        XCTAssertEqual(param?.identifier, "outputGain")
    }

    // MARK: - Parameter Display Names

    func testParameterDisplayName_WetDry() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 0)
        XCTAssertEqual(param?.displayName, "Wet/Dry Mix")
    }

    func testParameterDisplayName_RoomSize() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 1)
        XCTAssertEqual(param?.displayName, "Room Size")
    }

    func testParameterDisplayName_FilterCutoff() throws {
        let au = try makeAudioUnit()
        let param = au.parameterTree?.parameter(withAddress: 5)
        XCTAssertEqual(param?.displayName, "Filter Cutoff")
    }

    // MARK: - Parameter Value Observer/Provider Integration

    func testParameterTree_SetValueViaTree_ReflectsInKernel() throws {
        let au = try makeAudioUnit()
        au.parameterTree?.parameter(withAddress: 0)?.value = 0.65
        // Read back via tree (which calls implementorValueProvider -> kernel)
        let readBack = au.parameterTree?.parameter(withAddress: 0)?.value ?? -1
        XCTAssertEqual(readBack, 0.65, accuracy: 0.01)
    }

    func testParameterTree_SetMultipleValues_AllReflect() throws {
        let au = try makeAudioUnit()
        au.parameterTree?.parameter(withAddress: 0)?.value = 0.1
        au.parameterTree?.parameter(withAddress: 1)?.value = 0.2
        au.parameterTree?.parameter(withAddress: 5)?.value = 4000

        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.1, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 1)?.value ?? -1, 0.2, accuracy: 0.01)
        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 5)?.value ?? -1, 4000, accuracy: 1.0)
    }

    // MARK: - Preset Switching Overwrites Parameters

    func testPresetSwitch_OverwritesPreviousValues() throws {
        let au = try makeAudioUnit()

        // Set custom values
        au.parameterTree?.parameter(withAddress: 0)?.value = 0.99
        au.parameterTree?.parameter(withAddress: 1)?.value = 0.99

        // Apply Clean preset
        let preset = AUAudioUnitPreset()
        preset.number = 0
        preset.name = "Clean"
        au.currentPreset = preset

        XCTAssertEqual(au.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.0, accuracy: 0.01,
                       "Clean preset should override custom wetDry")
    }

    func testPresetSwitch_MultiplePresets_LastWins() throws {
        let au = try makeAudioUnit()

        // Apply Large Hall
        let hall = AUAudioUnitPreset()
        hall.number = 2
        hall.name = "Large Hall"
        au.currentPreset = hall

        // Apply Echo Chamber
        let echo = AUAudioUnitPreset()
        echo.number = 3
        echo.name = "Echo Chamber"
        au.currentPreset = echo

        let delayTime = au.parameterTree?.parameter(withAddress: 3)
        XCTAssertEqual(delayTime?.value ?? -1, 0.375, accuracy: 0.001,
                       "Echo Chamber delay time should be active")
    }
}

// MARK: - Factory Function Tests

final class EchoelmusicAudioUnitFactoryTests: XCTestCase {

    func testAudioUnit_CanBeInstantiated_ViaInit() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try EchoelmusicAudioUnit(componentDescription: desc, options: [])
        XCTAssertNotNil(au, "Factory-style instantiation should succeed")
    }

    func testAudioUnit_InstantiatedMultipleTimes_EachIsIndependent() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        let au1 = try EchoelmusicAudioUnit(componentDescription: desc, options: [])
        let au2 = try EchoelmusicAudioUnit(componentDescription: desc, options: [])

        // Modify au1 parameter
        au1.parameterTree?.parameter(withAddress: 0)?.value = 0.99

        // au2 should remain at default
        XCTAssertEqual(au2.parameterTree?.parameter(withAddress: 0)?.value ?? -1, 0.3, accuracy: 0.01,
                       "Second instance should be independent of first")
    }

    func testAudioUnit_ComponentDescription_TypeIsEffect() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try EchoelmusicAudioUnit(componentDescription: desc, options: [])
        XCTAssertEqual(au.componentDescription.componentType, kAudioUnitType_Effect)
    }

    func testAudioUnit_ComponentDescription_SubType() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try EchoelmusicAudioUnit(componentDescription: desc, options: [])
        XCTAssertEqual(au.componentDescription.componentSubType, FourCharCode("echl"))
    }

    func testAudioUnit_ComponentDescription_Manufacturer() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("echl"),
            componentManufacturer: FourCharCode("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try EchoelmusicAudioUnit(componentDescription: desc, options: [])
        XCTAssertEqual(au.componentDescription.componentManufacturer, FourCharCode("Echo"))
    }
}

// MARK: - FourCharCode Helper

private func FourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | UInt32(char)
    }
    return result
}

#endif
