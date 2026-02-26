// BasicAudioEngine - Minimal Bio-Reactive Audio
// Generates ambient tones modulated by biometric data

import Foundation
import AVFoundation

// MARK: - Basic Audio Engine

@MainActor
public final class BasicAudioEngine: ObservableObject {
    // MARK: - Published Properties

    @Published public var isRunning: Bool = false
    @Published public var volume: Float = 0.7
    @Published public var frequency: Float = 440.0
    @Published public var coherenceLevel: Float = 0.5

    // MARK: - Audio Components

    private var audioEngine: AVAudioEngine?
    private var toneNode: AVAudioSourceNode?
    private var reverbNode: AVAudioUnitReverb?

    // MARK: - Tone Generation State

    private var phase: Float = 0.0
    private var phaseIncrement: Float = 0.0
    private var targetFrequency: Float = 440.0
    private var currentFrequency: Float = 440.0

    // Harmonic blend (coherence-driven)
    private var harmonicBlend: Float = 0.3

    // Breathing modulation
    private var breathPhase: Float = 0.0
    private var breathRate: Float = 0.1 // cycles per second

    // MARK: - Audio Format

    private let sampleRate: Double = 44100.0
    private let channelCount: AVAudioChannelCount = 2

    // MARK: - Initialization

    public init() {
        setupAudioSession()
    }

    deinit {
        stop()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #if DEBUG
            print("🔊 [Audio] Session configured")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Audio] Session error: \(error)")
            #endif
        }
        #endif
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!

        // Create tone generator node
        toneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.generateTone(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        guard let toneNode = toneNode else { return }

        // Create reverb for ambient sound
        reverbNode = AVAudioUnitReverb()
        reverbNode?.loadFactoryPreset(.cathedral)
        reverbNode?.wetDryMix = 40

        guard let reverbNode = reverbNode else { return }

        // Connect nodes
        engine.attach(toneNode)
        engine.attach(reverbNode)

        engine.connect(toneNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: engine.mainMixerNode, format: format)

        // Set volume
        engine.mainMixerNode.outputVolume = volume

        #if DEBUG
        print("🎛️ [Audio] Engine configured")
        #endif
    }

    // MARK: - Tone Generation

    private func generateTone(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        // Smooth frequency transitions
        let frequencySmoothing: Float = 0.001

        for frame in 0..<Int(frameCount) {
            // Smooth frequency change
            currentFrequency += (targetFrequency - currentFrequency) * frequencySmoothing

            // Calculate phase increment
            phaseIncrement = (currentFrequency / Float(sampleRate)) * 2.0 * .pi

            // Update breath modulation
            breathPhase += breathRate / Float(sampleRate)
            if breathPhase > 1.0 { breathPhase -= 1.0 }
            let breathMod = sin(breathPhase * 2.0 * .pi)

            // Generate base tone with harmonics
            let fundamental = sin(phase)
            let second = sin(phase * 2.0) * 0.5 * harmonicBlend
            let third = sin(phase * 3.0) * 0.3 * harmonicBlend
            let fifth = sin(phase * 5.0) * 0.15 * harmonicBlend

            // Combine with breath modulation for tremolo
            let tremoloDepth: Float = 0.1
            let tremolo = 1.0 - tremoloDepth + tremoloDepth * (breathMod + 1.0) / 2.0

            var sample = (fundamental + second + third + fifth) * tremolo

            // Apply volume envelope
            sample *= volume * 0.3 // Keep it gentle

            // Write to stereo channels
            for buffer in ablPointer {
                let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                buf?[frame] = sample
            }

            // Advance phase
            phase += phaseIncrement
            if phase > 2.0 * .pi {
                phase -= 2.0 * .pi
            }
        }

        return noErr
    }

    // MARK: - Control

    public func start() {
        guard !isRunning else { return }

        setupEngine()

        do {
            try audioEngine?.start()
            isRunning = true
            #if DEBUG
            print("▶️ [Audio] Engine started")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Audio] Failed to start engine: \(error)")
            #endif
        }
    }

    public func stop() {
        guard isRunning else { return }

        audioEngine?.stop()
        audioEngine = nil
        toneNode = nil
        reverbNode = nil
        isRunning = false

        #if DEBUG
        print("⏹️ [Audio] Engine stopped")
        #endif
    }

    // MARK: - Bio Data Integration

    public func updateFromBioData(_ bioData: SimpleBioData) {
        // Map heart rate to base frequency
        // Lower HR → lower frequency (calming)
        // Higher HR → higher frequency (energizing)
        let hrNormalized = Float((bioData.heartRate - 50) / 100) // 50-150 BPM range
        let baseFreq: Float = 220.0 // A3
        let freqRange: Float = 220.0 // Up to A4
        targetFrequency = baseFreq + hrNormalized * freqRange

        // Map coherence to harmonic blend
        // Higher coherence → richer harmonics
        harmonicBlend = Float(bioData.coherence) * 0.6 + 0.2

        // Map breathing rate to tremolo speed
        breathRate = Float(bioData.breathingRate) / 60.0 // Convert BPM to Hz

        // Update coherence level for UI
        coherenceLevel = Float(bioData.coherence)

        // Update reverb based on coherence
        if let reverb = reverbNode {
            // Higher coherence → more reverb (expansive feel)
            reverb.wetDryMix = 20 + Float(bioData.coherence) * 50
        }
    }

    // MARK: - Manual Controls

    public func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioEngine?.mainMixerNode.outputVolume = volume
    }

    public func setFrequency(_ newFrequency: Float) {
        targetFrequency = max(20, min(2000, newFrequency))
    }
}

// MARK: - Audio Presets

public enum AudioPreset: String, CaseIterable {
    case calm = "Calm"
    case focus = "Focus"
    case energize = "Energize"
    case meditate = "Meditate"

    public var baseFrequency: Float {
        switch self {
        case .calm: return 329.628     // E4 - warm, open
        case .focus: return 440.0      // A4 - standard concert pitch
        case .energize: return 659.255 // E5 - bright, energetic
        case .meditate: return 220.0   // A3 - grounding
        }
    }

    public var harmonicBlend: Float {
        switch self {
        case .calm: return 0.2
        case .focus: return 0.4
        case .energize: return 0.6
        case .meditate: return 0.3
        }
    }

    public var reverbMix: Float {
        switch self {
        case .calm: return 50
        case .focus: return 30
        case .energize: return 20
        case .meditate: return 60
        }
    }
}
