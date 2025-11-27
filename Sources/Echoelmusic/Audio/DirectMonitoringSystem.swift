//
//  DirectMonitoringSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Professional Direct Monitoring with Real-Time Effects
//  Zero-latency input monitoring with effect processing
//  Like UAD Unison, RME TotalMix, or Apogee Control - but with effects!
//

import Foundation
import AVFoundation
import Accelerate
import Combine

/// Professional direct monitoring system with zero-latency effects
@MainActor
class DirectMonitoringSystem: ObservableObject {
    static let shared = DirectMonitoringSystem()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = false
    @Published var monitorInputs: [MonitorInput] = []
    @Published var monitorMode: MonitorMode = .autoLatencyCompensation
    @Published var mixMode: MixMode = .stereo
    @Published var hardwareBufferSize: Int = 64  // samples
    @Published var measuredLatency: Double = 0.0  // milliseconds
    @Published var dspLoad: Double = 0.0  // percentage

    // MARK: - Monitor Input

    struct MonitorInput: Identifiable {
        let id: UUID
        var name: String
        var channel: Int
        var isEnabled: Bool
        var volume: Float  // 0.0 to 1.0
        var pan: Float  // -1.0 (left) to 1.0 (right)
        var muted: Bool
        var solo: Bool
        var phase: Bool  // phase invert
        var effectChain: [MonitorEffect]
        var inputGain: Float  // -inf to +24 dB
        var outputGain: Float
        var peakLevel: Float
        var rmsLevel: Float

        static func create(name: String, channel: Int) -> MonitorInput {
            MonitorInput(
                id: UUID(),
                name: name,
                channel: channel,
                isEnabled: true,
                volume: 0.8,
                pan: 0.0,
                muted: false,
                solo: false,
                phase: false,
                effectChain: [],
                inputGain: 0.0,
                outputGain: 0.0,
                peakLevel: 0.0,
                rmsLevel: 0.0
            )
        }
    }

    // MARK: - Monitor Mode

    enum MonitorMode: String, CaseIterable {
        case autoLatencyCompensation = "Auto (Latency Compensation)"
        case ultraLowLatency = "Ultra-Low Latency"
        case zeroLatencyHardware = "Zero-Latency (Hardware DSP)"
        case custom = "Custom"

        var description: String {
            switch self {
            case .autoLatencyCompensation:
                return "Automatic latency compensation - best for recording"
            case .ultraLowLatency:
                return "Ultra-low latency software monitoring - <5ms typical"
            case .zeroLatencyHardware:
                return "Hardware DSP monitoring - true zero latency"
            case .custom:
                return "Custom monitoring configuration"
            }
        }

        var bufferSize: Int {
            switch self {
            case .autoLatencyCompensation: return 256
            case .ultraLowLatency: return 32
            case .zeroLatencyHardware: return 0  // Hardware
            case .custom: return 64
            }
        }
    }

    // MARK: - Mix Mode

    enum MixMode: String, CaseIterable {
        case stereo = "Stereo"
        case mono = "Mono"
        case mid = "Mid (L+R)"
        case side = "Side (L-R)"
        case left = "Left Only"
        case right = "Right Only"

        func process(_ left: Float, _ right: Float) -> (Float, Float) {
            switch self {
            case .stereo:
                return (left, right)
            case .mono:
                let mono = (left + right) * 0.5
                return (mono, mono)
            case .mid:
                let mid = (left + right) * 0.5
                return (mid, mid)
            case .side:
                let side = (left - right) * 0.5
                return (side, side)
            case .left:
                return (left, left)
            case .right:
                return (right, right)
            }
        }
    }

    // MARK: - Monitor Effects

    enum MonitorEffect: Identifiable, Equatable {
        case eq(bands: [EQBand])
        case compressor(threshold: Float, ratio: Float, attack: Float, release: Float)
        case gate(threshold: Float, ratio: Float, attack: Float, release: Float)
        case reverb(roomSize: Float, damping: Float, mix: Float)
        case delay(time: Float, feedback: Float, mix: Float)
        case chorus(rate: Float, depth: Float, mix: Float)
        case distortion(drive: Float, tone: Float, mix: Float)
        case autoTune(key: String, speed: Float)
        case deEsser(frequency: Float, threshold: Float)
        case exciter(frequency: Float, amount: Float)

        var id: String {
            switch self {
            case .eq: return "eq"
            case .compressor: return "compressor"
            case .gate: return "gate"
            case .reverb: return "reverb"
            case .delay: return "delay"
            case .chorus: return "chorus"
            case .distortion: return "distortion"
            case .autoTune: return "autoTune"
            case .deEsser: return "deEsser"
            case .exciter: return "exciter"
            }
        }

        var name: String {
            switch self {
            case .eq: return "EQ"
            case .compressor: return "Compressor"
            case .gate: return "Gate"
            case .reverb: return "Reverb"
            case .delay: return "Delay"
            case .chorus: return "Chorus"
            case .distortion: return "Distortion"
            case .autoTune: return "Auto-Tune"
            case .deEsser: return "De-Esser"
            case .exciter: return "Exciter"
            }
        }

        static func == (lhs: MonitorEffect, rhs: MonitorEffect) -> Bool {
            return lhs.id == rhs.id
        }
    }

    struct EQBand {
        var frequency: Float  // Hz
        var gain: Float  // dB
        var q: Float  // Quality factor
        var type: EQType

        enum EQType {
            case lowShelf
            case peak
            case highShelf
            case lowPass
            case highPass
            case notch
        }
    }

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var mixerNode: AVAudioMixerNode?
    private var effectNodes: [UUID: [AVAudioNode]] = [:]
    private var processingBuffer: AVAudioPCMBuffer?

    // MARK: - Setup

    func setup() throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw MonitorError.engineInitFailed
        }

        inputNode = engine.inputNode
        mixerNode = AVAudioMixerNode()

        guard let mixer = mixerNode else {
            throw MonitorError.mixerInitFailed
        }

        engine.attach(mixer)

        // Connect input to mixer with ultra-low latency format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        )

        if let input = inputNode, let validFormat = format {
            engine.connect(input, to: mixer, format: validFormat)
            engine.connect(mixer, to: engine.mainMixerNode, format: validFormat)
        }

        // Set hardware buffer size for ultra-low latency
        try setBufferSize(hardwareBufferSize)

        print("🎧 Direct Monitoring System initialized")
    }

    func enable() throws {
        guard !isEnabled else { return }

        if audioEngine == nil {
            try setup()
        }

        guard let engine = audioEngine else {
            throw MonitorError.engineNotInitialized
        }

        // Install tap for level metering and effect processing
        installMonitoringTap()

        try engine.start()
        isEnabled = true

        print("🎧 Direct Monitoring enabled - Latency: \(String(format: "%.2f", measuredLatency))ms")
    }

    func disable() {
        guard isEnabled else { return }

        audioEngine?.stop()
        isEnabled = false

        print("🎧 Direct Monitoring disabled")
    }

    // MARK: - Buffer Size Control

    func setBufferSize(_ samples: Int) throws {
        guard let engine = audioEngine else { return }

        let sampleRate = engine.inputNode.inputFormat(forBus: 0).sampleRate
        let duration = Double(samples) / sampleRate

        // Set hardware I/O buffer duration
        do {
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(duration)
            hardwareBufferSize = samples

            // Update measured latency
            let bufferLatency = (Double(samples) / sampleRate) * 1000.0
            measuredLatency = bufferLatency * 2.0  // Input + Output

            print("🎛️ Buffer size: \(samples) samples (\(String(format: "%.2f", bufferLatency))ms)")
        } catch {
            print("❌ Failed to set buffer size: \(error)")
        }
    }

    // MARK: - Input Management

    func addInput(name: String, channel: Int) {
        let input = MonitorInput.create(name: name, channel: channel)
        monitorInputs.append(input)
        print("➕ Added monitor input: \(name) (Ch \(channel))")
    }

    func removeInput(_ id: UUID) {
        monitorInputs.removeAll { $0.id == id }
        effectNodes.removeValue(forKey: id)
    }

    func updateInput(_ id: UUID, _ update: (inout MonitorInput) -> Void) {
        if let index = monitorInputs.firstIndex(where: { $0.id == id }) {
            update(&monitorInputs[index])
        }
    }

    // MARK: - Effect Chain

    func addEffect(_ effect: MonitorEffect, to inputID: UUID) {
        updateInput(inputID) { input in
            input.effectChain.append(effect)
        }
        rebuildEffectChain(for: inputID)
        print("🎛️ Added effect: \(effect.name)")
    }

    func removeEffect(_ effect: MonitorEffect, from inputID: UUID) {
        updateInput(inputID) { input in
            input.effectChain.removeAll { $0 == effect }
        }
        rebuildEffectChain(for: inputID)
    }

    private func rebuildEffectChain(for inputID: UUID) {
        guard let input = monitorInputs.first(where: { $0.id == inputID }),
              let engine = audioEngine else { return }

        // Remove old nodes
        if let oldNodes = effectNodes[inputID] {
            for node in oldNodes {
                engine.detach(node)
            }
        }

        // Create new effect nodes
        var nodes: [AVAudioNode] = []

        for effect in input.effectChain {
            if let node = createEffectNode(effect) {
                engine.attach(node)
                nodes.append(node)
            }
        }

        effectNodes[inputID] = nodes

        // Reconnect audio graph
        // TODO: Connect nodes in series
    }

    private func createEffectNode(_ effect: MonitorEffect) -> AVAudioNode? {
        switch effect {
        case .eq(let bands):
            return createEQNode(bands: bands)
        case .reverb(let roomSize, let damping, let mix):
            return createReverbNode(roomSize: roomSize, damping: damping, mix: mix)
        case .delay(let time, let feedback, let mix):
            return createDelayNode(time: time, feedback: feedback, mix: mix)
        case .distortion(let drive, _, _):
            return createDistortionNode(drive: drive)
        default:
            return nil
        }
    }

    private func createEQNode(bands: [EQBand]) -> AVAudioUnitEQ {
        let eq = AVAudioUnitEQ(numberOfBands: bands.count)

        for (index, band) in bands.enumerated() {
            eq.bands[index].frequency = band.frequency
            eq.bands[index].gain = band.gain
            eq.bands[index].bandwidth = 1.0 / band.q

            switch band.type {
            case .lowShelf:
                eq.bands[index].filterType = .lowShelf
            case .peak:
                eq.bands[index].filterType = .parametric
            case .highShelf:
                eq.bands[index].filterType = .highShelf
            case .lowPass:
                eq.bands[index].filterType = .lowPass
            case .highPass:
                eq.bands[index].filterType = .highPass
            default:
                eq.bands[index].filterType = .parametric
            }
        }

        return eq
    }

    private func createReverbNode(roomSize: Float, damping: Float, mix: Float) -> AVAudioUnitReverb {
        let reverb = AVAudioUnitReverb()
        reverb.wetDryMix = mix * 100.0
        reverb.loadFactoryPreset(.mediumHall)
        return reverb
    }

    private func createDelayNode(time: Float, feedback: Float, mix: Float) -> AVAudioUnitDelay {
        let delay = AVAudioUnitDelay()
        delay.delayTime = TimeInterval(time)
        delay.feedback = feedback * 100.0
        delay.wetDryMix = mix * 100.0
        return delay
    }

    private func createDistortionNode(drive: Float) -> AVAudioUnitDistortion {
        let distortion = AVAudioUnitDistortion()
        distortion.preGain = drive * 40.0 - 20.0
        distortion.wetDryMix = 100.0
        distortion.loadFactoryPreset(.multiDecimated1)
        return distortion
    }

    // MARK: - Audio Processing

    private func installMonitoringTap() {
        guard let input = inputNode else { return }

        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: UInt32(hardwareBufferSize), format: format) { [weak self] buffer, _ in
            self?.processMonitorBuffer(buffer)
        }
    }

    private func processMonitorBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Process each monitor input
        for input in monitorInputs where input.isEnabled && !input.muted {
            if input.channel < channelCount {
                let samples = channelData[input.channel]

                // Apply input gain
                let gainLinear = dBToLinear(input.inputGain)
                vDSP_vsmul(samples, 1, &gainLinear.unsafelyUnwrapped, samples, 1, vDSP_Length(frameCount))

                // Apply phase invert if enabled
                if input.phase {
                    var minusOne: Float = -1.0
                    vDSP_vsmul(samples, 1, &minusOne, samples, 1, vDSP_Length(frameCount))
                }

                // Process effect chain
                // (Effect processing would go here)

                // Apply volume
                var volumeValue = input.volume
                vDSP_vsmul(samples, 1, &volumeValue, samples, 1, vDSP_Length(frameCount))

                // Update meters
                updateMeters(for: input.id, samples: samples, count: frameCount)
            }
        }

        // Update DSP load
        updateDSPLoad()
    }

    private func updateMeters(for inputID: UUID, samples: UnsafePointer<Float>, count: Int) {
        // Calculate peak
        var peak: Float = 0.0
        vDSP_maxv(samples, 1, &peak, vDSP_Length(count))

        // Calculate RMS
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))

        // Update input meters
        updateInput(inputID) { input in
            input.peakLevel = peak
            input.rmsLevel = rms
        }
    }

    private func updateDSPLoad() {
        // Calculate CPU load from audio processing
        // Simplified - real implementation would track actual CPU time
        let activeInputs = monitorInputs.filter { $0.isEnabled && !$0.muted }.count
        let effectCount = monitorInputs.reduce(0) { $0 + $1.effectChain.count }

        dspLoad = (Double(activeInputs) * 5.0) + (Double(effectCount) * 3.0)
        dspLoad = min(dspLoad, 100.0)
    }

    // MARK: - Cue Mix

    struct CueMix: Identifiable {
        let id: UUID
        var name: String
        var inputs: [UUID: Float]  // InputID -> Volume
        var masterVolume: Float
        var outputChannel: Int

        static func create(name: String, outputChannel: Int) -> CueMix {
            CueMix(
                id: UUID(),
                name: name,
                inputs: [:],
                masterVolume: 0.8,
                outputChannel: outputChannel
            )
        }
    }

    @Published var cueMixes: [CueMix] = []

    func addCueMix(name: String, outputChannel: Int) {
        let mix = CueMix.create(name: name, outputChannel: outputChannel)
        cueMixes.append(mix)
        print("➕ Added cue mix: \(name)")
    }

    func setCueLevel(mixID: UUID, inputID: UUID, level: Float) {
        if let index = cueMixes.firstIndex(where: { $0.id == mixID }) {
            cueMixes[index].inputs[inputID] = level
        }
    }

    // MARK: - Utilities

    private func dBToLinear(_ dB: Float) -> UnsafePointer<Float> {
        var linear = powf(10.0, dB / 20.0)
        return withUnsafePointer(to: &linear) { $0 }
    }

    private func linearTodB(_ linear: Float) -> Float {
        guard linear > 0.0 else { return -96.0 }
        return 20.0 * log10(linear)
    }

    // MARK: - Errors

    enum MonitorError: LocalizedError {
        case engineInitFailed
        case mixerInitFailed
        case engineNotInitialized
        case invalidChannel

        var errorDescription: String? {
            switch self {
            case .engineInitFailed: return "Failed to initialize audio engine"
            case .mixerInitFailed: return "Failed to initialize mixer node"
            case .engineNotInitialized: return "Audio engine not initialized"
            case .invalidChannel: return "Invalid audio channel"
            }
        }
    }

    // MARK: - Initialization

    private init() {}
}

// MARK: - Presets

extension DirectMonitoringSystem {
    struct MonitorPreset {
        let name: String
        let effects: [MonitorEffect]
        let inputGain: Float
        let volume: Float

        static let vocalClassic = MonitorPreset(
            name: "Vocal Classic",
            effects: [
                .eq(bands: [
                    EQBand(frequency: 100, gain: -3, q: 0.7, type: .highPass),
                    EQBand(frequency: 3000, gain: 2, q: 1.0, type: .peak),
                    EQBand(frequency: 8000, gain: 1.5, q: 0.7, type: .highShelf)
                ]),
                .compressor(threshold: -12, ratio: 3, attack: 5, release: 100),
                .deEsser(frequency: 6000, threshold: -20),
                .reverb(roomSize: 0.3, damping: 0.5, mix: 0.15)
            ],
            inputGain: 0,
            volume: 0.8
        )

        static let guitarCrunch = MonitorPreset(
            name: "Guitar Crunch",
            effects: [
                .eq(bands: [
                    EQBand(frequency: 80, gain: -6, q: 0.7, type: .highPass),
                    EQBand(frequency: 800, gain: -2, q: 1.0, type: .peak),
                    EQBand(frequency: 2000, gain: 3, q: 1.0, type: .peak)
                ]),
                .distortion(drive: 0.6, tone: 0.7, mix: 0.8),
                .delay(time: 0.375, feedback: 0.3, mix: 0.2)
            ],
            inputGain: 0,
            volume: 0.8
        )

        static let drumPunch = MonitorPreset(
            name: "Drum Punch",
            effects: [
                .gate(threshold: -30, ratio: 10, attack: 0.1, release: 50),
                .compressor(threshold: -15, ratio: 4, attack: 3, release: 80),
                .eq(bands: [
                    EQBand(frequency: 60, gain: 3, q: 1.0, type: .lowShelf),
                    EQBand(frequency: 3000, gain: 2, q: 1.0, type: .peak)
                ]),
                .exciter(frequency: 5000, amount: 0.3)
            ],
            inputGain: 0,
            volume: 0.8
        )
    }

    func applyPreset(_ preset: MonitorPreset, to inputID: UUID) {
        updateInput(inputID) { input in
            input.effectChain = preset.effects
            input.inputGain = preset.inputGain
            input.volume = preset.volume
        }
        rebuildEffectChain(for: inputID)
        print("✨ Applied preset: \(preset.name)")
    }
}

#Preview {
    Text("Direct Monitoring System")
}
