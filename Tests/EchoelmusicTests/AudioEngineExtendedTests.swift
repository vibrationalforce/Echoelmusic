// AudioEngineExtendedTests.swift
// Echoelmusic — Comprehensive tests for Audio Engine utilities, Bluetooth, Link,
// Graph Builder, Breakbeat Chopper, Clip Launcher, and Visual Step Sequencer types
//
// Tests value types, enums, structs, and data models from:
//   - Audio/AudioGraphBuilder.swift
//   - Audio/AbletonLinkClient.swift
//   - Audio/UltraLowLatencyBluetoothEngine.swift
//   - Audio/Effects/BreakbeatChopper.swift
//   - Performance/ClipLauncherGrid.swift
//   - Sequencer/VisualStepSequencer.swift

import XCTest
@testable import Echoelmusic
import Foundation

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

    func testTypicalLatencyPositive() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertGreaterThan(codec.typicalLatency, 0)
        }
    }

    func testMaxBitratePositive() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertGreaterThan(codec.maxBitrate, 0)
        }
    }

    func testSupportedSampleRatesNotEmpty() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertFalse(codec.supportedSampleRates.isEmpty)
        }
    }

    func testSBCHighestLatency() {
        XCTAssertEqual(BluetoothAudioCodec.sbc.typicalLatency, 200)
    }

    func testLC3PlusLowestLatency() {
        XCTAssertEqual(BluetoothAudioCodec.lc3plus.typicalLatency, 15)
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

    func testIdentifiable() {
        for codec in BluetoothAudioCodec.allCases {
            XCTAssertEqual(codec.id, codec.rawValue)
        }
    }

    func testLDACHighestBitrate() {
        let maxBitrate = BluetoothAudioCodec.allCases.map { $0.maxBitrate }.max()
        XCTAssertEqual(maxBitrate, BluetoothAudioCodec.ldac.maxBitrate)
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

    func testIconNotEmpty() {
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
}

#endif

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

    func testEquatable() {
        let a = LinkSessionState(tempo: 120.0)
        let b = LinkSessionState(tempo: 120.0)
        // Note: timestamps differ, so these won't be equal
        // but the tempo/quantum should match
        XCTAssertEqual(a.tempo, b.tempo)
        XCTAssertEqual(a.quantum, b.quantum)
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

    func testUpdateBeat() {
        var state = LinkSessionState(tempo: 120.0)
        // Set timestamp to "1 second ago" (1_000_000 microseconds)
        state.timestamp = UInt64(CFAbsoluteTimeGetCurrent() * 1_000_000) - 1_000_000
        state.updateBeat()
        // At 120 BPM, 1 second = 2 beats
        XCTAssertEqual(state.beat, 2.0, accuracy: 0.5)
    }
}

// MARK: - LinkPeer Tests

final class LinkPeerTests: XCTestCase {

    func testInit() {
        let peer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100",
            port: 20808,
            name: "Ableton",
            tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent()
        )
        XCTAssertEqual(peer.address, "192.168.1.100")
        XCTAssertEqual(peer.port, 20808)
        XCTAssertEqual(peer.name, "Ableton")
        XCTAssertEqual(peer.tempo, 120.0)
    }

    func testIsStale() {
        let stalePeer = LinkPeer(
            id: UUID(),
            address: "10.0.0.1",
            port: 20808,
            name: "Old",
            tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent() - 10.0
        )
        XCTAssertTrue(stalePeer.isStale)
    }

    func testIsNotStale() {
        let freshPeer = LinkPeer(
            id: UUID(),
            address: "10.0.0.2",
            port: 20808,
            name: "Fresh",
            tempo: 120.0,
            lastSeen: CFAbsoluteTimeGetCurrent()
        )
        XCTAssertFalse(freshPeer.isStale)
    }

    func testEquatable() {
        let id = UUID()
        let a = LinkPeer(id: id, address: "1.1.1.1", port: 1, name: "A", tempo: 120, lastSeen: 0)
        let b = LinkPeer(id: id, address: "1.1.1.1", port: 1, name: "A", tempo: 120, lastSeen: 0)
        XCTAssertEqual(a, b)
    }
}

// MARK: - BreakSlice Tests

final class BreakSliceTests: XCTestCase {

    func testInit() {
        let slice = BreakSlice(start: 0, end: 44100, index: 0)
        XCTAssertEqual(slice.startSample, 0)
        XCTAssertEqual(slice.endSample, 44100)
        XCTAssertEqual(slice.originalIndex, 0)
        XCTAssertEqual(slice.pitch, 0.0)
        XCTAssertEqual(slice.gain, 1.0)
        XCTAssertEqual(slice.pan, 0.0)
        XCTAssertFalse(slice.reverse)
        XCTAssertFalse(slice.mute)
        XCTAssertEqual(slice.stretchFactor, 1.0)
    }

    func testLengthSamples() {
        let slice = BreakSlice(start: 1000, end: 5000, index: 2)
        XCTAssertEqual(slice.lengthSamples, 4000)
    }

    func testEquatable() {
        var a = BreakSlice(start: 0, end: 100, index: 0)
        var b = a
        b.pitch = 2.0
        XCTAssertNotEqual(a, b)
        a.pitch = 2.0
        XCTAssertEqual(a.startSample, b.startSample)
    }

    func testMutableProperties() {
        var slice = BreakSlice(start: 0, end: 100, index: 0)
        slice.pitch = 12.0
        slice.gain = 0.5
        slice.pan = -1.0
        slice.reverse = true
        slice.mute = true
        XCTAssertEqual(slice.pitch, 12.0)
        XCTAssertEqual(slice.gain, 0.5)
        XCTAssertEqual(slice.pan, -1.0)
        XCTAssertTrue(slice.reverse)
        XCTAssertTrue(slice.mute)
    }
}

// MARK: - ChopperPatternStep Tests

final class ChopperPatternStepTests: XCTestCase {

    func testInit() {
        let step = ChopperPatternStep(sliceIndex: 3)
        XCTAssertEqual(step.sliceIndex, 3)
        XCTAssertEqual(step.velocity, 1.0)
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

    func testRollTypeDivisions() {
        XCTAssertEqual(ChopperPatternStep.RollType.none.divisions, 1)
        XCTAssertEqual(ChopperPatternStep.RollType.r2.divisions, 2)
        XCTAssertEqual(ChopperPatternStep.RollType.r3.divisions, 3)
        XCTAssertEqual(ChopperPatternStep.RollType.r4.divisions, 4)
        XCTAssertEqual(ChopperPatternStep.RollType.r6.divisions, 6)
        XCTAssertEqual(ChopperPatternStep.RollType.r8.divisions, 8)
    }

    func testRollTypeCaseCount() {
        XCTAssertEqual(ChopperPatternStep.RollType.allCases.count, 6)
    }

    func testRollTypeRawValues() {
        XCTAssertEqual(ChopperPatternStep.RollType.none.rawValue, "None")
        XCTAssertEqual(ChopperPatternStep.RollType.r2.rawValue, "1/2")
        XCTAssertEqual(ChopperPatternStep.RollType.r8.rawValue, "1/8")
    }
}

// MARK: - ChopPattern Tests

final class ChopPatternTests: XCTestCase {

    func testInit() {
        let pattern = ChopPattern(name: "Amen Break", length: 16)
        XCTAssertEqual(pattern.name, "Amen Break")
        XCTAssertEqual(pattern.length, 16)
        XCTAssertEqual(pattern.steps.count, 16)
        XCTAssertEqual(pattern.stepsPerBar, 16)
        XCTAssertEqual(pattern.swing, 0.0)
    }

    func testDefaultLength() {
        let pattern = ChopPattern(name: "Test")
        XCTAssertEqual(pattern.length, 16)
    }

    func testFromIndices() {
        let indices: [Int?] = [0, 1, nil, 3, 2, nil, 1, 0]
        let pattern = ChopPattern.fromIndices(indices, name: "Custom")
        XCTAssertEqual(pattern.name, "Custom")
        XCTAssertEqual(pattern.steps.count, 8)
        XCTAssertEqual(pattern.steps[0].sliceIndex, 0)
        XCTAssertEqual(pattern.steps[1].sliceIndex, 1)
        XCTAssertNil(pattern.steps[2].sliceIndex)
        XCTAssertEqual(pattern.steps[3].sliceIndex, 3)
    }

    func testStepsCycleSlices() {
        let pattern = ChopPattern(name: "Default", length: 16)
        // Default creates steps that cycle through 8 slices
        XCTAssertEqual(pattern.steps[0].sliceIndex, 0)
        XCTAssertEqual(pattern.steps[7].sliceIndex, 7)
        XCTAssertEqual(pattern.steps[8].sliceIndex, 0) // wraps
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
        XCTAssertEqual(StretchAlgorithm.elastique.rawValue, "Élastique")
    }

    func testDescriptionNotEmpty() {
        for algo in StretchAlgorithm.allCases {
            XCTAssertFalse(algo.description.isEmpty)
        }
    }
}

// MARK: - ShuffleAlgorithm Tests

final class ShuffleAlgorithmTests: XCTestCase {

    func testCaseCount() {
        XCTAssertGreaterThanOrEqual(ShuffleAlgorithm.allCases.count, 1)
    }

    func testRawValuesNotEmpty() {
        for algo in ShuffleAlgorithm.allCases {
            XCTAssertFalse(algo.rawValue.isEmpty)
        }
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
    }

    func testCustomInit() {
        let clip = LauncherClip(name: "Bass Loop", color: .green, type: .audio, duration: 8.0)
        XCTAssertEqual(clip.name, "Bass Loop")
        XCTAssertEqual(clip.color, .green)
        XCTAssertEqual(clip.type, .audio)
        XCTAssertEqual(clip.duration, 8.0)
    }

    func testCodableRoundTrip() throws {
        let clip = LauncherClip(name: "Test Clip", color: .red, type: .midi)
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(LauncherClip.self, from: data)
        XCTAssertEqual(decoded.name, clip.name)
        XCTAssertEqual(decoded.color, clip.color)
        XCTAssertEqual(decoded.type, clip.type)
    }
}

// MARK: - LauncherClip.ClipType Tests

final class LauncherClipTypeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LauncherClip.ClipType.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(LauncherClip.ClipType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherClip.ClipType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherClip.ClipType.empty.rawValue, "Empty")
    }
}

// MARK: - LauncherClip.ClipColor Tests

final class LauncherClipColorTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LauncherClip.ClipColor.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(LauncherClip.ClipColor.red.rawValue, "red")
        XCTAssertEqual(LauncherClip.ClipColor.blue.rawValue, "blue")
        XCTAssertEqual(LauncherClip.ClipColor.white.rawValue, "white")
        XCTAssertEqual(LauncherClip.ClipColor.gray.rawValue, "gray")
    }
}

// MARK: - LauncherClip.WarpMode Tests

final class LauncherWarpModeTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LauncherClip.WarpMode.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(LauncherClip.WarpMode.beats.rawValue, "Beats")
        XCTAssertEqual(LauncherClip.WarpMode.tones.rawValue, "Tones")
        XCTAssertEqual(LauncherClip.WarpMode.texture.rawValue, "Texture")
        XCTAssertEqual(LauncherClip.WarpMode.repitch.rawValue, "Re-Pitch")
        XCTAssertEqual(LauncherClip.WarpMode.complex.rawValue, "Complex")
        XCTAssertEqual(LauncherClip.WarpMode.complexPro.rawValue, "Complex Pro")
    }
}

// MARK: - LauncherClip.Quantization Tests

final class LauncherQuantizationTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(LauncherClip.Quantization.allCases.count, 8)
    }

    func testBeats() {
        XCTAssertEqual(LauncherClip.Quantization.none.beats, 0)
        XCTAssertEqual(LauncherClip.Quantization.bar1.beats, 4)
        XCTAssertEqual(LauncherClip.Quantization.bar2.beats, 8)
        XCTAssertEqual(LauncherClip.Quantization.bar4.beats, 16)
        XCTAssertEqual(LauncherClip.Quantization.bar8.beats, 32)
        XCTAssertEqual(LauncherClip.Quantization.beat1.beats, 1)
        XCTAssertEqual(LauncherClip.Quantization.beat1_2.beats, 0.5)
        XCTAssertEqual(LauncherClip.Quantization.beat1_4.beats, 0.25)
    }
}

// MARK: - LauncherClip.FollowAction Tests

final class LauncherFollowActionTests: XCTestCase {

    func testActionCaseCount() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.allCases.count, 9)
    }

    func testActionRawValues() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.none.rawValue, "None")
        XCTAssertEqual(LauncherClip.FollowAction.Action.stop.rawValue, "Stop")
        XCTAssertEqual(LauncherClip.FollowAction.Action.playAgain.rawValue, "Play Again")
        XCTAssertEqual(LauncherClip.FollowAction.Action.next.rawValue, "Next")
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
        XCTAssertEqual(track.color, .blue)
        XCTAssertEqual(track.sendLevels, [0, 0])
    }

    func testCustomInit() {
        let track = LauncherTrack(name: "Drums", type: .midi, clipCount: 4, color: .orange)
        XCTAssertEqual(track.name, "Drums")
        XCTAssertEqual(track.type, .midi)
        XCTAssertEqual(track.clips.count, 4)
        XCTAssertEqual(track.color, .orange)
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
        XCTAssertEqual(decoded.name, track.name)
        XCTAssertEqual(decoded.type, track.type)
        XCTAssertEqual(decoded.clips.count, track.clips.count)
    }
}

// MARK: - LauncherScene Tests

final class LauncherSceneTests: XCTestCase {

    func testDefaultInit() {
        let scene = LauncherScene()
        XCTAssertEqual(scene.name, "Scene")
        XCTAssertNil(scene.tempo)
        XCTAssertNil(scene.timeSignature)
        XCTAssertEqual(scene.color, .gray)
    }

    func testCustomInit() {
        let scene = LauncherScene(name: "Drop", color: .red)
        XCTAssertEqual(scene.name, "Drop")
        XCTAssertEqual(scene.color, .red)
    }

    func testCodableRoundTrip() throws {
        let scene = LauncherScene(name: "Verse")
        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(LauncherScene.self, from: data)
        XCTAssertEqual(decoded.name, scene.name)
        XCTAssertEqual(decoded.color, scene.color)
    }
}

// MARK: - SequencerPattern Tests

final class SequencerPatternTests: XCTestCase {

    func testDefaultInit() {
        let pattern = SequencerPattern()
        // All steps should be inactive by default
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

    func testVelocity() {
        var pattern = SequencerPattern()
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0)
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.5)
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
        pattern.toggle(channel: .visual1, step: 8)
        pattern.clearChannel(.visual1)
        for step in 0..<VisualStepSequencer.stepCount {
            XCTAssertFalse(pattern.isActive(channel: .visual1, step: step))
        }
    }

    func testOutOfBoundsStep() {
        let pattern = SequencerPattern()
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 100))
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 100), 0)
    }

    func testEquatable() {
        let a = SequencerPattern()
        let b = SequencerPattern()
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .lighting, step: 8)
        let data = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(SequencerPattern.self, from: data)
        XCTAssertEqual(decoded, pattern)
    }
}

// MARK: - SequencerPattern.StepData Tests

final class StepDataTests: XCTestCase {

    func testDefaultInit() {
        let step = SequencerPattern.StepData()
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 1.0)
        XCTAssertEqual(step.parameter, 0.5)
    }

    func testEquatable() {
        let a = SequencerPattern.StepData()
        let b = SequencerPattern.StepData()
        XCTAssertEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        var step = SequencerPattern.StepData()
        step.isActive = true
        step.velocity = 0.7
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequencerPattern.StepData.self, from: data)
        XCTAssertEqual(decoded, step)
    }
}

// MARK: - BioModulationState Tests

final class BioModulationStateTests: XCTestCase {

    func testDefaultInit() {
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
        state.hrvVariability = 0.8
        state.skipProbability = 0.2
        state.tempoLockEnabled = true
        XCTAssertEqual(state.coherence, 0.9)
        XCTAssertEqual(state.heartRate, 85.0)
        XCTAssertEqual(state.hrvVariability, 0.8)
        XCTAssertEqual(state.skipProbability, 0.2)
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
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual2, step: 4))
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

    func testAllPresetsCount() {
        XCTAssertEqual(VisualStepSequencer.presets.count, 5)
    }
}

// MARK: - VisualStepSequencer.Channel Tests

final class SequencerChannelTests: XCTestCase {

    func testCaseCount() {
        XCTAssertEqual(VisualStepSequencer.Channel.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.rawValue, 0)
        XCTAssertEqual(VisualStepSequencer.Channel.visual2.rawValue, 1)
        XCTAssertEqual(VisualStepSequencer.Channel.visual3.rawValue, 2)
        XCTAssertEqual(VisualStepSequencer.Channel.visual4.rawValue, 3)
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.rawValue, 4)
        XCTAssertEqual(VisualStepSequencer.Channel.effect1.rawValue, 5)
        XCTAssertEqual(VisualStepSequencer.Channel.effect2.rawValue, 6)
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.rawValue, 7)
    }

    func testNames() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.name, "Visual A")
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.name, "Lighting")
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.name, "Bio Trigger")
    }

    func testIdentifiable() {
        for channel in VisualStepSequencer.Channel.allCases {
            XCTAssertEqual(channel.id, channel.rawValue)
        }
    }
}

// MARK: - VisualStepSequencer Constants Tests

final class VisualStepSequencerConstantsTests: XCTestCase {

    func testStepCount() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
    }

    func testBPMRange() {
        XCTAssertEqual(VisualStepSequencer.bpmRange.lowerBound, 60)
        XCTAssertEqual(VisualStepSequencer.bpmRange.upperBound, 180)
    }

    func testChannelCount() {
        XCTAssertEqual(VisualStepSequencer.channelCount, 8)
    }
}
