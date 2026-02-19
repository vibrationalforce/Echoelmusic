//
//  TR808DSPKernel.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  PULSE DRUM BASS SYNTH DSP KERNEL
//  Real-time audio processing for AUv3 instrument
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - EchoelBeat DSP Kernel

/// DSP Kernel for EchoelBeat Bass Synthesizer
public final class TR808DSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    // 808 specific
    private var pitchGlideTime: Float = 0.08
    private var pitchGlideRange: Float = -12.0
    private var pitchGlideCurve: Float = 0.7
    private var clickAmount: Float = 0.3
    private var decay: Float = 1.5
    private var drive: Float = 0.2
    private var filterCutoff: Float = 500.0
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - Voice State

    private struct Voice {
        var isActive: Bool = false
        var midiNote: UInt8 = 0
        var velocity: Float = 0
        var phase: Double = 0
        var clickPhase: Double = 0
        var envelope: Float = 1.0
        var glideProgress: Float = 0
        var startSample: Int64 = 0
        var releaseSample: Int64 = 0
        var isReleasing: Bool = false
        var filterZ1: Float = 0
    }

    private var voices: [Voice] = Array(repeating: Voice(), count: 8)
    private let maxVoices = 8
    private var currentSample: Int64 = 0
    private var pitchBendOffset: Float = 0.0

    // MARK: - Initialization

    public init() {
        // Set default parameter values
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.pitchGlideTime.rawValue] = 0.08
        parameters[EchoelmusicParameterAddress.pitchGlideRange.rawValue] = -12
        parameters[EchoelmusicParameterAddress.clickAmount.rawValue] = 0.3
        parameters[EchoelmusicParameterAddress.decay.rawValue] = 1.5
        parameters[EchoelmusicParameterAddress.drive.rawValue] = 0.2
        parameters[EchoelmusicParameterAddress.filterCutoff.rawValue] = 500
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        // Reset all voices
        for i in 0..<maxVoices {
            voices[i] = Voice()
        }

        currentSample = 0
    }

    public func deallocate() {
        // Clean up resources
        for i in 0..<maxVoices {
            voices[i].isActive = false
        }
    }

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        // Update local cached values for real-time access
        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass:
            bypass = value > 0.5
        case .gain:
            outputGain = value
        case .mix:
            mix = value
        case .pitchGlideTime:
            pitchGlideTime = value
        case .pitchGlideRange:
            pitchGlideRange = value
        case .pitchGlideCurve:
            pitchGlideCurve = value
        case .clickAmount:
            clickAmount = value
        case .decay:
            decay = value
        case .drive:
            drive = value
        case .filterCutoff:
            filterCutoff = value
        default:
            break
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
                noteOn(note: data1, velocity: data2, sampleOffset: sampleOffset)
            } else {
                noteOff(note: data1, sampleOffset: sampleOffset)
            }

        case 0x80: // Note Off
            noteOff(note: data1, sampleOffset: sampleOffset)

        case 0xB0: // Control Change
            handleCC(cc: data1, value: data2)

        case 0xE0: // Pitch Bend
            let pitchBend = (Int(data2) << 7) | Int(data1) - 8192
            handlePitchBend(value: pitchBend)

        default:
            break
        }
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)

        guard abl.count >= 2 else { return }

        let leftBuffer = abl[0].mData?.assumingMemoryBound(to: Float.self)
        let rightBuffer = abl[1].mData?.assumingMemoryBound(to: Float.self)

        guard let left = leftBuffer, let right = rightBuffer else { return }

        // Clear buffers
        memset(left, 0, frameCount * MemoryLayout<Float>.size)
        memset(right, 0, frameCount * MemoryLayout<Float>.size)

        // Bypass mode
        if bypass { return }

        // Render all active voices
        for voiceIndex in 0..<maxVoices {
            guard voices[voiceIndex].isActive else { continue }

            renderVoice(
                voiceIndex: voiceIndex,
                leftBuffer: left,
                rightBuffer: right,
                frameCount: frameCount
            )
        }

        // Apply output gain
        if outputGain != 1.0 {
            var gain = outputGain
            vDSP_vsmul(left, 1, &gain, left, 1, vDSP_Length(frameCount))
            vDSP_vsmul(right, 1, &gain, right, 1, vDSP_Length(frameCount))
        }

        currentSample += Int64(frameCount)
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Classic 808
            pitchGlideTime = 0.06
            pitchGlideRange = -12.0
            pitchGlideCurve = 0.7
            clickAmount = 0.25
            decay = 1.2
            drive = 0.15
            filterCutoff = 400

        case 1: // Hard Trap
            pitchGlideTime = 0.04
            pitchGlideRange = -24.0
            pitchGlideCurve = 0.9
            clickAmount = 0.5
            decay = 0.8
            drive = 0.4
            filterCutoff = 600

        case 2: // Deep Sub
            pitchGlideTime = 0.12
            pitchGlideRange = -7.0
            pitchGlideCurve = 0.5
            clickAmount = 0.1
            decay = 2.5
            drive = 0.1
            filterCutoff = 200

        case 3: // Distorted
            pitchGlideTime = 0.05
            pitchGlideRange = -12.0
            pitchGlideCurve = 0.8
            clickAmount = 0.4
            decay = 1.0
            drive = 0.7
            filterCutoff = 800

        case 4: // Long Slide
            pitchGlideTime = 0.25
            pitchGlideRange = -24.0
            pitchGlideCurve = 0.6
            clickAmount = 0.2
            decay = 3.0
            drive = 0.2
            filterCutoff = 350

        default:
            break
        }

        // Update parameter cache
        parameters[EchoelmusicParameterAddress.pitchGlideTime.rawValue] = pitchGlideTime
        parameters[EchoelmusicParameterAddress.pitchGlideRange.rawValue] = pitchGlideRange
        parameters[EchoelmusicParameterAddress.clickAmount.rawValue] = clickAmount
        parameters[EchoelmusicParameterAddress.decay.rawValue] = decay
        parameters[EchoelmusicParameterAddress.drive.rawValue] = drive
        parameters[EchoelmusicParameterAddress.filterCutoff.rawValue] = filterCutoff
    }

    public var latency: TimeInterval {
        return 0 // No latency for synthesis
    }

    public var tailTime: TimeInterval {
        return TimeInterval(decay + 0.5) // Decay time plus release
    }

    public var fullState: [String: Any]? {
        get {
            return [
                "pitchGlideTime": pitchGlideTime,
                "pitchGlideRange": pitchGlideRange,
                "pitchGlideCurve": pitchGlideCurve,
                "clickAmount": clickAmount,
                "decay": decay,
                "drive": drive,
                "filterCutoff": filterCutoff,
                "outputGain": outputGain
            ]
        }
        set {
            guard let state = newValue else { return }
            if let v = state["pitchGlideTime"] as? Float { pitchGlideTime = v }
            if let v = state["pitchGlideRange"] as? Float { pitchGlideRange = v }
            if let v = state["pitchGlideCurve"] as? Float { pitchGlideCurve = v }
            if let v = state["clickAmount"] as? Float { clickAmount = v }
            if let v = state["decay"] as? Float { decay = v }
            if let v = state["drive"] as? Float { drive = v }
            if let v = state["filterCutoff"] as? Float { filterCutoff = v }
            if let v = state["outputGain"] as? Float { outputGain = v }
        }
    }

    // MARK: - Note Handling

    private func noteOn(note: UInt8, velocity: UInt8, sampleOffset: AUEventSampleTime) {
        // Find free voice or steal oldest
        var voiceIndex = -1

        // First, try to find an inactive voice
        for i in 0..<maxVoices {
            if !voices[i].isActive {
                voiceIndex = i
                break
            }
        }

        // If no free voice, steal the oldest
        if voiceIndex < 0 {
            var oldestSample: Int64 = Int64.max
            for i in 0..<maxVoices {
                if voices[i].startSample < oldestSample {
                    oldestSample = voices[i].startSample
                    voiceIndex = i
                }
            }
        }

        guard voiceIndex >= 0 else { return }

        // Initialize voice
        voices[voiceIndex].isActive = true
        voices[voiceIndex].midiNote = note
        voices[voiceIndex].velocity = Float(velocity) / 127.0
        voices[voiceIndex].phase = 0
        voices[voiceIndex].clickPhase = 0
        voices[voiceIndex].envelope = 1.0
        voices[voiceIndex].glideProgress = 0
        voices[voiceIndex].startSample = currentSample + Int64(sampleOffset)
        voices[voiceIndex].isReleasing = false
        voices[voiceIndex].filterZ1 = 0
    }

    private func noteOff(note: UInt8, sampleOffset: AUEventSampleTime) {
        for i in 0..<maxVoices {
            if voices[i].isActive && voices[i].midiNote == note && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseSample = currentSample + Int64(sampleOffset)
            }
        }
    }

    private func handleCC(cc: UInt8, value: UInt8) {
        let normalized = Float(value) / 127.0

        switch cc {
        case 1: // Mod wheel → glide time
            pitchGlideTime = 0.01 + normalized * 0.49
        case 74: // Filter cutoff
            filterCutoff = 20 + normalized * 1980
        case 73: // Attack (click)
            clickAmount = normalized
        case 75: // Decay
            decay = 0.1 + normalized * 9.9
        case 91: // Drive
            drive = normalized
        case 7: // Volume
            outputGain = normalized
        case 123: // All notes off
            for i in 0..<maxVoices {
                voices[i].isActive = false
            }
        default:
            break
        }
    }

    private func handlePitchBend(value: Int) {
        // Pitch bend affects all voices
        // Range: +/-2 semitones by default
        let bendSemitones = Float(value) / 8192.0 * 2.0
        pitchBendOffset = bendSemitones
    }

    // MARK: - Voice Rendering

    private func renderVoice(voiceIndex: Int, leftBuffer: UnsafeMutablePointer<Float>, rightBuffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let releaseTime: Float = 0.3

        for frame in 0..<frameCount {
            let sampleTime = currentSample + Int64(frame)
            let voiceTime = sampleTime - voices[voiceIndex].startSample

            guard voiceTime >= 0 else { continue }

            let elapsed = Float(voiceTime) / Float(sampleRate)

            // Calculate envelope
            var env: Float
            if voices[voiceIndex].isReleasing {
                let releasedSamples = sampleTime - voices[voiceIndex].releaseSample
                let releaseElapsed = Float(releasedSamples) / Float(sampleRate)
                let releaseProgress = min(1.0, releaseElapsed / releaseTime)
                env = voices[voiceIndex].envelope * (1.0 - releaseProgress)

                if env < 0.001 {
                    voices[voiceIndex].isActive = false
                    continue
                }
            } else {
                // Exponential decay
                let decayProgress = elapsed / decay
                let decayCurve = pow(decayProgress, 0.85)
                env = max(0, 1.0 - decayCurve)
                voices[voiceIndex].envelope = env
            }

            // Calculate pitch with glide
            var pitchMultiplier: Float = 1.0
            if voices[voiceIndex].glideProgress < 1.0 {
                let glideProgress = min(1.0, elapsed / pitchGlideTime)
                voices[voiceIndex].glideProgress = glideProgress

                let curvedProgress = pow(glideProgress, pitchGlideCurve)
                let pitchOffset = pitchGlideRange * (1.0 - curvedProgress)
                pitchMultiplier = pow(2.0, pitchOffset / 12.0)
            }

            // Calculate frequency
            let baseFreq = 440.0 * pow(2.0, (Float(voices[voiceIndex].midiNote) - 69.0 + pitchBendOffset) / 12.0)
            let freq = baseFreq * pitchMultiplier

            // Phase increment
            let phaseInc = Double(freq) / sampleRate

            // Generate sine wave
            var sample = Float(sin(voices[voiceIndex].phase * 2.0 * Double.pi))
            voices[voiceIndex].phase += phaseInc
            if voices[voiceIndex].phase >= 1.0 {
                voices[voiceIndex].phase -= 1.0
            }

            // Attack click
            if clickAmount > 0 && elapsed < 0.02 {
                let clickEnv = 1.0 - (elapsed / 0.02)
                let clickFreqInc = Double(1200) / sampleRate
                let click = Float(sin(voices[voiceIndex].clickPhase * 2.0 * Double.pi)) * clickEnv * clickAmount
                voices[voiceIndex].clickPhase += clickFreqInc
                sample += click
            }

            // Apply envelope and velocity
            sample *= env * voices[voiceIndex].velocity

            // Saturation
            if drive > 0 {
                let driven = sample * (1.0 + drive * 3.0)
                let x2 = driven * driven
                sample = driven * (27.0 + x2) / (27.0 + 9.0 * x2)
            }

            // Low-pass filter
            let filterCoeff = exp(-2.0 * Float.pi * filterCutoff / Float(sampleRate))
            voices[voiceIndex].filterZ1 = sample * (1.0 - filterCoeff) + voices[voiceIndex].filterZ1 * filterCoeff
            sample = voices[voiceIndex].filterZ1

            // Output (mono to stereo)
            leftBuffer[frame] += sample
            rightBuffer[frame] += sample
        }
    }
}
