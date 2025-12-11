// SafeDSPBuffer.swift
// Echoelmusic - Safe DSP Buffer Operations
// SPDX-License-Identifier: MIT
//
// Type-safe wrappers for DSP operations eliminating unsafe pointer force unwraps

import Foundation
import Accelerate

// MARK: - Safe DSP Buffer

/// Type-safe wrapper for DSP audio buffers with bounds checking
public final class SafeDSPBuffer: @unchecked Sendable {

    public let capacity: Int
    public private(set) var count: Int

    private var realBuffer: [Float]
    private var imagBuffer: [Float]

    public init(capacity: Int) {
        self.capacity = capacity
        self.count = 0
        self.realBuffer = [Float](repeating: 0, count: capacity)
        self.imagBuffer = [Float](repeating: 0, count: capacity)
    }

    // MARK: - Safe Access

    /// Get real part at index with bounds checking
    public func real(at index: Int) -> Float? {
        guard index >= 0 && index < count else { return nil }
        return realBuffer[index]
    }

    /// Get imaginary part at index with bounds checking
    public func imag(at index: Int) -> Float? {
        guard index >= 0 && index < count else { return nil }
        return imagBuffer[index]
    }

    /// Set real part at index with bounds checking
    public func setReal(_ value: Float, at index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        realBuffer[index] = value
        count = max(count, index + 1)
        return true
    }

    /// Set imaginary part at index with bounds checking
    public func setImag(_ value: Float, at index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        imagBuffer[index] = value
        count = max(count, index + 1)
        return true
    }

    /// Set complex value at index
    public func setComplex(real: Float, imag: Float, at index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        realBuffer[index] = real
        imagBuffer[index] = imag
        count = max(count, index + 1)
        return true
    }

    /// Get complex value at index
    public func complex(at index: Int) -> (real: Float, imag: Float)? {
        guard index >= 0 && index < count else { return nil }
        return (realBuffer[index], imagBuffer[index])
    }

    // MARK: - Bulk Operations

    /// Copy from float array (real only)
    public func copyFrom(_ source: [Float]) {
        let copyCount = min(source.count, capacity)
        for i in 0..<copyCount {
            realBuffer[i] = source[i]
            imagBuffer[i] = 0
        }
        count = copyCount
    }

    /// Copy from split complex
    public func copyFromSplit(real: [Float], imag: [Float]) {
        let copyCount = min(real.count, imag.count, capacity)
        for i in 0..<copyCount {
            realBuffer[i] = real[i]
            imagBuffer[i] = imag[i]
        }
        count = copyCount
    }

    /// Export to float array (real only)
    public func toFloatArray() -> [Float] {
        Array(realBuffer.prefix(count))
    }

    /// Export to split arrays
    public func toSplitArrays() -> (real: [Float], imag: [Float]) {
        (Array(realBuffer.prefix(count)), Array(imagBuffer.prefix(count)))
    }

    // MARK: - Safe vDSP Operations

    /// Perform FFT safely
    public func performFFT(fftSetup: vDSP_DFT_Setup, direction: vDSP_DFT_Direction = .FORWARD) {
        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBase = realPtr.baseAddress,
                      let imagBase = imagPtr.baseAddress else {
                    return
                }
                vDSP_DFT_Execute(fftSetup, realBase, imagBase, realBase, imagBase)
            }
        }
    }

    /// Calculate magnitude spectrum safely
    public func magnitudeSpectrum() -> [Float] {
        var magnitudes = [Float](repeating: 0, count: count)

        for i in 0..<count {
            let r = realBuffer[i]
            let im = imagBuffer[i]
            magnitudes[i] = sqrt(r * r + im * im)
        }

        return magnitudes
    }

    /// Calculate power spectrum safely
    public func powerSpectrum() -> [Float] {
        var powers = [Float](repeating: 0, count: count)

        for i in 0..<count {
            let r = realBuffer[i]
            let im = imagBuffer[i]
            powers[i] = r * r + im * im
        }

        return powers
    }

    /// Apply Hamming window
    public func applyHammingWindow() {
        guard count > 1 else { return }
        let n = Float(count - 1)

        for i in 0..<count {
            let window = 0.54 - 0.46 * cos(2.0 * .pi * Float(i) / n)
            realBuffer[i] *= window
        }
    }

    /// Apply Hann window
    public func applyHannWindow() {
        guard count > 1 else { return }
        let n = Float(count - 1)

        for i in 0..<count {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / n))
            realBuffer[i] *= window
        }
    }

    // MARK: - Safe vDSP Wrappers

    /// Safe wrapper for vDSP_zvmags (complex magnitude squared)
    public func computeMagnitudeSquared(into output: inout [Float]) {
        guard output.count >= count else { return }

        realBuffer.withUnsafeBufferPointer { realPtr in
            imagBuffer.withUnsafeBufferPointer { imagPtr in
                output.withUnsafeMutableBufferPointer { outPtr in
                    guard let realBase = realPtr.baseAddress,
                          let imagBase = imagPtr.baseAddress,
                          let outBase = outPtr.baseAddress else {
                        return
                    }

                    var splitComplex = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realBase),
                        imagp: UnsafeMutablePointer(mutating: imagBase)
                    )

                    vDSP_zvmags(&splitComplex, 1, outBase, 1, vDSP_Length(count))
                }
            }
        }
    }

    /// Reset buffer to zeros
    public func clear() {
        realBuffer = [Float](repeating: 0, count: capacity)
        imagBuffer = [Float](repeating: 0, count: capacity)
        count = 0
    }
}

// MARK: - Safe Audio Buffer

/// Type-safe wrapper for mono/stereo audio buffers
public final class SafeAudioBuffer: @unchecked Sendable {

    public enum ChannelLayout: Int, Sendable {
        case mono = 1
        case stereo = 2
        case surround51 = 6
        case surround71 = 8
    }

    public let channels: Int
    public let frameCapacity: Int
    public private(set) var frameCount: Int

    private var channelBuffers: [[Float]]

    public init(channels: Int, frameCapacity: Int) {
        self.channels = max(1, channels)
        self.frameCapacity = frameCapacity
        self.frameCount = 0
        self.channelBuffers = (0..<self.channels).map { _ in
            [Float](repeating: 0, count: frameCapacity)
        }
    }

    public convenience init(layout: ChannelLayout, frameCapacity: Int) {
        self.init(channels: layout.rawValue, frameCapacity: frameCapacity)
    }

    // MARK: - Safe Access

    /// Get sample with bounds checking
    public func sample(channel: Int, frame: Int) -> Float? {
        guard channel >= 0 && channel < channels,
              frame >= 0 && frame < frameCount else {
            return nil
        }
        return channelBuffers[channel][frame]
    }

    /// Set sample with bounds checking
    public func setSample(_ value: Float, channel: Int, frame: Int) -> Bool {
        guard channel >= 0 && channel < channels,
              frame >= 0 && frame < frameCapacity else {
            return false
        }
        channelBuffers[channel][frame] = value
        frameCount = max(frameCount, frame + 1)
        return true
    }

    /// Get entire channel buffer
    public func channel(_ index: Int) -> [Float]? {
        guard index >= 0 && index < channels else { return nil }
        return Array(channelBuffers[index].prefix(frameCount))
    }

    /// Set entire channel buffer
    public func setChannel(_ index: Int, samples: [Float]) -> Bool {
        guard index >= 0 && index < channels else { return false }
        let copyCount = min(samples.count, frameCapacity)
        for i in 0..<copyCount {
            channelBuffers[index][i] = samples[i]
        }
        frameCount = max(frameCount, copyCount)
        return true
    }

    // MARK: - Stereo Operations

    /// Get left channel (mono returns the only channel)
    public var leftChannel: [Float] {
        Array(channelBuffers[0].prefix(frameCount))
    }

    /// Get right channel (mono returns left)
    public var rightChannel: [Float] {
        let index = channels > 1 ? 1 : 0
        return Array(channelBuffers[index].prefix(frameCount))
    }

    /// Convert to interleaved format
    public func toInterleaved() -> [Float] {
        var interleaved = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            for channel in 0..<channels {
                interleaved[frame * channels + channel] = channelBuffers[channel][frame]
            }
        }
        return interleaved
    }

    /// Import from interleaved format
    public func fromInterleaved(_ samples: [Float], channels: Int) {
        let expectedChannels = min(channels, self.channels)
        let frameCount = samples.count / expectedChannels

        for frame in 0..<min(frameCount, frameCapacity) {
            for channel in 0..<expectedChannels {
                channelBuffers[channel][frame] = samples[frame * channels + channel]
            }
        }
        self.frameCount = min(frameCount, frameCapacity)
    }

    // MARK: - Audio Processing

    /// Calculate RMS level for channel
    public func rmsLevel(channel: Int) -> Float? {
        guard channel >= 0 && channel < channels, frameCount > 0 else { return nil }

        var sumSquares: Float = 0
        for i in 0..<frameCount {
            let sample = channelBuffers[channel][i]
            sumSquares += sample * sample
        }
        return sqrt(sumSquares / Float(frameCount))
    }

    /// Calculate peak level for channel
    public func peakLevel(channel: Int) -> Float? {
        guard channel >= 0 && channel < channels, frameCount > 0 else { return nil }

        var peak: Float = 0
        for i in 0..<frameCount {
            peak = max(peak, abs(channelBuffers[channel][i]))
        }
        return peak
    }

    /// Apply gain to all channels
    public func applyGain(_ gain: Float) {
        for channel in 0..<channels {
            for i in 0..<frameCount {
                channelBuffers[channel][i] *= gain
            }
        }
    }

    /// Mix with another buffer
    public func mix(with other: SafeAudioBuffer, gain: Float = 1.0) {
        let mixChannels = min(channels, other.channels)
        let mixFrames = min(frameCount, other.frameCount)

        for channel in 0..<mixChannels {
            for frame in 0..<mixFrames {
                if let otherSample = other.sample(channel: channel, frame: frame) {
                    channelBuffers[channel][frame] += otherSample * gain
                }
            }
        }
    }

    /// Clear buffer
    public func clear() {
        for channel in 0..<channels {
            channelBuffers[channel] = [Float](repeating: 0, count: frameCapacity)
        }
        frameCount = 0
    }
}

// MARK: - Safe Memory Pool

/// Thread-safe memory pool for DSP buffers to avoid allocation in audio thread
public actor DSPBufferPool {

    private var dspBuffers: [SafeDSPBuffer] = []
    private var audioBuffers: [SafeAudioBuffer] = []
    private var inUse: Set<ObjectIdentifier> = []

    private let maxPoolSize: Int
    private let defaultDSPCapacity: Int
    private let defaultAudioFrames: Int

    public init(
        maxPoolSize: Int = 16,
        defaultDSPCapacity: Int = 4096,
        defaultAudioFrames: Int = 1024
    ) {
        self.maxPoolSize = maxPoolSize
        self.defaultDSPCapacity = defaultDSPCapacity
        self.defaultAudioFrames = defaultAudioFrames
    }

    /// Acquire a DSP buffer from pool
    public func acquireDSPBuffer(capacity: Int? = nil) -> SafeDSPBuffer {
        let requestedCapacity = capacity ?? defaultDSPCapacity

        // Try to find existing buffer
        if let index = dspBuffers.firstIndex(where: {
            $0.capacity >= requestedCapacity && !inUse.contains(ObjectIdentifier($0))
        }) {
            let buffer = dspBuffers[index]
            inUse.insert(ObjectIdentifier(buffer))
            buffer.clear()
            return buffer
        }

        // Create new buffer
        let buffer = SafeDSPBuffer(capacity: requestedCapacity)
        if dspBuffers.count < maxPoolSize {
            dspBuffers.append(buffer)
        }
        inUse.insert(ObjectIdentifier(buffer))
        return buffer
    }

    /// Release a DSP buffer back to pool
    public func release(_ buffer: SafeDSPBuffer) {
        inUse.remove(ObjectIdentifier(buffer))
    }

    /// Acquire an audio buffer from pool
    public func acquireAudioBuffer(channels: Int = 2, frames: Int? = nil) -> SafeAudioBuffer {
        let requestedFrames = frames ?? defaultAudioFrames

        // Try to find existing buffer
        if let index = audioBuffers.firstIndex(where: {
            $0.channels >= channels &&
            $0.frameCapacity >= requestedFrames &&
            !inUse.contains(ObjectIdentifier($0))
        }) {
            let buffer = audioBuffers[index]
            inUse.insert(ObjectIdentifier(buffer))
            buffer.clear()
            return buffer
        }

        // Create new buffer
        let buffer = SafeAudioBuffer(channels: channels, frameCapacity: requestedFrames)
        if audioBuffers.count < maxPoolSize {
            audioBuffers.append(buffer)
        }
        inUse.insert(ObjectIdentifier(buffer))
        return buffer
    }

    /// Release an audio buffer back to pool
    public func release(_ buffer: SafeAudioBuffer) {
        inUse.remove(ObjectIdentifier(buffer))
    }

    /// Clear all buffers (call during cleanup)
    public func clearAll() {
        dspBuffers.removeAll()
        audioBuffers.removeAll()
        inUse.removeAll()
    }

    /// Get pool statistics
    public func stats() -> (dspCount: Int, audioCount: Int, inUseCount: Int) {
        (dspBuffers.count, audioBuffers.count, inUse.count)
    }
}

// MARK: - Global Buffer Pool

/// Shared buffer pool for the application
public let sharedBufferPool = DSPBufferPool()
