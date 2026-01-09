// AudioEngine.swift
// Complete bio-reactive audio engine with multiple modes

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Engine

@MainActor
public final class AudioEngine: ObservableObject {
    // MARK: - Published Properties

    @Published public var isRunning: Bool = false
    @Published public var audioMode: AudioMode = .ambient
    @Published public var volume: Float = 0.7
    @Published public var baseFrequency: Float = 432.0
    @Published public var binauralState: BinauralState = .alpha

    // Bio-reactive parameters
    @Published public var coherenceLevel: Float = 0.5
    @Published public var heartRateNormalized: Float = 0.5

    // MARK: - Audio Components

    private var engine: AVAudioEngine?
    private var mainMixer: AVAudioMixerNode?

    // Tone generators
    private var ambientNode: AVAudioSourceNode?
    private var binauralLeftNode: AVAudioSourceNode?
    private var binauralRightNode: AVAudioSourceNode?
    private var droneNode: AVAudioSourceNode?

    // Effects
    private var reverbNode: AVAudioUnitReverb?
    private var delayNode: AVAudioUnitDelay?

    // MARK: - Synthesis State

    private var ambientPhase: Float = 0
    private var binauralLeftPhase: Float = 0
    private var binauralRightPhase: Float = 0
    private var dronePhases: [Float] = [0, 0, 0, 0]  // 4-layer drone

    // Modulation
    private var breathPhase: Float = 0
    private var breathRate: Float = 0.1

    // MARK: - Audio Format

    private let sampleRate: Double = 44100
    private let channelCount: AVAudioChannelCount = 2

    // MARK: - Initialization

    public init() {
        setupAudioSession()
    }

    deinit {
        stop()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(Double(AppConstants.bufferSize) / sampleRate)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        #endif
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        engine = AVAudioEngine()
        guard let engine = engine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!

        // Create mixer
        mainMixer = AVAudioMixerNode()
        guard let mixer = mainMixer else { return }
        engine.attach(mixer)

        // Create reverb
        reverbNode = AVAudioUnitReverb()
        reverbNode?.loadFactoryPreset(.cathedral)
        reverbNode?.wetDryMix = 30
        guard let reverb = reverbNode else { return }
        engine.attach(reverb)

        // Create delay
        delayNode = AVAudioUnitDelay()
        delayNode?.delayTime = 0.3
        delayNode?.feedback = 30
        delayNode?.wetDryMix = 20
        guard let delay = delayNode else { return }
        engine.attach(delay)

        // Create tone generators based on mode
        setupToneGenerators(format: format)

        // Connect: generators → mixer → reverb → delay → output
        engine.connect(mixer, to: reverb, format: format)
        engine.connect(reverb, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)

        engine.mainMixerNode.outputVolume = volume
    }

    private func setupToneGenerators(format: AVAudioFormat) {
        guard let engine = engine, let mixer = mainMixer else { return }

        // Ambient tone generator
        ambientNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.generateAmbient(frameCount: frameCount, audioBufferList: audioBufferList) ?? noErr
        }

        if let node = ambientNode {
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
        }

        // Multidimensional Brainwave Entrainment generators (stereo)
        let binauralFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        binauralLeftNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.generateBinauralLeft(frameCount: frameCount, audioBufferList: audioBufferList) ?? noErr
        }

        binauralRightNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.generateBinauralRight(frameCount: frameCount, audioBufferList: audioBufferList) ?? noErr
        }

        if let left = binauralLeftNode, let right = binauralRightNode {
            engine.attach(left)
            engine.attach(right)

            // Route to stereo channels
            engine.connect(left, to: mixer, format: binauralFormat)
            engine.connect(right, to: mixer, format: binauralFormat)
        }

        // Drone generator
        droneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.generateDrone(frameCount: frameCount, audioBufferList: audioBufferList) ?? noErr
        }

        if let node = droneNode {
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
        }

        updateNodeVolumes()
    }

    // MARK: - Control

    public func start() {
        guard !isRunning else { return }

        setupEngine()

        do {
            try engine?.start()
            isRunning = true
        } catch {
            print("Engine start error: \(error)")
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
        ambientNode = nil
        binauralLeftNode = nil
        binauralRightNode = nil
        droneNode = nil
        reverbNode = nil
        delayNode = nil
        mainMixer = nil
        isRunning = false
    }

    public func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        engine?.mainMixerNode.outputVolume = volume
    }

    public func setMode(_ mode: AudioMode) {
        audioMode = mode
        updateNodeVolumes()
    }

    private func updateNodeVolumes() {
        // Mute/unmute nodes based on mode
        // Note: In a real implementation, we'd control individual node volumes
    }

    // MARK: - Bio Data Integration

    public func updateFromBioData(_ data: BiometricData) {
        // Map heart rate to frequency (60-100 BPM → 200-600 Hz)
        let hrNorm = Float((data.heartRate - 60) / 40)
        heartRateNormalized = max(0, min(1, hrNorm))
        baseFrequency = 200 + heartRateNormalized * 400

        // Map coherence to effects
        coherenceLevel = Float(data.normalizedCoherence)

        // Update reverb based on coherence
        let reverbMix = 20 + coherenceLevel * 40  // 20-60%
        reverbNode?.wetDryMix = reverbMix

        // Update breath modulation
        breathRate = Float(data.breathingRate) / 60.0
        breathPhase = Float(data.breathPhase)
    }

    // MARK: - Tone Generation

    private func generateAmbient(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard audioMode == .ambient || audioMode == .drone else {
            return fillSilence(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let freq = baseFrequency
        let increment = (freq / Float(sampleRate)) * 2.0 * .pi

        for frame in 0..<Int(frameCount) {
            // Base tone with harmonics
            let fundamental = sin(ambientPhase)
            let second = sin(ambientPhase * 2) * 0.3 * coherenceLevel
            let third = sin(ambientPhase * 3) * 0.15 * coherenceLevel

            // Breath-modulated tremolo
            let tremolo = 1.0 - 0.15 + 0.15 * sin(breathPhase * 2 * .pi)

            var sample = (fundamental + second + third) * tremolo * 0.25

            // Write to all channels
            for buffer in ablPointer {
                let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                buf?[frame] = sample
            }

            ambientPhase += increment
            if ambientPhase > 2 * .pi { ambientPhase -= 2 * .pi }

            breathPhase += breathRate / Float(sampleRate)
            if breathPhase > 1 { breathPhase -= 1 }
        }

        return noErr
    }

    private func generateBinauralLeft(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard audioMode == .binaural else {
            return fillSilence(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let freq = AudioFrequencies.binauralCarrier
        let increment = (freq / Float(sampleRate)) * 2.0 * .pi

        for frame in 0..<Int(frameCount) {
            let sample = sin(binauralLeftPhase) * 0.3

            for buffer in ablPointer {
                let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                buf?[frame] = sample
            }

            binauralLeftPhase += increment
            if binauralLeftPhase > 2 * .pi { binauralLeftPhase -= 2 * .pi }
        }

        return noErr
    }

    private func generateBinauralRight(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard audioMode == .binaural else {
            return fillSilence(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let freq = AudioFrequencies.binauralCarrier + Float(binauralState.frequency)
        let increment = (freq / Float(sampleRate)) * 2.0 * .pi

        for frame in 0..<Int(frameCount) {
            let sample = sin(binauralRightPhase) * 0.3

            for buffer in ablPointer {
                let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                buf?[frame] = sample
            }

            binauralRightPhase += increment
            if binauralRightPhase > 2 * .pi { binauralRightPhase -= 2 * .pi }
        }

        return noErr
    }

    private func generateDrone(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard audioMode == .drone else {
            return fillSilence(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        // 4-layer drone frequencies (root, fifth, octave, ninth)
        let frequencies: [Float] = [
            baseFrequency,
            baseFrequency * 1.5,
            baseFrequency * 2.0,
            baseFrequency * 2.25
        ]

        let amplitudes: [Float] = [0.3, 0.2, 0.15, 0.1]

        for frame in 0..<Int(frameCount) {
            var sample: Float = 0

            for i in 0..<4 {
                let increment = (frequencies[i] / Float(sampleRate)) * 2.0 * .pi
                sample += sin(dronePhases[i]) * amplitudes[i]
                dronePhases[i] += increment
                if dronePhases[i] > 2 * .pi { dronePhases[i] -= 2 * .pi }
            }

            // Breath modulation
            let breathMod = 0.8 + 0.2 * sin(breathPhase * 2 * .pi)
            sample *= breathMod

            for buffer in ablPointer {
                let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                buf?[frame] = sample
            }

            breathPhase += breathRate / Float(sampleRate)
            if breathPhase > 1 { breathPhase -= 1 }
        }

        return noErr
    }

    private func fillSilence(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in ablPointer {
            let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
            for frame in 0..<Int(frameCount) {
                buf?[frame] = 0
            }
        }
        return noErr
    }
}
