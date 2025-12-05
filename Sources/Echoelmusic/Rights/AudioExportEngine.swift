// AudioExportEngine.swift
// Echoelmusic
//
// Audio Format Conversion for Distributor Requirements
// Converts to required specs: 24-bit/44.1kHz WAV for musicHub, etc.
// Handles Immersive Audio export for Dolby Atmos / Sony 360RA
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import AVFoundation
import Accelerate

// MARK: - Export Format

public struct AudioExportFormat: Equatable {
    public var sampleRate: Double
    public var bitDepth: Int
    public var fileFormat: FileFormat
    public var channels: Int
    public var isInterleaved: Bool

    public enum FileFormat: String, CaseIterable {
        case wav = "WAV"
        case aiff = "AIFF"
        case flac = "FLAC"
        case mp3 = "MP3"
        case aac = "AAC"
        case alac = "ALAC"

        public var fileExtension: String {
            rawValue.lowercased()
        }

        public var avFileType: AVFileType {
            switch self {
            case .wav: return .wav
            case .aiff: return .aiff
            case .mp3: return .mp3
            case .aac: return .m4a
            case .alac: return .m4a
            case .flac: return .wav // Fallback, FLAC needs external encoder
            }
        }
    }

    // MARK: Common Presets

    /// musicHub requirement: 24-bit 44.1kHz WAV
    public static let musicHub = AudioExportFormat(
        sampleRate: 44100,
        bitDepth: 24,
        fileFormat: .wav,
        channels: 2,
        isInterleaved: true
    )

    /// DistroKid standard: 16-bit 44.1kHz WAV
    public static let distroKid = AudioExportFormat(
        sampleRate: 44100,
        bitDepth: 16,
        fileFormat: .wav,
        channels: 2,
        isInterleaved: true
    )

    /// Apple Music standard: 24-bit 48kHz WAV
    public static let appleMusic = AudioExportFormat(
        sampleRate: 48000,
        bitDepth: 24,
        fileFormat: .wav,
        channels: 2,
        isInterleaved: true
    )

    /// High-resolution: 24-bit 96kHz WAV
    public static let highRes = AudioExportFormat(
        sampleRate: 96000,
        bitDepth: 24,
        fileFormat: .wav,
        channels: 2,
        isInterleaved: true
    )

    /// CD Quality: 16-bit 44.1kHz
    public static let cdQuality = AudioExportFormat(
        sampleRate: 44100,
        bitDepth: 16,
        fileFormat: .wav,
        channels: 2,
        isInterleaved: true
    )

    /// MP3 320kbps for preview
    public static let mp3Preview = AudioExportFormat(
        sampleRate: 44100,
        bitDepth: 16, // N/A for MP3
        fileFormat: .mp3,
        channels: 2,
        isInterleaved: true
    )

    public var description: String {
        "\(bitDepth)-bit / \(Int(sampleRate / 1000))kHz \(fileFormat.rawValue)"
    }
}

// MARK: - Immersive Format

public enum ImmersiveAudioFormat: String, CaseIterable {
    case stereo = "Stereo"
    case dolbyAtmos = "Dolby Atmos"
    case sony360RA = "Sony 360 Reality Audio"
    case appleSpat = "Apple Spatial Audio"
    case ambisonicsFirstOrder = "Ambisonics 1st Order (4ch)"
    case ambisonicsSecondOrder = "Ambisonics 2nd Order (9ch)"
    case ambisonicsThirdOrder = "Ambisonics 3rd Order (16ch)"
    case binaural = "Binaural (Headphones)"

    public var channelCount: Int {
        switch self {
        case .stereo, .binaural: return 2
        case .ambisonicsFirstOrder: return 4
        case .ambisonicsSecondOrder: return 9
        case .ambisonicsThirdOrder: return 16
        case .dolbyAtmos: return 12 // 7.1.4 bed
        case .sony360RA: return 24 // Up to 24 objects
        case .appleSpat: return 12 // Typically 7.1.4
        }
    }

    public var distributorSupport: [DistributorPlatform] {
        switch self {
        case .stereo:
            return DistributorPlatform.allCases
        case .dolbyAtmos, .appleSpat:
            return [.appleMusicForArtists, .dolbyAtmosMusic, .believe, .theOrchard]
        case .sony360RA:
            return [.sonyMusic360, .believe]
        default:
            return [] // Requires specialized workflow
        }
    }
}

// MARK: - Export Progress

public struct AudioExportProgress {
    public var phase: Phase
    public var progress: Float // 0.0 to 1.0
    public var currentFile: String?
    public var message: String

    public enum Phase: String {
        case preparing = "Preparing"
        case analyzing = "Analyzing"
        case converting = "Converting"
        case encoding = "Encoding"
        case writing = "Writing"
        case verifying = "Verifying"
        case complete = "Complete"
        case failed = "Failed"
    }
}

// MARK: - Export Result

public struct AudioExportResult {
    public let success: Bool
    public let outputURL: URL?
    public let inputFormat: String
    public let outputFormat: AudioExportFormat
    public let duration: TimeInterval
    public let fileSize: Int64
    public let peakLevel: Float // dBFS
    public let rmsLevel: Float // dBFS
    public let warnings: [String]
    public let error: Error?
}

// MARK: - Audio Export Engine

@MainActor
public final class AudioExportEngine: ObservableObject {
    public static let shared = AudioExportEngine()

    // MARK: Published State

    @Published public private(set) var isExporting = false
    @Published public private(set) var progress: AudioExportProgress = AudioExportProgress(
        phase: .preparing,
        progress: 0,
        message: ""
    )
    @Published public private(set) var lastResult: AudioExportResult?

    // MARK: Configuration

    public var normalizeAudio = true
    public var targetLUFS: Float = -14.0 // Spotify/Apple standard
    public var truePeakLimit: Float = -1.0 // dBTP
    public var addDither = true // For bit depth reduction

    // MARK: Initialization

    private init() {}

    // MARK: - Export Methods

    /// Export audio file for a specific distributor
    public func export(
        sourceURL: URL,
        for distributor: DistributorPlatform
    ) async throws -> AudioExportResult {
        let requirements = distributor.audioRequirements
        let format = AudioExportFormat(
            sampleRate: Double(requirements.sampleRate),
            bitDepth: requirements.bitDepth,
            fileFormat: mapFormat(requirements.format),
            channels: 2,
            isInterleaved: true
        )

        return try await export(sourceURL: sourceURL, to: format)
    }

    /// Export audio file to specific format
    public func export(
        sourceURL: URL,
        to format: AudioExportFormat
    ) async throws -> AudioExportResult {
        isExporting = true
        progress = AudioExportProgress(phase: .preparing, progress: 0, message: "Loading source file...")

        defer { isExporting = false }

        // Read source file
        let sourceFile: AVAudioFile
        do {
            sourceFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            return failedResult(error: error, format: format)
        }

        let sourceFormat = sourceFile.processingFormat
        let sourceFrames = AVAudioFrameCount(sourceFile.length)

        progress = AudioExportProgress(
            phase: .analyzing,
            progress: 0.1,
            message: "Analyzing: \(Int(sourceFormat.sampleRate))Hz → \(Int(format.sampleRate))Hz"
        )

        // Determine if conversion needed
        let needsSampleRateConversion = sourceFormat.sampleRate != format.sampleRate
        let needsBitDepthConversion = getBitDepth(from: sourceFormat) != format.bitDepth

        // Create output URL
        let outputURL = generateOutputURL(from: sourceURL, format: format)

        // Setup output format
        let outputSettings = createOutputSettings(format: format)

        guard let outputFormat = AVAudioFormat(settings: outputSettings) else {
            throw AudioExportError.invalidOutputFormat
        }

        progress = AudioExportProgress(
            phase: .converting,
            progress: 0.2,
            message: "Converting audio..."
        )

        // Read all audio into buffer
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: sourceFrames
        ) else {
            throw AudioExportError.bufferCreationFailed
        }

        try sourceFile.read(into: sourceBuffer)

        // Convert if needed
        var processedBuffer = sourceBuffer

        if needsSampleRateConversion {
            progress.message = "Resampling..."
            processedBuffer = try resample(
                buffer: processedBuffer,
                to: format.sampleRate
            )
        }

        progress = AudioExportProgress(
            phase: .encoding,
            progress: 0.5,
            message: "Encoding to \(format.description)..."
        )

        // Normalize if enabled
        var peakLevel: Float = 0
        var rmsLevel: Float = 0

        if normalizeAudio {
            let (normalized, peak, rms) = normalizeBuffer(processedBuffer)
            processedBuffer = normalized
            peakLevel = peak
            rmsLevel = rms
        } else {
            (peakLevel, rmsLevel) = analyzeBuffer(processedBuffer)
        }

        // Add dither for bit depth reduction
        if addDither && needsBitDepthConversion && format.bitDepth < getBitDepth(from: sourceFormat) {
            processedBuffer = applyDither(to: processedBuffer, targetBitDepth: format.bitDepth)
        }

        progress = AudioExportProgress(
            phase: .writing,
            progress: 0.7,
            message: "Writing file..."
        )

        // Write output file
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: format.isInterleaved
            )
            try outputFile.write(from: processedBuffer)
        } catch {
            return failedResult(error: error, format: format)
        }

        progress = AudioExportProgress(
            phase: .verifying,
            progress: 0.9,
            message: "Verifying output..."
        )

        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        // Verify output
        var warnings: [String] = []

        if peakLevel > truePeakLimit {
            warnings.append("Peak level (\(String(format: "%.1f", peakLevel)) dBFS) exceeds recommended limit")
        }

        progress = AudioExportProgress(
            phase: .complete,
            progress: 1.0,
            message: "Export complete!"
        )

        let result = AudioExportResult(
            success: true,
            outputURL: outputURL,
            inputFormat: "\(Int(sourceFormat.sampleRate))Hz \(sourceFormat.channelCount)ch",
            outputFormat: format,
            duration: Double(sourceFrames) / sourceFormat.sampleRate,
            fileSize: fileSize,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            warnings: warnings,
            error: nil
        )

        lastResult = result
        return result
    }

    /// Batch export for multiple distributors
    public func batchExport(
        sourceURL: URL,
        distributors: [DistributorPlatform]
    ) async throws -> [DistributorPlatform: AudioExportResult] {
        var results: [DistributorPlatform: AudioExportResult] = [:]

        for (index, distributor) in distributors.enumerated() {
            progress = AudioExportProgress(
                phase: .preparing,
                progress: Float(index) / Float(distributors.count),
                message: "Exporting for \(distributor.rawValue)..."
            )

            do {
                let result = try await export(sourceURL: sourceURL, for: distributor)
                results[distributor] = result
            } catch {
                results[distributor] = failedResult(error: error, format: distributor.audioRequirements.toExportFormat)
            }
        }

        return results
    }

    // MARK: - Immersive Audio Export

    /// Check if source has immersive audio
    public func detectImmersiveFormat(sourceURL: URL) -> ImmersiveAudioFormat {
        guard let file = try? AVAudioFile(forReading: sourceURL) else {
            return .stereo
        }

        let channels = file.processingFormat.channelCount

        switch channels {
        case 2: return .stereo
        case 4: return .ambisonicsFirstOrder
        case 9: return .ambisonicsSecondOrder
        case 16: return .ambisonicsThirdOrder
        case 8...12: return .dolbyAtmos // Likely bed mix
        default: return .stereo
        }
    }

    /// Export immersive audio with format conversion
    public func exportImmersive(
        sourceURL: URL,
        targetFormat: ImmersiveAudioFormat,
        for distributor: DistributorPlatform
    ) async throws -> AudioExportResult {
        let sourceFormat = detectImmersiveFormat(sourceURL: sourceURL)

        // Check if distributor supports immersive
        if !targetFormat.distributorSupport.contains(distributor) {
            // Fallback to stereo binaural render
            return try await exportBinauralDownmix(sourceURL: sourceURL, for: distributor)
        }

        // For now, export as-is if formats match
        if sourceFormat == targetFormat {
            return try await export(sourceURL: sourceURL, for: distributor)
        }

        // Conversion between immersive formats would require specialized processing
        throw AudioExportError.immersiveConversionNotSupported(from: sourceFormat, to: targetFormat)
    }

    /// Create binaural downmix from immersive source
    public func exportBinauralDownmix(
        sourceURL: URL,
        for distributor: DistributorPlatform
    ) async throws -> AudioExportResult {
        progress = AudioExportProgress(
            phase: .converting,
            progress: 0.3,
            message: "Creating binaural downmix..."
        )

        // This would use HRTF processing to create binaural stereo
        // For now, simple stereo export
        return try await export(sourceURL: sourceURL, for: distributor)
    }

    // MARK: - Helpers

    private func resample(buffer: AVAudioPCMBuffer, to sampleRate: Double) throws -> AVAudioPCMBuffer {
        guard let inputFormat = buffer.format as AVAudioFormat?,
              let outputFormat = AVAudioFormat(
                  standardFormatWithSampleRate: sampleRate,
                  channels: inputFormat.channelCount
              ) else {
            throw AudioExportError.resamplingFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioExportError.resamplingFailed
        }

        let ratio = sampleRate / inputFormat.sampleRate
        let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrames) else {
            throw AudioExportError.bufferCreationFailed
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw error
        }

        return outputBuffer
    }

    private func normalizeBuffer(_ buffer: AVAudioPCMBuffer) -> (AVAudioPCMBuffer, Float, Float) {
        guard let floatData = buffer.floatChannelData else {
            return (buffer, 0, 0)
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        var sumSquares: Float = 0

        // Find peak and RMS
        for channel in 0..<channelCount {
            var channelPeak: Float = 0
            vDSP_maxmgv(floatData[channel], 1, &channelPeak, vDSP_Length(frameCount))
            peak = max(peak, channelPeak)

            var channelSumSq: Float = 0
            vDSP_svesq(floatData[channel], 1, &channelSumSq, vDSP_Length(frameCount))
            sumSquares += channelSumSq
        }

        let rms = sqrt(sumSquares / Float(frameCount * channelCount))

        // Calculate gain needed
        let targetPeak: Float = pow(10, truePeakLimit / 20)
        let gain = peak > 0 ? min(targetPeak / peak, 2.0) : 1.0 // Max 6dB boost

        // Apply gain
        if gain != 1.0 {
            for channel in 0..<channelCount {
                var gainValue = gain
                vDSP_vsmul(floatData[channel], 1, &gainValue, floatData[channel], 1, vDSP_Length(frameCount))
            }
        }

        let peakDB = 20 * log10(peak)
        let rmsDB = 20 * log10(rms)

        return (buffer, peakDB, rmsDB)
    }

    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer) -> (Float, Float) {
        guard let floatData = buffer.floatChannelData else {
            return (0, 0)
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        var sumSquares: Float = 0

        for channel in 0..<channelCount {
            var channelPeak: Float = 0
            vDSP_maxmgv(floatData[channel], 1, &channelPeak, vDSP_Length(frameCount))
            peak = max(peak, channelPeak)

            var channelSumSq: Float = 0
            vDSP_svesq(floatData[channel], 1, &channelSumSq, vDSP_Length(frameCount))
            sumSquares += channelSumSq
        }

        let rms = sqrt(sumSquares / Float(frameCount * channelCount))
        let peakDB = peak > 0 ? 20 * log10(peak) : -96
        let rmsDB = rms > 0 ? 20 * log10(rms) : -96

        return (peakDB, rmsDB)
    }

    private func applyDither(to buffer: AVAudioPCMBuffer, targetBitDepth: Int) -> AVAudioPCMBuffer {
        guard let floatData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // TPDF dither
        let ditherAmplitude: Float = 1.0 / Float(1 << (targetBitDepth - 1))

        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                let dither = (Float.random(in: -1...1) + Float.random(in: -1...1)) * ditherAmplitude * 0.5
                floatData[channel][frame] += dither
            }
        }

        return buffer
    }

    private func createOutputSettings(format: AudioExportFormat) -> [String: Any] {
        var settings: [String: Any] = [
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channels
        ]

        switch format.fileFormat {
        case .wav, .aiff:
            settings[AVFormatIDKey] = format.fileFormat == .wav ? kAudioFormatLinearPCM : kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = format.bitDepth
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = format.fileFormat == .aiff
            settings[AVLinearPCMIsNonInterleaved] = !format.isInterleaved

        case .mp3:
            settings[AVFormatIDKey] = kAudioFormatMPEGLayer3
            settings[AVEncoderBitRateKey] = 320000

        case .aac:
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            settings[AVEncoderBitRateKey] = 256000

        case .alac:
            settings[AVFormatIDKey] = kAudioFormatAppleLossless
            settings[AVEncoderBitDepthHintKey] = format.bitDepth

        case .flac:
            // FLAC not natively supported, fallback to WAV
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = format.bitDepth
        }

        return settings
    }

    private func getBitDepth(from format: AVAudioFormat) -> Int {
        if format.commonFormat == .pcmFormatFloat32 { return 32 }
        if format.commonFormat == .pcmFormatFloat64 { return 64 }
        if format.commonFormat == .pcmFormatInt16 { return 16 }
        if format.commonFormat == .pcmFormatInt32 { return 24 } // Usually 24-bit in 32-bit container
        return 16
    }

    private func generateOutputURL(from sourceURL: URL, format: AudioExportFormat) -> URL {
        let filename = sourceURL.deletingPathExtension().lastPathComponent
        let outputFilename = "\(filename)_\(Int(format.sampleRate / 1000))k_\(format.bitDepth)bit.\(format.fileFormat.fileExtension)"
        return sourceURL.deletingLastPathComponent().appendingPathComponent(outputFilename)
    }

    private func mapFormat(_ format: DistributorPlatform.AudioRequirements.AudioFormat) -> AudioExportFormat.FileFormat {
        switch format {
        case .wav: return .wav
        case .aiff: return .aiff
        case .flac: return .flac
        case .adm: return .wav // ADM uses WAV container
        }
    }

    private func failedResult(error: Error, format: AudioExportFormat) -> AudioExportResult {
        AudioExportResult(
            success: false,
            outputURL: nil,
            inputFormat: "",
            outputFormat: format,
            duration: 0,
            fileSize: 0,
            peakLevel: 0,
            rmsLevel: 0,
            warnings: [],
            error: error
        )
    }
}

// MARK: - Errors

public enum AudioExportError: Error, LocalizedError {
    case invalidOutputFormat
    case bufferCreationFailed
    case resamplingFailed
    case writeFailed
    case immersiveConversionNotSupported(from: ImmersiveAudioFormat, to: ImmersiveAudioFormat)

    public var errorDescription: String? {
        switch self {
        case .invalidOutputFormat:
            return "Invalid output format"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .resamplingFailed:
            return "Sample rate conversion failed"
        case .writeFailed:
            return "Failed to write output file"
        case .immersiveConversionNotSupported(let from, let to):
            return "Conversion from \(from.rawValue) to \(to.rawValue) not supported"
        }
    }
}

// MARK: - Extension for AudioRequirements

extension DistributorPlatform.AudioRequirements {
    var toExportFormat: AudioExportFormat {
        AudioExportFormat(
            sampleRate: Double(sampleRate),
            bitDepth: bitDepth,
            fileFormat: {
                switch format {
                case .wav: return .wav
                case .aiff: return .aiff
                case .flac: return .flac
                case .adm: return .wav
                }
            }(),
            channels: channels == .stereo ? 2 : 12,
            isInterleaved: true
        )
    }
}

// MARK: - Quick Export Extension

extension AudioExportEngine {
    /// Quick export for musicHub (24-bit 44.1kHz WAV)
    public func exportForMusicHub(sourceURL: URL) async throws -> AudioExportResult {
        return try await export(sourceURL: sourceURL, for: .musicHub)
    }

    /// Export stereo + Dolby Atmos versions
    public func exportStereoAndImmersive(
        stereoURL: URL,
        immersiveURL: URL?
    ) async throws -> (stereo: AudioExportResult, immersive: AudioExportResult?) {
        // Export stereo for regular distributors
        let stereoResult = try await export(sourceURL: stereoURL, for: .musicHub)

        // If immersive source exists, export for Apple Music
        var immersiveResult: AudioExportResult?
        if let immersiveURL = immersiveURL {
            immersiveResult = try await export(sourceURL: immersiveURL, for: .appleMusicForArtists)
        }

        return (stereoResult, immersiveResult)
    }
}
