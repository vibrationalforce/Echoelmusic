// CrossfadeEngine.swift
// Echoelmusic
//
// Sample-accurate crossfade engine for professional audio editing.
// Supports multiple crossfade curves for seamless transitions
// between audio clips.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import Accelerate

// MARK: - Crossfade Curve

/// Crossfade curve shapes
public enum CrossfadeCurve: String, CaseIterable, Codable, Sendable {
    case linear = "Linear"
    case equalPower = "Equal Power"
    case sCurve = "S-Curve"
    case exponential = "Exponential"
    case logarithmic = "Logarithmic"
    case cosine = "Cosine"

    /// Generate fade-in gain curve
    public func fadeInGain(at position: Float) -> Float {
        let t = max(0, min(1, position))
        switch self {
        case .linear:
            return t
        case .equalPower:
            return sin(t * .pi / 2)
        case .sCurve:
            return t * t * (3 - 2 * t)
        case .exponential:
            return t * t
        case .logarithmic:
            return sqrt(t)
        case .cosine:
            return (1 - cos(t * .pi)) / 2
        }
    }

    /// Generate fade-out gain curve
    public func fadeOutGain(at position: Float) -> Float {
        let t = max(0, min(1, position))
        switch self {
        case .linear:
            return 1 - t
        case .equalPower:
            return cos(t * .pi / 2)
        case .sCurve:
            let s = 1 - t
            return s * s * (3 - 2 * s)
        case .exponential:
            let s = 1 - t
            return s * s
        case .logarithmic:
            return sqrt(1 - t)
        case .cosine:
            return (1 + cos(t * .pi)) / 2
        }
    }
}

// MARK: - Crossfade Region

/// Defines a crossfade between two audio regions
public struct CrossfadeRegion: Identifiable, Codable, Sendable {
    public let id: UUID
    public var startSample: Int64
    public var lengthInSamples: Int64
    public var curve: CrossfadeCurve
    public var isSymmetric: Bool

    /// Duration in seconds at given sample rate
    public func duration(sampleRate: Double) -> Double {
        return Double(lengthInSamples) / sampleRate
    }

    public init(
        id: UUID = UUID(),
        startSample: Int64,
        lengthInSamples: Int64,
        curve: CrossfadeCurve = .equalPower,
        isSymmetric: Bool = true
    ) {
        self.id = id
        self.startSample = startSample
        self.lengthInSamples = lengthInSamples
        self.curve = curve
        self.isSymmetric = isSymmetric
    }
}

// MARK: - Crossfade Engine

/// Sample-accurate crossfade processing engine
public final class CrossfadeEngine {

    // MARK: - Properties

    private let sampleRate: Double

    // MARK: - Initialization

    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Public API

    /// Apply crossfade between two audio buffers at a specific point
    /// - Parameters:
    ///   - outgoing: Audio buffer being faded out
    ///   - incoming: Audio buffer being faded in
    ///   - crossfadeLength: Length of crossfade in samples
    ///   - curve: Crossfade curve shape
    /// - Returns: Crossfaded audio buffer
    public func applyCrossfade(
        outgoing: AVAudioPCMBuffer,
        incoming: AVAudioPCMBuffer,
        crossfadeLength: Int,
        curve: CrossfadeCurve = .equalPower
    ) -> AVAudioPCMBuffer? {
        let format = outgoing.format
        let outLength = Int(outgoing.frameLength)
        let inLength = Int(incoming.frameLength)

        let actualCrossfade = min(crossfadeLength, outLength, inLength)
        let totalLength = outLength + inLength - actualCrossfade

        guard let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalLength)) else {
            return nil
        }
        result.frameLength = AVAudioFrameCount(totalLength)

        let channelCount = Int(format.channelCount)

        for ch in 0..<channelCount {
            guard let outData = outgoing.floatChannelData?[ch],
                  let inData = incoming.floatChannelData?[ch],
                  let resultData = result.floatChannelData?[ch] else { continue }

            // Copy pre-crossfade region from outgoing
            let preCrossfadeLength = outLength - actualCrossfade
            if preCrossfadeLength > 0 {
                memcpy(resultData, outData, preCrossfadeLength * MemoryLayout<Float>.size)
            }

            // Apply crossfade region
            for i in 0..<actualCrossfade {
                let position = Float(i) / Float(actualCrossfade)
                let fadeOut = curve.fadeOutGain(at: position)
                let fadeIn = curve.fadeInGain(at: position)

                let outSample = outData[preCrossfadeLength + i] * fadeOut
                let inSample = inData[i] * fadeIn

                resultData[preCrossfadeLength + i] = outSample + inSample
            }

            // Copy post-crossfade region from incoming
            let postCrossfadeStart = actualCrossfade
            let postCrossfadeLength = inLength - actualCrossfade
            if postCrossfadeLength > 0 {
                memcpy(
                    resultData.advanced(by: preCrossfadeLength + actualCrossfade),
                    inData.advanced(by: postCrossfadeStart),
                    postCrossfadeLength * MemoryLayout<Float>.size
                )
            }
        }

        return result
    }

    /// Apply fade-in to an audio buffer
    public func applyFadeIn(
        buffer: AVAudioPCMBuffer,
        fadeLengthSamples: Int,
        curve: CrossfadeCurve = .equalPower
    ) {
        let fadeLength = min(fadeLengthSamples, Int(buffer.frameLength))

        for ch in 0..<Int(buffer.format.channelCount) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<fadeLength {
                let position = Float(i) / Float(fadeLength)
                data[i] *= curve.fadeInGain(at: position)
            }
        }
    }

    /// Apply fade-out to an audio buffer
    public func applyFadeOut(
        buffer: AVAudioPCMBuffer,
        fadeLengthSamples: Int,
        curve: CrossfadeCurve = .equalPower
    ) {
        let totalFrames = Int(buffer.frameLength)
        let fadeLength = min(fadeLengthSamples, totalFrames)
        let fadeStart = totalFrames - fadeLength

        for ch in 0..<Int(buffer.format.channelCount) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<fadeLength {
                let position = Float(i) / Float(fadeLength)
                data[fadeStart + i] *= curve.fadeOutGain(at: position)
            }
        }
    }

    /// Generate crossfade gain table for real-time use
    /// - Parameters:
    ///   - length: Number of samples in the crossfade
    ///   - curve: Curve shape
    /// - Returns: Tuple of (fadeIn, fadeOut) gain arrays
    public func generateGainTable(
        length: Int,
        curve: CrossfadeCurve = .equalPower
    ) -> (fadeIn: [Float], fadeOut: [Float]) {
        var fadeIn = [Float](repeating: 0, count: length)
        var fadeOut = [Float](repeating: 0, count: length)

        for i in 0..<length {
            let position = Float(i) / Float(length)
            fadeIn[i] = curve.fadeInGain(at: position)
            fadeOut[i] = curve.fadeOutGain(at: position)
        }

        return (fadeIn, fadeOut)
    }

    /// Milliseconds to samples conversion
    public func millisecondsToSamples(_ ms: Double) -> Int {
        return Int(ms / 1000.0 * sampleRate)
    }

    /// Samples to milliseconds conversion
    public func samplesToMilliseconds(_ samples: Int) -> Double {
        return Double(samples) / sampleRate * 1000.0
    }
}
