//
//  ReverbDSPKernel.swift
//  EchoelmusicAUv3
//
//  Freeverb-style algorithmic reverb DSP kernel for AUv3 effect.
//  8 parallel comb filters + 4 series allpass filters.
//  Extracted from ReverbNode.swift for real-time audio thread usage.
//

import Foundation
import AVFoundation
import Accelerate

/// DSP Kernel for EchoelFX Reverb — Freeverb algorithm
public final class ReverbDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    private var wetDry: Float = 0.3       // 0.0-1.0
    private var roomSize: Float = 0.5     // 0.0-1.0
    private var dampingAmount: Float = 0.5 // 0.0-1.0
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false

    // MARK: - Freeverb DSP State

    /// Comb filter delays (samples at 44.1kHz, scaled for actual sample rate)
    private static let combDelays: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]

    /// Allpass filter delays
    private static let allpassDelays: [Int] = [556, 441, 341, 225]

    /// Comb filter buffers (8 filters, per channel)
    private var combBuffersL: [[Float]] = []
    private var combBuffersR: [[Float]] = []
    private var combIndicesL: [Int] = []
    private var combIndicesR: [Int] = []

    /// Allpass filter buffers (4 filters, per channel)
    private var allpassBuffersL: [[Float]] = []
    private var allpassBuffersR: [[Float]] = []
    private var allpassIndicesL: [Int] = []
    private var allpassIndicesR: [Int] = []

    /// Damping state
    private var dampedValuesL: [Float] = []
    private var dampedValuesR: [Float] = []

    /// Feedback amount (derived from roomSize)
    private var feedback: Float = 0.84

    /// Damping coefficient
    private var damping: Float = 0.2

    // MARK: - Initialization

    public init() {
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.reverbWetDry.rawValue] = 0.3
        parameters[EchoelmusicParameterAddress.reverbRoomSize.rawValue] = 0.5
        parameters[EchoelmusicParameterAddress.reverbDamping.rawValue] = 0.5
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        initializeBuffers()
    }

    public func deallocate() {
        combBuffersL.removeAll()
        combBuffersR.removeAll()
        allpassBuffersL.removeAll()
        allpassBuffersR.removeAll()
    }

    public func setParameter(address: AUParameterAddress, value: AUValue) {
        parameters[address] = value

        switch EchoelmusicParameterAddress(rawValue: address) {
        case .bypass:
            bypass = value > 0.5
        case .gain:
            outputGain = value
        case .mix:
            mix = value
        case .reverbWetDry:
            wetDry = value
        case .reverbRoomSize:
            roomSize = value
            feedback = 0.7 + roomSize * 0.28
        case .reverbDamping:
            dampingAmount = value
            damping = dampingAmount * 0.4
        default:
            break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        // Reverb doesn't respond to MIDI
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        guard abl.count >= 2 else { return }

        guard let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        if bypass { return }

        for frame in 0..<frameCount {
            let inputL = left[frame]
            let inputR = right[frame]

            // Process left channel through comb filters
            var combSumL: Float = 0.0
            for i in 0..<combBuffersL.count {
                let bufSize = combBuffersL[i].count
                guard bufSize > 0 else { continue }
                let delayed = combBuffersL[i][combIndicesL[i]]
                dampedValuesL[i] = delayed * (1.0 - damping) + dampedValuesL[i] * damping
                combBuffersL[i][combIndicesL[i]] = inputL + dampedValuesL[i] * feedback
                combIndicesL[i] = (combIndicesL[i] + 1) % bufSize
                combSumL += delayed
            }

            // Process right channel through comb filters
            var combSumR: Float = 0.0
            for i in 0..<combBuffersR.count {
                let bufSize = combBuffersR[i].count
                guard bufSize > 0 else { continue }
                let delayed = combBuffersR[i][combIndicesR[i]]
                dampedValuesR[i] = delayed * (1.0 - damping) + dampedValuesR[i] * damping
                combBuffersR[i][combIndicesR[i]] = inputR + dampedValuesR[i] * feedback
                combIndicesR[i] = (combIndicesR[i] + 1) % bufSize
                combSumR += delayed
            }

            // Scale comb output (divide by 8 filters)
            var outputL = combSumL * 0.125
            var outputR = combSumR * 0.125

            // Process through 4 series allpass filters
            for i in 0..<allpassBuffersL.count {
                let bufSize = allpassBuffersL[i].count
                guard bufSize > 0 else { continue }

                // Left
                let delayedL = allpassBuffersL[i][allpassIndicesL[i]]
                let tempL = outputL + delayedL * 0.5
                allpassBuffersL[i][allpassIndicesL[i]] = tempL
                allpassIndicesL[i] = (allpassIndicesL[i] + 1) % bufSize
                outputL = delayedL - outputL * 0.5

                // Right
                let delayedR = allpassBuffersR[i][allpassIndicesR[i]]
                let tempR = outputR + delayedR * 0.5
                allpassBuffersR[i][allpassIndicesR[i]] = tempR
                allpassIndicesR[i] = (allpassIndicesR[i] + 1) % bufSize
                outputR = delayedR - outputR * 0.5
            }

            // Mix dry and wet, apply gain
            left[frame] = (inputL * (1.0 - wetDry) + outputL * wetDry) * outputGain
            right[frame] = (inputR * (1.0 - wetDry) + outputR * wetDry) * outputGain
        }
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Small Room
            wetDry = 0.2; roomSize = 0.3; dampingAmount = 0.6
        case 1: // Medium Hall
            wetDry = 0.35; roomSize = 0.6; dampingAmount = 0.4
        case 2: // Large Hall
            wetDry = 0.5; roomSize = 0.85; dampingAmount = 0.3
        case 3: // Cathedral
            wetDry = 0.6; roomSize = 0.95; dampingAmount = 0.2
        case 4: // Plate
            wetDry = 0.4; roomSize = 0.5; dampingAmount = 0.7
        default:
            break
        }
        feedback = 0.7 + roomSize * 0.28
        damping = dampingAmount * 0.4
        parameters[EchoelmusicParameterAddress.reverbWetDry.rawValue] = wetDry
        parameters[EchoelmusicParameterAddress.reverbRoomSize.rawValue] = roomSize
        parameters[EchoelmusicParameterAddress.reverbDamping.rawValue] = dampingAmount
    }

    public var latency: TimeInterval { 0 }

    public var tailTime: TimeInterval {
        return TimeInterval(roomSize * 4.0 + 1.0)
    }

    public var fullState: [String: Any]? {
        get {
            return ["wetDry": wetDry, "roomSize": roomSize, "damping": dampingAmount, "gain": outputGain]
        }
        set {
            guard let state = newValue else { return }
            if let v = state["wetDry"] as? Float { wetDry = v }
            if let v = state["roomSize"] as? Float { roomSize = v; feedback = 0.7 + v * 0.28 }
            if let v = state["damping"] as? Float { dampingAmount = v; damping = v * 0.4 }
            if let v = state["gain"] as? Float { outputGain = v }
        }
    }

    // MARK: - Private

    private func initializeBuffers() {
        let scaleFactor = sampleRate / 44100.0

        combBuffersL = Self.combDelays.map { [Float](repeating: 0, count: Int(Double($0) * scaleFactor)) }
        combBuffersR = Self.combDelays.map { [Float](repeating: 0, count: Int(Double($0) * scaleFactor)) }
        combIndicesL = [Int](repeating: 0, count: Self.combDelays.count)
        combIndicesR = [Int](repeating: 0, count: Self.combDelays.count)
        dampedValuesL = [Float](repeating: 0, count: Self.combDelays.count)
        dampedValuesR = [Float](repeating: 0, count: Self.combDelays.count)

        allpassBuffersL = Self.allpassDelays.map { [Float](repeating: 0, count: Int(Double($0) * scaleFactor)) }
        allpassBuffersR = Self.allpassDelays.map { [Float](repeating: 0, count: Int(Double($0) * scaleFactor)) }
        allpassIndicesL = [Int](repeating: 0, count: Self.allpassDelays.count)
        allpassIndicesR = [Int](repeating: 0, count: Self.allpassDelays.count)
    }
}
