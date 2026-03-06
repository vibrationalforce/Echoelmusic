// AudioEngineExtendedTests.swift
// Echoelmusic
//
// Comprehensive tests for audio engine utility types:
// AudioGraphBuilder, AbletonLinkClient, UltraLowLatencyBluetoothEngine,
// BreakbeatChopper, NeveInspiredDSP, ClipLauncherGrid, VisualStepSequencer
//
// Created 2026-03-06

import XCTest
@testable import Echoelmusic
import Foundation

// MARK: - AudioNodeType Tests

final class AudioNodeTypeTests: XCTestCase {

    func testCaseCount() {
        let cases: [AudioNodeType] = [.source, .effect, .mixer, .output, .analyzer, .splitter, .bioReactive]
        XCTAssertEqual(cases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(AudioNodeType.source.rawValue, "source")
        XCTAssertEqual(AudioNodeType.effect.rawValue, "effect")
        XCTAssertEqual(AudioNodeType.mixer.rawValue, "mixer")
        XCTAssertEqual(AudioNodeType.output.rawValue, "output")
        XCTAssertEqual(AudioNodeType.analyzer.rawValue, "analyzer")
        XCTAssertEqual(AudioNodeType.splitter.rawValue, "splitter")
        XCTAssertEqual(AudioNodeType.bioReactive.rawValue, "bioReactive")
    }

    func testRoundTripFromRawValue() {
        for raw in ["source", "effect", "mixer", "output", "analyzer", "splitter", "bioReactive"] {
            let node = AudioNodeType(rawValue: raw)
            XCTAssertNotNil(node)
            XCTAssertEqual(node?.rawValue, raw)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(AudioNodeType(rawValue: "invalid"))
        XCTAssertNil(AudioNodeType(rawValue: ""))
    }
}

// MARK: - Source Tests

final class AudioGraphSourceTests: XCTestCase {

    func testSourceInit() {
        let source = Source("osc1")
        XCTAssertEqual(source.nodeId, "osc1")
        XCTAssertEqual(source.nodeType, .source)
        XCTAssertTrue(source.inputs.isEmpty)
        XCTAssertEqual(source.outputs, ["osc1"])
    }

    func testSourceFrequency() {
        let source = Source("osc1").frequency(880)
        XCTAssertEqual(source.parameters["frequency"] as? Float, 880)
    }

    func testSourceWaveform() {
        let source = Source("osc1").waveform(.sawtooth)
        XCTAssertEqual(source.parameters["waveform"] as? String, "sawtooth")
    }

    func testSourceAmplitude() {
        let source = Source("osc1").amplitude(0.8)
        XCTAssertEqual(source.parameters["amplitude"] as? Float, 0.8)
    }

    func testSourceWaveformRawValues() {
        XCTAssertEqual(Source.Waveform.sine.rawValue, "sine")
        XCTAssertEqual(Source.Waveform.square.rawValue, "square")
        XCTAssertEqual(Source.Waveform.sawtooth.rawValue, "sawtooth")
        XCTAssertEqual(Source.Waveform.triangle.rawValue, "triangle")
        XCTAssertEqual(Source.Waveform.noise.rawValue, "noise")
    }

    func testSourceChaining() {
        let source = Source("osc1")
            .frequency(440)
            .waveform(.sine)
            .amplitude(0.5)
        XCTAssertEqual(source.parameters["frequency"] as? Float, 440)
        XCTAssertEqual(source.parameters["waveform"] as? String, "sine")
        XCTAssertEqual(source.parameters["amplitude"] as? Float, 0.5)
    }
}

// MARK: - Effect Tests

final class AudioGraphEffectTests: XCTestCase {

    func testEffectInit() {
        let effect = Effect("filter1", type: .lowPass)
        XCTAssertEqual(effect.nodeId, "filter1")
        XCTAssertEqual(effect.nodeType, .effect)
        XCTAssertEqual(effect.parameters["type"] as? String, "lowPass")
        XCTAssertEqual(effect.outputs, ["filter1"])
    }

    func testEffectInput() {
        let effect = Effect("filter1", type: .lowPass).input("osc1")
        XCTAssertEqual(effect.inputs, ["osc1"])
    }

    func testEffectCutoff() {
        let effect = Effect("f", type: .lowPass).cutoff(2000)
        XCTAssertEqual(effect.parameters["cutoff"] as? Float, 2000)
    }

    func testEffectResonance() {
        let effect = Effect("f", type: .lowPass).resonance(0.9)
        XCTAssertEqual(effect.parameters["resonance"] as? Float, 0.9)
    }

    func testEffectMix() {
        let effect = Effect("r", type: .reverb).mix(0.5)
        XCTAssertEqual(effect.parameters["mix"] as? Float, 0.5)
    }

    func testEffectTime() {
        let effect = Effect("d", type: .delay).time(0.25)
        XCTAssertEqual(effect.parameters["time"] as? Float, 0.25)
    }

    func testEffectFeedback() {
        let effect = Effect("d", type: .delay).feedback(0.6)
        XCTAssertEqual(effect.parameters["feedback"] as? Float, 0.6)
    }

    func testEffectThreshold() {
        let effect = Effect("c", type: .compressor).threshold(-12)
        XCTAssertEqual(effect.parameters["threshold"] as? Float, -12)
    }

    func testEffectRatio() {
        let effect = Effect("c", type: .compressor).ratio(4.0)
        XCTAssertEqual(effect.parameters["ratio"] as? Float, 4.0)
    }

    func testEffectAttack() {
        let effect = Effect("c", type: .compressor).attack(10)
        XCTAssertEqual(effect.parameters["attack"] as? Float, 10)
    }

    func testEffectRelease() {
        let effect = Effect("c", type: .compressor).release(200)
        XCTAssertEqual(effect.parameters["release"] as? Float, 200)
    }

    func testEffectTypeRawValues() {
        XCTAssertEqual(Effect.EffectType.lowPass.rawValue, "lowPass")
        XCTAssertEqual(Effect.EffectType.highPass.rawValue, "highPass")
        XCTAssertEqual(Effect.EffectType.bandPass.rawValue, "bandPass")
        XCTAssertEqual(Effect.EffectType.notch.rawValue, "notch")
        XCTAssertEqual(Effect.EffectType.reverb.rawValue, "reverb")
        XCTAssertEqual(Effect.EffectType.delay.rawValue, "delay")
        XCTAssertEqual(Effect.EffectType.chorus.rawValue, "chorus")
        XCTAssertEqual(Effect.EffectType.flanger.rawValue, "flanger")
        XCTAssertEqual(Effect.EffectType.phaser.rawValue, "phaser")
        XCTAssertEqual(Effect.EffectType.distortion.rawValue, "distortion")
        XCTAssertEqual(Effect.EffectType.compressor.rawValue, "compressor")
        XCTAssertEqual(Effect.EffectType.limiter.rawValue, "limiter")
        XCTAssertEqual(Effect.EffectType.eq.rawValue, "eq")
        XCTAssertEqual(Effect.EffectType.parametricEQ.rawValue, "parametricEQ")
        XCTAssertEqual(Effect.EffectType.hall.rawValue, "hall")
        XCTAssertEqual(Effect.EffectType.plate.rawValue, "plate")
        XCTAssertEqual(Effect.EffectType.room.rawValue, "room")
        XCTAssertEqual(Effect.EffectType.spring.rawValue, "spring")
    }

    func testEffectChaining() {
        let effect = Effect("comp", type: .compressor)
            .input("mixer")
            .threshold(-20)
            .ratio(4.0)
            .attack(5)
            .release(100)
        XCTAssertEqual(effect.inputs, ["mixer"])
        XCTAssertEqual(effect.parameters["threshold"] as? Float, -20)
        XCTAssertEqual(effect.parameters["ratio"] as? Float, 4.0)
    }
}

// MARK: - BioReactiveNode Tests

final class BioReactiveNodeTests: XCTestCase {

    func testBioReactiveNodeInit() {
        let node = BioReactiveNode("bioMod")
        XCTAssertEqual(node.nodeId, "bioMod")
        XCTAssertEqual(node.nodeType, .bioReactive)
        XCTAssertEqual(node.outputs, ["bioMod"])
        XCTAssertTrue(node.inputs.isEmpty)
    }

    func testBioReactiveNodeInput() {
        let node = BioReactiveNode("bioMod").input("filter1")
        XCTAssertEqual(node.inputs, ["filter1"])
    }

    func testBioReactiveNodeParameterMapping() {
        let node = BioReactiveNode("bioMod")
            .parameter(.cutoff, mappedTo: .coherence)
        let mappings = node.parameters["mappings"] as? [[String: String]]
        XCTAssertNotNil(mappings)
        XCTAssertEqual(mappings?.count, 1)
        XCTAssertEqual(mappings?[0]["target"], "cutoff")
        XCTAssertEqual(mappings?[0]["source"], "coherence")
    }

    func testBioReactiveNodeMultipleMappings() {
        let node = BioReactiveNode("bioMod")
            .parameter(.cutoff, mappedTo: .coherence)
            .parameter(.amplitude, mappedTo: .heartRate)
        let mappings = node.parameters["mappings"] as? [[String: String]]
        XCTAssertEqual(mappings?.count, 2)
    }

    func testBioReactiveNodeRange() {
        let node = BioReactiveNode("bioMod").range(min: 100, max: 2000)
        XCTAssertEqual(node.parameters["rangeMin"] as? Float, 100)
        XCTAssertEqual(node.parameters["rangeMax"] as? Float, 2000)
    }

    func testBioReactiveNodeCurve() {
        let node = BioReactiveNode("bioMod").curve(.exponential)
        XCTAssertEqual(node.parameters["curve"] as? String, "exponential")
    }

    func testBioReactiveNodeSmoothing() {
        let node = BioReactiveNode("bioMod").smoothing(0.8)
        XCTAssertEqual(node.parameters["smoothing"] as? Float, 0.8)
    }

    func testTargetParameterRawValues() {
        XCTAssertEqual(BioReactiveNode.TargetParameter.cutoff.rawValue, "cutoff")
        XCTAssertEqual(BioReactiveNode.TargetParameter.resonance.rawValue, "resonance")
        XCTAssertEqual(BioReactiveNode.TargetParameter.mix.rawValue, "mix")
        XCTAssertEqual(BioReactiveNode.TargetParameter.amplitude.rawValue, "amplitude")
        XCTAssertEqual(BioReactiveNode.TargetParameter.pitch.rawValue, "pitch")
        XCTAssertEqual(BioReactiveNode.TargetParameter.pan.rawValue, "pan")
        XCTAssertEqual(BioReactiveNode.TargetParameter.attack.rawValue, "attack")
        XCTAssertEqual(BioReactiveNode.TargetParameter.release.rawValue, "release")
        XCTAssertEqual(BioReactiveNode.TargetParameter.threshold.rawValue, "threshold")
        XCTAssertEqual(BioReactiveNode.TargetParameter.ratio.rawValue, "ratio")
        XCTAssertEqual(BioReactiveNode.TargetParameter.delayTime.rawValue, "delayTime")
        XCTAssertEqual(BioReactiveNode.TargetParameter.feedback.rawValue, "feedback")
        XCTAssertEqual(BioReactiveNode.TargetParameter.reverbMix.rawValue, "reverbMix")
    }

    func testBioSourceRawValues() {
        XCTAssertEqual(BioReactiveNode.BioSource.coherence.rawValue, "coherence")
        XCTAssertEqual(BioReactiveNode.BioSource.heartRate.rawValue, "heartRate")
        XCTAssertEqual(BioReactiveNode.BioSource.hrv.rawValue, "hrv")
        XCTAssertEqual(BioReactiveNode.BioSource.breathPhase.rawValue, "breathPhase")
        XCTAssertEqual(BioReactiveNode.BioSource.breathRate.rawValue, "breathRate")
        XCTAssertEqual(BioReactiveNode.BioSource.gsr.rawValue, "gsr")
        XCTAssertEqual(BioReactiveNode.BioSource.spO2.rawValue, "spO2")
        XCTAssertEqual(BioReactiveNode.BioSource.attention.rawValue, "attention")
    }

    func testMappingCurveRawValues() {
        XCTAssertEqual(BioReactiveNode.MappingCurve.linear.rawValue, "linear")
        XCTAssertEqual(BioReactiveNode.MappingCurve.exponential.rawValue, "exponential")
        XCTAssertEqual(BioReactiveNode.MappingCurve.logarithmic.rawValue, "logarithmic")
        XCTAssertEqual(BioReactiveNode.MappingCurve.sCurve.rawValue, "sCurve")
    }
}

// MARK: - Mixer Tests

final class AudioGraphMixerTests: XCTestCase {

    func testMixerInit() {
        let mixer = Mixer("mix1")
        XCTAssertEqual(mixer.nodeId, "mix1")
        XCTAssertEqual(mixer.nodeType, .mixer)
        XCTAssertEqual(mixer.outputs, ["mix1"])
        XCTAssertTrue(mixer.inputs.isEmpty)
    }

    func testMixerInput() {
        let mixer = Mixer("mix1").input("osc1", volume: 0.8, pan: -0.5)
        XCTAssertEqual(mixer.inputs, ["osc1"])
        let inputParams = mixer.parameters["inputParams"] as? [[String: Any]]
        XCTAssertNotNil(inputParams)
        XCTAssertEqual(inputParams?[0]["volume"] as? Float, 0.8)
        XCTAssertEqual(inputParams?[0]["pan"] as? Float, -0.5)
    }

    func testMixerMultipleInputs() {
        let mixer = Mixer("mix1")
            .input("osc1", volume: 1.0, pan: -1.0)
            .input("osc2", volume: 0.5, pan: 1.0)
        XCTAssertEqual(mixer.inputs.count, 2)
    }

    func testMixerMasterVolume() {
        let mixer = Mixer("mix1").masterVolume(0.9)
        XCTAssertEqual(mixer.parameters["masterVolume"] as? Float, 0.9)
    }
}

// MARK: - Output Tests

final class AudioGraphOutputTests: XCTestCase {

    func testOutputInit() {
        let output = Output("main")
        XCTAssertEqual(output.nodeId, "main")
        XCTAssertEqual(output.nodeType, .output)
        XCTAssertTrue(output.inputs.isEmpty)
    }

    func testOutputInput() {
        let output = Output("main").input("mixer")
        XCTAssertEqual(output.inputs, ["mixer"])
    }

    func testOutputVolume() {
        let output = Output("main").volume(0.7)
        XCTAssertEqual(output.parameters["volume"] as? Float, 0.7)
    }

    func testOutputMuted() {
        let output = Output("main").muted(true)
        XCTAssertEqual(output.parameters["muted"] as? Bool, true)
    }
}

// MARK: - Analyzer Tests

final class AudioGraphAnalyzerTests: XCTestCase {

    func testAnalyzerInit() {
        let analyzer = Analyzer("fftAnalyzer", type: .fft)
        XCTAssertEqual(analyzer.nodeId, "fftAnalyzer")
        XCTAssertEqual(analyzer.nodeType, .analyzer)
        XCTAssertEqual(analyzer.parameters["analyzerType"] as? String, "fft")
        XCTAssertEqual(analyzer.outputs, ["fftAnalyzer"])
    }

    func testAnalyzerInput() {
        let analyzer = Analyzer("rms", type: .rms).input("mixer")
        XCTAssertEqual(analyzer.inputs, ["mixer"])
    }

    func testAnalyzerFFTSize() {
        let analyzer = Analyzer("fft", type: .fft).fftSize(2048)
        XCTAssertEqual(analyzer.parameters["fftSize"] as? Int, 2048)
    }

    func testAnalyzerTypeRawValues() {
        XCTAssertEqual(Analyzer.AnalyzerType.fft.rawValue, "fft")
        XCTAssertEqual(Analyzer.AnalyzerType.rms.rawValue, "rms")
        XCTAssertEqual(Analyzer.AnalyzerType.peak.rawValue, "peak")
        XCTAssertEqual(Analyzer.AnalyzerType.beatDetector.rawValue, "beatDetector")
        XCTAssertEqual(Analyzer.AnalyzerType.pitchDetector.rawValue, "pitchDetector")
    }
}

// MARK: - Splitter Tests

final class AudioGraphSplitterTests: XCTestCase {

    func testSplitterInit() {
        let splitter = Splitter("split1")
        XCTAssertEqual(splitter.nodeId, "split1")
        XCTAssertEqual(splitter.nodeType, .splitter)
        XCTAssertTrue(splitter.inputs.isEmpty)
    }

    func testSplitterInput() {
        let splitter = Splitter("split1").input("mixer")
        XCTAssertEqual(splitter.inputs, ["mixer"])
    }

    func testSplitterOutputCount() {
        let splitter = Splitter("split1").outputCount(3)
        XCTAssertEqual(splitter.outputs.count, 3)
        XCTAssertEqual(splitter.outputs[0], "split1_0")
        XCTAssertEqual(splitter.outputs[1], "split1_1")
        XCTAssertEqual(splitter.outputs[2], "split1_2")
        XCTAssertEqual(splitter.parameters["outputCount"] as? Int, 3)
    }
}

// MARK: - AudioGraph / AudioGraphBuilder Tests

final class AudioGraphBuilderTests: XCTestCase {

    func testBuildSimpleGraph() {
        let graph = AudioGraphBuilder.build {
            Source("osc1").frequency(440).waveform(.sine)
            Output("main").input("osc1")
        }
        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.connections.count, 1)
        XCTAssertEqual(graph.connections[0].from, "osc1")
        XCTAssertEqual(graph.connections[0].to, "main")
    }

    func testAudioConnectionDefaultBus() {
        let conn = AudioGraph.AudioConnection(from: "a", to: "b")
        XCTAssertEqual(conn.bus, 0)
    }

    func testAudioConnectionCustomBus() {
        let conn = AudioGraph.AudioConnection(from: "a", to: "b", bus: 3)
        XCTAssertEqual(conn.bus, 3)
        XCTAssertEqual(conn.from, "a")
        XCTAssertEqual(conn.to, "b")
    }

    func testInferredConnectionsBusIndices() {
        let graph = AudioGraphBuilder.build {
            Source("osc1")
            Source("osc2")
            Mixer("mix").input("osc1", volume: 1.0).input("osc2", volume: 1.0)
        }
        let mixConns = graph.connections.filter { $0.to == "mix" }
        XCTAssertEqual(mixConns.count, 2)
        XCTAssertEqual(mixConns[0].bus, 0)
        XCTAssertEqual(mixConns[1].bus, 1)
    }

    func testMeditationGraphPreset() {
        let graph = AudioGraphBuilder.meditationGraph()
        XCTAssertGreaterThanOrEqual(graph.nodes.count, 5)
        XCTAssertFalse(graph.connections.isEmpty)
    }

    func testEnergeticGraphPreset() {
        let graph = AudioGraphBuilder.energeticGraph()
        XCTAssertGreaterThanOrEqual(graph.nodes.count, 5)
        XCTAssertFalse(graph.connections.isEmpty)
    }
}

// MARK: - LinkConstants Tests

final class LinkConstantsTests: XCTestCase {

    func testMulticastAddress() {
        XCTAssertEqual(LinkConstants.multicastAddress, "224.76.78.75")
    }

    func testPort() {
        XCTAssertEqual(LinkConstants.port, 20808)
    }

    func testProtocolVersion() {
        XCTAssertEqual(LinkConstants.protocolVersion, 2)
    }

    func testDiscoveryInterval() {
        XCTAssertEqual(LinkConstants.discoveryInterval, 1.0)
    }

    func testSessionTimeout() {
        XCTAssertEqual(LinkConstants.sessionTimeout, 5.0)
    }

    func testMicrosecondsPerBeat() {
        XCTAssertEqual(LinkConstants.microsecondsPerBeatAt120BPM, 500_000)
    }

    func testMessageTypes() {
        XCTAssertEqual(LinkConstants.msgPing, 0x01)
        XCTAssertEqual(LinkConstants.msgPong, 0x02)
        XCTAssertEqual(LinkConstants.msgState, 0x03)
        XCTAssertEqual(LinkConstants.msgStartStop, 0x04)
    }
}

// MARK: - LinkSessionState Tests

final class LinkSessionStateTests: XCTestCase {

    func testDefaultInit() {
        let state = LinkSessionState()
        XCTAssertEqual(state.tempo, 120.0)
        XCTAssertEqual(state.beat, 0.0)
        XCTAssertEqual(state.phase, 0.0)
        XCTAssertEqual(state.quantum, 4.0)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.peerCount, 0)
        XCTAssertGreaterThan(state.timestamp, 0)
    }

    func testCustomInit() {
        let state = LinkSessionState(tempo: 140.0, quantum: 3.0)
        XCTAssertEqual(state.tempo, 140.0)
        XCTAssertEqual(state.quantum, 3.0)
    }

    func testMutableProperties() {
        var state = LinkSessionState()
        state.tempo = 150.0
        state.isPlaying = true
        state.peerCount = 3
        XCTAssertEqual(state.tempo, 150.0)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.peerCount, 3)
    }

    func testUpdateBeatDoesNotProduceNaN() {
        var state = LinkSessionState(tempo: 10.0)
        state.updateBeat()
        XCTAssertFalse(state.beat.isNaN)
        XCTAssertFalse(state.phase.isNaN)
    }
}

// MARK: - LinkPeer Tests

final class LinkPeerTests: XCTestCase {

    func testInit() {
        let id = UUID()
        let peer = LinkPeer(
            id: id, address: "192.168.1.10", port: 20808,
            name: "Test Peer", tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent()
        )
        XCTAssertEqual(peer.id, id)
        XCTAssertEqual(peer.address, "192.168.1.10")
        XCTAssertEqual(peer.port, 20808)
        XCTAssertEqual(peer.name, "Test Peer")
    }

    func testIsStale() {
        let peer = LinkPeer(
            id: UUID(), address: "10.0.0.1", port: 20808,
            name: "Old", tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent() - 10.0
        )
        XCTAssertTrue(peer.isStale)
    }

    func testIsNotStale() {
        let peer = LinkPeer(
            id: UUID(), address: "10.0.0.2", port: 20808,
            name: "Fresh", tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent()
        )
        XCTAssertFalse(peer.isStale)
    }

    func testEquatable() {
        let id = UUID()
        let a = LinkPeer(id: id, address: "1.1.1.1", port: 1, name: "A", tempo: 120, lastSeen: 0)
        let b = LinkPeer(id: id, address: "1.1.1.1", port: 1, name: "A", tempo: 120, lastSeen: 0)
        XCTAssertEqual(a, b)
    }
}

// MARK: - BluetoothAudioCodec Tests

#if canImport(CoreBluetooth)

final class BluetoothAudioCodecTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(BluetoothAudioCodec.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(BluetoothAudioCodec.sbc.rawValue, "SBC")
        XCTAssertEqual(BluetoothAudioCodec.aac.rawValue, "AAC")
        XCTAssertEqual(BluetoothAudioCodec.aptx.rawValue, "aptX")
        XCTAssertEqual(BluetoothAudioCodec.aptxHD.rawValue, "aptX HD")
        XCTAssertEqual(BluetoothAudioCodec.aptxLL.rawValue, "aptX Low Latency")
        XCTAssertEqual(BluetoothAudioCodec.aptxAdaptive.rawValue, "aptX Adaptive")
        XCTAssertEqual(BluetoothAudioCodec.ldac.rawValue, "LDAC")
        XCTAssertEqual(BluetoothAudioCodec.lc3.rawValue, "LC3")
        XCTAssertEqual(BluetoothAudioCodec.lc3plus.rawValue, "LC3plus")
        XCTAssertEqual(BluetoothAudioCodec.opus.rawValue, "Opus")
    }

    func testIdentifiable() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertEqual(codec.id, codec.rawValue)
        }
    }

    func testTypicalLatencyPositive() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertGreaterThan(codec.typicalLatency, 0)
        }
    }

    func testSBCHighestLatency() {
        XCTAssertEqual(BluetoothAudioCodec.sbc.typicalLatency, 200)
    }

    func testLC3PlusLowestLatency() {
        XCTAssertEqual(BluetoothAudioCodec.lc3plus.typicalLatency, 15)
    }

    func testMaxBitratePositive() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertGreaterThan(codec.maxBitrate, 0)
        }
    }

    func testLDACHighestBitrate() {
        XCTAssertEqual(BluetoothAudioCodec.ldac.maxBitrate, 990)
    }

    func testSupportedSampleRatesNotEmpty() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertFalse(codec.supportedSampleRates.isEmpty)
        }
    }

    func testRealtimeCapable() {
        XCTAssertTrue(BluetoothAudioCodec.aptxLL.isRealtimeCapable)
        XCTAssertTrue(BluetoothAudioCodec.lc3.isRealtimeCapable)
        XCTAssertTrue(BluetoothAudioCodec.lc3plus.isRealtimeCapable)
        XCTAssertTrue(BluetoothAudioCodec.opus.isRealtimeCapable)
        XCTAssertFalse(BluetoothAudioCodec.sbc.isRealtimeCapable)
        XCTAssertFalse(BluetoothAudioCodec.aac.isRealtimeCapable)
    }

    func testQualityTiers() {
        XCTAssertEqual(BluetoothAudioCodec.sbc.qualityTier, .standard)
        XCTAssertEqual(BluetoothAudioCodec.aac.qualityTier, .good)
        XCTAssertEqual(BluetoothAudioCodec.aptxHD.qualityTier, .highRes)
        XCTAssertEqual(BluetoothAudioCodec.aptxLL.qualityTier, .lowLatency)
        XCTAssertEqual(BluetoothAudioCodec.aptxAdaptive.qualityTier, .adaptive)
    }

    func testQualityTierRawValues() {
        XCTAssertEqual(BluetoothAudioCodec.QualityTier.standard.rawValue, "Standard")
        XCTAssertEqual(BluetoothAudioCodec.QualityTier.good.rawValue, "Good")
        XCTAssertEqual(BluetoothAudioCodec.QualityTier.highRes.rawValue, "Hi-Res")
        XCTAssertEqual(BluetoothAudioCodec.QualityTier.lowLatency.rawValue, "Low Latency")
        XCTAssertEqual(BluetoothAudioCodec.QualityTier.adaptive.rawValue, "Adaptive")
    }
}

// MARK: - BluetoothDeviceType Tests

final class BluetoothDeviceTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(BluetoothDeviceType.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(BluetoothDeviceType.headphones.rawValue, "Headphones")
        XCTAssertEqual(BluetoothDeviceType.earbuds.rawValue, "Earbuds")
        XCTAssertEqual(BluetoothDeviceType.speaker.rawValue, "Speaker")
        XCTAssertEqual(BluetoothDeviceType.soundbar.rawValue, "Soundbar")
        XCTAssertEqual(BluetoothDeviceType.audioInterface.rawValue, "Audio Interface")
        XCTAssertEqual(BluetoothDeviceType.midiController.rawValue, "MIDI Controller")
        XCTAssertEqual(BluetoothDeviceType.instrument.rawValue, "Instrument")
        XCTAssertEqual(BluetoothDeviceType.microphone.rawValue, "Microphone")
        XCTAssertEqual(BluetoothDeviceType.monitor.rawValue, "Studio Monitor")
        XCTAssertEqual(BluetoothDeviceType.unknown.rawValue, "Unknown")
    }

    func testIconsNotEmpty() {
        for device in BluetoothDeviceType.allCases {
            XCTAssertFalse(device.icon.isEmpty)
        }
    }

    func testRecommendedCodecExists() {
        for device in BluetoothDeviceType.allCases {
            let codec = device.recommendedCodec
            XCTAssertTrue(BluetoothAudioCodec.allCases.contains(codec))
        }
    }

    func testPerformanceDevicesRecommendLowLatency() {
        XCTAssertEqual(BluetoothDeviceType.audioInterface.recommendedCodec, .aptxLL)
        XCTAssertEqual(BluetoothDeviceType.monitor.recommendedCodec, .aptxLL)
    }
}

// MARK: - BluetoothAudioDevice Tests

final class BluetoothAudioDeviceTests: XCTestCase {

    private func makeDevice(
        rssi: Int = -45,
        codecs: [BluetoothAudioCodec] = [.sbc, .aac, .aptxLL, .lc3]
    ) -> BluetoothAudioDevice {
        BluetoothAudioDevice(
            id: UUID(), name: "Test", type: .headphones,
            supportedCodecs: codecs, rssi: rssi, batteryLevel: 80,
            isConnected: true, isPlaying: false,
            currentCodec: .aac, measuredLatency: 25.0,
            supportsA2DP: true, supportsHFP: true, supportsAVRCP: true,
            supportsBLE: true, supportsLEAudio: true, supportsMultipoint: false,
            maxSampleRate: 48000, maxBitDepth: 24, maxChannels: 2,
            firmwareVersion: "1.0"
        )
    }

    func testSignalQualityExcellent() {
        XCTAssertEqual(makeDevice(rssi: -45).signalQuality, .excellent)
    }

    func testSignalQualityGood() {
        XCTAssertEqual(makeDevice(rssi: -55).signalQuality, .good)
    }

    func testSignalQualityFair() {
        XCTAssertEqual(makeDevice(rssi: -65).signalQuality, .fair)
    }

    func testSignalQualityPoor() {
        XCTAssertEqual(makeDevice(rssi: -80).signalQuality, .poor)
    }

    func testBestLowLatencyCodecPreference() {
        let device = makeDevice(codecs: [.sbc, .aac, .aptxLL, .lc3])
        XCTAssertEqual(device.bestLowLatencyCodec, .lc3)
    }

    func testBestLowLatencyCodecFallback() {
        let device = makeDevice(codecs: [.sbc])
        XCTAssertEqual(device.bestLowLatencyCodec, .sbc)
    }

    func testBestQualityCodecPreference() {
        let device = makeDevice(codecs: [.sbc, .aac, .ldac])
        XCTAssertEqual(device.bestQualityCodec, .ldac)
    }

    func testHashable() {
        let device = makeDevice()
        var set: Set<BluetoothAudioDevice> = []
        set.insert(device)
        XCTAssertTrue(set.contains(device))
    }

    func testSignalQualityRawValues() {
        XCTAssertEqual(BluetoothAudioDevice.SignalQuality.excellent.rawValue, "Excellent")
        XCTAssertEqual(BluetoothAudioDevice.SignalQuality.good.rawValue, "Good")
        XCTAssertEqual(BluetoothAudioDevice.SignalQuality.fair.rawValue, "Fair")
        XCTAssertEqual(BluetoothAudioDevice.SignalQuality.poor.rawValue, "Poor")
    }
}

// MARK: - DirectMonitoringConfig Tests

final class DirectMonitoringConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = DirectMonitoringConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.inputGain, 1.0)
        XCTAssertEqual(config.outputGain, 1.0)
        XCTAssertEqual(config.pan, 0.0)
        XCTAssertFalse(config.soloMode)
        XCTAssertFalse(config.muteRecordedTrack)
        XCTAssertTrue(config.lowLatencyMode)
        XCTAssertFalse(config.bypassEffects)
        XCTAssertTrue(config.useHardwareMonitoring)
        XCTAssertEqual(config.bufferSize, .ultraLow)
    }

    func testBufferSizeCaseCount() {
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.allCases.count, 6)
    }

    func testBufferSizeRawValues() {
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.ultraLow.rawValue, 32)
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.veryLow.rawValue, 64)
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.low.rawValue, 128)
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.medium.rawValue, 256)
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.high.rawValue, 512)
        XCTAssertEqual(DirectMonitoringConfig.BufferSize.veryHigh.rawValue, 1024)
    }

    func testBufferSizeLatencyCalculation() {
        let latency = DirectMonitoringConfig.BufferSize.low.latencyMs(sampleRate: 48000)
        let expected = 128.0 / 48000.0 * 1000.0
        XCTAssertEqual(latency, expected, accuracy: 0.001)
    }
}

// MARK: - LatencyCompensation Tests

final class LatencyCompensationTests: XCTestCase {

    func testDefaultValues() {
        let comp = LatencyCompensation()
        XCTAssertEqual(comp.inputLatency, 0)
        XCTAssertEqual(comp.outputLatency, 0)
        XCTAssertEqual(comp.bluetoothLatency, 0)
        XCTAssertEqual(comp.processingLatency, 0)
        XCTAssertEqual(comp.networkLatency, 0)
    }

    func testTotalLatency() {
        var comp = LatencyCompensation()
        comp.inputLatency = 5
        comp.outputLatency = 5
        comp.bluetoothLatency = 20
        comp.processingLatency = 3
        XCTAssertEqual(comp.totalLatency, 33)
    }

    func testNetworkLatencyExcludedFromTotal() {
        var comp = LatencyCompensation()
        comp.networkLatency = 100
        XCTAssertEqual(comp.totalLatency, 0)
    }

    func testCompensationSamples() {
        var comp = LatencyCompensation()
        comp.inputLatency = 10
        comp.outputLatency = 10
        let samples = comp.compensationSamples(sampleRate: 48000)
        XCTAssertEqual(samples, 960)
    }

    func testIsRealtimeAcceptableTrue() {
        var comp = LatencyCompensation()
        comp.inputLatency = 5
        comp.outputLatency = 5
        XCTAssertTrue(comp.isRealtimeAcceptable)
    }

    func testIsRealtimeAcceptableFalse() {
        var comp = LatencyCompensation()
        comp.inputLatency = 10
        comp.outputLatency = 10
        comp.bluetoothLatency = 5
        XCTAssertFalse(comp.isRealtimeAcceptable)
    }
}

// MARK: - AudioRoute Tests

final class AudioRouteTests: XCTestCase {

    func testInternalDescription() {
        let route = AudioRoute(
            name: "Test", inputDevice: nil, outputDevice: nil,
            isWired: true, latency: LatencyCompensation(), isActive: true
        )
        XCTAssertEqual(route.description, "Internal")
    }

    func testIdentifiable() {
        let route = AudioRoute(
            name: "Test", inputDevice: nil, outputDevice: nil,
            isWired: true, latency: LatencyCompensation(), isActive: false
        )
        XCTAssertNotNil(route.id)
    }
}

#endif

// MARK: - BreakSlice Tests

final class BreakSliceTests: XCTestCase {

    func testInit() {
        let slice = BreakSlice(start: 0, end: 1000, index: 0)
        XCTAssertEqual(slice.startSample, 0)
        XCTAssertEqual(slice.endSample, 1000)
        XCTAssertEqual(slice.originalIndex, 0)
    }

    func testDefaultValues() {
        let slice = BreakSlice(start: 0, end: 1000, index: 0)
        XCTAssertEqual(slice.pitch, 0.0)
        XCTAssertEqual(slice.gain, 1.0)
        XCTAssertEqual(slice.pan, 0.0)
        XCTAssertFalse(slice.reverse)
        XCTAssertFalse(slice.mute)
        XCTAssertEqual(slice.stretchFactor, 1.0)
        XCTAssertEqual(slice.attack, 0.0)
        XCTAssertEqual(slice.decay, 0.0)
    }

    func testLengthSamples() {
        let slice = BreakSlice(start: 100, end: 500, index: 0)
        XCTAssertEqual(slice.lengthSamples, 400)
    }

    func testIdentifiable() {
        let slice = BreakSlice(start: 0, end: 1000, index: 0)
        XCTAssertNotNil(slice.id)
    }

    func testMutableProperties() {
        var slice = BreakSlice(start: 0, end: 100, index: 0)
        slice.pitch = 12.0
        slice.gain = 0.5
        slice.reverse = true
        slice.mute = true
        XCTAssertEqual(slice.pitch, 12.0)
        XCTAssertEqual(slice.gain, 0.5)
        XCTAssertTrue(slice.reverse)
        XCTAssertTrue(slice.mute)
    }
}

// MARK: - ChopperPatternStep Tests

final class ChopperPatternStepTests: XCTestCase {

    func testInit() {
        let step = ChopperPatternStep(sliceIndex: 3, velocity: 0.8)
        XCTAssertEqual(step.sliceIndex, 3)
        XCTAssertEqual(step.velocity, 0.8)
        XCTAssertEqual(step.pitch, 0)
        XCTAssertFalse(step.reverse)
        XCTAssertNil(step.roll)
        XCTAssertEqual(step.probability, 1.0)
    }

    func testRest() {
        let rest = ChopperPatternStep.rest()
        XCTAssertNil(rest.sliceIndex)
        XCTAssertEqual(rest.velocity, 0)
    }

    func testRollTypeCaseCount() {
        XCTAssertEqual(ChopperPatternStep.RollType.allCases.count, 6)
    }

    func testRollTypeDivisions() {
        XCTAssertEqual(ChopperPatternStep.RollType.none.divisions, 1)
        XCTAssertEqual(ChopperPatternStep.RollType.r2.divisions, 2)
        XCTAssertEqual(ChopperPatternStep.RollType.r3.divisions, 3)
        XCTAssertEqual(ChopperPatternStep.RollType.r4.divisions, 4)
        XCTAssertEqual(ChopperPatternStep.RollType.r6.divisions, 6)
        XCTAssertEqual(ChopperPatternStep.RollType.r8.divisions, 8)
    }

    func testRollTypeRawValues() {
        XCTAssertEqual(ChopperPatternStep.RollType.none.rawValue, "None")
        XCTAssertEqual(ChopperPatternStep.RollType.r2.rawValue, "1/2")
        XCTAssertEqual(ChopperPatternStep.RollType.r3.rawValue, "1/3")
        XCTAssertEqual(ChopperPatternStep.RollType.r4.rawValue, "1/4")
        XCTAssertEqual(ChopperPatternStep.RollType.r6.rawValue, "1/6")
        XCTAssertEqual(ChopperPatternStep.RollType.r8.rawValue, "1/8")
    }
}

// MARK: - ChopPattern Tests

final class ChopPatternTests: XCTestCase {

    func testInit() {
        let pattern = ChopPattern(name: "Test", length: 8)
        XCTAssertEqual(pattern.name, "Test")
        XCTAssertEqual(pattern.length, 8)
        XCTAssertEqual(pattern.steps.count, 8)
        XCTAssertEqual(pattern.stepsPerBar, 16)
        XCTAssertEqual(pattern.swing, 0.0)
    }

    func testFromIndices() {
        let pattern = ChopPattern.fromIndices([0, 1, nil, 3], name: "Custom")
        XCTAssertEqual(pattern.name, "Custom")
        XCTAssertEqual(pattern.steps.count, 4)
        XCTAssertEqual(pattern.steps[0].sliceIndex, 0)
        XCTAssertNil(pattern.steps[2].sliceIndex)
    }

    func testDefaultCyclesSlices() {
        let pattern = ChopPattern(name: "T", length: 16)
        XCTAssertEqual(pattern.steps[0].sliceIndex, 0)
        XCTAssertEqual(pattern.steps[7].sliceIndex, 7)
        XCTAssertEqual(pattern.steps[8].sliceIndex, 0)
    }
}

// MARK: - StretchAlgorithm Tests

final class StretchAlgorithmTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(StretchAlgorithm.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(StretchAlgorithm.resample.rawValue, "Resample")
        XCTAssertEqual(StretchAlgorithm.repitch.rawValue, "Repitch")
        XCTAssertEqual(StretchAlgorithm.granular.rawValue, "Granular")
        XCTAssertEqual(StretchAlgorithm.phaseVocoder.rawValue, "Phase Vocoder")
    }

    func testDescriptionsNotEmpty() {
        for algo in StretchAlgorithm.allCases {
            XCTAssertFalse(algo.description.isEmpty)
        }
    }
}

// MARK: - ShuffleAlgorithm Tests

final class ShuffleAlgorithmTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(ShuffleAlgorithm.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(ShuffleAlgorithm.random.rawValue, "Random")
        XCTAssertEqual(ShuffleAlgorithm.reverse.rawValue, "Reverse")
        XCTAssertEqual(ShuffleAlgorithm.everyOther.rawValue, "Every Other")
        XCTAssertEqual(ShuffleAlgorithm.pairs.rawValue, "Swap Pairs")
        XCTAssertEqual(ShuffleAlgorithm.thirds.rawValue, "Rotate Thirds")
        XCTAssertEqual(ShuffleAlgorithm.scramble.rawValue, "Scramble")
        XCTAssertEqual(ShuffleAlgorithm.mirror.rawValue, "Mirror")
        XCTAssertEqual(ShuffleAlgorithm.stutter.rawValue, "Stutter")
    }

    func testReverseApply() {
        let result = ShuffleAlgorithm.reverse.apply(to: [0, 1, 2, 3])
        XCTAssertEqual(result, [3, 2, 1, 0])
    }

    func testEveryOtherApply() {
        let result = ShuffleAlgorithm.everyOther.apply(to: [0, 1, 2, 3])
        XCTAssertEqual(result, [1, 0, 3, 2])
    }

    func testMirrorApply() {
        let result = ShuffleAlgorithm.mirror.apply(to: [0, 1, 2, 3])
        XCTAssertEqual(result, [0, 1, 2, 3])
    }

    func testStutterApply() {
        let result = ShuffleAlgorithm.stutter.apply(to: [0, 1, 2, 3])
        XCTAssertEqual(result, [0, 0, 1, 1])
    }

    func testThirdsApply() {
        let result = ShuffleAlgorithm.thirds.apply(to: [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(result, [1, 2, 0, 4, 5, 3])
    }

    func testRandomPreservesElements() {
        let input = [0, 1, 2, 3, 4, 5, 6, 7]
        let result = ShuffleAlgorithm.random.apply(to: input)
        XCTAssertEqual(result.count, input.count)
        XCTAssertEqual(result.sorted(), input)
    }
}

// MARK: - NeveTransformerSaturation Tests

final class NeveTransformerSaturationTests: XCTestCase {

    func testDefaultParameters() {
        let neve = NeveTransformerSaturation()
        XCTAssertEqual(neve.drive, 30.0)
        XCTAssertEqual(neve.texture, 50.0)
        XCTAssertEqual(neve.silk, 50.0)
        XCTAssertEqual(neve.silkMode, .red)
    }

    func testProcessReturnsCorrectLength() {
        let neve = NeveTransformerSaturation(sampleRate: 48000)
        let input = [Float](repeating: 0.5, count: 1024)
        let output = neve.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testProcessSilenceReturnsSilence() {
        let neve = NeveTransformerSaturation(sampleRate: 48000)
        let input = [Float](repeating: 0.0, count: 512)
        let output = neve.process(input)
        for sample in output {
            XCTAssertEqual(sample, 0.0, accuracy: 0.001)
        }
    }

    func testSilkModeCaseCount() {
        XCTAssertEqual(NeveTransformerSaturation.SilkMode.allCases.count, 2)
    }

    func testSilkModeRawValues() {
        XCTAssertEqual(NeveTransformerSaturation.SilkMode.red.rawValue, "Red")
        XCTAssertEqual(NeveTransformerSaturation.SilkMode.blue.rawValue, "Blue")
    }
}

// MARK: - NeveInductorEQ Tests

final class NeveInductorEQTests: XCTestCase {

    func testLowFreqCaseCount() {
        XCTAssertEqual(NeveInductorEQ.LowFreq.allCases.count, 4)
    }

    func testLowFreqRawValues() {
        XCTAssertEqual(NeveInductorEQ.LowFreq.hz35.rawValue, 35.0)
        XCTAssertEqual(NeveInductorEQ.LowFreq.hz60.rawValue, 60.0)
        XCTAssertEqual(NeveInductorEQ.LowFreq.hz110.rawValue, 110.0)
        XCTAssertEqual(NeveInductorEQ.LowFreq.hz220.rawValue, 220.0)
    }

    func testHighFreqCaseCount() {
        XCTAssertEqual(NeveInductorEQ.HighFreq.allCases.count, 2)
    }

    func testHighFreqRawValues() {
        XCTAssertEqual(NeveInductorEQ.HighFreq.khz12.rawValue, 12000.0)
        XCTAssertEqual(NeveInductorEQ.HighFreq.khz16.rawValue, 16000.0)
    }

    func testMidFreqCaseCount() {
        XCTAssertEqual(NeveInductorEQ.MidFreq.allCases.count, 6)
    }

    func testMidFreqRawValues() {
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz360.rawValue, 360.0)
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz700.rawValue, 700.0)
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz1k6.rawValue, 1600.0)
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz3k2.rawValue, 3200.0)
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz4k8.rawValue, 4800.0)
        XCTAssertEqual(NeveInductorEQ.MidFreq.hz7k2.rawValue, 7200.0)
    }

    func testProcessFlatReturnsOriginal() {
        let eq = NeveInductorEQ(sampleRate: 48000)
        eq.lowGain = 0.0
        eq.midGain = 0.0
        eq.highGain = 0.0
        let input = [Float](repeating: 0.5, count: 256)
        let output = eq.process(input)
        XCTAssertEqual(output.count, input.count)
        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i], accuracy: 0.01)
        }
    }
}

// MARK: - NeveFeedbackCompressor Tests

final class NeveFeedbackCompressorTests: XCTestCase {

    func testAttackTimeCaseCount() {
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.allCases.count, 6)
    }

    func testAttackTimeRawValues() {
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.fast1.rawValue, 1.5)
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.fast2.rawValue, 3.0)
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.medium1.rawValue, 6.0)
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.medium2.rawValue, 12.0)
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.slow1.rawValue, 24.0)
        XCTAssertEqual(NeveFeedbackCompressor.AttackTime.slow2.rawValue, 48.0)
    }

    func testReleaseTimeCaseCount() {
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.allCases.count, 6)
    }

    func testReleaseTimeRawValues() {
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.fast1.rawValue, 100.0)
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.fast2.rawValue, 200.0)
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.medium1.rawValue, 400.0)
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.medium2.rawValue, 800.0)
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.slow1.rawValue, 1200.0)
        XCTAssertEqual(NeveFeedbackCompressor.ReleaseTime.auto.rawValue, 0.0)
    }

    func testDefaultParameters() {
        let comp = NeveFeedbackCompressor()
        XCTAssertEqual(comp.threshold, -10.0)
        XCTAssertEqual(comp.ratio, 2.0)
        XCTAssertEqual(comp.attack, .medium1)
        XCTAssertEqual(comp.release, .medium1)
        XCTAssertEqual(comp.makeupGain, 0.0)
        XCTAssertEqual(comp.recovery, 50.0)
        XCTAssertTrue(comp.stereoLink)
    }

    func testProcessReturnsCorrectLength() {
        let comp = NeveFeedbackCompressor(sampleRate: 48000)
        let input = [Float](repeating: 0.3, count: 512)
        let output = comp.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testGetGainReductionInitiallyZero() {
        let comp = NeveFeedbackCompressor()
        XCTAssertEqual(comp.getGainReduction(), 0.0)
    }
}

// MARK: - NeveMasteringChain Tests

final class NeveMasteringChainTests: XCTestCase {

    func testInit() {
        let chain = NeveMasteringChain(sampleRate: 48000)
        XCTAssertFalse(chain.bypassed)
        XCTAssertFalse(chain.inputTransformerBypassed)
        XCTAssertFalse(chain.eqBypassed)
        XCTAssertFalse(chain.compressorBypassed)
        XCTAssertFalse(chain.outputTransformerBypassed)
    }

    func testBypassReturnsInput() {
        let chain = NeveMasteringChain()
        chain.bypassed = true
        let input: [Float] = [0.1, 0.2, 0.3, 0.4]
        let output = chain.process(input)
        XCTAssertEqual(output, input)
    }

    func testProcessReturnsCorrectLength() {
        let chain = NeveMasteringChain()
        let input = [Float](repeating: 0.5, count: 1024)
        let output = chain.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testMasteringDefaultsApplied() {
        let chain = NeveMasteringChain()
        XCTAssertEqual(chain.inputTransformer.drive, 25.0)
        XCTAssertEqual(chain.eq.lowFreq, .hz60)
        XCTAssertEqual(chain.compressor.ratio, 2.0)
        XCTAssertEqual(chain.outputTransformer.silkMode, .red)
    }

    func testWarmPreset() {
        let chain = NeveMasteringChain()
        chain.applyWarmPreset()
        XCTAssertEqual(chain.inputTransformer.drive, 35.0)
        XCTAssertEqual(chain.inputTransformer.silkMode, .red)
        XCTAssertEqual(chain.eq.lowGain, 2.0)
        XCTAssertEqual(chain.compressor.ratio, 1.5)
    }

    func testTransparentPreset() {
        let chain = NeveMasteringChain()
        chain.applyTransparentPreset()
        XCTAssertEqual(chain.inputTransformer.drive, 15.0)
        XCTAssertEqual(chain.eq.lowGain, 0.0)
        XCTAssertEqual(chain.eq.highGain, 0.0)
    }

    func testPunchyPreset() {
        let chain = NeveMasteringChain()
        chain.applyPunchyPreset()
        XCTAssertEqual(chain.inputTransformer.drive, 45.0)
        XCTAssertEqual(chain.compressor.ratio, 4.0)
        XCTAssertEqual(chain.compressor.attack, .fast2)
    }
}

// MARK: - LauncherClip Tests

final class LauncherClipTests: XCTestCase {

    func testDefaultInit() {
        let clip = LauncherClip()
        XCTAssertEqual(clip.name, "New Clip")
        XCTAssertEqual(clip.color, .blue)
        XCTAssertEqual(clip.type, .empty)
        XCTAssertEqual(clip.state, .stopped)
        XCTAssertTrue(clip.loopEnabled)
        XCTAssertEqual(clip.duration, 4.0)
        XCTAssertEqual(clip.warpMode, .beats)
        XCTAssertEqual(clip.quantization, .bar1)
        XCTAssertEqual(clip.velocity, 1.0)
        XCTAssertNil(clip.followAction)
    }

    func testCodableRoundTrip() throws {
        let clip = LauncherClip(name: "Test", color: .red, type: .audio, duration: 8.0)
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(LauncherClip.self, from: data)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.color, .red)
        XCTAssertEqual(decoded.type, .audio)
        XCTAssertEqual(decoded.duration, 8.0)
    }

    func testClipTypeCaseCount() {
        XCTAssertEqual(LauncherClip.ClipType.allCases.count, 3)
    }

    func testClipTypeRawValues() {
        XCTAssertEqual(LauncherClip.ClipType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherClip.ClipType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherClip.ClipType.empty.rawValue, "Empty")
    }

    func testClipStateRawValues() {
        XCTAssertEqual(LauncherClip.ClipState.stopped.rawValue, "Stopped")
        XCTAssertEqual(LauncherClip.ClipState.queued.rawValue, "Queued")
        XCTAssertEqual(LauncherClip.ClipState.playing.rawValue, "Playing")
        XCTAssertEqual(LauncherClip.ClipState.recording.rawValue, "Recording")
    }

    func testClipColorCaseCount() {
        XCTAssertEqual(LauncherClip.ClipColor.allCases.count, 10)
    }

    func testWarpModeCaseCount() {
        XCTAssertEqual(LauncherClip.WarpMode.allCases.count, 6)
    }

    func testWarpModeRawValues() {
        XCTAssertEqual(LauncherClip.WarpMode.beats.rawValue, "Beats")
        XCTAssertEqual(LauncherClip.WarpMode.tones.rawValue, "Tones")
        XCTAssertEqual(LauncherClip.WarpMode.texture.rawValue, "Texture")
        XCTAssertEqual(LauncherClip.WarpMode.repitch.rawValue, "Re-Pitch")
        XCTAssertEqual(LauncherClip.WarpMode.complex.rawValue, "Complex")
        XCTAssertEqual(LauncherClip.WarpMode.complexPro.rawValue, "Complex Pro")
    }

    func testQuantizationCaseCount() {
        XCTAssertEqual(LauncherClip.Quantization.allCases.count, 8)
    }

    func testQuantizationBeats() {
        XCTAssertEqual(LauncherClip.Quantization.none.beats, 0)
        XCTAssertEqual(LauncherClip.Quantization.bar1.beats, 4)
        XCTAssertEqual(LauncherClip.Quantization.bar2.beats, 8)
        XCTAssertEqual(LauncherClip.Quantization.bar4.beats, 16)
        XCTAssertEqual(LauncherClip.Quantization.bar8.beats, 32)
        XCTAssertEqual(LauncherClip.Quantization.beat1.beats, 1)
        XCTAssertEqual(LauncherClip.Quantization.beat1_2.beats, 0.5)
        XCTAssertEqual(LauncherClip.Quantization.beat1_4.beats, 0.25)
    }

    func testFollowActionCaseCount() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.allCases.count, 9)
    }

    func testFollowActionRawValues() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.none.rawValue, "None")
        XCTAssertEqual(LauncherClip.FollowAction.Action.stop.rawValue, "Stop")
        XCTAssertEqual(LauncherClip.FollowAction.Action.playAgain.rawValue, "Play Again")
        XCTAssertEqual(LauncherClip.FollowAction.Action.previous.rawValue, "Previous")
        XCTAssertEqual(LauncherClip.FollowAction.Action.next.rawValue, "Next")
        XCTAssertEqual(LauncherClip.FollowAction.Action.first.rawValue, "First")
        XCTAssertEqual(LauncherClip.FollowAction.Action.last.rawValue, "Last")
        XCTAssertEqual(LauncherClip.FollowAction.Action.any.rawValue, "Any")
        XCTAssertEqual(LauncherClip.FollowAction.Action.other.rawValue, "Other")
    }
}

// MARK: - LauncherTrack Tests

final class LauncherTrackTests: XCTestCase {

    func testDefaultInit() {
        let track = LauncherTrack()
        XCTAssertEqual(track.name, "Track")
        XCTAssertEqual(track.type, .audio)
        XCTAssertEqual(track.clips.count, 8)
        XCTAssertEqual(track.volume, 0.8)
        XCTAssertEqual(track.pan, 0)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSoloed)
        XCTAssertFalse(track.isArmed)
        XCTAssertEqual(track.sendLevels, [0, 0])
    }

    func testTrackTypeCaseCount() {
        XCTAssertEqual(LauncherTrack.TrackType.allCases.count, 5)
    }

    func testTrackTypeRawValues() {
        XCTAssertEqual(LauncherTrack.TrackType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherTrack.TrackType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherTrack.TrackType.group.rawValue, "Group")
        XCTAssertEqual(LauncherTrack.TrackType.return_.rawValue, "Return")
        XCTAssertEqual(LauncherTrack.TrackType.master.rawValue, "Master")
    }

    func testCodableRoundTrip() throws {
        let track = LauncherTrack(name: "Bass", type: .audio, clipCount: 2)
        let data = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(LauncherTrack.self, from: data)
        XCTAssertEqual(decoded.name, "Bass")
        XCTAssertEqual(decoded.clips.count, 2)
    }
}

// MARK: - LauncherScene Tests

final class LauncherSceneTests: XCTestCase {

    func testDefaultInit() {
        let scene = LauncherScene()
        XCTAssertEqual(scene.name, "Scene")
        XCTAssertEqual(scene.color, .gray)
        XCTAssertNil(scene.tempo)
        XCTAssertNil(scene.timeSignature)
    }

    func testCodableRoundTrip() throws {
        var scene = LauncherScene(name: "Verse", color: .green)
        scene.tempo = 128.0
        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(LauncherScene.self, from: data)
        XCTAssertEqual(decoded.name, "Verse")
        XCTAssertEqual(decoded.color, .green)
        XCTAssertEqual(decoded.tempo, 128.0)
    }

    func testTimeSignatureCodable() throws {
        let ts = LauncherScene.TimeSignature(numerator: 3, denominator: 4)
        let data = try JSONEncoder().encode(ts)
        let decoded = try JSONDecoder().decode(LauncherScene.TimeSignature.self, from: data)
        XCTAssertEqual(decoded.numerator, 3)
        XCTAssertEqual(decoded.denominator, 4)
    }
}

// MARK: - SequencerPattern Tests

final class SequencerPatternTests: XCTestCase {

    func testDefaultInit() {
        let pattern = SequencerPattern()
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<VisualStepSequencer.stepCount {
                XCTAssertFalse(pattern.isActive(channel: channel, step: step))
            }
        }
    }

    func testToggle() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))
        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))
    }

    func testSetVelocity() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.7)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.7, accuracy: 0.001)
    }

    func testVelocityClamping() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 5.0)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0)
        pattern.setVelocity(channel: .visual1, step: 0, velocity: -1.0)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.0)
    }

    func testClearChannel() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .visual1, step: 4)
        pattern.clearChannel(.visual1)
        for step in 0..<VisualStepSequencer.stepCount {
            XCTAssertFalse(pattern.isActive(channel: .visual1, step: step))
        }
    }

    func testOutOfBoundsStep() {
        let pattern = SequencerPattern()
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 999))
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 999), 0)
    }

    func testEquatable() {
        XCTAssertEqual(SequencerPattern(), SequencerPattern())
    }

    func testCodableRoundTrip() throws {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .lighting, step: 8)
        let data = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(SequencerPattern.self, from: data)
        XCTAssertEqual(decoded, pattern)
    }

    func testStepDataDefaults() {
        let step = SequencerPattern.StepData()
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 1.0)
        XCTAssertEqual(step.parameter, 0.5)
    }
}

// MARK: - BioModulationState Tests

final class BioModulationStateTests: XCTestCase {

    func testDefaultValues() {
        let state = BioModulationState()
        XCTAssertEqual(state.coherence, 0.5)
        XCTAssertEqual(state.heartRate, 70.0)
        XCTAssertEqual(state.hrvVariability, 0.5)
        XCTAssertEqual(state.skipProbability, 0.0)
        XCTAssertFalse(state.tempoLockEnabled)
    }

    func testMutableProperties() {
        var state = BioModulationState()
        state.coherence = 0.9
        state.heartRate = 85.0
        state.tempoLockEnabled = true
        XCTAssertEqual(state.coherence, 0.9)
        XCTAssertTrue(state.tempoLockEnabled)
    }
}

// MARK: - SequencerPreset Tests

final class SequencerPresetTests: XCTestCase {

    func testFourOnFloor() {
        let preset = SequencerPreset.fourOnFloor
        XCTAssertEqual(preset.id, "four_on_floor")
        XCTAssertEqual(preset.name, "Four on Floor")
        XCTAssertEqual(preset.bpm, 120)
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 4))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 8))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 12))
    }

    func testBreakbeat() {
        let preset = SequencerPreset.breakbeat
        XCTAssertEqual(preset.id, "breakbeat")
        XCTAssertEqual(preset.bpm, 90)
    }

    func testAmbient() {
        let preset = SequencerPreset.ambient
        XCTAssertEqual(preset.id, "ambient")
        XCTAssertEqual(preset.bpm, 70)
    }

    func testBioReactive() {
        let preset = SequencerPreset.bioReactive
        XCTAssertEqual(preset.id, "bio_reactive")
        XCTAssertEqual(preset.bpm, 100)
    }

    func testMinimal() {
        let preset = SequencerPreset.minimal
        XCTAssertEqual(preset.id, "minimal")
        XCTAssertEqual(preset.bpm, 110)
    }

    func testPresetsCount() {
        XCTAssertEqual(VisualStepSequencer.presets.count, 5)
    }

    func testAllPresetsHaveUniqueIds() {
        let ids = VisualStepSequencer.presets.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}

// MARK: - VisualStepSequencer.Channel Tests

final class SequencerChannelTests: XCTestCase {

    func testChannelCaseCount() {
        XCTAssertEqual(VisualStepSequencer.Channel.allCases.count, 8)
    }

    func testChannelRawValues() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.rawValue, 0)
        XCTAssertEqual(VisualStepSequencer.Channel.visual2.rawValue, 1)
        XCTAssertEqual(VisualStepSequencer.Channel.visual3.rawValue, 2)
        XCTAssertEqual(VisualStepSequencer.Channel.visual4.rawValue, 3)
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.rawValue, 4)
        XCTAssertEqual(VisualStepSequencer.Channel.effect1.rawValue, 5)
        XCTAssertEqual(VisualStepSequencer.Channel.effect2.rawValue, 6)
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.rawValue, 7)
    }

    func testChannelNames() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.name, "Visual A")
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.name, "Lighting")
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.name, "Bio Trigger")
    }

    func testChannelIdentifiable() {
        for channel in VisualStepSequencer.Channel.allCases {
            XCTAssertEqual(channel.id, channel.rawValue)
        }
    }

    func testConstants() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
        XCTAssertEqual(VisualStepSequencer.channelCount, 8)
        XCTAssertEqual(VisualStepSequencer.bpmRange, 60...180)
    }
}
