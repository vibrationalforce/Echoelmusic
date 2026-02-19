//
//  CompressorDSPKernel.swift
//  EchoelmusicAUv3
//
//  Analog-style feed-forward compressor DSP kernel for AUv3 effect.
//  Peak/RMS detection, soft knee, attack/release smoothing.
//  Extracted from CompressorNode.swift for real-time audio thread usage.
//

import Foundation
import AVFoundation
import Accelerate

/// DSP Kernel for EchoelMix Compressor
public final class CompressorDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    private var threshold: Float = -20.0   // dB
    private var ratio: Float = 4.0         // :1
    private var attackMs: Float = 10.0     // ms
    private var releaseMs: Float = 100.0   // ms
    private var makeupGaindB: Float = 0.0  // dB
    private var kneedB: Float = 6.0        // dB
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - DSP State

    private var envelope: [Float] = [0.0, 0.0]
    private(set) var gainReduction: Float = 0.0

    // MARK: - Initialization

    public init() {
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.compThreshold.rawValue] = -20
        parameters[EchoelmusicParameterAddress.compRatio.rawValue] = 4
        parameters[EchoelmusicParameterAddress.compAttack.rawValue] = 10
        parameters[EchoelmusicParameterAddress.compRelease.rawValue] = 100
        parameters[EchoelmusicParameterAddress.compMakeupGain.rawValue] = 0
        parameters[EchoelmusicParameterAddress.compKnee.rawValue] = 6
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        envelope = [Float](repeating: 0, count: max(channelCount, 2))
        gainReduction = 0
    }

    public func deallocate() {
        envelope = [0, 0]
    }

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass: bypass = value > 0.5
        case .gain: outputGain = value
        case .mix: mix = value
        case .compThreshold: threshold = value
        case .compRatio: ratio = value
        case .compAttack: attackMs = value
        case .compRelease: releaseMs = value
        case .compMakeupGain: makeupGaindB = value
        case .compKnee: kneedB = value
        default: break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        // Compressor doesn't respond to MIDI
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        guard abl.count >= 2 else { return }

        guard let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        if bypass { return }

        let attackCoeff = exp(-1.0 / (Float(sampleRate) * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * releaseMs / 1000.0))
        let makeupGainLinear = powf(10.0, makeupGaindB / 20.0)

        var maxGR: Float = 0.0

        for frame in 0..<frameCount {
            // Side-chain: max of both channels
            let detectedLevel = max(abs(left[frame]), abs(right[frame]))

            // Envelope follower
            let coeff = detectedLevel > envelope[0] ? attackCoeff : releaseCoeff
            envelope[0] = coeff * envelope[0] + (1.0 - coeff) * detectedLevel

            let envelopedB = 20.0 * log10(max(envelope[0], 1e-10))

            // Gain reduction with soft knee
            var grDB: Float = 0.0
            if kneedB > 0 && envelopedB > (threshold - kneedB / 2) && envelopedB < (threshold + kneedB / 2) {
                let x = envelopedB - threshold + kneedB / 2
                grDB = (1.0 / ratio - 1.0) * x * x / (2.0 * kneedB)
            } else if envelopedB > threshold {
                grDB = (envelopedB - threshold) * (1.0 / ratio - 1.0)
            }

            maxGR = min(maxGR, grDB)
            let gainLinear = powf(10.0, grDB / 20.0) * makeupGainLinear * outputGain

            left[frame] *= gainLinear
            right[frame] *= gainLinear
        }

        gainReduction = maxGR
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Vocal
            threshold = -18; ratio = 3; attackMs = 15; releaseMs = 150; makeupGaindB = 4; kneedB = 6
        case 1: // Drum Bus
            threshold = -12; ratio = 4; attackMs = 5; releaseMs = 80; makeupGaindB = 3; kneedB = 3
        case 2: // Master Bus
            threshold = -8; ratio = 2; attackMs = 30; releaseMs = 300; makeupGaindB = 2; kneedB = 8
        case 3: // Aggressive
            threshold = -24; ratio = 8; attackMs = 1; releaseMs = 50; makeupGaindB = 8; kneedB = 0
        case 4: // Gentle
            threshold = -15; ratio = 2; attackMs = 25; releaseMs = 200; makeupGaindB = 2; kneedB = 10
        default: break
        }
        parameters[EchoelmusicParameterAddress.compThreshold.rawValue] = threshold
        parameters[EchoelmusicParameterAddress.compRatio.rawValue] = ratio
        parameters[EchoelmusicParameterAddress.compAttack.rawValue] = attackMs
        parameters[EchoelmusicParameterAddress.compRelease.rawValue] = releaseMs
        parameters[EchoelmusicParameterAddress.compMakeupGain.rawValue] = makeupGaindB
        parameters[EchoelmusicParameterAddress.compKnee.rawValue] = kneedB
    }

    public var latency: TimeInterval { 0 }
    public var tailTime: TimeInterval { TimeInterval(releaseMs / 1000.0) }

    public var fullState: [String: Any]? {
        get {
            return [
                "threshold": threshold, "ratio": ratio,
                "attack": attackMs, "release": releaseMs,
                "makeupGain": makeupGaindB, "knee": kneedB, "gain": outputGain
            ]
        }
        set {
            guard let s = newValue else { return }
            if let v = s["threshold"] as? Float { threshold = v }
            if let v = s["ratio"] as? Float { ratio = v }
            if let v = s["attack"] as? Float { attackMs = v }
            if let v = s["release"] as? Float { releaseMs = v }
            if let v = s["makeupGain"] as? Float { makeupGaindB = v }
            if let v = s["knee"] as? Float { kneedB = v }
            if let v = s["gain"] as? Float { outputGain = v }
        }
    }
}
