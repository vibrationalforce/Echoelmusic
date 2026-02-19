//
//  EchoelCoreDSPKernel.swift
//  EchoelmusicAUv3
//
//  Analog console emulation DSP kernel for AUv3 effect.
//  8 classic analog hardware emulations (SSL, API, Neve, Pultec, Fairchild, LA-2A, 1176, Manley).
//  Extracted from EchoelCore.swift TheConsole for real-time audio thread usage.
//

import Foundation
import AVFoundation
import Accelerate

/// DSP Kernel for EchoelMind — Analog Console Emulation
public final class EchoelCoreDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    /// Console legend selection (0-7 maps to SSL, API, Neve, Pultec, Fairchild, LA-2A, 1176, Manley)
    private var legend: Int = 2        // Default: Neve
    private var vibe: Float = 50.0     // Drive amount 0-100
    private var blend: Float = 100.0   // Dry/Wet 0-100
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - Initialization

    public init() {
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.consoleLegend.rawValue] = 2
        parameters[EchoelmusicParameterAddress.consoleVibe.rawValue] = 50
        parameters[EchoelmusicParameterAddress.consoleBlend.rawValue] = 100
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public func deallocate() {}

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass: bypass = value > 0.5
        case .gain: outputGain = value
        case .mix: mix = value
        case .consoleLegend: legend = Int(value) % 8
        case .consoleVibe: vibe = value
        case .consoleBlend: blend = value
        default: break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        let messageType = status & 0xF0
        if messageType == 0xB0 {
            switch data1 {
            case 1: // Mod wheel → vibe
                vibe = Float(data2) / 127.0 * 100.0
            case 74: // Brightness → legend select
                legend = Int(Float(data2) / 127.0 * 7.0) % 8
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

        let amount = vibe / 100.0
        let wet = blend / 100.0

        let channels = [left, right]
        for ch in 0..<min(2, abl.count) {
            let samples = channels[ch]
            for frame in 0..<frameCount {
                let dry = samples[frame]
                let saturated = applySaturation(dry, amount: amount)
                samples[frame] = (dry * (1.0 - wet) + saturated * wet) * outputGain
            }
        }
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: legend = 0; vibe = 40; blend = 100  // SSL Glue
        case 1: legend = 1; vibe = 60; blend = 100  // API Thrust
        case 2: legend = 2; vibe = 50; blend = 100  // Neve Silk
        case 3: legend = 3; vibe = 45; blend = 80   // Pultec Air
        case 4: legend = 4; vibe = 55; blend = 100  // Fairchild Dream
        case 5: legend = 5; vibe = 50; blend = 100  // LA-2A Opto
        case 6: legend = 6; vibe = 65; blend = 100  // 1176 Bite
        case 7: legend = 7; vibe = 50; blend = 90   // Manley Velvet
        default: break
        }
        parameters[EchoelmusicParameterAddress.consoleLegend.rawValue] = Float(legend)
        parameters[EchoelmusicParameterAddress.consoleVibe.rawValue] = vibe
        parameters[EchoelmusicParameterAddress.consoleBlend.rawValue] = blend
    }

    public var latency: TimeInterval { 0 }
    public var tailTime: TimeInterval { 0 }

    public var fullState: [String: Any]? {
        get {
            return ["legend": legend, "vibe": vibe, "blend": blend, "gain": outputGain]
        }
        set {
            guard let s = newValue else { return }
            if let v = s["legend"] as? Int { legend = v % 8 }
            if let v = s["vibe"] as? Float { vibe = v }
            if let v = s["blend"] as? Float { blend = v }
            if let v = s["gain"] as? Float { outputGain = v }
        }
    }

    // MARK: - Saturation Algorithms

    private func applySaturation(_ sample: Float, amount: Float) -> Float {
        var out = sample

        switch legend {
        case 0: // SSL — VCA bus compression character
            let threshold: Float = 0.3 - amount * 0.2
            if abs(out) > threshold {
                let excess = abs(out) - threshold
                let compressed = threshold + excess / (1.0 + excess * 3.0 * amount)
                out = out > 0 ? compressed : -compressed
            }

        case 1: // API — Thrust circuit + punch
            out = tanh(out * (1.0 + amount * 2.0)) * (0.9 + amount * 0.1)

        case 2: // Neve — Transformer saturation + silk
            let second = out * out * 0.15 * amount
            let fourth = out * out * out * out * 0.05 * amount
            out = out + (out > 0 ? second + fourth : -second - fourth)
            out = out / (1.0 + abs(out) * amount * 0.1)

        case 3: // Pultec — Boost/cut curve
            out = out * (1.0 + amount * 0.3)

        case 4: // Fairchild — Variable-mu tube compression
            let level = abs(out)
            if level > 0.2 {
                let ratioVal = 2.0 + level * amount * 4.0
                out = out / (1.0 + level * (ratioVal - 1.0) * amount)
            }

        case 5: // LA-2A — Optical smoothness
            out = out / (1.0 + abs(out) * amount * 0.5)

        case 6: // 1176 — FET bite with odd harmonics
            out = tanh(out * (1.0 + amount * 3.0))
            out = out + out * out * out * 0.1 * amount

        case 7: // Manley — Tube velvet
            if out >= 0 {
                out = out / (1.0 + out * amount * 0.4)
            } else {
                out = out / (1.0 - out * amount * 0.3)
            }

        default:
            break
        }

        return out
    }
}
