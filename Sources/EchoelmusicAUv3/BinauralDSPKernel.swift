//
//  BinauralDSPKernel.swift
//  EchoelmusicAUv3
//
//  Binaural beat / isochronic tone generator DSP kernel for AUv3 instrument.
//  Generates brainwave entrainment tones (Delta, Theta, Alpha, Beta, Gamma).
//  Extracted from BinauralBeatGenerator.swift for real-time audio thread usage.
//

import Foundation
import AVFoundation

/// DSP Kernel for EchoelBio — Binaural Beat Synthesizer
public final class BinauralDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    private var carrierFrequency: Float = 432.0  // Hz
    private var beatFrequency: Float = 10.0      // Hz (Alpha default)
    private var amplitude: Float = 0.3           // 0.0-1.0
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - Oscillator State

    private var leftPhase: Double = 0.0
    private var rightPhase: Double = 0.0
    private var noteActive: Bool = false
    private var noteVelocity: Float = 0.0
    private var currentNote: UInt8 = 69  // A4

    // Envelope
    private var envelope: Float = 0.0
    private let attackTime: Float = 0.05   // 50ms
    private let releaseTime: Float = 0.2   // 200ms
    private var isReleasing: Bool = false

    // MARK: - Initialization

    public init() {
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.binauralCarrier.rawValue] = 432
        parameters[EchoelmusicParameterAddress.binauralBeat.rawValue] = 10
        parameters[EchoelmusicParameterAddress.binauralAmplitude.rawValue] = 0.3
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        leftPhase = 0; rightPhase = 0
        envelope = 0
    }

    public func deallocate() {
        noteActive = false
        envelope = 0
    }

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass: bypass = value > 0.5
        case .gain: outputGain = value
        case .mix: mix = value
        case .binauralCarrier: carrierFrequency = value
        case .binauralBeat: beatFrequency = value
        case .binauralAmplitude: amplitude = min(max(value, 0), 1)
        case .bioReactivity:
            // Map coherence (0-1) to beat frequency
            if value < 0.4 {
                beatFrequency = 10.0  // Alpha: relaxation
            } else if value < 0.6 {
                beatFrequency = 15.0  // Alpha-Beta transition
            } else {
                beatFrequency = 20.0  // Beta: focus
            }
        default: break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        let messageType = status & 0xF0

        switch messageType {
        case 0x90: // Note On
            if data2 > 0 {
                currentNote = data1
                noteVelocity = Float(data2) / 127.0
                noteActive = true
                isReleasing = false
                // Map MIDI note to carrier frequency
                carrierFrequency = 440.0 * pow(2.0, (Float(data1) - 69.0) / 12.0)
            } else {
                isReleasing = true
            }
        case 0x80: // Note Off
            isReleasing = true
        case 0xB0: // CC
            switch data1 {
            case 1: // Mod wheel → beat frequency
                beatFrequency = 0.5 + Float(data2) / 127.0 * 39.5  // 0.5-40 Hz
            case 74: // Carrier frequency
                carrierFrequency = 100.0 + Float(data2) / 127.0 * 900.0  // 100-1000 Hz
            case 123: // All notes off
                noteActive = false; isReleasing = false; envelope = 0
            default: break
            }
        default: break
        }
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        guard abl.count >= 2 else { return }

        guard let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        // Clear buffers (instrument generates audio, doesn't process input)
        memset(left, 0, frameCount * MemoryLayout<Float>.size)
        memset(right, 0, frameCount * MemoryLayout<Float>.size)

        if bypass { return }
        guard noteActive || envelope > 0.001 else { return }

        // Frequencies for left and right ears
        let leftFreq = carrierFrequency - (beatFrequency / 2.0)
        let rightFreq = carrierFrequency + (beatFrequency / 2.0)
        let leftPhaseInc = Double(leftFreq) / sampleRate
        let rightPhaseInc = Double(rightFreq) / sampleRate

        // Envelope coefficients
        let attackCoeff = 1.0 / (attackTime * Float(sampleRate))
        let releaseCoeff = 1.0 / (releaseTime * Float(sampleRate))

        for frame in 0..<frameCount {
            // Update envelope
            if isReleasing {
                envelope -= releaseCoeff
                if envelope <= 0 {
                    envelope = 0
                    noteActive = false
                    isReleasing = false
                    continue
                }
            } else if noteActive {
                envelope = min(1.0, envelope + attackCoeff)
            }

            // Generate binaural tones
            let leftSample = Float(sin(leftPhase * 2.0 * Double.pi))
            let rightSample = Float(sin(rightPhase * 2.0 * Double.pi))

            leftPhase += leftPhaseInc
            rightPhase += rightPhaseInc
            if leftPhase >= 1.0 { leftPhase -= 1.0 }
            if rightPhase >= 1.0 { rightPhase -= 1.0 }

            let env = amplitude * envelope * noteVelocity * outputGain
            left[frame] = leftSample * env
            right[frame] = rightSample * env
        }
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Delta — Deep Sleep
            carrierFrequency = 432; beatFrequency = 2.0; amplitude = 0.25
        case 1: // Theta — Meditation
            carrierFrequency = 432; beatFrequency = 6.0; amplitude = 0.3
        case 2: // Alpha — Relaxation
            carrierFrequency = 432; beatFrequency = 10.0; amplitude = 0.3
        case 3: // Beta — Focus
            carrierFrequency = 432; beatFrequency = 20.0; amplitude = 0.25
        case 4: // Gamma — Peak Awareness
            carrierFrequency = 432; beatFrequency = 40.0; amplitude = 0.2
        default: break
        }
        parameters[EchoelmusicParameterAddress.binauralCarrier.rawValue] = carrierFrequency
        parameters[EchoelmusicParameterAddress.binauralBeat.rawValue] = beatFrequency
        parameters[EchoelmusicParameterAddress.binauralAmplitude.rawValue] = amplitude
    }

    public var latency: TimeInterval { 0 }
    public var tailTime: TimeInterval { TimeInterval(releaseTime) }

    public var fullState: [String: Any]? {
        get {
            return ["carrier": carrierFrequency, "beat": beatFrequency, "amplitude": amplitude, "gain": outputGain]
        }
        set {
            guard let s = newValue else { return }
            if let v = s["carrier"] as? Float { carrierFrequency = v }
            if let v = s["beat"] as? Float { beatFrequency = v }
            if let v = s["amplitude"] as? Float { amplitude = v }
            if let v = s["gain"] as? Float { outputGain = v }
        }
    }
}
