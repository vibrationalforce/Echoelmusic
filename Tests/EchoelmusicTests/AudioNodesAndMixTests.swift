#if canImport(AVFoundation)
// AudioNodesAndMixTests.swift
// Echoelmusic — Comprehensive tests for Audio Nodes, ProMixEngine, and ProSessionEngine types
//
// Tests all value types, enums, structs, and data models from:
//   - Audio/Nodes/EchoelmusicNode.swift (NodeType, BioSignal, NodeParameter, NodeManifest)
//   - Audio/Nodes/NodeGraph.swift (NodeConnection, NodeGraphPreset)
//   - Audio/ProMixEngine.swift (ChannelColor, ChannelType, InputSource, ProEffectType, etc.)
//   - Audio/ProSessionEngine.swift (MIDINoteEvent, PatternStep, ClipType, etc.)

import XCTest
@testable import Echoelmusic
import Foundation

// MARK: - NodeType Tests

final class NodeTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(NodeType.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(NodeType.generator.rawValue, "generator")
        XCTAssertEqual(NodeType.effect.rawValue, "effect")
        XCTAssertEqual(NodeType.analyzer.rawValue, "analyzer")
        XCTAssertEqual(NodeType.mixer.rawValue, "mixer")
        XCTAssertEqual(NodeType.utility.rawValue, "utility")
        XCTAssertEqual(NodeType.output.rawValue, "output")
        XCTAssertEqual(NodeType.input.rawValue, "input")
        XCTAssertEqual(NodeType.reverb.rawValue, "reverb")
        XCTAssertEqual(NodeType.delay.rawValue, "delay")
        XCTAssertEqual(NodeType.filter.rawValue, "filter")
    }

    func testCodableRoundTrip() throws {
        for nodeType in NodeType.allCases {
            let data = try JSONEncoder().encode(nodeType)
            let decoded = try JSONDecoder().decode(NodeType.self, from: data)
            XCTAssertEqual(decoded, nodeType)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(NodeType(rawValue: "nonexistent"))
    }
}

// MARK: - BioSignal Tests

final class BioSignalTests: XCTestCase {

    func testDefaultInit() {
        let signal = BioSignal()
        XCTAssertEqual(signal.hrv, 0)
        XCTAssertEqual(signal.heartRate, 60)
        XCTAssertEqual(signal.coherence, 50)
        XCTAssertNil(signal.respiratoryRate)
        XCTAssertEqual(signal.audioLevel, 0)
        XCTAssertEqual(signal.voicePitch, 0)
        XCTAssertTrue(signal.customData.isEmpty)
    }

    func testCustomInit() {
        let signal = BioSignal(
            hrv: 42.5,
            heartRate: 72,
            coherence: 85.3,
            respiratoryRate: 16.0,
            audioLevel: 0.75,
            voicePitch: 220.0,
            customData: ["key": "value"]
        )
        XCTAssertEqual(signal.hrv, 42.5)
        XCTAssertEqual(signal.heartRate, 72)
        XCTAssertEqual(signal.coherence, 85.3)
        XCTAssertEqual(signal.respiratoryRate, 16.0)
        XCTAssertEqual(signal.audioLevel, 0.75)
        XCTAssertEqual(signal.voicePitch, 220.0)
        XCTAssertEqual(signal.customData["key"] as? String, "value")
    }

    func testPartialInit() {
        let signal = BioSignal(hrv: 50, heartRate: 80)
        XCTAssertEqual(signal.hrv, 50)
        XCTAssertEqual(signal.heartRate, 80)
        XCTAssertEqual(signal.coherence, 50)
        XCTAssertNil(signal.respiratoryRate)
    }

    func testMutableProperties() {
        var signal = BioSignal()
        signal.hrv = 100
        signal.heartRate = 120
        signal.audioLevel = 0.5
        XCTAssertEqual(signal.hrv, 100)
        XCTAssertEqual(signal.heartRate, 120)
        XCTAssertEqual(signal.audioLevel, 0.5)
    }
}

// MARK: - NodeParameter Tests

final class NodeParameterTests: XCTestCase {

    func testInit() {
        let param = NodeParameter(
            name: "cutoff",
            label: "Cutoff Frequency",
            value: 1000,
            min: 20,
            max: 20000,
            defaultValue: 1000,
            unit: "Hz",
            isAutomatable: true,
            type: .continuous
        )
        XCTAssertEqual(param.name, "cutoff")
        XCTAssertEqual(param.label, "Cutoff Frequency")
        XCTAssertEqual(param.value, 1000)
        XCTAssertEqual(param.min, 20)
        XCTAssertEqual(param.max, 20000)
        XCTAssertEqual(param.defaultValue, 1000)
        XCTAssertEqual(param.unit, "Hz")
        XCTAssertTrue(param.isAutomatable)
        XCTAssertNotNil(param.id)
    }

    func testParameterTypeDiscrete() {
        let param = NodeParameter(
            name: "steps",
            label: "Steps",
            value: 4,
            min: 1,
            max: 16,
            defaultValue: 8,
            unit: nil,
            isAutomatable: false,
            type: .discrete
        )
        XCTAssertNil(param.unit)
        XCTAssertFalse(param.isAutomatable)
    }

    func testParameterTypeToggle() {
        let param = NodeParameter(
            name: "bypass",
            label: "Bypass",
            value: 0,
            min: 0,
            max: 1,
            defaultValue: 0,
            unit: nil,
            isAutomatable: true,
            type: .toggle
        )
        XCTAssertEqual(param.value, 0)
    }

    func testParameterTypeSelection() {
        let param = NodeParameter(
            name: "mode",
            label: "Mode",
            value: 2,
            min: 0,
            max: 3,
            defaultValue: 0,
            unit: nil,
            isAutomatable: false,
            type: .selection
        )
        XCTAssertEqual(param.value, 2)
    }

    func testIdentifiable() {
        let p1 = NodeParameter(name: "a", label: "A", value: 0, min: 0, max: 1, defaultValue: 0, unit: nil, isAutomatable: false, type: .continuous)
        let p2 = NodeParameter(name: "b", label: "B", value: 0, min: 0, max: 1, defaultValue: 0, unit: nil, isAutomatable: false, type: .continuous)
        XCTAssertNotEqual(p1.id, p2.id)
    }
}

// MARK: - NodeManifest Tests

final class NodeManifestTests: XCTestCase {

    func testInit() {
        let manifest = NodeManifest(
            id: "test-id",
            type: .effect,
            className: "CompressorNode",
            version: "1.0",
            parameters: ["threshold": -20, "ratio": 4],
            isBypassed: false,
            metadata: ["author": "Echoel"]
        )
        XCTAssertEqual(manifest.id, "test-id")
        XCTAssertEqual(manifest.type, .effect)
        XCTAssertEqual(manifest.className, "CompressorNode")
        XCTAssertEqual(manifest.version, "1.0")
        XCTAssertEqual(manifest.parameters["threshold"], -20)
        XCTAssertEqual(manifest.parameters["ratio"], 4)
        XCTAssertFalse(manifest.isBypassed)
        XCTAssertEqual(manifest.metadata?["author"], "Echoel")
    }

    func testCodableRoundTrip() throws {
        let manifest = NodeManifest(
            id: "node-1",
            type: .generator,
            className: "OscillatorNode",
            version: "2.0",
            parameters: ["freq": 440, "amp": 0.5],
            isBypassed: true,
            metadata: nil
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(NodeManifest.self, from: data)
        XCTAssertEqual(decoded.id, manifest.id)
        XCTAssertEqual(decoded.type, manifest.type)
        XCTAssertEqual(decoded.className, manifest.className)
        XCTAssertEqual(decoded.version, manifest.version)
        XCTAssertEqual(decoded.parameters, manifest.parameters)
        XCTAssertEqual(decoded.isBypassed, manifest.isBypassed)
        XCTAssertNil(decoded.metadata)
    }

    func testNilMetadata() {
        let manifest = NodeManifest(
            id: "x",
            type: .utility,
            className: "GainNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        XCTAssertNil(manifest.metadata)
    }

    func testEmptyParameters() {
        let manifest = NodeManifest(
            id: "y",
            type: .output,
            className: "OutputNode",
            version: "1.0",
            parameters: [:],
            isBypassed: false,
            metadata: nil
        )
        XCTAssertTrue(manifest.parameters.isEmpty)
    }
}

// MARK: - ChannelColor Tests

final class ChannelColorTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ChannelColor.allCases.count, 14)
    }

    func testRawValues() {
        XCTAssertEqual(ChannelColor.red.rawValue, "red")
        XCTAssertEqual(ChannelColor.orange.rawValue, "orange")
        XCTAssertEqual(ChannelColor.yellow.rawValue, "yellow")
        XCTAssertEqual(ChannelColor.green.rawValue, "green")
        XCTAssertEqual(ChannelColor.cyan.rawValue, "cyan")
        XCTAssertEqual(ChannelColor.blue.rawValue, "blue")
        XCTAssertEqual(ChannelColor.purple.rawValue, "purple")
        XCTAssertEqual(ChannelColor.pink.rawValue, "pink")
        XCTAssertEqual(ChannelColor.coral.rawValue, "coral")
        XCTAssertEqual(ChannelColor.teal.rawValue, "teal")
        XCTAssertEqual(ChannelColor.indigo.rawValue, "indigo")
        XCTAssertEqual(ChannelColor.magenta.rawValue, "magenta")
        XCTAssertEqual(ChannelColor.slate.rawValue, "slate")
        XCTAssertEqual(ChannelColor.cream.rawValue, "cream")
    }

    func testCodableRoundTrip() throws {
        for color in ChannelColor.allCases {
            let data = try JSONEncoder().encode(color)
            let decoded = try JSONDecoder().decode(ChannelColor.self, from: data)
            XCTAssertEqual(decoded, color)
        }
    }

    func testInvalidRawValue() {
        XCTAssertNil(ChannelColor(rawValue: "rainbow"))
    }
}

// MARK: - ChannelType Tests

final class ChannelTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ChannelType.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(ChannelType.audio.rawValue, "audio")
        XCTAssertEqual(ChannelType.instrument.rawValue, "instrument")
        XCTAssertEqual(ChannelType.aux.rawValue, "aux")
        XCTAssertEqual(ChannelType.bus.rawValue, "bus")
        XCTAssertEqual(ChannelType.master.rawValue, "master")
        XCTAssertEqual(ChannelType.send.rawValue, "send")
    }

    func testCodableRoundTrip() throws {
        for ct in ChannelType.allCases {
            let data = try JSONEncoder().encode(ct)
            let decoded = try JSONDecoder().decode(ChannelType.self, from: data)
            XCTAssertEqual(decoded, ct)
        }
    }
}

// MARK: - InputSource Tests

final class InputSourceTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(InputSource.none.rawValue, "none")
        XCTAssertEqual(InputSource.mic.rawValue, "mic")
        XCTAssertEqual(InputSource.lineIn.rawValue, "lineIn")
        XCTAssertEqual(InputSource.bus.rawValue, "bus")
        XCTAssertEqual(InputSource.sidechain.rawValue, "sidechain")
    }

    func testCodableRoundTrip() throws {
        let sources: [InputSource] = [.none, .mic, .lineIn, .bus, .sidechain]
        for source in sources {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(InputSource.self, from: data)
            XCTAssertEqual(decoded, source)
        }
    }
}

// MARK: - ProEffectType Tests

final class ProEffectTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertGreaterThanOrEqual(ProEffectType.allCases.count, 30)
    }

    func testEQTypes() {
        XCTAssertEqual(ProEffectType.parametricEQ.rawValue, "parametricEQ")
        XCTAssertEqual(ProEffectType.graphicEQ.rawValue, "graphicEQ")
        XCTAssertEqual(ProEffectType.midSideEQ.rawValue, "midSideEQ")
        XCTAssertEqual(ProEffectType.dynamicEQ.rawValue, "dynamicEQ")
    }

    func testDynamicsTypes() {
        XCTAssertEqual(ProEffectType.compressor.rawValue, "compressor")
        XCTAssertEqual(ProEffectType.limiter.rawValue, "limiter")
        XCTAssertEqual(ProEffectType.gate.rawValue, "gate")
        XCTAssertEqual(ProEffectType.deEsser.rawValue, "deEsser")
        XCTAssertEqual(ProEffectType.transientShaper.rawValue, "transientShaper")
    }

    func testReverbTypes() {
        XCTAssertEqual(ProEffectType.convolutionReverb.rawValue, "convolutionReverb")
        XCTAssertEqual(ProEffectType.algorithmicReverb.rawValue, "algorithmicReverb")
        XCTAssertEqual(ProEffectType.plateReverb.rawValue, "plateReverb")
        XCTAssertEqual(ProEffectType.springReverb.rawValue, "springReverb")
        XCTAssertEqual(ProEffectType.shimmerReverb.rawValue, "shimmerReverb")
    }

    func testDelayTypes() {
        XCTAssertEqual(ProEffectType.stereoDelay.rawValue, "stereoDelay")
        XCTAssertEqual(ProEffectType.pingPongDelay.rawValue, "pingPongDelay")
        XCTAssertEqual(ProEffectType.tapeDelay.rawValue, "tapeDelay")
        XCTAssertEqual(ProEffectType.analogDelay.rawValue, "analogDelay")
    }

    func testModulationTypes() {
        XCTAssertEqual(ProEffectType.chorus.rawValue, "chorus")
        XCTAssertEqual(ProEffectType.flanger.rawValue, "flanger")
        XCTAssertEqual(ProEffectType.phaser.rawValue, "phaser")
        XCTAssertEqual(ProEffectType.tremolo.rawValue, "tremolo")
        XCTAssertEqual(ProEffectType.rotarySpeaker.rawValue, "rotarySpeaker")
    }

    func testCodableRoundTrip() throws {
        for effect in ProEffectType.allCases {
            let data = try JSONEncoder().encode(effect)
            let decoded = try JSONDecoder().decode(ProEffectType.self, from: data)
            XCTAssertEqual(decoded, effect)
        }
    }
}

// MARK: - AutomationCurveType Tests

final class AutomationCurveTypeTests: XCTestCase {

    func testAllCases() {
        let cases: [AutomationCurveType] = [.linear, .exponential, .sCurve, .hold]
        XCTAssertEqual(cases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(AutomationCurveType.linear.rawValue, "linear")
        XCTAssertEqual(AutomationCurveType.exponential.rawValue, "exponential")
        XCTAssertEqual(AutomationCurveType.sCurve.rawValue, "sCurve")
        XCTAssertEqual(AutomationCurveType.hold.rawValue, "hold")
    }

    func testCodableRoundTrip() throws {
        let curves: [AutomationCurveType] = [.linear, .exponential, .sCurve, .hold]
        for curve in curves {
            let data = try JSONEncoder().encode(curve)
            let decoded = try JSONDecoder().decode(AutomationCurveType.self, from: data)
            XCTAssertEqual(decoded, curve)
        }
    }
}

// MARK: - AutomationParameter Tests

final class AutomationParameterTests: XCTestCase {

    func testBasicCases() {
        let params: [AutomationParameter] = [.volume, .pan, .mute, .sendLevel, .insertParam]
        XCTAssertEqual(params.count, 5)
    }

    func testEQBands() {
        let bands: [AutomationParameter] = [.eqBand1, .eqBand2, .eqBand3, .eqBand4, .eqBand5, .eqBand6, .eqBand7, .eqBand8]
        XCTAssertEqual(bands.count, 8)
    }

    func testCustomCase() {
        let custom = AutomationParameter.custom("myParam")
        if case .custom(let name) = custom {
            XCTAssertEqual(name, "myParam")
        } else {
            XCTFail("Expected custom case")
        }
    }

    func testCodableRoundTrip() throws {
        let params: [AutomationParameter] = [.volume, .pan, .reverbMix, .custom("test")]
        for param in params {
            let data = try JSONEncoder().encode(param)
            let decoded = try JSONDecoder().decode(AutomationParameter.self, from: data)
            XCTAssertEqual(decoded, param)
        }
    }

    func testHashable() {
        var set = Set<AutomationParameter>()
        set.insert(.volume)
        set.insert(.pan)
        set.insert(.volume)
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - MeterState Tests

final class MeterStateTests: XCTestCase {

    func testDefaultInit() {
        let meter = MeterState()
        XCTAssertEqual(meter.peak, 0)
        XCTAssertEqual(meter.rms, 0)
        XCTAssertEqual(meter.peakHold, 0)
        XCTAssertFalse(meter.isClipping)
        XCTAssertEqual(meter.phaseCorrelation, 1.0)
    }

    func testCustomInit() {
        let meter = MeterState(peak: 0.9, rms: 0.7, peakHold: 0.95, isClipping: true, phaseCorrelation: -0.5)
        XCTAssertEqual(meter.peak, 0.9)
        XCTAssertEqual(meter.rms, 0.7)
        XCTAssertEqual(meter.peakHold, 0.95)
        XCTAssertTrue(meter.isClipping)
        XCTAssertEqual(meter.phaseCorrelation, -0.5)
    }

    func testCodableRoundTrip() throws {
        let meter = MeterState(peak: 0.5, rms: 0.3, peakHold: 0.6, isClipping: false, phaseCorrelation: 0.9)
        let data = try JSONEncoder().encode(meter)
        let decoded = try JSONDecoder().decode(MeterState.self, from: data)
        XCTAssertEqual(decoded.peak, meter.peak)
        XCTAssertEqual(decoded.rms, meter.rms)
        XCTAssertEqual(decoded.peakHold, meter.peakHold)
        XCTAssertEqual(decoded.isClipping, meter.isClipping)
        XCTAssertEqual(decoded.phaseCorrelation, meter.phaseCorrelation)
    }

    func testMutableProperties() {
        var meter = MeterState()
        meter.peak = 0.8
        meter.rms = 0.6
        meter.isClipping = true
        XCTAssertEqual(meter.peak, 0.8)
        XCTAssertEqual(meter.rms, 0.6)
        XCTAssertTrue(meter.isClipping)
    }
}

// MARK: - InsertSlot Tests

final class InsertSlotTests: XCTestCase {

    func testDefaultInit() {
        let slot = InsertSlot(effectType: .compressor)
        XCTAssertEqual(slot.effectType, .compressor)
        XCTAssertTrue(slot.isEnabled)
        XCTAssertEqual(slot.dryWet, 1.0)
        XCTAssertTrue(slot.parameters.isEmpty)
        XCTAssertNotNil(slot.id)
    }

    func testCustomInit() {
        let slot = InsertSlot(
            effectType: .plateReverb,
            isEnabled: false,
            dryWet: 0.5,
            parameters: ["decay": 2.5, "mix": 0.3]
        )
        XCTAssertEqual(slot.effectType, .plateReverb)
        XCTAssertFalse(slot.isEnabled)
        XCTAssertEqual(slot.dryWet, 0.5)
        XCTAssertEqual(slot.parameters["decay"], 2.5)
    }

    func testDryWetClamping() {
        let slotHigh = InsertSlot(effectType: .compressor, dryWet: 5.0)
        XCTAssertEqual(slotHigh.dryWet, 1.0)

        let slotLow = InsertSlot(effectType: .compressor, dryWet: -2.0)
        XCTAssertEqual(slotLow.dryWet, 0.0)
    }

    func testCodableRoundTrip() throws {
        let slot = InsertSlot(effectType: .chorus, isEnabled: true, dryWet: 0.7, parameters: ["rate": 1.5])
        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(InsertSlot.self, from: data)
        XCTAssertEqual(decoded.effectType, slot.effectType)
        XCTAssertEqual(decoded.isEnabled, slot.isEnabled)
        XCTAssertEqual(decoded.dryWet, slot.dryWet, accuracy: 0.001)
    }
}

// MARK: - SendSlot Tests

final class SendSlotTests: XCTestCase {

    func testDefaultInit() {
        let slot = SendSlot()
        XCTAssertNil(slot.destinationID)
        XCTAssertEqual(slot.level, 0.0)
        XCTAssertFalse(slot.isPreFader)
        XCTAssertTrue(slot.isEnabled)
    }

    func testCustomInit() {
        let destID = UUID()
        let slot = SendSlot(destinationID: destID, level: 0.75, isPreFader: true, isEnabled: false)
        XCTAssertEqual(slot.destinationID, destID)
        XCTAssertEqual(slot.level, 0.75)
        XCTAssertTrue(slot.isPreFader)
        XCTAssertFalse(slot.isEnabled)
    }

    func testLevelClamping() {
        let slotHigh = SendSlot(level: 2.0)
        XCTAssertEqual(slotHigh.level, 1.0)

        let slotLow = SendSlot(level: -1.0)
        XCTAssertEqual(slotLow.level, 0.0)
    }
}

// MARK: - ChannelStrip Tests

final class ChannelStripTests: XCTestCase {

    func testDefaultInit() {
        let strip = ChannelStrip(name: "Vocal", type: .audio)
        XCTAssertEqual(strip.name, "Vocal")
        XCTAssertEqual(strip.type, .audio)
        XCTAssertEqual(strip.volume, 0.8)
        XCTAssertEqual(strip.pan, 0.0)
        XCTAssertFalse(strip.mute)
        XCTAssertFalse(strip.solo)
        XCTAssertFalse(strip.isArmed)
        XCTAssertFalse(strip.phaseInvert)
        XCTAssertTrue(strip.inserts.isEmpty)
        XCTAssertTrue(strip.sends.isEmpty)
        XCTAssertEqual(strip.inputSource, .none)
        XCTAssertNil(strip.outputDestination)
        XCTAssertEqual(strip.color, .blue)
    }

    func testCustomInit() {
        let strip = ChannelStrip(
            name: "Bass",
            type: .instrument,
            volume: 0.6,
            pan: -0.5,
            mute: true,
            solo: false,
            isArmed: true,
            phaseInvert: true,
            inputSource: .mic,
            color: .green
        )
        XCTAssertEqual(strip.name, "Bass")
        XCTAssertEqual(strip.type, .instrument)
        XCTAssertEqual(strip.volume, 0.6)
        XCTAssertEqual(strip.pan, -0.5)
        XCTAssertTrue(strip.mute)
        XCTAssertTrue(strip.isArmed)
        XCTAssertTrue(strip.phaseInvert)
        XCTAssertEqual(strip.inputSource, .mic)
        XCTAssertEqual(strip.color, .green)
    }

    func testMaxConstants() {
        XCTAssertEqual(ChannelStrip.maxInserts, 8)
        XCTAssertEqual(ChannelStrip.maxSends, 8)
    }

    func testVolumeClamping() {
        let strip = ChannelStrip(name: "Test", type: .audio, volume: 5.0)
        XCTAssertEqual(strip.volume, 1.0)

        let stripLow = ChannelStrip(name: "Test", type: .audio, volume: -1.0)
        XCTAssertEqual(stripLow.volume, 0.0)
    }

    func testPanClamping() {
        let strip = ChannelStrip(name: "Test", type: .audio, pan: 5.0)
        XCTAssertEqual(strip.pan, 1.0)

        let stripLow = ChannelStrip(name: "Test", type: .audio, pan: -5.0)
        XCTAssertEqual(stripLow.pan, -1.0)
    }

    func testCodableRoundTrip() throws {
        let strip = ChannelStrip(name: "Guitar", type: .audio, volume: 0.7, pan: 0.3, color: .orange)
        let data = try JSONEncoder().encode(strip)
        let decoded = try JSONDecoder().decode(ChannelStrip.self, from: data)
        XCTAssertEqual(decoded.name, strip.name)
        XCTAssertEqual(decoded.type, strip.type)
        XCTAssertEqual(decoded.volume, strip.volume, accuracy: 0.001)
        XCTAssertEqual(decoded.pan, strip.pan, accuracy: 0.001)
        XCTAssertEqual(decoded.color, strip.color)
    }
}

// MARK: - AutomationPoint Tests

final class AutomationPointTests: XCTestCase {

    func testInit() {
        let point = AutomationPoint(time: 1.5, value: 0.8)
        XCTAssertEqual(point.time, 1.5)
        XCTAssertEqual(point.value, 0.8)
        XCTAssertEqual(point.curveType, .linear)
    }

    func testCustomCurveType() {
        let point = AutomationPoint(time: 2.0, value: 0.5, curveType: .exponential)
        XCTAssertEqual(point.curveType, .exponential)
    }

    func testValueClamping() {
        let pointHigh = AutomationPoint(time: 0, value: 5.0)
        XCTAssertEqual(pointHigh.value, 1.0)

        let pointLow = AutomationPoint(time: 0, value: -2.0)
        XCTAssertEqual(pointLow.value, 0.0)
    }

    func testComparable() {
        let a = AutomationPoint(time: 1.0, value: 0.5)
        let b = AutomationPoint(time: 2.0, value: 0.8)
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)
    }

    func testSorting() {
        let points = [
            AutomationPoint(time: 3.0, value: 0.1),
            AutomationPoint(time: 1.0, value: 0.5),
            AutomationPoint(time: 2.0, value: 0.9)
        ].sorted()
        XCTAssertEqual(points[0].time, 1.0)
        XCTAssertEqual(points[1].time, 2.0)
        XCTAssertEqual(points[2].time, 3.0)
    }
}

// MARK: - AutomationLane Tests

final class AutomationLaneTests: XCTestCase {

    func testDefaultInit() {
        let channelID = UUID()
        let lane = AutomationLane(parameter: .volume, channelID: channelID)
        XCTAssertEqual(lane.parameter, .volume)
        XCTAssertEqual(lane.channelID, channelID)
        XCTAssertTrue(lane.points.isEmpty)
        XCTAssertTrue(lane.isEnabled)
        XCTAssertFalse(lane.isRecording)
    }

    func testPointsSorted() {
        let channelID = UUID()
        let points = [
            AutomationPoint(time: 3.0, value: 0.1),
            AutomationPoint(time: 1.0, value: 0.5),
            AutomationPoint(time: 2.0, value: 0.9)
        ]
        let lane = AutomationLane(parameter: .pan, channelID: channelID, points: points)
        XCTAssertEqual(lane.points[0].time, 1.0)
        XCTAssertEqual(lane.points[1].time, 2.0)
        XCTAssertEqual(lane.points[2].time, 3.0)
    }

    func testValueAtEmptyLane() {
        let lane = AutomationLane(parameter: .volume, channelID: UUID())
        XCTAssertEqual(lane.valueAt(time: 5.0), 0)
    }

    func testValueAtBeforeFirstPoint() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [AutomationPoint(time: 2.0, value: 0.8)]
        )
        XCTAssertEqual(lane.valueAt(time: 0.0), 0.8)
    }

    func testValueAtAfterLastPoint() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [AutomationPoint(time: 1.0, value: 0.3)]
        )
        XCTAssertEqual(lane.valueAt(time: 10.0), 0.3)
    }

    func testLinearInterpolation() {
        let lane = AutomationLane(
            parameter: .volume,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 0.0, value: 0.0),
                AutomationPoint(time: 1.0, value: 1.0, curveType: .linear)
            ]
        )
        XCTAssertEqual(lane.valueAt(time: 0.5), 0.5, accuracy: 0.01)
    }

    func testHoldInterpolation() {
        let lane = AutomationLane(
            parameter: .mute,
            channelID: UUID(),
            points: [
                AutomationPoint(time: 0.0, value: 0.0),
                AutomationPoint(time: 1.0, value: 1.0, curveType: .hold)
            ]
        )
        XCTAssertEqual(lane.valueAt(time: 0.5), 0.0, accuracy: 0.01)
    }
}

// MARK: - RoutingConnection Tests

final class RoutingConnectionTests: XCTestCase {

    func testInit() {
        let src = UUID()
        let dst = UUID()
        let conn = RoutingConnection(sourceID: src, destinationID: dst, level: 0.8)
        XCTAssertEqual(conn.sourceID, src)
        XCTAssertEqual(conn.destinationID, dst)
        XCTAssertEqual(conn.level, 0.8)
    }

    func testDefaultLevel() {
        let conn = RoutingConnection(sourceID: UUID(), destinationID: UUID())
        XCTAssertEqual(conn.level, 1.0)
    }

    func testLevelClamping() {
        let connHigh = RoutingConnection(sourceID: UUID(), destinationID: UUID(), level: 5.0)
        XCTAssertEqual(connHigh.level, 1.0)

        let connLow = RoutingConnection(sourceID: UUID(), destinationID: UUID(), level: -1.0)
        XCTAssertEqual(connLow.level, 0.0)
    }
}

// MARK: - RoutingMatrix Tests

final class RoutingMatrixTests: XCTestCase {

    func testDefaultInit() {
        let matrix = RoutingMatrix()
        XCTAssertTrue(matrix.connections.isEmpty)
    }

    func testAddConnection() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()
        matrix.addConnection(from: src, to: dst, level: 0.5)
        XCTAssertEqual(matrix.connections.count, 1)
        XCTAssertEqual(matrix.connections[0].sourceID, src)
        XCTAssertEqual(matrix.connections[0].destinationID, dst)
    }

    func testResolve() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst1 = UUID()
        let dst2 = UUID()
        matrix.addConnection(from: src, to: dst1)
        matrix.addConnection(from: src, to: dst2)
        let resolved = matrix.resolve(for: src)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertTrue(resolved.contains(dst1))
        XCTAssertTrue(resolved.contains(dst2))
    }

    func testResolveExcludesZeroLevel() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()
        matrix.addConnection(from: src, to: dst, level: 0.0)
        let resolved = matrix.resolve(for: src)
        XCTAssertTrue(resolved.isEmpty)
    }

    func testRemoveConnection() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()
        matrix.addConnection(from: src, to: dst)
        XCTAssertEqual(matrix.connections.count, 1)
        matrix.removeConnection(from: src, to: dst)
        XCTAssertTrue(matrix.connections.isEmpty)
    }

    func testNoDuplicateConnections() {
        var matrix = RoutingMatrix()
        let src = UUID()
        let dst = UUID()
        matrix.addConnection(from: src, to: dst, level: 0.5)
        matrix.addConnection(from: src, to: dst, level: 0.8)
        XCTAssertEqual(matrix.connections.count, 1)
        XCTAssertEqual(matrix.connections[0].level, 0.8)
    }
}

// MARK: - ChannelSnapshot Tests

final class ChannelSnapshotTests: XCTestCase {

    func testInit() {
        let channelID = UUID()
        let snap = ChannelSnapshot(
            channelID: channelID,
            volume: 0.7,
            pan: -0.3,
            mute: false,
            solo: true,
            sends: [],
            inserts: []
        )
        XCTAssertEqual(snap.channelID, channelID)
        XCTAssertEqual(snap.volume, 0.7)
        XCTAssertEqual(snap.pan, -0.3)
        XCTAssertFalse(snap.mute)
        XCTAssertTrue(snap.solo)
    }

    func testCodableRoundTrip() throws {
        let snap = ChannelSnapshot(
            channelID: UUID(),
            volume: 0.5,
            pan: 0.0,
            mute: true,
            solo: false,
            sends: [],
            inserts: []
        )
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(ChannelSnapshot.self, from: data)
        XCTAssertEqual(decoded.volume, snap.volume)
        XCTAssertEqual(decoded.mute, snap.mute)
    }
}

// MARK: - MixSnapshot Tests

final class MixSnapshotTests: XCTestCase {

    func testInit() {
        let snap = MixSnapshot(name: "Verse Mix")
        XCTAssertEqual(snap.name, "Verse Mix")
        XCTAssertTrue(snap.channelStates.isEmpty)
        XCTAssertNotNil(snap.date)
    }

    func testWithChannelStates() {
        let ch = ChannelSnapshot(channelID: UUID(), volume: 0.8, pan: 0, mute: false, solo: false, sends: [], inserts: [])
        let snap = MixSnapshot(name: "Chorus", channelStates: [ch])
        XCTAssertEqual(snap.channelStates.count, 1)
    }

    func testCodableRoundTrip() throws {
        let snap = MixSnapshot(name: "Bridge")
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(MixSnapshot.self, from: data)
        XCTAssertEqual(decoded.name, snap.name)
    }
}

// MARK: - MIDINoteEvent Tests

final class MIDINoteEventTests: XCTestCase {

    func testDefaultInit() {
        let note = MIDINoteEvent(note: 60, startBeat: 0.0)
        XCTAssertEqual(note.note, 60)
        XCTAssertEqual(note.velocity, 100)
        XCTAssertEqual(note.startBeat, 0.0)
        XCTAssertEqual(note.duration, 0.25)
        XCTAssertEqual(note.channel, 0)
    }

    func testCustomInit() {
        let note = MIDINoteEvent(note: 72, velocity: 127, startBeat: 2.0, duration: 1.0, channel: 5)
        XCTAssertEqual(note.note, 72)
        XCTAssertEqual(note.velocity, 127)
        XCTAssertEqual(note.startBeat, 2.0)
        XCTAssertEqual(note.duration, 1.0)
        XCTAssertEqual(note.channel, 5)
    }

    func testEquatable() {
        let id = UUID()
        let a = MIDINoteEvent(id: id, note: 60, startBeat: 0)
        let b = MIDINoteEvent(id: id, note: 60, startBeat: 0)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let note = MIDINoteEvent(note: 48, velocity: 80, startBeat: 1.5, duration: 0.5, channel: 3)
        let data = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(MIDINoteEvent.self, from: data)
        XCTAssertEqual(decoded.note, note.note)
        XCTAssertEqual(decoded.velocity, note.velocity)
        XCTAssertEqual(decoded.startBeat, note.startBeat)
    }
}

// MARK: - PatternStep Tests

final class PatternStepTests: XCTestCase {

    func testDefaultInit() {
        let step = PatternStep(stepIndex: 0)
        XCTAssertEqual(step.stepIndex, 0)
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 0.8)
        XCTAssertEqual(step.pan, 0.0)
        XCTAssertEqual(step.pitch, 0.0)
        XCTAssertEqual(step.gate, 0.75)
        XCTAssertEqual(step.probability, 1.0)
        XCTAssertFalse(step.slide)
    }

    func testClamping() {
        let step = PatternStep(stepIndex: 0, velocity: 5.0, pan: -10.0, pitch: 100.0, gate: -1.0, probability: 2.0)
        XCTAssertEqual(step.velocity, 1.0)
        XCTAssertEqual(step.pan, -1.0)
        XCTAssertEqual(step.pitch, 24.0)
        XCTAssertEqual(step.gate, 0.0)
        XCTAssertEqual(step.probability, 1.0)
    }

    func testEquatable() {
        let id = UUID()
        let a = PatternStep(id: id, stepIndex: 3, isActive: true)
        let b = PatternStep(id: id, stepIndex: 3, isActive: true)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let step = PatternStep(stepIndex: 5, isActive: true, velocity: 0.6, pan: 0.3)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(PatternStep.self, from: data)
        XCTAssertEqual(decoded.stepIndex, step.stepIndex)
        XCTAssertEqual(decoded.isActive, step.isActive)
    }
}

// MARK: - WarpMarker Tests

final class WarpMarkerTests: XCTestCase {

    func testInit() {
        let marker = WarpMarker(samplePosition: 2.5, beatPosition: 4.0)
        XCTAssertEqual(marker.samplePosition, 2.5)
        XCTAssertEqual(marker.beatPosition, 4.0)
    }

    func testEquatable() {
        let id = UUID()
        let a = WarpMarker(id: id, samplePosition: 1.0, beatPosition: 2.0)
        let b = WarpMarker(id: id, samplePosition: 1.0, beatPosition: 2.0)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let marker = WarpMarker(samplePosition: 3.0, beatPosition: 6.0)
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(WarpMarker.self, from: data)
        XCTAssertEqual(decoded.samplePosition, marker.samplePosition)
        XCTAssertEqual(decoded.beatPosition, marker.beatPosition)
    }
}

// MARK: - ClipType Tests

final class ClipTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ClipType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(ClipType.audio.rawValue, "audio")
        XCTAssertEqual(ClipType.midi.rawValue, "midi")
        XCTAssertEqual(ClipType.pattern.rawValue, "pattern")
        XCTAssertEqual(ClipType.automation.rawValue, "automation")
        XCTAssertEqual(ClipType.video.rawValue, "video")
    }

    func testCodableRoundTrip() throws {
        for ct in ClipType.allCases {
            let data = try JSONEncoder().encode(ct)
            let decoded = try JSONDecoder().decode(ClipType.self, from: data)
            XCTAssertEqual(decoded, ct)
        }
    }
}

// MARK: - ClipState Tests

final class ClipStateTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ClipState.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(ClipState.empty.rawValue, "empty")
        XCTAssertEqual(ClipState.stopped.rawValue, "stopped")
        XCTAssertEqual(ClipState.queued.rawValue, "queued")
        XCTAssertEqual(ClipState.playing.rawValue, "playing")
        XCTAssertEqual(ClipState.recording.rawValue, "recording")
    }
}

// MARK: - ClipColor Tests

final class ClipColorTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ClipColor.allCases.count, 16)
    }

    func testRawValues() {
        XCTAssertEqual(ClipColor.rose.rawValue, 0)
        XCTAssertEqual(ClipColor.red.rawValue, 1)
        XCTAssertEqual(ClipColor.orange.rawValue, 2)
        XCTAssertEqual(ClipColor.amber.rawValue, 3)
        XCTAssertEqual(ClipColor.yellow.rawValue, 4)
        XCTAssertEqual(ClipColor.lime.rawValue, 5)
        XCTAssertEqual(ClipColor.green.rawValue, 6)
        XCTAssertEqual(ClipColor.mint.rawValue, 7)
        XCTAssertEqual(ClipColor.cyan.rawValue, 8)
        XCTAssertEqual(ClipColor.sky.rawValue, 9)
        XCTAssertEqual(ClipColor.blue.rawValue, 10)
        XCTAssertEqual(ClipColor.indigo.rawValue, 11)
        XCTAssertEqual(ClipColor.purple.rawValue, 12)
        XCTAssertEqual(ClipColor.magenta.rawValue, 13)
        XCTAssertEqual(ClipColor.pink.rawValue, 14)
        XCTAssertEqual(ClipColor.sand.rawValue, 15)
    }

    func testCodableRoundTrip() throws {
        for color in ClipColor.allCases {
            let data = try JSONEncoder().encode(color)
            let decoded = try JSONDecoder().decode(ClipColor.self, from: data)
            XCTAssertEqual(decoded, color)
        }
    }
}

// MARK: - LaunchMode Tests

final class LaunchModeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LaunchMode.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(LaunchMode.trigger.rawValue, "trigger")
        XCTAssertEqual(LaunchMode.gate.rawValue, "gate")
        XCTAssertEqual(LaunchMode.toggle.rawValue, "toggle")
        XCTAssertEqual(LaunchMode.repeating.rawValue, "repeating")
    }
}

// MARK: - LaunchQuantize Tests

final class LaunchQuantizeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LaunchQuantize.allCases.count, 6)
    }

    func testBeatCounts() {
        XCTAssertEqual(LaunchQuantize.none.beatCount, 0)
        XCTAssertEqual(LaunchQuantize.nextBeat.beatCount, 1)
        XCTAssertEqual(LaunchQuantize.nextBar.beatCount, 4)
        XCTAssertEqual(LaunchQuantize.next2Bars.beatCount, 8)
        XCTAssertEqual(LaunchQuantize.next4Bars.beatCount, 16)
        XCTAssertEqual(LaunchQuantize.next8Bars.beatCount, 32)
    }

    func testBeatCountIncreasing() {
        let ordered: [LaunchQuantize] = [.none, .nextBeat, .nextBar, .next2Bars, .next4Bars, .next8Bars]
        for i in 0..<(ordered.count - 1) {
            XCTAssertLessThan(ordered[i].beatCount, ordered[i + 1].beatCount)
        }
    }

    func testCodableRoundTrip() throws {
        for q in LaunchQuantize.allCases {
            let data = try JSONEncoder().encode(q)
            let decoded = try JSONDecoder().decode(LaunchQuantize.self, from: data)
            XCTAssertEqual(decoded, q)
        }
    }
}

// MARK: - FollowActionType Tests

final class FollowActionTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(FollowActionType.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(FollowActionType.stop.rawValue, "stop")
        XCTAssertEqual(FollowActionType.playAgain.rawValue, "playAgain")
        XCTAssertEqual(FollowActionType.playPrevious.rawValue, "playPrevious")
        XCTAssertEqual(FollowActionType.playNext.rawValue, "playNext")
        XCTAssertEqual(FollowActionType.playFirst.rawValue, "playFirst")
        XCTAssertEqual(FollowActionType.playLast.rawValue, "playLast")
        XCTAssertEqual(FollowActionType.playRandom.rawValue, "playRandom")
        XCTAssertEqual(FollowActionType.playAny.rawValue, "playAny")
    }
}

// MARK: - FollowAction Tests

final class FollowActionTests: XCTestCase {

    func testDefaultInit() {
        let fa = FollowAction()
        XCTAssertEqual(fa.action, .playNext)
        XCTAssertEqual(fa.chance, 1.0)
        XCTAssertNil(fa.linkedAction)
        XCTAssertEqual(fa.linkedChance, 0.0)
    }

    func testCustomInit() {
        let fa = FollowAction(action: .stop, chance: 0.7, linkedAction: .playRandom, linkedChance: 0.3)
        XCTAssertEqual(fa.action, .stop)
        XCTAssertEqual(fa.chance, 0.7)
        XCTAssertEqual(fa.linkedAction, .playRandom)
        XCTAssertEqual(fa.linkedChance, 0.3)
    }

    func testChanceClamping() {
        let fa = FollowAction(action: .playNext, chance: 5.0, linkedChance: -2.0)
        XCTAssertEqual(fa.chance, 1.0)
        XCTAssertEqual(fa.linkedChance, 0.0)
    }

    func testResolveWithOnlyPrimaryAction() {
        let fa = FollowAction(action: .playNext, chance: 1.0, linkedChance: 0.0)
        let result = fa.resolve()
        XCTAssertEqual(result, .playNext)
    }

    func testResolveZeroWeightReturnsPrimary() {
        let fa = FollowAction(action: .stop, chance: 0.0, linkedChance: 0.0)
        let result = fa.resolve()
        XCTAssertEqual(result, .stop)
    }

    func testEquatable() {
        let a = FollowAction(action: .playNext, chance: 1.0)
        let b = FollowAction(action: .playNext, chance: 1.0)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let fa = FollowAction(action: .playRandom, chance: 0.8, linkedAction: .stop, linkedChance: 0.2)
        let data = try JSONEncoder().encode(fa)
        let decoded = try JSONDecoder().decode(FollowAction.self, from: data)
        XCTAssertEqual(decoded.action, fa.action)
        XCTAssertEqual(decoded.chance, fa.chance, accuracy: 0.001)
        XCTAssertEqual(decoded.linkedAction, fa.linkedAction)
    }
}

// MARK: - WarpMode Tests

final class WarpModeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(WarpMode.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(WarpMode.off.rawValue, "off")
        XCTAssertEqual(WarpMode.beats.rawValue, "beats")
        XCTAssertEqual(WarpMode.tones.rawValue, "tones")
        XCTAssertEqual(WarpMode.texture.rawValue, "texture")
        XCTAssertEqual(WarpMode.rePitch.rawValue, "rePitch")
        XCTAssertEqual(WarpMode.complex.rawValue, "complex")
        XCTAssertEqual(WarpMode.complexPro.rawValue, "complexPro")
    }

    func testCodableRoundTrip() throws {
        for mode in WarpMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(WarpMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}

// MARK: - SessionClip Tests

final class SessionClipTests: XCTestCase {

    func testDefaultInit() {
        let clip = SessionClip()
        XCTAssertEqual(clip.name, "Clip")
        XCTAssertEqual(clip.type, .midi)
        XCTAssertEqual(clip.state, .stopped)
        XCTAssertEqual(clip.color, .blue)
        XCTAssertEqual(clip.length, 4.0)
        XCTAssertTrue(clip.loopEnabled)
        XCTAssertEqual(clip.launchMode, .trigger)
        XCTAssertEqual(clip.quantization, .nextBar)
        XCTAssertNil(clip.followAction)
        XCTAssertEqual(clip.warpMode, .off)
        XCTAssertTrue(clip.warpMarkers.isEmpty)
        XCTAssertEqual(clip.playbackSpeed, 1.0)
        XCTAssertNil(clip.audioURL)
        XCTAssertTrue(clip.midiNotes.isEmpty)
        XCTAssertTrue(clip.patternSteps.isEmpty)
    }

    func testPlaybackSpeedClamping() {
        let clipFast = SessionClip(playbackSpeed: 10.0)
        XCTAssertEqual(clipFast.playbackSpeed, 2.0)

        let clipSlow = SessionClip(playbackSpeed: 0.1)
        XCTAssertEqual(clipSlow.playbackSpeed, 0.5)
    }

    func testEquatable() {
        let id = UUID()
        let a = SessionClip(id: id, name: "Test")
        let b = SessionClip(id: id, name: "Test")
        XCTAssertEqual(a, b)
    }

    func testDuplicated() {
        let original = SessionClip(name: "Original", type: .audio, color: .rose)
        let duplicate = original.duplicated(name: "Copy")
        XCTAssertNotEqual(original.id, duplicate.id)
        XCTAssertEqual(duplicate.name, "Copy")
        XCTAssertEqual(duplicate.type, .audio)
        XCTAssertEqual(duplicate.color, .rose)
        XCTAssertEqual(duplicate.state, .stopped)
    }

    func testDuplicatedDefaultName() {
        let original = SessionClip(name: "Drums")
        let duplicate = original.duplicated()
        XCTAssertEqual(duplicate.name, "Drums")
    }
}

// MARK: - SessionTrackType Tests

final class SessionTrackTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(SessionTrackType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(SessionTrackType.audio.rawValue, "audio")
        XCTAssertEqual(SessionTrackType.midi.rawValue, "midi")
        XCTAssertEqual(SessionTrackType.instrument.rawValue, "instrument")
        XCTAssertEqual(SessionTrackType.returnBus.rawValue, "returnBus")
        XCTAssertEqual(SessionTrackType.master.rawValue, "master")
    }
}

// MARK: - SessionMonitorMode Tests

final class SessionMonitorModeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(SessionMonitorMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(SessionMonitorMode.auto.rawValue, "auto")
        XCTAssertEqual(SessionMonitorMode.always.rawValue, "always")
        XCTAssertEqual(SessionMonitorMode.off.rawValue, "off")
    }
}

// MARK: - TrackInput Tests

final class TrackInputTests: XCTestCase {

    func testNone() {
        let input = TrackInput.none
        if case .none = input {
            // pass
        } else {
            XCTFail("Expected .none")
        }
    }

    func testExtInput() {
        let input = TrackInput.extInput(index: 3)
        if case .extInput(let idx) = input {
            XCTAssertEqual(idx, 3)
        } else {
            XCTFail("Expected .extInput")
        }
    }

    func testResampling() {
        let input = TrackInput.resampling
        if case .resampling = input {
            // pass
        } else {
            XCTFail("Expected .resampling")
        }
    }

    func testTrackOutput() {
        let trackID = UUID()
        let input = TrackInput.trackOutput(trackID)
        if case .trackOutput(let id) = input {
            XCTAssertEqual(id, trackID)
        } else {
            XCTFail("Expected .trackOutput")
        }
    }

    func testEquatable() {
        XCTAssertEqual(TrackInput.none, TrackInput.none)
        XCTAssertEqual(TrackInput.extInput(index: 1), TrackInput.extInput(index: 1))
        XCTAssertNotEqual(TrackInput.extInput(index: 1), TrackInput.extInput(index: 2))
        XCTAssertEqual(TrackInput.resampling, TrackInput.resampling)
    }

    func testCodableRoundTrip() throws {
        let inputs: [TrackInput] = [.none, .extInput(index: 2), .resampling, .trackOutput(UUID())]
        for input in inputs {
            let data = try JSONEncoder().encode(input)
            let decoded = try JSONDecoder().decode(TrackInput.self, from: data)
            XCTAssertEqual(decoded, input)
        }
    }
}

// MARK: - CrossfadeAssign Tests

final class CrossfadeAssignTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(CrossfadeAssign.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(CrossfadeAssign.a.rawValue, "a")
        XCTAssertEqual(CrossfadeAssign.none.rawValue, "none")
        XCTAssertEqual(CrossfadeAssign.b.rawValue, "b")
    }
}

// MARK: - SessionTrackSend Tests

final class SessionTrackSendTests: XCTestCase {

    func testInit() {
        let returnID = UUID()
        let send = SessionTrackSend(returnTrackID: returnID, level: 0.5)
        XCTAssertEqual(send.returnTrackID, returnID)
        XCTAssertEqual(send.level, 0.5)
        XCTAssertFalse(send.isPreFader)
    }

    func testLevelClamping() {
        let send = SessionTrackSend(returnTrackID: UUID(), level: 5.0)
        XCTAssertEqual(send.level, 1.0)

        let sendLow = SessionTrackSend(returnTrackID: UUID(), level: -2.0)
        XCTAssertEqual(sendLow.level, 0.0)
    }

    func testEquatable() {
        let id = UUID()
        let returnID = UUID()
        let a = SessionTrackSend(id: id, returnTrackID: returnID, level: 0.3)
        let b = SessionTrackSend(id: id, returnTrackID: returnID, level: 0.3)
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let send = SessionTrackSend(returnTrackID: UUID(), level: 0.7, isPreFader: true)
        let data = try JSONEncoder().encode(send)
        let decoded = try JSONDecoder().decode(SessionTrackSend.self, from: data)
        XCTAssertEqual(decoded.level, send.level, accuracy: 0.001)
        XCTAssertEqual(decoded.isPreFader, send.isPreFader)
    }
}

// MARK: - SessionTrack Tests

final class SessionTrackTests: XCTestCase {

    func testDefaultInit() {
        let track = SessionTrack()
        XCTAssertEqual(track.name, "Track")
        XCTAssertEqual(track.color, .blue)
        XCTAssertTrue(track.clips.isEmpty)
        XCTAssertEqual(track.type, .audio)
        XCTAssertFalse(track.isArmed)
        XCTAssertEqual(track.monitorMode, .auto)
        XCTAssertEqual(track.volume, 0.85)
        XCTAssertEqual(track.pan, 0.0)
        XCTAssertFalse(track.mute)
        XCTAssertFalse(track.solo)
        XCTAssertEqual(track.inputRouting, .none)
        XCTAssertNil(track.outputRouting)
        XCTAssertTrue(track.sends.isEmpty)
        XCTAssertTrue(track.stopButton)
        XCTAssertEqual(track.crossfadeAssign, .none)
    }

    func testVolumeClamping() {
        let track = SessionTrack(volume: 5.0)
        XCTAssertEqual(track.volume, 1.0)
    }

    func testPanClamping() {
        let track = SessionTrack(pan: -5.0)
        XCTAssertEqual(track.pan, -1.0)
    }

    func testEnsureSlots() {
        var track = SessionTrack()
        XCTAssertTrue(track.clips.isEmpty)
        track.ensureSlots(count: 4)
        XCTAssertEqual(track.clips.count, 4)
        for clip in track.clips {
            XCTAssertNil(clip)
        }
    }

    func testEnsureSlotsDoesNotShrink() {
        var track = SessionTrack()
        track.ensureSlots(count: 8)
        track.ensureSlots(count: 4)
        XCTAssertEqual(track.clips.count, 8)
    }

    func testEquatable() {
        let id = UUID()
        let a = SessionTrack(id: id, name: "Drums")
        let b = SessionTrack(id: id, name: "Drums")
        XCTAssertEqual(a, b)
    }
}

// MARK: - SessionScene Tests

final class SessionSceneTests: XCTestCase {

    func testDefaultInit() {
        let scene = SessionScene()
        XCTAssertEqual(scene.name, "Scene")
        XCTAssertEqual(scene.number, 1)
        XCTAssertNil(scene.tempo)
        XCTAssertNil(scene.timeSignature)
        XCTAssertEqual(scene.color, .amber)
    }

    func testCustomInit() {
        let scene = SessionScene(name: "Chorus", number: 3, tempo: 140.0, timeSignature: "4/4", color: .red)
        XCTAssertEqual(scene.name, "Chorus")
        XCTAssertEqual(scene.number, 3)
        XCTAssertEqual(scene.tempo, 140.0)
        XCTAssertEqual(scene.timeSignature, "4/4")
        XCTAssertEqual(scene.color, .red)
    }

    func testEquatable() {
        let id = UUID()
        let a = SessionScene(id: id, name: "Intro", number: 1)
        let b = SessionScene(id: id, name: "Intro", number: 1)
        XCTAssertEqual(a, b)
    }
}

// MARK: - AudioNodeType Tests

final class AudioNodeTypeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(AudioNodeType.source.rawValue, "source")
        XCTAssertEqual(AudioNodeType.effect.rawValue, "effect")
        XCTAssertEqual(AudioNodeType.mixer.rawValue, "mixer")
        XCTAssertEqual(AudioNodeType.output.rawValue, "output")
        XCTAssertEqual(AudioNodeType.analyzer.rawValue, "analyzer")
        XCTAssertEqual(AudioNodeType.splitter.rawValue, "splitter")
        XCTAssertEqual(AudioNodeType.bioReactive.rawValue, "bioReactive")
    }

    func testInvalidRawValue() {
        XCTAssertNil(AudioNodeType(rawValue: "invalid"))
    }
}

// MARK: - AudioGraph.AudioConnection Tests

final class AudioConnectionTests: XCTestCase {

    func testInit() {
        let conn = AudioGraph.AudioConnection(from: "osc", to: "filter", bus: 0)
        XCTAssertEqual(conn.from, "osc")
        XCTAssertEqual(conn.to, "filter")
        XCTAssertEqual(conn.bus, 0)
    }

    func testDefaultBus() {
        let conn = AudioGraph.AudioConnection(from: "a", to: "b")
        XCTAssertEqual(conn.bus, 0)
    }
}

// MARK: - Source Node Tests

final class SourceNodeTests: XCTestCase {

    func testInit() {
        let source = Source("osc1")
        XCTAssertEqual(source.nodeId, "osc1")
        XCTAssertEqual(source.nodeType, .source)
        XCTAssertTrue(source.inputs.isEmpty)
        XCTAssertEqual(source.outputs, ["osc1"])
    }

    func testFrequency() {
        let source = Source("osc").frequency(880)
        XCTAssertEqual(source.parameters["frequency"] as? Float, 880)
    }

    func testWaveform() {
        let source = Source("osc").waveform(.sawtooth)
        XCTAssertEqual(source.parameters["waveform"] as? String, "sawtooth")
    }

    func testAmplitude() {
        let source = Source("osc").amplitude(0.3)
        XCTAssertEqual(source.parameters["amplitude"] as? Float, 0.3)
    }

    func testChaining() {
        let source = Source("osc").frequency(440).waveform(.sine).amplitude(0.5)
        XCTAssertEqual(source.parameters["frequency"] as? Float, 440)
        XCTAssertEqual(source.parameters["waveform"] as? String, "sine")
        XCTAssertEqual(source.parameters["amplitude"] as? Float, 0.5)
    }
}

// MARK: - Source.Waveform Tests

final class WaveformTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(Source.Waveform.sine.rawValue, "sine")
        XCTAssertEqual(Source.Waveform.square.rawValue, "square")
        XCTAssertEqual(Source.Waveform.sawtooth.rawValue, "sawtooth")
        XCTAssertEqual(Source.Waveform.triangle.rawValue, "triangle")
        XCTAssertEqual(Source.Waveform.noise.rawValue, "noise")
    }
}
#endif
