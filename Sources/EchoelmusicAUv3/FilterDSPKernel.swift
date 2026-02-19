//
//  FilterDSPKernel.swift
//  EchoelmusicAUv3
//
//  Multi-mode biquad filter DSP kernel for AUv3 effect.
//  Supports: Low Pass, High Pass, Band Pass, Notch.
//  Extracted from FilterNode.swift for real-time audio thread usage.
//

import Foundation
import AVFoundation

/// DSP Kernel for EchoelField Filter
public final class FilterDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    private var cutoffFrequency: Float = 1000.0  // Hz
    private var resonance: Float = 0.707         // Q
    private var filterMode: Int = 0              // 0=LP, 1=HP, 2=BP, 3=Notch
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - Biquad State

    private var b0: Float = 1.0, b1: Float = 0.0, b2: Float = 0.0
    private var a1: Float = 0.0, a2: Float = 0.0

    // Per-channel delay elements
    private var x1: [Float] = [0.0, 0.0]
    private var x2: [Float] = [0.0, 0.0]
    private var y1: [Float] = [0.0, 0.0]
    private var y2: [Float] = [0.0, 0.0]

    // MARK: - Initialization

    public init() {
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.filterFrequency.rawValue] = 1000
        parameters[EchoelmusicParameterAddress.filterResonance.rawValue] = 0.707
        parameters[EchoelmusicParameterAddress.filterMode.rawValue] = 0
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        x1 = [Float](repeating: 0, count: max(channelCount, 2))
        x2 = [Float](repeating: 0, count: max(channelCount, 2))
        y1 = [Float](repeating: 0, count: max(channelCount, 2))
        y2 = [Float](repeating: 0, count: max(channelCount, 2))
        updateCoefficients()
    }

    public func deallocate() {
        x1 = [0, 0]; x2 = [0, 0]; y1 = [0, 0]; y2 = [0, 0]
    }

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass: bypass = value > 0.5
        case .gain: outputGain = value
        case .mix: mix = value
        case .filterFrequency:
            cutoffFrequency = value
            updateCoefficients()
        case .filterResonance:
            resonance = value
            updateCoefficients()
        case .filterMode:
            filterMode = Int(value)
            updateCoefficients()
        default: break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        // Filter can respond to CC for cutoff sweeps
        let messageType = status & 0xF0
        if messageType == 0xB0 { // CC
            switch data1 {
            case 74: // Filter cutoff (standard)
                cutoffFrequency = 20.0 + (Float(data2) / 127.0) * 19980.0
                updateCoefficients()
            case 71: // Resonance (standard)
                resonance = 0.1 + (Float(data2) / 127.0) * 19.9
                updateCoefficients()
            default: break
            }
        }
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        guard abl.count >= 2 else { return }

        guard let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        if bypass { return }

        let channels = [left, right]
        for ch in 0..<min(2, abl.count) {
            let samples = channels[ch]
            for frame in 0..<frameCount {
                let x0 = samples[frame]
                let y0 = b0 * x0 + b1 * x1[ch] + b2 * x2[ch] - a1 * y1[ch] - a2 * y2[ch]
                x2[ch] = x1[ch]; x1[ch] = x0
                y2[ch] = y1[ch]; y1[ch] = y0
                samples[frame] = y0 * outputGain
            }
        }
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Warm LP
            cutoffFrequency = 800; resonance = 0.707; filterMode = 0
        case 1: // Bright HP
            cutoffFrequency = 200; resonance = 0.707; filterMode = 1
        case 2: // Vocal BP
            cutoffFrequency = 2000; resonance = 2.0; filterMode = 2
        case 3: // Notch 50Hz
            cutoffFrequency = 50; resonance = 5.0; filterMode = 3
        case 4: // Resonant Sweep
            cutoffFrequency = 500; resonance = 8.0; filterMode = 0
        default: break
        }
        updateCoefficients()
        parameters[EchoelmusicParameterAddress.filterFrequency.rawValue] = cutoffFrequency
        parameters[EchoelmusicParameterAddress.filterResonance.rawValue] = resonance
        parameters[EchoelmusicParameterAddress.filterMode.rawValue] = Float(filterMode)
    }

    public var latency: TimeInterval { 0 }
    public var tailTime: TimeInterval { 0 }

    public var fullState: [String: Any]? {
        get {
            return ["cutoff": cutoffFrequency, "resonance": resonance, "mode": filterMode, "gain": outputGain]
        }
        set {
            guard let s = newValue else { return }
            if let v = s["cutoff"] as? Float { cutoffFrequency = v }
            if let v = s["resonance"] as? Float { resonance = v }
            if let v = s["mode"] as? Int { filterMode = v }
            if let v = s["gain"] as? Float { outputGain = v }
            updateCoefficients()
        }
    }

    // MARK: - Biquad Coefficient Calculation

    private func updateCoefficients() {
        let omega = 2.0 * Float.pi * cutoffFrequency / Float(sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * resonance)
        var a0: Float = 1.0

        switch filterMode {
        case 0: // Low Pass
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            a0 = 1.0 + alpha; a1 = -2.0 * cosOmega; a2 = 1.0 - alpha
        case 1: // High Pass
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            a0 = 1.0 + alpha; a1 = -2.0 * cosOmega; a2 = 1.0 - alpha
        case 2: // Band Pass
            b0 = alpha; b1 = 0.0; b2 = -alpha
            a0 = 1.0 + alpha; a1 = -2.0 * cosOmega; a2 = 1.0 - alpha
        case 3: // Notch
            b0 = 1.0; b1 = -2.0 * cosOmega; b2 = 1.0
            a0 = 1.0 + alpha; a1 = -2.0 * cosOmega; a2 = 1.0 - alpha
        default:
            return
        }

        // Normalize
        b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
    }
}
