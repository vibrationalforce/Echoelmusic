import Foundation
import AVFoundation
import Accelerate

/// Extracts FFT (Fast Fourier Transform) data from audio files and buffers
/// Provides frequency domain analysis for visualization
class AudioFFTExtractor {

    // MARK: - Configuration

    private let fftSize: Int
    private let sampleRate: Double
    private let hopSize: Int

    // MARK: - FFT Components

    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var realParts: [Float]
    private var imagParts: [Float]
    private var magnitudes: [Float]

    // MARK: - Initialization

    init(fftSize: Int = 2048, sampleRate: Double = 44100.0) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.hopSize = fftSize / 4  // 75% overlap

        // Initialize buffers
        self.realParts = [Float](repeating: 0, count: fftSize)
        self.imagParts = [Float](repeating: 0, count: fftSize)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)

        // Create Hann window
        self.window = Self.createHannWindow(size: fftSize)

        // Setup FFT
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )

        print("🎵 AudioFFTExtractor initialized")
        print("   FFT Size: \(fftSize)")
        print("   Sample Rate: \(Int(sampleRate)) Hz")
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }


    // MARK: - FFT from Audio Buffer

    /// Extract FFT data from audio buffer
    /// - Parameter buffer: Audio PCM buffer
    /// - Returns: Array of magnitude values (0.0 - 1.0)
    func extractFFT(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return [Float](repeating: 0, count: fftSize / 2)
        }

        let frameLength = Int(buffer.frameLength)
        let channel = channelData[0]

        // Copy and window the data
        var samples = [Float](repeating: 0, count: fftSize)
        let copyLength = min(frameLength, fftSize)

        for i in 0..<copyLength {
            samples[i] = channel[i] * window[i]
        }

        return performFFT(on: samples)
    }


    // MARK: - FFT from Audio File

    /// Extract FFT data from audio file at specific time
    /// - Parameters:
    ///   - url: URL of audio file
    ///   - time: Time position in seconds
    /// - Returns: Array of magnitude values
    func extractFFT(from url: URL, at time: TimeInterval) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        // Calculate frame position
        let framePosition = AVAudioFramePosition(time * format.sampleRate)

        // Seek to position
        file.framePosition = framePosition

        // Read buffer
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(fftSize)
        ) else {
            throw AudioFFTError.bufferCreationFailed
        }

        try file.read(into: buffer)

        return extractFFT(from: buffer)
    }


    // MARK: - FFT from Session

    /// Extract FFT data timeline from entire audio session
    /// - Parameters:
    ///   - url: URL of audio file
    ///   - duration: Total duration in seconds
    /// - Returns: Array of FFT frames over time
    func extractFFTTimeline(from url: URL, duration: TimeInterval) throws -> [[Float]] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat

        var timeline: [[Float]] = []

        // Calculate number of frames
        let numFrames = Int(duration * Double(sampleRate) / Double(hopSize))

        print("📊 Extracting FFT timeline...")
        print("   Duration: \(String(format: "%.2f", duration))s")
        print("   Frames: \(numFrames)")

        // Read and process in chunks
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(fftSize)
        ) else {
            throw AudioFFTError.bufferCreationFailed
        }

        file.framePosition = 0

        for frameIndex in 0..<numFrames {
            // Read next chunk
            do {
                try file.read(into: buffer, frameCount: AVAudioFrameCount(hopSize))
            } catch {
                // End of file reached
                break
            }

            // Extract FFT
            let fftData = extractFFT(from: buffer)
            timeline.append(fftData)

            // Progress logging
            if frameIndex % (numFrames / 10) == 0 {
                let progress = Double(frameIndex) / Double(numFrames) * 100.0
                print("   Progress: \(Int(progress))%")
            }
        }

        print("   ✅ Extracted \(timeline.count) FFT frames")

        return timeline
    }


    // MARK: - Core FFT Processing

    /// Perform FFT on audio samples
    /// - Parameter samples: Array of audio samples (windowed)
    /// - Returns: Array of magnitude values (normalized 0.0 - 1.0)
    private func performFFT(on samples: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else {
            return [Float](repeating: 0, count: fftSize / 2)
        }

        // Copy samples to real parts
        realParts = samples
        imagParts = [Float](repeating: 0, count: fftSize)

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realParts, &imagParts, &realParts, &imagParts)

        // Calculate magnitudes
        for i in 0..<(fftSize / 2) {
            let real = realParts[i]
            let imag = imagParts[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }

        // Normalize to 0-1 range
        var max: Float = 0
        vDSP_maxv(magnitudes, 1, &max, vDSP_Length(magnitudes.count))

        if max > 0 {
            var normalizedMagnitudes = magnitudes
            vDSP_vsdiv(magnitudes, 1, &max, &normalizedMagnitudes, 1, vDSP_Length(magnitudes.count))
            return normalizedMagnitudes
        }

        return magnitudes
    }


    // MARK: - Frequency Analysis

    /// Get dominant frequency from FFT data
    /// - Parameter fftData: FFT magnitude array
    /// - Returns: Dominant frequency in Hz
    func getDominantFrequency(from fftData: [Float]) -> Float {
        // Find peak bin
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(fftData, 1, &maxValue, &maxIndex, vDSP_Length(fftData.count))

        // Convert bin to frequency
        let frequency = Float(maxIndex) * Float(sampleRate) / Float(fftSize)

        return frequency
    }

    /// Get frequency bins for specific range
    /// - Parameters:
    ///   - fftData: FFT magnitude array
    ///   - lowFreq: Low frequency bound (Hz)
    ///   - highFreq: High frequency bound (Hz)
    /// - Returns: Array of magnitudes in frequency range
    func getFrequencyRange(from fftData: [Float], lowFreq: Float, highFreq: Float) -> [Float] {
        let binLow = Int(lowFreq * Float(fftSize) / Float(sampleRate))
        let binHigh = Int(highFreq * Float(fftSize) / Float(sampleRate))

        let startIndex = max(0, binLow)
        let endIndex = min(fftData.count, binHigh)

        guard startIndex < endIndex else {
            return []
        }

        return Array(fftData[startIndex..<endIndex])
    }


    // MARK: - Utility Functions

    /// Create Hann window function
    private static func createHannWindow(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)

        for i in 0..<size {
            let phase = 2.0 * Float.pi * Float(i) / Float(size - 1)
            window[i] = 0.5 * (1.0 - cos(phase))
        }

        return window
    }

    /// Downsample FFT data for visualization
    /// - Parameters:
    ///   - fftData: Full FFT data
    ///   - targetSize: Desired output size (e.g., 32 bars)
    /// - Returns: Downsampled array
    static func downsample(_ fftData: [Float], to targetSize: Int) -> [Float] {
        guard fftData.count > targetSize else {
            return fftData
        }

        var downsampled = [Float](repeating: 0, count: targetSize)
        let binSize = fftData.count / targetSize

        for i in 0..<targetSize {
            let startIndex = i * binSize
            let endIndex = min(startIndex + binSize, fftData.count)

            // Average bins
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += fftData[j]
            }
            downsampled[i] = sum / Float(endIndex - startIndex)
        }

        return downsampled
    }
}


// MARK: - Session Extension

extension Session {
    /// Extract FFT timeline from session's first track
    func extractFFTTimeline(fftExtractor: AudioFFTExtractor) throws -> [[Float]] {
        guard let firstTrack = tracks.first,
              let trackURL = firstTrack.url else {
            throw AudioFFTError.noAudioTrack
        }

        return try fftExtractor.extractFFTTimeline(
            from: trackURL,
            duration: duration
        )
    }

    /// Get FFT data for specific time
    func getFFTData(at time: TimeInterval, fftExtractor: AudioFFTExtractor) throws -> [Float] {
        guard let firstTrack = tracks.first,
              let trackURL = firstTrack.url else {
            throw AudioFFTError.noAudioTrack
        }

        return try fftExtractor.extractFFT(from: trackURL, at: time)
    }
}


// MARK: - Errors

enum AudioFFTError: LocalizedError {
    case bufferCreationFailed
    case noAudioTrack
    case fileReadError(String)

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noAudioTrack:
            return "Session has no audio tracks"
        case .fileReadError(let message):
            return "File read error: \(message)"
        }
    }
}
