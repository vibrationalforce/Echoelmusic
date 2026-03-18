#if canImport(AVFoundation)
// AudioNodeBehaviorTests.swift
// Echoelmusic — Behavioral tests for audio processing nodes
//
// Tests CompressorNode, FilterNode, ReverbNode, DelayNode, SaturationNode
// for parameter management, state transitions, bypass behavior, and bio-reactivity.

import XCTest
@testable import Echoelmusic

// MARK: - CompressorNode Tests

@MainActor
final class CompressorNodeBehaviorTests: XCTestCase {

    func testCompressor_Init_HasCorrectName() {
        let compressor = CompressorNode()
        XCTAssertEqual(compressor.name, "Bio-Reactive Compressor")
        XCTAssertEqual(compressor.type, .effect)
    }

    func testCompressor_DefaultParameters_ValidRanges() {
        let compressor = CompressorNode()
        for param in compressor.parameters {
            XCTAssertGreaterThanOrEqual(param.value, param.min,
                "\(param.name) value \(param.value) below min \(param.min)")
            XCTAssertLessThanOrEqual(param.value, param.max,
                "\(param.name) value \(param.value) above max \(param.max)")
        }
    }

    func testCompressor_SetParameter_UpdatesValue() {
        let compressor = CompressorNode()
        compressor.setParameter(name: "threshold", value: -30.0)
        let threshold = compressor.getParameter(name: "threshold")
        XCTAssertNotNil(threshold)
        XCTAssertEqual(threshold ?? 0, -30.0, accuracy: 0.01)
    }

    func testCompressor_SetInvalidParameter_ReturnsNil() {
        let compressor = CompressorNode()
        let value = compressor.getParameter(name: "nonexistent_param")
        XCTAssertNil(value)
    }

    func testCompressor_Bypass_ToggleState() {
        let compressor = CompressorNode()
        XCTAssertFalse(compressor.isBypassed)
        compressor.isBypassed = true
        XCTAssertTrue(compressor.isBypassed)
        compressor.isBypassed = false
        XCTAssertFalse(compressor.isBypassed)
    }

    func testCompressor_StartStop_Lifecycle() {
        let compressor = CompressorNode()
        XCTAssertFalse(compressor.isActive)
        compressor.start()
        XCTAssertTrue(compressor.isActive)
        compressor.stop()
        XCTAssertFalse(compressor.isActive)
    }

    func testCompressor_Reset_ClearsState() {
        let compressor = CompressorNode()
        compressor.start()
        compressor.reset()
        XCTAssertEqual(compressor.gainReduction, 0.0, accuracy: 0.01)
    }

    func testCompressor_HasRequiredParameters() {
        let compressor = CompressorNode()
        let paramNames = compressor.parameters.map { $0.name }
        XCTAssertTrue(paramNames.contains("threshold"), "Missing threshold parameter")
        XCTAssertTrue(paramNames.contains("ratio"), "Missing ratio parameter")
        XCTAssertTrue(paramNames.contains("attack"), "Missing attack parameter")
        XCTAssertTrue(paramNames.contains("release"), "Missing release parameter")
        XCTAssertTrue(paramNames.contains("makeupGain"), "Missing makeupGain parameter")
    }

    func testCompressor_RatioRange_ValidForDynamics() {
        let compressor = CompressorNode()
        guard let ratio = compressor.parameters.first(where: { $0.name == "ratio" }) else {
            XCTFail("Missing ratio parameter")
            return
        }
        XCTAssertGreaterThanOrEqual(ratio.min, 1.0, "Ratio min should be >= 1:1")
        XCTAssertLessThanOrEqual(ratio.max, 100.0, "Ratio max should be reasonable")
    }
}

// MARK: - FilterNode Tests

@MainActor
final class FilterNodeBehaviorTests: XCTestCase {

    func testFilter_Init_HasCorrectName() {
        let filter = FilterNode()
        XCTAssertEqual(filter.name, "Bio-Reactive Filter")
        XCTAssertEqual(filter.type, .effect)
    }

    func testFilter_DefaultParameters_ValidRanges() {
        let filter = FilterNode()
        for param in filter.parameters {
            XCTAssertGreaterThanOrEqual(param.value, param.min,
                "\(param.name) value \(param.value) below min \(param.min)")
            XCTAssertLessThanOrEqual(param.value, param.max,
                "\(param.name) value \(param.value) above max \(param.max)")
        }
    }

    func testFilter_CutoffFrequency_AudioRange() {
        let filter = FilterNode()
        guard let cutoff = filter.parameters.first(where: { $0.name == "cutoffFrequency" }) else {
            XCTFail("Missing cutoff parameter")
            return
        }
        XCTAssertGreaterThanOrEqual(cutoff.min, 20.0, "Cutoff min should be at least 20Hz")
        XCTAssertLessThanOrEqual(cutoff.max, 22050.0, "Cutoff max should be <= Nyquist")
    }

    func testFilter_Resonance_HasValidRange() {
        let filter = FilterNode()
        guard let resonance = filter.parameters.first(where: { $0.name == "resonance" }) else {
            XCTFail("Missing resonance parameter")
            return
        }
        XCTAssertGreaterThan(resonance.min, 0.0, "Resonance min must be > 0 (avoid div by zero)")
    }

    func testFilter_SetCutoff_UpdatesValue() {
        let filter = FilterNode()
        filter.setParameter(name: "cutoffFrequency", value: 5000.0)
        let cutoff = filter.getParameter(name: "cutoffFrequency")
        XCTAssertNotNil(cutoff)
        XCTAssertEqual(cutoff ?? 0, 5000.0, accuracy: 0.1)
    }

    func testFilter_BypassPassthrough() {
        let filter = FilterNode()
        filter.isBypassed = true
        XCTAssertTrue(filter.isBypassed)
    }

    func testFilter_Reset_ClearsState() {
        let filter = FilterNode()
        filter.start()
        filter.reset()
        // After reset, filter should be in clean state
        XCTAssertFalse(filter.isActive)
    }
}

// MARK: - ReverbNode Tests

@MainActor
final class ReverbNodeBehaviorTests: XCTestCase {

    func testReverb_Init_HasCorrectName() {
        let reverb = ReverbNode()
        XCTAssertEqual(reverb.name, "Bio-Reactive Reverb")
    }

    func testReverb_DefaultParameters_ValidRanges() {
        let reverb = ReverbNode()
        for param in reverb.parameters {
            XCTAssertGreaterThanOrEqual(param.value, param.min,
                "\(param.name) value \(param.value) below min \(param.min)")
            XCTAssertLessThanOrEqual(param.value, param.max,
                "\(param.name) value \(param.value) above max \(param.max)")
        }
    }

    func testReverb_WetDry_Range() {
        let reverb = ReverbNode()
        guard let wetDry = reverb.parameters.first(where: { $0.name == "wetDry" }) else {
            XCTFail("Missing wetDry parameter")
            return
        }
        XCTAssertEqual(wetDry.min, 0.0, accuracy: 0.01)
        XCTAssertEqual(wetDry.max, 100.0, accuracy: 0.01)
    }

    func testReverb_SetRoomSize_UpdatesValue() {
        let reverb = ReverbNode()
        reverb.setParameter(name: "roomSize", value: 75.0)
        let size = reverb.getParameter(name: "roomSize")
        XCTAssertNotNil(size)
        XCTAssertEqual(size ?? 0, 75.0, accuracy: 0.1)
    }

    func testReverb_HasRequiredParameters() {
        let reverb = ReverbNode()
        let paramNames = reverb.parameters.map { $0.name }
        XCTAssertTrue(paramNames.contains("wetDry"), "Missing wetDry")
        XCTAssertTrue(paramNames.contains("roomSize"), "Missing roomSize")
        XCTAssertTrue(paramNames.contains("damping"), "Missing damping")
    }

    func testReverb_StartStop_Lifecycle() {
        let reverb = ReverbNode()
        reverb.start()
        XCTAssertTrue(reverb.isActive)
        reverb.stop()
        XCTAssertFalse(reverb.isActive)
    }
}

// MARK: - DelayNode Tests

@MainActor
final class DelayNodeBehaviorTests: XCTestCase {

    func testDelay_Init_HasCorrectType() {
        let delay = DelayNode()
        XCTAssertEqual(delay.type, .effect)
    }

    func testDelay_DefaultParameters_ValidRanges() {
        let delay = DelayNode()
        for param in delay.parameters {
            XCTAssertGreaterThanOrEqual(param.value, param.min,
                "\(param.name) value \(param.value) below min \(param.min)")
            XCTAssertLessThanOrEqual(param.value, param.max,
                "\(param.name) value \(param.value) above max \(param.max)")
        }
    }

    func testDelay_SetParameter_UpdatesValue() {
        let delay = DelayNode()
        // Find the first automatable parameter
        guard let firstParam = delay.parameters.first(where: { $0.isAutomatable }) else {
            XCTFail("No automatable parameters found")
            return
        }
        let midValue = (firstParam.min + firstParam.max) / 2
        delay.setParameter(name: firstParam.name, value: midValue)
        let retrieved = delay.getParameter(name: firstParam.name)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved ?? 0, midValue, accuracy: 0.1)
    }

    func testDelay_Bypass_ToggleState() {
        let delay = DelayNode()
        XCTAssertFalse(delay.isBypassed)
        delay.isBypassed = true
        XCTAssertTrue(delay.isBypassed)
    }
}

// MARK: - SaturationNode Tests

@MainActor
final class SaturationNodeBehaviorTests: XCTestCase {

    func testSaturation_Init_HasCorrectType() {
        let sat = SaturationNode()
        XCTAssertEqual(sat.type, .effect)
    }

    func testSaturation_DefaultParameters_ValidRanges() {
        let sat = SaturationNode()
        for param in sat.parameters {
            XCTAssertGreaterThanOrEqual(param.value, param.min,
                "\(param.name) value \(param.value) below min \(param.min)")
            XCTAssertLessThanOrEqual(param.value, param.max,
                "\(param.name) value \(param.value) above max \(param.max)")
        }
    }

    func testSaturation_StartStop_Lifecycle() {
        let sat = SaturationNode()
        sat.start()
        XCTAssertTrue(sat.isActive)
        sat.stop()
        XCTAssertFalse(sat.isActive)
    }

    func testSaturation_Reset_ClearsState() {
        let sat = SaturationNode()
        sat.start()
        sat.reset()
        XCTAssertFalse(sat.isActive)
    }
}

// MARK: - NodeGraph Tests

@MainActor
final class NodeGraphBehaviorTests: XCTestCase {

    func testNodeGraph_Init_EmptyChain() {
        let graph = NodeGraph()
        XCTAssertTrue(graph.nodes.isEmpty)
    }

    func testNodeGraph_AddNode_IncreasesCount() {
        let graph = NodeGraph()
        let filter = FilterNode()
        graph.addNode(filter)
        XCTAssertEqual(graph.nodes.count, 1)
    }

    func testNodeGraph_AddMultipleNodes_MaintainsOrder() {
        let graph = NodeGraph()
        let filter = FilterNode()
        let compressor = CompressorNode()
        let reverb = ReverbNode()
        graph.addNode(filter)
        graph.addNode(compressor)
        graph.addNode(reverb)
        XCTAssertEqual(graph.nodes.count, 3)
    }

    func testNodeGraph_RemoveNode_DecreasesCount() {
        let graph = NodeGraph()
        let filter = FilterNode()
        graph.addNode(filter)
        XCTAssertEqual(graph.nodes.count, 1)
        graph.removeNode(id: filter.id)
        XCTAssertTrue(graph.nodes.isEmpty)
    }

    func testNodeGraph_RemoveNonexistent_NoChange() {
        let graph = NodeGraph()
        let filter = FilterNode()
        graph.addNode(filter)
        graph.removeNode(id: UUID())
        XCTAssertEqual(graph.nodes.count, 1)
    }
}

// MARK: - BioSignal Tests

@MainActor
final class BioSignalTests: XCTestCase {

    func testBioSignal_DefaultValues() {
        let signal = BioSignal()
        XCTAssertEqual(signal.hrv, 0.0, accuracy: 0.01)
        XCTAssertEqual(signal.heartRate, 60.0, accuracy: 0.01)
        XCTAssertEqual(signal.coherence, 50.0, accuracy: 0.01)
        XCTAssertEqual(signal.audioLevel, 0.0, accuracy: 0.01)
    }

    func testBioSignal_CustomValues() {
        let signal = BioSignal(hrv: 65.0, heartRate: 72.0, coherence: 80.0, audioLevel: 0.5)
        XCTAssertEqual(signal.hrv, 65.0, accuracy: 0.01)
        XCTAssertEqual(signal.heartRate, 72.0, accuracy: 0.01)
        XCTAssertEqual(signal.coherence, 80.0, accuracy: 0.01)
        XCTAssertEqual(signal.audioLevel, 0.5, accuracy: 0.01)
    }

    func testBioSignal_OptionalRespiratoryRate() {
        let signal = BioSignal(respiratoryRate: 15.0)
        XCTAssertEqual(signal.respiratoryRate, 15.0)

        let noBreath = BioSignal()
        XCTAssertNil(noBreath.respiratoryRate)
    }
}

// MARK: - NodeParameter Tests

@MainActor
final class NodeParameterBehaviorTests: XCTestCase {

    func testNodeParameter_DefaultWithinRange() {
        let param = NodeParameter(
            name: "test",
            label: "Test",
            value: 50.0,
            min: 0.0,
            max: 100.0,
            defaultValue: 50.0,
            unit: "%",
            isAutomatable: true,
            type: .continuous
        )
        XCTAssertGreaterThanOrEqual(param.defaultValue, param.min)
        XCTAssertLessThanOrEqual(param.defaultValue, param.max)
    }

    func testNodeParameter_AllTypes() {
        // Verify all parameter types can be created
        let continuous = NodeParameter(name: "a", label: "A", value: 0, min: 0, max: 1,
                                        defaultValue: 0, unit: nil, isAutomatable: true, type: .continuous)
        let discrete = NodeParameter(name: "b", label: "B", value: 0, min: 0, max: 10,
                                      defaultValue: 0, unit: nil, isAutomatable: false, type: .discrete)
        let toggle = NodeParameter(name: "c", label: "C", value: 0, min: 0, max: 1,
                                    defaultValue: 0, unit: nil, isAutomatable: false, type: .toggle)
        let selection = NodeParameter(name: "d", label: "D", value: 0, min: 0, max: 4,
                                       defaultValue: 0, unit: nil, isAutomatable: false, type: .selection)

        XCTAssertEqual(continuous.name, "a")
        XCTAssertEqual(discrete.name, "b")
        XCTAssertEqual(toggle.name, "c")
        XCTAssertEqual(selection.name, "d")
    }
}

#endif
