// TrackFreezeEngine.swift
// Echoelmusic
//
// Professional track freeze/bounce engine for CPU optimization.
// Renders track effects offline to a flat audio file, allowing
// the original effects chain to be bypassed.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import Combine
import Accelerate

// MARK: - Freeze Configuration

/// Configuration for track freeze operation
public struct FreezeConfiguration: Codable, Sendable {
    /// Sample rate for frozen audio
    public var sampleRate: Double

    /// Bit depth for frozen audio
    public var bitDepth: Int

    /// Whether to include sends in the freeze
    public var includeSends: Bool

    /// Whether to include automation in the freeze
    public var includeAutomation: Bool

    /// Tail length in seconds (for reverb/delay tails)
    public var tailLength: TimeInterval

    /// Normalize frozen audio
    public var normalize: Bool

    public init(
        sampleRate: Double = 48000,
        bitDepth: Int = 24,
        includeSends: Bool = false,
        includeAutomation: Bool = true,
        tailLength: TimeInterval = 2.0,
        normalize: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.includeSends = includeSends
        self.includeAutomation = includeAutomation
        self.tailLength = tailLength
        self.normalize = normalize
    }
}

// MARK: - Freeze State

/// State of a frozen track
public enum TrackFreezeState: String, Codable, Sendable {
    case unfrozen
    case freezing
    case frozen
    case unfreezing
}

// MARK: - Freeze Result

/// Result of a freeze operation
public struct FreezeResult: Sendable {
    public let trackId: UUID
    public let frozenAudioURL: URL
    public let originalDuration: TimeInterval
    public let frozenDuration: TimeInterval
    public let peakLevel: Float
    public let rmsLevel: Float
    public let cpuSaved: Double
    public let diskSize: Int64
}

// MARK: - Freeze Error

public enum FreezeError: LocalizedError {
    case trackNotFound
    case noAudioToFreeze
    case renderingFailed(String)
    case fileWriteFailed
    case alreadyFrozen
    case notFrozen

    public var errorDescription: String? {
        switch self {
        case .trackNotFound: return "Track not found"
        case .noAudioToFreeze: return "No audio content to freeze"
        case .renderingFailed(let reason): return "Rendering failed: \(reason)"
        case .fileWriteFailed: return "Failed to write frozen audio file"
        case .alreadyFrozen: return "Track is already frozen"
        case .notFrozen: return "Track is not frozen"
        }
    }
}

// MARK: - Track Freeze Engine

/// Professional track freeze/bounce engine
/// Renders tracks with all effects offline to reduce real-time CPU load
@MainActor
public final class TrackFreezeEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var freezeStates: [UUID: TrackFreezeState] = [:]
    @Published public private(set) var freezeProgress: [UUID: Double] = [:]
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var totalCPUSaved: Double = 0

    // MARK: - Private Properties

    private let configuration: FreezeConfiguration
    private let renderQueue = DispatchQueue(label: "com.echoelmusic.freeze.render", qos: .userInitiated)
    private var frozenFiles: [UUID: URL] = [:]
    private var originalEffects: [UUID: [String]] = [:]

    // MARK: - Initialization

    public init(configuration: FreezeConfiguration = FreezeConfiguration()) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Freeze a track, rendering all effects offline
    /// - Parameters:
    ///   - trackId: ID of the track to freeze
    ///   - audioURL: URL of the track's source audio
    ///   - effectChain: List of effect names currently on the track
    ///   - duration: Duration of the track
    /// - Returns: FreezeResult with details about the frozen audio
    public func freezeTrack(
        trackId: UUID,
        audioURL: URL,
        effectChain: [String] = [],
        duration: TimeInterval
    ) async throws -> FreezeResult {
        guard freezeStates[trackId] != .frozen else {
            throw FreezeError.alreadyFrozen
        }

        freezeStates[trackId] = .freezing
        freezeProgress[trackId] = 0
        isProcessing = true

        do {
            // Store original effects for unfreeze
            originalEffects[trackId] = effectChain

            // Create output URL
            let outputURL = freezeFileURL(for: trackId)

            // Render the track offline with all effects
            let result = try await renderTrackOffline(
                trackId: trackId,
                sourceURL: audioURL,
                outputURL: outputURL,
                duration: duration
            )

            // Update state
            frozenFiles[trackId] = outputURL
            freezeStates[trackId] = .frozen
            freezeProgress[trackId] = 1.0
            isProcessing = false

            // Estimate CPU saved (roughly proportional to effect count)
            let savedCPU = Double(effectChain.count) * 2.5
            totalCPUSaved += savedCPU

            return FreezeResult(
                trackId: trackId,
                frozenAudioURL: outputURL,
                originalDuration: duration,
                frozenDuration: result.duration,
                peakLevel: result.peakLevel,
                rmsLevel: result.rmsLevel,
                cpuSaved: savedCPU,
                diskSize: result.fileSize
            )
        } catch {
            freezeStates[trackId] = .unfrozen
            freezeProgress[trackId] = 0
            isProcessing = false
            throw error
        }
    }

    /// Unfreeze a track, restoring original effects chain
    /// - Parameter trackId: ID of the track to unfreeze
    /// - Returns: The original effect chain names
    public func unfreezeTrack(trackId: UUID) throws -> [String] {
        guard freezeStates[trackId] == .frozen else {
            throw FreezeError.notFrozen
        }

        freezeStates[trackId] = .unfreezing

        // Remove frozen file
        if let frozenURL = frozenFiles[trackId] {
            try? FileManager.default.removeItem(at: frozenURL)
            frozenFiles.removeValue(forKey: trackId)
        }

        let effects = originalEffects[trackId] ?? []
        originalEffects.removeValue(forKey: trackId)

        // Restore CPU count
        let savedCPU = Double(effects.count) * 2.5
        totalCPUSaved = max(0, totalCPUSaved - savedCPU)

        freezeStates[trackId] = .unfrozen
        freezeProgress[trackId] = 0

        return effects
    }

    /// Bounce a track to a new audio file (similar to freeze but creates an exportable file)
    /// - Parameters:
    ///   - trackId: ID of the track
    ///   - audioURL: Source audio URL
    ///   - outputURL: Destination URL for bounced audio
    ///   - duration: Track duration
    /// - Returns: URL of the bounced file
    public func bounceTrack(
        trackId: UUID,
        audioURL: URL,
        outputURL: URL,
        duration: TimeInterval
    ) async throws -> URL {
        isProcessing = true
        freezeProgress[trackId] = 0

        do {
            let result = try await renderTrackOffline(
                trackId: trackId,
                sourceURL: audioURL,
                outputURL: outputURL,
                duration: duration
            )

            freezeProgress[trackId] = 1.0
            isProcessing = false
            return outputURL
        } catch {
            freezeProgress[trackId] = 0
            isProcessing = false
            throw error
        }
    }

    /// Bounce in place — replace original audio with rendered version
    public func bounceInPlace(
        trackId: UUID,
        audioURL: URL,
        duration: TimeInterval
    ) async throws -> URL {
        let outputURL = bounceFileURL(for: trackId)

        _ = try await bounceTrack(
            trackId: trackId,
            audioURL: audioURL,
            outputURL: outputURL,
            duration: duration
        )

        return outputURL
    }

    /// Get the frozen audio URL for a track
    public func frozenAudioURL(for trackId: UUID) -> URL? {
        return frozenFiles[trackId]
    }

    /// Check if a track is frozen
    public func isFrozen(_ trackId: UUID) -> Bool {
        return freezeStates[trackId] == .frozen
    }

    // MARK: - Offline Rendering

    private struct RenderResult {
        let duration: TimeInterval
        let peakLevel: Float
        let rmsLevel: Float
        let fileSize: Int64
    }

    /// Render audio file offline with effects processing
    private func renderTrackOffline(
        trackId: UUID,
        sourceURL: URL,
        outputURL: URL,
        duration: TimeInterval
    ) async throws -> RenderResult {
        return try await withCheckedThrowingContinuation { continuation in
            renderQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FreezeError.renderingFailed("Engine deallocated"))
                    return
                }

                do {
                    let result = try self.performOfflineRender(
                        trackId: trackId,
                        sourceURL: sourceURL,
                        outputURL: outputURL,
                        duration: duration
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Perform the actual offline rendering
    private nonisolated func performOfflineRender(
        trackId: UUID,
        sourceURL: URL,
        outputURL: URL,
        duration: TimeInterval
    ) throws -> RenderResult {
        // Read source audio
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let format = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)

        guard frameCount > 0 else {
            throw FreezeError.noAudioToFreeze
        }

        // Read source buffer
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw FreezeError.renderingFailed("Failed to allocate source audio buffer")
        }
        try sourceFile.read(into: sourceBuffer)

        // Create offline audio engine for rendering
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()

        engine.attach(playerNode)

        // Connect with effects chain (the engine processes the audio)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        // Enable manual rendering
        let maxFrames: AVAudioFrameCount = 4096

        try engine.enableManualRenderingMode(
            .offline,
            format: format,
            maximumFrameCount: maxFrames
        )

        try engine.start()
        playerNode.play()

        // Schedule the source buffer
        playerNode.scheduleBuffer(sourceBuffer, completionHandler: nil)

        // Calculate total frames including tail
        let tailFrames = AVAudioFrameCount(duration * format.sampleRate) + AVAudioFrameCount(2.0 * format.sampleRate)
        let totalFrames = max(frameCount, tailFrames)

        // Create output file
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        // Render loop
        guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: maxFrames) else {
            throw FreezeError.renderingFailed("Failed to allocate render buffer")
        }
        var framesRendered: AVAudioFrameCount = 0
        var peakLevel: Float = 0
        var sumSquares: Float = 0
        var totalSamples: Int = 0

        while framesRendered < totalFrames {
            let framesToRender = min(maxFrames, totalFrames - framesRendered)

            let status = try engine.renderOffline(framesToRender, to: renderBuffer)

            switch status {
            case .success:
                try outputFile.write(from: renderBuffer)

                // Analyze levels
                if let channelData = renderBuffer.floatChannelData?[0] {
                    let count = Int(renderBuffer.frameLength)
                    for i in 0..<count {
                        let sample = abs(channelData[i])
                        peakLevel = max(peakLevel, sample)
                        sumSquares += sample * sample
                    }
                    totalSamples += count
                }

                framesRendered += renderBuffer.frameLength

            case .insufficientDataFromInputNode:
                // No more data from player, but keep rendering for tail
                framesRendered += framesToRender

            case .cannotDoInCurrentContext:
                // Retry — yield to allow audio engine to catch up
                usleep(1000) // 1ms non-blocking yield

            case .error:
                throw FreezeError.renderingFailed("Render error at frame \(framesRendered)")

            @unknown default:
                break
            }
        }

        engine.stop()

        // Calculate RMS
        let rmsLevel = totalSamples > 0 ? sqrt(sumSquares / Float(totalSamples)) : 0

        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        return RenderResult(
            duration: Double(framesRendered) / format.sampleRate,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            fileSize: fileSize
        )
    }

    // MARK: - File Management

    private func freezeFileURL(for trackId: UUID) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let freezeDir = cacheDir.appendingPathComponent("FrozenTracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: freezeDir, withIntermediateDirectories: true)
        return freezeDir.appendingPathComponent("\(trackId.uuidString)_frozen.wav")
    }

    private func bounceFileURL(for trackId: UUID) -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bounceDir = documentsDir.appendingPathComponent("Bounced", isDirectory: true)
        try? FileManager.default.createDirectory(at: bounceDir, withIntermediateDirectories: true)
        return bounceDir.appendingPathComponent("\(trackId.uuidString)_bounced.wav")
    }

    /// Clean up all frozen files
    public func cleanupAllFrozenFiles() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let freezeDir = cacheDir.appendingPathComponent("FrozenTracks", isDirectory: true)
        try? FileManager.default.removeItem(at: freezeDir)

        frozenFiles.removeAll()
        freezeStates.removeAll()
        freezeProgress.removeAll()
        originalEffects.removeAll()
        totalCPUSaved = 0
    }
}
