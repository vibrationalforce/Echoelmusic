//
//  NumericExtensions.swift
//  Echoelmusic
//
//  Shared numeric extensions to avoid duplicate declarations
//

import Foundation
import AVFoundation

// MARK: - Clamped Extension (Consolidated)

/// Generic clamped extension for all Comparable types
/// This replaces all individual implementations across the codebase
extension Comparable {
    /// Clamps the value to the specified range
    /// - Parameter range: The closed range to clamp to
    /// - Returns: The clamped value
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Numeric Utilities

extension FloatingPoint {
    /// Maps a value from one range to another
    /// - Parameters:
    ///   - fromRange: The source range
    ///   - toRange: The target range
    /// - Returns: The mapped value
    func mapped(from fromRange: ClosedRange<Self>, to toRange: ClosedRange<Self>) -> Self {
        let fromLength = fromRange.upperBound - fromRange.lowerBound
        let toLength = toRange.upperBound - toRange.lowerBound
        guard fromLength != 0 else { return toRange.lowerBound }
        let normalized = (self - fromRange.lowerBound) / fromLength
        return toRange.lowerBound + normalized * toLength
    }

    /// Linear interpolation between two values
    /// - Parameters:
    ///   - to: The target value
    ///   - amount: The interpolation amount (0-1)
    /// - Returns: The interpolated value
    func lerp(to: Self, amount: Self) -> Self {
        self + (to - self) * amount
    }
}

extension BinaryInteger {
    /// Maps an integer value from one range to another
    func mapped(from fromRange: ClosedRange<Self>, to toRange: ClosedRange<Self>) -> Self {
        let fromLength = fromRange.upperBound - fromRange.lowerBound
        let toLength = toRange.upperBound - toRange.lowerBound
        guard fromLength != 0 else { return toRange.lowerBound }
        let normalized = (self - fromRange.lowerBound) * toLength / fromLength
        return toRange.lowerBound + normalized
    }
}

// MARK: - AVAudioPCMBuffer Convenience

extension AVAudioPCMBuffer {
    /// Extracts a Float array from a single channel, avoiding repeated UnsafeBufferPointer boilerplate.
    ///
    /// - Parameter channel: The channel index (default 0).
    /// - Returns: A `[Float]` copy of the channel data, or empty if unavailable.
    func floatArray(channel: Int = 0) -> [Float] {
        guard let data = floatChannelData,
              channel < Int(format.channelCount) else { return [] }
        return Array(UnsafeBufferPointer(start: data[channel], count: Int(frameLength)))
    }
}
