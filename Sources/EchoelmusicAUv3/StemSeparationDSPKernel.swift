//
//  StemSeparationDSPKernel.swift
//  EchoelmusicAUv3
//
//  Created: December 2025
//  AI STEM SEPARATION DSP KERNEL
//  Real-time stem separation for AUv3 effect
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Stem Separation DSP Kernel

/// DSP Kernel for AI Stem Separation Effect
public final class StemSeparationDSPKernel: EchoelmusicDSPKernel {

    // MARK: - Audio Format

    private var sampleRate: Double = 48000
    private var channelCount: Int = 2

    // MARK: - Parameters

    private var parameters: [AUParameterAddress: AUValue] = [:]

    // Stem levels
    private var vocalLevel: Float = 1.0
    private var drumLevel: Float = 1.0
    private var bassLevel: Float = 1.0
    private var otherLevel: Float = 1.0
    private var outputGain: Float = 1.0
    private var mix: Float = 1.0
    private var bypass: Bool = false
    private var quality: Int = 1  // 0=Fast, 1=Balanced, 2=High

    // MARK: - FFT Setup

    private let fftSize = 2048
    private let hopSize = 512
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0

    // MARK: - Buffers

    private var inputBuffer: [Float] = []
    private var outputBuffer: [Float] = []
    private var overlapBuffer: [Float] = []
    private var bufferPosition: Int = 0

    // Windows
    private var analysisWindow: [Float] = []
    private var synthesisWindow: [Float] = []

    // FFT work buffers
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []
    private var magnitudeBuffer: [Float] = []
    private var phaseBuffer: [Float] = []

    // Stem masks (simplified spectral separation)
    private var vocalMask: [Float] = []
    private var drumMask: [Float] = []
    private var bassMask: [Float] = []
    private var otherMask: [Float] = []

    // MARK: - Initialization

    public init() {
        // Set default parameter values
        parameters[EchoelmusicParameterAddress.bypass.rawValue] = 0
        parameters[EchoelmusicParameterAddress.gain.rawValue] = 1
        parameters[EchoelmusicParameterAddress.mix.rawValue] = 1
        parameters[EchoelmusicParameterAddress.vocalLevel.rawValue] = 1
        parameters[EchoelmusicParameterAddress.drumLevel.rawValue] = 1
        parameters[EchoelmusicParameterAddress.bassLevel.rawValue] = 1
        parameters[EchoelmusicParameterAddress.otherLevel.rawValue] = 1
        parameters[EchoelmusicParameterAddress.separationQuality.rawValue] = 1
    }

    // MARK: - EchoelmusicDSPKernel Protocol

    public func initialize(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        // Setup FFT
        log2n = vDSP_Length(log2(Double(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Initialize buffers
        inputBuffer = [Float](repeating: 0, count: fftSize * 4)
        outputBuffer = [Float](repeating: 0, count: fftSize * 4)
        overlapBuffer = [Float](repeating: 0, count: fftSize)
        bufferPosition = 0

        // Create Hann window
        analysisWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&analysisWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Synthesis window (square root for perfect reconstruction)
        synthesisWindow = analysisWindow.map { sqrt($0) }

        // FFT work buffers
        let freqBins = fftSize / 2
        realBuffer = [Float](repeating: 0, count: freqBins)
        imagBuffer = [Float](repeating: 0, count: freqBins)
        magnitudeBuffer = [Float](repeating: 0, count: freqBins)
        phaseBuffer = [Float](repeating: 0, count: freqBins)

        // Initialize masks (will be updated during processing)
        vocalMask = [Float](repeating: 0.25, count: freqBins)
        drumMask = [Float](repeating: 0.25, count: freqBins)
        bassMask = [Float](repeating: 0.25, count: freqBins)
        otherMask = [Float](repeating: 0.25, count: freqBins)

        // Create initial frequency-based masks
        updateFrequencyMasks()
    }

    public func deallocate() {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }

        inputBuffer.removeAll()
        outputBuffer.removeAll()
        overlapBuffer.removeAll()
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
        case .vocalLevel:
            vocalLevel = value
        case .drumLevel:
            drumLevel = value
        case .bassLevel:
            bassLevel = value
        case .otherLevel:
            otherLevel = value
        case .separationQuality:
            quality = Int(value * 2)
        default:
            break
        }
    }

    public func getParameter(address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0
    }

    public func handleMIDI(status: UInt8, data1: UInt8, data2: UInt8, sampleOffset: AUEventSampleTime) {
        // Stem separation doesn't typically respond to MIDI
        // Could be used for real-time stem muting via MIDI CC
        let messageType = status & 0xF0

        if messageType == 0xB0 { // CC
            let normalized = Float(data2) / 127.0
            switch data1 {
            case 20: vocalLevel = normalized
            case 21: drumLevel = normalized
            case 22: bassLevel = normalized
            case 23: otherLevel = normalized
            default: break
            }
        }
    }

    public func render(frameCount: Int, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        guard abl.count >= 2 else { return }

        let leftIn = abl[0].mData?.assumingMemoryBound(to: Float.self)
        let rightIn = abl[1].mData?.assumingMemoryBound(to: Float.self)

        guard let left = leftIn, let right = rightIn else { return }

        // Bypass mode - pass through unchanged
        if bypass { return }

        // Process audio through stem separation
        for frame in 0..<frameCount {
            // Mix to mono for processing
            let mono = (left[frame] + right[frame]) * 0.5

            // Add to input buffer
            inputBuffer[bufferPosition] = mono
            bufferPosition += 1

            // Process when we have enough samples
            if bufferPosition >= fftSize {
                processFFTFrame()
                bufferPosition = fftSize - hopSize

                // Shift input buffer
                for i in 0..<bufferPosition {
                    inputBuffer[i] = inputBuffer[i + hopSize]
                }
            }

            // Read from overlap-add output buffer
            let outputSample = overlapBuffer[frame % fftSize]

            // Mix with dry signal
            let wetSample = outputSample * mix
            let drySample = mono * (1 - mix)
            let finalSample = (wetSample + drySample) * outputGain

            // Output to stereo
            left[frame] = finalSample
            right[frame] = finalSample
        }
    }

    public func loadPreset(number: Int) {
        switch number {
        case 0: // Vocal Isolation
            vocalLevel = 1.0
            drumLevel = 0.0
            bassLevel = 0.0
            otherLevel = 0.0
        case 1: // Drums Only
            vocalLevel = 0.0
            drumLevel = 1.0
            bassLevel = 0.0
            otherLevel = 0.0
        case 2: // Bass Boost
            vocalLevel = 0.5
            drumLevel = 0.5
            bassLevel = 1.5
            otherLevel = 0.5
        case 3: // Karaoke Mode
            vocalLevel = 0.0
            drumLevel = 1.0
            bassLevel = 1.0
            otherLevel = 1.0
        case 4: // Instrumental
            vocalLevel = 0.0
            drumLevel = 1.0
            bassLevel = 1.0
            otherLevel = 1.0
        default:
            break
        }

        // Update parameters
        parameters[EchoelmusicParameterAddress.vocalLevel.rawValue] = vocalLevel
        parameters[EchoelmusicParameterAddress.drumLevel.rawValue] = drumLevel
        parameters[EchoelmusicParameterAddress.bassLevel.rawValue] = bassLevel
        parameters[EchoelmusicParameterAddress.otherLevel.rawValue] = otherLevel
    }

    public var latency: TimeInterval {
        return Double(fftSize) / sampleRate
    }

    public var tailTime: TimeInterval {
        return Double(fftSize) / sampleRate
    }

    public var fullState: [String: Any]? {
        get {
            return [
                "vocalLevel": vocalLevel,
                "drumLevel": drumLevel,
                "bassLevel": bassLevel,
                "otherLevel": otherLevel,
                "quality": quality,
                "outputGain": outputGain,
                "mix": mix
            ]
        }
        set {
            guard let state = newValue else { return }
            if let v = state["vocalLevel"] as? Float { vocalLevel = v }
            if let v = state["drumLevel"] as? Float { drumLevel = v }
            if let v = state["bassLevel"] as? Float { bassLevel = v }
            if let v = state["otherLevel"] as? Float { otherLevel = v }
            if let v = state["quality"] as? Int { quality = v }
            if let v = state["outputGain"] as? Float { outputGain = v }
            if let v = state["mix"] as? Float { mix = v }
        }
    }

    // MARK: - FFT Processing

    private func processFFTFrame() {
        guard let setup = fftSetup else { return }

        let freqBins = fftSize / 2

        // Apply analysis window
        var windowedFrame = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(inputBuffer, 1, analysisWindow, 1, &windowedFrame, 1, vDSP_Length(fftSize))

        // Forward FFT
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

        windowedFrame.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: freqBins) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(freqBins))
            }
        }

        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude and phase
        vDSP_zvabs(&splitComplex, 1, &magnitudeBuffer, 1, vDSP_Length(freqBins))
        vDSP_zvphas(&splitComplex, 1, &phaseBuffer, 1, vDSP_Length(freqBins))

        // Apply stem masks and levels
        var stemMagnitude = [Float](repeating: 0, count: freqBins)

        for bin in 0..<freqBins {
            let vocalContrib = magnitudeBuffer[bin] * vocalMask[bin] * vocalLevel
            let drumContrib = magnitudeBuffer[bin] * drumMask[bin] * drumLevel
            let bassContrib = magnitudeBuffer[bin] * bassMask[bin] * bassLevel
            let otherContrib = magnitudeBuffer[bin] * otherMask[bin] * otherLevel

            stemMagnitude[bin] = vocalContrib + drumContrib + bassContrib + otherContrib
        }

        // Reconstruct complex spectrum
        for bin in 0..<freqBins {
            realBuffer[bin] = stemMagnitude[bin] * cos(phaseBuffer[bin])
            imagBuffer[bin] = stemMagnitude[bin] * sin(phaseBuffer[bin])
        }

        // Inverse FFT
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))

        // Convert back to real
        var outputFrame = [Float](repeating: 0, count: fftSize)
        splitComplex.realp.withMemoryRebound(to: DSPComplex.self, capacity: freqBins) { complexPtr in
            vDSP_ztoc(&splitComplex, 1, complexPtr, 2, vDSP_Length(freqBins))
        }

        for i in 0..<freqBins {
            outputFrame[i * 2] = realBuffer[i]
            outputFrame[i * 2 + 1] = imagBuffer[i]
        }

        // Scale
        var scale = 1.0 / Float(fftSize)
        vDSP_vsmul(outputFrame, 1, &scale, &outputFrame, 1, vDSP_Length(fftSize))

        // Apply synthesis window
        vDSP_vmul(outputFrame, 1, synthesisWindow, 1, &outputFrame, 1, vDSP_Length(fftSize))

        // Overlap-add
        vDSP_vadd(overlapBuffer, 1, outputFrame, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

        // Shift overlap buffer
        for i in 0..<(fftSize - hopSize) {
            overlapBuffer[i] = overlapBuffer[i + hopSize]
        }
        for i in (fftSize - hopSize)..<fftSize {
            overlapBuffer[i] = 0
        }
    }

    private func updateFrequencyMasks() {
        let freqBins = fftSize / 2
        let binWidth = Float(sampleRate) / Float(fftSize)

        for bin in 0..<freqBins {
            let freq = Float(bin) * binWidth

            // Simple frequency-based source separation heuristics
            // In production, these would be learned neural network masks

            // Bass: 20-250 Hz
            if freq < 250 {
                bassMask[bin] = 0.7
                drumMask[bin] = 0.2
                vocalMask[bin] = 0.05
                otherMask[bin] = 0.05
            }
            // Low-mids: 250-500 Hz (kick, bass guitar, male vocals)
            else if freq < 500 {
                bassMask[bin] = 0.4
                drumMask[bin] = 0.3
                vocalMask[bin] = 0.2
                otherMask[bin] = 0.1
            }
            // Mids: 500-2000 Hz (vocals, snare, guitars)
            else if freq < 2000 {
                vocalMask[bin] = 0.5
                drumMask[bin] = 0.2
                bassMask[bin] = 0.1
                otherMask[bin] = 0.2
            }
            // Upper-mids: 2000-4000 Hz (vocal presence, hi-hats)
            else if freq < 4000 {
                vocalMask[bin] = 0.4
                drumMask[bin] = 0.3
                otherMask[bin] = 0.2
                bassMask[bin] = 0.1
            }
            // Highs: 4000-10000 Hz (brilliance, cymbals)
            else if freq < 10000 {
                drumMask[bin] = 0.4
                otherMask[bin] = 0.3
                vocalMask[bin] = 0.2
                bassMask[bin] = 0.1
            }
            // Air: 10000+ Hz
            else {
                drumMask[bin] = 0.5
                otherMask[bin] = 0.3
                vocalMask[bin] = 0.15
                bassMask[bin] = 0.05
            }
        }
    }
}
